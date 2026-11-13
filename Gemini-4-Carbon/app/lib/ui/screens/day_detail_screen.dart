/// Unified Day Detail screen (P06) combining Nutrition, Water/Caffeine,
/// Cycle/Period records, Weight, and Symptoms for any selected calendar day.
library;

import 'package:flutter/material.dart';

import '../../core/nutrients.dart';
import '../app_controller.dart';
import '../sheets/entry_editors.dart';
import '../sheets/food_sheets.dart';
import '../theme.dart';
import '../widgets/date_bar.dart';

Future<void> openDayDetailScreen(
  BuildContext context,
  AppController controller, {
  String? dateIso,
}) async {
  if (dateIso != null) {
    controller.setSelectedDate(dateIso);
  }
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => DayDetailScreen(controller: controller),
    ),
  );
}

class DayDetailScreen extends StatelessWidget {
  final AppController controller;

  const DayDetailScreen({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final s = controller.strings;
        final bundle = controller.store.overviewForDay(controller.selectedDate);
        final nut = bundle.nutrition;
        final dispUnit = controller.preferences.weightUnit;
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return Scaffold(
          appBar: AppBar(title: Text(s.dayDetailTitle)),
          body: ListView(
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              MediaQuery.viewPaddingOf(context).bottom + 32,
            ),
            children: [
              MhDateSelectorBar(controller: controller),
              const SizedBox(height: 16),

              // 1. Nutrition + All Micronutrients
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.restaurant_rounded,
                            color: Theme.of(context).colorScheme.primary,
                          ),
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
                          TextButton.icon(
                            onPressed: () => showAddFoodModal(
                              context,
                              controller,
                            ),
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: Text(s.add),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 16,
                        runSpacing: 8,
                        children: [
                          _StatPill(
                            label: s.tr('Kalorien', 'Calories'),
                            value:
                                '${nut.combinedNutrients.valueOrZero(NutrientKey.caloriesKcal).round()} kcal',
                          ),
                          _StatPill(
                            label: 'Protein',
                            value:
                                '${nut.combinedNutrients.valueOrZero(NutrientKey.proteinG).toStringAsFixed(1)} g',
                          ),
                          _StatPill(
                            label: s.tr('Kohlenhydrate', 'Carbs'),
                            value:
                                '${nut.combinedNutrients.valueOrZero(NutrientKey.carbsG).toStringAsFixed(1)} g',
                          ),
                          _StatPill(
                            label: s.tr('Fett', 'Fat'),
                            value:
                                '${nut.combinedNutrients.valueOrZero(NutrientKey.fatG).toStringAsFixed(1)} g',
                          ),
                        ],
                      ),
                      if (nut.allMealEntries.isNotEmpty) ...[
                        const Divider(height: 22),
                        for (final r in nut.allMealEntries)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            title: Text(
                              r.entry.displayName(r.food, controller.localeCode),
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              '${r.entry.mealType.label(controller.localeCode)} · ${r.entry.amount} ${r.entry.unit.label(controller.localeCode)}',
                            ),
                            trailing: Text(
                              '${r.nutrients.valueOrZero(NutrientKey.caloriesKcal).round()} kcal',
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            onTap: () => showLogFoodEntrySheet(
                              context,
                              controller,
                              food: r.food,
                              existingEntry: r.entry,
                            ),
                          ),
                      ] else
                        Padding(
                          padding: const EdgeInsets.only(top: 10),
                          child: Text(
                            s.tr(
                              'Keine Mahlzeiten an diesem Tag erfasst.',
                              'No meals logged on this day.',
                            ),
                            style: TextStyle(
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                        ),
                      ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        title: Text(
                          s.allNutrientsAndMicros,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        children: [
                          for (final k in NutrientKey.values.where(
                            (x) => x.category != NutrientCategory.macro,
                          ))
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2.5),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      k.label(controller.localeCode),
                                      style: const TextStyle(fontSize: 13),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${nut.combinedNutrients.valueOrZero(k).toStringAsFixed(k.decimals)} ${k.unit}',
                                    style: const TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // 2. Water & Caffeine
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.water_drop_rounded,
                            color: isDark
                                ? MhColors.waterAccentDark
                                : MhColors.waterAccentLight,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              s.waterAndCaffeine,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          ActionChip(
                            label: Text('+ ${s.water}'),
                            onPressed: () => showWaterEditorSheet(
                              context,
                              controller,
                            ),
                          ),
                          ActionChip(
                            label: Text('+ ${s.caffeine}'),
                            onPressed: () => showCaffeineEditorSheet(
                              context,
                              controller,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${s.water}: ${nut.waterMl.round()} ml · ${s.caffeine}: ${nut.totalCaffeineMg.round()} mg (${s.tr("direkt", "direct")}: ${nut.caffeineDirectMg.round()} mg, ${s.tr("Lebensmittel", "foods")}: ${nut.caffeineFromFoodsMg.round()} mg)',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      for (final w in nut.waterEntries)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: Text('${s.water}: ${w.amountMl.round()} ml'),
                          subtitle: w.note != null ? Text(w.note!) : null,
                          onTap: () => showWaterEditorSheet(
                            context,
                            controller,
                            existing: w,
                          ),
                        ),
                      for (final c in nut.caffeineEntries)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: Text(
                            '${c.sourceLabel ?? s.caffeine}: ${c.amountMg.round()} mg',
                          ),
                          subtitle: c.note != null ? Text(c.note!) : null,
                          onTap: () => showCaffeineEditorSheet(
                            context,
                            controller,
                            existing: c,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // 3. Cycle / Period
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_month_rounded,
                            color: isDark
                                ? MhColors.cycleAccentDark
                                : MhColors.cycleAccentLight,
                          ),
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
                          TextButton.icon(
                            onPressed: () => showPeriodEditorSheet(
                              context,
                              controller,
                              initialStartDate: controller.selectedDate,
                            ),
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: Text(s.add),
                          ),
                        ],
                      ),
                      if (bundle.cycleForecast.currentCycleDay != null)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            '${s.tr("Zyklustag", "Cycle day")} ${bundle.cycleForecast.currentCycleDay}',
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      if (bundle.periodsCoveringDay.isEmpty)
                        Text(
                          s.tr(
                            'Keine Blutung oder Spotting für diesen Tag eingetragen.',
                            'No bleeding or spotting logged for this day.',
                          ),
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        )
                      else
                        for (final pe in bundle.periodsCoveringDay)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            title: Text(
                              '${pe.countsAsPeriod ? s.tr("Periode", "Period") : "Spotting"} · ${pe.intensityForDate(controller.selectedDate).label(controller.localeCode)}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: Text(
                              '${pe.startDate} – ${pe.endDate ?? s.tr("laufend", "ongoing")}${pe.note != null ? " · ${pe.note}" : ""}',
                            ),
                            onTap: () => showPeriodEditorSheet(
                              context,
                              controller,
                              existing: pe,
                            ),
                          ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // 4. Weight
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.monitor_weight_outlined,
                            color: isDark
                                ? MhColors.weightAccentDark
                                : MhColors.weightAccentLight,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              s.weightTitle,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () => showWeightEditorSheet(
                              context,
                              controller,
                              initialDate: controller.selectedDate,
                            ),
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: Text(s.add),
                          ),
                        ],
                      ),
                      if (bundle.weightEntries.isEmpty)
                        Text(
                          s.tr(
                            'Kein Gewichtseintrag an diesem Tag.',
                            'No weight entry on this day.',
                          ),
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        )
                      else
                        for (final w in bundle.weightEntries)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            title: Text(
                              '${w.valueIn(dispUnit).toStringAsFixed(1)} ${dispUnit.jsonKey}',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w700),
                            ),
                            subtitle: w.note != null ? Text(w.note!) : null,
                            onTap: () => showWeightEditorSheet(
                              context,
                              controller,
                              existing: w,
                            ),
                          ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // 5. Symptoms
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.healing_outlined,
                            color: isDark
                                ? MhColors.symptomAccentDark
                                : MhColors.symptomAccentLight,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              s.symptomsTitle,
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () => showSymptomEditorSheet(
                              context,
                              controller,
                              initialDate: controller.selectedDate,
                            ),
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: Text(s.add),
                          ),
                        ],
                      ),
                      if (bundle.symptomEntries.isEmpty)
                        Text(
                          s.tr(
                            'Keine Symptome an diesem Tag dokumentiert.',
                            'No symptoms recorded on this day.',
                          ),
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        )
                      else
                        for (final sym in bundle.symptomEntries)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            dense: true,
                            title: Text(
                              '${sym.name} (${sym.intensity}/10)',
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            subtitle: sym.note != null ? Text(sym.note!) : null,
                            onTap: () => showSymptomEditorSheet(
                              context,
                              controller,
                              existing: sym,
                            ),
                          ),
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

class _StatPill extends StatelessWidget {
  final String label;
  final String value;

  const _StatPill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
