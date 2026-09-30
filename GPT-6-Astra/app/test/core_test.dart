import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:cryptography/cryptography.dart';
import 'package:morphhealth/core/core.dart';

Json _food({
  String id = 'f',
  String basis = 'g',
  double? serving = 50,
  Json? values,
}) => validateFood({
  'id': id,
  'name': 'Test food',
  'basis': basis,
  'servingSize': serving,
  'nutrients': values ?? {'energy': 200, 'protein': 10, 'caffeine': 2},
});
Json _meal(
  String id,
  Json food, {
  num amount = 100,
  String unit = 'g',
  String at = '2026-09-17T12:30:00+02:00',
}) => validateItem('meals', {
  'id': id,
  'food': food,
  'amount': amount,
  'unit': unit,
  'at': at,
  'meal': 'lunch',
});
Json _period(
  String start, {
  String? end,
  String flow = 'medium',
  bool open = false,
}) => validateItem('periods', {
  'id': 'p-$start',
  'start': start,
  'end': open
      ? null
      : end ?? dateKey(parseDay(start).add(const Duration(days: 3))),
  'flow': flow,
});

// Independently construct the original v1 wire format, without the production
// writer. Fixed nonce/salt are test fixtures only and never used by the app.
Future<String> _legacyEnvelope(Json doc, List<int> key, {Json? kdf}) async {
  final kind = kdf == null ? 'store' : 'backup';
  final aad =
      'morphhealth-encrypted|1|$kind|AES-256-GCM${kdf == null ? '' : '|PBKDF2-HMAC-SHA256|600000|${kdf['salt']}'}';
  final box = await AesGcm.with256bits().encrypt(
    utf8.encode(jsonEncode(doc)),
    secretKey: SecretKey(key),
    nonce: List<int>.generate(12, (i) => i + 10),
    aad: utf8.encode(aad),
  );
  return jsonEncode({
    'format': 'morphhealth-encrypted',
    'version': 1,
    'kind': kind,
    'cipher': 'AES-256-GCM',
    'kdf': ?kdf,
    'nonce': base64Encode(box.nonce),
    'ciphertext': base64Encode(box.cipherText),
    'mac': base64Encode(box.mac.bytes),
  });
}

