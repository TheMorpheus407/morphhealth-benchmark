import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:morphhealth_core/morphhealth_core.dart';

import '../l10n/strings.dart';

/// Formats dates, times, numbers and amounts for the current language.
class Fmt {
  final String locale;
  final L l;
  final bool use24h;
  final Day today;

  const Fmt({
    required this.locale,
    required this.l,
    required this.use24h,
    required this.today,
  });

  /// The formatter for the locale and settings of [context].
  factory Fmt.of(BuildContext context, {required Day today}) => Fmt(
    locale: Localizations.localeOf(context).toString(),
    l: L.of(context),
    use24h:
        MediaQuery.alwaysUse24HourFormatOf(context) ||
        Localizations.localeOf(context).languageCode == 'de',
    today: today,
  );

  static final Map<String, DateFormat> _dateFormats = {};
  static final Map<String, NumberFormat> _numberFormats = {};

  DateFormat _df(String skeleton) =>
      _dateFormats['$locale|$skeleton'] ??= DateFormat(skeleton, locale);

  DateFormat _named(String key, DateFormat Function() create) =>
      _dateFormats['$locale|$key'] ??= create();

  // --------------------------------------------------------------- dates

  /// "Mo., 9. Nov." / "Mon, 9 Nov".
  String day(Day d) =>
      _named('MMMEd', () => DateFormat.MMMEd(locale)).format(d.toDateTime());

  /// "Montag, 9. November 2026" / "Monday, 9 November 2026".
  String dayLong(Day d) => _named(
    'yMMMMEEEEd',
    () => DateFormat.yMMMMEEEEd(locale),
  ).format(d.toDateTime());

  /// "Montag, 9. November".
  String dayLongNoYear(Day d) => _named(
    'MMMMEEEEd',
    () => DateFormat.MMMMEEEEd(locale),
  ).format(d.toDateTime());

  /// "9. Nov. 2026" / "9 Nov 2026".
  String date(Day d) =>
      _named('yMMMd', () => DateFormat.yMMMd(locale)).format(d.toDateTime());

  /// "9. Nov." / "9 Nov".
  String dateShort(Day d) =>
      _named('MMMd', () => DateFormat.MMMd(locale)).format(d.toDateTime());

  /// "9. November".
  String dateMonthLong(Day d) =>
      _named('MMMMd', () => DateFormat.MMMMd(locale)).format(d.toDateTime());

  /// Like [dateShort], with the year when it is not the current one.
  String dateCompact(Day d) => d.year == today.year ? dateShort(d) : date(d);

  /// "November 2026".
  String month(Day d) =>
      _named('yMMMM', () => DateFormat.yMMMM(locale)).format(d.toDateTime());

  /// "Heute", "Gestern", "Morgen" or [day].
  String dayRelative(Day d) {
    final diff = d.daysSince(today);
    if (diff == 0) return l.today;
    if (diff == -1) return l.yesterday;
    if (diff == 1) return l.tomorrow;
    return d.year == today.year ? day(d) : '${day(d)} ${d.year}';
  }

  /// "Heute, 9. Nov." for nearby days, otherwise the weekday form.
  String dayHeadline(Day d) {
    final diff = d.daysSince(today);
    if (diff >= -1 && diff <= 1) return '${dayRelative(d)}, ${dateShort(d)}';
    return dayRelative(d);
  }

  /// "16. – 20. Sept. 2026".
  String range(Day from, Day to) {
    if (from == to) return dateCompact(from);
    if (from.year == to.year && from.month == to.month) {
      final a = _df('d').format(from.toDateTime());
      return locale.startsWith('de')
          ? '$a. – ${dateCompact(to)}'
          : '$a – ${dateCompact(to)}';
    }
    return '${from.year == to.year ? dateShort(from) : date(from)} – '
        '${dateCompact(to)}';
  }

  /// Abbreviated weekday names ("Mo.", "Mon"), starting with [firstWeekday]
  /// (1 = Monday … 7 = Sunday).
  List<String> weekdayNames(int firstWeekday, {bool long = false}) {
    final f = _df(long ? 'EEEE' : 'EEE');
    // 2024-01-01 is a Monday.
    return [
      for (var i = 0; i < 7; i++)
        f.format(DateTime(2024, 1, 1 + (firstWeekday - 1 + i) % 7)),
    ];
  }

  String time(LocalDateTime t) => use24h
      ? t.hhmm
      : _named('jm', () => DateFormat.jm(locale)).format(t.toDateTime());

