import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:morphhealth/core/describe.dart';
import 'package:morphhealth/core/issues.dart';
import 'package:morphhealth/core/models.dart';
import 'package:morphhealth/core/portable.dart';

import 'helpers.dart';

Map<String, Object?> deepCopy(Object? o) => (jsonDecode(jsonEncode(o)) as Map).cast<String, Object?>();

void main() {
  test('Das Beispieldokument aus describe ist gültig und ohne Warnungen importierbar', () async {
    final core = await memoryCore();
    final report = await core.importDocument(exampleImportDocument());
    expect(report.warnings, isEmpty);
    expect(report.imported['food_entries'], 3);
    expect(report.imported['periods'], 4);
    expect(core.db.entries.byId['entry-2']!.food.name, 'Haferflocken (eigene Angabe)'); // per food_id aufgelöst
    expect(core.db.settings.language, 'de');
    expect(core.db.goals.energyKcal, 2200);
    expect(core.db.periods[2].dayFlows.length, 2);
  });

  test('Export und erneuter Import sind gleichwertig (Rundreise)', () async {
    final a = await memoryCore();
    await a.importDocument(exampleImportDocument());
    final doc1 = a.exportDocument();
    final b = await memoryCore();
    await b.importDocument(deepCopy(doc1));
    final doc2 = b.exportDocument();
    doc1.remove('exported_at');
    doc2.remove('exported_at');
    expect(jsonEncode(doc2), jsonEncode(doc1));
    expect(doc1['format'], portableFormat);
    // Der Export enthält keine gerätespezifischen Verbindungsdaten.
    expect((doc1['settings'] as Map).containsKey('food_base_url'), isFalse);
  });

  test('Import ersetzt den Bestand vollständig', () async {
    final core = await memoryCore();
    await core.importDocument(exampleImportDocument());
    await core.importDocument({
      'format': portableFormat,
      'version': 1,
      'water_entries': [
        {'at': '2026-09-01T08:00', 'ml': 100},
      ],
    });
    expect(core.db.entries.length, 0);
    expect(core.db.periods, isEmpty);
    expect(core.db.water.length, 1);
    expect(core.db.settings.language, 'de'); // ohne settings bleiben die Vorgaben
  });

  test('Fehler nennen Pfad und Grund, der Bestand bleibt unverändert', () async {
    final core = await memoryCore();
    await core.importDocument(exampleImportDocument());
    final bad = deepCopy(exampleImportDocument());
    (bad['food_entries'] as List)[1]['amount'] = -3;
    (bad['symptom_entries'] as List)[0]['intensity'] = 11;
    (bad['periods'] as List)[0]['end'] = '2026-06-01'; // vor dem Beginn
    (bad['weight_entries'] as List)[0]['at'] = 'gestern';
    Object? caught;
    try {
      await core.importDocument(bad);
    } on ValidationException catch (e) {
      caught = e;
    }
    expect(caught, isA<ValidationException>());
    final paths = (caught as ValidationException).issues.map((i) => i.path).toList();
    expect(
      paths,
      containsAll([
        r'$.food_entries[1].amount',
        r'$.symptom_entries[0].intensity',
        r'$.periods[0].end',
        r'$.weight_entries[0].at',
      ]),
    );
    expect(core.db.entries.length, 3); // unverändert
  });

  test('Eintrag ohne food und ohne passenden food_id ist ein Fehler; Portion braucht Portionsgröße', () {
    expect(
      () => parsePortable({
        'food_entries': [
          {'at': '2026-09-01T08:00', 'amount': 1, 'unit': 'g', 'food_id': 'gibt-es-nicht'},
        ],
      }),
      throwsA(isA<ValidationException>()),
    );
    expect(
      () => parsePortable({
        'food_entries': [
          {
            'at': '2026-09-01T08:00',
            'amount': 1,
            'unit': 'portion',
            'food': {
              'name': 'X',
              'nutrients': {'energy_kcal': 1},
            },
          },
        ],
      }),
      throwsA(isA<ValidationException>()),
    );
  });

  test('Doppelte IDs, falsches Format und zu neue Version werden abgewiesen', () {
    expect(
      () => parsePortable({
        'water_entries': [
          {'id': 'x', 'at': '2026-09-01T08:00', 'ml': 100},
          {'id': 'x', 'at': '2026-09-01T09:00', 'ml': 100},
        ],
      }),
      throwsA(isA<ValidationException>()),
    );
    expect(() => parsePortable({'format': 'anderes-format'}), throwsA(isA<ValidationException>()));
    expect(() => parsePortable({'format': portableFormat, 'version': 2}), throwsA(isA<ValidationException>()));
    expect(() => parsePortable([1, 2]), throwsA(isA<ValidationException>()));
    expect(() => parsePortable(null), throwsA(isA<ValidationException>()));
  });

  test('Nachsicht: Kurzschreibweisen der Nährstoffe, Zahlen als Text, Zeitzonen, fehlende IDs', () async {
    final core = await memoryCore();
    final report = await core.importDocument({
      'food_entries': [
        {
          'at': '2026-09-01T23:30:00+02:00',
          'meal': 'dinner',
          'amount': '150,5',
          'unit': 'g',
          'food': {
            'name': 'Testessen',
            'nutrients': {'kcal': 100, 'protein': '10', 'carbs': 20, 'fat': 5, 'vitamin_c_mg': 12},
          },
        },
      ],
    });
    expect(report.warnings.map((w) => w.path), ['$r.format']); // nur der Hinweis auf das fehlende Format
    final e = core.db.entries.on(day('2026-09-01')).single;
    expect(e.at.toString(), '2026-09-01T23:30:00');
    expect(e.amount, 150.5);
    expect(e.food.nutrients['energy_kcal'], 100);
    expect(e.food.nutrients['protein_g'], 10);
    expect(e.food.nutrients['carbohydrates_g'], 20);
    expect(e.id, isNotEmpty);
  });

  test('Unbekannte Felder und überschneidende Perioden ergeben Warnungen, keine Fehler', () async {
    final core = await memoryCore();
    final report = await core.importDocument({
      'format': portableFormat,
      'version': 1,
      'zusatz': 1,
      'periods': [
        {'start': '2026-09-01', 'end': '2026-09-05', 'farbe': 'rot'},
        {'start': '2026-09-04', 'end': '2026-09-08'},
      ],
    });
    expect(report.warnings.length, 3);
    expect(core.db.periods.length, 2);
  });

  test('Sehr viele Einträge werden zügig geprüft und gespeichert', () async {
    final core = await memoryCore();
    final entries = [
      for (var i = 0; i < 10000; i++)
        {
          'at': '2024-01-01T08:00:00',
          'amount': 100,
          'unit': 'g',
          'meal': 'lunch',
          'food': {
            'name': 'Essen $i',
            'nutrients': {'energy_kcal': 100},
          },
        },
    ];
    final sw = Stopwatch()..start();
    await core.importDocument({'format': portableFormat, 'version': 1, 'food_entries': entries});
    // ignore: avoid_print
    print('10000 Einträge importiert in ${sw.elapsedMilliseconds} ms (JIT)');
    expect(core.db.entries.length, 10000);
    expect(sw.elapsedMilliseconds, lessThan(15000));
  });

  test('Export ist deterministisch sortiert', () async {
    final core = await memoryCore();
    await core.importDocument(exampleImportDocument());
    final doc = core.exportDocument();
    final at = [for (final e in doc['food_entries'] as List) (e as Map)['at']];
    expect(at, [...at]..sort());
    expect(((doc['periods'] as List).first as Map)['start'], '2026-06-08');
    expect(doc['exported_at'], matches(RegExp(r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}[+-]\d{2}:\d{2}$')));
    final flow = ((doc['periods'] as List)[2] as Map)['day_flows'];
    expect(flow, {'2026-08-03': 'light', '2026-08-04': 'heavy'});
    expect(FlowLevel.values.map((f) => f.name), contains('spotting'));
  });
}

const r = r'$';
