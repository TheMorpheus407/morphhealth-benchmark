import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphhealth/core/civil.dart';
import 'package:morphhealth/core/core.dart';
import 'package:morphhealth/core/models.dart';

import 'harness.dart';

Future<void> seedHistory(MorphCore core) async {
  final db = core.db;
  for (final s in [
    ('Kopfschmerz', 4, '2026-09-28T16:00'),
    ('Müdigkeit', 3, '2026-09-28T20:30'),
    ('Kopfschmerz', 6, '2026-09-20T09:00'),
  ]) {
    await db.saveSymptom(SymptomEntry(id: 's${s.$3}', name: s.$1, intensity: s.$2, at: LocalDateTime.parse(s.$3)));
  }
  await db.saveWeight(WeightEntry(id: 'w1', at: LocalDateTime.parse('2026-09-21T07:00'), kg: 72.4));
  await db.saveWeight(WeightEntry(id: 'w2', at: LocalDateTime.parse('2026-09-28T07:00'), kg: 72.0, note: 'nüchtern'));
  for (final d in ['2026-06-08', '2026-07-06', '2026-08-03', '2026-08-31']) {
    final s = Day.parse(d);
    await db.savePeriod(PeriodRecord(id: 'p$d', start: s, end: s.addDays(4), flow: FlowLevel.medium));
  }
  await db.saveWater(WaterEntry(id: 'wa1', at: LocalDateTime.parse('2026-09-28T08:00'), ml: 250));
}

