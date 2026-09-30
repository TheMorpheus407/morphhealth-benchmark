import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphhealth/core/core.dart';
import 'package:morphhealth/ui/nutrition.dart';
import 'package:morphhealth/ui/shared.dart';

class _FoodFixtureApi extends FoodApi {
  _FoodFixtureApi()
    : super(baseUrl: 'https://localhost:8788', userAgent: 'MorphHealth/tests');
  final List<String> calls = [];
  @override
  Future<Json> search(String q, {int page = 1}) async {
    calls.add('$q:$page');
    return {
      'page': page,
      'count': 23,
      'pageSize': 20,
      'products': List.generate(page == 1 ? 20 : 3, (i) {
        final index = (page - 1) * 20 + i;
        return validateFood({
          'id': 'food-$index',
          'name': 'Hafer $index',
          'source': 'off',
          'basis': 'g',
          'nutrients': {'energy': 370},
        });
      }),
    };
  }

  @override
  Future<Json?> lookup(String barcode) async {
    calls.add(barcode);
    return null;
  }
}

Future<AppModel> _model(WidgetTester tester, {FoodApi? api}) async {
  late Store store;
  late Directory dir;
  await tester.runAsync(() async {
    final parent = Directory(
      '${Directory.current.path}/.dart_tool/ui-test-data',
    );
    await parent.create(recursive: true);
    dir = await parent.createTemp('nutrition-');
    store = Store(dir, List.generate(32, (i) => i));
    await store.open();
  });
  final model = AppModel(store, api ?? _FoodFixtureApi());
  model.selectDate(DateTime(2026, 9, 17));
  addTearDown(() async {
    model.dispose();
    await tester.runAsync(() async {
      await store.close();
      await dir.delete(recursive: true);
    });
  });
  return model;
}

