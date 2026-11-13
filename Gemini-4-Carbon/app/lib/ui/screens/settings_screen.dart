/// Settings, Localization, Privacy, Portable Export/Import, Encrypted Backup/Restore,
/// and Complete Local Data Wipe screen (P02, P07, P08).
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/models.dart';
import '../app_controller.dart';
import '../sheets/entry_editors.dart';

Future<void> openSettingsScreen(
  BuildContext context,
  AppController controller,
) async {
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => SettingsScreen(controller: controller),
    ),
  );
}

class SettingsScreen extends StatefulWidget {
  final AppController controller;

  const SettingsScreen({super.key, required this.controller});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _busy = false;

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? Theme.of(context).colorScheme.error : null,
      ),
    );
  }

  Future<void> _handleCreateEncryptedBackup() async {
    final s = widget.controller.strings;
    final pass1Ctrl = TextEditingController();
    final pass2Ctrl = TextEditingController();
    String? err;

    final passphrase = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: Text(s.createEncryptedBackup),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.tr(
                  'Deine Sicherung wird mit Argon2id und ChaCha20-Poly1305 verschlüsselt und lässt sich auf einer frischen Installation wiederherstellen.',
                  'Your backup is encrypted using Argon2id and ChaCha20-Poly1305 and can be restored on a fresh installation.',
                ),
                style: const TextStyle(fontSize: 13.5),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: pass1Ctrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: s.tr('Passphrase', 'Passphrase'),
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: pass2Ctrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: s.tr('Passphrase wiederholen', 'Confirm passphrase'),
                ),
              ),
              if (err != null) ...[
                const SizedBox(height: 8),
                Text(
                  err!,
                  style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(s.cancel),
            ),
            FilledButton(
              onPressed: () {
                if (pass1Ctrl.text.length < 4) {
                  setDlg(
                    () => err = s.tr(
                      'Bitte wähle eine Passphrase mit mindestens 4 Zeichen.',
                      'Please enter a passphrase of at least 4 characters.',
                    ),
                  );
                  return;
                }
                if (pass1Ctrl.text != pass2Ctrl.text) {
                  setDlg(
                    () => err = s.tr(
                      'Die beiden Eingaben stimmen nicht überein.',
                      'Passphrases do not match.',
                    ),
                  );
                  return;
                }
                Navigator.pop(ctx, pass1Ctrl.text);
              },
              child: Text(s.tr('Verschlüsseln & Speichern', 'Encrypt & Save')),
            ),
          ],
        ),
      ),
    );

    if (passphrase == null) return;
    setState(() => _busy = true);
    try {
      final encryptedJson =
          await widget.controller.createEncryptedBackupString(passphrase);
      final bytes = Uint8List.fromList(utf8.encode(encryptedJson));
      final saved = await widget.controller.platformBridge.saveDocument(
        fileName:
            'morphhealth_backup_${widget.controller.todayDate}.mhbackup.json',
        mimeType: 'application/json',
        bytes: bytes,
      );
      if (saved) {
        _snack(
          s.tr(
            'Verschlüsselte Sicherung erfolgreich gespeichert.',
            'Encrypted backup saved successfully.',
          ),
        );
      } else {
        await Clipboard.setData(ClipboardData(text: encryptedJson));
        _snack(
          s.tr(
            'Dateiauswahl abgebrochen — verschlüsselte Sicherung wurde in die Zwischenablage kopiert.',
            'File dialog cancelled — encrypted backup copied to clipboard.',
          ),
        );
      }
    } catch (e) {
      _snack('$e', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _handleRestoreEncryptedBackup() async {
    final s = widget.controller.strings;
    String? backupText;
    final picked = await widget.controller.platformBridge.openDocument();
    if (picked != null) {
      backupText = utf8.decode(picked.bytes, allowMalformed: true);
    } else {
      // Optional paste fallback if document picker cancelled
      backupText = await _promptPasteTextDialog(
        title: s.restoreEncryptedBackup,
        hint: s.tr(
          'Verschlüsselten Sicherungs-JSON-Inhalt einfügen…',
          'Paste encrypted backup JSON…',
        ),
      );
    }
    if (backupText == null || backupText.trim().isEmpty || !mounted) return;

    final passCtrl = TextEditingController();
    var confirmReplace = false;
    String? err;

    final passphrase = await showDialog<String>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: Text(s.restoreEncryptedBackup),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: passCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: s.tr('Passphrase der Sicherung', 'Backup passphrase'),
                ),
              ),
              const SizedBox(height: 10),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: confirmReplace,
                onChanged: (v) => setDlg(() => confirmReplace = v ?? false),
                title: Text(
                  s.tr(
                    'Aktuellen lokalen Datenbestand durch diese Sicherung ersetzen',
                    'Replace current local data with this backup',
                  ),
                  style: const TextStyle(fontSize: 13.5),
                ),
              ),
              if (err != null)
                Text(
                  err!,
                  style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(s.cancel),
            ),
            FilledButton(
              onPressed: () {
                if (passCtrl.text.isEmpty) {
                  setDlg(
                    () => err = s.tr(
                      'Bitte gib die Passphrase ein.',
                      'Please enter the passphrase.',
                    ),
                  );
                  return;
                }
                if (!confirmReplace) {
                  setDlg(
                    () => err = s.tr(
                      'Bitte bestätige das Ersetzen der lokalen Daten.',
                      'Please confirm replacing local data.',
                    ),
                  );
                  return;
                }
                Navigator.pop(ctx, passCtrl.text);
              },
              child: Text(s.tr('Wiederherstellen', 'Restore')),
            ),
          ],
        ),
      ),
    );

    if (passphrase == null) return;
    setState(() => _busy = true);
    try {
      final report = await widget.controller.restoreEncryptedBackupString(
        passphrase: passphrase,
        backupText: backupText,
      );
      final counts = report['counts'] as Map<String, dynamic>?;
      _snack(
        s.tr(
          'Sicherung wiederhergestellt (${counts?["total_diary_entries"] ?? 0} Einträge).',
          'Backup restored (${counts?["total_diary_entries"] ?? 0} entries).',
        ),
      );
    } catch (e) {
      _snack(
        s.tr(
          'Wiederherstellung fehlgeschlagen (falsche Passphrase oder ungültige Datei): $e',
          'Restore failed (wrong passphrase or invalid file): $e',
        ),
        isError: true,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _handlePortableExport() async {
    final s = widget.controller.strings;
    var ackPlaintext = false;

    final proceed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: Text(s.exportPlainJson),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                s.tr(
                  'Der portable Export erzeugt eine maschinenlesbare, unverschlüsselte JSON-Datei im Format „morphhealth.portable“.',
                  'Portable export writes a machine-readable, unencrypted JSON file in "morphhealth.portable" format.',
                ),
                style: const TextStyle(fontSize: 13.5),
              ),
              const SizedBox(height: 10),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: ackPlaintext,
                onChanged: (v) => setDlg(() => ackPlaintext = v ?? false),
                title: Text(
                  s.tr(
                    'Mir ist bewusst, dass dieser Export unverschlüsselt gespeichert wird',
                    'I understand this export is stored unencrypted',
                  ),
                  style: const TextStyle(fontSize: 13.5),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(s.cancel),
            ),
            FilledButton(
              onPressed: ackPlaintext ? () => Navigator.pop(ctx, true) : null,
              child: Text(s.tr('Exportieren', 'Export')),
            ),
          ],
        ),
      ),
    );

    if (proceed != true) return;
    final jsonText = widget.controller.exportPortableJsonPretty();
    final bytes = Uint8List.fromList(utf8.encode(jsonText));
    final saved = await widget.controller.platformBridge.saveDocument(
      fileName: 'morphhealth_export_${widget.controller.todayDate}.json',
      mimeType: 'application/json',
      bytes: bytes,
    );
    if (saved) {
      _snack(s.tr('Portabler JSON-Export gespeichert.', 'Portable JSON exported.'));
    } else {
      await Clipboard.setData(ClipboardData(text: jsonText));
      _snack(
        s.tr(
          'Export-JSON in die Zwischenablage kopiert.',
          'Export JSON copied to clipboard.',
        ),
      );
    }
  }

  Future<void> _handlePortableImport() async {
    final s = widget.controller.strings;
    String? jsonText;
    final picked = await widget.controller.platformBridge.openDocument();
    if (picked != null) {
      jsonText = utf8.decode(picked.bytes, allowMalformed: true);
    } else {
      jsonText = await _promptPasteTextDialog(
        title: s.importPlainJson,
        hint: s.tr(
          'JSON im Format „morphhealth.portable“ einfügen…',
          'Paste "morphhealth.portable" JSON…',
        ),
      );
    }
    if (jsonText == null || jsonText.trim().isEmpty || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.importPlainJson),
        content: Text(
          s.tr(
            'Soll der gesamte aktuelle Arbeitsdatenbestand durch die importierte Datei ersetzt werden?',
            'Replace the entire current local dataset with the imported document?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.tr('Datenbestand ersetzen', 'Replace dataset')),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _busy = true);
    try {
      final report = await widget.controller.importPortableJsonText(jsonText);
      final counts = report['counts'] as Map<String, dynamic>?;
      _snack(
        s.tr(
          'Import erfolgreich (${counts?["total_diary_entries"] ?? 0} Einträge übernommen).',
          'Import completed (${counts?["total_diary_entries"] ?? 0} entries imported).',
        ),
      );
    } catch (e) {
      _snack('${s.tr("Import fehlgeschlagen", "Import failed")}: $e', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<String?> _promptPasteTextDialog({
    required String title,
    required String hint,
  }) async {
    final s = widget.controller.strings;
    final ctrl = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          maxLines: 6,
          decoration: InputDecoration(hintText: hint),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(s.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: Text(s.tr('Übernehmen', 'Continue')),
          ),
        ],
      ),
    );
  }

  Future<void> _handleEditEndpointDialog() async {
    final s = widget.controller.strings;
    final ctrl = TextEditingController(
      text: widget.controller.preferences.customFoodApiBaseUrl ?? '',
    );
    String? err;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          title: Text(
            s.tr('Open-Food-Facts-Origin', 'Open Food Facts Origin'),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${s.tr("Standard", "Default")}: ${AppController.envFoodBaseUrl}',
                style: const TextStyle(fontSize: 12.5),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: ctrl,
                decoration: const InputDecoration(
                  labelText: 'HTTPS Origin URL',
                  hintText: 'https://world.openfoodfacts.org',
                ),
              ),
              if (err != null) ...[
                const SizedBox(height: 8),
                Text(
                  err!,
                  style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () async {
                await widget.controller.updatePreferences(
                  widget.controller.preferences
                      .copyWith(clearCustomFoodApiBaseUrl: true),
                );
                if (ctx.mounted) Navigator.pop(ctx);
              },
              child: Text(s.tr('Zurücksetzen', 'Reset')),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(s.cancel),
            ),
            FilledButton(
              onPressed: () async {
                final val = ctrl.text.trim();
                try {
                  await widget.controller.updatePreferences(
                    val.isEmpty
                        ? widget.controller.preferences
                            .copyWith(clearCustomFoodApiBaseUrl: true)
                        : widget.controller.preferences
                            .copyWith(customFoodApiBaseUrl: val),
                  );
                  if (ctx.mounted) Navigator.pop(ctx);
                } catch (e) {
                  setDlg(() => err = '$e');
                }
              },
              child: Text(s.save),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handleWipeAllData() async {
    final s = widget.controller.strings;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.wipeAllData),
        content: Text(
          s.tr(
            'Alle lokalen Mahlzeiten, eigenen Lebensmittel, Perioden, Gewichtswerte, Symptome und Ziele werden unwiderruflich gelöscht und der lokale Hauptschlüssel im Android Keystore wird erneuert.',
            'All local meals, custom foods, periods, weights, symptoms, and goals will be permanently deleted and the local Android Keystore master key will be rotated.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(s.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.error,
              foregroundColor: Theme.of(ctx).colorScheme.onError,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(s.tr('Endgültig löschen', 'Delete everything')),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      await widget.controller.wipeAllLocalData();
      _snack(
        s.tr(
          'Lokaler Datenbestand vollständig gelöscht.',
          'All local data deleted.',
        ),
      );
    } catch (e) {
      _snack('$e', isError: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final c = widget.controller;
        final s = c.strings;
        final prefs = c.preferences;

        return Scaffold(
          appBar: AppBar(title: Text(s.settingsTitle)),
          body: Stack(
            children: [
              ListView(
                padding: EdgeInsets.fromLTRB(
                  16,
                  8,
                  16,
                  MediaQuery.viewPaddingOf(context).bottom + 32,
                ),
                children: [
                  // 1. Language & Units
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.tr('Sprache & Einheiten', 'Language & Units'),
                            style: const TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 12,
                            runSpacing: 8,
                            children: [
                              Text(s.tr('Oberflächensprache', 'App language')),
                              SegmentedButton<String>(
                                segments: const [
                                  ButtonSegment(
                                    value: 'de',
                                    label: Text('Deutsch'),
                                  ),
                                  ButtonSegment(
                                    value: 'en',
                                    label: Text('English'),
                                  ),
                                ],
                                selected: {prefs.localeCode},
                                onSelectionChanged: (sel) =>
                                    c.updatePreferences(
                                  prefs.copyWith(localeCode: sel.first),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 12,
                            runSpacing: 8,
                            children: [
                              Text(s.tr('Gewichtseinheit', 'Weight unit')),
                              SegmentedButton<WeightUnit>(
                                segments: const [
                                  ButtonSegment(
                                    value: WeightUnit.kg,
                                    label: Text('kg'),
                                  ),
                                  ButtonSegment(
                                    value: WeightUnit.lb,
                                    label: Text('lb'),
                                  ),
                                ],
                                selected: {prefs.weightUnit},
                                onSelectionChanged: (sel) =>
                                    c.updatePreferences(
                                  prefs.copyWith(weightUnit: sel.first),
                                ),
                              ),
                            ],
                          ),
                          const Divider(height: 22),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.flag_outlined),
                            title: Text(
                              s.tr(
                                'Freiwillige Tagesziele verwalten',
                                'Manage voluntary daily goals',
                              ),
                            ),
                            trailing: const Icon(Icons.chevron_right_rounded),
                            onTap: () => showGoalsEditorSheet(context, c),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 2. Overview areas & Cycle Diary Mode
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.customizeAreas,
                            style: const TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          for (final mod in AppModule.values)
                            SwitchListTile.adaptive(
                              contentPadding: EdgeInsets.zero,
                              title: Text(mod.label(c.localeCode)),
                              value:
                                  prefs.visibleOverviewModules.contains(mod),
                              onChanged: (_) => c.toggleOverviewModule(mod),
                            ),
                          const Divider(height: 16),
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              s.tr(
                                'Periodentracker ausschließlich als Tagebuch nutzen',
                                'Use period tracker purely as a diary',
                              ),
                            ),
                            subtitle: Text(
                              s.tr(
                                'Blendet Prognosefenster aus und zeigt nur protokollierte Daten.',
                                'Hides forecast windows and displays recorded history only.',
                              ),
                            ),
                            value: prefs.cycleDiaryOnlyMode,
                            onChanged: (v) => c.updatePreferences(
                              prefs.copyWith(cycleDiaryOnlyMode: v),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 3. Privacy & Open Food Facts Online Control
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.tr(
                              'Privatsphäre & Open Food Facts',
                              'Privacy & Open Food Facts',
                            ),
                            style: const TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          SwitchListTile.adaptive(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              s.tr(
                                'Online-Lebensmittelsuche zulassen',
                                'Allow online food search',
                              ),
                            ),
                            subtitle: Text(
                              s.tr(
                                'Ausschalten für vollständig offline arbeitenden Betrieb.',
                                'Turn off for strictly offline local operation.',
                              ),
                            ),
                            value: prefs.onlineFoodEnabled,
                            onChanged: (v) => c.updatePreferences(
                              prefs.copyWith(onlineFoodEnabled: v),
                            ),
                          ),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.dns_outlined),
                            title: Text(
                              s.tr('Aktiver Dienst-Origin', 'Active API origin'),
                            ),
                            subtitle: Text(c.activeFoodBaseUrl),
                            trailing: const Icon(Icons.edit_outlined, size: 18),
                            onTap: _handleEditEndpointDialog,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // 4. Portability, Encrypted Backup & Wipe
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.portabilitySection,
                            style: const TextStyle(
                              fontSize: 16.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${s.tr("Aktueller lokaler Bestand", "Current local dataset")}: ${c.store.totalDiaryEntriesCount} ${s.tr("Tagebucheinträge", "diary entries")}, ${c.store.allFoods.length} ${s.tr("Lebensmittel", "foods")}.',
                            style: TextStyle(
                              fontSize: 13,
                              color: Theme.of(context)
                                  .colorScheme
                                  .onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.enhanced_encryption_outlined),
                            title: Text(s.createEncryptedBackup),
                            subtitle: Text(
                              s.tr(
                                'Passphrasengeschützte Sicherung (Argon2id + ChaCha20-Poly1305)',
                                'Passphrase-protected backup (Argon2id + ChaCha20-Poly1305)',
                              ),
                            ),
                            onTap: _busy ? null : _handleCreateEncryptedBackup,
                          ),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.settings_backup_restore_rounded),
                            title: Text(s.restoreEncryptedBackup),
                            subtitle: Text(
                              s.tr(
                                'Vollständige Übernahme auch auf frischer Installation',
                                'Full restoration including onto a fresh installation',
                              ),
                            ),
                            onTap: _busy ? null : _handleRestoreEncryptedBackup,
                          ),
                          const Divider(height: 16),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.file_upload_outlined),
                            title: Text(s.exportPlainJson),
                            subtitle: Text(
                              s.tr(
                                'Dokumentiertes Format „morphhealth.portable“ v1',
                                'Documented "morphhealth.portable" v1 format',
                              ),
                            ),
                            onTap: _busy ? null : _handlePortableExport,
                          ),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.file_download_outlined),
                            title: Text(s.importPlainJson),
                            onTap: _busy ? null : _handlePortableImport,
                          ),
                          const Divider(height: 16),
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: Icon(
                              Icons.delete_forever_outlined,
                              color: Theme.of(context).colorScheme.error,
                            ),
                            title: Text(
                              s.wipeAllData,
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.error,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            onTap: _busy ? null : _handleWipeAllData,
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              if (_busy)
                Container(
                  color: Colors.black26,
                  child: const Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
        );
      },
    );
  }
}
