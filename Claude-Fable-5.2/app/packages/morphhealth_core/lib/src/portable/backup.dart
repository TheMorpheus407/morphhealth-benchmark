import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../store/crypto.dart';
import '../util/dates.dart';
import '../util/ids.dart';
import '../version.dart';

/// A backup file could not be created or opened.
class BackupException implements Exception {
  /// * `weak_passphrase` – the passphrase is too short.
  /// * `not_a_backup` – the file is not a MorphHealth backup.
  /// * `unsupported` – written by a newer version or with unknown algorithms.
  /// * `wrong_passphrase` – wrong passphrase, or the file was modified.
  /// * `corrupt` – decrypted, but the content cannot be read.
  final String code;
  final String message;

  const BackupException(this.code, this.message);

  @override
  String toString() => 'BackupException($code): $message';
}

/// The readable, unencrypted part of a backup file.
class BackupHeader {
  final int version;
  final LocalDateTime? createdAt;
  final String? appVersion;
  final Argon2Params kdf;

  const BackupHeader(this.version, this.createdAt, this.appVersion, this.kdf);
}

/// Passphrase-protected backup of the complete export document.
///
/// A backup file is a small JSON envelope around an encrypted payload:
///
/// ```json
/// {
///   "format": "morphhealth-backup",
///   "version": 1,
///   "created_at": "2026-11-09T21:14:03+01:00",
///   "app_version": "1.0.0",
///   "kdf": {"algorithm": "argon2id", "version": 19, "memory_kib": 65536,
///           "iterations": 3, "parallelism": 4, "salt": "<base64, 16 bytes>"},
///   "cipher": "xchacha20-poly1305",
///   "compression": "gzip",
///   "data": "<base64 of nonce(24) || ciphertext || tag(16)>"
/// }
/// ```
///
/// The key is derived from the passphrase with Argon2id. The payload is the
/// gzip-compressed export document (`morphhealth-export`). All header members
/// are authenticated together with the payload, so that changing any of them
/// makes the file unreadable.
abstract final class BackupCodec {
  static const String format = 'morphhealth-backup';
  static const int version = 1;
  static const int minPassphraseLength = 8;
  static const String fileExtension = 'mhbackup';
  static const int _saltLength = 16;

  /// Suggested file name, for example `morphhealth-2026-11-09.mhbackup`.
  static String suggestedFileName(Day day) => 'morphhealth-$day.$fileExtension';

  static void checkPassphrase(String passphrase) {
    if (passphrase.length < minPassphraseLength) {
      throw const BackupException(
        'weak_passphrase',
        'The passphrase needs at least $minPassphraseLength characters.',
      );
    }
  }

  /// Encrypts [document] (an export document) with [passphrase] and returns
  /// the bytes of the backup file.
  static Future<Uint8List> seal(
    Map<String, dynamic> document,
    String passphrase, {
    required LocalDateTime createdAt,
    Argon2Params params = Argon2Params.standard,
  }) async {
    checkPassphrase(passphrase);
    final salt = randomBytes(_saltLength);
    final header = <String, dynamic>{
      'format': format,
      'version': version,
      'created_at': createdAt.toIso(),
      'app_version': morphHealthVersion,
      'kdf': {
        'algorithm': 'argon2id',
        'version': 19,
        'memory_kib': params.memoryKib,
        'iterations': params.iterations,
        'parallelism': params.parallelism,
        'salt': base64.encode(salt),
      },
      'cipher': 'xchacha20-poly1305',
      'compression': 'gzip',
    };
    final key = await argon2id(utf8.encode(passphrase), salt, params: params);
    final packed = gzip.encode(utf8.encode(jsonEncode(document)));
    final sealed = Aead.seal(key, packed, aad: _aad(header));
    header['data'] = base64.encode(sealed);
    return Uint8List.fromList(
      utf8.encode(const JsonEncoder.withIndent(' ').convert(header)),
    );
  }

