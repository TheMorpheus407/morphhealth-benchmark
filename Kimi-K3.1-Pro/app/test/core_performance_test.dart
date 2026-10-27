import 'package:flutter_test/flutter_test.dart';
import 'package:morphhealth/core/history.dart';
import 'package:morphhealth/core/nutrition.dart';
import 'package:morphhealth/core/utils.dart';

import 'core_fixtures.dart';

void main() {
  test('Performance-Smoke: 10000 Intakes für Aggregation und Historie', () {
    final food = testFood();
    final entries = List.generate(
      10000,
      (index) => testFoodIntake(
        id: 'intake-${index.toString().padLeft(5, '0')}',
        occurredAt: DateTime.utc(
          2016,
          1,
          1,
          12,
        ).add(Duration(days: index % 3650)),
        notes: index.isEven ? 'Müsli mit Milch' : 'Müsli mit Joghurt',
        nutrients: const {'calories': 120, 'protein': 6},
      ),
    );
    expect(entries, hasLength(10000));
    final state = testState(foods: [food], intakes: entries);
    state.validate();

    final selected = entries[5000];
    final date = instantDateKey(selected.occurredAt);
    final expectedForDay = entries
        .where((entry) => instantDateKey(entry.occurredAt) == date)
        .toList();
    final day = summarizeNutrition(date, entries);
    expect(day.entries, hasLength(expectedForDay.length));
    expect(day.foodEntryCount, expectedForDay.length);
    expect(day.total(Nutrient.calories), expectedForDay.length * 120);
    expect(day.total(Nutrient.protein), expectedForDay.length * 6);
    expect(day.knownFoodEntries['protein'], expectedForDay.length);
    expect(day.knownFoodEntries['vitamin_a'], 0);

    final expectedHistory = entries.where((entry) {
      final entryDate = instantDateKey(entry.occurredAt);
      return entryDate.compareTo('2019-01-01') >= 0 &&
          entryDate.compareTo('2019-12-31') <= 0;
    }).toList();
    final history = searchHistory(
      state,
      query: 'joghurt',
      area: 'nutrition',
      from: '2019-01-01',
      to: '2019-12-31',
    );
    final expectedOddEntries = expectedHistory
        .where((entry) => int.parse(entry.id.substring(7)).isOdd)
        .length;
    expect(history, hasLength(expectedOddEntries));
    expect(history, isNotEmpty);
    for (var index = 1; index < history.length; index++) {
      final previous = history[index - 1];
      final current = history[index];
      final byTime = previous.sortTime.compareTo(current.sortTime);
      expect(byTime >= 0, isTrue);
      if (byTime == 0) expect(previous.id.compareTo(current.id) >= 0, isTrue);
    }
  });
}
