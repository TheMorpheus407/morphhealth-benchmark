import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:morphhealth_core/morphhealth_core.dart';

import '../l10n/app_localizations.dart';
import '../services/platform_services.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';

/// Language, units, areas and everything about the local data.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('settings.title'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
        children: <Widget>[
          SectionCard(
            title: l10n.t('settings.language'),
            child: SegmentedSwitch<String>(
              value: state.settings.languageCode,
              options: <String, String>{
                'de': l10n.t('common.german'),
                'en': l10n.t('common.english'),
              },
              onChanged: state.setLanguage,
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: l10n.t('settings.units'),
            child: SegmentedSwitch<WeightUnit>(
              value: state.settings.weightUnit,
              options: <WeightUnit, String>{
                WeightUnit.kg: l10n.t('weight.unit.kg'),
                WeightUnit.lb: l10n.t('weight.unit.lb'),
              },
              onChanged: state.setWeightUnit,
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: l10n.t('settings.areas'),
            subtitle: l10n.t('overview.visible_areas_hint'),
            child: Column(
              children: <Widget>[
                for (final AppArea area in AppArea.values)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    title: Text(l10n.t('area.${area.name}')),
                    value: state.visibleAreas.contains(area),
                    onChanged: (bool value) => state.setAreaVisible(area, value),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: l10n.t('settings.data'),
            child: Column(
              children: <Widget>[
                _action(
                  context,
                  icon: Icons.upload_file,
                  title: l10n.t('settings.export'),
                  subtitle: l10n.t('settings.export_hint'),
                  onTap: () => _export(context),
                ),
                _action(
                  context,
                  icon: Icons.download,
                  title: l10n.t('settings.import'),
                  subtitle: l10n.t('settings.import_hint'),
                  onTap: () => _import(context),
                ),
                _action(
                  context,
                  icon: Icons.lock_outline,
                  title: l10n.t('settings.backup'),
                  subtitle: l10n.t('settings.backup_hint'),
                  onTap: () => _backup(context),
                ),
                _action(
                  context,
                  icon: Icons.lock_open,
                  title: l10n.t('settings.restore'),
                  subtitle: l10n.t('settings.restore_hint'),
                  onTap: () => _restore(context),
                ),
                _action(
                  context,
                  icon: Icons.delete_forever_outlined,
                  title: l10n.t('settings.delete_all'),
                  subtitle: l10n.t('settings.delete_all_hint'),
                  danger: true,
                  onTap: () => _deleteAll(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: l10n.t('settings.food_api'),
            subtitle: l10n.t('settings.food_api_hint'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${l10n.t('settings.food_api_base')}: ${state.foodBaseUrl}',
                  style: theme.textTheme.bodySmall,
                ),
                Text(
                  '${l10n.t('settings.food_api_user_agent')}: ${state.foodUserAgent}',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => _editFoodService(context),
                  icon: const Icon(Icons.tune),
                  label: Text(l10n.t('common.edit')),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: l10n.t('settings.about'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(l10n.t('settings.about_body')),
                const SizedBox(height: 8),
                Text(
                  '${l10n.t('settings.record_count')}: '
                  '${state.repository.data.recordCount}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
                Text(
                  l10n.t('app.tagline'),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _action(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
    bool danger = false,
  }) {
    final ThemeData theme = Theme.of(context);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: danger ? theme.colorScheme.error : null),
      title: Text(
        title,
        style: danger
            ? TextStyle(color: theme.colorScheme.error)
            : null,
      ),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right),
      onTap: onTap,
    );
  }

  // ------------------------------------------------------------- data work

  Future<void> _export(BuildContext context) async {
    final AppState state = AppScope.of(context);
    final AppLocalizations l10n = context.l10n;
    final Map<String, dynamic> document = PortableFormat.exportDocument(
      state.repository.data,
      exportedAt: DateTime.now(),
    );
    final String name =
        'morphhealth-export-${DateMath.format(DateTime.now())}.json';
    final DocumentService documents = const DocumentService();
    final String? uri = await documents.createDocument(
      suggestedName: name,
      mimeType: 'application/json',
    );
    if (uri == null) return;
    final bool written = await documents.writeFile(
      uri,
      utf8.encode(PortableFormat.encode(document)),
    );
    if (!context.mounted) return;
    _message(context, written ? l10n.t('settings.export_done') : l10n.t('common.save_failed'));
  }

  Future<void> _import(BuildContext context) async {
    final AppState state = AppScope.of(context);
    final AppLocalizations l10n = context.l10n;
    final bool confirmed = await _confirm(
      context,
      title: l10n.t('settings.import'),
      body: l10n.t('settings.import_hint'),
    );
    if (!confirmed) return;
    final DocumentService documents = const DocumentService();
    final String? uri = await documents.openDocument(mimeType: 'application/json');
    if (uri == null) return;
    final List<int>? bytes = await documents.readFile(uri);
    if (bytes == null || !context.mounted) return;
    try {
      final Map<String, dynamic> document =
          PortableFormat.decode(utf8.decode(bytes));
      final HealthData data = PortableFormat.importDocument(document);
      await state.replaceAll(data);
      if (!context.mounted) return;
      _message(context, l10n.t('settings.import_done'));
    } on Object {
      if (!context.mounted) return;
      _message(context, l10n.t('common.error'));
    }
  }

  Future<void> _backup(BuildContext context) async {
    final AppState state = AppScope.of(context);
    final AppLocalizations l10n = context.l10n;
    final String? passphrase = await _askPassphrase(context);
    if (passphrase == null) return;
    final Map<String, dynamic> document = PortableFormat.exportDocument(
      state.repository.data,
      exportedAt: DateTime.now(),
    );
    final List<int> bytes = await BackupContainer.seal(document, passphrase);
    final String name =
        'morphhealth-backup-${DateMath.format(DateTime.now())}.mhbackup';
    final DocumentService documents = const DocumentService();
    final String? uri = await documents.createDocument(
      suggestedName: name,
      mimeType: 'application/octet-stream',
    );
    if (uri == null) return;
    final bool written = await documents.writeFile(uri, bytes);
    if (!context.mounted) return;
    _message(context, written ? l10n.t('settings.backup_done') : l10n.t('common.save_failed'));
  }

  Future<void> _restore(BuildContext context) async {
    final AppState state = AppScope.of(context);
    final AppLocalizations l10n = context.l10n;
    final bool confirmed = await _confirm(
      context,
      title: l10n.t('settings.restore'),
      body: l10n.t('settings.restore_hint'),
    );
    if (!confirmed) return;
    final DocumentService documents = const DocumentService();
    final String? uri =
        await documents.openDocument(mimeType: 'application/octet-stream');
    if (uri == null) return;
    final List<int>? bytes = await documents.readFile(uri);
    if (bytes == null || !context.mounted) return;
    final String? passphrase = await _askPassphrase(context);
    if (passphrase == null) return;
    try {
      final Map<String, dynamic> document =
          await BackupContainer.open(bytes, passphrase);
      final HealthData data = PortableFormat.importDocument(document);
      await state.replaceAll(data);
      if (!context.mounted) return;
      _message(context, l10n.t('settings.restore_done'));
    } on BackupException {
      if (!context.mounted) return;
      _message(context, l10n.t('settings.wrong_passphrase'));
    } on Object {
      if (!context.mounted) return;
      _message(context, l10n.t('common.error'));
    }
  }

  Future<void> _deleteAll(BuildContext context) async {
    final AppState state = AppScope.of(context);
    final AppLocalizations l10n = context.l10n;
    final bool confirmed = await _confirm(
      context,
      title: l10n.t('settings.delete_all_confirm'),
      body: l10n.t('settings.delete_all_confirm_body'),
      danger: true,
    );
    if (!confirmed) return;
    await state.deleteEverything();
    if (!context.mounted) return;
    _message(context, l10n.t('settings.delete_done'));
  }

  Future<void> _editFoodService(BuildContext context) async {
    final AppState state = AppScope.of(context);
    final AppLocalizations l10n = context.l10n;
    final TextEditingController base =
        TextEditingController(text: state.foodBaseUrl);
    final TextEditingController agent =
        TextEditingController(text: state.foodUserAgent);

    final bool? saved = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(l10n.t('settings.food_api')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: base,
              decoration: InputDecoration(
                labelText: l10n.t('settings.food_api_base'),
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: agent,
              decoration: InputDecoration(
                labelText: l10n.t('settings.food_api_user_agent'),
              ),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.t('common.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.t('common.save')),
          ),
        ],
      ),
    );
    if (saved == true) {
      await state.setFoodService(
        baseUrl: base.text.trim(),
        userAgent: agent.text.trim(),
      );
    }
    base.dispose();
    agent.dispose();
  }

  Future<bool> _confirm(
    BuildContext context, {
    required String title,
    required String body,
    bool danger = false,
  }) async {
    final AppLocalizations l10n = context.l10n;
    final bool? result = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(title),
        content: Text(body),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.t('common.cancel')),
          ),
          FilledButton(
            style: danger
                ? FilledButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.error,
                  )
                : null,
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.t('common.confirm')),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<String?> _askPassphrase(BuildContext context) async {
    final AppLocalizations l10n = context.l10n;
    final TextEditingController first = TextEditingController();
    final TextEditingController second = TextEditingController();
    String? error;

    final String? result = await showDialog<String>(
      context: context,
      builder: (BuildContext context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return AlertDialog(
            title: Text(l10n.t('settings.passphrase')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextField(
                  controller: first,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: l10n.t('settings.passphrase'),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: second,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: l10n.t('settings.passphrase_confirm'),
                  ),
                ),
                if (error != null) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
            actions: <Widget>[
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: Text(l10n.t('common.cancel')),
              ),
              FilledButton(
                onPressed: () {
                  if (first.text.length < 8) {
                    setState(() => error = l10n.t('settings.passphrase_too_short'));
                    return;
                  }
                  if (first.text != second.text) {
                    setState(() => error = l10n.t('settings.passphrase_mismatch'));
                    return;
                  }
                  Navigator.of(context).pop(first.text);
                },
                child: Text(l10n.t('common.confirm')),
              ),
            ],
          );
        },
      ),
    );
    first.dispose();
    second.dispose();
    return result;
  }

  void _message(BuildContext context, String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}
