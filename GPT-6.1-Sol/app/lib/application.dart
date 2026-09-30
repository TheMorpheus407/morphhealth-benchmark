import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/engine.dart';
import 'core/food_api.dart';
import 'core/model.dart';
import 'core/storage.dart';
import 'platform_bridge.dart';
import 'ui/common.dart';
import 'ui/controller.dart';
import 'ui/cycle_screen.dart';
import 'ui/food_screens.dart';
import 'ui/history_screen.dart';
import 'ui/overview.dart';
import 'ui/settings_screen.dart';
import 'ui/editors.dart';

const configuredFoodBase = String.fromEnvironment(
  'FOOD_BASE_URL',
  defaultValue: 'https://world.openfoodfacts.org',
);
const configuredFoodAgent = String.fromEnvironment(
  'FOOD_USER_AGENT',
  defaultValue: 'MorphHealth/1.0 (Android local journal)',
);

Future<void> startMorphHealth() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('de');
  await initializeDateFormatting('en');
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
    ),
  );
  runApp(const MorphHealthBoot());
}

ThemeData healthTheme() {
  final colors = ColorScheme.fromSeed(
    seedColor: ink,
    brightness: Brightness.light,
    surface: canvas,
    primary: ink,
    secondary: rose,
  );
  return ThemeData(
    useMaterial3: true,
    colorScheme: colors,
    scaffoldBackgroundColor: canvas,
    appBarTheme: const AppBarTheme(
      backgroundColor: canvas,
      foregroundColor: ink,
      centerTitle: false,
      scrolledUnderElevation: 0,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(22),
        side: const BorderSide(color: Color(0xffe1e7df)),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.white,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
    ),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: Colors.white,
      indicatorColor: sage,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    textTheme: const TextTheme(
      headlineLarge: TextStyle(
        fontSize: 36,
        fontWeight: FontWeight.w600,
        letterSpacing: -1,
        color: ink,
      ),
      headlineMedium: TextStyle(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        letterSpacing: -.6,
        color: ink,
      ),
      titleLarge: TextStyle(
        fontSize: 21,
        fontWeight: FontWeight.w600,
        color: ink,
      ),
      titleMedium: TextStyle(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: ink,
      ),
      bodyMedium: TextStyle(fontSize: 14, height: 1.5, color: ink),
      bodySmall: TextStyle(fontSize: 12, height: 1.4, color: Color(0xff52645c)),
    ),
  );
}

class MorphHealthBoot extends StatefulWidget {
  const MorphHealthBoot({super.key});
  @override
  State<MorphHealthBoot> createState() => _MorphHealthBootState();
}

class _MorphHealthBootState extends State<MorphHealthBoot> {
  AppController? controller;
  bool failed = false;
  @override
  void initState() {
    super.initState();
    open();
  }

  Future<void> open() async {
    if (mounted) setState(() => failed = false);
    try {
      final native = await PlatformBridge.vault();
      final engine = await HealthEngine.open(
        VaultStore(Directory(native['directory']), base64Decode(native['key'])),
      );
      if (mounted) {
        setState(
          () => controller = AppController(
            engine,
            FoodApi(configuredFoodBase, configuredFoodAgent),
          ),
        );
      }
    } catch (_) {
      if (mounted) setState(() => failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (controller != null) return MorphHealthApp(controller: controller!);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: healthTheme(),
      locale: const Locale('de'),
      supportedLocales: const [Locale('de'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: failed
          ? RecoveryScreen(retry: open)
          : const Scaffold(
              body: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.spa_outlined, size: 48, color: ink),
                    SizedBox(height: 16),
                    Text(
                      'MorphHealth',
                      style: TextStyle(fontSize: 26, color: ink),
                    ),
                    SizedBox(height: 24),
                    CircularProgressIndicator(),
                  ],
                ),
              ),
            ),
    );
  }
}

