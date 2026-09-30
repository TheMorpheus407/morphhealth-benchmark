import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'accessibility_test.dart' show seedAll;
import 'harness.dart';

/// Android zeichnet randlos: Die System-Navigationsleiste (126 px auf dem Referenzgerät)
/// liegt über der App. Blätter und Bildschirme müssen ihre Schaltflächen darüber halten.
const navBarPx = 126.0;

Future<void> withNavigationBar(WidgetTester tester) async {
  tester.view.padding = const FakeViewPadding(bottom: navBarPx);
  tester.view.viewPadding = const FakeViewPadding(bottom: navBarPx);
  addTearDown(tester.view.resetPadding);
  addTearDown(tester.view.resetViewPadding);
  await tester.pumpAndSettle();
}

void expectAboveNavigationBar(WidgetTester tester, Finder button, String reason) {
  expect(button, findsWidgets, reason: reason);
  final limit = (2400 - navBarPx) / 2.625; // logische Pixel
  final bottom = tester.getBottomLeft(button.last).dy;
  expect(bottom, lessThanOrEqualTo(limit + 0.5), reason: '$reason: Unterkante $bottom, Navigationsleiste ab $limit');
}

void main() {
  setUpAll(loadRoboto);

  testWidgets('Blätter halten ihre Schaltflächen über der Navigationsleiste', (tester) async {
    await launchApp(tester, seed: seedAll);
    await withNavigationBar(tester);

    final save = find.widgetWithText(FilledButton, 'Speichern');
    await openTab(tester, 'Gewicht');
    await tester.tap(find.text('Gewicht erfassen'));
    await tester.pumpAndSettle();
    expectAboveNavigationBar(tester, save, 'Gewicht erfassen');
    await popTop(tester);

    await openTab(tester, 'Symptome');
    await tester.tap(find.text('Symptom erfassen'));
    await tester.pumpAndSettle();
    expectAboveNavigationBar(tester, save, 'Symptom erfassen');
    await popTop(tester);

    await openTab(tester, 'Zyklus');
    await tester.tap(find.text('Periode erfassen'));
    await tester.pumpAndSettle();
    expectAboveNavigationBar(tester, save, 'Periode erfassen');
    await popTop(tester);

    await openTab(tester, 'Ernährung');
    await tapScrolled(tester, find.text('Andere Menge'));
    expectAboveNavigationBar(tester, find.byType(FilledButton), 'Wassermenge');
    await popTop(tester);
    await scrollTo(tester, find.text('Koffein'));
    await tester.tap(find.widgetWithText(TextButton, 'Hinzufügen').last);
    await tester.pumpAndSettle();
    expectAboveNavigationBar(tester, find.byType(FilledButton), 'Koffein');
    await popTop(tester);

    await openTab(tester, 'Übersicht');
    await tester.tap(find.byTooltip('Bereiche anpassen'));
    await tester.pumpAndSettle();
    expectAboveNavigationBar(tester, find.widgetWithText(FilledButton, 'Fertig'), 'Bereiche anpassen');
  });

  testWidgets('Nebenbildschirme halten ihre Schaltflächen über der Navigationsleiste', (tester) async {
    await launchApp(tester, seed: seedAll);
    await withNavigationBar(tester);
    await openTab(tester, 'Ernährung');
    await tapScrolled(tester, find.text('Lebensmittel hinzufügen'));
    await tester.tap(find.text('Eigenes Lebensmittel anlegen'));
    await tester.pumpAndSettle();
    await tapScrolled(tester, find.widgetWithText(FilledButton, 'Speichern'));
    // Der Speichern-Knopf liegt am Listenende und ließ sich erreichen; die Liste endet über der Leiste.
    expectAboveNavigationBar(tester, find.widgetWithText(FilledButton, 'Speichern'), 'Eigenes Lebensmittel');
  });
}
