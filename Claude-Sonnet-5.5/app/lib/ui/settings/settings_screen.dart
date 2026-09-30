import 'package:flutter/material.dart';

import '../../core/core.dart';
import '../../core/food_api.dart';
import '../../core/models.dart';
import '../../core/portable.dart' show kAppVersion;
import '../../state/app_state.dart';
import '../l10n_x.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'data_screen.dart';
import 'goals_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final l = context.l10n;
    final s = app.settings;
    Future<void> save(AppSettings next) => app.db.saveSettings(next);
    Widget heading(String text) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Semantics(
        header: true,
        child: Text(text, style: context.text.titleSmall?.copyWith(color: context.colors.primary)),
      ),
    );
    return AppScaffold(
      appBar: AppBar(title: Text(l.settingsTitle)),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          heading(l.settingsLanguage),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<String>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: 'de', label: Text(l.langGerman)),
                ButtonSegment(value: 'en', label: Text(l.langEnglish)),
              ],
              selected: {s.language},
              onSelectionChanged: (v) => save(s.copyWith(language: v.first)),
            ),
          ),
          heading(l.settingsTheme),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<String>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: 'system', label: Text(l.themeSystem)),
                ButtonSegment(value: 'light', label: Text(l.themeLight)),
                ButtonSegment(value: 'dark', label: Text(l.themeDark)),
              ],
              selected: {s.theme},
              onSelectionChanged: (v) => save(s.copyWith(theme: v.first)),
            ),
          ),
          heading(l.settingsWeightUnit),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: SegmentedButton<WeightUnit>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: WeightUnit.kg, label: Text(l.unitKg)),
                ButtonSegment(value: WeightUnit.lb, label: Text(l.unitLb)),
              ],
              selected: {s.weightUnit},
              onSelectionChanged: (v) => save(s.copyWith(weightUnit: v.first)),
            ),
          ),
          heading(l.settingsAreas),
          for (final a in Area.values)
            SwitchListTile(
              secondary: Icon(areaIcon(a), color: areaColor(a, context.theme.brightness)),
              title: Text(l.area(a)),
              value: s.shows(a),
              onChanged: (v) {
                final next = {...s.areas};
                v ? next.add(a) : next.remove(a);
                save(s.copyWith(areas: next));
              },
            ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: EmptyHint(l.overviewCustomizeHint, icon: Icons.info_outline),
          ),
          heading(l.settingsGoals),
          ListTile(
            leading: const Icon(Icons.flag_outlined),
            title: Text(l.settingsGoals),
            subtitle: Text(l.settingsGoalsSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const GoalsScreen())),
          ),
          heading(l.settingsCycleSection),
          SwitchListTile(
            title: Text(l.settingsForecast),
            subtitle: Text(l.settingsForecastHint),
            value: s.cycleForecast,
            onChanged: (v) => save(s.copyWith(cycleForecast: v)),
          ),
          const _ExpectedCycleField(),
          heading(l.settingsOnlineSection),
          SwitchListTile(
            title: Text(l.settingsOnlineSwitch),
            subtitle: Text(l.settingsOnlineHint),
            value: s.onlineFood,
            onChanged: (v) => save(s.copyWith(onlineFood: v)),
          ),
          const _ServerField(),
          heading(l.settingsPrivacySection),
          SwitchListTile(
            title: Text(l.settingsSecure),
            subtitle: Text(l.settingsSecureHint),
            value: s.secureScreen,
            onChanged: (v) => save(s.copyWith(secureScreen: v)),
          ),
          heading(l.settingsData),
          ListTile(
            leading: const Icon(Icons.lock_outline),
            title: Text(l.settingsData),
            subtitle: Text(l.settingsDataSubtitle),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DataScreen())),
          ),
          heading(l.settingsAbout),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.aboutText, style: context.text.bodyMedium),
                const SizedBox(height: 8),
                Text(l.aboutMedical, style: context.text.bodyMedium),
                const SizedBox(height: 8),
                Text(l.aboutVersion(kAppVersion), style: context.text.bodySmall),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: Text(l.aboutLicenses),
            onTap: () => showLicensePage(context: context, applicationName: l.appName, applicationVersion: kAppVersion),
          ),
        ],
      ),
    );
  }
}

/// Typische Zykluslänge, solange noch keine eigene Historie vorliegt.
class _ExpectedCycleField extends StatefulWidget {
  const _ExpectedCycleField();

  @override
  State<_ExpectedCycleField> createState() => _ExpectedCycleFieldState();
}

class _ExpectedCycleFieldState extends State<_ExpectedCycleField> {
  late final TextEditingController _c;
  String? _error;
  bool _init = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_init) return;
    _init = true;
    final v = AppScope.read(context).settings.expectedCycleLength;
    _c = TextEditingController(text: v == null ? '' : '$v');
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _commit() async {
    final app = AppScope.read(context);
    final l = context.l10n;
    final t = _c.text.trim();
    if (t.isEmpty) {
      setState(() => _error = null);
      await app.db.saveSettings(app.settings.copyWith(expectedCycleLength: () => null));
      return;
    }
    final v = int.tryParse(t);
    if (v == null || v < 15 || v > 60) {
      setState(() => _error = l.settingsExpectedCycleHint);
      return;
    }
    setState(() => _error = null);
    await app.db.saveSettings(app.settings.copyWith(expectedCycleLength: () => v));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: TextField(
        controller: _c,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _commit(),
        onTapOutside: (_) => _commit(),
        decoration: InputDecoration(
          labelText: l.settingsExpectedCycle,
          helperText: l.settingsExpectedCycleHint,
          helperMaxLines: 3,
          errorText: _error,
          errorMaxLines: 3,
        ),
      ),
    );
  }
}

/// Ursprung der Lebensmittel-API. Leer bedeutet: Vorgabe des Builds.
class _ServerField extends StatefulWidget {
  const _ServerField();

  @override
  State<_ServerField> createState() => _ServerFieldState();
}

class _ServerFieldState extends State<_ServerField> {
  late final TextEditingController _c;
  String? _error;
  bool _init = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_init) return;
    _init = true;
    _c = TextEditingController(text: AppScope.read(context).settings.foodBaseUrl ?? '');
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _commit() async {
    final app = AppScope.read(context);
    final l = context.l10n;
    final t = _c.text.trim();
    if (t.isEmpty) {
      setState(() => _error = null);
      await app.db.saveSettings(app.settings.copyWith(foodBaseUrl: () => null));
      return;
    }
    try {
      final u = FoodApi.parseBaseUrl(t);
      setState(() => _error = null);
      await app.db.saveSettings(app.settings.copyWith(foodBaseUrl: () => u.toString()));
      if (mounted) showMessage(context, l.settingsServerSaved);
    } on FoodApiException {
      setState(() => _error = l.settingsServerInvalid);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
      child: ControlGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _c,
              keyboardType: TextInputType.url,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _commit(),
              onTapOutside: (_) => _commit(),
              decoration: InputDecoration(
                labelText: l.settingsServer,
                hintText: kDefaultFoodBaseUrl,
                helperText: l.settingsServerDefault(kDefaultFoodBaseUrl),
                helperMaxLines: 2,
                errorText: _error,
                errorMaxLines: 3,
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () {
                  _c.clear();
                  _commit();
                },
                child: Text(l.settingsServerReset),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
