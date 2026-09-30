import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../core/backup.dart';
import '../../core/issues.dart';
import '../../core/portable.dart';
import '../../platform/platform_bridge.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../state/app_state.dart';
import '../issue_text.dart';
import '../l10n_x.dart';
import '../widgets/common.dart';

/// Datei-Namensteil mit Datum: `2026-09-29`.
String _stamp(AppState app) => app.today.toString();

/// Lässt [work] auf einem Hintergrund-Thread laufen und zeigt währenddessen
/// einen Wartedialog (die Schlüsselableitung braucht einen Moment).
Future<T> runWithProgress<T>(BuildContext context, Future<T> Function() work) async {
  final l = context.l10n;
  final nav = Navigator.of(context, rootNavigator: true);
  unawaited(
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (c) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(width: 20),
              Expanded(child: Semantics(liveRegion: true, child: Text(l.dataWorking))),
            ],
          ),
        ),
      ),
    ),
  );
  try {
    return await work();
  } finally {
    nav.pop();
  }
}

/// Fragt eine Passphrase ab (bei [confirm] zweimal). Liefert null bei Abbruch.
Future<String?> askPassphrase(BuildContext context, {required bool confirm, required String title, String? warning}) {
  return showDialog<String>(
    context: context,
    builder: (c) => _PassphraseDialog(confirm: confirm, title: title, warning: warning),
  );
}

class _PassphraseDialog extends StatefulWidget {
  final bool confirm;
  final String title;
  final String? warning;

  const _PassphraseDialog({required this.confirm, required this.title, this.warning});

  @override
  State<_PassphraseDialog> createState() => _PassphraseDialogState();
}

class _PassphraseDialogState extends State<_PassphraseDialog> {
  final _form = GlobalKey<FormState>();
  final _a = TextEditingController();
  final _b = TextEditingController();
  bool _show = false;

  @override
  void dispose() {
    _a.dispose();
    _b.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (widget.warning != null) ...[
                Text(widget.warning!, style: context.text.bodyMedium),
                const SizedBox(height: 12),
              ],
              TextFormField(
                controller: _a,
                autofocus: true,
                obscureText: !_show,
                enableSuggestions: false,
                autocorrect: false,
                keyboardType: TextInputType.visiblePassword,
                decoration: InputDecoration(
                  labelText: l.dataPassphrase,
                  suffixIcon: IconButton(
                    tooltip: _show ? l.commonHide : l.commonShow,
                    icon: Icon(_show ? Icons.visibility_off : Icons.visibility),
                    onPressed: () => setState(() => _show = !_show),
                  ),
                ),
                validator: (v) {
                  if ((v ?? '').isEmpty) return l.commonRequired;
                  if (widget.confirm && v!.length < kMinPassphraseLength) {
                    return l.dataPassphraseShort('$kMinPassphraseLength');
                  }
                  return null;
                },
              ),
              if (widget.confirm) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _b,
                  obscureText: !_show,
                  enableSuggestions: false,
                  autocorrect: false,
                  keyboardType: TextInputType.visiblePassword,
                  decoration: InputDecoration(labelText: l.dataPassphraseRepeat),
                  validator: (v) => v != _a.text ? l.dataPassphraseMismatch : null,
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(l.commonCancel)),
        FilledButton(
          onPressed: () {
            if (_form.currentState!.validate()) Navigator.pop(context, _a.text);
          },
          child: Text(l.commonOk),
        ),
      ],
    );
  }
}

/// Zeigt Fehler eines ungültigen Dokuments (Pfad und Grund).
/// Meldung zu einem Fehler der Dateiauswahl in der Sprache der App.
String _platformError(AppLocalizations l, PlatformFailure e) => switch (e.code) {
  'too_large' => l.dataFileTooLarge,
  'busy' => l.errPickerBusy,
  _ => l.commonError(e.message),
};

