import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../core/civil.dart';
import '../l10n_x.dart';

/// Ein Balken: Tag und Wert (null = keine Angabe).
final class BarPoint {
  final Day day;
  final double? value;

  const BarPoint(this.day, this.value);
}

/// Ein Punkt einer Linie.
final class LinePoint {
  final Day day;
  final double value;

  const LinePoint(this.day, this.value);
}

double _niceCeil(double v) {
  if (v <= 0) return 1;
  final exp = math.pow(10, (math.log(v) / math.ln10).floor()).toDouble();
  final f = v / exp;
  final nice = f <= 1 ? 1 : (f <= 2 ? 2 : (f <= 2.5 ? 2.5 : (f <= 5 ? 5 : 10)));
  return nice * exp;
}

TextPainter _tp(String text, TextStyle style, {double? maxWidth, TextAlign align = TextAlign.left}) {
  final p = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: TextDirection.ltr,
    textAlign: align,
    maxLines: 1,
    ellipsis: '…',
  )..layout(maxWidth: maxWidth ?? double.infinity);
  return p;
}

double _chartHeight(BuildContext context, double base) {
  final s = MediaQuery.textScalerOf(context).scale(1.0);
  return base * s.clamp(1.0, 1.6);
}

/// Säulendiagramm für Tageswerte (Nährstoffe, Wasser, ...). Antippen zeigt
/// den Wert; für Screenreader gibt es je Balken einen eigenen Knoten.
class BarChart extends StatefulWidget {
  final List<BarPoint> points;
  final Color color;
  final double? goal;
  final String goalLabel;
  final String Function(double) valueLabel;
  final String Function(Day) dayLabel;
  final String Function(Day) axisLabel;
  final String noDataLabel;
  final String hint;
  final String summary;

  const BarChart({
    super.key,
    required this.points,
    required this.color,
    required this.valueLabel,
    required this.dayLabel,
    required this.axisLabel,
    required this.noDataLabel,
    required this.hint,
    required this.summary,
    this.goal,
    this.goalLabel = '',
  });

  @override
  State<BarChart> createState() => _BarChartState();
}

class _BarChartState extends State<BarChart> {
  int? _selected;

  @override
  void didUpdateWidget(BarChart old) {
    super.didUpdateWidget(old);
    if (_selected != null && _selected! >= widget.points.length) _selected = null;
  }

  @override
  Widget build(BuildContext context) {
    final style = context.text.bodySmall!.copyWith(color: context.colors.onSurfaceVariant);
    final painter = _BarPainter(
      points: widget.points,
      color: widget.color,
      goal: widget.goal,
      goalLabel: widget.goalLabel,
      valueLabel: widget.valueLabel,
      dayLabel: widget.dayLabel,
      axisLabel: widget.axisLabel,
      noDataLabel: widget.noDataLabel,
      style: style,
      gridColor: context.colors.outlineVariant,
      axisColor: context.colors.onSurfaceVariant,
      selected: _selected,
      onSelect: (i) => setState(() => _selected = i),
    );
    final sel = _selected;
    final selText = sel == null || sel >= widget.points.length
        ? widget.hint
        : '${widget.dayLabel(widget.points[sel].day)}: ${widget.points[sel].value == null ? widget.noDataLabel : widget.valueLabel(widget.points[sel].value!)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          container: true,
          explicitChildNodes: true,
          label: widget.summary,
          child: LayoutBuilder(
            builder: (context, c) => GestureDetector(
              excludeFromSemantics: true,
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => painter.hit(d.localPosition, Size(c.maxWidth, _chartHeight(context, 190))),
              child: CustomPaint(
                size: Size(c.maxWidth, _chartHeight(context, 190)),
                painter: painter,
                willChange: false,
              ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          selText,
          style: context.text.bodyMedium?.copyWith(fontWeight: sel == null ? FontWeight.normal : FontWeight.w600),
        ),
      ],
    );
  }
}

class _BarPainter extends CustomPainter {
  final List<BarPoint> points;
  final Color color;
  final double? goal;
  final String goalLabel;
  final String Function(double) valueLabel;
  final String Function(Day) dayLabel;
  final String Function(Day) axisLabel;
  final String noDataLabel;
  final TextStyle style;
  final Color gridColor;
  final Color axisColor;
  final int? selected;
  final void Function(int) onSelect;

