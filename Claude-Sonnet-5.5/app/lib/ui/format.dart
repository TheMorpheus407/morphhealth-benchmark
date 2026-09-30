import 'package:intl/intl.dart';

import '../core/civil.dart';
import '../core/nutrients.dart';

/// Zahlen, Datum und Uhrzeit in der Sprache der App (`de` oder `en`).
class Fmt {
  final String lang;
  late final NumberFormat _n0 = NumberFormat('#,##0', lang);
  late final NumberFormat _n1 = NumberFormat('#,##0.0', lang);
  late final NumberFormat _n2 = NumberFormat('#,##0.00', lang);
  late final NumberFormat _n3 = NumberFormat('#,##0.000', lang);

  Fmt(this.lang);

  bool get isEnglish => lang == 'en';

  /// Zahl mit fester Anzahl Nachkommastellen (0 bis 3), Tausendertrennung.
  String n(double v, [int decimals = 0]) {
    final f = switch (decimals) {
      0 => _n0,
      1 => _n1,
      2 => _n2,
      _ => _n3,
    };
    final s = f.format(v);
    return s == '-0' || s == '-0,0' || s == '-0.0' ? s.substring(1) : s;
  }

  /// Zahl ohne überflüssige Nullen, höchstens [maxDecimals] Stellen.
  String nTrim(double v, [int maxDecimals = 2]) {
    var s = n(v, maxDecimals);
    final sep = isEnglish ? '.' : ',';
    if (s.contains(sep)) {
      s = s.replaceFirst(RegExp('${RegExp.escape(sep)}?0+\$'), '');
    }
    return s;
  }

  /// Nährstoffwert mit den Stellen und der Einheit des Katalogs.
  String nutrient(double v, NutrientDef def) => '${n(v, def.decimals)} ${def.unit}';

  String kcal(double v) => '${n(v)} kcal';

  /// Eingabetext für ein Zahlenfeld (ohne Tausendertrennung).
  String input(double v, [int maxDecimals = 2]) {
    var s = v.toStringAsFixed(maxDecimals);
    if (s.contains('.')) s = s.replaceFirst(RegExp(r'\.?0+$'), '');
    return isEnglish ? s : s.replaceAll('.', ',');
  }

  /// Zahl aus Nutzereingabe: akzeptiert Komma und Punkt als Dezimaltrenner.
  static double? parse(String? text) {
    if (text == null) return null;
    var t = text.trim().replaceAll(RegExp(r'\s'), '');
    if (t.isEmpty) return null;
    if (t.contains(',') && t.contains('.')) {
      // Der zuletzt stehende Trenner ist der Dezimaltrenner.
      final lastComma = t.lastIndexOf(',');
      final lastDot = t.lastIndexOf('.');
      t = lastComma > lastDot ? t.replaceAll('.', '').replaceAll(',', '.') : t.replaceAll(',', '');
    } else {
      t = t.replaceAll(',', '.');
    }
    final v = double.tryParse(t);
    if (v == null || v.isNaN || v.isInfinite) return null;
    return v;
  }

  DateFormat get _dateFmt => isEnglish ? DateFormat('MMM d, y', lang) : DateFormat('dd.MM.yyyy', lang);

  /// `29.09.2026` beziehungsweise `Sep 29, 2026`.
  String date(Day d) => _dateFmt.format(d.toDateTime());

  /// `Di., 29.09.2026` beziehungsweise `Tue, Sep 29, 2026`.
  String dateWithWeekday(Day d) => isEnglish
      ? DateFormat('EEE, MMM d, y', lang).format(d.toDateTime())
      : DateFormat('EEE, dd.MM.yyyy', lang).format(d.toDateTime());

  /// `Dienstag, 29. September 2026`.
  String dateLong(Day d) => isEnglish
      ? DateFormat('EEEE, MMMM d, y', lang).format(d.toDateTime())
      : DateFormat('EEEE, d. MMMM y', lang).format(d.toDateTime());

  /// `29.09.` beziehungsweise `Sep 29`.
  String dayMonth(Day d) =>
      isEnglish ? DateFormat('MMM d', lang).format(d.toDateTime()) : DateFormat('dd.MM.', lang).format(d.toDateTime());

  /// `September 2026`.
  String monthYear(Day d) => DateFormat('MMMM y', lang).format(d.toDateTime());

  /// Kurzer Wochentag: `Di.` beziehungsweise `Tue`.
  String weekdayShort(Day d) => DateFormat('EEE', lang).format(d.toDateTime());

  /// Kürzester Wochentag für Kalenderköpfe: `D` beziehungsweise `T`.
  String weekdayNarrow(Day d) => DateFormat('EEEEE', lang).format(d.toDateTime());

  /// Uhrzeit: `08:15` beziehungsweise `8:15 AM`.
  String time(LocalDateTime t) =>
      isEnglish ? DateFormat('h:mm a', lang).format(t.toDateTime()) : DateFormat('HH:mm', lang).format(t.toDateTime());

  String timeOfHm(int h, int m) => time(LocalDateTime(Day(2000, 1, 1), h, m));

  /// Datum und Uhrzeit.
  String dateTime(LocalDateTime t) => '${date(t.day)}, ${time(t)}';
}
