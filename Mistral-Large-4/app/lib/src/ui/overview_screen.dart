// Übersichtsseite: die vom Nutzer sichtbaren Bereiche als Karten.
library;

import 'package:flutter/material.dart';

import '../core/parse.dart';
import '../cycle/forecast.dart';
import '../data/repository.dart';
import '../l10n/app_strings.dart';
import '../model/cycle.dart';
import '../nutrition/day.dart';
import 'day_detail_screen.dart';
import 'history_screen.dart';
import 'scope.dart';
import 'settings_screen.dart';
import 'trends_screen.dart';
import 'widgets.dart';

class OverviewScreen extends StatelessWidget {
  /// Öffnet einen Bereich in der Bottom-Navigation der Home-Shell.
  final void Function(String area) onOpenArea;

  const OverviewScreen({super.key, required this.onOpenArea});

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = StringsScope.of(context);
    final MorphRepository repo = MorphScope.repoOf(context);
    return ListenableBuilder(
      listenable: MorphScope.listenableOf(context),
      builder: (BuildContext context, Widget? _) {
        final String today = todayString();
        final List<String> areas = repo.settings.visibleAreas;
        final DayNutrition day = computeDayNutrition(repo.document, today);
        final CycleForecast forecast =
            computeCycleForecast(repo.document, today);
        return ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 24),
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
              child: Text(strings.todaySection,
                  style: Theme.of(context).textTheme.headlineSmall),
            ),
            if (areas.contains('nutrition'))
              _NutritionCard(day: day, onTap: () => onOpenArea('nutrition')),
            if (areas.contains('cycle'))
              _CycleCard(forecast: forecast, onTap: () => onOpenArea('cycle')),
            if (areas.contains('weight'))
              _WeightCard(onTap: () => onOpenArea('weight')),
            if (areas.contains('symptoms'))
              _SymptomsCard(today: today, onTap: () => onOpenArea('symptoms')),
            if (areas.isEmpty)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Text(strings.noDataYet),
              ),
            const SizedBox(height: 8),
            _ActionButtons(today: today),
          ],
        );
      },
    );
  }
}

class _ActionButtons extends StatelessWidget {
  final String today;
  const _ActionButtons({required this.today});

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = StringsScope.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: <Widget>[
          FilledButton.tonalIcon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<Widget>(
                builder: (_) => DayDetailScreen(date: today))),
            icon: const Icon(Icons.article_outlined),
            label: Text(strings.openDayDetail),
          ),
          FilledButton.tonalIcon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<Widget>(
                builder: (_) => const TrendsScreen())),
            icon: const Icon(Icons.trending_up),
            label: Text(strings.openTrends),
          ),
          FilledButton.tonalIcon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<Widget>(
                builder: (_) => const HistoryScreen())),
            icon: const Icon(Icons.search),
            label: Text(strings.openHistory),
          ),
          FilledButton.tonalIcon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute<Widget>(
                builder: (_) => const SettingsScreen())),
            icon: const Icon(Icons.settings_outlined),
            label: Text(strings.openSettings),
          ),
        ],
      ),
    );
  }
}

class _NutritionCard extends StatelessWidget {
  final DayNutrition day;
  final VoidCallback onTap;
  const _NutritionCard({required this.day, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = StringsScope.of(context);
    final MorphRepository repo = MorphScope.repoOf(context);
    final double kcal = day.totals['energy_kcal'] ?? 0;
    return _OverviewCard(
      title: strings.nutritionCardTitle,
      icon: Icons.restaurant_outlined,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          StatRow(
              label: strings.nutrientName('energy_kcal'),
              value: strings.nutrientAmount('energy_kcal', kcal)),
          StatRow(
              label: strings.nutrientName('protein_g'),
              value: strings.nutrientAmount(
                  'protein_g', day.totals['protein_g'] ?? 0)),
          StatRow(
              label: strings.nutrientName('carbohydrates_g'),
              value: strings.nutrientAmount(
                  'carbohydrates_g', day.totals['carbohydrates_g'] ?? 0)),
          StatRow(
              label: strings.nutrientName('fat_g'),
              value: strings.nutrientAmount('fat_g', day.totals['fat_g'] ?? 0)),
          StatRow(
              label: strings.waterLabel,
              value:
                  '${strings.formatMl(day.waterMl)}${_goalSuffix(strings, repo, day)}'),
          StatRow(
              label: strings.caffeineLabel,
              value: strings.formatMg(day.caffeineTotalMg)),
          Text(strings.entriesCount(day.entryCount),
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  static String _goalSuffix(
      AppStrings strings, MorphRepository repo, DayNutrition day) {
    final double? p = day.waterPercentOfGoal(repo.settings.goals);
    if (p == null) return '';
    return ' · ${strings.percentOfGoal(p)}';
  }
}

class _CycleCard extends StatelessWidget {
  final CycleForecast forecast;
  final VoidCallback onTap;
  const _CycleCard({required this.forecast, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = StringsScope.of(context);
    final List<Widget> rows = <Widget>[];
    if (forecast.currentCycleDay != null) {
      rows.add(StatRow(
          label: strings.cycleDayLabel(forecast.currentCycleDay!),
          value: forecast.lastPeriodStart ?? ''));
    }
    if (forecast.nextPeriodStartEstimate != null) {
      rows.add(StatRow(
          label: strings.nextPeriodLabel,
          value: strings.formatDateShort(
              parseDate(forecast.nextPeriodStartEstimate!)!)));
    }
    if (rows.isEmpty) {
      rows.add(Text(strings.noPeriods));
    }
    return _OverviewCard(
      title: strings.cycleCardTitle,
      icon: Icons.calendar_month_outlined,
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: rows,
      ),
    );
  }
}

class _WeightCard extends StatelessWidget {
  final VoidCallback onTap;
  const _WeightCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = StringsScope.of(context);
    final MorphRepository repo = MorphScope.repoOf(context);
    final WeightEntry? latest = repo.latestWeightEntry();
    return _OverviewCard(
      title: strings.weightCardTitle,
      icon: Icons.monitor_weight_outlined,
      onTap: onTap,
      child: latest == null
          ? Text(strings.noWeights)
          : StatRow(
              label: strings.latestWeight,
              value:
                  '${strings.formatWeight(latest.weightKg, repo.settings.weightUnit)} · ${strings.formatDateShort(parseDate(latest.date)!)}',
            ),
    );
  }
}

class _SymptomsCard extends StatelessWidget {
  final String today;
  final VoidCallback onTap;
  const _SymptomsCard({required this.today, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = StringsScope.of(context);
    final MorphRepository repo = MorphScope.repoOf(context);
    final List<SymptomEntry> entries = repo.symptomEntriesForDate(today);
    return _OverviewCard(
      title: strings.symptomsCardTitle,
      icon: Icons.healing_outlined,
      onTap: onTap,
      child: entries.isEmpty
          ? Text(strings.noSymptoms)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                for (final SymptomEntry e in entries)
                  StatRow(
                      label: e.name,
                      value: strings.intensityValue(e.intensity)),
              ],
            ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final VoidCallback onTap;

  const _OverviewCard({
    required this.title,
    required this.icon,
    required this.child,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(icon, size: 20,
                      color: Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(title,
                        style: Theme.of(context).textTheme.titleMedium),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              const SizedBox(height: 8),
              child,
            ],
          ),
        ),
      ),
    );
  }
}
