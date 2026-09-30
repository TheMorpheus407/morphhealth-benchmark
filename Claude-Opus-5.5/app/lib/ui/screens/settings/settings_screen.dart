import 'package:flutter/material.dart';

import '../../../core/food/off_client.dart';
import '../../../core/l10n/format.dart';
import '../../../core/model/enums.dart';
import '../../../core/model/settings.dart';
import '../../../core/service/morphhealth_service.dart';
import '../../controller.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/inputs.dart';
import 'data_actions.dart';

/// Language, units, goals, overview areas, quick entry, cycle mode, online
/// food search, data management and information.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final s = app.s;
    final settings = app.settings;
    final goals = settings.goals;
    final fmt = app.fmt;
    String goalText() {
      final parts = [
        if (goals.energyKcal != null) '${fmt.integer(goals.energyKcal!)} kcal',
        if (goals.proteinG != null) '${fmt.number(goals.proteinG!, 0)} g ${s.nutrientName('protein_g')}',
        if (goals.carbohydratesG != null) '${fmt.number(goals.carbohydratesG!, 0)} g ${s.nutrientName('carbohydrates_g')}',
        if (goals.fatG != null) '${fmt.number(goals.fatG!, 0)} g ${s.nutrientName('fat_g')}',
        if (goals.waterMl != null) '${fmt.integer(goals.waterMl!)} ml ${s.water}',
      ];
      return parts.isEmpty ? s.noGoal : parts.join(' · ');
    }

    return Scaffold(
      appBar: AppBar(title: Text(s.settingsTitle)),
      body: ListView(
        padding: pagePadding(context, horizontal: 0, top: 0),
        children: [
          ListTile(
            leading: const Icon(Icons.language),
            title: Text(s.languageLabel),
            subtitle: Text(s.languageName),
            onTap: () => _chooseLanguage(context),
          ),
          ListHeader(s.units),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(child: Text(s.weightUnit)),
                SegmentedButton<WeightUnit>(
                  segments: const [
                    ButtonSegment(value: WeightUnit.kg, label: Text('kg')),
                    ButtonSegment(value: WeightUnit.lb, label: Text('lb')),
                  ],
                  selected: {settings.weightUnit},
                  onSelectionChanged: (v) => app.updateSettings(settings.copyWith(weightUnit: v.first)),
                ),
              ],
            ),
          ),
          ListHeader(s.dailyGoals),
          ListTile(
            leading: const Icon(Icons.flag_outlined),
            title: Text(s.dailyGoals),
            subtitle: Text(goalText()),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const GoalsEditor()),
            ),
          ),
          ListHeader(s.overviewAreas),
          for (final area in Area.values)
            SwitchListTile(
              secondary: Icon(areaIcon(area), color: context.colors.area(area)),
              title: Text(s.areaName(area)),
              value: settings.overviewAreas.contains(area),
              onChanged: (on) {
                final next = {...settings.overviewAreas};
                on ? next.add(area) : next.remove(area);
                app.updateSettings(settings.copyWith(overviewAreas: next));
              },
            ),
          ListHeader(s.quickAmounts),
          ListTile(
            leading: Icon(Icons.local_drink_outlined, color: context.colors.water),
            title: Text(s.waterQuickAmounts),
            subtitle: Text(settings.waterQuickMl.join(', ')),
            onTap: () => _editQuick(context, water: true),
          ),
          ListTile(
            leading: Icon(Icons.coffee_outlined, color: context.colors.symptoms),
            title: Text(s.caffeineQuickAmounts),
            subtitle: Text(settings.caffeineQuickMg.join(', ')),
            onTap: () => _editQuick(context, water: false),
          ),
          ListHeader(s.cycleSettings),
          SwitchListTile(
            secondary: Icon(Icons.insights_outlined, color: context.colors.cycle),
            title: Text(s.predictionsSwitch),
            subtitle: Text(s.predictionsHint),
            value: settings.cyclePredictions,
            onChanged: (v) => app.updateSettings(settings.copyWith(cyclePredictions: v)),
          ),
          ListHeader(s.onlineSection),
          SwitchListTile(
            secondary: const Icon(Icons.travel_explore),
            title: Text(s.onlineSwitch),
            subtitle: Text(s.onlineHint),
            value: settings.onlineFoodSearch,
            onChanged: (v) => app.updateSettings(settings.copyWith(onlineFoodSearch: v)),
          ),
          ListTile(
            leading: const Icon(Icons.dns_outlined),
            title: Text(s.serverOrigin),
            subtitle: Text('${app.service.foodApiConfig.baseUrl}\n${s.userAgent}: ${app.service.foodApiConfig.userAgent}'),
            isThreeLine: true,
            enabled: settings.onlineFoodSearch,
            onTap: () => _editServer(context),
          ),
          ListHeader(s.dataSection),
          ListTile(
            leading: const Icon(Icons.storage_outlined),
            title: Text(s.storageInfo),
            subtitle: Text(s.dataCounts(app.data.diaryEntryCount, app.data.foods.length)),
          ),
          ListTile(
            leading: const Icon(Icons.file_upload_outlined),
            title: Text(s.exportData),
            subtitle: Text(s.exportDataHint),
            onTap: () => exportData(context),
          ),
          ListTile(
            leading: const Icon(Icons.file_download_outlined),
            title: Text(s.importData),
            subtitle: Text(s.importDataHint),
            onTap: () => importData(context),
          ),
          ListTile(
            leading: const Icon(Icons.enhanced_encryption_outlined),
            title: Text(s.createBackup),
            subtitle: Text(s.createBackupHint),
            onTap: () => createBackupFile(context),
          ),
          ListTile(
            leading: const Icon(Icons.settings_backup_restore),
            title: Text(s.restoreBackup),
            subtitle: Text(s.restoreBackupHint),
            onTap: () => restoreBackupFile(context),
          ),
          ListTile(
            leading: Icon(Icons.delete_forever_outlined, color: context.scheme.error),
            title: Text(s.deleteAllData, style: TextStyle(color: context.scheme.error)),
            subtitle: Text(s.deleteAllDataHint),
            onTap: () => deleteAllData(context),
          ),
          ListHeader(s.about),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('MorphHealth'),
            subtitle: Text('${s.version} $appVersion'),
          ),
          ListTile(
            leading: const Icon(Icons.privacy_tip_outlined),
            title: Text(s.privacyTitle),
            subtitle: Text(s.privacyText),
          ),
          ListTile(
            leading: const Icon(Icons.health_and_safety_outlined),
            title: Text(s.medicalNoteTitle),
            subtitle: Text(s.disclaimer),
          ),
          ListTile(
            leading: const Icon(Icons.dataset_outlined),
            title: Text(s.onlineFood),
            subtitle: Text(s.offAttribution),
          ),
          ListTile(
            leading: const Icon(Icons.description_outlined),
            title: Text(s.licenses),
            onTap: () => showLicensePage(
              context: context,
              applicationName: 'MorphHealth',
              applicationVersion: appVersion,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _chooseLanguage(BuildContext context) async {
    final app = context.appRead;
    final choice = await showDialog<AppLanguage>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: Text(app.s.languageLabel),
        children: [
          for (final (lang, name) in const [(AppLanguage.de, 'Deutsch'), (AppLanguage.en, 'English')])
            SimpleDialogOption(
              onPressed: () => Navigator.pop(dialogContext, lang),
              child: Row(
                children: [
                  Icon(app.settings.language == lang ? Icons.radio_button_checked : Icons.radio_button_unchecked),
                  const SizedBox(width: 12),
                  Text(name),
                ],
              ),
            ),
        ],
      ),
    );
    if (choice != null) await app.updateSettings(app.settings.copyWith(language: choice));
  }

  Future<void> _editQuick(BuildContext context, {required bool water}) async {
    final app = context.appRead;
    final s = app.s;
    final current = water ? app.settings.waterQuickMl : app.settings.caffeineQuickMg;
    final controller = TextEditingController(text: current.join(', '));
    final max = water ? 5000 : 1000;
    final result = await showDialog<List<int>>(
      context: context,
      builder: (dialogContext) {
        String? error;
        return StatefulBuilder(
          builder: (dialogContext, setState) => AlertDialog(
            title: Text(water ? s.waterQuickAmounts : s.caffeineQuickAmounts),
            content: TextField(
              controller: controller,
              autofocus: true,
              keyboardType: TextInputType.text,
              decoration: InputDecoration(helperText: s.quickAmountsHint, errorText: error, helperMaxLines: 2),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, water ? Settings.defaultWaterQuickMl : Settings.defaultCaffeineQuickMg),
                child: Text(s.resetToDefault),
              ),
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(s.cancel)),
              FilledButton(
                onPressed: () {
                  final values = parseIntList(controller.text, max);
                  if (values == null) {
                    setState(() => error = s.numberRange('1', '$max'));
                  } else {
                    Navigator.pop(dialogContext, values);
                  }
                },
                child: Text(s.save),
              ),
            ],
          ),
        );
      },
    );
    if (result == null) return;
    await app.updateSettings(
      water ? app.settings.copyWith(waterQuickMl: result) : app.settings.copyWith(caffeineQuickMg: result),
    );
  }

  Future<void> _editServer(BuildContext context) async {
    final app = context.appRead;
    final s = app.s;
    final controller = TextEditingController(text: app.service.foodApiConfig.baseUrl);
    final result = await showDialog<String?>(
      context: context,
      builder: (dialogContext) {
        String? error;
        return StatefulBuilder(
          builder: (dialogContext, setState) => AlertDialog(
            title: Text(s.serverOrigin),
            content: TextField(
              controller: controller,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: InputDecoration(helperText: s.serverOriginHint, errorText: error, helperMaxLines: 2),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, ''),
                child: Text(s.resetToDefault),
              ),
              TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(s.cancel)),
              FilledButton(
                onPressed: () {
                  if (FoodApiConfig.parseBaseUrl(controller.text) == null) {
                    setState(() => error = s.serverOriginInvalid);
                  } else {
                    Navigator.pop(dialogContext, controller.text.trim());
                  }
                },
                child: Text(s.save),
              ),
            ],
          ),
        );
      },
    );
    if (result == null) return;
    final device = app.service.repo.device;
    final isDefault = result.isEmpty || result == app.service.defaultFoodApi.baseUrl;
    await app.run(() => app.service.updateDevice(
      device.copyWith(foodApiBaseUrl: () => isDefault ? null : result),
    ));
  }
}

