import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../model/dataset.dart';
import '../portable/portable_codec.dart';
import '../util/clock.dart';
import '../util/json_reader.dart';
import 'crypto.dart';

/// Installation-specific state that is stored encrypted together with the
/// data set but is not part of exports or backups.
class DeviceState {
  const DeviceState({this.onboardingCompleted = false, this.foodApiBaseUrl});

  final bool onboardingCompleted;

  /// User override of the food database origin (null = build default).
  final String? foodApiBaseUrl;

  DeviceState copyWith({
    bool? onboardingCompleted,
    String? Function()? foodApiBaseUrl,
  }) => DeviceState(
    onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
    foodApiBaseUrl: foodApiBaseUrl != null
        ? foodApiBaseUrl()
        : this.foodApiBaseUrl,
  );

  Map<String, Object?> toJson() => {
    'onboarding_completed': onboardingCompleted,
    'food_api_base_url': foodApiBaseUrl,
  };

  static DeviceState fromJson(Object? json) {
    if (json is! Map) return const DeviceState();
    final url = json['food_api_base_url'];
    return DeviceState(
      onboardingCompleted: json['onboarding_completed'] == true,
      foodApiBaseUrl: url is String && url.isNotEmpty ? url : null,
    );
  }
}

/// In-memory content of a store.
class StoreContents {
  StoreContents(this.dataset, this.device);

  final Dataset dataset;
  DeviceState device;
}

enum StoreErrorKind { wrongKey, corrupted, unsupported, locked, io }

class StoreException implements Exception {
  StoreException(this.kind, this.message);

  final StoreErrorKind kind;
  final String message;

  String get code => switch (kind) {
    StoreErrorKind.wrongKey => 'store_wrong_key',
    StoreErrorKind.corrupted => 'store_corrupted',
    StoreErrorKind.unsupported => 'store_unsupported',
    StoreErrorKind.locked => 'store_locked',
    StoreErrorKind.io => 'store_io_error',
  };

  @override
  String toString() => 'StoreException($code): $message';
}

/// Result of decoding a snapshot file (pure function, isolate friendly).
class SnapshotData {
  SnapshotData({
    required this.storeId,
    required this.generation,
    required this.createdAt,
    required this.contents,
    required this.warnings,
  });

  final String storeId;
  final int generation;
  final DateTime createdAt;
  final StoreContents contents;
  final List<Issue> warnings;
}

/// Encrypted, crash-safe persistence of a MorphHealth data set.
///
/// Layout of a data directory:
///
/// * `morphhealth.snapshot` – full state: `MHSTORE1`, a length-prefixed
///   plaintext JSON header (authenticated as AAD) and
///   AES-256-GCM(gzip(JSON)). Replaced atomically (write temp + rename).
/// * `morphhealth.journal` – append-only log of changes since the snapshot:
///   `MHJRNL01`, a header, then records `u32 length | nonce | ciphertext |
///   tag`. Each record's AAD binds store id, generation and sequence number.
/// * `morphhealth.lock` – exclusive lock held while the store is open.
///
/// The AES key is derived from the 32-byte master key with HKDF-SHA256
/// (salt = store id, info = `morphhealth/store/v1`).
class EncryptedStore {
  EncryptedStore._(
    this.directory,
    this._storeKey,
    this.storeId,
    this._generation,
    this.createdAt,
    this._lock,
  );

  static const String snapshotName = 'morphhealth.snapshot';
  static const String journalName = 'morphhealth.journal';
  static const String lockName = 'morphhealth.lock';
  static const String formatId = 'morphhealth.store';
  static const int formatVersion = 1;

  static final List<int> _snapshotMagic = ascii.encode('MHSTORE1');
  static final List<int> _journalMagic = ascii.encode('MHJRNL01');
  static final List<int> _keyCheckLabel = utf8.encode(
    'morphhealth key check v1',
  );

  /// Compact the journal into a new snapshot after this many records.
  static const int compactAfterRecords = 400;

