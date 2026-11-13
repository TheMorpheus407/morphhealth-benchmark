import 'package:flutter/material.dart';
import 'package:morphhealth_core/morphhealth_core.dart';

import '../theme.dart';
import '../widgets/common.dart';
import 'period_form_screen.dart';

/// All recorded periods, newest first, with their length and the length of
/// the cycle each one began.
class CycleHistoryScreen extends StatelessWidget {
  const CycleHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final app = context.app;
    final f = app.forecast;
    final periods = app.data.periodsSorted;
    final header = <Widget>[
      if (f.predictionsEnabled && f.cyclesUsed > 0)
        MhCard(
          child: AdaptiveColumns(
            minColumnWidth: 130,
            children: [
              GoalBar(
                label: l.typicalCycle,
                value: f.shortestDays == f.longestDays
                    ? l.daysCount(f.typicalLengthDays!)
                    : '${l.daysCount(f.typicalLengthDays!)} '
                          '(${l.cycleRange(f.shortestDays!, f.longestDays!)})',
              ),
              GoalBar(
                label: l.typicalPeriod,
                value: l.daysCount(f.typicalPeriodLengthDays),
              ),
            ],
          ),
        ),
      if (f.predictionsEnabled && f.cyclesUsed > 0) const SizedBox(height: 12),
    ];

    return Scaffold(
      appBar: AppBar(title: Text(l.cycleHistory)),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'period-add',
        icon: const Icon(Icons.add),
        label: Text(l.periodNew),
        onPressed: () => Navigator.of(context).push<void>(
          MaterialPageRoute(builder: (_) => const PeriodFormScreen()),
        ),
      ),
      body: SafeArea(
        child: periods.isEmpty
            ? SingleChildScrollView(
                child: EmptyHint(
                  icon: Icons.calendar_month_outlined,
                  text: l.noPeriods,
                ),
              )
            : ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 168),
                itemCount: header.length + periods.length,
                itemBuilder: (context, i) {
                  if (i < header.length) return header[i];
                  // Newest first.
                  final index = periods.length - 1 - (i - header.length);
                  final period = periods[index];
                  final next = index + 1 < periods.length
                      ? periods[index + 1]
                      : null;
                  return PeriodTile(
                    period: period,
                    cycleLength: next?.start.daysSince(period.start),
                  );
                },
              ),
      ),
    );
  }
}

/// One period in a list; tap to edit.
class PeriodTile extends StatelessWidget {
  final Period period;

  /// Days from this period's start to the next one's, if there is a next.
  final int? cycleLength;

  const PeriodTile({super.key, required this.period, this.cycleLength});

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final fmt = context.fmt;
    final app = context.app;
    final today = app.today;
    final colors = MhColors.of(context);
    final end = period.end;
    final running = period.isRunning(today);
    final title = end != null
        ? fmt.range(period.start, end)
        : '${fmt.dateCompact(period.start)} – '
              '${running ? l.periodRunning : l.endNotRecorded}';
    final strongest = period.flow.values.fold<FlowLevel?>(
      null,
      (m, f) => m == null || f.index > m.index ? f : m,
    );
    return ListTile(
      leading: Icon(Icons.water_drop, color: colors.period),
      title: Text(title),
      subtitle: Text(
        [
          if (period.lengthDays != null) l.daysCount(period.lengthDays!),
          if (cycleLength != null) l.cycleOf(cycleLength!),
          if (strongest != null) '${l.flowTitle}: ${l.flow(strongest)}',
          if (period.note != null) period.note!,
        ].join(' · '),
      ),
      trailing: const Icon(Icons.edit_outlined),
      onTap: () => Navigator.of(context).push<void>(
        MaterialPageRoute(builder: (_) => PeriodFormScreen(period: period)),
      ),
    );
  }
}