  /// Reads the unencrypted header. Throws [BackupException] if [bytes] are
  /// not a backup this version can read.
  static BackupHeader readHeader(List<int> bytes) => _parse(bytes).header;

  /// Decrypts a backup file and returns the export document it contains.
  static Future<Map<String, dynamic>> open(
    List<int> bytes,
    String passphrase,
  ) async {
    final parsed = _parse(bytes);
    final key = await argon2id(
      utf8.encode(passphrase),
      parsed.salt,
      params: parsed.header.kdf,
    );
    final Uint8List packed;
    try {
      packed = Aead.open(key, parsed.data, aad: _aad(parsed.json));
    } on AuthenticationFailure {
      throw const BackupException(
        'wrong_passphrase',
        'The passphrase does not open this backup (or the file was '
            'modified).',
      );
    }
    try {
      return jsonDecode(utf8.decode(gzip.decode(packed)))
          as Map<String, dynamic>;
    } on Object {
      throw const BackupException(
        'corrupt',
        'The content of the backup cannot be read.',
      );
    }
  }

  static ({
    Map<String, dynamic> json,
    BackupHeader header,
    Uint8List salt,
    Uint8List data,
  })
  _parse(List<int> bytes) {
    const notABackup = BackupException(
      'not_a_backup',
      'The file is not a MorphHealth backup.',
    );
    final Object? decoded;
    try {
      decoded = jsonDecode(utf8.decode(bytes));
    } on FormatException {
      throw notABackup;
    }
    if (decoded is! Map<String, dynamic> || decoded['format'] != format) {
      throw notABackup;
    }
    final v = decoded['version'];
    if (v is! int || v < 1) throw notABackup;
    if (v > version) {
      throw const BackupException(
        'unsupported',
        'The backup was written by a newer version of MorphHealth.',
      );
    }
    final kdf = decoded['kdf'];
    if (kdf is! Map ||
        kdf['algorithm'] != 'argon2id' ||
        kdf['version'] != 19 ||
        decoded['cipher'] != 'xchacha20-poly1305' ||
        decoded['compression'] != 'gzip') {
      throw const BackupException(
        'unsupported',
        'The backup uses algorithms this version does not know.',
      );
    }
    final memory = kdf['memory_kib'];
    final iterations = kdf['iterations'];
    final parallelism = kdf['parallelism'];
    if (memory is! int || iterations is! int || parallelism is! int) {
      throw notABackup;
    }
    final params = Argon2Params(
      memoryKib: memory,
      iterations: iterations,
      parallelism: parallelism,
    );
    if (!params.isAcceptable) {
      throw const BackupException(
        'unsupported',
        'The key derivation parameters of the backup are out of range.',
      );
    }
    final Uint8List salt;
    final Uint8List data;
    try {
      salt = base64.decode(kdf['salt'] as String);
      data = base64.decode(decoded['data'] as String);
    } on Object {
      throw notABackup;
    }
    if (salt.length < 8 || salt.length > 64 || data.length < Aead.overhead) {
      throw notABackup;
    }
    final created = decoded['created_at'];
    final app = decoded['app_version'];
    return (
      json: decoded,
      header: BackupHeader(
        v,
        created is String ? LocalDateTime.tryParse(created) : null,
        app is String ? app : null,
        params,
      ),
      salt: salt,
      data: data,
    );
  }

  /// Canonical bytes of all header members; bound to the payload as
  /// associated data.
  static List<int> _aad(Map<String, dynamic> h) {
    final kdf = h['kdf'] as Map;
    return utf8.encode(
      [
        h['format'],
        h['version'],
        h['created_at'],
        h['app_version'],
        kdf['algorithm'],
        kdf['version'],
        kdf['memory_kib'],
        kdf['iterations'],
        kdf['parallelism'],
        kdf['salt'],
        h['cipher'],
        h['compression'],
      ].join('\n'),
    );
  }
}