  _BarPainter({
    required this.points,
    required this.color,
    required this.goal,
    required this.goalLabel,
    required this.valueLabel,
    required this.dayLabel,
    required this.axisLabel,
    required this.noDataLabel,
    required this.style,
    required this.gridColor,
    required this.axisColor,
    required this.selected,
    required this.onSelect,
  });

  static const double left = 46;
  static const double right = 8;
  static const double top = 10;
  static const double bottom = 26;

  double get _yMax {
    var m = goal ?? 0;
    for (final p in points) {
      if (p.value != null && p.value! > m) m = p.value!;
    }
    return _niceCeil(m * 1.08);
  }

  Rect _plot(Size s) => Rect.fromLTRB(left, top, s.width - right, s.height - bottom);

  Rect _slot(Size s, int i) {
    final plot = _plot(s);
    final w = plot.width / points.length;
    return Rect.fromLTWH(plot.left + i * w, plot.top, w, plot.height);
  }

  void hit(Offset p, Size s) {
    final plot = _plot(s);
    if (points.isEmpty || p.dx < plot.left - 4 || p.dx > plot.right + 4) return;
    final w = plot.width / points.length;
    final i = ((p.dx - plot.left) / w).floor().clamp(0, points.length - 1);
    onSelect(i);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final plot = _plot(size);
    final yMax = _yMax;
    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (final f in [0.0, 0.5, 1.0]) {
      final y = plot.bottom - plot.height * f;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), grid);
      final t = _tp(valueLabel(yMax * f), style, maxWidth: left - 6, align: TextAlign.right);
      t.paint(canvas, Offset(left - 6 - t.width, y - t.height / 2));
    }
    final n = points.length;
    if (n == 0) return;
    final slotW = plot.width / n;
    final barW = math.min(slotW * 0.62, 34.0);
    final fill = Paint()..color = color;
    final dim = Paint()..color = color.withValues(alpha: 0.45);
    for (var i = 0; i < n; i++) {
      final v = points[i].value;
      final cx = plot.left + slotW * (i + 0.5);
      if (v == null) {
        canvas.drawCircle(
          Offset(cx, plot.bottom - 3),
          2.5,
          Paint()
            ..color = axisColor.withValues(alpha: 0.6)
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.2,
        );
        continue;
      }
      final h = math.max(2.0, plot.height * (v / yMax).clamp(0.0, 1.0));
      final r = RRect.fromRectAndCorners(
        Rect.fromLTWH(cx - barW / 2, plot.bottom - h, barW, h),
        topLeft: const Radius.circular(4),
        topRight: const Radius.circular(4),
      );
      canvas.drawRRect(r, selected == null || selected == i ? fill : dim);
      if (selected == i) {
        canvas.drawRRect(
          r.inflate(1.5),
          Paint()
            ..color = axisColor
            ..style = PaintingStyle.stroke
            ..strokeWidth = 1.5,
        );
      }
    }
    // Ziel
    if (goal != null && goal! > 0 && goal! <= yMax) {
      final y = plot.bottom - plot.height * (goal! / yMax);
      final dash = Paint()
        ..color = axisColor
        ..strokeWidth = 1.5;
      for (var x = plot.left; x < plot.right; x += 10) {
        canvas.drawLine(Offset(x, y), Offset(math.min(x + 5, plot.right), y), dash);
      }
      if (goalLabel.isNotEmpty) {
        final t = _tp(goalLabel, style.copyWith(fontWeight: FontWeight.w600), maxWidth: 90);
        t.paint(canvas, Offset(plot.right - t.width, y - t.height - 1));
      }
    }
    // x-Beschriftung
    final step = n <= 8 ? 1 : (n <= 16 ? 2 : 7);
    for (var i = 0; i < n; i++) {
      final show = step == 1 || i % step == (n - 1) % step;
      if (!show) continue;
      final t = _tp(axisLabel(points[i].day), style, maxWidth: slotW * step * 1.4, align: TextAlign.center);
      final cx = plot.left + slotW * (i + 0.5);
      final x = (cx - t.width / 2).clamp(0.0, size.width - t.width);
      t.paint(canvas, Offset(x, plot.bottom + 5));
    }
  }

  @override
  SemanticsBuilderCallback get semanticsBuilder => (Size size) {
    return [
      for (var i = 0; i < points.length; i++)
        CustomPainterSemantics(
          rect: _slot(size, i),
          properties: SemanticsProperties(
            label:
                '${dayLabel(points[i].day)}: ${points[i].value == null ? noDataLabel : valueLabel(points[i].value!)}',
            textDirection: TextDirection.ltr,
          ),
        ),
    ];
  };

  @override
  bool shouldRepaint(_BarPainter old) =>
      old.points != points || old.selected != selected || old.goal != goal || old.color != color || old.style != style;

  @override
  bool shouldRebuildSemantics(_BarPainter old) => shouldRepaint(old);
}

