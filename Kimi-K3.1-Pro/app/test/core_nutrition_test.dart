import 'package:flutter_test/flutter_test.dart';
import 'package:morphhealth/core/nutrition.dart';

import 'core_fixtures.dart';

void main() {
  group('Nährstoffdefinitionen', () {
    test(
      'alle 31 kanonischen Definitionen einschließlich OFF-Aliase sind vollständig',
      () {
        final expected = <String, Map<String, Object>>{
          'calories': {
            'unit': 'kcal',
            'group': NutrientGroup.main,
            'off': ['energy-kcal'],
          },
          'protein': {
            'unit': 'g',
            'group': NutrientGroup.main,
            'off': ['proteins'],
          },
          'carbs': {
            'unit': 'g',
            'group': NutrientGroup.main,
            'off': ['carbohydrates'],
          },
          'fat': {
            'unit': 'g',
            'group': NutrientGroup.main,
            'off': ['fat'],
          },
          'saturated_fat': {
            'unit': 'g',
            'group': NutrientGroup.additional,
            'off': ['saturated-fat'],
          },
          'sugar': {
            'unit': 'g',
            'group': NutrientGroup.additional,
            'off': ['sugars'],
          },
          'fiber': {
            'unit': 'g',
            'group': NutrientGroup.additional,
            'off': ['fiber'],
          },
          'salt': {
            'unit': 'g',
            'group': NutrientGroup.additional,
            'off': ['salt'],
          },
          'sodium': {
            'unit': 'mg',
            'group': NutrientGroup.additional,
            'off': ['sodium'],
          },
          'caffeine': {
            'unit': 'mg',
            'group': NutrientGroup.additional,
            'off': ['caffeine'],
          },
          'vitamin_a': {
            'unit': 'µg',
            'group': NutrientGroup.vitamin,
            'off': ['vitamin-a'],
          },
          'vitamin_c': {
            'unit': 'mg',
            'group': NutrientGroup.vitamin,
            'off': ['vitamin-c'],
          },
          'vitamin_d': {
            'unit': 'µg',
            'group': NutrientGroup.vitamin,
            'off': ['vitamin-d'],
          },
          'vitamin_e': {
            'unit': 'mg',
            'group': NutrientGroup.vitamin,
            'off': ['vitamin-e'],
          },
          'vitamin_k': {
            'unit': 'µg',
            'group': NutrientGroup.vitamin,
            'off': ['vitamin-k'],
          },
          'vitamin_b1': {
            'unit': 'mg',
            'group': NutrientGroup.vitamin,
            'off': ['vitamin-b1'],
          },
          'vitamin_b2': {
            'unit': 'mg',
            'group': NutrientGroup.vitamin,
            'off': ['vitamin-b2'],
          },
          'vitamin_b3': {
            'unit': 'mg',
            'group': NutrientGroup.vitamin,
            'off': ['vitamin-b3', 'vitamin-pp'],
          },
          'vitamin_b5': {
            'unit': 'mg',
            'group': NutrientGroup.vitamin,
            'off': ['vitamin-b5', 'pantothenic-acid'],
          },
          'vitamin_b6': {
            'unit': 'mg',
            'group': NutrientGroup.vitamin,
            'off': ['vitamin-b6'],
          },
          'vitamin_b7': {
            'unit': 'µg',
            'group': NutrientGroup.vitamin,
            'off': ['vitamin-b7', 'biotin'],
          },
          'vitamin_b9': {
            'unit': 'µg',
            'group': NutrientGroup.vitamin,
            'off': ['vitamin-b9', 'folates', 'folic-acid'],
          },
          'vitamin_b12': {
            'unit': 'µg',
            'group': NutrientGroup.vitamin,
            'off': ['vitamin-b12'],
          },
          'calcium': {
            'unit': 'mg',
            'group': NutrientGroup.mineral,
            'off': ['calcium'],
          },
          'iron': {
            'unit': 'mg',
            'group': NutrientGroup.mineral,
            'off': ['iron'],
          },
          'magnesium': {
            'unit': 'mg',
            'group': NutrientGroup.mineral,
            'off': ['magnesium'],
          },
          'potassium': {
            'unit': 'mg',
            'group': NutrientGroup.mineral,
            'off': ['potassium'],
          },
          'zinc': {
            'unit': 'mg',
            'group': NutrientGroup.mineral,
            'off': ['zinc'],
          },
          'selenium': {
            'unit': 'µg',
            'group': NutrientGroup.mineral,
            'off': ['selenium'],
          },
          'iodine': {
            'unit': 'µg',
            'group': NutrientGroup.mineral,
            'off': ['iodine'],
          },
          'phosphorus': {
            'unit': 'mg',
            'group': NutrientGroup.mineral,
            'off': ['phosphorus'],
          },
        };
        expect(expected, hasLength(31));
        expect(Nutrient.values, hasLength(31));
        expect(Nutrient.values.map((item) => item.id).toSet(), hasLength(31));
        expect(
          Nutrient.values.map((item) => item.id).toSet(),
          expected.keys.toSet(),
        );
        for (final entry in expected.entries) {
          final nutrient = Nutrient.byId(entry.key);
          expect(nutrient.unit, entry.value['unit'], reason: entry.key);
          expect(nutrient.group, entry.value['group'], reason: entry.key);
          expect(nutrient.offKeys, entry.value['off'], reason: entry.key);
        }
        expect(
          Nutrient.values.where((item) => item.group == NutrientGroup.main),
          hasLength(4),
        );
        expect(
          Nutrient.values.where(
            (item) => item.group == NutrientGroup.additional,
          ),
          hasLength(6),
        );
        expect(
          Nutrient.values.where((item) => item.group == NutrientGroup.vitamin),
          hasLength(13),
        );
        expect(
          Nutrient.values.where((item) => item.group == NutrientGroup.mineral),
          hasLength(8),
        );
        expect(() => Nutrient.byId('unknown'), throwsFormatException);
      },
    );
  });

  group('IntakeEntry', () {
    test('g, ml und Portionen berechnen den richtigen Faktor', () {
      final grams = testFoodIntake(amount: 150);
      final millilitres = testFoodIntake(amount: 250, unit: 'ml');
      final portions = testFoodIntake(
        amount: 2,
        unit: 'portion',
        portionSize: 30,
      );
      expect(grams.nutrientFactor, 1.5);
      expect(millilitres.nutrientFactor, 2.5);
      expect(portions.nutrientFactor, closeTo(0.6, 1e-12));
      expect(grams.amountOf(Nutrient.calories), 300);
      expect(millilitres.amountOf(Nutrient.protein), 25);
      expect(portions.amountOf(Nutrient.calories), closeTo(120, 1e-12));
    });

    test('JSON-Roundtrip und copyWith erhalten den Nährstoff-Snapshot', () {
      final original = testFoodIntake(
        amount: 1.5,
        unit: 'portion',
        portionSize: 45,
        notes: 'Notiz',
        nutrients: const {'calories': 123, 'vitamin_b12': 0},
      );
      final restored = IntakeEntry.fromJson(cloneJson(original.toJson()));
      expect(restored.toJson(), original.toJson());
      final changed = restored.copyWith(
        occurredAt: DateTime.utc(2026, 2, 1),
        meal: 'dinner',
        amount: 2,
        unit: 'g',
        portionSize: 50,
        nutrients: const {'calories': 100},
        notes: 'Neu',
        updatedAt: DateTime.utc(2026, 2, 2),
      );
      expect(changed.id, original.id);
      expect(changed.foodId, original.foodId);
      expect(changed.foodName, original.foodName);
      expect(changed.amount, 2);
      expect(changed.nutrients, {'calories': 100});
      expect(changed.notes, 'Neu');
      expect(changed.updatedAt, DateTime.utc(2026, 2, 2));
    });

    test(
      'JSON-Validierung erzwingt Art, Einheit, Mahlzeit, Menge und Portionsgröße',
      () {
        final cases = <Map<String, dynamic>>[];
        Map<String, dynamic> jsonOf(IntakeEntry entry) =>
            cloneJson(entry.toJson()) as Map<String, dynamic>;
        final invalidFoodUnit = jsonOf(testFoodIntake());
        invalidFoodUnit['unit'] = 'kg';
        cases.add(invalidFoodUnit);
        final invalidWaterUnit = jsonOf(testSimpleIntake());
        invalidWaterUnit['unit'] = 'g';
        cases.add(invalidWaterUnit);
        final invalidCaffeineUnit = jsonOf(
          testSimpleIntake(kind: IntakeKind.caffeine),
        );
        invalidCaffeineUnit['unit'] = 'ml';
        cases.add(invalidCaffeineUnit);
        final invalidKind = jsonOf(testFoodIntake());
        invalidKind['kind'] = 'supplement';
        cases.add(invalidKind);
        final invalidMeal = jsonOf(testFoodIntake());
        invalidMeal['meal'] = 'brunch';
        cases.add(invalidMeal);
        final missingPortion = jsonOf(testFoodIntake(unit: 'portion'));
        cases.add(missingPortion);
        final zeroPortion = jsonOf(
          testFoodIntake(unit: 'portion', portionSize: 1),
        );
        zeroPortion['portion_size'] = 0;
        cases.add(zeroPortion);
        final zeroAmount = jsonOf(testFoodIntake());
        zeroAmount['amount'] = 0;
        cases.add(zeroAmount);
        final unknownNutrient = jsonOf(testFoodIntake());
        unknownNutrient['nutrients_per_100_snapshot'] = {'unknown': 1};
        cases.add(unknownNutrient);
        for (final json in cases) {
          expect(
            () => IntakeEntry.fromJson(json),
            throwsFormatException,
            reason: jsonEncodeForReason(json),
          );
        }
      },
    );
  });

  group('Tagesaggregation', () {
    test(
      'aggregiert g, ml und Portionen und zählt bekannte Werte je Nährstoff',
      () {
        final day = summarizeNutrition('2026-01-15', [
          testFoodIntake(id: 'g', amount: 150, occurredAt: testTimestamp(12)),
          testFoodIntake(
            id: 'ml',
            amount: 250,
            unit: 'ml',
            occurredAt: testTimestamp(11),
            nutrients: const {'calories': 40, 'carbs': 10},
          ),
          testFoodIntake(
            id: 'portion',
            amount: 2,
            unit: 'portion',
            portionSize: 30,
            occurredAt: testTimestamp(10),
          ),
          testFoodIntake(
            id: 'other-day',
            amount: 1000,
            occurredAt: DateTime.utc(2026, 1, 14, 12),
            nutrients: const {'calories': 1000},
          ),
        ]);
        expect(day.date, '2026-01-15');
        expect(day.entries.map((entry) => entry.id), ['portion', 'ml', 'g']);
        expect(day.foodEntryCount, 3);
        expect(day.total(Nutrient.calories), closeTo(520, 1e-12));
        expect(day.total(Nutrient.protein), closeTo(21, 1e-12));
        expect(day.total(Nutrient.carbs), closeTo(88, 1e-12));
        expect(day.total(Nutrient.fat), closeTo(10.5, 1e-12));
        expect(day.total(Nutrient.caffeine), closeTo(42, 1e-12));
        expect(day.knownFoodEntries['calories'], 3);
        expect(day.knownFoodEntries['protein'], 2);
        expect(day.knownFoodEntries['carbs'], 3);
        expect(day.knownFoodEntries['vitamin_a'], 0);
        final json = day.toJson();
        expect(json['nutrient_units'], hasLength(31));
        expect(json['known_food_entries_per_nutrient'], hasLength(31));
        expect(json['entries'], hasLength(3));
        final first = (json['entries'] as List).first as Map<String, dynamic>;
        expect(first['local_date'], '2026-01-15');
        expect(first['calculated_nutrients'], hasLength(31));
        expect(first['calculated_nutrients']['calories'], closeTo(120, 1e-12));
        expect(
          () => summarizeNutrition('2026-02-30', const []),
          throwsFormatException,
        );
      },
    );

    test(
      'Wasser und zusätzliches Koffein werden getrennt von Lebensmitteln behandelt',
      () {
        final water = testSimpleIntake(id: 'water', amount: 250);
        final caffeine = testSimpleIntake(
          id: 'extra-caffeine',
          kind: IntakeKind.caffeine,
          amount: 75,
        );
        expect(water.amountOf(Nutrient.calories), 0);
        expect(water.amountOf(Nutrient.caffeine), isNull);
        expect(water.amountOf(Nutrient.protein), isNull);
        expect(caffeine.amountOf(Nutrient.caffeine), 75);
        expect(caffeine.amountOf(Nutrient.calories), 0);
        expect(caffeine.amountOf(Nutrient.protein), isNull);
        final day = summarizeNutrition('2026-01-15', [
          water,
          testSimpleIntake(
            id: 'water-2',
            amount: 300,
            occurredAt: testTimestamp(13),
          ),
          caffeine,
          testFoodIntake(
            id: 'food',
            amount: 50,
            nutrients: const {'calories': 100, 'caffeine': 20},
          ),
        ]);
        expect(day.waterMl, 550);
        expect(day.foodEntryCount, 1);
        expect(day.total(Nutrient.calories), 50);
        expect(day.total(Nutrient.caffeine), 85);
        expect(day.knownFoodEntries['caffeine'], 1);
        expect(day.knownFoodEntries['calories'], 1);
      },
    );

    test(
      'unbekannt ist nicht null: explizite Null und fehlender Schlüssel bleiben unterscheidbar',
      () {
        final missing = testFoodIntake(
          id: 'missing',
          nutrients: const {'calories': 0},
        );
        final explicitZero = testFoodIntake(
          id: 'zero',
          nutrients: const {'protein': 0, 'vitamin_a': 0},
        );
        expect(missing.amountOf(Nutrient.calories), 0);
        expect(missing.amountOf(Nutrient.protein), isNull);
        expect(explicitZero.amountOf(Nutrient.protein), 0);
        expect(explicitZero.amountOf(Nutrient.vitaminA), 0);
        final day = summarizeNutrition('2026-01-15', [missing, explicitZero]);
        expect(day.total(Nutrient.calories), 0);
        expect(day.total(Nutrient.protein), 0);
        expect(day.total(Nutrient.carbs), 0);
        expect(day.knownFoodEntries['calories'], 1);
        expect(day.knownFoodEntries['protein'], 1);
        expect(day.knownFoodEntries['vitamin_a'], 1);
        expect(day.knownFoodEntries['carbs'], 0);
        final calculated =
            (day.toJson()['entries'] as List)
                    .cast<Map<String, dynamic>>()
                    .singleWhere(
                      (entry) => entry['id'] == 'missing',
                    )['calculated_nutrients']
                as Map<String, dynamic>;
        expect(calculated['calories'], 0);
        expect(calculated['protein'], isNull);
        final entirelyUnknown = summarizeNutrition('2026-01-15', [
          testFoodIntake(nutrients: const {}),
        ]);
        expect(entirelyUnknown.total(Nutrient.protein), 0);
        expect(entirelyUnknown.knownFoodEntries['protein'], 0);
      },
    );
  });
}

String jsonEncodeForReason(Map<String, dynamic> json) =>
    '${json['kind']}/${json['unit']}/${json['meal']}/${json['amount']}/${json['portion_size']}';
