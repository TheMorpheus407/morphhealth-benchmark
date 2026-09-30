import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../core/nutrients.dart';
import '../../core/nutrition.dart';
import '../../state/app_state.dart';
import '../cycle/cycle_widgets.dart';
import '../day/day_detail_screen.dart';
import '../history/history_screen.dart';
import '../l10n_x.dart';
import '../nutrition/nutrition_screen.dart';
import '../nutrition/trend_card.dart';
import '../nutrition/water_caffeine.dart';
import '../settings/settings_screen.dart';
import '../symptoms/symptom_screen.dart';
import '../theme.dart';
import '../weight/weight_screen.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';

/// Übersicht: die vom Nutzer gewählten Bereiche für den gewählten Tag oder
/// als Verlauf über 7 beziehungsweise 28 Tage.
class OverviewScreen extends StatefulWidget {
  const OverviewScreen({super.key});

  @override
  State<OverviewScreen> createState() => _OverviewScreenState();
}

class _OverviewScreenState extends State<OverviewScreen> {
  int _range = 1; // 1 Tag, 7, 28

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final l = context.l10n;
    final areas = Area.values.where(app.settings.shows).toList();
    final day = app.selectedDay;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.navOverview),
        actions: [
          IconButton(
            tooltip: l.historyTitle,
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const HistoryScreen())),
          ),
          IconButton(
            tooltip: l.overviewCustomize,
            icon: const Icon(Icons.tune),
            onPressed: () => showAreasSheet(context),
          ),
          IconButton(
            tooltip: l.overviewSettings,
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
          ),
        ],
      ),
      body: ListView(
        key: const PageStorageKey('overview'),
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 32),
        children: [
          DayNavigator(day: day, today: app.today, onChanged: app.selectDay),
          const SizedBox(height: 4),
          SegmentedButton<int>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: 1, label: Text(l.overviewRangeDay)),
              ButtonSegment(value: 7, label: Text(l.trendsRange7)),
              ButtonSegment(value: 28, label: Text(l.trendsRange28)),
            ],
            selected: {_range},
            onSelectionChanged: (s) => setState(() => _range = s.first),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () =>
                  Navigator.of(context).push(MaterialPageRoute(builder: (_) => DayDetailScreen(initialDay: day))),
              icon: const Icon(Icons.article_outlined),
              label: Text(l.overviewOpenDay),
            ),
          ),
          if (areas.isEmpty)
            Padding(
              padding: const EdgeInsets.all(8),
              child: EmptyHint(l.overviewNothingVisible, icon: Icons.visibility_off_outlined),
            )
          else
            for (final a in areas) ...[
              switch (a) {
                Area.nutrition => _range == 1 ? const _NutritionDayCard() : _NutritionRangeCard(days: _range),
                Area.cycle => _range == 1 ? const _CycleDayCard() : _CycleRangeCard(days: _range),
                Area.weight => _range == 1 ? const _WeightDayCard() : _WeightRangeCard(days: _range),
                Area.symptoms => _range == 1 ? const _SymptomsDayCard() : _SymptomsRangeCard(days: _range),
              },
              const SizedBox(height: 12),
            ],
        ],
      ),
    );
  }
}

/// Blatt zum Ein- und Ausblenden der vier Bereiche.
Future<void> showAreasSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (c) => const _AreasSheet(),
  );
}

class _AreasSheet extends StatelessWidget {
  const _AreasSheet();

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final l = context.l10n;
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 24 + sheetBottomInset(context)),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.overviewCustomize, style: context.text.titleLarge),
          const SizedBox(height: 4),
          Text(l.overviewCustomizeHint, style: context.text.bodyMedium),
          const SizedBox(height: 8),
          for (final a in Area.values)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: Icon(areaIcon(a), color: areaColor(a, context.theme.brightness)),
              title: Text(l.area(a)),
              value: app.settings.shows(a),
              onChanged: (v) {
                final next = {...app.settings.areas};
                v ? next.add(a) : next.remove(a);
                app.db.saveSettings(app.settings.copyWith(areas: next));
                if (!v && app.currentArea == a) app.openArea(null);
              },
            ),
          Align(
            alignment: Alignment.centerRight,
            child: FilledButton(onPressed: () => Navigator.pop(context), child: Text(l.commonDone)),
          ),
        ],
      ),
    );
  }
}

// -- Tageskarten ---------------------------------------------------------------

