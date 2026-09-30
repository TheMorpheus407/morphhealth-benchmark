import 'package:flutter/material.dart';

import '../../core/civil.dart';
import '../../core/models.dart';
import '../../core/nutrients.dart';
import '../../state/app_state.dart';
import '../cycle/cycle_widgets.dart';
import '../l10n_x.dart';
import '../nutrition/nutrition_screen.dart';
import '../nutrition/water_caffeine.dart';
import '../symptoms/symptom_screen.dart';
import '../theme.dart';
import '../weight/weight_screen.dart';
import '../widgets/common.dart';

/// Gemeinsames Tagesdetail: Ernährung, Wasser und Koffein, Gewicht,
/// Periodenaufzeichnungen und Symptome eines Tages.
class DayDetailScreen extends StatefulWidget {
  final Day? initialDay;

  const DayDetailScreen({super.key, this.initialDay});

  @override
  State<DayDetailScreen> createState() => _DayDetailScreenState();
}

class _DayDetailScreenState extends State<DayDetailScreen> {
  @override
  void initState() {
    super.initState();
    final d = widget.initialDay;
    if (d != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) AppScope.read(context).selectDay(d);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final l = context.l10n;
    final f = context.fmt;
    final brightness = context.theme.brightness;
    final day = app.selectedDay;
    final s = app.settings;
    final nutrition = app.core.nutritionDay(day);
    final periods = app.db.periodsOn(day);
    final weights = app.db.weights.on(day);
    final symptoms = app.db.symptoms.on(day);
    final children = <Widget>[
      DayNavigator(day: day, today: app.today, onChanged: app.selectDay),
      Padding(
        padding: const EdgeInsets.only(left: 16, bottom: 8),
        child: Text(f.dateLong(day), style: context.text.bodyMedium),
      ),
    ];
    if (s.shows(Area.nutrition)) {
      final color = areaColor(Area.nutrition, brightness);
      children.add(
        SectionCard(
          title: l.navNutrition,
          icon: areaIcon(Area.nutrition),
          accent: color,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!nutrition.hasAnyData) EmptyHint(l.nutritionDayEmpty, icon: Icons.restaurant_outlined),
              if (nutrition.entries.isNotEmpty) ...[
                Text(
                  nutrition.goals.energyKcal == null
                      ? l.nutritionKcalPlain(f.n(nutrition.totals.get0(kEnergy)))
                      : l.nutritionKcalOfGoal(f.n(nutrition.totals.get0(kEnergy)), f.n(nutrition.goals.energyKcal!)),
                  style: context.text.titleLarge,
                ),
                Wrap(
                  spacing: 16,
                  children: [
                    for (final k in [kProtein, kCarbs, kFat])
                      Text(
                        '${nutrientName(k, f.lang)} ${f.nutrient(nutrition.totals.get0(k), nutrientByKey[k]!)}',
                        style: context.text.bodyMedium,
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                for (final m in nutrition.meals)
                  if (m.entries.isNotEmpty) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '${l.meal(m.meal)} · ${f.kcal(m.totals.get0(kEnergy))}',
                        style: context.text.titleSmall,
                      ),
                    ),
                    for (final e in m.entries) EntryTile(entry: e, app: app),
                  ],
              ],
              const Divider(height: 24),
              Text(
                '${l.waterTitle}: ${nutrition.goals.waterMl == null ? l.waterPlain(f.n(nutrition.waterMl)) : l.waterOfGoal(f.n(nutrition.waterMl), f.n(nutrition.goals.waterMl!))}',
                style: context.text.bodyLarge,
              ),
              for (final w in nutrition.waterEntries)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(l.waterEntryTitle(f.n(w.ml))),
                  subtitle: Text(f.time(w.at)),
                  trailing: const Icon(Icons.edit_outlined, size: 18),
                  onTap: () => showWaterSheet(context, day: day, existing: w),
                ),
              Text(
                '${l.caffeineTitle}: ${l.caffeineTotal(f.n(nutrition.caffeineTotalMg))}',
                style: context.text.bodyLarge,
              ),
              for (final c in nutrition.caffeineEntries)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(c.label == null ? l.caffeineEntryTitle(f.n(c.mg)) : '${c.label} · ${f.n(c.mg)} mg'),
                  subtitle: Text(f.time(c.at)),
                  trailing: const Icon(Icons.edit_outlined, size: 18),
                  onTap: () => showCaffeineSheet(context, day: day, existing: c),
                ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: () => openFoodPicker(context),
                    icon: const Icon(Icons.add),
                    label: Text(l.nutritionAddFood),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => addWater(context, app, day, 250),
                    icon: const Icon(Icons.water_drop_outlined),
                    label: const Text('+250 ml'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => showWaterSheet(context, day: day),
                    icon: const Icon(Icons.water_drop_outlined),
                    label: Text(l.waterOther),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => showCaffeineSheet(context, day: day),
                    icon: const Icon(Icons.coffee_outlined),
                    label: Text(l.caffeineLogTitle),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
      children.add(const SizedBox(height: 12));
    }
    if (s.shows(Area.weight)) {
      final color = areaColor(Area.weight, brightness);
      children.add(
        SectionCard(
          title: l.navWeight,
          icon: areaIcon(Area.weight),
          accent: color,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (weights.isEmpty) EmptyHint(l.weightNoEntries, icon: Icons.monitor_weight_outlined),
              for (final w in weights)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(formatWeight(context, app, w.kg), style: context.text.titleMedium),
                  subtitle: Text([f.time(w.at), if (w.note != null) w.note!].join(' · ')),
                  trailing: const Icon(Icons.edit_outlined, size: 18),
                  onTap: () => showWeightSheet(context, day: day, existing: w),
                ),
              TextButton.icon(
                onPressed: () => showWeightSheet(context, day: day),
                icon: const Icon(Icons.add),
                label: Text(l.weightAdd),
              ),
            ],
          ),
        ),
      );
      children.add(const SizedBox(height: 12));
    }
    if (s.shows(Area.cycle)) {
      final color = areaColor(Area.cycle, brightness);
      final flow = periods.isEmpty ? null : periods.first.flowOn(day);
      children.add(
        SectionCard(
          title: l.navCycle,
          icon: areaIcon(Area.cycle),
          accent: color,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (periods.isEmpty)
                EmptyHint(l.cycleDayNoPeriod, icon: Icons.water_drop_outlined)
              else
                for (final p in periods)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l.cycleDayInPeriod('${p.start.daysUntil(day) + 1}')),
                    subtitle: Text([if (flow != null) l.flow(flow), if (p.notes != null) p.notes!].join(' · ')),
                    trailing: const Icon(Icons.edit_outlined, size: 18),
                    onTap: () => showPeriodSheet(context, existing: p),
                  ),
              if (s.cycleForecast) ForecastBody(forecast: app.core.cycleForecast(day)),
              const SizedBox(height: 8),
              const PeriodQuickActions(),
            ],
          ),
        ),
      );
      children.add(const SizedBox(height: 12));
    }
    if (s.shows(Area.symptoms)) {
      final color = areaColor(Area.symptoms, brightness);
      children.add(
        SectionCard(
          title: l.navSymptoms,
          icon: areaIcon(Area.symptoms),
          accent: color,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (symptoms.isEmpty) EmptyHint(l.symptomNoEntries, icon: Icons.healing_outlined),
              for (final e in symptoms) SymptomTile(entry: e),
              TextButton.icon(
                onPressed: () => showSymptomSheet(context, day: day),
                icon: const Icon(Icons.add),
                label: Text(l.symptomAdd),
              ),
            ],
          ),
        ),
      );
    }
    return AppScaffold(
      appBar: AppBar(title: Text(l.dayDetailTitle)),
      body: ListView(padding: const EdgeInsets.fromLTRB(12, 4, 12, 32), children: children),
    );
  }
}
