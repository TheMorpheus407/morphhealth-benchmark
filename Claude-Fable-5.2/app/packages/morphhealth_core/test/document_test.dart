import 'dart:convert';

import 'package:morphhealth_core/morphhealth_core.dart';
import 'package:morphhealth_core/src/portable/example_document.dart';
import 'package:morphhealth_core/src/testing/sample_data.dart';
import 'package:test/test.dart';

final _now = LocalDateTime.parse('2026-09-23T20:00:00+02:00');

Map<String, dynamic> _doc([Map<String, dynamic> extra = const {}]) => {
  'format': 'morphhealth-export',
  'version': 1,
  ...extra,
};

({AppData? data, IssueLog log}) _read(Object? doc) {
  final log = IssueLog();
  var n = 0;
  final data = AppData.fromDocument(
    doc,
    log,
    now: _now,
    idFactory: () => 'generated-${++n}',
  );
  return (data: data, log: log);
}

List<String> _errorPaths(Object? doc) => [
  for (final e in _read(doc).log.errors) e.path,
];

void main() {
  group('example document', () {
    test('imports without errors or warnings', () {
      final r = _read(exampleDocument());
      expect(r.log.errors, isEmpty);
      expect(r.log.warnings, isEmpty);
      expect(r.data!.counts, {
        'foods': 5,
        'intake': 7,
        'water': 5,
        'caffeine': 2,
        'weights': 4,
        'symptoms': 9,
        'periods': 8,
        'cycle_days': 1,
      });
    });

    test('survives export → import → export unchanged', () {
      final first = exampleDocument();
      final data = _read(jsonDecode(jsonEncode(first))).data!;
      final second = data.toDocument(
        exportedAt: _now,
        appVersion: morphHealthVersion,
      );
      expect(jsonEncode(second), jsonEncode(first));
    });

    test('covers every nutrient key', () {
      final foods = exampleDocument()['foods'] as List;
      final keys = <String>{
        for (final f in foods) ...((f as Map)['nutrients'] as Map).keys.cast(),
      };
      expect(keys, {for (final n in Nutrients.all) n.key});
      expect(Nutrients.all.length, 31);
    });
  });

  test('a large generated diary survives the round trip', () {
    final data = generateSampleDiary(end: Day(2026, 9, 23), days: 120);
    final doc = jsonDecode(
      jsonEncode(
        data.toDocument(exportedAt: _now, appVersion: morphHealthVersion),
      ),
    );
    final r = _read(doc);
    expect(r.log.errors, isEmpty);
    expect(r.log.warnings, isEmpty);
    expect(r.data!.counts, data.counts);
    expect(
      jsonEncode(
        r.data!.toDocument(exportedAt: _now, appVersion: morphHealthVersion),
      ),
      jsonEncode(doc),
    );
  });

  group('minimal documents', () {
    test('an empty document gives an empty data set with defaults', () {
      final r = _read(_doc());
      expect(r.log.hasErrors, isFalse);
      expect(r.data!.isEmpty, isTrue);
      expect(r.data!.settings.language, 'de');
      expect(r.data!.settings.cyclePredictions, isTrue);
      expect(r.data!.settings.onlineFoodSearch, OnlineFoodSearch.ask);
      expect(r.data!.settings.overviewSections, Area.values.toSet());
      expect(r.data!.goals.isEmpty, isTrue);
    });

    test('ids, meal and timestamps are optional', () {
      final r = _read(
        _doc({
          'foods': [
            {
              'id': 'f',
              'name': 'Brot',
              'nutrients': {'energy_kcal': 250},
            },
          ],
          'intake': [
            {
              'food_id': 'f',
              'at': '2026-09-22T07:30',
              'amount': 50,
              'unit': 'g',
            },
            {
              'food_id': 'f',
              'at': '2026-09-22T19:15',
              'amount': 50,
              'unit': 'g',
            },
          ],
          'periods': [
            {'start': '2026-09-01', 'end': null},
          ],
        }),
      );
      expect(r.log.errors, isEmpty);
      final entries = r.data!.intakeOn(Day(2026, 9, 22));
      expect(entries.map((e) => e.meal), [Meal.breakfast, Meal.dinner]);
      expect(entries.first.id, startsWith('generated-'));
      expect(r.data!.food('f')!.basis, FoodBasis.per100g);
      expect(r.data!.food('f')!.source, FoodSource.custom);
      expect(r.data!.periodsSorted.single.end, isNull);
    });

    test('a date without time is accepted with a warning', () {
      final r = _read(
        _doc({
          'water': [
            {'at': '2026-09-22', 'amount_ml': 250},
          ],
        }),
      );
      expect(r.log.errors, isEmpty);
      expect(r.log.warnings.single.path, 'water[0].at');
      expect(r.data!.waterOn(Day(2026, 9, 22)).single.at.hhmm, '12:00');
    });

    test('unknown members are ignored with a warning', () {
      final r = _read(
        _doc({
          'mood': <Object>[],
          'weights': [
            {'date': '2026-09-01', 'weight_kg': 70, 'device': 'scale'},
          ],
        }),
      );
      expect(r.log.errors, isEmpty);
      expect(
        r.log.warnings.map((w) => w.path),
        containsAll(['mood', 'weights[0].device']),
      );
    });

    test('offsets never move an entry to another day', () {
      final r = _read(
        _doc({
          'water': [
            {'at': '2026-09-22T23:50:00Z', 'amount_ml': 100},
            {'at': '2026-09-22T00:10:00+14:00', 'amount_ml': 100},
          ],
        }),
      );
      expect(r.data!.waterOn(Day(2026, 9, 22)), hasLength(2));
    });
  });

  group('rejected documents', () {
    test('wrong root, format or version', () {
      expect(_errorPaths([1, 2]), ['']);
      expect(_errorPaths({'version': 1}), ['format']);
      expect(_errorPaths({'format': 'morphhealth-export'}), ['version']);
      expect(_errorPaths(_doc({'version': 2})), ['version']);
      expect(_errorPaths({'format': 'other', 'version': 1}), ['format']);
    });

    test('reports all problems with their paths', () {
      final paths = _errorPaths(
        _doc({
          'settings': {'language': 'fr', 'weight_unit': 'stone'},
          'goals': {'energy_kcal': -5},
          'foods': [
            {
              'id': 'a',
              'name': 'A',
              'nutrients': {'protein_g': -1},
            },
            {'id': 'a', 'name': 'Doppelt'},
            {'id': 'b'},
            'kein Objekt',
          ],
          'intake': [
            {
              'food_id': 'missing',
              'at': '2026-09-22T07:30',
              'amount': 1,
              'unit': 'g',
            },
            {'food_id': 'a', 'at': 'gestern', 'amount': 0, 'unit': 'cups'},
          ],
          'water': [
            {'at': '2026-09-22T08:00', 'amount_ml': 0},
          ],
          'caffeine': [
            {'at': '2026-09-22T08:00', 'amount_mg': '60'},
          ],
          'weights': [
            {'date': '2026-09-31', 'weight_kg': 70},
            {'date': '2026-09-01', 'weight_kg': 0.5},
          ],
          'symptoms': [
            {'name': '', 'intensity': 11, 'at': '2026-09-22T08:00'},
            {
              'name': 'Kopfschmerzen',
              'intensity': 2.5,
              'at': '2026-09-22T08:00',
            },
          ],
          'periods': [
            {'start': '2026-09-10', 'end': '2026-09-05'},
            {
              'start': '2026-08-01',
              'end': '2026-08-05',
              'flow': {'2026-08-02': 'flood'},
            },
          ],
          'cycle_days': [
            {'date': '2026-09-02', 'spotting': 'yes'},
          ],
        }),
      );
      expect(
        paths,
        containsAll([
          'settings.language',
          'settings.weight_unit',
          'goals.energy_kcal',
          'foods[0].nutrients.protein_g',
          'foods[2].name',
          'foods[3]',
          'intake[0].food_id',
          'intake[1].at',
          'intake[1].amount',
          'intake[1].unit',
          'water[0].amount_ml',
          'caffeine[0].amount_mg',
          'weights[0].date',
          'weights[1].weight_kg',
          'symptoms[0].name',
          'symptoms[0].intensity',
          'symptoms[1].intensity',
          'periods[0].end',
          'periods[1].flow.2026-08-02',
          'cycle_days[0].spotting',
        ]),
      );
    });

    test('duplicate ids and dates', () {
      expect(
        _errorPaths(
          _doc({
            'weights': [
              {'id': 'w', 'date': '2026-09-01', 'weight_kg': 70},
              {'id': 'w', 'date': '2026-09-02', 'weight_kg': 70},
            ],
            'cycle_days': [
              {'date': '2026-09-02', 'spotting': true},
              {'date': '2026-09-02', 'note': 'x'},
            ],
          }),
        ),
        ['weights[1].id', 'cycle_days[1].date'],
      );
    });

    test('overlapping periods', () {
      final r = _read(
        _doc({
          'periods': [
            {'id': 'a', 'start': '2026-09-01', 'end': '2026-09-05'},
            {'id': 'b', 'start': '2026-09-05', 'end': '2026-09-08'},
          ],
        }),
      );
      expect(r.data, isNull);
      expect(r.log.errors.single.path, 'periods[1]');
      expect(r.log.errors.single.message, contains('2026-09-01'));
    });

    test('a portion entry needs a portion size somewhere', () {
      final base = {
        'foods': [
          {'id': 'f', 'name': 'Brot', 'nutrients': <String, dynamic>{}},
        ],
        'intake': [
          {
            'food_id': 'f',
            'at': '2026-09-22T07:30',
            'amount': 2,
            'unit': 'portion',
          },
        ],
      };
      expect(_errorPaths(_doc(base)), ['intake[0].portion_size']);
      ((base['intake']! as List).first as Map)['portion_size'] = 40;
      expect(_read(_doc(base)).log.errors, isEmpty);
    });

    test('nothing is returned when there is any error', () {
      final r = _read(
        _doc({
          'weights': [
            {'date': '2026-09-01', 'weight_kg': 70},
            {'date': 'x', 'weight_kg': 70},
          ],
        }),
      );
      expect(r.data, isNull);
      expect(r.log.errorCount, 1);
    });
  });

  test('period flow outside the period is dropped with a warning', () {
    final r = _read(
      _doc({
        'periods': [
          {
            'start': '2026-09-01',
            'end': '2026-09-03',
            'flow': {'2026-09-02': 'heavy', '2026-09-09': 'light'},
          },
        ],
      }),
    );
    expect(r.log.errors, isEmpty);
    expect(r.log.warnings.single.path, 'periods[0].flow.2026-09-09');
    expect(r.data!.periodsSorted.single.flow, {
      Day(2026, 9, 2): FlowLevel.heavy,
    });
  });

  test('PortableService.decodeBytes handles BOM and invalid JSON', () {
    final bytes = [0xEF, 0xBB, 0xBF, ...utf8.encode('{"format":"x"}')];
    expect(PortableService.decodeBytes(bytes), {'format': 'x'});
    expect(
      () => PortableService.decodeBytes(utf8.encode('{nope')),
      throwsA(isA<ImportRejected>()),
    );
  });
}