  final Directory directory;
  final Uint8List _storeKey;
  final String storeId;
  final DateTime createdAt;
  int _generation;
  final RandomAccessFile _lock;
  RandomAccessFile? _journal;
  int _sequence = 0;
  bool _closed = false;

  int get generation => _generation;
  int get journalRecords => _sequence;
  bool get needsCompaction => _sequence >= compactAfterRecords;

  File get _snapshotFile => File('${directory.path}/$snapshotName');
  File get _journalFile => File('${directory.path}/$journalName');

  static Uint8List deriveStoreKey(List<int> masterKey, List<int> storeIdBytes) {
    if (masterKey.length != 32) {
      throw ArgumentError('The master key must be exactly 32 bytes');
    }
    return hkdfSha256(
      masterKey,
      salt: storeIdBytes,
      info: utf8.encode('morphhealth/store/v1'),
    );
  }

  static String _keyCheck(List<int> storeKey) =>
      base64UrlNoPad(hmacSha256(storeKey, _keyCheckLabel).sublist(0, 16));

  /// Opens (or creates) the store in [directory]. [decoder] may move the
  /// CPU-heavy snapshot decoding to a background isolate.
  static Future<OpenedStore> open(
    Directory directory,
    List<int> masterKey, {
    required DateTime now,
    SnapshotDecoder? decoder,
  }) async {
    try {
      await directory.create(recursive: true);
    } on FileSystemException catch (e) {
      throw StoreException(StoreErrorKind.io, 'Cannot create directory: $e');
    }
    final lock = await _acquireLock(directory);
    try {
      final snapshotFile = File('${directory.path}/$snapshotName');
      final journalFile = File('${directory.path}/$journalName');
      if (!await snapshotFile.exists()) {
        if (await journalFile.exists()) {
          throw StoreException(
            StoreErrorKind.corrupted,
            'Journal found without snapshot',
          );
        }
        return await _create(directory, masterKey, lock, now);
      }
      final bytes = await snapshotFile.readAsBytes();
      final snap = decoder == null
          ? decodeSnapshot(bytes, masterKey, now: now)
          : await decoder(bytes, masterKey, now);
      final store = EncryptedStore._(
        directory,
        deriveStoreKey(masterKey, decodeBase64Flexible(snap.storeId)),
        snap.storeId,
        snap.generation,
        snap.createdAt,
        lock,
      );
      final warnings = <String>[...snap.warnings.map((w) => w.toString())];
      final replay = await store._replayJournal(snap.contents, now);
      warnings.addAll(replay.warnings);
      if (replay.needsRewrite) {
        await store.writeSnapshot(snap.contents, now: now);
      } else {
        await store._openJournalForAppend();
      }
      return OpenedStore(store, snap.contents, warnings);
    } catch (_) {
      await _releaseLock(lock);
      rethrow;
    }
  }

  static Future<RandomAccessFile> _acquireLock(Directory directory) async {
    final file = File('${directory.path}/$lockName');
    final raf = await file.open(mode: FileMode.append);
    try {
      await raf.lock(FileLock.exclusive);
    } on FileSystemException {
      await raf.close();
      throw StoreException(
        StoreErrorKind.locked,
        'The data directory is in use by another process',
      );
    }
    return raf;
  }

  static Future<void> _releaseLock(RandomAccessFile lock) async {
    try {
      await lock.unlock();
    } catch (_) {}
    try {
      await lock.close();
    } catch (_) {}
  }

  static Future<OpenedStore> _create(
    Directory directory,
    List<int> masterKey,
    RandomAccessFile lock,
    DateTime now,
  ) async {
    final idBytes = randomBytes(16);
    final storeId = base64UrlNoPad(idBytes);
    final store = EncryptedStore._(
      directory,
      deriveStoreKey(masterKey, idBytes),
      storeId,
      0,
      now,
      lock,
    );
    final contents = StoreContents(Dataset(), const DeviceState());
    await store.writeSnapshot(contents, now: now);
    return OpenedStore(store, contents, const []);
  }

