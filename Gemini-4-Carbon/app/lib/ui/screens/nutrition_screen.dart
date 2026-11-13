/// Complete Nutrition Diary screen (P03) with Macros, Extended & 21 Micronutrients,
/// Water quick-add, Caffeine tracking, Voluntary Goals, and Meal sections.
library;

import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../core/nutrients.dart';
import '../../core/nutrition_service.dart';
import '../app_controller.dart';
import '../sheets/entry_editors.dart';
import '../sheets/food_sheets.dart';
import '../theme.dart';
import '../widgets/date_bar.dart';
import 'trends_screen.dart';

class NutritionScreen extends StatelessWidget {
  final AppController controller;

  const NutritionScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    final s = controller.strings;
    final day = controller.store.nutritionForDay(controller.selectedDate);
    final goals = controller.goals;
    final cs = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text(s.nutritionDiary),
        actions: [
          IconButton(
            tooltip: s.goalsButton,
            onPressed: () => showGoalsEditorSheet(context, controller),
            icon: const Icon(Icons.flag_outlined),
          ),
          IconButton(
            tooltip: s.openTrends,
            onPressed: () => openTrendsScreen(context, controller),
            icon: const Icon(Icons.insights_rounded),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_nutrition',
        onPressed: () => showAddFoodModal(context, controller),
        icon: const Icon(Icons.add_rounded),
        label: Text(s.addFood),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 88),
        children: [
          MhDateSelectorBar(controller: controller),
          const SizedBox(height: 14),

          // Daily Macro & All 21 Micronutrients Summary Card
          _DailyNutrientSummaryCard(
            controller: controller,
            day: day,
            goals: goals,
          ),
          const SizedBox(height: 12),

          // Water & Caffeine Card (integrated directly in Nutrition Diary per P02/P03)
          _WaterAndCaffeineCard(
            controller: controller,
            day: day,
            goals: goals,
            waterColor:
                isDark ? MhColors.waterAccentDark : MhColors.waterAccentLight,
            cs: cs,
          ),
          const SizedBox(height: 12),

          // Four Meal Sections: Breakfast, Lunch, Dinner, Snack
          for (final mt in MealType.values) ...[
            _MealSectionCard(
              controller: controller,
              mealSummary: day.meals[mt]!,
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }
}

class _DailyNutrientSummaryCard extends StatelessWidget {
  final AppController controller;
  final NutritionDaySummary day;
  final NutritionGoals goals;

  const _DailyNutrientSummaryCard({
    required this.controller,
    required this.day,
    required this.goals,
  });

  @override
  Widget build(BuildContext context) {
    final s = controller.strings;
    final n = day.combinedNutrients;
    final cs = Theme.of(context).colorScheme;

    final kcal = n.valueOrZero(NutrientKey.caloriesKcal);
    final prot = n.valueOrZero(NutrientKey.proteinG);
    final carbs = n.valueOrZero(NutrientKey.carbsG);
    final fat = n.valueOrZero(NutrientKey.fatG);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    s.tr('Tagesübersicht Nährwerte', 'Daily Nutrition Summary'),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => showGoalsEditorSheet(context, controller),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  child: Text(s.goalsButton),
                ),
              ],
            ),
            const SizedBox(height: 6),
            _MacroRowWithOptionalGoal(
              label: s.tr('Kalorien', 'Calories'),
              actual: kcal,
              goal: goals.caloriesKcal,
              unit: 'kcal',
              decimals: 0,
              color: cs.primary,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _CompactMacroTile(
                    label: 'Protein',
                    actual: prot,
                    goal: goals.proteinG,
                    color: cs.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _CompactMacroTile(
                    label: s.tr('Kohlenhydrate', 'Carbs'),
                    actual: carbs,
                    goal: goals.carbsG,
                    color: cs.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _CompactMacroTile(
                    label: s.tr('Fett', 'Fat'),
                    actual: fat,
                    goal: goals.fatG,
                    color: cs.primary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: Text(
                s.allNutrientsAndMicros,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              children: [
                _NutrientCategoryTable(
                  title: s.extendedSection,
                  keys: NutrientKey.byCategory(NutrientCategory.extended),
                  profile: n,
                  localeCode: controller.localeCode,
                ),
                const Divider(height: 18),
                _NutrientCategoryTable(
                  title: s.vitaminsSection,
                  keys: NutrientKey.byCategory(NutrientCategory.vitamin),
                  profile: n,
                  localeCode: controller.localeCode,
                ),
                const Divider(height: 18),
                _NutrientCategoryTable(
                  title: s.mineralsSection,
                  keys: NutrientKey.byCategory(NutrientCategory.mineral),
                  profile: n,
                  localeCode: controller.localeCode,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MacroRowWithOptionalGoal extends StatelessWidget {
  final String label;
  final double actual;
  final double? goal;
  final String unit;
  final int decimals;
  final Color color;

  const _MacroRowWithOptionalGoal({
    required this.label,
    required this.actual,
    required this.goal,
    required this.unit,
    required this.decimals,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final valStr = actual.toStringAsFixed(decimals);
    final goalStr = goal != null ? ' / ${goal!.toStringAsFixed(decimals)}' : '';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                '$valStr$goalStr $unit',
                textAlign: TextAlign.end,
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        if (goal != null && goal! > 0) ...[
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              minHeight: 7,
              value: (actual / goal!).clamp(0.0, 1.0),
              color: color,
              backgroundColor: color.withValues(alpha: 0.15),
            ),
          ),
        ],
      ],
    );
  }
}

class _CompactMacroTile extends StatelessWidget {
  final String label;
  final double actual;
  final double? goal;
  final Color color;

  const _CompactMacroTile({
    required this.label,
    required this.actual,
    required this.goal,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: 2),
          Text(
            goal != null
                ? '${actual.toStringAsFixed(1)} / ${goal!.round()} g'
                : '${actual.toStringAsFixed(1)} g',
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
          ),
          if (goal != null && goal! > 0) ...[
            const SizedBox(height: 5),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                minHeight: 4,
                value: (actual / goal!).clamp(0.0, 1.0),
                color: color,
                backgroundColor: color.withValues(alpha: 0.15),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NutrientCategoryTable extends StatelessWidget {
  final String title;
  final List<NutrientKey> keys;
  final NutrientProfile profile;
  final String localeCode;

  const _NutrientCategoryTable({
    required this.title,
    required this.keys,
    required this.profile,
    required this.localeCode,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 13.5,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        const SizedBox(height: 6),
        for (final k in keys)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.5),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    k.label(localeCode),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                Text(
                  '${profile.valueOrZero(k).toStringAsFixed(k.decimals)} ${k.unit}',
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

class _WaterAndCaffeineCard extends StatelessWidget {
  final AppController controller;
  final NutritionDaySummary day;
  final NutritionGoals goals;
  final Color waterColor;
  final ColorScheme cs;

  const _WaterAndCaffeineCard({
    required this.controller,
    required this.day,
    required this.goals,
    required this.waterColor,
    required this.cs,
  });

  @override
  Widget build(BuildContext context) {
    final s = controller.strings;
    final quickAmounts = controller.preferences.waterQuickAmountsMl;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.water_drop_rounded, color: waterColor),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    s.waterAndCaffeine,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            _MacroRowWithOptionalGoal(
              label: s.water,
              actual: day.waterMl,
              goal: goals.waterMl,
              unit: 'ml',
              decimals: 0,
              color: waterColor,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final ml in quickAmounts)
                  ActionChip(
                    avatar: Icon(Icons.add_rounded, size: 16, color: waterColor),
                    label: Text('$ml ml'),
                    onPressed: () => controller.quickAddWater(ml.toDouble()),
                  ),
                ActionChip(
                  label: Text(s.customAmount),
                  onPressed: () => showWaterEditorSheet(context, controller),
                ),
              ],
            ),
            const Divider(height: 24),
            Row(
              children: [
                Expanded(
                  child: Text(
                    s.caffeine,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                Text(
                  '${day.totalCaffeineMg.round()} mg',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            Text(
              '${s.tr("Direkt erfasst", "Direct")}: ${day.caffeineDirectMg.round()} mg · ${s.tr("Aus Lebensmitteln", "From foods")}: ${day.caffeineFromFoodsMg.round()} mg',
              style: TextStyle(fontSize: 12.5, color: cs.onSurfaceVariant),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  label: const Text('Espresso (65 mg)'),
                  onPressed: () =>
                      controller.quickAddCaffeine(65, sourceLabel: 'Espresso'),
                ),
                ActionChip(
                  label: Text('${s.tr("Kaffee", "Coffee")} (95 mg)'),
                  onPressed: () => controller.quickAddCaffeine(
                    95,
                    sourceLabel: s.tr('Filterkaffee', 'Coffee'),
                  ),
                ),
                ActionChip(
                  label: Text('${s.tr("Tee", "Tea")} (40 mg)'),
                  onPressed: () => controller.quickAddCaffeine(
                    40,
                    sourceLabel: s.tr('Tee', 'Tea'),
                  ),
                ),
                ActionChip(
                  label: Text(s.customAmount),
                  onPressed: () => showCaffeineEditorSheet(context, controller),
                ),
              ],
            ),
            if (day.waterEntries.isNotEmpty || day.caffeineEntries.isNotEmpty)
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(
                  s.tr(
                    'Einzeleinträge (${day.waterEntries.length + day.caffeineEntries.length})',
                    'Individual logs (${day.waterEntries.length + day.caffeineEntries.length})',
                  ),
                  style: const TextStyle(fontSize: 13.5),
                ),
                children: [
                  for (final w in day.waterEntries)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: const Icon(Icons.water_drop_outlined, size: 18),
                      title: Text('${s.water}: ${w.amountMl.round()} ml'),
                      subtitle: w.note != null ? Text(w.note!) : null,
                      trailing: const Icon(Icons.edit_outlined, size: 18),
                      onTap: () => showWaterEditorSheet(
                        context,
                        controller,
                        existing: w,
                      ),
                    ),
                  for (final c in day.caffeineEntries)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: const Icon(Icons.coffee_outlined, size: 18),
                      title: Text(
                        '${c.sourceLabel ?? s.caffeine}: ${c.amountMg.round()} mg',
                      ),
                      subtitle: c.note != null ? Text(c.note!) : null,
                      trailing: const Icon(Icons.edit_outlined, size: 18),
                      onTap: () => showCaffeineEditorSheet(
                        context,
                        controller,
                        existing: c,
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _MealSectionCard extends StatelessWidget {
  final AppController controller;
  final MealGroupSummary mealSummary;

  const _MealSectionCard({
    required this.controller,
    required this.mealSummary,
  });

  @override
  Widget build(BuildContext context) {
    final s = controller.strings;
    final mt = mealSummary.mealType;
    final kcal =
        mealSummary.totals.valueOrZero(NutrientKey.caloriesKcal).round();

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${mt.label(controller.localeCode)} · $kcal kcal',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => showAddFoodModal(
                    context,
                    controller,
                    initialMealType: mt,
                  ),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(s.add),
                ),
              ],
            ),
            if (mealSummary.entries.isEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  s.tr('Noch kein Eintrag', 'No entries yet'),
                  style: TextStyle(
                    fontSize: 13,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              for (final r in mealSummary.entries)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    r.entry.displayName(r.food, controller.localeCode),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: Text(
                    '${_fmt(r.entry.amount)} ${r.entry.unit.label(controller.localeCode)} · ${r.nutrients.valueOrZero(NutrientKey.caloriesKcal).round()} kcal · P ${r.nutrients.valueOrZero(NutrientKey.proteinG).toStringAsFixed(1)}g · KH ${r.nutrients.valueOrZero(NutrientKey.carbsG).toStringAsFixed(1)}g · F ${r.nutrients.valueOrZero(NutrientKey.fatG).toStringAsFixed(1)}g',
                  ),
                  trailing: IconButton(
                    tooltip: s.relogEntry,
                    onPressed: () async {
                      await controller.relogMealEntry(r.entry);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(s.reloggedNotice)),
                        );
                      }
                    },
                    icon: const Icon(Icons.replay_rounded, size: 20),
                  ),
                  onTap: () => showLogFoodEntrySheet(
                    context,
                    controller,
                    food: r.food,
                    existingEntry: r.entry,
                  ),
                ),
          ],
        ),
      ),
    );
  }

  static String _fmt(double v) =>
      v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);
}
