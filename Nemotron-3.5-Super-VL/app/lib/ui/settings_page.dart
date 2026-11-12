library morphhealth.ui.settings_page;

import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:morphhealth/core/model/entries.dart';
import 'package:morphhealth/core/repository.dart';
import 'package:morphhealth/l10n/app_localizations.dart';

class SettingsPage extends StatefulWidget {
  final HealthRepository repository;
  final void Function(Locale) onLocaleChange;
  const SettingsPage({super.key, required this.repository, required this.onLocaleChange});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late String _locale;
  late Set<String> _areas;
  late UserGoals _goals;
  final Map<String, TextEditingController> _goalControllers = {};

  @override
  void initState() {
    super.initState();
    _locale = widget.repository.settings.locale;
    _areas = Set<String>.from(widget.repository.settings.visibleAreas);
    _goals = widget.repository.settings.goals ?? const UserGoals();
    _goalControllers['waterMilliliters'] = TextEditingController(text: _goals.waterMilliliters != null ? _goals.waterMilliliters!.toStringAsFixed(0) : '');
    _goalControllers['energyKcal'] = TextEditingController(text: _goals.energyKcal != null ? _goals.energyKcal!.toStringAsFixed(0) : '');
    _goalControllers['proteinG'] = TextEditingController(text: _goals.proteinG != null ? _goals.proteinG!.toStringAsFixed(0) : '');
    _goalControllers['carbsG'] = TextEditingController(text: _goals.carbsG != null ? _goals.carbsG!.toStringAsFixed(0) : '');
    _goalControllers['fatG'] = TextEditingController(text: _goals.fatG != null ? _goals.fatG!.toStringAsFixed(0) : '');
  }

