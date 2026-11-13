import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:morphhealth_core/morphhealth_core.dart';

import '../../controller.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// What the cycle calendar knows about one day.
class CycleDayInfo {
  final Day day;

  /// The recorded period that covers the day.
  final Period? period;
  final FlowLevel? flow;

  /// The day lies in an estimated period (only for days after today).
  final bool expected;

  /// The day lies in the window in which an estimated period may start.
  final bool possibleStart;
  final bool spotting;
  final bool hasNote;
  final int symptomCount;

  const CycleDayInfo({
    required this.day,
    this.period,
    this.flow,
    this.expected = false,
    this.possibleStart = false,
    this.spotting = false,
    this.hasNote = false,
    this.symptomCount = 0,
  });

  factory CycleDayInfo.of(AppController app, Day day) {
    final data = app.data;
    final today = app.today;
    final period = day <= today ? data.periodOn(day, today) : null;
    var expected = false;
    var possibleStart = false;
    if (period == null && day >= today && app.settings.cyclePredictions) {
      for (final p in app.forecast.predictedPeriods) {
        if (p.isExpectedDay(day) && day > today) expected = true;
        if (p.isInStartWindow(day)) possibleStart = true;
      }
    }
    final cycleDay = data.cycleDay(day);
    return CycleDayInfo(
      day: day,
      period: period,
      flow: period?.flow[day],
      expected: expected,
      possibleStart: possibleStart,
      spotting: cycleDay?.spotting ?? false,
      hasNote: (cycleDay?.note ?? '').isNotEmpty,
      symptomCount: data.symptomsOn(day).length,
    );
  }
}

/// A month grid of the cycle: recorded periods, estimates and symptoms.
///
/// Every state is shown by shape as well as colour: recorded period days are
/// filled, expected days have a dashed ring, possible start days a short bar
/// below the number, symptoms a dot in the corner.
class MonthCalendar extends StatelessWidget {
  /// Any day of the month to show.
  final Day month;
  final Day selected;
  final ValueChanged<Day> onSelect;

  const MonthCalendar({
    super.key,
    required this.month,
    required this.selected,
    required this.onSelect,
  });

  static const double cellHeight = 50;

  /// Height of the grid for six weeks plus the weekday row.
  static const double height = 6 * cellHeight + 30;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final fmt = context.fmt;
    final first = month.firstOfMonth;
    final firstWeekday =
        (MaterialLocalizations.of(context).firstDayOfWeekIndex + 6) % 7 + 1;
    final lead = (first.weekday - firstWeekday + 7) % 7;
    final days = first.daysInMonth;
    final rows = ((lead + days) / 7).ceil();
    final names = fmt.weekdayNames(firstWeekday);

