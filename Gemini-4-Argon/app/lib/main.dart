import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'src/ui/app_state.dart';
import 'src/ui/screens/cycle_tab.dart';
import 'src/ui/screens/history_settings_tab.dart';
import 'src/ui/screens/nutrition_tab.dart';
import 'src/ui/screens/overview_tab.dart';
import 'src/ui/screens/weight_symptoms_tab.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final controller = MorphHealthController();
  await controller.init();
  runApp(MorphHealthApp(controller: controller));
}

class MorphHealthApp extends StatelessWidget {
  final MorphHealthController controller;

  const MorphHealthApp({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final lang = controller.isInitialized ? controller.lang : 'de';
        const seedColor = Color(0xFF2E6F65);

        return MaterialApp(
          title: 'MorphHealth',
          debugShowCheckedModeBanner: false,
          locale: Locale(lang),
          supportedLocales: const [
            Locale('de'),
            Locale('en'),
          ],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: seedColor,
              brightness: Brightness.light,
            ),
            cardTheme: CardThemeData(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(
                  color: Colors.teal.withValues(alpha: 0.16),
                ),
              ),
            ),
          ),
          home: MorphHealthHomeShell(controller: controller),
        );
      },
    );
  }
}

class MorphHealthHomeShell extends StatefulWidget {
  final MorphHealthController controller;

  const MorphHealthHomeShell({super.key, required this.controller});

  @override
  State<MorphHealthHomeShell> createState() => _MorphHealthHomeShellState();
}

class _MorphHealthHomeShellState extends State<MorphHealthHomeShell> {
  int _selectedIndex = 0;

  Future<void> _pickDate(BuildContext context) async {
    final ctrl = widget.controller;
    final initial =
        DateTime.tryParse('${ctrl.selectedDate}T00:00:00Z') ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2015, 1, 1),
      lastDate: DateTime(2035, 12, 31),
    );
    if (picked != null) {
      final y = picked.year.toString().padLeft(4, '0');
      final m = picked.month.toString().padLeft(2, '0');
      final d = picked.day.toString().padLeft(2, '0');
      ctrl.setSelectedDate('$y-$m-$d');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.controller;
    if (!ctrl.isInitialized) {
      return Scaffold(
        body: Center(
          child: ctrl.initError != null
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Error: ${ctrl.initError}'),
                )
              : const CircularProgressIndicator(),
        ),
      );
    }

    final s = ctrl.s;
    final isToday = ctrl.selectedDate == ctrl.repository.todayYmd;

    final pages = <Widget>[
      OverviewTab(
        ctrl: ctrl,
        onNavigateTab: (idx) => setState(() => _selectedIndex = idx),
      ),
      NutritionTab(ctrl: ctrl),
      CycleTab(ctrl: ctrl),
      WeightSymptomsTab(ctrl: ctrl),
      HistorySettingsTab(ctrl: ctrl),
    ];

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 12,
        title: const Text(
          'MorphHealth',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ),
        actions: [
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 36),
            tooltip: s.t('Vorheriger Tag', 'Previous Day'),
            icon: const Icon(Icons.chevron_left, size: 20),
            onPressed: () => ctrl.shiftSelectedDate(-1),
          ),
          TextButton.icon(
            style: TextButton.styleFrom(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 6),
            ),
            icon: const Icon(Icons.event, size: 15),
            label: Text(
              ctrl.selectedDate,
              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
            ),
            onPressed: () => _pickDate(context),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 32, minHeight: 36),
            tooltip: s.t('Nächster Tag', 'Next Day'),
            icon: const Icon(Icons.chevron_right, size: 20),
            onPressed: () => ctrl.shiftSelectedDate(1),
          ),
          if (!isToday)
            TextButton(
              style: TextButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                minimumSize: const Size(36, 32),
              ),
              onPressed: ctrl.jumpToToday,
              child: Text(s.today, style: const TextStyle(fontSize: 12)),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 8, left: 2),
            child: ActionChip(
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 4),
              tooltip: s.t('Sprache wechseln', 'Switch Language'),
              label: Text(
                ctrl.lang.toUpperCase(),
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onPressed: () =>
                  ctrl.setLanguage(ctrl.lang == 'de' ? 'en' : 'de'),
            ),
          ),
        ],
      ),
      body: pages[_selectedIndex],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (idx) => setState(() => _selectedIndex = idx),
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
            icon: const Icon(Icons.favorite_outline),
            selectedIcon: const Icon(Icons.favorite),
            label: s.navCycle,
          ),
          NavigationDestination(
            icon: const Icon(Icons.monitor_weight_outlined),
            selectedIcon: const Icon(Icons.monitor_weight),
            label: s.navWeightSymptoms,
          ),
          NavigationDestination(
            icon: const Icon(Icons.history_outlined),
            selectedIcon: const Icon(Icons.history),
            label: s.navHistorySettings,
          ),
        ],
      ),
    );
  }
}
