/// Kalenderdaten und Ortszeiten ohne Zeitzonen.
///
/// Das Tagebuch kennt nur den Tag, den die Nutzerin oder der Nutzer vor Augen
/// hat. Ein Eintrag von 23:30 gehört zu diesem Tag, egal in welcher Zeitzone
/// das Gerät später steht. Deshalb rechnet der gesamte Kern mit [Day] und
/// [LocalDateTime] statt mit [DateTime].
library;

/// Ein Kalendertag (proleptisch gregorianisch, 1900 bis 2199).
final class Day implements Comparable<Day> {
  final int year;
  final int month;
  final int day;

  const Day._(this.year, this.month, this.day);

  static const int minYear = 1900;
  static const int maxYear = 2199;

  /// Erzeugt einen gültigen Tag oder wirft einen [FormatException].
  factory Day(int year, int month, int day) {
    if (year < minYear || year > maxYear) {
      throw FormatException('Jahr außerhalb $minYear..$maxYear', '$year');
    }
    if (month < 1 || month > 12) {
      throw FormatException('Monat außerhalb 1..12', '$month');
    }
    if (day < 1 || day > daysInMonthOf(year, month)) {
      throw FormatException('Tag außerhalb des Monats', '$day');
    }
    return Day._(year, month, day);
  }

  static final RegExp _iso = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

  /// Erwartet `YYYY-MM-DD`.
  factory Day.parse(String s) {
    final m = _iso.firstMatch(s.trim());
    if (m == null) throw FormatException('Datum erwartet als YYYY-MM-DD', s);
    return Day(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!));
  }

  static Day? tryParse(String? s) {
    if (s == null) return null;
    try {
      return Day.parse(s);
    } on FormatException {
      return null;
    }
  }

  factory Day.fromDateTime(DateTime d) => Day(d.year, d.month, d.day);

  factory Day.fromEpochDay(int n) {
    final c = _civilFromDays(n);
    return Day(c.$1, c.$2, c.$3);
  }

  /// Tage seit 1970-01-01.
  int get epochDay => _daysFromCivil(year, month, day);

  Day addDays(int n) => Day.fromEpochDay(epochDay + n);

  /// Anzahl Tage von diesem bis [other] (positiv, wenn [other] später liegt).
  int daysUntil(Day other) => other.epochDay - epochDay;

  /// ISO-Wochentag: Montag = 1 bis Sonntag = 7.
  int get weekday => (epochDay + 3) % 7 + 1;

  Day get firstOfMonth => Day._(year, month, 1);

  int get daysInMonth => daysInMonthOf(year, month);

  Day get lastOfMonth => Day._(year, month, daysInMonth);

  /// Erster Tag des Vor- oder Folgemonats (n Monate verschoben).
  Day addMonths(int n) {
    final total = year * 12 + (month - 1) + n;
    var y = total ~/ 12;
    var m = total % 12 + 1;
    if (y < minYear) {
      y = minYear;
      m = 1;
    } else if (y > maxYear) {
      y = maxYear;
      m = 12;
    }
    final d = day > daysInMonthOf(y, m) ? daysInMonthOf(y, m) : day;
    return Day._(y, m, d);
  }

  /// Mitternacht dieses Tages in der lokalen Zeitzone (nur für Darstellung).
  DateTime toDateTime() => DateTime(year, month, day);

  bool isBefore(Day o) => compareTo(o) < 0;
  bool isAfter(Day o) => compareTo(o) > 0;

  @override
  int compareTo(Day other) {
    if (year != other.year) return year.compareTo(other.year);
    if (month != other.month) return month.compareTo(other.month);
    return day.compareTo(other.day);
  }

  @override
  bool operator ==(Object other) => other is Day && other.year == year && other.month == month && other.day == day;

  @override
  int get hashCode => year * 372 + month * 31 + day;

  @override
  String toString() =>
      '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}';

  static bool isLeap(int y) => (y % 4 == 0 && y % 100 != 0) || y % 400 == 0;

  static int daysInMonthOf(int y, int m) {
    const d = [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31];
    return m == 2 && isLeap(y) ? 29 : d[m - 1];
  }
}

