import 'civil.dart';

/// Die fachliche Uhr. Kein Fachcode ruft `DateTime.now()` direkt auf.
abstract class Clock {
  /// Der aktuelle Zeitpunkt in Ortszeit des Prozesses.
  DateTime now();

  Day today() => Day.fromDateTime(now());

  LocalDateTime nowLocal() => LocalDateTime.fromDateTime(now());
}

/// Die Systemuhr.
final class SystemClock extends Clock {
  @override
  DateTime now() => DateTime.now();
}

/// Eine angehaltene Uhr für Wartungszugang und Tests (`--now`).
final class FixedClock extends Clock {
  final DateTime _t;

  FixedClock(DateTime t) : _t = t.toLocal();

  /// Parst RFC 3339 (`2026-09-29T10:00:00+02:00`, `...Z`). Ohne Zeitzone gilt
  /// die Ortszeit des Prozesses. Der Zeitpunkt wird in die Ortszeit des
  /// Prozesses umgerechnet, genau wie bei einer verstellten Systemuhr.
  factory FixedClock.parse(String s) {
    final t = DateTime.tryParse(s.trim());
    if (t == null) {
      throw FormatException('Zeitpunkt erwartet als RFC 3339, z. B. 2026-09-29T10:00:00+02:00', s);
    }
    return FixedClock(t);
  }

  @override
  DateTime now() => _t;
}

/// RFC 3339 mit Zeitzonenversatz, z. B. `2026-09-29T10:00:00+02:00`.
String rfc3339(DateTime t) {
  final local = t.toLocal();
  String two(int n) => n.toString().padLeft(2, '0');
  final off = local.timeZoneOffset;
  final sign = off.isNegative ? '-' : '+';
  final abs = off.abs();
  return '${local.year.toString().padLeft(4, '0')}-${two(local.month)}-${two(local.day)}'
      'T${two(local.hour)}:${two(local.minute)}:${two(local.second)}'
      '$sign${two(abs.inHours)}:${two(abs.inMinutes % 60)}';
}
