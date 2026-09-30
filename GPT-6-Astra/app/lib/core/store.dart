import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';
import 'model.dart';

const _iterations = 600000;
const _maxDocumentBytes = 64 * 1024 * 1024;
final _aes = AesGcm.with256bits();
List<int> _randomBytes(int length) {
  final random = Random.secure();
  return List.generate(length, (_) => random.nextInt(256));
}

List<int> _aad(String kind, [Json? kdf, String? compression]) => utf8.encode(
  'morphhealth-encrypted|1|$kind|AES-256-GCM${kdf == null ? '' : '|PBKDF2-HMAC-SHA256|$_iterations|${kdf['salt']}'}${compression == null ? '' : '|compression=$compression'}',
);

/// Incrementally decompresses authenticated snapshot bytes with a strict output
/// bound. Tiny compressed input chunks also bound the decoder's transient output
/// allocation, instead of inflating an entire hostile file before checking size.
/// The optional bound permits focused regression tests without allocating 64 MiB.
List<int> decodeGzipBounded(
  List<int> compressed, {
  int maximumBytes = _maxDocumentBytes,
}) {
  if (maximumBytes < 1) throw ArgumentError.value(maximumBytes, 'maximumBytes');
  final target = _BoundedByteSink(maximumBytes);
  final decoder = gzip.decoder.startChunkedConversion(target);
  try {
    for (var offset = 0; offset < compressed.length; offset += 512) {
      final end = min(offset + 512, compressed.length);
      decoder.add(compressed.sublist(offset, end));
    }
    decoder.close();
    return target.takeBytes();
  } on CoreException {
    rethrow;
  } on FormatException {
    throw const CoreException(
      'encrypted_data_invalid',
      'Invalid compressed snapshot.',
    );
  }
}

class _BoundedByteSink extends ByteConversionSinkBase {
  final int maximumBytes;
  final _bytes = BytesBuilder(copy: false);
  int _length = 0;
  _BoundedByteSink(this.maximumBytes);
  @override
  void add(List<int> chunk) {
    if (_length + chunk.length > maximumBytes) {
      throw const CoreException(
        'document_too_large',
        'Decompressed document exceeds the permitted size.',
      );
    }
    _length += chunk.length;
    // Decoder chunks may reuse their backing buffer; retain an owned copy.
    _bytes.add(Uint8List.fromList(chunk));
  }

  @override
  void close() {}
  Uint8List takeBytes() => _bytes.takeBytes();
}

Future<String> _seal(
  Json document,
  List<int> key, {
  String kind = 'store',
  Json? kdf,
}) async {
  final cleartext = utf8.encode(jsonEncode(document));
  if (cleartext.length > _maxDocumentBytes) {
    throw const CoreException('document_too_large', 'Document exceeds 64 MiB.');
  }
  final compressed = gzip.encode(cleartext);
  final box = await _aes.encrypt(
    compressed,
    secretKey: SecretKey(key),
    nonce: _randomBytes(12),
    aad: _aad(kind, kdf, 'gzip'),
  );
  return jsonEncode({
    'format': 'morphhealth-encrypted',
    'version': 1,
    'kind': kind,
    'cipher': 'AES-256-GCM',
    'compression': 'gzip',
    'kdf': ?kdf,
    'nonce': base64Encode(box.nonce),
    'ciphertext': base64Encode(box.cipherText),
    'mac': base64Encode(box.mac.bytes),
  });
}

Json _envelope(String text, String kind) {
  if (text.length > 100 * 1024 * 1024) {
    throw const CoreException(
      'encrypted_data_invalid',
      'Encrypted file exceeds 100 MiB.',
    );
  }
  dynamic raw;
  try {
    raw = jsonDecode(text);
  } on FormatException {
    throw const CoreException(
      'encrypted_data_invalid',
      'Invalid encrypted JSON envelope.',
    );
  }
  if (raw is! Map ||
      raw['format'] != 'morphhealth-encrypted' ||
      raw['version'] != 1 ||
      raw['kind'] != kind ||
      raw['cipher'] != 'AES-256-GCM') {
    throw const CoreException(
      'encrypted_data_invalid',
      'Unsupported encrypted file format, kind or version.',
    );
  }
  final e = Map<String, dynamic>.from(raw);
  final allowed = [
    'format',
    'version',
    'kind',
    'cipher',
    'compression',
    'nonce',
    'ciphertext',
    'mac',
    if (kind == 'backup') 'kdf',
  ];
  if (e.keys.any((k) => !allowed.contains(k))) {
    throw const CoreException(
      'encrypted_data_invalid',
      'Unexpected encrypted header field.',
    );
  }
  if (e.containsKey('compression') && e['compression'] != 'gzip') {
    throw const CoreException(
      'encrypted_data_invalid',
      'Unsupported compression.',
    );
  }
  return e;
}

