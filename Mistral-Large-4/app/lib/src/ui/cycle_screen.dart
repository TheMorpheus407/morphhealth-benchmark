// Zyklus-Bereich: Monatskalender, persönliche Einschätzung, Verlauf.
library;

import 'package:flutter/material.dart';

import '../core/parse.dart';
import '../cycle/forecast.dart';
import '../data/repository.dart';
import '../l10n/app_strings.dart';
import '../model/cycle.dart';
import 'day_detail_screen.dart';
import 'scope.dart';
import 'widgets.dart';

class CycleScreen extends StatefulWidget {
  const CycleScreen({super.key});

  @override
  State<CycleScreen> createState() => _CycleScreenState();
}

class _CycleScreenState extends State<CycleScreen> {
  late DateTime _month; // erster Tag des angezeigten Monats (UTC)

  @override
  void initState() {
    super.initState();
    final DateTime now = DateTime.now();
    _month = DateTime.utc(now.year, now.month, 1);
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = StringsScope.of(context);
    final MorphRepository repo = MorphScope.repoOf(context);
    return ListenableBuilder(
      listenable: MorphScope.listenableOf(context),
      builder: (BuildContext context, Widget? _) {
        final String today = todayString();
        final CycleForecast forecast =
            computeCycleForecast(repo.document, today);
        final PeriodRecord? ongoing =
            repo.periodOn(today, today: today);
        return ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: <Widget>[
            _monthHeader(strings),
            _calendar(strings, repo, forecast, today),
            _legend(strings),
            _quickActions(strings, repo, today, ongoing),
            _forecastCard(strings, forecast),
            _historySection(strings, repo),
          ],
        );
      },
    );
  }

  Widget _monthHeader(AppStrings strings) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
      child: Row(
        children: <Widget>[
          IconButton(
            tooltip: strings.back,
            icon: const Icon(Icons.chevron_left),
            onPressed: () => setState(() => _month =
                DateTime.utc(_month.year, _month.month - 1, 1)),
          ),
          Expanded(
            child: Text(
              '${strings.monthName(_month.month)} ${_month.year}',
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
          ),
          IconButton(
            tooltip: strings.tomorrow,
            icon: const Icon(Icons.chevron_right),
            onPressed: () => setState(() => _month =
                DateTime.utc(_month.year, _month.month + 1, 1)),
          ),
        ],
      ),
    );
  }

  Widget _calendar(AppStrings strings, MorphRepository repo,
      CycleForecast forecast, String today) {
    final int daysInMonth = DateTime.utc(_month.year, _month.month + 1, 0).day;
    final int offset = (_month.weekday - 1) % 7; // Montag-first
    final int cellCount = offset + daysInMonth;
    final int rows = (cellCount / 7).ceil();

    // Prognose-Bereich
    final String? predStart = forecast.nextPeriodStartEstimate;
    final String? predEnd = forecast.nextPeriodEndEstimate;

    bool isRecorded(String date) => repo.periodOn(date, today: today) != null;

    bool isPredicted(String date) {
      if (predStart == null || predEnd == null) return false;
      return date.compareTo(predStart) >= 0 && date.compareTo(predEnd) <= 0;
    }

    bool hasSymptom(String date) =>
        repo.symptomEntriesForDate(date).isNotEmpty;

    bool hasWeight(String date) => repo.weightEntryOn(date) != null;

    final List<Widget> cells = <Widget>[];
    for (int i = 0; i < rows * 7; i++) {
      final int dayNumber = i - offset + 1;
      if (dayNumber < 1 || dayNumber > daysInMonth) {
        cells.add(const SizedBox.shrink());
        continue;
      }
      final DateTime day =
          DateTime.utc(_month.year, _month.month, dayNumber);
      final String date = formatDate(day);
      final bool isToday = date == today;
      final bool recorded = isRecorded(date);
      final bool predicted = !recorded && isPredicted(date);
      final bool symptom = hasSymptom(date);
      final bool weight = hasWeight(date);
      cells.add(_DayCell(
        day: dayNumber,
        isToday: isToday,
        recorded: recorded,
        predicted: predicted,
        hasSymptom: symptom,
        hasWeight: weight,
        strings: strings,
        onTap: () => Navigator.of(context).push(
          MaterialPageRoute<Widget>(
              builder: (_) => DayDetailScreen(date: date)),
        ),
      ));
    }

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: <Widget>[
              for (int w = 1; w <= 7; w++)
                Expanded(
                  child: Text(
                    strings.weekdayShort(w),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
            ],
          ),
        ),
        GridView.count(
          crossAxisCount: 7,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          children: cells,
        ),
      ],
    );
  }

  Widget _legend(AppStrings strings) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Wrap(
        spacing: 12,
        runSpacing: 4,
        children: <Widget>[
          _LegendDot(label: strings.legendRecorded, color: _recordedColor(scheme)),
          _LegendDot(
              label: strings.legendPredicted,
              color: _recordedColor(scheme).withValues(alpha: 0.35)),
          _LegendDot(label: strings.legendSymptom, color: scheme.tertiary),
          _LegendDot(label: strings.legendWeight, color: scheme.primary),
        ],
      ),
    );
  }

  Widget _quickActions(AppStrings strings, MorphRepository repo, String today,
      PeriodRecord? ongoing) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: <Widget>[
          if (ongoing != null)
            FilledButton.tonalIcon(
              onPressed: () async {
                ongoing.end = today;
                await repo.updatePeriod(ongoing);
              },
              icon: const Icon(Icons.stop_circle_outlined),
              label: Text(strings.endPeriodToday),
            )
          else
            FilledButton.tonalIcon(
              onPressed: () async {
                await repo.addPeriod(PeriodRecord(
                  id: '',
                  start: today,
                  end: null,
                  flow: FlowLevel.medium,
                ));
              },
              icon: const Icon(Icons.play_circle_outline),
              label: Text(strings.startPeriodToday),
            ),
          FilledButton.tonalIcon(
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<Widget>(
                    builder: (_) => PeriodEditScreen(initialDate: today))),
            icon: const Icon(Icons.add),
            label: Text(strings.addPeriod),
          ),
        ],
      ),
    );
  }

  Widget _forecastCard(AppStrings strings, CycleForecast forecast) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final List<Widget> rows = <Widget>[];
    rows.add(Chip(
      label: Text(_stateLabel(strings, forecast.state)),
      backgroundColor: scheme.secondaryContainer,
      labelStyle: TextStyle(color: scheme.onSecondaryContainer),
    ));
    if (forecast.currentCycleDay != null) {
      rows.add(StatRow(
          label: strings.cycleDayLabel(forecast.currentCycleDay!),
          value: forecast.lastPeriodStart ?? ''));
    }
    if (forecast.nextPeriodStartEstimate != null) {
      rows.add(StatRow(
        label: strings.expectedStartLabel,
        value: strings.formatDateShort(
            parseDate(forecast.nextPeriodStartEstimate!)!),
      ));
      if (forecast.nextPeriodStartRangeStart != null &&
          forecast.nextPeriodStartRangeEnd != null) {
        rows.add(StatRow(
          label: strings.uncertaintyRangeLabel,
          value:
              '${strings.formatDateShort(parseDate(forecast.nextPeriodStartRangeStart!)!)} – ${strings.formatDateShort(parseDate(forecast.nextPeriodStartRangeEnd!)!)}',
        ));
      }
      if (forecast.nextPeriodEndEstimate != null) {
        rows.add(StatRow(
          label: strings.expectedEndLabel,
          value: strings.formatDateShort(
              parseDate(forecast.nextPeriodEndEstimate!)!),
        ));
      }
    }
    if (forecast.averageCycleDays != null) {
      rows.add(StatRow(
        label: strings.averageCycleLabel,
        value: strings.daysCount(forecast.averageCycleDays!.round()),
      ));
    }
    if (forecast.averagePeriodDays != null) {
      rows.add(StatRow(
        label: strings.averagePeriodLabel,
        value: strings.daysCount(forecast.averagePeriodDays!.round()),
      ));
    }
    if (forecast.confidence != null) {
      rows.add(StatRow(
        label: strings.confidenceLabel,
        value: switch (forecast.confidence!) {
          'high' => strings.confidenceHigh,
          'medium' => strings.confidenceMedium,
          _ => strings.confidenceLow,
        },
      ));
    }
    if (forecast.periodsRecorded == 0) {
      rows.add(Text(strings.noPeriods));
    }
    return SectionCard(
      title: strings.forecastTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Wrap(
              children: <Widget>[if (rows.isNotEmpty) rows.first]),
          for (final Widget r in rows.skip(1)) r,
          const SizedBox(height: 8),
          ExpansionTile(
            title: Text(strings.explanationTitle),
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(strings.lang == 'de'
                    ? forecast.explanationDe()
                    : forecast.explanationEn()),
              ),
            ],
          ),
          Text(strings.disclaimer,
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  String _stateLabel(AppStrings strings, String state) => switch (state) {
        'no_data' => strings.stateNoData,
        'insufficient_data' => strings.stateInsufficient,
        'before_next' => strings.stateBeforeNext,
        'within_recorded' => strings.stateWithinRecorded,
        'within_predicted' => strings.stateWithinPredicted,
        'between_predicted' => strings.stateBetweenPredicted,
        _ => state,
      };

  Widget _historySection(AppStrings strings, MorphRepository repo) {
    final List<PeriodRecord> periods =
        repo.sortedPeriods.reversed.toList();
    return SectionCard(
      title: strings.cycleHistory,
      trailing: IconButton(
        tooltip: strings.addPeriod,
        icon: const Icon(Icons.add),
        onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<Widget>(
                builder: (_) => PeriodEditScreen(
                    initialDate: todayString()))),
      ),
      child: periods.isEmpty
          ? Text(strings.noPeriods)
          : Column(
              children: <Widget>[
                for (final PeriodRecord p in periods.take(12).toList())
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: Icon(Icons.calendar_today,
                        color: _recordedColor(Theme.of(context).colorScheme),
                        size: 20),
                    title: Text(p.end == null
                        ? '${p.start} (${strings.periodOngoing})'
                        : '${p.start} – ${p.end}'),
                    subtitle: Text(
                        '${strings.flowName(p.flow)} · ${_duration(strings, p)}'
                        '${p.note != null && p.note!.isNotEmpty ? ' · ${p.note}' : ''}'),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<Widget>(
                          builder: (_) => PeriodEditScreen(period: p)),
                    ),
                  ),
              ],
            ),
    );
  }

  String _duration(AppStrings strings, PeriodRecord p) {
    if (p.end == null) return strings.periodOpen;
    final DateTime? s = parseDate(p.start);
    final DateTime? e = parseDate(p.end!);
    if (s == null || e == null) return '';
    return strings.daysCount(e.difference(s).inDays + 1);
  }

  static Color _recordedColor(ColorScheme scheme) =>
      scheme.brightness == Brightness.dark
          ? const Color(0xFFB3564D)
          : const Color(0xFF9E4A42);
}

