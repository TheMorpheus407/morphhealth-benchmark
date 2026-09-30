import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// One value of a chart. [value] null = no data for this slot.
class ChartPoint {
  const ChartPoint({required this.label, required this.value, required this.fullLabel});

  /// Short axis label (e.g. "Mo" or "23.").
  final String label;

  /// Complete description for the table view (e.g. the full date).
  final String fullLabel;
  final double? value;
}

enum ChartStyle { bars, line }

/// Simple, calm bar/line chart with an accessible summary and an optional
/// goal line. Screen readers get [semanticSummary]; a table alternative is
/// offered by [ChartWithTable].
class TrendChart extends StatelessWidget {
  const TrendChart({
    super.key,
    required this.points,
    required this.semanticSummary,
    required this.formatValue,
    this.style = ChartStyle.bars,
    this.goal,
    this.color,
    this.height = 190,
    this.zeroBased = true,
  });

  final List<ChartPoint> points;
  final String semanticSummary;
  final String Function(double) formatValue;
  final ChartStyle style;
  final double? goal;
  final Color? color;
  final double height;
  final bool zeroBased;

  @override
  Widget build(BuildContext context) {
    final scheme = context.scheme;
    return Semantics(
      label: semanticSummary,
      image: true,
      excludeSemantics: true,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: _ChartPainter(
            points: points,
            style: style,
            goal: goal,
            color: color ?? scheme.primary,
            gridColor: scheme.outlineVariant,
            textColor: scheme.onSurfaceVariant,
            goalColor: scheme.tertiary,
            formatValue: formatValue,
            textStyle: context.text.labelSmall ?? const TextStyle(fontSize: 11),
            textScaler: MediaQuery.textScalerOf(context),
            zeroBased: zeroBased,
          ),
        ),
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  _ChartPainter({
    required this.points,
    required this.style,
    required this.goal,
    required this.color,
    required this.gridColor,
    required this.textColor,
    required this.goalColor,
    required this.formatValue,
    required this.textStyle,
    required this.textScaler,
    required this.zeroBased,
  });

  final List<ChartPoint> points;
  final ChartStyle style;
  final double? goal;
  final Color color;
  final Color gridColor;
  final Color textColor;
  final Color goalColor;
  final String Function(double) formatValue;
  final TextStyle textStyle;
  final TextScaler textScaler;
  final bool zeroBased;

  TextPainter _text(String s, {Color? color}) => TextPainter(
    text: TextSpan(text: s, style: textStyle.copyWith(color: color ?? textColor)),
    textDirection: TextDirection.ltr,
    textScaler: textScaler,
    maxLines: 1,
  )..layout();

  @override
  void paint(Canvas canvas, Size size) {
    final values = points.map((p) => p.value).whereType<double>().toList();
    var maxV = values.isEmpty ? 1.0 : values.reduce(math.max);
    var minV = values.isEmpty ? 0.0 : values.reduce(math.min);
    if (goal != null) {
      maxV = math.max(maxV, goal!);
      minV = math.min(minV, goal!);
    }
    if (zeroBased) {
      minV = 0;
      maxV = maxV <= 0 ? 1 : maxV * 1.1;
    } else {
      final span = math.max(maxV - minV, 1.0);
      minV -= span * 0.15;
      maxV += span * 0.15;
    }

    final labelHeight = _text('0').height + 6;
    final yLabelWidth = math.max(_text(formatValue(maxV)).width, _text(formatValue(minV)).width) + 8;
    final chart = Rect.fromLTRB(yLabelWidth, 8, size.width - 4, size.height - labelHeight);
    double y(double v) => chart.bottom - (v - minV) / (maxV - minV) * chart.height;

    // Grid with three labelled lines.
    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (var i = 0; i <= 2; i++) {
      final v = minV + (maxV - minV) * i / 2;
      final yy = y(v);
      canvas.drawLine(Offset(chart.left, yy), Offset(chart.right, yy), grid);
      final tp = _text(formatValue(v));
      tp.paint(canvas, Offset(chart.left - tp.width - 6, yy - tp.height / 2));
    }

    final n = points.length;
    if (n == 0) return;
    final slot = chart.width / n;

    if (style == ChartStyle.bars) {
      final bar = Paint()..color = color;
      final barWidth = math.max(2.0, slot * 0.62);
      for (var i = 0; i < n; i++) {
        final v = points[i].value;
        if (v == null) continue;
        final cx = chart.left + slot * (i + 0.5);
        final top = y(v);
        final rect = RRect.fromRectAndCorners(
          Rect.fromLTRB(cx - barWidth / 2, top, cx + barWidth / 2, chart.bottom),
          topLeft: const Radius.circular(3),
          topRight: const Radius.circular(3),
        );
        canvas.drawRRect(rect, bar);
      }
    } else {
      final line = Paint()
        ..color = color
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round;
      final dot = Paint()..color = color;
      final path = Path();
      var started = false;
      for (var i = 0; i < n; i++) {
        final v = points[i].value;
        if (v == null) continue;
        final p = Offset(chart.left + slot * (i + 0.5), y(v));
        if (!started) {
          path.moveTo(p.dx, p.dy);
          started = true;
        } else {
          path.lineTo(p.dx, p.dy);
        }
      }
      canvas.drawPath(path, line);
      for (var i = 0; i < n; i++) {
        final v = points[i].value;
        if (v == null) continue;
        canvas.drawCircle(Offset(chart.left + slot * (i + 0.5), y(v)), n > 60 ? 1.5 : 3.5, dot);
      }
    }

    // Goal: dashed line.
    if (goal != null) {
      final gy = y(goal!);
      final paint = Paint()
        ..color = goalColor
        ..strokeWidth = 1.5;
      for (var x = chart.left; x < chart.right; x += 8) {
        canvas.drawLine(Offset(x, gy), Offset(math.min(x + 4, chart.right), gy), paint);
      }
    }

    // X labels: as many as fit.
    final sample = _text(points.map((p) => p.label).fold('', (a, b) => a.length >= b.length ? a : b));
    final every = math.max(1, (sample.width + 6) ~/ slot + 1);
    for (var i = 0; i < n; i++) {
      if ((n - 1 - i) % every != 0) continue;
      final tp = _text(points[i].label);
      final cx = chart.left + slot * (i + 0.5);
      final dx = (cx - tp.width / 2).clamp(chart.left - yLabelWidth + 2, size.width - tp.width);
      tp.paint(canvas, Offset(dx, chart.bottom + 4));
    }
  }

  @override
  bool shouldRepaint(covariant _ChartPainter old) =>
      old.points != points || old.goal != goal || old.color != color || old.style != style;
}

/// A chart with a switch to an accessible table of the same values.
class ChartWithTable extends StatefulWidget {
  const ChartWithTable({
    super.key,
    required this.chart,
    required this.points,
    required this.formatValue,
    required this.showTableLabel,
    required this.showChartLabel,
    required this.emptyLabel,
  });

  final TrendChart chart;
  final List<ChartPoint> points;
  final String Function(double) formatValue;
  final String showTableLabel;
  final String showChartLabel;
  final String emptyLabel;

  @override
  State<ChartWithTable> createState() => _ChartWithTableState();
}

class _ChartWithTableState extends State<ChartWithTable> {
  bool _table = false;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_table)
          Column(
            children: [
              for (final p in widget.points.reversed)
                MergeSemantics(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Expanded(child: Text(p.fullLabel)),
                        Text(
                          p.value == null ? widget.emptyLabel : widget.formatValue(p.value!),
                          style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          )
        else
          widget.chart,
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => setState(() => _table = !_table),
            icon: Icon(_table ? Icons.bar_chart : Icons.table_rows_outlined),
            label: Text(_table ? widget.showChartLabel : widget.showTableLabel),
          ),
        ),
      ],
    );
  }
}