/// Liniendiagramm über Kalendertage (Gewicht, Symptomintensität).
class LineChart extends StatefulWidget {
  final List<LinePoint> points;
  final Day start;
  final Day end;
  final Color color;
  final double? yMin;
  final double? yMax;
  final String Function(double) valueLabel;
  final String Function(Day) dayLabel;
  final String Function(Day) axisLabel;
  final String hint;
  final String summary;

  const LineChart({
    super.key,
    required this.points,
    required this.start,
    required this.end,
    required this.color,
    required this.valueLabel,
    required this.dayLabel,
    required this.axisLabel,
    required this.hint,
    required this.summary,
    this.yMin,
    this.yMax,
  });

  @override
  State<LineChart> createState() => _LineChartState();
}

class _LineChartState extends State<LineChart> {
  int? _selected;

  @override
  void didUpdateWidget(LineChart old) {
    super.didUpdateWidget(old);
    if (_selected != null && _selected! >= widget.points.length) _selected = null;
  }

  @override
  Widget build(BuildContext context) {
    final style = context.text.bodySmall!.copyWith(color: context.colors.onSurfaceVariant);
    final painter = _LinePainter(
      points: widget.points,
      start: widget.start,
      end: widget.end,
      color: widget.color,
      yMinFixed: widget.yMin,
      yMaxFixed: widget.yMax,
      valueLabel: widget.valueLabel,
      dayLabel: widget.dayLabel,
      axisLabel: widget.axisLabel,
      style: style,
      gridColor: context.colors.outlineVariant,
      axisColor: context.colors.onSurfaceVariant,
      surface: context.colors.surface,
      selected: _selected,
      onSelect: (i) => setState(() => _selected = i),
    );
    final sel = _selected;
    final selText = sel == null || sel >= widget.points.length
        ? widget.hint
        : '${widget.dayLabel(widget.points[sel].day)}: ${widget.valueLabel(widget.points[sel].value)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          container: true,
          explicitChildNodes: true,
          label: widget.summary,
          child: LayoutBuilder(
            builder: (context, c) => GestureDetector(
              excludeFromSemantics: true,
              behavior: HitTestBehavior.opaque,
              onTapDown: (d) => painter.hit(d.localPosition, Size(c.maxWidth, _chartHeight(context, 190))),
              child: CustomPaint(size: Size(c.maxWidth, _chartHeight(context, 190)), painter: painter),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          selText,
          style: context.text.bodyMedium?.copyWith(fontWeight: sel == null ? FontWeight.normal : FontWeight.w600),
        ),
      ],
    );
  }
}

class _LinePainter extends CustomPainter {
  final List<LinePoint> points;
  final Day start;
  final Day end;
  final Color color;
  final double? yMinFixed;
  final double? yMaxFixed;
  final String Function(double) valueLabel;
  final String Function(Day) dayLabel;
  final String Function(Day) axisLabel;
  final TextStyle style;
  final Color gridColor;
  final Color axisColor;
  final Color surface;
  final int? selected;
  final void Function(int) onSelect;

  _LinePainter({
    required this.points,
    required this.start,
    required this.end,
    required this.color,
    required this.yMinFixed,
    required this.yMaxFixed,
    required this.valueLabel,
    required this.dayLabel,
    required this.axisLabel,
    required this.style,
    required this.gridColor,
    required this.axisColor,
    required this.surface,
    required this.selected,
    required this.onSelect,
  });

