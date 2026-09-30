import 'package:flutter/material.dart';

import '../../core/cycle.dart';
import '../../core/forecast_text.dart';
import '../l10n_x.dart';
import '../widgets/common.dart';

/// Verständliche Erklärung der persönlichen Einschätzung: Schritte in
/// Klartext, die verwendeten Abstände und die Regeln.
class ExplainScreen extends StatelessWidget {
  final Forecast forecast;

  const ExplainScreen({super.key, required this.forecast});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final f = context.fmt;
    final lines = explainForecast(forecast, f.lang);
    final disclaimer = lines.last;
    final steps = lines.sublist(0, lines.length - 1);
    return AppScaffold(
      appBar: AppBar(title: Text(l.cycleExplainTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          for (final s in steps)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(s, style: context.text.bodyLarge),
            ),
          const SizedBox(height: 8),
          Semantics(header: true, child: Text(l.cycleExplainIntervals, style: context.text.titleMedium)),
          const SizedBox(height: 8),
          if (forecast.intervals.isEmpty)
            EmptyHint(l.cycleExplainNoIntervals)
          else
            for (final i in forecast.intervals.reversed)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  i.used ? Icons.check_circle_outline : Icons.remove_circle_outline,
                  color: i.used ? context.colors.primary : context.colors.outline,
                ),
                title: Text(l.cycleIntervalRow(f.date(i.start), f.date(i.nextStart), '${i.days}')),
                subtitle: Text(switch (i.excludedReason) {
                  null => l.cycleExplainUsed,
                  'too_short' => l.cycleExplainTooShort,
                  'too_long' => l.cycleExplainTooLong,
                  _ => l.cycleExplainOlder,
                }),
              ),
          const SizedBox(height: 16),
          EmptyHint(disclaimer, icon: Icons.info_outline),
        ],
      ),
    );
  }
}
