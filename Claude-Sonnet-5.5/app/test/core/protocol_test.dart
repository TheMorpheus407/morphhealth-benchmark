import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:morphhealth/core/core.dart';
import 'package:morphhealth/core/describe.dart';
import 'package:morphhealth/core/http.dart';
import 'package:morphhealth/core/protocol.dart';
import 'package:morphhealth/core/store.dart';
import 'package:morphhealth/core/clock.dart';

class FakeHttp implements HttpTransport {
  final List<Uri> seen = [];
  final Map<String, String> headers = {};

  @override
  Future<HttpResponse> get(Uri uri, {required Map<String, String> headers, required Duration timeout}) async {
    seen.add(uri);
    this.headers.addAll(headers);
    if (uri.path.contains('/api/v3.6/product/')) {
      final code = uri.pathSegments.last.replaceAll('.json', '');
      if (code == '0000000000000') {
        return HttpResponse(404, const {}, Uint8List.fromList(utf8.encode('{"status":"failure"}')));
      }
      return HttpResponse(
        200,
        const {},
        Uint8List.fromList(
          utf8.encode(
            jsonEncode({
              'code': code,
              'status': 'success',
              'product': {
                'code': code,
                'product_name': 'Testprodukt',
                'nutriments': {'energy-kcal_100g': 250, 'proteins_100g': 8},
              },
            }),
          ),
        ),
      );
    }
    return HttpResponse(
      200,
      const {},
      Uint8List.fromList(
        utf8.encode(
          jsonEncode({
            'count': 45,
            'page': 2,
            'page_size': 20,
            'products': [
              {
                'code': '4000540000108',
                'product_name': 'Flocken',
                'nutriments': {'energy-kcal_100g': 361},
              },
            ],
          }),
        ),
      ),
    );
  }
}

Future<Protocol> protocol({FakeHttp? fake, String? baseUrl}) async {
  final core = await MorphCore.open(
    persistence: MemoryPersistence(),
    clock: FixedClock(DateTime(2026, 9, 29, 12)),
    transport: fake ?? FakeHttp(),
    baseUrlOverride: baseUrl ?? 'https://localhost:8788',
    userAgentOverride: 'MorphHealth/test',
  );
  return Protocol(core: core);
}