Future<void> showIssuesDialog(BuildContext context, String title, List<Issue> issues) {
  final l = context.l10n;
  return showDialog<void>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final i in issues.take(12))
              ListTile(dense: true, title: Text(issueMessage(context.fmt.lang, i.message)), subtitle: Text(i.path)),
          ],
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(c), child: Text(l.commonClose))],
    ),
  );
}

/// Ablauf "Datei prüfen und Bestand ersetzen" für Import und Wiederherstellung.
/// Liefert die Zahl der Datensätze oder null bei Abbruch oder Fehler.
Future<int?> confirmAndImport(BuildContext context, AppState app, Object? document, {bool restore = false}) async {
  final l = context.l10n;
  final ParsedImport parsed;
  try {
    parsed = app.core.previewImport(document);
  } on ValidationException catch (e) {
    if (context.mounted) await showIssuesDialog(context, l.dataImportInvalid, e.issues);
    return null;
  }
  if (!context.mounted) return null;
  final r = parsed.report;
  final hasData = app.db.totalRecords > 0;
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(restore ? l.dataRestorePreviewTitle : l.dataImportPreviewTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.dataImportSummary('${r.total}')),
            if (r.warnings.isNotEmpty || r.droppedWarnings > 0) ...[
              const SizedBox(height: 8),
              Text(l.dataImportWarnings('${r.warnings.length + r.droppedWarnings}')),
            ],
            if (hasData) ...[
              const SizedBox(height: 12),
              Text(
                l.dataImportReplaceWarning,
                style: TextStyle(fontWeight: FontWeight.w600, color: c.colors.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l.commonCancel)),
        FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(l.dataImportConfirm)),
      ],
    ),
  );
  if (ok != true) return null;
  final report = await app.core.importDocument(document);
  return report.total;
}

class DataScreen extends StatelessWidget {
  const DataScreen({super.key});

  Future<void> _export(BuildContext context) async {
    final app = AppScope.read(context);
    final l = context.l10n;
    final ok = await confirmDialog(
      context,
      title: l.dataExportWarnTitle,
      message: l.dataExportWarnMessage,
      confirmLabel: l.dataExportButton,
    );
    if (!ok || !context.mounted) return;
    final doc = app.core.exportDocument();
    final text = app.db.totalRecords < 3000 ? const JsonEncoder.withIndent('  ').convert(doc) : jsonEncode(doc);
    try {
      final name = await app.session.platform.saveDocument(
        name: 'morphhealth-export-${_stamp(app)}.json',
        mime: 'application/json',
        bytes: Uint8List.fromList(utf8.encode(text)),
      );
      if (name != null && context.mounted) showMessage(context, l.dataExportDone(name));
    } on PlatformFailure catch (e) {
      if (context.mounted) showMessage(context, _platformError(l, e));
    }
  }

  Future<PickedDocument?> _pick(BuildContext context, AppState app) async {
    final l = context.l10n;
    try {
      return await app.session.platform.openDocument();
    } on PlatformFailure catch (e) {
      if (context.mounted) showMessage(context, _platformError(l, e));
      return null;
    }
  }

  Future<void> _import(BuildContext context) async {
    final app = AppScope.read(context);
    final l = context.l10n;
    final doc = await _pick(context, app);
    if (doc == null || !context.mounted) return;
    Object? json;
    try {
      json = jsonDecode(utf8.decode(doc.bytes));
    } on Object {
      showMessage(context, l.dataImportInvalidJson);
      return;
    }
    final count = await confirmAndImport(context, app, json);
    if (count != null && context.mounted) showMessage(context, l.dataImportDone('$count'));
  }

  Future<void> _backup(BuildContext context) async {
    final app = AppScope.read(context);
    final l = context.l10n;
    final pass = await askPassphrase(context, confirm: true, title: l.dataBackupCreate, warning: l.dataBackupWarning);
    if (pass == null || !context.mounted) return;
    final doc = app.core.exportDocument();
    final Uint8List bytes;
    try {
      bytes = await runWithProgress(context, () => Isolate.run(() => createBackup(doc, pass)));
    } on BackupException catch (e) {
      if (context.mounted) showMessage(context, l.commonError(e.message));
      return;
    }
    if (!context.mounted) return;
    try {
      final name = await app.session.platform.saveDocument(
        name: 'morphhealth-${_stamp(app)}.$kBackupExtension',
        mime: kBackupMime,
        bytes: bytes,
      );
      if (name != null && context.mounted) showMessage(context, l.dataBackupDone(name));
    } on PlatformFailure catch (e) {
      if (context.mounted) showMessage(context, _platformError(l, e));
    }
  }

