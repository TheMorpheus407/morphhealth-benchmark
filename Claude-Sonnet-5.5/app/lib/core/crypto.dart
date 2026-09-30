import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import 'ids.dart';

/// Kryptografischer Fehler (falscher Schlüssel, manipulierte Daten, ...).
final class CryptoFailure implements Exception {
  final String message;

  const CryptoFailure(this.message);

  @override
  String toString() => 'CryptoFailure: $message';
}

const int aeadNonceLength = 12;
const int aeadTagLength = 16;

final AesGcm _aes = AesGcm.with256bits();
final Hmac _hmac = Hmac.sha256();

/// HKDF-SHA-256 (RFC 5869) über [ikm], mit [salt] und Verwendungszweck [info].
/// Ergebnis: 32 Byte.
Future<Uint8List> hkdfSha256(Uint8List ikm, Uint8List salt, String info) =>
    hkdfSha256Bytes(ikm, salt, utf8.encode(info));

/// Wie [hkdfSha256], mit Bytes als Kontext und wählbarer Ausgabelänge.
Future<Uint8List> hkdfSha256Bytes(Uint8List ikm, Uint8List salt, List<int> info, {int length = 32}) async {
  final key = await Hkdf(
    hmac: _hmac,
    outputLength: length,
  ).deriveKey(secretKey: SecretKey(ikm), nonce: salt, info: info);
  return Uint8List.fromList(await key.extractBytes());
}

Future<Uint8List> hmacSha256(Uint8List key, Uint8List data) async {
  final mac = await _hmac.calculateMac(data, secretKey: SecretKey(key));
  return Uint8List.fromList(mac.bytes);
}

/// AES-256-GCM. Ergebnis: `nonce(12) | ciphertext | tag(16)`. Die Nonce ist
/// zufällig, [aad] wird authentifiziert, aber nicht verschlüsselt.
Future<Uint8List> aeadSeal(Uint8List key, Uint8List plaintext, Uint8List aad) async {
  final box = await _aes.encrypt(plaintext, secretKey: SecretKey(key), nonce: randomBytes(aeadNonceLength), aad: aad);
  return Uint8List.fromList(box.concatenation());
}

/// Gegenstück zu [aeadSeal]. Wirft [CryptoFailure], wenn Schlüssel, Daten oder
/// [aad] nicht passen.
Future<Uint8List> aeadOpen(Uint8List key, Uint8List sealed, Uint8List aad) async {
  if (sealed.length < aeadNonceLength + aeadTagLength) {
    throw const CryptoFailure('Daten zu kurz');
  }
  final box = SecretBox.fromConcatenation(sealed, nonceLength: aeadNonceLength, macLength: aeadTagLength, copy: false);
  try {
    final clear = await _aes.decrypt(box, secretKey: SecretKey(key), aad: aad);
    return clear is Uint8List ? clear : Uint8List.fromList(clear);
  } on SecretBoxAuthenticationError {
    throw const CryptoFailure('Authentifizierung fehlgeschlagen');
  }
}

/// Parameter der passphrasenbasierten Schlüsselableitung (Argon2id).
final class Argon2Params {
  /// Speicher in KiB.
  final int memoryKiB;
  final int iterations;
  final int parallelism;

  const Argon2Params({required this.memoryKiB, required this.iterations, required this.parallelism});

  /// Vorgabe für neue Sicherungen: 64 MiB, 3 Durchläufe, 1 Lane.
  static const Argon2Params standard = Argon2Params(memoryKiB: 65536, iterations: 3, parallelism: 1);

  /// Obergrenzen, die beim Lesen fremder Dateien akzeptiert werden.
  static const int maxMemoryKiB = 524288;
  static const int maxIterations = 10;
  static const int maxParallelism = 8;

  bool get withinLimits =>
      memoryKiB >= 8 * parallelism &&
      memoryKiB <= maxMemoryKiB &&
      iterations >= 1 &&
      iterations <= maxIterations &&
      parallelism >= 1 &&
      parallelism <= maxParallelism;
}

/// Leitet aus einer Passphrase einen 32-Byte-Schlüssel ab (Argon2id).
Future<Uint8List> argon2idKey(String passphrase, Uint8List salt, Argon2Params p) async {
  final key = await Argon2id(
    parallelism: p.parallelism,
    memory: p.memoryKiB,
    iterations: p.iterations,
    hashLength: 32,
  ).deriveKey(secretKey: SecretKey(utf8.encode(passphrase)), nonce: salt);
  return Uint8List.fromList(await key.extractBytes());
}

/// Vergleich in konstanter Zeit.
bool constantTimeEquals(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  var diff = 0;
  for (var i = 0; i < a.length; i++) {
    diff |= a[i] ^ b[i];
  }
  return diff == 0;
}
