import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../core/portable/backup.dart';
import '../../../core/portable/portable_codec.dart';
import '../../../core/util/local_date.dart';
import '../../controller.dart';
import '../../widgets/common.dart';

String _stamp(LocalDate d) => d.toIso();

/// Plaintext JSON export via the system "save as" dialog.
Future<void> exportData(BuildContext context) async {
  final app = context.appRead;
  final s = app.s;
  final ok = await confirm(
    context,
    title: s.exportWarningTitle,
    message: s.exportWarning,
    confirmLabel: s.exportAck,
  );
  if (!ok) return;
  final json = const JsonEncoder.withIndent('  ').convert(app.service.exportDocument());
  final bytes = Uint8List.fromList(utf8.encode(json));
  try {
    final saved = await app.platform.createDocument(
      name: 'morphhealth-export-${_stamp(app.today)}.json',
      mimeType: 'application/json',
      bytes: bytes,
    );
    app.showMessage(saved ? s.exportDone : s.cancelled);
  } catch (_) {
    app.showMessage(s.fileSaveFailed);
  }
}

/// Imports a JSON export, replacing all data after confirmation.
Future<void> importData(BuildContext context) async {
  final app = context.appRead;
  final s = app.s;
  Uint8List? bytes;
  try {
    bytes = await app.platform.openDocument(['application/json', 'text/plain', 'application/octet-stream']);
  } catch (_) {
    app.showMessage(s.fileOpenFailed);
    return;
  }
  if (bytes == null || !context.mounted) return;
  final ok = await confirm(
    context,
    title: s.importData,
    message: s.importConfirm,
    confirmLabel: s.importData,
    destructive: true,
  );
  if (!ok || !context.mounted) return;
  final data = bytes;
  final now = app.service.clock.nowUtc();
  try {
    // Parsing and validation of large files run in a background isolate.
    final decoded = await _withProgress(
      context,
      s.loading,
      () => Isolate.run(() {
        Object? json;
        try {
          json = jsonDecode(utf8.decode(data));
        } on FormatException {
          throw const _UnreadableFile();
        }
        return decodePortable(json, now: now);
      }),
      rethrowErrors: true,
    );
    if (decoded == null) return;
    final report = await app.service.importDecoded(decoded);
    app.showMessage(s.importDone(report.diaryEntries));
  } on _UnreadableFile {
    app.showMessage(s.importFailed(s.fileOpenFailed));
  } catch (e) {
    app.showMessage(app.errorMessage(e));
  }
}

class _UnreadableFile implements Exception {
  const _UnreadableFile();
}

/// Creates a passphrase-protected backup file.
Future<void> createBackupFile(BuildContext context) async {
  final app = context.appRead;
  final s = app.s;
  final passphrase = await showDialog<String>(
    context: context,
    builder: (_) => const _PassphraseDialog(confirm: true),
  );
  if (passphrase == null || !context.mounted) return;
  final document = app.service.exportDocument();
  final now = app.service.clock.nowUtc();
  final bytes = await _withProgress(
    context,
    s.backupWorking,
    () => Isolate.run(() => createBackup(document, passphrase, now: now)),
  );
  if (bytes == null) return;
  try {
    final saved = await app.platform.createDocument(
      name: 'morphhealth-backup-${_stamp(app.today)}.${BackupFormat.fileExtension}',
      mimeType: 'application/octet-stream',
      bytes: bytes,
    );
    app.showMessage(saved ? s.backupDone : s.cancelled);
  } catch (_) {
    app.showMessage(s.fileSaveFailed);
  }
}

/// Restores a backup file (replaces all data).
Future<void> restoreBackupFile(BuildContext context) async {
  final app = context.appRead;
  final s = app.s;
  Uint8List? bytes;
  try {
    bytes = await app.platform.openDocument(['*/*']);
  } catch (_) {
    app.showMessage(s.fileOpenFailed);
    return;
  }
  if (bytes == null || !context.mounted) return;
  final ok = await confirm(
    context,
    title: s.restoreBackup,
    message: s.restoreConfirm,
    confirmLabel: s.restoreBackup,
    destructive: true,
  );
  if (!ok || !context.mounted) return;
  final passphrase = await showDialog<String>(
    context: context,
    builder: (_) => const _PassphraseDialog(confirm: false),
  );
  if (passphrase == null || !context.mounted) return;
  final data = bytes;
  final now = app.service.clock.nowUtc();
  try {
    // Key derivation, decryption and validation run in a background isolate.
    final decoded = await _withProgress(
      context,
      s.loading,
      () => Isolate.run(() async => decodePortable(await openBackup(data, passphrase), now: now)),
      rethrowErrors: true,
    );
    if (decoded == null) return;
    final report = await app.service.importDecoded(decoded);
    app.showMessage(s.restoreDone(report.diaryEntries));
  } catch (e) {
    app.showMessage(app.errorMessage(e));
  }
}

