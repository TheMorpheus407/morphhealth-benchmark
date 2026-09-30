import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'crypto.dart';
import 'ids.dart';

/// Datensätze einer Tabelle: ID -> JSON-Objekt.
typedef Records = Map<String, Map<String, Object?>>;

/// Der gesamte Datenbestand: Tabellenname -> Datensätze.
typedef State = Map<String, Records>;

/// Eine Änderung: Datensatz schreiben ([value] gesetzt) oder löschen.
final class Op {
  final String table;
  final String id;
  final Map<String, Object?>? value;

  const Op.put(this.table, this.id, Map<String, Object?> this.value);
  const Op.delete(this.table, this.id) : value = null;

  bool get isDelete => value == null;

  List<Object?> toJson() => value == null ? ['d', table, id] : ['p', table, id, value];
}

void applyOps(State state, Iterable<Op> ops) {
  for (final op in ops) {
    if (op.value == null) {
      state[op.table]?.remove(op.id);
    } else {
      (state[op.table] ??= {})[op.id] = op.value!;
    }
  }
}

enum StoreErrorCode { wrongKey, corrupt, locked, unsupported, io }

final class StoreException implements Exception {
  final StoreErrorCode code;
  final String message;

  const StoreException(this.code, this.message);

  @override
  String toString() => 'StoreException(${code.name}): $message';
}

/// Dauerhafte Ablage des Datenbestands.
abstract interface class Persistence {
  /// Der geladene Bestand. Nur lesen; Änderungen laufen über [commit].
  State get state;

  /// Schreibt die Änderungen dauerhaft und übernimmt sie in [state].
  Future<void> commit(List<Op> ops);

  /// Ersetzt den gesamten Bestand atomar.
  Future<void> replaceAll(State newState);

  Future<void> close();
}

/// Flüchtige Ablage für Tests. Werte laufen durch JSON, damit nur
/// serialisierbare Daten hineingelangen.
final class MemoryPersistence implements Persistence {
  final State _state = {};

  @override
  State get state => _state;

  @override
  Future<void> commit(List<Op> ops) async {
    applyOps(
      _state,
      ops.map(
        (o) => o.value == null
            ? o
            : Op.put(o.table, o.id, (jsonDecode(jsonEncode(o.value)) as Map).cast<String, Object?>()),
      ),
    );
  }

  @override
  Future<void> replaceAll(State newState) async {
    _state
      ..clear()
      ..addAll(
        (jsonDecode(jsonEncode(newState)) as Map).map(
          (t, r) => MapEntry(
            t as String,
            (r as Map).map((i, v) => MapEntry(i as String, (v as Map).cast<String, Object?>())),
          ),
        ),
      );
  }

  @override
  Future<void> close() async {}
}

const List<int> _snapMagic = [0x4D, 0x48, 0x53, 0x31]; // "MHS1"
const List<int> _jrnMagic = [0x4D, 0x48, 0x4A, 0x31]; // "MHJ1"
const int _headerLength = 4 + 16 + 8 + 16;
const String _kdfInfo = 'MorphHealth/store/v1/aes-256-gcm';
const String _kcvLabel = 'MorphHealth/store/v1/key-check';

/// Verschlüsselte lokale Ablage: ein Snapshot plus ein Journal.
///
/// Der Datenbestand liegt vollständig im Speicher. Jede Änderung wird als
/// einzeln authentifizierter, verschlüsselter Journal-Eintrag angehängt
/// (AES-256-GCM, zufällige Nonce, Sequenznummer in den zusätzlichen
/// authentifizierten Daten). Ab einer Schwelle schreibt der Speicher einen
/// neuen Snapshot (JSON, gzip, AES-256-GCM) mit neuem Salt und beginnt ein
/// leeres Journal. Formate: siehe SECURITY.md.
final class EncryptedStore implements Persistence {
  static const String snapshotName = 'store.mhs';
  static const String journalName = 'store.mhj';
  static const String lockName = 'store.lock';

