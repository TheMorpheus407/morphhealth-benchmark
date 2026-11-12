library morphhealth.ui.weight_page;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:morphhealth/core/repository.dart';
import 'package:morphhealth/l10n/app_localizations.dart';
import 'package:morphhealth/ui/weight_entry_page.dart';

class WeightPage extends StatefulWidget {
  final HealthRepository repository;
  const WeightPage({super.key, required this.repository});

  @override
  State<WeightPage> createState() => _WeightPageState();
}

class _WeightPageState extends State<WeightPage> {
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final entries = List<WeightEntry>.from(widget.repository.weightEntries)
      ..sort((a, b) => b.date.compareTo(a.date));

    return Column(
      children: [
        Expanded(
          flex: 2,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: WeightChart(entries: entries, repository: widget.repository),
          ),
        ),
        Expanded(
          flex: 3,
          child: ListView.builder(
            padding: const EdgeInsets.all(12),
            itemCount: entries.length,
            itemBuilder: (_, i) {
              final e = entries[i];
              return Dismissible(
                key: ValueKey(e.id),
                onDismissed: (_) => widget.repository.deleteWeightEntry(e.id),
                background: const ColoredBox(color: Colors.red),
                child: ListTile(
                  title: Text('${e.value.toStringAsFixed(1)} ${e.unit.key.toUpperCase()}'),
                  subtitle: Text(DateFormat.yMMMd(widget.repository.settings.locale).format(e.date)),
                  trailing: const Icon(Icons.arrow_forward_ios),
                  onTap: () => _edit(context, e),
                ),
              );
            },
          ),
        ),
        SafeArea(
          top: false,
          child: FilledButton.icon(
            icon: const Icon(Icons.add),
            label: Text(l.msg('add')),
            onPressed: () => _add(context),
          ),
        ),
      ],
    );
  }

  Future<void> _add(BuildContext context) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => WeightEntryPage(repository: widget.repository, day: DateTime.now()),
    ));
    setState(() {});
  }

  Future<void> _edit(BuildContext context, WeightEntry entry) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => WeightEntryPage(repository: widget.repository, day: entry.date, entry: entry),
    ));
    setState(() {});
  }
}

class WeightChart extends StatelessWidget {
  final List<WeightEntry> entries;
  final HealthRepository repository;
  const WeightChart({super.key, required this.entries, required this.repository});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final sorted = List<WeightEntry>.from(entries)..sort((a, b) => a.date.compareTo(b.date));
    if (sorted.isEmpty) {
      return Center(child: Text(l.msg('noData')));
    }
    return Column(
      children: [
        Expanded(
          child: CustomPaint(
            size: Size.infinite,
            painter: _WeightPainter(
              color: Theme.of(context).colorScheme.primary,
              points: sorted.map((e) => _Point(e.date, e.valueInKg)).toList(),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
                '${sorted.first.valueInKg.toStringAsFixed(1)} kg · ${DateFormat.yMMMd(repository.settings.locale).format(sorted.first.date)}'),
            const Spacer(),
            Text(
                '${sorted.last.valueInKg.toStringAsFixed(1)} kg · ${DateFormat.yMMMd(repository.settings.locale).format(sorted.last.date)}'),
          ],
        ),
      ],
    );
  }
}

class _Point {
  final DateTime date;
  final double kg;
  _Point(this.date, this.kg);
}

class _WeightPainter extends CustomPainter {
  final Color color;
  final List<_Point> points;
  _WeightPainter({required this.color, required this.points});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final minKg = points.map((p) => p.kg).reduce((a, b) => a < b ? a : b);
    final maxKg = points.map((p) => p.kg).reduce((a, b) => a > b ? a : b);
    final range = (maxKg - minKg).clamp(0.1, double.maxFinite);
    final pad = range * 0.15;
    final yMin = minKg - pad;
    final yMax = maxKg + pad;

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    final dotPaint = Paint()..color = color;

    double x(int i) => (i / (points.length - 1)) * size.width;
    double y(double kg) => size.height - ((kg - yMin) / (yMax - yMin)) * size.height;

    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      final px = x(i);
      final py = y(p.kg);
      if (i == 0) path.moveTo(px, py);
      else path.lineTo(px, py);
    }
    canvas.drawPath(path, linePaint);
    for (var i = 0; i < points.length; i++) {
      final p = points[i];
      canvas.drawCircle(Offset(x(i), y(p.kg)), 3.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _WeightPainter old) => old.points != points || old.color != color;
}