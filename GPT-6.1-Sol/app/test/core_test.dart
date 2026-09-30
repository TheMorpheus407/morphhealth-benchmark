import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphhealth/core/contract.dart';
import 'package:morphhealth/core/engine.dart';
import 'package:morphhealth/core/food_api.dart';
import 'package:morphhealth/core/model.dart';
import 'package:morphhealth/core/nutrients.dart';
import 'package:morphhealth/core/storage.dart';

Json allFood({String id = 'complete', String base = 'g', double? density}) => {
  'id': id,
  'name': 'Vollständig',
  'source': 'custom',
  'base_unit': base,
  'serving_size': 40,
  'grams_per_ml': density,
  'nutrients': {
    for (var i = 0; i < nutrients.length; i++) nutrients[i].id: i + 1,
  },
};
Json consume(Json f, String id, double amount, String unit) => {
  'id': id,
  'at': '2026-09-20T08:00:00',
  'food_id': f['id'],
  'food': f,
  'amount': amount,
  'unit': unit,
  'meal': 'breakfast',
};

void main() {
  late Directory dir;
  late VaultStore store;
  setUp(() async {
    dir = await Directory('.dart_tool').createTemp('mh-core-');
    store = VaultStore(dir, List.generate(32, (i) => i));
  });
  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });
  HealthEngine engine(HealthData data) => HealthEngine(
    store,
    HealthData.import(data.export(DateTime(2026, 9, 20))),
    clock: BusinessClock(DateTime(2026, 9, 20, 12)),
  );

  test(
    'all 31 nutrients scale in g, ml and servings; missing is distinct from zero',
    () {
      expect(nutrients.length, 31);
      final d = HealthData.empty(), food = allFood(density: 1.2);
      d['foods'].add(food);
      d['consumption'].addAll([
        consume(food, 'a', 50, 'g'),
        consume(food, 'b', 2, 'portion'),
        consume(food, 'c', 100, 'ml'),
      ]);
      final partial = allFood(id: 'partial');
      partial['nutrients'] = {'calories': 0};
      d['foods'].add(partial);
      d['consumption'].add(consume(partial, 'd', 100, 'g'));
      d['drinks'].addAll([
        {
          'id': 'water',
          'at': '2026-09-20T10:00:00',
          'kind': 'water',
          'amount': 500,
        },
        {
          'id': 'coffee',
          'at': '2026-09-20T10:10:00',
          'kind': 'caffeine',
          'amount': 80,
        },
      ]);
      final day = engine(d).nutritionDay('2026-09-20');
      for (var i = 0; i < nutrients.length; i++) {
        final n = nutrients[i];
        expect(
          day['nutrients'][n.id],
          closeTo((i + 1) * 2.5 + (n.id == 'caffeine' ? 80 : 0), 1e-9),
        );
        expect(day['known_food_count'][n.id], n.id == 'calories' ? 4 : 3);
      }
      expect(day['water_ml'], 500);
      expect(day['additional_caffeine_mg'], 80);
      expect(day['incomplete_nutrients'], contains('vitamin_b7'));
      expect(day['incomplete_nutrients'], isNot(contains('calories')));
      expect(
        engine(d).nutritionDay('2026-09-19')['nutrients']['calories'],
        isNull,
      );
      final liquid = allFood(base: 'ml', density: 1.2);
      expect(baseQuantity(liquid, 120, 'g'), 100);
      expect(() => baseQuantity(allFood(), 50, 'ml'), throwsFormatException);
    },
  );
  test(
    'food corrections do not change old snapshots; updates invalidate day index',
    () async {
      final d = HealthData.empty(), f = allFood();
      d['foods'].add(f);
      d['consumption'].add(consume(f, 'e', 100, 'g'));
      final e = engine(d);
      expect(e.nutritionDay('2026-09-20')['nutrients']['protein'], 2);
      await e.change((d) => d['foods'].first['nutrients']['protein'] = 99);
      expect(e.nutritionDay('2026-09-20')['nutrients']['protein'], 2);
      await e.change((d) => d['consumption'].first['amount'] = 200);
      expect(e.nutritionDay('2026-09-20')['nutrients']['protein'], 4);
      await e.change((d) => d['consumption'].clear());
      expect(e.nutritionDay('2026-09-20')['food_count'], 0);
    },
  );
  test(
    'strict import rejects invalid data without changing encrypted live data',
    () async {
      final e = engine(HealthData.empty());
      await e.replace(exampleDocument());
      final before = await store.file.readAsBytes();
      for (final invalid in [
        {...exampleDocument(), 'version': 2},
        {
          ...exampleDocument(),
          'symptoms': [
            {
              'id': 'bad',
              'at': '2026-09-20T24:00:00',
              'name': 'Pain',
              'intensity': 11,
            },
          ],
        },
        {
          ...exampleDocument(),
          'weights': [
            {'id': 'bad', 'date': '2026-02-30', 'kg': 70},
          ],
        },
        {
          ...exampleDocument(),
          'periods': [
            {
              'id': 'a',
              'start': '2026-09-20',
              'end': null,
              'strength': 'medium',
            },
            {
              'id': 'b',
              'start': '2026-09-21',
              'end': null,
              'strength': 'light',
            },
          ],
        },
      ]) {
        await expectLater(e.replace(invalid), throwsFormatException);
        expect(await store.file.readAsBytes(), before);
      }
      expect(e.data['foods'].length, 1);
    },
  );
  test(
    'personal median, variability and past-window handling without future leakage',
    () {
      final d = HealthData.empty();
      final starts = [
        '2026-01-01',
        '2026-01-29',
        '2026-02-27',
        '2026-03-28',
        '2026-04-25',
        '2026-05-23',
        '2026-06-20',
        '2026-07-20',
        '2026-08-18',
      ];
      for (var i = 0; i < starts.length; i++) {
        d['periods'].add({
          'id': 'p$i',
          'start': starts[i],
          'end': addDays(starts[i], 4),
          'strength': 'medium',
        });
      }
      d['periods'].add({
        'id': 'spot',
        'start': '2026-09-01',
        'end': '2026-09-02',
        'strength': 'spotting',
      });
      d['periods'].add({
        'id': 'future',
        'start': '2026-10-01',
        'end': '2026-10-04',
        'strength': 'light',
      });
      final e = engine(d), f = e.cycleForecast('2026-09-20');
      expect(f['sample_count'], 6);
      expect(f['intervals_days'], [29, 28, 28, 28, 30, 29]);
      expect(f['median_cycle_days'], 28.5);
      expect(f['predicted_start'], '2026-09-16');
      expect(f['window_start'], '2026-09-14');
      expect(f['window_end'], '2026-09-18');
      expect(f['status'], 'past_window');
      expect(f['latest_start'], '2026-08-18');
      expect(e.cycleForecast('2026-01-15')['predicted_start'], isNull);
      expect(e.cycleForecast('2026-02-01')['variability'], 'limited_history');
      e.data.settings['cycle_prediction'] = false;
      expect(e.cycleForecast('2026-09-20')['predicted_start'], isNull);
      expect(e.cycleForecast('2026-09-20')['status'], 'journal_only');
    },
  );
  test(
    'daily bleeding overrides ranges, including explicit none, without creating starts',
    () {
      final d = HealthData.empty();
      d['periods'].add({
        'id': 'p',
        'start': '2026-09-18',
        'end': '2026-09-22',
        'strength': 'medium',
      });
      d['bleeding'].add({
        'id': 'b',
        'date': '2026-09-20',
        'strength': 'none',
        'note': 'Ended early',
      });
      final e = engine(d);
      expect(e.bleedingOn('2026-09-19')!['strength'], 'medium');
      expect(e.bleedingOn('2026-09-20')!['strength'], 'none');
      expect(e.cycleForecast('2026-09-20')['recorded_starts'], 1);
      // An unfinished period records the elapsed days, not future bleeding.
      e.data['periods'].first['end'] = null;
      expect(e.bleedingOn('2026-09-19')!['strength'], 'medium');
      expect(e.bleedingOn('2026-09-21'), isNull);
      expect(e.cycleForecast('2026-09-21')['recorded_period'], isNull);
    },
  );
  test(
    'encrypted file reload and authenticated tamper/wrong-key rejection',
    () async {
      final d = HealthData.import(exampleDocument());
      await store.write(d);
      final raw = await store.file.readAsString();
      expect(raw, isNot(contains('Haferflocken')));
      expect(raw, isNot(contains('Kopfschmerz')));
      expect((await store.read())['symptoms'].first['intensity'], 3);
      await expectLater(
        VaultStore(dir, List.filled(32, 255)).read(),
        throwsFormatException,
      );
      final envelope = jsonDecode(raw);
      envelope['ciphertext'] = base64Encode([
        1,
        ...base64Decode(envelope['ciphertext']).skip(1),
      ]);
      await store.file.writeAsString(jsonEncode(envelope));
      await expectLater(store.read(), throwsFormatException);
    },
  );
  test(
    'passphrase backup restores on a new installation and authenticates metadata',
    () async {
      final document = exampleDocument();
      const pass = 'separate correct horse battery';
      final backup = await createBackup(document, pass);
      expect(jsonEncode(backup), isNot(contains('Kopfschmerz')));
      final recovered = await restoreBackup(backup, pass);
      final fresh = await Directory('.dart_tool').createTemp('mh-fresh-');
      try {
        final target = VaultStore(fresh, List.filled(32, 77));
        await target.write(recovered);
        expect((await target.read())['periods'].length, 3);
        expect(recovered['foods'].first['nutrients']['protein'], 13);
        await expectLater(
          restoreBackup(backup, 'wrong passphrase'),
          throwsFormatException,
        );
        final changed = {...backup, 'cipher': 'AES-128-GCM'};
        await expectLater(restoreBackup(changed, pass), throwsFormatException);
      } finally {
        await fresh.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
  test(
    'actual OFF legacy and v3.6 normalized units and complete mapping',
    () async {
      final legacy = normalizeFood(
        jsonDecode(await File('test/fixtures/off-legacy.json').readAsString()),
      )!;
      final v3 = normalizeFood(
        jsonDecode(
          await File('test/fixtures/off-v3.json').readAsString(),
        )['product'],
      )!;
      for (final f in [legacy, v3]) {
        expect(f['nutrients']['calcium'], 120);
        expect(f['nutrients']['vitamin_d'], .75);
        expect(f['nutrients']['vitamin_b12'], closeTo(.38, 1e-10));
        expect(f['nutrients']['sodium'], 150);
        expect(f['nutrients']['calories'], 14);
      }
      expect(v3['estimated'], contains('vitamin_b3'));
      final synthetic = {
        'code': '00001234',
        'product_name': 'Liquid',
        'nutrition': {
          'aggregated_set': {
            'per': '100ml',
            'nutrients': {
              for (final n in nutrients)
                n.off: {'value': n.unit == 'kcal' ? 100 : 1, 'unit': n.unit},
            },
          },
        },
      };
      final all = normalizeFood(synthetic)!;
      expect(all['base_unit'], 'ml');
      expect(all['nutrients'].values.every((v) => v != null), isTrue);
      expect(all['nutrients']['vitamin_b7'], 1);
      expect(
        () => FoodApi('http://localhost:8788', 'Test'),
        throwsFormatException,
      );
    },
  );
  test(
    'unified history filters include overlapping periods and German/English labels',
    () {
      final e = engine(HealthData.import(exampleDocument()));
      expect(e.history(areas: {'weight'}).length, 1);
      expect(e.history(q: 'kopfschmerz').single['table'], 'symptoms');
      expect(e.history(q: 'wasser').single['table'], 'drinks');
      expect(
        e
            .history(from: '2026-08-24', to: '2026-08-24', areas: {'cycle'})
            .single['record']['id'],
        'example-period-2',
      );
      expect(e.history(from: '2026-09-20', to: '2026-09-20').length, 5);
    },
  );
}
