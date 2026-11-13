import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:morphhealth_core/morphhealth_core.dart';

import '../../platform/platform_bridge.dart';
import '../widgets/common.dart';

/// Lines "Lebensmittel: 5" … for the summary of a data set.
Widget _counts(BuildContext context, Map<String, int> counts) {
  final l = context.l;
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      for (final e in counts.entries)
        Text(l.countLine(e.key, e.value), style: context.texts.bodyMedium),
    ],
  );
}

/// Shows why a document was refused.
Future<void> _showRejected(BuildContext context, ImportRejected rejected) {
  final l = context.l;
  return showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l.importRejectedTitle),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l.importProblems(rejected.errorCount)),
            const SizedBox(height: 12),
            for (final e in rejected.errors.take(12))
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('• $e', style: context.texts.bodySmall),
              ),
            if (rejected.errorCount > 12)
              Text('…', style: context.texts.bodySmall),
          ],
        ),
      ),
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.close),
        ),
      ],
    ),
  );
}

/// Asks whether [preview] should replace the current data. Returns true if
/// the user agreed.
Future<bool> _confirmReplace(
  BuildContext context,
  ImportPreview preview,
  String title, {
  String? subtitle,
}) async {
  final l = context.l;
  final current = context.appRead.data.counts;
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (subtitle != null) ...[
              Text(subtitle),
              const SizedBox(height: 12),
            ],
            Text(l.fileContains, style: context.texts.titleSmall),
            const SizedBox(height: 4),
            _counts(context, preview.data.counts),
            if (preview.warningCount > 0) ...[
              const SizedBox(height: 8),
              Text(
                l.importWarnings(preview.warningCount),
                style: context.texts.bodySmall,
              ),
              for (final w in preview.warnings.take(5))
                Text('• $w', style: context.texts.bodySmall),
            ],
            const SizedBox(height: 16),
            Text(l.currentlyStored, style: context.texts.titleSmall),
            const SizedBox(height: 4),
            _counts(context, current),
            const SizedBox(height: 16),
            Text(
              l.importReplaces,
              style: TextStyle(
                color: Theme.of(context).colorScheme.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l.replaceAll),
        ),
      ],
    ),
  );
  return ok ?? false;
}

/// Exports all data as a readable JSON file after a clear warning.
Future<void> exportDataFlow(BuildContext context) async {
  final l = context.l;
  final app = context.appRead;
  final sure = await confirm(
    context,
    title: l.exportWarnTitle,
    message: l.exportWarnBody,
    action: l.exportConfirm,
  );
  if (!sure || !context.mounted) return;
  try {
    final service = app.portable;
    final bytes = Uint8List.fromList(service.exportBytes());
    final name = await app.platform.saveDocument(
      name: service.suggestedFileName(),
      mimeType: 'application/json',
      bytes: bytes,
    );
    if (name != null && context.mounted) showSnack(context, l.fileSaved(name));
  } on Object catch (e) {
    if (context.mounted) showSnack(context, describeError(context, e));
  }
}

/// Imports a JSON export: pick, check, confirm, replace. Returns true if the
/// data were replaced.
Future<bool> importDataFlow(BuildContext context) async {
  final l = context.l;
  final app = context.appRead;
  try {
    final picked = await app.platform.openDocument();
    if (picked == null || !context.mounted) return false;
    final ImportPreview preview;
    try {
      preview = app.portable.preview(PortableService.decodeBytes(picked.bytes));
    } on ImportRejected catch (rejected) {
      if (context.mounted) await _showRejected(context, rejected);
      return false;
    }
    if (!context.mounted) return false;
    if (!await _confirmReplace(
          context,
          preview,
          l.importCheckTitle,
          subtitle: picked.name,
        ) ||
        !context.mounted) {
      return false;
    }
    final report = await app.portable.apply(preview);
    if (context.mounted) {
      showSnack(
        context,
        l.importDone(
          report.counts.entries
              .where((e) => e.key != 'foods')
              .fold(0, (a, e) => a + e.value),
        ),
      );
    }
    return true;
  } on Object catch (e) {
    if (context.mounted) showSnack(context, describeError(context, e));
    return false;
  }
}

/// Creates an encrypted backup with a passphrase the user chooses.
Future<void> createBackupFlow(BuildContext context) async {
  final l = context.l;
  final app = context.appRead;
  final passphrase = await showDialog<String>(
    context: context,
    builder: (_) => const _PassphraseDialog(create: true),
  );
  if (passphrase == null || !context.mounted) return;
  try {
    final document = app.portable.exportDocument();
    final bytes = await withProgress(
      context,
      l.backupWorking,
      () => app.backups.seal(document, passphrase, app.now),
    );
    final name = await app.platform.saveDocument(
      name: BackupCodec.suggestedFileName(app.today),
      mimeType: 'application/octet-stream',
      bytes: bytes,
    );
    if (name != null && context.mounted) showSnack(context, l.fileSaved(name));
  } on Object catch (e) {
    if (context.mounted) showSnack(context, describeError(context, e));
  }
}

