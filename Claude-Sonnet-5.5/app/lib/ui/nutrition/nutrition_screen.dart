import 'package:flutter/material.dart';

import '../../core/ids.dart';
import '../../core/models.dart';
import '../../core/nutrients.dart';
import '../../core/nutrition.dart';
import '../../state/app_state.dart';
import '../history/history_screen.dart';
import '../l10n_x.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'food_entry_screen.dart';
import 'food_picker_screen.dart';
import 'nutrient_table.dart';
import 'trend_card.dart';
import 'water_caffeine.dart';

/// Bereich "Ernährung": Tagebuch des gewählten Tages und Verlauf.
class NutritionScreen extends StatelessWidget {
  const NutritionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l.navNutrition),
          actions: [
            IconButton(
              tooltip: l.historyTitle,
              icon: const Icon(Icons.search),
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const HistoryScreen(initialAreas: {Area.nutrition}))),
            ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(text: l.nutritionTabDiary),
              Tab(text: l.nutritionTabTrends),
            ],
          ),
        ),
        body: const TabBarView(children: [DiaryTab(), TrendsTab()]),
      ),
    );
  }
}

/// Öffnet die Lebensmittelauswahl für [meal] am gewählten Tag.
Future<void> openFoodPicker(BuildContext context, {Meal? meal}) async {
  final app = AppScope.read(context);
  await Navigator.of(context).push<bool>(
    MaterialPageRoute(
      builder: (_) => FoodPickerScreen(meal: meal, day: app.selectedDay),
    ),
  );
}

class DiaryTab extends StatelessWidget {
  const DiaryTab({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final l = context.l10n;
    final day = app.selectedDay;
    final data = app.core.nutritionDay(day);
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => openFoodPicker(context),
        icon: const Icon(Icons.add),
        label: Text(l.nutritionAddFood),
      ),
      body: ListView(
        key: const PageStorageKey('diary'),
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 96),
        children: [
          DayNavigator(day: day, today: app.today, onChanged: app.selectDay),
          const SizedBox(height: 8),
          DaySummaryCard(data: data),
          const SizedBox(height: 12),
          WaterCard(data: data),
          const SizedBox(height: 12),
          for (final m in data.meals) ...[MealSection(summary: m), const SizedBox(height: 12)],
          CaffeineCard(data: data),
        ],
      ),
    );
  }
}

/// Tagessumme: Kalorien, Makronährstoffe und Fortschritt zu Zielen.
class DaySummaryCard extends StatelessWidget {
  final DayNutrition data;

  const DaySummaryCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final f = context.fmt;
    final color = areaColor(Area.nutrition, context.theme.brightness);
    final kcal = data.totals.get0(kEnergy);
    final goal = data.goals.energyKcal;
    String status;
    if (goal == null) {
      status = l.nutritionKcalPlain(f.n(kcal));
    } else {
      status = l.nutritionKcalOfGoal(f.n(kcal), f.n(goal));
    }
    String? remaining;
    if (goal != null) {
      final diff = goal - kcal;
      remaining = diff.round() == 0
          ? l.nutritionGoalReached
          : diff > 0
          ? l.nutritionKcalLeft(f.n(diff))
          : l.nutritionKcalOver(f.n(-diff));
    }
    final hasAny = data.entries.isNotEmpty;
    return SectionCard(
      title: l.nutritionDaySummary,
      icon: Icons.local_fire_department_outlined,
      accent: color,
      trailing: hasAny
          ? TextButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => NutrientsScreen(
                    title: l.nutrientsTitle,
                    subtitle: f.dateLong(data.day),
                    values: data.totals,
                    coverage: data.entriesWithData,
                    entryCount: data.entries.length,
                  ),
                ),
              ),
              child: Text(l.nutritionAllNutrients),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            label: status,
            excludeSemantics: true,
            child: Text(status, style: context.text.headlineSmall?.copyWith(fontWeight: FontWeight.w600)),
          ),
          if (remaining != null) Text(remaining, style: context.text.bodyMedium),
          if (goal != null) ...[
            const SizedBox(height: 8),
            // Der Balken wiederholt nur die Angabe darüber und bleibt für Screenreader stumm.
            ExcludeSemantics(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: (kcal / goal).clamp(0.0, 1.0),
                  minHeight: 8,
                  color: color,
                  backgroundColor: context.colors.surfaceContainerHighest,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          for (final k in [kProtein, kCarbs, kFat]) ...[
            _MacroRow(nutrientKey: k, value: data.totals.get0(k), goal: data.goals.forNutrient(k), color: color),
            const SizedBox(height: 8),
          ],
          if (!hasAny) EmptyHint(l.nutritionDayEmpty, icon: Icons.restaurant_outlined),
        ],
      ),
    );
  }
}

class _MacroRow extends StatelessWidget {
  final String nutrientKey;
  final double value;
  final double? goal;
  final Color color;

  const _MacroRow({required this.nutrientKey, required this.value, required this.goal, required this.color});

  @override
  Widget build(BuildContext context) {
    final f = context.fmt;
    final def = nutrientByKey[nutrientKey]!;
    final name = nutrientName(nutrientKey, f.lang);
    final valueText = goal == null
        ? f.nutrient(value, def)
        : '${f.n(value, def.decimals)} / ${f.nTrim(goal!, 1)} ${def.unit}';
    return ProgressRow(
      label: name,
      valueText: valueText,
      fraction: goal == null ? null : value / goal!,
      color: color,
      semanticsValue: valueText,
    );
  }
}

