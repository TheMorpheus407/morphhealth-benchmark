import 'local_date.dart';

/// The business clock. The app uses the system clock; the `mh` maintenance
/// process can pin it with `--now RFC3339`.
abstract class Clock {
  /// Current instant in UTC.
  DateTime nowUtc();

  /// The user's current calendar day.
  LocalDate today();

  /// The user's current wall-clock time in minutes since midnight.
  int minutesOfDay();
}

class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime nowUtc() => DateTime.now().toUtc();

  @override
  LocalDate today() => LocalDate.fromDateTime(DateTime.now());

  @override
  int minutesOfDay() {
    final now = DateTime.now();
    return now.hour * 60 + now.minute;
  }
}

/// A clock frozen at a given instant. The local wall time is derived from the
/// UTC offset that was part of the RFC 3339 timestamp.
class FixedClock implements Clock {
  FixedClock(this.instantUtc, this.offset) : assert(instantUtc.isUtc);

  final DateTime instantUtc;
  final Duration offset;

  static final RegExp _rfc3339 = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})[Tt ](\d{2}):(\d{2}):(\d{2})(\.\d{1,9})?([Zz]|[+-]\d{2}:\d{2})$',
  );

  /// Parses an RFC 3339 timestamp such as `2026-09-23T08:30:00+02:00`.
  static FixedClock parseRfc3339(String text) {
    final m = _rfc3339.firstMatch(text.trim());
    if (m == null) {
      throw FormatException('Invalid RFC 3339 timestamp', text);
    }
    final date = LocalDate.tryParse('${m[1]}-${m[2]}-${m[3]}');
    final hour = int.parse(m[4]!);
    final minute = int.parse(m[5]!);
    final second = int.parse(m[6]!);
    if (date == null || hour > 23 || minute > 59 || second > 60) {
      throw FormatException('Invalid RFC 3339 timestamp', text);
    }
    var micros = 0;
    final fraction = m[7];
    if (fraction != null) {
      final digits = fraction.substring(1).padRight(6, '0').substring(0, 6);
      micros = int.parse(digits);
    }
    final zone = m[8]!;
    Duration offset;
    if (zone == 'Z' || zone == 'z') {
      offset = Duration.zero;
    } else {
      final sign = zone.startsWith('-') ? -1 : 1;
      final oh = int.parse(zone.substring(1, 3));
      final om = int.parse(zone.substring(4, 6));
      if (oh > 23 || om > 59) {
        throw FormatException('Invalid UTC offset', text);
      }
      offset = Duration(hours: oh, minutes: om) * sign;
    }
    final wall = DateTime.utc(
      date.year,
      date.month,
      date.day,
      hour,
      minute,
      second.clamp(0, 59),
      0,
      micros,
    );
    return FixedClock(wall.subtract(offset), offset);
  }

  DateTime get _wall => instantUtc.add(offset);

  @override
  DateTime nowUtc() => instantUtc;

  @override
  LocalDate today() => LocalDate(_wall.year, _wall.month, _wall.day);

  @override
  int minutesOfDay() => _wall.hour * 60 + _wall.minute;
}

/// Formats a UTC instant as RFC 3339 with millisecond precision.
String formatInstant(DateTime instant) => instant.toUtc().toIso8601String();

/// Parses an RFC 3339 / ISO-8601 instant into UTC, or returns null.
DateTime? tryParseInstant(Object? value) {
  if (value is! String) return null;
  final parsed = DateTime.tryParse(value);
  if (parsed == null) return null;
  // Only accept values that carry an explicit zone designator.
  if (!RegExp(r'([Zz]|[+-]\d{2}:?\d{2})$').hasMatch(value.trim())) return null;
  return parsed.toUtc();
}
