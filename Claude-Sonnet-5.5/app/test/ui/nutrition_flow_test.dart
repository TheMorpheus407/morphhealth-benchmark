import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphhealth/core/civil.dart';
import 'package:morphhealth/core/models.dart';
import 'package:morphhealth/core/nutrients.dart';

import 'harness.dart';

void main() {
  setUpAll(loadRoboto);
  onlineTests();

  testWidgets('Wasser: Schnellerfassung addiert, Rückgängig nimmt zurück', (tester) async {
    final app = await launchApp(tester);
    await openTab(tester, 'Ernährung');
    await tester.tap(find.widgetWithText(ActionChip, '250 ml'));
    await tester.pumpAndSettle();
    expect(app.core.nutritionDay(Day.parse('2026-09-29')).waterMl, 250);
    expect(find.text('250 ml Wasser erfasst'), findsOneWidget);
    await tester.tap(find.widgetWithText(ActionChip, '500 ml'));
    await tester.pumpAndSettle();
    expect(app.core.nutritionDay(Day.parse('2026-09-29')).waterMl, 750);
    await tester.tap(find.text('Rückgängig'));
    await tester.pumpAndSettle();
    expect(app.core.nutritionDay(Day.parse('2026-09-29')).waterMl, 250);
  });

  testWidgets('Koffein: zusätzlich erfasstes Koffein zählt zur Tagessumme', (tester) async {
    final app = await launchApp(tester);
    await openTab(tester, 'Ernährung');
    await scrollTo(tester, find.text('Koffein'));
    await tester.tap(find.widgetWithText(TextButton, 'Hinzufügen').last);
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Kaffee · 80 mg'));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, 'Speichern'));
    await tester.pumpAndSettle();
    final d = app.core.nutritionDay(Day.parse('2026-09-29'));
    expect(d.caffeineAdditionalMg, 80);
    expect(d.totals.get0(kCaffeine), 80);
    expect(d.caffeineEntries.single.label, 'Kaffee');
  });

  testWidgets('Eigenes Lebensmittel: alle Nährstoffe erfassen, bearbeiten und im Tagebuch nutzen', (tester) async {
    final app = await launchApp(tester);
    await openTab(tester, 'Ernährung');
    await tester.tap(find.text('Lebensmittel hinzufügen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eigene'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Eigenes Lebensmittel anlegen'));
    await tester.pumpAndSettle();

    await enterByLabel(tester, 'Name', 'Testmüsli');
    await enterByLabel(tester, 'Marke (optional)', 'Eigenmarke');
    await enterByLabel(tester, 'Menge', '40');
    // Vitamine und Mineralstoffe liegen in eingeklappten Bereichen.
    await tapScrolled(tester, find.text('Vitamine'));
    await tapScrolled(tester, find.text('Mineralstoffe'));
    // Alle Katalog-Nährstoffe mit eindeutigen Werten befüllen.
    var i = 1;
    final expected = <String, double>{};
    for (final d in nutrientCatalog) {
      final label = '${nutrientName(d.key, 'de')} (${d.unit})';
      if (d.key == 'sodium_mg' || d.key == 'salt_g') continue; // Umrechnung wird separat geprüft
      final v = i.toDouble();
      await enterByLabel(tester, label, '$v');
      expected[d.key] = v;
      i++;
    }
    await enterByLabel(tester, 'Salz (g)', '1,5');
    await tapScrolled(tester, find.widgetWithText(FilledButton, 'Speichern'));

    // Nach dem Speichern öffnet sich der Eintragsbildschirm mit dem neuen Lebensmittel.
    expect(find.text('Testmüsli'), findsWidgets);
    final food = app.db.foods.single;
    expect(food.info.name, 'Testmüsli');
    expect(food.info.serving!.amount, 40);
    for (final e in expected.entries) {
      expect(food.info.nutrients[e.key], e.value, reason: e.key);
    }
    expect(food.info.nutrients['salt_g'], 1.5);
    expect(food.info.nutrients['sodium_mg'], closeTo(600, 1e-9), reason: 'Natrium wird aus Salz berechnet');

    // Menge 50 g, Frühstück, speichern.
    await tester.tap(find.descendant(of: find.byType(SegmentedButton<AmountUnit>), matching: find.text('g')));
    await tester.pumpAndSettle();
    await enterByLabel(tester, 'Menge', '50');
    await tester.tap(find.widgetWithText(FilledButton, 'Hinzufügen'));
    await tester.pumpAndSettle();
    final entries = app.db.entries.on(Day.parse('2026-09-29'));
    expect(entries.length, 1);
    final day = app.core.nutritionDay(Day.parse('2026-09-29'));
    // Jeder Nährstoff des Lebensmittels steckt (halbiert) in der Tagessumme.
    for (final e in expected.entries) {
      expect(day.totals.get0(e.key), closeTo(e.value / 2, 1e-9), reason: e.key);
    }
    // Und ist in der Tagesansicht "Alle Nährwerte" sichtbar.
    await tester.tap(find.text('Alle Nährwerte'));
    await tester.pumpAndSettle();
    expect(find.text('Vitamin B12'), findsOneWidget);
    await scrollTo(tester, find.text('Phosphor'));
    expect(find.text('Phosphor'), findsOneWidget);
  });
}

/// Öffnet die Lebensmittelauswahl aus dem Ernährungstagebuch.
Future<void> openPicker(WidgetTester tester) async {
  await openTab(tester, 'Ernährung');
  await tester.tap(find.text('Lebensmittel hinzufügen'));
  await tester.pumpAndSettle();
}

Future<void> submitSearch(WidgetTester tester, String text) async {
  await tester.enterText(find.byType(TextField).first, text);
  await tester.testTextInput.receiveAction(TextInputAction.search);
  await tester.pumpAndSettle();
}

void onlineTests() {
  testWidgets('Online-Suche: Treffer, Produktdetails, Eintrag mit Portion', (tester) async {
    final food = defaultFoodService();
    final app = await launchApp(tester, food: food);
    await openPicker(tester);
    await submitSearch(tester, 'haferflocken');
    expect(find.text('548 Treffer'), findsOneWidget);
    // Anfrage entspricht dem Vertrag.
    final search = food.requests.firstWhere((u) => u.path == '/cgi/search.pl');
    expect(search.queryParameters['search_terms'], 'haferflocken');
    expect(search.queryParameters['page'], '1');
    expect(search.queryParameters['page_size'], '20');
    expect(search.queryParameters['json'], '1');
    // Ein Treffer öffnet die Details (Abruf über den Barcode) und den Eintragsbildschirm.
    await tester.tap(find.text('Vollkorn-Haferflocken').first);
    await tester.pumpAndSettle();
    expect(food.requests.any((u) => u.path == '/api/v3.6/product/4000540000108.json'), isTrue);
    expect(find.text('Eintrag hinzufügen'), findsOneWidget);
    expect(find.textContaining('361 kcal je 100 g'), findsOneWidget);
    // Standard: eine Portion (40 g) -> 144,4 kcal.
    expect(find.textContaining('144 kcal'), findsWidgets);
    await tester.tap(find.widgetWithText(FilledButton, 'Hinzufügen'));
    await tester.pumpAndSettle();
    final day = app.core.nutritionDay(Day.parse('2026-09-29'));
    expect(day.entries.length, 1);
    expect(day.entries.single.food.barcode, '4000540000108');
    expect(day.totals.get0(kEnergy), closeTo(144.4, 1e-9));
    expect(day.totals.get0(kProtein), closeTo(5.6, 1e-9));
    // Das Produkt liegt jetzt in der Bibliothek (offline wieder verwendbar).
    expect(app.db.foods.single.info.barcode, '4000540000108');
  });

  testWidgets('Barcode: gefunden, nicht gefunden, ungültig und offline', (tester) async {
    final food = defaultFoodService();
    await launchApp(tester, food: food);
    await openPicker(tester);
    await tester.tap(find.text('Barcode').first);
    await tester.pumpAndSettle();
    await submitSearch(tester, '4008400402222');
    expect(find.text('Nutella'), findsOneWidget);
    expect(find.textContaining('539 kcal je 100 g'), findsOneWidget);
    await submitSearch(tester, '0000000000000');
    expect(find.text('Zu dieser Nummer wurde kein Produkt gefunden.'), findsOneWidget);
    await submitSearch(tester, '123');
    expect(find.text('Eine Barcode-Nummer hat 8 bis 14 Ziffern.'), findsOneWidget);
    food.offline = true;
    await submitSearch(tester, '4008400402222');
    expect(find.textContaining('Keine Verbindung zum Lebensmitteldienst'), findsOneWidget);
    // Erneut versuchen, sobald das Netz wieder da ist.
    food.offline = false;
    await tester.tap(find.text('Erneut versuchen'));
    await tester.pumpAndSettle();
    expect(find.text('Nutella'), findsOneWidget);
  });

  testWidgets('Online-Suche ausgeschaltet: keine Anfrage, klarer Hinweis', (tester) async {
    final food = defaultFoodService();
    final app = await launchApp(tester, food: food);
    await app.db.saveSettings(app.settings.copyWith(onlineFood: false));
    await openPicker(tester);
    expect(find.textContaining('Online-Suche ist ausgeschaltet'), findsOneWidget);
    await submitSearch(tester, 'milch');
    expect(food.requests, isEmpty);
  });
}
