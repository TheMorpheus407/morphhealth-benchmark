import 'package:flutter/material.dart';

import '../../../core/l10n/format.dart';
import '../../../core/model/dataset.dart';
import '../../../core/model/entries.dart';
import '../../../core/model/enums.dart';
import '../../../core/util/local_date.dart';
import '../../controller.dart';
import '../../theme.dart';
import '../../widgets/charts.dart';
import '../../widgets/common.dart';
import '../../widgets/inputs.dart';
import '../home_shell.dart';
import '../nutrition/intake_cards.dart';

/// Weight entries in kg or lb with a history chart.
class WeightScreen extends StatefulWidget {
  const WeightScreen({super.key});

  @override
  State<WeightScreen> createState() => _WeightScreenState();
}

class _WeightScreenState extends State<WeightScreen> {
  int _range = 28; // days; 0 = all

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final s = app.s;
    final entries = app.data.weightsSorted.reversed.toList();
    final header = <Widget>[
      WeightSummaryCard(rangeDays: _range),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final (days, label) in [
            (7, s.range7),
            (28, s.range28),
            (90, s.range90),
            (365, s.range365),
            (0, s.rangeAll),
          ])
            ChoiceChip(
              label: Text(label),
              selected: _range == days,
              onSelected: (_) => setState(() => _range = days),
            ),
        ],
      ),
      const SizedBox(height: 12),
      Card(
        semanticContainer: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: WeightChart(rangeDays: _range),
        ),
      ),
      ListHeader(s.weightEntries),
      if (entries.isEmpty) Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: EmptyHint(s.noWeightYet)),
    ];
    return Scaffold(
      appBar: AppBar(title: Text(s.navWeight), actions: mainActions(context)),
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
        itemCount: header.length + entries.length,
        itemBuilder: (context, i) {
          if (i < header.length) return header[i];
          return WeightTile(entry: entries[i - header.length]);
        },
      ),
    );
  }
}

String formatWeight(BuildContext context, WeightEntry e) {
  final app = context.appRead;
  final unit = app.settings.weightUnit;
  return '${app.fmt.fixed(e.valueIn(unit), 1)} ${unit.json}';
}

class WeightTile extends StatelessWidget {
  const WeightTile({super.key, required this.entry});

  final WeightEntry entry;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final fmt = app.fmt;
    return ListTile(
      leading: ExcludeSemantics(child: Icon(Icons.monitor_weight_outlined, color: context.colors.weight)),
      title: Text(formatWeight(context, entry)),
      subtitle: Text([
        fmt.weekdayDayMonth(entry.date) + (entry.date.year == app.today.year ? '' : ' ${entry.date.year}'),
        if (entry.time != null) fmt.time(entry.time!),
        if (entry.note != null) entry.note!,
      ].join(' · ')),
      onTap: () => openWeightEditor(context, entry: entry),
    );
  }
}

/// Latest weight and the neutral change within the selected range.
class WeightSummaryCard extends StatelessWidget {
  const WeightSummaryCard({super.key, this.rangeDays = 28, this.onTap, this.showAdd = false});

  final int rangeDays;
  final VoidCallback? onTap;

  /// Adds a direct "add weight" action (used on the overview).
  final bool showAdd;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final s = app.s;
    final fmt = app.fmt;
    final unit = app.settings.weightUnit;
    final all = app.data.weightsSorted;
    final latest = all.isEmpty ? null : all.last;
    String? change;
    if (latest != null) {
      final from = rangeDays == 0 ? null : app.today.addDays(-(rangeDays - 1));
      final inRange = all.where((w) => from == null || !w.date.isBefore(from)).toList();
      if (inRange.length >= 2) {
        final diff = inRange.last.valueIn(unit) - inRange.first.valueIn(unit);
        final sign = diff > 0.05 ? '+' : (diff < -0.05 ? '−' : '±');
        change = s.changeSince('$sign${fmt.fixed(diff.abs(), 1)} ${unit.json}', fmt.dayMonth(inRange.first.date));
      }
    }
    return SectionCard(
      title: s.weight,
      icon: Icons.monitor_weight_outlined,
      iconColor: context.colors.weight,
      onTap: onTap,
      trailing: showAdd
          ? IconButton(
              tooltip: s.addWeight,
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () => openWeightEditor(context, date: app.selectedDate),
            )
          : null,
      child: latest == null
          ? EmptyHint(s.noWeightYet)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(formatWeight(context, latest), style: context.text.headlineSmall),
                Text(
                  '${s.latestWeight}: ${fmt.weekdayDayMonth(latest.date)}',
                  style: context.text.bodyMedium,
                ),
                if (change != null) Text(change, style: context.text.bodyMedium),
              ],
            ),
    );
  }
}

class WeightChart extends StatelessWidget {
  const WeightChart({super.key, required this.rangeDays, this.height = 190});

