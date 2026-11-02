import 'package:flutter/material.dart';
import 'package:morphhealth_core/morphhealth_core.dart';

import '../l10n/app_localizations.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import 'food_search_sheet.dart';
import 'home_shell.dart';
import 'journal_entry_sheet.dart';

/// The food diary of one day.
class NutritionDayView extends StatelessWidget {
  const NutritionDayView({required this.date, super.key});

  final String date;

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final DayNutrition day = state.nutrition.day(date);
    final Goals goals = state.goals;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      children: <Widget>[
        _DateNavigation(date: date),
        const SizedBox(height: 12),
        SectionCard(
          title: l10n.t('nutrition.day_total'),
          child: Column(
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: _BigMetric(
                      label: l10n.t('overview.calories_today'),
                      value: '${day.caloriesKcal.round()}',
                      unit: 'kcal',
                    ),
                  ),
                  Expanded(
                    child: _BigMetric(
                      label: l10n.t('nutrition.water'),
                      value: '${day.waterMl.round()}',
                      unit: 'ml',
                    ),
                  ),
                  Expanded(
                    child: _BigMetric(
                      label: l10n.t('nutrition.caffeine'),
                      value: '${day.caffeineMg.round()}',
                      unit: 'mg',
                    ),
                  ),
                ],
              ),
              if (goals.caloriesKcal != null) ...<Widget>[
                const SizedBox(height: 10),
                GoalBar(
                  label: l10n.t('nutrition.goal_calories'),
                  value: day.caloriesKcal,
                  goal: goals.caloriesKcal!,
                  unit: 'kcal',
                ),
              ],
              if (goals.waterMl != null)
                GoalBar(
                  label: l10n.t('nutrition.goal_water'),
                  value: day.waterMl,
                  goal: goals.waterMl!,
                  unit: 'ml',
                ),
              if (goals.proteinG != null)
                GoalBar(
                  label: l10n.t('nutrition.goal_protein'),
                  value: day.proteinG,
                  goal: goals.proteinG!,
                  unit: 'g',
                ),
              if (goals.carbohydratesG != null)
                GoalBar(
                  label: l10n.t('nutrition.goal_carbs'),
                  value: day.carbohydratesG,
                  goal: goals.carbohydratesG!,
                  unit: 'g',
                ),
              if (goals.fatG != null)
                GoalBar(
                  label: l10n.t('nutrition.goal_fat'),
                  value: day.fatG,
                  goal: goals.fatG!,
                  unit: 'g',
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _WaterCard(date: date),
        const SizedBox(height: 12),
        for (final MealSlot meal in MealSlot.values) ...<Widget>[
          _MealCard(date: date, meal: meal),
          const SizedBox(height: 12),
        ],
        if (day.isEmpty)
          EmptyState(
            message: l10n.t('nutrition.empty_day'),
            icon: Icons.restaurant_menu,
          ),
        Text(
          l10n.t('common.total'),
          style: theme.textTheme.labelSmall,
        ),
      ],
    );
  }
}

class _DateNavigation extends StatelessWidget {
  const _DateNavigation({required this.date});

  final String date;

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final AppLocalizations l10n = context.l10n;
    return Row(
      children: <Widget>[
        IconButton(
          onPressed: () => state.setSelectedDate(
            DateMath.addDays(date, -1),
          ),
          icon: const Icon(Icons.chevron_left),
          tooltip: l10n.t('common.yesterday'),
        ),
        Expanded(
          child: InkWell(
            onTap: () => _pickDate(context),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: <Widget>[
                  Text(
                    formatDay(context, date, withYear: true),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    relativeDayLabel(context, date),
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                  ),
                ],
              ),
            ),
          ),
        ),
        IconButton(
          onPressed: () => state.setSelectedDate(
            DateMath.addDays(date, 1),
          ),
          icon: const Icon(Icons.chevron_right),
          tooltip: l10n.t('common.tomorrow'),
        ),
        TextButton(
          onPressed: () => state.setSelectedDate(
            DateMath.format(DateTime.now()),
          ),
          child: Text(l10n.t('common.today')),
        ),
      ],
    );
  }

  Future<void> _pickDate(BuildContext context) async {
    final AppState state = AppScope.of(context);
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateMath.parse(date),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) state.setSelectedDate(DateMath.format(picked));
  }
}