void main() {
  test('describe: beschreibt Formate, Operationen und liefert ein Beispiel', () async {
    final p = await protocol();
    final r = await p.handle({'request_id': 7, 'op': 'describe'});
    expect(r['request_id'], 7);
    expect(r['ok'], isTrue);
    final d = r['data'] as Map;
    expect(
      d.keys,
      containsAll(['app', 'protocol', 'cli', 'operations', 'formats', 'example_import_document', 'example_results']),
    );
    expect(
      (d['operations'] as Map).keys,
      containsAll([
        'describe',
        'portable.export',
        'portable.import',
        'nutrition.day',
        'cycle.forecast',
        'food.search',
        'food.lookup',
      ]),
    );
    expect(((d['formats'] as Map)['nutrients'] as List).length, 31);
    // Das Beispiel funktioniert unverändert über das Protokoll.
    final imp = await p.handle({
      'request_id': 'x',
      'op': 'portable.import',
      'confirm_replace': true,
      'document': d['example_import_document'],
    });
    expect(imp['ok'], isTrue);
    final exampleDay = (d['example_results'] as Map)['nutrition.day 2026-09-28'] as Map;
    final day = await p.handle({'request_id': 1, 'op': 'nutrition.day', 'date': '2026-09-28'});
    expect(jsonEncode((day['data'] as Map)['totals']), jsonEncode(exampleDay['totals']));
  });

  test('Antwort enthält immer dieselbe request_id (beliebiger JSON-Wert)', () async {
    final p = await protocol();
    for (final id in [
      1,
      'abc',
      null,
      2.5,
      {'a': 1},
      [1, 2],
    ]) {
      final r = await p.handle({'request_id': id, 'op': 'nutrition.day', 'date': '2026-09-28'});
      expect(r['request_id'], id);
      expect(r['ok'], isTrue);
    }
  });

  test('Fehler: ungültige Anfragen, unbekannte Operation, falsche Eingaben', () async {
    final p = await protocol();
    Future<String> code(Object? req) async => ((await p.handle(req))['error'] as Map)['code'] as String;
    expect(await code('text'), 'invalid_request');
    expect(await code({'request_id': 1}), 'invalid_request');
    expect(await code({'request_id': 1, 'op': 'x.y'}), 'unknown_op');
    expect(await code({'request_id': 1, 'op': 'nutrition.day'}), 'invalid_argument');
    expect(await code({'request_id': 1, 'op': 'nutrition.day', 'date': '28.09.2026'}), 'invalid_argument');
    expect(await code({'request_id': 1, 'op': 'nutrition.day', 'date': '2026-02-30'}), 'invalid_argument');
    expect(await code({'request_id': 1, 'op': 'cycle.forecast', 'on': 5}), 'invalid_argument');
    expect(await code({'request_id': 1, 'op': 'food.search', 'q': 5}), 'invalid_argument');
    expect(await code({'request_id': 1, 'op': 'food.search', 'q': 'x', 'page': 0}), 'invalid_argument');
    expect(await code({'request_id': 1, 'op': 'food.lookup', 'barcode': '12'}), 'invalid_barcode');
    expect(await code({'request_id': 1, 'op': 'food.lookup', 'barcode': '0000000000000'}), 'not_found');
  });

  test('Export und Import verlangen ausdrückliche Bestätigung', () async {
    final p = await protocol();
    expect((await p.handle({'request_id': 1, 'op': 'portable.export'}))['error'], containsPair('code', 'ack_required'));
    expect((await p.handle({'request_id': 1, 'op': 'portable.export', 'ack_plaintext': false}))['ok'], isFalse);
    expect((await p.handle({'request_id': 1, 'op': 'portable.export', 'ack_plaintext': true}))['ok'], isTrue);
    expect(
      (await p.handle({'request_id': 1, 'op': 'portable.import', 'document': {}}))['error'],
      containsPair('code', 'confirm_required'),
    );
    expect(
      (await p.handle({'request_id': 1, 'op': 'portable.import', 'confirm_replace': true}))['error'],
      containsPair('code', 'invalid_argument'),
    );
  });

  test('Toleranzen: Dokument als JSON-Text, Datum mit Uhrzeit', () async {
    final p = await protocol();
    final doc = {
      'format': 'morphhealth-portable',
      'version': 1,
      'water_entries': [
        {'at': '2026-09-28T08:00', 'ml': 250},
      ],
    };
    final imported = await p.handle({
      'request_id': 1,
      'op': 'portable.import',
      'confirm_replace': true,
      'document': jsonEncode(doc),
    });
    expect(imported['ok'], isTrue, reason: '$imported');
    expect((imported['data'] as Map)['total_records'], 1);
    final broken = await p.handle({
      'request_id': 2,
      'op': 'portable.import',
      'confirm_replace': true,
      'document': '{kein json',
    });
    expect((broken['error'] as Map)['code'], 'invalid_argument');
    for (final date in ['2026-09-28', '2026-09-28T23:59:59+02:00', '2026-09-28 07:00']) {
      final r = await p.handle({'request_id': 3, 'op': 'nutrition.day', 'date': date});
      expect((r['data'] as Map)['water_ml'], 250, reason: date);
    }
    // Ein Wert, der weder Datum noch Zeitstempel ist, bleibt ein Fehler.
    final bad = await p.handle({'request_id': 4, 'op': 'nutrition.day', 'date': '2026-09-28x'});
    expect((bad['error'] as Map)['code'], 'invalid_argument');
  });

  test('Ungültiges Dokument: invalid_document mit Pfaden, Bestand bleibt', () async {
    final p = await protocol();
    await p.handle({
      'request_id': 1,
      'op': 'portable.import',
      'confirm_replace': true,
      'document': exampleImportDocument(),
    });
    final r = await p.handle({
      'request_id': 2,
      'op': 'portable.import',
      'confirm_replace': true,
      'document': {
        'water_entries': [
          {'at': 'x', 'ml': 0},
        ],
      },
    });
    final err = r['error'] as Map;
    expect(err['code'], 'invalid_document');
    expect(
      (err['details'] as List).map((e) => (e as Map)['path']),
      containsAll([r'$.water_entries[0].at', r'$.water_entries[0].ml']),
    );
    final day = await p.handle({'request_id': 3, 'op': 'nutrition.day', 'date': '2026-09-28'});
    expect((day['data'] as Map)['entry_count'], 3);
  });

  test('Prognose über das Protokoll entspricht der Berechnung im Kern', () async {
    final p = await protocol();
    await p.handle({
      'request_id': 1,
      'op': 'portable.import',
      'confirm_replace': true,
      'document': exampleImportDocument(),
    });
    final r = await p.handle({'request_id': 2, 'op': 'cycle.forecast', 'on': '2026-09-20'});
    final d = r['data'] as Map;
    expect(d['status'], 'predicted');
    expect(d['predicted_start'], '2026-09-28');
    expect(d['days_until_predicted'], 8);
    expect((d['explanation'] as Map).keys, containsAll(['de', 'en']));
  });

  test('Lebensmittel: Suche und Abruf nutzen Ursprung und User-Agent', () async {
    final fake = FakeHttp();
    final p = await protocol(fake: fake);
    final s = await p.handle({'request_id': 1, 'op': 'food.search', 'q': 'flocken', 'page': 2});
    expect(s['ok'], isTrue);
    final data = s['data'] as Map;
    expect(data['total'], 45);
    expect(data['has_more'], isTrue);
    expect(((data['results'] as List).first as Map)['barcode'], '4000540000108');
    final l = await p.handle({'request_id': 2, 'op': 'food.lookup', 'barcode': '4000 5400 00108'});
    expect(l['ok'], isTrue);
    expect(((l['data'] as Map)['food'] as Map)['name'], 'Testprodukt');
    expect(fake.seen.first.host, 'localhost');
    expect(fake.seen.first.path, '/cgi/search.pl');
    expect(fake.seen.last.path, '/api/v3.6/product/4000540000108.json');
    expect(fake.headers['user-agent'], 'MorphHealth/test');
  });

  test('Online-Suche ausgeschaltet: disabled; ungültiger Ursprung: invalid_base_url', () async {
    final p = await protocol();
    final c = p.core!;
    await c.db.saveSettings(c.db.settings.copyWith(onlineFood: false));
    expect(((await p.handle({'request_id': 1, 'op': 'food.search', 'q': 'x'}))['error'] as Map)['code'], 'disabled');
    final q = await protocol(baseUrl: 'http://unsicher.example');
    expect(
      ((await q.handle({'request_id': 1, 'op': 'food.search', 'q': 'x'}))['error'] as Map)['code'],
      'invalid_base_url',
    );
    // describe geht immer
    expect((await q.handle({'request_id': 1, 'op': 'describe'}))['ok'], isTrue);
  });

  test('Start mit falschem Schlüssel: alle Operationen außer describe melden den Grund', () async {
    final p = Protocol(startupError: const StoreException(StoreErrorCode.wrongKey, 'Der Schlüssel passt nicht'));
    final r = await p.handle({'request_id': 1, 'op': 'nutrition.day', 'date': '2026-09-28'});
    expect((r['error'] as Map)['code'], 'wrong_key');
    expect((await p.handle({'request_id': 2, 'op': 'describe'}))['ok'], isTrue);
    expect((await p.handle({'request_id': 3, 'op': 'nope'}))['error'], containsPair('code', 'unknown_op'));
  });

  test('describe ist reines JSON (ohne Sonderobjekte)', () async {
    final p = await protocol();
    final r = await p.handle({'request_id': 1, 'op': 'describe'});
    expect(() => jsonEncode(r), returnsNormally);
    expect(jsonEncode(r).length, greaterThan(10000));
  });
}
