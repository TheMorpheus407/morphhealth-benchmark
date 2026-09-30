import 'dart:convert';
import 'package:flutter/material.dart';
import '../core/model.dart';
import '../core/nutrients.dart';
import '../core/storage.dart';
import '../platform_bridge.dart';
import 'common.dart';
import 'controller.dart';

Future<String?> requestPassphrase(
  BuildContext context, {
  required bool create,
}) async {
  final c = AppScope.of(context),
      pass = TextEditingController(),
      again = TextEditingController(),
      form = GlobalKey<FormState>();
  bool visible = false;
  final result = await showDialog<String>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: Text(
          create
              ? c.tr('Sicherung schützen', 'Protect backup')
              : c.tr('Sicherung entsperren', 'Unlock backup'),
        ),
        content: SingleChildScrollView(
          child: Form(
            key: form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  create
                      ? c.tr(
                          'Wähle eine Passphrase mit mindestens zehn Zeichen. Bewahre sie getrennt auf; sie lässt sich nicht zurücksetzen.',
                          'Choose a passphrase with at least ten characters. Keep it separately; it cannot be reset.',
                        )
                      : c.tr(
                          'Gib die Passphrase dieser Sicherung ein.',
                          'Enter the passphrase for this backup.',
                        ),
                ),
                const SizedBox(height: 18),
                TextFormField(
                  key: const ValueKey('backup-passphrase'),
                  controller: pass,
                  obscureText: !visible,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: InputDecoration(
                    labelText: c.tr('Passphrase', 'Passphrase'),
                    suffixIcon: IconButton(
                      tooltip: visible
                          ? c.tr('Verbergen', 'Hide')
                          : c.tr('Anzeigen', 'Show'),
                      onPressed: () => set(() => visible = !visible),
                      icon: Icon(
                        visible
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                      ),
                    ),
                  ),
                  validator: (v) => create
                      ? (v ?? '').runes.length < 10
                            ? c.tr(
                                'Mindestens zehn Zeichen',
                                'At least ten characters',
                              )
                            : null
                      : requiredValidation(v, c),
                ),
                if (create) ...[
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: again,
                    obscureText: !visible,
                    autocorrect: false,
                    enableSuggestions: false,
                    decoration: InputDecoration(
                      labelText: c.tr(
                        'Passphrase wiederholen',
                        'Repeat passphrase',
                      ),
                    ),
                    validator: (v) => v != pass.text
                        ? c.tr(
                            'Passphrasen stimmen nicht überein',
                            'Passphrases do not match',
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
            onPressed: () => Navigator.pop(ctx),
            child: Text(c.tr('Abbrechen', 'Cancel')),
          ),
          FilledButton(
            onPressed: () {
              if (form.currentState!.validate()) Navigator.pop(ctx, pass.text);
            },
            child: Text(c.tr('Weiter', 'Continue')),
          ),
        ],
      ),
    ),
  );
  // Controllers are disposed after the dialog exit animation has detached fields.
  Future.delayed(const Duration(milliseconds: 400), () {
    pass.dispose();
    again.dispose();
  });
  return result;
}

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});
  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool busy = false;
  String busyLabel = '';
  Future<void> task(String label, Future<void> Function() action) async {
    if (busy) return;
    setState(() {
      busy = true;
      busyLabel = label;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) await notifyError(context, e);
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> exportPlain() async {
    final c = AppScope.of(context);
    if (!await confirm(
      context,
      c.tr('Unverschlüsselt exportieren?', 'Export without encryption?'),
      c.tr(
        'Diese JSON-Datei enthält deinen vollständigen Datenbestand im Klartext. Wähle einen geschützten Speicherort. Für den Gerätewechsel kannst du auch eine verschlüsselte Sicherung erstellen.',
        'This JSON file contains your complete data in plaintext. Choose a protected location. You can also create an encrypted backup to move to another device.',
      ),
      action: c.tr('Exportieren', 'Export'),
    )) {
      return;
    }
    await task(c.tr('Export wird erstellt', 'Creating export'), () async {
      final saved = await PlatformBridge.saveJson(
        'morphhealth-${c.engine.clock.today}.json',
        c.engine.export(),
      );
      if (saved && mounted) {
        notice(context, c.tr('Export gespeichert', 'Export saved'));
      }
    });
  }

  Future<void> backup() async {
    final c = AppScope.of(context);
    final pass = await requestPassphrase(context, create: true);
    if (pass == null || !mounted) return;
    await task(
      c.tr('Sicherung wird verschlüsselt', 'Encrypting backup'),
      () async {
        final document = await createBackup(c.engine.export(), pass);
        final saved = await PlatformBridge.saveJson(
          'morphhealth-${c.engine.clock.today}.mhbackup.json',
          document,
        );
        if (saved && mounted) {
          notice(
            context,
            c.tr(
              'Verschlüsselte Sicherung gespeichert',
              'Encrypted backup saved',
            ),
          );
        }
      },
    );
  }

  Future<void> import({required bool encrypted}) async {
    final c = AppScope.of(context);
    await task(c.tr('Datei wird eingelesen', 'Reading document'), () async {
      final bytes = await PlatformBridge.openDocument();
      if (bytes == null || !mounted) return;
      final raw = object(jsonDecode(utf8.decode(bytes)), 'document');
      HealthData data;
      if (encrypted) {
        final pass = await requestPassphrase(context, create: false);
        if (pass == null || !mounted) return;
        data = await restoreBackup(raw, pass);
      } else {
        data = HealthData.import(raw);
      }
      if (!mounted) return;
      final count = tableNames
          .where((t) => t != 'foods')
          .fold<int>(0, (sum, t) => sum + data[t].length);
      final old = tableNames
          .where((t) => t != 'foods')
          .fold<int>(0, (sum, t) => sum + c.data[t].length);
      if (!await confirm(
        context,
        c.tr('Datenbestand ersetzen?', 'Replace dataset?'),
        c.tr('Die Datei enthält ', 'This document contains ') +
            count.toString() +
            c.tr(' Tagebucheinträge und ', ' journal entries and ') +
            data['foods'].length.toString() +
            c.tr(
              ' Lebensmittel. Dein aktueller Bestand mit ',
              ' foods. Your current dataset with ',
            ) +
            old.toString() +
            c.tr(
              ' Einträgen wird vollständig ersetzt, einschließlich Einstellungen.',
              ' entries will be replaced completely, including settings.',
            ),
        action: c.tr('Ersetzen', 'Replace'),
      )) {
        return;
      }
      await c.replace(data.export(c.engine.clock.now));
      if (mounted) notice(context, c.tr('Daten übernommen', 'Data restored'));
    });
  }

  Future<void> erase() async {
    final c = AppScope.of(context);
    if (!await confirm(
      context,
      c.tr('Alle lokalen Daten löschen?', 'Delete all local data?'),
      c.tr(
        'Alle Einträge, Lebensmittel und Einstellungen werden gelöscht. Exportierte Dateien und Sicherungen bleiben an ihren Speicherorten.',
        'All entries, foods and settings will be deleted. Exported files and backups remain at their saved locations.',
      ),
    )) {
      return;
    }
    await task(c.tr('Daten werden gelöscht', 'Deleting data'), () async {
      await c.replace(HealthData.empty().export(c.engine.clock.now));
      if (mounted) {
        notice(
          context,
          c.tr('Lokaler Datenbestand gelöscht', 'Local dataset deleted'),
        );
      }
    });
  }

  Future<void> setting(String key, dynamic value) async {
    final c = AppScope.of(context);
    try {
      await c.change((d) => d.settings[key] = value);
    } catch (e) {
      if (mounted) await notifyError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context), settings = c.data.settings;
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (busy)
          Panel(
            color: sage,
            child: Row(
              children: [
                const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 16),
                Expanded(child: Text(busyLabel)),
              ],
            ),
          ),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Heading(c.tr('Dein MorphHealth', 'Your MorphHealth')),
              DropdownButtonFormField<String>(
                key: ValueKey('language-${c.language}'),
                initialValue: c.language,
                decoration: InputDecoration(
                  labelText: c.tr('Sprache', 'Language'),
                ),
                items: const [
                  DropdownMenuItem(value: 'de', child: Text('Deutsch')),
                  DropdownMenuItem(value: 'en', child: Text('English')),
                ],
                onChanged: busy ? null : (v) => setting('language', v),
              ),
              const SizedBox(height: 18),
              DropdownButtonFormField<String>(
                key: ValueKey("weight-unit-${settings['weight_unit']}"),
                initialValue: settings['weight_unit'],
                decoration: InputDecoration(
                  labelText: c.tr('Gewichtseinheit', 'Weight unit'),
                ),
                items: ['kg', 'lb']
                    .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                    .toList(),
                onChanged: busy ? null : (v) => setting('weight_unit', v),
              ),
            ],
          ),
        ),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Heading(
                c.tr('Bereiche in der Übersicht', 'Overview sections'),
                subtitle: c.tr(
                  'Ein- und Ausblenden verändert deine Daten nicht.',
                  'Showing or hiding sections keeps your data.',
                ),
              ),
              for (final area in areaNames)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(switch (area) {
                    'nutrition' => c.tr('Ernährung', 'Nutrition'),
                    'cycle' => c.tr('Zyklus', 'Cycle'),
                    'weight' => c.tr('Gewicht', 'Weight'),
                    _ => c.tr('Symptome', 'Symptoms'),
                  }),
                  value: settings['sections'][area],
                  onChanged: busy
                      ? null
                      : (v) async {
                          try {
                            await c.change(
                              (d) => d.settings['sections'][area] = v,
                            );
                          } catch (e) {
                            if (context.mounted) await notifyError(context, e);
                          }
                        },
                ),
            ],
          ),
        ),
        Panel(
          child: Column(
            children: [
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.tune),
                title: Text(
                  c.tr('Freiwillige Tagesziele', 'Optional daily goals'),
                ),
                subtitle: Text(
                  c.tr(
                    'Wasser, Energie, Protein, Kohlenhydrate, Fett',
                    'Water, energy, protein, carbohydrates, fat',
                  ),
                ),
                trailing: const Icon(Icons.chevron_right),
                onTap: busy
                    ? null
                    : () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const GoalsEditor()),
                      ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  c.tr(
                    'Persönliche Zykluseinschätzung',
                    'Personal cycle estimate',
                  ),
                ),
                subtitle: Text(
                  c.tr(
                    'Ausschalten für reinen Tagebuchmodus.',
                    'Turn off for journal-only mode.',
                  ),
                ),
                value: settings['cycle_prediction'],
                onChanged: busy ? null : (v) => setting('cycle_prediction', v),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(
                  c.tr(
                    'Open Food Facts online verwenden',
                    'Use Open Food Facts online',
                  ),
                ),
                subtitle: Text(
                  c.tr(
                    'Nur Suchtext und Barcode werden übertragen.',
                    'Only search text and barcodes are sent.',
                  ),
                ),
                value: settings['online_enabled'],
                onChanged: busy ? null : (v) => setting('online_enabled', v),
              ),
            ],
          ),
        ),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Heading(
                c.tr('Deine Daten', 'Your data'),
                subtitle: c.tr(
                  'Lokal verschlüsselt. Ohne Konto oder Telemetrie.',
                  'Encrypted locally. No account or telemetry.',
                ),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.lock_outline),
                title: Text(
                  c.tr('Verschlüsselte Sicherung', 'Encrypted backup'),
                ),
                subtitle: Text(
                  c.tr(
                    'Vollständiger Bestand · mit eigener Passphrase',
                    'Complete dataset · with your own passphrase',
                  ),
                ),
                onTap: busy ? null : backup,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.restore),
                title: Text(
                  c.tr('Sicherung wiederherstellen', 'Restore backup'),
                ),
                onTap: busy ? null : () => import(encrypted: true),
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.file_upload_outlined),
                title: Text(c.tr('JSON exportieren', 'Export JSON')),
                subtitle: Text(
                  c.tr(
                    'Vollständige maschinenlesbare Datei · unverschlüsselt',
                    'Complete machine-readable file · unencrypted',
                  ),
                ),
                onTap: busy ? null : exportPlain,
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.file_download_outlined),
                title: Text(c.tr('JSON importieren', 'Import JSON')),
                subtitle: Text(
                  c.tr(
                    'Ersetzt den aktuellen Bestand',
                    'Replaces the current dataset',
                  ),
                ),
                onTap: busy ? null : () => import(encrypted: false),
              ),
              const Divider(),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.delete_outline,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  c.tr('Alle lokalen Daten löschen', 'Delete all local data'),
                ),
                onTap: busy ? null : erase,
              ),
            ],
          ),
        ),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Heading('MorphHealth', subtitle: '1.0.0 · MH-PERSONAL-3'),
              Text(
                c.tr(
                  'Ein persönliches Werkzeug für Ernährung, Zyklus, Gewicht und Symptome. Alle vier Bereiche sind unabhängig nutzbar.',
                  'A personal tool for nutrition, cycle, weight and symptoms. All four sections work independently.',
                ),
              ),
              const SizedBox(height: 12),
              Text(
                c.tr(
                  'Lebensmitteldaten von Open Food Facts, unter ODbL 1.0. Keine Bilder werden geladen.',
                  'Food data from Open Food Facts, under ODbL 1.0. Images are not loaded.',
                ),
              ),
              const SizedBox(height: 12),
              Text(
                c.tr(
                  'Deine lokale Verschlüsselung schützt gespeicherte Dateien. Auf einem entsperrten Gerät ist dein Tagebuch in dieser App zugänglich. Bewahre eine Sicherung und deren Passphrase getrennt auf.',
                  'Local encryption protects stored files. On an unlocked device, this app can access your journal. Keep a backup and its passphrase separately.',
                ),
              ),
              TextButton(
                onPressed: () => showLicensePage(
                  context: context,
                  applicationName: 'MorphHealth',
                  applicationVersion: '1.0.0',
                ),
                child: Text(c.tr('Softwarelizenzen', 'Software licences')),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class GoalsEditor extends StatefulWidget {
  const GoalsEditor({super.key});
  @override
  State<GoalsEditor> createState() => _GoalsEditorState();
}

class _GoalsEditorState extends State<GoalsEditor> {
  final form = GlobalKey<FormState>(),
      values = <String, TextEditingController>{};
  bool initialized = false, busy = false;
  String? error;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (initialized) return;
    initialized = true;
    final c = AppScope.of(context);
    for (final key in ['water', 'calories', 'protein', 'carbs', 'fat']) {
      values[key] = TextEditingController(
        text: number(c.data.settings['goals'][key]) == null
            ? ''
            : c.fmt(c.data.settings['goals'][key], digits: 4),
      );
    }
  }

  @override
  void dispose() {
    for (final v in values.values) {
      v.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    final c = AppScope.of(context);
    setState(() {
      busy = true;
      error = null;
    });
    try {
      await c.change(
        (d) => d.settings['goals'] = {
          for (final e in values.entries)
            if (number(e.value.text) != null) e.key: number(e.value.text),
        },
      );
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          error = c.error(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    return FormFrame(
      title: c.tr('Deine Tagesziele', 'Your daily goals'),
      busy: busy,
      save: save,
      error: error,
      children: [
        Text(
          c.tr(
            'Du entscheidest, was du verfolgen möchtest. Leere Felder bedeuten kein Ziel.',
            'You choose what to track. Empty fields mean no goal.',
          ),
        ),
        const SizedBox(height: 20),
        Form(
          key: form,
          child: Column(
            children: [
              for (final key in values.keys)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: TextFormField(
                    key: ValueKey('goal-$key'),
                    controller: values[key],
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: InputDecoration(
                      labelText: key == 'water'
                          ? c.tr('Wasser', 'Water')
                          : nutrientById(key).name(c.language),
                      suffixText: key == 'water'
                          ? 'ml'
                          : nutrientById(key).unit,
                    ),
                    validator: (v) => numericValidation(v, c, optional: true),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
