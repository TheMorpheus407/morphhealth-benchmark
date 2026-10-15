import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/models.dart';
import '../../core/repository.dart';
import '../app_state.dart';
import '../modals/entry_modals.dart';

class HistorySettingsTab extends StatefulWidget {
  final MorphHealthController ctrl;

  const HistorySettingsTab({super.key, required this.ctrl});

  @override
  State<HistorySettingsTab> createState() => _HistorySettingsTabState();
}

class _HistorySettingsTabState extends State<HistorySettingsTab>
    with SingleTickerProviderStateMixin {
  late final TabController _subTabCtrl;
  final TextEditingController _queryCtrl = TextEditingController();
  final TextEditingController _fromDateCtrl = TextEditingController();
  final TextEditingController _toDateCtrl = TextEditingController();
  String _selectedDomain = 'all';

  @override
  void initState() {
    super.initState();
    _subTabCtrl = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _subTabCtrl.dispose();
    _queryCtrl.dispose();
    _fromDateCtrl.dispose();
    _toDateCtrl.dispose();
    super.dispose();
  }

  void _openHistoryRecord(BuildContext context, HistoryRecord rec) {
    final ctrl = widget.ctrl;
    final raw = rec.rawEntry;
    if (raw is FoodDiaryEntry) {
      showFoodEntryEditorSheet(context, ctrl, existingEntry: raw);
    } else if (raw is WaterEntry) {
      showWaterEntryDialog(context, ctrl, existing: raw);
    } else if (raw is CaffeineEntry) {
      showCaffeineEntryDialog(context, ctrl, existing: raw);
    } else if (raw is PeriodEntry) {
      showPeriodEntryDialog(context, ctrl, existing: raw);
    } else if (raw is WeightEntry) {
      showWeightEntryDialog(context, ctrl, existing: raw);
    } else if (raw is SymptomEntry) {
      showSymptomEntryDialog(context, ctrl, existing: raw);
    }
  }

  IconData _iconForRecord(HistoryRecord r) {
    switch (r.subType) {
      case 'food':
        return Icons.restaurant;
      case 'water':
        return Icons.water_drop_outlined;
      case 'caffeine':
        return Icons.coffee_outlined;
      case 'period':
        return Icons.favorite_border;
      case 'weight':
        return Icons.monitor_weight_outlined;
      case 'symptom':
      default:
        return Icons.healing_outlined;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.ctrl.s;
    return Column(
      children: [
        TabBar(
          controller: _subTabCtrl,
          tabs: [
            Tab(
              icon: const Icon(Icons.manage_search, size: 18),
              text: s.searchableHistory,
            ),
            Tab(
              icon: const Icon(Icons.settings_outlined, size: 18),
              text: s.t('Daten & Einstellungen', 'Data & Settings'),
            ),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _subTabCtrl,
            children: [
              _buildHistoryView(context),
              _buildSettingsAndDataView(context),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryView(BuildContext context) {
    final ctrl = widget.ctrl;
    final s = ctrl.s;
    final records = ctrl.repository.searchHistory(
      fromDate: _fromDateCtrl.text.trim(),
      toDate: _toDateCtrl.text.trim(),
      domain: _selectedDomain,
      query: _queryCtrl.text,
      lang: ctrl.lang,
    );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: TextField(
            controller: _queryCtrl,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: s.t(
                'Freitextsuche (Name, Marke, Notiz, Mahlzeit …)',
                'Free-text search (Name, brand, note, meal …)',
              ),
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _queryCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _queryCtrl.clear();
                        setState(() {});
                      },
                    )
                  : null,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _fromDateCtrl,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: s.t('Von (YYYY-MM-DD)', 'From (YYYY-MM-DD)'),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _toDateCtrl,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: s.t('Bis (YYYY-MM-DD)', 'To (YYYY-MM-DD)'),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              if (_fromDateCtrl.text.isNotEmpty || _toDateCtrl.text.isNotEmpty)
                IconButton(
                  tooltip: s.t('Datumsfilter zurücksetzen', 'Clear dates'),
                  icon: const Icon(Icons.filter_alt_off),
                  onPressed: () {
                    _fromDateCtrl.clear();
                    _toDateCtrl.clear();
                    setState(() {});
                  },
                ),
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              _DomainFilterChip(
                label: s.domainAll,
                selected: _selectedDomain == 'all',
                onSelected: () => setState(() => _selectedDomain = 'all'),
              ),
              const SizedBox(width: 6),
              _DomainFilterChip(
                label: s.domainNutrition,
                selected: _selectedDomain == 'nutrition',
                onSelected: () => setState(() => _selectedDomain = 'nutrition'),
              ),
              const SizedBox(width: 6),
              _DomainFilterChip(
                label: s.domainCycle,
                selected: _selectedDomain == 'cycle',
                onSelected: () => setState(() => _selectedDomain = 'cycle'),
              ),
              const SizedBox(width: 6),
              _DomainFilterChip(
                label: s.domainWeight,
                selected: _selectedDomain == 'weight',
                onSelected: () => setState(() => _selectedDomain = 'weight'),
              ),
              const SizedBox(width: 6),
              _DomainFilterChip(
                label: s.domainSymptoms,
                selected: _selectedDomain == 'symptoms',
                onSelected: () => setState(() => _selectedDomain = 'symptoms'),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  s.t(
                    '${records.length} Einträge gefunden (Gesamtbestand: ${ctrl.repository.totalDiaryEntryCount})',
                    '${records.length} entries found (Total stored: ${ctrl.repository.totalDiaryEntryCount})',
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                s.t('Antippen zum Bearbeiten', 'Tap to edit'),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: records.isEmpty
              ? Center(
                  child: Text(
                    s.t(
                      'Keine Einträge für die gewählten Filter gefunden.',
                      'No entries found matching the selected filters.',
                    ),
                  ),
                )
              : ListView.separated(
                  itemCount: records.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final r = records[i];
                    return ListTile(
                      dense: true,
                      leading: Icon(_iconForRecord(r)),
                      title: Text(
                        r.title,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        '${r.date} · ${r.subtitle}'
                        '${r.notes != null ? ' · ${r.notes}' : ''}',
                      ),
                      trailing: const Icon(Icons.edit_outlined, size: 18),
                      onTap: () => _openHistoryRecord(context, r),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildSettingsAndDataView(BuildContext context) {
    final ctrl = widget.ctrl;
    final s = ctrl.s;
    final settings = ctrl.settings;

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 40),
      children: [
        // 1. Language & Units
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.t('Sprache & Einheiten', 'Language & Units'),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(s.t('Oberflächensprache', 'Interface Language')),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'de', label: Text('Deutsch')),
                        ButtonSegment(value: 'en', label: Text('English')),
                      ],
                      selected: {settings.language},
                      onSelectionChanged: (sel) => ctrl.setLanguage(sel.first),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(s.t('Gewichtseinheit', 'Weight Unit')),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'kg', label: Text('kg')),
                        ButtonSegment(value: 'lb', label: Text('lb')),
                      ],
                      selected: {settings.weightUnit},
                      onSelectionChanged: (sel) =>
                          ctrl.setWeightUnit(sel.first),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // 2. Online Food Search & Privacy Control (P07 & P08)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.t(
                    'Open Food Facts & Online-Verbindung',
                    'Open Food Facts & Online Connection',
                  ),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    s.t(
                      'Online-Lebensmittelsuche aktivieren',
                      'Enable Online Food Search',
                    ),
                  ),
                  subtitle: Text(
                    s.t(
                      'Nur lesende Abfragen an ${ctrl.foodApiBaseUrl}. Persönliche Gesundheitsdaten verlassen das Gerät nie.',
                      'Read-only queries to ${ctrl.foodApiBaseUrl}. Personal health data never leaves your device.',
                    ),
                  ),
                  value: settings.onlineFoodSearchEnabled,
                  onChanged: (v) => ctrl.updateSettings(
                    settings.copyWith(onlineFoodSearchEnabled: v),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // 3. Passphrase-Protected Encrypted Backups (.mhb) (P07)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.encryptedBackup,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  s.t(
                    'Erstellt oder lädt eine passphrasengeschützte Sicherung (PBKDF2-HMAC-SHA256 + AES-256-GCM), geeignet zur Übernahme auf eine frische Installation.',
                    'Creates or restores a passphrase-protected backup (PBKDF2-HMAC-SHA256 + AES-256-GCM), suitable for migrating to a fresh installation.',
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      icon: const Icon(Icons.lock_outline, size: 18),
                      label: Text(
                        s.t(
                          'Verschlüsselte Sicherung erstellen',
                          'Create Encrypted Backup',
                        ),
                      ),
                      onPressed: () =>
                          _showCreateEncryptedBackupDialog(context, ctrl),
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.lock_open_outlined, size: 18),
                      label: Text(
                        s.t(
                          'Sicherung wiederherstellen',
                          'Restore Backup',
                        ),
                      ),
                      onPressed: () =>
                          _showRestoreEncryptedBackupDialog(context, ctrl),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // 4. Machine-Readable Portable JSON Export & Import (P07)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.portableExportImport,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  s.t(
                    'Vollständiger, dokumentierter Datenexport und -import im Format morphhealth.portable.v1 (identisch zum Wartungszugang ./mh).',
                    'Complete, documented data export and import in morphhealth.portable.v1 format (identical to the ./mh maintenance interface).',
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.tonalIcon(
                      icon: const Icon(Icons.upload_file, size: 18),
                      label: Text(s.t('JSON exportieren', 'Export JSON')),
                      onPressed: () => _showPortableExportDialog(context, ctrl),
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.download_outlined, size: 18),
                      label: Text(s.t('JSON importieren', 'Import JSON')),
                      onPressed: () => _showPortableImportDialog(context, ctrl),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // 5. Sample Data, 10k Bulk Test & Complete Wipe (P06 & P07)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.t(
                    'Datenbestand & Zurücksetzen',
                    'Dataset Management & Reset',
                  ),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    OutlinedButton.icon(
                      icon: const Icon(Icons.dataset_outlined, size: 18),
                      label: Text(
                        s.t('Beispieldatensatz laden', 'Load Sample Dataset'),
                      ),
                      onPressed: () async {
                        await ctrl.loadSampleDataset();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                s.t(
                                  'Beispieldatensatz geladen.',
                                  'Sample dataset loaded.',
                                ),
                              ),
                            ),
                          );
                        }
                      },
                    ),
                    OutlinedButton.icon(
                      icon: const Icon(Icons.speed, size: 18),
                      label: Text(
                        s.t(
                          '10.000 Einträge generieren (Lasttest)',
                          'Generate 10,000 Entries (Stress Test)',
                        ),
                      ),
                      onPressed: () async {
                        await ctrl.generateBulk10kDataset();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                s.t(
                                  '10.000 Tagebucheinträge erfolgreich generiert.',
                                  '10,000 diary entries generated.',
                                ),
                              ),
                            ),
                          );
                        }
                      },
                    ),
                    FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.error,
                        foregroundColor: Theme.of(context).colorScheme.onError,
                      ),
                      icon: const Icon(Icons.delete_forever, size: 18),
                      label: Text(s.deleteAllData),
                      onPressed: () => _confirmDeleteAll(context, ctrl),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showCreateEncryptedBackupDialog(
    BuildContext context,
    MorphHealthController ctrl,
  ) async {
    final s = ctrl.s;
    final passCtrl = TextEditingController();
    String? statusMsg;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(s.encryptedBackup),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: passCtrl,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: s.t('Passphrase *', 'Passphrase *'),
                  border: const OutlineInputBorder(),
                ),
              ),
              if (statusMsg != null) ...[
                const SizedBox(height: 10),
                Text(statusMsg!, style: const TextStyle(fontSize: 12)),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(s.close),
            ),
            OutlinedButton(
              onPressed: () async {
                final pass = passCtrl.text;
                if (pass.isEmpty) return;
                final content =
                    await ctrl.createEncryptedBackupJsonString(pass);
                final file = await ctrl.saveLocalExportFile(
                  'morphhealth_backup.mhb',
                  content,
                );
                await Clipboard.setData(ClipboardData(text: content));
                setDialogState(() {
                  statusMsg = s.t(
                    'Lokal gespeichert (${file.path}) & in Zwischenablage kopiert.',
                    'Saved locally (${file.path}) & copied to clipboard.',
                  );
                });
              },
              child: Text(s.t('Lokal & Kopieren', 'Save Local & Copy')),
            ),
            FilledButton(
              onPressed: () async {
                final pass = passCtrl.text;
                if (pass.isEmpty) return;
                final content =
                    await ctrl.createEncryptedBackupJsonString(pass);
                await ctrl.saveLocalExportFile(
                  'morphhealth_backup.mhb',
                  content,
                );
                final uri = await ctrl.saveWithAndroidDocumentPicker(
                  suggestedName: 'morphhealth_backup.mhb',
                  mimeType: 'application/octet-stream',
                  content: content,
                );
                if (ctx.mounted) {
                  Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        uri != null
                            ? s.t(
                                'Verschlüsselte Sicherung gespeichert: $uri',
                                'Encrypted backup saved: $uri',
                              )
                            : s.t(
                                'Verschlüsselte Sicherung im App-Exportordner gespeichert.',
                                'Encrypted backup saved in app exports folder.',
                              ),
                      ),
                    ),
                  );
                }
              },
              child: Text(s.t('Datei speichern …', 'Save File …')),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showRestoreEncryptedBackupDialog(
    BuildContext context,
    MorphHealthController ctrl,
  ) async {
    final s = ctrl.s;
    final passCtrl = TextEditingController();
    final jsonCtrl = TextEditingController();
    String? errorMsg;

    final localFiles = ctrl
        .listLocalExportFiles()
        .where((f) => f.path.endsWith('.mhb'))
        .toList();
    if (localFiles.isNotEmpty) {
      jsonCtrl.text = localFiles.first.readAsStringSync();
    }

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(
            s.t('Verschlüsselte Sicherung wiederherstellen', 'Restore Encrypted Backup'),
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.folder_open),
                  label: Text(
                    s.t(
                      'Datei über Android-Dateiauswahl öffnen …',
                      'Pick File via Android Document Picker …',
                    ),
                  ),
                  onPressed: () async {
                    final picked = await ctrl.openWithAndroidDocumentPicker();
                    if (picked != null && picked.isNotEmpty) {
                      setDialogState(() => jsonCtrl.text = picked);
                    }
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: passCtrl,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: s.t('Passphrase *', 'Passphrase *'),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: jsonCtrl,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: s.t(
                      'Sicherungsdaten (.mhb JSON)',
                      'Backup Payload (.mhb JSON)',
                    ),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                if (errorMsg != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    errorMsg!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(s.cancel),
            ),
            FilledButton(
              onPressed: () async {
                try {
                  final report = await ctrl.restoreEncryptedBackupJsonString(
                    jsonCtrl.text.trim(),
                    passCtrl.text,
                  );
                  if (ctx.mounted) {
                    Navigator.of(ctx).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          s.t(
                            'Sicherung erfolgreich wiederhergestellt (${report['counts']?['total_entries'] ?? 0} Einträge).',
                            'Backup successfully restored (${report['counts']?['total_entries'] ?? 0} entries).',
                          ),
                        ),
                      ),
                    );
                  }
                } catch (e) {
                  setDialogState(() => errorMsg = e.toString());
                }
              },
              child: Text(s.t('Wiederherstellen', 'Restore')),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPortableExportDialog(
    BuildContext context,
    MorphHealthController ctrl,
  ) async {
    final s = ctrl.s;
    bool ackPlaintext = false;

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(s.t('Maschinenlesbarer Datenexport', 'Portable Data Export')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: ackPlaintext,
                onChanged: (v) =>
                    setDialogState(() => ackPlaintext = v ?? false),
                title: Text(
                  s.t(
                    'Mir ist bewusst, dass dieser JSON-Export unverschlüsselten Klartext enthält (ack_plaintext).',
                    'I acknowledge that this JSON export contains unencrypted plaintext (ack_plaintext).',
                  ),
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(s.cancel),
            ),
            OutlinedButton(
              onPressed: !ackPlaintext
                  ? null
                  : () async {
                      final doc = ctrl.repository
                          .exportPortableDocument(ackPlaintext: true);
                      final jsonStr =
                          const JsonEncoder.withIndent('  ').convert(doc);
                      final file = await ctrl.saveLocalExportFile(
                        'morphhealth_export.json',
                        jsonStr,
                      );
                      await Clipboard.setData(ClipboardData(text: jsonStr));
                      if (ctx.mounted) {
                        Navigator.of(ctx).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              s.t(
                                'Export gespeichert (${file.path}) & in Zwischenablage kopiert.',
                                'Export saved (${file.path}) & copied to clipboard.',
                              ),
                            ),
                          ),
                        );
                      }
                    },
              child: Text(s.t('Lokal & Kopieren', 'Save Local & Copy')),
            ),
            FilledButton(
              onPressed: !ackPlaintext
                  ? null
                  : () async {
                      final doc = ctrl.repository
                          .exportPortableDocument(ackPlaintext: true);
                      final jsonStr =
                          const JsonEncoder.withIndent('  ').convert(doc);
                      await ctrl.saveLocalExportFile(
                        'morphhealth_export.json',
                        jsonStr,
                      );
                      final uri = await ctrl.saveWithAndroidDocumentPicker(
                        suggestedName: 'morphhealth_export.json',
                        mimeType: 'application/json',
                        content: jsonStr,
                      );
                      if (ctx.mounted) {
                        Navigator.of(ctx).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              uri != null
                                  ? s.t(
                                      'JSON-Export gespeichert: $uri',
                                      'JSON export saved: $uri',
                                    )
                                  : s.t(
                                      'JSON-Export im App-Exportordner gespeichert.',
                                      'JSON export saved in app exports folder.',
                                    ),
                            ),
                          ),
                        );
                      }
                    },
              child: Text(s.t('Datei speichern …', 'Save File …')),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showPortableImportDialog(
    BuildContext context,
    MorphHealthController ctrl,
  ) async {
    final s = ctrl.s;
    bool confirmReplace = false;
    final jsonCtrl = TextEditingController();
    String? errorMsg;

    final localJsonFiles = ctrl
        .listLocalExportFiles()
        .where((f) => f.path.endsWith('.json'))
        .toList();
    if (localJsonFiles.isNotEmpty) {
      jsonCtrl.text = localJsonFiles.first.readAsStringSync();
    }

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(s.t('Maschinenlesbarer Datenimport', 'Portable Data Import')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                OutlinedButton.icon(
                  icon: const Icon(Icons.folder_open),
                  label: Text(
                    s.t(
                      'JSON-Datei über Android-Dateiauswahl öffnen …',
                      'Pick JSON File via Android Document Picker …',
                    ),
                  ),
                  onPressed: () async {
                    final picked = await ctrl.openWithAndroidDocumentPicker();
                    if (picked != null && picked.isNotEmpty) {
                      setDialogState(() => jsonCtrl.text = picked);
                    }
                  },
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: jsonCtrl,
                  maxLines: 5,
                  decoration: InputDecoration(
                    labelText: s.t(
                      'Portable JSON (morphhealth.portable.v1)',
                      'Portable JSON (morphhealth.portable.v1)',
                    ),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 8),
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  value: confirmReplace,
                  onChanged: (v) =>
                      setDialogState(() => confirmReplace = v ?? false),
                  title: Text(
                    s.t(
                      'Aktuellen Datenbestand durch diesen Import vollständig ersetzen (confirm_replace).',
                      'Replace current working dataset with this import (confirm_replace).',
                    ),
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
                if (errorMsg != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    errorMsg!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontSize: 12,
                    ),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text(s.cancel),
            ),
            FilledButton(
              onPressed: !confirmReplace
                  ? null
                  : () async {
                      try {
                        final report = await ctrl.importPortableJsonString(
                          jsonCtrl.text.trim(),
                          confirmReplace: true,
                        );
                        if (ctx.mounted) {
                          Navigator.of(ctx).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                s.t(
                                  'Import erfolgreich (${report['counts']?['total_entries'] ?? 0} Einträge übernommen).',
                                  'Import successful (${report['counts']?['total_entries'] ?? 0} entries imported).',
                                ),
                              ),
                            ),
                          );
                        }
                      } catch (e) {
                        setDialogState(() => errorMsg = e.toString());
                      }
                    },
              child: Text(s.t('Importieren', 'Import')),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteAll(
    BuildContext context,
    MorphHealthController ctrl,
  ) async {
    final s = ctrl.s;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(s.deleteAllData),
        content: Text(
          s.t(
            'Möchtest du wirklich alle lokal gespeicherten Einträge, eigenen Lebensmittel und Einstellungen unwiderruflich löschen?',
            'Do you really want to permanently delete all locally stored entries, custom foods, and settings?',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(s.cancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(s.delete),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ctrl.deleteAllData();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              s.t(
                'Gesamter lokaler Datenbestand wurde gelöscht.',
                'All local data has been deleted.',
              ),
            ),
          ),
        );
      }
    }
  }
}

class _DomainFilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onSelected;

  const _DomainFilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onSelected(),
    );
  }
}
