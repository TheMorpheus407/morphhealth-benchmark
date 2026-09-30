import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/core.dart';
import 'shared.dart';

const documents = MethodChannel('de.themorpheus.morphhealth/documents');

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key, required this.model});
  final AppModel model;
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool busy = false;
  Future<bool> confirm(String title, String body, String button) async =>
      await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: Text(widget.model.tr('Abbrechen', 'Cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: Text(button),
            ),
          ],
        ),
      ) ??
      false;
  Future<String?> passphrase({required bool creating}) => showDialog<String>(
    context: context,
    builder: (_) => _PassphraseDialog(model: widget.model, creating: creating),
  );

  Future<void> transfer(String type) async {
    final m = widget.model;
    try {
      String? secret;
      if (type == 'export') {
        if (!await confirm(
          m.tr('Unverschlüsselt exportieren?', 'Export without encryption?'),
          m.tr(
            'Der JSON-Export enthält alle persönlichen Daten im Klartext. Speichere ihn nur an einem geschützten Ort. Für den Gerätewechsel ist eine verschlüsselte Sicherung geeignet.',
            'The JSON export contains all personal data in plain text. Save it in a protected location. An encrypted backup is suitable for moving to a new device.',
          ),
          m.tr('Klartext exportieren', 'Export plain text'),
        )) {
          return;
        }
      }
      if (type == 'backup' || type == 'restore') {
        secret = await passphrase(creating: type == 'backup');
        if (secret == null) return;
      }
      if (!mounted) return;
      setState(() => busy = true);
      if (type == 'export' || type == 'backup') {
        final text = type == 'backup'
            ? await encryptBackup(m.doc, secret!)
            : jsonEncode(m.doc);
        final saved = await documents.invokeMethod<bool>('save', {
          'name':
              'morphhealth-${dateKey(DateTime.now())}.${type == 'backup' ? 'mhbackup.json' : 'json'}',
          'mime': 'application/json',
          'content': text,
        });
        if (saved == true && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(m.tr('Datei gespeichert.', 'File saved.'))),
          );
        }
      } else {
        final text = await documents.invokeMethod<String>('open');
        if (text == null) return;
        final decoded = type == 'restore'
            ? await decryptBackup(text, secret!)
            : jsonDecode(text);
        if (decoded is! Map<String, dynamic>) {
          throw const FormatException('Expected JSON object');
        }
        if (!mounted) return;
        setState(() => busy = false);
        if (!await confirm(
          m.tr('Alle lokalen Daten ersetzen?', 'Replace all local data?'),
          m.tr(
            'Die ausgewählte Datei ersetzt Lebensmittel, Tagebücher und Einstellungen vollständig. Sichere den aktuellen Datenbestand, falls du ihn behalten möchtest. Ungültige Dateien werden abgewiesen.',
            'The selected file will replace all foods, journals and settings. Back up your current data if you want to keep it. Invalid files will be rejected.',
          ),
          m.tr('Ersetzen', 'Replace'),
        )) {
          return;
        }
        if (!mounted) return;
        setState(() => busy = true);
        await m.replace(decoded);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                m.tr('Daten vollständig übernommen.', 'All data restored.'),
              ),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${m.tr('Datei konnte nicht verarbeitet werden', 'Could not process file')}: ${friendlyError(m, e)}',
            ),
            duration: const Duration(seconds: 8),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.model,
    builder: (context, _) {
      final m = widget.model;
      return Scaffold(
        appBar: AppBar(title: Text(m.tr('Einstellungen', 'Settings'))),
        body: Stack(
          children: [
            AbsorbPointer(
              absorbing: busy,
              child: ExcludeSemantics(
                excluding: busy,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  children: [
                    SectionTitle(m.tr('Deine App', 'Your app')),
                    Panel(
                      child: Column(
                        children: [
                          DropdownButtonFormField<String>(
                            initialValue: m.de ? 'de' : 'en',
                            decoration: InputDecoration(
                              labelText: m.tr('Sprache', 'Language'),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'de',
                                child: Text('Deutsch'),
                              ),
                              DropdownMenuItem(
                                value: 'en',
                                child: Text('English'),
                              ),
                            ],
                            onChanged: (v) => safeAction(
                              context,
                              m,
                              () => m.settingsPatch({'language': v}),
                            ),
                          ),
                          const SizedBox(height: 16),
                          DropdownButtonFormField<String>(
                            initialValue: m.settings['weightUnit'] as String,
                            decoration: InputDecoration(
                              labelText: m.tr('Gewichtseinheit', 'Weight unit'),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'kg',
                                child: Text('Kilogramm / kilograms (kg)'),
                              ),
                              DropdownMenuItem(
                                value: 'lb',
                                child: Text('Pfund / pounds (lb)'),
                              ),
                            ],
                            onChanged: (v) => safeAction(
                              context,
                              m,
                              () => m.settingsPatch({'weightUnit': v}),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SectionTitle(
                      m.tr('Bereiche in der Übersicht', 'Overview sections'),
                    ),
                    Panel(
                      child: Column(
                        children: [
                          for (final pair in [
                            ['nutrition', m.tr('Ernährung', 'Nutrition')],
                            ['cycle', m.tr('Zyklus', 'Cycle')],
                            ['weight', m.tr('Gewicht', 'Weight')],
                            ['symptoms', m.tr('Symptome', 'Symptoms')],
                          ])
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: Text(pair[1]),
                              value:
                                  (m.settings['visible'] as Map)[pair[0]] ==
                                  true,
                              onChanged: (v) => safeAction(
                                context,
                                m,
                                () => m.settingsPatch({
                                  'visible': {pair[0]: v},
                                }),
                              ),
                            ),
                        ],
                      ),
                    ),
                    SectionTitle(
                      m.tr('Freiwillige Tagesziele', 'Optional daily goals'),
                    ),
                    Panel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            m.tr(
                              'Wähle eigene Orientierungswerte. Alle Felder dürfen leer bleiben.',
                              'Choose your own reference values. Every field can remain empty.',
                            ),
                          ),
                          const SizedBox(height: 12),
                          OutlinedButton.icon(
                            onPressed: () => showDialog<void>(
                              context: context,
                              builder: (_) => _GoalsDialog(model: m),
                            ),
                            icon: const Icon(Icons.flag_outlined),
                            label: Text(m.tr('Ziele bearbeiten', 'Edit goals')),
                          ),
                        ],
                      ),
                    ),
                    SectionTitle(
                      m.tr('Privatsphäre & Zyklus', 'Privacy & cycle'),
                    ),
                    Panel(
                      child: Column(
                        children: [
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              m.tr(
                                'Online-Lebensmittelsuche',
                                'Online food search',
                              ),
                            ),
                            subtitle: Text(
                              m.tr(
                                'Nur aktiv gestartete Suchanfragen und Barcodes werden an Open Food Facts übertragen. Dein Tagebuch bleibt lokal.',
                                'Only searches and barcodes you submit are sent to Open Food Facts. Your journal stays local.',
                              ),
                            ),
                            value: m.settings['onlineFood'] == true,
                            onChanged: (v) => safeAction(
                              context,
                              m,
                              () => m.settingsPatch({'onlineFood': v}),
                            ),
                          ),
                          const Divider(),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: Text(
                              m.tr(
                                'Persönliche Zykluseinschätzung',
                                'Personal cycle estimates',
                              ),
                            ),
                            subtitle: Text(
                              m.tr(
                                'Ausschalten, um den Zyklus ausschließlich als Tagebuch zu verwenden.',
                                'Turn off to use the cycle section solely as a journal.',
                              ),
                            ),
                            value: m.settings['cyclePredictions'] == true,
                            onChanged: (v) => safeAction(
                              context,
                              m,
                              () => m.settingsPatch({'cyclePredictions': v}),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SectionTitle(m.tr('Daten & Sicherung', 'Data & backup')),
                    Panel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.enhanced_encryption_outlined,
                            size: 28,
                          ),
                          const SizedBox(height: 12),
                          Text(
                            m.tr(
                              'Deine Gesundheitsdaten sind auf diesem Gerät verschlüsselt gespeichert. Eine Sicherung mit Passphrase lässt sich auf einer frischen Installation wiederherstellen.',
                              'Your health data is encrypted on this device. A passphrase-protected backup can be restored on a fresh installation.',
                            ),
                          ),
                          const SizedBox(height: 16),
                          _action(
                            Icons.lock_outline,
                            m.tr(
                              'Verschlüsselte Sicherung erstellen',
                              'Create encrypted backup',
                            ),
                            () => transfer('backup'),
                          ),
                          _action(
                            Icons.settings_backup_restore,
                            m.tr(
                              'Sicherung wiederherstellen',
                              'Restore backup',
                            ),
                            () => transfer('restore'),
                          ),
                          const Divider(),
                          _action(
                            Icons.file_upload_outlined,
                            m.tr(
                              'Vollständiger JSON-Export',
                              'Full JSON export',
                            ),
                            () => transfer('export'),
                          ),
                          _action(
                            Icons.file_download_outlined,
                            m.tr('JSON-Import', 'JSON import'),
                            () => transfer('import'),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            m.tr(
                              'JSON-Dateien enthalten alle Bereiche und Einstellungen. Ein Import ersetzt den aktuellen Bestand vollständig.',
                              'JSON files include all sections and settings. An import completely replaces the current data.',
                            ),
                            style: const TextStyle(fontSize: 12),
                          ),
                          const Divider(),
                          _action(
                            Icons.delete_forever_outlined,
                            m.tr(
                              'Alle lokalen Daten löschen',
                              'Delete all local data',
                            ),
                            () async {
                              if (await confirm(
                                m.tr(
                                  'Gesamten Datenbestand löschen?',
                                  'Delete all local data?',
                                ),
                                m.tr(
                                  'Alle Einträge, Lebensmittel, Favoriten und Einstellungen werden dauerhaft gelöscht. Exportierte Dateien bleiben an ihrem Speicherort und müssen dort separat entfernt werden.',
                                  'All entries, foods, favorites and settings will be permanently deleted. Exported files remain in their chosen location and must be deleted separately.',
                                ),
                                m.tr('Alles löschen', 'Delete everything'),
                              )) {
                                if (!context.mounted) return;
                                await safeAction(context, m, () => m.clear());
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                    SectionTitle(m.tr('Über MorphHealth', 'About MorphHealth')),
                    Panel(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('MorphHealth 1.0.0 · MH-PERSONAL-3'),
                          const SizedBox(height: 12),
                          Text(
                            m.tr(
                              'Persönliche Dokumentation und Planung. Zykluseinschätzungen sind keine Diagnosen und dienen nicht der Verhütung oder Eisprungbestimmung.',
                              'Personal recording and planning. Cycle estimates are not diagnoses and do not support contraception or ovulation tracking.',
                            ),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            m.tr(
                              'Lebensmitteldaten: Open Food Facts, ODbL. Angaben können unvollständig oder ungenau sein. Fehlende Werte bleiben als unbekannt gekennzeichnet.',
                              'Food data: Open Food Facts, ODbL. Values can be incomplete or inaccurate. Missing values are marked as unknown.',
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextButton(
                            onPressed: () => showLicensePage(
                              context: context,
                              applicationName: 'MorphHealth',
                              applicationVersion: '1.0.0',
                            ),
                            child: Text(
                              m.tr(
                                'Open-Source-Lizenzen',
                                'Open-source licenses',
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                ignoring: !busy,
                child: AnimatedSwitcher(
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 180),
                  child: busy
                      ? _FileProcessingOverlay(
                          key: const ValueKey('file-processing'),
                          message: m.tr(
                            'Datei wird verarbeitet …',
                            'Processing file …',
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
  Widget _action(IconData icon, String label, VoidCallback callback) =>
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon),
        title: Text(label),
        trailing: const Icon(Icons.chevron_right),
        onTap: callback,
      );
}

class _FileProcessingOverlay extends StatelessWidget {
  const _FileProcessingOverlay({super.key, required this.message});
  final String message;

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    liveRegion: true,
    label: message,
    child: ExcludeSemantics(
      child: Stack(
        fit: StackFit.expand,
        children: [
          ModalBarrier(
            dismissible: false,
            color: Theme.of(context).colorScheme.scrim.withValues(alpha: .2),
          ),
          Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Card(
                  elevation: 6,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 30,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const CircularProgressIndicator(),
                        const SizedBox(height: 22),
                        Text(
                          message,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class _GoalsDialog extends StatefulWidget {
  const _GoalsDialog({required this.model});
  final AppModel model;
  @override
  State<_GoalsDialog> createState() => _GoalsDialogState();
}

class _GoalsDialogState extends State<_GoalsDialog> {
  final form = GlobalKey<FormState>();
  late Map<String, TextEditingController> fields;
  bool saving = false;
  @override
  void initState() {
    super.initState();
    fields = {
      for (final key in ['water', 'energy', 'protein', 'carbs', 'fat'])
        key: TextEditingController(
          text: (widget.model.settings['goals'] as Map)[key]?.toString() ?? '',
        ),
    };
  }

  @override
  void dispose() {
    for (final c in fields.values) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.model;
    return AlertDialog(
      title: Text(m.tr('Deine Tagesziele', 'Your daily goals')),
      content: SingleChildScrollView(
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final e in fields.entries)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: TextFormField(
                    controller: e.value,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: e.key == 'water'
                          ? m.tr('Wasser (ml)', 'Water (ml)')
                          : '${m.de ? nutrients.firstWhere((n) => n.key == e.key).de : nutrients.firstWhere((n) => n.key == e.key).en} (${nutrients.firstWhere((n) => n.key == e.key).unit})',
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return null;
                      final n = double.tryParse(v.replaceAll(',', '.'));
                      return n == null || !n.isFinite || n <= 0
                          ? m.tr(
                              'Positive Zahl eingeben oder leer lassen.',
                              'Enter a positive number or leave empty.',
                            )
                          : null;
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: saving ? null : () => Navigator.pop(context),
          child: Text(m.tr('Abbrechen', 'Cancel')),
        ),
        FilledButton(
          onPressed: saving
              ? null
              : () async {
                  if (!form.currentState!.validate()) return;
                  setState(() => saving = true);
                  try {
                    await m.settingsPatch({
                      'goals': {
                        for (final e in fields.entries)
                          e.key: e.value.text.isEmpty
                              ? null
                              : double.parse(e.value.text.replaceAll(',', '.')),
                      },
                    });
                    if (context.mounted) Navigator.pop(context);
                  } catch (e) {
                    if (context.mounted) {
                      setState(() => saving = false);
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(friendlyError(m, e))),
                      );
                    }
                  }
                },
          child: Text(m.tr('Speichern', 'Save')),
        ),
      ],
    );
  }
}

class _PassphraseDialog extends StatefulWidget {
  const _PassphraseDialog({required this.model, required this.creating});
  final AppModel model;
  final bool creating;
  @override
  State<_PassphraseDialog> createState() => _PassphraseDialogState();
}

class _PassphraseDialogState extends State<_PassphraseDialog> {
  final first = TextEditingController(), second = TextEditingController();
  final form = GlobalKey<FormState>();
  bool visible = false;
  @override
  void dispose() {
    first.dispose();
    second.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.model;
    final creating = widget.creating;
    return AlertDialog(
      title: Text(
        creating
            ? m.tr('Sicherung schützen', 'Protect backup')
            : m.tr('Sicherung entsperren', 'Unlock backup'),
      ),
      content: SingleChildScrollView(
        child: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                creating
                    ? m.tr(
                        'Wähle eine lange, einzigartige Passphrase. Ohne sie kann die Sicherung nicht wiederhergestellt werden.',
                        'Choose a long, unique passphrase. You cannot restore the backup without it.',
                      )
                    : m.tr(
                        'Gib die Passphrase dieser Sicherung ein.',
                        'Enter the passphrase for this backup.',
                      ),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: first,
                obscureText: !visible,
                autocorrect: false,
                enableSuggestions: false,
                decoration: InputDecoration(
                  labelText: m.tr('Passphrase', 'Passphrase'),
                  suffixIcon: IconButton(
                    tooltip: m.tr(
                      'Passphrase anzeigen/verbergen',
                      'Show/hide passphrase',
                    ),
                    onPressed: () => setState(() => visible = !visible),
                    icon: Icon(
                      visible
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                    ),
                  ),
                ),
                validator: (s) => (s?.length ?? 0) < (creating ? 10 : 1)
                    ? m.tr(
                        creating
                            ? 'Mindestens 10 Zeichen.'
                            : 'Passphrase eingeben.',
                        creating
                            ? 'At least 10 characters.'
                            : 'Enter passphrase.',
                      )
                    : null,
              ),
              if (creating) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: second,
                  obscureText: !visible,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                    labelText: m.tr(
                      'Passphrase wiederholen',
                      'Repeat passphrase',
                    ),
                  ),
                  validator: (s) => s != first.text
                      ? m.tr(
                          'Passphrasen stimmen nicht überein.',
                          'Passphrases do not match.',
                        )
                      : null,
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(m.tr('Abbrechen', 'Cancel')),
        ),
        FilledButton(
          onPressed: () {
            if (form.currentState!.validate()) {
              Navigator.pop(context, first.text);
            }
          },
          child: Text(m.tr('Weiter', 'Continue')),
        ),
      ],
    );
  }
}
