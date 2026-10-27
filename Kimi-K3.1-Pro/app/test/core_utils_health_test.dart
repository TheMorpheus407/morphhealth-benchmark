import 'package:flutter_test/flutter_test.dart';
import 'package:morphhealth/core/health.dart';
import 'package:morphhealth/core/nutrition.dart';
import 'package:morphhealth/core/utils.dart';

import 'core_fixtures.dart';

void main() {
  group('utils', () {
    test('newId erzeugt eindeutige 32-stellige hexadezimale IDs', () {
      final ids = List.generate(200, (_) => newId());
      expect(ids.toSet(), hasLength(ids.length));
      for (final id in ids) expect(id, matches(RegExp(r'^[0-9a-f]{32}$')));
    });

    test('Datums- und Zeitfunktionen behalten Kalender- und UTC-Semantik', () {
      expect(dateKey(DateTime(2026, 2, 3)), '2026-02-03');
      expect(dateKey(addDays(DateTime(2024, 2, 28), 1)), '2024-02-29');
      expect(dateKey(addDays(DateTime(2026, 1, 31), 1)), '2026-02-01');
      expect(
        formatInstant(DateTime.utc(2026, 1, 1, 1)),
        '2026-01-01T01:00:00.000Z',
      );
      expect(
        parseInstant('2026-01-01T01:00:00+01:00', 'at'),
        DateTime.utc(2026, 1, 1),
      );
      expect(instantDateKey(DateTime(2026, 1, 1)), '2026-01-01');
    });

    test('parseDate akzeptiert echte Kalenderdaten und weist andere ab', () {
      expect(parseDate('2024-02-29'), DateTime(2024, 2, 29));
      for (final value in [
        '2026-2-01',
        '2026-02-30',
        '2023-02-29',
        '2026-13-01',
        '2026-01-01T00:00:00Z',
        '',
      ]) {
        expect(
          () => parseDate(value, 'start'),
          throwsFormatException,
          reason: value,
        );
      }
      for (final value in [null, 123, '2026-01-01']) {
        if (value is String) continue;
        expect(() => parseInstant(value, 'at'), throwsFormatException);
      }
      expect(
        () => parseInstant('2026-01-01T00:00:00', 'at'),
        throwsFormatException,
      );
      expect(() => parseInstant('not-a-date', 'at'), throwsFormatException);
    });

    test('JSON-Hilfen validieren Typen, Text und Container', () {
      expect(jsonMap(const {'a': 1}, 'value'), {'a': 1});
      expect(jsonList(const [1, 2], 'value'), [1, 2]);
      expect(() => jsonMap([], 'value'), throwsFormatException);
      expect(() => jsonList({}, 'value'), throwsFormatException);
      expect(() => jsonMap({1: 'x'}, 'value'), throwsFormatException);
      expect(jsonString(' x ', 'value'), ' x ');
      expect(jsonString('', 'value', allowEmpty: true), '');
      expect(jsonOptionalString(null, 'value'), isNull);
      expect(jsonOptionalString('', 'value'), '');
      for (final value in ['', '   ', null, 3]) {
        expect(() => jsonString(value, 'value'), throwsFormatException);
      }
      expect(() => jsonOptionalString(3, 'value'), throwsFormatException);
      expect(jsonBool(false, 'value'), isFalse);
      expect(() => jsonBool(0, 'value'), throwsFormatException);
    });

    test('JSON-Zahlen validieren Endlichkeit, Ganzzahlen und Grenzen', () {
      expect(jsonDouble(2, 'value'), 2.0);
      expect(jsonDouble(2.5, 'value', min: 2, max: 3), 2.5);
      expect(jsonOptionalDouble(null, 'value'), isNull);
      expect(jsonInt(2, 'value', min: 2, max: 2), 2);
      expect(jsonNumberMap(const {'a': 1, 'b': 0.5}, 'value'), {
        'a': 1.0,
        'b': 0.5,
      });
      for (final value in [double.nan, double.infinity, '1', null, true]) {
        expect(() => jsonDouble(value, 'value'), throwsFormatException);
      }
      expect(() => jsonDouble(-1, 'value', min: 0), throwsFormatException);
      expect(() => jsonDouble(4, 'value', max: 3), throwsFormatException);
      expect(
        () => jsonOptionalDouble(-1, 'value', min: 0),
        throwsFormatException,
      );
      for (final value in [2.0, true, '2', null, -1, 4]) {
        expect(
          () => jsonInt(value, 'value', min: 0, max: 3),
          throwsFormatException,
        );
      }
      expect(() => jsonNumberMap({'a': -1}, 'value'), throwsFormatException);
      expect(
        () => jsonNumberMap({'a': double.nan}, 'value'),
        throwsFormatException,
      );
    });

    test('normalizeSearch unterstützt deutsche Suchbegriffe', () {
      expect(
        normalizeSearch('  Ärger ÖL über Straße  '),
        'aerger oel ueber strasse',
      );
      expect(normalizeSearch('MÜSLI'), 'muesli');
    });
  });

  group('Food- und Health-Modelle', () {
    test('Food serialisiert alle Felder und copyWith schützt Identität', () {
      final food = testFood(favorite: true, barcode: '12345678');
      final restored = Food.fromJson(cloneJson(food.toJson()));
      expect(restored.toJson(), food.toJson());
      final changed = food.copyWith(
        name: 'Neu',
        brand: 'Marke',
        measure: 'ml',
        portionSize: 40,
        nutrients: const {'calories': 10},
        favorite: true,
        updatedAt: DateTime.utc(2026, 2, 1),
      );
      expect(changed.id, food.id);
      expect(changed.source, food.source);
      expect(changed.createdAt, food.createdAt);
      expect(changed.name, 'Neu');
      expect(changed.measure, 'ml');
      expect(changed.portionSize, 40);
      expect(changed.nutrients, {'calories': 10});
      expect(changed.updatedAt, DateTime.utc(2026, 2, 1));
      expect(changed.copyWith(clearPortion: true).portionSize, isNull);
      expect(testFood(source: 'openfoodfacts').isCustom, isFalse);
      expect(testFood().isCustom, isTrue);
    });

    test(
      'Food.fromJson weist ungültige Quellen, Maße, Nährstoffe und Portionen ab',
      () {
        final invalid = <String, Object?>{
          'source': 'unknown',
          'measure': 'portion',
          'portion_size': 0,
          'portion_size_negative': -1,
          'favorite': 1,
        };
        for (final entry in invalid.entries) {
          final json = cloneJson(testFood().toJson()) as Map<String, dynamic>;
          if (entry.key == 'portion_size_negative') {
            json['portion_size'] = entry.value;
          } else {
            json[entry.key] = entry.value;
          }
          expect(
            () => Food.fromJson(json),
            throwsFormatException,
            reason: entry.key,
          );
        }
        final unknownNutrient =
            cloneJson(testFood().toJson()) as Map<String, dynamic>;
        unknownNutrient['nutrients_per_100'] = {'unknown': 1};
        expect(() => Food.fromJson(unknownNutrient), throwsFormatException);
        final negativeNutrient =
            cloneJson(testFood().toJson()) as Map<String, dynamic>;
        negativeNutrient['nutrients_per_100'] = {'protein': -1};
        expect(() => Food.fromJson(negativeNutrient), throwsFormatException);
      },
    );

    test('Goals und Settings werden vollständig abgebildet', () {
      const goals = Goals(
        waterMl: 1800,
        calories: 2000,
        protein: 100,
        carbs: 250,
        fat: 65,
      );
      expect(goals.forNutrient(Nutrient.calories), 2000);
      expect(goals.forNutrient(Nutrient.protein), 100);
      expect(goals.forNutrient(Nutrient.carbs), 250);
      expect(goals.forNutrient(Nutrient.fat), 65);
      expect(goals.forNutrient(Nutrient.vitaminC), isNull);
      expect(
        Goals.fromJson(cloneJson(goals.toJson())).toJson(),
        goals.toJson(),
      );
      const settings = Settings(
        language: 'en',
        weightUnit: 'lb',
        showNutrition: false,
        showCycle: false,
        showWeight: false,
        showSymptoms: false,
        onlineEnabled: false,
        cycleForecastEnabled: false,
        goals: goals,
      );
      final restored = Settings.fromJson(cloneJson(settings.toJson()));
      expect(restored.toJson(), settings.toJson());
      final changed = restored.copyWith(
        language: 'de',
        showNutrition: true,
        goals: const Goals(),
      );
      expect(changed.language, 'de');
      expect(changed.showNutrition, isTrue);
      expect(changed.weightUnit, 'lb');
      expect(changed.goals.toJson(), const Goals().toJson());
      for (final entry in {'language': 'fr', 'weight_unit': 'stone'}.entries) {
        final json = cloneJson(settings.toJson()) as Map<String, dynamic>;
        json[entry.key] = entry.value;
        expect(() => Settings.fromJson(json), throwsFormatException);
      }
      final negativeGoal = cloneJson(settings.toJson()) as Map<String, dynamic>;
      negativeGoal['goals']['water_ml'] = -1;
      expect(() => Settings.fromJson(negativeGoal), throwsFormatException);
    });

    test('Period.contains behandelt offene und abgeschlossene Intervalle', () {
      final open = testPeriod(start: '2026-01-10', end: null);
      expect(open.contains('2026-01-09', '2026-01-15'), isFalse);
      expect(open.contains('2026-01-10', '2026-01-15'), isTrue);
      expect(open.contains('2026-01-15', '2026-01-15'), isTrue);
      expect(open.contains('2026-01-16', '2026-01-15'), isFalse);
      final closed = testPeriod(start: '2026-01-10', end: '2026-01-12');
      expect(closed.contains('2026-01-12', '2026-01-15'), isTrue);
      expect(closed.contains('2026-01-13', '2026-01-15'), isFalse);
      expect(Period.fromJson(cloneJson(open.toJson())).toJson(), open.toJson());
      for (final entry in {
        'flow': 'unknown',
        'end': '2025-12-31',
        'start': '2026-02-30',
      }.entries) {
        final json = cloneJson(open.toJson()) as Map<String, dynamic>;
        json[entry.key] = entry.value;
        expect(
          () => Period.fromJson(json),
          throwsFormatException,
          reason: entry.key,
        );
      }
    });

    test('WeightEntry und SymptomEntry validieren Wertebereiche', () {
      final weight = testWeight(kg: 80);
      expect(weight.pounds, closeTo(176.369809744, 0.000000001));
      expect(
        WeightEntry.fromJson(cloneJson(weight.toJson())).toJson(),
        weight.toJson(),
      );
      for (final value in [0, -1, 2000.1, double.nan]) {
        final json = cloneJson(weight.toJson()) as Map<String, dynamic>;
        json['kg'] = value;
        expect(() => WeightEntry.fromJson(json), throwsFormatException);
      }
      for (final intensity in [0, 10]) {
        final symptom = testSymptom(intensity: intensity);
        expect(
          SymptomEntry.fromJson(cloneJson(symptom.toJson())).intensity,
          intensity,
        );
      }
      for (final intensity in [-1, 11, 4.5]) {
        final json = cloneJson(testSymptom().toJson()) as Map<String, dynamic>;
        json['intensity'] = intensity;
        expect(() => SymptomEntry.fromJson(json), throwsFormatException);
      }
    });
  });

  group('AppState', () {
    test('vollständiger JSON-Roundtrip und initiale Werte', () {
      final initial = AppState.initial();
      expect(initial.foods, isEmpty);
      expect(initial.settings.language, 'de');
      expect(initial.toJson()['schema_version'], 1);
      final state = fullTestState();
      final restored = AppState.fromJson(cloneJson(state.toJson()));
      expect(restored.toJson(), state.toJson());
      final changed = restored.copyWith(
        weights: const [],
        settings: const Settings(),
      );
      expect(changed.foods, hasLength(1));
      expect(changed.weights, isEmpty);
      expect(changed.settings.language, 'de');
    });

    test('Schema und doppelte IDs werden abgelehnt', () {
      final wrongSchema =
          cloneJson(AppState.initial().toJson()) as Map<String, dynamic>;
      wrongSchema['schema_version'] = 2;
      expect(() => AppState.fromJson(wrongSchema), throwsFormatException);
      final invalidStates = <AppState>[
        testState(foods: [testFood(), testFood()]),
        testState(
          periods: [
            testPeriod(end: null),
            testPeriod(start: '2026-02-01', end: null),
          ],
        ),
        testState(weights: [testWeight(), testWeight()]),
        testState(symptoms: [testSymptom(), testSymptom()]),
      ];
      for (final state in invalidStates) {
        expect(state.validate, throwsFormatException);
      }
      final food = testFood();
      expect(
        () => testState(
          foods: [food],
          intakes: [
            testFoodIntake(),
            testFoodIntake(nutrients: food.nutrients),
          ],
        ).validate(),
        throwsFormatException,
      );
    });

    test(
      'Referenzen, Snapshots und Periodenüberlappungen werden validiert',
      () {
        expect(
          () => testState(intakes: [testFoodIntake()]).validate(),
          throwsFormatException,
        );
        expect(
          () => testState(
            foods: [testFood()],
            intakes: [testFoodIntake(foodName: ' ')],
          ).validate(),
          throwsFormatException,
        );
        for (final periods in [
          [
            testPeriod(end: '2026-01-05'),
            testPeriod(id: 'period-2', start: '2026-01-05', end: '2026-01-08'),
          ],
          [
            testPeriod(end: null),
            testPeriod(id: 'period-2', start: '2026-02-01', end: null),
          ],
        ]) {
          expect(
            () => testState(periods: periods).validate(),
            throwsFormatException,
          );
        }
        testState(
          periods: [
            testPeriod(end: '2026-01-05'),
            testPeriod(id: 'period-2', start: '2026-01-06', end: null),
          ],
        ).validate();
      },
    );
  });
}
