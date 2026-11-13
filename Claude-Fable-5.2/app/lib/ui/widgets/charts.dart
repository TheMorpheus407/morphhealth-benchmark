import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:morphhealth_core/morphhealth_core.dart';

import 'common.dart';

enum DayChartKind { bars, line }

/// A chart of one value per day.
///
/// The drawing is accompanied by a text summary for screen readers
/// ([semanticsLabel]) and, below the chart, by the value of the day the user
/// tapped. A complete list of the values is offered by [ChartValueList].
class DayChart extends StatefulWidget {
  final List<DayValue> values;
  final DayChartKind kind;
  final Color color;

  /// Draws a horizontal line at this value, for example a daily goal.
  final double? goal;
  final String? goalLabel;

  /// Fixed upper end of the scale (for example 10 for intensities).
  final double? fixedMax;

  /// Formats a value with its unit for labels.
  final String Function(double value) formatValue;

  /// Formats a value for the axis (short, without unit).
  final String Function(double value) formatAxis;
  final String semanticsLabel;
  final String emptyText;
  final double height;

  /// Called when the user asks to open the tapped day.
  final ValueChanged<Day>? onOpenDay;
  final String? openDayLabel;

  const DayChart({
    super.key,
    required this.values,
    required this.kind,
    required this.color,
    required this.formatValue,
    required this.formatAxis,
    required this.semanticsLabel,
    required this.emptyText,
    this.goal,
    this.goalLabel,
    this.fixedMax,
    this.height = 180,
    this.onOpenDay,
    this.openDayLabel,
  });

  @override
  State<DayChart> createState() => _DayChartState();
}

class _DayChartState extends State<DayChart> {
  int? _selected;

