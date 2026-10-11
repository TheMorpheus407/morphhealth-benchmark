// Datentransfer: Klartext-Export/Import (portables JSON), passphrasen-
// geschützte Sicherung (MHBK) und vollständiges Löschen des Datenbestands.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../core/exceptions.dart';
import '../data/repository.dart';
import '../l10n/app_strings.dart';
import '../model/document.dart';
import '../store/backup.dart';
import 'scope.dart';
import 'widgets.dart';

class DataTransferScreen extends StatefulWidget {
  /// 0 = Export/Import, 1 = Sicherung erstellen, 2 = wiederherstellen,
  /// 3 = alles löschen (nur zum initialen Scrollen).
  final int? initialSection;

  const DataTransferScreen({super.key, this.initialSection});

  @override
  State<DataTransferScreen> createState() => _DataTransferScreenState();
}

class _DataTransferScreenState extends State<DataTransferScreen> {
  final ScrollController _scrollController = ScrollController();
  final List<GlobalKey> _sectionKeys =
      List<GlobalKey>.generate(4, (int i) => GlobalKey());

  bool _exportAck = false;
  bool _busy = false;

  final TextEditingController _backupPassController = TextEditingController();
  final TextEditingController _backupPassRepeatController =
      TextEditingController();
  final TextEditingController _restorePassController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final int? initial = widget.initialSection;
    if (initial != null && initial >= 0 && initial < _sectionKeys.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final BuildContext? ctx = _sectionKeys[initial].currentContext;
        if (ctx != null && mounted) {
          Scrollable.ensureVisible(ctx,
              duration: const Duration(milliseconds: 300));
        }
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _backupPassController.dispose();
    _backupPassRepeatController.dispose();
    _restorePassController.dispose();
    super.dispose();
  }

  String _todayCompact() {
    final DateTime n = DateTime.now();
    final String mm = n.month.toString().padLeft(2, '0');
    final String dd = n.day.toString().padLeft(2, '0');
    return '${n.year}$mm$dd';
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = StringsScope.of(context);
    final MorphRepository repo = MorphScope.repoOf(context);
    return Scaffold(
      appBar: AppBar(title: Text(strings.dataSection)),
      body: ListView(
        controller: _scrollController,
        padding: const EdgeInsets.only(bottom: 24),
        children: <Widget>[
          _exportCard(strings, repo),
          _importCard(strings, repo),
          _backupCreateCard(strings, repo),
          _backupRestoreCard(strings, repo),
          _deleteCard(strings, repo),
        ],
      ),
    );
  }

  // ------------------------------------------------------------- Export

