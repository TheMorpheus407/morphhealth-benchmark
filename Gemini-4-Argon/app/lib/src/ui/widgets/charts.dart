import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../core/cycle_engine.dart';
import '../../core/models.dart';

class TrendPoint {
  final String date; // YYYY-MM-DD
  final double value;

  const TrendPoint({required this.date, required this.value});
}

class TrendSeriesChart extends StatelessWidget {
  final List<TrendPoint> points;
  final String unit;
  final double? goalValue;
  final Color color;
  final int decimals;
  final String emptyLabel;
  final bool connectLine;

  const TrendSeriesChart({
    super.key,
    required this.points,
    required this.unit,
    this.goalValue,
    required this.color,
    this.decimals = 1,
    required this.emptyLabel,
    this.connectLine = false,
  });

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return SizedBox(
        height: 150,
        child: Center(
          child: Text(
            emptyLabel,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ),
      );
    }

    final nonZero = points.where((p) => p.value > 0).toList();
    double maxVal = 0.0;
    double minVal = double.infinity;
    double sum = 0.0;
    for (final p in points) {
      if (p.value > maxVal) maxVal = p.value;
      if (p.value < minVal) minVal = p.value;
      sum += p.value;
    }
    if (goalValue != null && goalValue! > maxVal) {
      maxVal = goalValue!;
    }
    if (maxVal <= 0) maxVal = 10.0;
    if (minVal == double.infinity) minVal = 0.0;
    final avg = points.isNotEmpty ? sum / points.length : 0.0;

