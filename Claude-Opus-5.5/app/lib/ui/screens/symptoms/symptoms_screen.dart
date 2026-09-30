import 'package:flutter/material.dart';

import '../../../core/model/entries.dart';
import '../../controller.dart';
import '../../theme.dart';
import '../../widgets/charts.dart';
import '../../widgets/common.dart';
import '../home_shell.dart';
import 'symptom_editor.dart';

/// Symptom diary with a trend per selected symptom.
class SymptomsScreen extends StatelessWidget {
  const SymptomsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(s.navSymptoms),
          actions: mainActions(context),
          bottom: TabBar(tabs: [Tab(text: s.symptomEntriesTab), Tab(text: s.symptomTrendTab)]),
        ),
        body: const TabBarView(children: [_EntriesTab(), SymptomTrendTab()]),
      ),
    );
  }
}

class _EntriesTab extends StatelessWidget {
  const _EntriesTab();

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final entries = app.data.symptomEntries.values.toList()..sort((a, b) => compareDated(b, a));
    if (entries.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [EmptyHint(app.s.noSymptomsYet, icon: Icons.healing_outlined)],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 96),
      itemCount: entries.length,
      itemBuilder: (context, i) => SymptomTile(entry: entries[i], showDate: true),
    );
  }
}

class SymptomTile extends StatelessWidget {
  const SymptomTile({super.key, required this.entry, this.showDate = false});

  final SymptomEntry entry;
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final s = app.s;
    final fmt = app.fmt;
    final e = entry;
    return ListTile(
      leading: _IntensityBadge(intensity: e.intensity),
      title: Text(e.name),
      subtitle: Text([
        if (showDate) fmt.weekdayDayMonth(e.date) + (e.date.year == app.today.year ? '' : ' ${e.date.year}'),
        if (e.time != null) fmt.time(e.time!),
        '${s.intensity} ${s.intensityValue(e.intensity)} (${s.intensityWord(e.intensity)})',
        if (e.note != null) e.note!,
      ].join(' · ')),
      onTap: () => openSymptomEditor(context, entry: e),
    );
  }
}

class _IntensityBadge extends StatelessWidget {
  const _IntensityBadge({required this.intensity});

  final int intensity;

  @override
  Widget build(BuildContext context) {
    final color = context.colors.symptoms;
    return ExcludeSemantics(
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: color, width: 2),
          color: color.withValues(alpha: 0.08 + intensity * 0.02),
        ),
        child: Text('$intensity', style: context.text.titleSmall?.copyWith(color: color)),
      ),
    );
  }
}

/// Trend of one selected symptom over 7 or 28 days.
class SymptomTrendTab extends StatefulWidget {
  const SymptomTrendTab({super.key});

  @override
  State<SymptomTrendTab> createState() => _SymptomTrendTabState();
}

class _SymptomTrendTabState extends State<SymptomTrendTab> {
  String? _name;
  int _days = 28;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final s = app.s;
    final fmt = app.fmt;
    final names = app.service.knownSymptomNames();
    if (names.isEmpty) {
      return ListView(padding: const EdgeInsets.all(16), children: [EmptyHint(s.noSymptomsYet)]);
    }
    final selected = names.firstWhere(
      (n) => normalizeSymptomName(n) == normalizeSymptomName(_name ?? ''),
      orElse: () => names.first,
    );
    final series = app.service.symptomSeries(selected, app.today, _days);
    final all = app.service.symptomEntriesNamed(selected);
    final points = [
      for (var i = 0; i < series.days.length; i++)
        ChartPoint(
          label: _days == 7 ? fmt.weekdayShort(series.days[i].weekday) : fmt.dayOfMonth(series.days[i]),
          fullLabel: fmt.weekdayDayMonth(series.days[i]),
          value: series.values[i]?.toDouble(),
        ),
    ];
    final avg = series.averageIntensity;
    final summary = '$selected, ${s.days(_days)}: ${s.occurrences(series.entries.length)}'
        '${avg == null ? '' : ', ${s.averageIntensity} ${fmt.number(avg, 1)}'}';
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
      children: [
        DropdownButtonFormField<String>(
          initialValue: selected,
          isExpanded: true,
          decoration: InputDecoration(labelText: s.chooseSymptom),
          items: [for (final n in names) DropdownMenuItem(value: n, child: Text(n))],
          onChanged: (v) => setState(() => _name = v),
        ),
        const SizedBox(height: 12),
        SegmentedButton<int>(
          segments: [
            ButtonSegment(value: 7, label: Text(s.days(7))),
            ButtonSegment(value: 28, label: Text(s.days(28))),
          ],
          selected: {_days},
          onSelectionChanged: (v) => setState(() => _days = v.first),
        ),
        const SizedBox(height: 12),
        Card(
          semanticContainer: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (series.entries.isEmpty)
                  EmptyHint(s.noDataInRange)
                else
                  ChartWithTable(
                    points: points,
                    formatValue: (v) => s.intensityValue(v.round()),
                    showTableLabel: s.showTable,
                    showChartLabel: s.showChart,
                    emptyLabel: '–',
                    chart: TrendChart(
                      points: points,
                      semanticSummary: summary,
                      formatValue: (v) => fmt.integer(v),
                      color: context.colors.symptoms,
                    ),
                  ),
                const Divider(),
                _stat(context, s.occurrences(series.entries.length), ''),
                _stat(context, s.averageIntensity, avg == null ? '–' : fmt.number(avg, 1)),
                _stat(context, s.maxIntensity, series.maxIntensity?.toString() ?? '–'),
              ],
            ),
          ),
        ),
        ListHeader(s.symptomEntriesTab),
        for (final e in all.take(200)) SymptomTile(entry: e, showDate: true),
      ],
    );
  }

  Widget _stat(BuildContext context, String label, String value) => MergeSemantics(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(value, style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
        ],
      ),
    ),
  );
}
