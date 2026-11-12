library morphhealth.ui.cycle_page;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:morphhealth/core/repository.dart';
import 'package:morphhealth/l10n/app_localizations.dart';

class CyclePage extends StatefulWidget {
  final HealthRepository repository;
  final DateTime initialDate;
  const CyclePage({super.key, required this.repository, required this.initialDate});

  @override
  State<CyclePage> createState() => _CyclePageState();
}

class _CyclePageState extends State<CyclePage> {
  DateTime _month = DateTime.now();

  @override
  void initState() {
    super.initState();
    _month = DateTime(widget.initialDate.year, widget.initialDate.month);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final entries = widget.repository.cycleEntriesForMonth(_month);
    final forecast = widget.repository.forecastFor(
      DateTime.now(),
      locale: widget.repository.settings.locale,
    );

    return Column(
      children: [
        Expanded(
          flex: 2,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Row(
                  children: [
                    IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => setState(() => _month = DateTime(_month.year, _month.month - 1))),
                    Expanded(
                      child: Text(
                        DateFormat.yMMM(widget.repository.settings.locale).format(_month),
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => setState(() => _month = DateTime(_month.year, _month.month + 1))),
                  ],
                ),
                const SizedBox(height: 8),
                _WeekdayRow(locale: widget.repository.settings.locale),
                const SizedBox(height: 4),
                Expanded(child: _CalendarGrid(month: _month, entries: entries, onDaySelected: _editDay)),
              ],
            ),
          ),
        ),
        Expanded(
          flex: 3,
          child: _HistoryList(entries: entries, repository: widget.repository),
        ),
        if (forecast.hasPrediction)
          _ForecastCard(forecast: forecast, repository: widget.repository),
      ],
    );
  }

  Future<void> _editDay(DateTime day) async {
    final sameDay = widget.repository.cycleEntriesForMonth(day).firstWhere(
      (e) => e.startDate.year == day.year && e.startDate.month == day.month && e.startDate.day == day.day,
      orElse: () => CycleEntry(id: '', startDate: day, intensity: PeriodIntensity.spotting),
    );
    await _editPeriod(context, widget.repository, sameDay);
    setState(() {});
  }
}

class _WeekdayRow extends StatelessWidget {
  final String locale;
  const _WeekdayRow({required this.locale});

  @override
  Widget build(BuildContext context) {
    const weekdays = ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];
    return Row(
      children: weekdays
          .map((w) => Expanded(child: Text(w, textAlign: TextAlign.center, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600))))
          .toList(),
    );
  }
}

class _CalendarGrid extends StatelessWidget {
  final DateTime month;
  final List<CycleEntry> entries;
  final ValueChanged<DateTime> onDaySelected;
  const _CalendarGrid({required this.month, required this.entries, required this.onDaySelected});

  @override
  Widget build(BuildContext context) {
    final first = DateTime(month.year, month.month, 1);
    final startOffset = (first.weekday - DateTime.monday) % 7;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final today = DateTime.now();

    return GridView.builder(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 7, childAspectRatio: 1.6),
      itemCount: startOffset + daysInMonth,
      itemBuilder: (_, i) {
        if (i < startOffset) return const SizedBox.shrink();
        final day = i - startOffset + 1;
        final d = DateTime(month.year, month.month, day);
        final dayEntries = entries.where((e) {
          final end = e.endDate ?? e.startDate;
          return !d.isBefore(e.startDate) && !d.isAfter(end);
        }).toList();
        return _DayCell(day: d, entries: dayEntries, isToday: DateUtils.isSameDay(d, today), onTap: () => onDaySelected(d));
      },
    );
  }
}

class _DayCell extends StatelessWidget {
  final DateTime day;
  final List<CycleEntry> entries;
  final bool isToday;
  final VoidCallback onTap;
  const _DayCell({required this.day, required this.entries, required this.isToday, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = entries.isNotEmpty ? _intensityColor(entries.last.intensity) : null;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: color?.withValues(alpha: 0.35),
          border: isToday ? Border.all(color: Theme.of(context).colorScheme.primary, width: 2) : null,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('${day.day}', style: TextStyle(fontWeight: isToday ? FontWeight.bold : FontWeight.normal)),
              if (entries.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 2),
                  height: 4,
                  width: 14,
                  decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2)),
                ),
            ],
          ),
        ),
      ),
    );
  }

  static Color? _intensityColor(PeriodIntensity i) {
    switch (i) {
      case PeriodIntensity.spotting:
        return Colors.pink;
      case PeriodIntensity.light:
        return Colors.red.shade200;
      case PeriodIntensity.medium:
        return Colors.red;
      case PeriodIntensity.heavy:
        return Colors.red.shade800;
    }
  }
}

