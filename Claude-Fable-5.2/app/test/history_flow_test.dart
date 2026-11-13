import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphhealth/ui/cycle/period_form_screen.dart';
import 'package:morphhealth/ui/day/day_detail_screen.dart';
import 'package:morphhealth/ui/history/history_screen.dart';
import 'package:morphhealth/ui/nutrition/intake_screen.dart';
import 'package:morphhealth_core/src/testing/sample_data.dart';

import 'support.dart';

Finder get searchField =>
    find.widgetWithText(TextField, 'Einträge durchsuchen');

Future<void> search(WidgetTester tester, String text) async {
  await tester.enterText(searchField, text);
  await tester.pumpAndSettle();
}

Future<void> toggleArea(WidgetTester tester, String label) async {
  final chip = find.widgetWithText(FilterChip, label);
  await tester.ensureVisible(chip);
  await tester.pumpAndSettle();
  await tester.tap(chip);
  await tester.pumpAndSettle();
}

Future<void> chooseRange(WidgetTester tester, String label) async {
  final chip = find.byType(ActionChip).first;
  await tester.ensureVisible(chip);
  await tester.pumpAndSettle();
  await tester.tap(chip);
  await tester.pumpAndSettle();
  await tester.tap(find.widgetWithText(ListTile, label));
  await tester.pumpAndSettle();
}