class MorphHealthApp extends StatelessWidget {
  final AppController controller;
  const MorphHealthApp({super.key, required this.controller});
  @override
  Widget build(BuildContext context) => AppScope(
    controller: controller,
    child: AnimatedBuilder(
      animation: controller,
      builder: (context, _) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'MorphHealth',
        theme: healthTheme(),
        locale: Locale(controller.language),
        supportedLocales: const [Locale('de'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const AppShell(),
      ),
    ),
  );
}

class AppShell extends StatelessWidget {
  const AppShell({super.key});
  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final titles = [
      'MorphHealth',
      c.tr('Ernährung', 'Nutrition'),
      c.tr('Zyklus', 'Cycle'),
      c.tr('Historie & Verläufe', 'History & trends'),
      c.tr('Einstellungen', 'Settings'),
    ];
    return Scaffold(
      floatingActionButton: c.tab == 0
          ? FloatingActionButton.extended(
              tooltip: c.tr('Eintrag erfassen', 'Add entry'),
              onPressed: () async {
                final choice = await showModalBottomSheet<String>(
                  context: context,
                  showDragHandle: true,
                  builder: (ctx) => SafeArea(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        for (final item in [
                          'food',
                          'water',
                          'caffeine',
                          'periods',
                          'weights',
                          'symptoms',
                        ])
                          ListTile(
                            leading: Icon(switch (item) {
                              'food' => Icons.restaurant_outlined,
                              'water' => Icons.water_drop_outlined,
                              'caffeine' => Icons.coffee_outlined,
                              'periods' => Icons.calendar_month_outlined,
                              'weights' => Icons.monitor_weight_outlined,
                              _ => Icons.spa_outlined,
                            }),
                            title: Text(switch (item) {
                              'food' => c.tr('Lebensmittel', 'Food'),
                              'water' => c.tr('Wasser', 'Water'),
                              'caffeine' => c.tr('Koffein', 'Caffeine'),
                              'periods' => c.tr('Periode', 'Period'),
                              'weights' => c.tr('Gewicht', 'Weight'),
                              _ => c.tr('Symptom', 'Symptom'),
                            }),
                            onTap: () => Navigator.pop(ctx, item),
                          ),
                      ],
                    ),
                  ),
                );
                if (choice == null || !context.mounted) return;
                if (choice == 'food') {
                  await pickFood(context);
                } else if (choice == 'water' || choice == 'caffeine') {
                  await editRecord(
                    context,
                    'drinks',
                    record: <String, dynamic>{
                      'id': newId(),
                      'kind': choice,
                      'at': atTime(
                        c.selectedDay,
                        TimeOfDay.fromDateTime(c.engine.clock.now),
                      ),
                      'amount': 0,
                    },
                  );
                } else {
                  await editRecord(context, choice);
                }
              },
              icon: const Icon(Icons.add),
              label: Text(c.tr('Erfassen', 'Add')),
            )
          : null,
      appBar: AppBar(
        title: Text(titles[c.tab]),
        actions: [
          if (c.tab != 4)
            IconButton(
              tooltip: c.tr('Einstellungen', 'Settings'),
              onPressed: () => c.navigate(4),
              icon: const Icon(Icons.tune),
            ),
        ],
      ),
      body: SafeArea(
        child: IndexedStack(
          index: c.tab,
          children: const [
            Overview(),
            FoodDiary(),
            CycleScreen(),
            HistoryScreen(),
            SettingsScreen(),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: c.tab,
        onDestinationSelected: c.navigate,
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.grid_view_outlined),
            selectedIcon: const Icon(Icons.grid_view),
            label: c.tr('Übersicht', 'Overview'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.restaurant_outlined),
            selectedIcon: const Icon(Icons.restaurant),
            label: c.tr('Ernährung', 'Nutrition'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.calendar_month_outlined),
            selectedIcon: const Icon(Icons.calendar_month),
            label: c.tr('Zyklus', 'Cycle'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.timeline_outlined),
            selectedIcon: const Icon(Icons.timeline),
            label: c.tr('Historie', 'History'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: c.tr('Optionen', 'Settings'),
          ),
        ],
      ),
    );
  }
}