  Future<void> _restore(BuildContext context) async {
    final app = AppScope.read(context);
    final l = context.l10n;
    final file = await _pick(context, app);
    if (file == null || !context.mounted) return;
    final pass = await askPassphrase(context, confirm: false, title: l.dataRestoreTitle);
    if (pass == null || !context.mounted) return;
    final Map<String, Object?> doc;
    try {
      doc = await runWithProgress(context, () => Isolate.run(() => openBackup(file.bytes, pass)));
    } on BackupException catch (e) {
      if (context.mounted) {
        showMessage(context, switch (e.code) {
          'wrong_passphrase' => l.dataRestoreWrong,
          'not_a_backup' => l.dataRestoreNotBackup,
          'unsupported' => l.errBackupUnsupported,
          'corrupt' => l.errBackupCorrupt,
          _ => l.commonError(e.message),
        });
      }
      return;
    }
    if (!context.mounted) return;
    final count = await confirmAndImport(context, app, doc, restore: true);
    if (count != null && context.mounted) showMessage(context, l.dataRestoreDone('$count'));
  }

  Future<void> _wipe(BuildContext context) async {
    final app = AppScope.read(context);
    final l = context.l10n;
    final ok = await confirmDialog(
      context,
      title: l.dataWipeConfirmTitle,
      message: l.dataWipeConfirmMessage,
      confirmLabel: l.dataWipeButton,
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    await app.wipeAll();
    nav.popUntil((r) => r.isFirst);
    messenger.showSnackBar(SnackBar(content: Text(l.dataWipeDone)));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    Widget block({
      required IconData icon,
      required String title,
      required String hint,
      required String button,
      required VoidCallback onPressed,
      bool danger = false,
    }) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, color: danger ? context.colors.error : context.colors.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Semantics(header: true, child: Text(title, style: context.text.titleMedium)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(hint, style: context.text.bodyMedium),
              const SizedBox(height: 12),
              danger
                  ? FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: context.colors.error,
                        foregroundColor: context.colors.onError,
                      ),
                      onPressed: onPressed,
                      child: Text(button),
                    )
                  : FilledButton.tonal(onPressed: onPressed, child: Text(button)),
            ],
          ),
        ),
      );
    }

    return AppScaffold(
      appBar: AppBar(title: Text(l.dataTitle)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
        children: [
          block(
            icon: Icons.file_upload_outlined,
            title: l.dataExportTitle,
            hint: l.dataExportHint,
            button: l.dataExportButton,
            onPressed: () => _export(context),
          ),
          const SizedBox(height: 12),
          block(
            icon: Icons.file_download_outlined,
            title: l.dataImportTitle,
            hint: l.dataImportHint,
            button: l.dataImportButton,
            onPressed: () => _import(context),
          ),
          const SizedBox(height: 12),
          block(
            icon: Icons.enhanced_encryption_outlined,
            title: l.dataBackupTitle,
            hint: l.dataBackupHint,
            button: l.dataBackupCreate,
            onPressed: () => _backup(context),
          ),
          const SizedBox(height: 12),
          block(
            icon: Icons.settings_backup_restore,
            title: l.dataRestoreTitle,
            hint: l.dataRestoreHint,
            button: l.dataRestoreButton,
            onPressed: () => _restore(context),
          ),
          const SizedBox(height: 12),
          block(
            icon: Icons.delete_forever_outlined,
            title: l.dataWipeTitle,
            hint: l.dataWipeHint,
            button: l.dataWipeButton,
            onPressed: () => _wipe(context),
            danger: true,
          ),
        ],
      ),
    );
  }
}
