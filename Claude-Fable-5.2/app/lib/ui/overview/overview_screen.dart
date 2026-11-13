import 'package:flutter/material.dart';
import 'package:morphhealth_core/morphhealth_core.dart';

import '../body/editors.dart';
import '../cycle/forecast_card.dart';
import '../day/day_detail_screen.dart';
import '../nutrition/add_food_screen.dart';
import '../nutrition/diary_screen.dart';
import '../nutrition/hydration.dart';
import '../shell.dart';
import '../theme.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';

/// Today at a glance: the areas the user chose, each with its quick entry.
class OverviewScreen extends StatelessWidget {
  const OverviewScreen({super.key});

  void _go(BuildContext context, AppTab tab, {int? subTab}) =>
      ShellNavigator.maybeOf(context)?.goTo(tab, subTab: subTab);

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final fmt = context.fmt;
    final app = context.app;
    final today = app.today;
    final sections = app.settings.overviewSections;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.navOverview),
            Text(
              fmt.dayLongNoYear(today),
              style: context.texts.bodySmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: const [SettingsButton()],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
          children: [
            if (sections.contains(Area.nutrition)) ...[
              NutritionSummaryCard(
                day: today,
                title: l.navNutrition,
                onOpen: () => _go(context, AppTab.nutrition),
                showAllNutrients: false,
                action: FilledButton.tonalIcon(
                  icon: const Icon(Icons.add),
                  label: Text(l.logFood),
                  onPressed: () => AddFoodScreen.open(context, day: today),
                ),
              ),
              const SizedBox(height: 12),
              WaterCaffeineCard(day: today, compact: true),
              const SizedBox(height: 12),
            ],
            if (sections.contains(Area.cycle)) ...[
              ForecastCard(onOpen: () => _go(context, AppTab.cycle)),
              const SizedBox(height: 12),
            ],
            if (sections.contains(Area.weight)) ...[
              _WeightCard(onOpen: () => _go(context, AppTab.body, subTab: 0)),
              const SizedBox(height: 12),
            ],
            if (sections.contains(Area.symptoms)) ...[
              _SymptomsCard(onOpen: () => _go(context, AppTab.body, subTab: 1)),
              const SizedBox(height: 12),
            ],
            if (sections.isEmpty)
              EmptyHint(
                icon: Icons.dashboard_customize_outlined,
                text: l.overviewAllHidden,
              ),
            OutlinedButton.icon(
              icon: const Icon(Icons.view_day_outlined),
              label: Text(l.openDayDetail),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => DayDetailScreen(day: today),
                ),
              ),
            ),
            const SizedBox(height: 4),
            TextButton.icon(
              icon: const Icon(Icons.tune),
              label: Text(l.overviewCustomize),
              onPressed: () => showOverviewCustomizer(context),
            ),
          ],
        ),
      ),
    );
  }
}

/// Lets the user show or hide each of the four areas on the overview.
Future<void> showOverviewCustomizer(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      useSafeArea: true,
      // The sheet ends above the system navigation bar.
      builder: (context) => SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
                child: Semantics(
                  header: true,
                  child: Text(
                    context.l.overviewCustomize,
                    style: context.texts.titleLarge,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  context.l.overviewCustomizeHint,
                  style: context.texts.bodyMedium,
                ),
              ),
              const AreaSwitches(),
            ],
          ),
        ),
      ),
    );

/// One switch per area for the overview.
class AreaSwitches extends StatelessWidget {
  const AreaSwitches({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final app = context.app;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final area in Area.values)
          SwitchListTile(
            title: Text(l.area(area)),
            value: app.settings.overviewSections.contains(area),
            onChanged: (v) =>
                guarded(context, () => app.setAreaVisible(area, v)),
          ),
      ],
    );
  }
}

class _WeightCard extends StatelessWidget {
  final VoidCallback onOpen;

  const _WeightCard({required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final fmt = context.fmt;
    final app = context.app;
    final unit = app.settings.weightUnit;
    final all = app.data.weightsSorted;
    final colors = MhColors.of(context);
    final today = app.today;
    final latest = all.isEmpty ? null : all.last;
    final previous = all.length < 2 ? null : all[all.length - 2];

    return MhCard(
      title: l.weight,
      icon: Icons.monitor_weight_outlined,
      iconColor: colors.weight,
      onOpen: onOpen,
      openLabel: l.openArea(l.weight),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (latest == null)
            Text(
              l.noWeightYet,
              style: context.texts.bodyMedium?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Semantics(
                    label:
                        '${fmt.weight(latest.weightKg, unit)}, '
                        '${fmt.dayRelative(latest.date)}',
                    excludeSemantics: true,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          fmt.weight(latest.weightKg, unit),
                          style: context.texts.headlineSmall,
                        ),
                        Text(
                          previous == null
                              ? fmt.dayRelative(latest.date)
                              : '${fmt.dayRelative(latest.date)} · '
                                    '${l.sinceEntry(fmt.weightChange(latest.weightKg - previous.weightKg, unit), fmt.dateShort(previous.date))}',
                          style: context.texts.bodyMedium?.copyWith(
                            color: context.colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (all.length >= 2)
                  SizedBox(
                    width: 110,
                    child: Sparkline(
                      values: weightSeries(app.data, today.addDays(-27), today),
                      color: colors.weight,
                    ),
                  ),
              ],
            ),
          const SizedBox(height: 10),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: FilledButton.tonalIcon(
              icon: const Icon(Icons.add),
              label: Text(l.addWeight),
              onPressed: () => showWeightEditor(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _SymptomsCard extends StatelessWidget {
  final VoidCallback onOpen;

  const _SymptomsCard({required this.onOpen});

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final app = context.app;
    final symptoms = app.data.symptomsOn(app.today);
    return MhCard(
      title: l.symptoms,
      icon: Icons.healing_outlined,
      iconColor: MhColors.of(context).symptom,
      onOpen: onOpen,
      openLabel: l.openArea(l.symptoms),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (symptoms.isEmpty)
            Text(
              l.noSymptomsToday,
              style: context.texts.bodyMedium?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final s in symptoms)
                  ActionChip(
                    label: Text(
                      '${s.name} · ${s.intensity}',
                      semanticsLabel:
                          '${s.name}, ${l.intensityOf(s.intensity)}. ${l.edit}',
                    ),
                    onPressed: () => showSymptomEditor(context, entry: s),
                  ),
              ],
            ),
          const SizedBox(height: 10),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: FilledButton.tonalIcon(
              icon: const Icon(Icons.add),
              label: Text(l.addSymptom),
              onPressed: () => showSymptomEditor(context),
            ),
          ),
        ],
      ),
    );
  }
}