/// Restores an encrypted backup: pick, enter the passphrase, check, confirm,
/// replace. Returns true if the data were replaced.
Future<bool> restoreBackupFlow(BuildContext context) async {
  final l = context.l;
  final app = context.appRead;
  final fmt = context.fmt;
  try {
    final PickedDocument? picked = await app.platform.openDocument();
    if (picked == null || !context.mounted) return false;
    final BackupHeader header;
    try {
      header = BackupCodec.readHeader(picked.bytes);
    } on BackupException catch (e) {
      if (context.mounted) showSnack(context, l.backupError(e.code));
      return false;
    }

    Map<String, dynamic>? document;
    String? error;
    while (document == null) {
      if (!context.mounted) return false;
      final passphrase = await showDialog<String>(
        context: context,
        builder: (_) => _PassphraseDialog(create: false, error: error),
      );
      if (passphrase == null || !context.mounted) return false;
      try {
        document = await withProgress(
          context,
          l.restoreWorking,
          () => app.backups.open(picked.bytes, passphrase),
        );
      } on BackupException catch (e) {
        if (e.code != 'wrong_passphrase') {
          if (context.mounted) showSnack(context, l.backupError(e.code));
          return false;
        }
        error = l.backupError(e.code);
      }
    }
    if (!context.mounted) return false;

    final ImportPreview preview;
    try {
      preview = app.portable.preview(document);
    } on ImportRejected catch (rejected) {
      if (context.mounted) await _showRejected(context, rejected);
      return false;
    }
    if (!context.mounted) return false;
    final created = header.createdAt;
    if (!await _confirmReplace(
          context,
          preview,
          l.backupRestore,
          subtitle: created == null
              ? picked.name
              : l.backupFrom(fmt.date(created.day)),
        ) ||
        !context.mounted) {
      return false;
    }
    await app.portable.apply(preview);
    if (context.mounted) showSnack(context, l.restoreDone);
    return true;
  } on Object catch (e) {
    if (context.mounted) showSnack(context, describeError(context, e));
    return false;
  }
}

/// Deletes everything after an explicit confirmation.
Future<void> wipeDataFlow(BuildContext context) async {
  final app = context.appRead;
  final sure = await showDialog<bool>(
    context: context,
    builder: (_) => const _WipeDialog(),
  );
  if (sure != true || !context.mounted) return;
  try {
    // Afterwards the app starts again with the welcome screen, which is the
    // visible confirmation that everything is gone.
    Navigator.of(context).popUntil((route) => route.isFirst);
    await app.wipeEverything();
  } on Object catch (e) {
    if (context.mounted) showSnack(context, describeError(context, e));
  }
}

class _WipeDialog extends StatefulWidget {
  const _WipeDialog();

  @override
  State<_WipeDialog> createState() => _WipeDialogState();
}

class _WipeDialogState extends State<_WipeDialog> {
  bool _checked = false;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final scheme = Theme.of(context).colorScheme;
    return AlertDialog(
      icon: Icon(Icons.warning_amber_rounded, color: scheme.error),
      title: Text(l.wipeConfirmTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(l.wipeConfirmBody),
            const SizedBox(height: 8),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              controlAffinity: ListTileControlAffinity.leading,
              value: _checked,
              onChanged: (v) => setState(() => _checked = v ?? false),
              title: Text(l.wipeConfirmCheck),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l.cancel),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: scheme.error,
            foregroundColor: scheme.onError,
          ),
          onPressed: _checked ? () => Navigator.of(context).pop(true) : null,
          child: Text(l.wipeConfirmAction),
        ),
      ],
    );
  }
}

class _PassphraseDialog extends StatefulWidget {
  /// True: choose a new passphrase (entered twice). False: enter the
  /// passphrase of an existing backup.
  final bool create;
  final String? error;

  const _PassphraseDialog({required this.create, this.error});

  @override
  State<_PassphraseDialog> createState() => _PassphraseDialogState();
}

class _PassphraseDialogState extends State<_PassphraseDialog> {
  final _formKey = GlobalKey<FormState>();
  final _first = TextEditingController();
  final _second = TextEditingController();
  bool _visible = false;

  @override
  void dispose() {
    _first.dispose();
    _second.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(_first.text);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    return AlertDialog(
      title: Text(widget.create ? l.backupCreate : l.backupRestore),
      scrollable: true,
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (widget.create)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(l.passphraseHint, style: context.texts.bodyMedium),
              ),
            TextFormField(
              enableIMEPersonalizedLearning: false,
              controller: _first,
              autofocus: true,
              obscureText: !_visible,
              enableSuggestions: false,
              autocorrect: false,
              keyboardType: TextInputType.visiblePassword,
              textInputAction: widget.create
                  ? TextInputAction.next
                  : TextInputAction.done,
              onFieldSubmitted: widget.create ? null : (_) => _submit(),
              decoration: InputDecoration(
                labelText: l.passphrase,
                errorText: widget.error,
                suffixIcon: IconButton(
                  tooltip: _visible ? l.hidePassphrase : l.showPassphrase,
                  icon: Icon(
                    _visible
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                  ),
                  onPressed: () => setState(() => _visible = !_visible),
                ),
              ),
              validator: (v) {
                if (v == null || v.isEmpty) return l.requiredField;
                if (widget.create &&
                    v.length < BackupCodec.minPassphraseLength) {
                  return l.passphraseTooShort(BackupCodec.minPassphraseLength);
                }
                return null;
              },
            ),
            if (widget.create) ...[
              const SizedBox(height: 12),
              TextFormField(
                enableIMEPersonalizedLearning: false,
                controller: _second,
                obscureText: !_visible,
                enableSuggestions: false,
                autocorrect: false,
                keyboardType: TextInputType.visiblePassword,
                onFieldSubmitted: (_) => _submit(),
                decoration: InputDecoration(labelText: l.passphraseRepeat),
                validator: (v) =>
                    v != _first.text ? l.passphraseMismatch : null,
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.create ? l.createBackup : l.openBackup),
        ),
      ],
    );
  }
}