/// Optional daily goals for calories, macronutrients and water.
class GoalsEditor extends StatefulWidget {
  const GoalsEditor({super.key});

  @override
  State<GoalsEditor> createState() => _GoalsEditorState();
}

class _GoalsEditorState extends State<GoalsEditor> {
  final _form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> _fields;

  static const _keys = ['energy_kcal', 'protein_g', 'carbohydrates_g', 'fat_g', 'water_ml'];

  @override
  void initState() {
    super.initState();
    final app = context.appRead;
    final goals = app.settings.goals;
    _fields = {
      for (final k in _keys)
        k: TextEditingController(text: goals.forKey(k) == null ? '' : app.fmt.input(goals.forKey(k)!, 1)),
    };
  }

  @override
  void dispose() {
    for (final c in _fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final app = context.appRead;
    var goals = const Goals();
    for (final k in _keys) {
      goals = goals.withKey(k, Fmt.parseNumber(_fields[k]!.text));
    }
    final ok = await app.run(() => app.updateSettings(app.settings.copyWith(goals: goals)));
    if (ok && mounted) {
      app.showMessage(app.s.saved);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final labels = {
      'energy_kcal': (s.goalEnergy, 'kcal'),
      'protein_g': (s.goalProtein, 'g'),
      'carbohydrates_g': (s.goalCarbs, 'g'),
      'fat_g': (s.goalFat, 'g'),
      'water_ml': (s.goalWater, 'ml'),
    };
    return Scaffold(
      appBar: AppBar(title: Text(s.dailyGoals)),
      body: Form(
        key: _form,
        child: ListView(
          padding: pagePadding(context, top: 16, bottom: 16),
          children: [
            Text(s.goalsHint, style: context.text.bodyMedium),
            const SizedBox(height: 16),
            for (final k in _keys)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: NumberField(
                  controller: _fields[k]!,
                  label: labels[k]!.$1,
                  suffix: labels[k]!.$2,
                  min: 0,
                  minExclusive: true,
                  max: Goals.maxima[k],
                ),
              ),
            FilledButton(
              onPressed: _save,
              child: Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(s.save)),
            ),
          ],
        ),
      ),
    );
  }
}
