import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../util/ids.dart';
import 'crypto.dart';

/// A problem with the persistent data store.
class StoreException implements Exception {
  /// `wrong_key`: the key does not open the stored data (or they were
  /// modified). `corrupt`: files are damaged or incomplete. `io`: the file
  /// system refused an operation. `unsupported`: written by a newer version.
  final String code;
  final String message;

  const StoreException(this.code, this.message);

  @override
  String toString() => 'StoreException($code): $message';
}

/// What a store hands back when it is opened.
class StoredState {
  /// The last complete state, or null if nothing has been stored yet.
  final Map<String, dynamic>? snapshot;

  /// Transactions recorded after [snapshot], oldest first. Each transaction is
  /// a list of operations that were written atomically.
  final List<List<Map<String, dynamic>>> journal;

  /// True if unreadable journal records had to be dropped (not counting an
  /// incomplete last record, which is the normal trace of an interrupted
  /// write).
  final bool journalDamaged;

  const StoredState(this.snapshot, this.journal, {this.journalDamaged = false});
}

/// Persistence for the data set: a full state plus a journal of changes.
abstract class DataStore {
  Future<StoredState> load();

  /// Durably records one transaction (a list of operations).
  Future<void> append(List<Map<String, dynamic>> transaction);

  /// Replaces everything stored so far by [state] and empties the journal.
  Future<void> writeSnapshot(Map<String, dynamic> state);

  /// True when the journal has grown enough to be folded into a snapshot.
  bool get wantsCompaction;

  /// True if another process changed the stored data since the last
  /// [load], [append] or [writeSnapshot] of this instance.
  Future<bool> hasChangedOutside();

  /// Runs [action] while holding the store's inter-process lock.
  Future<T> exclusive<T>(Future<T> Function() action);

  /// Deletes all stored data.
  Future<void> wipe();
}

/// Keeps everything in memory. For tests and previews.
class MemoryDataStore implements DataStore {
  String? _snapshot;
  final List<String> _journal = [];
  final int compactAfter;

  /// Number of snapshot writes, for tests.
  int snapshotWrites = 0;

  MemoryDataStore({this.compactAfter = 64});

  @override
  Future<StoredState> load() async {
    final s = _snapshot;
    return StoredState(
      s == null ? null : jsonDecode(s) as Map<String, dynamic>,
      [
        for (final t in _journal)
          (jsonDecode(t) as List).cast<Map<String, dynamic>>(),
      ],
    );
  }

  @override
  Future<void> append(List<Map<String, dynamic>> transaction) async {
    _journal.add(jsonEncode(transaction));
  }

  @override
  Future<void> writeSnapshot(Map<String, dynamic> state) async {
    _snapshot = jsonEncode(state);
    _journal.clear();
    snapshotWrites++;
  }

  @override
  bool get wantsCompaction => _journal.length >= compactAfter;

  @override
  Future<bool> hasChangedOutside() async => false;

  @override
  Future<T> exclusive<T>(Future<T> Function() action) => action();

  @override
  Future<void> wipe() async {
    _snapshot = null;
    _journal.clear();
  }
}

/// The encrypted on-disk store used by the app and by `mh`.
///
/// Files in the data directory (see SECURITY.md for the exact layout):
///
/// * `morphhealth.snapshot` – the complete state: gzip-compressed JSON,
///   encrypted with XChaCha20-Poly1305.
/// * `morphhealth.journal`  – changes since the snapshot, one encrypted
///   record per transaction, appended and synced on every change.
/// * `morphhealth.lock`     – empty file for the inter-process lock.
///
/// The snapshot is replaced atomically (write to a temporary file, sync,
/// rename). Every snapshot carries a random *generation*; journal records are
/// bound to the generation and to their position, so records of an older
/// snapshot or reordered records are never applied. An incomplete last record
/// (power loss during a write) is detected and dropped.
class EncryptedFileStore implements DataStore {
  static const String snapshotName = 'morphhealth.snapshot';
  static const String journalName = 'morphhealth.journal';
  static const String lockName = 'morphhealth.lock';

  static const String _snapshotMagic = 'MHSNAP1\n';
  static const String _journalMagic = 'MHJRNL1\n';
  static const int _magicLength = 8;
  static const int _generationLength = 16;
  static const int _headerLength = _magicLength + _generationLength;
  static const int _maxRecordLength = 32 * 1024 * 1024;

  /// Journal size after which a new snapshot is due.
  static const int compactAfterRecords = 256;
  static const int compactAfterBytes = 512 * 1024;

  final Directory directory;
  final Uint8List _masterKey;

  Uint8List? _storeKey;
  Uint8List? _generation;
  int _nextSequence = 0;
  int _journalBytes = 0;
  int _journalRecords = 0;

  /// [masterKey] must be 32 bytes. It never leaves this object; the files are
  /// encrypted with a key derived from it for this purpose only.
  EncryptedFileStore(this.directory, List<int> masterKey)
    : _masterKey = Uint8List.fromList(masterKey) {
    if (masterKey.length != 32) {
      throw ArgumentError.value(
        masterKey.length,
        'masterKey',
        'must be exactly 32 bytes',
      );
    }
  }