class _NutritionDayCard extends StatelessWidget {
  const _NutritionDayCard();

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final l = context.l10n;
    final f = context.fmt;
    final color = areaColor(Area.nutrition, context.theme.brightness);
    final data = app.core.nutritionDay(app.selectedDay);
    final kcal = data.totals.get0(kEnergy);
    final goal = data.goals.energyKcal;
    final waterGoal = data.goals.waterMl;
    return SectionCard(
      title: l.navNutrition,
      icon: areaIcon(Area.nutrition),
      accent: color,
      trailing: TextButton(onPressed: () => app.openArea(Area.nutrition), child: Text(l.commonShow)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Semantics(
            label: goal == null ? l.nutritionKcalPlain(f.n(kcal)) : l.nutritionKcalOfGoal(f.n(kcal), f.n(goal)),
            excludeSemantics: true,
            child: Text(
              goal == null ? l.nutritionKcalPlain(f.n(kcal)) : l.nutritionKcalOfGoal(f.n(kcal), f.n(goal)),
              style: context.text.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
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
          const SizedBox(height: 10),
          Wrap(
            spacing: 16,
            runSpacing: 4,
            children: [
              for (final k in [kProtein, kCarbs, kFat])
                Text(
                  data.goals.forNutrient(k) == null
                      ? '${nutrientName(k, f.lang)} ${f.nutrient(data.totals.get0(k), nutrientByKey[k]!)}'
                      : '${nutrientName(k, f.lang)} ${f.n(data.totals.get0(k), nutrientByKey[k]!.decimals)} / ${f.nTrim(data.goals.forNutrient(k)!, 1)} ${nutrientByKey[k]!.unit}',
                  style: context.text.bodyMedium,
                ),
            ],
          ),
          const SizedBox(height: 12),
          ProgressRow(
            label: l.waterTitle,
            valueText: waterGoal == null
                ? l.waterPlain(f.n(data.waterMl))
                : l.waterOfGoal(f.n(data.waterMl), f.n(waterGoal)),
            fraction: waterGoal == null ? null : data.waterMl / waterGoal,
            color: color,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final ml in kQuickWaterAmounts)
                Semantics(
                  label: l.waterQuickAdd('$ml'),
                  button: true,
                  excludeSemantics: true,
                  onTap: () => addWater(context, app, app.selectedDay, ml.toDouble()),
                  child: ActionChip(
                    avatar: const Icon(Icons.add, size: 18),
                    label: Text('$ml ml'),
                    onPressed: () => addWater(context, app, app.selectedDay, ml.toDouble()),
                  ),
                ),
            ],
          ),
          if (data.caffeineTotalMg > 0) ...[
            const SizedBox(height: 8),
            Text('${l.caffeineTitle}: ${l.caffeineTotal(f.n(data.caffeineTotalMg))}', style: context.text.bodyMedium),
          ],
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => openFoodPicker(context),
              icon: const Icon(Icons.add),
              label: Text(l.nutritionAddFood),
            ),
          ),
        ],
      ),
    );
  }
}

class _CycleDayCard extends StatelessWidget {
  const _CycleDayCard();

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final l = context.l10n;
    final color = areaColor(Area.cycle, context.theme.brightness);
    return SectionCard(
      title: l.navCycle,
      icon: areaIcon(Area.cycle),
      accent: color,
      trailing: TextButton(onPressed: () => app.openArea(Area.cycle), child: Text(l.commonShow)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (app.settings.cycleForecast) ForecastBody(forecast: app.core.cycleForecast(app.selectedDay)),
          if (app.settings.cycleForecast) const SizedBox(height: 8),
          const PeriodQuickActions(),
        ],
      ),
    );
  }
}

class _WeightDayCard extends StatelessWidget {
  const _WeightDayCard();

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final l = context.l10n;
    final f = context.fmt;
    final color = areaColor(Area.weight, context.theme.brightness);
    final day = app.selectedDay;
    final latest = app.db.latestWeightUpTo(day);
    return SectionCard(
      title: l.navWeight,
      icon: areaIcon(Area.weight),
      accent: color,
      trailing: TextButton(onPressed: () => app.openArea(Area.weight), child: Text(l.commonShow)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (latest == null)
            EmptyHint(l.overviewWeightNone, icon: Icons.monitor_weight_outlined)
          else ...[
            Text(
              formatWeight(context, app, latest.kg),
              style: context.text.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            Text(
              l.weightLatest(formatWeight(context, app, latest.kg), f.date(latest.day)),
              style: context.text.bodyMedium,
            ),
          ],
          const SizedBox(height: 4),
          TextButton.icon(
            onPressed: () => showWeightSheet(context, day: day),
            icon: const Icon(Icons.add),
            label: Text(l.weightAdd),
          ),
        ],
      ),
    );
  }
}

class _SymptomsDayCard extends StatelessWidget {
  const _SymptomsDayCard();

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final l = context.l10n;
    final color = areaColor(Area.symptoms, context.theme.brightness);
    final day = app.selectedDay;
    final entries = app.db.symptoms.on(day);
    return SectionCard(
      title: l.navSymptoms,
      icon: areaIcon(Area.symptoms),
      accent: color,
      trailing: TextButton(onPressed: () => app.openArea(Area.symptoms), child: Text(l.commonShow)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (entries.isEmpty)
            EmptyHint(l.overviewSymptomsNone, icon: Icons.healing_outlined)
          else
            for (final e in entries) SymptomTile(entry: e),
          TextButton.icon(
            onPressed: () => showSymptomSheet(context, day: day),
            icon: const Icon(Icons.add),
            label: Text(l.symptomAdd),
          ),
        ],
      ),
    );
  }
}

// -- Verlaufskarten (7 und 28 Tage) ------------------------------------------------