    String fmt(double v) => v.toStringAsFixed(decimals);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            _StatBadge(
              label: 'Ø',
              value: '${fmt(avg)} $unit',
              color: color,
            ),
            if (nonZero.isNotEmpty)
              _StatBadge(
                label: 'Max',
                value: '${fmt(maxVal)} $unit',
                color: color,
              ),
            if (goalValue != null && goalValue! > 0)
              _StatBadge(
                label: 'Ziel / Goal',
                value: '${fmt(goalValue!)} $unit',
                color: Colors.teal,
              ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 150,
          child: CustomPaint(
            painter: _TrendChartPainter(
              points: points,
              maxVal: maxVal,
              goalValue: goalValue,
              color: color,
              connectLine: connectLine,
              textColor: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

class _StatBadge extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _StatBadge({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '$label: $value',
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _TrendChartPainter extends CustomPainter {
  final List<TrendPoint> points;
  final double maxVal;
  final double? goalValue;
  final Color color;
  final bool connectLine;
  final Color textColor;

  _TrendChartPainter({
    required this.points,
    required this.maxVal,
    this.goalValue,
    required this.color,
    required this.connectLine,
    required this.textColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const double bottomPad = 22.0;
    const double topPad = 8.0;
    const double leftPad = 8.0;
    const double rightPad = 8.0;

    final chartWidth = math.max(1.0, size.width - leftPad - rightPad);
    final chartHeight = math.max(1.0, size.height - topPad - bottomPad);
    final baseLineY = topPad + chartHeight;

    final gridPaint = Paint()
      ..color = textColor.withValues(alpha: 0.16)
      ..strokeWidth = 1.0;

    // Draw horizontal guide lines
    for (final frac in const [0.0, 0.5, 1.0]) {
      final y = topPad + chartHeight * (1.0 - frac);
      canvas.drawLine(
        Offset(leftPad, y),
        Offset(size.width - rightPad, y),
        gridPaint,
      );
    }

    // Draw optional goal line
    if (goalValue != null && goalValue! > 0 && maxVal > 0) {
      final ratio = (goalValue! / maxVal).clamp(0.0, 1.0);
      final gy = baseLineY - chartHeight * ratio;
      final goalPaint = Paint()
        ..color = Colors.teal.withValues(alpha: 0.65)
        ..strokeWidth = 1.5;
      canvas.drawLine(
        Offset(leftPad, gy),
        Offset(size.width - rightPad, gy),
        goalPaint,
      );
    }

    final n = points.length;
    if (n == 0) return;

    final stepX = chartWidth / n;

    if (connectLine) {
      final linePaint = Paint()
        ..color = color
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke;
      final dotPaint = Paint()
        ..color = color
        ..style = PaintingStyle.fill;

      final path = Path();
      bool started = false;
      for (int i = 0; i < n; i++) {
        final v = points[i].value;
        final x = leftPad + stepX * (i + 0.5);
        final ratio = maxVal > 0 ? (v / maxVal).clamp(0.0, 1.0) : 0.0;
        final y = baseLineY - chartHeight * ratio;
        if (!started) {
          path.moveTo(x, y);
          started = true;
        } else {
          path.lineTo(x, y);
        }
        canvas.drawCircle(Offset(x, y), 3.5, dotPaint);
      }
      if (started && n > 1) {
        canvas.drawPath(path, linePaint);
      }
    } else {
      final barPaint = Paint()
        ..color = color.withValues(alpha: 0.82)
        ..style = PaintingStyle.fill;
      final barWidth = math.max(3.0, math.min(20.0, stepX * 0.62));

      for (int i = 0; i < n; i++) {
        final v = points[i].value;
        final x = leftPad + stepX * (i + 0.5);
        final ratio = maxVal > 0 ? (v / maxVal).clamp(0.0, 1.0) : 0.0;
        final barH = math.max(v > 0 ? 3.0 : 1.0, chartHeight * ratio);
        final rect = RRect.fromRectAndRadius(
          Rect.fromLTWH(x - barWidth / 2, baseLineY - barH, barWidth, barH),
          const Radius.circular(4),
        );
        canvas.drawRRect(rect, barPaint);
      }
    }

    // Draw X-axis date labels (first, middle, last)
    final labelIndices = <int>{0, n ~/ 2, n - 1};
    for (final idx in labelIndices) {
      if (idx < 0 || idx >= n) continue;
      final d = points[idx].date;
      final shortDate = d.length >= 10 ? '${d.substring(8, 10)}.${d.substring(5, 7)}.' : d;
      final tp = TextPainter(
        text: TextSpan(
          text: shortDate,
          style: TextStyle(fontSize: 10, color: textColor),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final cx = (leftPad + stepX * (idx + 0.5) - tp.width / 2)
          .clamp(0.0, size.width - tp.width);
      tp.paint(canvas, Offset(cx, baseLineY + 4));
    }
  }

  @override
  bool shouldRepaint(covariant _TrendChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.maxVal != maxVal ||
        oldDelegate.goalValue != goalValue ||
        oldDelegate.color != color ||
        oldDelegate.connectLine != connectLine;
  }
}

class CycleMonthCalendar extends StatefulWidget {
  final String selectedDate;
  final ValueChanged<String> onSelectDate;
  final List<PeriodEntry> periods;
  final CycleForecastResult forecast;
  final bool showPredictions;
  final Set<String> datesWithSymptoms;
  final String lang;

  const CycleMonthCalendar({
    super.key,
    required this.selectedDate,
    required this.onSelectDate,
    required this.periods,
    required this.forecast,
    required this.showPredictions,
    required this.datesWithSymptoms,
    required this.lang,
  });

  @override
  State<CycleMonthCalendar> createState() => _CycleMonthCalendarState();
}

class _CycleMonthCalendarState extends State<CycleMonthCalendar> {
  late int _year;
  late int _month;

  @override
  void initState() {
    super.initState();
    _syncFromSelected();
  }

  @override
  void didUpdateWidget(covariant CycleMonthCalendar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedDate.substring(0, 7) !=
        widget.selectedDate.substring(0, 7)) {
      _syncFromSelected();
    }
  }

  void _syncFromSelected() {
    final dt =
        DateTime.tryParse('${widget.selectedDate}T00:00:00Z') ?? DateTime.now();
    _year = dt.year;
    _month = dt.month;
  }

  void _shiftMonth(int delta) {
    setState(() {
      _month += delta;
      while (_month < 1) {
        _month += 12;
        _year -= 1;
      }
      while (_month > 12) {
        _month -= 12;
        _year += 1;
      }
    });
  }

  String _monthTitle() {
    const monthsDe = [
      'Januar',
      'Februar',
      'März',
      'April',
      'Mai',
      'Juni',
      'Juli',
      'August',
      'September',
      'Oktober',
      'November',
      'Dezember',
    ];
    const monthsEn = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final names = widget.lang == 'en' ? monthsEn : monthsDe;
    return '${names[(_month - 1).clamp(0, 11)]} $_year';
  }

  String? _bleedingIntensityOn(String ymd) {
    for (final p in widget.periods) {
      final intensity = p.intensityForDate(ymd);
      if (intensity != null) return intensity;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final weekdays = widget.lang == 'en'
        ? const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
        : const ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];

    final firstOfMonth = DateTime.utc(_year, _month, 1);
    final daysInMonth = DateTime.utc(_year, _month + 1, 0).day;
    final leadingBlanks = (firstOfMonth.weekday - 1) % 7; // Monday = 0

    final cells = <Widget>[];
    for (int i = 0; i < leadingBlanks; i++) {
      cells.add(const SizedBox.shrink());
    }

    for (int day = 1; day <= daysInMonth; day++) {
      final y = _year.toString().padLeft(4, '0');
      final m = _month.toString().padLeft(2, '0');
      final d = day.toString().padLeft(2, '0');
      final ymd = '$y-$m-$d';

      final isSelected = ymd == widget.selectedDate;
      final intensity = _bleedingIntensityOn(ymd);
      final isPredictedPeriod = widget.showPredictions &&
          intensity == null &&
          widget.forecast.isPredictedPeriodDate(ymd);
      final isPredictedWindow = widget.showPredictions &&
          intensity == null &&
          !isPredictedPeriod &&
          widget.forecast.isPredictedWindowDate(ymd);
      final hasSymptom = widget.datesWithSymptoms.contains(ymd);

      Color? bgColor;
      Color textColor = Theme.of(context).colorScheme.onSurface;
      Border? border;

      if (intensity != null) {
        if (intensity == BleedingIntensity.spotting) {
          bgColor = Colors.pink.shade100;
          textColor = Colors.pink.shade900;
        } else if (intensity == BleedingIntensity.light) {
          bgColor = Colors.pink.shade200;
          textColor = Colors.pink.shade900;
        } else if (intensity == BleedingIntensity.heavy) {
          bgColor = Colors.red.shade700;
          textColor = Colors.white;
        } else {
          bgColor = Colors.pink.shade500;
          textColor = Colors.white;
        }
      } else if (isPredictedPeriod) {
        bgColor = Colors.pink.withValues(alpha: 0.16);
        border = Border.all(color: Colors.pink.shade400, width: 1.5);
      } else if (isPredictedWindow) {
        bgColor = Colors.purple.withValues(alpha: 0.08);
        border = Border.all(
          color: Colors.purple.shade200,
          width: 1.0,
        );
      }

      if (isSelected) {
        border = Border.all(
          color: Theme.of(context).colorScheme.primary,
          width: 2.5,
        );
      }

      cells.add(
        Semantics(
          label: ymd,
          selected: isSelected,
          button: true,
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () => widget.onSelectDate(ymd),
            child: Container(
              margin: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(10),
                border: border,
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Text(
                    '$day',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: isSelected || intensity != null
                          ? FontWeight.bold
                          : FontWeight.normal,
                      color: textColor,
                    ),
                  ),
                  if (hasSymptom)
                    Positioned(
                      bottom: 4,
                      child: Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: intensity == BleedingIntensity.heavy ||
                                  intensity == BleedingIntensity.medium
                              ? Colors.white
                              : Colors.deepPurple,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              tooltip: widget.lang == 'en' ? 'Previous month' : 'Vorheriger Monat',
              onPressed: () => _shiftMonth(-1),
              icon: const Icon(Icons.chevron_left),
            ),
            Text(
              _monthTitle(),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            IconButton(
              tooltip: widget.lang == 'en' ? 'Next month' : 'Nächster Monat',
              onPressed: () => _shiftMonth(1),
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            for (final w in weekdays)
              Expanded(
                child: Center(
                  child: Text(
                    w,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          childAspectRatio: 1.35,
          children: cells,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 6,
          children: [
            _LegendDot(
              color: Colors.pink.shade500,
              label: widget.lang == 'en' ? 'Period' : 'Periode',
            ),
            _LegendDot(
              color: Colors.pink.shade100,
              label: widget.lang == 'en' ? 'Spotting' : 'Spotting',
            ),
            if (widget.showPredictions)
              _LegendDot(
                color: Colors.pink.withValues(alpha: 0.25),
                borderColor: Colors.pink.shade400,
                label: widget.lang == 'en'
                    ? 'Expected Window'
                    : 'Erwartetes Fenster',
              ),
            _LegendDot(
              color: Colors.deepPurple,
              label: widget.lang == 'en' ? 'Symptom' : 'Symptom',
              isSmallDot: true,
            ),
          ],
        ),
      ],
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final Color? borderColor;
  final String label;
  final bool isSmallDot;

  const _LegendDot({
    required this.color,
    this.borderColor,
    required this.label,
    this.isSmallDot = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: isSmallDot ? 8 : 14,
          height: isSmallDot ? 8 : 14,
          decoration: BoxDecoration(
            color: color,
            shape: isSmallDot ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: isSmallDot ? null : BorderRadius.circular(4),
            border: borderColor != null
                ? Border.all(color: borderColor!, width: 1.5)
                : null,
          ),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}
