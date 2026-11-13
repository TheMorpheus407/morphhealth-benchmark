import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/store.dart';
import 'ui/app_controller.dart';
import 'ui/platform_bridge.dart';
import 'ui/screens/body_screen.dart';
import 'ui/screens/cycle_screen.dart';
import 'ui/screens/history_screen.dart';
import 'ui/screens/nutrition_screen.dart';
import 'ui/screens/overview_screen.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MorphHealthBootstrap());
}

/// Bootstraps the Android Keystore-wrapped master key and encrypted local store.
class MorphHealthBootstrap extends StatefulWidget {
  final AppController? injectedController;

  const MorphHealthBootstrap({super.key, this.injectedController});

  @override
  State<MorphHealthBootstrap> createState() => _MorphHealthBootstrapState();
}

class _MorphHealthBootstrapState extends State<MorphHealthBootstrap> {
  AppController? _controller;
  String? _bootError;

  @override
  void initState() {
    super.initState();
    if (widget.injectedController != null) {
      _controller = widget.injectedController;
    } else {
      _initEncryptedVault();
    }
  }

  Future<void> _initEncryptedVault() async {
    try {
      const bridge = AndroidMethodChannelBridge();
      final creds = await bridge.getAppPathsAndMasterKey();
      final store = await MorphHealthStore.open(
        dataDir: creds.dataDir,
        masterKey: creds.masterKey,
      );
      if (!mounted) return;
      setState(() {
        _controller = AppController(
          store: store,
          platformBridge: bridge,
        );
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _bootError = '$e';
      });
    }
  }

  @override
  void dispose() {
    if (widget.injectedController == null) {
      _controller?.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = _controller;
    if (ctrl == null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: MhTheme.light(),
        darkTheme: MhTheme.dark(),
        home: Scaffold(
          body: Center(
            child: _bootError != null
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      'Fehler beim Öffnen des verschlüsselten Speichers:\n$_bootError',
                      textAlign: TextAlign.center,
                    ),
                  )
                : const CircularProgressIndicator(),
          ),
        ),
      );
    }

    return MorphHealthApp(controller: ctrl);
  }
}

class MorphHealthApp extends StatelessWidget {
  final AppController controller;

  const MorphHealthApp({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final s = controller.strings;
        final locale = Locale(controller.localeCode);

        final pages = <Widget>[
          OverviewScreen(controller: controller),
          NutritionScreen(controller: controller),
          CycleScreen(controller: controller),
          BodyScreen(controller: controller),
          HistoryScreen(controller: controller),
        ];

        return MaterialApp(
          title: 'MorphHealth',
          debugShowCheckedModeBanner: false,
          theme: MhTheme.light(),
          darkTheme: MhTheme.dark(),
          locale: locale,
          supportedLocales: const [
            Locale('de'),
            Locale('en'),
          ],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Scaffold(
            body: IndexedStack(
              index: controller.activeNavIndex,
              children: pages,
            ),
            bottomNavigationBar: NavigationBar(
              selectedIndex: controller.activeNavIndex,
              onDestinationSelected: controller.setNavIndex,
              destinations: [
                NavigationDestination(
                  icon: const Icon(Icons.dashboard_outlined),
                  selectedIcon: const Icon(Icons.dashboard_rounded),
                  label: s.navOverview,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.restaurant_outlined),
                  selectedIcon: const Icon(Icons.restaurant_rounded),
                  label: s.navNutrition,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.calendar_month_outlined),
                  selectedIcon: const Icon(Icons.calendar_month_rounded),
                  label: s.navCycle,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.monitor_weight_outlined),
                  selectedIcon: const Icon(Icons.monitor_weight_rounded),
                  label: s.navBody,
                ),
                NavigationDestination(
                  icon: const Icon(Icons.manage_search_rounded),
                  selectedIcon: const Icon(Icons.manage_search_rounded),
                  label: s.navHistory,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
