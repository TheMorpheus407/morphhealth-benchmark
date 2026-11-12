library morphhealth.ui.home_page;

import 'package:flutter/material.dart';
import 'package:morphhealth/core/repository.dart';
import 'package:morphhealth/l10n/app_localizations.dart';
import 'package:morphhealth/ui/cycle_page.dart';
import 'package:morphhealth/ui/nutrition_page.dart';
import 'package:morphhealth/ui/overview_page.dart';
import 'package:morphhealth/ui/settings_page.dart';
import 'package:morphhealth/ui/weight_page.dart';

class HomePage extends StatefulWidget {
  final HealthRepository repository;
  final void Function(Locale) onLocaleChange;
  const HomePage({super.key, required this.repository, required this.onLocaleChange});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final pages = <Widget>[
      OverviewPage(repository: widget.repository),
      NutritionPage(repository: widget.repository),
      CyclePage(repository: widget.repository, initialDate: DateTime.now()),
      WeightPage(repository: widget.repository),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.repository.settings.visibleAreas.contains('overview')
            ? l.msg('navOverview')
            : l.msg('appTitle')),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(
              builder: (_) => SettingsPage(
                repository: widget.repository,
                onLocaleChange: widget.onLocaleChange,
              ),
            )),
          ),
        ],
      ),
      body: IndexedStack(index: _index, children: pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.dashboard),
            label: l.msg('navOverview'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.restaurant_menu),
            label: l.msg('navNutrition'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.calendar_today),
            label: l.msg('navCycle'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.monitor_weight),
            label: l.msg('navWeight'),
          ),
        ],
      ),
    );
  }
}