void main() {
  group('Portable schema and civil dates', () {
    test('complete example imports without lost records or nutrients', () {
      final document = exampleDocument();
      expect(validateDocument(document), document);
      expect(nutrients.length, 31);
      expect(nutrients.map((n) => n.key).toSet().length, 31);
      validatePeriodOverlaps(document['periods']);
    });
    test(
      'calendar parsing rejects normalized impossible dates and is DST safe',
      () {
        for (final date in [
          '2026-02-29',
          '2024-02-30',
          '2026-13-01',
          '2026-00-01',
          '2026-01-00',
          '0000-01-01',
          '2026-1-01',
        ]) {
          expect(() => parseDay(date), throwsA(isA<CoreException>()));
        }
        expect(dateKey(parseDay('2024-02-29')), '2024-02-29');
        expect(
          parseDay('2026-03-30').difference(parseDay('2026-03-29')).inDays,
          1,
        );
        expect(
          parseDay('2026-10-26').difference(parseDay('2026-10-25')).inDays,
          1,
        );
      },
    );
    test(
      'invalid content never normalizes dangerous values into valid data',
      () {
        final cases = <Json>[];
        var d = cloneJson(exampleDocument());
        d['version'] = 2;
        cases.add(d);
        d = cloneJson(exampleDocument());
        d['unknown'] = true;
        cases.add(d);
        d = cloneJson(exampleDocument());
        d['weights'][0]['kg'] = -1;
        cases.add(d);
        d = cloneJson(exampleDocument());
        d['weights'][0]['at'] = '2026-09-17T25:00:00';
        cases.add(d);
        d = cloneJson(exampleDocument());
        d['symptoms'][0]['intensity'] = 2.5;
        cases.add(d);
        d = cloneJson(exampleDocument());
        d['symptoms'][0]['intensity'] = 11;
        cases.add(d);
        d = cloneJson(exampleDocument());
        d['foods'][0]['nutrients']['energy'] = '200';
        cases.add(d);
        d = cloneJson(exampleDocument());
        d['foods'][0]['nutrients']['energy'] = double.nan;
        cases.add(d);
        d = cloneJson(exampleDocument());
        d['foods'][0]['nutrients']['unknown'] = 2;
        cases.add(d);
        d = cloneJson(exampleDocument());
        d['weights'].add(Map<String, dynamic>.of(d['weights'][0]));
        cases.add(d);
        d = cloneJson(exampleDocument());
        d['meals'][0]['unit'] = 'ml';
        cases.add(d);
        d = cloneJson(exampleDocument());
        d['periods'][0]['end'] = '2020-01-01';
        cases.add(d);
        for (final doc in cases) {
          expect(() => validateDocument(doc), throwsA(isA<CoreException>()));
        }
      },
    );
    test(
      'nonspotting overlap and multiple open episodes fail; spotting allowed',
      () {
        expect(
          () => validatePeriodOverlaps([
            _period('2026-01-01', open: true),
            _period('2026-02-01'),
          ]),
          throwsA(isA<CoreException>()),
        );
        expect(
          () => validatePeriodOverlaps([
            _period('2026-01-01'),
            _period('2026-01-04'),
          ]),
          throwsA(isA<CoreException>()),
        );
        validatePeriodOverlaps([
          _period('2026-01-01'),
          _period('2026-01-02', flow: 'spotting'),
          _period('2026-02-01', open: true),
        ]);
      },
    );
  });

  group('Nutrition, snapshot semantics and unknown values', () {
    test('all nutrients scale in grams, millilitres and portions', () {
      final values = {
        for (var i = 0; i < nutrients.length; i++) nutrients[i].key: i + 1.0,
      };
      final doc = emptyDocument();
      doc['meals'] = [
        _meal('g', _food(values: values), amount: 50),
        _meal('p', _food(values: values), amount: 2, unit: 'serving'),
        _meal(
          'ml',
          _food(basis: 'ml', values: values),
          amount: 150,
          unit: 'ml',
        ),
      ];
      final day = nutritionDay(doc, '2026-09-17');
      for (var i = 0; i < nutrients.length; i++) {
        expect(
          day['totals'][nutrients[i].key],
          closeTo((i + 1) * 3, 0.0000001),
        );
        expect(day['knownCounts'][nutrients[i].key], 3);
        expect(day['completeness'][nutrients[i].key], true);
      }
      expect(day['entryCount'], 3);
      expect(day['entries'][0]['totals']['energy'], 0.5);
    });
    test('unknown is not zero; partial caffeine includes explicit drinks', () {
      final doc = emptyDocument();
      doc['meals'] = [
        _meal('known', _food(values: {'energy': 0, 'caffeine': 8})),
        _meal('unknown', _food(values: {})),
      ];
      doc['drinks'] = [
        validateItem('drinks', {
          'id': 'water',
          'kind': 'water',
          'amount': 250,
          'at': '2026-09-17T13:00:00',
        }),
        validateItem('drinks', {
          'id': 'coffee',
          'kind': 'caffeine',
          'amount': 80,
          'at': '2026-09-17T13:00:00',
        }),
      ];
      final day = nutritionDay(doc, '2026-09-17');
      expect(day['totals']['energy'], 0);
      expect(day['totals']['protein'], null);
      expect(day['knownCounts']['energy'], 1);
      expect(day['completeness']['energy'], false);
      expect(day['caffeineMg'], 88);
      expect(day['extraCaffeineMg'], 80);
      expect(day['waterMl'], 250);
      final empty = nutritionDay(doc, '2026-09-18');
      expect(empty['caffeineMg'], null);
      expect(empty['waterMl'], 0);
      expect(empty['completeness']['energy'], null);
    });
    test('local-calendar timestamp offsets are not moved into another day', () {
      final doc = emptyDocument();
      doc['meals'] = [
        _meal('early', _food(), at: '2026-09-17T00:05:00+14:00'),
        _meal('late', _food(), at: '2026-09-17T23:55:00-12:00'),
      ];
      expect(nutritionDay(doc, '2026-09-17')['entryCount'], 2);
      expect(nutritionDay(doc, '2026-09-16')['entryCount'], 0);
    });
    test('density is never invented and unknown servings are rejected', () {
      expect(
        () => _meal('x', _food(), unit: 'ml'),
        throwsA(isA<CoreException>()),
      );
      expect(
        () => _meal('x', _food(serving: null), unit: 'serving'),
        throwsA(isA<CoreException>()),
      );
    });
  });

  group('Personal forecast', () {
    test('no static baseline; insufficient and diary modes remain clear', () {
      final doc = emptyDocument();
      expect(cycleForecast(doc, '2026-09-17')['predictedStart'], null);
      doc['periods'] = [_period('2026-07-01'), _period('2026-08-01')];
      expect(cycleForecast(doc, '2026-09-17')['status'], 'insufficient');
      doc['settings']['cyclePredictions'] = false;
      expect(cycleForecast(doc, '2026-09-17')['status'], 'disabled');
    });
    test(
      'personal median adapts to longer history, excluding spotting/future',
      () {
        final doc = emptyDocument();
        doc['periods'] = [
          _period('2026-01-01'),
          _period('2026-02-05'),
          _period('2026-03-12'),
          _period('2026-03-20', flow: 'spotting'),
          _period('2026-05-20'),
        ];
        final result = cycleForecast(doc, '2026-03-25');
        expect(result['cycleLength'], 35);
        expect(result['predictedStart'], '2026-04-16');
        expect(result['sampleSize'], 2);
        expect(result['spottingExcluded'], 1);
        expect(result['earliest'], '2026-04-13');
        expect(result['latest'], '2026-04-19');
        expect(cycleForecast(doc, '2026-02-07')['status'], 'insufficient');
      },
    );
    test(
      'robust outlier handling reports exclusions; overdue never fabricates a cycle',
      () {
        final doc = emptyDocument();
        var date = parseDay('2025-01-01');
        final records = [_period(dateKey(date))];
        for (final interval in [28, 29, 28, 90, 27, 28]) {
          date = date.add(Duration(days: interval));
          records.add(_period(dateKey(date)));
        }
        doc['periods'] = records;
        final result = cycleForecast(
          doc,
          dateKey(date.add(const Duration(days: 5))),
        );
        expect(result['cycleLength'], 28);
        expect(result['excludedIntervals'], 1);
        expect(result['observedIntervals'], contains(90));
        final overdue = cycleForecast(
          doc,
          dateKey(date.add(const Duration(days: 80))),
        );
        expect(overdue['predictedStart'], result['predictedStart']);
        expect(overdue['overdueDays'], greaterThan(0));
        expect(overdue['explanation']['en'], contains('not assumed'));
      },
    );
    test(
      'observed irregularity widens uncertainty; future episodes do not leak',
      () {
        final regular = emptyDocument()
          ..['periods'] = [
            _period('2026-01-01'),
            _period('2026-01-29'),
            _period('2026-02-26'),
          ];
        final irregular = emptyDocument()
          ..['periods'] = [
            _period('2026-01-01'),
            _period('2026-01-21'),
            _period('2026-03-02'),
          ];
        final a = cycleForecast(regular, '2026-03-05');
        final b = cycleForecast(irregular, '2026-03-05');
        expect(
          parseDay(b['latest']).difference(parseDay(b['earliest'])).inDays,
          greaterThan(
            parseDay(a['latest']).difference(parseDay(a['earliest'])).inDays,
          ),
        );
        expect(b['confidence'], 'limited');
      },
    );
  });

  group('Open Food Facts adapter', () {
    test(
      'legacy normalized mass units cover every nutrient and distinguish zero',
      () {
        final legacy = <String, dynamic>{
          'energy-kcal_100g': 250,
          'proteins_100g': 10,
          'carbohydrates_100g': 20,
          'fat_100g': 5,
          'saturated-fat_100g': 0,
          'sugars_100g': 1,
          'fiber_100g': 2,
          'salt_100g': 0.5,
          'sodium_100g': 0.2,
          'caffeine_100g': 0.08,
          'vitamin-a_100g': 0.0008,
          'vitamin-c_100g': 0.04,
          'vitamin-d_100g': 0.000005,
          'vitamin-e_100g': 0.012,
          'vitamin-k_100g': 0.000075,
          'vitamin-b1_100g': 0.0011,
          'vitamin-b2_100g': 0.0014,
          'vitamin-pp_100g': 0.016,
          'pantothenic-acid_100g': 0.006,
          'vitamin-b6_100g': 0.0014,
          'biotin_100g': 0.00005,
          'vitamin-b9_100g': 0.0002,
          'vitamin-b12_100g': 0.0000025,
          'calcium_100g': 0.12,
          'iron_100g': 0.014,
          'magnesium_100g': 0.375,
          'potassium_100g': 2,
          'zinc_100g': 0.01,
          'selenium_100g': 0.000055,
          'iodine_100g': 0.00015,
          'phosphorus_100g': 0.7,
          'iron_unit': 'mg',
        };
        final mapped = mapOffProduct({
          'code': '12345678',
          'product_name': 'Complete',
          'nutriments': legacy,
        });
        final n = mapped['nutrients'];
        expect(n.values.where((v) => v == null), isEmpty);
        expect(n['saturatedFat'], 0);
        expect(n['calcium'], closeTo(120, 0.00001));
        expect(n['iron'], closeTo(14, 0.00001));
        expect(n['vitaminA'], closeTo(800, 0.00001));
        expect(n['vitaminB12'], closeTo(2.5, 0.00001));
        expect(n['caffeine'], closeTo(80, 0.00001));
      },
    );
    test(
      'v3.6 structured units, 100ml basis, kJ fallback and unknown bounds',
      () {
        final mapped = mapOffProduct({
          'code': '12345678',
          'product_name_de': 'Getränk',
          'serving_quantity': 250,
          'serving_quantity_unit': 'ml',
          'nutrition': {
            'aggregated_set': {
              'preparation': 'as_sold',
              'per': '100ml',
              'nutrients': {
                'energy-kj': {'value': 418.4, 'unit': 'kJ'},
                'proteins': {'value': 1200, 'unit': 'mg'},
                'vitamin-b12': {'value': 1.5, 'unit': 'µg'},
                'calcium': {'value': 0.12, 'unit': 'g'},
                'vitamin-d': {'value': 100, 'unit': 'IU'},
                'sugars': {'value': 0.5, 'unit': 'g', 'modifier': '<'},
                'fat': {'value': 0, 'unit': 'g'},
              },
            },
          },
        });
        final n = mapped['nutrients'];
        expect(mapped['basis'], 'ml');
        expect(mapped['servingSize'], 250);
        expect(n['energy'], closeTo(100, 0.00001));
        expect(n['protein'], closeTo(1.2, 0.00001));
        expect(n['vitaminB12'], closeTo(1.5, 0.00001));
        expect(n['calcium'], closeTo(120, 0.00001));
        expect(n['vitaminD'], null);
        expect(n['sugar'], null);
        expect(n['fat'], 0);
      },
    );
    test(
      'serving nutrition scales once, incompatible package units do not become density',
      () {
        final mapped = mapOffProduct({
          'code': '1234',
          'product_quantity_unit': 'ml',
          'serving_quantity_unit': 'ml',
          'serving_quantity': 200,
          'nutrition': {
            'aggregated_set': {
              'per': 'serving',
              'per_quantity': 25,
              'per_unit': 'g',
              'nutrients': {
                'energy-kcal': {'value': 50, 'unit': 'kcal'},
              },
            },
          },
        });
        expect(mapped['nutrients']['energy'], 200);
        expect(mapped['basis'], 'g');
        expect(mapped['servingSize'], null);
      },
    );
    test('transport configuration rejects unsafe or non-origin URLs', () {
      for (final url in [
        'http://localhost',
        'https://host/path',
        'https://user:pass@host',
        'https://host?q=a',
      ]) {
        expect(
          () => FoodApi(baseUrl: url, userAgent: 'MorphHealth/test'),
          throwsA(isA<CoreException>()),
        );
      }
      FoodApi(baseUrl: 'https://localhost:8788', userAgent: 'MorphHealth/test');
    });
  });

  group('Bounded gzip decoding', () {
    test('valid data roundtrips and the exact output limit is accepted', () {
      final data = utf8.encode('A health note. ' * 2000);
      final compressed = gzip.encode(data);
      expect(decodeGzipBounded(compressed, maximumBytes: data.length), data);
      expect(
        () => decodeGzipBounded(compressed, maximumBytes: data.length - 1),
        throwsA(
          isA<CoreException>().having(
            (e) => e.code,
            'code',
            'document_too_large',
          ),
        ),
      );
    });
    test('expansion bombs and malformed compressed bytes are rejected', () {
      final bomb = gzip.encode(List<int>.filled(2 * 1024 * 1024, 65));
      expect(bomb.length, lessThan(4096));
      expect(
        () => decodeGzipBounded(bomb, maximumBytes: 8192),
        throwsA(
          isA<CoreException>().having(
            (e) => e.code,
            'code',
            'document_too_large',
          ),
        ),
      );
      expect(
        () => decodeGzipBounded([0, 1, 2, 3]),
        throwsA(
          isA<CoreException>().having(
            (e) => e.code,
            'code',
            'encrypted_data_invalid',
          ),
        ),
      );
    });
  });

  group('Authenticated local store and backups', () {
    late Directory dir;
    final key = List<int>.generate(32, (i) => i);
    final stores = <Store>[];
    setUp(() async {
      final base = Directory('build/core-tests');
      await base.create(recursive: true);
      dir = await base.createTemp('case-');
    });
    tearDown(() async {
      for (final store in stores) {
        await store.close();
      }
      stores.clear();
      if (await dir.exists()) await dir.delete(recursive: true);
    });
    Future<Store> opened([List<int>? suppliedKey]) async {
      final store = Store(dir, suppliedKey ?? key);
      stores.add(store);
      await store.open();
      return store;
    }

    test(
      'original uncompressed v1 store opens and migrates on the next commit',
      () async {
        final document = exampleDocument();
        final file = File('${dir.path}/health.mhenc');
        await file.writeAsString(await _legacyEnvelope(document, key));
        final store = await opened();
        expect(store.document, document);
        await store.updateSettings({'language': 'en'});
        expect(jsonDecode(await file.readAsString())['compression'], 'gzip');
        await store.close();
        final reopened = await opened();
        expect(reopened.document['settings']['language'], 'en');
        expect(
          nutritionDay(reopened.document, '2026-09-17')['totals']['energy'],
          185,
        );
      },
    );
    test(
      'original uncompressed v1 passphrase backup remains portable',
      () async {
        const phrase = 'legacy backup passphrase';
        final salt = List<int>.generate(16, (i) => i);
        final derived = await Pbkdf2(
          macAlgorithm: Hmac.sha256(),
          iterations: 600000,
          bits: 256,
        ).deriveKey(secretKey: SecretKey(utf8.encode(phrase)), nonce: salt);
        final legacy = await _legacyEnvelope(
          exampleDocument(),
          await derived.extractBytes(),
          kdf: {
            'name': 'PBKDF2-HMAC-SHA256',
            'iterations': 600000,
            'salt': base64Encode(salt),
          },
        );
        final restored = await decryptBackup(legacy, phrase);
        expect(restored, exampleDocument());
        final store = await opened(List<int>.filled(32, 12));
        await store.replace(restored);
        expect(
          jsonDecode(
            await File('${dir.path}/health.mhenc').readAsString(),
          )['compression'],
          'gzip',
        );
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
    test(
      'compression metadata is authenticated and unknown methods fail closed',
      () async {
        final store = await opened();
        await store.replace(exampleDocument());
        await store.close();
        final file = File('${dir.path}/health.mhenc');
        final original = await file.readAsString();
        final without = (jsonDecode(original) as Map).cast<String, dynamic>()
          ..remove('compression');
        await file.writeAsString(jsonEncode(without));
        final stripped = Store(dir, key);
        stores.add(stripped);
        await expectLater(
          stripped.open(),
          throwsA(
            isA<CoreException>().having(
              (e) => e.code,
              'code',
              'authentication_failed',
            ),
          ),
        );
        for (final unsupported in ['none', 'deflate', null]) {
          final changed = (jsonDecode(original) as Map).cast<String, dynamic>()
            ..['compression'] = unsupported;
          await file.writeAsString(jsonEncode(changed));
          final invalid = Store(dir, key);
          stores.add(invalid);
          await expectLater(
            invalid.open(),
            throwsA(
              isA<CoreException>().having(
                (e) => e.code,
                'code',
                'encrypted_data_invalid',
              ),
            ),
          );
          expect(await file.readAsString(), jsonEncode(changed));
        }
      },
    );

    test(
      'encrypted reopen preserves snapshots and failed import preserves committed data',
      () async {
        final store = await opened();
        await store.replace(exampleDocument());
        await store.put('foods', {
          ...(store.document['foods'][0] as Json),
          'name': 'Changed food',
          'nutrients': {'energy': 900},
        });
        expect(
          nutritionDay(store.document, '2026-09-17')['totals']['energy'],
          185,
        );
        final before = jsonEncode(store.document);
        final bad = cloneJson(store.document);
        bad['weights'][0]['kg'] = -7;
        expect(() => store.replace(bad), throwsA(isA<CoreException>()));
        expect(jsonEncode(store.document), before);
        final ciphertext = await File(
          '${dir.path}/health.mhenc',
        ).readAsString();
        expect(ciphertext, isNot(contains('Changed food')));
        expect(ciphertext, isNot(contains('Kopfschmerz')));
        final nonce = jsonDecode(ciphertext)['nonce'];
        await store.updateSettings({'language': 'en'});
        expect(
          jsonDecode(
            await File('${dir.path}/health.mhenc').readAsString(),
          )['nonce'],
          isNot(nonce),
        );
        await store.close();
        final reopened = await opened();
        expect(reopened.document['settings']['language'], 'en');
        expect(reopened.document['foods'][0]['name'], 'Changed food');
        expect(
          nutritionDay(reopened.document, '2026-09-17')['totals']['energy'],
          185,
        );
      },
    );
    test(
      'concurrent writes serialize without losing entries and queue recovers after rejection',
      () async {
        final store = await opened();
        await Future.wait([
          for (var i = 0; i < 30; i++)
            store.put('symptoms', {
              'id': 's-$i',
              'name': 'Tiredness',
              'at': '2026-09-17T12:00:00',
              'intensity': i % 11,
            }),
        ]);
        expect(store.document['symptoms'].length, 30);
        await store.put('periods', _period('2026-01-01', open: true));
        await expectLater(
          store.put('periods', _period('2026-02-01')),
          throwsA(isA<CoreException>()),
        );
        await store.updateSettings({'weightUnit': 'lb'});
        expect(store.document['settings']['weightUnit'], 'lb');
        expect(store.document['periods'].length, 1);
      },
    );
    test(
      'wrong key and altered ciphertext fail closed without overwriting state',
      () async {
        final store = await opened();
        await store.replace(exampleDocument());
        await store.close();
        final file = File('${dir.path}/health.mhenc');
        final original = await file.readAsString();
        final wrong = Store(dir, List.filled(32, 99));
        stores.add(wrong);
        await expectLater(
          wrong.open(),
          throwsA(
            isA<CoreException>().having(
              (e) => e.code,
              'code',
              'authentication_failed',
            ),
          ),
        );
        expect(await file.readAsString(), original);
        final encoded = (jsonDecode(original) as Map).cast<String, dynamic>();
        final bytes = base64Decode(encoded['ciphertext']);
        bytes[0] ^= 1;
        encoded['ciphertext'] = base64Encode(bytes);
        await file.writeAsString(jsonEncode(encoded));
        final tampered = Store(dir, key);
        stores.add(tampered);
        await expectLater(
          tampered.open(),
          throwsA(
            isA<CoreException>().having(
              (e) => e.code,
              'code',
              'authentication_failed',
            ),
          ),
        );
        expect(await file.readAsString(), jsonEncode(encoded));
      },
    );
    test(
      'portable encrypted backup restores under a fresh installation key; tampering detected',
      () async {
        final doc = exampleDocument();
        final watch = Stopwatch()..start();
        final backup = await encryptBackup(doc, 'long correct phrase 🔐');
        final encryptedMs = watch.elapsedMilliseconds;
        expect(backup, isNot(contains('Haferflocken')));
        expect(jsonDecode(backup)['compression'], 'gzip');
        final restored = await decryptBackup(backup, 'long correct phrase 🔐');
        expect(restored, doc);
        final fresh = await opened(List.filled(32, 77));
        await fresh.replace(restored);
        expect(
          nutritionDay(fresh.document, '2026-09-17')['totals']['energy'],
          185,
        );
        await expectLater(
          decryptBackup(backup, 'wrong secret phrase'),
          throwsA(
            isA<CoreException>().having(
              (e) => e.code,
              'code',
              'authentication_failed',
            ),
          ),
        );
        final header = (jsonDecode(backup) as Map).cast<String, dynamic>();
        header['kdf']['iterations'] = 1;
        await expectLater(
          decryptBackup(jsonEncode(header), 'long correct phrase 🔐'),
          throwsA(isA<CoreException>()),
        );
        // ignore: avoid_print
        print(
          'BACKUP: 600000 PBKDF2 iterations, encrypt ${encryptedMs}ms, entire roundtrip/wrong-key check ${watch.elapsedMilliseconds}ms',
        );
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );
    test(
      'cross-collection record limit rejects overflow before changing persistent state',
      () async {
        final doc = emptyDocument();
        doc['foods'] = [_food()];
        doc['drinks'] = [
          for (var i = 0; i < 99999; i++)
            {
              'id': 'd-$i',
              'kind': 'water',
              'amount': 1,
              'at': '2026-09-17T12:00:00',
              'note': '',
            },
        ];
        final store = await opened();
        await store.replace(doc);
        final file = File('${dir.path}/health.mhenc');
        final committedLength = await file.length();
        final committedChanged = await file.lastModified();
        await expectLater(
          store.put('weights', {
            'id': 'overflow',
            'kg': 65,
            'at': '2026-09-17T12:00:00',
          }),
          throwsA(
            isA<CoreException>().having(
              (e) => e.code,
              'code',
              'document_too_large',
            ),
          ),
        );
        expect(store.document['weights'], isEmpty);
        expect(await file.length(), committedLength);
        expect(await file.lastModified(), committedChanged);
        await store.close();
        final reopened = await opened();
        expect(reopened.document['drinks'].length, 99999);
        expect(reopened.document['foods'].length, 1);
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );

    test(
      '10,000 entries remain fast to filter, summarize, persist and reopen',
      () async {
        final doc = emptyDocument();
        final food = _food(values: {for (final n in nutrients) n.key: 1.0});
        final origin = parseDay('2020-01-01');
        doc['foods'] = [food];
        doc['meals'] = [
          for (var i = 0; i < 10000; i++)
            _meal(
              'm-$i',
              food,
              at: '${dateKey(origin.add(Duration(days: i ~/ 4)))}T12:00:00',
              amount: 100,
            ),
        ];
        final watch = Stopwatch()..start();
        for (var i = 0; i < 28; i++) {
          nutritionDay(doc, dateKey(origin.add(Duration(days: i))));
        }
        final daysMs = watch.elapsedMilliseconds;
        watch.reset();
        final rows = history(
          doc,
          from: '2022-01-01',
          to: '2024-01-01',
          area: 'nutrition',
          query: 'test',
          offset: 100,
          limit: 50,
        );
        final historyMs = watch.elapsedMilliseconds;
        expect(rows.length, 50);
        expect(history(doc, area: 'symptoms'), isEmpty);
        final store = await opened();
        watch.reset();
        await store.replace(doc);
        final saveMs = watch.elapsedMilliseconds;
        await store.close();
        watch.reset();
        final reopened = await opened();
        final openMs = watch.elapsedMilliseconds;
        expect(reopened.document['meals'].length, 10000);
        expect(
          nutritionDay(reopened.document, '2020-01-01')['totals']['energy'],
          4,
        );
        expect(daysMs, lessThan(3000));
        expect(historyMs, lessThan(2000));
        // ignore: avoid_print
        print(
          'PERFORMANCE: 10000 meals; 28 day summaries ${daysMs}ms; filtered page ${historyMs}ms; encrypted save ${saveMs}ms; reopen ${openMs}ms; bytes ${await File('${dir.path}/health.mhenc').length()}',
        );
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );
  });
}