class _NutritionRangeCard extends StatelessWidget {
  final int days;

  const _NutritionRangeCard({required this.days});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final l = context.l10n;
    final color = areaColor(Area.nutrition, context.theme.brightness);
    return SectionCard(
      title: l.navNutrition,
      icon: areaIcon(Area.nutrition),
      accent: color,
      trailing: TextButton(onPressed: () => app.openArea(Area.nutrition), child: Text(l.commonShow)),
      child: NutritionTrendCard(days: days, end: app.selectedDay, embedded: true),
    );
  }
}

class _CycleRangeCard extends StatelessWidget {
  final int days;

  const _CycleRangeCard({required this.days});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final l = context.l10n;
    final f = context.fmt;
    final color = areaColor(Area.cycle, context.theme.brightness);
    final end = app.selectedDay;
    final start = end.addDays(-(days - 1));
    final inRange = [
      for (final p in app.db.periods)
        if (!p.start.isAfter(end) && !p.lastDay(end).isBefore(start)) p,
    ];
    return SectionCard(
      title: l.navCycle,
      icon: areaIcon(Area.cycle),
      accent: color,
      trailing: TextButton(onPressed: () => app.openArea(Area.cycle), child: Text(l.commonShow)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.overviewCyclePeriods(inRange.length), style: context.text.bodyLarge),
          for (final p in inRange)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                p.end == null
                    ? l.historyPeriodOpen(f.date(p.start))
                    : l.historyPeriodTitle(f.date(p.start), f.date(p.end!)),
                style: context.text.bodyMedium,
              ),
            ),
          if (app.settings.cycleForecast) ...[
            const SizedBox(height: 8),
            ForecastBody(forecast: app.core.cycleForecast(end)),
          ],
        ],
      ),
    );
  }
}

class _WeightRangeCard extends StatelessWidget {
  final int days;

  const _WeightRangeCard({required this.days});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final l = context.l10n;
    final f = context.fmt;
    final color = areaColor(Area.weight, context.theme.brightness);
    final end = app.selectedDay;
    final series = weightSeries(app.db, end, days);
    final points = [
      for (final p in series.points)
        if (p.value != null) LinePoint(p.day, p.value!),
    ];
    final lb = app.settings.weightUnit == WeightUnit.lb;
    double toUnit(double kg) => lb ? kgToLb(kg) : kg;
    return SectionCard(
      title: l.navWeight,
      icon: areaIcon(Area.weight),
      accent: color,
      trailing: TextButton(onPressed: () => app.openArea(Area.weight), child: Text(l.commonShow)),
      child: points.isEmpty
          ? EmptyHint(l.weightNoRange, icon: Icons.monitor_weight_outlined)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l.overviewWeightRange(
                    formatWeight(context, app, points.first.value),
                    formatWeight(context, app, points.last.value),
                    formatWeightDelta(context, app, points.last.value - points.first.value),
                  ),
                  style: context.text.bodyLarge,
                ),
                const SizedBox(height: 8),
                LineChart(
                  points: [for (final p in points) LinePoint(p.day, toUnit(p.value))],
                  start: end.addDays(-(days - 1)),
                  end: end,
                  color: color,
                  valueLabel: (v) => f.n(v, 1),
                  dayLabel: (d) => f.dateWithWeekday(d),
                  axisLabel: (d) => f.dayMonth(d),
                  hint: l.weightChartHint,
                  summary: l.weightChartSummary(
                    days == 7 ? l.trendsRange7 : l.trendsRange28,
                    formatWeight(context, app, points.first.value),
                    formatWeight(context, app, points.last.value),
                    points.length,
                  ),
                ),
              ],
            ),
    );
  }
}

class _SymptomsRangeCard extends StatelessWidget {
  final int days;

  const _SymptomsRangeCard({required this.days});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final l = context.l10n;
    final f = context.fmt;
    final color = areaColor(Area.symptoms, context.theme.brightness);
    final end = app.selectedDay;
    final start = end.addDays(-(days - 1));
    final counts = <String, (String, int, int)>{};
    for (final s in app.db.symptoms.all) {
      if (s.day.isBefore(start) || s.day.isAfter(end)) continue;
      final cur = counts[s.key];
      counts[s.key] = cur == null ? (s.name, 1, s.intensity) : (cur.$1, cur.$2 + 1, cur.$3 + s.intensity);
    }
    final top = counts.values.toList()..sort((a, b) => b.$2.compareTo(a.$2));
    return SectionCard(
      title: l.navSymptoms,
      icon: areaIcon(Area.symptoms),
      accent: color,
      trailing: TextButton(onPressed: () => app.openArea(Area.symptoms), child: Text(l.commonShow)),
      child: top.isEmpty
          ? EmptyHint(l.overviewNoDataRange, icon: Icons.healing_outlined)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.overviewTopSymptoms, style: context.text.titleSmall),
                for (final t in top.take(5))
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(t.$1),
                    subtitle: Text(l.overviewSymptomCount(t.$2, f.n(roundTo(t.$3 / t.$2, 1), 1))),
                  ),
              ],
            ),
    );
  }
}
