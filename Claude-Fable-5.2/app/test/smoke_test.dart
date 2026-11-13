import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphhealth/ui/settings/settings_screen.dart';
import 'package:morphhealth_core/morphhealth_core.dart';

import 'support.dart';

void main() {
  testWidgets('every main screen builds with the example data', (tester) async {
    await pumpApp(tester, data: exampleData());
    expect(find.text('Übersicht'), findsWidgets);

    for (final tab in [
      'Ernährung',
      'Zyklus',
      'Körper',
      'Verlauf',
      'Übersicht',
    ]) {
      await openTab(tester, tab);
      expect(tester.takeException(), isNull, reason: tab);
    }
    await openTab(tester, 'Körper');
    await tester.tap(find.widgetWithText(Tab, 'Symptome'));
    await tester.pumpAndSettle();
    await openTab(tester, 'Verlauf');
    await tester.tap(find.widgetWithText(Tab, 'Verläufe'));
    await tester.pumpAndSettle();

    await openTab(tester, 'Übersicht');
    await tapTooltip(tester, 'Einstellungen');
    expect(find.byType(SettingsScreen), findsOneWidget);
  });

  testWidgets('every main screen builds without any data', (tester) async {
    await pumpApp(tester);
    for (final tab in [
      'Ernährung',
      'Zyklus',
      'Körper',
      'Verlauf',
      'Übersicht',
    ]) {
      await openTab(tester, tab);
    }
    await openTab(tester, 'Körper');
    await tester.tap(find.widgetWithText(Tab, 'Symptome'));
    await tester.pumpAndSettle();
    await openTab(tester, 'Verlauf');
    await tester.tap(find.widgetWithText(Tab, 'Verläufe'));
    await tester.pumpAndSettle();
  });

  testWidgets('the app works in English', (tester) async {
    await pumpApp(
      tester,
      data: exampleData(),
      settings: (s) => s.copyWith(language: 'en'),
    );
    expect(find.text('Overview'), findsWidgets);
    for (final tab in ['Nutrition', 'Cycle', 'Body', 'History', 'Overview']) {
      await openTab(tester, tab);
    }
    expect(find.text('Übersicht'), findsNothing);
  });

  testWidgets('the welcome screen leads into the app', (tester) async {
    final app = await pumpApp(tester, onboarded: false);
    expect(find.text('Willkommen bei MorphHealth'), findsOneWidget);
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(find.text('Welcome to MorphHealth'), findsOneWidget);
    await tester.tap(find.text('Deutsch'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Zyklus'));
    await tester.pumpAndSettle();
    await tapText(tester, 'Loslegen');
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(app.controller.local.onboardingDone, isTrue);
    expect(app.controller.settings.overviewSections, {
      Area.nutrition,
      Area.weight,
      Area.symptoms,
    });
  });
}
