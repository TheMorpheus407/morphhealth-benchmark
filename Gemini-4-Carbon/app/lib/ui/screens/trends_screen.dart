/// 7-day and 28-day Trends screen (P06) with selectable nutrient/water trend,
/// weight trend, and per-symptom intensity trend.
library;

import 'package:flutter/material.dart';

import '../../core/nutrients.dart';
import '../app_controller.dart';
import '../theme.dart';
import '../widgets/date_bar.dart';
import '../widgets/trend_chart.dart';

Future<void> openTrendsScreen(
  BuildContext context,
  AppController controller, {
  String? initialMetricKey,
}) async {
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => TrendsScreen(
        controller: controller,
        initialMetricKey: initialMetricKey,
      ),
    ),
  );
}

class TrendsScreen extends StatefulWidget {
  final AppController controller;
  final String? initialMetricKey;

  const TrendsScreen({
    super.key,
    required this.controller,
    this.initialMetricKey,
  });

  @override
  State<TrendsScreen> createState() => _TrendsScreenState();
}

class _TrendsScreenState extends State<TrendsScreen> {
  int _windowDays = 7; // 7 or 28
  late String _selectedMetricKey;
  String? _selectedSymptom;

  @override
  void initState() {
    super.initState();
    _selectedMetricKey =
        widget.initialMetricKey ?? NutrientKey.caloriesKcal.jsonKey;
    final names = widget.controller.store.distinctSymptomNames;
    if (names.isNotEmpty) _selectedSymptom = names.first;
  }

  double? _goalForMetric(String key) {
    final g = widget.controller.goals;
    if (key == 'water_ml') return g.waterMl;
    if (key == NutrientKey.caloriesKcal.jsonKey) return g.caloriesKcal;
    if (key == NutrientKey.proteinG.jsonKey) return g.proteinG;
    if (key == NutrientKey.carbsG.jsonKey) return g.carbsG;
    if (key == NutrientKey.fatG.jsonKey) return g.fatG;
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final c = widget.controller;
        final s = c.strings;
        final isDark = Theme.of(context).brightness == Brightness.dark;

        final isWater = _selectedMetricKey == 'water_ml';
        final nKey = NutrientKey.byJsonKey[_selectedMetricKey];
        final metricTitle = isWater
            ? s.water
            : (nKey?.label(c.localeCode) ?? _selectedMetricKey);
        final metricUnit = isWater ? 'ml' : (nKey?.unit ?? '');
        final metricDecimals = isWater ? 0 : (nKey?.decimals ?? 1);

        final nutSeries = c.store.nutrientTrendSeries(
          endDateIso: c.selectedDate,
          days: _windowDays,
          metricKey: _selectedMetricKey,
        );

        final dispUnit = c.preferences.weightUnit;
        final weightSeries = c.store.weightTrendSeries(
          endDateIso: c.selectedDate,
          days: _windowDays,
          unit: dispUnit,
        );

        final symNames = c.store.distinctSymptomNames;
        final activeSym = (_selectedSymptom != null &&
                symNames.contains(_selectedSymptom))
            ? _selectedSymptom
            : (symNames.isNotEmpty ? symNames.first : null);

        final symSeries = activeSym != null
            ? c.store.symptomTrendSeries(
                endDateIso: c.selectedDate,
                days: _windowDays,
                symptomName: activeSym,
              )
            : null;

        return Scaffold(
          appBar: AppBar(title: Text(s.trendsTitle)),
          body: ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              MediaQuery.viewPaddingOf(context).bottom + 32,
            ),
            children: [
              MhDateSelectorBar(controller: c),
              const SizedBox(height: 12),
              SegmentedButton<int>(
                segments: [
                  ButtonSegment(value: 7, label: Text(s.window7Days)),
                  ButtonSegment(value: 28, label: Text(s.window28Days)),
                ],
                selected: {_windowDays},
                onSelectionChanged: (v) =>
                    setState(() => _windowDays = v.first),
              ),
              const SizedBox(height: 16),

              // 1. Selectable Nutrient / Water Chart
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.tr('Ernährungs- & Wasserverlauf', 'Nutrition & Water Trend'),
                        style: const TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedMetricKey,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: s.tr('Messgröße wählen', 'Select nutrient / metric'),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 'water_ml',
                            child: Text('${s.water} (ml)'),
                          ),
                          for (final k in NutrientKey.values)
                            DropdownMenuItem(
                              value: k.jsonKey,
                              child: Text('${k.label(c.localeCode)} (${k.unit})'),
                            ),
                        ],
                        onChanged: (v) {
                          if (v != null) {
                            setState(() => _selectedMetricKey = v);
                          }
                        },
                      ),
                      const SizedBox(height: 14),
                      MhTrendChart(
                        points: nutSeries,
                        unit: metricUnit,
                        title: metricTitle,
                        color: isWater
                            ? (isDark
                                ? MhColors.waterAccentDark
                                : MhColors.waterAccentLight)
                            : Theme.of(context).colorScheme.primary,
                        style: MhChartStyle.bar,
                        goalValue: _goalForMetric(_selectedMetricKey),
                        decimals: metricDecimals,
                        localeCode: c.localeCode,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // 2. Weight Trend Chart
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${s.weightTitle} (${dispUnit.jsonKey})',
                        style: const TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 12),
                      MhTrendChart(
                        points: weightSeries,
                        unit: dispUnit.jsonKey,
                        title: s.weightTitle,
                        color: isDark
                            ? MhColors.weightAccentDark
                            : MhColors.weightAccentLight,
                        style: MhChartStyle.line,
                        decimals: 1,
                        localeCode: c.localeCode,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // 3. Per-Symptom Trend Chart
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.tr('Symptomverlauf (0–10)', 'Symptom Trend (0–10)'),
                        style: const TextStyle(
                          fontSize: 16.5,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),
                      if (symNames.isEmpty)
                        Text(
                          s.tr(
                            'Sobald Symptome erfasst sind, lässt sich ihr zeitlicher Verlauf hier gezielt betrachten.',
                            'Once symptoms are recorded, their intensity course can be inspected here.',
                          ),
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        )
                      else ...[
                        DropdownButtonFormField<String>(
                          initialValue: activeSym,
                          isExpanded: true,
                          decoration: InputDecoration(
                            labelText: s.symptomTrendSelect,
                          ),
                          items: [
                            for (final name in symNames)
                              DropdownMenuItem(value: name, child: Text(name)),
                          ],
                          onChanged: (v) =>
                              setState(() => _selectedSymptom = v),
                        ),
                        const SizedBox(height: 14),
                        MhTrendChart(
                          points: symSeries!,
                          unit: '/10',
                          title: activeSym!,
                          color: isDark
                              ? MhColors.symptomAccentDark
                              : MhColors.symptomAccentLight,
                          style: MhChartStyle.line,
                          fixedMinY: 0,
                          fixedMaxY: 10,
                          decimals: 0,
                          localeCode: c.localeCode,
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