  @override
  void didUpdateWidget(DayChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.values.length != widget.values.length ||
        (widget.values.isNotEmpty &&
            oldWidget.values.isNotEmpty &&
            oldWidget.values.first.day != widget.values.first.day)) {
      _selected = null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final fmt = context.fmt;
    final values = widget.values;
    final hasData = values.any((v) => v.value != null);
    final selected = _selected != null && _selected! < values.length
        ? values[_selected!]
        : null;
    final scheme = context.colors;

    final chart = SizedBox(
      height: widget.height,
      child: hasData
          ? LayoutBuilder(
              builder: (context, constraints) => GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapUp: (details) {
                  const left = _ChartPainter.leftPadding;
                  final width = constraints.maxWidth - left - 8;
                  if (width <= 0 || values.isEmpty) return;
                  final slot = width / values.length;
                  final i = ((details.localPosition.dx - left) / slot)
                      .floor()
                      .clamp(0, values.length - 1);
                  setState(() => _selected = i);
                },
                child: CustomPaint(
                  size: Size(constraints.maxWidth, widget.height),
                  painter: _ChartPainter(
                    values: values,
                    kind: widget.kind,
                    color: widget.color,
                    goal: widget.goal,
                    goalLabel: widget.goalLabel,
                    fixedMax: widget.fixedMax,
                    selected: _selected,
                    formatAxis: widget.formatAxis,
                    xLabel: (d) => values.length <= 7
                        ? fmt.weekdayNames(d.weekday).first
                        : fmt.dateShort(d),
                    textStyle: context.texts.labelSmall!.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                    gridColor: scheme.outlineVariant,
                    goalColor: scheme.onSurfaceVariant,
                    selectionColor: scheme.onSurface,
                    textScaler: MediaQuery.textScalerOf(context),
                  ),
                ),
              ),
            )
          : Center(
              child: Text(
                widget.emptyText,
                style: context.texts.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Semantics(
          label: widget.semanticsLabel,
          image: true,
          excludeSemantics: true,
          child: chart,
        ),
        if (selected != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '${fmt.day(selected.day)}: '
                    '${selected.value == null ? '–' : widget.formatValue(selected.value!)}',
                    style: context.texts.bodyMedium,
                  ),
                ),
                if (widget.onOpenDay != null)
                  TextButton(
                    onPressed: () => widget.onOpenDay!(selected.day),
                    child: Text(widget.openDayLabel ?? ''),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// The next round number at or above [value], so that the axis of a bar
/// chart reads 0 / 600 / 1.200 instead of 0 / 655 / 1.309.
@visibleForTesting
double niceUpperBound(double value) {
  if (value <= 0 || value.isNaN || value.isInfinite) return 1;
  final magnitude = math
      .pow(10, (math.log(value) / math.ln10).floor())
      .toDouble();
  for (final factor in const [
    1.0,
    1.2,
    1.5,
    2.0,
    2.5,
    3.0,
    4.0,
    5.0,
    6.0,
    8.0,
  ]) {
    // The tolerance absorbs the rounding of the logarithm.
    if (factor * magnitude >= value * (1 - 1e-9)) return factor * magnitude;
  }
  return 10 * magnitude;
}

class _ChartPainter extends CustomPainter {
  static const double leftPadding = 44;
  static const double _bottomPadding = 22;
  static const double _topPadding = 10;

  final List<DayValue> values;
  final DayChartKind kind;
  final Color color;
  final double? goal;
  final String? goalLabel;
  final double? fixedMax;
  final int? selected;
  final String Function(double) formatAxis;
  final String Function(Day) xLabel;
  final TextStyle textStyle;
  final Color gridColor;
  final Color goalColor;
  final Color selectionColor;
  final TextScaler textScaler;

  _ChartPainter({
    required this.values,
    required this.kind,
    required this.color,
    required this.goal,
    required this.goalLabel,
    required this.fixedMax,
    required this.selected,
    required this.formatAxis,
    required this.xLabel,
    required this.textStyle,
    required this.gridColor,
    required this.goalColor,
    required this.selectionColor,
    required this.textScaler,
  });

  TextPainter _text(String s, {double maxWidth = 200}) => TextPainter(
    text: TextSpan(text: s, style: textStyle),
    textDirection: TextDirection.ltr,
    maxLines: 1,
    ellipsis: '…',
    // Axis labels stay small enough to fit; the values are also
    // available as text below the chart.
    textScaler: textScaler.clamp(maxScaleFactor: 1.3),
  )..layout(maxWidth: maxWidth);

  @override
  void paint(Canvas canvas, Size size) {
    final known = [
      for (final v in values)
        if (v.value != null) v.value!,
    ];
    if (known.isEmpty) return;

    var lo = known.reduce(math.min);
    var hi = known.reduce(math.max);
    final g = goal;
    if (g != null) hi = math.max(hi, g);
    if (kind == DayChartKind.bars) {
      lo = 0;
      hi = fixedMax ?? (hi <= 0 ? 1 : niceUpperBound(hi));
    } else {
      final span = hi - lo;
      final pad = span == 0 ? math.max(hi.abs() * 0.02, 0.5) : span * 0.15;
      lo -= pad;
      hi += pad;
    }
    if (hi <= lo) hi = lo + 1;

    final plot = Rect.fromLTRB(
      leftPadding,
      _topPadding,
      size.width - 8,
      size.height - _bottomPadding,
    );
    double y(double v) => plot.bottom - (v - lo) / (hi - lo) * plot.height;
    final slot = plot.width / values.length;
    double x(int i) => plot.left + slot * (i + 0.5);

    // Horizontal grid with labels.
    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (final fraction in const [0.0, 0.5, 1.0]) {
      final v = lo + (hi - lo) * fraction;
      final yy = y(v);
      canvas.drawLine(Offset(plot.left, yy), Offset(plot.right, yy), grid);
      final tp = _text(formatAxis(v), maxWidth: leftPadding - 6);
      tp.paint(canvas, Offset(plot.left - tp.width - 6, yy - tp.height / 2));
    }

    // Day labels: all for a week, otherwise first, middle and last.
    final labelled = values.length <= 7
        ? [for (var i = 0; i < values.length; i++) i]
        : [0, values.length ~/ 2, values.length - 1];
    for (final i in labelled) {
      final tp = _text(xLabel(values[i].day), maxWidth: 80);
      final dx = (x(i) - tp.width / 2)
          .clamp(plot.left, math.max(plot.left, plot.right - tp.width))
          .toDouble();
      tp.paint(canvas, Offset(dx, plot.bottom + 4));
    }

    // Goal line.
    if (g != null) {
      final paint = Paint()
        ..color = goalColor
        ..strokeWidth = 1.5;
      final yy = y(g);
      for (var dx = plot.left; dx < plot.right; dx += 9) {
        canvas.drawLine(
          Offset(dx, yy),
          Offset(math.min(dx + 5, plot.right), yy),
          paint,
        );
      }
      final label = goalLabel;
      if (label != null) {
        final tp = _text(label, maxWidth: 120);
        tp.paint(
          canvas,
          Offset(plot.right - tp.width, math.max(0, yy - tp.height - 2)),
        );
      }
    }

    final sel = selected;
    if (sel != null && sel < values.length) {
      canvas.drawLine(
        Offset(x(sel), plot.top),
        Offset(x(sel), plot.bottom),
        Paint()
          ..color = selectionColor.withValues(alpha: 0.45)
          ..strokeWidth = 1,
      );
    }

    if (kind == DayChartKind.bars) {
      final barWidth = math.min(28.0, slot * 0.62);
      final paint = Paint()..color = color;
      for (var i = 0; i < values.length; i++) {
        final v = values[i].value;
        if (v == null) continue;
        final top = y(v);
        // A recorded zero stays visible as a thin base line.
        final rect = Rect.fromLTRB(
          x(i) - barWidth / 2,
          math.min(top, plot.bottom - 2),
          x(i) + barWidth / 2,
          plot.bottom,
        );
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            rect,
            topLeft: const Radius.circular(3),
            topRight: const Radius.circular(3),
          ),
          paint,
        );
      }
    } else {
      final line = Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke
        ..strokeJoin = StrokeJoin.round;
      final path = Path();
      var started = false;
      for (var i = 0; i < values.length; i++) {
        final v = values[i].value;
        if (v == null) continue;
        if (started) {
          path.lineTo(x(i), y(v));
        } else {
          path.moveTo(x(i), y(v));
          started = true;
        }
      }
      canvas.drawPath(path, line);
      final dot = Paint()..color = color;
      final radius = values.length > 40 ? 2.0 : 3.5;
      for (var i = 0; i < values.length; i++) {
        final v = values[i].value;
        if (v != null) canvas.drawCircle(Offset(x(i), y(v)), radius, dot);
      }
    }
  }

  @override
  bool shouldRepaint(_ChartPainter old) =>
      old.values != values ||
      old.selected != selected ||
      old.color != color ||
      old.goal != goal ||
      old.kind != kind ||
      old.textStyle != textStyle;
}

/// The values of a chart as text: one line per day that has a value.
class ChartValueList extends StatelessWidget {
  final String title;
  final List<DayValue> values;
  final String Function(double value) formatValue;

  const ChartValueList({
    super.key,
    required this.title,
    required this.values,
    required this.formatValue,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = context.fmt;
    final rows = [
      for (final v in values.reversed)
        if (v.value != null) v,
    ];
    if (rows.isEmpty) return const SizedBox.shrink();
    return Theme(
      data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        childrenPadding: const EdgeInsets.only(bottom: 8),
        title: Text(title, style: context.texts.bodyMedium),
        children: [
          for (final v in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(child: Text(fmt.dayRelative(v.day))),
                  Text(formatValue(v.value!)),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// A tiny line without axes, for cards.
class Sparkline extends StatelessWidget {
  final List<DayValue> values;
  final Color color;
  final double height;

  const Sparkline({
    super.key,
    required this.values,
    required this.color,
    this.height = 44,
  });

  @override
  Widget build(BuildContext context) => ExcludeSemantics(
    child: SizedBox(
      height: height,
      child: CustomPaint(
        size: Size.infinite,
        painter: _SparkPainter(values, color),
      ),
    ),
  );
}

class _SparkPainter extends CustomPainter {
  final List<DayValue> values;
  final Color color;

  _SparkPainter(this.values, this.color);

  @override
  void paint(Canvas canvas, Size size) {
    final points = <(int, double)>[
      for (var i = 0; i < values.length; i++)
        if (values[i].value != null) (i, values[i].value!),
    ];
    if (points.isEmpty) return;
    final lo = points.map((p) => p.$2).reduce(math.min);
    final hi = points.map((p) => p.$2).reduce(math.max);
    final span = hi - lo == 0 ? 1.0 : hi - lo;
    double x(int i) => values.length == 1
        ? size.width / 2
        : 4 + (size.width - 8) * i / (values.length - 1);
    double y(double v) =>
        size.height - 5 - (size.height - 10) * (v - lo) / span;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;
    final path = Path()..moveTo(x(points.first.$1), y(points.first.$2));
    for (final p in points.skip(1)) {
      path.lineTo(x(p.$1), y(p.$2));
    }
    canvas.drawPath(path, paint);
    canvas.drawCircle(
      Offset(x(points.last.$1), y(points.last.$2)),
      3.5,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(_SparkPainter old) =>
      old.values != values || old.color != color;
}
