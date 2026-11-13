/// Calendar and wall-clock value types.
///
/// MorphHealth is a personal diary: an entry made at 23:30 on 3 November stays
/// on 3 November, wherever the device travels afterwards. All diary times are
/// therefore *floating* local times (calendar day plus time of day). A UTC
/// offset may be kept as written, but it never shifts an entry to another day.
library;

/// A calendar day in the proleptic Gregorian calendar, without time zone.
class Day implements Comparable<Day> {
  /// Days since 1970-01-01.
  final int epochDay;

  const Day.fromEpochDay(this.epochDay);

  /// Creates a validated calendar day. Throws [FormatException] for dates
  /// that do not exist (for example 2026-02-30).
  factory Day(int year, int month, int day) {
    final dt = DateTime.utc(year, month, day);
    if (dt.year != year || dt.month != month || dt.day != day) {
      throw FormatException(
        'Invalid calendar date: ${_p4(year)}-${_p2(month)}-${_p2(day)}',
      );
    }
    return Day.fromEpochDay(
      dt.millisecondsSinceEpoch ~/ Duration.millisecondsPerDay,
    );
  }

  /// The calendar day shown by the wall-clock fields of [dt].
  factory Day.fromDateTime(DateTime dt) => Day(dt.year, dt.month, dt.day);

  static final RegExp _iso = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

  /// Parses a strict `YYYY-MM-DD` date. Returns null if [input] is not one.
  static Day? tryParse(String input) {
    final m = _iso.firstMatch(input.trim());
    if (m == null) return null;
    try {
      return Day(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
    } on FormatException {
      return null;
    }
  }

  static Day parse(String input) =>
      tryParse(input) ??
      (throw FormatException('Expected a date as YYYY-MM-DD', input));

  DateTime get _utc => DateTime.fromMillisecondsSinceEpoch(
    epochDay * Duration.millisecondsPerDay,
    isUtc: true,
  );

  int get year => _utc.year;
  int get month => _utc.month;
  int get day => _utc.day;

  /// ISO weekday: Monday = 1 … Sunday = 7.
  int get weekday => _utc.weekday;

  Day addDays(int days) => Day.fromEpochDay(epochDay + days);

  /// Number of days from [other] to this day (positive if this is later).
  int daysSince(Day other) => epochDay - other.epochDay;

  Day get firstOfMonth => Day(year, month, 1);

  int get daysInMonth => DateTime.utc(year, month + 1, 0).day;

  /// Same day of month [months] later (or earlier), clamped to the month end.
  Day addMonths(int months) {
    final total = year * 12 + (month - 1) + months;
    final y = total ~/ 12;
    final m = total % 12 + 1;
    final last = DateTime.utc(y, m + 1, 0).day;
    return Day(y, m, day > last ? last : day);
  }

  /// Local midnight of this day as a [DateTime] (for platform pickers).
  DateTime toDateTime() => DateTime(year, month, day);

  bool operator <(Day other) => epochDay < other.epochDay;
  bool operator <=(Day other) => epochDay <= other.epochDay;
  bool operator >(Day other) => epochDay > other.epochDay;
  bool operator >=(Day other) => epochDay >= other.epochDay;

  @override
  int compareTo(Day other) => epochDay.compareTo(other.epochDay);

  @override
  bool operator ==(Object other) => other is Day && other.epochDay == epochDay;

  @override
  int get hashCode => epochDay.hashCode;

  /// ISO 8601 calendar date, `YYYY-MM-DD`.
  @override
  String toString() {
    final u = _utc;
    return '${_p4(u.year)}-${_p2(u.month)}-${_p2(u.day)}';
  }

  static Day min(Day a, Day b) => a <= b ? a : b;
  static Day max(Day a, Day b) => a >= b ? a : b;
}

/// A wall-clock date and time ("floating" local time).
///
/// [offsetMinutes] records the UTC offset that was written with the value, if
/// any. It is informational and round-trips through export and import, but it
/// is never used to move the value to another day.
class LocalDateTime implements Comparable<LocalDateTime> {
  final Day day;

  /// Seconds since local midnight, 0 … 86399.
  final int secondOfDay;

  final int? offsetMinutes;

  const LocalDateTime._(this.day, this.secondOfDay, this.offsetMinutes);

  factory LocalDateTime(
    Day day,
    int hour,
    int minute, [
    int second = 0,
    int? offsetMinutes,
  ]) {
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) {
      throw FormatException('Invalid time of day: $hour:$minute');
    }
    final s = second < 0 ? 0 : (second > 59 ? 59 : second);
    return LocalDateTime._(day, hour * 3600 + minute * 60 + s, offsetMinutes);
  }

  /// The wall-clock fields of [dt] as shown by [dt] itself (local or UTC).
  factory LocalDateTime.fromDateTime(DateTime dt) => LocalDateTime(
    Day(dt.year, dt.month, dt.day),
    dt.hour,
    dt.minute,
    dt.second,
    dt.timeZoneOffset.inMinutes,
  );

  /// Noon of [day]; used where only a date is known.
  factory LocalDateTime.noon(Day day) => LocalDateTime(day, 12, 0);

  int get hour => secondOfDay ~/ 3600;
  int get minute => (secondOfDay % 3600) ~/ 60;
  int get second => secondOfDay % 60;

