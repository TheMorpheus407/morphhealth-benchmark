import 'package:flutter/material.dart';
import 'package:morphhealth_core/morphhealth_core.dart';

import '../widgets/common.dart';

/// What the app is for, how it treats data, and the licences.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    return Scaffold(
      appBar: AppBar(title: Text(l.about)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
          children: [
            MhCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(l.appName, style: context.texts.headlineSmall),
                  Text(
                    l.version(morphHealthVersion),
                    style: context.texts.bodyMedium?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(l.aboutPurpose, style: context.texts.bodyLarge),
                ],
              ),
            ),
            const SizedBox(height: 12),
            MhCard(
              title: l.privacyTitle,
              icon: Icons.lock_outline,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final point in l.privacyPoints)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const ExcludeSemantics(
                            child: Padding(
                              padding: EdgeInsets.only(top: 2, right: 8),
                              child: Icon(Icons.check, size: 18),
                            ),
                          ),
                          Expanded(
                            child: Text(point, style: context.texts.bodyMedium),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            MhCard(
              title: l.offTitle,
              icon: Icons.public,
              child: Text(l.offNotice, style: context.texts.bodyMedium),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              icon: const Icon(Icons.description_outlined),
              label: Text(l.licenses),
              onPressed: () => showLicensePage(
                context: context,
                applicationName: l.appName,
                applicationVersion: morphHealthVersion,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
