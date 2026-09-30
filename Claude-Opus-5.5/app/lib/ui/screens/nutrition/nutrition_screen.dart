import 'package:flutter/material.dart';

import '../../../core/model/dataset.dart';
import '../../../core/model/entries.dart';
import '../../../core/model/enums.dart';
import '../../../core/model/nutrients.dart';
import '../../../core/nutrition/nutrition.dart';
import '../../../core/util/local_date.dart';
import '../../controller.dart';
import '../../theme.dart';
import '../../widgets/charts.dart';
import '../../widgets/common.dart';
import '../../widgets/date_nav.dart';
import '../../widgets/inputs.dart';
import '../home_shell.dart';
import 'day_nutrients_screen.dart';
import 'food_search_screen.dart';
import 'intake_cards.dart';
import 'log_food_screen.dart';
import 'nutrient_list.dart';

/// Nutrition diary: day view and nutrient trends.
class NutritionScreen extends StatelessWidget {
  const NutritionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(s.navNutrition),
          actions: mainActions(context),
          bottom: TabBar(tabs: [Tab(text: s.dayTab), Tab(text: s.trendTab)]),
        ),
        body: const TabBarView(children: [_DayTab(), NutritionTrendTab()]),
      ),
    );
  }
}

Future<void> openFoodSearch(BuildContext context, LocalDate date, Meal? meal) {
  final app = context.appRead;
  final suggested = meal ??
      (date == app.today ? Meal.suggestFor(app.service.clock.minutesOfDay()) : Meal.lunch);
  return Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => FoodSearchScreen(date: date, meal: suggested)),
  );
}

class _DayTab extends StatelessWidget {
  const _DayTab();

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final date = app.selectedDate;
    final day = app.service.nutritionDay(date);
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 96),
      children: [
        DateNavigator(date: date, onChanged: app.selectDate),
        const SizedBox(height: 4),
        NutritionSummaryCard(day: day),
        const SizedBox(height: 12),
        for (final meal in Meal.values) ...[
          MealCard(day: day, meal: meal),
          const SizedBox(height: 12),
        ],
        WaterCard(date: date),
        const SizedBox(height: 12),
        CaffeineCard(date: date),
      ],
    );
  }
}

/// Day totals: calories and macronutrients with optional goals.
class NutritionSummaryCard extends StatelessWidget {
  const NutritionSummaryCard({
    super.key,
    required this.day,
    this.onTap,
    this.title,
    this.showAddFood = false,
  });

  final DayNutrition day;
  final VoidCallback? onTap;
  final String? title;

  /// Adds a direct "add food" action (used on the overview).
  final bool showAddFood;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final s = app.s;
    final fmt = app.fmt;
    final goals = app.settings.goals;
    final t = day.totals;
    Widget macro(String key, double? goal) {
      final n = Nutrients.byKey[key]!;
      final v = t.valueOrZero(key);
      return GoalProgress(
        label: s.nutrientName(key),
        valueText: fmt.nutrient(n, v),
        value: v,
        goal: goal,
        goalText: goal == null ? null : fmt.nutrient(n, goal),
      );
    }

    return SectionCard(
      title: title ?? s.dayTotal,
      icon: Icons.restaurant_outlined,
      iconColor: context.colors.nutrition,
      onTap: onTap,
      trailing: TextButton(
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => DayNutrientsScreen(date: day.date)),
        ),
        child: Text(s.allNutrients),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          macro('energy_kcal', goals.energyKcal),
          macro('protein_g', goals.proteinG),
          macro('carbohydrates_g', goals.carbohydratesG),
          macro('fat_g', goals.fatG),
          if (day.entries.isEmpty) EmptyHint(s.noFoodLogged),
          if (showAddFood)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                style: TextButton.styleFrom(padding: EdgeInsets.zero),
                onPressed: () => openFoodSearch(context, day.date, null),
                icon: const Icon(Icons.add),
                label: Text(s.addFood),
              ),
            ),
        ],
      ),
    );
  }
}

/// One meal with its entries.
class MealCard extends StatelessWidget {
  const MealCard({super.key, required this.day, required this.meal});

