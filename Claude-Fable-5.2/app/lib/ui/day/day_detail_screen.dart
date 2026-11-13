import 'package:flutter/material.dart';
import 'package:morphhealth_core/morphhealth_core.dart';

import '../body/body_screen.dart' show SymptomTile;
import '../body/editors.dart';
import '../cycle/cycle_day_panel.dart';
import '../nutrition/add_food_screen.dart';
import '../nutrition/diary_screen.dart';
import '../nutrition/hydration.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Everything recorded on one day in one place: nutrition, water and
/// caffeine, weight, period records and symptoms, each editable.
class DayDetailScreen extends StatefulWidget {
  final Day day;

  const DayDetailScreen({super.key, required this.day});

  @override
  State<DayDetailScreen> createState() => _DayDetailScreenState();
}

class _DayDetailScreenState extends State<DayDetailScreen> {
  late Day _day = widget.day;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final fmt = context.fmt;
    final app = context.app;
    final colors = MhColors.of(context);
    final unit = app.settings.weightUnit;
    final weights = app.data.weightsOn(_day);
    final symptoms = app.data.symptomsOn(_day);
    final summary = app.nutritionDay(_day);

    return Scaffold(
      appBar: AppBar(title: Text(l.dayDetail)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
          children: [
            DayBar(day: _day, onChanged: (d) => setState(() => _day = d)),
            const SizedBox(height: 4),

            // Nutrition
            NutritionSummaryCard(day: _day, title: l.navNutrition),
            const SizedBox(height: 12),
            for (final meal in Meal.values)
              if (summary.entriesOf(meal).isNotEmpty) ...[
                MealCard(day: _day, meal: meal),
                const SizedBox(height: 12),
              ],
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                icon: const Icon(Icons.add),
                label: Text(l.logFood),
                onPressed: () => AddFoodScreen.open(context, day: _day),
              ),
            ),
            const SizedBox(height: 4),

            // Water and caffeine
            WaterCaffeineCard(day: _day),
            const SizedBox(height: 12),

            // Weight
            MhCard(
              title: l.weight,
              icon: Icons.monitor_weight_outlined,
              iconColor: colors.weight,
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (weights.isEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                      child: Text(
                        l.nothingLoggedYet,
                        style: context.texts.bodyMedium?.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                    )
                  else
                    for (final w in weights)
                      ListTile(
                        title: Text(fmt.weight(w.weightKg, unit)),
                        subtitle: w.note == null ? null : Text(w.note!),
                        trailing: const Icon(Icons.edit_outlined),
                        onTap: () => showWeightEditor(context, entry: w),
                      ),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      icon: const Icon(Icons.add),
                      label: Text(l.addWeight),
                      onPressed: () => showWeightEditor(context, day: _day),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            // Cycle
            MhCard(
              title: l.navCycle,
              icon: Icons.calendar_month_outlined,
              iconColor: colors.period,
              child: CycleDayPanel(day: _day, withSymptoms: false),
            ),
            const SizedBox(height: 12),

            // Symptoms
            MhCard(
              title: l.symptoms,
              icon: Icons.healing_outlined,
              iconColor: colors.symptom,
              padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (symptoms.isEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
                      child: Text(
                        l.noSymptomsThisDay,
                        style: context.texts.bodyMedium?.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                    )
                  else
                    for (final s in symptoms)
                      SymptomTile(entry: s, showDate: false),
                  Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: TextButton.icon(
                      icon: const Icon(Icons.add),
                      label: Text(l.addSymptom),
                      onPressed: () => showSymptomEditor(context, day: _day),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
