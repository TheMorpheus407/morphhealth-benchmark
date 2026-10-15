import 'package:flutter/material.dart';
import '../../core/models.dart';
import '../../core/nutrients.dart';
import '../app_state.dart';
import '../modals/entry_modals.dart';
import '../widgets/charts.dart';

class OverviewTab extends StatelessWidget {
  final MorphHealthController ctrl;
  final ValueChanged<int> onNavigateTab;

  const OverviewTab({
    super.key,
    required this.ctrl,
    required this.onNavigateTab,
  });

  @override
  Widget build(BuildContext context) {
    final s = ctrl.s;
    final lang = ctrl.lang;
    final vis = ctrl.settings;
    final dayNutr = ctrl.currentDayNutrition;
    final forecast = ctrl.currentCycleForecast;
    final dayPeriods = ctrl.selectedDayPeriods;
    final dayWeights = ctrl.selectedDayWeights;
    final latestWeight = ctrl.latestWeight;
    final daySymptoms = ctrl.selectedDaySymptoms;
    final weightUnit = vis.weightUnit;

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 28),
      children: [
        // Area visibility filter bar (P02: Die vier Bereiche lassen sich in der Übersicht ein- und ausblenden)
        Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.t(
                    'Sichtbare Bereiche in der Übersicht',
                    'Visible Areas in Overview',
                  ),
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    FilterChip(
                      label: Text(s.domainNutrition),
                      selected: vis.showNutritionInOverview,
                      onSelected: (v) => ctrl.updateSettings(
                        vis.copyWith(showNutritionInOverview: v),
                      ),
                    ),
                    FilterChip(
                      label: Text(s.domainCycle),
                      selected: vis.showCycleInOverview,
                      onSelected: (v) => ctrl.updateSettings(
                        vis.copyWith(showCycleInOverview: v),
                      ),
                    ),
                    FilterChip(
                      label: Text(s.domainWeight),
                      selected: vis.showWeightInOverview,
                      onSelected: (v) => ctrl.updateSettings(
                        vis.copyWith(showWeightInOverview: v),
                      ),
                    ),
                    FilterChip(
                      label: Text(s.domainSymptoms),
                      selected: vis.showSymptomsInOverview,
                      onSelected: (v) => ctrl.updateSettings(
                        vis.copyWith(showSymptomsInOverview: v),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),

        // Unified Day Detail (P06: Ein gemeinsames Tagesdetail führt Ernährung, Wasser/Koffein, Gewicht, Periodenaufzeichnungen und Symptome dieses Tages zusammen)
        Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        s.t(
                          'Gemeinsames Tagesdetail (${ctrl.selectedDate})',
                          'Unified Day Summary (${ctrl.selectedDate})',
                        ),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ],
                ),
                const Divider(height: 18),

