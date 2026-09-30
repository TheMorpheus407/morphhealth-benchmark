import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphhealth/core/civil.dart';
import 'package:morphhealth/core/core.dart';
import 'package:morphhealth/core/models.dart';
import 'package:morphhealth/core/nutrients.dart';

import 'harness.dart';

Future<void> seedFood(MorphCore core) async {
  final f = await core.db.saveFood(
    Food(
      id: 'f1',
      info: FoodInfo(
        name: 'Haferflocken',
        serving: const Serving(40, '1 Portion'),
        nutrients: Nutrients.of({'energy_kcal': 372, 'protein_g': 13.5, 'carbohydrates_g': 58.7, 'fat_g': 7}),
      ),
      favorite: true,
    ),
  );
  await core.db.saveEntry(
    FoodEntry(
      id: 'e1',
      foodId: f.id,
      food: f.info,
      amount: 60,
      unit: AmountUnit.g,
      meal: Meal.breakfast,
      at: LocalDateTime.parse('2026-09-29T08:00'),
    ),
  );
}

void main() {
  setUpAll(loadRoboto);

  testWidgets('Eintrag bearbeiten: Menge und Mahlzeit ändern', (tester) async {
    final app = await launchApp(tester, seed: seedFood);
    await openTab(tester, 'Ernährung');
    expect(find.text('Haferflocken'), findsOneWidget);
    await tester.tap(find.text('Haferflocken'));
    await tester.pumpAndSettle();
    expect(find.text('Eintrag bearbeiten'), findsOneWidget);
    await enterByLabel(tester, 'Menge', '100');
    await tester.tap(find.widgetWithText(ChoiceChip, 'Abendessen'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Speichern'));
    await tester.pumpAndSettle();
    final e = app.db.entries.byId['e1']!;
    expect(e.amount, 100);
    expect(e.meal, Meal.dinner);
    expect(app.core.nutritionDay(Day.parse('2026-09-29')).totals.get0(kEnergy), closeTo(372, 1e-9));
  });

  testWidgets('Eintrag löschen mit Rückgängig', (tester) async {
    final app = await launchApp(tester, seed: seedFood);
    await openTab(tester, 'Ernährung');
    await tester.tap(find.byTooltip('Mehr').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Löschen'));
    await tester.pumpAndSettle();
    expect(app.db.entries.length, 0);
    await tester.tap(find.text('Rückgängig'));
    await tester.pumpAndSettle();
    expect(app.db.entries.length, 1);
    expect(app.db.entries.byId['e1']!.amount, 60);
  });

  testWidgets('Erneut erfassen: kopiert den Eintrag auf heute, Original bleibt', (tester) async {
    final app = await launchApp(
      tester,
      seed: (core) async {
        await seedFood(core);
        // Original von gestern
        final e = core.db.entries.byId['e1']!;
        await core.db.saveEntry(e.copyWith(at: LocalDateTime.parse('2026-09-28T08:00')));
      },
    );
    app.selectDay(Day.parse('2026-09-28'));
    await openTab(tester, 'Ernährung');
    await tester.tap(find.byTooltip('Mehr').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Erneut erfassen'));
    await tester.pumpAndSettle();
    expect(app.db.entries.length, 2);
    final today = app.db.entries.on(Day.parse('2026-09-29'));
    expect(today.length, 1);
    expect(today.single.amount, 60);
    expect(today.single.food.name, 'Haferflocken');
    expect(app.db.entries.on(Day.parse('2026-09-28')).length, 1);
  });

  testWidgets('Zuletzt und Favoriten in der Auswahl: schneller Weg zu bekannten Lebensmitteln', (tester) async {
    final app = await launchApp(tester, seed: seedFood);
    await openTab(tester, 'Ernährung');
    await tester.tap(find.text('Lebensmittel hinzufügen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Zuletzt'));
    await tester.pumpAndSettle();
    expect(find.textContaining('60 g'), findsOneWidget);
    await tester.tap(find.text('Favoriten'));
    await tester.pumpAndSettle();
    expect(find.text('Haferflocken'), findsOneWidget);
    // Antippen öffnet den Eintrag mit dem Lebensmittel aus der Bibliothek.
    await tester.tap(find.text('Haferflocken'));
    await tester.pumpAndSettle();
    expect(find.text('Eintrag hinzufügen'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Hinzufügen'));
    await tester.pumpAndSettle();
    expect(app.db.entries.length, 2);
    expect(app.db.entries.all.where((e) => e.foodId == 'f1').length, 2);
  });

  testWidgets('Eigenes Lebensmittel bearbeiten: Änderung gilt für bestehende Einträge', (tester) async {
    final app = await launchApp(tester, seed: seedFood);
    await openTab(tester, 'Ernährung');
    await tester.tap(find.text('Lebensmittel hinzufügen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eigene'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Bearbeiten'));
    await tester.pumpAndSettle();
    expect(find.text('Lebensmittel bearbeiten'), findsOneWidget);
    await enterByLabel(tester, 'Energie (kcal)', '400');
    await tapScrolled(tester, find.widgetWithText(FilledButton, 'Speichern'));
    expect(app.db.food('f1')!.info.nutrients['energy_kcal'], 400);
    expect(app.db.entries.byId['e1']!.nutrients['energy_kcal'], closeTo(240, 1e-9)); // 60 g
  });

  testWidgets('Tagesziele: freiwillig, leer bedeutet kein Ziel', (tester) async {
    final app = await launchApp(tester);
    await tester.tap(find.byTooltip('Einstellungen'));
    await tester.pumpAndSettle();
    await tapScrolled(tester, find.widgetWithText(ListTile, 'Tagesziele'));
    await tester.pumpAndSettle();
    await enterByLabel(tester, 'Wasser', '2500');
    await enterByLabel(tester, 'Kalorien', '1900');
    await tester.tap(find.widgetWithText(FilledButton, 'Speichern'));
    await tester.pumpAndSettle();
    expect(app.db.goals.waterMl, 2500);
    expect(app.db.goals.energyKcal, 1900);
    expect(app.db.goals.proteinG, isNull);
    // Ziel wieder entfernen: Feld leeren.
    await tapScrolled(tester, find.widgetWithText(ListTile, 'Tagesziele'));
    await tester.pumpAndSettle();
    await enterByLabel(tester, 'Kalorien', '');
    await tester.tap(find.widgetWithText(FilledButton, 'Speichern'));
    await tester.pumpAndSettle();
    expect(app.db.goals.energyKcal, isNull);
    expect(app.db.goals.waterMl, 2500);
  });
}
