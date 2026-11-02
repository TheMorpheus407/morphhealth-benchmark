import 'dart:math';

/// Application clock. The `mh` CLI can override it with `--now`, the app
/// always uses the system clock.
abstract class AppClock {
  const AppClock();

  DateTime now();
}

/// Clock that follows the system time.
class SystemClock extends AppClock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now();
}

/// Clock frozen at a given instant. Used by the maintenance CLI.
class FixedClock extends AppClock {
  const FixedClock(this.instant);

  final DateTime instant;

  @override
  DateTime now() => instant;
}

/// Generates short, collision resistant identifiers.
abstract final class Ids {
  static final Random _random = Random.secure();

  /// Returns a 24 character hex identifier.
  static String newId() {
    final StringBuffer buffer = StringBuffer();
    for (int i = 0; i < 12; i++) {
      buffer.write(_random.nextInt(256).toRadixString(16).padLeft(2, '0'));
    }
    return buffer.toString();
  }
}
