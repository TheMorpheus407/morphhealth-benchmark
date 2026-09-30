import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphhealth/core/models.dart';

import 'harness.dart';

void main() {
  setUpAll(loadRoboto);

  testWidgets('Übersicht: vier Bereiche in der Navigation, Deutsch voreingestellt', (tester) async {
    await launchApp(tester);
    expect(find.text('Übersicht'), findsWidgets);
    for (final t in ['Ernährung', 'Zyklus', 'Gewicht', 'Symptome']) {
      expect(
        find.descendant(of: find.byType(NavigationBar), matching: find.text(t)),
        findsOneWidget,
        reason: t,
      );
    }
    expect(find.textContaining('kcal'), findsWidgets);
    expect(find.text('Heute'), findsWidgets);
  });

  testWidgets('Bereiche lassen sich in der Übersicht aus- und einblenden', (tester) async {
    final app = await launchApp(tester);
    await tester.tap(find.byTooltip('Bereiche anpassen'));
    await tester.pumpAndSettle();
    // Zyklus und Gewicht ausblenden.
    await tester.tap(find.widgetWithText(SwitchListTile, 'Zyklus'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(SwitchListTile, 'Gewicht'));
    await tester.pumpAndSettle();
    expect(app.settings.shows(Area.cycle), isFalse);
    expect(app.settings.shows(Area.weight), isFalse);
    await tester.tap(find.text('Fertig'));
    await tester.pumpAndSettle();
    expect(find.descendant(of: find.byType(NavigationBar), matching: find.text('Zyklus')), findsNothing);
    expect(find.descendant(of: find.byType(NavigationBar), matching: find.text('Gewicht')), findsNothing);
    expect(find.descendant(of: find.byType(NavigationBar), matching: find.text('Ernährung')), findsOneWidget);
    // Ernährung lässt sich ohne Zyklus verwenden und umgekehrt.
    await openTab(tester, 'Ernährung');
    expect(find.text('Tagessumme'), findsOneWidget);
  });

  testWidgets('Übersicht: 7 und 28 Tage zeigen Verläufe statt Tageswerten', (tester) async {
    await launchApp(tester);
    await tester.tap(find.text('7 Tage'));
    await tester.pumpAndSettle();
    expect(find.textContaining('7 Tage'), findsWidgets);
    await tester.tap(find.text('28 Tage'));
    await tester.pumpAndSettle();
    expect(find.textContaining('28 Tage'), findsWidgets);
  });
}
