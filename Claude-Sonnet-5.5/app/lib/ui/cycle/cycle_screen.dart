import 'package:flutter/material.dart';

import '../../core/civil.dart';
import '../../core/cycle.dart';
import '../../core/db.dart';
import '../../core/models.dart';
import '../../core/nutrients.dart' show roundTo;
import '../../state/app_state.dart';
import '../day/day_detail_screen.dart';
import '../history/history_screen.dart';
import '../l10n_x.dart';
import '../symptoms/symptom_screen.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'calendar.dart';
import 'cycle_widgets.dart';

/// Bereich "Zyklus": Einschätzung, Monatskalender und Historie der Perioden.
class CycleScreen extends StatefulWidget {
  const CycleScreen({super.key});

  @override
  State<CycleScreen> createState() => _CycleScreenState();
}

class _CycleScreenState extends State<CycleScreen> {
  int _view = 0; // 0 Kalender, 1 Historie
  late Day _month;
  Day? _lastSelected;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final app = AppScope.of(context);
    if (_lastSelected == null) {
      _month = app.selectedDay.firstOfMonth;
    } else if (_lastSelected != app.selectedDay) {
      _month = app.selectedDay.firstOfMonth;
    }
    _lastSelected = app.selectedDay;
  }

  /// Markierungen aller Tage eines Monats.
  DayMark Function(Day) _marks(AppState app, Forecast today) {
    final month = _month;
    final last = month.lastOfMonth;
    final period = <Day, FlowLevel?>{};
    for (final p in app.db.periods) {
      final end = p.lastDay(app.today.isAfter(p.start) ? app.today : p.start);
      if (end.isBefore(month) || p.start.isAfter(last)) continue;
      for (var d = p.start; !d.isAfter(end); d = d.addDays(1)) {
        if (!d.isBefore(month) && !d.isAfter(last)) period[d] = p.flowOn(d);
      }
    }
    final predicted = <Day>{};
    final window = <Day>{};
    if (today.available) {
      final n = today.predictedPeriodDays ?? 1;
      for (var i = 0; i < today.upcoming.length; i++) {
        final u = today.upcoming[i];
        for (var k = 0; k < n; k++) {
          final d = u.predictedStart.addDays(k);
          if (!d.isBefore(app.today)) predicted.add(d);
        }
        if (i == 0) {
          for (var d = u.earliest; !d.isAfter(u.latest); d = d.addDays(1)) {
            if (!d.isBefore(app.today)) window.add(d);
          }
        }
      }
    }
    return (Day d) => DayMark(
      inPeriod: period.containsKey(d),
      flow: period[d],
      predicted: predicted.contains(d),
      window: window.contains(d),
      symptoms: app.db.symptoms.on(d).isNotEmpty,
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final l = context.l10n;
    final color = areaColor(Area.cycle, context.theme.brightness);
    final forecast = app.core.cycleForecast(app.selectedDay);
    final forecastToday = app.core.cycleForecast(app.today);
    return Scaffold(
      appBar: AppBar(
        title: Text(l.navCycle),
        actions: [
          IconButton(
            tooltip: l.historyTitle,
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const HistoryScreen(initialAreas: {Area.cycle, Area.symptoms}))),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showPeriodSheet(context, start: app.selectedDay),
        icon: const Icon(Icons.add),
        label: Text(l.cycleAddPeriod),
      ),
      body: ListView(
        key: const PageStorageKey('cycle'),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
        children: [
          if (app.settings.cycleForecast) ...[ForecastCard(forecast: forecast), const SizedBox(height: 12)],
          const PeriodQuickActions(),
          const SizedBox(height: 12),
          SegmentedButton<int>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: 0, icon: const Icon(Icons.calendar_month), label: Text(l.cycleTabCalendar)),
              ButtonSegment(value: 1, icon: const Icon(Icons.list), label: Text(l.cycleTabHistory)),
            ],
            selected: {_view},
            onSelectionChanged: (s) => setState(() => _view = s.first),
          ),
          const SizedBox(height: 12),
          if (_view == 0) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
                child: Column(
                  children: [
                    MonthCalendar(
                      month: _month,
                      today: app.today,
                      selected: app.selectedDay,
                      color: color,
                      markOf: _marks(app, forecastToday),
                      onSelect: app.selectDay,
                      onMonthChanged: (m) => setState(() => _month = m.firstOfMonth),
                    ),
                    const SizedBox(height: 4),
                    _Legend(color: color, showPredicted: app.settings.cycleForecast),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            _DayPanel(day: app.selectedDay, forecast: forecastToday),
          ] else
            _PeriodHistory(forecast: forecastToday),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  final Color color;
  final bool showPredicted;

  const _Legend({required this.color, required this.showPredicted});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    Widget item(Widget mark, String text) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        mark,
        const SizedBox(width: 6),
        Text(text, style: context.text.bodySmall),
      ],
    );
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Wrap(
        spacing: 16,
        runSpacing: 4,
        children: [
          item(
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            l.cycleLegendPeriod,
          ),
          if (showPredicted) ...[
            item(
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: color, width: 1.6),
                ),
              ),
              l.cycleLegendPredicted,
            ),
            item(Container(width: 14, height: 14, color: color.withValues(alpha: 0.18)), l.cycleLegendWindow),
          ],
          item(
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: context.colors.tertiary, shape: BoxShape.circle),
            ),
            l.cycleLegendSymptom,
          ),
        ],
      ),
    );
  }
}