  // ---------------------------------------------------------------------
  // Snapshot encoding (pure functions; can run in a background isolate).

  static Map<String, Object?> _contentJson(
    StoreContents contents,
    DateTime now,
  ) => {
    'store_version': formatVersion,
    'device': contents.device.toJson(),
    'data': encodePortable(
      contents.dataset,
      exportedAt: now,
      appVersion: 'store',
    ),
  };

  static Uint8List encodeSnapshot({
    required List<int> storeKey,
    required String storeId,
    required int generation,
    required DateTime createdAt,
    required DateTime writtenAt,
    required StoreContents contents,
  }) {
    final header = utf8.encode(
      jsonEncode({
        'format': formatId,
        'version': formatVersion,
        'store_id': storeId,
        'generation': generation,
        'created_at': formatInstant(createdAt),
        'written_at': formatInstant(writtenAt),
        'cipher': 'AES-256-GCM',
        'kdf': 'HKDF-SHA256',
        'compression': 'gzip',
        'key_check': _keyCheck(storeKey),
      }),
    );
    final prefix = BytesBuilder(copy: false)
      ..add(_snapshotMagic)
      ..add(_u32(header.length))
      ..add(header);
    final aad = prefix.toBytes();
    final plain = gzip.encode(
      utf8.encode(jsonEncode(_contentJson(contents, writtenAt))),
    );
    final sealed = Aead.seal(storeKey, plain, aad);
    return (BytesBuilder(copy: false)
          ..add(aad)
          ..add(sealed))
        .toBytes();
  }

  static SnapshotData decodeSnapshot(
    Uint8List bytes,
    List<int> masterKey, {
    required DateTime now,
  }) {
    if (bytes.length < 12 || !_startsWith(bytes, _snapshotMagic)) {
      throw StoreException(StoreErrorKind.corrupted, 'Not a MorphHealth store');
    }
    final headerLength = _readU32(bytes, 8);
    if (12 + headerLength > bytes.length) {
      throw StoreException(StoreErrorKind.corrupted, 'Truncated snapshot');
    }
    Map<String, Object?> header;
    try {
      header =
          jsonDecode(utf8.decode(bytes.sublist(12, 12 + headerLength)))
              as Map<String, Object?>;
    } catch (_) {
      throw StoreException(StoreErrorKind.corrupted, 'Unreadable header');
    }
    if (header['format'] != formatId) {
      throw StoreException(StoreErrorKind.corrupted, 'Unknown store format');
    }
    final version = header['version'];
    if (version is! int || version > formatVersion) {
      throw StoreException(
        StoreErrorKind.unsupported,
        'Store version $version is not supported',
      );
    }
    final storeId = header['store_id'];
    final generation = header['generation'];
    if (storeId is! String || generation is! int) {
      throw StoreException(StoreErrorKind.corrupted, 'Incomplete header');
    }
    final storeKey = deriveStoreKey(masterKey, decodeBase64Flexible(storeId));
    if (header['key_check'] != _keyCheck(storeKey)) {
      throw StoreException(
        StoreErrorKind.wrongKey,
        'The key does not belong to this data store',
      );
    }
    final aad = Uint8List.sublistView(bytes, 0, 12 + headerLength);
    Uint8List plain;
    try {
      plain = Aead.open(
        storeKey,
        Uint8List.sublistView(bytes, 12 + headerLength),
        aad,
      );
    } on AeadAuthenticationException {
      throw StoreException(
        StoreErrorKind.corrupted,
        'The snapshot is damaged (authentication failed)',
      );
    }
    Object? content;
    try {
      content = jsonDecode(utf8.decode(gzip.decode(plain)));
    } catch (_) {
      throw StoreException(StoreErrorKind.corrupted, 'Unreadable content');
    }
    if (content is! Map) {
      throw StoreException(StoreErrorKind.corrupted, 'Unexpected content');
    }
    DecodedPortable decoded;
    try {
      decoded = decodePortable(content['data'], now: now);
    } on ValidationException catch (e) {
      throw StoreException(
        StoreErrorKind.corrupted,
        'Stored data is invalid: $e',
      );
    }
    return SnapshotData(
      storeId: storeId,
      generation: generation,
      createdAt: tryParseInstant(header['created_at']) ?? now,
      contents: StoreContents(
        decoded.dataset,
        DeviceState.fromJson(content['device']),
      ),
      warnings: decoded.warnings,
    );
  }