/// Deletes everything after the user typed the confirmation word.
Future<void> deleteAllData(BuildContext context) async {
  final app = context.appRead;
  final s = app.s;
  final controller = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (dialogContext, setState) => AlertDialog(
        title: Text(s.deleteAllData),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.deleteAllConfirm),
            const SizedBox(height: 8),
            Text(s.cannotUndo),
            const SizedBox(height: 16),
            Text(s.deleteAllTypeWord),
            TextField(
              controller: controller,
              autofocus: true,
              onChanged: (_) => setState(() {}),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: Text(s.cancel)),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              foregroundColor: Theme.of(dialogContext).colorScheme.onError,
            ),
            onPressed: _foldUmlauts(controller.text) == _foldUmlauts(s.deleteAllWord)
                ? () => Navigator.pop(dialogContext, true)
                : null,
            child: Text(s.delete),
          ),
        ],
      ),
    ),
  );
  if (ok != true || !context.mounted) return;
  Navigator.of(context).popUntil((r) => r.isFirst);
  await app.onResetRequested();
}

/// Case-insensitive comparison key that also accepts "LOESCHEN" for
/// "LÖSCHEN" (keyboards without umlauts).
String _foldUmlauts(String text) => text
    .trim()
    .toUpperCase()
    .replaceAll('Ä', 'AE')
    .replaceAll('Ö', 'OE')
    .replaceAll('Ü', 'UE')
    .replaceAll('ß', 'SS');

Future<T?> _withProgress<T>(
  BuildContext context,
  String label,
  Future<T> Function() work, {
  bool rethrowErrors = false,
}) async {
  final navigator = Navigator.of(context);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => PopScope(
      canPop: false,
      child: AlertDialog(
        content: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 20),
            Expanded(child: Text(label)),
          ],
        ),
      ),
    ),
  );
  try {
    return await work();
  } catch (e) {
    if (rethrowErrors) rethrow;
    if (context.mounted) context.appRead.showMessage(context.appRead.errorMessage(e));
    return null;
  } finally {
    navigator.pop();
  }
}

class _PassphraseDialog extends StatefulWidget {
  const _PassphraseDialog({required this.confirm});

  final bool confirm;

  @override
  State<_PassphraseDialog> createState() => _PassphraseDialogState();
}

class _PassphraseDialogState extends State<_PassphraseDialog> {
  final _form = GlobalKey<FormState>();
  final _first = TextEditingController();
  final _second = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _first.dispose();
    _second.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return AlertDialog(
      title: Text(widget.confirm ? s.createBackup : s.restoreBackup),
      scrollable: true,
      content: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.confirm) Text(s.passphraseHint),
            const SizedBox(height: 12),
            TextFormField(
              controller: _first,
              obscureText: _obscure,
              autofocus: true,
              enableSuggestions: false,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: s.passphrase,
                suffixIcon: IconButton(
                  tooltip: _obscure ? s.showPassphrase : s.hidePassphrase,
                  icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return s.fieldRequired;
                if (widget.confirm && v.length < BackupFormat.minPassphraseLength) {
                  return s.passphraseTooShort;
                }
                return null;
              },
            ),
            if (widget.confirm) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _second,
                obscureText: _obscure,
                enableSuggestions: false,
                autocorrect: false,
                decoration: InputDecoration(labelText: s.passphraseRepeat),
                validator: (v) => v != _first.text ? s.passphraseMismatch : null,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(s.cancel)),
        FilledButton(
          onPressed: () {
            if (_form.currentState!.validate()) Navigator.pop(context, _first.text);
          },
          child: Text(s.ok),
        ),
      ],
    );
  }
}
