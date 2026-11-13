import 'package:flutter/material.dart';

import '../widgets/common.dart';
import 'data_actions.dart';

/// Export, import, encrypted backup, restore and deleting everything.
class DataScreen extends StatelessWidget {
  const DataScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final app = context.app;
    final counts = app.data.counts;
    return Scaffold(
      appBar: AppBar(title: Text(l.dataTitle)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
          children: [
            MhCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.lock_outline, color: context.colors.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          l.storageInfo,
                          style: context.texts.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(l.currentlyStored, style: context.texts.titleSmall),
                  const SizedBox(height: 4),
                  for (final e in counts.entries)
                    Text(
                      l.countLine(e.key, e.value),
                      style: context.texts.bodyMedium,
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            PlainCard(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.enhanced_encryption_outlined),
                    title: Text(l.backupCreate),
                    subtitle: Text(l.backupCreateSubtitle),
                    onTap: () => createBackupFlow(context),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.settings_backup_restore),
                    title: Text(l.backupRestore),
                    subtitle: Text(l.backupRestoreSubtitle),
                    onTap: () => restoreBackupFlow(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            PlainCard(
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.file_upload_outlined),
                    title: Text(l.exportData),
                    subtitle: Text(l.exportSubtitle),
                    onTap: () => exportDataFlow(context),
                  ),
                  const Divider(),
                  ListTile(
                    leading: const Icon(Icons.file_download_outlined),
                    title: Text(l.importData),
                    subtitle: Text(l.importSubtitle),
                    onTap: () => importDataFlow(context),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            PlainCard(
              child: ListTile(
                leading: Icon(
                  Icons.delete_forever_outlined,
                  color: context.colors.error,
                ),
                title: Text(
                  l.wipe,
                  style: TextStyle(color: context.colors.error),
                ),
                subtitle: Text(l.wipeSubtitle),
                onTap: () => wipeDataFlow(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