  // ---------------------------------------------------------------------
  // Writing.

  /// Writes a complete new snapshot and starts an empty journal.
  Future<void> writeSnapshot(
    StoreContents contents, {
    required DateTime now,
    Uint8List? preEncoded,
  }) async {
    _checkOpen();
    final nextGeneration = _generation + 1;
    final bytes =
        preEncoded ??
        encodeSnapshot(
          storeKey: _storeKey,
          storeId: storeId,
          generation: nextGeneration,
          createdAt: createdAt,
          writtenAt: now,
          contents: contents,
        );
    await _journal?.close();
    _journal = null;
    try {
      await _atomicWrite(_snapshotFile, bytes);
      _generation = nextGeneration;
      await _atomicWrite(_journalFile, _journalHeader(nextGeneration));
    } on FileSystemException catch (e) {
      throw StoreException(StoreErrorKind.io, 'Write failed: $e');
    }
    _sequence = 0;
    await _openJournalForAppend();
  }

  /// Encodes a snapshot for the next generation without writing it; used to
  /// move the CPU-heavy part into a background isolate.
  SnapshotJob prepareSnapshotJob(DateTime now) => SnapshotJob(
    storeKey: _storeKey,
    storeId: storeId,
    generation: _generation + 1,
    createdAt: createdAt,
    writtenAt: now,
  );

  /// Appends one change record (a JSON object) to the journal.
  Future<void> append(Map<String, Object?> operation) async {
    _checkOpen();
    final journal = _journal!;
    final plain = utf8.encode(jsonEncode(operation));
    final sealed = Aead.seal(_storeKey, plain, _recordAad(_sequence));
    final record = BytesBuilder(copy: false)
      ..add(_u32(sealed.length))
      ..add(sealed);
    try {
      await journal.writeFrom(record.toBytes());
      await journal.flush();
    } on FileSystemException catch (e) {
      throw StoreException(StoreErrorKind.io, 'Journal write failed: $e');
    }
    _sequence++;
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _journal?.close();
    _journal = null;
    await _releaseLock(_lock);
  }

  /// Deletes all store files in [directory] (the directory itself remains).
  static Future<void> destroyFiles(Directory directory) async {
    for (final name in [
      snapshotName,
      journalName,
      '$snapshotName.tmp',
      '$journalName.tmp',
    ]) {
      final f = File('${directory.path}/$name');
      if (await f.exists()) await f.delete();
    }
    if (await directory.exists()) {
      await for (final entity in directory.list()) {
        if (entity is File &&
            entity.uri.pathSegments.last.startsWith('$journalName.damaged')) {
          await entity.delete();
        }
      }
    }
  }

  // ---------------------------------------------------------------------
  // Journal handling.

  List<int> _recordAad(int sequence) {
    final b = BytesBuilder(copy: false)
      ..add(_journalMagic)
      ..add(utf8.encode(storeId))
      ..add(_u64(_generation))
      ..add(_u64(sequence));
    return b.toBytes();
  }

  Uint8List _journalHeader(int generation) {
    final header = utf8.encode(
      jsonEncode({'store_id': storeId, 'generation': generation}),
    );
    return (BytesBuilder(copy: false)
          ..add(_journalMagic)
          ..add(_u32(header.length))
          ..add(header))
        .toBytes();
  }

  Future<void> _openJournalForAppend() async {
    if (!await _journalFile.exists()) {
      await _atomicWrite(_journalFile, _journalHeader(_generation));
      _sequence = 0;
    }
    _journal = await _journalFile.open(mode: FileMode.append);
  }

