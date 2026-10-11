import 'dart:math';

/// Eindeutige ID (UUID v4) für Datensätze.
String newId() {
  final rnd = Random.secure();
  final bytes = List<int>.generate(16, (int i) => rnd.nextInt(256));
  // RFC 4122 v4: Version und Variante setzen.
  bytes[6] = (bytes[6] & 0x0f) | 0x40;
  bytes[8] = (bytes[8] & 0x3f) | 0x80;
  final hex = bytes.map((int b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
}

/// 32 zufällige Bytes (z. B. für Datenschlüssel).
List<int> randomBytes(int length) {
  final rnd = Random.secure();
  return List<int>.generate(length, (int i) => rnd.nextInt(256));
}
