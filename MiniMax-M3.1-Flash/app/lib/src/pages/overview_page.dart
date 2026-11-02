import 'package:flutter/material.dart';
import 'package:morphhealth_core/morphhealth_core.dart';

import '../l10n/app_localizations.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import 'day_detail_page.dart';
import 'home_shell.dart';
import 'symptom_page.dart';
import 'weight_page.dart';

/// Overview of the areas the user chose to see.
class OverviewPage extends StatelessWidget {
  const OverviewPage({required this.onOpenTab, super.key});

  /// Jumps to one of the tabs of the main navigation.
  final void Function(int index) onOpenTab;

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final AppLocalizations l10n = context.l10n;
    final DateTime now = DateTime.now();
    final String today = DateMath.format(now);

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('app.name')),
        actions: <Widget>[
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                relativeDayLabel(context, today),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
        children: <Widget>[
          if (state.visibleAreas.contains(AppArea.nutrition))
            _NutritionCard(today: today, onTap: () => onOpenTab(1)),
          if (state.visibleAreas.contains(AppArea.cycle))
            _CycleCard(today: today, onTap: () => onOpenTab(2)),
          if (state.visibleAreas.contains(AppArea.weight))
            _WeightCard(onTap: () => _open(context, const WeightPage())),
          if (state.visibleAreas.contains(AppArea.symptoms))
            _SymptomCard(onTap: () => _open(context, const SymptomPage())),
          const SizedBox(height: 4),
          SectionCard(
            title: l10n.t('overview.day_detail'),
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.today_outlined),
              title: Text(formatDay(context, today, withYear: true)),
              subtitle: Text(l10n.t('overview.open_day')),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _open(context, DayDetailPage(date: today)),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            l10n.t('app.tagline'),
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }

  static void _open(BuildContext context, Widget page) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (BuildContext context) => page),
    );
  }
}

class _NutritionCard extends StatelessWidget {
  const _NutritionCard({required this.today, required this.onTap});

  final String today;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final AppLocalizations l10n = context.l10n;
    final DayNutrition day = state.nutrition.day(today);
    final Goals goals = state.goals;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SectionCard(
        title: l10n.t('area.nutrition'),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: _Metric(
                    label: l10n.t('overview.calories_today'),
                    value: '${day.caloriesKcal.round()}',
                    unit: 'kcal',
                  ),
                ),
                Expanded(
                  child: _Metric(
                    label: l10n.t('overview.water_today'),
                    value: '${day.waterMl.round()}',
                    unit: 'ml',
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
            if (goals.waterMl != null) ...<Widget>[
              GoalBar(
                label: l10n.t('nutrition.goal_water'),
                value: day.waterMl,
                goal: goals.waterMl!,
                unit: 'ml',
              ),
            ],
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(
                  child: _MiniMacro(
                    label: l10n.nutrientLabel(Nutrients.protein),
                    value: day.proteinG,
                    goal: goals.proteinG,
                  ),
                ),
                Expanded(
                  child: _MiniMacro(
                    label: l10n.nutrientLabel(Nutrients.carbohydrates),
                    value: day.carbohydratesG,
                    goal: goals.carbohydratesG,
                  ),
                ),
                Expanded(
                  child: _MiniMacro(
                    label: l10n.nutrientLabel(Nutrients.fat),
                    value: day.fatG,
                    goal: goals.fatG,
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

class _CycleCard extends StatelessWidget {
  const _CycleCard({required this.today, required this.onTap});

  final String today;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final AppLocalizations l10n = context.l10n;
    final CycleForecast forecast = state.cycle.forecast(today);

    String headline;
    if (!forecast.hasData) {
      headline = l10n.t('cycle.before_first');
    } else if (forecast.cycleDay != null) {
      headline = l10n.t(
        'cycle.cycle_day',
        <String, String>{'day': '${forecast.cycleDay}'},
      );
    } else {
      headline = l10n.t('cycle.only_one');
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SectionCard(
        title: l10n.t('area.cycle'),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
        subtitle: l10n.t('cycle.forecast_hint'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              headline,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            if (forecast.predictedNextStart != null) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                '${l10n.t('cycle.next_start')}: '
                '${formatDay(context, forecast.predictedNextStart!, withYear: true)}',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
            if (forecast.explanation.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Text(
                forecast.explanation.first,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _WeightCard extends StatelessWidget {
  const _WeightCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final AppLocalizations l10n = context.l10n;
    final WeightEntry? latest = state.weight.latest;
    final double? change = state.weight.latestChange;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SectionCard(
        title: l10n.t('area.weight'),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
        child: Row(
          children: <Widget>[
            Expanded(
              child: _Metric(
                label: l10n.t('weight.latest'),
                value: latest == null
                    ? '–'
                    : WeightService.toDisplay(
                          latest.valueKg,
                          state.settings.weightUnit,
                        ).toStringAsFixed(1),
                unit: state.settings.weightUnit == WeightUnit.lb ? 'lb' : 'kg',
              ),
            ),
            if (change != null)
              Expanded(
                child: _Metric(
                  label: l10n.t('weight.change'),
                  value: WeightService.toDisplay(
                        change,
                        state.settings.weightUnit,
                      ).toStringAsFixed(1),
                  unit: state.settings.weightUnit == WeightUnit.lb ? 'lb' : 'kg',
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SymptomCard extends StatelessWidget {
  const _SymptomCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final AppLocalizations l10n = context.l10n;
    final List<SymptomEntry> recent = state.symptoms.entries.reversed.take(3).toList();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SectionCard(
        title: l10n.t('area.symptoms'),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
        child: recent.isEmpty
            ? EmptyState(message: l10n.t('symptom.empty'))
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  for (final SymptomEntry entry in recent)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              entry.name,
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                          Text(
                            '${entry.intensity}/10',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            relativeDayLabel(context, entry.date),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
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

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.unit});

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

class _MiniMacro extends StatelessWidget {
  const _MiniMacro({required this.label, required this.value, this.goal});

  final String label;
  final double value;
  final double? goal;

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
        Text(
          '${value.toStringAsFixed(1)} g',
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
