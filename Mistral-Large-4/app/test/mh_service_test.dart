// Tests für cli/mh_service.dart (Wartungszugang `mh`, SPEC P10).
//
// Die Operationen food.search/food.lookup werden über den OffClient mit
// Mock-HTTP in off_client_test.dart geprüft; hier laufen alle lokalen Ops
// gegen ein In-Memory-Repository mit festem Datum.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:morphhealth/src/cli/example_document.dart';
import 'package:morphhealth/src/cli/mh_service.dart';
import 'package:morphhealth/src/core/clock.dart';
import 'package:morphhealth/src/data/repository.dart';
import 'package:morphhealth/src/food/off_client.dart';
import 'package:morphhealth/src/model/document.dart';
import 'package:morphhealth/src/model/settings.dart';

import 'helpers.dart';

Future<MhService> makeService({MemoryStoreBackend? backend}) async {
  final MorphRepository repo = await makeRepo(backend: backend);
  final MhConfig config = MhConfig(
    dataDir: Directory('/tmp/mh-test-data'),
    keyFile: File('/tmp/mh-test-data/master.key'),
    clock: FixedClock(DateTime.utc(2026, 9, 23, 12)),
    offConfig: const OffConfig(
        baseUrl: 'https://foodapi.example', userAgent: 'MorphHealth/1.0 (test)'),
    clockSource: '--now',
    appInfo: const AppInfo(name: 'MorphHealth', version: '1.0.0+1'),
  );
  return MhService(repo, config);
}

