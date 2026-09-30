import 'package:flutter/material.dart';

import '../../../core/cycle/forecast.dart';
import '../../../core/model/cycle_records.dart';
import '../../../core/util/local_date.dart';
import '../../controller.dart';
import '../../theme.dart';
import '../../widgets/charts.dart';
import '../../widgets/common.dart';
import '../home_shell.dart';
import 'cycle_calendar.dart';
import 'cycle_day_sheet.dart';
import 'period_editor.dart';

/// Personal period tracker: status and estimate, calendar, history.
class CycleScreen extends StatefulWidget {
  const CycleScreen({super.key});

  @override
  State<CycleScreen> createState() => _CycleScreenState();
}

class _CycleScreenState extends State<CycleScreen> {
  LocalDate? _month;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final s = app.s;
    final today = app.today;
    final forecast = app.service.cycleForecast(today);
    final periods = app.data.periodsSorted;
    final ongoing = periods.isNotEmpty && periods.last.end == null
        ? periods.last
        : null;
    return Scaffold(
      appBar: AppBar(title: Text(s.navCycle), actions: mainActions(context)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
        children: [
          CycleStatusCard(forecast: forecast, title: s.today),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (ongoing == null)
                FilledButton.icon(
                  onPressed: () => app.run(() async {
                    await app.service.startPeriod(today);
                    app.showMessage(s.periodStarted(app.fmt.dayMonth(today)));
                  }),
                  icon: const Icon(Icons.water_drop),
                  label: Text(s.periodStartToday),
                )
              else
                FilledButton.icon(
                  onPressed: () => app.run(() async {
                    await app.service.endPeriod(ongoing, today);
                    app.showMessage(s.periodEnded(app.fmt.dayMonth(today)));
                  }),
                  icon: const Icon(Icons.stop_circle_outlined),
                  label: Text(s.periodEndToday),
                ),
              OutlinedButton.icon(
                onPressed: () => openPeriodEditor(context),
                icon: const Icon(Icons.history_edu_outlined),
                label: Text(s.addPastPeriod),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Card(
            semanticContainer: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CycleCalendar(
                    month: _month ?? today,
                    onMonthChanged: (m) => setState(() => _month = m),
                    onDayTap: (d) => showCycleDaySheet(context, d),
                    forecast: forecast,
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: CycleLegend(
                      showPredictions: forecast.predictionsEnabled,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          _StatsCard(forecast: forecast, periods: periods),
          const SizedBox(height: 12),
          _HistoryCard(periods: periods),
        ],
      ),
    );
  }
}

/// Headline, detail line, confidence and the "why" explanation.
class CycleStatusCard extends StatelessWidget {
  const CycleStatusCard({
    super.key,
    required this.forecast,
    this.onTap,
    this.title,
  });

  final CycleForecast forecast;
  final VoidCallback? onTap;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final s = app.s;
    final fmt = app.fmt;
    final sub = s.cycleSubline(forecast, fmt);
    return SectionCard(
      title: title ?? s.navCycle,
      icon: Icons.water_drop_outlined,
      iconColor: context.colors.cycle,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            s.cycleHeadline(forecast, fmt),
            style: context.text.headlineSmall,
          ),
          if (sub != null) ...[
            const SizedBox(height: 4),
            Text(sub, style: context.text.bodyMedium),
          ],
          // A period open for more than two weeks was probably not ended.
          if (forecast.on == app.today &&
              forecast.currentPeriod?.end == null &&
              (forecast.currentPeriodDay ?? 0) > 14) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const ExcludeSemantics(
                  child: Icon(Icons.hourglass_bottom, size: 20),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    s.longOngoingPeriodHint(forecast.currentPeriodDay!),
                    style: context.text.bodyMedium,
                  ),
                ),
              ],
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                onPressed: () => openPeriodEditor(
                  context,
                  period: forecast.currentPeriod,
                  closing: true,
                ),
                icon: const Icon(Icons.edit_calendar_outlined),
                label: Text(s.enterLastDay),
              ),
            ),
          ],
          if (forecast.confidence != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TagChip(
                s.confidenceName(forecast.confidence!),
                color: context.colors.cycle,
              ),
            ),
          ],
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
              onPressed: () => showExplanation(context, forecast),
              icon: const Icon(Icons.info_outline),
              label: Text(s.whyThisEstimate),
            ),
          ),
        ],
      ),
    );
  }
}

