import 'package:flutter/material.dart' hide Flow;

import '../../../core/cycle/forecast.dart';
import '../../../core/model/enums.dart';
import '../../../core/util/local_date.dart';
import '../../controller.dart';
import '../../theme.dart';

/// Month calendar of the cycle tracker. Recorded period days are filled,
/// estimated period days outlined, the likely start window shaded; dots mark
/// symptoms or notes. Every day has a complete screen reader label.
class CycleCalendar extends StatelessWidget {
  const CycleCalendar({
    super.key,
    required this.month,
    required this.onMonthChanged,
    required this.onDayTap,
    required this.forecast,
  });

  /// Any day of the displayed month.
  final LocalDate month;
  final ValueChanged<LocalDate> onMonthChanged;
  final ValueChanged<LocalDate> onDayTap;
  final CycleForecast forecast;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final s = app.s;
    final fmt = app.fmt;
    final first = month.firstOfMonth;
    final firstWeekday = MaterialLocalizations.of(context).firstDayOfWeekIndex; // 0 = Sunday
    final isoFirst = firstWeekday == 0 ? 7 : firstWeekday;
    final leading = (first.weekday - isoFirst + 7) % 7;
    final daysInMonth = LocalDate.daysInMonth(first.year, first.month);
    final cells = <LocalDate?>[
      for (var i = 0; i < leading; i++) null,
      for (var d = 1; d <= daysInMonth; d++) LocalDate(first.year, first.month, d),
    ];
    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    final today = app.today;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              tooltip: s.previousMonth,
              icon: const Icon(Icons.chevron_left),
              onPressed: () => onMonthChanged(first.addMonths(-1)),
            ),
            Expanded(
              child: Semantics(
                header: true,
                liveRegion: true,
                child: Text(
                  fmt.monthYear(first),
                  textAlign: TextAlign.center,
                  style: context.text.titleMedium,
                ),
              ),
            ),
            if (first != today.firstOfMonth)
              TextButton(onPressed: () => onMonthChanged(today), child: Text(s.today)),
            IconButton(
              tooltip: s.nextMonth,
              icon: const Icon(Icons.chevron_right),
              onPressed: () => onMonthChanged(first.addMonths(1)),
            ),
          ],
        ),
        ExcludeSemantics(
          child: Row(
            children: [
              for (var i = 0; i < 7; i++)
                Expanded(
                  child: Center(
                    child: Text(
                      fmt.weekdayShort((isoFirst - 1 + i) % 7 + 1),
                      style: context.text.labelSmall?.copyWith(color: context.scheme.onSurfaceVariant),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        for (var row = 0; row < cells.length ~/ 7; row++)
          Row(
            children: [
              for (var col = 0; col < 7; col++)
                Expanded(
                  child: cells[row * 7 + col] == null
                      ? const SizedBox(height: 48)
                      : _DayCell(
                          day: cells[row * 7 + col]!,
                          today: today,
                          forecast: forecast,
                          onTap: onDayTap,
                        ),
                ),
            ],
          ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.today,
    required this.forecast,
    required this.onTap,
  });

  final LocalDate day;
  final LocalDate today;
  final CycleForecast forecast;
  final ValueChanged<LocalDate> onTap;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final colors = context.colors;
    final data = app.data;
    final period = data.periodOn(day, today);
    final inPeriod = period != null && !day.isAfter(today);
    final cycleDay = data.cycleDayOn(day);
    final flow = cycleDay?.flow;
    final symptoms = data.symptomsOn(day).length;
    final hasNote = cycleDay?.note != null && cycleDay!.note!.isNotEmpty;
    final future = day.isAfter(today);
    final predicted = !inPeriod && forecast.predictionsEnabled && future && forecast.isPredictedPeriodDay(day);
    final inWindow = !inPeriod && forecast.predictionsEnabled && !day.isBefore(today) && forecast.isInWindow(day);
    final isToday = day == today;

    final label = app.s.calendarDayLabel(
      date: app.fmt.full(day),
      isToday: isToday,
      inPeriod: inPeriod,
      flow: flow,
      predicted: predicted,
      inWindow: inWindow,
      symptoms: symptoms,
      hasNote: hasNote,
    );

    Color? fill;
    Color textColor = context.scheme.onSurface;
    BoxBorder? border;
    if (inPeriod) {
      fill = colors.period;
      textColor = colors.onPeriod;
    } else if (predicted) {
      border = Border.all(color: colors.period, width: 2);
    }
    if (isToday) {
      border = Border.all(
        color: inPeriod ? context.scheme.onSurface : context.scheme.primary,
        width: 2.5,
      );
    }

    return Semantics(
      button: true,
      label: label,
      onTap: () => onTap(day),
      excludeSemantics: true,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => onTap(day),
        child: SizedBox(
          height: 52,
          child: Stack(
            alignment: Alignment.center,
            children: [
              if (inWindow)
                Positioned.fill(
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 6),
                    color: colors.window,
                  ),
                ),
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: fill, shape: BoxShape.circle, border: border),
                child: Text(
                  '${day.day}',
                  style: context.text.bodyMedium?.copyWith(
                    color: inWindow && !inPeriod ? colors.onWindow : textColor,
                    fontWeight: isToday || inPeriod ? FontWeight.w700 : FontWeight.w400,
                  ),
                ),
              ),
              if (flow != null)
                Positioned(
                  top: 1,
                  right: 2,
                  child: Icon(
                    flow == Flow.spotting ? Icons.water_drop_outlined : Icons.water_drop,
                    size: 13,
                    color: colors.period,
                  ),
                ),
              if (symptoms > 0 || hasNote)
                Positioned(
                  bottom: 3,
                  child: Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(color: colors.symptoms, shape: BoxShape.circle),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Legend explaining the calendar markers.
class CycleLegend extends StatelessWidget {
  const CycleLegend({super.key, required this.showPredictions});

  final bool showPredictions;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final colors = context.colors;
    Widget item(Widget marker, String text) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [marker, const SizedBox(width: 6), Text(text, style: context.text.bodySmall)],
    );
    Widget circle({Color? fill, Color? border}) => Container(
      width: 16,
      height: 16,
      decoration: BoxDecoration(
        color: fill,
        shape: BoxShape.circle,
        border: border == null ? null : Border.all(color: border, width: 2),
      ),
    );
    return Wrap(
      spacing: 16,
      runSpacing: 8,
      children: [
        item(circle(fill: colors.period), s.legendPeriod),
        if (showPredictions) item(circle(border: colors.period), s.legendPredicted),
        if (showPredictions) item(Container(width: 16, height: 16, color: colors.window), s.legendWindow),
        item(Icon(Icons.water_drop, size: 16, color: colors.period), s.flow),
        item(Icon(Icons.water_drop_outlined, size: 16, color: colors.period), s.legendSpotting),
        item(Container(width: 8, height: 8, decoration: BoxDecoration(color: colors.symptoms, shape: BoxShape.circle)),
            '${s.legendSymptoms} / ${s.note}'),
        item(circle(border: context.scheme.primary), s.legendToday),
      ],
    );
  }
}