List<int> _decodeBytes(dynamic field, {int? length}) {
  try {
    if (field is! String) throw const FormatException();
    final bytes = base64Decode(field);
    if (length != null && bytes.length != length) throw const FormatException();
    return bytes;
  } on FormatException {
    throw const CoreException(
      'encrypted_data_invalid',
      'Invalid encrypted byte field.',
    );
  }
}

Future<Json> _unseal(Json e, List<int> key, {Json? kdf}) async {
  final box = SecretBox(
    _decodeBytes(e['ciphertext']),
    nonce: _decodeBytes(e['nonce'], length: 12),
    mac: Mac(_decodeBytes(e['mac'], length: 16)),
  );
  List<int> cleartext;
  try {
    cleartext = await _aes.decrypt(
      box,
      secretKey: SecretKey(key),
      aad: _aad(e['kind'] as String, kdf, e['compression'] as String?),
    );
  } on SecretBoxAuthenticationError {
    throw const CoreException(
      'authentication_failed',
      'Incorrect key/passphrase or damaged encrypted file.',
    );
  }
  if (e['compression'] == 'gzip') {
    cleartext = decodeGzipBounded(cleartext);
  }
  if (cleartext.length > _maxDocumentBytes) {
    throw const CoreException('document_too_large', 'Document exceeds 64 MiB.');
  }
  try {
    return validateDocument(jsonDecode(utf8.decode(cleartext)));
  } on FormatException {
    throw const CoreException(
      'encrypted_data_invalid',
      'Decrypted content is not valid JSON.',
    );
  }
}

void _passphrase(String passphrase) {
  if (passphrase.length < 10 || passphrase.length > 1024) {
    throw const CoreException(
      'invalid_passphrase',
      'Passphrase requires 10–1024 characters.',
    );
  }
}

Future<List<int>> _derive(String passphrase, List<int> salt) async {
  final kdf = Pbkdf2(
    macAlgorithm: Hmac.sha256(),
    iterations: _iterations,
    bits: 256,
  );
  final key = await kdf.deriveKey(
    secretKey: SecretKey(utf8.encode(passphrase)),
    nonce: salt,
  );
  return key.extractBytes();
}

Future<String> encryptBackup(Json document, String passphrase) async {
  _passphrase(passphrase);
  final validated = validateDocument(document);
  return Isolate.run(() async {
    final salt = _randomBytes(16);
    final key = await _derive(passphrase, salt);
    return _seal(
      validated,
      key,
      kind: 'backup',
      kdf: {
        'name': 'PBKDF2-HMAC-SHA256',
        'iterations': _iterations,
        'salt': base64Encode(salt),
      },
    );
  });
}

Future<Json> decryptBackup(String envelope, String passphrase) async {
  _passphrase(passphrase);
  return Isolate.run(() async {
    final e = _envelope(envelope, 'backup');
    final raw = e['kdf'];
    if (raw is! Map ||
        raw['name'] != 'PBKDF2-HMAC-SHA256' ||
        raw['iterations'] != _iterations ||
        raw.keys.any((k) => !['name', 'iterations', 'salt'].contains(k))) {
      throw const CoreException(
        'encrypted_data_invalid',
        'Unsupported backup key derivation.',
      );
    }
    final kdf = Map<String, dynamic>.from(raw);
    final key = await _derive(
      passphrase,
      _decodeBytes(kdf['salt'], length: 16),
    );
    return _unseal(e, key, kdf: kdf);
  });
}

