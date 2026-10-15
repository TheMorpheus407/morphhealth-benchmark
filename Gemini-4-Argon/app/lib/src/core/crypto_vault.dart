import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'package:cryptography/cryptography.dart';

class VaultCryptoException implements Exception {
  final String code;
  final String message;

  const VaultCryptoException(this.code, this.message);

  @override
  String toString() => 'VaultCryptoException($code): $message';
}

class CryptoVault {
  static const List<int> _magic = [0x4D, 0x48, 0x56, 0x31]; // "MHV1"
  static const int _version = 0x01;
  static const int _flagGzip = 0x01;
  static const String backupFormatId = 'morphhealth.encrypted_backup.v1';
  static const int pbkdf2Iterations = 100000;

  static final AesGcm _aesGcm = AesGcm.with256bits();

  static Uint8List generateRandomBytes(int length) {
    final rng = Random.secure();
    final out = Uint8List(length);
    for (int i = 0; i < length; i++) {
      out[i] = rng.nextInt(256);
    }
    return out;
  }

  /// Validates that [keyFilePath] lies outside [dataDirPath] and loads (or
  /// initializes if [createIfMissing] is true) the 32 raw key bytes.
  static Uint8List loadOrCreateMasterKey({
    required String dataDirPath,
    required String keyFilePath,
    bool createIfMissing = true,
  }) {
    final absDataDir = Directory(dataDirPath).absolute.path;
    final absKeyFile = File(keyFilePath).absolute.path;

    final normDataPrefix =
        absDataDir.endsWith(Platform.pathSeparator)
            ? absDataDir
            : '$absDataDir${Platform.pathSeparator}';
    if (absKeyFile == absDataDir || absKeyFile.startsWith(normDataPrefix)) {
      throw const VaultCryptoException(
        'key_inside_data_dir',
        'Key file must be located outside data-dir.',
      );
    }

    final keyFile = File(absKeyFile);
    if (!keyFile.existsSync()) {
      if (!createIfMissing) {
        throw VaultCryptoException(
          'key_file_missing',
          'Key file does not exist: $absKeyFile',
        );
      }
      keyFile.parent.createSync(recursive: true);
      final keyBytes = generateRandomBytes(32);
      keyFile.writeAsBytesSync(keyBytes, flush: true);
      return keyBytes;
    }

    final bytes = keyFile.readAsBytesSync();
    if (bytes.length != 32) {
      throw VaultCryptoException(
        'invalid_key_length',
        'Key file must contain exactly 32 raw bytes (found ${bytes.length} bytes).',
      );
    }
    return Uint8List.fromList(bytes);
  }

  /// Encrypts a JSON map using AES-256-GCM (with gzip compression) into the
  /// binary `MHV1` vault format.
  static Future<Uint8List> encryptVaultPayload(
    Map<String, dynamic> payload,
    Uint8List masterKey32,
  ) async {
    if (masterKey32.length != 32) {
      throw const VaultCryptoException(
        'invalid_key_length',
        'Master key must be 32 bytes.',
      );
    }
    final jsonBytes = utf8.encode(jsonEncode(payload));
    final compressed = gzip.encode(jsonBytes);

    final header = Uint8List.fromList([..._magic, _version, _flagGzip]);
    final nonce = generateRandomBytes(12);
    final secretKey = SecretKey(masterKey32);

    final secretBox = await _aesGcm.encrypt(
      compressed,
      secretKey: secretKey,
      nonce: nonce,
      aad: header,
    );

    final out = BytesBuilder(copy: false)
      ..add(header)
      ..add(nonce)
      ..add(secretBox.mac.bytes)
      ..add(secretBox.cipherText);
    return out.toBytes();
  }

  /// Decrypts a binary `MHV1` vault file using AES-256-GCM and returns the
  /// decoded JSON map.
  static Future<Map<String, dynamic>> decryptVaultPayload(
    Uint8List fileBytes,
    Uint8List masterKey32,
  ) async {
    if (masterKey32.length != 32) {
      throw const VaultCryptoException(
        'invalid_key_length',
        'Master key must be 32 bytes.',
      );
    }
    // Header (6) + Nonce (12) + Tag (16) = 34 bytes minimum
    if (fileBytes.length < 34) {
      throw const VaultCryptoException(
        'corrupt_vault',
        'Vault file is truncated or corrupt (< 34 bytes).',
      );
    }
    for (int i = 0; i < 4; i++) {
      if (fileBytes[i] != _magic[i]) {
        throw const VaultCryptoException(
          'invalid_magic',
          'Vault file does not start with MHV1 magic header.',
        );
      }
    }
    final version = fileBytes[4];
    if (version != _version) {
      throw VaultCryptoException(
        'unsupported_version',
        'Unsupported vault version: $version',
      );
    }
    final flags = fileBytes[5];
    final header = fileBytes.sublist(0, 6);
    final nonce = fileBytes.sublist(6, 18);
    final tagBytes = fileBytes.sublist(18, 34);
    final cipherText = fileBytes.sublist(34);

    final secretBox = SecretBox(
      cipherText,
      nonce: nonce,
      mac: Mac(tagBytes),
    );

    List<int> clearBytes;
    try {
      clearBytes = await _aesGcm.decrypt(
        secretBox,
        secretKey: SecretKey(masterKey32),
        aad: header,
      );
    } catch (e) {
      throw VaultCryptoException(
        'decryption_failed',
        'Failed to authenticate or decrypt vault (wrong key or tampered file): $e',
      );
    }

    final decompressed =
        (flags & _flagGzip) != 0 ? gzip.decode(clearBytes) : clearBytes;
    final decoded = jsonDecode(utf8.decode(decompressed));
    if (decoded is! Map) {
      throw const VaultCryptoException(
        'corrupt_vault',
        'Decrypted vault content is not a JSON object.',
      );
    }
    return Map<String, dynamic>.from(decoded);
  }

