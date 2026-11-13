/// Cryptographic primitives for local health vault encryption at rest
/// and passphrase-protected portable backups.
///
/// - Local Vault: 32-byte master key -> HKDF-SHA256 -> ChaCha20-Poly1305 (RFC 8439)
///   over gzip-compressed snapshots (`vault.mhv1`) + authenticated WAL frames (`vault.wal.mhv1`).
/// - Encrypted Backups: User passphrase -> Argon2id (RFC 9106) -> ChaCha20-Poly1305
///   over gzip-compressed portable JSON documents.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

class VaultSecurityException implements Exception {
  final String code;
  final String message;

  const VaultSecurityException(this.code, this.message);

  @override
  String toString() => 'VaultSecurityException($code): $message';
}

class DecryptedSnapshot {
  final Uint8List epochId;
  final Uint8List salt;
  final Map<String, dynamic> payload;

  const DecryptedSnapshot({
    required this.epochId,
    required this.salt,
    required this.payload,
  });
}

class VaultCrypto {
  static const String snapshotMagic = 'MHVAULT1';
  static const String walMagic = 'MHWAL001';
  static const int formatVersion = 1;
  static const int masterKeyLength = 32;

  static final Chacha20 _aead = Chacha20.poly1305Aead();
  static final Hkdf _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);

  static void validateMasterKey(Uint8List masterKey) {
    if (masterKey.length != masterKeyLength) {
      throw VaultSecurityException(
        'INVALID_KEY_LENGTH',
        'Master key must be exactly $masterKeyLength raw bytes (got ${masterKey.length}).',
      );
    }
  }

  static Uint8List randomBytes(int length) {
    final rng = Random.secure();
    final out = Uint8List(length);
    for (var i = 0; i < length; i++) {
      out[i] = rng.nextInt(256);
    }
    return out;
  }

  static Future<SecretKey> deriveSnapshotKey(
    Uint8List masterKey,
    Uint8List salt,
  ) async {
    validateMasterKey(masterKey);
    return _hkdf.deriveKey(
      secretKey: SecretKey(masterKey),
      nonce: salt,
      info: utf8.encode('morphhealth.vault.snapshot.v1'),
    );
  }

  static Future<SecretKey> deriveWalKey(
    Uint8List masterKey,
    Uint8List salt,
  ) async {
    validateMasterKey(masterKey);
    return _hkdf.deriveKey(
      secretKey: SecretKey(masterKey),
      nonce: salt,
      info: utf8.encode('morphhealth.vault.wal.v1'),
    );
  }

  static Future<Uint8List> encryptSnapshot({
    required Uint8List masterKey,
    required Uint8List epochId,
    required Uint8List salt,
    required Map<String, dynamic> payload,
  }) async {
    validateMasterKey(masterKey);
    if (epochId.length != 16 || salt.length != 16) {
      throw const VaultSecurityException(
        'INVALID_VAULT_PARAMS',
        'Epoch ID and HKDF salt must be 16 bytes each.',
      );
    }
    final key = await deriveSnapshotKey(masterKey, salt);
    final nonce = randomBytes(12);

    final header = BytesBuilder(copy: false)
      ..add(ascii.encode(snapshotMagic))
      ..addByte(formatVersion)
      ..add(epochId)
      ..add(salt)
      ..add(nonce);
    final headerBytes = header.toBytes(); // 8 + 1 + 16 + 16 + 12 = 53 bytes

    final jsonBytes = utf8.encode(jsonEncode(payload));
    final compressed = gzip.encode(jsonBytes);

    final box = await _aead.encrypt(
      compressed,
      secretKey: key,
      nonce: nonce,
      aad: headerBytes,
    );

    final out = BytesBuilder(copy: false)
      ..add(headerBytes)
      ..add(box.mac.bytes)
      ..add(box.cipherText);
    return out.toBytes();
  }

  static Future<DecryptedSnapshot> decryptSnapshot({
    required Uint8List masterKey,
    required Uint8List fileBytes,
  }) async {
    validateMasterKey(masterKey);
    // Minimum size: 53 header + 16 MAC = 69 bytes
    if (fileBytes.length < 69) {
      throw const VaultSecurityException(
        'CORRUPT_VAULT',
        'Vault snapshot file is truncated or malformed.',
      );
    }
    final magic = ascii.decode(fileBytes.sublist(0, 8), allowInvalid: true);
    if (magic != snapshotMagic) {
      throw const VaultSecurityException(
        'INVALID_VAULT_MAGIC',
        'File is not a valid MorphHealth encrypted vault snapshot.',
      );
    }
    final version = fileBytes[8];
    if (version != formatVersion) {
      throw VaultSecurityException(
        'UNSUPPORTED_VAULT_VERSION',
        'Unsupported vault format version: $version.',
      );
    }
    final epochId = Uint8List.fromList(fileBytes.sublist(9, 25));
    final salt = Uint8List.fromList(fileBytes.sublist(25, 41));
    final nonce = Uint8List.fromList(fileBytes.sublist(41, 53));
    final headerBytes = Uint8List.sublistView(fileBytes, 0, 53);
    final macBytes = Uint8List.sublistView(fileBytes, 53, 69);
    final cipherText = Uint8List.sublistView(fileBytes, 69);

    final key = await deriveSnapshotKey(masterKey, salt);
    List<int> compressed;
    try {
      compressed = await _aead.decrypt(
        SecretBox(cipherText, nonce: nonce, mac: Mac(macBytes)),
        secretKey: key,
        aad: headerBytes,
      );
    } on SecretBoxAuthenticationError {
      throw const VaultSecurityException(
        'AUTH_FAILED',
        'Vault authentication failed (wrong key or tampered vault file).',
      );
    }

    try {
      final jsonBytes = gzip.decode(compressed);
      final decoded = jsonDecode(utf8.decode(jsonBytes));
      if (decoded is! Map<String, dynamic>) {
        throw const VaultSecurityException(
          'CORRUPT_PAYLOAD',
          'Decrypted vault payload is not a JSON object.',
        );
      }
      return DecryptedSnapshot(
        epochId: epochId,
        salt: salt,
        payload: decoded,
      );
    } catch (e) {
      if (e is VaultSecurityException) rethrow;
      throw VaultSecurityException(
        'CORRUPT_PAYLOAD',
        'Failed to decode decrypted vault snapshot: $e',
      );
    }
  }

  static Uint8List buildWalHeader(Uint8List epochId) {
    final b = BytesBuilder(copy: false)
      ..add(ascii.encode(walMagic))
      ..addByte(formatVersion)
      ..add(epochId);
    return b.toBytes(); // 25 bytes
  }

  static Future<Uint8List> encryptWalFrame({
    required SecretKey walKey,
    required Uint8List epochId,
    required int sequence,
    required Map<String, dynamic> deltaOp,
  }) async {
    final nonce = randomBytes(12);
    final seqBytes = ByteData(8)..setUint64(0, sequence, Endian.big);
    final aad = BytesBuilder(copy: false)
      ..add(ascii.encode(walMagic))
      ..addByte(formatVersion)
      ..add(epochId)
      ..add(seqBytes.buffer.asUint8List())
      ..add(nonce);
    final aadBytes = aad.toBytes();

    final plain = utf8.encode(jsonEncode(deltaOp));
    final box = await _aead.encrypt(
      plain,
      secretKey: walKey,
      nonce: nonce,
      aad: aadBytes,
    );

    final lenBytes = ByteData(4)
      ..setUint32(0, box.cipherText.length, Endian.big);
    final frame = BytesBuilder(copy: false)
      ..add(lenBytes.buffer.asUint8List())
      ..add(seqBytes.buffer.asUint8List())
      ..add(nonce)
      ..add(box.mac.bytes)
      ..add(box.cipherText);
    return frame.toBytes();
  }

  static Future<List<Map<String, dynamic>>> decryptWalFile({
    required SecretKey walKey,
    required Uint8List expectedEpochId,
    required Uint8List fileBytes,
  }) async {
    if (fileBytes.isEmpty) return const [];
    if (fileBytes.length < 25) {
      throw const VaultSecurityException(
        'CORRUPT_WAL',
        'WAL journal header is truncated.',
      );
    }
    final magic = ascii.decode(fileBytes.sublist(0, 8), allowInvalid: true);
    if (magic != walMagic || fileBytes[8] != formatVersion) {
      throw const VaultSecurityException(
        'CORRUPT_WAL',
        'Invalid WAL journal magic or version.',
      );
    }
    for (var i = 0; i < 16; i++) {
      if (fileBytes[9 + i] != expectedEpochId[i]) {
        // Stale WAL from an older epoch (e.g. crash right after snapshot rename before WAL cleanup)
        return const [];
      }
    }

    final ops = <Map<String, dynamic>>[];
    var offset = 25;
    var expectedSeq = 1;
    while (offset < fileBytes.length) {
      // Frame header: 4 len + 8 seq + 12 nonce + 16 mac = 40 bytes
      if (offset + 40 > fileBytes.length) {
        throw const VaultSecurityException(
          'CORRUPT_WAL',
          'Truncated WAL frame header.',
        );
      }
      final bd = ByteData.sublistView(fileBytes, offset, offset + 12);
      final cipherLen = bd.getUint32(0, Endian.big);
      final seq = bd.getUint64(4, Endian.big);
      if (seq != expectedSeq) {
        throw VaultSecurityException(
          'WAL_SEQUENCE_MISMATCH',
          'Expected WAL frame sequence $expectedSeq, found $seq.',
        );
      }
      final endOffset = offset + 40 + cipherLen;
      if (endOffset > fileBytes.length) {
        throw const VaultSecurityException(
          'CORRUPT_WAL',
          'Truncated WAL frame ciphertext.',
        );
      }
      final nonce = Uint8List.sublistView(fileBytes, offset + 12, offset + 24);
      final mac = Uint8List.sublistView(fileBytes, offset + 24, offset + 40);
      final cipher = Uint8List.sublistView(fileBytes, offset + 40, endOffset);
      final seqRaw = Uint8List.sublistView(fileBytes, offset + 4, offset + 12);

      final aad = BytesBuilder(copy: false)
        ..add(ascii.encode(walMagic))
        ..addByte(formatVersion)
        ..add(expectedEpochId)
        ..add(seqRaw)
        ..add(nonce);

      List<int> plain;
      try {
        plain = await _aead.decrypt(
          SecretBox(cipher, nonce: nonce, mac: Mac(mac)),
          secretKey: walKey,
          aad: aad.toBytes(),
        );
      } on SecretBoxAuthenticationError {
        throw const VaultSecurityException(
          'WAL_AUTH_FAILED',
          'WAL frame authentication failed.',
        );
      }

      final obj = jsonDecode(utf8.decode(plain));
      if (obj is! Map<String, dynamic>) {
        throw const VaultSecurityException(
          'CORRUPT_WAL',
          'Invalid WAL operation payload.',
        );
      }
      ops.add(obj);
      offset = endOffset;
      expectedSeq++;
    }
    return ops;
  }
}

