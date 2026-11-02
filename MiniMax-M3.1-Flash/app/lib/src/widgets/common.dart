import 'package:flutter/material.dart';

/// A titled card used all over the app.
class SectionCard extends StatelessWidget {
  const SectionCard({
    required this.child,
    super.key,
    this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.padding = const EdgeInsets.fromLTRB(16, 14, 16, 16),
  });

  /// Optional headline of the card.
  final String? title;
  final String? subtitle;
  final Widget? trailing;
  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Widget content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        if (title != null)
        Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title ?? '',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  if (subtitle != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        subtitle!,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
        if (title != null) const SizedBox(height: 12),
        child,
      ],
    );
    if (onTap == null) {
      return Card(
        child: Padding(padding: padding, child: content),
      );
    }
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(padding: padding, child: content),
      ),
    );
  }
}

/// Progress bar with a label, used for the daily goals.
class GoalBar extends StatelessWidget {
  const GoalBar({
    required this.label,
    required this.value,
    required this.goal,
    required this.unit,
    super.key,
  });

  final String label;
  final double value;
  final double goal;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final double ratio = goal <= 0 ? 0 : (value / goal).clamp(0.0, 1.0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(label, style: theme.textTheme.bodyMedium),
              ),
              Text(
                '${_format(value)} / ${_format(goal)} $unit',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              backgroundColor:
                  theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }

  static String _format(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(1);
  }
}

/// Friendly empty state.
class EmptyState extends StatelessWidget {
  const EmptyState({required this.message, super.key, this.icon});

  final String message;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 12),
      child: Column(
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(
              icon,
              size: 34,
              color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.7),
            ),
            const SizedBox(height: 10),
          ],
          Text(
            message,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// A simple line chart for numeric series.
class SimpleLineChart extends StatelessWidget {
  const SimpleLineChart({
    required this.values,
    super.key,
    this.labels,
    this.height = 160,
    this.color,
    this.filled = true,
  });

  final List<double> values;
  final List<String>? labels;
  final double height;
  final Color? color;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    if (values.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            '–',
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }
    return SizedBox(
      height: height,
      child: CustomPaint(
        painter: _LineChartPainter(
          values: values,
          color: color ?? theme.colorScheme.primary,
          gridColor: theme.colorScheme.outlineVariant.withValues(alpha: 0.5),
          labelColor: theme.colorScheme.onSurfaceVariant,
          labels: labels,
          filled: filled,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  _LineChartPainter({
    required this.values,
    required this.color,
    required this.gridColor,
    required this.labelColor,
    required this.labels,
    required this.filled,
  });

  final List<double> values;
  final Color color;
  final Color gridColor;
  final Color labelColor;
  final List<String>? labels;
  final bool filled;

  @override
  void paint(Canvas canvas, Size size) {
    final double left = 6;
    final double right = size.width - 6;
    final double top = 10;
    final double bottom = size.height - (labels != null ? 20 : 6);
    if (right <= left || bottom <= top) return;

    final Paint grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;
    for (int i = 0; i <= 3; i++) {
      final double y = top + (bottom - top) * (i / 3);
      canvas.drawLine(Offset(left, y), Offset(right, y), grid);
    }

    double min = values.first;
    double max = values.first;
    for (final double value in values) {
      if (value < min) min = value;
      if (value > max) max = value;
    }
    if ((max - min).abs() < 1e-9) {
      max = min + 1;
      min = min - 1;
    }
    final double span = max - min;

    final List<Offset> points = <Offset>[];
    for (int i = 0; i < values.length; i++) {
      final double x = values.length == 1
          ? (left + right) / 2
          : left + (right - left) * (i / (values.length - 1));
      final double y = bottom - (values[i] - min) / span * (bottom - top);
      points.add(Offset(x, y));
    }

    final Path path = Path()..moveTo(points.first.dx, points.first.dy);
    for (int i = 1; i < points.length; i++) {
      path.lineTo(points[i].dx, points[i].dy);
    }

    if (filled && points.length > 1) {
      final Path area = Path.from(path)
        ..lineTo(points.last.dx, bottom)
        ..lineTo(points.first.dx, bottom)
        ..close();
      canvas.drawPath(
        area,
        Paint()..color = color.withValues(alpha: 0.14),
      );
    }

    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..strokeWidth = 2.2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );

    for (final Offset point in points) {
      canvas.drawCircle(point, 3, Paint()..color = color);
    }

    if (labels != null && labels!.isNotEmpty) {
      final TextPainter painter = TextPainter(
        textDirection: TextDirection.ltr,
        textAlign: TextAlign.center,
      );
      painter.text = TextSpan(
        text: labels!.first,
        style: TextStyle(fontSize: 10, color: labelColor),
      );
      painter.layout();
      painter.paint(
        canvas,
        Offset(left, bottom + 4),
      );
      painter.text = TextSpan(
        text: labels!.last,
        style: TextStyle(fontSize: 10, color: labelColor),
      );
      painter.layout();
      painter.paint(
        canvas,
        Offset(right - painter.width, bottom + 4),
      );
    }
  }

  @override
  bool shouldRepaint(_LineChartPainter oldDelegate) =>
      oldDelegate.values != values || oldDelegate.color != color;
}

/// Horizontal segmented control used for small switches.
class SegmentedSwitch<T> extends StatelessWidget {
  const SegmentedSwitch({
    required this.value,
    required this.options,
    required this.onChanged,
    super.key,
  });

  final T value;
  final Map<T, String> options;
  final ValueChanged<T> onChanged;

  @override
  Widget build(BuildContext context) {
    return SegmentedButton<T>(
      segments: options.entries
          .map((MapEntry<T, String> e) => ButtonSegment<T>(
                value: e.key,
                label: Text(e.value),
              ))
          .toList(growable: false),
      selected: <T>{value},
      onSelectionChanged: (Set<T> selection) {
        if (selection.isNotEmpty) onChanged(selection.first);
      },
      showSelectedIcon: false,
    );
  }
}