void main() {
  setUpAll(loadRoboto);

  testWidgets('Gewicht: Eingabe und Anzeige in lb, intern kg', (tester) async {
    final app = await launchApp(tester);
    await app.db.saveSettings(app.settings.copyWith(weightUnit: WeightUnit.lb));
    await tester.pumpAndSettle();
    await openTab(tester, 'Gewicht');
    await tester.tap(find.text('Gewicht erfassen'));
    await tester.pumpAndSettle();
    await enterByLabel(tester, 'Gewicht', '160');
    await tester.tap(find.widgetWithText(FilledButton, 'Speichern'));
    await tester.pumpAndSettle();
    final e = app.db.weights.all.single;
    expect(e.kg, closeTo(72.5748, 1e-3));
    expect(find.text('160,0 lb'), findsWidgets);
    // Bearbeiten und Löschen.
    await tester.tap(find.byIcon(Icons.edit_outlined).first);
    await tester.pumpAndSettle();
    await enterByLabel(tester, 'Gewicht', '158,5');
    await tester.tap(find.widgetWithText(FilledButton, 'Speichern'));
    await tester.pumpAndSettle();
    expect(app.db.weights.all.single.kg, closeTo(71.8935, 1e-3));
    await tester.tap(find.byIcon(Icons.edit_outlined).first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(TextButton, 'Löschen'));
    await tester.pumpAndSettle();
    expect(app.db.weights.length, 0);
  });

  testWidgets('Fachliche Fehler erscheinen in der Sprache der App', (tester) async {
    final app = await launchApp(tester);
    // Deutsch: 0,5 kg besteht die Feldprüfung (größer als 0), liegt aber unter dem zulässigen Bereich.
    await openTab(tester, 'Gewicht');
    await tester.tap(find.text('Gewicht erfassen'));
    await tester.pumpAndSettle();
    await enterByLabel(tester, 'Gewicht', '0,5');
    await tester.tap(find.widgetWithText(FilledButton, 'Speichern'));
    await tester.pumpAndSettle();
    expect(find.text('Das Gewicht liegt außerhalb des zulässigen Bereichs (1 bis 700 kg).'), findsOneWidget);
    expect(app.db.weights.length, 0);
    await popTop(tester);

    await app.db.saveSettings(app.settings.copyWith(language: 'en'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Log weight'));
    await tester.pumpAndSettle();
    await enterByLabel(tester, 'Weight', '0.5');
    await tester.tap(find.widgetWithText(FilledButton, 'Save'));
    await tester.pumpAndSettle();
    expect(find.text('The weight is outside the allowed range (1 to 700 kg).'), findsOneWidget);
    expect(find.textContaining('Gewicht'), findsNothing, reason: 'kein deutscher Text in der englischen Oberfläche');
  });

  testWidgets('Gewicht in kg: Verlauf mit Diagramm und Änderung', (tester) async {
    final app = await launchApp(tester, seed: seedHistory);
    await openTab(tester, 'Gewicht');
    expect(find.text('72,0 kg'), findsWidgets);
    expect(find.textContaining('−0,4 kg'), findsWidgets);
    expect(app.db.weightOn(Day.parse('2026-09-28'))!.kg, 72.0);
  });

  testWidgets('Symptome: erfassen, Schnellwahl zuletzt verwendeter, Verlauf je Symptom', (tester) async {
    final app = await launchApp(tester, seed: seedHistory);
    await openTab(tester, 'Symptome');
    await tester.tap(find.text('Symptom erfassen'));
    await tester.pumpAndSettle();
    await enterByLabel(tester, 'Name des Symptoms', 'Rückenschmerz');
    // Intensität 7: Schieberegler per Tastenaktion.
    final slider = find.byType(Slider);
    await tester.drag(slider, const Offset(100, 0));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Speichern'));
    await tester.pumpAndSettle();
    final added = app.db.symptoms.all.firstWhere((s) => s.name == 'Rückenschmerz');
    expect(added.intensity, inInclusiveRange(0, 10));
    expect(added.at.day, Day.parse('2026-09-29'));
    // Schnellwahl zeigt bekannte Namen.
    expect(find.widgetWithText(ActionChip, 'Kopfschmerz'), findsOneWidget);
    // Verlauf je Symptom.
    await tester.tap(find.text('Verlauf'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Einträge'), findsWidgets);
    expect(find.textContaining('Durchschnitt'), findsWidgets);
    final k = app.db.symptoms.all.where((s) => s.key == 'kopfschmerz').toList();
    expect(k.length, 2);
  });

  testWidgets('Periode: beginnen, beenden, Überschneidung wird erklärt', (tester) async {
    final app = await launchApp(tester);
    await openTab(tester, 'Zyklus');
    expect(find.text('Noch keine Perioden erfasst'), findsWidgets);
    await tester.tap(find.text('Periode beginnt heute'));
    await tester.pumpAndSettle();
    expect(app.db.periods.length, 1);
    expect(app.db.periods.single.start, Day.parse('2026-09-29'));
    expect(app.db.periods.single.end, isNull);
    expect(find.text('Tag 1 der Periode'), findsWidgets);
    await tester.tap(find.text('Periode endet heute'));
    await tester.pumpAndSettle();
    expect(app.db.periods.single.end, Day.parse('2026-09-29'));
    // Überschneidende Periode über das Blatt: Fehlermeldung mit Zeitraum.
    await tester.tap(find.text('Periode erfassen'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Speichern'));
    await tester.pumpAndSettle();
    expect(find.textContaining('überschneidet sich'), findsOneWidget);
    expect(app.db.periods.length, 1);
  });

  testWidgets('Zyklus: Blutungsstärke am gewählten Tag, Spotting zählt nicht als Beginn', (tester) async {
    final app = await launchApp(tester);
    await openTab(tester, 'Zyklus');
    await tapScrolled(tester, find.widgetWithText(ChoiceChip, 'Spotting'));
    await tester.pumpAndSettle();
    expect(app.db.periods.single.flow, FlowLevel.spotting);
    expect(app.core.cycleForecast(Day.parse('2026-09-29')).status.id, 'no_data'); // nur Spotting
    await tapScrolled(tester, find.widgetWithText(ChoiceChip, 'Stark'));
    expect(app.db.periods.single.flowOn(Day.parse('2026-09-29')), FlowLevel.heavy);
    expect(app.core.cycleForecast(Day.parse('2026-09-29')).status.id, 'in_period');
  });

  testWidgets('Prognose: Erklärung erreichbar, Tagebuchmodus blendet sie aus', (tester) async {
    final app = await launchApp(tester, seed: seedHistory);
    await openTab(tester, 'Zyklus');
    expect(find.textContaining('Der berechnete Beginn liegt 1 Tag zurück'), findsOneWidget);
    await tester.tap(find.text('Wie kommt die Einschätzung zustande?'));
    await tester.pumpAndSettle();
    expect(find.text('Erklärung der Einschätzung'), findsOneWidget);
    expect(find.textContaining('Mittelwert'), findsOneWidget);
    expect(find.textContaining('28, 28, 28'), findsOneWidget);
    expect(find.textContaining('Eisprung'), findsOneWidget); // Abgrenzung im Hinweis
    await tester.tap(find.byTooltip('Zurück'));
    await tester.pumpAndSettle();
    await app.db.saveSettings(app.settings.copyWith(cycleForecast: false));
    await tester.pumpAndSettle();
    expect(find.text('Wie kommt die Einschätzung zustande?'), findsNothing);
    expect(find.textContaining('berechnete Beginn'), findsNothing);
    // Das Tagebuch bleibt bedienbar.
    expect(find.text('Periode beginnt heute'), findsOneWidget);
    expect(app.core.cycleForecast(Day.parse('2026-09-29')).status.id, 'disabled');
  });

  testWidgets('Historie: Text, Bereich und Zeitraum filtern, Einträge lassen sich öffnen', (tester) async {
    final app = await launchApp(tester, seed: seedHistory);
    await tester.tap(find.byTooltip('Historie'));
    await tester.pumpAndSettle();
    expect(find.text('10 Einträge'), findsOneWidget);
    // Freitext
    await tester.enterText(find.byType(TextField).first, 'kopf');
    await tester.pumpAndSettle();
    expect(find.text('2 Einträge'), findsOneWidget);
    // Bereich: nur Gewicht -> Freitext passt nicht mehr
    await tester.tap(find.widgetWithText(FilterChip, 'Gewicht'));
    await tester.pumpAndSettle();
    expect(find.text('Keine Einträge'), findsOneWidget);
    await tester.tap(find.text('Filter zurücksetzen'));
    await tester.pumpAndSettle();
    expect(find.text('10 Einträge'), findsOneWidget);
    // Zeitraum: letzte 7 Tage (23.09. bis 29.09.) -> 28.09. (Symptome, Gewicht, Wasser)
    await tester.tap(find.text('Letzte 7 Tage'));
    await tester.pumpAndSettle();
    expect(find.text('4 Einträge'), findsOneWidget);
    // Von der Historie aus öffnen und bearbeiten.
    await tester.tap(find.textContaining('Müdigkeit'));
    await tester.pumpAndSettle();
    expect(find.text('Symptom bearbeiten'), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, 'Löschen'));
    await tester.pumpAndSettle();
    expect(app.db.symptoms.all.where((s) => s.name == 'Müdigkeit'), isEmpty);
    expect(find.text('3 Einträge'), findsOneWidget);
  });

  testWidgets('Sprache: Englisch und zurück, Formate folgen der Sprache', (tester) async {
    final app = await launchApp(tester);
    await tester.tap(find.byTooltip('Einstellungen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(app.settings.language, 'en');
    expect(find.text('Settings'), findsOneWidget);
    await tester.tap(find.byTooltip('Back'));
    await tester.pumpAndSettle();
    expect(find.text('Overview'), findsWidgets);
    expect(find.descendant(of: find.byType(NavigationBar), matching: find.text('Nutrition')), findsOneWidget);
    expect(find.textContaining('Sep 29, 2026'), findsWidgets);
    await tester.tap(find.byTooltip('Settings'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Deutsch'));
    await tester.pumpAndSettle();
    expect(find.text('Einstellungen'), findsOneWidget);
    expect(app.settings.language, 'de');
  });

  testWidgets('Tagesdetail führt alle Bereiche eines Tages zusammen', (tester) async {
    final app = await launchApp(tester, seed: seedHistory);
    app.selectDay(Day.parse('2026-09-28'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tagesdetail'));
    await tester.pumpAndSettle();
    expect(find.text('Tagesdetail'), findsWidgets);
    for (final t in ['Ernährung', 'Gewicht', 'Zyklus', 'Symptome']) {
      await scrollTo(tester, find.text(t));
      expect(find.text(t), findsWidgets, reason: t);
    }
    await scrollTo(tester, find.textContaining('Kopfschmerz'));
    expect(find.textContaining('Kopfschmerz'), findsOneWidget);
    await scrollTo(tester, find.text('72,0 kg'));
    expect(find.text('72,0 kg'), findsOneWidget);
    await scrollTo(tester, find.textContaining('250 ml Wasser'));
    expect(find.textContaining('250 ml Wasser'), findsWidgets);
  });
}
