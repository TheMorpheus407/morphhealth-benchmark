// Gemeinsame UI-Komponenten: Karten, Nährwerttabellen, Picker, Diagramme,
// Dialoge. Alle Texte laufen über StringsScope (de/en).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/parse.dart';
import '../l10n/app_strings.dart';
import '../model/cycle.dart';
import '../model/entries.dart';
import '../nutrients/nutrients.dart';
import 'scope.dart';

// ------------------------------------------------------------------ Karten

/// Karte mit Abschnittstitel und optionalem Trailing-Widget.
class SectionCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
    this.padding = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    final Widget? trailingWidget = trailing;
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(title,
                      style: Theme.of(context).textTheme.titleMedium),
                ),
                ?trailingWidget,
              ],
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}

/// Leerzustand mit Icon und Text.
class EmptyState extends StatelessWidget {
  final IconData icon;
  final String text;

  const EmptyState({super.key, required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    final Color hint = Theme.of(context).colorScheme.onSurfaceVariant;
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 40, color: hint),
          const SizedBox(height: 8),
          Text(text,
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: hint)),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ Nährwerte

/// Eine Zeile: Nährstoffname + formatierter Wert.
class NutrientRow extends StatelessWidget {
  final String name;
  final String value;

  const NutrientRow({super.key, required this.name, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(name)),
          Text(value,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

/// Vollständige Nährwerttabelle (31 Nährstoffe, gruppiert).
class NutrientTable extends StatelessWidget {
  final Map<String, double> values;

  const NutrientTable({super.key, required this.values});

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = StringsScope.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        _group(strings, strings.mainNutrients, mainNutrients),
        _group(strings, strings.vitamins, vitaminNutrients),
        _group(strings, strings.minerals, mineralNutrients),
      ],
    );
  }

  Widget _group(AppStrings strings, String title, List<NutrientDef> defs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: 10, bottom: 4),
          child: Text(title,
              style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        for (final NutrientDef d in defs)
          NutrientRow(
            name: strings.nutrientName(d.key),
            value: strings.nutrientAmount(d.key, values[d.key] ?? 0),
          ),
      ],
    );
  }
}

/// Zeile mit Kennzahl (z. B. „Kalorien“ + „1.850 kcal“).
class StatRow extends StatelessWidget {
  final String label;
  final String value;

