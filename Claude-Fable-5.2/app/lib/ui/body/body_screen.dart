import 'package:flutter/material.dart';
import 'package:morphhealth_core/morphhealth_core.dart';

import '../day/day_detail_screen.dart';
import '../format.dart';
import '../shell.dart';
import '../theme.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import 'editors.dart';

/// Weight and symptoms: entry, history and trends for both.
class BodyScreen extends StatefulWidget {
  /// Receives the index of the visible tab: weight (0) or symptoms (1). The
  /// main frame uses it to offer the matching action.
  final ValueNotifier<int> tabIndex;

  const BodyScreen({super.key, required this.tabIndex});

  @override
  State<BodyScreen> createState() => BodyScreenState();
}

class BodyScreenState extends State<BodyScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this)
    ..addListener(() => widget.tabIndex.value = _tabs.index);

  /// Shows the weight (0) or the symptoms (1) tab.
  void showTab(int index) => _tabs.animateTo(index.clamp(0, 1));

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.navBody),
        actions: const [SettingsButton()],
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: l.weight),
            Tab(text: l.symptoms),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [WeightTab(), SymptomsTab()],
      ),
    );
  }
}

/// Lets the user choose how many days a trend covers; 0 means everything.
class RangeSelector extends StatelessWidget {
  final int days;
  final ValueChanged<int> onChanged;
  final List<int> options;

  const RangeSelector({
    super.key,
    required this.days,
    required this.onChanged,
    this.options = const [7, 28, 90, 0],
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    String label(int d) => switch (d) {
      7 => l.range7,
      28 => l.range28,
      90 => l.range90,
      _ => l.rangeAll,
    };
    return Semantics(
      label: l.rangeLabel,
      container: true,
      child: SizedBox(
        width: double.infinity,
        child: SegmentedButton<int>(
          showSelectedIcon: false,
          segments: [
            for (final d in options)
              ButtonSegment(value: d, label: Text(label(d))),
          ],
          selected: {days},
          onSelectionChanged: (s) => onChanged(s.first),
        ),
      ),
    );
  }
}

void _openDay(BuildContext context, Day day) => Navigator.of(
  context,
).push(MaterialPageRoute<void>(builder: (_) => DayDetailScreen(day: day)));

class WeightTab extends StatefulWidget {
  const WeightTab({super.key});

  @override
  State<WeightTab> createState() => _WeightTabState();
}

class _WeightTabState extends State<WeightTab>
    with AutomaticKeepAliveClientMixin {
  int _days = 28;

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l = context.l;
    final fmt = context.fmt;
    final app = context.app;
    final unit = app.settings.weightUnit;
    final all = app.data.weightsSorted;
    if (all.isEmpty) {
      return SingleChildScrollView(
        child: EmptyHint(
          icon: Icons.monitor_weight_outlined,
          text: l.noWeights,
        ),
      );
    }
    final today = app.today;
    final from = _days == 0 ? all.first.date : today.addDays(-(_days - 1));
    final to = today < all.last.date ? all.last.date : today;
    final series = weightSeries(app.data, from, to);
    final stats = SeriesStats.of(series);
    final entries = [
      for (final w in all.reversed)
        if (w.date >= from) w,
    ];
    final latest = all.last;
    String value(double kg) => fmt.weight(kg, unit);
    final rangeText = fmt.range(from, to);
    final color = MhColors.of(context).weight;

    final header = <Widget>[
      MhCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              label:
                  '${l.weight}: ${value(latest.weightKg)}, '
                  '${fmt.dayRelative(latest.date)}',
              excludeSemantics: true,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value(latest.weightKg),
                    style: context.texts.headlineMedium,
                  ),
                  Text(
                    fmt.dayRelative(latest.date),
                    style: context.texts.bodyMedium?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            RangeSelector(
              days: _days,
              onChanged: (d) => setState(() => _days = d),
            ),
            const SizedBox(height: 12),
            DayChart(
              values: series,
              kind: DayChartKind.line,
              color: color,
              formatValue: value,
              formatAxis: (kg) =>
                  fmt.number(Fmt.weightValue(kg, unit), decimals: 1),
              emptyText: l.trendNoData,
              semanticsLabel: stats.count == 0
                  ? l.chartEmpty(l.weight, rangeText)
                  : l.chartSummary(
                      l.weight,
                      rangeText,
                      value(stats.mean!),
                      value(stats.min!),
                      value(stats.max!),
                      stats.count,
                    ),
              onOpenDay: (d) => _openDay(context, d),
              openDayLabel: l.dayDetail,
            ),
            if (stats.count >= 2)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '${l.average}: ${value(stats.mean!)} · '
                  '${l.sinceEntry(fmt.weightChange(stats.change!, unit), fmt.dateCompact(stats.firstDay!))}',
                  style: context.texts.bodyMedium,
                ),
              ),
            ChartValueList(
              title: l.valuesAsList,
              values: series,
              formatValue: value,
            ),
          ],
        ),
      ),
      SectionTitle(l.tabEntries),
    ];

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 168),
      itemCount: header.length + entries.length,
      itemBuilder: (context, i) {
        if (i < header.length) return header[i];
        final w = entries[i - header.length];
        return ListTile(
          leading: Icon(Icons.monitor_weight_outlined, color: color),
          title: Text(value(w.weightKg)),
          subtitle: Text(
            w.note == null
                ? fmt.dayRelative(w.date)
                : '${fmt.dayRelative(w.date)} · ${w.note}',
          ),
          trailing: const Icon(Icons.edit_outlined),
          onTap: () => showWeightEditor(context, entry: w),
        );
      },
    );
  }
}

