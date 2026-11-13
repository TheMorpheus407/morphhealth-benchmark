import 'package:flutter/material.dart';
import 'package:morphhealth_core/morphhealth_core.dart';

import '../shell.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'add_food_screen.dart';
import 'day_nutrients_screen.dart';
import 'goals_screen.dart';
import 'hydration.dart';
import 'intake_screen.dart';
import 'my_foods_screen.dart';

/// The nutrition diary of one day: totals, water and caffeine, four meals.
class DiaryScreen extends StatelessWidget {
  /// The day shown; null follows today. Owned by the main frame, whose
  /// action button logs food for the same day.
  final ValueNotifier<Day?> day;

  const DiaryScreen({super.key, required this.day});

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<Day?>(
    valueListenable: day,
    builder: (context, selected, _) => _build(context, selected),
  );

  Widget _build(BuildContext context, Day? selected) {
    final l = context.l;
    final app = context.app;
    final day = selected ?? app.today;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.navNutrition),
        actions: [
          IconButton(
            tooltip: l.goals,
            icon: const Icon(Icons.flag_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const GoalsScreen()),
            ),
          ),
          IconButton(
            tooltip: l.myFoods,
            icon: const Icon(Icons.kitchen_outlined),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const MyFoodsScreen()),
            ),
          ),
          const SettingsButton(),
        ],
      ),
      body: SafeArea(
        child: ListView(
          // Room below the last card for the action button and a message.
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 168),
          children: [
            DayBar(
              day: day,
              onChanged: (d) => this.day.value = d == app.today ? null : d,
            ),
            const SizedBox(height: 4),
            NutritionSummaryCard(day: day),
            const SizedBox(height: 12),
            for (final meal in Meal.values) ...[
              MealCard(day: day, meal: meal),
              const SizedBox(height: 12),
            ],
            WaterCaffeineCard(day: day),
          ],
        ),
      ),
    );
  }
}

/// Calories and macronutrients of a day, with progress towards goals.
class NutritionSummaryCard extends StatelessWidget {
  final Day day;

  /// Title of the card; the default is "Nährwerte des Tages".
  final String? title;
  final VoidCallback? onOpen;

  /// An additional button below the figures.
  final Widget? action;

  /// Shows the link to the table of all nutrients.
  final bool showAllNutrients;