  File get _snapshotFile => File(_path(snapshotName));
  File get _journalFile => File(_path(journalName));

  String _path(String name) =>
      '${directory.path}${Platform.pathSeparator}$name';

  Future<Uint8List> _key() async => _storeKey ??= await hkdfSha256(
    _masterKey,
    salt: utf8.encode('MorphHealth'),
    info: 'morphhealth/store/v1',
  );

  @override
  Future<StoredState> load() async {
    try {
      await directory.create(recursive: true);
      final key = await _key();
      final snapshotFile = _snapshotFile;
      final journalFile = _journalFile;

      if (!await snapshotFile.exists()) {
        if (await journalFile.exists() && await journalFile.length() > 0) {
          throw const StoreException(
            'corrupt',
            'The journal exists but the snapshot is missing. The data '
                'directory is incomplete.',
          );
        }
        _generation = null;
        _nextSequence = 0;
        _journalBytes = 0;
        _journalRecords = 0;
        return const StoredState(null, []);
      }

      final bytes = await snapshotFile.readAsBytes();
      if (bytes.length < _headerLength + Aead.overhead ||
          latin1.decode(bytes.sublist(0, _magicLength)) != _snapshotMagic) {
        final head = bytes.length >= _magicLength
            ? latin1.decode(bytes.sublist(0, _magicLength))
            : '';
        if (head.startsWith('MHSNAP')) {
          throw const StoreException(
            'unsupported',
            'The data were written by a newer version of MorphHealth.',
          );
        }
        throw const StoreException(
          'corrupt',
          'The snapshot file is not a MorphHealth snapshot.',
        );
      }
      final generation = Uint8List.fromList(
        bytes.sublist(_magicLength, _headerLength),
      );
      final Uint8List packed;
      try {
        packed = Aead.open(
          key,
          Uint8List.sublistView(bytes, _headerLength),
          aad: Uint8List.sublistView(bytes, 0, _headerLength),
        );
      } on AuthenticationFailure {
        throw const StoreException(
          'wrong_key',
          'The key does not open this data directory (wrong key file, or '
              'the stored data were modified).',
        );
      }
      final Map<String, dynamic> snapshot;
      try {
        snapshot =
            jsonDecode(utf8.decode(gzip.decode(packed)))
                as Map<String, dynamic>;
      } on Object {
        throw const StoreException(
          'corrupt',
          'The snapshot content cannot be read.',
        );
      }

      _generation = generation;
      final journal = <List<Map<String, dynamic>>>[];
      var damaged = false;
      _nextSequence = 0;
      _journalBytes = 0;
      _journalRecords = 0;

      if (await journalFile.exists()) {
        final jb = await journalFile.readAsBytes();
        final headerOk =
            jb.length >= _headerLength &&
            latin1.decode(jb.sublist(0, _magicLength)) == _journalMagic &&
            _equal(jb, _magicLength, generation);
        if (!headerOk) {
          // Left over from an older snapshot or from an interrupted start:
          // its content is already part of the snapshot or was never valid.
          _journalBytes = 0;
        } else {
          var offset = _headerLength;
          while (offset < jb.length) {
            if (jb.length - offset < 4) break; // incomplete length field
            final length = ByteData.sublistView(
              jb,
              offset,
              offset + 4,
            ).getUint32(0);
            if (length < Aead.overhead || length > _maxRecordLength) {
              damaged = true;
              break;
            }
            if (offset + 4 + length > jb.length) break; // incomplete record
            final sealed = Uint8List.sublistView(
              jb,
              offset + 4,
              offset + 4 + length,
            );
            final isLast = offset + 4 + length == jb.length;
            try {
              final clear = Aead.open(
                key,
                sealed,
                aad: _journalAad(generation, _nextSequence),
              );
              final tx = (jsonDecode(utf8.decode(clear)) as List)
                  .cast<Map<String, dynamic>>();
              journal.add(tx);
            } on Object {
              if (!isLast) damaged = true;
              break;
            }
            offset += 4 + length;
            _nextSequence++;
          }
          _journalRecords = _nextSequence;
          _journalBytes = offset;
          if (offset < jb.length) {
            if (damaged) {
              await File(_path('$journalName.damaged')).writeAsBytes(jb);
            }
            final raf = await journalFile.open(mode: FileMode.append);
            try {
              await raf.truncate(offset);
              await raf.flush();
            } finally {
              await raf.close();
            }
          }
        }
      }
      return StoredState(snapshot, journal, journalDamaged: damaged);
    } on FileSystemException catch (e) {
      throw StoreException(
        'io',
        'Cannot read the data directory: ${e.message}',
      );
    }
  }

