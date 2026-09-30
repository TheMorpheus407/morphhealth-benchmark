import 'dart:convert';
import 'dart:isolate';

import 'package:flutter/material.dart';

import '../core/backup.dart';
import '../core/issues.dart';
import '../platform/platform_bridge.dart';
import '../state/boot.dart';
import 'l10n_x.dart';
import 'settings/data_screen.dart' show askPassphrase, runWithProgress, showIssuesDialog;
import 'widgets/common.dart';

/// Wird gezeigt, wenn der lokale Datenbestand nicht geöffnet werden kann
/// (Schlüssel verloren, Datei beschädigt). Angeboten werden erneutes Versuchen,
/// Wiederherstellen aus einer Sicherung oder ein Neustart ohne Daten.
class BootFailureScreen extends StatefulWidget {
  final BootFailure failure;
  final Future<void> Function() onRetry;
  final void Function(BootResult) onRecovered;

  const BootFailureScreen({super.key, required this.failure, required this.onRetry, required this.onRecovered});

  @override
  State<BootFailureScreen> createState() => _BootFailureScreenState();
}

class _BootFailureScreenState extends State<BootFailureScreen> {
  String _message(BuildContext context) {
    final l = context.l10n;
    return switch (widget.failure.code) {
      'wrong_key' => l.bootFailedWrongKey,
      'corrupt' => l.bootFailedCorrupt,
      'locked' => l.bootFailedLocked,
      'key' => l.bootFailedKey,
      _ => l.bootFailedIo,
    };
  }

  Future<void> _fresh() async {
    final l = context.l10n;
    final ok = await confirmDialog(
      context,
      title: l.dataWipeConfirmTitle,
      message: l.dataWipeConfirmMessage,
      confirmLabel: l.dataWipeButton,
      destructive: true,
    );
    if (!ok || !mounted) return;
    final s = widget.failure.session;
    final core = await s.wipeAndReopen(null);
    widget.onRecovered(BootOk(core, s));
  }

  Future<void> _restore() async {
    final l = context.l10n;
    final s = widget.failure.session;
    PickedDocument? file;
    try {
      file = await s.platform.openDocument();
    } on PlatformFailure catch (e) {
      if (mounted) showMessage(context, l.commonError(e.message));
      return;
    }
    if (file == null || !mounted) return;
    final picked = file;
    final pass = await askPassphrase(context, confirm: false, title: l.dataRestoreTitle);
    if (pass == null || !mounted) return;
    Map<String, Object?> doc;
    try {
      doc = await runWithProgress(context, () => Isolate.run(() => openBackup(picked.bytes, pass)));
    } on BackupException catch (e) {
      if (mounted) {
        showMessage(context, switch (e.code) {
          'wrong_passphrase' => l.dataRestoreWrong,
          'not_a_backup' => l.dataRestoreNotBackup,
          _ => l.commonError(e.message),
        });
      }
      return;
    }
    if (!mounted) return;
    // Erst prüfen, dann den kaputten Bestand ersetzen.
    try {
      final core = await s.wipeAndReopen(null);
      try {
        await core.importDocument(jsonDecode(jsonEncode(doc)));
      } on ValidationException catch (e) {
        if (mounted) await showIssuesDialog(context, l.dataImportInvalid, e.issues);
      }
      widget.onRecovered(BootOk(core, s));
    } on Object catch (e) {
      if (mounted) showMessage(context, l.commonError('$e'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            const SizedBox(height: 40),
            Icon(Icons.lock_outline, size: 48, color: context.colors.primary),
            const SizedBox(height: 16),
            Semantics(header: true, child: Text(l.bootFailedTitle, style: context.text.headlineSmall)),
            const SizedBox(height: 12),
            Text(_message(context), style: context.text.bodyLarge),
            const SizedBox(height: 8),
            Text(widget.failure.message, style: context.text.bodySmall),
            const SizedBox(height: 24),
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              onPressed: widget.onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(l.commonRetry),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              onPressed: _restore,
              icon: const Icon(Icons.settings_backup_restore),
              label: Text(l.bootRestore),
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              style: TextButton.styleFrom(
                minimumSize: const Size.fromHeight(52),
                foregroundColor: context.colors.error,
              ),
              onPressed: _fresh,
              icon: const Icon(Icons.delete_outline),
              label: Text(l.bootStartFresh),
            ),
          ],
        ),
      ),
    );
  }
}
