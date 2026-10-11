// Einstellungen: Darstellung (Sprache, Gewichtseinheit), sichtbare Bereiche,
// Tagesziele, Daten-Transfer und Über-die-App-Informationen.
library;

import 'package:flutter/material.dart';

import '../data/repository.dart';
import '../l10n/app_strings.dart';
import '../model/document.dart';
import '../model/settings.dart';
import 'bootstrap.dart';
import 'data_transfer_screen.dart';
import 'scope.dart';
import 'widgets.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = StringsScope.of(context);
    final MorphRepository repo = MorphScope.repoOf(context);
    final AppInfo appInfo = MorphScope.appInfoOf(context);
    return Scaffold(
      appBar: AppBar(title: Text(strings.settingsTitle)),
      body: ListenableBuilder(
        listenable: MorphScope.listenableOf(context),
        builder: (BuildContext context, Widget? _) {
          final AppSettings settings = repo.settings;
          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: <Widget>[
              _appearanceSection(strings, repo, settings),
              _areasSection(context, strings, repo, settings),
              _goalsSection(context, strings, repo, settings),
              _foodApiSection(context, strings),
              _dataSection(context, strings),
              _aboutSection(context, strings, appInfo),
            ],
          );
        },
      ),
    );
  }

  // --------------------------------------------------------- Darstellung

  Widget _appearanceSection(
      AppStrings strings, MorphRepository repo, AppSettings settings) {
    return SectionCard(
      title: strings.appearanceSection,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(strings.languageLabel),
          const SizedBox(height: 4),
          SegmentedButton<String?>(
            segments: <ButtonSegment<String?>>[
              ButtonSegment<String?>(
                  value: null, label: Text(strings.languageSystem)),
              ButtonSegment<String?>(
                  value: 'de', label: Text(strings.languageDe)),
              ButtonSegment<String?>(
                  value: 'en', label: Text(strings.languageEn)),
            ],
            selected: <String?>{settings.language},
            onSelectionChanged: (Set<String?> v) {
              repo.updateSettings((AppSettings s) => s..language = v.first);
            },
          ),
          const SizedBox(height: 16),
          Text(strings.weightUnitLabel),
          const SizedBox(height: 4),
          SegmentedButton<String>(
            segments: <ButtonSegment<String>>[
              ButtonSegment<String>(
                  value: 'kg', label: Text(strings.unitKg)),
              ButtonSegment<String>(
                  value: 'lb', label: Text(strings.unitLb)),
            ],
            selected: <String>{settings.weightUnit},
            onSelectionChanged: (Set<String> v) {
              repo.updateSettings((AppSettings s) => s..weightUnit = v.first);
            },
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------- Sichtbare Bereiche

  Widget _areasSection(BuildContext context, AppStrings strings,
      MorphRepository repo, AppSettings settings) {
    return SectionCard(
      title: strings.areasSection,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (final String area in areaKeys)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(strings.areaName(area)),
              value: settings.isAreaVisible(area),
              onChanged: (bool v) {
                final List<String> next =
                    List<String>.of(settings.visibleAreas);
                if (v) {
                  if (!next.contains(area)) next.add(area);
                } else {
                  // Mindestens ein Bereich muss sichtbar bleiben.
                  if (next.length <= 1) {
                    showError(context, strings.areasHint);
                    return;
                  }
                  next.remove(area);
                }
                repo.updateSettings((AppSettings s) => s..visibleAreas = next);
              },
            ),
          Text(strings.areasHint,
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  // --------------------------------------------------------- Tagesziele

  Widget _goalsSection(BuildContext context, AppStrings strings,
      MorphRepository repo, AppSettings settings) {
    final Goals goals = settings.goals;
    return SectionCard(
      title: strings.goalsSection,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          _GoalField(
            label: '${strings.goalWaterLabel} (ml)',
            initial: goals.waterMl,
            onSave: (double? v) => repo.updateSettings((AppSettings s) =>
                s
                  ..goals = Goals(
                    waterMl: v,
                    energyKcal: s.goals.energyKcal,
                    proteinG: s.goals.proteinG,
                    carbohydratesG: s.goals.carbohydratesG,
                    fatG: s.goals.fatG,
                  )),
          ),
          _GoalField(
            label: '${strings.goalEnergyLabel} (kcal)',
            initial: goals.energyKcal,
            onSave: (double? v) => repo.updateSettings((AppSettings s) =>
                s
                  ..goals = Goals(
                    waterMl: s.goals.waterMl,
                    energyKcal: v,
                    proteinG: s.goals.proteinG,
                    carbohydratesG: s.goals.carbohydratesG,
                    fatG: s.goals.fatG,
                  )),
          ),
          _GoalField(
            label: '${strings.goalProteinLabel} (g)',
            initial: goals.proteinG,
            onSave: (double? v) => repo.updateSettings((AppSettings s) =>
                s
                  ..goals = Goals(
                    waterMl: s.goals.waterMl,
                    energyKcal: s.goals.energyKcal,
                    proteinG: v,
                    carbohydratesG: s.goals.carbohydratesG,
                    fatG: s.goals.fatG,
                  )),
          ),
          _GoalField(
            label: '${strings.goalCarbsLabel} (g)',
            initial: goals.carbohydratesG,
            onSave: (double? v) => repo.updateSettings((AppSettings s) =>
                s
                  ..goals = Goals(
                    waterMl: s.goals.waterMl,
                    energyKcal: s.goals.energyKcal,
                    proteinG: s.goals.proteinG,
                    carbohydratesG: v,
                    fatG: s.goals.fatG,
                  )),
          ),
          _GoalField(
            label: '${strings.goalFatLabel} (g)',
            initial: goals.fatG,
            onSave: (double? v) => repo.updateSettings((AppSettings s) =>
                s
                  ..goals = Goals(
                    waterMl: s.goals.waterMl,
                    energyKcal: s.goals.energyKcal,
                    proteinG: s.goals.proteinG,
                    carbohydratesG: s.goals.carbohydratesG,
                    fatG: v,
                  )),
          ),
          const SizedBox(height: 4),
          Text(strings.goalsHint,
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  // ---------------------------------------------------- Lebensmittel-API

  Widget _foodApiSection(BuildContext context, AppStrings strings) {
    return SectionCard(
      title: strings.foodApiSection,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          StatRow(label: strings.foodApiOrigin, value: foodBaseUrl),
          StatRow(label: strings.foodApiUserAgent, value: foodUserAgent),
          const SizedBox(height: 4),
          Text(strings.foodApiOfflineHint,
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }

  // -------------------------------------------------------------- Daten

  Widget _dataSection(BuildContext context, AppStrings strings) {
    return SectionCard(
      title: strings.dataSection,
      child: Column(
        children: <Widget>[
          _dataTile(context, strings.exportData, Icons.upload_outlined, 0),
          _dataTile(context, strings.importData, Icons.download_outlined, 0),
          _dataTile(context, strings.backupCreate, Icons.lock_outlined, 1),
          _dataTile(context, strings.backupRestore, Icons.lock_open_outlined, 2),
          _dataTile(
              context, strings.deleteAll, Icons.delete_forever_outlined, 3),
        ],
      ),
    );
  }

  Widget _dataTile(
      BuildContext context, String title, IconData icon, int section) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(title),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<Widget>(
          builder: (_) => DataTransferScreen(initialSection: section),
        ),
      ),
    );
  }

  // -------------------------------------------------------------- About

  Widget _aboutSection(BuildContext context, AppStrings strings, AppInfo appInfo) {
    return SectionCard(
      title: strings.aboutSection,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          StatRow(label: strings.aboutVersion, value: appInfo.version),
          const SizedBox(height: 8),
          Text(strings.aboutPrivacy,
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(strings.aboutOffline,
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 4),
          Text(strings.offLicenseFull,
              style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ Ziele

/// Ein Tagesziel-Feld: leer = kein Ziel, sonst Zahl in der Einheit.
class _GoalField extends StatefulWidget {
  final String label;
  final double? initial;
  final ValueChanged<double?> onSave;

  const _GoalField({
    required this.label,
    required this.initial,
    required this.onSave,
  });

  @override
  State<_GoalField> createState() => _GoalFieldState();
}

class _GoalFieldState extends State<_GoalField> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.initial == null
          ? ''
          : _formatInitial(widget.initial!),
    );
  }

  String _formatInitial(double v) {
    // Vor der ersten Bildschirm-Anzeige steht die Sprache noch nicht fest;
    // die lokalisierte Formatierung erfolgt in build() über den Controller.
    return v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toStringAsFixed(1);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Initiale Anzeige lokalisiert formatieren (einmalig pro Wert).
    final AppStrings strings = StringsScope.of(context);
    final String formatted = widget.initial == null
        ? ''
        : strings.formatNumber(widget.initial!, fractionDigits: 0);
    if (_controller.text != formatted) {
      _controller.text = formatted;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = StringsScope.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: NumberField(
        controller: _controller,
        label: widget.label,
        hint: strings.noGoal,
        onSubmitted: (_) => _save(strings),
      ),
    );
  }

  void _save(AppStrings strings) {
    final String text = _controller.text.trim();
    if (text.isEmpty) {
      widget.onSave(null);
      return;
    }
    final double? v = NumberField.parse(strings, text);
    if (v == null || v < 0) {
      showError(context, strings.invalidNumber);
      _controller.text = widget.initial == null
          ? ''
          : strings.formatNumber(widget.initial!, fractionDigits: 0);
      return;
    }
    widget.onSave(v);
  }
}