/// Eine Mahlzeit mit ihren Einträgen.
class MealSection extends StatelessWidget {
  final MealSummary summary;

  const MealSection({super.key, required this.summary});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final l = context.l10n;
    final f = context.fmt;
    final color = areaColor(Area.nutrition, context.theme.brightness);
    final kcal = summary.totals.get0(kEnergy);
    return SectionCard(
      title: l.meal(summary.meal),
      icon: switch (summary.meal) {
        Meal.breakfast => Icons.free_breakfast_outlined,
        Meal.lunch => Icons.lunch_dining_outlined,
        Meal.dinner => Icons.dinner_dining_outlined,
        Meal.snack => Icons.cookie_outlined,
      },
      accent: color,
      padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (summary.entries.isNotEmpty) Text(f.kcal(kcal), style: context.text.titleSmall),
          IconButton(
            tooltip: l.nutritionAddToMeal(l.meal(summary.meal)),
            icon: const Icon(Icons.add_circle_outline),
            onPressed: () => openFoodPicker(context, meal: summary.meal),
          ),
        ],
      ),
      child: summary.entries.isEmpty
          ? Padding(padding: const EdgeInsets.only(right: 8), child: EmptyHint(l.nutritionMealEmpty))
          : Column(
              children: [for (final e in summary.entries) EntryTile(entry: e, app: app)],
            ),
    );
  }
}

/// Zeile für einen Verzehreintrag mit Menü (bearbeiten, erneut erfassen, löschen).
class EntryTile extends StatelessWidget {
  final FoodEntry entry;
  final AppState app;
  final bool showDate;

  const EntryTile({super.key, required this.entry, required this.app, this.showDate = false});

  Future<void> _edit(BuildContext context) => Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => FoodEntryScreen(food: entry.food, foodId: entry.foodId, existing: entry),
    ),
  );

  Future<void> _relog(BuildContext context) async {
    final l = context.l10n;
    final at = defaultTimeFor(app, app.today);
    final copy = FoodEntry(
      id: newId(),
      foodId: entry.foodId,
      food: entry.food,
      amount: entry.amount,
      unit: entry.unit,
      meal: entry.meal,
      at: at,
      note: entry.note,
    );
    await app.db.saveEntry(copy);
    if (context.mounted) showUndo(context, l.nutritionRelogged(entry.food.name), () => app.db.deleteEntry(copy.id));
  }

  Future<void> _delete(BuildContext context) async {
    final l = context.l10n;
    await app.db.deleteEntry(entry.id);
    if (context.mounted) showUndo(context, l.nutritionEntryDeleted, () => app.db.saveEntry(entry));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final f = context.fmt;
    final n = entry.nutrients;
    final amount = '${f.nTrim(entry.amount, 2)} ${l.unitFor(entry.unit, entry.amount)}';
    final kcal = n.has(kEnergy) ? f.kcal(n.get0(kEnergy)) : l.nutritionNoKcal;
    final name = entry.food.name == entry.food.barcode ? l.foodUnnamed : entry.food.name;
    final subtitle = [if (showDate) f.dateTime(entry.at) else f.time(entry.at), amount, kcal].join(' · ');
    final macros = [
      for (final k in [kProtein, kCarbs, kFat])
        '${nutrientName(k, f.lang)} ${n.has(k) ? f.nutrient(n.get0(k), nutrientByKey[k]!) : '–'}',
    ].join(' · ');
    return ListTile(
      contentPadding: const EdgeInsets.only(right: 0),
      title: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text('$subtitle\n$macros'),
      isThreeLine: true,
      onTap: () => _edit(context),
      trailing: PopupMenuButton<String>(
        tooltip: l.commonMore,
        onSelected: (v) {
          switch (v) {
            case 'edit':
              _edit(context);
            case 'relog':
              _relog(context);
            case 'delete':
              _delete(context);
          }
        },
        itemBuilder: (c) => [
          PopupMenuItem(value: 'edit', child: Text(l.commonEdit)),
          PopupMenuItem(value: 'relog', child: Text(l.nutritionEntryRelog)),
          PopupMenuItem(value: 'delete', child: Text(l.commonDelete)),
        ],
      ),
    );
  }
}

/// Verlauf über 7 oder 28 Tage für einen auswählbaren Nährstoff.
class TrendsTab extends StatefulWidget {
  const TrendsTab({super.key});

  @override
  State<TrendsTab> createState() => _TrendsTabState();
}

class _TrendsTabState extends State<TrendsTab> {
  int _days = 7;

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final l = context.l10n;
    return ListView(
      key: const PageStorageKey('trends'),
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 32),
      children: [
        DayNavigator(day: app.selectedDay, today: app.today, onChanged: app.selectDay),
        const SizedBox(height: 8),
        SegmentedButton<int>(
          showSelectedIcon: false,
          segments: [
            ButtonSegment(value: 7, label: Text(l.trendsRange7)),
            ButtonSegment(value: 28, label: Text(l.trendsRange28)),
          ],
          selected: {_days},
          onSelectionChanged: (s) => setState(() => _days = s.first),
        ),
        const SizedBox(height: 12),
        NutritionTrendCard(days: _days, end: app.selectedDay),
      ],
    );
  }
}
