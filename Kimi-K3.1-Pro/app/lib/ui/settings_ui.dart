import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/health.dart';
import '../core/portable.dart';
import 'controller.dart';
import 'l10n.dart';
import 'nutrition_ui.dart';
import 'widgets.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool busy = false;

  Future<T?> _busy<T>(Future<T> Function() action) async {
    if (busy) return null;
    setState(() => busy = true);
    try {
      return await action();
    } catch (_) {
      if (mounted) showError(context);
      return null;
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<bool> _confirm(
    String title,
    String message, {
    bool acknowledgement = false,
  }) async {
    final strings = l10n(context);
    var acknowledged = !acknowledgement;
    return await showDialog<bool>(
          context: context,
          builder: (context) => StatefulBuilder(
            builder: (context, setDialogState) => AlertDialog(
              scrollable: true,
              title: Text(strings.t(title)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(strings.t(message)),
                  if (acknowledgement)
                    CheckboxListTile(
                      value: acknowledged,
                      contentPadding: EdgeInsets.zero,
                      title: Text(strings.t('plain_export_ack')),
                      onChanged: (value) =>
                          setDialogState(() => acknowledged = value ?? false),
                    ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text(strings.t('cancel')),
                ),
                FilledButton(
                  key: const ValueKey('sensitive-confirm'),
                  onPressed: acknowledged
                      ? () => Navigator.pop(context, true)
                      : null,
                  child: Text(strings.t('yes')),
                ),
              ],
            ),
          ),
        ) ??
        false;
  }

  Future<String?> _passphrase({bool repeat = false}) async {
    final strings = l10n(context);
    final first = TextEditingController();
    final second = TextEditingController();
    final form = GlobalKey<FormState>();
    try {
      return await showDialog<String>(
        context: context,
        builder: (context) => AlertDialog(
          scrollable: true,
          title: Text(strings.t(repeat ? 'create_backup' : 'restore_backup')),
          content: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(strings.t('passphrase_help')),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('backup-passphrase'),
                  controller: first,
                  obscureText: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: fieldDecoration(strings.t('passphrase')),
                  validator: (value) => (value ?? '').length < 8
                      ? strings.t('passphrase_short')
                      : null,
                ),
                if (repeat)
                  TextFormField(
                    key: const ValueKey('backup-passphrase-repeat'),
                    controller: second,
                    obscureText: true,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: fieldDecoration(strings.t('passphrase_repeat')),
                    validator: (value) {
                      if ((value ?? '').length < 8)
                        return strings.t('passphrase_short');
                      return value == first.text
                          ? null
                          : strings.t('passphrase_mismatch');
                    },
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(strings.t('cancel')),
            ),
            FilledButton(
              key: const ValueKey('backup-passphrase-save'),
              onPressed: () {
                if (form.currentState!.validate())
                  Navigator.pop(context, first.text);
              },
              child: Text(strings.t('save')),
            ),
          ],
        ),
      );
    } finally {
      first.dispose();
      second.dispose();
    }
  }

  Future<Uint8List?> _pickJson() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: l10n(context).t('plain_import'),
      type: FileType.custom,
      allowedExtensions: ['json'],
      allowMultiple: false,
      withData: true,
    );
    if (result == null) return null;
    return result.files.single.bytes;
  }

  Future<bool> _saveJson(
    Map<String, dynamic> document,
    String extension,
  ) async {
    final timestamp = context
        .read<AppController>()
        .now
        .toUtc()
        .toIso8601String()
        .replaceAll(':', '-');
    final bytes = Uint8List.fromList(
      utf8.encode(const JsonEncoder.withIndent('  ').convert(document)),
    );
    final path = await FilePicker.platform.saveFile(
      dialogTitle: l10n(context).t('save'),
      fileName: 'morphhealth-$timestamp.$extension.json',
      type: FileType.custom,
      allowedExtensions: ['json'],
      bytes: bytes,
    );
    return path != null;
  }

  Future<void> _export() async {
    if (!await _confirm(
      'plain_export',
      'plain_export_help',
      acknowledgement: true,
    ))
      return;
    if (!mounted) return;
    final controller = context.read<AppController>();
    final saved = await _busy(
      () => _saveJson(
        createPortableDocument(controller.state, controller.now),
        'portable',
      ),
    );
    if (saved == true && mounted)
      showMessage(context, l10n(context).t('export_success'));
  }

  Future<void> _import() async {
    if (!await _confirm('plain_import', 'replace_warning')) return;
    if (!mounted) return;
    final controller = context.read<AppController>();
    final result = await _busy(() async {
      final bytes = await _pickJson();
      if (bytes == null) return false;
      final state = parsePortableDocument(jsonDecode(utf8.decode(bytes)));
      await controller.repository.replaceAll(state);
      return true;
    });
    if (result == true && mounted)
      showMessage(context, l10n(context).t('import_success'));
  }

  Future<void> _backup() async {
    final passphrase = await _passphrase(repeat: true);
    if (passphrase == null || !mounted) return;
    final controller = context.read<AppController>();
    final saved = await _busy(() async {
      final document = createPortableDocument(controller.state, controller.now);
      final backup = await BackupCodec.encrypt(document, passphrase);
      return _saveJson(backup, 'encrypted-backup');
    });
    if (saved == true && mounted)
      showMessage(context, l10n(context).t('backup_success'));
  }

  Future<void> _restore() async {
    if (!await _confirm('restore_backup', 'replace_warning')) return;
    if (!mounted) return;
    final bytes = await _busy(_pickJson);
    if (bytes == null || !mounted) return;
    final passphrase = await _passphrase();
    if (passphrase == null || !mounted) return;
    final controller = context.read<AppController>();
    final restored = await _busy(() async {
      final document = await BackupCodec.decrypt(
        jsonDecode(utf8.decode(bytes)),
        passphrase,
      );
      final state = parsePortableDocument(document);
      await controller.repository.replaceAll(state);
      return true;
    });
    if (restored == true && mounted)
      showMessage(context, l10n(context).t('restore_success'));
  }

  Future<void> _wipe() async {
    final strings = l10n(context);
    final confirmation = TextEditingController();
    final expected = strings.locale.languageCode == 'en' ? 'DELETE' : 'LÖSCHEN';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          scrollable: true,
          title: Text(strings.t('wipe_data')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(strings.t('wipe_warning')),
              const SizedBox(height: 12),
              Text(
                strings.t(
                  strings.locale.languageCode == 'en'
                      ? 'wipe_phrase_en'
                      : 'wipe_phrase',
                ),
              ),
              TextField(
                key: const ValueKey('wipe-confirmation'),
                controller: confirmation,
                autocorrect: false,
                onChanged: (_) => setDialogState(() {}),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(strings.t('cancel')),
            ),
            FilledButton(
              key: const ValueKey('wipe-confirm-button'),
              onPressed: confirmation.text == expected
                  ? () => Navigator.pop(context, true)
                  : null,
              child: Text(strings.t('delete')),
            ),
          ],
        ),
      ),
    );
    confirmation.dispose();
    if (confirmed != true) return;
    final wiped = await _busy(() async {
      await context.read<AppController>().repository.wipe();
      return true;
    });
    if (wiped == true && mounted)
      showMessage(context, strings.t('wipe_success'));
  }

  @override
  Widget build(BuildContext context) {
    final strings = l10n(context);
    final controller = context.watch<AppController>();
    final settings = controller.settings;
    Future<void> update(SettingsCopy update) async {
      try {
        await controller.repository.updateSettings(update(settings));
      } catch (_) {
        if (!context.mounted) return;
        showError(context);
      }
    }

    return Scaffold(
      appBar: AppBar(title: Text(strings.t('settings'))),
      body: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              AppCard(
                title: strings.t('language'),
                icon: Icons.language,
                children: [
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    initialValue: settings.language,
                    items: [
                      DropdownMenuItem(
                        value: 'de',
                        child: Text(strings.t('german')),
                      ),
                      DropdownMenuItem(
                        value: 'en',
                        child: Text(strings.t('english')),
                      ),
                    ],
                    onChanged: (value) =>
                        update((current) => current.copyWith(language: value)),
                  ),
                ],
              ),
              AppCard(
                title: strings.t('online'),
                subtitle: strings.t('online_subtitle'),
                icon: Icons.cloud_outlined,
                children: [
                  SwitchListTile(
                    value: settings.onlineEnabled,
                    title: Text(strings.t('online')),
                    onChanged: (value) => update(
                      (current) => current.copyWith(onlineEnabled: value),
                    ),
                  ),
                ],
              ),
              AppCard(
                title: strings.t('show_areas'),
                icon: Icons.dashboard_customize_outlined,
                children: [
                  for (final item in [
                    ('nutrition', settings.showNutrition),
                    ('cycle', settings.showCycle),
                    ('weight', settings.showWeight),
                    ('symptoms', settings.showSymptoms),
                  ])
                    SwitchListTile(
                      title: Text(strings.t(item.$1)),
                      value: item.$2,
                      onChanged: (value) => update(
                        (current) => switch (item.$1) {
                          'nutrition' => current.copyWith(showNutrition: value),
                          'cycle' => current.copyWith(showCycle: value),
                          'weight' => current.copyWith(showWeight: value),
                          _ => current.copyWith(showSymptoms: value),
                        },
                      ),
                    ),
                ],
              ),
              AppCard(
                title: strings.t('goals'),
                icon: Icons.flag_outlined,
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => const GoalsPage()),
                ),
              ),
              AppCard(
                title: strings.t('privacy_data'),
                subtitle: strings.t('data_local'),
                icon: Icons.lock_outline,
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.upload_file_outlined),
                    title: Text(strings.t('plain_export')),
                    subtitle: Text(strings.t('plain_export_help')),
                    onTap: _export,
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.download_outlined),
                    title: Text(strings.t('plain_import')),
                    subtitle: Text(strings.t('replace_warning')),
                    onTap: _import,
                  ),
                  const Divider(),
                  ListTile(
                    key: const ValueKey('create-backup'),
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.enhanced_encryption_outlined),
                    title: Text(strings.t('create_backup')),
                    onTap: _backup,
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.restore),
                    title: Text(strings.t('restore_backup')),
                    onTap: _restore,
                  ),
                  const Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.delete_forever_outlined,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    title: Text(strings.t('wipe_data')),
                    subtitle: Text(strings.t('wipe_warning')),
                    onTap: _wipe,
                  ),
                ],
              ),
              AppCard(
                title: strings.t('about'),
                icon: Icons.info_outline,
                children: [
                  Text(strings.t('about_text')),
                  const SizedBox(height: 8),
                  Text(strings.t('off_attribution')),
                ],
              ),
            ],
          ),
          if (busy)
            Positioned.fill(
              child: ColoredBox(
                color: Colors.black26,
                child: Center(
                  child: Card(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const CircularProgressIndicator(),
                          const SizedBox(height: 12),
                          Text(strings.t('working')),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

typedef SettingsCopy = Settings Function(Settings current);