// Algorithmen von Howard Hinnant (days_from_civil, civil_from_days).
int _daysFromCivil(int y, int m, int d) {
  final yy = m <= 2 ? y - 1 : y;
  final era = (yy >= 0 ? yy : yy - 399) ~/ 400;
  final yoe = yy - era * 400;
  final doy = (153 * (m + (m > 2 ? -3 : 9)) + 2) ~/ 5 + d - 1;
  final doe = yoe * 365 + yoe ~/ 4 - yoe ~/ 100 + doy;
  return era * 146097 + doe - 719468;
}

(int, int, int) _civilFromDays(int z0) {
  final z = z0 + 719468;
  final era = (z >= 0 ? z : z - 146096) ~/ 146097;
  final doe = z - era * 146097;
  final yoe = (doe - doe ~/ 1460 + doe ~/ 36524 - doe ~/ 146096) ~/ 365;
  final y = yoe + era * 400;
  final doy = doe - (365 * yoe + yoe ~/ 4 - yoe ~/ 100);
  final mp = (5 * doy + 2) ~/ 153;
  final d = doy - (153 * mp + 2) ~/ 5 + 1;
  final m = mp < 10 ? mp + 3 : mp - 9;
  return (m <= 2 ? y + 1 : y, m, d);
}

/// Ein Zeitpunkt in Ortszeit (Tag, Stunde, Minute, Sekunde) ohne Zeitzone.
final class LocalDateTime implements Comparable<LocalDateTime> {
  final Day day;
  final int hour;
  final int minute;
  final int second;

  const LocalDateTime._(this.day, this.hour, this.minute, this.second);

  factory LocalDateTime(Day day, [int hour = 0, int minute = 0, int second = 0]) {
    if (hour < 0 || hour > 23) throw FormatException('Stunde außerhalb 0..23', '$hour');
    if (minute < 0 || minute > 59) throw FormatException('Minute außerhalb 0..59', '$minute');
    if (second < 0 || second > 59) throw FormatException('Sekunde außerhalb 0..59', '$second');
    return LocalDateTime._(day, hour, minute, second);
  }

  static final RegExp _re = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})(?:[Tt ](\d{2}):(\d{2})(?::(\d{2})(?:[.,]\d+)?)?)?\s*(?:[Zz]|[+-]\d{2}(?::?\d{2})?)?$',
  );

  /// Akzeptiert `YYYY-MM-DD` und `YYYY-MM-DDTHH:MM[:SS[.fff]]`. Eine
  /// angehängte Zeitzone wird ignoriert: Es gilt die Ortszeit wie notiert.
  factory LocalDateTime.parse(String s) {
    final m = _re.firstMatch(s.trim());
    if (m == null) {
      throw FormatException('Zeitpunkt erwartet als YYYY-MM-DD oder YYYY-MM-DDTHH:MM[:SS]', s);
    }
    return LocalDateTime(
      Day(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!)),
      m[4] == null ? 0 : int.parse(m[4]!),
      m[5] == null ? 0 : int.parse(m[5]!),
      m[6] == null ? 0 : int.parse(m[6]!),
    );
  }

  static LocalDateTime? tryParse(String? s) {
    if (s == null) return null;
    try {
      return LocalDateTime.parse(s);
    } on FormatException {
      return null;
    }
  }

  factory LocalDateTime.fromDateTime(DateTime d) => LocalDateTime(Day.fromDateTime(d), d.hour, d.minute, d.second);

  int get minuteOfDay => hour * 60 + minute;

  DateTime toDateTime() => DateTime(day.year, day.month, day.day, hour, minute, second);

  LocalDateTime withDay(Day d) => LocalDateTime._(d, hour, minute, second);

  LocalDateTime withTime(int h, int m) => LocalDateTime(day, h, m, 0);

  bool isBefore(LocalDateTime o) => compareTo(o) < 0;

  @override
  int compareTo(LocalDateTime other) {
    final c = day.compareTo(other.day);
    if (c != 0) return c;
    final a = hour * 3600 + minute * 60 + second;
    final b = other.hour * 3600 + other.minute * 60 + other.second;
    return a.compareTo(b);
  }

  @override
  bool operator ==(Object other) =>
      other is LocalDateTime &&
      other.day == day &&
      other.hour == hour &&
      other.minute == minute &&
      other.second == second;

  @override
  int get hashCode => Object.hash(day, hour, minute, second);

  /// `YYYY-MM-DDTHH:MM:SS`
  @override
  String toString() =>
      '$day'
      'T${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}:${second.toString().padLeft(2, '0')}';
}
