import 'package:morphhealth_core/morphhealth_core.dart';
import 'package:morphhealth_core/src/portable/example_document.dart';
import 'package:test/test.dart';

final _now = LocalDateTime.parse('2026-09-23T20:00:00+02:00');

AppData _example() =>
    AppData.fromDocument(exampleDocument(), IssueLog(), now: _now)!;

void main() {
  group('day totals of the example data', () {
    final day = NutritionDay.compute(_example(), Day(2026, 9, 22));

    test('calories and macronutrients', () {
      // 60 g oats + 200 ml milk + 150 g apple + 30 g spread
      expect(day.entryCount, 4);
      expect(
        day.total(Nutrients.energy),
        closeTo(372 * .6 + 65 * 2 + 54 * 1.5 + 539 * .3, 1e-9),
      );
      expect(
        day.total(Nutrients.protein),
        closeTo(13.5 * .6 + 3.4 * 2 + 0.3 * 1.5 + 6.3 * .3, 1e-9),
      );
      expect(
        day.total(Nutrients.carbohydrates),
        closeTo(58.7 * .6 + 4.8 * 2 + 11.4 * 1.5 + 57.5 * .3, 1e-9),
      );
      expect(
        day.total(Nutrients.fat),
        closeTo(7.0 * .6 + 3.6 * 2 + 0.1 * 1.5 + 30.9 * .3, 1e-9),
      );
    });

    test('totals per meal', () {
      expect(
        day.mealTotals[Meal.breakfast]![Nutrients.energy],
        closeTo(223.2 + 130, 1e-9),
      );
      expect(day.mealTotals[Meal.lunch]![Nutrients.energy], closeTo(81, 1e-9));
      expect(day.mealTotals[Meal.dinner]!.isEmpty, isTrue);
      expect(day.entriesOf(Meal.snack).single.entry.note, 'auf Brot');
    });

    test('salt and sodium are derived from each other', () {
      // Milk states only salt (0.11 g per 100 ml) → 44 mg sodium per 100 ml.
      final milk = day.entries.firstWhere(
        (e) => e.food!.id == 'food-vollmilch',
      );
      expect(milk.nutrients[Nutrients.sodium], closeTo(88, 1e-9));
      expect(
        day.total(Nutrients.sodium),
        closeTo(8 * .6 + 88 + 42.8 * .3, 1e-9),
      );
    });

    test('unknown is not zero: coverage tells who contributed', () {
      // Only oats and apple state vitamin C.
      expect(day.knownCounts[Nutrients.vitaminC.index], 2);
      expect(day.total(Nutrients.vitaminC), closeTo(0 * .6 + 12 * 1.5, 1e-9));
      // Calcium of the spread is an estimate.
      expect(day.knownCounts[Nutrients.calcium.index], 3);
      expect(day.estimatedCounts[Nutrients.calcium.index], 1);
      final apple = day.entries.firstWhere((e) => e.food!.id == 'food-apfel');
      expect(apple.nutrients.has(Nutrients.calcium), isFalse);
    });

    test('water, caffeine and goals', () {
      expect(day.waterMl, 1080);
      expect(day.caffeineAdditionalMg, 60);
      expect(day.caffeineFoodMg, 0);
      expect(day.waterProgress!.fraction, closeTo(0.54, 1e-9));
      final energy = day.goalProgress(Nutrients.energy)!;
      expect(energy.goal, 2100);
      expect(energy.remaining, closeTo(2100 - 595.9, 1e-9));
      expect(day.goalProgress(Nutrients.fiber), isNull);
    });

    test('caffeine from foods is added to recorded caffeine', () {
      final next = NutritionDay.compute(_example(), Day(2026, 9, 23));
      expect(next.caffeineFoodMg, closeTo(33, 1e-9)); // 330 ml × 10 mg/100 ml
      expect(next.caffeineAdditionalMg, 90);
      expect(next.caffeineTotalMg, closeTo(123, 1e-9));
    });

    test('JSON form lists all nutrients, meals and coverage', () {
      final json = day.toJson();
      expect((json['totals'] as Map).keys, [
        for (final n in Nutrients.all) n.key,
      ]);
      expect((json['meals'] as List).map((m) => (m as Map)['meal']), [
        'breakfast',
        'lunch',
        'dinner',
        'snack',
      ]);
      expect((json['totals'] as Map)['energy_kcal'], 595.9);
      expect(((json['coverage'] as Map)['vitamin_c_mg'] as Map), {
        'entries_with_value': 2,
        'entries_total': 4,
        'estimated_entries': 0,
      });
      final first =
          (((json['meals'] as List).first as Map)['entries'] as List).first
              as Map;
      expect(first['quantity'], 60);
      expect(first['quantity_unit'], 'g');
      expect((first['nutrients'] as Map)['energy_kcal'], 223.2);
      expect(
        ((json['goals'] as Map)['energy_kcal'] as Map)['percent'],
        closeTo(28.37619, 1e-5),
      );
    });
  });

  test('an empty day has zero totals and no goal noise', () {
    final day = NutritionDay.compute(AppData(), Day(2026, 1, 1));
    expect(day.isEmpty, isTrue);
    expect(day.total(Nutrients.energy), 0);
    final json = day.toJson();
    expect((json['totals'] as Map).values.every((v) => v == 0), isTrue);
    expect((json['goals'] as Map).values.every((v) => v == null), isTrue);
  });

  test('portions, grams and millilitres', () {
    final data = _example();
    final day = NutritionDay.compute(data, Day(2026, 9, 23));
    final oats = day.entries[0]; // 1 portion of 50 g
    expect(oats.quantity, 50);
    expect(oats.nutrients[Nutrients.energy], closeTo(186, 1e-9));
    final milk = day.entries[1]; // 1 portion of 200 ml
    expect(milk.quantity, 200);
    expect(milk.food!.basis, FoodBasis.per100ml);
    expect(milk.nutrients[Nutrients.energy], closeTo(130, 1e-9));
  });

  test('numbers are free of binary noise in JSON', () {
    expect(roundForJson(0.1 + 0.2), 0.3);
    expect(roundForJson(12.300000000000001), 12.3);
    expect(roundForJson(5.0), isA<int>());
    expect(roundForJson(1 / 3), 0.333333);
  });

  group('trend series', () {
    final data = _example();

    test('nutrients, water and total caffeine per day with gaps', () {
      final from = Day(2026, 9, 21), to = Day(2026, 9, 23);
      final kcal = nutritionSeries(
        data,
        NutritionMetric.nutrient(Nutrients.energy),
        from,
        to,
      );
      expect(kcal.map((p) => p.value?.round()), [null, 596, 317]);
      expect(
        nutritionSeries(
          data,
          NutritionMetric.water,
          from,
          to,
        ).map((p) => p.value),
        [null, 1080.0, 500.0],
      );
      expect(
        nutritionSeries(
          data,
          NutritionMetric.caffeineTotal,
          from,
          to,
        ).map((p) => p.value?.round()),
        [null, 60, 123],
      );
    });

    test('every nutrient plus water and caffeine can be selected', () {
      expect(NutritionMetric.all.length, 31 + 1);
      expect(NutritionMetric.all.map((m) => m.key).toSet().length, 32);
    });

    test('weight series and statistics', () {
      final series = weightSeries(data, Day(2026, 9, 1), Day(2026, 9, 22));
      expect(series.length, 22);
      final stats = SeriesStats.of(series);
      expect(stats.count, 4);
      expect((stats.min, stats.minDay), (67.9, Day(2026, 9, 15)));
      expect((stats.max, stats.maxDay), (68.4, Day(2026, 9, 1)));
      expect(stats.change, closeTo(-0.4, 1e-9));
      expect(stats.mean, closeTo(68.1, 1e-9));
    });
  });

  test('recent foods carry the latest entry for logging again', () {
    final recent = recentFoods(_example());
    expect(recent.first.food.id, 'food-cola-zero');
    expect(recent.map((r) => r.food.id).toSet().length, recent.length);
    final oats = recent.firstWhere((r) => r.food.id == 'food-haferflocken');
    expect(oats.uses, 2);
    expect(oats.lastEntry.id, 'intake-0005');
  });

  test('local food search ignores case and accents', () {
    final data = _example();
    expect(searchLocalFoods(data, 'HAFER').single.id, 'food-haferflocken');
    expect(
      searchLocalFoods(data, 'nuss creme').single.id,
      'food-nuss-nugat-creme',
    );
    expect(searchLocalFoods(data, '4000000000020').single.id, 'food-cola-zero');
    expect(searchLocalFoods(data, '', customOnly: true), hasLength(3));
    expect(searchLocalFoods(data, 'xyz'), isEmpty);
  });
}