  /// Journal-Größe, ab der beim nächsten Schreiben ein Snapshot entsteht.
  static const int compactBytes = 512 * 1024;
  static const int compactRecords = 500;

  final Directory dir;
  final Uint8List _masterKey;
  final void Function(String message)? onWarning;

  late final File _snapFile = File('${dir.path}/$snapshotName');
  late final File _jrnFile = File('${dir.path}/$journalName');
  late final File _lockFile = File('${dir.path}/$lockName');

  RandomAccessFile? _lock;
  RandomAccessFile? _journal;
  Uint8List _salt = Uint8List(16);
  Uint8List _dataKey = Uint8List(32);
  Uint8List _kcv = Uint8List(16);
  Uint8List _journalHeader = Uint8List(_headerLength);
  int _seq = 0;
  int _journalBytes = 0;
  int _journalRecords = 0;
  int _snapshotBytes = 0;
  State _state = {};
  bool _closed = false;
  Future<void> _queue = Future.value();

  EncryptedStore._(this.dir, this._masterKey, this.onWarning);

  /// Öffnet (oder legt an) die Ablage in [dir]. [masterKey] sind 32 Byte.
  /// Hält bis [close] eine Sperre auf dem Verzeichnis.
  static Future<EncryptedStore> open(
    Directory dir,
    Uint8List masterKey, {
    Duration lockTimeout = const Duration(seconds: 10),
    void Function(String message)? onWarning,
  }) async {
    if (masterKey.length != 32) {
      throw const StoreException(StoreErrorCode.wrongKey, 'Der Hauptschlüssel muss genau 32 Byte lang sein');
    }
    final store = EncryptedStore._(dir, Uint8List.fromList(masterKey), onWarning);
    try {
      await dir.create(recursive: true);
      await store._acquireLock(lockTimeout);
      await store._load();
    } catch (_) {
      await store._release();
      rethrow;
    }
    return store;
  }

  /// Löscht alle Dateien der Ablage. Die Ablage darf nicht geöffnet sein.
  static Future<void> deleteFiles(Directory dir) async {
    for (final n in [snapshotName, journalName, lockName, '$snapshotName.tmp', '$journalName.tmp']) {
      final f = File('${dir.path}/$n');
      if (await f.exists()) await f.delete();
    }
  }

  @override
  State get state => _state;

  int get sequence => _seq;
  int get snapshotBytes => _snapshotBytes;
  int get journalBytes => _journalBytes;
  int get journalRecords => _journalRecords;

  // -- Sperre ---------------------------------------------------------------

  Future<void> _acquireLock(Duration timeout) async {
    final raf = await _lockFile.open(mode: FileMode.append);
    final deadline = DateTime.now().add(timeout);
    while (true) {
      try {
        await raf.lock(FileLock.exclusive);
        _lock = raf;
        return;
      } on FileSystemException {
        if (DateTime.now().isAfter(deadline)) {
          await raf.close();
          throw const StoreException(
            StoreErrorCode.locked,
            'Das Datenverzeichnis wird von einem anderen Prozess verwendet',
          );
        }
        await Future<void>.delayed(const Duration(milliseconds: 100));
      }
    }
  }

  Future<void> _release() async {
    try {
      await _journal?.close();
    } catch (_) {}
    _journal = null;
    try {
      await _lock?.unlock();
    } catch (_) {}
    try {
      await _lock?.close();
    } catch (_) {}
    _lock = null;
  }

  // -- Laden ----------------------------------------------------------------

  Future<Uint8List> _keyFor(Uint8List salt) => hkdfSha256(_masterKey, salt, _kdfInfo);

  Future<Uint8List> _kcvFor(Uint8List dataKey) async {
    final mac = await hmacSha256(dataKey, Uint8List.fromList(utf8.encode(_kcvLabel)));
    return Uint8List.sublistView(mac, 0, 16);
  }

