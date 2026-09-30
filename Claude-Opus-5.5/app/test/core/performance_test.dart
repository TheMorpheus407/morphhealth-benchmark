import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:morphhealth/core/history/history.dart';
import 'package:morphhealth/core/l10n/format.dart';
import 'package:morphhealth/core/model/enums.dart';
import 'package:morphhealth/core/portable/portable_codec.dart';
import 'package:morphhealth/core/service/repository.dart';
import 'package:morphhealth/core/util/local_date.dart';

import '../support/generator.dart';
import '../support/helpers.dart';

/// Multi-year data set with ≥ 10,000 diary entries (P06). Thresholds are
/// generous upper bounds for CI; measured times are printed.
void main() {
  setUpAll(initializeFormatting);

  test('10,000+ diary entries stay fast', () async {
    final doc = generateDataset();
    final count = diaryEntryCount(doc);
    expect(count, greaterThanOrEqualTo(10000));
    final json = jsonEncode(doc);

    final timings = <String, int>{};
    Future<T> measure<T>(String name, Future<T> Function() body) async {
      final sw = Stopwatch()..start();
      final result = await body();
      timings[name] = sw.elapsedMilliseconds;
      return result;
    }

    final (s, repo, dir) = await openService();
    await measure('decode+validate', () async => decodePortable(jsonDecode(json), now: DateTime.utc(2026)));
    final report = await measure('import (validate + encrypted snapshot)', () => s.importDocument(jsonDecode(json)));
    expect(report.diaryEntries, count);
    await repo.close();

    final reopened = await measure(
      'reopen store (decrypt + parse)',
      () => Repository.open(directory: dir, masterKey: testKey(), clock: clockAt('2026-09-23T10:00:00+02:00')),
    );
    await reopened.close();

    final (s2, repo2, _) = await openService(dir: dir);
    final day = LocalDate(2026, 9, 22);
    await measure('nutrition.day', () async => s2.nutritionDay(day).toJson());
    await measure('28-day nutrient trend', () async => s2.nutritionTrend('iron_mg', day, 28));
    await measure('cycle forecast', () async => s2.cycleForecast(day.addDays(1)));
    final index = await measure('history index build', () async => s2.historyIndex());
    expect(index.items.length, count);
    final hits = await measure('history filter (text+area+range)', () async => index.filter(
      HistoryQuery(text: 'kopf', areas: const {Area.symptoms}, from: day.addDays(-365), to: day),
    ));
    expect(hits, isNotEmpty);
    await measure('export document', () async => jsonEncode(s2.exportDocument()));
    await measure('add entry (journal append)', () => s2.addWater(day, 250));
    await repo2.close();

    // ignore: avoid_print
    print('PERF $count diary entries: ${jsonEncode(timings)}');
    expect(timings['import (validate + encrypted snapshot)']!, lessThan(5000));
    expect(timings['reopen store (decrypt + parse)']!, lessThan(5000));
    expect(timings['nutrition.day']!, lessThan(200));
    expect(timings['history filter (text+area+range)']!, lessThan(200));
    expect(timings['add entry (journal append)']!, lessThan(200));
  });
}
