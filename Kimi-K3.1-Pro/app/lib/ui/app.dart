import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import '../core/food_api.dart';
import '../core/repository.dart';
import 'controller.dart';
import 'cycle_ui.dart';
import 'history_ui.dart';
import 'l10n.dart';
import 'nutrition_ui.dart';
import 'overview.dart';
import 'settings_ui.dart';

class MorphHealthApp extends StatelessWidget {
  const MorphHealthApp({
    super.key,
    required this.repository,
    required this.foodApi,
  });

  final HealthRepository repository;
  final FoodApi foodApi;

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (_) => AppController(repository, foodApi),
    child: Consumer<AppController>(
      builder: (context, controller, _) => MaterialApp(
        title: 'MorphHealth',
        debugShowCheckedModeBanner: false,
        locale: Locale(controller.settings.language),
        supportedLocales: const [Locale('de'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: _theme(Brightness.light),
        darkTheme: _theme(Brightness.dark),
        themeMode: ThemeMode.system,
        home: const MainShell(),
      ),
    ),
  );
}

ThemeData _theme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF296A63),
    brightness: brightness,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: brightness == Brightness.light
        ? const Color(0xFFFAFAF7)
        : scheme.surface,
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
    ),
    cardTheme: const CardThemeData(elevation: 0.5),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
  );
}

class MainShell extends StatelessWidget {
  const MainShell({super.key});

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<AppController>();
    final strings = l10n(context);
    return Scaffold(
      body: IndexedStack(
        index: controller.navigationIndex,
        children: const [
          OverviewPage(),
          NutritionPage(),
          CyclePage(),
          HistoryPage(),
          SettingsPage(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: controller.navigationIndex,
        onDestinationSelected: controller.navigate,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.home_outlined),
            selectedIcon: const Icon(Icons.home),
            label: strings.t('overview'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.restaurant_outlined),
            selectedIcon: const Icon(Icons.restaurant),
            label: strings.t('nutrition'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.calendar_month_outlined),
            selectedIcon: const Icon(Icons.calendar_month),
            label: strings.t('cycle'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.history),
            selectedIcon: const Icon(Icons.manage_search),
            label: strings.t('history'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: strings.t('settings'),
          ),
        ],
      ),
    );
  }
}

class StartupErrorApp extends StatelessWidget {
  const StartupErrorApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    debugShowCheckedModeBanner: false,
    supportedLocales: const [Locale('de'), Locale('en')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_outline, size: 48),
              const SizedBox(height: 20),
              Text(
                const S(Locale('de')).t('startup_error'),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                const S(Locale('en')).t('startup_error'),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
