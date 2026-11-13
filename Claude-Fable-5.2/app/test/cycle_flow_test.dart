import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphhealth/ui/cycle/cycle_history_screen.dart';
import 'package:morphhealth/ui/cycle/month_calendar.dart';
import 'package:morphhealth/ui/cycle/period_form_screen.dart';
import 'package:morphhealth_core/morphhealth_core.dart';

import 'support.dart';

/// The calendar cell of the day whose spoken label starts with [label].
Finder dayCell(String label) => find.descendant(
  of: find.byType(MonthCalendar),
  matching: find.bySemanticsLabel(RegExp('^${RegExp.escape(label)}')),
);

Future<void> tapDay(WidgetTester tester, String label) async {
  await reveal(tester, dayCell(label));
  await tester.tap(dayCell(label));
  await tester.pumpAndSettle();
}

Future<void> saveForm(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(TextButton, 'Speichern').first);
  await tester.pumpAndSettle();
}

void main() {
  final today = testNow.day; // Wednesday, 23 September 2026

  testWidgets('a period is started and ended with one tap each', (
    tester,
  ) async {
    final app = await pumpApp(tester);
    await openTab(tester, 'Zyklus');
    expect(find.text('Noch keine Periode erfasst'), findsOneWidget);

    await tapText(tester, 'Periode beginnt heute');
    var period = app.data.periodsSorted.single;
    expect((period.start, period.end), (today, null));
    expect(find.text('Periode, Tag 1'), findsWidgets);
    expect(find.text('Periode eingetragen'), findsOneWidget);

    // Bleeding strength of the day, including spotting.
    await tapChoice(tester, 'Stark');
    expect(app.data.periodsSorted.single.flow, {today: FlowLevel.heavy});
    await tapChoice(tester, 'Schmierblutung');
    expect(app.data.periodsSorted.single.flow, {today: FlowLevel.spotting});
    await tapChoice(tester, 'Schmierblutung');
    expect(app.data.periodsSorted.single.flow, isEmpty);

    await tapText(tester, 'Periode endet heute');
    period = app.data.periodsSorted.single;
    expect(period.end, today);
    await tapText(tester, 'Rückgängig');
    expect(app.data.periodsSorted.single.end, isNull);
  });

  testWidgets('the calendar shows history, estimate and day details', (
    tester,
  ) async {
    final app = await pumpApp(tester, data: exampleData());
    await openTab(tester, 'Zyklus');

    // Assessment for today.
    expect(
      find.text('Nächste Periode voraussichtlich um den 14. Oktober'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Zeitfenster 12. Okt. bis 16. Okt.'),
      findsOneWidget,
    );
    expect(find.textContaining('in 21 Tagen'), findsOneWidget);
    expect(find.text('Zyklustag 8'), findsWidgets);

    // September: recorded period, spotting, symptoms.
    expect(dayCell('Mittwoch, 16. September, Periode, Leicht'), findsOneWidget);
    expect(
      dayCell('Donnerstag, 17. September, Periode, Stark'),
      findsOneWidget,
    );
    expect(
      tester.getSemantics(dayCell('Mittwoch, 2. September')).label,
      contains('Schmierblutung'),
    );
    expect(
      tester.getSemantics(dayCell('Dienstag, 15. September')).label,
      contains('Symptome eingetragen'),
    );
    expect(
      tester.getSemantics(dayCell('Mittwoch, 23. September')).label,
      contains('heute'),
    );

    // A day of the period: its details and symptoms appear below.
    await tapDay(tester, 'Mittwoch, 16. September');
    expect(find.text('Mittwoch, 16. September 2026'), findsOneWidget);
    expect(find.text('Periode, Tag 1'), findsOneWidget);
    await reveal(tester, find.text('Krämpfe'));
    expect(find.textContaining('Stärke 7 von 10'), findsOneWidget);

    // Symptoms can be added from the calendar's day context.
    await tapText(tester, 'Symptom eintragen');
    await tester.enterText(
      find.widgetWithText(TextField, 'Symptom'),
      'Rückenschmerzen',
    );
    await saveForm(tester);
    final added = app.data
        .symptomsOn(Day(2026, 9, 16))
        .firstWhere((s) => s.name == 'Rückenschmerzen');
    expect(added.intensity, 5);

    // October: the estimate.
    await tapTooltip(tester, 'Nächster Monat');
    expect(find.text('Oktober 2026'), findsOneWidget);
    expect(
      tester.getSemantics(dayCell('Mittwoch, 14. Oktober')).label,
      contains('Periode erwartet'),
    );
    expect(
      tester.getSemantics(dayCell('Montag, 12. Oktober')).label,
      contains('möglicher Beginn der Periode'),
    );
    await tapDay(tester, 'Mittwoch, 14. Oktober');
    await reveal(
      tester,
      find.text('Für diesen Tag wird die Periode erwartet.'),
    );
    expect(
      find.text('Periode begann an diesem Tag'),
      findsNothing,
      reason: 'nothing can be recorded for days to come',
    );

    // Older months stay reachable.
    for (var i = 0; i < 8; i++) {
      await tapTooltip(tester, 'Vorheriger Monat');
    }
    expect(find.text('Februar 2026'), findsOneWidget);
    await tapTooltip(tester, 'Zu heute springen');
    expect(find.text('September 2026'), findsOneWidget);
  });

  testWidgets('the explanation tells how the estimate comes about', (
    tester,
  ) async {
    await pumpApp(tester, data: exampleData());
    await openTab(tester, 'Zyklus');
    await tapText(tester, 'Wie kommt das zustande?');
    expect(find.text('So entsteht die Einschätzung'), findsOneWidget);
    expect(
      find.textContaining('Grundlage sind deine letzten 7 Zyklen'),
      findsOneWidget,
    );
    expect(
      find.textContaining('typische Zykluslänge von 28 Tagen'),
      findsOneWidget,
    );
    final sheet = find.byType(Scrollable).last;
    await tester.scrollUntilVisible(
      find.textContaining('eignet sich weder zur Verhütung'),
      200,
      scrollable: sheet,
    );
    await tester.scrollUntilVisible(
      find.textContaining('Verlässlichkeit dieser Einschätzung: hoch'),
      -200,
      scrollable: sheet,
    );
  });

  testWidgets('recurring symptoms around the period are pointed out', (
    tester,
  ) async {
    await pumpApp(tester, data: exampleData());
    await openTab(tester, 'Zyklus');
    expect(find.text('Wiederkehrende Muster'), findsOneWidget);
    expect(
      find.textContaining(
        'Kopfschmerzen: in 4 von 6 Zyklen vor Beginn der '
        'Periode, meist 1 Tag vorher',
      ),
      findsOneWidget,
    );
    expect(
      find.textContaining(
        'Krämpfe: in 4 von 6 Zyklen in den ersten Tagen '
        'der Periode, meist an Tag 1',
      ),
      findsOneWidget,
    );
  });

  testWidgets('a past period is recorded, corrected and deleted', (
    tester,
  ) async {
    final app = await pumpApp(tester, data: exampleData());
    await openTab(tester, 'Zyklus');

    // A day in August without period: the form opens with a suggested end.
    await tapTooltip(tester, 'Vorheriger Monat');
    await tapDay(tester, 'Mittwoch, 5. August');
    await tapText(tester, 'Periode begann an diesem Tag');
    expect(find.byType(PeriodFormScreen), findsOneWidget);
    expect(find.text('Mittwoch, 5. August 2026'), findsOneWidget);
    expect(find.text('Sonntag, 9. August 2026'), findsOneWidget);
    await saveForm(tester);
    expect(app.data.periodCount, 9);
    final added = app.data.periodOn(Day(2026, 8, 7), today)!;
    expect((added.start, added.end), (Day(2026, 8, 5), Day(2026, 8, 9)));

    // A period that would overlap an existing one is refused with a reason.
    await tapDay(tester, 'Montag, 17. August');
    await tapText(tester, 'Periode begann an diesem Tag');
    await saveForm(tester);
    expect(find.byType(PeriodFormScreen), findsOneWidget);
    expect(
      find.textContaining('überschneidet sich mit der Periode ab 19. Aug.'),
      findsOneWidget,
    );
    await goBack(tester);
    expect(app.data.periodCount, 9);

    // Correct the added period in the history: bleeding strength and note.
    await tapTooltip(tester, 'Periodenverlauf');
    expect(find.byType(CycleHistoryScreen), findsOneWidget);
    expect(find.text('Typischer Zyklus'), findsOneWidget);
    await tapText(tester, '5. – 9. Aug.');
    await choose(tester, 'Mi., 5. Aug.', 'Mittel');
    await reveal(tester, find.widgetWithText(TextField, 'Notiz (optional)'));
    await tester.enterText(
      find.widgetWithText(TextField, 'Notiz (optional)'),
      'kürzer als sonst',
    );
    await saveForm(tester);
    final edited = app.data.period(added.id)!;
    expect(edited.flow, {Day(2026, 8, 5): FlowLevel.medium});
    expect(edited.note, 'kürzer als sonst');

    // Delete it, with confirmation and the chance to undo.
    await tapText(tester, '5. – 9. Aug.');
    await tapTooltip(tester, 'Löschen');
    expect(find.text('Diese Periode löschen?'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Löschen'));
    await tester.pumpAndSettle();
    expect(app.data.period(added.id), isNull);
    await tapText(tester, 'Rückgängig');
    expect(app.data.period(added.id), isNotNull);
  });

  testWidgets('diary mode: records only, no estimate anywhere', (tester) async {
    final app = await pumpApp(
      tester,
      data: exampleData(),
      settings: (s) => s.copyWith(cyclePredictions: false),
    );
    await openTab(tester, 'Zyklus');
    expect(find.textContaining('Tagebuchmodus'), findsOneWidget);
    expect(find.textContaining('Nächste Periode'), findsNothing);
    expect(find.text('Wie kommt das zustande?'), findsNothing);
    expect(find.text('Wiederkehrende Muster'), findsNothing);
    expect(find.text('Erwartete Periode'), findsNothing);
    expect(find.text('Zyklustag 8'), findsWidgets);

    await tapTooltip(tester, 'Nächster Monat');
    expect(
      tester.getSemantics(dayCell('Mittwoch, 14. Oktober')).label,
      isNot(contains('erwartet')),
    );

    // Recording still works.
    await tapTooltip(tester, 'Zu heute springen');
    await tapDay(tester, 'Mittwoch, 23. September');
    await tapText(tester, 'Periode begann an diesem Tag');
    expect(app.data.periodCount, 9);
  });

  testWidgets('spotting and a note outside a period', (tester) async {
    final app = await pumpApp(tester);
    await openTab(tester, 'Zyklus');
    await tapDay(tester, 'Montag, 21. September');
    await tapText(tester, 'Schmierblutung an diesem Tag');
    expect(app.data.cycleDay(Day(2026, 9, 21))!.spotting, isTrue);
    await tapText(tester, 'Notiz zum Tag');
    await tester.enterText(find.widgetWithText(TextField, 'Notiz'), 'leicht');
    await tapText(tester, 'Speichern');
    expect(app.data.cycleDay(Day(2026, 9, 21))!.note, 'leicht');
    expect(find.text('leicht'), findsOneWidget);
    expect(
      tester.getSemantics(dayCell('Montag, 21. September')).label,
      allOf(contains('Schmierblutung'), contains('Notiz vorhanden')),
    );
  });
}
