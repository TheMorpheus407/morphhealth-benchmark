import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:path/path.dart' as p;

import 'crypto.dart';

/// The kinds of records the local store can hold.
enum RecordKind {
  food,
  journalEntry,
  intake,
  period,
  weight,
  symptom,
  goals,
  settings;

  static RecordKind parse(String value) => RecordKind.values.firstWhere(
        (RecordKind k) => k.name == value,
        orElse: () => RecordKind.food,
      );
}

/// One mutation inside the store log.
class StoreOperation {
  const StoreOperation({
    required this.kind,
    required this.id,
    this.data,
    this.deleted = false,
  });

  final RecordKind kind;
  final String id;

  /// Payload of a `put` operation.
  final Map<String, dynamic>? data;

  /// Whether this operation removes the record.
  final bool deleted;

  String get key => '${kind.name}/$id';

  Map<String, dynamic> toJson() => <String, dynamic>{
        'k': kind.name,
        'id': id,
        if (deleted) 'x': 1,
        if (!deleted && data != null) 'd': data,
      };

  static StoreOperation fromJson(Map<String, dynamic> json) => StoreOperation(
        kind: RecordKind.parse(json['k'] as String? ?? 'food'),
        id: json['id'] as String? ?? '',
        deleted: json['x'] == 1,
        data: json['d'] as Map<String, dynamic>?,
      );
}

/// Encrypted, append only local store.
///
/// Every record is encrypted with AES-256-GCM. The key is derived from the
/// 32 byte master key with HKDF-SHA256, so the master key never has to be
/// stored next to the data.
///
/// On disk the working directory contains:
///  * `manifest.json` – format metadata and the HKDF salt (no health data)
///  * `records.bin`   – the encrypted, append only record log
///  * `store.lock`    – advisory lock file that prevents two writers
class RecordStore {
  RecordStore._(this._directory, this._key, this._salt);

  /// Opens (and creates if needed) the store inside [directory].
  static Future<RecordStore> open({
    required Directory directory,
    required List<int> masterKey,
  }) async {
    if (masterKey.length != 32) {
      throw ArgumentError('Master key must be 32 bytes, got ${masterKey.length}');
    }
    await directory.create(recursive: true);
    final File manifestFile = File(p.join(directory.path, 'manifest.json'));
    List<int> salt;
    if (await manifestFile.exists()) {
      final Map<String, dynamic> manifest = jsonDecode(
        await manifestFile.readAsString(),
      ) as Map<String, dynamic>;
      if (manifest['format'] != storeFormat) {
        throw StateError('Unsupported store format: ${manifest['format']}');
      }
      salt = base64Decode(manifest['salt'] as String);
    } else {
      salt = Crypto.randomBytes(32);
      await manifestFile.writeAsString(
        jsonEncode(<String, dynamic>{
          'format': storeFormat,
          'version': storeVersion,
          'cipher': 'AES-256-GCM',
          'kdf': 'HKDF-SHA256',
          'salt': base64Encode(salt),
          'created_at': DateTime.now().toUtc().toIso8601String(),
        }),
        flush: true,
      );
    }
    final SecretKey key =
        await Crypto.deriveStoreKey(masterKey, salt, storeKeyInfo);
    final RecordStore store = RecordStore._(directory, key, salt);
    await store._load();
    return store;
  }

  static const String storeFormat = 'morphhealth.store';
  static const int storeVersion = 1;
  static const String storeKeyInfo = 'morphhealth/store/dek/v1';

  final Directory _directory;
  final SecretKey _key;
  final List<int> _salt;

  final Map<String, StoreOperation> _records = <String, StoreOperation>{};
  RandomAccessFile? _handle;
  int _frameCounter = 0;
  int _pendingWrites = 0;
  DateTime _lastFlush = DateTime.fromMillisecondsSinceEpoch(0);

  /// Records are written to the operating system immediately but only forced
  /// to the disk every [_flushInterval] or after [_flushRecords] writes. That
  /// keeps bulk operations fast while a crash loses at most a fraction of a
  /// second of the newest entries.
  static const Duration _flushInterval = Duration(milliseconds: 500);
  static const int _flushRecords = 64;

  /// Live records keyed by `<kind>/<id>`.
  Map<String, StoreOperation> get records => Map<String, StoreOperation>.unmodifiable(_records);

  File get logFile => File(p.join(_directory.path, 'records.bin'));
  File get manifestFile => File(p.join(_directory.path, 'manifest.json'));
  File get lockFile => File(p.join(_directory.path, 'store.lock'));

  /// Number of records currently held.
  int get length => _records.length;

  Future<void> _load() async {
    _records.clear();
    _frameCounter = 0;
    if (!await logFile.exists()) return;
    final Uint8List bytes = await logFile.readAsBytes();
    int offset = 0;
    final ByteData view = ByteData.sublistView(bytes);
    while (offset + 4 <= bytes.length) {
      final int length = view.getUint32(offset, Endian.big);
      final int start = offset + 4;
      if (length <= 0 || start + length > bytes.length) {
        throw const FormatException('Corrupt store log: bad frame length');
      }
      final List<int> payload = bytes.sublist(start, start + length);
      final List<int> clear = await Crypto.decrypt(
        EncryptedPayload.fromCombined(payload),
        key: _key,
        aad: _aadFor(_frameCounter),
      );
      _frameCounter++;
      final Map<String, dynamic> json =
          jsonDecode(utf8.decode(clear)) as Map<String, dynamic>;
      final StoreOperation op = StoreOperation.fromJson(json);
      if (op.deleted) {
        _records.remove(op.key);
      } else {
        _records[op.key] = op;
      }
      offset = start + length;
    }
  }

