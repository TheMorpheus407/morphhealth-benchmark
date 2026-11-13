import 'dart:math';

import '../model/app_data.dart';
import '../model/entries.dart';
import '../model/food.dart';
import '../model/nutrients.dart';
import '../model/settings.dart';
import '../util/dates.dart';

/// Builds a realistic multi-year diary for tests, benchmarks and trying out
/// the app with a large data set. The same [seed] gives the same data.
///
/// With the defaults (1,000 days ending on [end]) the result holds a little
/// more than 10,000 diary entries across all four areas.
AppData generateSampleDiary({required Day end, int days = 1000, int seed = 7}) {
  final random = Random(seed);
  final first = end.addDays(-(days - 1));
  LocalDateTime stamp(Day d, int h, int m) => LocalDateTime(d, h, m);
  final created = stamp(first, 8, 0);

  final data = AppData(
    settings: const Settings(onlineFoodSearch: OnlineFoodSearch.enabled),
    goals: const Goals(
      waterMl: 2000,
      energyKcal: 2100,
      proteinG: 80,
      carbohydratesG: 250,
      fatG: 70,
    ),
  );

  // name, basis, serving, kcal, protein, carbs, fat
  const foods = <(String, FoodBasis, double, double, double, double, double)>[
    ('Haferflocken', FoodBasis.per100g, 50, 372, 13.5, 58.7, 7.0),
    ('Vollmilch 3,5 %', FoodBasis.per100ml, 200, 65, 3.4, 4.8, 3.6),
    ('Apfel', FoodBasis.per100g, 150, 54, 0.3, 11.4, 0.1),
    ('Banane', FoodBasis.per100g, 120, 93, 1.2, 20.0, 0.2),
    ('Vollkornbrot', FoodBasis.per100g, 50, 213, 7.3, 38.0, 1.4),
    ('Butter', FoodBasis.per100g, 10, 741, 0.7, 0.6, 82.0),
    ('Gouda', FoodBasis.per100g, 30, 356, 25.0, 0.0, 28.0),
    ('Naturjoghurt', FoodBasis.per100g, 150, 62, 3.8, 4.4, 3.2),
    ('Nudeln, gekocht', FoodBasis.per100g, 200, 150, 5.3, 30.0, 0.9),
    ('Tomatensoße', FoodBasis.per100g, 125, 45, 1.5, 7.0, 1.0),
    ('Hähnchenbrust', FoodBasis.per100g, 150, 110, 23.0, 0.0, 1.5),
    ('Reis, gekocht', FoodBasis.per100g, 180, 130, 2.7, 28.0, 0.3),
    ('Brokkoli', FoodBasis.per100g, 200, 34, 2.8, 2.7, 0.4),
    ('Olivenöl', FoodBasis.per100ml, 10, 824, 0.0, 0.0, 91.6),
    ('Linsensuppe', FoodBasis.per100ml, 300, 62, 3.9, 8.2, 1.1),
    ('Orangensaft', FoodBasis.per100ml, 200, 44, 0.7, 9.0, 0.2),
    ('Mandeln', FoodBasis.per100g, 25, 611, 24.0, 5.7, 53.0),
    ('Zartbitterschokolade', FoodBasis.per100g, 20, 546, 7.8, 31.0, 40.0),
    ('Kartoffeln, gekocht', FoodBasis.per100g, 200, 73, 1.9, 15.0, 0.1),
    ('Lachsfilet', FoodBasis.per100g, 125, 202, 20.0, 0.0, 13.6),
    ('Ei', FoodBasis.per100g, 60, 137, 11.9, 1.5, 9.3),
    ('Hummus', FoodBasis.per100g, 40, 237, 7.0, 10.0, 17.0),
    ('Müsliriegel', FoodBasis.per100g, 25, 420, 6.5, 62.0, 14.0),
    ('Cola ohne Zucker', FoodBasis.per100ml, 330, 0.2, 0.0, 0.0, 0.0),
  ];
  final foodIds = <String>[];
  for (var i = 0; i < foods.length; i++) {
    final f = foods[i];
    final n = NutrientValues()
      ..[Nutrients.energy] = f.$4
      ..[Nutrients.protein] = f.$5
      ..[Nutrients.carbohydrates] = f.$6
      ..[Nutrients.fat] = f.$7
      ..[Nutrients.saturatedFat] = f.$7 * 0.35
      ..[Nutrients.sugars] = f.$6 * 0.3
      ..[Nutrients.fiber] = (f.$6 * 0.08)
      ..[Nutrients.salt] = 0.1 + i * 0.01;
    // Every third food carries the full set of vitamins and minerals.
    if (i % 3 == 0) {
      for (final nutrient in Nutrients.all) {
        if (nutrient.group == NutrientGroup.vitamin ||
            nutrient.group == NutrientGroup.mineral) {
          n[nutrient] = ((i + 1) * (nutrient.index + 3) % 97) / 10;
        }
      }
    }
    if (f.$1.startsWith('Cola')) n[Nutrients.caffeine] = 10;
    final id = 'food-${(i + 1).toString().padLeft(3, '0')}';
    foodIds.add(id);
    data.putFood(
      Food(
        id: id,
        source: FoodSource.custom,
        name: f.$1,
        basis: f.$2,
        servingSize: f.$3,
        nutrients: n,
        favorite: i < 4,
        createdAt: created,
        updatedAt: created,
      ),
    );
  }

  const symptomNames = [
    'Kopfschmerzen',
    'Krämpfe',
    'Müdigkeit',
    'Rückenschmerzen',
    'Übelkeit',
  ];

  var counter = 0;
  String id(String prefix) =>
      '$prefix-${(++counter).toString().padLeft(6, '0')}';

  // Periods: a cycle of about 28 days with small variation.
  var periodStart = first.addDays(random.nextInt(20));
  while (periodStart <= end) {
    final length = 4 + random.nextInt(3);
    final periodEnd = periodStart.addDays(length - 1);
    final running = periodEnd > end;
    data.putPeriod(
      Period(
        id: id('period'),
        start: periodStart,
        end: running ? null : periodEnd,
        flow: {
          for (var d = 0; d < length && periodStart.addDays(d) <= end; d++)
            periodStart.addDays(d): d == 0
                ? FlowLevel.light
                : d == 1
                ? FlowLevel.heavy
                : d < length - 1
                ? FlowLevel.medium
                : FlowLevel.spotting,
        },
        createdAt: stamp(periodStart, 9, 0),
        updatedAt: stamp(periodStart, 9, 0),
      ),
    );
    // Symptoms around the start of the period.
    if (periodStart.addDays(-1) >= first) {
      final at = stamp(periodStart.addDays(-1), 18, 30);
      data.putSymptom(
        SymptomEntry(
          id: id('symptom'),
          name: 'Kopfschmerzen',
          intensity: 3 + random.nextInt(4),
          at: at,
          createdAt: at,
          updatedAt: at,
        ),
      );
    }
    final at = stamp(periodStart, 9, 15);
    data.putSymptom(
      SymptomEntry(
        id: id('symptom'),
        name: 'Krämpfe',
        intensity: 4 + random.nextInt(5),
        at: at,
        createdAt: at,
        updatedAt: at,
      ),
    );
    periodStart = periodStart.addDays(26 + random.nextInt(5));
  }

  for (var d = first; d <= end; d = d.addDays(1)) {
    // Meals.
    const mealTimes = {
      Meal.breakfast: 7,
      Meal.lunch: 12,
      Meal.dinner: 19,
      Meal.snack: 15,
    };
    for (final meal in Meal.values) {
      final items = meal == Meal.snack
          ? random.nextInt(2)
          : 1 + random.nextInt(2);
      for (var k = 0; k < items; k++) {
        final index = random.nextInt(foodIds.length);
        final food = data.food(foodIds[index])!;
        final at = stamp(d, mealTimes[meal]!, 5 + random.nextInt(50));
        final usePortion = random.nextInt(4) == 0;
        data.putIntake(
          IntakeEntry(
            id: id('intake'),
            foodId: food.id,
            at: at,
            meal: meal,
            amount: usePortion
                ? (1 + random.nextInt(2)).toDouble()
                : (food.servingSize! * (0.5 + random.nextInt(4) * 0.5)),
            unit: usePortion
                ? AmountUnit.portion
                : (food.basis == FoodBasis.per100g
                      ? AmountUnit.g
                      : AmountUnit.ml),
            portionSize: usePortion ? food.servingSize : null,
            createdAt: at,
            updatedAt: at,
          ),
        );
      }
    }
    // Water and caffeine.
    final glasses = 3 + random.nextInt(3);
    for (var k = 0; k < glasses; k++) {
      final at = stamp(d, 8 + k * 3, random.nextInt(60));
      data.putWater(
        WaterEntry(
          id: id('water'),
          at: at,
          amountMl: const [150.0, 250.0, 330.0, 500.0][random.nextInt(4)],
          createdAt: at,
          updatedAt: at,
        ),
      );
    }
    if (random.nextInt(10) < 8) {
      final at = stamp(d, 8, 10 + random.nextInt(30));
      data.putCaffeine(
        CaffeineEntry(
          id: id('caffeine'),
          at: at,
          amountMg: random.nextBool() ? 60 : 90,
          label: random.nextBool() ? 'Espresso' : 'Kaffee',
          createdAt: at,
          updatedAt: at,
        ),
      );
    }
    // Weight every other day.
    if (d.epochDay.isEven) {
      final offset = d.daysSince(first);
      data.putWeight(
        WeightEntry(
          id: id('weight'),
          date: d,
          weightKg: 68 + sin(offset / 60) * 1.5 + (random.nextInt(9) - 4) / 10,
          createdAt: stamp(d, 7, 0),
          updatedAt: stamp(d, 7, 0),
        ),
      );
    }
    // An occasional symptom.
    if (random.nextInt(4) == 0) {
      final at = stamp(d, 10 + random.nextInt(10), random.nextInt(60));
      data.putSymptom(
        SymptomEntry(
          id: id('symptom'),
          name: symptomNames[random.nextInt(symptomNames.length)],
          intensity: 1 + random.nextInt(8),
          at: at,
          note: random.nextInt(5) == 0 ? 'nach dem Sport' : null,
          createdAt: at,
          updatedAt: at,
        ),
      );
    }
  }
  data.revision = 0;
  return data;
}