class Store {
  final Directory dir;
  final List<int> _key;
  Json _document = emptyDocument();
  Json get document => _document;
  Future<void> _pending = Future<void>.value();
  RandomAccessFile? _lock;
  bool _opened = false;
  bool _closed = false;
  Store(this.dir, List<int> key) : _key = List<int>.of(key) {
    if (key.length != 32 || key.any((v) => v < 0 || v > 255)) {
      throw const CoreException(
        'invalid_key',
        'Storage key must contain exactly 32 raw bytes.',
      );
    }
  }
  File get _file => File('${dir.path}/health.mhenc');

  Future<void> open() async {
    if (_opened) return;
    if (_closed) throw const CoreException('store_closed', 'Store is closed.');
    await dir.create(recursive: true);
    final lock = await File('${dir.path}/.lock').open(mode: FileMode.append);
    try {
      // Cooperative process lock: two CLI writers must never overwrite one
      // another's committed snapshot. This is not a network/server interface.
      await lock.lock(FileLock.exclusive);
      _lock = lock;
      if (await _file.exists()) {
        if (await _file.length() > 100 * 1024 * 1024) {
          throw const CoreException(
            'encrypted_data_invalid',
            'Local encrypted file exceeds 100 MiB.',
          );
        }
        final text = await _file.readAsString();
        final key = _key;
        _document = await Isolate.run(
          () => _unseal(_envelope(text, 'store'), key),
        );
        validatePeriodOverlaps(_document['periods'] as List);
      } else {
        await _save(_document);
      }
      // A crash before rename may leave ciphertext. Never adopt an uncommitted
      // temporary state; authenticated committed data stays authoritative.
      final temp = File('${dir.path}/health.mhenc.pending');
      if (await temp.exists()) await temp.delete();
      _opened = true;
    } catch (_) {
      await lock.close();
      _lock = null;
      rethrow;
    }
  }

  Future<void> _save(Json next) async {
    final key = _key;
    final encrypted = await Isolate.run(() => _seal(next, key));
    final temp = File('${dir.path}/health.mhenc.pending');
    await temp.writeAsString(encrypted, flush: true);
    await temp.rename(_file.path); // atomic replacement on Linux and Android
  }

  Future<void> _mutate(Json Function(Json) action) {
    if (!_opened || _closed) {
      return Future.error(
        const CoreException('store_closed', 'Open the store before use.'),
      );
    }
    final operation = _pending.then((_) async {
      final next = action(_document);
      await _save(next);
      _document = next; // State only advances after the atomic disk commit.
    });
    _pending = operation.then<void>(
      (_) {},
      onError: (Object _, StackTrace _) {},
    );
    return operation;
  }

  Future<void> put(String collection, Json item) {
    final valid = validateItem(collection, item);
    return _mutate((current) {
      final list = List<Json>.from(current[collection] as List);
      final index = list.indexWhere((e) => e['id'] == valid['id']);
      if (index < 0) {
        list.add(valid);
      } else {
        list[index] = valid;
      }
      if (collection == 'periods') validatePeriodOverlaps(list);
      final total = collections.fold<int>(
        0,
        (count, c) =>
            count +
            (c == collection ? list.length : (current[c] as List).length),
      );
      if (total > 100000) {
        throw const CoreException(
          'document_too_large',
          'Maximum 100000 records per document.',
        );
      }
      return {...current, collection: list};
    });
  }

  Future<void> remove(String collection, String id) {
    if (!collections.contains(collection)) {
      throw const CoreException('invalid_collection', 'Unknown collection.');
    }
    return _mutate(
      (current) => {
        ...current,
        collection: (current[collection] as List)
            .where((e) => e['id'] != id)
            .toList(),
      },
    );
  }

  Future<void> updateSettings(Json settings) => _mutate((current) {
    final previous = current['settings'] as Json;
    final merged = {...previous, ...settings};
    for (final key in ['goals', 'visible']) {
      if (settings[key] is Map) {
        merged[key] = {...(previous[key] as Map), ...(settings[key] as Map)};
      }
    }
    return {...current, 'settings': validateSettings(merged)};
  });

  Future<void> replace(Json doc) {
    final valid = validateDocument(doc);
    validatePeriodOverlaps(valid['periods'] as List);
    return _mutate((_) => valid);
  }

  Future<void> clear() => _mutate((_) => emptyDocument());

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _pending;
    if (_lock != null) {
      await _lock!.unlock();
      await _lock!.close();
      _lock = null;
    }
    for (var i = 0; i < _key.length; i++) {
      _key[i] = 0;
    }
  }
}
