import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as hash;
import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';

final Random _random = Random.secure();

/// Cryptographically secure random bytes.
Uint8List randomBytes(int length) {
  final out = Uint8List(length);
  for (var i = 0; i < length; i++) {
    out[i] = _random.nextInt(256);
  }
  return out;
}

Uint8List hmacSha256(List<int> key, List<int> data) =>
    Uint8List.fromList(hash.Hmac(hash.sha256, key).convert(data).bytes);

Uint8List sha256(List<int> data) =>
    Uint8List.fromList(hash.sha256.convert(data).bytes);

/// HKDF with HMAC-SHA256 as specified in RFC 5869.
Uint8List hkdfSha256(
  List<int> inputKeyMaterial, {
  List<int> salt = const [],
  List<int> info = const [],
  int length = 32,
}) {
  if (length <= 0 || length > 255 * 32) {
    throw ArgumentError.value(length, 'length');
  }
  final prk = hmacSha256(
    salt.isEmpty ? Uint8List(32) : salt,
    inputKeyMaterial,
  );
  final out = BytesBuilder(copy: false);
  var previous = Uint8List(0);
  var counter = 1;
  while (out.length < length) {
    previous = hmacSha256(prk, [...previous, ...info, counter]);
    out.add(previous);
    counter++;
  }
  return Uint8List.sublistView(out.toBytes(), 0, length);
}

/// Compares two byte sequences in constant time (for equal lengths).
bool constantTimeEquals(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff == 0;
}

class AeadAuthenticationException implements Exception {
  const AeadAuthenticationException();
  @override
  String toString() => 'Authentication failed (wrong key or damaged data)';
}

/// AES-256-GCM with a random 96-bit nonce and a 128-bit tag.
///
/// The sealed form is `nonce (12) || ciphertext || tag (16)`.
class Aead {
  const Aead._();

  static const int keyLength = 32;
  static const int nonceLength = 12;
  static const int tagLength = 16;
  static final DartAesGcm _algorithm = DartAesGcm.with256bits();

  static Uint8List seal(List<int> key, List<int> plaintext, List<int> aad) {
    _checkKey(key);
    final nonce = randomBytes(nonceLength);
    final box = _algorithm.encryptSync(
      plaintext,
      secretKeyData: SecretKeyData(key),
      nonce: nonce,
      aad: aad,
    );
    final out = Uint8List(nonceLength + box.cipherText.length + tagLength);
    out.setRange(0, nonceLength, nonce);
    out.setRange(nonceLength, nonceLength + box.cipherText.length, box.cipherText);
    out.setRange(
      nonceLength + box.cipherText.length,
      out.length,
      box.mac.bytes,
    );
    return out;
  }

  static Uint8List open(List<int> key, List<int> sealed, List<int> aad) {
    _checkKey(key);
    if (sealed.length < nonceLength + tagLength) {
      throw const AeadAuthenticationException();
    }
    final bytes = sealed is Uint8List ? sealed : Uint8List.fromList(sealed);
    final nonce = Uint8List.sublistView(bytes, 0, nonceLength);
    final cipherText = Uint8List.sublistView(
      bytes,
      nonceLength,
      bytes.length - tagLength,
    );
    final tag = Uint8List.sublistView(bytes, bytes.length - tagLength);
    try {
      final clear = _algorithm.decryptSync(
        SecretBox(cipherText, nonce: nonce, mac: Mac(tag)),
        secretKeyData: SecretKeyData(key),
        aad: aad,
      );
      return clear is Uint8List ? clear : Uint8List.fromList(clear);
    } on SecretBoxAuthenticationError {
      throw const AeadAuthenticationException();
    }
  }

  static void _checkKey(List<int> key) {
    if (key.length != keyLength) {
      throw ArgumentError('AES-256-GCM needs a 32-byte key');
    }
  }
}

/// Argon2id parameters used for passphrase-protected backups.
class Argon2Params {
  const Argon2Params({
    required this.memoryKib,
    required this.iterations,
    required this.parallelism,
  });

  /// Default: 64 MiB, 3 passes, 1 lane (stronger than the OWASP minimum of
  /// 19 MiB / 2 passes).
  static const Argon2Params standard = Argon2Params(
    memoryKib: 65536,
    iterations: 3,
    parallelism: 1,
  );

  final int memoryKib;
  final int iterations;
  final int parallelism;

  /// Bounds accepted when reading a backup, to reject absurd parameters.
  bool get isAcceptable =>
      memoryKib >= 8192 &&
      memoryKib <= 1048576 &&
      iterations >= 1 &&
      iterations <= 20 &&
      parallelism >= 1 &&
      parallelism <= 8;

  Future<Uint8List> deriveKey(String passphrase, List<int> salt) async {
    final algorithm = DartArgon2id(
      parallelism: parallelism,
      memory: memoryKib,
      iterations: iterations,
      hashLength: 32,
    );
    final key = await algorithm.deriveKey(
      secretKey: SecretKey(utf8.encode(passphrase)),
      nonce: salt,
    );
    return Uint8List.fromList(await key.extractBytes());
  }
}

String base64UrlNoPad(List<int> bytes) =>
    base64Url.encode(bytes).replaceAll('=', '');

Uint8List decodeBase64Flexible(String text) {
  var s = text.trim().replaceAll('-', '+').replaceAll('_', '/');
  while (s.length % 4 != 0) {
    s += '=';
  }
  return base64.decode(s);
}
