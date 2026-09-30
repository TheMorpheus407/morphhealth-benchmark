import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/civil.dart';
import '../../core/models.dart';
import '../l10n_x.dart';

/// Was der Kalender an einem Tag zeigt.
final class DayMark {
  /// Der Tag liegt in einer erfassten Periode (mit Stärke, falls angegeben).
  final bool inPeriod;
  final FlowLevel? flow;

  /// Voraussichtlicher Periodentag (nur Zukunft, gestrichelt).
  final bool predicted;

  /// Im wahrscheinlichen Zeitfenster.
  final bool window;

  /// Es gibt Symptomeinträge.
  final bool symptoms;

  const DayMark({this.inPeriod = false, this.flow, this.predicted = false, this.window = false, this.symptoms = false});

  static const DayMark none = DayMark();
}

/// Monatskalender (Woche beginnt am Montag) mit Markierungen für Perioden,
/// Prognose und Symptome.
class MonthCalendar extends StatelessWidget {
  final Day month;
  final Day today;
  final Day selected;
  final DayMark Function(Day) markOf;
  final ValueChanged<Day> onSelect;
  final ValueChanged<Day> onMonthChanged;
  final Color color;

  const MonthCalendar({
    super.key,
    required this.month,
    required this.today,
    required this.selected,
    required this.markOf,
    required this.onSelect,
    required this.onMonthChanged,
    required this.color,
  });

  Future<void> _pickMonth(BuildContext context) async {
    final d = await showDatePicker(
      context: context,
      initialDate: month.toDateTime(),
      firstDate: DateTime(2000),
      lastDate: today.addDays(366 * 3).toDateTime(),
      initialDatePickerMode: DatePickerMode.year,
      helpText: context.l10n.cycleMonthPick,
    );
    if (d != null) onMonthChanged(Day.fromDateTime(d).firstOfMonth);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final f = context.fmt;
    final first = month.firstOfMonth;
    final lead = first.weekday - 1; // Montag = 0
    final rows = ((lead + first.daysInMonth) / 7).ceil();
    final weekdayRow = [for (var i = 0; i < 7; i++) Day(2024, 1, 1).addDays(i)]; // 1.1.2024 war ein Montag
    return GestureDetector(
      onHorizontalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (v < -200) onMonthChanged(first.addMonths(1));
        if (v > 200) onMonthChanged(first.addMonths(-1));
      },
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: l.cycleMonthPrev,
                icon: const Icon(Icons.chevron_left),
                onPressed: () => onMonthChanged(first.addMonths(-1)),
              ),
              Expanded(
                child: Semantics(
                  button: true,
                  label: '${f.monthYear(first)}. ${l.cycleMonthPick}',
                  excludeSemantics: true,
                  onTap: () => _pickMonth(context),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => _pickMonth(context),
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 48),
                      child: Center(
                        child: Text(
                          f.monthYear(first),
                          style: context.text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: l.cycleMonthNext,
                icon: const Icon(Icons.chevron_right),
                onPressed: () => onMonthChanged(first.addMonths(1)),
              ),
            ],
          ),
          ExcludeSemantics(
            child: Row(
              children: [
                for (final d in weekdayRow)
                  Expanded(
                    child: Center(
                      child: Text(
                        f.weekdayShort(d),
                        style: context.text.labelSmall?.copyWith(color: context.colors.onSurfaceVariant),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          for (var r = 0; r < rows; r++)
            Row(
              children: [
                for (var c = 0; c < 7; c++)
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final index = r * 7 + c - lead;
                        if (index < 0 || index >= first.daysInMonth) return const SizedBox(height: 52);
                        final d = first.addDays(index);
                        return _DayCell(
                          day: d,
                          today: today,
                          selected: selected,
                          mark: markOf(d),
                          color: color,
                          onTap: () => onSelect(d),
                        );
                      },
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _DayCell extends StatelessWidget {
  final Day day;
  final Day today;
  final Day selected;
  final DayMark mark;
  final Color color;
  final VoidCallback onTap;

  const _DayCell({
    required this.day,
    required this.today,
    required this.selected,
    required this.mark,
    required this.color,
    required this.onTap,
  });

  double get _alpha => switch (mark.flow) {
    FlowLevel.heavy => 1.0,
    FlowLevel.medium => 0.8,
    FlowLevel.light => 0.55,
    FlowLevel.spotting => 0.35,
    null => 0.7,
  };

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final f = context.fmt;
    final cs = context.colors;
    final isSel = day == selected;
    final isToday = day == today;
    final period = mark.inPeriod;
    final fill = period ? color.withValues(alpha: _alpha) : Colors.transparent;
    final onFill = period && _alpha > 0.5
        ? (ThemeData.estimateBrightnessForColor(color) == Brightness.dark ? Colors.white : Colors.black)
        : cs.onSurface;
    final label = [
      f.dateLong(day),
      if (period) mark.flow == null ? l.cycleLegendPeriod : '${l.cycleLegendPeriod}, ${l.flow(mark.flow)}',
      if (mark.predicted) l.cycleDayPredicted,
      if (mark.symptoms) l.cycleLegendSymptom,
      if (isToday) l.cycleLegendToday,
    ].join(', ');
    return Semantics(
      button: true,
      selected: isSel,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(26),
        child: Container(
          height: 52,
          alignment: Alignment.center,
          color: mark.window && !period ? color.withValues(alpha: 0.10) : null,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (mark.predicted && !period)
                CustomPaint(
                  size: const Size(38, 38),
                  painter: _DashedCircle(color: color),
                ),
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: fill,
                  border: isSel
                      ? Border.all(color: cs.primary, width: 2.5)
                      : (isToday ? Border.all(color: cs.onSurface, width: 1.2) : null),
                ),
                child: Text(
                  '${day.day}',
                  style: context.text.bodyMedium?.copyWith(
                    color: onFill,
                    fontWeight: isToday || isSel || period ? FontWeight.w700 : FontWeight.normal,
                  ),
                ),
              ),
              if (mark.symptoms)
                Positioned(
                  bottom: 2,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(color: cs.tertiary, shape: BoxShape.circle),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedCircle extends CustomPainter {
  final Color color;

  _DashedCircle({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8;
    final r = size.width / 2 - 1;
    const dashes = 14;
    for (var i = 0; i < dashes; i++) {
      final a0 = 2 * math.pi * i / dashes;
      canvas.drawArc(Rect.fromCircle(center: size.center(Offset.zero), radius: r), a0, math.pi / dashes, false, p);
    }
  }

  @override
  bool shouldRepaint(_DashedCircle old) => old.color != color;
}
