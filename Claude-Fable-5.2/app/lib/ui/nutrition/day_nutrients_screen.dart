import 'package:flutter/material.dart';
import 'package:morphhealth_core/morphhealth_core.dart';

import '../theme.dart';
import '../widgets/common.dart';
import 'nutrient_table.dart';

/// All nutrient totals of one day, with water and caffeine.
class DayNutrientsScreen extends StatefulWidget {
  final Day day;

  const DayNutrientsScreen({super.key, required this.day});

  @override
  State<DayNutrientsScreen> createState() => _DayNutrientsScreenState();
}

class _DayNutrientsScreenState extends State<DayNutrientsScreen> {
  late Day _day = widget.day;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final fmt = context.fmt;
    final summary = context.app.nutritionDay(_day);
    final colors = MhColors.of(context);
    final goals = summary.goals;

    Widget goalRow(Nutrient n, double? goal) {
      final value = summary.total(n);
      return Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: GoalBar(
          label: l.nutrient(n),
          value: goal == null
              ? fmt.nutrient(n, value)
              : l.ofGoal(
                  n == Nutrients.energy
                      ? fmt.kcalNumber(value)
                      : fmt.adaptive(value),
                  fmt.number(goal, decimals: 0),
                  n.unit,
                ),
          fraction: goal == null || goal <= 0 ? null : value / goal,
          color: colors.nutrition,
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l.dayNutrientsTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
          children: [
            DayBar(day: _day, onChanged: (d) => setState(() => _day = d)),
            MhCard(
              title: l.nutrientGroup(NutrientGroup.macro),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  goalRow(Nutrients.energy, goals.energyKcal),
                  goalRow(Nutrients.protein, goals.proteinG),
                  goalRow(Nutrients.carbohydrates, goals.carbohydratesG),
                  goalRow(Nutrients.fat, goals.fatG),
                  Text(
                    l.entriesCount(summary.entryCount),
                    style: context.texts.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            MhCard(
              title: l.waterAndCaffeine,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  GoalBar(
                    label: l.water,
                    value: goals.waterMl == null
                        ? fmt.volume(summary.waterMl)
                        : l.ofGoal(
                            fmt.number(summary.waterMl, decimals: 0),
                            fmt.number(goals.waterMl!, decimals: 0),
                            'ml',
                          ),
                    fraction: summary.waterProgress?.fraction,
                    color: colors.water,
                  ),
                  const SizedBox(height: 12),
                  GoalBar(
                    label: l.caffeine,
                    value:
                        '${fmt.mg(summary.caffeineTotalMg)} '
                        '(${fmt.mg(summary.caffeineFoodMg)} ${l.caffeineFromFood}, '
                        '${fmt.mg(summary.caffeineAdditionalMg)} ${l.caffeineAdditional})',
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            MhCard(
              title: l.allNutrients,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l.dayNutrientsHint, style: context.texts.bodySmall),
                  NutrientTable(
                    values: summary.totals,
                    knownCounts: summary.knownCounts,
                    estimatedCounts: summary.estimatedCounts,
                    entryTotal: summary.entryCount,
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
