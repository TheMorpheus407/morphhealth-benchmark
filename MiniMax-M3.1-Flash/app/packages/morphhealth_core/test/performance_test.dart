import 'dart:io';

import 'package:morphhealth_core/morphhealth_core.dart';
import 'package:test/test.dart';

/// Performance check for the requirement "a multi year daily data set with up
/// to 10.000 journal entries has to be handled smoothly".
void main() {
  test('handles 10.000 journal entries quickly', () async {
    final Directory temp =
        await Directory.systemTemp.createTemp('morphhealth_perf_test');
    final List<int> masterKey = Crypto.newMasterKey();
    final HealthRepository repository = await HealthRepository.open(
      directory: Directory('${temp.path}/data'),
      masterKey: masterKey,
    );
    await repository.load();

    final FoodItem food = FoodItem(
      id: 'f1',
      name: 'Benchmark food',
      source: FoodSource.custom,
      nutrientsPer100: const NutrientProfile(<String, double>{
        Nutrients.energyKcal: 250,
        Nutrients.protein: 10,
        Nutrients.carbohydrates: 30,
        Nutrients.fat: 8,
      }),
    );
    await repository.upsertFood(food);

    final Stopwatch write = Stopwatch()..start();
    for (int i = 0; i < 10000; i++) {
      final String date = DateMath.addDays('2020-01-01', i ~/ 4);
      await repository.upsertJournalEntry(JournalEntry(
        id: 'e$i',
        foodId: food.id,
        foodName: food.name,
        quantity: 100,
        unit: QuantityUnit.gram,
        meal: MealSlot.values[i % 4],
        date: date,
        loggedAtMs: i,
        nutrientsPer100Snapshot: food.nutrientsPer100.values,
      ));
    }
    write.stop();

    final Stopwatch load = Stopwatch()..start();
    final HealthRepository reopened = await HealthRepository.open(
      directory: Directory('${temp.path}/data'),
      masterKey: masterKey,
    );
    await reopened.load();
    load.stop();

    expect(reopened.journalEntries, hasLength(10000));

    final Stopwatch query = Stopwatch()..start();
    final DayNutrition day = NutritionService(reopened).day('2020-06-01');
    final List<HistoryItem> history =
        HistoryService(reopened).query(text: 'Benchmark');
    query.stop();

    expect(day.entries, isNotEmpty);
    expect(history, hasLength(10000));

    // The thresholds are deliberately generous; they document the measured
    // behaviour on the reference host.
    expect(write.elapsedMilliseconds, lessThan(120000));
    expect(load.elapsedMilliseconds, lessThan(20000));
    expect(query.elapsedMilliseconds, lessThan(2000));

    // ignore: avoid_print
    print('write: ${write.elapsedMilliseconds} ms, '
        'load: ${load.elapsedMilliseconds} ms, '
        'query: ${query.elapsedMilliseconds} ms');

    await reopened.close();
    await repository.close();
    await temp.delete(recursive: true);
  }, timeout: const Timeout(Duration(minutes: 10)));
}