  static final RegExp _pattern = RegExp(
    r'^(\d{4}-\d{2}-\d{2})'
    r'(?:[Tt ](\d{2}):(\d{2})(?::(\d{2})(?:[.,]\d+)?)?)?'
    r'\s*(Z|z|[+-]\d{2}(?::?\d{2})?)?$',
  );

  /// Parses ISO 8601 / RFC 3339 date-times such as `2026-11-09T07:45`,
  /// `2026-11-09T07:45:10` or `2026-11-09T07:45:10+01:00`.
  ///
  /// The calendar day and time are taken exactly as written. A date without
  /// time is accepted and placed at 12:00; [ParsedLocalDateTime.dateOnly]
  /// reports that case.
  static ParsedLocalDateTime? tryParseDetailed(String input) {
    final m = _pattern.firstMatch(input.trim());
    if (m == null) return null;
    final day = Day.tryParse(m[1]!);
    if (day == null) return null;
    final zone = m[5];
    int? offset;
    if (zone != null) {
      if (zone == 'Z' || zone == 'z') {
        offset = 0;
      } else {
        final sign = zone.startsWith('-') ? -1 : 1;
        final digits = zone.substring(1).replaceAll(':', '');
        final hh = int.parse(digits.substring(0, 2));
        final mm = digits.length >= 4 ? int.parse(digits.substring(2, 4)) : 0;
        if (hh > 18 || mm > 59) return null;
        offset = sign * (hh * 60 + mm);
      }
    }
    if (m[2] == null) {
      if (zone != null) return null;
      return ParsedLocalDateTime(LocalDateTime(day, 12, 0), dateOnly: true);
    }
    final hour = int.parse(m[2]!);
    final minute = int.parse(m[3]!);
    final second = m[4] == null ? 0 : int.parse(m[4]!);
    if (hour > 23 || minute > 59 || second > 60) return null;
    return ParsedLocalDateTime(
      LocalDateTime(day, hour, minute, second, offset),
      dateOnly: false,
    );
  }

  static LocalDateTime? tryParse(String input) =>
      tryParseDetailed(input)?.value;

  static LocalDateTime parse(String input) =>
      tryParse(input) ??
      (throw FormatException(
        'Expected a date-time such as 2026-11-09T07:45:00',
        input,
      ));

  LocalDateTime withOffset(int? minutes) =>
      LocalDateTime._(day, secondOfDay, minutes);

  LocalDateTime withDay(Day newDay) =>
      LocalDateTime._(newDay, secondOfDay, offsetMinutes);

  LocalDateTime withTime(int hour, int minute) =>
      LocalDateTime(day, hour, minute, 0, offsetMinutes);

  /// Local [DateTime] with the same wall-clock fields (for platform pickers).
  DateTime toDateTime() =>
      DateTime(day.year, day.month, day.day, hour, minute, second);

  /// `YYYY-MM-DDTHH:MM:SS`, followed by the UTC offset if one is recorded.
  String toIso() {
    final b = StringBuffer()
      ..write(day)
      ..write('T')
      ..write(_p2(hour))
      ..write(':')
      ..write(_p2(minute))
      ..write(':')
      ..write(_p2(second));
    final o = offsetMinutes;
    if (o != null) {
      final a = o.abs();
      b
        ..write(o < 0 ? '-' : '+')
        ..write(_p2(a ~/ 60))
        ..write(':')
        ..write(_p2(a % 60));
    }
    return b.toString();
  }

  /// `HH:MM`.
  String get hhmm => '${_p2(hour)}:${_p2(minute)}';

  /// Orders by wall-clock time (calendar day, then time of day).
  @override
  int compareTo(LocalDateTime other) {
    final c = day.epochDay.compareTo(other.day.epochDay);
    return c != 0 ? c : secondOfDay.compareTo(other.secondOfDay);
  }

  /// A sortable integer of the wall-clock time.
  int get sortKey => day.epochDay * 86400 + secondOfDay;

  @override
  bool operator ==(Object other) =>
      other is LocalDateTime &&
      other.day == day &&
      other.secondOfDay == secondOfDay &&
      other.offsetMinutes == offsetMinutes;

  @override
  int get hashCode => Object.hash(day, secondOfDay, offsetMinutes);

  @override
  String toString() => toIso();
}

class ParsedLocalDateTime {
  final LocalDateTime value;

  /// True if the input carried only a date; the time was set to 12:00.
  final bool dateOnly;

  const ParsedLocalDateTime(this.value, {required this.dateOnly});
}

/// Source of the current time for all domain logic ("fachliche Uhr").
abstract class Clock {
  LocalDateTime now();
}

extension ClockToday on Clock {
  Day get today => now().day;
}

/// The device or host clock in its local time zone.
class SystemClock implements Clock {
  const SystemClock();

  @override
  LocalDateTime now() => LocalDateTime.fromDateTime(DateTime.now());
}

/// A clock that stands still at [value] (used by `mh --now` and by tests).
class FixedClock implements Clock {
  final LocalDateTime value;

  const FixedClock(this.value);

  @override
  LocalDateTime now() => value;
}

String _p2(int v) => v < 10 ? '0$v' : '$v';

String _p4(int v) => v.toString().padLeft(4, '0');
