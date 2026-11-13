import 'package:morphhealth_core/morphhealth_core.dart';
import 'package:test/test.dart';

final _clock = FixedClock(LocalDateTime.parse('2026-09-23T12:40:00+02:00'));

Future<HealthRepository> _repo([MemoryDataStore? store]) {
  var n = 0;
  return HealthRepository.open(
    store ?? MemoryDataStore(),
    clock: _clock,
    idFactory: () => 'id-${++n}',
  );
}

Food _food(
  String id, {
  String name = 'Brot',
  FoodBasis basis = FoodBasis.per100g,
  double? serving,
  double? density,
}) => Food(
  id: id,
  source: FoodSource.custom,
  name: name,
  basis: basis,
  servingSize: serving,
  densityGPerMl: density,
  nutrients: NutrientValues()..[Nutrients.energy] = 200,
  createdAt: _clock.now(),
  updatedAt: _clock.now(),
);

Matcher _invalid(String code) =>
    throwsA(isA<ValidationException>().having((e) => e.code, 'code', code));

void main() {
  test(
    'journal and snapshot replay give the same data as live changes',
    () async {
      final store = MemoryDataStore(compactAfter: 7);
      final repo = await _repo(store);
      await repo.saveFood(_food('f', serving: 40));
      for (var i = 0; i < 20; i++) {
        final e = await repo.logIntake(
          foodId: 'f',
          amount: 10.0 + i,
          unit: AmountUnit.g,
        );
        if (i.isOdd) await repo.deleteIntake(e.id);
        await repo.addWater(100.0 + i);
      }
      await repo.addCaffeine(60, label: 'Espresso');
      await repo.addWeight(Day(2026, 9, 23), 70.5);
      await repo.addSymptom('  Kopfschmerzen ', 3);
      await repo.saveCycleDay(Day(2026, 9, 2), spotting: true);
      expect(store.snapshotWrites, greaterThan(2));

      final again = await _repo(store);
      final a = repo.data.toDocument(exportedAt: _clock.now(), appVersion: 'x');
      final b = again.data.toDocument(
        exportedAt: _clock.now(),
        appVersion: 'x',
      );
      expect(b, a);
      expect(again.data.symptoms.single.name, 'Kopfschmerzen');
    },
  );

  test('listeners are told about every change', () async {
    final repo = await _repo();
    var calls = 0;
    void listener() => calls++;
    repo.addListener(listener);
    await repo.addWater(100);
    await repo.updateGoals(const Goals(waterMl: 2000));
    expect(calls, 2);
    repo.removeListener(listener);
    await repo.addWater(100);
    expect(calls, 2);
  });

  group('intake', () {
    test('meal follows the time of day unless given', () async {
      final repo = await _repo();
      await repo.saveFood(_food('f'));
      final lunch = await repo.logIntake(
        foodId: 'f',
        amount: 50,
        unit: AmountUnit.g,
      );
      expect(lunch.meal, Meal.lunch);
      expect(lunch.at, _clock.now());
      final dinner = await repo.logIntake(
        foodId: 'f',
        amount: 50,
        unit: AmountUnit.g,
        at: LocalDateTime(Day(2026, 9, 22), 7, 15),
        meal: Meal.dinner,
      );
      expect(dinner.meal, Meal.dinner);
      expect(repo.data.intakeOn(Day(2026, 9, 22)).single.id, dinner.id);
    });

    test('a portion entry remembers the portion size of that moment', () async {
      final repo = await _repo();
      await repo.saveFood(_food('f', serving: 40));
      final entry = await repo.logIntake(
        foodId: 'f',
        amount: 2,
        unit: AmountUnit.portion,
      );
      expect(entry.portionSize, 40);
      await repo.saveFood(repo.data.food('f')!.copyWith(servingSize: 55.0));
      final food = repo.data.food('f')!;
      expect(repo.data.intakeEntry(entry.id)!.basisQuantity(food), 80);
    });

    test(
      'portions need a size; amounts must be positive; food must exist',
      () async {
        final repo = await _repo();
        await repo.saveFood(_food('f'));
        await expectLater(
          repo.logIntake(foodId: 'f', amount: 1, unit: AmountUnit.portion),
          _invalid('portion_size_missing'),
        );
        await expectLater(
          repo.logIntake(foodId: 'f', amount: 0, unit: AmountUnit.g),
          _invalid('amount_invalid'),
        );
        await expectLater(
          repo.logIntake(foodId: 'nope', amount: 1, unit: AmountUnit.g),
          _invalid('food_missing'),
        );
        expect(repo.data.intakeCount, 0);
      },
    );

    test('an entry can be logged again', () async {
      final repo = await _repo();
      await repo.saveFood(_food('f', serving: 30));
      final first = await repo.logIntake(
        foodId: 'f',
        amount: 1.5,
        unit: AmountUnit.portion,
        at: LocalDateTime(Day(2026, 9, 20), 8, 0),
        meal: Meal.breakfast,
        note: 'mit Butter',
      );
      final again = await repo.relogIntake(first.id);
      expect(again.id, isNot(first.id));
      expect(
        (again.foodId, again.amount, again.unit, again.portionSize),
        ('f', 1.5, AmountUnit.portion, 30.0),
      );
      expect(again.meal, Meal.breakfast);
      expect(again.at, _clock.now());
      expect(again.note, isNull);
      expect(repo.data.intakeCount, 2);
    });

    test('converting between g and ml uses the density of the food', () async {
      final repo = await _repo();
      await repo.saveFood(
        _food('oil', basis: FoodBasis.per100ml, density: 0.92),
      );
      await repo.saveFood(_food('bread'));
      final oil = await repo.logIntake(
        foodId: 'oil',
        amount: 46,
        unit: AmountUnit.g,
      );
      expect(oil.basisQuantity(repo.data.food('oil')!), closeTo(50, 1e-9));
      final bread = await repo.logIntake(
        foodId: 'bread',
        amount: 30,
        unit: AmountUnit.ml,
      );
      expect(bread.basisQuantity(repo.data.food('bread')!), 30);
    });
  });

  group('foods', () {
    test(
      'deleting a used food archives it, an unused one is removed',
      () async {
        final repo = await _repo();
        await repo.saveFood(_food('used').copyWith(favorite: true));
        await repo.saveFood(_food('unused'));
        await repo.logIntake(foodId: 'used', amount: 50, unit: AmountUnit.g);
        expect(await repo.deleteFood('unused'), FoodDeletion.removed);
        expect(await repo.deleteFood('used'), FoodDeletion.archived);
        expect(repo.data.food('unused'), isNull);
        expect(repo.data.food('used')!.archived, isTrue);
        expect(repo.data.food('used')!.favorite, isFalse);
        expect(searchLocalFoods(repo.data, ''), isEmpty);
        expect(recentFoods(repo.data), isEmpty);
        // The diary entry is still complete.
        final day = NutritionDay.compute(repo.data, _clock.today);
        expect(day.energyKcal, 100);
      },
    );

    test('favorites', () async {
      final repo = await _repo();
      await repo.saveFood(_food('a', name: 'Zwieback'));
      await repo.saveFood(_food('b', name: 'Apfel'));
      await repo.setFavorite('a', true);
      expect(searchLocalFoods(repo.data, '').map((f) => f.id), ['a', 'b']);
      expect(
        searchLocalFoods(repo.data, '', favoritesOnly: true).map((f) => f.id),
        ['a'],
      );
    });

    test('a product from Open Food Facts is kept once and refreshed', () async {
      final repo = await _repo();
      final product = CatalogProduct(
        barcode: '0000080176800',
        name: 'Nuss-Nugat-Creme',
        brand: 'Marke',
        servingSize: 15,
        nutrients: NutrientValues()..[Nutrients.energy] = 539,
      );
      final kept = await repo.adoptProduct(product);
      expect(kept.barcode, '80176800');
      expect(kept.source, FoodSource.openFoodFacts);
      await repo.setFavorite(kept.id, true);

      final refreshed = await repo.adoptProduct(
        CatalogProduct(
          barcode: '80176800',
          name: 'Nuss-Nugat-Creme neu',
          nutrients: NutrientValues()..[Nutrients.energy] = 540,
        ),
      );
      expect(refreshed.id, kept.id);
      expect(refreshed.favorite, isTrue);
      expect(refreshed.name, 'Nuss-Nugat-Creme neu');
      expect(refreshed.servingSize, 15, reason: 'known serving is kept');
      expect(refreshed.nutrients[Nutrients.energy], 540);
      expect(repo.data.foodCount, 1);
    });
  });

  group('periods', () {
    test('refuses impossible and overlapping periods', () async {
      final repo = await _repo();
      Period p(String id, String start, [String? end]) => Period(
        id: id,
        start: Day.parse(start),
        end: end == null ? null : Day.parse(end),
        createdAt: _clock.now(),
        updatedAt: _clock.now(),
      );
      await repo.savePeriod(p('a', '2026-09-01', '2026-09-05'));
      await expectLater(
        repo.savePeriod(p('b', '2026-09-10', '2026-09-08')),
        _invalid('period_end_before_start'),
      );
      await expectLater(
        repo.savePeriod(p('b', '2026-09-05', '2026-09-07')),
        _invalid('period_overlap'),
      );
      await expectLater(
        repo.savePeriod(p('b', '2026-08-30', '2026-09-01')),
        _invalid('period_overlap'),
      );
      await expectLater(
        repo.savePeriod(p('b', '2026-06-01', '2026-09-30')),
        _invalid('period_too_long'),
      );
      // Editing a period does not collide with itself.
      await repo.savePeriod(p('a', '2026-09-02', '2026-09-06'));
      await repo.savePeriod(p('b', '2026-09-07', '2026-09-09'));
      expect(repo.data.periodCount, 2);
    });

    test(
      'flow values outside the period are dropped when it is shortened',
      () async {
        final repo = await _repo();
        final period = await repo.startPeriod(
          Day(2026, 9, 1),
          flow: FlowLevel.light,
        );
        await repo.setFlow(period.id, Day(2026, 9, 3), FlowLevel.heavy);
        await repo.setFlow(period.id, Day(2026, 9, 5), FlowLevel.spotting);
        final shortened = await repo.savePeriod(
          repo.data.period(period.id)!.copyWith(end: Day(2026, 9, 4)),
        );
        expect(shortened.flow.keys, [Day(2026, 9, 1), Day(2026, 9, 3)]);
        final cleared = await repo.setFlow(period.id, Day(2026, 9, 3), null);
        expect(cleared.flow.keys, [Day(2026, 9, 1)]);
      },
    );

    test(
      'an open period runs for 14 days at most and stops before the next',
      () async {
        final repo = await _repo();
        final open = await repo.startPeriod(Day(2026, 8, 1));
        final data = repo.data;
        expect(data.periodOn(Day(2026, 8, 3), Day(2026, 8, 3))?.id, open.id);
        expect(
          data.periodOn(Day(2026, 8, 5), Day(2026, 8, 3)),
          isNull,
          reason: 'not beyond the viewing day',
        );
        expect(data.periodOn(Day(2026, 8, 14), Day(2026, 9, 23))?.id, open.id);
        expect(data.periodOn(Day(2026, 8, 15), Day(2026, 9, 23)), isNull);
        await repo.startPeriod(Day(2026, 8, 10));
        expect(
          repo.data.periodOn(Day(2026, 8, 9), Day(2026, 9, 23))?.id,
          open.id,
        );
        expect(
          repo.data.periodOn(Day(2026, 8, 10), Day(2026, 9, 23))?.id,
          isNot(open.id),
        );
      },
    );

    test('an empty cycle day record removes the day', () async {
      final repo = await _repo();
      await repo.saveCycleDay(Day(2026, 9, 2), spotting: true, note: '  x ');
      expect(repo.data.cycleDay(Day(2026, 9, 2))!.note, 'x');
      await repo.saveCycleDay(Day(2026, 9, 2), spotting: false, note: ' ');
      expect(repo.data.cycleDayCount, 0);
    });
  });

  test('value ranges are enforced', () async {
    final repo = await _repo();
    await expectLater(repo.addWater(0), _invalid('amount_invalid'));
    await expectLater(repo.addCaffeine(6000), _invalid('amount_invalid'));
    await expectLater(
      repo.addWeight(Day(2026, 9, 1), 0.2),
      _invalid('weight_invalid'),
    );
    await expectLater(repo.addSymptom(' ', 3), _invalid('name_required'));
    await expectLater(repo.addSymptom('x', 11), _invalid('intensity_invalid'));
    expect(repo.data.isEmpty, isTrue);
  });

  test('symptom names group without regard to case and spacing', () async {
    final repo = await _repo();
    await repo.addSymptom(
      'Kopfschmerzen',
      3,
      at: LocalDateTime(Day(2026, 9, 20), 8, 0),
    );
    await repo.addSymptom(
      'kopfschmerzen ',
      5,
      at: LocalDateTime(Day(2026, 9, 21), 8, 0),
    );
    await repo.addSymptom(
      'Übelkeit',
      2,
      at: LocalDateTime(Day(2026, 9, 19), 8, 0),
    );
    final names = symptomNames(repo.data);
    expect(names.map((n) => (n.display, n.count)), [
      ('kopfschmerzen', 2),
      ('Übelkeit', 1),
    ]);
    final series = symptomSeries(
      repo.data,
      names.first.key,
      Day(2026, 9, 19),
      Day(2026, 9, 21),
    );
    expect(series.map((p) => p.value), [null, 3.0, 5.0]);
  });
}