  const NutritionSummaryCard({
    super.key,
    required this.day,
    this.title,
    this.onOpen,
    this.action,
    this.showAllNutrients = true,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final fmt = context.fmt;
    final summary = context.app.nutritionDay(day);
    final colors = MhColors.of(context);

    Widget macro(Nutrient n) {
      final goal = summary.goalProgress(n);
      final value = summary.total(n);
      return GoalBar(
        label: l.nutrient(n),
        value: goal == null
            ? fmt.nutrient(n, value)
            : l.ofGoal(
                fmt.adaptive(value),
                fmt.number(goal.goal, decimals: 0),
                n.unit,
              ),
        fraction: goal?.fraction,
        color: colors.nutrition,
      );
    }

    final energy = summary.goalProgress(Nutrients.energy);
    return MhCard(
      title: title ?? l.dayNutrientsTitle,
      icon: Icons.restaurant_outlined,
      iconColor: colors.nutrition,
      onOpen: onOpen,
      openLabel: onOpen == null ? null : l.openArea(title ?? l.navNutrition),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            label: energy == null
                ? '${l.nutrient(Nutrients.energy)}: ${fmt.kcal(summary.energyKcal)}'
                : '${l.nutrient(Nutrients.energy)}: ${l.ofGoal(fmt.kcalNumber(summary.energyKcal), fmt.number(energy.goal, decimals: 0), 'kcal')}',
            excludeSemantics: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      fmt.kcalNumber(summary.energyKcal),
                      style: context.texts.headlineMedium,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        energy == null
                            ? 'kcal'
                            : '/ ${fmt.number(energy.goal, decimals: 0)} kcal',
                        style: context.texts.titleMedium?.copyWith(
                          color: context.colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                if (energy != null) ...[
                  const SizedBox(height: 8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: energy.fraction.clamp(0.0, 1.0),
                      minHeight: 8,
                      color: colors.nutrition,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
          AdaptiveColumns(
            children: [
              macro(Nutrients.protein),
              macro(Nutrients.carbohydrates),
              macro(Nutrients.fat),
            ],
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ?action,
              if (showAllNutrients)
                TextButton.icon(
                  icon: const Icon(Icons.table_rows_outlined),
                  label: Text(l.allNutrients),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => DayNutrientsScreen(day: day),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// One meal of a day with its entries.
class MealCard extends StatelessWidget {
  final Day day;
  final Meal meal;

  const MealCard({super.key, required this.day, required this.meal});

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final fmt = context.fmt;
    final summary = context.app.nutritionDay(day);
    final entries = summary.entriesOf(meal);
    final kcal = summary.mealTotals[meal]![Nutrients.energy];
    final emptyNote = Text(
      l.mealEmpty,
      style: context.texts.bodyMedium?.copyWith(
        color: context.colors.onSurfaceVariant,
      ),
    );
    // An empty meal takes one line, so that the meals with entries move up.
    // With enlarged text the note goes below the name.
    final oneLine =
        entries.isEmpty &&
        MediaQuery.textScalerOf(context).scale(14) / 14 <= 1.3;
    return PlainCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(16, 6, 6, oneLine ? 6 : 0),
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    header: true,
                    child: Text(
                      l.meal(meal),
                      style: context.texts.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                if (entries.isNotEmpty)
                  Text(
                    fmt.kcal(kcal ?? 0),
                    style: context.texts.bodyMedium?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                if (oneLine) emptyNote,
                IconButton(
                  tooltip: l.addToMeal(l.meal(meal)),
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: () =>
                      AddFoodScreen.open(context, day: day, meal: meal),
                ),
              ],
            ),
          ),
          if (entries.isEmpty && !oneLine)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: emptyNote,
            ),
          for (final e in entries) IntakeTile(item: e),
          if (entries.isNotEmpty) const SizedBox(height: 6),
        ],
      ),
    );
  }
}

/// One diary entry: tap to correct it, menu to repeat or delete it.
class IntakeTile extends StatelessWidget {
  final IntakeNutrition item;

  /// Shows the time instead of the macronutrients, for the common history.
  final bool showTime;

  const IntakeTile({super.key, required this.item, this.showTime = false});

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final fmt = context.fmt;
    final entry = item.entry;
    final food = item.food;
    final n = item.nutrients;
    String part(Nutrient nutrient, String short) {
      final v = n[nutrient];
      return v == null ? '$short –' : '$short ${fmt.adaptive(v)} g';
    }

    final kcal = n[Nutrients.energy];
    final macros = [
      part(Nutrients.protein, l.languageCode == 'en' ? 'P' : 'E'),
      part(Nutrients.carbohydrates, l.languageCode == 'en' ? 'C' : 'K'),
      part(Nutrients.fat, 'F'),
    ].join(' · ');
    final name = food?.name ?? l.unknownFood;

    return ListTile(
      contentPadding: const EdgeInsets.only(left: 16, right: 4),
      title: Text(name),
      subtitle: Semantics(
        label: [
          fmt.intakeAmount(entry, food),
          if (kcal != null) fmt.kcal(kcal),
          for (final m in Nutrients.main.skip(1))
            if (n[m] != null) '${l.nutrient(m)} ${fmt.nutrient(m, n[m]!)}',
        ].join(', '),
        excludeSemantics: true,
        child: Text(
          '${fmt.intakeAmount(entry, food)}'
          '${showTime ? ' · ${fmt.time(entry.at)}' : ''}\n$macros',
        ),
      ),
      isThreeLine: true,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(
            child: Text(
              kcal == null ? '–' : fmt.kcal(kcal),
              style: context.texts.bodyMedium,
            ),
          ),
          PopupMenuButton<String>(
            tooltip: l.moreActions,
            onSelected: (action) => _onAction(context, action),
            itemBuilder: (_) => [
              PopupMenuItem(value: 'repeat', child: Text(l.repeatEntry)),
              PopupMenuItem(value: 'edit', child: Text(l.edit)),
              PopupMenuItem(value: 'delete', child: Text(l.delete)),
            ],
          ),
        ],
      ),
      onTap: food == null
          ? null
          : () => IntakeScreen.open(context, food: food, entry: entry),
    );
  }

  Future<void> _onAction(BuildContext context, String action) async {
    final l = context.l;
    final repo = context.appRead.repository;
    final entry = item.entry;
    final food = item.food;
    switch (action) {
      case 'repeat':
        IntakeEntry? created;
        final ok = await guarded(context, () async {
          created = await repo.relogIntake(entry.id);
        });
        if (ok && context.mounted) {
          showSnack(
            context,
            l.entryRepeated(food?.name ?? l.unknownFood),
            onUndo: () => repo.deleteIntake(created!.id),
          );
        }
      case 'edit':
        if (food != null) {
          await IntakeScreen.open(context, food: food, entry: entry);
        }
      case 'delete':
        final ok = await guarded(context, () => repo.deleteIntake(entry.id));
        if (ok && context.mounted) {
          showSnack(
            context,
            l.entryDeleted,
            onUndo: () => repo.saveIntake(entry),
          );
        }
    }
  }
}