  Uint8List _header(List<int> magic, Uint8List salt, int seq, Uint8List kcv) {
    final b = BytesBuilder(copy: false)
      ..add(magic)
      ..add(salt)
      ..add(_be64(seq))
      ..add(kcv);
    return b.toBytes();
  }

  Future<void> _load() async {
    final snapExists = await _snapFile.exists();
    if (!snapExists) {
      if (await _jrnFile.exists() && await _jrnFile.length() > 0) {
        throw const StoreException(StoreErrorCode.corrupt, 'Snapshot fehlt, aber ein Journal ist vorhanden');
      }
      _state = {};
      _seq = 0;
      await _writeSnapshot();
      return;
    }
    Uint8List bytes;
    try {
      bytes = await _snapFile.readAsBytes();
    } on FileSystemException catch (e) {
      throw StoreException(StoreErrorCode.io, 'Snapshot nicht lesbar: ${e.message}');
    }
    if (bytes.length < _headerLength + aeadNonceLength + aeadTagLength) {
      throw const StoreException(StoreErrorCode.corrupt, 'Snapshot ist zu kurz');
    }
    if (!_startsWith(bytes, _snapMagic)) {
      throw const StoreException(StoreErrorCode.unsupported, 'Kein MorphHealth-Snapshot (Kennung oder Version)');
    }
    final salt = Uint8List.sublistView(bytes, 4, 20);
    final seq = _readBe64(bytes, 20);
    final kcv = Uint8List.sublistView(bytes, 28, 44);
    final dataKey = await _keyFor(Uint8List.fromList(salt));
    final expected = await _kcvFor(dataKey);
    if (!constantTimeEquals(kcv, expected)) {
      throw const StoreException(StoreErrorCode.wrongKey, 'Der Schlüssel passt nicht zu diesem Datenbestand');
    }
    Uint8List plain;
    try {
      plain = await aeadOpen(
        dataKey,
        Uint8List.sublistView(bytes, _headerLength),
        Uint8List.sublistView(bytes, 0, _headerLength),
      );
    } on CryptoFailure {
      throw const StoreException(StoreErrorCode.corrupt, 'Snapshot ist beschädigt (Authentifizierung fehlgeschlagen)');
    }
    Object? doc;
    try {
      doc = jsonDecode(utf8.decode(gzip.decode(plain)));
    } on Object {
      throw const StoreException(StoreErrorCode.corrupt, 'Snapshot lässt sich nicht entpacken');
    }
    if (doc is! Map || doc['tables'] is! Map) {
      throw const StoreException(StoreErrorCode.corrupt, 'Snapshot hat ein unerwartetes Format');
    }
    _state = _castState(doc['tables'] as Map);
    _seq = seq;
    _salt = Uint8List.fromList(salt);
    _dataKey = dataKey;
    _kcv = Uint8List.fromList(kcv);
    _snapshotBytes = bytes.length;
    await _loadJournal();
  }