  List<int> _aadFor(int index) {
    final Uint8List aad = Uint8List(8);
    ByteData.sublistView(aad).setUint64(0, index, Endian.big);
    return aad;
  }

  Future<RandomAccessFile> _file() async {
    RandomAccessFile? handle = _handle;
    if (handle == null) {
      handle = await logFile.open(mode: FileMode.append);
      _handle = handle;
    }
    return handle;
  }

  /// Inserts or replaces a record and appends it to the encrypted log.
  Future<void> put(RecordKind kind, String id, Map<String, dynamic> data) async {
    final StoreOperation op =
        StoreOperation(kind: kind, id: id, data: data);
    await _append(op);
    _records[op.key] = op;
  }

  /// Removes a record and appends a tombstone to the encrypted log.
  Future<void> delete(RecordKind kind, String id) async {
    final StoreOperation op =
        StoreOperation(kind: kind, id: id, deleted: true);
    await _append(op);
    _records.remove(op.key);
  }

  Future<void> _append(StoreOperation op) async {
    final List<int> clear = utf8.encode(jsonEncode(op.toJson()));
    final EncryptedPayload payload = await Crypto.encrypt(
      clear,
      key: _key,
      aad: _aadFor(_frameCounter),
    );
    final List<int> combined = payload.combined;
    final Uint8List frame = Uint8List(4 + combined.length);
    ByteData.sublistView(frame).setUint32(0, combined.length, Endian.big);
    frame.setRange(4, 4 + combined.length, combined);
    final RandomAccessFile handle = await _file();
    await handle.writeFrom(frame);
    _frameCounter++;
    _pendingWrites++;
    final DateTime now = DateTime.now();
    if (_pendingWrites >= _flushRecords ||
        now.difference(_lastFlush) >= _flushInterval) {
      await handle.flush();
      _pendingWrites = 0;
      _lastFlush = now;
    }
  }

  /// Rewrites the log so that it only contains the live records.
  Future<void> compact() async {
    final List<StoreOperation> live = _records.values.toList(growable: false);
    final File temp = File(p.join(_directory.path, 'records.bin.compact'));
    final RandomAccessFile out = await temp.open(mode: FileMode.writeOnly);
    int index = 0;
    for (final StoreOperation op in live) {
      final List<int> clear = utf8.encode(jsonEncode(op.toJson()));
      final EncryptedPayload payload = await Crypto.encrypt(
        clear,
        key: _key,
        aad: _aadFor(index),
      );
      final List<int> combined = payload.combined;
      final Uint8List frame = Uint8List(4 + combined.length);
      ByteData.sublistView(frame).setUint32(0, combined.length, Endian.big);
      frame.setRange(4, 4 + combined.length, combined);
      await out.writeFrom(frame);
      index++;
    }
    await out.flush();
    await out.close();
    _pendingWrites = 0;
    await _handle?.close();
    _handle = null;
    await temp.rename(logFile.path);
    _frameCounter = index;
  }

  /// Removes every record but keeps the store itself intact.
  Future<void> clear() async {
    _records.clear();
    await _handle?.close();
    _handle = null;
    if (await logFile.exists()) await logFile.delete();
    _frameCounter = 0;
  }

  /// Flushes and releases the file handle.
  ///
  /// Calling it twice is safe.
  Future<void> close() async {
    final RandomAccessFile? handle = _handle;
    _handle = null;
    _pendingWrites = 0;
    if (handle == null) return;
    try {
      await handle.flush();
    } on FileSystemException {
      // The file was already closed or removed.
    }
    try {
      await handle.close();
    } on FileSystemException {
      // The file was already closed.
    }
  }

  /// Number of log frames (including tombstones).
  int get frameCount => _frameCounter;

  /// Salt of this store.
  List<int> get salt => List<int>.unmodifiable(_salt);
}

/// Advisory lock that keeps two writers out of the same working directory.
///
/// The lock combines a POSIX file lock (which excludes other processes) with
/// an in-process registry (because POSIX locks are owned by the process, not
/// by the file descriptor, and would not exclude a second handle of the same
/// process).
class StoreLock {
  StoreLock._(this._handle, this._path);

  static final Set<String> _lockedPaths = <String>{};

  final RandomAccessFile? _handle;
  final String _path;

  /// Tries to acquire the lock without blocking.
  ///
  /// Returns `null` when the directory is already locked.
  static Future<StoreLock?> tryAcquire(Directory directory) async {
    final File file = File(p.join(directory.path, 'store.lock'));
    await file.parent.create(recursive: true);
    if (_lockedPaths.contains(file.path)) return null;
    final RandomAccessFile handle = await file.open(mode: FileMode.writeOnlyAppend);
    try {
      await handle.lock(FileLock.exclusive);
    } on FileSystemException {
      await handle.close();
      return null;
    }
    _lockedPaths.add(file.path);
    return StoreLock._(handle, file.path);
  }

  Future<void> release() async {
    _lockedPaths.remove(_path);
    try {
      await _handle?.unlock();
    } on FileSystemException {
      // The lock is released anyway when the handle closes.
    }
    await _handle?.close();
  }
}