Future<void> showExplanation(BuildContext context, CycleForecast forecast) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (sheetContext) {
      final app = context.appRead;
      final s = app.s;
      final paragraphs = s.cycleExplanation(forecast, app.fmt);
      return DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.7,
        maxChildSize: 0.95,
        builder: (context, scroll) => ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          children: [
            Semantics(
              header: true,
              child: Text(s.explanationTitle, style: context.text.titleLarge),
            ),
            const SizedBox(height: 12),
            for (final p in paragraphs)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(p, style: context.text.bodyLarge),
              ),
          ],
        ),
      );
    },
  );
}

class _StatsCard extends StatelessWidget {
  const _StatsCard({required this.forecast, required this.periods});

  final CycleForecast forecast;
  final List<Period> periods;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final s = app.s;
    final fmt = app.fmt;
    final cycles = <(LocalDate, int)>[
      for (var i = 1; i < periods.length; i++)
        (
          periods[i - 1].start,
          periods[i - 1].start.daysUntil(periods[i].start),
        ),
    ];
    final recent = cycles.length > 12
        ? cycles.sublist(cycles.length - 12)
        : cycles;
    final points = [
      for (final (start, length) in recent)
        ChartPoint(
          label: fmt.dayMonth(start).split(' ').last,
          fullLabel: fmt.medium(start),
          value: length.toDouble(),
        ),
    ];
    return SectionCard(
      title: s.cycleStats,
      icon: Icons.insights_outlined,
      iconColor: context.colors.cycle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _row(
            context,
            s.averageCycle,
            forecast.medianCycleLength == null
                ? '–'
                : s.periodLengthDays(forecast.medianCycleLength!),
          ),
          _row(
            context,
            s.averagePeriod,
            forecast.medianPeriodLength == null
                ? '–'
                : s.periodLengthDays(forecast.medianPeriodLength!),
          ),
          _row(context, s.cycleLengthsChart, s.cyclesRecorded(cycles.length)),
          if (points.length >= 2) ...[
            const SizedBox(height: 12),
            ChartWithTable(
              points: points,
              formatValue: (v) => s.periodLengthDays(v.round()),
              showTableLabel: s.showTable,
              showChartLabel: s.showChart,
              emptyLabel: '–',
              chart: TrendChart(
                points: points,
                height: 150,
                semanticSummary:
                    '${s.cycleLengthsChart}: ${recent.map((c) => c.$2).join(', ')}',
                formatValue: (v) => fmt.integer(v),
                color: context.colors.cycle,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _row(BuildContext context, String label, String value) =>
      MergeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(child: Text(label)),
              Text(
                value,
                style: context.text.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
}

class _HistoryCard extends StatelessWidget {
  const _HistoryCard({required this.periods});

  final List<Period> periods;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final s = app.s;
    final fmt = app.fmt;
    final items = periods.reversed.toList();
    return SectionCard(
      title: s.periodHistory,
      icon: Icons.history,
      iconColor: context.colors.cycle,
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (items.isEmpty) EmptyHint(s.noPeriodsYet),
          for (var i = 0; i < items.length && i < 60; i++)
            Builder(
              builder: (context) {
                final p = items[i];
                final next = i > 0 ? items[i - 1] : null;
                final length =
                    p.lengthDays ?? (p.start.daysUntil(app.today) + 1);
                final range = p.end == null
                    ? '${fmt.medium(p.start)} – ${s.periodStillOngoing}'
                    : '${fmt.medium(p.start)} – ${fmt.medium(p.end!)}';
                final details = [
                  s.periodLengthDays(length < 1 ? 1 : length),
                  if (next != null)
                    s.cycleLengthDays(p.start.daysUntil(next.start)),
                  if (p.note != null) p.note!,
                ].join(' · ');
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(range),
                  subtitle: Text(details),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => openPeriodEditor(context, period: p),
                );
              },
            ),
        ],
      ),
    );
  }
}