  final int rangeDays;
  final double height;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final s = app.s;
    final fmt = app.fmt;
    final unit = app.settings.weightUnit;
    final all = app.data.weightsSorted;
    List<ChartPoint> points;
    if (rangeDays == 0) {
      // One point per measured day.
      final byDay = <LocalDate, WeightEntry>{};
      for (final w in all) {
        byDay[w.date] = w;
      }
      points = [
        for (final e in byDay.entries)
          ChartPoint(
            label: fmt.numericMonthYear(e.key),
            fullLabel: fmt.medium(e.key),
            value: e.value.valueIn(unit),
          ),
      ];
    } else {
      final start = app.today.addDays(-(rangeDays - 1));
      points = [
        for (var i = 0; i < rangeDays; i++)
          () {
            final day = start.addDays(i);
            final w = app.data.weightsOn(day);
            return ChartPoint(
              label: rangeDays <= 7 ? fmt.weekdayShort(day.weekday) : fmt.numericDayMonth(day),
              fullLabel: fmt.weekdayDayMonth(day),
              value: w.isEmpty ? null : w.last.valueIn(unit),
            );
          }(),
      ];
    }
    final values = points.map((p) => p.value).whereType<double>().toList();
    if (values.isEmpty) return EmptyHint(s.noDataInRange, icon: Icons.show_chart);
    String format(double v) => '${fmt.fixed(v, 1)} ${unit.json}';
    final summary = '${s.weight}: ${values.length} ${s.weightEntries}, '
        '${s.minimum} ${format(values.reduce((a, b) => a < b ? a : b))}, '
        '${s.maximum} ${format(values.reduce((a, b) => a > b ? a : b))}, '
        '${s.latestWeight} ${format(values.last)}';
    return ChartWithTable(
      points: points.where((p) => rangeDays == 0 || p.value != null).toList(),
      formatValue: format,
      showTableLabel: s.showTable,
      showChartLabel: s.showChart,
      emptyLabel: '–',
      chart: TrendChart(
        points: points,
        style: ChartStyle.line,
        height: height,
        zeroBased: false,
        semanticSummary: summary,
        formatValue: (v) => fmt.number(v, 1),
        color: context.colors.weight,
      ),
    );
  }
}

Future<void> openWeightEditor(BuildContext context, {WeightEntry? entry, LocalDate? date}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => WeightEditor(entry: entry, date: date)),
  );
}

class WeightEditor extends StatefulWidget {
  const WeightEditor({super.key, this.entry, this.date});

  final WeightEntry? entry;
  final LocalDate? date;

  @override
  State<WeightEditor> createState() => _WeightEditorState();
}

class _WeightEditorState extends State<WeightEditor> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _value;
  late final TextEditingController _note;
  late WeightUnit _unit;
  late LocalDate _date;
  int? _time;

  @override
  void initState() {
    super.initState();
    final app = context.appRead;
    final e = widget.entry;
    _unit = e?.unit ?? app.settings.weightUnit;
    _value = TextEditingController(text: e == null ? '' : app.fmt.input(e.value, 2));
    _note = TextEditingController(text: e?.note ?? '');
    _date = e?.date ?? widget.date ?? app.today;
    _time = e?.time ?? (_date == app.today ? app.service.clock.minutesOfDay() : null);
  }

  @override
  void dispose() {
    _value.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final app = context.appRead;
    final value = Fmt.parseNumber(_value.text)!;
    final note = _note.text.trim().isEmpty ? null : _note.text.trim();
    final now = app.service.clock.nowUtc();
    final e = widget.entry;
    final record = e == null
        ? WeightEntry.create(date: _date, time: _time, value: value, unit: _unit, note: note, now: now)
        : e.copyWith(date: _date, time: () => _time, value: value, unit: _unit, note: () => note, updatedAt: now);
    final ok = await app.run(() => app.service.saveWeight(record));
    if (ok && mounted) {
      app.showMessage(app.s.saved);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final s = app.s;
    final minV = _unit.fromKg(WeightEntry.minKg);
    final maxV = _unit.fromKg(WeightEntry.maxKg);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.entry == null ? s.addWeight : s.editWeight),
        actions: [
          if (widget.entry != null)
            IconButton(
              tooltip: s.delete,
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final entry = widget.entry!;
                Navigator.of(context).pop();
                await deleteWithUndo(context, Collection.weightEntries, entry);
              },
            ),
        ],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: pagePadding(context, top: 16),
          children: [
            SegmentedButton<WeightUnit>(
              segments: const [
                ButtonSegment(value: WeightUnit.kg, label: Text('kg')),
                ButtonSegment(value: WeightUnit.lb, label: Text('lb')),
              ],
              selected: {_unit},
              onSelectionChanged: (v) => setState(() {
                final previous = _unit;
                _unit = v.first;
                final current = Fmt.parseNumber(_value.text);
                if (current != null && previous != _unit) {
                  _value.text = app.fmt.input(_unit.fromKg(previous.toKg(current)), 1);
                }
              }),
            ),
            const SizedBox(height: 16),
            NumberField(
              controller: _value,
              label: s.weight,
              suffix: _unit.json,
              min: minV,
              max: maxV,
              required: true,
              autofocus: widget.entry == null,
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: DateField(date: _date, onChanged: (d) => setState(() => _date = d))),
                const SizedBox(width: 12),
                Expanded(child: TimeField(minutes: _time, onChanged: (t) => setState(() => _time = t))),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _note,
              maxLength: 2000,
              minLines: 1,
              maxLines: 4,
              decoration: InputDecoration(labelText: s.noteOptional),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _save,
              child: Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(s.save)),
            ),
          ],
        ),
      ),
    );
  }
}
