import 'package:flutter/material.dart';
import 'package:morphhealth_core/morphhealth_core.dart';

import 'body/body_screen.dart';
import 'body/editors.dart';
import 'cycle/cycle_screen.dart';
import 'history/history_screen.dart';
import 'nutrition/add_food_screen.dart';
import 'nutrition/diary_screen.dart';
import 'overview/overview_screen.dart';
import 'settings/settings_screen.dart';
import 'widgets/common.dart';

/// The five main places of the app.
enum AppTab { overview, nutrition, cycle, body, history }

/// Lets screens switch the main tab, for example from an overview card.
class ShellNavigator extends InheritedWidget {
  final void Function(AppTab tab, {int? subTab}) goTo;

  const ShellNavigator({super.key, required this.goTo, required super.child});

  static ShellNavigator? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<ShellNavigator>();

  @override
  bool updateShouldNotify(ShellNavigator oldWidget) => false;
}

/// The main frame: one screen per tab, the navigation bar and the main
/// action of the current tab.
///
/// The action button belongs to this frame and not to the tab screens, so
/// that it and the brief messages at the bottom share one layout: a message
/// lifts the button instead of covering it.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  AppTab _tab = AppTab.overview;
  final _bodyKey = GlobalKey<BodyScreenState>();
  final _historyKey = GlobalKey<HistoryScreenState>();

  /// The day shown in the nutrition diary; null follows today.
  final _diaryDay = ValueNotifier<Day?>(null);

  /// The tab shown on the body screen: weight (0) or symptoms (1).
  final _bodyTab = ValueNotifier<int>(0);

  @override
  void dispose() {
    _diaryDay.dispose();
    _bodyTab.dispose();
    super.dispose();
  }

  void _goTo(AppTab tab, {int? subTab}) {
    setState(() => _tab = tab);
    if (subTab != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (tab == AppTab.body) _bodyKey.currentState?.showTab(subTab);
        if (tab == AppTab.history) _historyKey.currentState?.showTab(subTab);
      });
    }
  }

  Widget? _actionButton(BuildContext context) {
    final l = context.l;
    switch (_tab) {
      case AppTab.nutrition:
        return FloatingActionButton.extended(
          heroTag: 'main-action',
          icon: const Icon(Icons.add),
          label: Text(l.logFood),
          onPressed: () => AddFoodScreen.open(
            context,
            day: _diaryDay.value ?? context.appRead.today,
          ),
        );
      case AppTab.body:
        final weight = _bodyTab.value == 0;
        return FloatingActionButton.extended(
          heroTag: 'main-action',
          icon: const Icon(Icons.add),
          label: Text(weight ? l.addWeight : l.addSymptom),
          onPressed: () =>
              weight ? showWeightEditor(context) : showSymptomEditor(context),
        );
      case AppTab.overview:
      case AppTab.cycle:
      case AppTab.history:
        return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    return ShellNavigator(
      goTo: _goTo,
      // The system back gesture first returns to the overview.
      child: PopScope(
        canPop: _tab == AppTab.overview,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) setState(() => _tab = AppTab.overview);
        },
        child: ListenableBuilder(
          listenable: _bodyTab,
          builder: (context, _) => Scaffold(
            body: IndexedStack(
              index: _tab.index,
              children: [
                const OverviewScreen(),
                DiaryScreen(day: _diaryDay),
                const CycleScreen(),
                BodyScreen(key: _bodyKey, tabIndex: _bodyTab),
                HistoryScreen(key: _historyKey),
              ],
            ),
            floatingActionButton: _actionButton(context),
            bottomNavigationBar: NavigationBar(
              selectedIndex: _tab.index,
              onDestinationSelected: (i) =>
                  setState(() => _tab = AppTab.values[i]),
              destinations: [
                NavigationDestination(
                  icon: const Icon(Icons.today_outlined),
                  selectedIcon: const Icon(Icons.today),
                  label: l.navOverview,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.restaurant_outlined),
                  selectedIcon: const Icon(Icons.restaurant),
                  label: l.navNutrition,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.calendar_month_outlined),
                  selectedIcon: const Icon(Icons.calendar_month),
                  label: l.navCycle,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.monitor_weight_outlined),
                  selectedIcon: const Icon(Icons.monitor_weight),
                  label: l.navBody,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.insights_outlined),
                  selectedIcon: const Icon(Icons.insights),
                  label: l.navHistory,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// The settings button shown in the app bar of every main screen.
class SettingsButton extends StatelessWidget {
  const SettingsButton({super.key});

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: context.l.settings,
    icon: const Icon(Icons.settings_outlined),
    onPressed: () => Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const SettingsScreen())),
  );
}
