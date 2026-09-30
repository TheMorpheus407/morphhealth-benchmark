import 'package:flutter/material.dart';

import '../core/models.dart';
import '../state/app_state.dart';
import 'cycle/cycle_screen.dart';
import 'l10n_x.dart';
import 'nutrition/nutrition_screen.dart';
import 'overview/overview_screen.dart';
import 'symptoms/symptom_screen.dart';
import 'theme.dart';
import 'weight/weight_screen.dart';

/// Hauptnavigation: Übersicht plus die eingeblendeten Bereiche. Schmale
/// Bildschirme bekommen eine Navigationsleiste unten, breite eine Leiste links.
class HomeShell extends StatelessWidget {
  const HomeShell({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final l = context.l10n;
    final areas = Area.values.where(app.settings.shows).toList();
    // Ein ausgeblendeter Bereich kann nicht geöffnet bleiben.
    final current = app.currentArea != null && areas.contains(app.currentArea) ? app.currentArea : null;
    if (app.currentArea != null && current == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => app.openArea(null));
    }
    final destinations = <(Area?, IconData, IconData, String)>[
      (null, Icons.dashboard_outlined, Icons.dashboard, l.navOverview),
      for (final a in areas) (a, areaIcon(a), areaIcon(a, selected: true), l.area(a)),
    ];
    final index = destinations.indexWhere((d) => d.$1 == current);
    final body = switch (current) {
      null => const OverviewScreen(),
      Area.nutrition => const NutritionScreen(),
      Area.cycle => const CycleScreen(),
      Area.weight => const WeightScreen(),
      Area.symptoms => const SymptomScreen(),
    };
    final wide = MediaQuery.sizeOf(context).width >= 720;
    return PopScope(
      canPop: current == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) app.openArea(null);
      },
      child: Scaffold(
        body: wide
            ? Row(
                children: [
                  NavigationRail(
                    selectedIndex: index < 0 ? 0 : index,
                    labelType: NavigationRailLabelType.all,
                    onDestinationSelected: (i) => app.openArea(destinations[i].$1),
                    destinations: [
                      for (final d in destinations)
                        NavigationRailDestination(icon: Icon(d.$2), selectedIcon: Icon(d.$3), label: Text(d.$4)),
                    ],
                  ),
                  const VerticalDivider(width: 1),
                  Expanded(child: body),
                ],
              )
            : body,
        bottomNavigationBar: wide || destinations.length < 2
            ? null
            : NavigationBar(
                selectedIndex: index < 0 ? 0 : index,
                onDestinationSelected: (i) => app.openArea(destinations[i].$1),
                destinations: [
                  for (final d in destinations)
                    NavigationDestination(icon: Icon(d.$2), selectedIcon: Icon(d.$3), label: d.$4),
                ],
              ),
      ),
    );
  }
}
