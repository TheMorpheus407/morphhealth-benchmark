import 'package:flutter/material.dart';
import 'package:morphhealth_core/morphhealth_core.dart';

import '../cycle/month_calendar.dart' show CycleDayInfo;
import '../day/day_detail_screen.dart';
import '../format.dart';
import '../theme.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';

/// Trends over seven or 28 days: one selectable nutrition value, weight, one
/// selectable symptom and the period days.
class TrendsTab extends StatefulWidget {
  const TrendsTab({super.key});

  @override
  State<TrendsTab> createState() => _TrendsTabState();
}

class _TrendsTabState extends State<TrendsTab>
    with AutomaticKeepAliveClientMixin {
  int _days = 7;

  /// Last day of the range; null follows today.
  Day? _end;
  NutritionMetric _metric = NutritionMetric.all.first;
  String _symptom = '';

  @override
  bool get wantKeepAlive => true;

  void _openDay(Day day) => Navigator.of(
    context,
  ).push(MaterialPageRoute<void>(builder: (_) => DayDetailScreen(day: day)));

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l = context.l;
    final fmt = context.fmt;
    final app = context.app;
    final colors = MhColors.of(context);
    final today = app.today;
    final end = _end ?? today;
    final from = end.addDays(-(_days - 1));
    final rangeText = fmt.range(from, end);
    final unit = app.settings.weightUnit;

    // Nutrition.
    final metric = _metric;
    final nutrition = nutritionSeries(app.data, metric, from, end);
    final nutritionStats = SeriesStats.of(nutrition);
    final goal = metric.goalIn(app.goals);
    String metricValue(double v) {
      final n = metric.nutrient;
      if (n != null) return fmt.nutrient(n, v);
      return metric.key == NutritionMetric.water.key ? fmt.ml(v) : fmt.mg(v);
    }

    final metricColor = metric.key == NutritionMetric.water.key
        ? colors.water
        : (metric.key == NutritionMetric.caffeineTotal.key ||
              metric.nutrient == Nutrients.caffeine)
        ? colors.caffeine
        : colors.nutrition;

    // Weight.
    final weights = weightSeries(app.data, from, end);
    final weightStats = SeriesStats.of(weights);
    String weightValue(double kg) => fmt.weight(kg, unit);

    // Symptoms.
    final names = app.usedSymptoms;
    if (_symptom.isEmpty || names.every((n) => n.key != _symptom)) {
      _symptom = names.isEmpty ? '' : names.first.key;
    }
    final symptomTitle = names.isEmpty
        ? l.symptoms
        : names.firstWhere((n) => n.key == _symptom).display;
    final symptomValues = _symptom.isEmpty
        ? const <DayValue>[]
        : symptomSeries(app.data, _symptom, from, end);
    final symptomStats = SeriesStats.of(symptomValues);

    // Cycle.
    final cycleDays = [
      for (var d = from; d <= end; d = d.addDays(1)) CycleDayInfo.of(app, d),
    ];
    final periodDays = cycleDays.where((c) => c.period != null).length;

    // Average, lowest and highest say something from two values on; a
    // single value is shown by the chart and its list.
    Widget summaryLine(SeriesStats s, String Function(double) value) =>
        s.count < 2
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              '${l.average}: ${value(s.mean!)} · '
              '${l.lowest}: ${value(s.min!)} · '
              '${l.highest}: ${value(s.max!)}',
              style: context.texts.bodyMedium,
            ),
          );

    String chartLabel(String title, SeriesStats s, String Function(double) v) =>
        s.count == 0
        ? l.chartEmpty(title, rangeText)
        : l.chartSummary(
            title,
            rangeText,
            v(s.mean!),
            v(s.min!),
            v(s.max!),
            s.count,
          );

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: [
        Semantics(
          label: l.rangeLabel,
          container: true,
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<int>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: 7, label: Text(l.range7)),
                ButtonSegment(value: 28, label: Text(l.range28)),
              ],
              selected: {_days},
              onSelectionChanged: (s) => setState(() => _days = s.first),
            ),
          ),
        ),
        Row(
          children: [
            IconButton(
              tooltip: l.previousRange,
              icon: const Icon(Icons.chevron_left),
              onPressed: () => setState(() => _end = end.addDays(-_days)),
            ),
            Expanded(
              child: Semantics(
                container: true,
                liveRegion: true,
                child: Text(
                  rangeText,
                  textAlign: TextAlign.center,
                  style: context.texts.titleMedium,
                ),
              ),
            ),
            if (end != today)
              IconButton(
                tooltip: l.goToToday,
                icon: const Icon(Icons.today_outlined),
                onPressed: () => setState(() => _end = null),
              ),
            IconButton(
              tooltip: l.nextRange,
              icon: const Icon(Icons.chevron_right),
              onPressed: end < today
                  ? () => setState(() {
                      final next = end.addDays(_days);
                      _end = next >= today ? null : next;
                    })
                  : null,
            ),
          ],
        ),
        MhCard(
          title: l.navNutrition,
          icon: Icons.restaurant_outlined,
          iconColor: colors.nutrition,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              ChoiceField<NutritionMetric>(
                label: l.quantity,
                value: metric,
                options: [
                  for (final m in NutritionMetric.all)
                    (m, '${l.metric(m)} (${m.unit})'),
                ],
                onChanged: (m) => setState(() => _metric = m),
              ),
              const SizedBox(height: 12),
              DayChart(
                values: nutrition,
                kind: DayChartKind.bars,
                color: metricColor,
                goal: goal,
                goalLabel: goal == null ? null : l.goal,
                formatValue: metricValue,
                formatAxis: (v) => fmt.adaptive(v),
                emptyText: l.trendNoData,
                semanticsLabel: chartLabel(
                  l.metric(metric),
                  nutritionStats,
                  metricValue,
                ),
                onOpenDay: _openDay,
                openDayLabel: l.dayDetail,
              ),
              summaryLine(nutritionStats, metricValue),
              ChartValueList(
                title: l.valuesAsList,
                values: nutrition,
                formatValue: metricValue,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        MhCard(
          title: l.weight,
          icon: Icons.monitor_weight_outlined,
          iconColor: colors.weight,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DayChart(
                values: weights,
                kind: DayChartKind.line,
                color: colors.weight,
                formatValue: weightValue,
                formatAxis: (kg) =>
                    fmt.number(Fmt.weightValue(kg, unit), decimals: 1),
                emptyText: l.trendNoData,
                semanticsLabel: chartLabel(l.weight, weightStats, weightValue),
                onOpenDay: _openDay,
                openDayLabel: l.dayDetail,
              ),
              summaryLine(weightStats, weightValue),
              ChartValueList(
                title: l.valuesAsList,
                values: weights,
                formatValue: weightValue,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        MhCard(
          title: l.symptoms,
          icon: Icons.healing_outlined,
          iconColor: colors.symptom,
          child: names.isEmpty
              ? Text(
                  l.noSymptoms,
                  style: context.texts.bodyMedium?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ChoiceField<String>(
                      label: l.symptom,
                      value: _symptom,
                      options: [for (final n in names) (n.key, n.display)],
                      onChanged: (v) => setState(() => _symptom = v),
                    ),
                    const SizedBox(height: 12),
                    DayChart(
                      values: symptomValues,
                      kind: DayChartKind.bars,
                      color: colors.symptom,
                      fixedMax: 10,
                      formatValue: (v) => l.intensityOf(v.round()),
                      formatAxis: (v) => fmt.number(v, decimals: 0),
                      emptyText: l.trendNoData,
                      semanticsLabel: chartLabel(
                        '$symptomTitle, ${l.strongestPerDay}',
                        symptomStats,
                        (v) => fmt.number(v, decimals: 1),
                      ),
                      onOpenDay: _openDay,
                      openDayLabel: l.dayDetail,
                    ),
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        l.strongestPerDay,
                        style: context.texts.bodySmall,
                      ),
                    ),
                    ChartValueList(
                      title: l.valuesAsList,
                      values: symptomValues,
                      formatValue: (v) => l.intensityOf(v.round()),
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 12),
        MhCard(
          title: l.navCycle,
          icon: Icons.calendar_month_outlined,
          iconColor: colors.period,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Semantics(
                label: l.periodDaysSummary(periodDays),
                excludeSemantics: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        for (final c in cycleDays)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 1,
                              ),
                              child: Container(
                                height: 22,
                                decoration: BoxDecoration(
                                  color: c.period != null
                                      ? colors.period
                                      : null,
                                  border: Border.all(
                                    color: c.period != null
                                        ? colors.period
                                        : (c.spotting
                                              ? colors.period
                                              : context.colors.outlineVariant),
                                    width: c.spotting ? 2 : 1,
                                  ),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          fmt.dateShort(from),
                          style: context.texts.labelSmall,
                        ),
                        Text(
                          fmt.dateShort(end),
                          style: context.texts.labelSmall,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              Text(
                l.periodDaysSummary(periodDays),
                style: context.texts.bodyMedium,
              ),
            ],
          ),
        ),
      ],
    );
  }
}
