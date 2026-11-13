import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphhealth/ui/body/body_screen.dart';
import 'package:morphhealth/ui/body/editors.dart';
import 'package:morphhealth/ui/day/day_detail_screen.dart';

import 'support.dart';

Future<void> openSymptoms(WidgetTester tester) async {
  await openTab(tester, 'Körper');
  await tester.tap(find.widgetWithText(Tab, 'Symptome'));
  await tester.pumpAndSettle();
}

Future<void> tapAction(WidgetTester tester, String label) async {
  await tester.tap(find.widgetWithText(FloatingActionButton, label));
  await tester.pumpAndSettle();
}

Future<void> saveDialog(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(FilledButton, 'Speichern'));
  await tester.pumpAndSettle();
}

void main() {
  final today = testNow.day;

  testWidgets('weight: record, validate, correct, delete', (tester) async {
    final app = await pumpApp(tester);
    await openTab(tester, 'Körper');
    expect(find.textContaining('Noch keine Gewichtseinträge'), findsOneWidget);

    await tapAction(tester, 'Gewicht eintragen');
    final field = find.widgetWithText(TextFormField, 'Gewicht in kg');
    await tester.enterText(field, 'abc');
    await tester.pump();
    expect(find.text('Bitte eine Zahl eingeben'), findsOneWidget);
    await tester.enterText(field, '0,5');
    await tester.pump();
    expect(
      find.text('Bitte einen Wert zwischen 1 und 700 eingeben'),
      findsOneWidget,
    );
    await saveDialog(tester);
    expect(
      app.data.weightsSorted,
      isEmpty,
      reason: 'invalid input is kept out',
    );

    await tester.enterText(field, '68,4');
    await saveDialog(tester);
    final added = app.data.weightsSorted.single;
    expect((added.weightKg, added.date), (68.4, today));
    expect(find.text('68,4 kg'), findsWidgets);
    expect(find.text('Heute'), findsWidgets);

    // Correct value and note.
    await tester.tap(find.widgetWithText(ListTile, '68,4 kg'));
    await tester.pumpAndSettle();
    expect(find.text('Gewicht bearbeiten'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '68,4'), findsOneWidget);
    await tester.enterText(field, '67.9');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Notiz (optional)'),
      'morgens',
    );
    await saveDialog(tester);
    final edited = app.data.weightsSorted.single;
    expect(
      (edited.id, edited.weightKg, edited.note),
      (added.id, 67.9, 'morgens'),
    );
    expect(find.text('Heute · morgens'), findsOneWidget);

    // Delete and undo.
    await tester.tap(find.widgetWithText(ListTile, '67,9 kg'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Löschen'));
    await tester.pumpAndSettle();
    expect(app.data.weightsSorted, isEmpty);
    expect(find.text('Eintrag gelöscht'), findsOneWidget);
    await tapText(tester, 'Rückgängig');
    expect(app.data.weightsSorted.single.weightKg, 67.9);
  });

  testWidgets('weight in pounds is converted exactly', (tester) async {
    final app = await pumpApp(
      tester,
      data: exampleData(),
      settings: (s) => s.copyWith(weightUnit: 'lb'),
    );
    await openTab(tester, 'Körper');
    // 68.0 kg of the example in pounds.
    expect(find.text('149,9 lb'), findsWidgets);

    await tapAction(tester, 'Gewicht eintragen');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Gewicht in lb'),
      '150',
    );
    await saveDialog(tester);
    final added = app.data.weightsOn(today).single;
    expect(added.weightKg, closeTo(150 * 0.45359237, 1e-9));
    expect(find.text('150,0 lb'), findsWidgets);

    // The stored value stays in kilograms; switching back shows it again.
    await app.controller.updateSettings((s) => s.copyWith(weightUnit: 'kg'));
    await tester.pumpAndSettle();
    expect(find.text('68,0 kg'), findsWidgets);
  });

  testWidgets('weight trend: ranges, summary and the way to the day', (
    tester,
  ) async {
    await pumpApp(tester, data: exampleData());
    await openTab(tester, 'Körper');
    expect(find.text('68,0 kg'), findsWidgets);
    expect(
      find.text('Durchschnitt: 68,1 kg · −0,4 kg seit 1. Sept.'),
      findsOneWidget,
    );
    expect(
      find.bySemanticsLabel(
        RegExp(
          r'^Gewicht, 27\. Aug\. – 23\. Sept\.: 4 Tage mit Werten\. '
          r'Durchschnitt 68,1 kg, niedrigster Wert 67,9 kg, '
          r'höchster Wert 68,4 kg\.',
        ),
      ),
      findsOneWidget,
    );

    // The same values as text.
    await tapText(tester, 'Werte als Liste');
    expect(find.text('Di., 15. Sept.'), findsWidgets);

    await tester.tap(find.text('7 Tage'));
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Durchschnitt:'),
      findsNothing,
      reason: 'one value is no trend',
    );
    expect(
      find.bySemanticsLabel(
        'Gewicht, 17. – 23. Sept.: 1 Tag mit einem Wert, 68,0 kg.',
      ),
      findsOneWidget,
    );

    await tester.tap(find.text('Alles'));
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsLabel(RegExp(r'^Gewicht, 1\. – 23\. Sept\.')),
      findsOneWidget,
    );
  });

  testWidgets('symptoms: free name, strength 0 to 10, correct, delete', (
    tester,
  ) async {
    final app = await pumpApp(tester);
    await openSymptoms(tester);
    expect(find.text('Noch keine Symptome eingetragen.'), findsOneWidget);

    await tapAction(tester, 'Symptom eintragen');
    expect(find.byType(SymptomScreen), findsOneWidget);
    // Without a name nothing is saved.
    await tester.tap(find.widgetWithText(TextButton, 'Speichern'));
    await tester.pumpAndSettle();
    expect(find.text('Bitte ausfüllen'), findsOneWidget);
    expect(app.data.symptoms, isEmpty);

    // A suggestion fills in the name; the strength goes up to 10 and down to 0.
    await tapChip(tester, 'Kopfschmerzen');
    for (var i = 0; i < 6; i++) {
      await tapTooltip(tester, 'Stärker');
    }
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.add_circle_outline),
          )
          .onPressed,
      isNull,
      reason: '10 is the upper end',
    );
    for (var i = 0; i < 3; i++) {
      await tapTooltip(tester, 'Schwächer');
    }
    await tester.tap(find.widgetWithText(TextButton, 'Speichern'));
    await tester.pumpAndSettle();
    final added = app.data.symptoms.single;
    expect(
      (added.name, added.intensity, added.at.day),
      ('Kopfschmerzen', 7, today),
    );
    expect(find.text('Stärke 7 von 10 · Heute, 12:40'), findsOneWidget);

    // A name of one's own, strength 0.
    await tapAction(tester, 'Symptom eintragen');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Symptom'),
      'Kribbeln im Fuß',
    );
    for (var i = 0; i < 5; i++) {
      await tapTooltip(tester, 'Schwächer');
    }
    await tester.tap(find.widgetWithText(TextButton, 'Speichern'));
    await tester.pumpAndSettle();
    expect(
      app.data.symptoms
          .firstWhere((s) => s.name == 'Kribbeln im Fuß')
          .intensity,
      0,
    );

    // Correct the first one.
    await tapText(tester, 'Kopfschmerzen');
    expect(find.text('Symptom bearbeiten'), findsOneWidget);
    await tapTooltip(tester, 'Schwächer');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Notiz (optional)'),
      'nach Bildschirm',
    );
    await tester.tap(find.widgetWithText(TextButton, 'Speichern'));
    await tester.pumpAndSettle();
    final edited = app.data.symptomEntry(added.id)!;
    expect((edited.intensity, edited.note), (6, 'nach Bildschirm'));

    // Delete and undo.
    await tapText(tester, 'Kopfschmerzen');
    await tapTooltip(tester, 'Löschen');
    expect(app.data.symptomEntry(added.id), isNull);
    await tapText(tester, 'Rückgängig');
    expect(app.data.symptomEntry(added.id), isNotNull);
  });

  testWidgets('symptom trend: one symptom or all, ranges, day detail', (
    tester,
  ) async {
    await pumpApp(tester, data: exampleData());
    await openSymptoms(tester);
    expect(
      find.bySemanticsLabel(
        RegExp(
          r'^Alle Symptome, Stärkster Wert je Tag, 27\. Aug\. – 23\. Sept\.: '
          r'3 Tage mit Werten\. Durchschnitt 4,7, niedrigster Wert 3, '
          r'höchster Wert 7\.',
        ),
      ),
      findsOneWidget,
    );
    await reveal(tester, find.byType(SymptomTile));
    expect(find.byType(SymptomTile), findsNWidgets(3));

    // One symptom over the whole time.
    await choose(tester, 'Symptom', 'Krämpfe (4)');
    await tester.tap(find.text('Alles'));
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsLabel(
        RegExp(
          r'^Krämpfe, Stärkster Wert je Tag, 23\. Juni – 23\. Sept\.: '
          r'4 Tage mit Werten\. Durchschnitt 6, niedrigster Wert 5, '
          r'höchster Wert 7\.',
        ),
      ),
      findsOneWidget,
    );

    // The same values as text.
    await tapText(tester, 'Werte als Liste');
    await reveal(tester, find.text('Mi., 16. Sept.'));
    expect(find.text('Stärke 7 von 10'), findsWidgets);
  });

  testWidgets('a chart opens the day it shows', (tester) async {
    await pumpApp(tester, data: exampleData());
    await openTab(tester, 'Körper');
    final chart = find.bySemanticsLabel(RegExp(r'^Gewicht, 27\. Aug\.'));
    // 28 days from 27 August; 22 September is the 27th of them. The plot
    // begins 44 px from the left and ends 8 px before the right edge.
    final box = tester.getRect(chart);
    final slot = (box.width - 44 - 8) / 28;
    await tester.tapAt(Offset(box.left + 44 + slot * 26.5, box.center.dy));
    await tester.pumpAndSettle();
    expect(find.text('Di., 22. Sept.: 68,0 kg'), findsOneWidget);
    await tapText(tester, 'Tagesdetail');
    expect(find.byType(DayDetailScreen), findsOneWidget);
    expect(find.textContaining('22. Sept'), findsWidgets);
  });
}