  final DayNutrition day;
  final Meal meal;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final s = app.s;
    final fmt = app.fmt;
    final entries = day.entriesFor(meal);
    final kcal = day.mealTotals[meal]![Nutrients.energy.key];
    return SectionCard(
      title: s.mealName(meal),
      icon: mealIcon(meal),
      iconColor: context.colors.nutrition,
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 8),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (kcal != null) Text('${fmt.integer(kcal)} kcal', style: context.text.labelLarge),
          IconButton(
            tooltip: s.addFoodTo(meal),
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => openFoodSearch(context, day.date, meal),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (entries.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                s.nothingLoggedMeal,
                style: context.text.bodyMedium?.copyWith(color: context.scheme.onSurfaceVariant),
              ),
            ),
          for (final e in entries) FoodEntryTile(entry: e),
        ],
      ),
    );
  }
}

/// Amount text of an entry, e.g. "150 g" or "1,5 Portionen (225 g)".
String entryAmountText(BuildContext context, FoodEntry e) {
  final s = context.s;
  final fmt = context.fmt;
  if (e.unit == AmountUnit.portion) {
    final q = e.quantity;
    final base = '${fmt.number(e.amount, 2)} ${s.unitName(AmountUnit.portion, plural: e.amount != 1)}';
    return q == null ? base : '$base (${fmt.number(q, 1)} ${e.food.basis.json})';
  }
  return '${fmt.number(e.amount, 1)} ${e.unit.json}';
}

class FoodEntryTile extends StatelessWidget {
  const FoodEntryTile({super.key, required this.entry, this.showDate = false});

  final FoodEntry entry;
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final fmt = context.fmt;
    final e = entry;
    final subtitle = [
      entryAmountText(context, e),
      if (e.time != null) fmt.time(e.time!),
      if (showDate) fmt.dayMonth(e.date),
    ].join(' · ');
    return ListTile(
      contentPadding: const EdgeInsets.only(left: 0, right: 0),
      title: Text(e.food.brand == null ? e.food.name : '${e.food.name} · ${e.food.brand}'),
      subtitle: Text('$subtitle\n${macroLine(context, e.nutrient)}'),
      isThreeLine: true,
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => LogFoodScreen.edit(entry: e)),
      ),
      trailing: PopupMenuButton<String>(
        tooltip: s.more,
        onSelected: (action) async {
          switch (action) {
            case 'again':
              await relogWithDialog(context, e);
            case 'delete':
              await deleteWithUndo(context, Collection.foodEntries, e);
          }
        },
        itemBuilder: (_) => [
          PopupMenuItem(value: 'again', child: Text(s.logAgain)),
          PopupMenuItem(value: 'delete', child: Text(s.delete)),
        ],
      ),
    );
  }
}

/// "Erneut erfassen": copies an entry to a chosen day, meal and time.
Future<void> relogWithDialog(BuildContext context, FoodEntry entry) async {
  final app = context.appRead;
  final result = await showDialog<(LocalDate, Meal, int?)>(
    context: context,
    builder: (_) => _RelogDialog(entry: entry),
  );
  if (result == null) return;
  await app.run(() async {
    await app.service.relogEntry(entry, date: result.$1, meal: result.$2, time: result.$3);
    app.showMessage(app.s.loggedAgain(app.fmt.weekdayDayMonth(result.$1)));
  });
}

class _RelogDialog extends StatefulWidget {
  const _RelogDialog({required this.entry});
  final FoodEntry entry;

  @override
  State<_RelogDialog> createState() => _RelogDialogState();
}

class _RelogDialogState extends State<_RelogDialog> {
  late LocalDate _date;
  late Meal _meal;
  late int? _time;

  @override
  void initState() {
    super.initState();
    final app = context.appRead;
    _date = app.today;
    _time = app.service.clock.minutesOfDay();
    _meal = widget.entry.meal;
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return AlertDialog(
      title: Text(s.logAgainTitle),
      scrollable: true,
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${widget.entry.food.name} · ${entryAmountText(context, widget.entry)}'),
          const SizedBox(height: 16),
          DateField(date: _date, onChanged: (d) => setState(() => _date = d)),
          const SizedBox(height: 12),
          TimeField(minutes: _time, onChanged: (t) => setState(() => _time = t)),
          const SizedBox(height: 12),
          DropdownButtonFormField<Meal>(
            initialValue: _meal,
            isExpanded: true,
            decoration: InputDecoration(labelText: s.meal),
            items: [
              for (final m in Meal.values) DropdownMenuItem(value: m, child: Text(s.mealName(m))),
            ],
            onChanged: (m) => setState(() => _meal = m ?? _meal),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(s.cancel)),
        FilledButton(
          onPressed: () => Navigator.pop(context, (_date, _meal, _time)),
          child: Text(s.add),
        ),
      ],
    );
  }
}