/// Panel zum gewählten Tag: Periode, Blutungsstärke, Symptome, Tagesdetail.
class _DayPanel extends StatelessWidget {
  final Day day;
  final Forecast forecast;

  const _DayPanel({required this.day, required this.forecast});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final l = context.l10n;
    final f = context.fmt;
    final color = areaColor(Area.cycle, context.theme.brightness);
    final periods = app.db.periodsOn(day);
    final current = periods.isEmpty ? null : periods.first;
    final flow = current?.flowOn(day);
    final symptoms = app.db.symptoms.on(day);
    final predicted = forecast.available && forecast.predictedPeriodDaySet.contains(day) && !day.isBefore(app.today);
    return SectionCard(
      title: f.dateLong(day),
      icon: Icons.event,
      accent: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            current == null
                ? (predicted ? l.cycleDayPredicted : l.cycleDayNoPeriod)
                : l.cycleDayInPeriod('${current.start.daysUntil(day) + 1}'),
            style: context.text.titleSmall,
          ),
          const SizedBox(height: 8),
          Text(l.cycleFlowOnDay, style: context.text.bodyMedium),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final v in FlowLevel.values)
                ChoiceChip(
                  label: Text(l.flow(v)),
                  selected: current != null && flow == v,
                  onSelected: (sel) async {
                    try {
                      await app.db.markFlowOn(day, sel ? v : null);
                    } on DomainException catch (e) {
                      if (context.mounted) showMessage(context, periodErrorText(context, e));
                    }
                  },
                ),
              if (current != null)
                ActionChip(
                  avatar: const Icon(Icons.close, size: 18),
                  label: Text(l.cycleFlowRemove),
                  onPressed: () async {
                    // Nur diesen Tag aus der Periode nehmen, wenn er am Rand liegt;
                    // sonst die Periode zum Bearbeiten öffnen.
                    final p = current;
                    if (p.end == day && p.start != day) {
                      await app.db.savePeriod(p.copyWith(end: () => day.addDays(-1)));
                    } else if (p.start == day && p.end != null && p.end != day) {
                      await app.db.savePeriod(p.copyWith(start: day.addDays(1)));
                    } else if (p.start == day && (p.end == day || p.end == null)) {
                      await app.db.deletePeriod(p.id);
                    } else if (context.mounted) {
                      await showPeriodSheet(context, existing: p);
                    }
                  },
                ),
            ],
          ),
          if (current != null) ...[
            const SizedBox(height: 4),
            TextButton.icon(
              onPressed: () => showPeriodSheet(context, existing: current),
              icon: const Icon(Icons.edit_outlined),
              label: Text(l.cycleEditPeriod),
            ),
            if (current.notes != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(current.notes!, style: context.text.bodyMedium),
              ),
          ],
          const Divider(height: 24),
          Text(l.cycleDaySymptoms, style: context.text.titleSmall),
          if (symptoms.isEmpty) EmptyHint(l.symptomNoEntries) else for (final s in symptoms) SymptomTile(entry: s),
          Wrap(
            spacing: 8,
            children: [
              TextButton.icon(
                onPressed: () => showSymptomSheet(context, day: day),
                icon: const Icon(Icons.add),
                label: Text(l.cycleAddSymptomHere),
              ),
              TextButton.icon(
                onPressed: () =>
                    Navigator.of(context).push(MaterialPageRoute(builder: (_) => DayDetailScreen(initialDay: day))),
                icon: const Icon(Icons.open_in_new),
                label: Text(l.cycleOpenDayDetail),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Liste aller Perioden mit Zykluslänge und Kennzahlen.
class _PeriodHistory extends StatelessWidget {
  final Forecast forecast;

  const _PeriodHistory({required this.forecast});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final l = context.l10n;
    final f = context.fmt;
    final color = areaColor(Area.cycle, context.theme.brightness);
    final periods = app.db.periods.reversed.toList();
    if (periods.isEmpty) {
      return EmptyHint(l.cycleHistoryEmpty, icon: Icons.water_drop_outlined);
    }
    final done = [
      for (final p in app.db.periods)
        if (p.lengthDays != null && !p.spottingOnly) p.lengthDays!,
    ];
    final avgPeriod = done.isEmpty ? null : done.reduce((a, b) => a + b) / done.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionCard(
          title: l.cycleStatsTitle,
          icon: Icons.insights,
          accent: color,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(l.cycleStatsCount(periods.length), style: context.text.bodyLarge),
              if (forecast.averageCycleDays != null)
                Text(l.cycleStatsAvg(f.n(forecast.averageCycleDays!, 1)), style: context.text.bodyLarge),
              if (avgPeriod != null)
                Text(l.cycleStatsPeriod(f.n(roundTo(avgPeriod, 1), 1)), style: context.text.bodyLarge),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Column(
            children: [
              for (var i = 0; i < periods.length; i++) ...[
                _PeriodTile(period: periods[i], previous: i + 1 < periods.length ? periods[i + 1] : null),
                if (i < periods.length - 1) const Divider(height: 1),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _PeriodTile extends StatelessWidget {
  final PeriodRecord period;
  final PeriodRecord? previous;

  const _PeriodTile({required this.period, required this.previous});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final l = context.l10n;
    final f = context.fmt;
    final p = period;
    final title = p.end == null
        ? l.historyPeriodOpen(f.date(p.start))
        : l.historyPeriodTitle(f.date(p.start), f.date(p.end!));
    final missingEnd = p.end == null && app.today.isAfter(p.start.addDays(PeriodRecord.openMaxDays - 1));
    final cycle = previous?.start.daysUntil(p.start);
    final sub = [
      if (p.lengthDays != null) l.cycleHistoryDays(p.lengthDays!),
      if (p.flow != null) l.flow(p.flow),
      if (cycle != null && cycle > 0) l.cycleHistoryCycle('$cycle'),
      if (missingEnd) l.cycleEndMissing,
      if (p.spottingOnly) l.flowSpotting,
      if (p.notes != null) p.notes!,
    ].join(' · ');
    return ListTile(
      leading: Icon(Icons.water_drop_outlined, color: areaColor(Area.cycle, context.theme.brightness)),
      title: Text(title),
      subtitle: Text(sub),
      trailing: const Icon(Icons.edit_outlined, size: 18),
      onTap: () => showPeriodSheet(context, existing: p),
    );
  }
}