  String dateTime(LocalDateTime t) => '${dayRelative(t.day)}, ${time(t)}';

  // ------------------------------------------------------------- numbers

  NumberFormat _nf(int min, int max) => _numberFormats['$locale|$min|$max'] ??=
      (NumberFormat.decimalPattern(locale)
        ..minimumFractionDigits = min
        ..maximumFractionDigits = max);

  /// [v] with at most [decimals] decimals and grouping.
  String number(num v, {int decimals = 1, int minDecimals = 0}) =>
      _nf(minDecimals, decimals).format(v);

  /// A number for an input field: no grouping, decimal comma in German.
  String editable(num v, {int decimals = 2}) {
    final s = (NumberFormat('0.${'#' * decimals}', locale)).format(v);
    return s;
  }

  /// Parses user input; accepts comma and point as decimal separator.
  static double? parse(String input) {
    var s = input.trim().replaceAll(' ', '').replaceAll(' ', '');
    if (s.isEmpty) return null;
    if (s.contains(',') && s.contains('.')) {
      // "1.234,5" or "1,234.5": the last separator is the decimal one.
      final decimalComma = s.lastIndexOf(',') > s.lastIndexOf('.');
      s = decimalComma
          ? s.replaceAll('.', '').replaceAll(',', '.')
          : s.replaceAll(',', '');
    } else {
      s = s.replaceAll(',', '.');
    }
    final v = double.tryParse(s);
    return v == null || v.isNaN || v.isInfinite ? null : v;
  }

  /// Picks decimals so that small amounts stay readable: 0.05, 2.5, 13, 240.
  String adaptive(double v) {
    final a = v.abs();
    if (a == 0) return '0';
    if (a >= 100) return number(v, decimals: 0);
    if (a >= 10) return number(v, decimals: 1);
    if (a >= 1) return number(v, decimals: 1);
    return number(v, decimals: 2);
  }

  String kcal(double v) => '${number(v, decimals: v.abs() < 10 ? 1 : 0)} kcal';

  String kcalNumber(double v) => number(v, decimals: v.abs() < 10 ? 1 : 0);

  /// Amount of [n] with its unit; [approximate] adds "≈".
  String nutrient(Nutrient n, double v, {bool approximate = false}) =>
      '${approximate ? '≈ ' : ''}${n == Nutrients.energy ? kcalNumber(v) : adaptive(v)} ${n.unit}';

  /// "250 ml" or "1,2 l".
  String volume(double ml) => ml >= 1000
      ? '${number(ml / 1000, decimals: 2)} l'
      : '${number(ml, decimals: 0)} ml';

  String ml(double v) => '${number(v, decimals: 0)} ml';

  String mg(double v) => '${number(v, decimals: 0)} mg';

  /// Weight in the user's unit ("kg" or "lb").
  String weight(double kg, String unit) =>
      '${number(weightValue(kg, unit), decimals: 1, minDecimals: 1)} $unit';

  static double weightValue(double kg, String unit) =>
      unit == 'lb' ? kg / WeightEntry.kgPerLb : kg;

  static double weightToKg(double value, String unit) =>
      unit == 'lb' ? value * WeightEntry.kgPerLb : value;

  /// Signed weight difference, e.g. "−0,4 kg".
  String weightChange(double deltaKg, String unit) {
    final v = weightValue(deltaKg, unit);
    final sign = v > 0.049 ? '+' : (v < -0.049 ? '−' : '±');
    return '$sign${number(v.abs(), decimals: 1, minDecimals: 1)} $unit';
  }

  /// "60 g", "200 ml" or "2 Portionen (100 g)".
  String intakeAmount(IntakeEntry e, Food? food) {
    switch (e.unit) {
      case AmountUnit.g:
        return '${adaptive(e.amount)} g';
      case AmountUnit.ml:
        return '${adaptive(e.amount)} ml';
      case AmountUnit.portion:
        final text = l.portions(adaptive(e.amount), e.amount == 1);
        final size = e.portionSize ?? food?.servingSize;
        if (size == null || food == null) return text;
        return '$text (${adaptive(e.amount * size)} ${food.basis.unit})';
    }
  }

  String basis(FoodBasis b) => b == FoodBasis.per100g ? '100 g' : '100 ml';

  String percent(double fraction) => '${number(fraction * 100, decimals: 0)} %';
}