    return Column(
      children: [
        SizedBox(
          height: 30,
          child: ExcludeSemantics(
            child: Row(
              children: [
                for (final n in names)
                  Expanded(
                    child: Center(
                      child: Text(
                        n,
                        style: context.texts.labelMedium?.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        for (var r = 0; r < rows; r++)
          SizedBox(
            height: cellHeight,
            child: Row(
              children: [
                for (var c = 0; c < 7; c++)
                  Expanded(
                    child: Builder(
                      builder: (context) {
                        final index = r * 7 + c - lead;
                        if (index < 0 || index >= days) {
                          return const SizedBox.shrink();
                        }
                        final day = first.addDays(index);
                        return _DayCell(
                          info: CycleDayInfo.of(app, day),
                          isToday: day == app.today,
                          isSelected: day == selected,
                          onTap: () => onSelect(day),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  final CycleDayInfo info;
  final bool isToday;
  final bool isSelected;
  final VoidCallback onTap;

  const _DayCell({
    required this.info,
    required this.isToday,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final fmt = context.fmt;
    final scheme = context.colors;
    final colors = MhColors.of(context);
    final inPeriod = info.period != null;
    final light = info.flow == FlowLevel.spotting;

    final Color? fill = inPeriod
        ? (light ? colors.periodContainer : colors.period)
        : null;
    final Color textColor = inPeriod
        ? (light ? colors.onPeriodContainer : colors.onPeriod)
        : scheme.onSurface;

    final label = [
      fmt.dayLongNoYear(info.day),
      if (inPeriod) l.semPeriodDay,
      if (info.flow != null) l.flow(info.flow!),
      if (info.expected) l.semExpected,
      if (info.possibleStart && !info.expected) l.semWindow,
      if (info.spotting) l.semSpotting,
      if (info.symptomCount > 0) l.semSymptoms,
      if (info.hasNote) l.semNote,
      if (isToday) l.semToday,
    ].join(', ');

    final dots = switch (info.flow) {
      FlowLevel.light => 1,
      FlowLevel.medium => 2,
      FlowLevel.heavy => 3,
      _ => 0,
    };

    return Semantics(
      button: true,
      selected: isSelected,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Center(
          child: SizedBox(
            width: 44,
            height: 44,
            child: CustomPaint(
              painter: _CellPainter(
                fill: fill,
                dashedRing: info.expected ? colors.period : null,
                ring: isSelected
                    ? scheme.primary
                    : (isToday ? scheme.outline : null),
                ringWidth: isSelected ? 2.5 : 1.5,
                startBar: info.possibleStart && !info.expected && !inPeriod
                    ? colors.period
                    : null,
                symptomDot: info.symptomCount > 0 ? colors.symptom : null,
                spottingRing: info.spotting && !inPeriod ? colors.period : null,
                flowDots: dots,
                flowDotColor: textColor,
              ),
              child: Center(
                child: Text(
                  '${info.day.day}',
                  style: context.texts.bodyMedium?.copyWith(
                    color: textColor,
                    fontWeight: isToday || inPeriod
                        ? FontWeight.w700
                        : FontWeight.w400,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CellPainter extends CustomPainter {
  final Color? fill;
  final Color? dashedRing;
  final Color? ring;
  final double ringWidth;
  final Color? startBar;
  final Color? symptomDot;
  final Color? spottingRing;
  final int flowDots;
  final Color flowDotColor;

  _CellPainter({
    required this.fill,
    required this.dashedRing,
    required this.ring,
    required this.ringWidth,
    required this.startBar,
    required this.symptomDot,
    required this.spottingRing,
    required this.flowDots,
    required this.flowDotColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2 - 3;
    if (fill != null) {
      canvas.drawCircle(center, radius, Paint()..color = fill!);
    }
    if (dashedRing != null) {
      final paint = Paint()
        ..color = dashedRing!
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;
      const segments = 14;
      const sweep = 2 * math.pi / segments;
      for (var i = 0; i < segments; i++) {
        canvas.drawArc(
          Rect.fromCircle(center: center, radius: radius),
          i * sweep,
          sweep * 0.55,
          false,
          paint,
        );
      }
    }
    if (ring != null) {
      canvas.drawCircle(
        center,
        radius + 2,
        Paint()
          ..color = ring!
          ..style = PaintingStyle.stroke
          ..strokeWidth = ringWidth,
      );
    }
    if (startBar != null) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: Offset(center.dx, size.height - 8),
            width: 14,
            height: 3,
          ),
          const Radius.circular(2),
        ),
        Paint()..color = startBar!,
      );
    }
    if (flowDots > 0) {
      final paint = Paint()..color = flowDotColor;
      const gap = 5.0;
      final startX = center.dx - (flowDots - 1) * gap / 2;
      for (var i = 0; i < flowDots; i++) {
        canvas.drawCircle(
          Offset(startX + i * gap, size.height - 10),
          1.6,
          paint,
        );
      }
    }
    if (spottingRing != null) {
      canvas.drawCircle(
        Offset(center.dx, size.height - 8),
        3,
        Paint()
          ..color = spottingRing!
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
    }
    if (symptomDot != null) {
      canvas.drawCircle(
        Offset(size.width - 7, 8),
        3.5,
        Paint()..color = symptomDot!,
      );
    }
  }

  @override
  bool shouldRepaint(_CellPainter old) =>
      old.fill != fill ||
      old.dashedRing != dashedRing ||
      old.ring != ring ||
      old.ringWidth != ringWidth ||
      old.startBar != startBar ||
      old.symptomDot != symptomDot ||
      old.spottingRing != spottingRing ||
      old.flowDots != flowDots ||
      old.flowDotColor != flowDotColor;
}

/// Explains the marks of [MonthCalendar].
class CalendarLegend extends StatelessWidget {
  final bool withEstimates;

  const CalendarLegend({super.key, required this.withEstimates});

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final colors = MhColors.of(context);
    Widget item(_CellPainter painter, String text) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(
          child: SizedBox(
            width: 26,
            height: 26,
            child: CustomPaint(painter: painter),
          ),
        ),
        const SizedBox(width: 6),
        Flexible(child: Text(text, style: context.texts.bodySmall)),
      ],
    );
    _CellPainter painter({
      Color? fill,
      Color? dashed,
      Color? bar,
      Color? dot,
      Color? spotting,
    }) => _CellPainter(
      fill: fill,
      dashedRing: dashed,
      ring: null,
      ringWidth: 0,
      startBar: bar,
      symptomDot: dot,
      spottingRing: spotting,
      flowDots: 0,
      flowDotColor: colors.onPeriod,
    );
    return Semantics(
      label: l.legend,
      container: true,
      child: Wrap(
        spacing: 16,
        runSpacing: 6,
        children: [
          item(painter(fill: colors.period), l.legendPeriod),
          if (withEstimates) ...[
            item(painter(dashed: colors.period), l.legendExpected),
            item(painter(bar: colors.period), l.legendWindow),
          ],
          item(painter(spotting: colors.period), l.legendSpotting),
          item(painter(dot: colors.symptom), l.legendSymptom),
        ],
      ),
    );
  }
}
