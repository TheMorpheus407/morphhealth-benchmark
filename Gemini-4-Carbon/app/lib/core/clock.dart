/// Domain clock and strict ISO-8601 / RFC3339 calendar utilities.
///
/// All calendar-day arithmetic uses UTC date components so DST transitions
/// (such as Europe/Berlin spring/autumn shifts) never skew day counts.
library;

class FormatValidationException implements Exception {
  final String message;
  const FormatValidationException(this.message);

  @override
  String toString() => message;
}

abstract class AppClock {
  DateTime now();
  String todayIso();
  String nowRfc3339();
}

class SystemClock implements AppClock {
  const SystemClock();

  @override
  DateTime now() => DateTime.now();

  @override
  String todayIso() => IsoDate.fromLocalDateTime(DateTime.now());

  @override
  String nowRfc3339() => Rfc3339.formatLocal(DateTime.now());
}

class FixedClock implements AppClock {
  final DateTime _instantUtc;
  final String _calendarDateIso;
  final String _rawRfc3339;

  FixedClock._(this._instantUtc, this._calendarDateIso, this._rawRfc3339);

  factory FixedClock.fromRfc3339(String raw) {
    final parsed = Rfc3339.parseStrict(raw);
    return FixedClock._(parsed.instantUtc, parsed.calendarDateIso, parsed.canonical);
  }

  @override
  DateTime now() => _instantUtc.toLocal();

  @override
  String todayIso() => _calendarDateIso;

  @override
  String nowRfc3339() => _rawRfc3339;
}

class ParsedRfc3339 {
  final DateTime instantUtc;
  final String calendarDateIso;
  final String canonical;

  const ParsedRfc3339({
    required this.instantUtc,
    required this.calendarDateIso,
    required this.canonical,
  });
}

class Rfc3339 {
  static final RegExp _rfc3339Pattern = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})[Tt](\d{2}):(\d{2}):(\d{2})(?:\.(\d{1,9}))?([Zz]|([+-])(\d{2}):(\d{2}))$',
  );

  static ParsedRfc3339 parseStrict(String input) {
    final trimmed = input.trim();
    final match = _rfc3339Pattern.firstMatch(trimmed);
    if (match == null) {
      throw FormatValidationException(
        'Invalid RFC3339 timestamp: "$input". Expected YYYY-MM-DDTHH:MM:SSZ or ±HH:MM.',
      );
    }

    final hour = int.parse(match.group(4)!);
    final minute = int.parse(match.group(5)!);
    final second = int.parse(match.group(6)!);

    final dateIso =
        '${match.group(1)!}-${match.group(2)!}-${match.group(3)!}';
    if (!IsoDate.isValid(dateIso)) {
      throw FormatValidationException('Invalid calendar date in RFC3339: "$dateIso".');
    }
    if (hour > 23 || minute > 59 || second > 60) {
      throw FormatValidationException('Invalid time components in RFC3339: "$input".');
    }

    final tzSign = match.group(9);
    if (tzSign != null) {
      final tzHour = int.parse(match.group(10)!);
      final tzMin = int.parse(match.group(11)!);
      if (tzHour > 23 || tzMin > 59) {
        throw FormatValidationException('Invalid timezone offset in RFC3339: "$input".');
      }
    }

    // Normalize fractional seconds to at most 6 digits for Dart DateTime.parse
    var normalized = trimmed;
    final frac = match.group(7);
    if (frac != null && frac.length > 6) {
      final prefix =
          '${match.group(1)}-${match.group(2)}-${match.group(3)}T${match.group(4)}:${match.group(5)}:${match.group(6)}.${frac.substring(0, 6)}${match.group(8)}';
      normalized = prefix;
    }

    final parsed = DateTime.parse(normalized).toUtc();
    return ParsedRfc3339(
      instantUtc: parsed,
      calendarDateIso: dateIso,
      canonical: trimmed,
    );
  }

  static String formatLocal(DateTime dt) {
    final local = dt.toLocal();
    final y = local.year.toString().padLeft(4, '0');
    final m = local.month.toString().padLeft(2, '0');
    final d = local.day.toString().padLeft(2, '0');
    final hh = local.hour.toString().padLeft(2, '0');
    final mm = local.minute.toString().padLeft(2, '0');
    final ss = local.second.toString().padLeft(2, '0');
    final offset = local.timeZoneOffset;
    final sign = offset.isNegative ? '-' : '+';
    final totalMinutes = offset.inMinutes.abs();
    final oh = (totalMinutes ~/ 60).toString().padLeft(2, '0');
    final om = (totalMinutes % 60).toString().padLeft(2, '0');
    return '$y-$m-${d}T$hh:$mm:$ss$sign$oh:$om';
  }
}

class IsoDate {
  static final RegExp _isoPattern = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$');

  static bool isValid(String value) {
    final m = _isoPattern.firstMatch(value);
    if (m == null) return false;
    final year = int.parse(m.group(1)!);
    final month = int.parse(m.group(2)!);
    final day = int.parse(m.group(3)!);
    if (year < 1900 || year > 2200) return false;
    if (month < 1 || month > 12 || day < 1 || day > 31) return false;
    final utc = DateTime.utc(year, month, day);
    return utc.year == year && utc.month == month && utc.day == day;
  }

  static DateTime parseUtc(String dateIso) {
    if (!isValid(dateIso)) {
      throw FormatValidationException(
        'Invalid ISO date "$dateIso". Expected YYYY-MM-DD.',
      );
    }
    final parts = dateIso.split('-');
    return DateTime.utc(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  static String formatUtc(DateTime utcDate) {
    final y = utcDate.year.toString().padLeft(4, '0');
    final m = utcDate.month.toString().padLeft(2, '0');
    final d = utcDate.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static String fromLocalDateTime(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static int daysBetween(String startDateIso, String endDateIso) {
    final start = parseUtc(startDateIso);
    final end = parseUtc(endDateIso);
    return end.difference(start).inDays;
  }

  static String addDays(String dateIso, int deltaDays) {
    final d = parseUtc(dateIso);
    final shifted = DateTime.utc(d.year, d.month, d.day + deltaDays);
    return formatUtc(shifted);
  }

  static List<String> rangeInclusive(String startDateIso, String endDateIso) {
    final count = daysBetween(startDateIso, endDateIso);
    if (count < 0) return const [];
    return List<String>.generate(
      count + 1,
      (i) => addDays(startDateIso, i),
      growable: false,
    );
  }

  static String extractTimeHm(String recordedAt) {
    final idx = recordedAt.indexOf('T');
    final idxLower = idx >= 0 ? idx : recordedAt.indexOf('t');
    if (idxLower >= 0 && recordedAt.length >= idxLower + 6) {
      return recordedAt.substring(idxLower + 1, idxLower + 6);
    }
    return '12:00';
  }

  static String combineDateAndHm(String dateIso, String hm) {
    final parts = hm.split(':');
    final h = parts.isNotEmpty ? (int.tryParse(parts[0]) ?? 12).clamp(0, 23) : 12;
    final m = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0).clamp(0, 59) : 0;
    final local = DateTime(
      int.parse(dateIso.substring(0, 4)),
      int.parse(dateIso.substring(5, 7)),
      int.parse(dateIso.substring(8, 10)),
      h,
      m,
    );
    return Rfc3339.formatLocal(local);
  }
}
