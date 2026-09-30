import 'package:flutter/material.dart';

import '../../core/civil.dart';
import '../../core/models.dart';
import '../../core/nutrients.dart';
import '../../core/nutrition.dart';
import '../../state/app_state.dart';
import '../format.dart';
import '../l10n_x.dart';
import '../theme.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';

/// Diagramm der Tageswerte eines auswählbaren Nährstoffs (oder von Wasser)
/// über [days] Tage bis einschließlich [end].
class NutritionTrendCard extends StatefulWidget {
  final int days;
  final Day end;

  /// Ohne eigene Karte (zum Einbetten in eine andere Karte).
  final bool embedded;

  const NutritionTrendCard({super.key, required this.days, required this.end, this.embedded = false});

  @override
  State<NutritionTrendCard> createState() => _NutritionTrendCardState();
}

class _NutritionTrendCardState extends State<NutritionTrendCard> {
  String _metric = kEnergy;

  String _axisNumber(Fmt f, double v, int decimals) {
    if (v >= 1000) return f.n(v);
    return f.n(v, v < 10 ? decimals.clamp(0, 1) : 0);
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final l = context.l10n;
    final f = context.fmt;
    final color = areaColor(Area.nutrition, context.theme.brightness);
    final days = widget.days;
    final series = nutritionSeries(app.db, _metric, widget.end, days);
    final unit = series.unit;
    final def = nutrientByKey[_metric];
    final decimals = def?.decimals ?? 0;
    final metricName = _metric == kMetricWater ? l.waterTitle : nutrientName(_metric, f.lang);
    String fmtValue(double v) => '${f.n(v, decimals)} $unit';
    final goal = _metric == kMetricWater ? app.db.goals.waterMl : app.db.goals.forNutrient(_metric);
    final avg = series.average;
    final rangeText = days == 7 ? l.trendsRange7 : l.trendsRange28;
    final entries = <DropdownMenuEntry<String>>[
      DropdownMenuEntry(value: kMetricWater, label: '${l.waterTitle} (ml)'),
      for (final d in nutrientCatalog)
        DropdownMenuEntry(value: d.key, label: '${nutrientName(d.key, f.lang)} (${d.unit})'),
    ];
    final chart = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BarChart(
          points: [for (final p in series.points) BarPoint(p.day, p.value)],
          color: color,
          goal: goal,
          goalLabel: l.trendsGoal,
          valueLabel: (v) => _axisNumber(f, v, decimals),
          dayLabel: (d) => f.dateWithWeekday(d),
          axisLabel: (d) => days == 7 ? f.weekdayShort(d) : f.dayMonth(d),
          noDataLabel: l.trendsNoDataDay,
          hint: l.trendsChartHint,
          summary: l.trendsSummary(
            metricName,
            rangeText,
            avg == null ? '–' : fmtValue(avg),
            '${series.daysWithData}',
            '$days',
          ),
        ),
        const SizedBox(height: 12),
        if (avg == null)
          EmptyHint(l.trendsNoData, icon: Icons.info_outline)
        else ...[
          Text(l.trendsAverage(fmtValue(avg), '${series.daysWithData}', '$days'), style: context.text.bodyLarge),
          const SizedBox(height: 4),
          Text(l.trendsMinMax(fmtValue(series.minimum!), fmtValue(series.maximum!)), style: context.text.bodyMedium),
        ],
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownMenu<String>(
          key: ValueKey(_metric),
          width: double.infinity,
          menuHeight: 360,
          label: Text(l.trendsMetric),
          initialSelection: _metric,
          dropdownMenuEntries: entries,
          onSelected: (v) {
            if (v != null) setState(() => _metric = v);
          },
        ),
        const SizedBox(height: 12),
        if (widget.embedded)
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Semantics(header: true, child: Text('$metricName · $rangeText', style: context.text.titleSmall)),
              const SizedBox(height: 8),
              chart,
            ],
          )
        else
          SectionCard(title: '$metricName · $rangeText', icon: Icons.bar_chart, accent: color, child: chart),
      ],
    );
  }
}
