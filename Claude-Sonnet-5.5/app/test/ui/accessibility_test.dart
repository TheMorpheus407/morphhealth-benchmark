import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphhealth/core/civil.dart';
import 'package:morphhealth/core/core.dart';
import 'package:morphhealth/core/models.dart';
import 'package:morphhealth/core/nutrients.dart';

import 'harness.dart';

Future<void> seedAll(MorphCore core) async {
  final db = core.db;
  await db.saveGoals(const Goals(waterMl: 2000, energyKcal: 2200, proteinG: 110, carbohydratesG: 250, fatG: 70));
  final f = await db.saveFood(
    Food(
      id: 'f1',
      info: FoodInfo(
        name: 'Haferflocken mit sehr langem Namen zur Prüfung des Umbruchs bei großer Schrift',
        brand: 'Beispielmarke',
        serving: const Serving(40, '1 Portion'),
        nutrients: Nutrients.of({
          'energy_kcal': 372,
          'protein_g': 13.5,
          'carbohydrates_g': 58.7,
          'fat_g': 7,
          'iron_mg': 4.6,
        }),
      ),
      favorite: true,
    ),
  );
  for (var i = 0; i < 10; i++) {
    final day = Day.parse('2026-09-29').addDays(-i);
    await db.saveEntry(
      FoodEntry(
        id: 'e$i',
        foodId: f.id,
        food: f.info,
        amount: 60 + i * 5.0,
        unit: AmountUnit.g,
        meal: Meal.values[i % 4],
        at: LocalDateTime.parse('${day}T08:00'),
      ),
    );
    await db.saveWater(WaterEntry(id: 'w$i', at: LocalDateTime.parse('${day}T09:00'), ml: 250));
    await db.saveWeight(WeightEntry(id: 'g$i', at: LocalDateTime.parse('${day}T07:00'), kg: 72 + i * 0.1));
    await db.saveSymptom(
      SymptomEntry(id: 's$i', name: 'Kopfschmerz', intensity: i % 11, at: LocalDateTime.parse('${day}T18:00')),
    );
  }
  for (final d in ['2026-06-08', '2026-07-06', '2026-08-03', '2026-08-31']) {
    final s = Day.parse(d);
    await db.savePeriod(PeriodRecord(id: 'p$d', start: s, end: s.addDays(4), flow: FlowLevel.medium, notes: 'Notiz'));
  }
}

const tabs = ['Übersicht', 'Ernährung', 'Zyklus', 'Gewicht', 'Symptome'];

void main() {
  setUpAll(loadRoboto);

  for (final dark in [false, true]) {
    testWidgets('Barrierefreiheit (${dark ? 'dunkel' : 'hell'}): Tippflächen, Beschriftungen, Kontrast', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final app = await launchApp(tester, seed: seedAll);
      await app.db.saveSettings(app.settings.copyWith(theme: dark ? 'dark' : 'light'));
      await tester.pumpAndSettle();
      for (final t in tabs) {
        if (t != 'Übersicht') await openTab(tester, t);
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline), reason: 'Tippfläche $t');
        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline), reason: 'Beschriftung $t');
        await expectLater(tester, meetsGuideline(textContrastGuideline), reason: 'Kontrast $t');
      }
      handle.dispose();
    });
  }

  testWidgets('Große Schrift (200 %): keine Überläufe auf den Hauptbildschirmen', (tester) async {
    final app = await launchApp(tester, seed: seedAll, textScale: 2.0);
    for (final t in tabs) {
      if (t != 'Übersicht') await openTab(tester, t);
      expect(tester.takeException(), isNull, reason: t);
    }
    // Weitere Bildschirme: Tagebuch mit Einträgen, Historie, Einstellungen, Eintrag bearbeiten.
    await openTab(tester, 'Ernährung');
    expect(tester.takeException(), isNull);
    await tester.tap(find.byTooltip('Historie'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'Historie');
    await tester.tap(find.byTooltip('Zurück'));
    await tester.pumpAndSettle();
    await tapScrolled(
      tester,
      find.text('Haferflocken mit sehr langem Namen zur Prüfung des Umbruchs bei großer Schrift'),
    );
    expect(tester.takeException(), isNull, reason: 'Eintrag bearbeiten');
    await tester.tap(find.byTooltip('Zurück'));
    await tester.pumpAndSettle();
    await openTab(tester, 'Übersicht');
    await tester.tap(find.byTooltip('Einstellungen'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull, reason: 'Einstellungen');
    expect(app.settings.language, 'de');
  });

  testWidgets('Große Schrift (200 %): Blätter und Nebenbildschirme laufen nicht über', (tester) async {
    await launchApp(tester, seed: seedAll, textScale: 2.0);
    Future<void> visit(String reason, Future<void> Function() open, Future<void> Function() close) async {
      await open();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: reason);
      await close();
      await tester.pumpAndSettle();
    }

    Future<void> back() async => tester.tap(find.byTooltip('Zurück'));
    Future<void> dismissSheet() => popTop(tester);

    await openTab(tester, 'Gewicht');
    await visit('Gewicht erfassen', () => tester.tap(find.text('Gewicht erfassen')), dismissSheet);
    await openTab(tester, 'Symptome');
    await visit('Symptom erfassen', () => tester.tap(find.text('Symptom erfassen')), dismissSheet);
    await openTab(tester, 'Zyklus');
    await visit('Periode erfassen', () => tester.tap(find.text('Periode erfassen')), dismissSheet);
    await visit('Erklärung', () => tester.tap(find.text('Wie kommt die Einschätzung zustande?')), back);
    await openTab(tester, 'Ernährung');
    await visit('Eigene Menge Wasser', () => tapScrolled(tester, find.text('Andere Menge')), dismissSheet);
    await visit('Alle Nährwerte', () => tapScrolled(tester, find.text('Alle Nährwerte')), back);
    await visit('Lebensmittelauswahl', () => tapScrolled(tester, find.text('Lebensmittel hinzufügen')), back);
    await openTab(tester, 'Übersicht');
    await visit('Bereiche anpassen', () => tester.tap(find.byTooltip('Bereiche anpassen')), dismissSheet);
    await visit('Tagesdetail', () => tester.tap(find.text('Tagesdetail')), back);
    await tester.tap(find.byTooltip('Einstellungen'));
    await tester.pumpAndSettle();
    await visit(
      'Daten und Sicherung',
      () => tapScrolled(tester, find.widgetWithText(ListTile, 'Daten und Sicherung')),
      back,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Englisch: alle Hauptbildschirme ohne Überläufe und ohne deutsche Reste in der Navigation', (
    tester,
  ) async {
    final app = await launchApp(tester, seed: seedAll);
    await app.db.saveSettings(app.settings.copyWith(language: 'en'));
    await tester.pumpAndSettle();
    for (final t in ['Overview', 'Nutrition', 'Cycle', 'Weight', 'Symptoms']) {
      await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text(t)));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: t);
    }
    expect(find.text('Übersicht'), findsNothing);
  });
}
