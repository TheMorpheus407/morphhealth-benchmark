// Verläufe: Balkendiagramm pro Nährstoff/Wasser/Koffein, Liniendiagramm
// für das Gewicht, jeweils über die letzten 7 oder 28 Tage.
library;

import 'package:flutter/material.dart';

import '../core/parse.dart';
import '../data/repository.dart';
import '../l10n/app_strings.dart';
import '../model/cycle.dart';
import '../nutrients/nutrients.dart';
import '../nutrition/day.dart';
import 'scope.dart';
import 'widgets.dart';

class TrendsScreen extends StatefulWidget {
  const TrendsScreen({super.key});

  @override
  State<TrendsScreen> createState() => _TrendsScreenState();
}

class _TrendsScreenState extends State<TrendsScreen> {
  int _days = 7;
  String _metric = 'energy_kcal';

  /// Alle wählbaren Kennzahlen: 31 Nährstoffe + Wasser + Koffein + Gewicht.
  static final List<String> _metricKeys = <String>[
    for (final NutrientDef d in nutrientDefs) d.key,
    'water',
    'caffeine',
    'weight',
  ];

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = StringsScope.of(context);
    final MorphRepository repo = MorphScope.repoOf(context);
    return Scaffold(
      appBar: AppBar(title: Text(strings.trendsTitle)),
      body: ListenableBuilder(
        listenable: MorphScope.listenableOf(context),
        builder: (BuildContext context, Widget? _) {
          final DateTime now = DateTime.now();
          final DateTime today = DateTime.utc(now.year, now.month, now.day);
          final DateTime from = today.subtract(Duration(days: _days - 1));
          final String fromStr = formatDate(from);
          final String toStr = formatDate(today);
          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: <Widget>[
              SectionCard(
                title: strings.selectMetricLabel,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    SegmentedButton<int>(
                      segments: <ButtonSegment<int>>[
                        ButtonSegment<int>(
                            value: 7, label: Text(strings.last7)),
                        ButtonSegment<int>(
                            value: 28, label: Text(strings.last28)),
                      ],
                      selected: <int>{_days},
                      onSelectionChanged: (Set<int> v) =>
                          setState(() => _days = v.first),
                    ),
                    const SizedBox(height: 12),
                    DropdownButtonFormField<String>(
                      initialValue: _metric,
                      isExpanded: true,
                      decoration: InputDecoration(
                          labelText: strings.selectMetricLabel),
                      items: <DropdownMenuItem<String>>[
                        for (final String key in _metricKeys)
                          DropdownMenuItem<String>(
                            value: key,
                            child: Text(strings.trendMetricName(key)),
                          ),
                      ],
                      onChanged: (String? v) {
                        if (v != null) setState(() => _metric = v);
                      },
                    ),
                  ],
                ),
              ),
              if (_metric == 'weight')
                _weightCard(strings, repo, fromStr, toStr)
              else
                _seriesCard(strings, repo, from, fromStr, toStr),
            ],
          );
        },
      ),
    );
  }

  // ------------------------------------------------------------- Serie

  double _valueOf(Map<String, dynamic> day) {
    switch (_metric) {
      case 'water':
        return (day['water_ml'] as num).toDouble();
      case 'caffeine':
        return (day['caffeine_mg'] as num).toDouble();
      default:
        final Map<String, double> totals = day['totals'] as Map<String, double>;
        return totals[_metric] ?? 0;
    }
  }

  String _unitOf(AppStrings strings) {
    switch (_metric) {
      case 'water':
        return 'ml';
      case 'caffeine':
        return 'mg';
      default:
        return strings.nutrientUnit(_metric);
    }
  }

  String _fmt(AppStrings strings, double v) {
    switch (_metric) {
      case 'water':
        return strings.formatMl(v);
      case 'caffeine':
        return strings.formatMg(v);
      default:
        return strings.nutrientAmount(_metric, v);
    }
  }

  Widget _seriesCard(AppStrings strings, MorphRepository repo, DateTime from,
      String fromStr, String toStr) {
    final List<Map<String, dynamic>> series =
        computeNutrientSeries(repo.document, fromStr, toStr);
    final List<double> values =
        <double>[for (final Map<String, dynamic> d in series) _valueOf(d)];
    final List<String> labels = <String>[
      for (int i = 0; i < _days; i++)
        _label(strings, from.add(Duration(days: i)), i),
    ];
    final bool hasData = values.any((double v) => v > 0);
    return SectionCard(
      title: strings.trendMetricName(_metric),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (hasData)
            BarChart(
              values: values,
              labels: labels,
              unit: _unitOf(strings),
              height: 180,
            )
          else
            EmptyState(
              icon: Icons.trending_up,
              text: strings.trendNoData,
            ),
          const SizedBox(height: 8),
          _stats(strings, values),
        ],
      ),
    );
  }

  String _label(AppStrings strings, DateTime d, int i) {
    if (_days <= 7) return strings.weekdayShort(d.weekday);
    // 28 Tage: nur jeden vierten Tag beschriften (sonst überlappen die Texte).
    if (i % 4 != 0) return '';
    return '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.';
  }

  // ------------------------------------------------------------- Gewicht

  Widget _weightCard(
      AppStrings strings, MorphRepository repo, String fromStr, String toStr) {
    final String unit = repo.settings.weightUnit;
    final List<WeightEntry> inRange = repo.sortedWeightEntries
        .where((WeightEntry e) =>
            e.date.compareTo(fromStr) >= 0 && e.date.compareTo(toStr) <= 0)
        .toList();
    final List<double> kgValues =
        <double>[for (final WeightEntry e in inRange) e.weightKg];
    return SectionCard(
      title: strings.trendMetricName('weight'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (inRange.isEmpty)
            EmptyState(
              icon: Icons.monitor_weight_outlined,
              text: strings.trendNoData,
            )
          else ...<Widget>[
            if (inRange.length >= 2)
              LineChart(
                values: <double>[
                  for (final WeightEntry e in inRange)
                    unit == 'lb' ? e.weightKg * 2.2046226218 : e.weightKg,
                ],
                labels: <String>[
                  for (final WeightEntry e in inRange)
                    strings.formatDateShort(parseDate(e.date)!),
                ],
                unit: unit,
                height: 180,
              ),
            StatRow(
              label: strings.latestWeight,
              value: strings.formatWeight(
                  inRange.last.weightKg, unit),
            ),
            const SizedBox(height: 8),
            _statsKg(strings, kgValues),
          ],
        ],
      ),
    );
  }

  // ------------------------------------------------------------- Statistik

  Widget _stats(AppStrings strings, List<double> values) {
    if (values.isEmpty) {
      return Text(strings.trendNoData,
          style: Theme.of(context).textTheme.bodySmall);
    }
    final double total =
        values.fold(0.0, (double a, double b) => a + b);
    final double avg = total / values.length;
    final double min = values.reduce((double a, double b) => a < b ? a : b);
    final double max = values.reduce((double a, double b) => a > b ? a : b);
    return Column(
      children: <Widget>[
        StatRow(label: strings.averageLabel, value: _fmt(strings, avg)),
        StatRow(label: strings.totalLabel, value: _fmt(strings, total)),
        StatRow(label: strings.minLabel, value: _fmt(strings, min)),
        StatRow(label: strings.maxLabel, value: _fmt(strings, max)),
      ],
    );
  }

  Widget _statsKg(AppStrings strings, List<double> kgValues) {
    if (kgValues.isEmpty) {
      return Text(strings.trendNoData,
          style: Theme.of(context).textTheme.bodySmall);
    }
    final String unit = MorphScope.repoOf(context).settings.weightUnit;
    final double total =
        kgValues.fold(0.0, (double a, double b) => a + b);
    final double avg = total / kgValues.length;
    final double min = kgValues.reduce((double a, double b) => a < b ? a : b);
    final double max = kgValues.reduce((double a, double b) => a > b ? a : b);
    String fmt(double v) => strings.formatWeight(v, unit);
    return Column(
      children: <Widget>[
        StatRow(label: strings.averageLabel, value: fmt(avg)),
        StatRow(label: strings.minLabel, value: fmt(min)),
        StatRow(label: strings.maxLabel, value: fmt(max)),
      ],
    );
  }
}
