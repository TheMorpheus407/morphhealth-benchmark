import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/nutrition.dart';
import '../core/utils.dart';
import 'controller.dart';
import 'l10n.dart';

class ChartPoint {
  const ChartPoint(this.label, this.value, this.valueLabel);
  final String label;
  final double value;
  final String valueLabel;
}

class SimpleChart extends StatelessWidget {
  const SimpleChart({
    super.key,
    required this.points,
    required this.semanticLabel,
    this.line = false,
  });

  final List<ChartPoint> points;
  final String semanticLabel;
  final bool line;

  @override
  Widget build(BuildContext context) {
    final strings = l10n(context);
    final color = Theme.of(context).colorScheme.primary;
    return Semantics(
      label: semanticLabel,
      child: Column(
        children: [
          SizedBox(
            height: 170,
            width: double.infinity,
            child: points.isEmpty
                ? Center(child: Text(strings.t('no_chart_data')))
                : CustomPaint(painter: _ChartPainter(points, color, line)),
          ),
          if (points.isNotEmpty)
            ExpansionTile(
              title: Text(strings.t('chart_values')),
              children: [
                for (final point in points)
                  ListTile(
                    dense: true,
                    title: Text(point.label),
                    trailing: Text(point.valueLabel),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}

class _ChartPainter extends CustomPainter {
  const _ChartPainter(this.points, this.color, this.line);
  final List<ChartPoint> points;
  final Color color;
  final bool line;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = line ? PaintingStyle.stroke : PaintingStyle.fill;
    final axis = Paint()
      ..color = color.withValues(alpha: 0.25)
      ..strokeWidth = 1;
    canvas.drawLine(
      Offset(0, size.height - 20),
      Offset(size.width, size.height - 20),
      axis,
    );
    final values = points.map((point) => point.value).toList();
    final minimum = line ? values.reduce(math.min) : 0.0;
    final maximum = values.reduce(math.max);
    final range = (maximum - minimum).abs() < 0.0001 ? 1.0 : maximum - minimum;
    final usableHeight = size.height - 36;
    double y(double value) => 8 + (maximum - value) / range * usableHeight;
    if (line) {
      final path = Path();
      for (var index = 0; index < points.length; index++) {
        final x = points.length == 1
            ? size.width / 2
            : index * size.width / (points.length - 1);
        final point = Offset(x, y(points[index].value));
        if (index == 0) {
          path.moveTo(point.dx, point.dy);
        } else {
          path.lineTo(point.dx, point.dy);
        }
        canvas.drawCircle(point, 4, Paint()..color = color);
      }
      canvas.drawPath(path, paint);
    } else {
      final slot = size.width / points.length;
      final width = math.max(2.0, slot * 0.58);
      for (var index = 0; index < points.length; index++) {
        final x = slot * index + slot / 2;
        final top = y(points[index].value);
        canvas.drawRRect(
          RRect.fromRectAndCorners(
            Rect.fromLTWH(
              x - width / 2,
              top,
              width,
              math.max(2, size.height - 20 - top),
            ),
            topLeft: const Radius.circular(3),
            topRight: const Radius.circular(3),
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_ChartPainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.color != color ||
      oldDelegate.line != line;
}

class NutrientTrends extends StatefulWidget {
  const NutrientTrends({super.key, required this.endDate});
  final String endDate;

  @override
  State<NutrientTrends> createState() => _NutrientTrendsState();
}

class _NutrientTrendsState extends State<NutrientTrends> {
  int days = 7;
  Nutrient nutrient = Nutrient.calories;

  @override
  Widget build(BuildContext context) {
    final strings = l10n(context);
    final controller = context.watch<AppController>();
    final end = parseDate(widget.endDate);
    final daily = List.generate(days, (index) {
      final date = dateKey(addDays(end, index - days + 1));
      return (
        date,
        summarizeNutrition(date, controller.state.intakes).total(nutrient),
      );
    });
    final points = [
      for (final item in daily)
        ChartPoint(
          strings.date(item.$1),
          item.$2,
          strings.amount(item.$2, nutrient.unit),
        ),
    ];
    final average = daily.fold<double>(0, (sum, item) => sum + item.$2) / days;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SegmentedButton<int>(
            segments: [
              ButtonSegment(value: 7, label: Text(strings.t('days_7'))),
              ButtonSegment(value: 28, label: Text(strings.t('days_28'))),
            ],
            selected: {days},
            onSelectionChanged: (selection) =>
                setState(() => days = selection.first),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: DropdownButtonFormField<Nutrient>(
            isExpanded: true,
            initialValue: nutrient,
            decoration: fieldDecoration(strings.t('select_nutrient')),
            items: [
              for (final item in Nutrient.values)
                DropdownMenuItem(
                  value: item,
                  child: Text('${strings.nutrient(item)} (${item.unit})'),
                ),
            ],
            onChanged: (value) => setState(() => nutrient = value ?? nutrient),
          ),
        ),
        Text(
          '${strings.t('average')}: ${strings.amount(average, nutrient.unit)}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        SimpleChart(
          points: points,
          semanticLabel:
              '${strings.nutrient(nutrient)}, ${strings.t('days_$days')}, ${strings.t('average')} ${strings.amount(average, nutrient.unit)}',
        ),
      ],
    );
  }
}

InputDecoration fieldDecoration(String label) =>
    InputDecoration(labelText: label, border: const OutlineInputBorder());
