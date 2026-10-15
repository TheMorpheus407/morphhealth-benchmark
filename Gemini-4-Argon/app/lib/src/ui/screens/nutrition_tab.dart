import 'package:flutter/material.dart';
import '../../core/models.dart';
import '../../core/nutrients.dart';
import '../app_state.dart';
import '../modals/entry_modals.dart';
import '../widgets/charts.dart';

class NutritionTab extends StatefulWidget {
  final MorphHealthController ctrl;

  const NutritionTab({super.key, required this.ctrl});

  @override
  State<NutritionTab> createState() => _NutritionTabState();
}

class _NutritionTabState extends State<NutritionTab> {
  bool _showAllDayNutrients = false;

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.ctrl;
    final s = ctrl.s;
    final lang = ctrl.lang;
    final day = ctrl.currentDayNutrition;
    final n = day.totalNutrients;
    final goals = ctrl.settings.goals;

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 80),
      children: [
        // Top Action Bar
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              icon: const Icon(Icons.add),
              label: Text(s.addFood),
              onPressed: () => showAddFoodCatalogSheet(context, ctrl),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.restaurant_menu, size: 18),
              label: Text(s.createCustomFood),
              onPressed: () => showCustomFoodEditorSheet(context, ctrl),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.flag_outlined, size: 18),
              label: Text(s.dailyGoals),
              onPressed: () => showGoalsDialog(context, ctrl),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Daily Macro & Micronutrient Summary Card
        Card(
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
                          'Tagesbilanz (${ctrl.selectedDate})',
                          'Daily Summary (${ctrl.selectedDate})',
                        ),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '${n.caloriesKcal.round()} kcal',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _GoalMacroRow(
                  label: s.t('Kalorien', 'Calories'),
                  value: n.caloriesKcal,
                  goal: goals.caloriesKcal,
                  unit: 'kcal',
                  decimals: 0,
                  color: Colors.teal.shade700,
                ),
                const SizedBox(height: 8),
                _GoalMacroRow(
                  label: 'Protein',
                  value: n.proteinG,
                  goal: goals.proteinG,
                  unit: 'g',
                  decimals: 1,
                  color: Colors.blue.shade700,
                ),
                const SizedBox(height: 8),
                _GoalMacroRow(
                  label: s.t('Kohlenhydrate', 'Carbohydrates'),
                  value: n.carbohydratesG,
                  goal: goals.carbohydratesG,
                  unit: 'g',
                  decimals: 1,
                  color: Colors.orange.shade700,
                ),
                const SizedBox(height: 8),
                _GoalMacroRow(
                  label: s.t('Fett', 'Fat'),
                  value: n.fatG,
                  goal: goals.fatG,
                  unit: 'g',
                  decimals: 1,
                  color: Colors.amber.shade800,
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    icon: Icon(
                      _showAllDayNutrients
                          ? Icons.expand_less
                          : Icons.expand_more,
                    ),
                    label: Text(
                      _showAllDayNutrients
                          ? s.t(
                              'Mikronährstoffe ausblenden',
                              'Hide Micronutrients',
                            )
                          : s.t(
                              'Alle 31 Nährstoffe & Mikronährstoffe des Tages',
                              'All 31 Daily Nutrients & Micronutrients',
                            ),
                    ),
                    onPressed: () => setState(
                      () => _showAllDayNutrients = !_showAllDayNutrients,
                    ),
                  ),
                ),
                if (_showAllDayNutrients) ...[
                  const Divider(),
                  _DayNutrientSection(
                    title: s.extendedNutrients,
                    metas:
                        NutrientCatalog.byCategory(NutrientCategory.extended),
                    profile: n,
                    lang: lang,
                  ),
                  const SizedBox(height: 10),
                  _DayNutrientSection(
                    title: s.vitamins,
                    metas: NutrientCatalog.byCategory(NutrientCategory.vitamin),
                    profile: n,
                    lang: lang,
                  ),
                  const SizedBox(height: 10),
                  _DayNutrientSection(
                    title: s.minerals,
                    metas: NutrientCatalog.byCategory(NutrientCategory.mineral),
                    profile: n,
                    lang: lang,
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Water & Caffeine Card (P02 & P03: Wasser und Koffein gehören in das Ernährungstagebuch; Schnellerfassung für häufige Wassermengen)
        Card(
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
                        s.waterAndCaffeine,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        '${day.waterMl.round()} ml · ${day.totalCaffeineMg.round()} mg',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                _GoalMacroRow(
                  label: s.water,
                  value: day.waterMl,
                  goal: goals.waterMl,
                  unit: 'ml',
                  decimals: 0,
                  color: Colors.lightBlue.shade600,
                ),
                const SizedBox(height: 10),
                Text(
                  s.t(
                    'Wasser-Schnellerfassung:',
                    'Quick-add Water:',
                  ),
                  style: Theme.of(context).textTheme.labelMedium,
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    for (final ml in const [150.0, 250.0, 330.0, 500.0])
                      FilledButton.tonalIcon(
                        icon: const Icon(Icons.water_drop_outlined, size: 16),
                        label: Text('+${ml.round()} ml'),
                        onPressed: () => ctrl.quickAddWater(ml),
                      ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.edit_outlined, size: 16),
                      label: Text(s.t('Eigene Menge', 'Custom')),
                      onPressed: () => showWaterEntryDialog(context, ctrl),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '${s.caffeine}: ${day.totalCaffeineMg.round()} mg '
                        '(${s.t('Getränke', 'Drinks')}: ${day.caffeineFromDrinksMg.round()} mg, '
                        '${s.t('Essen', 'Food')}: ${day.caffeineFromFoodMg.round()} mg)',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.coffee, size: 16),
                      label: Text('+ ${s.caffeine}'),
                      onPressed: () => showCaffeineEntryDialog(context, ctrl),
                    ),
                  ],
                ),
                if (day.waterEntries.isNotEmpty ||
                    day.caffeineEntries.isNotEmpty) ...[
                  const Divider(),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final w in day.waterEntries)
                        InputChip(
                          avatar: const Icon(Icons.water_drop, size: 15),
                          label: Text('${w.amountMl.round()} ml'),
                          onPressed: () => showWaterEntryDialog(
                            context,
                            ctrl,
                            existing: w,
                          ),
                          onDeleted: () => ctrl.deleteWaterEntry(w.id),
                        ),
                      for (final c in day.caffeineEntries)
                        InputChip(
                          avatar: const Icon(Icons.coffee, size: 15),
                          label: Text(
                            '${c.beverageName ?? s.caffeine}: ${c.amountMg.round()} mg',
                          ),
                          onPressed: () => showCaffeineEntryDialog(
                            context,
                            ctrl,
                            existing: c,
                          ),
                          onDeleted: () => ctrl.deleteCaffeineEntry(c.id),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Meals (Frühstück, Mittagessen, Abendessen, Snack)
        for (final mealKey in MealType.all)
          _MealSectionCard(
            ctrl: ctrl,
            mealKey: mealKey,
            entries: day.meals[mealKey]?.entries ?? const [],
            mealTotals: day.meals[mealKey]?.totals ?? NutrientProfile(),
          ),

        const SizedBox(height: 12),
        // Selectable Nutrient Trend (7 & 28 days)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Text(
                      s.nutrientTrend,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                    SegmentedButton<int>(
                      segments: [
                        ButtonSegment(value: 7, label: Text(s.days7)),
                        ButtonSegment(value: 28, label: Text(s.days28)),
                      ],
                      selected: {ctrl.selectedTrendDays},
                      onSelectionChanged: (sel) =>
                          ctrl.setTrendDays(sel.first),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  initialValue: ctrl.selectedNutrientKey,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: [
                    DropdownMenuItem(
                      value: 'water_ml',
                      child: Text('${s.water} (ml)'),
                    ),
                    for (final m in NutrientCatalog.all)
                      DropdownMenuItem(
                        value: m.key,
                        child: Text('${m.label(lang)} (${m.unit})'),
                      ),
                  ],
                  onChanged: (v) {
                    if (v != null) ctrl.setSelectedNutrientKey(v);
                  },
                ),
                const SizedBox(height: 12),
                Builder(
                  builder: (context) {
                    final key = ctrl.selectedNutrientKey;
                    final meta = NutrientCatalog.byKey[key];
                    final unit = key == 'water_ml' ? 'ml' : (meta?.unit ?? '');
                    final decimals =
                        key == 'water_ml' ? 0 : (meta?.decimals ?? 1);
                    final series = ctrl.repository
                        .getNutrientSeries(
                          endDate: ctrl.selectedDate,
                          days: ctrl.selectedTrendDays,
                          metricKey: key,
                        )
                        .map((e) => TrendPoint(date: e.date, value: e.value))
                        .toList();
                    return TrendSeriesChart(
                      points: series,
                      unit: unit,
                      color: Colors.teal.shade600,
                      decimals: decimals,
                      emptyLabel: s.t('Keine Daten', 'No data'),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _GoalMacroRow extends StatelessWidget {
  final String label;
  final double value;
  final double? goal;
  final String unit;
  final int decimals;
  final Color color;

  const _GoalMacroRow({
    required this.label,
    required this.value,
    this.goal,
    required this.unit,
    required this.decimals,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final valStr = value.toStringAsFixed(decimals);
    final goalStr = goal != null && goal! > 0
        ? ' / ${goal!.toStringAsFixed(decimals)} $unit'
        : ' $unit';
    final progress =
        (goal != null && goal! > 0) ? (value / goal!).clamp(0.0, 1.0) : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(label, style: const TextStyle(fontSize: 13)),
            ),
            const SizedBox(width: 8),
            Text(
              '$valStr$goalStr',
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        if (progress != null) ...[
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              color: color,
              backgroundColor: color.withValues(alpha: 0.15),
            ),
          ),
        ],
      ],
    );
  }
}

class _DayNutrientSection extends StatelessWidget {
  final String title;
  final List<NutrientMeta> metas;
  final NutrientProfile profile;
  final String lang;

  const _DayNutrientSection({
    required this.title,
    required this.metas,
    required this.profile,
    required this.lang,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 4),
        for (final m in metas)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(m.label(lang), style: const TextStyle(fontSize: 13)),
                Text(
                  '${profile[m.key].toStringAsFixed(m.decimals)} ${m.unit}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _MealSectionCard extends StatelessWidget {
  final MorphHealthController ctrl;
  final String mealKey;
  final List<FoodDiaryEntry> entries;
  final NutrientProfile mealTotals;

  const _MealSectionCard({
    required this.ctrl,
    required this.mealKey,
    required this.entries,
    required this.mealTotals,
  });

  @override
  Widget build(BuildContext context) {
    final s = ctrl.s;
    final lang = ctrl.lang;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        MealType.label(mealKey, lang),
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                      Text(
                        '${mealTotals.caloriesKcal.round()} kcal · '
                        'P ${mealTotals.proteinG.toStringAsFixed(1)}g · '
                        'KH ${mealTotals.carbohydratesG.toStringAsFixed(1)}g · '
                        'F ${mealTotals.fatG.toStringAsFixed(1)}g',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: '${s.addFood} (${MealType.label(mealKey, lang)})',
                  icon: const Icon(Icons.add),
                  onPressed: () => showAddFoodCatalogSheet(
                    context,
                    ctrl,
                    initialMeal: mealKey,
                  ),
                ),
              ],
            ),
            if (entries.isNotEmpty) ...[
              const Divider(height: 16),
              for (final e in entries)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(
                    e.food.displayName(lang),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '${e.amount.toStringAsFixed(e.amount == e.amount.roundToDouble() ? 0 : 1)} '
                    '${FoodUnit.label(e.unit, lang)} · '
                    '${e.nutrients.caloriesKcal.round()} kcal '
                    '(P ${e.nutrients.proteinG.toStringAsFixed(1)}g, '
                    'KH ${e.nutrients.carbohydratesG.toStringAsFixed(1)}g, '
                    'F ${e.nutrients.fatG.toStringAsFixed(1)}g)',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: s.logAgain,
                        icon: const Icon(Icons.replay, size: 18),
                        onPressed: () async {
                          await ctrl.relogFoodEntry(e);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  s.t(
                                    '„${e.food.displayName(lang)}“ erneut erfasst.',
                                    'Logged "${e.food.displayName(lang)}" again.',
                                  ),
                                ),
                              ),
                            );
                          }
                        },
                      ),
                      IconButton(
                        tooltip: s.edit,
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        onPressed: () => showFoodEntryEditorSheet(
                          context,
                          ctrl,
                          existingEntry: e,
                        ),
                      ),
                      IconButton(
                        tooltip: s.delete,
                        icon: const Icon(Icons.delete_outline, size: 18),
                        onPressed: () => ctrl.deleteFoodEntry(e.id),
                      ),
                    ],
                  ),
                  onTap: () => showFoodEntryEditorSheet(
                    context,
                    ctrl,
                    existingEntry: e,
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
