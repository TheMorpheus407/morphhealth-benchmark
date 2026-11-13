/// Accessible, interactive 7-day and 28-day bar/line trend chart widget.
library;

import 'dart:math';

import 'package:flutter/material.dart';

import '../../core/store.dart';

enum MhChartStyle { bar, line }

class MhTrendChart extends StatefulWidget {
  final List<TrendPoint> points;
  final String unit;
  final String title;
  final Color color;
  final MhChartStyle style;
  final double? fixedMaxY;
  final double? fixedMinY;
  final double? goalValue;
  final int decimals;
  final String localeCode;

  const MhTrendChart({
    super.key,
    required this.points,
    required this.unit,
    required this.title,
    required this.color,
    this.style = MhChartStyle.bar,
    this.fixedMaxY,
    this.fixedMinY,
    this.goalValue,
    this.decimals = 0,
    required this.localeCode,
  });

  @override
  State<MhTrendChart> createState() => _MhTrendChartState();
}

class _MhTrendChartState extends State<MhTrendChart> {
  int? _selectedIndex;

  @override
  void didUpdateWidget(covariant MhTrendChart oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_selectedIndex != null && _selectedIndex! >= widget.points.length) {
      _selectedIndex = null;
    }
  }

  String _fmt(double v) => v.toStringAsFixed(widget.decimals);

  void _handleTouch(Offset localPos, double width) {
    if (widget.points.isEmpty || width <= 0) return;
    final padLeft = 42.0;
    final padRight = 10.0;
    final plotW = max(1.0, width - padLeft - padRight);
    final relX = (localPos.dx - padLeft).clamp(0.0, plotW);
    final idx = ((relX / plotW) * widget.points.length)
        .floor()
        .clamp(0, widget.points.length - 1);
    if (_selectedIndex != idx) {
      setState(() => _selectedIndex = idx);
    }
  }

  @override
  Widget build(BuildContext context) {
    final recorded = widget.points
        .where((p) => p.hasEntry && p.value != null)
        .map((p) => p.value!)
        .toList();

    final isEn = widget.localeCode == 'en';
    final avg = recorded.isEmpty
        ? null
        : recorded.reduce((a, b) => a + b) / recorded.length;
    final minVal = recorded.isEmpty ? null : recorded.reduce(min);
    final maxVal = recorded.isEmpty ? null : recorded.reduce(max);

    final semanticsSummary = recorded.isEmpty
        ? (isEn
            ? '${widget.title}: no recorded values in selected period.'
            : '${widget.title}: keine erfassten Werte im gewählten Zeitraum.')
        : (isEn
            ? '${widget.title}: ${recorded.length} days with entries, average ${_fmt(avg!)} ${widget.unit}, range ${_fmt(minVal!)} to ${_fmt(maxVal!)} ${widget.unit}.'
            : '${widget.title}: ${recorded.length} Tage mit Einträgen, Durchschnitt ${_fmt(avg!)} ${widget.unit}, Spanne ${_fmt(minVal!)} bis ${_fmt(maxVal!)} ${widget.unit}.');

    final selectedPoint = _selectedIndex != null &&
            _selectedIndex! < widget.points.length
        ? widget.points[_selectedIndex!]
        : null;

    final cs = Theme.of(context).colorScheme;

    return Semantics(
      label: semanticsSummary,
      container: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  selectedPoint != null
                      ? '${selectedPoint.date}: ${selectedPoint.value != null && selectedPoint.hasEntry ? "${_fmt(selectedPoint.value!)} ${widget.unit}" : (isEn ? "no entry" : "kein Eintrag")}'
                      : (avg != null
                          ? '${isEn ? "Avg" : "Ø"} ${_fmt(avg)} ${widget.unit} (${recorded.length}/${widget.points.length} ${isEn ? "d" : "T."})'
                          : (isEn
                              ? 'No entries in this window'
                              : 'Keine Einträge in diesem Zeitraum')),
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ),
              if (widget.goalValue != null && widget.goalValue! > 0)
                Text(
                  '${isEn ? "Goal" : "Ziel"}: ${_fmt(widget.goalValue!)} ${widget.unit}',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: cs.primary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, constraints) {
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTapDown: (d) =>
                    _handleTouch(d.localPosition, constraints.maxWidth),
                onHorizontalDragUpdate: (d) =>
                    _handleTouch(d.localPosition, constraints.maxWidth),
                child: SizedBox(
                  height: 175,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: _TrendChartPainter(
                      points: widget.points,
                      color: widget.color,
                      style: widget.style,
                      fixedMinY: widget.fixedMinY,
                      fixedMaxY: widget.fixedMaxY,
                      goalValue: widget.goalValue,
                      selectedIndex: _selectedIndex,
                      gridColor: cs.outlineVariant.withValues(alpha: 0.5),
                      labelColor: cs.onSurfaceVariant,
                      decimals: widget.decimals,
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TrendChartPainter extends CustomPainter {
  final List<TrendPoint> points;
  final Color color;
  final MhChartStyle style;
  final double? fixedMinY;
  final double? fixedMaxY;
  final double? goalValue;
  final int? selectedIndex;
  final Color gridColor;
  final Color labelColor;
  final int decimals;

  _TrendChartPainter({
    required this.points,
    required this.color,
    required this.style,
    this.fixedMinY,
    this.fixedMaxY,
    this.goalValue,
    this.selectedIndex,
    required this.gridColor,
    required this.labelColor,
    required this.decimals,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const padLeft = 42.0;
    const padRight = 10.0;
    const padTop = 10.0;
    const padBottom = 26.0;

    final plotW = max(1.0, size.width - padLeft - padRight);
    final plotH = max(1.0, size.height - padTop - padBottom);

    double minY = fixedMinY ?? 0.0;
    double maxY = fixedMaxY ?? 10.0;

    if (fixedMaxY == null) {
      final vals = points
          .where((p) => p.hasEntry && p.value != null)
          .map((p) => p.value!)
          .toList();
      if (goalValue != null && goalValue! > 0) {
        vals.add(goalValue!);
      }
      if (vals.isNotEmpty) {
        if (style == MhChartStyle.line && fixedMinY == null) {
          final lo = vals.reduce(min);
          final hi = vals.reduce(max);
          final span = max(1.0, hi - lo);
          minY = max(0.0, lo - span * 0.25);
          maxY = hi + span * 0.25;
        } else {
          minY = fixedMinY ?? 0.0;
          maxY = max(1.0, vals.reduce(max) * 1.15);
        }
      }
    }
    if (maxY <= minY) maxY = minY + 1.0;

    double yFor(double val) {
      final norm = ((val - minY) / (maxY - minY)).clamp(0.0, 1.0);
      return padTop + plotH * (1.0 - norm);
    }

    final gridPaint = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    // 3 horizontal reference grid lines (top, mid, bottom)
    for (final frac in [0.0, 0.5, 1.0]) {
      final v = minY + (maxY - minY) * frac;
      final y = yFor(v);
      canvas.drawLine(Offset(padLeft, y), Offset(padLeft + plotW, y), gridPaint);
      final tp = TextPainter(
        text: TextSpan(
          text: v >= 1000
              ? '${(v / 1000).toStringAsFixed(1)}k'
              : v.toStringAsFixed(v == v.roundToDouble() ? 0 : min(1, decimals)),
          style: TextStyle(color: labelColor, fontSize: 10.5),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: padLeft - 4);
      tp.paint(canvas, Offset(padLeft - tp.width - 5, y - tp.height / 2));
    }

    // Optional goal line
    if (goalValue != null && goalValue! >= minY && goalValue! <= maxY) {
      final gy = yFor(goalValue!);
      final dashPaint = Paint()
        ..color = color.withValues(alpha: 0.65)
        ..strokeWidth = 1.4;
      var x = padLeft;
      while (x < padLeft + plotW) {
        canvas.drawLine(Offset(x, gy), Offset(min(x + 5, padLeft + plotW), gy), dashPaint);
        x += 9;
      }
    }

    if (points.isEmpty) return;

    final n = points.length;
    final stepX = plotW / n;

    if (style == MhChartStyle.bar) {
      final barW = max(3.0, stepX * 0.62);
      final barPaint = Paint()..style = PaintingStyle.fill;
      for (var i = 0; i < n; i++) {
        final pt = points[i];
        final cx = padLeft + stepX * (i + 0.5);
        if (selectedIndex == i) {
          canvas.drawRect(
            Rect.fromLTWH(padLeft + stepX * i, padTop, stepX, plotH),
            Paint()..color = color.withValues(alpha: 0.09),
          );
        }
        if (pt.hasEntry && pt.value != null && pt.value! > 0) {
          final topY = yFor(pt.value!);
          final bottomY = padTop + plotH;
          barPaint.color = selectedIndex == i
              ? color
              : color.withValues(alpha: 0.82);
          canvas.drawRRect(
            RRect.fromRectAndCorners(
              Rect.fromLTRB(
                cx - barW / 2,
                min(topY, bottomY - 2),
                cx + barW / 2,
                bottomY,
              ),
              topLeft: const Radius.circular(4),
              topRight: const Radius.circular(4),
            ),
            barPaint,
          );
        }
      }
    } else {
      final linePaint = Paint()
        ..color = color
        ..strokeWidth = 2.4
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;

      final dotFill = Paint()
        ..color = color
        ..style = PaintingStyle.fill;

      final path = Path();
      var started = false;
      for (var i = 0; i < n; i++) {
        final pt = points[i];
        final cx = padLeft + stepX * (i + 0.5);
        if (selectedIndex == i) {
          canvas.drawLine(
            Offset(cx, padTop),
            Offset(cx, padTop + plotH),
            Paint()
              ..color = color.withValues(alpha: 0.25)
              ..strokeWidth = 1.5,
          );
        }
        if (pt.hasEntry && pt.value != null) {
          final cy = yFor(pt.value!);
          if (!started) {
            path.moveTo(cx, cy);
            started = true;
          } else {
            path.lineTo(cx, cy);
          }
        }
      }
      if (started) {
        canvas.drawPath(path, linePaint);
      }
      for (var i = 0; i < n; i++) {
        final pt = points[i];
        if (pt.hasEntry && pt.value != null) {
          final cx = padLeft + stepX * (i + 0.5);
          final cy = yFor(pt.value!);
          canvas.drawCircle(
            Offset(cx, cy),
            selectedIndex == i ? 5.2 : 3.6,
            dotFill,
          );
        }
      }
    }

    // X-axis date labels (sparse so 28 days never overlap)
    final labelIndices = n <= 7
        ? List<int>.generate(n, (i) => i)
        : <int>{0, n ~/ 4, n ~/ 2, (3 * n) ~/ 4, n - 1}.toList();
    for (final idx in labelIndices) {
      final d = points[idx].date; // YYYY-MM-DD
      final shortDate = '${d.substring(8, 10)}.${d.substring(5, 7)}.';
      final cx = padLeft + stepX * (idx + 0.5);
      final tp = TextPainter(
        text: TextSpan(
          text: shortDate,
          style: TextStyle(color: labelColor, fontSize: 10),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final drawX = (cx - tp.width / 2).clamp(0.0, size.width - tp.width);
      tp.paint(canvas, Offset(drawX, padTop + plotH + 6));
    }
  }

  @override
  bool shouldRepaint(covariant _TrendChartPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.color != color ||
        oldDelegate.goalValue != goalValue ||
        oldDelegate.style != style;
  }
}