  /// Creates a passphrase-protected encrypted backup (`.mhb` JSON envelope)
  /// using PBKDF2-HMAC-SHA256 (100,000 iterations) and AES-256-GCM.
  static Future<Map<String, dynamic>> createEncryptedBackup({
    required Map<String, dynamic> portableDocument,
    required String passphrase,
    required String createdAtIso,
  }) async {
    if (passphrase.isEmpty) {
      throw const VaultCryptoException(
        'empty_passphrase',
        'Passphrase must not be empty for encrypted backup.',
      );
    }
    final salt = generateRandomBytes(16);
    final nonce = generateRandomBytes(12);

    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: pbkdf2Iterations,
      bits: 256,
    );
    final secretKey = await pbkdf2.deriveKeyFromPassword(
      password: passphrase,
      nonce: salt,
    );

    final rawJson = utf8.encode(jsonEncode(portableDocument));
    final compressed = gzip.encode(rawJson);
    final aad = utf8.encode(backupFormatId);

    final box = await _aesGcm.encrypt(
      compressed,
      secretKey: secretKey,
      nonce: nonce,
      aad: aad,
    );

    return {
      'format': backupFormatId,
      'kdf': 'PBKDF2-HMAC-SHA256',
      'kdf_iterations': pbkdf2Iterations,
      'salt_b64': base64Encode(salt),
      'cipher': 'AES-256-GCM',
      'compression': 'gzip',
      'nonce_b64': base64Encode(nonce),
      'tag_b64': base64Encode(box.mac.bytes),
      'ciphertext_b64': base64Encode(box.cipherText),
      'created_at': createdAtIso,
    };
  }

  /// Decrypts and verifies a passphrase-protected encrypted backup envelope.
  static Future<Map<String, dynamic>> decryptEncryptedBackup({
    required Map<String, dynamic> backupEnvelope,
    required String passphrase,
  }) async {
    if (passphrase.isEmpty) {
      throw const VaultCryptoException(
        'empty_passphrase',
        'Passphrase is required to decrypt backup.',
      );
    }
    final format = backupEnvelope['format']?.toString();
    if (format != backupFormatId) {
      throw VaultCryptoException(
        'invalid_backup_format',
        'Unsupported encrypted backup format: $format',
      );
    }

    final iterations = (backupEnvelope['kdf_iterations'] is num)
        ? (backupEnvelope['kdf_iterations'] as num).toInt()
        : pbkdf2Iterations;
    final salt = base64Decode(backupEnvelope['salt_b64'].toString());
    final nonce = base64Decode(backupEnvelope['nonce_b64'].toString());
    final tag = base64Decode(backupEnvelope['tag_b64'].toString());
    final cipherText =
        base64Decode(backupEnvelope['ciphertext_b64'].toString());

    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iterations.clamp(1000, 1000000),
      bits: 256,
    );
    final secretKey = await pbkdf2.deriveKeyFromPassword(
      password: passphrase,
      nonce: salt,
    );

    final box = SecretBox(
      cipherText,
      nonce: nonce,
      mac: Mac(tag),
    );

    List<int> clearBytes;
    try {
      clearBytes = await _aesGcm.decrypt(
        box,
        secretKey: secretKey,
        aad: utf8.encode(backupFormatId),
      );
    } catch (e) {
      throw const VaultCryptoException(
        'invalid_passphrase_or_corrupt',
        'Could not decrypt backup: wrong passphrase or corrupted backup file.',
      );
    }

    final compression = backupEnvelope['compression']?.toString() ?? 'gzip';
    final jsonBytes =
        compression == 'gzip' ? gzip.decode(clearBytes) : clearBytes;
    final doc = jsonDecode(utf8.decode(jsonBytes));
    if (doc is! Map) {
      throw const VaultCryptoException(
        'corrupt_backup',
        'Decrypted backup payload is not a valid JSON document.',
      );
    }
    return Map<String, dynamic>.from(doc);
  }
}
