import 'package:flutter/material.dart';

import '../../core/model/enums.dart';
import '../controller.dart';
import '../theme.dart';

/// First start: language, visible areas and the online food search choice.
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  Set<Area>? _areas;
  bool? _online;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final s = app.s;
    final settings = app.settings;
    final areas = _areas ?? settings.overviewAreas;
    final online = _online ?? settings.onlineFoodSearch;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
          children: [
            ExcludeSemantics(
              child: Align(
                alignment: Alignment.centerLeft,
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: seedColor,
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: const Icon(Icons.favorite, color: Colors.white, size: 36),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Semantics(
              header: true,
              child: Text(s.welcomeTitle, style: context.text.headlineSmall),
            ),
            const SizedBox(height: 12),
            Text(s.welcomeText, style: context.text.bodyLarge),
            const SizedBox(height: 28),
            Text(s.onboardingLanguage, style: context.text.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<AppLanguage>(
              segments: const [
                ButtonSegment(value: AppLanguage.de, label: Text('Deutsch')),
                ButtonSegment(value: AppLanguage.en, label: Text('English')),
              ],
              selected: {settings.language},
              onSelectionChanged: (v) =>
                  app.updateSettings(settings.copyWith(language: v.first)),
            ),
            const SizedBox(height: 28),
            Text(s.onboardingAreas, style: context.text.titleSmall),
            const SizedBox(height: 4),
            Text(
              s.onboardingAreasHint,
              style: context.text.bodySmall?.copyWith(color: context.scheme.onSurfaceVariant),
            ),
            for (final area in Area.values)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: areas.contains(area),
                secondary: Icon(areaIcon(area), color: context.colors.area(area)),
                title: Text(s.areaName(area)),
                onChanged: (v) => setState(() {
                  final next = {...areas};
                  v == true ? next.add(area) : next.remove(area);
                  _areas = next;
                }),
              ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: online,
              title: Text(s.onboardingOnline),
              subtitle: Text(s.onboardingOnlineHint),
              onChanged: (v) => setState(() => _online = v),
            ),
            const SizedBox(height: 16),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const ExcludeSemantics(child: Icon(Icons.lock_outline)),
                    const SizedBox(width: 12),
                    Expanded(child: Text(s.onboardingPrivacy)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 28),
            FilledButton(
              onPressed: () async {
                await app.updateSettings(
                  app.settings.copyWith(overviewAreas: areas, onlineFoodSearch: online),
                );
                await app.service.updateDevice(
                  app.service.repo.device.copyWith(onboardingCompleted: true),
                );
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(s.getStarted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