class _WaterCard extends StatelessWidget {
  const _WaterCard({required this.date});

  final String date;

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final AppLocalizations l10n = context.l10n;
    final DayNutrition day = state.nutrition.day(date);
    final List<IntakeEntry> water = day.intakes
        .where((IntakeEntry e) => e.kind == IntakeKind.water)
        .toList(growable: false);
    final List<IntakeEntry> caffeine = day.intakes
        .where((IntakeEntry e) => e.kind == IntakeKind.caffeine)
        .toList(growable: false);

    return SectionCard(
      title: l10n.t('day.water_caffeine'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '${l10n.t('nutrition.water_quick')}: '
            '${state.settings.waterQuickAmountsMl.map((double v) => v.round()).join(' / ')} ml',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              for (final double amount in state.settings.waterQuickAmountsMl)
                ActionChip(
                  avatar: const Icon(Icons.water_drop_outlined, size: 18),
                  label: Text('${amount.round()} ml'),
                  onPressed: () => _addWater(context, amount),
                ),
              ActionChip(
                avatar: const Icon(Icons.coffee_outlined, size: 18),
                label: Text('${l10n.t('nutrition.caffeine')} +'),
                onPressed: () => _addCaffeine(context),
              ),
            ],
          ),
          if (water.isNotEmpty || caffeine.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            for (final IntakeEntry entry in <IntakeEntry>[...water, ...caffeine])
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: Icon(
                  entry.kind == IntakeKind.water
                      ? Icons.water_drop_outlined
                      : Icons.coffee_outlined,
                ),
                title: Text(
                  entry.kind == IntakeKind.water
                      ? '${entry.amount.round()} ml ${l10n.t('nutrition.water')}'
                      : '${entry.amount.round()} mg ${l10n.t('nutrition.caffeine')}',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  tooltip: l10n.t('common.delete'),
                  onPressed: () => state.deleteIntake(entry.id),
                ),
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _addWater(BuildContext context, double amount) async {
    final AppState state = AppScope.of(context);
    final DateTime now = DateTime.now();
    await state.upsertIntake(IntakeEntry(
      id: Ids.newId(),
      kind: IntakeKind.water,
      amount: amount,
      date: date,
      loggedAtMs: DateTime(
        DateMath.parse(date).year,
        DateMath.parse(date).month,
        DateMath.parse(date).day,
        now.hour,
        now.minute,
      ).millisecondsSinceEpoch,
    ));
  }

  Future<void> _addCaffeine(BuildContext context) async {
    final AppState state = AppScope.of(context);
    final double? amount = await showDialog<double>(
      context: context,
      builder: (BuildContext context) {
        final TextEditingController controller =
            TextEditingController(text: '100');
        return AlertDialog(
          title: Text(context.l10n.t('nutrition.caffeine_add')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              TextField(
                controller: controller,
                autofocus: true,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'mg',
                  helperText: context.l10n.t('nutrition.caffeine_hint'),
                ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text(context.l10n.t('common.cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(
                double.tryParse(controller.text.replaceAll(',', '.')),
              ),
              child: Text(context.l10n.t('common.save')),
            ),
          ],
        );
      },
    );
    if (amount == null || amount <= 0) return;
    final DateTime now = DateTime.now();
    await state.upsertIntake(IntakeEntry(
      id: Ids.newId(),
      kind: IntakeKind.caffeine,
      amount: amount,
      date: date,
      loggedAtMs: DateTime(
        DateMath.parse(date).year,
        DateMath.parse(date).month,
        DateMath.parse(date).day,
        now.hour,
        now.minute,
      ).millisecondsSinceEpoch,
    ));
  }
}

class _MealCard extends StatelessWidget {
  const _MealCard({required this.date, required this.meal});

  final String date;
  final MealSlot meal;

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final AppLocalizations l10n = context.l10n;
    final NutritionService service = state.nutrition;
    final DayNutrition day = service.day(date);
    final List<JournalEntry> entries = day.entriesForMeal(meal);
    final NutrientProfile totals = service.totalsForMeal(day, meal);

    return SectionCard(
      title: l10n.t('meal.${meal.name}'),
      trailing: IconButton(
        icon: const Icon(Icons.add),
        tooltip: l10n.t('common.add'),
        onPressed: () => FoodPickerSheet.show(context),
      ),
      child: entries.isEmpty
          ? Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Text(
                l10n.t('common.empty'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            )
          : Column(
              children: <Widget>[
                for (final JournalEntry entry in entries)
                  _EntryTile(entry: entry, date: date),
                const Divider(height: 18),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: <Widget>[
                    Text(
                      l10n.t('nutrition.meal_total'),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      '${totals[Nutrients.energyKcal].round()} kcal · '
                      '${totals[Nutrients.protein].toStringAsFixed(1)} g P · '
                      '${totals[Nutrients.carbohydrates].toStringAsFixed(1)} g K · '
                      '${totals[Nutrients.fat].toStringAsFixed(1)} g F',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ],
            ),
    );
  }
}

class _EntryTile extends StatelessWidget {
  const _EntryTile({required this.entry, required this.date});

  final JournalEntry entry;
  final String date;

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final AppLocalizations l10n = context.l10n;
    final double grams = state.nutrition.gramsFor(entry);
    final NutrientProfile contribution =
        state.nutrition.contributionOf(entry);
    final FoodItem? food = state.repository.foodById(entry.foodId);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(entry.foodName),
      subtitle: Text(
        '${_quantityLabel(entry, grams)} · '
        '${contribution[Nutrients.energyKcal].round()} kcal',
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (food != null)
            IconButton(
              icon: Icon(
                food.isFavorite ? Icons.star : Icons.star_border,
                size: 20,
              ),
              tooltip: l10n.t('common.favorite'),
              onPressed: () =>
                  state.upsertFood(food.copyWith(isFavorite: !food.isFavorite)),
            ),
          IconButton(
            icon: const Icon(Icons.replay_outlined, size: 20),
            tooltip: l10n.t('nutrition.log_again'),
            onPressed: () => JournalEntrySheet.show(
              context,
              food: food ?? _fallbackFood(entry),
              template: entry,
              initialDate: date,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20),
            tooltip: l10n.t('common.edit'),
            onPressed: () => JournalEntrySheet.show(
              context,
              food: food ?? _fallbackFood(entry),
              entry: entry,
              initialDate: date,
            ),
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline, size: 20),
            tooltip: l10n.t('common.delete'),
            onPressed: () => state.deleteJournalEntry(entry.id),
          ),
        ],
      ),
    );
  }

  FoodItem _fallbackFood(JournalEntry entry) => FoodItem(
        id: entry.foodId,
        name: entry.foodName,
        source: FoodSource.custom,
        nutrientsPer100: NutrientProfile(entry.nutrientsPer100Snapshot),
        createdAtMs: entry.createdAtMs,
        updatedAtMs: entry.updatedAtMs,
      );

  static String _quantityLabel(JournalEntry entry, double grams) {
    switch (entry.unit) {
      case QuantityUnit.gram:
        return '${_trim(entry.quantity)} g';
      case QuantityUnit.milliliter:
        return '${_trim(entry.quantity)} ml';
      case QuantityUnit.portion:
        final String label = entry.portionLabel ?? 'Portion';
        return '${_trim(entry.quantity)} × $label (${_trim(grams)} g)';
    }
  }

  static String _trim(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(1);
  }
}

class _BigMetric extends StatelessWidget {
  const _BigMetric({
    required this.label,
    required this.value,
    required this.unit,
  });

  final String label;
  final String value;
  final String unit;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 2),
        RichText(
          text: TextSpan(
            children: <InlineSpan>[
              TextSpan(
                text: value,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              TextSpan(
                text: ' $unit',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
