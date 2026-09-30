import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';

import '../model/enums.dart';
import '../model/nutrients.dart';
import '../util/local_date.dart';

bool _initialized = false;

/// Loads the date symbols for German and English. Call once at startup.
Future<void> initializeFormatting() async {
  if (_initialized) return;
  await initializeDateFormatting('de_DE');
  await initializeDateFormatting('en_US');
  _initialized = true;
}

/// Locale-aware formatting of dates, times and numbers.
class Fmt {
  Fmt(this.language)
    : locale = language == AppLanguage.de ? 'de_DE' : 'en_US',
      _dayMonth = DateFormat.MMMd(
        language == AppLanguage.de ? 'de_DE' : 'en_US',
      ),
      _weekdayDayMonth = DateFormat.MMMEd(
        language == AppLanguage.de ? 'de_DE' : 'en_US',
      ),
      _full = DateFormat.yMMMMEEEEd(
        language == AppLanguage.de ? 'de_DE' : 'en_US',
      ),
      _medium = DateFormat.yMMMd(
        language == AppLanguage.de ? 'de_DE' : 'en_US',
      ),
      _monthYear = DateFormat.yMMMM(
        language == AppLanguage.de ? 'de_DE' : 'en_US',
      ),
      _weekdayShort = DateFormat.E(
        language == AppLanguage.de ? 'de_DE' : 'en_US',
      ),
      _time = language == AppLanguage.de
          ? DateFormat.Hm('de_DE')
          : DateFormat.jm('en_US');

  final AppLanguage language;
  final String locale;
  final DateFormat _dayMonth;
  final DateFormat _weekdayDayMonth;
  final DateFormat _full;
  final DateFormat _medium;
  final DateFormat _monthYear;
  final DateFormat _weekdayShort;
  final DateFormat _time;

  /// "23. Sept." / "Sep 23"
  String dayMonth(LocalDate d) => _dayMonth.format(d.toDateTime());

  /// "Mi., 23. Sept." / "Wed, Sep 23"
  String weekdayDayMonth(LocalDate d) => _weekdayDayMonth.format(d.toDateTime());

  /// "Mittwoch, 23. September 2026"
  String full(LocalDate d) => _full.format(d.toDateTime());

  /// "23.09.2026" style medium date: "23. Sept. 2026" / "Sep 23, 2026"
  String medium(LocalDate d) => _medium.format(d.toDateTime());

  /// "September 2026"
  String monthYear(LocalDate d) => _monthYear.format(d.toDateTime());

  /// Short weekday name for an ISO weekday (1 = Monday).
  String weekdayShort(int isoWeekday) {
    // 2024-01-01 was a Monday.
    return _weekdayShort.format(DateTime(2024, 1, isoWeekday));
  }

  /// Compact day-of-month axis label: "23." (de) / "23" (en).
  String dayOfMonth(LocalDate d) =>
      language == AppLanguage.de ? '${d.day}.' : '${d.day}';

  /// Compact numeric date: "23.9." (de) / "9/23" (en).
  String numericDayMonth(LocalDate d) =>
      language == AppLanguage.de ? '${d.day}.${d.month}.' : '${d.month}/${d.day}';

  /// Compact numeric month: "9/26" for September 2026 in both languages.
  String numericMonthYear(LocalDate d) => '${d.month}/${d.year % 100}';

  String time(int minutes) =>
      _time.format(DateTime(2024, 1, 1, minutes ~/ 60, minutes % 60));

  /// Number with up to [decimals] fraction digits (trailing zeros dropped).
  String number(double value, [int decimals = 1]) {
    final f = NumberFormat.decimalPattern(locale)
      ..minimumFractionDigits = 0
      ..maximumFractionDigits = decimals;
    return f.format(value);
  }

  /// Number with exactly [decimals] fraction digits.
  String fixed(double value, int decimals) {
    final f = NumberFormat.decimalPattern(locale)
      ..minimumFractionDigits = decimals
      ..maximumFractionDigits = decimals;
    return f.format(value);
  }

  String integer(num value) =>
      NumberFormat.decimalPattern(locale).format(value.round());

  /// Value with the nutrient's unit and display precision.
  String nutrient(Nutrient n, double value) {
    var decimals = n.decimals;
    // Show small amounts with more precision instead of "0".
    if (value > 0 && value < 1 && decimals < 2) decimals = 2;
    return '${number(value, decimals)} ${n.unit}';
  }

  String percent(double ratio) =>
      NumberFormat.percentPattern(locale).format(ratio);

  /// Parses user input with either decimal separator. Returns null for
  /// empty or invalid text.
  static double? parseNumber(String text) {
    var t = text.trim().replaceAll(' ', '');
    if (t.isEmpty) return null;
    // Accept "1.234,5" and "1,234.5" as well as simple "1,5" / "1.5".
    final lastComma = t.lastIndexOf(',');
    final lastDot = t.lastIndexOf('.');
    if (lastComma >= 0 && lastDot >= 0) {
      if (lastComma > lastDot) {
        t = t.replaceAll('.', '').replaceAll(',', '.');
      } else {
        t = t.replaceAll(',', '');
      }
    } else {
      t = t.replaceAll(',', '.');
    }
    if (!RegExp(r'^[+-]?(\d+\.?\d*|\.\d+)$').hasMatch(t)) return null;
    final v = double.tryParse(t);
    if (v == null || v.isNaN || v.isInfinite) return null;
    return v;
  }

  /// Formats a number for an input field (no grouping).
  String input(double value, [int decimals = 2]) {
    var s = value.toStringAsFixed(decimals);
    if (s.contains('.')) {
      s = s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '');
    }
    return language == AppLanguage.de ? s.replaceAll('.', ',') : s;
  }
}
