import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/cycle.dart';
import '../core/nutrition.dart';
import '../core/utils.dart';
import 'charts.dart';
import 'controller.dart';
import 'cycle_ui.dart';
import 'l10n.dart';
import 'nutrition_ui.dart';
import 'tracking_ui.dart';
import 'widgets.dart';

class OverviewPage extends StatelessWidget {
  const OverviewPage({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = l10n(context);
    final controller = context.watch<AppController>();
    final state = controller.state;
    final settings = state.settings;
    final day = controller.repository.nutritionDay(controller.selectedDate);
    final forecast = forecastCycle(state.periods, controller.selectedDate);
    final weights = state.weights
        .where((entry) => entry.date == controller.selectedDate)
        .toList();
    final symptoms = state.symptoms
        .where(
          (entry) =>
              instantDateKey(entry.occurredAt) == controller.selectedDate,
        )
        .toList();
    final anyVisible =
        settings.showNutrition ||
        settings.showCycle ||
        settings.showWeight ||
        settings.showSymptoms;
    return Scaffold(
      appBar: AppBar(
        title: Text(strings.t('app_title')),
        actions: [
          IconButton(
            tooltip: strings.t('today'),
            onPressed: () =>
                controller.selectDate(instantDateKey(controller.now)),
            icon: const Icon(Icons.today_outlined),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          DateSelector(
            date: controller.selectedDate,
            onChanged: controller.selectDate,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.tonalIcon(
                    key: const ValueKey('open-day-detail'),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute<void>(
                        builder: (_) =>
                            DayDetailPage(date: controller.selectedDate),
                      ),
                    ),
                    icon: const Icon(Icons.view_day_outlined),
                    label: Text(strings.t('open_day')),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filledTonal(
                  tooltip: strings.t('trends'),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) =>
                          TrendsPage(endDate: controller.selectedDate),
                    ),
                  ),
                  icon: const Icon(Icons.show_chart),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          if (!anyVisible) EmptyState(text: strings.t('all_areas_hidden')),
          if (settings.showNutrition)
            AppCard(
              title: strings.t('nutrition'),
              subtitle: strings.t('nutrition_overview_subtitle'),
              icon: Icons.restaurant_menu_outlined,
              trailing: IconButton(
                tooltip: strings.t('nutrition'),
                onPressed: () => controller.navigate(1),
                icon: const Icon(Icons.arrow_forward),
              ),
              onTap: () => _openDay(context, controller.selectedDate),
              children: [
                Text(
                  '${strings.amount(day.total(Nutrient.calories), 'kcal')} · '
                  '${strings.amount(day.waterMl, 'ml')}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                Text(
                  '${strings.nutrient(Nutrient.protein)} ${strings.amount(day.total(Nutrient.protein), 'g')} · '
                  '${strings.nutrient(Nutrient.carbs)} ${strings.amount(day.total(Nutrient.carbs), 'g')} · '
                  '${strings.nutrient(Nutrient.fat)} ${strings.amount(day.total(Nutrient.fat), 'g')}',
                ),
              ],
            ),
          if (settings.showCycle)
            AppCard(
              title: strings.t('cycle'),
              subtitle: strings.t('cycle_overview_subtitle'),
              icon: Icons.calendar_month_outlined,
              trailing: IconButton(
                tooltip: strings.t('cycle'),
                onPressed: () => controller.navigate(2),
                icon: const Icon(Icons.arrow_forward),
              ),
              onTap: () => _openDay(context, controller.selectedDate),
              children: [
                Text(
                  !settings.cycleForecastEnabled
                      ? strings.t('forecast_off')
                      : forecast.available
                      ? '${strings.t('estimated_next')}: ${strings.date(forecast.predictedStart!)}'
                      : strings.t('no_forecast'),
                ),
              ],
            ),
          if (settings.showWeight)
            AppCard(
              title: strings.t('weight'),
              subtitle: strings.t('weight_overview_subtitle'),
              icon: Icons.monitor_weight_outlined,
              trailing: IconButton(
                tooltip: strings.t('weight_history'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => const WeightPage()),
                ),
                icon: const Icon(Icons.arrow_forward),
              ),
              onTap: () => _openDay(context, controller.selectedDate),
              children: [
                if (weights.isEmpty)
                  Text(strings.t('no_weight'))
                else
                  for (final entry in weights)
                    Text(
                      settings.weightUnit == 'lb'
                          ? strings.amount(entry.pounds, 'lb')
                          : strings.amount(entry.kg, 'kg'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
              ],
            ),
          if (settings.showSymptoms)
            AppCard(
              title: strings.t('symptoms'),
              subtitle: strings.t('symptoms_overview_subtitle'),
              icon: Icons.favorite_outline,
              trailing: IconButton(
                tooltip: strings.t('symptom_history'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => const SymptomsPage()),
                ),
                icon: const Icon(Icons.arrow_forward),
              ),
              onTap: () => _openDay(context, controller.selectedDate),
              children: [
                Text(strings.t('results_count', {'count': symptoms.length})),
                if (symptoms.isNotEmpty)
                  Text(
                    symptoms
                        .map((entry) => '${entry.name} ${entry.intensity}/10')
                        .join(' · '),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  static void _openDay(BuildContext context, String date) {
    Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => DayDetailPage(date: date)),
    );
  }
}

class DayDetailPage extends StatefulWidget {
  const DayDetailPage({super.key, required this.date});
  final String date;

  @override
  State<DayDetailPage> createState() => _DayDetailPageState();
}

class _DayDetailPageState extends State<DayDetailPage> {
  late String date = widget.date;

  @override
  Widget build(BuildContext context) {
    final strings = l10n(context);
    final controller = context.watch<AppController>();
    final state = controller.state;
    final nutrition = controller.repository.nutritionDay(date);
    final weights = state.weights.where((entry) => entry.date == date).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    final symptoms =
        state.symptoms
            .where((entry) => instantDateKey(entry.occurredAt) == date)
            .toList()
          ..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
    final today = instantDateKey(controller.now);
    final periods = state.periods
        .where((period) => period.contains(date, today))
        .toList();
    final localNow = controller.now.toLocal();
    final selected = parseDate(date);
    final initialTime = DateTime(
      selected.year,
      selected.month,
      selected.day,
      localNow.hour,
      localNow.minute,
    );
    return Scaffold(
      appBar: AppBar(title: Text(strings.t('open_day'))),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          DateSelector(
            date: date,
            onChanged: (value) {
              setState(() => date = value);
              controller.selectDate(value);
            },
          ),
          AppCard(
            title: strings.t('nutrition'),
            icon: Icons.restaurant_outlined,
            trailing: IconButton(
              tooltip: strings.t('add_intake'),
              onPressed: () {
                controller.selectDate(date);
                controller.navigate(1);
                Navigator.pop(context);
              },
              icon: const Icon(Icons.add),
            ),
            children: [
              Text(
                '${strings.amount(nutrition.total(Nutrient.calories), 'kcal')} · '
                '${strings.amount(nutrition.waterMl, 'ml')} ${strings.t('water').toLowerCase()}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (nutrition.entries.isEmpty) Text(strings.t('no_entries')),
              for (final entry in nutrition.entries) IntakeTile(entry: entry),
            ],
          ),
          AppCard(
            title: strings.t('weight'),
            icon: Icons.monitor_weight_outlined,
            trailing: IconButton(
              tooltip: strings.t('add_weight'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => WeightEditPage(initialDate: date),
                ),
              ),
              icon: const Icon(Icons.add),
            ),
            children: [
              if (weights.isEmpty) Text(strings.t('no_weight')),
              for (final entry in weights)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    state.settings.weightUnit == 'lb'
                        ? strings.amount(entry.pounds, 'lb')
                        : strings.amount(entry.kg, 'kg'),
                  ),
                  subtitle: entry.notes.isEmpty ? null : Text(entry.notes),
                  trailing: const Icon(Icons.edit_outlined),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => WeightEditPage(existing: entry),
                    ),
                  ),
                ),
            ],
          ),
          AppCard(
            title: strings.t('period'),
            icon: Icons.water_drop_outlined,
            trailing: IconButton(
              tooltip: strings.t('add_period'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => PeriodEditPage(initialDate: date),
                ),
              ),
              icon: const Icon(Icons.add),
            ),
            children: [
              if (periods.isEmpty) Text(strings.t('no_entries')),
              for (final period in periods)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    '${strings.date(period.start)} – '
                    '${period.end == null ? strings.t('end_open') : strings.date(period.end!)}',
                  ),
                  subtitle: Text(
                    '${strings.flow(period.flow)}'
                    '${period.notes.isEmpty ? '' : '\n${period.notes}'}',
                  ),
                  trailing: const Icon(Icons.edit_outlined),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => PeriodEditPage(existing: period),
                    ),
                  ),
                ),
            ],
          ),
          AppCard(
            title: strings.t('symptoms'),
            icon: Icons.favorite_outline,
            trailing: IconButton(
              tooltip: strings.t('add_symptom'),
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => SymptomEditPage(initialTime: initialTime),
                ),
              ),
              icon: const Icon(Icons.add),
            ),
            children: [
              if (symptoms.isEmpty) Text(strings.t('no_symptoms')),
              for (final symptom in symptoms)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(symptom.name),
                  subtitle: Text(
                    '${strings.time(symptom.occurredAt)} · '
                    '${strings.t('intensity_value', {'value': symptom.intensity})}'
                    '${symptom.notes.isEmpty ? '' : '\n${symptom.notes}'}',
                  ),
                  trailing: const Icon(Icons.edit_outlined),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => SymptomEditPage(existing: symptom),
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

class TrendsPage extends StatelessWidget {
  const TrendsPage({super.key, required this.endDate});
  final String endDate;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(l10n(context).t('trends'))),
    body: ListView(children: [NutrientTrends(endDate: endDate)]),
  );
}