                // 1. Nutrition + Water/Caffeine
                if (vis.showNutritionInOverview) ...[
                  InkWell(
                    onTap: () => onNavigateTab(1),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              s.domainNutrition,
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(width: 8),
                            Flexible(
                              child: Text(
                                '${dayNutr.totalNutrients.caloriesKcal.round()} kcal · '
                                '${dayNutr.waterMl.round()} ml ${s.water} · '
                                '${dayNutr.totalCaffeineMg.round()} mg ${s.caffeine}',
                                textAlign: TextAlign.end,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 12,
                          runSpacing: 4,
                          children: [
                            Text(
                              'Protein: ${dayNutr.totalNutrients.proteinG.toStringAsFixed(1)} g',
                              style: const TextStyle(fontSize: 13),
                            ),
                            Text(
                              '${s.t('Kohlenhydrate', 'Carbs')}: ${dayNutr.totalNutrients.carbohydratesG.toStringAsFixed(1)} g',
                              style: const TextStyle(fontSize: 13),
                            ),
                            Text(
                              '${s.t('Fett', 'Fat')}: ${dayNutr.totalNutrients.fatG.toStringAsFixed(1)} g',
                              style: const TextStyle(fontSize: 13),
                            ),
                            Text(
                              '${s.t('Ballaststoffe', 'Fiber')}: ${dayNutr.totalNutrients.fiberG.toStringAsFixed(1)} g',
                              style: const TextStyle(fontSize: 13),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      ActionChip(
                        avatar: const Icon(Icons.restaurant, size: 16),
                        label: Text(s.addFood),
                        onPressed: () => showAddFoodCatalogSheet(context, ctrl),
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.water_drop_outlined, size: 16),
                        label: const Text('+250 ml'),
                        onPressed: () => ctrl.quickAddWater(250),
                      ),
                      ActionChip(
                        avatar: const Icon(Icons.coffee_outlined, size: 16),
                        label: Text('+ ${s.caffeine}'),
                        onPressed: () => showCaffeineEntryDialog(context, ctrl),
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                ],

                // 2. Cycle / Period
                if (vis.showCycleInOverview) ...[
                  InkWell(
                    onTap: () => onNavigateTab(2),
                    child: Row(
                      children: [
                        Icon(
                          Icons.favorite_border,
                          color: Colors.pink.shade500,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.domainCycle,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                dayPeriods.isNotEmpty
                                    ? s.t(
                                        'Periode erfasst (${BleedingIntensity.label(dayPeriods.first.intensity, lang)})',
                                        'Period logged (${BleedingIntensity.label(dayPeriods.first.intensity, lang)})',
                                      )
                                    : (forecast.hasSufficientData
                                        ? s.t(
                                            'Zyklustag ${forecast.currentCycleDay ?? '-'} · Nächste Periode ca. ${forecast.expectedStartDate ?? '-'}',
                                            'Cycle day ${forecast.currentCycleDay ?? '-'} · Next period est. ${forecast.expectedStartDate ?? '-'}',
                                          )
                                        : s.t(
                                            'Keine Periode an diesem Tag erfasst',
                                            'No period logged on this day',
                                          )),
                                style: const TextStyle(fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () => showPeriodEntryDialog(
                            context,
                            ctrl,
                            existing: dayPeriods.isNotEmpty
                                ? dayPeriods.first
                                : null,
                          ),
                          child: Text(
                            dayPeriods.isNotEmpty ? s.edit : s.logPeriod,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 20),
                ],

                // 3. Weight
                if (vis.showWeightInOverview) ...[
                  InkWell(
                    onTap: () => onNavigateTab(3),
                    child: Row(
                      children: [
                        Icon(
                          Icons.monitor_weight_outlined,
                          color: Colors.indigo.shade500,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                s.domainWeight,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                dayWeights.isNotEmpty
                                    ? '${dayWeights.first.valueInUnit(weightUnit).toStringAsFixed(1)} $weightUnit (${s.t('am gewählten Tag', 'on selected day')})'
                                    : (latestWeight != null
                                        ? '${latestWeight.valueInUnit(weightUnit).toStringAsFixed(1)} $weightUnit (${s.t('zuletzt am', 'last on')} ${latestWeight.date})'
                                        : s.t(
                                            'Noch kein Gewicht erfasst',
                                            'No weight recorded yet',
                                          )),
                                style: const TextStyle(fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () => showWeightEntryDialog(
                            context,
                            ctrl,
                            existing: dayWeights.isNotEmpty
                                ? dayWeights.first
                                : null,
                          ),
                          child: Text(
                            dayWeights.isNotEmpty ? s.edit : s.logWeight,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 20),
                ],

                // 4. Symptoms
                if (vis.showSymptomsInOverview) ...[
                  InkWell(
                    onTap: () => onNavigateTab(3),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.healing_outlined,
                              color: Colors.deepPurple.shade400,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '${s.domainSymptoms} (${daySymptoms.length})',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: () =>
                                  showSymptomEntryDialog(context, ctrl),
                              child: Text(s.logSymptom),
                            ),
                          ],
                        ),
                        if (daySymptoms.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(left: 28),
                            child: Text(
                              s.t(
                                'Keine Symptome für diesen Tag protokolliert.',
                                'No symptoms logged for this day.',
                              ),
                              style: const TextStyle(fontSize: 13),
                            ),
                          )
                        else
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              for (final sym in daySymptoms)
                                ActionChip(
                                  label: Text(
                                    '${sym.name} (${sym.intensity}/10)',
                                    style: const TextStyle(fontSize: 12),
                                  ),
                                  onPressed: () => showSymptomEntryDialog(
                                    context,
                                    ctrl,
                                    existing: sym,
                                  ),
                                ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),

        // 7-Day and 28-Day Trends Section (P06: Biete Tagesansichten sowie Verläufe über sieben und 28 Tage an)
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                s.t('Verläufe (7 & 28 Tage)', 'Trends (7 & 28 Days)'),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            SegmentedButton<int>(
              segments: [
                ButtonSegment(value: 7, label: Text(s.days7)),
                ButtonSegment(value: 28, label: Text(s.days28)),
              ],
              selected: {ctrl.selectedTrendDays},
              onSelectionChanged: (sel) => ctrl.setTrendDays(sel.first),
            ),
          ],
        ),
        const SizedBox(height: 10),

        // Selectable NutrientTrend Chart
        if (vis.showNutritionInOverview)
          _SelectableNutrientTrendCard(ctrl: ctrl),

        // Weight Trend Card
        if (vis.showWeightInOverview) _WeightTrendOverviewCard(ctrl: ctrl),

        // Symptom Trend Card
        if (vis.showSymptomsInOverview) _SymptomTrendOverviewCard(ctrl: ctrl),
      ],
    );
  }
}

class _SelectableNutrientTrendCard extends StatelessWidget {
  final MorphHealthController ctrl;

  const _SelectableNutrientTrendCard({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final s = ctrl.s;
    final lang = ctrl.lang;
    final selectedKey = ctrl.selectedNutrientKey;

    String unit = 'kcal';
    int decimals = 0;
    double? goalValue;

    if (selectedKey == 'water_ml') {
      unit = 'ml';
      decimals = 0;
      goalValue = ctrl.settings.goals.waterMl;
    } else {
      final meta = NutrientCatalog.byKey[selectedKey] ??
          NutrientCatalog.all.first;
      unit = meta.unit;
      decimals = meta.decimals;
      if (meta.key == 'calories_kcal') {
        goalValue = ctrl.settings.goals.caloriesKcal;
      } else if (meta.key == 'protein_g') {
        goalValue = ctrl.settings.goals.proteinG;
      } else if (meta.key == 'carbohydrates_g') {
        goalValue = ctrl.settings.goals.carbohydratesG;
      } else if (meta.key == 'fat_g') {
        goalValue = ctrl.settings.goals.fatG;
      }
    }

    final rawSeries = ctrl.repository.getNutrientSeries(
      endDate: ctrl.selectedDate,
      days: ctrl.selectedTrendDays,
      metricKey: selectedKey,
    );
    final points = rawSeries
        .map((e) => TrendPoint(date: e.date, value: e.value))
        .toList();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: Text(
                    s.nutrientTrend,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 3,
                  child: DropdownButton<String>(
                    value: selectedKey,
                    isDense: true,
                    isExpanded: true,
                    items: [
                      DropdownMenuItem(
                        value: 'water_ml',
                        child: Text(
                          '${s.water} (ml)',
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      for (final m in NutrientCatalog.all)
                        DropdownMenuItem(
                          value: m.key,
                          child: Text(
                            '${m.label(lang)} (${m.unit})',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    onChanged: (v) {
                      if (v != null) ctrl.setSelectedNutrientKey(v);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TrendSeriesChart(
              points: points,
              unit: unit,
              goalValue: goalValue,
              color: Colors.teal.shade600,
              decimals: decimals,
              emptyLabel: s.t('Keine Daten im Zeitraum', 'No data in range'),
            ),
          ],
        ),
      ),
    );
  }
}

class _WeightTrendOverviewCard extends StatelessWidget {
  final MorphHealthController ctrl;

  const _WeightTrendOverviewCard({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final s = ctrl.s;
    final unit = ctrl.settings.weightUnit;
    final entries = ctrl.repository.getWeightSeries(
      endDate: ctrl.selectedDate,
      days: ctrl.selectedTrendDays,
    );
    final points = entries
        .map((e) => TrendPoint(date: e.date, value: e.valueInUnit(unit)))
        .toList();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${s.domainWeight} (${ctrl.selectedTrendDays} ${s.t('Tage', 'Days')}, $unit)',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            TrendSeriesChart(
              points: points,
              unit: unit,
              color: Colors.indigo.shade500,
              decimals: 1,
              connectLine: true,
              emptyLabel: s.t(
                'Keine Gewichtseinträge im gewählten Zeitraum',
                'No weight entries in selected period',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SymptomTrendOverviewCard extends StatelessWidget {
  final MorphHealthController ctrl;

  const _SymptomTrendOverviewCard({required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final s = ctrl.s;
    final names = ctrl.repository.distinctSymptomNames;
    final currentSymptom =
        (ctrl.selectedSymptomForTrend != null &&
                names.contains(ctrl.selectedSymptomForTrend))
            ? ctrl.selectedSymptomForTrend
            : (names.isNotEmpty ? names.first : null);

    final series = currentSymptom != null
        ? ctrl.repository.getSymptomSeries(
            symptomName: currentSymptom,
            endDate: ctrl.selectedDate,
            days: ctrl.selectedTrendDays,
          )
        : const <SymptomEntry>[];

    final points = series
        .map((e) => TrendPoint(date: e.date, value: e.intensity.toDouble()))
        .toList();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    s.symptomTrend,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                if (names.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButton<String>(
                      value: currentSymptom,
                      isDense: true,
                      isExpanded: true,
                      items: [
                        for (final n in names)
                          DropdownMenuItem(
                            value: n,
                            child: Text(n, overflow: TextOverflow.ellipsis),
                          ),
                      ],
                      onChanged: (v) => ctrl.setSelectedSymptomForTrend(v),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 8),
            TrendSeriesChart(
              points: points,
              unit: '/ 10',
              color: Colors.deepPurple.shade400,
              decimals: 0,
              connectLine: true,
              emptyLabel: s.t(
                'Noch keine Symptome für einen Verlauf erfasst',
                'No symptoms recorded for trend view yet',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
