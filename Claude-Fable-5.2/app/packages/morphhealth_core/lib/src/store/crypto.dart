/// Cryptographic building blocks of MorphHealth.
///
/// Nothing here is a home-grown algorithm. All primitives come from the
/// `cryptography` package (pure Dart): XChaCha20-Poly1305 for authenticated
/// encryption, HKDF-SHA-256 for key separation and Argon2id for passphrases.
/// The unit tests check them against the published test vectors.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';

import '../util/ids.dart';

/// Decryption failed: wrong key or passphrase, or the data was modified.
class AuthenticationFailure implements Exception {
  const AuthenticationFailure();

  @override
  String toString() =>
      'AuthenticationFailure: wrong key or passphrase, or modified data';
}

/// Authenticated encryption with XChaCha20-Poly1305 (256-bit key, 192-bit
/// random nonce, 128-bit tag).
abstract final class Aead {
  static const int keyLength = 32;
  static const int nonceLength = 24;
  static const int tagLength = 16;

  /// Bytes added to a plaintext by [seal].
  static const int overhead = nonceLength + tagLength;

  static const DartXchacha20 _cipher = DartXchacha20.poly1305Aead();

  /// Encrypts [plaintext] and binds it to [aad].
  /// Returns `nonce || ciphertext || tag` with a fresh random nonce.
  static Uint8List seal(
    Uint8List key,
    List<int> plaintext, {
    required List<int> aad,
  }) {
    _checkKey(key);
    final nonce = randomBytes(nonceLength);
    final box = _cipher.encryptSync(
      plaintext,
      secretKey: SecretKeyData(key),
      nonce: nonce,
      aad: aad,
    );
    final out = Uint8List(nonceLength + box.cipherText.length + tagLength);
    out.setRange(0, nonceLength, nonce);
    out.setRange(
      nonceLength,
      nonceLength + box.cipherText.length,
      box.cipherText,
    );
    out.setRange(
      nonceLength + box.cipherText.length,
      out.length,
      box.mac.bytes,
    );
    return out;
  }

  /// Verifies and decrypts the output of [seal].
  /// Throws [AuthenticationFailure] if key, [aad] or data do not match.
  static Uint8List open(
    Uint8List key,
    Uint8List sealed, {
    required List<int> aad,
  }) {
    _checkKey(key);
    if (sealed.length < overhead) throw const AuthenticationFailure();
    final nonce = Uint8List.sublistView(sealed, 0, nonceLength);
    final cipherText = Uint8List.sublistView(
      sealed,
      nonceLength,
      sealed.length - tagLength,
    );
    final tag = Uint8List.sublistView(sealed, sealed.length - tagLength);
    try {
      final clear = _cipher.decryptSync(
        SecretBox(cipherText, nonce: nonce, mac: Mac(tag)),
        secretKey: SecretKeyData(key),
        aad: aad,
      );
      return clear is Uint8List ? clear : Uint8List.fromList(clear);
    } on SecretBoxAuthenticationError {
      throw const AuthenticationFailure();
    }
  }

  static void _checkKey(Uint8List key) {
    if (key.length != keyLength) {
      throw ArgumentError.value(
        key.length,
        'key',
        'must be exactly $keyLength bytes',
      );
    }
  }
}

/// HKDF-SHA-256 (RFC 5869): derives a purpose-bound key from [keyMaterial].
Future<Uint8List> hkdfSha256(
  List<int> keyMaterial, {
  required String info,
  List<int> salt = const [],
  int length = 32,
}) async {
  final hkdf = DartHkdf(hmac: Hmac.sha256(), outputLength: length);
  final out = await hkdf.deriveKey(
    secretKey: SecretKeyData(keyMaterial),
    nonce: salt,
    info: utf8.encode(info),
  );
  return Uint8List.fromList(out.bytes);
}

/// Cost parameters of Argon2id (RFC 9106).
class Argon2Params {
  /// Memory in kibibytes.
  final int memoryKib;
  final int iterations;
  final int parallelism;

  const Argon2Params({
    required this.memoryKib,
    required this.iterations,
    required this.parallelism,
  });

  /// RFC 9106, second recommended option: 64 MiB, 3 passes, 4 lanes.
  static const Argon2Params standard = Argon2Params(
    memoryKib: 64 * 1024,
    iterations: 3,
    parallelism: 4,
  );

  /// Accepted bounds when reading a backup, so that a manipulated file
  /// cannot demand unreasonable resources.
  bool get isAcceptable =>
      memoryKib >= 8 * 1024 &&
      memoryKib <= 1024 * 1024 &&
      iterations >= 1 &&
      iterations <= 16 &&
      parallelism >= 1 &&
      parallelism <= 16 &&
      memoryKib >= 8 * parallelism;
}

/// Argon2id version 1.3: derives a 256-bit key from a passphrase.
///
/// Runs in the calling isolate. Callers with a user interface should run it
/// in a background isolate, because it takes several hundred milliseconds.
Future<Uint8List> argon2id(
  List<int> passphrase,
  List<int> salt, {
  required Argon2Params params,
  int length = 32,
}) async {
  final algorithm = DartArgon2id(
    parallelism: params.parallelism,
    memory: params.memoryKib,
    iterations: params.iterations,
    hashLength: length,
    maxIsolates: 0,
  );
  final key = await algorithm.deriveKey(
    secretKey: SecretKeyData(passphrase),
    nonce: salt,
  );
  return Uint8List.fromList(await key.extractBytes());
}

String hexEncode(List<int> bytes) {
  final b = StringBuffer();
  for (final v in bytes) {
    b.write(v.toRadixString(16).padLeft(2, '0'));
  }
  return b.toString();
}

Uint8List hexDecode(String hex) {
  final clean = hex.replaceAll(RegExp(r'\s'), '');
  if (clean.length.isOdd) throw const FormatException('odd hex length');
  final out = Uint8List(clean.length ~/ 2);
  for (var i = 0; i < out.length; i++) {
    out[i] = int.parse(clean.substring(2 * i, 2 * i + 2), radix: 16);
  }
  return out;
}
