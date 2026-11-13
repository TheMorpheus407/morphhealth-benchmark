import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphhealth/ui/nutrition/add_food_screen.dart';
import 'package:morphhealth/ui/nutrition/day_nutrients_screen.dart';
import 'package:morphhealth/ui/nutrition/food_form_screen.dart';
import 'package:morphhealth/ui/nutrition/intake_screen.dart';
import 'package:morphhealth_core/morphhealth_core.dart';

import 'support.dart';

/// The text field whose decoration carries [label].
Finder field(String label) => find.widgetWithText(TextField, label);

Future<void> enter(WidgetTester tester, String label, String text) async {
  await reveal(tester, field(label));
  await tester.enterText(field(label), text);
  await tester.pump();
}

/// Taps the save action in the app bar of a form.
Future<void> saveForm(WidgetTester tester) async {
  await tester.tap(find.widgetWithText(TextButton, 'Speichern').first);
  await tester.pumpAndSettle();
}

void main() {
  final today = testNow.day;

  testWidgets('own food with micronutrients: create, log, correct, delete', (
    tester,
  ) async {
    final app = await pumpApp(tester);
    await openTab(tester, 'Ernährung');
    await tapText(tester, 'Lebensmittel erfassen');
    expect(find.byType(AddFoodScreen), findsOneWidget);
    await tapText(tester, 'Eigenes Lebensmittel anlegen');
    expect(find.byType(FoodFormScreen), findsOneWidget);

    await enter(tester, 'Name', 'Linsensalat');
    await enter(tester, 'Portionsgröße (optional)', '250');
    await enter(tester, 'Kalorien', '120');
    await enter(tester, 'Eiweiß', '7,5');
    await enter(tester, 'Kohlenhydrate', '14');
    await enter(tester, 'Fett', '3.2');
    // Micronutrients live in expandable groups.
    await tapText(tester, 'Vitamine');
    await enter(tester, 'Vitamin C', '9');
    await enter(tester, 'Vitamin B9 (Folat)', '60');
    await tapText(tester, 'Mineralstoffe');
    await enter(tester, 'Eisen', '2,1');
    await enter(tester, 'Jod', '1');
    await saveForm(tester);

    // The entry form follows at once, preset to one portion.
    expect(find.byType(IntakeScreen), findsOneWidget);
    final food = app.data.foods.single;
    expect(food.name, 'Linsensalat');
    expect(food.servingSize, 250);
    expect(food.nutrients[Nutrients.protein], 7.5);
    expect(food.nutrients[Nutrients.fat], 3.2);
    expect(food.nutrients[Nutrients.vitaminC], 9);
    expect(food.nutrients[Nutrients.vitaminB9], 60);
    expect(food.nutrients[Nutrients.iron], 2.1);
    expect(food.nutrients[Nutrients.iodine], 1);
    expect(food.nutrients[Nutrients.calcium], isNull);

    expect(find.text('300 kcal'), findsOneWidget); // 250 g × 120 kcal
    await enter(tester, 'Menge', '2');
    expect(find.text('600 kcal'), findsOneWidget);
    await tapText(tester, 'Abendessen');
    await saveForm(tester);

    // Back in the diary.
    expect(find.byType(AddFoodScreen), findsNothing);
    final entry = app.data.intakeOn(today).single;
    expect(
      (entry.amount, entry.unit, entry.portionSize, entry.meal),
      (2.0, AmountUnit.portion, 250.0, Meal.dinner),
    );
    expect(find.text('Linsensalat'), findsOneWidget);
    expect(find.textContaining('2 Portionen (500 g)'), findsOneWidget);

    // Correct the entry: grams instead of portions.
    await tapText(tester, 'Linsensalat');
    await tester.tap(find.text('g').first);
    await tester.pumpAndSettle();
    await enter(tester, 'Menge', '150');
    await saveForm(tester);
    expect(app.data.intakeOn(today).single.unit, AmountUnit.g);
    expect(app.controller.nutritionDay(today).energyKcal, 180);

    // Delete it from the menu and bring it back.
    await tapTooltip(tester, 'Weitere Aktionen');
    await tapText(tester, 'Löschen');
    expect(app.data.intakeCount, 0);
    await tapText(tester, 'Rückgängig');
    expect(app.data.intakeOn(today).single.amount, 150);
  });

  testWidgets('a logged entry can be logged again', (tester) async {
    final app = await pumpApp(tester, data: exampleData());
    await openTab(tester, 'Ernährung');
    // The example has entries yesterday; go there.
    await tapTooltip(tester, 'Vorheriger Tag');
    expect(find.text('Haferflocken'), findsOneWidget);
    await tapTooltip(tester, 'Weitere Aktionen', index: 0);
    await tapText(tester, 'Erneut erfassen');
    expect(find.text('Haferflocken erneut erfasst'), findsOneWidget);

    final repeated = app.data
        .intakeOn(today)
        .where((e) => e.foodId == 'food-haferflocken')
        .toList();
    expect(repeated, hasLength(2));
    expect(repeated.last.amount, 60);
    expect(repeated.last.unit, AmountUnit.g);
    expect(repeated.last.meal, Meal.breakfast);

    // And once more from the list of recent foods.
    await tapTooltip(tester, 'Nächster Tag');
    await tapText(tester, 'Lebensmittel erfassen');
    await tester.tap(
      find.byTooltip('Apfel, 1 Portion (150 g), erneut erfassen'),
    );
    await tester.pumpAndSettle();
    expect(
      app.data.intakeOn(today).where((e) => e.foodId == 'food-apfel'),
      hasLength(1),
    );
  });

  testWidgets('online search asks for consent, then finds, pages and keeps', (
    tester,
  ) async {
    final app = await pumpApp(tester);
    await openTab(tester, 'Ernährung');
    await tapText(tester, 'Lebensmittel erfassen');
    await tester.enterText(find.byType(TextField).first, 'testprodukt');
    await tester.pump();
    expect(app.food.requests, isEmpty, reason: 'typing sends nothing');

    await tapText(tester, '„testprodukt“ in Open Food Facts suchen');
    expect(find.text('Online-Suche in Open Food Facts'), findsOneWidget);
    expect(app.food.requests, isEmpty, reason: 'nothing before consent');
    await tapText(tester, 'Online-Suche einschalten');
    expect(app.controller.settings.onlineFoodSearch, OnlineFoodSearch.enabled);

    expect(app.food.requests.single.path, '/cgi/search.pl');
    expect(
      app.food.requests.single.queryParameters['search_terms'],
      'testprodukt',
    );
    expect(find.text('25 Treffer'), findsOneWidget);
    expect(find.text('Testprodukt 1'), findsOneWidget);

    await tapText(tester, 'Weitere Treffer laden');
    expect(app.food.requests.last.queryParameters['page'], '2');
    await reveal(tester, find.text('Testprodukt 25'));
    expect(find.text('Weitere Treffer laden'), findsNothing);

    // Opening a result fetches the full product and leads to the form.
    await tapText(tester, 'Testprodukt 25');
    expect(app.food.requests.last.path, '/api/v3.6/product/4000000000125.json');
    expect(find.byType(IntakeScreen), findsOneWidget);
    await enter(tester, 'Menge', '200');
    await saveForm(tester);

    final food = app.data.foods.single;
    expect(food.source, FoodSource.openFoodFacts);
    expect(food.barcode, '4000000000125');
    expect(app.controller.nutritionDay(today).energyKcal, 250);

    // The kept product is found again without a request.
    final before = app.food.requests.length;
    await tapText(tester, 'Lebensmittel erfassen');
    await tester.enterText(find.byType(TextField).first, 'testprodukt 25');
    await tester.pump();
    expect(find.text('Meine Lebensmittel'), findsOneWidget);
    await tester.tap(find.text('Testprodukt 25').first);
    await tester.pumpAndSettle();
    expect(find.byType(IntakeScreen), findsOneWidget);
    expect(app.food.requests.length, before);
  });

  testWidgets('declining the online search sends nothing', (tester) async {
    final app = await pumpApp(tester);
    await openTab(tester, 'Ernährung');
    await tapText(tester, 'Lebensmittel erfassen');
    await tester.enterText(find.byType(TextField).first, 'testprodukt');
    await tester.pump();
    await tapText(tester, '„testprodukt“ in Open Food Facts suchen');
    await tapText(tester, 'Nicht jetzt');
    expect(app.food.requests, isEmpty);
    expect(app.controller.settings.onlineFoodSearch, OnlineFoodSearch.disabled);
    expect(
      find.textContaining('Die Online-Suche ist ausgeschaltet'),
      findsOneWidget,
    );
  });

  testWidgets('barcode: found product, unknown code, own food from code', (
    tester,
  ) async {
    final app = await pumpApp(
      tester,
      settings: (s) => s.copyWith(onlineFoodSearch: OnlineFoodSearch.enabled),
    );
    await openTab(tester, 'Ernährung');
    await tapText(tester, 'Lebensmittel erfassen');

    // Invalid input is explained in the dialog.
    await tapTooltip(tester, 'Barcode eingeben');
    await tester.enterText(field('Barcode'), '12345');
    await tapText(tester, 'Nachschlagen');
    expect(
      find.text('Ein Barcode besteht aus 7 bis 14 Ziffern.'),
      findsOneWidget,
    );
    expect(app.food.requests, isEmpty);

    // A known product.
    await tester.enterText(field('Barcode'), '4000000000099');
    await tapText(tester, 'Nachschlagen');
    expect(
      app.food.requests.single.path,
      '/api/v3.6/product/4000000000099.json',
    );
    expect(find.byType(IntakeScreen), findsOneWidget);
    expect(find.text('Testmüsli'), findsOneWidget);
    // One portion of 40 g: 152 kcal; vitamin C is an estimate.
    expect(find.text('152 kcal'), findsOneWidget);
    await tapText(tester, 'Alle Nährwerte');
    await reveal(tester, find.text('≈ 12 mg'));
    await saveForm(tester);
    expect(app.data.foods.single.estimated, contains('vitamin_c_mg'));

    // An unknown code offers to create an own food with it.
    await tapText(tester, 'Lebensmittel erfassen');
    await tapTooltip(tester, 'Barcode eingeben');
    await tester.enterText(field('Barcode'), '4000000000013');
    await tapText(tester, 'Nachschlagen');
    expect(find.textContaining('kein Lebensmittel hinterlegt'), findsOneWidget);
    await tapText(tester, 'Als eigenes Lebensmittel anlegen');
    expect(find.byType(FoodFormScreen), findsOneWidget);
    await enter(tester, 'Name', 'Hausmarke');
    await saveForm(tester);
    expect(app.data.foodByBarcode('4000000000013')!.name, 'Hausmarke');
  });

  testWidgets('a failing food service is explained and can be retried', (
    tester,
  ) async {
    final app = await pumpApp(
      tester,
      settings: (s) => s.copyWith(onlineFoodSearch: OnlineFoodSearch.enabled),
    );
    app.food.failure = const FoodApiException('network', 'down');
    await openTab(tester, 'Ernährung');
    await tapText(tester, 'Lebensmittel erfassen');
    await tester.enterText(find.byType(TextField).first, 'testprodukt');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(
      find.textContaining('Open Food Facts ist nicht erreichbar'),
      findsOneWidget,
    );

    app.food.failure = null;
    await tapText(tester, 'Erneut versuchen');
    expect(find.text('25 Treffer'), findsOneWidget);
  });

  testWidgets('water and caffeine: one tap, undo, own amount', (tester) async {
    final app = await pumpApp(tester);
    await tapChip(tester, '250 ml');
    await tapChip(tester, '250 ml');
    expect(app.controller.nutritionDay(today).waterMl, 500);
    expect(find.text('250 ml Wasser erfasst'), findsOneWidget);
    await tapText(tester, 'Rückgängig');
    expect(app.controller.nutritionDay(today).waterMl, 250);

    await openTab(tester, 'Ernährung');
    await tapChip(tester, 'Espresso 60 mg');
    await tapChip(tester, 'Andere Menge', index: 1);
    await tester.enterText(field('Menge in mg'), '200');
    await tester.enterText(field('Bezeichnung (optional)'), 'Tablette');
    await tapText(tester, 'Speichern');
    final day = app.controller.nutritionDay(today);
    expect(day.caffeineAdditionalMg, 260);
    expect(day.caffeine.map((c) => c.label), ['Espresso', 'Tablette']);

    // Entries can be corrected and deleted from the list.
    await tapText(tester, 'Einträge anzeigen (3)');
    await tapText(tester, 'Tablette, 200 mg');
    await tester.enterText(field('Menge in mg'), '100');
    await tapText(tester, 'Speichern');
    expect(app.controller.nutritionDay(today).caffeineAdditionalMg, 160);
    await tapText(tester, 'Wasser, 250 ml');
    await tapText(tester, 'Löschen');
    expect(app.data.waterCount, 0);
  });

  testWidgets('goals are optional and show progress', (tester) async {
    final app = await pumpApp(tester, data: exampleData());
    await openTab(tester, 'Ernährung');
    await tapTooltip(tester, 'Tagesziele');
    expect(find.widgetWithText(TextField, 'Kalorien in kcal'), findsOneWidget);
    await tester.enterText(field('Kalorien in kcal'), '1800');
    await tester.enterText(field('Eiweiß in g'), '');
    await tapText(tester, 'Speichern', index: 1);
    expect(app.controller.goals.energyKcal, 1800);
    expect(app.controller.goals.proteinG, isNull);
    expect(app.controller.goals.waterMl, 2000);
    expect(find.text('/ 1.800 kcal'), findsOneWidget);
  });

  testWidgets('the day view lists all 31 nutrients with their coverage', (
    tester,
  ) async {
    await pumpApp(tester, data: exampleData());
    await openTab(tester, 'Ernährung');
    await tapTooltip(tester, 'Vorheriger Tag');
    await tapText(tester, 'Alle Nährwerte');
    expect(find.byType(DayNutrientsScreen), findsOneWidget);
    for (final n in Nutrients.all) {
      await reveal(tester, find.text(n.labelDe).last);
    }
    // Vitamin C is stated by two of the four entries of that day.
    await reveal(tester, find.text('Angabe in 2 von 4 Einträgen'));
    await reveal(tester, find.textContaining('enthält Schätzwerte'));
  });
}