  Future<_ReplayResult> _replayJournal(StoreContents contents, DateTime now) async {
    final result = _ReplayResult();
    if (!await _journalFile.exists()) return result;
    final bytes = await _journalFile.readAsBytes();
    if (bytes.length < 12 || !_startsWith(bytes, _journalMagic)) {
      result.warnings.add('Journal header unreadable; journal ignored');
      await _quarantineJournal(now);
      result.needsRewrite = true;
      return result;
    }
    final headerLength = _readU32(bytes, 8);
    Map<String, Object?>? header;
    try {
      header =
          jsonDecode(utf8.decode(bytes.sublist(12, 12 + headerLength)))
              as Map<String, Object?>;
    } catch (_) {
      header = null;
    }
    if (header == null || header['store_id'] != storeId) {
      result.warnings.add('Journal does not belong to this store; ignored');
      await _quarantineJournal(now);
      result.needsRewrite = true;
      return result;
    }
    final journalGeneration = header['generation'];
    if (journalGeneration is! int || journalGeneration < _generation) {
      // Left over from before the last snapshot: already contained in it.
      await _atomicWrite(_journalFile, _journalHeader(_generation));
      return result;
    }
    if (journalGeneration > _generation) {
      throw StoreException(
        StoreErrorKind.corrupted,
        'Journal is newer than the snapshot',
      );
    }
    var offset = 12 + headerLength;
    var sequence = 0;
    while (offset < bytes.length) {
      if (offset + 4 > bytes.length) {
        result.truncatedAt = offset;
        break;
      }
      final length = _readU32(bytes, offset);
      if (offset + 4 + length > bytes.length) {
        result.truncatedAt = offset;
        break;
      }
      final sealed = Uint8List.sublistView(bytes, offset + 4, offset + 4 + length);
      try {
        final plain = Aead.open(_storeKey, sealed, _recordAad(sequence));
        final op = jsonDecode(utf8.decode(plain)) as Map<String, Object?>;
        applyOperation(contents, op, now: now);
      } catch (_) {
        result.warnings.add(
          'Journal record ${sequence + 1} is damaged; later changes '
          'could not be restored',
        );
        await _quarantineJournal(now);
        result.needsRewrite = true;
        return result;
      }
      sequence++;
      offset += 4 + length;
    }
    _sequence = sequence;
    if (result.truncatedAt != null) {
      // An interrupted write left an incomplete record at the end.
      final raf = await _journalFile.open(mode: FileMode.append);
      await raf.truncate(result.truncatedAt!);
      await raf.flush();
      await raf.close();
      result.warnings.add('Removed an incomplete journal record');
    }
    if (_sequence >= compactAfterRecords) result.needsRewrite = true;
    return result;
  }

  Future<void> _quarantineJournal(DateTime now) async {
    final stamp = now.toUtc().millisecondsSinceEpoch;
    try {
      await _journalFile.rename('${directory.path}/$journalName.damaged-$stamp');
    } on FileSystemException {
      // Best effort only.
    }
  }

  void _checkOpen() {
    if (_closed) throw StateError('Store is closed');
  }

  static Future<void> _atomicWrite(File target, List<int> bytes) async {
    final temp = File('${target.path}.tmp');
    final raf = await temp.open(mode: FileMode.write);
    try {
      await raf.writeFrom(bytes);
      await raf.flush();
    } finally {
      await raf.close();
    }
    await temp.rename(target.path);
  }

  static bool _startsWith(List<int> bytes, List<int> prefix) {
    if (bytes.length < prefix.length) return false;
    for (var i = 0; i < prefix.length; i++) {
      if (bytes[i] != prefix[i]) return false;
    }
    return true;
  }

  static Uint8List _u32(int v) =>
      Uint8List(4)..buffer.asByteData().setUint32(0, v, Endian.big);

  static Uint8List _u64(int v) =>
      Uint8List(8)..buffer.asByteData().setUint64(0, v, Endian.big);