  Widget _exportCard(AppStrings strings, MorphRepository repo) {
    return SectionCard(
      key: _sectionKeys[0],
      title: strings.exportTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(strings.exportAck),
            value: _exportAck,
            onChanged: (bool? v) => setState(() => _exportAck = v ?? false),
          ),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed: (_exportAck && !_busy) ? () => _doExport(strings, repo) : null,
            icon: const Icon(Icons.upload_outlined),
            label: Text(strings.exportData),
          ),
        ],
      ),
    );
  }

  Future<void> _doExport(AppStrings strings, MorphRepository repo) async {
    setState(() => _busy = true);
    try {
      final String json = jsonEncode(repo.exportPortable());
      final Uri? uri = await FilePicker.saveFile(
        fileName: 'morphhealth-export-${_todayCompact()}.json',
        bytes: utf8.encode(json),
        mimeType: 'application/json',
        dialogTitle: strings.exportTitle,
      );
      if (!mounted) return;
      if (uri == null) {
        showInfo(context, strings.fileSaveCanceled);
        return;
      }
      showInfo(context, strings.savedAt(uri.toString()));
    } on MorphException catch (e) {
      if (mounted) showError(context, e.message);
    } catch (_) {
      if (mounted) showError(context, strings.errorGeneric);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ------------------------------------------------------------- Import

  Widget _importCard(AppStrings strings, MorphRepository repo) {
    return SectionCard(
      title: strings.importTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(strings.importConfirm,
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            onPressed: _busy ? null : () => _doImport(strings, repo),
            icon: const Icon(Icons.download_outlined),
            label: Text(strings.importData),
          ),
        ],
      ),
    );
  }

  Future<void> _doImport(AppStrings strings, MorphRepository repo) async {
    setState(() => _busy = true);
    try {
      final PlatformFile? file = await FilePicker.pickFile(
        dialogTitle: strings.importTitle,
        type: FileType.custom,
        allowedExtensions: <String>['json'],
      );
      if (file == null) {
        if (mounted) showInfo(context, strings.fileSaveCanceled);
        return;
      }
      final Uint8List bytes = await file.readAsBytes();
      final MorphDocument? doc = _parsePortable(strings, bytes);
      if (doc == null || !mounted) return;
      final bool ok = await confirmAction(
        context,
        title: strings.importTitle,
        message: strings.importConfirm,
        confirmLabel: strings.importData,
      );
      if (!ok || !mounted) return;
      final Map<String, int> report = await repo.replaceDocument(doc);
      if (!mounted) return;
      final String details = _reportLines(strings, report).join('\n');
      showInfo(context, '${strings.importSuccess}\n$details');
    } on MorphException catch (e) {
      if (mounted) showError(context, e.message);
    } catch (_) {
      if (mounted) showError(context, strings.errorGeneric);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Parst ein portables Dokument aus Rohbytes; null bei ungültigem Inhalt
  /// (Fehlermeldung wurde bereits angezeigt).
  MorphDocument? _parsePortable(AppStrings strings, List<int> bytes) {
    try {
      final dynamic decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Kein JSON-Objekt');
      }
      return MorphDocument.fromPortableJson(decoded);
    } on MorphException catch (e) {
      showError(context, e.message);
      return null;
    } catch (_) {
      showError(context, strings.errorGeneric);
      return null;
    }
  }

  /// Import-Bericht als lokalisierte Zeilen (pro Bereich zusammengefasst).
  List<String> _reportLines(AppStrings strings, Map<String, int> report) {
    final Map<String, int> perArea = <String, int>{
      'nutrition': (report['foods'] ?? 0) +
          (report['nutrition_entries'] ?? 0) +
          (report['water_entries'] ?? 0) +
          (report['caffeine_entries'] ?? 0),
      'cycle': report['periods'] ?? 0,
      'weight': report['weight_entries'] ?? 0,
      'symptoms': report['symptom_entries'] ?? 0,
    };
    return <String>[
      for (final MapEntry<String, int> e in perArea.entries)
        strings.imported(strings.areaName(e.key), e.value),
    ];
  }

  // ---------------------------------------------------- Sicherung erstellen

  Widget _backupCreateCard(AppStrings strings, MorphRepository repo) {
    return SectionCard(
      key: _sectionKeys[1],
      title: strings.backupCreateTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          TextField(
            controller: _backupPassController,
            obscureText: true,
            decoration: InputDecoration(labelText: strings.backupPassphrase),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _backupPassRepeatController,
            obscureText: true,
            decoration:
                InputDecoration(labelText: strings.backupPassphraseRepeat),
          ),
          const SizedBox(height: 4),
          Text(strings.backupPassphraseHint,
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          FilledButton.icon(
            onPressed:
                _busy ? null : () => _doBackupCreate(strings, repo),
            icon: const Icon(Icons.lock_outlined),
            label: Text(strings.backupCreate),
          ),
        ],
      ),
    );
  }

  Future<void> _doBackupCreate(
      AppStrings strings, MorphRepository repo) async {
    final String pass = _backupPassController.text;
    final String repeat = _backupPassRepeatController.text;
    if (pass.isEmpty) {
      showError(context, strings.passphraseRequired);
      return;
    }
    if (pass != repeat) {
      showError(context, strings.passphraseMismatch);
      return;
    }
    if (pass.length < 8) {
      showError(context, strings.passphraseTooShort);
      return;
    }
    setState(() => _busy = true);
    try {
      final List<int> blob = await BackupFile.seal(repo.exportPortable(), pass);
      final Uri? uri = await FilePicker.saveFile(
        fileName: 'morphhealth-backup-${_todayCompact()}.mhbk',
        bytes: Uint8List.fromList(blob),
        mimeType: 'application/octet-stream',
        dialogTitle: strings.backupCreateTitle,
      );
      if (!mounted) return;
      if (uri == null) {
        showInfo(context, strings.fileSaveCanceled);
        return;
      }
      showInfo(
          context, '${strings.backupSuccess}\n${strings.savedAt(uri.toString())}');
      _backupPassController.clear();
      _backupPassRepeatController.clear();
    } on MorphException catch (e) {
      if (mounted) showError(context, e.message);
    } catch (_) {
      if (mounted) showError(context, strings.errorGeneric);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ------------------------------------------------ Sicherung wiederherstellen

  Widget _backupRestoreCard(AppStrings strings, MorphRepository repo) {
    return SectionCard(
      key: _sectionKeys[2],
      title: strings.backupRestoreTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(strings.backupRestoreConfirm,
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          TextField(
            controller: _restorePassController,
            obscureText: true,
            decoration: InputDecoration(labelText: strings.backupPassphrase),
          ),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            onPressed: _busy ? null : () => _doBackupRestore(strings, repo),
            icon: const Icon(Icons.lock_open_outlined),
            label: Text(strings.backupRestore),
          ),
        ],
      ),
    );
  }

  Future<void> _doBackupRestore(
      AppStrings strings, MorphRepository repo) async {
    final String pass = _restorePassController.text;
    if (pass.isEmpty) {
      showError(context, strings.passphraseRequired);
      return;
    }
    setState(() => _busy = true);
    try {
      final PlatformFile? file = await FilePicker.pickFile(
        dialogTitle: strings.backupRestoreTitle,
        type: FileType.any,
      );
      if (file == null) {
        if (mounted) showInfo(context, strings.fileSaveCanceled);
        return;
      }
      final Uint8List bytes = await file.readAsBytes();
      final MorphDocument doc =
          await BackupFile.openBytes(bytes, pass); // wirft bei falscher Passphrase
      if (!mounted) return;
      final bool ok = await confirmAction(
        context,
        title: strings.backupRestoreTitle,
        message: strings.backupRestoreConfirm,
        confirmLabel: strings.backupRestore,
      );
      if (!ok || !mounted) return;
      await repo.replaceDocument(doc);
      if (!mounted) return;
      showInfo(context, strings.backupRestoreSuccess);
      _restorePassController.clear();
    } on MorphException catch (e) {
      if (mounted) showError(context, e.message);
    } catch (_) {
      if (mounted) showError(context, strings.errorGeneric);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // --------------------------------------------------------- Löschen

  Widget _deleteCard(AppStrings strings, MorphRepository repo) {
    return SectionCard(
      key: _sectionKeys[3],
      title: strings.deleteAllTitle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(strings.deleteAllConfirm,
              style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: 8),
          FilledButton.icon(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
              foregroundColor: Theme.of(context).colorScheme.onError,
            ),
            onPressed: _busy ? null : () => _doDeleteAll(strings, repo),
            icon: const Icon(Icons.delete_forever),
            label: Text(strings.deleteAll),
          ),
        ],
      ),
    );
  }

  Future<void> _doDeleteAll(AppStrings strings, MorphRepository repo) async {
    final bool ok = await confirmAction(
      context,
      title: strings.deleteAllTitle,
      message: strings.deleteAllConfirm,
      confirmLabel: strings.delete,
    );
    if (!ok || !mounted) return;
    setState(() => _busy = true);
    try {
      await repo.deleteAllData();
      if (!mounted) return;
      showInfo(context, strings.deleteAllSuccess);
      Navigator.of(context).pop();
    } on MorphException catch (e) {
      if (mounted) showError(context, e.message);
    } catch (_) {
      if (mounted) showError(context, strings.errorGeneric);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
