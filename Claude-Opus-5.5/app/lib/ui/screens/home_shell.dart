import 'package:flutter/material.dart';

import '../controller.dart';
import 'cycle/cycle_screen.dart';
import 'history_screen.dart';
import 'nutrition/nutrition_screen.dart';
import 'overview_screen.dart';
import 'settings/settings_screen.dart';
import 'symptoms/symptom_editor.dart';
import 'symptoms/symptoms_screen.dart';
import 'weight/weight_screen.dart';

/// Main navigation: overview plus the four areas.
class HomeShell extends StatelessWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final s = app.s;
    // The action button lives in this outer scaffold so that snack bars
    // (shown here) move it up instead of covering it.
    final fab = switch (app.tabIndex) {
      1 => FloatingActionButton.extended(
        heroTag: 'add-food',
        onPressed: () => openFoodSearch(context, app.selectedDate, null),
        icon: const Icon(Icons.add),
        label: Text(s.addFood),
      ),
      3 => FloatingActionButton.extended(
        heroTag: 'add-weight',
        onPressed: () => openWeightEditor(context),
        icon: const Icon(Icons.add),
        label: Text(s.addWeight),
      ),
      4 => FloatingActionButton.extended(
        heroTag: 'add-symptom',
        onPressed: () => openSymptomEditor(context, date: app.today),
        icon: const Icon(Icons.add),
        label: Text(s.addSymptom),
      ),
      _ => null,
    };
    return Scaffold(
      floatingActionButton: fab,
      body: IndexedStack(
        index: app.tabIndex,
        children: const [
          OverviewScreen(),
          NutritionScreen(),
          CycleScreen(),
          WeightScreen(),
          SymptomsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: app.tabIndex,
        onDestinationSelected: app.goToTab,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.dashboard_outlined),
            selectedIcon: const Icon(Icons.dashboard),
            label: s.navOverview,
          ),
          NavigationDestination(
            icon: const Icon(Icons.restaurant_outlined),
            selectedIcon: const Icon(Icons.restaurant),
            label: s.navNutrition,
          ),
          NavigationDestination(
            icon: const Icon(Icons.water_drop_outlined),
            selectedIcon: const Icon(Icons.water_drop),
            label: s.navCycle,
          ),
          NavigationDestination(
            icon: const Icon(Icons.monitor_weight_outlined),
            selectedIcon: const Icon(Icons.monitor_weight),
            label: s.navWeight,
          ),
          NavigationDestination(
            icon: const Icon(Icons.healing_outlined),
            selectedIcon: const Icon(Icons.healing),
            label: s.navSymptoms,
          ),
        ],
      ),
    );
  }
}

/// App bar actions shared by all main screens: history search and settings.
List<Widget> mainActions(BuildContext context) {
  final s = context.s;
  return [
    IconButton(
      tooltip: s.historyTitle,
      icon: const Icon(Icons.search),
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const HistoryScreen()),
      ),
    ),
    IconButton(
      tooltip: s.settingsTitle,
      icon: const Icon(Icons.settings_outlined),
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
      ),
    ),
  ];
}