class RecoveryScreen extends StatefulWidget {
  final Future<void> Function() retry;
  const RecoveryScreen({super.key, required this.retry});
  @override
  State<RecoveryScreen> createState() => _RecoveryScreenState();
}

class _RecoveryScreenState extends State<RecoveryScreen> {
  bool english = false, busy = false;
  String? error;
  String t(String de, String en) => english ? en : de;
  Future<bool> confirmation() async =>
      await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(
            t('Lokalen Speicher zurücksetzen?', 'Reset local storage?'),
          ),
          content: Text(
            t(
              'Die unlesbaren lokalen Daten und ihr Schlüssel werden gelöscht. Sichere vorhandene Dateien, falls du sie später untersuchen möchtest.',
              'The unreadable local data and their key will be deleted. Keep any files you may want to investigate later.',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(t('Abbrechen', 'Cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(t('Zurücksetzen', 'Reset')),
            ),
          ],
        ),
      ) ??
      false;
  Future<void> reset({bool restore = false}) async {
    setState(() {
      busy = true;
      error = null;
    });
    try {
      HealthData? restored;
      if (restore) {
        final bytes = await PlatformBridge.openDocument();
        if (bytes == null || !mounted) {
          if (mounted) setState(() => busy = false);
          return;
        }
        final input = object(jsonDecode(utf8.decode(bytes)), 'backup');
        final pass = TextEditingController();
        final secret = await showDialog<String>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: Text(t('Sicherung entsperren', 'Unlock backup')),
            content: TextField(
              controller: pass,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(labelText: 'Passphrase'),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(t('Abbrechen', 'Cancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, pass.text),
                child: Text(t('Weiter', 'Continue')),
              ),
            ],
          ),
        );
        Future.delayed(const Duration(milliseconds: 400), pass.dispose);
        if (secret == null || !mounted) {
          if (mounted) setState(() => busy = false);
          return;
        }
        restored = await restoreBackup(input, secret);
      }
      if (!mounted || !await confirmation()) {
        if (mounted) setState(() => busy = false);
        return;
      }
      await PlatformBridge.resetStorage();
      if (restored != null) {
        final native = await PlatformBridge.vault();
        await VaultStore(
          Directory(native['directory']),
          base64Decode(native['key']),
        ).write(restored);
      }
      await widget.retry();
    } catch (_) {
      if (mounted) {
        setState(
          () => error = t(
            'Wiederherstellung fehlgeschlagen. Prüfe Datei und Passphrase.',
            'Recovery failed. Check the file and passphrase.',
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('MorphHealth'),
      actions: [
        TextButton(
          onPressed: () => setState(() => english = !english),
          child: Text(english ? 'Deutsch' : 'English'),
        ),
      ],
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Icon(Icons.lock_outline, size: 48, color: ink),
          const SizedBox(height: 20),
          Text(
            t(
              'Lokale Daten konnten nicht geöffnet werden.',
              'Local data could not be opened.',
            ),
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 12),
          Text(
            t(
              'Deine Dateien bleiben erhalten. Versuche es erneut oder stelle eine verschlüsselte Sicherung wieder her.',
              'Your files are preserved. Retry or restore an encrypted backup.',
            ),
          ),
          if (error != null)
            Padding(padding: const EdgeInsets.all(12), child: Text(error!)),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: busy ? null : widget.retry,
            child: Text(t('Erneut versuchen', 'Retry')),
          ),
          OutlinedButton(
            onPressed: busy ? null : () => reset(restore: true),
            child: Text(t('Sicherung wiederherstellen', 'Restore backup')),
          ),
          TextButton(
            onPressed: busy ? null : reset,
            child: Text(t('Lokale Daten löschen', 'Delete local data')),
          ),
          if (busy) const Center(child: CircularProgressIndicator()),
        ],
      ),
    ),
  );
}
