// Home-Shell: Bottom-Navigation über Übersicht + die sichtbaren Bereiche.
library;

import 'package:flutter/material.dart';

import '../data/repository.dart';
import '../l10n/app_strings.dart';
import 'cycle_screen.dart';
import 'history_screen.dart';
import 'nutrition_screen.dart';
import 'overview_screen.dart';
import 'scope.dart';
import 'settings_screen.dart';
import 'symptoms_screen.dart';
import 'trends_screen.dart';
import 'weight_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

IconData _areaIcon(String area, {bool filled = false}) {
  switch (area) {
    case 'nutrition':
      return filled ? Icons.restaurant : Icons.restaurant_outlined;
    case 'cycle':
      return filled ? Icons.calendar_month : Icons.calendar_month_outlined;
    case 'weight':
      return filled ? Icons.monitor_weight : Icons.monitor_weight_outlined;
    case 'symptoms':
      return filled ? Icons.healing : Icons.healing_outlined;
    default:
      return filled ? Icons.dashboard : Icons.dashboard_outlined;
  }
}

Widget _areaScreen(String area) {
  switch (area) {
    case 'nutrition':
      return const NutritionScreen();
    case 'cycle':
      return const CycleScreen();
    case 'weight':
      return const WeightScreen();
    case 'symptoms':
      return const SymptomsScreen();
    default:
      // Nur über die Overview-Route erreichbar (erfordert onOpenArea).
      return OverviewScreen(onOpenArea: (_) {});
  }
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = StringsScope.of(context);
    final MorphRepository repo = MorphScope.repoOf(context);
    return ListenableBuilder(
      listenable: MorphScope.listenableOf(context),
      builder: (BuildContext context, Widget? _) {
        final List<String> areas = repo.settings.visibleAreas;
        final List<Widget> screens = <Widget>[
          OverviewScreen(onOpenArea: (String area) {
            final int i = areas.indexOf(area) + 1;
            if (i > 0) setState(() => _index = i);
          }),
          for (final String a in areas) _areaScreen(a),
        ];
        final int index = _index.clamp(0, screens.length - 1);
        final String currentArea =
            index == 0 ? 'overview' : areas[index - 1];
        return Scaffold(
          appBar: AppBar(
            title: Text(index == 0 ? strings.appName : strings.areaName(currentArea)),
            actions: index == 0
                ? <Widget>[
                    IconButton(
                      tooltip: strings.openHistory,
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<Widget>(
                            builder: (_) => const HistoryScreen()),
                      ),
                      icon: const Icon(Icons.search),
                    ),
                    IconButton(
                      tooltip: strings.openTrends,
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<Widget>(
                            builder: (_) => const TrendsScreen()),
                      ),
                      icon: const Icon(Icons.trending_up),
                    ),
                    IconButton(
                      tooltip: strings.openSettings,
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute<Widget>(
                            builder: (_) => const SettingsScreen()),
                      ),
                      icon: const Icon(Icons.settings_outlined),
                    ),
                  ]
                : null,
          ),
          body: IndexedStack(index: index, children: screens),
          bottomNavigationBar: NavigationBar(
            selectedIndex: index,
            onDestinationSelected: (int i) => setState(() => _index = i),
            destinations: <NavigationDestination>[
              NavigationDestination(
                icon: const Icon(Icons.dashboard_outlined),
                selectedIcon: const Icon(Icons.dashboard),
                label: strings.areaName('overview'),
              ),
              for (final String a in areas)
                NavigationDestination(
                  icon: Icon(_areaIcon(a)),
                  selectedIcon: Icon(_areaIcon(a, filled: true)),
                  label: strings.areaName(a),
                ),
            ],
          ),
        );
      },
    );
  }
}