class EncryptedBackupCodec {
  static const String backupFormat = 'morphhealth.encrypted-backup';
  static const int schemaVersion = 1;

  // Argon2id parameters: 32 MiB memory, 2 lanes, 3 iterations, 256-bit output
  static const int defaultMemoryKiB = 32768;
  static const int defaultParallelism = 2;
  static const int defaultIterations = 3;

  static final Chacha20 _aead = Chacha20.poly1305Aead();

  static Future<String> createEncryptedBackup({
    required String passphrase,
    required Map<String, dynamic> portableDocument,
    required String createdAtRfc3339,
    int memoryKiB = defaultMemoryKiB,
    int parallelism = defaultParallelism,
    int iterations = defaultIterations,
  }) async {
    if (passphrase.isEmpty) {
      throw const VaultSecurityException(
        'EMPTY_PASSPHRASE',
        'A non-empty passphrase is required for encrypted backups.',
      );
    }
    final salt = VaultCrypto.randomBytes(16);
    final nonce = VaultCrypto.randomBytes(12);

    final kdf = Argon2id(
      memory: memoryKiB,
      parallelism: parallelism,
      iterations: iterations,
      hashLength: 32,
    );
    final secretKey = await kdf.deriveKeyFromPassword(
      password: passphrase,
      nonce: salt,
    );

    final saltB64 = base64Encode(salt);
    final nonceB64 = base64Encode(nonce);
    final aadString =
        '$backupFormat|v$schemaVersion|Argon2id|$memoryKiB|$parallelism|$iterations|$saltB64|$nonceB64';

    final plainJson = utf8.encode(jsonEncode(portableDocument));
    final compressed = gzip.encode(plainJson);

    final box = await _aead.encrypt(
      compressed,
      secretKey: secretKey,
      nonce: nonce,
      aad: utf8.encode(aadString),
    );

    final envelope = <String, dynamic>{
      'format': backupFormat,
      'schema_version': schemaVersion,
      'created_at': createdAtRfc3339,
      'kdf': {
        'algorithm': 'Argon2id',
        'memory_kib': memoryKiB,
        'parallelism': parallelism,
        'iterations': iterations,
        'salt_b64': saltB64,
      },
      'cipher': {
        'algorithm': 'ChaCha20-Poly1305',
        'compression': 'gzip',
        'nonce_b64': nonceB64,
        'tag_b64': base64Encode(box.mac.bytes),
      },
      'ciphertext_b64': base64Encode(box.cipherText),
    };
    return const JsonEncoder.withIndent('  ').convert(envelope);
  }

