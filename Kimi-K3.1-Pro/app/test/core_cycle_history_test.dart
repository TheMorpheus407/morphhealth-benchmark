import 'package:flutter_test/flutter_test.dart';
import 'package:morphhealth/core/cycle.dart';
import 'package:morphhealth/core/health.dart';
import 'package:morphhealth/core/history.dart';
import 'package:morphhealth/core/nutrition.dart';
import 'package:morphhealth/core/utils.dart';

import 'core_fixtures.dart';

void main() {
  group('CycleForecast', () {
    test(
      'median sortiert eine Kopie und behandelt gerade und ungerade Stichproben',
      () {
        final values = <num>[30, 28, 29];
        expect(median(values), 29);
        expect(values, [30, 28, 29]);
        expect(median(const [31, 28, 30, 29]), 29.5);
        expect(median(const [2.5]), 2.5);
        expect(() => median(const []), throwsArgumentError);
      },
    );

    test('ohne plausibles Startintervall ist keine Prognose verfügbar', () {
      final empty = forecastCycle(const [], '2026-03-01');
      expect(empty.available, isFalse);
      expect(empty.sampleSize, 0);
      expect(empty.cycleLengths, isEmpty);
      expect(empty.excludedIntervals, 0);
      expect(empty.predictedStart, isNull);
      expect(empty.toJson()['confidence'], 'none');
      expect(empty.toJson()['method'], contains('median'));
      final onlyOne = forecastCycle([testPeriod()], '2026-03-01');
      expect(onlyOne.available, isFalse);
      expect(onlyOne.sampleSize, 0);
      final implausible = forecastCycle(
        periodsForIntervals([14, 91]),
        '2026-12-31',
      );
      expect(implausible.available, isFalse);
      expect(implausible.excludedIntervals, 2);
      expect(implausible.sampleSize, 0);
    });

    test(
      'Median, MAD-Mindestbreite und Periodendauer bestimmen die Prognose',
      () {
        final periods = periodsForIntervals([28, 30, 29]);
        final forecast = forecastCycle(periods, '2026-12-31');
        final lastStart = parseDate(periods.last.start);
        expect(forecast.available, isTrue);
        expect(forecast.sampleSize, 3);
        expect(forecast.cycleLengths, [28, 30, 29]);
        expect(forecast.excludedIntervals, 0);
        expect(forecast.medianCycleDays, 29);
        expect(forecast.medianPeriodDays, 5);
        expect(forecast.predictedStart, dateKey(addDays(lastStart, 29)));
        expect(forecast.earliestStart, dateKey(addDays(lastStart, 27)));
        expect(forecast.latestStart, dateKey(addDays(lastStart, 31)));
        expect(forecast.predictedEnd, dateKey(addDays(lastStart, 33)));
        expect(forecast.confidence, 'low');
        expect(forecast.toJson()['explanation'], contains('15–90'));
        expect(forecast.toJson()['explanation'], contains('not a'));
      },
    );

    test('gerade Stichproben und Konfidenzstufen verwenden den Median', () {
      final even = forecastCycle(periodsForIntervals([28, 30]), '2026-12-31');
      expect(even.medianCycleDays, 29);
      expect(even.sampleSize, 2);
      expect(even.confidence, 'low');
      final one = forecastCycle(periodsForIntervals([28]), '2026-12-31');
      expect(one.confidence, 'very_low');
      final four = forecastCycle(
        periodsForIntervals([28, 28, 30, 30]),
        '2026-12-31',
      );
      expect(four.sampleSize, 4);
      expect(four.medianCycleDays, 29);
      expect(four.confidence, 'medium');
    });

    test(
      'Intervalle außerhalb 15 bis 90 Tage werden ausgeschlossen, Grenzen bleiben',
      () {
        final periods = periodsForIntervals([14, 15, 90, 91]);
        final forecast = forecastCycle(periods, '2026-12-31');
        final lastStart = parseDate(periods.last.start);
        expect(forecast.cycleLengths, [15, 90]);
        expect(forecast.excludedIntervals, 2);
        expect(forecast.medianCycleDays, 52.5);
        expect(forecast.predictedStart, dateKey(addDays(lastStart, 53)));
        expect(forecast.earliestStart, dateKey(addDays(lastStart, 23)));
        expect(forecast.latestStart, dateKey(addDays(lastStart, 83)));
      },
    );

    test('nur die sechs jüngsten plausiblen Intervalle fließen ein', () {
      final forecast = forecastCycle(
        periodsForIntervals([28, 29, 30, 31, 32, 33, 34, 120]),
        '2027-12-31',
      );
      expect(forecast.cycleLengths, [29, 30, 31, 32, 33, 34]);
      expect(forecast.sampleSize, 6);
      expect(forecast.excludedIntervals, 1);
      expect(forecast.medianCycleDays, 31.5);
    });

    test(
      'Betrachtungstag begrenzt Historie und Periodenlängen werden gefiltert',
      () {
        final periods = periodsForIntervals([28, 28]);
        final beforeSecond = forecastCycle(periods, periods.first.start);
        expect(beforeSecond.available, isFalse);
        final modified = [
          testPeriod(
            id: 'long',
            start: periods[0].start,
            end: dateKey(addDays(parseDate(periods[0].start), 30)),
          ),
          testPeriod(id: 'open', start: periods[1].start, end: null),
          testPeriod(
            id: 'normal',
            start: periods[2].start,
            end: dateKey(addDays(parseDate(periods[2].start), 3)),
          ),
        ];
        final forecast = forecastCycle(modified, '2026-12-31');
        expect(forecast.medianPeriodDays, 4);
        expect(
          forecast.predictedEnd,
          dateKey(addDays(parseDate(forecast.predictedStart!), 3)),
        );
        expect(
          () => forecastCycle(periods, '2026-02-30'),
          throwsFormatException,
        );
      },
    );

    test(
      'Startintervalle zählen Kalendertage auch über den Sommerzeitwechsel',
      () {
        final forecast = forecastCycle([
          testPeriod(id: 'before-dst', start: '2026-03-02', end: '2026-03-06'),
          testPeriod(id: 'after-dst', start: '2026-03-30', end: '2026-04-03'),
        ], '2026-04-15');
        expect(forecast.cycleLengths, [28]);
        expect(forecast.medianCycleDays, 28);
        expect(forecast.predictedStart, '2026-04-27');
      },
    );

    test(
      'Periodenlängen zählen Kalendertage auch über den Sommerzeitwechsel',
      () {
        final forecast = forecastCycle([
          testPeriod(id: 'long', start: '2026-02-25', end: '2026-03-27'),
          testPeriod(id: 'six-days', start: '2026-03-28', end: '2026-04-02'),
        ], '2026-04-15');
        expect(forecast.cycleLengths, [31]);
        expect(forecast.medianPeriodDays, 6);
        expect(
          forecast.predictedEnd,
          dateKey(addDays(parseDate(forecast.predictedStart!), 5)),
        );
      },
    );
  });

  group('searchHistory', () {
    AppState historyState() {
      final food = testFood(name: 'Müsli', brand: 'Süßwaren');
      return testState(
        foods: [food],
        intakes: [
          testFoodIntake(
            id: 'food-entry',
            foodName: food.name,
            brand: food.brand,
            occurredAt: testTimestamp(15),
            notes: 'Frühstück',
          ),
          testSimpleIntake(
            id: 'water-entry',
            occurredAt: testTimestamp(16),
            notes: 'Flasche',
          ),
        ],
        periods: [
          testPeriod(
            id: 'period-entry',
            start: '2026-01-15',
            end: '2026-01-18',
            notes: 'Periode stark',
          ),
        ],
        weights: [
          testWeight(
            id: 'weight-entry',
            date: '2026-01-16',
            notes: 'Gewicht morgens',
          ),
        ],
        symptoms: [
          testSymptom(
            id: 'symptom-entry',
            occurredAt: testTimestamp(17),
            name: 'Übelkeit',
            intensity: 6,
          ),
        ],
      );
    }

    test('kombiniert Bereiche und liefert typisierte Datensätze', () {
      final state = historyState();
      final records = searchHistory(state);
      expect(records, hasLength(5));
      expect(records.map((record) => record.id).toSet(), {
        'food-entry',
        'water-entry',
        'period-entry',
        'weight-entry',
        'symptom-entry',
      });
      expect(searchHistory(state, area: 'nutrition'), hasLength(2));
      expect(searchHistory(state, area: 'cycle').single.kind, 'period');
      expect(
        searchHistory(state, area: 'weight').single.value,
        isA<WeightEntry>(),
      );
      expect(
        searchHistory(state, area: 'symptoms').single.value,
        isA<SymptomEntry>(),
      );
      expect(searchHistory(state, area: 'missing'), isEmpty);
      final food = records.singleWhere((record) => record.id == 'food-entry');
      expect(food.area, 'nutrition');
      expect(food.kind, 'food');
      expect(food.title, 'Müsli');
      expect(food.date, instantDateKey(testTimestamp(15)));
      expect(food.value, isA<IntakeEntry>());
    });

    test(
      'Datumsfilter sind inklusive und Freitext normalisiert deutsche Schreibweise',
      () {
        final state = historyState();
        expect(
          searchHistory(state, from: '2026-01-15', to: '2026-01-15'),
          hasLength(4),
        );
        expect(
          searchHistory(state, from: '2026-01-16', to: '2026-01-16').single.id,
          'weight-entry',
        );
        expect(searchHistory(state, from: '2026-01-17'), isEmpty);
        expect(searchHistory(state, query: 'muesli').single.id, 'food-entry');
        expect(
          searchHistory(state, query: 'suesswaren').single.id,
          'food-entry',
        );
        expect(
          searchHistory(state, query: 'uebelkeit').single.id,
          'symptom-entry',
        );
        expect(searchHistory(state, query: '6').single.id, 'symptom-entry');
        expect(
          searchHistory(state, query: 'periode').single.id,
          'period-entry',
        );
        expect(
          searchHistory(state, query: 'gewicht').single.id,
          'weight-entry',
        );
        expect(
          searchHistory(state, query: 'flasche', area: 'nutrition').single.id,
          'water-entry',
        );
        expect(searchHistory(state, query: 'muesli', area: 'weight'), isEmpty);
        expect(
          () => searchHistory(state, from: '2026-02-30'),
          throwsFormatException,
        );
        expect(
          () => searchHistory(state, to: 'invalid'),
          throwsFormatException,
        );
      },
    );

    test('sortiert absteigend nach Zeit und bei Gleichstand nach ID', () {
      final state = historyState();
      final ids = searchHistory(state).map((record) => record.id).toList();
      expect(ids.first, 'weight-entry');
      expect(ids[1], 'symptom-entry');
      expect(ids[2], 'water-entry');
      final tied = testState(
        weights: [
          testWeight(id: 'a', date: '2026-01-15'),
          testWeight(id: 'b', date: '2026-01-15'),
        ],
      );
      expect(searchHistory(tied).map((record) => record.id), ['b', 'a']);
    });
  });
}

List<Period> periodsForIntervals(List<int> intervals) {
  var start = DateTime(2026, 5, 1);
  final result = <Period>[];
  for (var index = 0; index <= intervals.length; index++) {
    result.add(
      testPeriod(
        id: 'period-$index',
        start: dateKey(start),
        end: dateKey(addDays(start, 4)),
      ),
    );
    if (index < intervals.length) start = addDays(start, intervals[index]);
  }
  return result;
}
