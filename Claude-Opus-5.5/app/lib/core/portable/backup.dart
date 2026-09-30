import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../storage/crypto.dart';
import '../util/clock.dart';

/// Passphrase-protected backup file (`*.mhbackup`), format
/// `morphhealth.backup` version 1.
///
/// The file is a JSON object:
///
/// ```json
/// {
///   "format": "morphhealth.backup", "version": 1,
///   "created_at": "2026-09-23T10:00:00.000Z",
///   "kdf": {"algorithm": "argon2id", "version": 19, "memory_kib": 65536,
///           "iterations": 3, "parallelism": 1, "salt": "<base64>"},
///   "cipher": {"algorithm": "aes-256-gcm"},
///   "compression": "gzip",
///   "payload": "<base64(nonce(12) || ciphertext || tag(16))>"
/// }
/// ```
///
/// The key is Argon2id(passphrase, salt). The plaintext is the gzip
/// compressed UTF-8 JSON of a `morphhealth.portable` document. All header
/// fields except `payload` are authenticated as AES-GCM associated data
/// (their canonical JSON encoding), so parameters cannot be swapped.
class BackupFormat {
  const BackupFormat._();

  static const String formatId = 'morphhealth.backup';
  static const int version = 1;
  static const String fileExtension = 'mhbackup';
  static const int minPassphraseLength = 10;
}

class BackupFormatException implements Exception {
  BackupFormatException(this.message);
  final String message;
  @override
  String toString() => 'BackupFormatException: $message';
}

/// Wrong passphrase or modified/damaged file.
class BackupAuthenticationException implements Exception {
  const BackupAuthenticationException();
  @override
  String toString() => 'Wrong passphrase or damaged backup';
}

Map<String, Object?> _header({
  required String createdAt,
  required Argon2Params params,
  required String salt,
}) => {
  'format': BackupFormat.formatId,
  'version': BackupFormat.version,
  'created_at': createdAt,
  'kdf': {
    'algorithm': 'argon2id',
    'version': 19,
    'memory_kib': params.memoryKib,
    'iterations': params.iterations,
    'parallelism': params.parallelism,
    'salt': salt,
  },
  'cipher': {'algorithm': 'aes-256-gcm'},
  'compression': 'gzip',
};

/// Encrypts a portable document with a passphrase.
Future<Uint8List> createBackup(
  Map<String, Object?> portableDocument,
  String passphrase, {
  required DateTime now,
  Argon2Params params = Argon2Params.standard,
}) async {
  final salt = randomBytes(16);
  final saltText = base64.encode(salt);
  final key = await params.deriveKey(passphrase, salt);
  final header = _header(
    createdAt: formatInstant(now),
    params: params,
    salt: saltText,
  );
  final aad = utf8.encode(jsonEncode(header));
  final plain = gzip.encode(utf8.encode(jsonEncode(portableDocument)));
  final sealed = Aead.seal(key, plain, aad);
  final file = {...header, 'payload': base64.encode(sealed)};
  return Uint8List.fromList(utf8.encode(jsonEncode(file)));
}

/// Decrypts a backup file and returns the contained portable document.
Future<Object?> openBackup(List<int> fileBytes, String passphrase) async {
  Map<String, Object?> file;
  try {
    final decoded = jsonDecode(utf8.decode(fileBytes));
    if (decoded is! Map<String, Object?>) throw const FormatException();
    file = decoded;
  } catch (_) {
    throw BackupFormatException('not a MorphHealth backup file');
  }
  if (file['format'] != BackupFormat.formatId) {
    throw BackupFormatException('not a MorphHealth backup file');
  }
  if (file['version'] != BackupFormat.version) {
    throw BackupFormatException('unsupported backup version ${file['version']}');
  }
  final kdf = file['kdf'];
  final cipher = file['cipher'];
  final createdAt = file['created_at'];
  final payload = file['payload'];
  if (kdf is! Map ||
      cipher is! Map ||
      createdAt is! String ||
      payload is! String ||
      kdf['algorithm'] != 'argon2id' ||
      kdf['version'] != 19 ||
      cipher['algorithm'] != 'aes-256-gcm' ||
      file['compression'] != 'gzip') {
    throw BackupFormatException('unsupported backup parameters');
  }
  final memory = kdf['memory_kib'];
  final iterations = kdf['iterations'];
  final parallelism = kdf['parallelism'];
  final salt = kdf['salt'];
  if (memory is! int || iterations is! int || parallelism is! int || salt is! String) {
    throw BackupFormatException('incomplete key derivation parameters');
  }
  final params = Argon2Params(
    memoryKib: memory,
    iterations: iterations,
    parallelism: parallelism,
  );
  if (!params.isAcceptable) {
    throw BackupFormatException('key derivation parameters out of range');
  }
  Uint8List saltBytes;
  Uint8List sealed;
  try {
    saltBytes = base64.decode(salt);
    sealed = base64.decode(payload);
  } catch (_) {
    throw BackupFormatException('invalid encoding');
  }
  final key = await params.deriveKey(passphrase, saltBytes);
  final aad = utf8.encode(
    jsonEncode(_header(createdAt: createdAt, params: params, salt: salt)),
  );
  Uint8List plain;
  try {
    plain = Aead.open(key, sealed, aad);
  } on AeadAuthenticationException {
    throw const BackupAuthenticationException();
  }
  try {
    return jsonDecode(utf8.decode(gzip.decode(plain)));
  } catch (_) {
    throw BackupFormatException('backup content is unreadable');
  }
}
