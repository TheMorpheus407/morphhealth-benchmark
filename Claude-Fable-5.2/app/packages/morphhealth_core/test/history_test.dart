import 'package:morphhealth_core/morphhealth_core.dart';
import 'package:morphhealth_core/src/portable/example_document.dart';
import 'package:morphhealth_core/src/testing/sample_data.dart';
import 'package:test/test.dart';

final _now = LocalDateTime.parse('2026-09-23T20:00:00+02:00');

const _labels = {
  'water': 'Wasser',
  'caffeine': 'Koffein',
  'weight': 'Gewicht',
  'period': 'Periode',
  'spotting': 'Schmierblutung',
  'meal.breakfast': 'Frühstück',
  'meal.lunch': 'Mittagessen',
  'meal.dinner': 'Abendessen',
  'meal.snack': 'Snack',
  'flow.spotting': 'Schmierblutung',
  'flow.light': 'leicht',
  'flow.medium': 'mittel',
  'flow.heavy': 'stark',
};

void main() {
  final data = AppData.fromDocument(exampleDocument(), IssueLog(), now: _now)!;
  final index = HistoryIndex.build(data, labels: _labels);

  test('lists every entry of all four areas, newest first', () {
    expect(index.items.length, data.entryCount);
    final keys = [for (final i in index.items) i.sortKey];
    final descending = List<int>.of(keys)..sort((a, b) => b.compareTo(a));
    expect(keys, orderedEquals(descending));
    expect(index.items.map((i) => i.area).toSet(), Area.values.toSet());
    expect(index.items.first.kind, HistoryKind.intake);
    expect(index.items.first.food!.name, 'Cola ohne Zucker');
  });

  test('filters by area', () {
    final cycle = index.search(areas: {Area.cycle});
    expect(cycle.map((i) => i.kind).toSet(), {
      HistoryKind.period,
      HistoryKind.cycleDay,
    });
    expect(cycle, hasLength(9));
    expect(index.search(areas: {Area.weight}), hasLength(4));
    expect(index.search(areas: {Area.symptoms}), hasLength(9));
    expect(index.search(areas: {Area.nutrition}), hasLength(7 + 5 + 2));
    expect(index.search(areas: {Area.weight, Area.symptoms}), hasLength(13));
    expect(index.search(areas: const {}), isEmpty);
  });

  test('filters by date range, inclusive on both ends', () {
    final day = index.search(from: Day(2026, 9, 22), to: Day(2026, 9, 22));
    expect(day.every((i) => i.day == Day(2026, 9, 22)), isTrue);
    expect(day, hasLength(4 + 3 + 1 + 1 + 1));
    expect(
      index
          .search(from: Day(2026, 9, 23))
          .every((i) => i.day == Day(2026, 9, 23)),
      isTrue,
    );
    expect(index.search(to: Day(2026, 3, 1)), isEmpty);
  });

  test('a period matches every range it touches', () {
    final hit = index.search(
      from: Day(2026, 9, 18),
      to: Day(2026, 9, 18),
      areas: {Area.cycle},
    );
    expect(hit.single.id, 'period-2026-09-16');
  });

  test('free text matches names, notes, labels and meals', () {
    expect(index.search(text: 'hafer').map((i) => i.id), [
      'intake-0005',
      'intake-0001',
    ]);
    expect(index.search(text: 'Frühstück'), hasLength(4));
    expect(index.search(text: 'fruhstuck'), hasLength(4));
    expect(index.search(text: 'auf brot').single.id, 'intake-0004');
    expect(index.search(text: 'wasser'), hasLength(5));
    expect(index.search(text: 'espresso').single.kind, HistoryKind.caffeine);
    expect(index.search(text: 'KRÄMPFE'), hasLength(4));
    expect(index.search(text: 'krampfe'), hasLength(4));
    expect(index.search(text: 'wärmflasche').single.kind, HistoryKind.period);
    expect(index.search(text: 'schmierblutung').map((i) => i.kind).toSet(), {
      HistoryKind.period,
      HistoryKind.cycleDay,
    });
    expect(index.search(text: 'morgens').single.kind, HistoryKind.weight);
    expect(index.search(text: 'gibtsnicht'), isEmpty);
  });

  test('umlauts may be typed as ä, a or ae', () {
    expect(foldForSearch('Müsli'), 'musli');
    expect(foldForSearch('MUESLI'), 'musli');
    expect(foldForSearch('Musli'), 'musli');
    expect(foldForSearch('Käse Größe Straße'), 'kase grosse strasse');
    expect(foldForSearch('Crème brûlée'), 'creme brulee');
    expect(index.search(text: 'kraempfe'), hasLength(4));
    expect(index.search(text: 'fruehstueck'), hasLength(4));
    expect(index.search(text: 'waermflasche').single.kind, HistoryKind.period);
    expect(index.search(text: 'muedigkeit').single.kind, HistoryKind.symptom);
    // A word that contains such a pair by itself still finds itself.
    expect(foldForSearch('Quelle'), foldForSearch('quelle'));
    expect(foldForSearch('Bauer').contains(foldForSearch('baue')), isTrue);
  });

  test('all words must match; filters combine', () {
    expect(index.search(text: 'milch frühstück'), hasLength(2));
    expect(index.search(text: 'milch snack'), isEmpty);
    expect(
      index.search(
        text: 'kopf',
        areas: {Area.symptoms},
        from: Day(2026, 9, 1),
        to: Day(2026, 9, 30),
      ),
      hasLength(1),
    );
  });

  test('without filters the complete list is returned as is', () {
    expect(identical(index.search(), index.items), isTrue);
    expect(identical(index.search(text: '   '), index.items), isTrue);
  });

  group('10,000 entries', () {
    final big = generateSampleDiary(end: Day(2026, 9, 23));

    test('the generated diary is as large as the product requirement', () {
      expect(big.entryCount, greaterThanOrEqualTo(10000));
      expect(big.dateRange!.last.daysSince(big.dateRange!.first), 999);
    });

    test('building the index and searching stay fast', () {
      final build = Stopwatch()..start();
      final idx = HistoryIndex.build(big, labels: _labels);
      build.stop();
      expect(idx.items.length, big.entryCount);

      final search = Stopwatch()..start();
      var hits = 0;
      for (var i = 0; i < 20; i++) {
        hits += idx
            .search(
              text: 'kopfschmerzen',
              areas: {Area.symptoms},
              from: Day(2025, 1, 1),
              to: Day(2026, 9, 23),
            )
            .length;
        hits += idx.search(text: 'hafer frühstück').length;
      }
      search.stop();
      expect(hits, greaterThan(0));
      // Generous limits for slow test machines; typical values are a few
      // milliseconds for the build and well below one per search.
      expect(build.elapsedMilliseconds, lessThan(1500));
      expect(search.elapsedMilliseconds / 40, lessThan(50));
    });

    test('day views, trends and forecasts stay fast', () {
      final watch = Stopwatch()..start();
      for (var i = 0; i < 28; i++) {
        NutritionDay.compute(big, Day(2026, 9, 23).addDays(-i));
      }
      nutritionSeries(
        big,
        NutritionMetric.nutrient(Nutrients.energy),
        Day(2026, 8, 27),
        Day(2026, 9, 23),
      );
      weightSeries(big, Day(2026, 8, 27), Day(2026, 9, 23));
      CycleForecast.compute(big.periods, Day(2026, 9, 23));
      symptomPatterns(big, Day(2026, 9, 23));
      recentFoods(big);
      symptomNames(big);
      watch.stop();
      expect(watch.elapsedMilliseconds, lessThan(1000));
    });
  });
}