  static Future<Map<String, dynamic>> decryptEncryptedBackup({
    required String passphrase,
    required String backupJsonText,
  }) async {
    if (passphrase.isEmpty) {
      throw const VaultSecurityException(
        'EMPTY_PASSPHRASE',
        'Passphrase cannot be empty.',
      );
    }
    dynamic parsed;
    try {
      parsed = jsonDecode(backupJsonText);
    } catch (_) {
      throw const VaultSecurityException(
        'INVALID_BACKUP_FORMAT',
        'Backup file is not valid JSON.',
      );
    }
    if (parsed is! Map<String, dynamic> ||
        parsed['format'] != backupFormat ||
        parsed['schema_version'] != schemaVersion) {
      throw const VaultSecurityException(
        'INVALID_BACKUP_FORMAT',
        'Unsupported or unrecognized MorphHealth encrypted backup envelope.',
      );
    }

    final kdfMap = parsed['kdf'];
    final cipherMap = parsed['cipher'];
    final ciphertextB64 = parsed['ciphertext_b64'];
    if (kdfMap is! Map<String, dynamic> ||
        cipherMap is! Map<String, dynamic> ||
        ciphertextB64 is! String) {
      throw const VaultSecurityException(
        'INVALID_BACKUP_FORMAT',
        'Encrypted backup envelope is missing required cryptographic fields.',
      );
    }

    if (kdfMap['algorithm'] != 'Argon2id' ||
        cipherMap['algorithm'] != 'ChaCha20-Poly1305') {
      throw const VaultSecurityException(
        'UNSUPPORTED_CRYPTO_SUITE',
        'Unsupported KDF or AEAD algorithm in backup file.',
      );
    }

    final memoryKiB = kdfMap['memory_kib'];
    final parallelism = kdfMap['parallelism'];
    final iterations = kdfMap['iterations'];
    final saltB64 = kdfMap['salt_b64'];
    final nonceB64 = cipherMap['nonce_b64'];
    final tagB64 = cipherMap['tag_b64'];

    if (memoryKiB is! int ||
        memoryKiB < 1024 ||
        memoryKiB > 524288 ||
        parallelism is! int ||
        parallelism < 1 ||
        parallelism > 16 ||
        iterations is! int ||
        iterations < 1 ||
        iterations > 32 ||
        saltB64 is! String ||
        nonceB64 is! String ||
        tagB64 is! String) {
      throw const VaultSecurityException(
        'INVALID_BACKUP_PARAMS',
        'Invalid or out-of-bounds KDF parameters in backup file.',
      );
    }

    late final Uint8List salt;
    late final Uint8List nonce;
    late final Uint8List tag;
    late final Uint8List cipherBytes;
    try {
      salt = base64Decode(saltB64);
      nonce = base64Decode(nonceB64);
      tag = base64Decode(tagB64);
      cipherBytes = base64Decode(ciphertextB64);
    } catch (_) {
      throw const VaultSecurityException(
        'INVALID_BACKUP_ENCODING',
        'Corrupted base64 data in backup file.',
      );
    }
    if (salt.length != 16 || nonce.length != 12 || tag.length != 16) {
      throw const VaultSecurityException(
        'INVALID_BACKUP_PARAMS',
        'Invalid salt, nonce, or authentication tag length.',
      );
    }

    final kdf = Argon2id(
      memory: memoryKiB,
      parallelism: parallelism,
      iterations: iterations,
      hashLength: 32,
    );
    final secretKey = await kdf.deriveKeyFromPassword(
      password: passphrase,
      nonce: salt,
    );

    final aadString =
        '$backupFormat|v$schemaVersion|Argon2id|$memoryKiB|$parallelism|$iterations|$saltB64|$nonceB64';

    List<int> compressed;
    try {
      compressed = await _aead.decrypt(
        SecretBox(cipherBytes, nonce: nonce, mac: Mac(tag)),
        secretKey: secretKey,
        aad: utf8.encode(aadString),
      );
    } on SecretBoxAuthenticationError {
      throw const VaultSecurityException(
        'WRONG_PASSPHRASE_OR_CORRUPT',
        'Decryption failed: wrong passphrase or tampered backup file.',
      );
    }

    try {
      final plainBytes = gzip.decode(compressed);
      final doc = jsonDecode(utf8.decode(plainBytes));
      if (doc is! Map<String, dynamic>) {
        throw const VaultSecurityException(
          'CORRUPT_BACKUP_DOCUMENT',
          'Decrypted backup payload is not a JSON object.',
        );
      }
      return doc;
    } catch (e) {
      if (e is VaultSecurityException) rethrow;
      throw VaultSecurityException(
        'CORRUPT_BACKUP_DOCUMENT',
        'Failed to decode backup payload: $e',
      );
    }
  }
}