Future<void> openTrends(WidgetTester tester) async {
  await openTab(tester, 'Verlauf');
  await tester.tap(find.widgetWithText(Tab, 'Verläufe'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('one list for all areas: search, areas, date range', (
    tester,
  ) async {
    await pumpApp(tester, data: exampleData());
    await openTab(tester, 'Verlauf');
    // 7 food entries, 5 water, 2 caffeine, 4 weights, 9 symptoms, 8 periods
    // and 1 cycle note.
    expect(find.text('36 Einträge'), findsOneWidget);
    expect(find.text('Mittwoch, 23. September'), findsOneWidget);

    // Free text finds names, meals and notes, regardless of case and umlauts.
    await search(tester, 'krampfe');
    expect(find.text('4 Einträge'), findsOneWidget);
    await search(tester, 'FRÜHSTÜCK');
    expect(find.text('4 Einträge'), findsOneWidget);
    await search(tester, 'frühstück hafer');
    expect(find.text('2 Einträge'), findsOneWidget);
    await search(tester, 'wärmflasche');
    expect(find.text('1 Eintrag'), findsOneWidget);
    expect(find.text('Periode, 16. – 20. Sept.'), findsOneWidget);
    await search(tester, 'gibt es nicht');
    expect(find.text('0 Einträge'), findsOneWidget);
    expect(find.text('Keine Einträge gefunden.'), findsOneWidget);
    await tapTooltip(tester, 'Suche leeren');
    expect(find.text('36 Einträge'), findsOneWidget);

    // Areas.
    await toggleArea(tester, 'Ernährung');
    expect(find.text('22 Einträge'), findsOneWidget);
    await toggleArea(tester, 'Zyklus');
    expect(find.text('13 Einträge'), findsOneWidget);
    await toggleArea(tester, 'Gewicht');
    expect(find.text('9 Einträge'), findsOneWidget);
    await toggleArea(tester, 'Symptome');
    expect(find.text('0 Einträge'), findsOneWidget);
    await tapText(tester, 'Filter zurücksetzen');
    expect(find.text('36 Einträge'), findsOneWidget);
    expect(find.text('Filter zurücksetzen'), findsNothing);

    // Date range; the period that reaches into the range belongs to it.
    await chooseRange(tester, 'Letzte 7 Tage');
    expect(find.text('17 Einträge'), findsOneWidget);
    await chooseRange(tester, 'Letzte 28 Tage');
    expect(find.text('23 Einträge'), findsOneWidget);
    await search(tester, 'kopf');
    expect(find.text('1 Eintrag'), findsOneWidget);
    await chooseRange(tester, 'Gesamter Zeitraum');
    expect(find.text('4 Einträge'), findsOneWidget);
  });

  testWidgets('every kind of entry opens for correction', (tester) async {
    await pumpApp(tester, data: exampleData());
    await openTab(tester, 'Verlauf');

    await search(tester, 'cola');
    await tester.tap(find.byType(HistoryTile));
    await tester.pumpAndSettle();
    expect(find.byType(IntakeScreen), findsOneWidget);
    await goBack(tester);

    await search(tester, 'wasser');
    await tester.tap(find.byType(HistoryTile).first);
    await tester.pumpAndSettle();
    expect(find.text('Wassereintrag bearbeiten'), findsOneWidget);
    await tapText(tester, 'Abbrechen');

    await search(tester, 'kaffee');
    await tester.tap(find.byType(HistoryTile).first);
    await tester.pumpAndSettle();
    expect(find.text('Koffeineintrag bearbeiten'), findsOneWidget);
    await tapText(tester, 'Abbrechen');

    await search(tester, 'gewicht');
    await tester.tap(find.byType(HistoryTile).first);
    await tester.pumpAndSettle();
    expect(find.text('Gewicht bearbeiten'), findsOneWidget);
    await tapText(tester, 'Abbrechen');

    await search(tester, 'müdigkeit');
    await tester.tap(find.byType(HistoryTile));
    await tester.pumpAndSettle();
    expect(find.text('Symptom bearbeiten'), findsOneWidget);
    await tapTooltip(tester, 'Schließen');

    await search(tester, 'wärmflasche');
    await tester.tap(find.byType(HistoryTile));
    await tester.pumpAndSettle();
    expect(find.byType(PeriodFormScreen), findsOneWidget);
    await goBack(tester);

    // The period with spotting on its last day and the note of 2 September.
    await search(tester, 'schmierblutung');
    expect(find.byType(HistoryTile), findsNWidgets(2));
    await tester.tap(find.byType(HistoryTile).last);
    await tester.pumpAndSettle();
    expect(find.byType(DayDetailScreen), findsOneWidget);
  });

  testWidgets('trends over 7 and 28 days for all four areas', (tester) async {
    await pumpApp(tester, data: exampleData());
    await openTrends(tester);

    // Seven days up to today.
    expect(find.text('17. – 23. Sept.'), findsOneWidget);
    expect(
      find.bySemanticsLabel(
        RegExp(
          r'^Kalorien, 17\. – 23\. Sept\.: '
          r'2 Tage mit Werten\.',
        ),
      ),
      findsOneWidget,
    );
    await reveal(
      tester,
      find.bySemanticsLabel(RegExp(r'^Gewicht, 17\. – 23\. Sept\.')),
    );
    await reveal(tester, find.text('4 Periodentage im Zeitraum'));

    // 28 days.
    await reveal(tester, find.text('28 Tage'));
    await tester.tap(find.text('28 Tage'));
    await tester.pumpAndSettle();
    expect(find.text('27. Aug. – 23. Sept.'), findsOneWidget);
    await reveal(
      tester,
      find.bySemanticsLabel(
        RegExp(r'^Gewicht, 27\. Aug\. – 23\. Sept\.: 4 Tage mit Werten\.'),
      ),
    );
    await reveal(tester, find.text('5 Periodentage im Zeitraum'));

    // Another quantity: water with its goal.
    await choose(tester, 'Größe', 'Wasser (ml)');
    expect(
      find.bySemanticsLabel(
        RegExp(
          r'^Wasser, 27\. Aug\. – 23\. Sept\.: 2 Tage mit Werten\. '
          r'Durchschnitt 790 ml, niedrigster Wert 500 ml, '
          r'höchster Wert 1\.080 ml\.',
        ),
      ),
      findsOneWidget,
    );

    // The earlier range and back.
    await reveal(tester, find.byTooltip('Früherer Zeitraum'));
    await tapTooltip(tester, 'Früherer Zeitraum');
    expect(find.text('30. Juli – 26. Aug.'), findsOneWidget);
    await reveal(tester, find.text('5 Periodentage im Zeitraum'));
    await reveal(tester, find.byTooltip('Zu heute springen'));
    await tapTooltip(tester, 'Zu heute springen');
    expect(find.text('27. Aug. – 23. Sept.'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.chevron_right),
          )
          .onPressed,
      isNull,
      reason: 'there is nothing after today',
    );
  });

  testWidgets('10,000 entries: the list opens, searches and scrolls quickly', (
    tester,
  ) async {
    final data = generateSampleDiary(end: testNow.day);
    expect(data.entryCount, greaterThan(10000));
    final watch = Stopwatch()..start();
    await pumpApp(tester, data: data);
    final started = watch.elapsedMilliseconds;

    watch.reset();
    await openTab(tester, 'Verlauf');
    final opened = watch.elapsedMilliseconds;
    expect(find.text('10.734 Einträge'), findsOneWidget);

    // Every keystroke filters the whole list.
    final times = <int>[];
    for (final text in ['k', 'kr', 'krä', 'kräm', 'krämpfe']) {
      watch.reset();
      await tester.enterText(searchField, text);
      await tester.pump();
      times.add(watch.elapsedMilliseconds);
    }
    await tester.pumpAndSettle();
    final hits = int.parse(
      RegExp(r'^(\d+) Einträge$')
          .firstMatch(
            tester
                .widget<Text>(find.textContaining(RegExp(r'^\d+ Einträge$')))
                .data!,
          )!
          .group(1)!,
    );
    expect(hits, inInclusiveRange(20, 200));

    watch.reset();
    await search(tester, '');
    await toggleArea(tester, 'Ernährung');
    final filtered = watch.elapsedMilliseconds;

    // Scrolling far builds only what is visible.
    await toggleArea(tester, 'Ernährung');
    watch.reset();
    final list = find.byWidgetPredicate(
      (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
    );
    for (var i = 0; i < 20; i++) {
      await tester.fling(list.last, const Offset(0, -900), 6000);
      await tester.pump(const Duration(milliseconds: 400));
    }
    await tester.pumpAndSettle();
    final scrolled = watch.elapsedMilliseconds;
    expect(tester.takeException(), isNull);

    // Trends over the same data.
    watch.reset();
    await tester.tap(find.widgetWithText(Tab, 'Verläufe'));
    await tester.pumpAndSettle();
    final trends = watch.elapsedMilliseconds;

    debugPrint(
      '10k entries (debug build, test host): start $started ms, '
      'history $opened ms, keystrokes $times ms, area filter $filtered ms, '
      '20 flings $scrolled ms, trends $trends ms',
    );
    // Generous limits for an unoptimised debug build; the release build is
    // several times faster.
    expect(opened, lessThan(1500));
    expect(times.reduce((a, b) => a > b ? a : b), lessThan(400));
    expect(trends, lessThan(1500));
  });
}
