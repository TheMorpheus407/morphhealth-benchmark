import 'dart:math';

final Random _secureRandom = Random.secure();

/// Returns a random RFC 4122 version 4 UUID, for example
/// `3f2b8c1e-5d4a-4b7c-9e1f-0a2b3c4d5e6f`.
String newId() {
  final b = List<int>.generate(16, (_) => _secureRandom.nextInt(256));
  b[6] = (b[6] & 0x0f) | 0x40;
  b[8] = (b[8] & 0x3f) | 0x80;
  final s = StringBuffer();
  for (var i = 0; i < 16; i++) {
    if (i == 4 || i == 6 || i == 8 || i == 10) s.write('-');
    s.write(b[i].toRadixString(16).padLeft(2, '0'));
  }
  return s.toString();
}

/// Cryptographically secure random bytes.
List<int> randomBytes(int length) =>
    List<int>.generate(length, (_) => _secureRandom.nextInt(256));