class _HistoryList extends StatelessWidget {
  final List<CycleEntry> entries;
  final HealthRepository repository;
  const _HistoryList({required this.entries, required this.repository});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final sorted = entries..sort((a, b) => b.startDate.compareTo(a.startDate));
    return ListView.builder(
      itemCount: sorted.length,
      itemBuilder: (_, i) {
        final e = sorted[i];
        return Dismissible(
          key: ValueKey(e.id),
          onDismissed: (_) => repository.deleteCycleEntry(e.id),
          background: const ColoredBox(color: Colors.red),
          child: ListTile(
            title: Text(DateFormatHelper.formatRange(e)),
            subtitle: Text('${l.msg(e.intensity.key)}${e.notes != null ? ' · ${e.notes}' : ''}'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () => _edit(context, repository, e),
          ),
        );
      },
    );
  }

  Future<void> _edit(BuildContext context, HealthRepository repository, CycleEntry entry) async {
    await _editPeriod(context, repository, entry);
  }
}

class DateFormatHelper {
  static String formatDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static String formatRange(CycleEntry e) {
    final end = e.endDate ?? e.startDate;
    final df = DateFormat('dd.MM.');
    return '${df.format(e.startDate)} – ${df.format(end)} (${e.durationDays} ${e.durationDays == 1 ? 'Tag' : 'Tage'})';
  }
}

class _ForecastCard extends StatelessWidget {
  final CycleForecast forecast;
  final HealthRepository repository;
  const _ForecastCard({required this.forecast, required this.repository});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Card(
      margin: const EdgeInsets.all(12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.msg('forecast'), style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: _Stat(label: l.msg('avgCycleLength'), value: forecast.averageCycleLengthDays != null ? '${forecast.averageCycleLengthDays!.toStringAsFixed(1)} Tage' : '-')),
              Expanded(child: _Stat(label: l.msg('avgPeriodLength'), value: forecast.averagePeriodLengthDays != null ? '${forecast.averagePeriodLengthDays!.toStringAsFixed(1)} Tage' : '-')),
              Expanded(child: _Stat(label: l.msg('cyclesRecorded'), value: '${forecast.cyclesRecorded}')),
            ]),
            const SizedBox(height: 8),
            if (forecast.predictedNextStart != null) ...[
              Row(children: [
                Expanded(child: _Stat(label: l.msg('predictedStart'), value: DateFormat.yMMMd(repository.settings.locale).format(forecast.predictedNextStart!))),
                Expanded(child: _Stat(label: l.msg('predictedEnd'), value: forecast.predictedNextEnd != null ? DateFormat.yMMMd(repository.settings.locale).format(forecast.predictedNextEnd!) : '-')),
              ]),
            ] else
              Text(l.msg('noPredictionYet'), style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            Text('${l.msg('forecastExplanation')}: ${forecast.explanation}', style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 2),
        Text(value, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
      ],
    );
  }
}

Future<void> _editPeriod(BuildContext context, HealthRepository repository, CycleEntry entry) async {
  final l = AppLocalizations.of(context)!;
  DateTime start = entry.startDate;
  DateTime? end = entry.endDate;
  PeriodIntensity intensity = entry.intensity;
  final notesController = TextEditingController(text: entry.notes ?? '');
  final newEntry = await showDialog<CycleEntry>(
    context: context,
    builder: (_) => StatefulBuilder(
      builder: (context, setSt) => AlertDialog(
        title: Text(entry.id.isEmpty ? l.msg('add') : l.msg('edit')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(l.msg('periodStart')),
              subtitle: Text(DateFormatHelper.formatDate(start)),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () async {
                final picked = await showDatePicker(context: context, initialDate: start, firstDate: DateTime(2000), lastDate: DateTime(2100), locale: Locale(repository.settings.locale));
                if (picked != null) setSt(() => start = picked);
              },
            ),
            ListTile(
              title: Text(l.msg('periodEnd')),
              subtitle: Text(DateFormatHelper.formatDate(end!)),
              trailing: const Icon(Icons.arrow_forward_ios),
              onTap: () async {
                final picked = await showDatePicker(context: context, initialDate: end ?? start, firstDate: DateTime(2000), lastDate: DateTime(2100), locale: Locale(repository.settings.locale));
                setSt(() => end = picked);
              },
            ),
            DropdownButton<PeriodIntensity>(
              value: intensity,
              items: const [
                DropdownMenuItem(value: PeriodIntensity.spotting, child: Text('Spotting')),
                DropdownMenuItem(value: PeriodIntensity.light, child: Text('leicht')),
                DropdownMenuItem(value: PeriodIntensity.medium, child: Text('mittel')),
                DropdownMenuItem(value: PeriodIntensity.heavy, child: Text('stark')),
              ],
              onChanged: (v) => setSt(() => intensity = v!),
            ),
            TextField(
              controller: notesController,
              decoration: const InputDecoration(labelText: 'Notiz'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l.msg('cancel'))),
          FilledButton(
            onPressed: () {
              Navigator.pop(context, CycleEntry(
                id: entry.id,
                startDate: start,
                endDate: end,
                intensity: intensity,
                notes: notesController.text.isEmpty ? null : notesController.text,
              ));
            },
            child: Text(l.msg('save')),
          ),
        ],
      ),
    ),
  );
  if (newEntry == null) return;
  if (entry.id.isEmpty) {
    repository.addCycleEntry(newEntry);
  } else {
    repository.updateCycleEntry(entry.id, newEntry);
  }
}