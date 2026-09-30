import 'package:flutter/material.dart';

import '../../core/model/enums.dart';
import '../controller.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/date_nav.dart';
import 'cycle/cycle_screen.dart';
import 'day_detail_screen.dart';
import 'home_shell.dart';
import 'nutrition/intake_cards.dart';
import 'nutrition/nutrition_screen.dart';
import 'symptoms/symptom_editor.dart';
import 'symptoms/symptoms_screen.dart';
import 'weight/weight_screen.dart';

/// Overview of the areas the user chose to show, for the selected day.
class OverviewScreen extends StatelessWidget {
  const OverviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final s = app.s;
    final date = app.selectedDate;
    final areas = app.settings.overviewAreas;
    final cards = <Widget>[];
    void add(Widget w) => cards
      ..add(w)
      ..add(const SizedBox(height: 12));

    if (areas.contains(Area.nutrition)) {
      add(NutritionSummaryCard(
        day: app.service.nutritionDay(date),
        title: s.nutritionToday,
        onTap: () => app.goToTab(1),
        showAddFood: true,
      ));
      add(WaterCard(date: date, compact: true));
      add(CaffeineCard(date: date, compact: true));
    }
    if (areas.contains(Area.cycle)) {
      add(CycleStatusCard(
        forecast: app.service.cycleForecast(date),
        onTap: () => app.goToTab(2),
      ));
    }
    if (areas.contains(Area.weight)) {
      add(WeightSummaryCard(onTap: () => app.goToTab(3), showAdd: true));
    }
    if (areas.contains(Area.symptoms)) {
      add(_SymptomsCard(onTap: () => app.goToTab(4)));
    }

    return Scaffold(
      appBar: AppBar(title: Text(s.appName), actions: mainActions(context)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 32),
        children: [
          DateNavigator(date: date, onChanged: app.selectDate),
          Align(
            alignment: Alignment.center,
            child: TextButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => DayDetailScreen(date: date)),
              ),
              icon: const Icon(Icons.today_outlined),
              label: Text(s.openDayDetail),
            ),
          ),
          const SizedBox(height: 4),
          if (areas.isEmpty) EmptyHint(s.noAreasVisible, icon: Icons.visibility_off_outlined),
          ...cards,
          OutlinedButton.icon(
            onPressed: () => showAreaSettings(context),
            icon: const Icon(Icons.tune),
            label: Text(s.customizeOverview),
          ),
        ],
      ),
    );
  }
}

/// Bottom sheet with one switch per area.
Future<void> showAreaSettings(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => const _AreaSettingsSheet(),
  );
}

class _AreaSettingsSheet extends StatelessWidget {
  const _AreaSettingsSheet();

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final s = app.s;
    final areas = app.settings.overviewAreas;
    return SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        children: [
          Semantics(header: true, child: Text(s.customizeOverview, style: context.text.titleLarge)),
          const SizedBox(height: 4),
          Text(s.customizeOverviewHint, style: context.text.bodyMedium),
          const SizedBox(height: 8),
          for (final area in Area.values)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              secondary: Icon(areaIcon(area), color: context.colors.area(area)),
              title: Text(s.areaName(area)),
              value: areas.contains(area),
              onChanged: (on) {
                final next = {...areas};
                on ? next.add(area) : next.remove(area);
                app.updateSettings(app.settings.copyWith(overviewAreas: next));
              },
            ),
        ],
      ),
    );
  }
}

class _SymptomsCard extends StatelessWidget {
  const _SymptomsCard({this.onTap});

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final s = app.s;
    final date = app.selectedDate;
    final entries = app.data.symptomsOn(date);
    return SectionCard(
      title: s.navSymptoms,
      icon: Icons.healing_outlined,
      iconColor: context.colors.symptoms,
      onTap: onTap,
      trailing: IconButton(
        tooltip: s.addSymptom,
        icon: const Icon(Icons.add_circle_outline),
        onPressed: () => openSymptomEditor(context, date: date),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (entries.isEmpty) EmptyHint(s.noSymptomsOnDay),
          for (final e in entries) SymptomTile(entry: e),
        ],
      ),
    );
  }
}