void main() {
  group('describe', () {
    test('beschreibt App, Prozess, Formate, Ops und Beispieldokument', () async {
      final MhService service = await makeService();
      final Map<String, dynamic> res =
          await service.handleRequest(<String, dynamic>{
        'request_id': 'd1',
        'op': 'describe',
      });
      expect(res['request_id'], 'd1');
      expect(res['ok'], isTrue);
      final Map<String, dynamic> data =
          res['data'] as Map<String, dynamic>;
      expect(data['app']['name'], 'MorphHealth');
      expect(data['app']['version'], '1.0.0+1');
      expect(data['process']['clock']['source'], '--now');
      expect(data['process']['clock']['now'], '2026-09-23T12:00:00.000Z');
      expect(data['process']['data_dir'], '/tmp/mh-test-data');
      expect(data['food_api']['base_url'], 'https://foodapi.example');
      expect(data['food_api']['user_agent'], 'MorphHealth/1.0 (test)');
      expect(data['food_api']['endpoints'], hasLength(2));

      final Map<String, dynamic> formats =
          data['data_formats'] as Map<String, dynamic>;
      expect(formats['portable']['format'], 'morphhealth.portable');
      expect(formats['portable']['data_fields'], hasLength(8));
      expect(formats['portable']['nutrient_keys'], hasLength(31));
      expect(formats['store']['file'], 'morphhealth.store (im data-dir)');
      expect(formats['key_file']['length_bytes'], 32);
      expect(formats['backup']['encoding'], contains('PBKDF2'));

      final List<dynamic> ops = data['requests'] as List<dynamic>;
      expect(
          ops
              .map((dynamic o) => (o as Map<String, dynamic>)['op'])
              .toList(),
          containsAll(<String>[
            'describe',
            'portable.export',
            'portable.import',
            'nutrition.day',
            'cycle.forecast',
            'food.search',
            'food.lookup',
          ]));
      expect(data['responses'], contains('request_id'));

      // Das Beispieldokument muss importierbar sein.
      final Map<String, dynamic> example =
          data['example_document'] as Map<String, dynamic>;
      final MorphDocument doc = MorphDocument.fromPortableJson(example);
      expect(doc.foods.length, 1);
      expect(doc.nutritionEntries.length, 1);
      expect(doc.waterEntries.length, 1);
      expect(doc.caffeineEntries.length, 1);
      expect(doc.periods.length, 1);
      expect(doc.weightEntries.length, 1);
      expect(doc.symptomEntries.length, 1);
      // Und es ist identisch zur fachlichen Funktion.
      expect(example, examplePortableDocument());
    });
  });

  group('Fehlerbehandlung', () {
    test('unbekannte op → request.unknown_op', () async {
      final MhService service = await makeService();
      final Map<String, dynamic> res =
          await service.handleRequest(<String, dynamic>{
        'request_id': 42,
        'op': 'gibts.nicht',
      });
      expect(res['request_id'], 42);
      expect(res['ok'], isFalse);
      expect(res['error']['code'], 'request.unknown_op');
    });

    test('fehlende op → request.invalid', () async {
      final MhService service = await makeService();
      final Map<String, dynamic> res =
          await service.handleRequest(<String, dynamic>{'request_id': 'x'});
      expect(res['ok'], isFalse);
      expect(res['error']['code'], 'request.invalid');
    });

    test('request_id wird gespiegelt (auch null)', () async {
      final MhService service = await makeService();
      final Map<String, dynamic> res = await service
          .handleRequest(<String, dynamic>{'op': 'describe'});
      expect(res['request_id'], isNull);
      expect(res['ok'], isTrue);
    });
  });

  group('portable.export', () {
    test('ohne ack_plaintext wird abgelehnt', () async {
      final MhService service = await makeService();
      final Map<String, dynamic> res =
          await service.handleRequest(<String, dynamic>{
        'request_id': 'e1',
        'op': 'portable.export',
      });
      expect(res['ok'], isFalse);
      expect(res['error']['code'], 'export.requires_ack');
    });

    test('mit ack_plaintext wird das Dokument exportiert', () async {
      final MhService service = await makeService();
      await service.repo.addFood(makeFood(id: 'f1', name: 'Haferflocken'));
      final Map<String, dynamic> res =
          await service.handleRequest(<String, dynamic>{
        'request_id': 'e2',
        'op': 'portable.export',
        'ack_plaintext': true,
      });
      expect(res['ok'], isTrue);
      final Map<String, dynamic> data = res['data'] as Map<String, dynamic>;
      expect(data['format'], 'morphhealth.portable');
      final MorphDocument doc = MorphDocument.fromPortableJson(data);
      expect(doc.foods.single.name, 'Haferflocken');
    });
  });

  group('portable.import', () {
    test('ohne confirm_replace wird abgelehnt', () async {
      final MhService service = await makeService();
      final Map<String, dynamic> res =
          await service.handleRequest(<String, dynamic>{
        'request_id': 'i1',
        'op': 'portable.import',
        'document': examplePortableDocument(),
      });
      expect(res['ok'], isFalse);
      expect(res['error']['code'], 'import.requires_confirm');
    });

    test('mit confirm_replace ersetzt der Import den Bestand', () async {
      final MemoryStoreBackend backend = MemoryStoreBackend();
      final MhService service = await makeService(backend: backend);
      await service.repo.addFood(makeFood(id: 'alt', name: 'Alt'));
      final Map<String, dynamic> res =
          await service.handleRequest(<String, dynamic>{
        'request_id': 'i2',
        'op': 'portable.import',
        'confirm_replace': true,
        'document': examplePortableDocument(),
      });
      expect(res['ok'], isTrue);
      expect(res['data']['replaced'], isTrue);
      expect(res['data']['report']['foods'], 1);
      expect(res['data']['report']['nutrition_entries'], 1);
      expect(service.repo.foods.single.name, contains('Haferflocken'));
      // Der Import wurde persistiert (Datei-Backend wäre hier analog).
      final MorphRepository neu = await makeRepo(backend: backend);
      expect(neu.foods.single.name, contains('Haferflocken'));
      await neu.dispose();
    });

    test('ungültiges Dokument wird abgelehnt', () async {
      final MhService service = await makeService();
      final Map<String, dynamic> res =
          await service.handleRequest(<String, dynamic>{
        'request_id': 'i3',
        'op': 'portable.import',
        'confirm_replace': true,
        'document': <String, dynamic>{'format': 'falsch'},
      });
      expect(res['ok'], isFalse);
      expect(res['error']['code'], 'portable.invalid_format');
    });
  });

  group('nutrition.day', () {
    test('liefert die Tagesauswertung mit Zielen', () async {
      final MhService service = await makeService();
      await service.repo.updateSettings((AppSettings s) {
        s.goals = const Goals(waterMl: 2000, energyKcal: 2000);
        return s;
      });
      await service.repo.addNutritionEntry(makeNutritionEntry(
        foodPer100: nutrientsWith(<String, double>{'energy_kcal': 1000}),
      ));
      await service.repo.addWaterEntry(makeWaterEntry(amountMl: 1000));
      final Map<String, dynamic> res =
          await service.handleRequest(<String, dynamic>{
        'request_id': 'n1',
        'op': 'nutrition.day',
        'date': '2026-09-23',
      });
      expect(res['ok'], isTrue);
      final Map<String, dynamic> data = res['data'] as Map<String, dynamic>;
      expect(data['date'], '2026-09-23');
      expect((data['totals'] as Map<String, dynamic>)['energy_kcal'], 1000);
      expect(data['water_ml'], 1000);
      expect(data['entry_count'], 1);
      expect(data['goals'], <String, dynamic>{'water_ml': 2000, 'energy_kcal': 2000});
    });

    test('ungültiges Datum wird abgelehnt', () async {
      final MhService service = await makeService();
      final Map<String, dynamic> res =
          await service.handleRequest(<String, dynamic>{
        'request_id': 'n2',
        'op': 'nutrition.day',
        'date': '23.09.2026',
      });
      expect(res['ok'], isFalse);
      expect(res['error']['code'], 'nutrition.invalid_date');
    });
  });

  group('cycle.forecast', () {
    test('liefert Einschätzung + Erklärungen', () async {
      final MhService service = await makeService();
      await service.repo.addPeriod(makePeriod(
          id: 'p1', start: '2026-01-01', end: '2026-01-05'));
      await service.repo.addPeriod(makePeriod(
          id: 'p2', start: '2026-01-29', end: '2026-02-02'));
      final Map<String, dynamic> res =
          await service.handleRequest(<String, dynamic>{
        'request_id': 'c1',
        'op': 'cycle.forecast',
        'on': '2026-02-10',
      });
      expect(res['ok'], isTrue);
      final Map<String, dynamic> data = res['data'] as Map<String, dynamic>;
      expect(data['on'], '2026-02-10');
      expect(data['state'], 'before_next');
      expect(data['next_period_start_estimate'], '2026-02-26');
      expect(data['explanation']['de'], contains('Zyklus'));
      expect(data['explanation']['en'], contains('cycle'));
    });

    test('ungültiges Datum wird abgelehnt', () async {
      final MhService service = await makeService();
      final Map<String, dynamic> res =
          await service.handleRequest(<String, dynamic>{
        'request_id': 'c2',
        'op': 'cycle.forecast',
      });
      expect(res['ok'], isFalse);
      expect(res['error']['code'], 'cycle.invalid_date');
    });
  });

  group('food.search / food.lookup (Parameterprüfung)', () {
    test('leere Suchanfrage wird abgelehnt (ohne HTTP)', () async {
      final MhService service = await makeService();
      final Map<String, dynamic> res =
          await service.handleRequest(<String, dynamic>{
        'request_id': 'f1',
        'op': 'food.search',
        'q': '   ',
      });
      expect(res['ok'], isFalse);
      expect(res['error']['code'], 'food.invalid_query');
    });

    test('ungültige Barcode wird abgelehnt (ohne HTTP)', () async {
      final MhService service = await makeService();
      final Map<String, dynamic> res =
          await service.handleRequest(<String, dynamic>{
        'request_id': 'f2',
        'op': 'food.lookup',
        'barcode': 'abc',
      });
      expect(res['ok'], isFalse);
      expect(res['error']['code'], 'food.invalid_barcode');
    });
  });
}
