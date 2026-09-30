import 'dart:math';

final Random _rng = Random.secure();

/// Zufällige ID aus 16 Hexzeichen (64 Bit). Kollisionen sind bei einem
/// Nutzer pro Installation praktisch ausgeschlossen.
String newId() {
  final sb = StringBuffer();
  for (var i = 0; i < 8; i++) {
    sb.write(_rng.nextInt(256).toRadixString(16).padLeft(2, '0'));
  }
  return sb.toString();
}

/// Zufällige Bytes aus dem Betriebssystem-Zufallsgenerator.
List<int> randomBytes(int n) => List<int>.generate(n, (_) => _rng.nextInt(256), growable: false);