/// Selectable nutrient trend over 7 or 28 days.
class NutritionTrendTab extends StatefulWidget {
  const NutritionTrendTab({super.key});

  @override
  State<NutritionTrendTab> createState() => _NutritionTrendTabState();
}

class _NutritionTrendTabState extends State<NutritionTrendTab> {
  String _metric = Nutrients.energy.key;
  int _days = 7;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final s = app.s;
    final fmt = app.fmt;
    final end = app.selectedDate;
    final series = app.service.nutritionTrend(_metric, end, _days);
    final unit = TrendMetric.unitOf(_metric);
    final nutrient = Nutrients.byKey[_metric];
    String format(double v) => nutrient != null
        ? fmt.nutrient(nutrient, v)
        : '${fmt.integer(v)} $unit';
    final points = [
      for (var i = 0; i < series.days.length; i++)
        ChartPoint(
          label: _days == 7
              ? fmt.weekdayShort(series.days[i].weekday)
              : fmt.dayOfMonth(series.days[i]),
          fullLabel: fmt.weekdayDayMonth(series.days[i]),
          value: series.values[i],
        ),
    ];
    final avg = series.average;
    final summary = [
      '${s.nutrientName(_metric)}, ${s.days(_days)}',
      if (avg != null) '${s.average} ${format(avg)}',
      s.daysWithData(series.daysWithData, _days),
      if (series.goal != null) '${s.goal} ${format(series.goal!)}',
    ].join(', ');
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: [
        DateNavigator(date: end, onChanged: app.selectDate),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          initialValue: _metric,
          isExpanded: true,
          decoration: InputDecoration(labelText: s.trendMetric),
          items: [
            for (final key in TrendMetric.all)
              DropdownMenuItem(value: key, child: Text(s.nutrientName(key))),
          ],
          onChanged: (v) => setState(() => _metric = v ?? _metric),
        ),
        const SizedBox(height: 12),
        SegmentedButton<int>(
          segments: [
            ButtonSegment(value: 7, label: Text(s.days(7))),
            ButtonSegment(value: 28, label: Text(s.days(28))),
          ],
          selected: {_days},
          onSelectionChanged: (v) => setState(() => _days = v.first),
        ),
        const SizedBox(height: 16),
        Card(
          semanticContainer: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (series.daysWithData == 0)
                  EmptyHint(s.noDataInRange, icon: Icons.insights_outlined)
                else
                  ChartWithTable(
                    points: points,
                    formatValue: format,
                    showTableLabel: s.showTable,
                    showChartLabel: s.showChart,
                    emptyLabel: '–',
                    chart: TrendChart(
                      points: points,
                      semanticSummary: summary,
                      formatValue: (v) => fmt.number(v, v < 10 ? 1 : 0),
                      goal: series.goal,
                      color: _metric == TrendMetric.water
                          ? context.colors.water
                          : context.colors.nutrition,
                    ),
                  ),
                const Divider(),
                _Stat(label: s.average, hint: s.averageHint, value: avg == null ? '–' : format(avg)),
                _Stat(label: s.minimum, value: series.minimum == null ? '–' : format(series.minimum!)),
                _Stat(label: s.maximum, value: series.maximum == null ? '–' : format(series.maximum!)),
                if (series.goal != null) _Stat(label: s.goal, value: format(series.goal!)),
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    s.daysWithData(series.daysWithData, _days),
                    style: context.text.bodySmall?.copyWith(color: context.scheme.onSurfaceVariant),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.hint});

  final String label;
  final String value;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label),
                  if (hint != null)
                    Text(
                      hint!,
                      style: context.text.bodySmall?.copyWith(color: context.scheme.onSurfaceVariant),
                    ),
                ],
              ),
            ),
            Text(value, style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