/// Ein Kalendertag.
class _DayCell extends StatelessWidget {
  final int day;
  final bool isToday;
  final bool recorded;
  final bool predicted;
  final bool hasSymptom;
  final bool hasWeight;
  final AppStrings strings;
  final VoidCallback onTap;

  const _DayCell({
    required this.day,
    required this.isToday,
    required this.recorded,
    required this.predicted,
    required this.hasSymptom,
    required this.hasWeight,
    required this.strings,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color recordedColor = _CycleScreenState._recordedColor(scheme);
    Color? background;
    Color textColor = scheme.onSurface;
    if (recorded) {
      background = recordedColor;
      textColor = Colors.white;
    } else if (predicted) {
      background = recordedColor.withValues(alpha: 0.25);
    }
    return Semantics(
      label: strings.formatDateLong(DateTime.utc(2000, 1, day)),
      button: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.all(2),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(8),
            border: isToday
                ? Border.all(color: scheme.primary, width: 2)
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text('$day',
                  style: TextStyle(
                      color: textColor,
                      fontWeight: isToday ? FontWeight.bold : FontWeight.normal)),
              if (hasSymptom || hasWeight)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    if (hasSymptom)
                      Container(
                        width: 5,
                        height: 5,
                        decoration: BoxDecoration(
                            color: recorded ? Colors.white : scheme.tertiary,
                            shape: BoxShape.circle),
                      ),
                    if (hasWeight)
                      Container(
                        width: 5,
                        height: 5,
                        margin: const EdgeInsets.only(left: 2),
                        decoration: BoxDecoration(
                            color: recorded ? Colors.white : scheme.primary,
                            shape: BoxShape.circle),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final String label;
  final Color color;
  const _LegendDot({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 4),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}

// ------------------------------------------------------------------ Periode bearbeiten

/// Periode erfassen/bearbeiten (Beginn, Ende, Blutungsstärke, Notiz).
class PeriodEditScreen extends StatefulWidget {
  final PeriodRecord? period;
  final String? initialDate;

  const PeriodEditScreen({super.key, this.period, this.initialDate});

  @override
  State<PeriodEditScreen> createState() => _PeriodEditScreenState();
}

class _PeriodEditScreenState extends State<PeriodEditScreen> {
  late DateTime _start;
  DateTime? _end;
  bool _ongoing = true;
  FlowLevel _flow = FlowLevel.medium;
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    final PeriodRecord? p = widget.period;
    if (p != null) {
      _start = parseDate(p.start) ?? DateTime.utc(
          DateTime.now().year, DateTime.now().month, DateTime.now().day);
      _end = p.end == null ? null : parseDate(p.end!);
      _ongoing = p.end == null;
      _flow = p.flow;
      _noteController = TextEditingController(text: p.note ?? '');
    } else {
      _start = parseDate(widget.initialDate ?? '') ?? DateTime.utc(
          DateTime.now().year, DateTime.now().month, DateTime.now().day);
      _ongoing = true;
      _noteController = TextEditingController();
    }
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final AppStrings strings = StringsScope.of(context);
    final MorphRepository repo = MorphScope.repoOf(context);
    if (_ongoing) {
      _end = null;
    }
    if (_end != null && formatDate(_end!) == formatDate(_start)) {
      _end = null; // Ein-Tages-Periode: Ende = null würde „läuft“ bedeuten —
      // stattdessen explizit denselben Tag als Ende speichern.
      _end = _start;
    }
    final PeriodRecord period = PeriodRecord(
      id: widget.period?.id ?? '',
      start: formatDate(_start),
      end: _end == null ? null : formatDate(_end!),
      flow: _flow,
      note: _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
    );
    if (widget.period == null) {
      await repo.addPeriod(period);
    } else {
      await repo.updatePeriod(period);
    }
    if (!mounted) return;
    showInfo(context, strings.periodSaved);
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final AppStrings strings = StringsScope.of(context);
    final MorphRepository repo = MorphScope.repoOf(context);
    final PeriodRecord? period = widget.period;
    if (period == null) return;
    if (await confirmDelete(context, message: strings.deletePeriodConfirm)) {
      await repo.deletePeriod(period.id);
      if (!mounted) return;
      showInfo(context, strings.periodDeleted);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = StringsScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.period == null
            ? strings.addPeriod
            : strings.editPeriod),
        actions: <Widget>[
          if (widget.period != null)
            IconButton(
              tooltip: strings.a11yDelete,
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          TextButton.icon(
            onPressed: () async {
              final DateTime? picked = await pickDate(context, initial: _start);
              if (picked != null && mounted) {
                setState(() => _start =
                    DateTime.utc(picked.year, picked.month, picked.day));
              }
            },
            icon: const Icon(Icons.calendar_today),
            label: Text(
                '${strings.periodStartLabel}: ${strings.formatDateShort(_start)}'),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(strings.periodOngoing),
            value: _ongoing,
            onChanged: (bool v) => setState(() => _ongoing = v),
          ),
          if (!_ongoing)
            TextButton.icon(
              onPressed: () async {
                final DateTime? picked =
                    await pickDate(context, initial: _end ?? _start);
                if (picked != null && mounted) {
                  setState(() => _end =
                      DateTime.utc(picked.year, picked.month, picked.day));
                }
              },
              icon: const Icon(Icons.calendar_today),
              label: Text(
                  '${strings.periodEndLabel}: ${_end == null ? strings.formatDateShort(_start) : strings.formatDateShort(_end!)}'),
            ),
          const SizedBox(height: 8),
          FlowPicker(
            value: _flow,
            onChanged: (FlowLevel f) => setState(() => _flow = f),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _noteController,
            decoration: InputDecoration(
              labelText: strings.periodNoteLabel,
              hintText: strings.optionalLabel,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save),
            label: Text(strings.save),
          ),
        ],
      ),
    );
  }
}
