import 'dart:math';

final Random _secureRandom = Random.secure();

/// A new random record identifier: 24 lowercase hex characters (96 bits).
String newId() {
  final buffer = StringBuffer();
  for (var i = 0; i < 12; i++) {
    buffer.write(_secureRandom.nextInt(256).toRadixString(16).padLeft(2, '0'));
  }
  return buffer.toString();
}

final RegExp _idPattern = RegExp(r'^[A-Za-z0-9._:-]{1,64}$');

/// Identifiers in imported documents may be any short token of safe characters.
bool isValidId(String id) => _idPattern.hasMatch(id);
