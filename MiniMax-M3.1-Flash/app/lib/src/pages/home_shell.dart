import 'package:flutter/material.dart';
import 'package:morphhealth_core/morphhealth_core.dart';

import '../l10n/app_localizations.dart';
import 'cycle_page.dart';
import 'history_page.dart';
import 'nutrition_page.dart';
import 'overview_page.dart';
import 'settings_page.dart';

/// Main navigation of MorphHealth.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  void _select(int index) {
    if (_index == index) return;
    setState(() => _index = index);
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: <Widget>[
          OverviewPage(onOpenTab: _select),
          const NutritionPage(),
          const CyclePage(),
          const HistoryPage(),
          const SettingsPage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _select,
        destinations: <NavigationDestination>[
          NavigationDestination(
            icon: const Icon(Icons.dashboard_outlined),
            selectedIcon: const Icon(Icons.dashboard),
            label: l10n.t('nav.overview'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.restaurant_outlined),
            selectedIcon: const Icon(Icons.restaurant),
            label: l10n.t('nav.nutrition'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.water_drop_outlined),
            selectedIcon: const Icon(Icons.water_drop),
            label: l10n.t('nav.cycle'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.history_outlined),
            selectedIcon: const Icon(Icons.history),
            label: l10n.t('nav.history'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: l10n.t('nav.settings'),
          ),
        ],
      ),
    );
  }
}

/// Shared helper that formats a calendar day for the user interface.
String formatDay(BuildContext context, String date, {bool withYear = false}) {
  final DateTime value = DateMath.parse(date);
  final String language = Localizations.localeOf(context).languageCode;
  if (language == 'en') {
    return '${_monthNameEn(value.month)} ${value.day}, ${value.year}';
  }
  return '${value.day}. ${_monthNameDe(value.month)}${withYear ? ' ${value.year}' : ''}';
}

/// Human readable difference between today and a calendar day.
String relativeDayLabel(BuildContext context, String date) {
  final AppLocalizations l10n = context.l10n;
  final String today = DateMath.format(DateTime.now());
  final int diff = DateMath.dayDiff(date, today);
  if (diff == 0) return l10n.t('common.today');
  if (diff == 1) return l10n.t('common.yesterday');
  if (diff == -1) return l10n.t('common.tomorrow');
  return formatDay(context, date, withYear: true);
}

String _monthNameDe(int month) {
  const List<String> names = <String>[
    'Januar',
    'Februar',
    'März',
    'April',
    'Mai',
    'Juni',
    'Juli',
    'August',
    'September',
    'Oktober',
    'November',
    'Dezember',
  ];
  return names[month - 1];
}

String _monthNameEn(int month) {
  const List<String> names = <String>[
    'January',
    'February',
    'March',
    'April',
    'May',
    'June',
    'July',
    'August',
    'September',
    'October',
    'November',
    'December',
  ];
  return names[month - 1];
}

/// Name of a month for the calendar header.
String monthTitle(BuildContext context, int year, int month) {
  final String language = Localizations.localeOf(context).languageCode;
  if (language == 'en') {
    return '${_monthNameEn(month)} $year';
  }
  return '${_monthNameDe(month)} $year';
}