Widget _host(AppModel model, Widget child, {double textScale = 1}) =>
    MaterialApp(
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      locale: Locale(model.de ? 'de' : 'en'),
      supportedLocales: const [Locale('de'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: const Color(0xff38675a),
      ),
      home: Scaffold(body: child),
    );

Finder _field(String label) => find.byWidgetPredicate(
  (widget) => widget is TextField && widget.decoration?.labelText == label,
);

Future<void> _reveal(
  WidgetTester tester,
  Finder finder, {
  double delta = 320,
}) async {
  await tester.scrollUntilVisible(
    finder,
    delta,
    scrollable: find.byType(Scrollable).first,
    maxScrolls: 100,
  );
  await tester.pumpAndSettle();
}

Future<void> _fill(WidgetTester tester, String label, String value) async {
  final finder = _field(label);
  await _reveal(tester, finder);
  await tester.enterText(finder, value);
  tester.testTextInput.hide();
  await tester.pumpAndSettle();
}

Future<void> _commit(
  WidgetTester tester,
  Finder button,
  bool Function() done,
) async {
  await tester.runAsync(() async {
    await tester.tap(button);
  });
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
  await tester.runAsync(() async {
    final deadline = DateTime.now().add(const Duration(seconds: 5));
    while (!done() && DateTime.now().isBefore(deadline)) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
  });
  await tester.pumpAndSettle();
  expect(done(), isTrue);
}

void main() {
  testWidgets(
    'custom food persists every micronutrient, comma decimals and unknown values',
    (tester) async {
      tester.view.physicalSize = const Size(411, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final model = await _model(tester);
      await tester.pumpWidget(
        _host(
          model,
          Builder(
            builder: (context) => FilledButton(
              onPressed: () => editFood(context, model),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await _fill(tester, 'Name', 'Eigenes Müsli');
      await _fill(tester, 'Portionsgröße (optional)', '40');
      await _fill(tester, 'Energie', '375');
      await _fill(tester, 'Protein', '12,5');
      await _reveal(tester, find.text('Vitamine'));
      await tester.tap(find.text('Vitamine'));
      await tester.pumpAndSettle();
      var index = 1;
      final expected = <String, double>{};
      for (final n in nutrients.where((n) => n.key.startsWith('vitamin'))) {
        await _fill(tester, n.de, '$index,25');
        expected[n.key] = index + .25;
        index++;
      }
      await _reveal(tester, find.text('Mineralstoffe & Spurenelemente'));
      await tester.tap(find.text('Mineralstoffe & Spurenelemente'));
      await tester.pumpAndSettle();
      for (final n in nutrients.where(
        (n) => [
          'calcium',
          'iron',
          'magnesium',
          'potassium',
          'zinc',
          'selenium',
          'iodine',
          'phosphorus',
        ].contains(n.key),
      )) {
        await _fill(tester, n.de, '$index,25');
        expected[n.key] = index + .25;
        index++;
      }
      await _reveal(tester, find.text('Lebensmittel speichern'));
      await _commit(
        tester,
        find.text('Lebensmittel speichern'),
        () => (model.doc['foods'] as List).length == 1,
      );
      final food = (model.doc['foods'] as List).single as Json;
      expect(food['name'], 'Eigenes Müsli');
      expect(food['servingSize'], 40);
      expect(food['nutrients']['protein'], 12.5);
      expect(food['nutrients']['carbs'], isNull);
      for (final e in expected.entries) {
        expect(food['nutrients'][e.key], e.value, reason: e.key);
      }
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'fractional servings use explicit basis and immutable snapshot; entry repeats',
    (tester) async {
      tester.view.physicalSize = const Size(411, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final model = await _model(tester);
      final food = validateFood({
        'id': 'oats',
        'name': 'Haferdrink',
        'source': 'custom',
        'basis': 'ml',
        'servingSize': 200,
        'nutrients': {
          'energy': 50,
          'protein': 2,
          'carbs': 6,
          'fat': 2,
          'vitaminB12': .8,
        },
      });
      await tester.pumpWidget(
        _host(
          model,
          Builder(
            builder: (context) => FilledButton(
              onPressed: () => editMeal(context, model, food: food),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('ml').first);
      await tester.pumpAndSettle();
      expect(
        find.text('g'),
        findsNothing,
        reason: 'No density-free mass/volume conversion',
      );
      await tester.tap(find.text('Portionen').last);
      await tester.pumpAndSettle();
      await _fill(tester, 'Menge', '1,5');
      await _reveal(tester, find.text('Speichern'));
      await _commit(
        tester,
        find.text('Speichern'),
        () => (model.doc['meals'] as List).length == 1,
      );
      expect(nutritionDay(model.doc, '2026-09-17')['totals']['energy'], 150);
      expect(
        nutritionDay(model.doc, '2026-09-17')['totals']['vitaminB12'],
        closeTo(2.4, 1e-9),
      );
      await tester.runAsync(
        () => model.put('foods', {
          ...food,
          'nutrients': {'energy': 100},
        }),
      );
      expect(nutritionDay(model.doc, '2026-09-17')['totals']['energy'], 150);
      await tester.pumpWidget(_host(model, NutritionPage(model: model)));
      await tester.pumpAndSettle();
      await _reveal(tester, find.byTooltip('Eintrag verwalten'));
      await tester.tap(find.byTooltip('Eintrag verwalten'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Erneut erfassen'));
      await tester.pumpAndSettle();
      await _reveal(tester, find.text('Speichern'));
      await _commit(
        tester,
        find.text('Speichern'),
        () => (model.doc['meals'] as List).length == 2,
      );
      expect(nutritionDay(model.doc, '2026-09-17')['totals']['energy'], 300);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'water quick entry and additional caffeine can be corrected and deleted',
    (tester) async {
      tester.view.physicalSize = const Size(411, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final model = await _model(tester);
      await tester.pumpWidget(_host(model, NutritionPage(model: model)));
      await tester.pumpAndSettle();
      await _reveal(tester, find.byTooltip('250 ml Wasser erfassen'));
      await _commit(
        tester,
        find.byTooltip('250 ml Wasser erfassen'),
        () => (model.doc['drinks'] as List).length == 1,
      );
      expect(nutritionDay(model.doc, '2026-09-17')['waterMl'], 250);
      await _reveal(tester, find.text('Erfassen'));
      await tester.tap(find.text('Erfassen'));
      await tester.pumpAndSettle();
      await _fill(tester, 'Menge', '75,5');
      await _reveal(tester, find.text('Speichern'));
      await _commit(
        tester,
        find.text('Speichern'),
        () => (model.doc['drinks'] as List).length == 2,
      );
      expect(nutritionDay(model.doc, '2026-09-17')['caffeineMg'], 75.5);
      await _reveal(tester, find.text('Koffein · 75.5 mg'));
      await tester.tap(find.text('Koffein · 75.5 mg'));
      await tester.pumpAndSettle();
      await _fill(tester, 'Menge', '50');
      await _reveal(tester, find.text('Speichern'));
      await _commit(
        tester,
        find.text('Speichern'),
        () => nutritionDay(model.doc, '2026-09-17')['caffeineMg'] == 50,
      );
      await _reveal(tester, find.text('Koffein · 50 mg'));
      await tester.tap(find.text('Koffein · 50 mg'));
      await tester.pumpAndSettle();
      await _reveal(tester, find.text('Eintrag löschen'));
      await tester.runAsync(() async {
        await tester.tap(find.text('Eintrag löschen'));
      });
      await tester.pumpAndSettle();
      await _commit(
        tester,
        find.text('Löschen'),
        () => (model.doc['drinks'] as List).length == 1,
      );
      expect(nutritionDay(model.doc, '2026-09-17')['caffeineMg'], isNull);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'online consent gates requests, pagination and barcode not-found in English',
    (tester) async {
      tester.view.physicalSize = const Size(411, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final api = _FoodFixtureApi();
      final model = await _model(tester, api: api);
      await tester.runAsync(() => model.settingsPatch({'language': 'en'}));
      await tester.pumpWidget(_host(model, FoodPickerPage(model: model)));
      await tester.tap(find.text('Search'));
      await tester.pumpAndSettle();
      expect(api.calls, isEmpty);
      expect(find.text('Enable online search'), findsNWidgets(2));
      await _commit(
        tester,
        find.widgetWithText(FilledButton, 'Enable online search'),
        () => model.settings['onlineFood'] == true,
      );
      expect(api.calls, isEmpty, reason: 'Opt-in alone sends no query');
      await _fill(tester, 'Name or brand', 'Hafer');
      await tester.tap(find.text('Search Open Food Facts'));
      await tester.pumpAndSettle();
      expect(api.calls, ['Hafer:1']);
      await _reveal(tester, find.text('Load more results'));
      await tester.tap(find.text('Load more results'));
      await tester.pumpAndSettle();
      expect(api.calls, ['Hafer:1', 'Hafer:2']);
      await _reveal(tester, find.text('Barcode'), delta: -600);
      await tester.tap(find.text('Barcode'));
      await tester.pumpAndSettle();
      await _fill(tester, 'Barcode number', '0000000000001');
      await tester.tap(find.text('Look up barcode'));
      await tester.pumpAndSettle();
      expect(api.calls.last, '0000000000001');
      expect(find.text('No results'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'offset timestamps retain entered civil day and time when editing',
    (tester) async {
      tester.view.physicalSize = const Size(411, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final model = await _model(tester);
      const timestamp = '2026-09-26T00:30:00+02:00';
      final food = validateFood({
        'id': 'tea',
        'name': 'Tee',
        'source': 'custom',
        'basis': 'ml',
        'nutrients': {'energy': 0},
      });
      final meal = {
        'id': 'meal-offset',
        'food': food,
        'amount': 200,
        'unit': 'ml',
        'meal': 'snack',
        'at': timestamp,
        'note': '',
      };
      final drink = {
        'id': 'water-offset',
        'kind': 'water',
        'amount': 250,
        'at': timestamp,
        'note': '',
      };
      await tester.runAsync(() async {
        await model.put('meals', meal);
        await model.put('drinks', drink);
      });
      await tester.pumpWidget(
        _host(
          model,
          Builder(
            builder: (context) => Column(
              children: [
                FilledButton(
                  onPressed: () => editMeal(context, model, entry: meal),
                  child: const Text('meal'),
                ),
                FilledButton(
                  onPressed: () => editDrink(context, model, entry: drink),
                  child: const Text('drink'),
                ),
              ],
            ),
          ),
        ),
      );
      await tester.tap(find.text('meal'));
      await tester.pumpAndSettle();
      await _reveal(tester, find.text('26.09.2026 · 00:30'));
      expect(find.text('26.09.2026 · 00:30'), findsOneWidget);
      await _fill(tester, 'Notiz (optional)', 'korrigiert');
      await _reveal(tester, find.text('Speichern'));
      await _commit(
        tester,
        find.text('Speichern'),
        () => (model.doc['meals'] as List).single['note'] == 'korrigiert',
      );
      expect((model.doc['meals'] as List).single['at'], timestamp);
      await tester.tap(find.text('drink'));
      await tester.pumpAndSettle();
      expect(find.text('26.09.2026 · 00:30'), findsOneWidget);
      await _fill(tester, 'Menge', '300');
      await _reveal(tester, find.text('Speichern'));
      await _commit(
        tester,
        find.text('Speichern'),
        () => (model.doc['drinks'] as List).single['amount'] == 300,
      );
      expect((model.doc['drinks'] as List).single['at'], timestamp);
      expect(nutritionDay(model.doc, '2026-09-26')['waterMl'], 300);
      expect(nutritionDay(model.doc, '2026-09-25')['waterMl'], 0);
    },
  );

  testWidgets(
    'nutrition and library remain operable with enlarged text on narrow screen',
    (tester) async {
      tester.view.physicalSize = const Size(320, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final model = await _model(tester);
      final food = validateFood({
        'id': 'scale-food',
        'name': 'Haferflocken',
        'source': 'custom',
        'basis': 'g',
        'servingSize': 50,
        'nutrients': {'energy': 300, 'protein': 13, 'carbs': 60, 'fat': 6},
      });
      await tester.runAsync(() async {
        await model.put('meals', {
          'id': 'scale-meal',
          'food': food,
          'amount': 100,
          'unit': 'g',
          'at': '2026-09-17T12:00:00',
          'meal': 'lunch',
          'note': '',
        });
      });
      await tester.pumpWidget(
        _host(model, NutritionPage(model: model), textScale: 2),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await _reveal(tester, find.byTooltip('250 ml Wasser erfassen'));
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(
        _host(model, FoodPickerPage(model: model), textScale: 2),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(
        _host(
          model,
          Builder(
            builder: (context) => FilledButton(
              onPressed: () => editMeal(context, model, food: food),
              child: const Text('open'),
            ),
          ),
          textScale: 2,
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await _reveal(tester, _field('Menge'));
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'additional caffeine remains explicitly incomplete when food caffeine is unknown',
    (tester) async {
      tester.view.physicalSize = const Size(411, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final model = await _model(tester);
      final food = validateFood({
        'id': 'unknown-caffeine',
        'name': 'Kuchen',
        'source': 'custom',
        'basis': 'g',
        'nutrients': {'energy': 250, 'caffeine': null},
      });
      await tester.runAsync(() async {
        await model.put('meals', {
          'id': 'meal-unknown',
          'food': food,
          'amount': 100,
          'unit': 'g',
          'at': '2026-09-17T12:00:00',
          'meal': 'lunch',
          'note': '',
        });
        await model.put('drinks', {
          'id': 'extra-caffeine',
          'kind': 'caffeine',
          'amount': 70,
          'at': '2026-09-17T12:00:00',
          'note': '',
        });
      });
      final day = nutritionDay(model.doc, '2026-09-17');
      expect(day['caffeineMg'], 70);
      expect(day['knownCounts']['caffeine'], 0);
      expect(day['completeness']['caffeine'], isFalse);
      await tester.pumpWidget(_host(model, NutritionPage(model: model)));
      await tester.pumpAndSettle();
      await _reveal(
        tester,
        find.text(
          'Unvollständig: Nicht alle Lebensmittel enthalten eine Koffeinangabe.',
        ),
      );
      expect(find.text('Erfasstes Koffein'), findsOneWidget);
      await _reveal(tester, find.text('Alle'), delta: -400);
      await tester.tap(find.text('Alle'));
      await tester.pumpAndSettle();
      final caffeine = find.byKey(const ValueKey('nutrient-caffeine'));
      await tester.scrollUntilVisible(
        caffeine,
        300,
        scrollable: find.byType(Scrollable).last,
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(of: caffeine, matching: find.text('70 mg')),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: caffeine,
          matching: find.text('0 von 1 Lebensmitteln bekannt'),
        ),
        findsOneWidget,
      );
      expect(
        find.descendant(
          of: caffeine,
          matching: find.text('Zusätzlich erfasst: 70 mg'),
        ),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