  @override
  Future<void> append(List<Map<String, dynamic>> transaction) async {
    final generation = _generation;
    if (generation == null) {
      throw StateError('append() before the first snapshot was written');
    }
    try {
      final key = await _key();
      final sealed = Aead.seal(
        key,
        utf8.encode(jsonEncode(transaction)),
        aad: _journalAad(generation, _nextSequence),
      );
      final record = BytesBuilder(copy: false);
      if (_journalBytes == 0) {
        record.add(latin1.encode(_journalMagic));
        record.add(generation);
      }
      record.add(
        (ByteData(4)..setUint32(0, sealed.length)).buffer.asUint8List(),
      );
      record.add(sealed);
      final bytes = record.takeBytes();

      final file = _journalFile;
      final RandomAccessFile raf;
      if (_journalBytes == 0) {
        raf = await file.open(mode: FileMode.write);
      } else {
        raf = await file.open(mode: FileMode.append);
        final length = await raf.length();
        if (length != _journalBytes) {
          await raf.close();
          throw const StoreException(
            'io',
            'The journal was changed by another process. Reload before '
                'writing.',
          );
        }
      }
      try {
        await raf.writeFrom(bytes);
        await raf.flush();
      } finally {
        await raf.close();
      }
      _journalBytes += bytes.length;
      _journalRecords++;
      _nextSequence++;
    } on FileSystemException catch (e) {
      throw StoreException('io', 'Cannot write the journal: ${e.message}');
    }
  }

  @override
  Future<void> writeSnapshot(Map<String, dynamic> state) async {
    try {
      await directory.create(recursive: true);
      final key = await _key();
      final generation = Uint8List.fromList(randomBytes(_generationLength));
      final header = Uint8List(_headerLength)
        ..setRange(0, _magicLength, latin1.encode(_snapshotMagic))
        ..setRange(_magicLength, _headerLength, generation);
      final packed = gzip.encode(utf8.encode(jsonEncode(state)));
      final sealed = Aead.seal(key, packed, aad: header);

      final tmp = File(_path('$snapshotName.tmp'));
      final raf = await tmp.open(mode: FileMode.write);
      try {
        await raf.writeFrom(header);
        await raf.writeFrom(sealed);
        await raf.flush();
      } finally {
        await raf.close();
      }
      await tmp.rename(_snapshotFile.path);

      // From here on the old journal is obsolete: its generation no longer
      // matches. Replace it by an empty one.
      final journalTmp = File(_path('$journalName.tmp'));
      await journalTmp.writeAsBytes(const [], flush: true);
      await journalTmp.rename(_journalFile.path);

      _generation = generation;
      _nextSequence = 0;
      _journalBytes = 0;
      _journalRecords = 0;
    } on FileSystemException catch (e) {
      throw StoreException('io', 'Cannot write the snapshot: ${e.message}');
    }
  }

  @override
  bool get wantsCompaction =>
      _journalRecords >= compactAfterRecords ||
      _journalBytes >= compactAfterBytes;

  @override
  Future<bool> hasChangedOutside() async {
    try {
      final snapshotFile = _snapshotFile;
      final known = _generation;
      if (!await snapshotFile.exists()) return known != null;
      if (known == null) return true;
      final raf = await snapshotFile.open();
      try {
        final head = await raf.read(_headerLength);
        if (head.length < _headerLength || !_equal(head, _magicLength, known)) {
          return true;
        }
      } finally {
        await raf.close();
      }
      final journalFile = _journalFile;
      final length = await journalFile.exists()
          ? await journalFile.length()
          : 0;
      return length != _journalBytes;
    } on FileSystemException {
      return true;
    }
  }

  @override
  Future<T> exclusive<T>(Future<T> Function() action) async {
    RandomAccessFile? lock;
    try {
      await directory.create(recursive: true);
      lock = await File(_path(lockName)).open(mode: FileMode.append);
      await lock.lock(FileLock.blockingExclusive);
    } on FileSystemException catch (e) {
      await lock?.close();
      throw StoreException(
        'io',
        'Cannot lock the data directory: ${e.message}',
      );
    }
    try {
      return await action();
    } finally {
      try {
        await lock.unlock();
      } on FileSystemException {
        // Closing the file releases the lock as well.
      }
      await lock.close();
    }
  }

  @override
  Future<void> wipe() async {
    try {
      for (final name in [
        snapshotName,
        journalName,
        '$snapshotName.tmp',
        '$journalName.tmp',
        '$journalName.damaged',
      ]) {
        final f = File(_path(name));
        if (await f.exists()) await f.delete();
      }
      _generation = null;
      _nextSequence = 0;
      _journalBytes = 0;
      _journalRecords = 0;
    } on FileSystemException catch (e) {
      throw StoreException('io', 'Cannot delete the stored data: ${e.message}');
    }
  }

  static Uint8List _journalAad(Uint8List generation, int sequence) {
    final aad = Uint8List(_headerLength + 8);
    aad.setRange(0, _magicLength, latin1.encode(_journalMagic));
    aad.setRange(_magicLength, _headerLength, generation);
    ByteData.sublistView(aad, _headerLength).setUint64(0, sequence);
    return aad;
  }

  static bool _equal(List<int> data, int offset, List<int> expected) {
    if (data.length < offset + expected.length) return false;
    for (var i = 0; i < expected.length; i++) {
      if (data[offset + i] != expected[i]) return false;
    }
    return true;
  }
}
