import 'package:flutter/material.dart';
import 'package:morphhealth_core/morphhealth_core.dart';

import '../l10n/app_localizations.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import 'food_search_sheet.dart';
import 'home_shell.dart';
import 'journal_entry_sheet.dart';
import 'period_editor_sheet.dart';
import 'symptom_entry_sheet.dart';

/// One day across all four areas.
class DayDetailPage extends StatelessWidget {
  const DayDetailPage({required this.date, super.key});

  final String date;

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final NutritionService nutrition = state.nutrition;
    final DayNutrition day = nutrition.day(date);
    final List<WeightEntry> weights = state.weight.entries
        .where((WeightEntry e) => e.date == date)
        .toList(growable: false);
    final List<PeriodRecord> periods = state.repository.periods
        .where((PeriodRecord p) =>
            p.startDate == date ||
            (p.endDate != null && !DateMath.before(date, p.endDate!) &&
                !DateMath.after(date, p.startDate)))
        .toList(growable: false);
    final List<SymptomEntry> symptoms = state.symptoms.entries
        .where((SymptomEntry e) => e.date == date)
        .toList(growable: false);
    final List<IntakeEntry> water = day.intakes
        .where((IntakeEntry e) => e.kind == IntakeKind.water)
        .toList(growable: false);
    final List<IntakeEntry> caffeine = day.intakes
        .where((IntakeEntry e) => e.kind == IntakeKind.caffeine)
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(
        title: Text(formatDay(context, date, withYear: true)),
        actions: <Widget>[
          IconButton(
            onPressed: () => _shift(context, -1),
            icon: const Icon(Icons.chevron_left),
            tooltip: l10n.t('common.yesterday'),
          ),
          IconButton(
            onPressed: () => _shift(context, 1),
            icon: const Icon(Icons.chevron_right),
            tooltip: l10n.t('common.tomorrow'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: <Widget>[
          SectionCard(
            title: l10n.t('day.nutrition'),
            trailing: IconButton(
              icon: const Icon(Icons.add),
              tooltip: l10n.t('common.add'),
              onPressed: () => FoodPickerSheet.show(context),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _metric(
                        context,
                        'kcal',
                        '${day.caloriesKcal.round()}',
                      ),
                    ),
                    Expanded(
                      child: _metric(
                        context,
                        l10n.nutrientLabel(Nutrients.protein),
                        '${day.proteinG.toStringAsFixed(1)} g',
                      ),
                    ),
                    Expanded(
                      child: _metric(
                        context,
                        l10n.nutrientLabel(Nutrients.carbohydrates),
                        '${day.carbohydratesG.toStringAsFixed(1)} g',
                      ),
                    ),
                    Expanded(
                      child: _metric(
                        context,
                        l10n.nutrientLabel(Nutrients.fat),
                        '${day.fatG.toStringAsFixed(1)} g',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (day.entries.isEmpty)
                  Text(
                    l10n.t('common.empty'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  )
                else
                  for (final JournalEntry entry in day.entries)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(entry.foodName),
                      subtitle: Text(
                        '${l10n.t('meal.${entry.meal.name}')} · '
                        '${nutrition.contributionOf(entry)[Nutrients.energyKcal].round()} kcal',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: <Widget>[
                          IconButton(
                            icon: const Icon(Icons.replay_outlined, size: 18),
                            tooltip: l10n.t('nutrition.log_again'),
                            onPressed: () {
                              final FoodItem? food =
                                  state.repository.foodById(entry.foodId);
                              if (food == null) return;
                              JournalEntrySheet.show(
                                context,
                                food: food,
                                template: entry,
                                initialDate: date,
                              );
                            },
                          ),
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            onPressed: () {
                              final FoodItem? food =
                                  state.repository.foodById(entry.foodId);
                              if (food == null) return;
                              JournalEntrySheet.show(
                                context,
                                food: food,
                                entry: entry,
                                initialDate: date,
                              );
                            },
                          ),
                        ],
                      ),
                    ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: l10n.t('day.water_caffeine'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                _metric(context, l10n.t('nutrition.water'),
                    '${day.waterMl.round()} ml'),
                _metric(context, l10n.t('nutrition.caffeine'),
                    '${day.caffeineMg.round()} mg'),
                for (final IntakeEntry entry in <IntakeEntry>[...water, ...caffeine])
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(
                      entry.kind == IntakeKind.water
                          ? '${entry.amount.round()} ml ${l10n.t('nutrition.water')}'
                          : '${entry.amount.round()} mg ${l10n.t('nutrition.caffeine')}',
                    ),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline, size: 18),
                      onPressed: () => state.deleteIntake(entry.id),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: l10n.t('day.weight'),
            child: weights.isEmpty
                ? Text(
                    l10n.t('common.empty'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  )
                : Column(
                    children: <Widget>[
                      for (final WeightEntry entry in weights)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: Text(
                            '${WeightService.toDisplay(entry.valueKg, state.settings.weightUnit).toStringAsFixed(1)} '
                            '${state.settings.weightUnit == WeightUnit.lb ? 'lb' : 'kg'}',
                          ),
                          subtitle: entry.note == null ? null : Text(entry.note!),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline, size: 18),
                            onPressed: () => state.deleteWeight(entry.id),
                          ),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: l10n.t('day.period'),
            trailing: IconButton(
              icon: const Icon(Icons.add),
              tooltip: l10n.t('common.add'),
              onPressed: () => PeriodEditorSheet.show(context),
            ),
            child: periods.isEmpty
                ? Text(
                    l10n.t('common.empty'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  )
                : Column(
                    children: <Widget>[
                      for (final PeriodRecord record in periods)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: Text(
                            record.spotting
                                ? l10n.t('cycle.spotting')
                                : l10n.t('cycle.periods'),
                          ),
                          subtitle: Text(
                            record.note ??
                                l10n.t('cycle.strength.${record.flow.name}'),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            onPressed: () =>
                                PeriodEditorSheet.show(context, record: record),
                          ),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: l10n.t('day.symptoms'),
            trailing: IconButton(
              icon: const Icon(Icons.add),
              tooltip: l10n.t('common.add'),
              onPressed: () => SymptomEntrySheet.show(context, initialDate: date),
            ),
            child: symptoms.isEmpty
                ? Text(
                    l10n.t('common.empty'),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  )
                : Column(
                    children: <Widget>[
                      for (final SymptomEntry entry in symptoms)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: Text(entry.name),
                          subtitle: Text('${entry.intensity}/10'),
                          trailing: IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            onPressed: () =>
                                SymptomEntrySheet.show(context, entry: entry),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _metric(BuildContext context, String label, String value) {
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
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  void _shift(BuildContext context, int delta) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (BuildContext context) =>
            DayDetailPage(date: DateMath.addDays(date, delta)),
      ),
    );
  }
}
