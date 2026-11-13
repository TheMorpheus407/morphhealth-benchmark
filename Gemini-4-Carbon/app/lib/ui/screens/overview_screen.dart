/// Calm personal Overview screen (P02, P06) with toggleable area cards,
/// quick capture actions, Unified Day Detail entry, and 7d/28d Trends shortcut.
library;

import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../core/nutrients.dart';
import '../app_controller.dart';
import '../sheets/entry_editors.dart';
import '../sheets/food_sheets.dart';
import '../theme.dart';
import '../widgets/date_bar.dart';
import 'day_detail_screen.dart';
import 'settings_screen.dart';
import 'trends_screen.dart';

class OverviewScreen extends StatelessWidget {
  final AppController controller;

  const OverviewScreen({super.key, required this.controller});

  void _showCustomizeModulesSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      builder: (ctx) {
        return ListenableBuilder(
          listenable: controller,
          builder: (ctx, _) {
            final s = controller.strings;
            final vis = controller.preferences.visibleOverviewModules;
            return Padding(
              padding: EdgeInsets.fromLTRB(
                20,
                4,
                20,
                MediaQuery.viewPaddingOf(ctx).bottom + 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.customizeAreas,
                    style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    s.tr(
                      'Wähle frei aus, welche Bereiche in deiner Übersicht erscheinen sollen.',
                      'Choose freely which areas appear on your personal overview.',
                    ),
                    style: TextStyle(
                      color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (final mod in AppModule.values)
                    SwitchListTile.adaptive(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        mod.label(controller.localeCode),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      value: vis.contains(mod),
                      onChanged: (_) => controller.toggleOverviewModule(mod),
                    ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = controller.strings;
    final bundle = controller.store.overviewForDay(controller.selectedDate);
    final visible = controller.preferences.visibleOverviewModules;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('MorphHealth'),
        actions: [
          IconButton(
            tooltip: s.customizeAreas,
            onPressed: () => _showCustomizeModulesSheet(context),
            icon: const Icon(Icons.tune_rounded),
          ),
          IconButton(
            tooltip: s.settingsTitle,
            onPressed: () => openSettingsScreen(context, controller),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
        children: [
          MhDateSelectorBar(controller: controller),
          const SizedBox(height: 12),

          // Unified Day Detail & 7d/28d Trends Action Row
          Row(
            children: [
              Expanded(
                child: FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  onPressed: () => openDayDetailScreen(context, controller),
                  icon: const Icon(Icons.view_day_outlined, size: 17),
                  label: Text(
                    s.openDayDetail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13.5),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                  ),
                  onPressed: () => openTrendsScreen(context, controller),
                  icon: const Icon(Icons.insights_rounded, size: 17),
                  label: Text(
                    s.openTrends,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13.5),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          if (visible.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      s.allModulesHidden,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    FilledButton.tonal(
                      onPressed: () => _showCustomizeModulesSheet(context),
                      child: Text(s.customizeAreas),
                    ),
                  ],
                ),
              ),
            ),

          // 1. Nutrition Card
          if (visible.contains(AppModule.nutrition)) ...[
            _buildNutritionOverviewCard(context, bundle, cs, isDark),
            const SizedBox(height: 12),
          ],

          // 2. Cycle Card
          if (visible.contains(AppModule.cycle)) ...[
            _buildCycleOverviewCard(context, bundle, isDark),
            const SizedBox(height: 12),
          ],

          // 3. Weight Card
          if (visible.contains(AppModule.weight)) ...[
            _buildWeightOverviewCard(context, bundle, isDark),
            const SizedBox(height: 12),
          ],

          // 4. Symptoms Card
          if (visible.contains(AppModule.symptoms)) ...[
            _buildSymptomsOverviewCard(context, bundle, isDark),
          ],
        ],
      ),
    );
  }

  Widget _buildNutritionOverviewCard(
    BuildContext context,
    dynamic bundle,
    ColorScheme cs,
    bool isDark,
  ) {
    final s = controller.strings;
    final nut = bundle.nutrition;
    final kcal =
        nut.combinedNutrients.valueOrZero(NutrientKey.caloriesKcal).round();
    final prot = nut.combinedNutrients
        .valueOrZero(NutrientKey.proteinG)
        .toStringAsFixed(0);
    final carbs = nut.combinedNutrients
        .valueOrZero(NutrientKey.carbsG)
        .toStringAsFixed(0);
    final fat =
        nut.combinedNutrients.valueOrZero(NutrientKey.fatG).toStringAsFixed(0);
    final water = nut.waterMl.round();
    final caff = nut.totalCaffeineMg.round();
    final goals = controller.goals;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => controller.setNavIndex(1),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.restaurant_rounded, color: cs.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      s.navNutrition,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, size: 20),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                goals.caloriesKcal != null
                    ? '$kcal / ${goals.caloriesKcal!.round()} kcal'
                    : '$kcal kcal',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Protein $prot g · ${s.tr("Kohlenhydrate", "Carbs")} $carbs g · ${s.tr("Fett", "Fat")} $fat g',
                style: TextStyle(color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 4),
              Text(
                '${s.water}: ${goals.waterMl != null ? "$water / ${goals.waterMl!.round()} ml" : "$water ml"} · ${s.caffeine}: $caff mg',
                style: TextStyle(
                  color: isDark
                      ? MhColors.waterAccentDark
                      : MhColors.waterAccentLight,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ActionChip(
                    avatar: const Icon(Icons.add_rounded, size: 16),
                    label: Text(s.tr('Mahlzeit', 'Meal')),
                    onPressed: () => showAddFoodModal(context, controller),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.water_drop_outlined, size: 16),
                    label: const Text('+250 ml'),
                    onPressed: () => controller.quickAddWater(250),
                  ),
                  ActionChip(
                    avatar: const Icon(Icons.coffee_outlined, size: 16),
                    label: Text('+ ${s.caffeine}'),
                    onPressed: () =>
                        showCaffeineEditorSheet(context, controller),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCycleOverviewCard(
    BuildContext context,
    dynamic bundle,
    bool isDark,
  ) {
    final s = controller.strings;
    final fc = bundle.cycleForecast;
    final accent =
        isDark ? MhColors.cycleAccentDark : MhColors.cycleAccentLight;

    String headline;
    String subline;
    if (fc.isPeriodActiveOnDate) {
      headline = s.tr('Periode / Blutung eingetragen', 'Period / bleeding logged');
      subline = fc.activeFlowIntensity?.label(controller.localeCode) ?? '';
    } else if (fc.diaryOnlyMode) {
      headline = fc.currentCycleDay != null
          ? '${s.tr("Zyklustag", "Cycle day")} ${fc.currentCycleDay}'
          : s.tr('Zyklus-Tagebuch', 'Cycle diary');
      subline = s.tr('Tagebuch-Modus ohne Prognose', 'Diary-only mode active');
    } else if (fc.predictedNextStart != null) {
      final d = fc.daysUntilExpectedStart ?? 0;
      if (d > 0) {
        headline = s.tr(
          'Nächste Periode in ca. $d Tagen',
          'Next period in ~$d days',
        );
      } else if (d == 0) {
        headline = s.tr(
          'Voraussichtlicher Beginn um heute',
          'Expected start around today',
        );
      } else {
        headline = s.tr(
          '${d.abs()} Tage nach üblichem Richtwert',
          '${d.abs()} days past typical estimate',
        );
      }
      subline =
          '${s.tr("Fenster", "Window")}: ${fc.predictedWindowStart} – ${fc.predictedWindowEnd}';
    } else if (fc.currentCycleDay != null) {
      headline = '${s.tr("Zyklustag", "Cycle day")} ${fc.currentCycleDay}';
      subline = s.tr(
        'Ab der 2. Periode persönliche Prognose verfügbar',
        'Personal forecast available once 2nd period is logged',
      );
    } else {
      headline = s.tr('Noch keine Periode erfasst', 'No period recorded yet');
      subline = s.tr(
        'Tippe zum Erfassen oder Planen im Kalender',
        'Tap to log or inspect the cycle calendar',
      );
    }

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => controller.setNavIndex(2),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.calendar_month_rounded, color: accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      s.navCycle,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, size: 20),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                headline,
                style: const TextStyle(
                  fontSize: 16.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (subline.isNotEmpty) ...[
                const SizedBox(height: 3),
                Text(
                  subline,
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 10),
              ActionChip(
                avatar: const Icon(Icons.add_rounded, size: 16),
                label: Text(s.logPeriodOrSpotting),
                onPressed: () => showPeriodEditorSheet(
                  context,
                  controller,
                  initialStartDate: controller.selectedDate,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildWeightOverviewCard(
    BuildContext context,
    dynamic bundle,
    bool isDark,
  ) {
    final s = controller.strings;
    final unit = controller.preferences.weightUnit;
    final dayWeights = bundle.weightEntries as List<WeightEntry>;
    final allWeights = controller.store.allWeights;
    final accent =
        isDark ? MhColors.weightAccentDark : MhColors.weightAccentLight;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => controller.setNavIndex(3),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.monitor_weight_outlined, color: accent),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      s.weightTitle,
                      style: const TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      dayWeights.isNotEmpty
                          ? '${dayWeights.first.valueIn(unit).toStringAsFixed(1)} ${unit.jsonKey} (${s.tr("gewählter Tag", "selected day")})'
                          : (allWeights.isNotEmpty
                              ? '${s.tr("Zuletzt", "Latest")}: ${allWeights.first.valueIn(unit).toStringAsFixed(1)} ${unit.jsonKey} (${allWeights.first.date})'
                              : s.tr('Kein Eintrag vorhanden', 'No entry yet')),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.tonal(
                onPressed: () => showWeightEditorSheet(
                  context,
                  controller,
                  existing: dayWeights.isNotEmpty ? dayWeights.first : null,
                ),
                child: Text(dayWeights.isNotEmpty ? s.edit : '+ ${unit.jsonKey}'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSymptomsOverviewCard(
    BuildContext context,
    dynamic bundle,
    bool isDark,
  ) {
    final s = controller.strings;
    final syms = bundle.symptomEntries as List<SymptomEntry>;
    final accent =
        isDark ? MhColors.symptomAccentDark : MhColors.symptomAccentLight;

    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => controller.setNavIndex(3),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.healing_outlined, color: accent),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      s.symptomsTitle,
                      style: const TextStyle(
                        fontSize: 16.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  FilledButton.tonal(
                    onPressed: () =>
                        showSymptomEditorSheet(context, controller),
                    child: Text('+ ${s.tr("Symptom", "Symptom")}'),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              if (syms.isEmpty)
                Text(
                  s.tr(
                    'Keine Symptome am gewählten Tag.',
                    'No symptoms logged on the selected day.',
                  ),
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                )
              else
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final sym in syms)
                      InputChip(
                        label: Text('${sym.name} (${sym.intensity}/10)'),
                        onPressed: () => showSymptomEditorSheet(
                          context,
                          controller,
                          existing: sym,
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