class SymptomsTab extends StatefulWidget {
  const SymptomsTab({super.key});

  @override
  State<SymptomsTab> createState() => _SymptomsTabState();
}

class _SymptomsTabState extends State<SymptomsTab>
    with AutomaticKeepAliveClientMixin {
  int _days = 28;

  /// Key of the selected symptom; empty for all symptoms.
  String _selected = '';

  @override
  bool get wantKeepAlive => true;

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l = context.l;
    final fmt = context.fmt;
    final app = context.app;
    final names = app.usedSymptoms;
    if (names.isEmpty) {
      return SingleChildScrollView(
        child: EmptyHint(icon: Icons.healing_outlined, text: l.noSymptoms),
      );
    }
    if (_selected.isNotEmpty && names.every((n) => n.key != _selected)) {
      _selected = '';
    }
    final today = app.today;
    final range = app.data.dateRange;
    Day from;
    if (_days == 0) {
      from = today;
      for (final s in app.data.symptoms) {
        if (s.day < from) from = s.day;
      }
    } else {
      from = today.addDays(-(_days - 1));
    }
    final to = range != null && range.last > today ? range.last : today;

    final List<DayValue> series;
    if (_selected.isEmpty) {
      series = [
        for (var d = from; d <= to; d = d.addDays(1))
          DayValue(
            d,
            app.data
                .symptomsOn(d)
                .fold<double?>(
                  null,
                  (m, s) =>
                      m == null || s.intensity > m ? s.intensity.toDouble() : m,
                ),
          ),
      ];
    } else {
      series = symptomSeries(app.data, _selected, from, to);
    }
    final entries =
        app.data.symptoms
            .where(
              (s) =>
                  s.day >= from &&
                  (_selected.isEmpty || s.nameKey == _selected),
            )
            .toList()
          ..sort((a, b) => b.at.compareTo(a.at));
    final stats = SeriesStats.of(series);
    final title = _selected.isEmpty
        ? l.allSymptoms
        : names.firstWhere((n) => n.key == _selected).display;
    final color = MhColors.of(context).symptom;
    String value(double v) => l.intensityOf(v.round());
    final rangeText = fmt.range(from, to);

    final header = <Widget>[
      MhCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ChoiceField<String>(
              label: l.symptom,
              value: _selected,
              options: [
                ('', l.allSymptoms),
                for (final n in names) (n.key, '${n.display} (${n.count})'),
              ],
              onChanged: (v) => setState(() => _selected = v),
            ),
            const SizedBox(height: 12),
            RangeSelector(
              days: _days,
              onChanged: (d) => setState(() => _days = d),
            ),
            const SizedBox(height: 12),
            DayChart(
              values: series,
              kind: DayChartKind.bars,
              color: color,
              fixedMax: 10,
              formatValue: value,
              formatAxis: (v) => fmt.number(v, decimals: 0),
              emptyText: l.trendNoData,
              semanticsLabel: stats.count == 0
                  ? l.chartEmpty('$title, ${l.strongestPerDay}', rangeText)
                  : l.chartSummary(
                      '$title, ${l.strongestPerDay}',
                      rangeText,
                      fmt.number(stats.mean!, decimals: 1),
                      fmt.number(stats.min!, decimals: 0),
                      fmt.number(stats.max!, decimals: 0),
                      stats.count,
                    ),
              onOpenDay: (d) => _openDay(context, d),
              openDayLabel: l.dayDetail,
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(l.strongestPerDay, style: context.texts.bodySmall),
            ),
            ChartValueList(
              title: l.valuesAsList,
              values: series,
              formatValue: value,
            ),
          ],
        ),
      ),
      SectionTitle(l.tabEntries),
      if (entries.isEmpty)
        Padding(padding: const EdgeInsets.all(16), child: Text(l.trendNoData)),
    ];

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 168),
      itemCount: header.length + entries.length,
      itemBuilder: (context, i) {
        if (i < header.length) return header[i];
        return SymptomTile(entry: entries[i - header.length]);
      },
    );
  }
}

/// One symptom entry; tap to edit.
class SymptomTile extends StatelessWidget {
  final SymptomEntry entry;
  final bool showDate;

  const SymptomTile({super.key, required this.entry, this.showDate = true});

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final fmt = context.fmt;
    return ListTile(
      leading: IntensityBadge(value: entry.intensity),
      title: Text(entry.name),
      subtitle: Text(
        [
          l.intensityOf(entry.intensity),
          showDate ? fmt.dateTime(entry.at) : fmt.time(entry.at),
          if (entry.note != null) entry.note!,
        ].join(' · '),
      ),
      trailing: const Icon(Icons.edit_outlined),
      onTap: () => showSymptomEditor(context, entry: entry),
    );
  }
}

/// The intensity as a number in a circle whose fill grows with the value.
class IntensityBadge extends StatelessWidget {
  final int value;

  const IntensityBadge({super.key, required this.value});

  @override
  Widget build(BuildContext context) {
    final color = MhColors.of(context).symptom;
    return ExcludeSemantics(
      child: Container(
        width: 40,
        height: 40,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.08 + 0.022 * value),
          border: Border.all(color: color, width: 1.5),
        ),
        child: Text('$value', style: context.texts.titleMedium),
      ),
    );
  }
}