  Future<void> _loadJournal() async {
    if (!await _jrnFile.exists()) {
      await _resetJournal();
      return;
    }
    final bytes = await _jrnFile.readAsBytes();
    if (bytes.length < _headerLength) {
      onWarning?.call('Journal war unvollständig und wird neu angelegt');
      await _resetJournal();
      return;
    }
    if (!_startsWith(bytes, _jrnMagic)) {
      throw const StoreException(StoreErrorCode.corrupt, 'Journal hat eine unbekannte Kennung');
    }
    final jsalt = Uint8List.sublistView(bytes, 4, 20);
    if (!constantTimeEquals(jsalt, _salt)) {
      // Ein Snapshot wurde geschrieben, aber das Journal noch nicht ersetzt.
      // Alle Einträge des alten Journals stecken bereits im Snapshot.
      onWarning?.call('Veraltetes Journal verworfen');
      await _resetJournal();
      return;
    }
    final base = _readBe64(bytes, 20);
    if (base != _seq) {
      throw StoreException(StoreErrorCode.corrupt, 'Journal ($base) passt nicht zum Snapshot ($_seq)');
    }
    _journalHeader = Uint8List.fromList(Uint8List.sublistView(bytes, 0, _headerLength));
    var offset = _headerLength;
    var good = offset;
    var records = 0;
    var seq = _seq;
    while (offset + 4 <= bytes.length) {
      final n = _readBe32(bytes, offset);
      if (n < aeadNonceLength + aeadTagLength) {
        // Nach einem Absturz kann das Dateiende mit Nullen aufgefüllt sein.
        if (_allZero(bytes, offset)) break;
        throw const StoreException(StoreErrorCode.corrupt, 'Journal-Eintrag hat eine ungültige Länge');
      }
      final end = offset + 4 + n;
      if (end > bytes.length) break; // abgerissener letzter Eintrag
      final aad = BytesBuilder(copy: false)
        ..add(_journalHeader)
        ..add(_be64(seq + 1));
      Uint8List plain;
      try {
        plain = await aeadOpen(_dataKey, Uint8List.sublistView(bytes, offset + 4, end), aad.toBytes());
      } on CryptoFailure {
        if (end == bytes.length) break; // letzter Eintrag unvollständig geschrieben
        throw StoreException(
          StoreErrorCode.corrupt,
          'Journal-Eintrag ${records + 1} ist beschädigt (Authentifizierung fehlgeschlagen)',
        );
      }
      try {
        final doc = jsonDecode(utf8.decode(plain)) as Map;
        for (final o in (doc['ops'] as List)) {
          final op = o as List;
          final table = op[1] as String;
          final id = op[2] as String;
          if (op[0] == 'd') {
            _state[table]?.remove(id);
          } else {
            (_state[table] ??= {})[id] = (op[3] as Map).cast<String, Object?>();
          }
        }
      } on Object {
        throw StoreException(StoreErrorCode.corrupt, 'Journal-Eintrag ${records + 1} hat ein unerwartetes Format');
      }
      seq++;
      records++;
      offset = end;
      good = end;
    }
    if (good < bytes.length) {
      onWarning?.call('Unvollständiger Journal-Eintrag am Ende verworfen (${bytes.length - good} Byte)');
      final raf = await _jrnFile.open(mode: FileMode.append);
      try {
        await raf.truncate(good);
        await raf.flush();
      } finally {
        await raf.close();
      }
    }
    _seq = seq;
    _journalBytes = good;
    _journalRecords = records;
    _journal = await _jrnFile.open(mode: FileMode.append);
    if (records >= 200 || good > 256 * 1024) {
      await _writeSnapshot();
    }
  }

  // -- Schreiben ------------------------------------------------------------

  Future<T> _serial<T>(Future<T> Function() action) {
    final next = _queue.then((_) => action());
    _queue = next.then<void>((_) {}, onError: (_) {});
    return next;
  }

  @override
  Future<void> commit(List<Op> ops) => _serial(() async {
    if (_closed) throw const StoreException(StoreErrorCode.io, 'Ablage ist geschlossen');
    if (ops.isEmpty) return;
    final payload = utf8.encode(
      jsonEncode({
        'ops': [for (final o in ops) o.toJson()],
      }),
    );
    final seq = _seq + 1;
    final aad = BytesBuilder(copy: false)
      ..add(_journalHeader)
      ..add(_be64(seq));
    final sealed = await aeadSeal(_dataKey, Uint8List.fromList(payload), aad.toBytes());
    final rec = BytesBuilder(copy: false)
      ..add(_be32(sealed.length))
      ..add(sealed);
    final data = rec.toBytes();
    final j = _journal!;
    try {
      await j.writeFrom(data);
      await j.flush();
    } on Object catch (e) {
      try {
        await j.truncate(_journalBytes);
      } catch (_) {}
      throw StoreException(StoreErrorCode.io, 'Schreiben fehlgeschlagen: $e');
    }
    _seq = seq;
    _journalBytes += data.length;
    _journalRecords++;
    applyOps(_state, ops);
    if (_journalBytes > compactBytes || _journalRecords >= compactRecords) {
      try {
        await _writeSnapshot();
      } on Object catch (e) {
        onWarning?.call('Snapshot konnte nicht geschrieben werden: $e');
      }
    }
  });