  static int _readU32(Uint8List bytes, int offset) =>
      ByteData.sublistView(bytes, offset, offset + 4).getUint32(0, Endian.big);
}

/// Decodes snapshot bytes (see [EncryptedStore.decodeSnapshot]).
typedef SnapshotDecoder =
    Future<SnapshotData> Function(Uint8List bytes, List<int> masterKey, DateTime now);

class _ReplayResult {
  final List<String> warnings = [];
  bool needsRewrite = false;
  int? truncatedAt;
}

class OpenedStore {
  OpenedStore(this.store, this.contents, this.warnings);

  final EncryptedStore store;
  final StoreContents contents;
  final List<String> warnings;
}

/// Parameters for encoding a snapshot in a background isolate.
class SnapshotJob {
  SnapshotJob({
    required this.storeKey,
    required this.storeId,
    required this.generation,
    required this.createdAt,
    required this.writtenAt,
  });

  final Uint8List storeKey;
  final String storeId;
  final int generation;
  final DateTime createdAt;
  final DateTime writtenAt;

  Uint8List encode(StoreContents contents) => EncryptedStore.encodeSnapshot(
    storeKey: storeKey,
    storeId: storeId,
    generation: generation,
    createdAt: createdAt,
    writtenAt: writtenAt,
    contents: contents,
  );
}

// -------------------------------------------------------------------------
// Journal operations.

/// Journal operation: insert or replace a record.
Map<String, Object?> putOperation(Collection c, Map<String, Object?> record) =>
    {'op': 'put', 'collection': c.json, 'record': record};

/// Journal operation: delete a record.
Map<String, Object?> deleteOperation(Collection c, String id) =>
    {'op': 'delete', 'collection': c.json, 'id': id};

Map<String, Object?> settingsOperation(Map<String, Object?> settings) =>
    {'op': 'settings', 'settings': settings};

Map<String, Object?> deviceOperation(DeviceState device) =>
    {'op': 'device', 'device': device.toJson()};

Map<String, Object?> batchOperation(List<Map<String, Object?>> ops) =>
    {'op': 'batch', 'ops': ops};

/// A validated journal operation, ready to be applied.
typedef PreparedOperation = void Function(StoreContents contents);

/// Validates [op] completely (every record of a batch) without changing
/// anything; throws [ValidationException] or [StoreException] if invalid.
PreparedOperation prepareOperation(
  Map<String, Object?> op, {
  required DateTime now,
}) {
  switch (op['op']) {
    case 'put':
      final c = Collection.byJson[op['collection']];
      if (c == null) throw StoreException(StoreErrorKind.corrupted, 'Bad op');
      final record = decodeRecord(c, op['record'], now: now);
      return (contents) => contents.dataset.put(c, record);
    case 'delete':
      final c = Collection.byJson[op['collection']];
      final id = op['id'];
      if (c == null || id is! String) {
        throw StoreException(StoreErrorKind.corrupted, 'Bad op');
      }
      return (contents) => contents.dataset.remove(c, id);
    case 'settings':
      final settings = settingsFromJson(op['settings'], Issues());
      return (contents) {
        contents.dataset.settings = settings;
        contents.dataset.touch();
      };
    case 'device':
      final device = DeviceState.fromJson(op['device']);
      return (contents) => contents.device = device;
    case 'batch':
      final ops = op['ops'];
      if (ops is! List) throw StoreException(StoreErrorKind.corrupted, 'Bad op');
      final prepared = [
        for (final inner in ops)
          prepareOperation(inner as Map<String, Object?>, now: now),
      ];
      return (contents) {
        for (final apply in prepared) {
          apply(contents);
        }
      };
    default:
      throw StoreException(StoreErrorKind.corrupted, 'Unknown operation');
  }
}

/// Applies a journal operation to [contents]. Operations are idempotent
/// overwrites, so replaying them in order always yields the same state.
void applyOperation(
  StoreContents contents,
  Map<String, Object?> op, {
  required DateTime now,
}) => prepareOperation(op, now: now)(contents);