  static const double left = 50;
  static const double right = 14;
  static const double top = 12;
  static const double bottom = 26;

  Rect _plot(Size s) => Rect.fromLTRB(left, top, s.width - right, s.height - bottom);

  (double, double) get _yRange {
    if (yMinFixed != null && yMaxFixed != null) return (yMinFixed!, yMaxFixed!);
    var lo = double.infinity;
    var hi = -double.infinity;
    for (final p in points) {
      lo = math.min(lo, p.value);
      hi = math.max(hi, p.value);
    }
    if (lo == double.infinity) return (0, 1);
    if (hi - lo < 1) {
      final mid = (hi + lo) / 2;
      lo = mid - 0.5;
      hi = mid + 0.5;
    }
    final pad = (hi - lo) * 0.15;
    return (lo - pad, hi + pad);
  }

  double _x(Rect plot, Day d) {
    final span = math.max(1, start.daysUntil(end));
    return plot.left + plot.width * (start.daysUntil(d) / span).clamp(0.0, 1.0);
  }

  double _y(Rect plot, double v, (double, double) r) =>
      plot.bottom - plot.height * ((v - r.$1) / (r.$2 - r.$1)).clamp(0.0, 1.0);

  void hit(Offset p, Size s) {
    if (points.isEmpty) return;
    final plot = _plot(s);
    var best = 0;
    var bestD = double.infinity;
    for (var i = 0; i < points.length; i++) {
      final d = (_x(plot, points[i].day) - p.dx).abs();
      if (d < bestD) {
        bestD = d;
        best = i;
      }
    }
    onSelect(best);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final plot = _plot(size);
    final r = _yRange;
    final grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (final f in [0.0, 0.5, 1.0]) {
      final y = plot.bottom - plot.height * f;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), grid);
      final v = r.$1 + (r.$2 - r.$1) * f;
      final t = _tp(valueLabel(v), style, maxWidth: left - 6, align: TextAlign.right);
      t.paint(canvas, Offset(left - 6 - t.width, y - t.height / 2));
    }
    // x-Beschriftung: Anfang, Mitte, Ende
    final labels = <Day>{start, start.addDays(start.daysUntil(end) ~/ 2), end}.toList();
    for (var i = 0; i < labels.length; i++) {
      final t = _tp(axisLabel(labels[i]), style, maxWidth: 90, align: TextAlign.center);
      final cx = _x(plot, labels[i]);
      final x = (cx - t.width / 2).clamp(0.0, size.width - t.width);
      t.paint(canvas, Offset(x, plot.bottom + 5));
    }
    if (points.isEmpty) return;
    final line = Paint()
      ..color = color
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final o = Offset(_x(plot, points[i].day), _y(plot, points[i].value, r));
      if (i == 0) {
        path.moveTo(o.dx, o.dy);
      } else {
        path.lineTo(o.dx, o.dy);
      }
    }
    canvas.drawPath(path, line);
    for (var i = 0; i < points.length; i++) {
      final o = Offset(_x(plot, points[i].day), _y(plot, points[i].value, r));
      final isSel = selected == i;
      canvas.drawCircle(o, isSel ? 6 : 4, Paint()..color = surface);
      canvas.drawCircle(
        o,
        isSel ? 6 : 4,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = isSel ? 3 : 2,
      );
    }
  }

  @override
  SemanticsBuilderCallback get semanticsBuilder => (Size size) {
    final plot = _plot(size);
    return [
      for (var i = 0; i < points.length; i++)
        CustomPainterSemantics(
          rect: Rect.fromCenter(
            center: Offset(_x(plot, points[i].day), plot.center.dy),
            width: 28,
            height: plot.height,
          ),
          properties: SemanticsProperties(
            label: '${dayLabel(points[i].day)}: ${valueLabel(points[i].value)}',
            textDirection: TextDirection.ltr,
          ),
        ),
    ];
  };

  @override
  bool shouldRepaint(_LinePainter old) =>
      old.points != points || old.selected != selected || old.start != start || old.end != end || old.color != color;

  @override
  bool shouldRebuildSemantics(_LinePainter old) => shouldRepaint(old);
}
