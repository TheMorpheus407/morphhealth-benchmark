/// A calendar date without a time zone, serialized as ISO-8601 `YYYY-MM-DD`.
///
/// All diary data is organized by the user's local calendar day. Using a
/// dedicated value type (instead of [DateTime]) avoids daylight-saving and
/// time-zone shifts when doing day arithmetic.
class LocalDate implements Comparable<LocalDate> {
  const LocalDate(this.year, this.month, this.day);

  factory LocalDate.fromDateTime(DateTime dateTime) =>
      LocalDate(dateTime.year, dateTime.month, dateTime.day);

  factory LocalDate.fromEpochDay(int epochDay) {
    final d = DateTime.fromMillisecondsSinceEpoch(
      epochDay * Duration.millisecondsPerDay,
      isUtc: true,
    );
    return LocalDate(d.year, d.month, d.day);
  }

  final int year;
  final int month;
  final int day;

  /// Earliest and latest dates accepted anywhere in the application.
  static const LocalDate min = LocalDate(1900, 1, 1);
  static const LocalDate max = LocalDate(2100, 12, 31);

  static final RegExp _pattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

  static LocalDate parse(String text) {
    final value = tryParse(text);
    if (value == null) {
      throw FormatException('Invalid date, expected YYYY-MM-DD', text);
    }
    return value;
  }

  static LocalDate? tryParse(String text) {
    final match = _pattern.firstMatch(text);
    if (match == null) return null;
    final year = int.parse(match[1]!);
    final month = int.parse(match[2]!);
    final day = int.parse(match[3]!);
    if (month < 1 || month > 12) return null;
    if (day < 1 || day > daysInMonth(year, month)) return null;
    return LocalDate(year, month, day);
  }

  static int daysInMonth(int year, int month) =>
      DateTime.utc(year, month + 1, 0).day;

  /// Days since 1970-01-01.
  int get epochDay =>
      DateTime.utc(year, month, day).millisecondsSinceEpoch ~/
      Duration.millisecondsPerDay;

  /// ISO weekday: 1 = Monday … 7 = Sunday.
  int get weekday => DateTime.utc(year, month, day).weekday;

  LocalDate addDays(int days) => LocalDate.fromEpochDay(epochDay + days);

  LocalDate addMonths(int months) {
    final total = year * 12 + (month - 1) + months;
    final y = total ~/ 12;
    final m = total % 12 + 1;
    final d = day > daysInMonth(y, m) ? daysInMonth(y, m) : day;
    return LocalDate(y, m, d);
  }

  /// Number of days from this date to [other] (positive if [other] is later).
  int daysUntil(LocalDate other) => other.epochDay - epochDay;

  LocalDate get firstOfMonth => LocalDate(year, month, 1);
  LocalDate get lastOfMonth => LocalDate(year, month, daysInMonth(year, month));

  bool isBefore(LocalDate other) => compareTo(other) < 0;
  bool isAfter(LocalDate other) => compareTo(other) > 0;
  bool isAtOrBefore(LocalDate other) => compareTo(other) <= 0;
  bool isAtOrAfter(LocalDate other) => compareTo(other) >= 0;

  bool isWithin(LocalDate from, LocalDate to) =>
      isAtOrAfter(from) && isAtOrBefore(to);

  bool get isInSupportedRange => isWithin(min, max);

  /// Local midnight of this date (for formatting with `intl`).
  DateTime toDateTime() => DateTime(year, month, day);

  String toIso() =>
      '${year.toString().padLeft(4, '0')}-${_two(month)}-${_two(day)}';

  static String _two(int v) => v.toString().padLeft(2, '0');

  @override
  int compareTo(LocalDate other) {
    if (year != other.year) return year.compareTo(other.year);
    if (month != other.month) return month.compareTo(other.month);
    return day.compareTo(other.day);
  }

  @override
  bool operator ==(Object other) =>
      other is LocalDate &&
      other.year == year &&
      other.month == month &&
      other.day == day;

  @override
  int get hashCode => year * 10000 + month * 100 + day;

  @override
  String toString() => toIso();
}

/// Wall-clock time of day in minutes since midnight, serialized as `HH:mm`.
class TimeOfDayMinutes {
  const TimeOfDayMinutes._();

  static final RegExp _pattern = RegExp(r'^(\d{2}):(\d{2})$');

  static int? tryParse(String text) {
    final match = _pattern.firstMatch(text);
    if (match == null) return null;
    final h = int.parse(match[1]!);
    final m = int.parse(match[2]!);
    if (h > 23 || m > 59) return null;
    return h * 60 + m;
  }

  static int parse(String text) {
    final value = tryParse(text);
    if (value == null) {
      throw FormatException('Invalid time, expected HH:mm', text);
    }
    return value;
  }

  static String format(int minutes) {
    final h = (minutes ~/ 60).toString().padLeft(2, '0');
    final m = (minutes % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }

  static bool isValid(int minutes) => minutes >= 0 && minutes < 24 * 60;
}