  @override
  void dispose() {
    for (final c in _goalControllers.values) c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l.msg('settings'))),
      body: ListView(
        children: [
          ListTile(
            title: Text(l.msg('language')),
            trailing: DropdownButton<String>(
              value: _locale,
              items: const [
                DropdownMenuItem(value: 'de', child: Text('Deutsch')),
                DropdownMenuItem(value: 'en', child: Text('English')),
              ],
              onChanged: (v) {
                if (v == null) return;
                setState(() => _locale = v);
                widget.repository.setSettings(AppSettings(
                  locale: v,
                  visibleAreas: _areas,
                  goals: _goals,
                ));
                widget.onLocaleChange(Locale(v == 'de' ? 'de' : 'en'));
              },
            ),
          ),
          const Divider(),
          _AreaRow(icon: Icons.dashboard, label: l.msg('navOverview'), area: 'overview', value: _areas.contains('overview'), onChanged: (_) => _toggleAndSave('overview')),
          _AreaRow(icon: Icons.restaurant_menu, label: l.msg('navNutrition'), area: 'nutrition', value: _areas.contains('nutrition'), onChanged: (_) => _toggleAndSave('nutrition')),
          _AreaRow(icon: Icons.calendar_today, label: l.msg('navCycle'), area: 'cycle', value: _areas.contains('cycle'), onChanged: (_) => _toggleAndSave('cycle')),
          _AreaRow(icon: Icons.monitor_weight, label: l.msg('navWeight'), area: 'weight', value: _areas.contains('weight'), onChanged: (_) => _toggleAndSave('weight')),
          const Divider(),
          ListTile(
            title: Text(l.msg('visibleAreas')),
            subtitle: const Text('Bereiche in der Übersicht ein-/ausblenden'),
          ),
          const Divider(),
          ListTile(title: Text(l.msg('goals'))),
          _GoalRow(goalKey: 'waterMilliliters', label: l.msg('goalWater'), unit: 'ml', controller: _goalControllers['waterMilliliters']!, onChanged: (_) => _saveGoals()),
          _GoalRow(goalKey: 'energyKcal', label: l.msg('goalKcal'), unit: 'kcal', controller: _goalControllers['energyKcal']!, onChanged: (_) => _saveGoals()),
          _GoalRow(goalKey: 'proteinG', label: l.msg('goalProtein'), unit: 'g', controller: _goalControllers['proteinG']!, onChanged: (_) => _saveGoals()),
          _GoalRow(goalKey: 'carbsG', label: l.msg('goalCarbs'), unit: 'g', controller: _goalControllers['carbsG']!, onChanged: (_) => _saveGoals()),
          _GoalRow(goalKey: 'fatG', label: l.msg('goalFat'), unit: 'g', controller: _goalControllers['fatG']!, onChanged: (_) => _saveGoals()),
          const Divider(),
          ListTile(
            title: Text(l.msg('encryption')),
            subtitle: const Text('Lokaler Datenbestand ist verschlüsselt abgelegt.'),
          ),
          ListTile(
            title: Text(l.msg('dataKey')),
            subtitle: const Text('Schlüssel für den mh-CLI-Zugang aus 32 Rohbyte'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: _showKey,
          ),
          const Divider(),
          ListTile(
            title: Text(l.msg('backup')),
            subtitle: const Text('Verschlüsselte Sicherung erstellen / wiederherstellen'),
            onTap: () => _backupMenu(context),
          ),
          ListTile(
            title: Text(l.msg('export')),
            subtitle: const Text('Maschinenlesbarer Datenexport (portables Format)'),
            onTap: _exportPortable,
          ),
          ListTile(
            title: Text(l.msg('import')),
            subtitle: const Text('Datenbestand aus Export ersetzen'),
            onTap: _importPortable,
          ),
          ListTile(
            title: Text(l.msg('wipe')),
            subtitle: const Text('Gesamten lokalen Datenbestand löschen'),
            leading: const Icon(Icons.delete_outline, color: Colors.red),
            onTap: _wipe,
          ),
          const Divider(),
          ListTile(
            title: Text(l.msg('about')),
            subtitle: Text(l.msg('privacy')),
            onTap: _about,
          ),
        ],
      ),
    );
  }

  void _toggleAndSave(String area) {
    if (_areas.contains(area)) _areas.remove(area);
    else _areas.add(area);
    if (_areas.isEmpty) _areas.add(area);
    widget.repository.setSettings(AppSettings(
      locale: _locale,
      visibleAreas: _areas,
      goals: _goals,
    ));
  }

  void _saveGoals() {
    final g = UserGoals(
      waterMilliliters: _parse(_goalControllers['waterMilliliters']),
      energyKcal: _parse(_goalControllers['energyKcal']),
      proteinG: _parse(_goalControllers['proteinG']),
      carbsG: _parse(_goalControllers['carbsG']),
      fatG: _parse(_goalControllers['fatG']),
    );
    _goals = g;
    widget.repository.setSettings(AppSettings(
      locale: _locale,
      visibleAreas: _areas,
      goals: g,
    ));
  }

  static double? _parse(TextEditingController? c) {
    if (c == null) return null;
    final text = c.text.trim();
    if (text.isEmpty) return null;
    return double.tryParse(text);
  }

  void _showKey() {
    showDialog(context: context, builder: (_) => AlertDialog(
      title: Text('Daten-Schlüssel'),
      content: const Text('Der Schlüssel wird vom Betriebssystem im sicheren Schlüsselspeicher verwaltet. Für den mh-CLI-Zugang muss eine separate Schlüsseldatei mit genau 32 Rohbyte erstellt werden (z. B. mit head -c 32 /dev/urandom > keyfile). Diese Datei liegt außerhalb des Datenverzeichnisses.'),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
    ));
  }

  Future<void> _backupMenu(BuildContext context) async {
    final l = AppLocalizations.of(context)!;
    final choice = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l.msg('backup')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(title: const Text('Verschlüsselte Sicherung erstellen'), onTap: () => Navigator.pop(context, 'exportEnc')),
            ListTile(title: const Text('Sicherung wiederherstellen'), onTap: () => Navigator.pop(context, 'importEnc')),
          ],
        ),
      ),
    );
    if (choice == 'exportEnc') await _exportEncrypted();
    if (choice == 'importEnc') await _importEncrypted();
  }

  Future<void> _exportEncrypted() async {
    final l = AppLocalizations.of(context)!;
    final dir = Directory(widget.repository.dataPath).parent;
    final target = File('${dir.path}/morphhealth_backup.enc');
    final source = File(widget.repository.dataPath);
    if (!await source.exists()) return;
    await source.copy(target.path);
    _toast('${l.msg('saved')}: ${target.path}');
  }

  Future<void> _importEncrypted() async {
    final l = AppLocalizations.of(context)!;
    final result = await FilePicker.platform.pickFiles(allowedExtensions: ['enc']);
    if (result == null || result.files.first.path == null) return;
    final target = File(widget.repository.dataPath);
    await File(result.files.first.path!).copy(target.path);
    try {
      await widget.repository.load();
      _toast(l.msg('success'));
      setState(() {});
    } on Exception {
      if (await target.exists()) await target.delete();
      await widget.repository.reset();
      _show(context, l.msg('error'), 'Sicherung konnte nicht entschlüsselt werden');
    }
  }

  Future<void> _exportPortable() async {
    final l = AppLocalizations.of(context)!;
    final result = await FilePicker.platform.saveFile(
      dialogTitle: 'Datenexport speichern',
      fileName: 'morphhealth_export.json',
      allowedExtensions: ['json'],
    );
    if (result == null) return;
    final doc = await widget.repository.exportDocument();
    final file = File(result);
    await file.writeAsString(const JsonEncoder.withIndent('  ').convert(doc));
    _toast(l.msg('saved'));
  }

  Future<void> _importPortable() async {
    final l = AppLocalizations.of(context)!;
    final result = await FilePicker.platform.pickFiles(allowedExtensions: ['json']);
    if (result == null || result.files.first.path == null) return;
    final content = await File(result.files.first.path!).readAsString();
    final decoded = jsonDecode(content) as Map<String, dynamic>;
    final document = decoded['document'] != null
        ? Map<String, dynamic>.from(decoded['document'] as Map)
        : decoded;
    await widget.repository.importDocument(document);
    _toast(l.msg('success'));
    setState(() {});
  }

  Future<void> _wipe() async {
    final l = AppLocalizations.of(context)!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(l.msg('wipe')),
        content: Text(l.msg('confirmDelete')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(l.msg('cancel'))),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(l.msg('delete'), style: const TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (ok != true) return;
    final target = File(widget.repository.dataPath);
    if (await target.exists()) await target.delete();
    await widget.repository.reset();
    setState(() {});
    _toast(l.msg('deleted'));
  }

  void _about() {
    final l = AppLocalizations.of(context)!;
    showDialog(context: context, builder: (_) => AlertDialog(
      title: Text(l.msg('about')),
      content: Text('MorphHealth 1.0-rc3\n${l.msg('privacy')}'),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
    ));
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _show(BuildContext context, String title, String message) {
    showDialog(context: context, builder: (_) => AlertDialog(title: Text(title), content: Text(message), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))]));
  }
}

class _AreaRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String area;
  final bool value;
  final ValueChanged<bool?>? onChanged;
  const _AreaRow({required this.icon, required this.label, required this.area, required this.value, this.onChanged});
  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Row(children: [Icon(icon), const SizedBox(width: 12), Text(label)]),
      trailing: Checkbox(value: value, onChanged: onChanged),
    );
  }
}

class _GoalRow extends StatelessWidget {
  final String goalKey;
  final String label;
  final String unit;
  final TextEditingController controller;
  final ValueChanged<String>? onChanged;
  const _GoalRow({required this.goalKey, required this.label, required this.unit, required this.controller, this.onChanged});
  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(label),
      trailing: SizedBox(width: 110, child: TextField(controller: controller, keyboardType: TextInputType.number, onChanged: onChanged, decoration: InputDecoration(isDense: true, border: const OutlineInputBorder(), suffixText: unit))),
    );
  }
}