  const StatRow({super.key, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: <Widget>[
          Expanded(child: Text(label)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ Picker

/// Mahlzeiten-Picker.
class MealPicker extends StatelessWidget {
  final Meal value;
  final ValueChanged<Meal> onChanged;

  const MealPicker({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = StringsScope.of(context);
    return DropdownButtonFormField<Meal>(
      initialValue: value,
      decoration: InputDecoration(labelText: strings.mealLabel),
      items: <DropdownMenuItem<Meal>>[
        for (final Meal m in Meal.values)
          DropdownMenuItem<Meal>(
              value: m, child: Text(strings.mealName(m))),
      ],
      onChanged: (Meal? v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

/// Mengeneinheiten-Picker.
class QuantityUnitPicker extends StatelessWidget {
  final QuantityUnit value;
  final ValueChanged<QuantityUnit> onChanged;

  const QuantityUnitPicker(
      {super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = StringsScope.of(context);
    return DropdownButtonFormField<QuantityUnit>(
      initialValue: value,
      decoration: InputDecoration(labelText: strings.unitLabel),
      items: <DropdownMenuItem<QuantityUnit>>[
        for (final QuantityUnit u in QuantityUnit.values)
          DropdownMenuItem<QuantityUnit>(
              value: u, child: Text(strings.quantityUnitName(u))),
      ],
      onChanged: (QuantityUnit? v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

/// Blutungsstärke-Picker.
class FlowPicker extends StatelessWidget {
  final FlowLevel value;
  final ValueChanged<FlowLevel> onChanged;

  const FlowPicker({super.key, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = StringsScope.of(context);
    return DropdownButtonFormField<FlowLevel>(
      initialValue: value,
      decoration: InputDecoration(labelText: strings.flowLabel),
      items: <DropdownMenuItem<FlowLevel>>[
        for (final FlowLevel f in FlowLevel.values)
          DropdownMenuItem<FlowLevel>(
              value: f, child: Text(strings.flowName(f))),
      ],
      onChanged: (FlowLevel? v) {
        if (v != null) onChanged(v);
      },
    );
  }
}

// ------------------------------------------------------------------ Dialoge

/// Bestätigungsdialog zum Löschen.
Future<bool> confirmDelete(BuildContext context, {String? message}) async {
  final AppStrings strings = StringsScope.of(context);
  final bool? result = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      title: Text(strings.confirmDeleteTitle),
      content: Text(message ?? strings.confirmDeleteMessage),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(strings.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(strings.delete),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Allgemeiner Bestätigungsdialog (Ja/Nein).
Future<bool> confirmAction(
  BuildContext context, {
  required String title,
  required String message,
  String? confirmLabel,
}) async {
  final AppStrings strings = StringsScope.of(context);
  final bool? result = await showDialog<bool>(
    context: context,
    builder: (BuildContext context) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(strings.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel ?? strings.ok),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Datumsauswahl (mit de/en-Lokalisierung der Material-Picker).
Future<DateTime?> pickDate(
  BuildContext context, {
  required DateTime initial,
  DateTime? first,
  DateTime? last,
}) async {
  return showDatePicker(
    context: context,
    initialDate: initial,
    firstDate: first ?? DateTime(2000, 1, 1),
    lastDate: last ?? DateTime(2100, 12, 31),
    locale: Localizations.localeOf(context),
  );
}

/// Uhrzeitauswahl.
Future<TimeOfDay?> pickTime(BuildContext context,
    {required TimeOfDay initial}) async {
  return showTimePicker(
    context: context,
    initialTime: initial,
  );
}

/// Datumsnavigation (vor/zurück + Antippen zum Auswählen).
class DayNavHeader extends StatelessWidget {
  final DateTime date;
  final ValueChanged<DateTime> onDateChanged;

  const DayNavHeader(
      {super.key, required this.date, required this.onDateChanged});

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = StringsScope.of(context);
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: <Widget>[
          IconButton(
            tooltip: strings.yesterday,
            onPressed: () =>
                onDateChanged(date.subtract(const Duration(days: 1))),
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: TextButton(
              onPressed: () async {
                final DateTime? picked = await pickDate(context,
                    initial: date, first: DateTime(2000, 1, 1));
                if (picked != null) {
                  onDateChanged(DateTime(picked.year, picked.month, picked.day));
                }
              },
              child: Text(
                strings.formatDateLong(date),
                style: theme.textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
            ),
          ),
          IconButton(
            tooltip: strings.tomorrow,
            onPressed: () => onDateChanged(date.add(const Duration(days: 1))),
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}

/// Schnellauswahl für häufige Mengen (z. B. Wassergläser).
class AmountChips extends StatelessWidget {
  final List<double> amounts;
  final String Function(double amount) format;
  final ValueChanged<double> onSelected;

  const AmountChips({
    super.key,
    required this.amounts,
    required this.format,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: <Widget>[
        for (final double a in amounts)
          ActionChip(
            label: Text(format(a)),
            onPressed: () => onSelected(a),
          ),
      ],
    );
  }
}

/// Dezimalzahlen-Eingabefeld (lokalisiert: de „1,5“, en „1.5“).
class NumberField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? hint;
  final bool allowNegative;
  final ValueChanged<String>? onSubmitted;

  const NumberField({
    super.key,
    required this.controller,
    required this.label,
    this.hint,
    this.allowNegative = false,
    this.onSubmitted,
  });

  /// Parst den Feldinhalt lokalisiert. Liefert null bei ungültiger Eingabe.
  static double? parse(AppStrings strings, String text) {
    final String t = text.trim().replaceAll(' ', '');
    if (t.isEmpty) return null;
    final String normalized =
        strings.lang == 'de' ? t.replaceAll('.', '').replaceAll(',', '.') : t;
    return double.tryParse(normalized);
  }

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(labelText: label, hintText: hint),
      keyboardType:
          const TextInputType.numberWithOptions(decimal: true, signed: true),
      inputFormatters: <TextInputFormatter>[
        FilteringTextInputFormatter.allow(
            allowNegative ? RegExp(r'[0-9.,\-]') : RegExp(r'[0-9.,]')),
      ],
      onSubmitted: onSubmitted,
    );
  }
}

// ------------------------------------------------------------------ Diagramme

/// Einfaches Balkendiagramm (Tageswerte) als CustomPaint.
class BarChart extends StatelessWidget {
  final List<double> values;
  final List<String> labels;
  final String? unit;
  final double height;

  const BarChart({
    super.key,
    required this.values,
    required this.labels,
    this.unit,
    this.height = 160,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return CustomPaint(
          size: Size(constraints.maxWidth, height),
          painter: _BarChartPainter(
            values: values,
            labels: labels,
            unit: unit,
            color: theme.colorScheme.primary,
            textColor: theme.colorScheme.onSurface,
          ),
        );
      },
    );
  }
}

class _BarChartPainter extends CustomPainter {
  final List<double> values;
  final List<String> labels;
  final String? unit;
  final Color color;
  final Color textColor;

  _BarChartPainter({
    required this.values,
    required this.labels,
    required this.unit,
    required this.color,
    required this.textColor,
  });

  static String _fmt(double v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}k';
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v.toStringAsFixed(1);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    double maxV = 0;
    for (final double v in values) {
      if (v > maxV) maxV = v;
    }
    final double top = maxV <= 0 ? 1 : maxV * 1.18;
    const double chartTop = 20;
    const double labelHeight = 16;
    final double chartBottom = size.height - labelHeight;
    final double chartHeight = chartBottom - chartTop;
    final double slot = size.width / values.length;
    final double barWidth = slot * 0.62;
    final Paint barPaint = Paint()..color = color;
    final Paint gridPaint = Paint()
      ..color = textColor.withValues(alpha: 0.18)
      ..strokeWidth = 1;
    canvas.drawLine(
        Offset(0, chartTop), Offset(size.width, chartTop), gridPaint);
    for (int i = 0; i < values.length; i++) {
      final double v = values[i];
      final double h = v <= 0 ? 0 : (v / top) * chartHeight;
      final double left = i * slot + (slot - barWidth) / 2;
      if (h > 0) {
        final Rect rect =
            Rect.fromLTWH(left, chartBottom - h, barWidth, h);
        canvas.drawRRect(
            RRect.fromRectAndRadius(rect, const Radius.circular(3)),
            barPaint);
      }
      final String label = i < labels.length ? labels[i] : '';
      final TextPainter tp = TextPainter(
        text: TextSpan(
          text: label,
          style: TextStyle(
              color: textColor.withValues(alpha: 0.7), fontSize: 9),
        ),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas,
          Offset(i * slot + (slot - tp.width) / 2, chartBottom + 3));
    }
    final TextPainter maxTp = TextPainter(
      text: TextSpan(
        text: unit == null ? _fmt(maxV) : '${_fmt(maxV)} $unit',
        style: TextStyle(color: textColor, fontSize: 10),
      ),
      textDirection: TextDirection.ltr,
    );
    maxTp.layout();
    maxTp.paint(canvas, const Offset(0, 2));
  }

  @override
  bool shouldRepaint(covariant _BarChartPainter oldDelegate) => true;
}

/// Einfaches Liniendiagramm (z. B. Gewichtsverlauf) als CustomPaint.
class LineChart extends StatelessWidget {
  final List<double> values;
  final List<String> labels;
  final String? unit;
  final double height;

  const LineChart({
    super.key,
    required this.values,
    required this.labels,
    this.unit,
    this.height = 160,
  });

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        return CustomPaint(
          size: Size(constraints.maxWidth, height),
          painter: _LineChartPainter(
            values: values,
            labels: labels,
            unit: unit,
            color: theme.colorScheme.primary,
            textColor: theme.colorScheme.onSurface,
          ),
        );
      },
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<double> values;
  final List<String> labels;
  final String? unit;
  final Color color;
  final Color textColor;

  _LineChartPainter({
    required this.values,
    required this.labels,
    required this.unit,
    required this.color,
    required this.textColor,
  });

  static String _fmt(double v) {
    if (v == v.roundToDouble()) return v.toStringAsFixed(0);
    return v.toStringAsFixed(1);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    double minV = values.first;
    double maxV = values.first;
    for (final double v in values) {
      if (v < minV) minV = v;
      if (v > maxV) maxV = v;
    }
    if (maxV - minV < 1e-9) {
      minV -= 1;
      maxV += 1;
    } else {
      final double pad = (maxV - minV) * 0.15;
      minV -= pad;
      maxV += pad;
    }
    const double chartTop = 20;
    const double labelHeight = 16;
    final double chartBottom = size.height - labelHeight;
    final double chartHeight = chartBottom - chartTop;
    final double slot = size.width / (values.length - 1);
    final Paint linePaint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
    final Paint dotPaint = Paint()..color = color;
    final Paint gridPaint = Paint()
      ..color = textColor.withValues(alpha: 0.18)
      ..strokeWidth = 1;

    double yOf(double v) => chartBottom - ((v - minV) / (maxV - minV)) * chartHeight;
    double xOf(int i) => i * slot;

    canvas.drawLine(Offset(0, chartTop), Offset(size.width, chartTop), gridPaint);
    canvas.drawLine(
        Offset(0, chartBottom), Offset(size.width, chartBottom), gridPaint);

    final Path path = Path();
    for (int i = 0; i < values.length; i++) {
      final Offset p = Offset(xOf(i), yOf(values[i]));
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(path, linePaint);
    for (int i = 0; i < values.length; i++) {
      canvas.drawCircle(Offset(xOf(i), yOf(values[i])), 3, dotPaint);
    }
    // Beschriftung erstes/letztes Label + Max/Min
    void drawLabel(String text, Offset offset, {bool bold = false}) {
      final TextPainter tp = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(
            color: textColor,
            fontSize: 10,
            fontWeight: bold ? FontWeight.bold : FontWeight.normal,
          ),
        ),
        textDirection: TextDirection.ltr,
      );
      tp.layout();
      tp.paint(canvas, offset);
    }

    drawLabel(
        unit == null ? _fmt(maxV) : '${_fmt(maxV)} $unit', const Offset(0, 2),
        bold: true);
    drawLabel(unit == null ? _fmt(minV) : '${_fmt(minV)} $unit',
        Offset(0, chartBottom - 12));
    final String firstLabel = labels.isNotEmpty ? labels.first : '';
    final String lastLabel =
        labels.isNotEmpty ? labels[labels.length - 1] : '';
    drawLabel(firstLabel, Offset(0, chartBottom + 3));
    final TextPainter lastTp = TextPainter(
      text: TextSpan(
          text: lastLabel,
          style: TextStyle(
              color: textColor.withValues(alpha: 0.7), fontSize: 9)),
      textDirection: TextDirection.ltr,
    );
    lastTp.layout();
    lastTp.paint(canvas,
        Offset(size.width - lastTp.width, chartBottom + 3));
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) => true;
}

// ------------------------------------------------------------------ misc

/// „Heute“-Chip zur schnellen Rückkehr.
class TodayChip extends StatelessWidget {
  final DateTime today;
  final DateTime date;
  final ValueChanged<DateTime> onSelected;

  const TodayChip({
    super.key,
    required this.today,
    required this.date,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = StringsScope.of(context);
    final bool isToday = formatDate(date) == formatDate(today);
    if (isToday) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Align(
        alignment: Alignment.center,
        child: ActionChip(
          label: Text(strings.today),
          onPressed: () => onSelected(today),
        ),
      ),
    );
  }
}

/// SnackBar mit Fehlermeldung.
void showError(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
  );
}

/// SnackBar mit Erfolgmeldung.
void showInfo(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
  );
}