  @override
  Future<void> replaceAll(State newState) => _serial(() async {
    if (_closed) throw const StoreException(StoreErrorCode.io, 'Ablage ist geschlossen');
    final copy = _castState(jsonDecode(jsonEncode(newState)) as Map);
    final old = _state;
    _state = copy;
    _seq++;
    try {
      await _writeSnapshot();
    } on Object {
      _state = old;
      _seq--;
      rethrow;
    }
  });

  /// Erzwingt einen neuen Snapshot (leeres Journal danach).
  Future<void> compact() => _serial(_writeSnapshot);

  Future<void> _writeSnapshot() async {
    final salt = Uint8List.fromList(randomBytes(16));
    final dataKey = await _keyFor(salt);
    final kcv = await _kcvFor(dataKey);
    final header = _header(_snapMagic, salt, _seq, kcv);
    final doc = {'format': 'morphhealth-store', 'version': 1, 'seq': _seq, 'tables': _state};
    final plain = Uint8List.fromList(gzip.encode(utf8.encode(jsonEncode(doc))));
    final sealed = await aeadSeal(dataKey, plain, header);
    final out = BytesBuilder(copy: false)
      ..add(header)
      ..add(sealed);
    final bytes = out.toBytes();
    final tmp = File('${_snapFile.path}.tmp');
    final raf = await tmp.open(mode: FileMode.write);
    try {
      await raf.writeFrom(bytes);
      await raf.flush();
    } finally {
      await raf.close();
    }
    await tmp.rename(_snapFile.path);
    _salt = salt;
    _dataKey = dataKey;
    _kcv = kcv;
    _snapshotBytes = bytes.length;
    await _resetJournal();
  }

  Future<void> _resetJournal() async {
    await _journal?.close();
    _journal = null;
    _journalHeader = _header(_jrnMagic, _salt, _seq, _kcv);
    final tmp = File('${_jrnFile.path}.tmp');
    final raf = await tmp.open(mode: FileMode.write);
    try {
      await raf.writeFrom(_journalHeader);
      await raf.flush();
    } finally {
      await raf.close();
    }
    await tmp.rename(_jrnFile.path);
    _journalBytes = _headerLength;
    _journalRecords = 0;
    _journal = await _jrnFile.open(mode: FileMode.append);
  }

  @override
  Future<void> close() => _serial(() async {
    if (_closed) return;
    _closed = true;
    await _release();
  });
}

// -- Bytes ------------------------------------------------------------------

State _castState(Map raw) => {
  for (final t in raw.entries)
    t.key as String: {
      for (final r in (t.value as Map).entries) r.key as String: (r.value as Map).cast<String, Object?>(),
    },
};

bool _allZero(Uint8List b, int from) {
  for (var i = from; i < b.length; i++) {
    if (b[i] != 0) return false;
  }
  return true;
}

bool _startsWith(Uint8List b, List<int> magic) {
  if (b.length < magic.length) return false;
  for (var i = 0; i < magic.length; i++) {
    if (b[i] != magic[i]) return false;
  }
  return true;
}

Uint8List _be64(int v) {
  final d = ByteData(8)..setUint64(0, v, Endian.big);
  return d.buffer.asUint8List();
}

Uint8List _be32(int v) {
  final d = ByteData(4)..setUint32(0, v, Endian.big);
  return d.buffer.asUint8List();
}

int _readBe64(Uint8List b, int offset) => ByteData.sublistView(b, offset, offset + 8).getUint64(0, Endian.big);
int _readBe32(Uint8List b, int offset) => ByteData.sublistView(b, offset, offset + 4).getUint32(0, Endian.big);
