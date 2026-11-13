import 'package:flutter/material.dart';
import 'package:morphhealth_core/morphhealth_core.dart';

import '../settings/data_actions.dart';
import '../widgets/common.dart';

/// The first screen after installation: language, the areas for the
/// overview, what happens with the data, and the way to restore a backup.
/// There is no registration.
class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  bool _busy = false;

  Future<void> _finish() async {
    if (_busy) return;
    setState(() => _busy = true);
    final app = context.appRead;
    await guarded(
      context,
      () =>
          app.repository.updateLocal(app.local.copyWith(onboardingDone: true)),
    );
    if (mounted) setState(() => _busy = false);
  }

  Future<void> _restore() async {
    final restored = await restoreBackupFlow(context);
    if (restored && mounted) await _finish();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final app = context.app;
    final s = app.settings;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 32, 20, 24),
              children: [
                if (app.afterWipe)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Semantics(
                      liveRegion: true,
                      container: true,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: context.colors.secondaryContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            children: [
                              ExcludeSemantics(
                                child: Icon(
                                  Icons.check_circle_outline,
                                  color: context.colors.onSecondaryContainer,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  l.wipeDone,
                                  style: context.texts.bodyLarge?.copyWith(
                                    color: context.colors.onSecondaryContainer,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: ExcludeSemantics(
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: context.colors.primary,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'M',
                        style: context.texts.headlineMedium?.copyWith(
                          color: context.colors.onPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Semantics(
                  header: true,
                  child: Text(
                    l.welcomeTitle,
                    style: context.texts.headlineSmall,
                  ),
                ),
                const SizedBox(height: 8),
                Text(l.welcomeBody, style: context.texts.bodyLarge),
                const SizedBox(height: 20),
                Semantics(
                  label: l.language,
                  container: true,
                  child: SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<String>(
                      showSelectedIcon: false,
                      segments: const [
                        ButtonSegment(value: 'de', label: Text('Deutsch')),
                        ButtonSegment(value: 'en', label: Text('English')),
                      ],
                      selected: {s.language},
                      onSelectionChanged: (sel) => guarded(
                        context,
                        () => app.updateSettings(
                          (s) => s.copyWith(language: sel.first),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(l.welcomeAreas, style: context.texts.titleMedium),
                for (final area in Area.values)
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    title: Text(l.area(area)),
                    value: s.overviewSections.contains(area),
                    onChanged: (v) => guarded(
                      context,
                      () => app.setAreaVisible(area, v ?? false),
                    ),
                  ),
                Text(l.welcomeChangeLater, style: context.texts.bodySmall),
                const SizedBox(height: 20),
                for (final point in l.privacyPoints.take(3))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        ExcludeSemantics(
                          child: Padding(
                            padding: const EdgeInsets.only(top: 2, right: 8),
                            child: Icon(
                              Icons.lock_outline,
                              size: 18,
                              color: context.colors.primary,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(point, style: context.texts.bodyMedium),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: _busy ? null : _finish,
                  child: Text(l.welcomeStart),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.settings_backup_restore),
                  label: Text(l.backupRestore),
                  onPressed: _busy ? null : _restore,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
