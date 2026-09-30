import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:morphhealth/core/cli/describe.dart';
import 'package:morphhealth/core/cli/protocol.dart';
import 'package:morphhealth/core/food/off_client.dart';
import 'package:morphhealth/core/l10n/format.dart';
import 'package:morphhealth/core/storage/encrypted_store.dart';

import '../support/helpers.dart';

MockClient fakeOff() => MockClient((request) async {
  final path = request.url.path;
  if (path == '/cgi/search.pl') {
    return http.Response.bytes(File('test/fixtures/off_search_milch.json').readAsBytesSync(), 200);
  }
  if (path == '/api/v3.6/product/4000417025005.json') {
    return http.Response.bytes(File('test/fixtures/off_product_v36_marzipan.json').readAsBytesSync(), 200);
  }
  if (path.startsWith('/api/v3.6/product/')) {
    return http.Response(File('test/fixtures/off_product_not_found.json').readAsStringSync(), 404);
  }
  return http.Response('', 500);
});

void main() {
  setUpAll(initializeFormatting);

  Future<MaintenanceProtocol> protocol({http.Client? client}) async {
    final (service, _, dir) = await openService(httpClient: client ?? fakeOff());
    return MaintenanceProtocol(
      context: ProtocolContext(
        dataDir: dir.path,
        clock: service.clock,
        clockSource: '--now',
        foodApi: FoodApiConfig('https://food.example.test', 'MorphHealthTest/1.0'),
      ),
      service: service,
    );
  }

  Future<Map<String, Object?>> call(MaintenanceProtocol p, Map<String, Object?> req) =>
      p.handleLine(jsonEncode(req));

  test('request/response envelope and errors', () async {
    final p = await protocol();
    expect(await p.handleLine('{'), {
      'request_id': null,
      'ok': false,
      'error': {'code': 'invalid_json', 'message': 'The line is not valid JSON'},
    });
    expect(((await p.handleLine('[1]'))['error'] as Map)['code'], 'invalid_request');
    expect(((await call(p, {'op': 'describe'}))['error'] as Map)['code'], 'invalid_request');
    final unknown = await call(p, {'request_id': 'x', 'op': 'foo'});
    expect(unknown['request_id'], 'x');
    expect((unknown['error'] as Map)['code'], 'unknown_op');
    final noAck = await call(p, {'request_id': 1, 'op': 'portable.export'});
    expect((noAck['error'] as Map)['code'], 'confirmation_required');
    final noConfirm = await call(p, {'request_id': 2, 'op': 'portable.import', 'document': exampleDocument()});
    expect((noConfirm['error'] as Map)['code'], 'confirmation_required');
    final badDate = await call(p, {'request_id': 3, 'op': 'nutrition.day', 'date': '2026-02-30'});
    expect((badDate['error'] as Map)['code'], 'invalid_parameter');
    final badDoc = await call(p, {'request_id': 4, 'op': 'portable.import', 'confirm_replace': true, 'document': {'format': 'x'}});
    expect((badDoc['error'] as Map)['code'], 'validation_failed');
    expect(((badDoc['error'] as Map)['details'] as Map)['errors'], isNotEmpty);
  });

  test('import, export, nutrition and forecast', () async {
    final p = await protocol();
    final describe = await call(p, {'request_id': 1, 'op': 'describe'});
    final example = (describe['data'] as Map)['example_document'];
    final imported = await call(p, {'request_id': 2, 'op': 'portable.import', 'confirm_replace': true, 'document': example});
    expect(imported['ok'], isTrue);
    expect((imported['data'] as Map)['diary_entries'], 22);

    final day = await call(p, {'request_id': 3, 'op': 'nutrition.day', 'date': '2026-09-22'});
    final data = day['data'] as Map;
    expect((data['totals'] as Map)['energy_kcal'], 578.9);
    expect((data['totals'] as Map)['protein_g'], 25.65);
    expect((data['caffeine'] as Map)['total_mg'], 143.6);
    expect((data['water'] as Map)['total_ml'], 1080.0);

    final forecast = await call(p, {'request_id': 4, 'op': 'cycle.forecast', 'on': '2026-09-23'});
    final f = forecast['data'] as Map;
    expect(f['status'], 'before_window');
    expect((f['next_period'] as Map)['expected_start'], '2026-09-26');

    final export = await call(p, {'request_id': 5, 'op': 'portable.export', 'ack_plaintext': true});
    expect(((export['data'] as Map)['food_entries'] as List), hasLength(4));

    // Export → import round trip keeps the data identical.
    final again = await call(p, {'request_id': 6, 'op': 'portable.import', 'confirm_replace': true, 'document': export['data']});
    expect(again['ok'], isTrue);
    final export2 = await call(p, {'request_id': 7, 'op': 'portable.export', 'ack_plaintext': true});
    final a = Map.of(export['data'] as Map)..remove('exported_at');
    final b = Map.of(export2['data'] as Map)..remove('exported_at');
    expect(jsonEncode(b), jsonEncode(a));
  });

  test('food search and lookup', () async {
    final p = await protocol();
    final search = await call(p, {'request_id': 's', 'op': 'food.search', 'q': 'milch', 'page': 1});
    expect(search['ok'], isTrue);
    final online = (search['data'] as Map)['online'] as Map;
    expect(online['count'], 12624);
    expect((online['products'] as List), hasLength(20));
    final lookup = await call(p, {'request_id': 'l', 'op': 'food.lookup', 'barcode': '4000417025005'});
    expect(((lookup['data'] as Map)['product'] as Map)['name'], 'Marzipan');
    final missing = await call(p, {'request_id': 'm', 'op': 'food.lookup', 'barcode': '4000000000009'});
    expect((missing['data'] as Map)['found'], isFalse);
    final invalid = await call(p, {'request_id': 'i', 'op': 'food.lookup', 'barcode': 'abc'});
    expect((invalid['error'] as Map)['code'], 'invalid_barcode');
    final emptyQ = await call(p, {'request_id': 'e', 'op': 'food.search', 'q': ' '});
    expect((emptyQ['error'] as Map)['code'], 'invalid_parameter');
  });

  test('network failures are reported with a code', () async {
    final p = await protocol(client: MockClient((_) async => throw const SocketException('offline')));
    final r = await call(p, {'request_id': 1, 'op': 'food.search', 'q': 'brot', 'page': 1});
    expect(r['ok'], isFalse);
    expect((r['error'] as Map)['code'], 'network_error');
  });

  test('store errors are reported for data operations only', () async {
    final dir = await createTempDir('proto');
    final p = MaintenanceProtocol(
      context: ProtocolContext(
        dataDir: dir.path,
        clock: clockAt('2026-09-23T10:00:00Z'),
        clockSource: 'system',
        foodApi: FoodApiConfig('https://food.example.test', 'UA'),
      ),
      storeError: StoreException(StoreErrorKind.wrongKey, 'wrong key'),
    );
    final describe = await call(p, {'request_id': 1, 'op': 'describe'});
    expect(describe['ok'], isTrue);
    expect(((describe['data'] as Map)['store'] as Map)['status'], 'store_wrong_key');
    final day = await call(p, {'request_id': 2, 'op': 'nutrition.day', 'date': '2026-09-22'});
    expect((day['error'] as Map)['code'], 'store_wrong_key');
  });
}
