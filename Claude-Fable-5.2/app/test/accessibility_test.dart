import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:morphhealth/ui/widgets/common.dart';

import 'support.dart';

/// Checks the screen as it is now: touch targets of at least 48 dp, a label
/// on everything that can be tapped, and sufficient text contrast.
Future<void> expectAccessible(
  WidgetTester tester,
  String where, {
  bool contrast = true,
}) async {
  await expectLater(
    tester,
    meetsGuideline(androidTapTargetGuideline),
    reason: 'tap targets: $where',
  );
  await expectLater(
    tester,
    meetsGuideline(labeledTapTargetGuideline),
    reason: 'labels: $where',
  );
  if (contrast) {
    await expectLater(
      tester,
      meetsGuideline(textContrastGuideline),
      reason: 'contrast: $where',
    );
  }
}

const tabsDe = ['Übersicht', 'Ernährung', 'Zyklus', 'Körper', 'Verlauf'];

/// Visits every main screen and the most used forms, calling [check] on each.
Future<void> visitScreens(
  WidgetTester tester,
  Future<void> Function(String where) check,
) async {
  for (final tab in tabsDe) {
    await openTab(tester, tab);
    await check(tab);
  }

  await openTab(tester, 'Körper');
  await tester.tap(find.widgetWithText(Tab, 'Symptome'));
  await tester.pumpAndSettle();
  await check('Körper/Symptome');
  await tester.tap(
    find.widgetWithText(FloatingActionButton, 'Symptom eintragen'),
  );
  await tester.pumpAndSettle();
  await check('Symptom eintragen');
  await goBack(tester);
  await tester.tap(find.widgetWithText(Tab, 'Gewicht'));
  await tester.pumpAndSettle();
  await tester.tap(
    find.widgetWithText(FloatingActionButton, 'Gewicht eintragen'),
  );
  await tester.pumpAndSettle();
  await check('Gewicht eintragen');
  await tapText(tester, 'Abbrechen');

  await openTab(tester, 'Verlauf');
  await tester.tap(find.widgetWithText(Tab, 'Verläufe'));
  await tester.pumpAndSettle();
  await check('Verlauf/Verläufe');
  await tester.tap(find.widgetWithText(Tab, 'Einträge'));
  await tester.pumpAndSettle();

  await openTab(tester, 'Ernährung');
  await tester.tap(
    find.widgetWithText(FloatingActionButton, 'Lebensmittel erfassen'),
  );
  await tester.pumpAndSettle();
  await check('Lebensmittel erfassen');
  await goBack(tester);

  await openTab(tester, 'Zyklus');
  await tapTooltip(tester, 'Periodenverlauf');
  await check('Periodenverlauf');
  await tester.tap(
    find.widgetWithText(FloatingActionButton, 'Periode eintragen'),
  );
  await tester.pumpAndSettle();
  await check('Periode eintragen');
  await goBack(tester);
  await goBack(tester);
  await tapText(tester, 'Wie kommt das zustande?');
  await check('Erklärung der Einschätzung');
  await tester.tapAt(const Offset(200, 30));
  await tester.pumpAndSettle();

  await openTab(tester, 'Übersicht');
  await tapText(tester, 'Tagesdetail öffnen');
  await check('Tagesdetail');
  await goBack(tester);

  await tapTooltip(tester, 'Einstellungen');
  await check('Einstellungen');
  await tapText(tester, 'Daten');
  await check('Daten');
  await tapText(tester, 'Verschlüsselte Sicherung erstellen');
  await check('Passphrase');
  await tapText(tester, 'Abbrechen');
  await tapText(tester, 'Alle Daten löschen');
  await check('Alle Daten löschen');
  await tapText(tester, 'Abbrechen');
  await goBack(tester);
  await tapText(tester, 'Über MorphHealth');
  await check('Über MorphHealth');
  await goBack(tester);
  await goBack(tester);
}

