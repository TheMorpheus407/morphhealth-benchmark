import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

/// Cryptographic helpers used by the local store and the backup container.
///
/// MorphHealth only needs symmetric encryption: the local store is protected
/// with AES-256-GCM, the passphrase protected backups with AES-256-GCM as
/// well, the passphrase is turned into a key with Argon2id.
abstract final class Crypto {
  static final Random _random = Random.secure();

  static final AesGcm _aes = AesGcm.with256bits();
  static final Hkdf _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);

  /// Argon2id parameters for passphrase protected backups.
  ///
  /// 19 MiB / 2 iterations / 1 lane follows the OWASP minimum configuration
  /// and keeps the pure Dart implementation usable on a phone.
  static const int argon2MemoryKib = 19456;
  static const int argon2Iterations = 2;
  static const int argon2Parallelism = 1;
  static const int argon2HashLength = 32;

  /// Random bytes from the platform CSPRNG.
  static List<int> randomBytes(int length) {
    final Uint8List out = Uint8List(length);
    for (int i = 0; i < length; i++) {
      out[i] = _random.nextInt(256);
    }
    return out;
  }

  /// A fresh 32 byte master key.
  static List<int> newMasterKey() => randomBytes(32);

  /// Derives the store key from the master key with HKDF-SHA256.
  static Future<SecretKey> deriveStoreKey(
    List<int> masterKey,
    List<int> salt,
    String info,
  ) async {
    final SecretKeyData derived = await _hkdf.deriveKey(
      secretKey: SecretKey(masterKey),
      nonce: salt,
      info: utf8.encode(info),
    );
    return SecretKey(derived.bytes);
  }

  /// Derives a key from a passphrase with Argon2id.
  static Future<SecretKey> derivePassphraseKey(
    String passphrase,
    List<int> salt, {
    int memory = argon2MemoryKib,
    int iterations = argon2Iterations,
    int parallelism = argon2Parallelism,
  }) async {
    final Argon2id argon2 = Argon2id(
      parallelism: parallelism,
      memory: memory,
      iterations: iterations,
      hashLength: argon2HashLength,
    );
    final SecretKey derived = await argon2.deriveKey(
      secretKey: SecretKey(utf8.encode(passphrase)),
      nonce: salt,
    );
    return derived;
  }

  /// Encrypts [plainText] with AES-256-GCM.
  ///
  /// [aad] is authenticated but not encrypted and is used to bind a record to
  /// its position inside the store.
  static Future<EncryptedPayload> encrypt(
    List<int> plainText, {
    required SecretKey key,
    List<int> aad = const <int>[],
    List<int>? nonce,
  }) async {
    final SecretBox box = await _aes.encrypt(
      plainText,
      secretKey: key,
      nonce: nonce ?? randomBytes(AesGcm.defaultNonceLength),
      aad: aad,
    );
    return EncryptedPayload(
      nonce: box.nonce,
      cipherText: box.cipherText,
      mac: box.mac.bytes,
    );
  }

  /// Decrypts and verifies a payload produced by [encrypt].
  static Future<List<int>> decrypt(
    EncryptedPayload payload, {
    required SecretKey key,
    List<int> aad = const <int>[],
  }) async {
    final SecretBox box = SecretBox(
      payload.cipherText,
      nonce: payload.nonce,
      mac: Mac(payload.mac),
    );
    return _aes.decrypt(box, secretKey: key, aad: aad);
  }
}

/// An AES-GCM ciphertext together with nonce and authentication tag.
class EncryptedPayload {
  const EncryptedPayload({
    required this.nonce,
    required this.cipherText,
    required this.mac,
  });

  final List<int> nonce;
  final List<int> cipherText;
  final List<int> mac;

  List<int> get combined {
    final Uint8List out = Uint8List(nonce.length + cipherText.length + mac.length)
      ..setRange(0, nonce.length, nonce)
      ..setRange(nonce.length, nonce.length + cipherText.length, cipherText)
      ..setRange(
        nonce.length + cipherText.length,
        nonce.length + cipherText.length + mac.length,
        mac,
      );
    return out;
  }

  static EncryptedPayload fromCombined(List<int> bytes) {
    if (bytes.length < 12 + 16) {
      throw const FormatException('Encrypted payload too short');
    }
    final List<int> nonce = bytes.sublist(0, 12);
    final List<int> cipherText = bytes.sublist(12, bytes.length - 16);
    final List<int> mac = bytes.sublist(bytes.length - 16);
    return EncryptedPayload(
      nonce: nonce,
      cipherText: cipherText,
      mac: mac,
    );
  }
}

/// Raised when encrypted data cannot be authenticated or decrypted.
class CryptoException implements Exception {
  const CryptoException(this.message);

  final String message;

  @override
  String toString() => 'CryptoException: $message';
}