void main() {
  testWidgets('light theme: tap targets, labels and contrast', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpApp(
      tester,
      data: exampleData(),
      settings: (s) => s.copyWith(theme: 'light'),
    );
    await visitScreens(tester, (where) => expectAccessible(tester, where));
    handle.dispose();
  });

  testWidgets('dark theme: tap targets, labels and contrast', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpApp(
      tester,
      data: exampleData(),
      settings: (s) => s.copyWith(theme: 'dark'),
    );
    expect(
      Theme.of(tester.element(find.byType(NavigationBar))).brightness,
      Brightness.dark,
    );
    await visitScreens(tester, (where) => expectAccessible(tester, where));
    handle.dispose();
  });

  testWidgets('without data: tap targets, labels and contrast', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpApp(tester, onboarded: false);
    await expectAccessible(tester, 'Willkommen');
    await tapText(tester, 'Loslegen');
    for (final tab in tabsDe) {
      await openTab(tester, tab);
      await expectAccessible(tester, '$tab (leer)');
    }
    handle.dispose();
  });

  testWidgets('text at 200 % on a small phone: nothing breaks or overflows', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await pumpApp(
      tester,
      data: exampleData(),
      size: const Size(360, 640),
      textScale: 2.0,
    );
    // A layout that does not fit raises an error, which fails the test.
    await visitScreens(tester, (where) async {
      expect(tester.takeException(), isNull, reason: where);
      await expectLater(
        tester,
        meetsGuideline(labeledTapTargetGuideline),
        reason: 'labels: $where',
      );
    });
    handle.dispose();
  });

  testWidgets('English with large text: nothing breaks or overflows', (
    tester,
  ) async {
    await pumpApp(
      tester,
      data: exampleData(),
      size: const Size(360, 640),
      textScale: 1.5,
      settings: (s) => s.copyWith(language: 'en', weightUnit: 'lb'),
    );
    for (final tab in ['Overview', 'Nutrition', 'Cycle', 'Body', 'History']) {
      await openTab(tester, tab);
      expect(tester.takeException(), isNull, reason: tab);
    }
    await tester.tap(find.widgetWithText(Tab, 'Trends'));
    await tester.pumpAndSettle();
    await openTab(tester, 'Body');
    await tester.tap(find.widgetWithText(Tab, 'Symptoms'));
    await tester.pumpAndSettle();
    await openTab(tester, 'Cycle');
    await tapText(tester, 'How is this worked out?');
    await tester.tapAt(const Offset(200, 30));
    await tester.pumpAndSettle();
    await tapTooltip(tester, 'Settings');
    await tapText(tester, 'Data');
    expect(tester.takeException(), isNull);
  });

  testWidgets('landscape and a narrow width keep working', (tester) async {
    await pumpApp(tester, data: exampleData(), size: const Size(914, 411));
    for (final tab in tabsDe) {
      await openTab(tester, tab);
      expect(tester.takeException(), isNull, reason: 'landscape $tab');
    }
    tester.view.physicalSize = const Size(320, 568);
    await tester.pumpAndSettle();
    for (final tab in tabsDe) {
      await openTab(tester, tab);
      expect(tester.takeException(), isNull, reason: 'narrow $tab');
    }
  });

  testWidgets(
    'enlarged text: figures move below each other, words stay whole',
    (tester) async {
      await pumpApp(tester, data: exampleData(), textScale: 2.0);
      final carbs = find.text('Kohlenhydrate').first;
      final fat = find.text('Fett').first;
      expect(
        tester.getSize(carbs).height,
        tester.getSize(fat).height,
        reason: 'the long label is not broken into two lines',
      );
      expect(
        tester.getTopLeft(fat).dy,
        greaterThan(tester.getTopLeft(carbs).dy),
        reason: 'the figures stand below each other',
      );

      // At normal size they share one row.
      tester.platformDispatcher.textScaleFactorTestValue = 1.0;
      await tester.pumpAndSettle();
      expect(
        tester.getTopLeft(find.text('Fett').first).dy,
        tester.getTopLeft(find.text('Kohlenhydrate').first).dy,
      );
    },
  );

  testWidgets('sheets end above the system navigation bar', (tester) async {
    const bar = 48.0;
    await pumpApp(tester, data: exampleData(), systemBarBottom: bar);
    final limit = tester.view.physicalSize.height - bar;
    double bottomOf(Finder finder) => tester.getRect(finder).bottom;

    // Customizing the overview.
    await tapText(tester, 'Übersicht anpassen');
    expect(
      bottomOf(find.widgetWithText(SwitchListTile, 'Symptome')),
      lessThanOrEqualTo(limit),
    );
    await tester.tapAt(const Offset(200, 40));
    await tester.pumpAndSettle();

    // Water and caffeine entries of the day.
    await openTab(tester, 'Ernährung');
    await tapText(tester, 'Einträge anzeigen (3)');
    final sheetList = find
        .descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(Scrollable),
        )
        .first;
    expect(bottomOf(sheetList), lessThanOrEqualTo(limit));
    await tester.tapAt(const Offset(200, 40));
    await tester.pumpAndSettle();

    // The explanation of the estimate, scrolled to its end.
    await openTab(tester, 'Zyklus');
    await tapText(tester, 'Wie kommt das zustande?');
    final last = find.text('Einschätzung in den Einstellungen ausschalten');
    await tester.scrollUntilVisible(
      last,
      300,
      scrollable: find
          .descendant(
            of: find.byType(BottomSheet),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();
    expect(bottomOf(last), lessThanOrEqualTo(limit));
    await tester.tapAt(const Offset(200, 40));
    await tester.pumpAndSettle();

    // A list of options.
    await tapTooltip(tester, 'Periodenverlauf');
    await tapText(tester, '16. – 20. Sept.');
    await choose(tester, 'Mi., 16. Sept.', 'Stark');
    await tester.tap(find.byWidgetPredicate((w) => w is ChoiceField).first);
    await tester.pumpAndSettle();
    expect(
      bottomOf(find.widgetWithText(ListTile, 'Stark').last),
      lessThanOrEqualTo(limit),
    );
  });

  testWidgets('what is shown by colour is also said in words', (tester) async {
    final handle = tester.ensureSemantics();
    await pumpApp(tester, data: exampleData());
    await openTab(tester, 'Zyklus');
    // Every day of the calendar says what its marking means.
    for (final label in [
      r'^Mittwoch, 2\. September, Schmierblutung, Notiz vorhanden',
      r'^Dienstag, 15\. September, Symptome eingetragen',
      r'^Mittwoch, 16\. September, Periode, Leicht',
      r'^Sonntag, 20\. September, Periode, Schmierblutung',
      r'^Mittwoch, 23\. September, heute',
    ]) {
      expect(
        find.bySemanticsLabel(RegExp(label)),
        findsOneWidget,
        reason: label,
      );
    }
    // The legend names every marking.
    for (final entry in [
      'Periode',
      'Schmierblutung',
      'Erwartete Periode',
      'Möglicher Beginn',
      'Symptom',
    ]) {
      await reveal(tester, find.text(entry));
    }
    handle.dispose();
  });
}
