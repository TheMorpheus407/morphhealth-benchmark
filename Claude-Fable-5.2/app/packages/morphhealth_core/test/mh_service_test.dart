import 'dart:convert';

import 'package:morphhealth_core/morphhealth_core.dart';
import 'package:morphhealth_core/src/portable/example_document.dart';
import 'package:test/test.dart';

import 'off_client_test.dart' show FakeTransport;

final _clock = FixedClock(LocalDateTime.parse('2026-09-23T08:00:00+02:00'));

/// A food service without any product.
TransportResponse _emptyFoodService(Uri uri) => uri.path.contains('/product/')
    ? TransportResponse(
        404,
        const {},
        utf8.encode(
          jsonEncode({
            'status': 'failure',
            'result': {'id': 'product_not_found'},
          }),
        ),
      )
    : TransportResponse(
        200,
        const {},
        utf8.encode('{"count":0,"products":[]}'),
      );

class _Harness {
  final MemoryDataStore store = MemoryDataStore();
  final List<FakeTransport> transports = [];
  Object? openError;
  late final MhService service;

  _Harness({TransportResponse Function(Uri uri)? food}) {
    service = MhService(
      clock: _clock,
      clockIsFixed: true,
      foodBaseUrl: 'https://food.example',
      foodUserAgent: 'MorphHealth/test',
      foodClient: (languages) {
        final transport = FakeTransport([
          (uri) => (food ?? _emptyFoodService)(uri),
        ]);
        transports.add(transport);
        return FoodApiClient(
          origin: Uri.parse('https://food.example'),
          userAgent: 'MorphHealth/test',
          transport: transport,
          languages: languages,
          sleep: (_) async {},
        );
      },
      openRepository: () {
        final error = openError;
        if (error != null) throw error;
        return HealthRepository.open(store, clock: _clock);
      },
    );
  }

  Future<Map<String, dynamic>> call(Map<String, dynamic> request) async =>
      (await service.handleLine(jsonEncode(request)))!;

  Future<Map<String, dynamic>> data(Map<String, dynamic> request) async {
    final response = await call(request);
    expect(response['ok'], isTrue, reason: '${response['error']}');
    return response['data'] as Map<String, dynamic>;
  }

  Future<Map<String, dynamic>> error(Map<String, dynamic> request) async {
    final response = await call(request);
    expect(response['ok'], isFalse);
    expect(response.containsKey('data'), isFalse);
    return response['error'] as Map<String, dynamic>;
  }

  Future<void> importExample() => data({
    'request_id': 'import',
    'op': 'portable.import',
    'confirm_replace': true,
    'document': exampleDocument(),
  });
}

void main() {
  group('protocol', () {
    test('answers carry the request id unchanged', () async {
      final h = _Harness();
      expect(
        (await h.call({'request_id': 'abc', 'op': 'describe'}))['request_id'],
        'abc',
      );
      expect(
        (await h.call({'request_id': 42, 'op': 'describe'}))['request_id'],
        42,
      );
      expect(
        (await h.call({'request_id': 1.5, 'op': 'nope'}))['request_id'],
        1.5,
      );
    });

    test('every answer is one JSON line with ok and data or error', () async {
      final h = _Harness();
      final ok = await h.call({'request_id': 1, 'op': 'describe'});
      expect(ok.keys, ['request_id', 'ok', 'data']);
      expect(jsonEncode(ok).contains('\n'), isFalse);
      final failed = await h.call({'request_id': 1, 'op': 'nope'});
      expect(failed.keys, ['request_id', 'ok', 'error']);
      expect((failed['error'] as Map).keys, containsAll(['code', 'message']));
    });

    test('malformed input is answered, not fatal', () async {
      final h = _Harness();
      Future<String> code(String line) async =>
          ((await h.service.handleLine(line))!['error'] as Map)['code']
              as String;
      expect(await code('not json'), 'invalid_json');
      expect(await code('[1,2,3]'), 'invalid_json');
      expect(await code('"text"'), 'invalid_json');
      expect(await code('{"op":"describe"}'), 'invalid_request');
      expect(
        await code('{"request_id":null,"op":"describe"}'),
        'invalid_request',
      );
      expect(
        await code('{"request_id":{"a":1},"op":"describe"}'),
        'invalid_request',
      );
      expect(await code('{"request_id":1}'), 'invalid_request');
      expect(await code('{"request_id":1,"op":7}'), 'invalid_request');
      expect(
        await code('{"request_id":1,"op":"portable.delete"}'),
        'unknown_op',
      );
      // The service is still fine afterwards.
      expect((await h.call({'request_id': 2, 'op': 'describe'}))['ok'], isTrue);
    });

    test('empty lines and a byte order mark are ignored', () async {
      final h = _Harness();
      expect(await h.service.handleLine(''), isNull);
      expect(await h.service.handleLine('   \t'), isNull);
      final r = await h.service.handleLine('﻿{"request_id":1,"op":"describe"}');
      expect(r!['ok'], isTrue);
    });
  });

  group('describe', () {
    test('documents every operation, the formats and all nutrients', () async {
      final d = await _Harness().data({'request_id': 1, 'op': 'describe'});
      expect((d['operations'] as Map).keys, [
        'describe', 'portable.export', 'portable.import', 'nutrition.day',
        'cycle.forecast', 'food.search', 'food.lookup', //
      ]);
      expect(
        (d['formats'] as Map).keys,
        containsAll(['export', 'backup', 'store', 'key_file']),
      );
      expect((d['nutrients'] as List), hasLength(31));
      final current = (d['invocation'] as Map)['current'] as Map;
      expect(current['now'], '2026-09-23T08:00:00+02:00');
      expect(current['food_base_url'], 'https://food.example');
    });

    test('needs no data directory', () async {
      final h = _Harness()..openError = const StoreException('io', 'no disk');
      expect((await h.call({'request_id': 1, 'op': 'describe'}))['ok'], isTrue);
    });

    test('its example document imports as it is and its example answers are '
        'what the operations return', () async {
      final h = _Harness();
      final d = await h.data({'request_id': 1, 'op': 'describe'});
      final ops = d['operations'] as Map;
      final report = await h.data({
        'request_id': 2,
        'op': 'portable.import',
        'confirm_replace': true,
        'document': d['example_document'],
      });
      expect(report['warning_count'], 0);
      expect(
        report['counts'],
        ((ops['portable.import'] as Map)['example_response_data']
            as Map)['counts'],
      );

      final nutritionExample = ops['nutrition.day'] as Map;
      expect(
        await h.data((nutritionExample['example_request'] as Map).cast()),
        nutritionExample['example_response_data'],
      );
      final cycleExample = ops['cycle.forecast'] as Map;
      expect(
        await h.data((cycleExample['example_request'] as Map).cast()),
        cycleExample['example_response_data'],
      );
    });

    test('every request of the example session is accepted', () async {
      final h = _Harness();
      final d = await h.data({'request_id': 1, 'op': 'describe'});
      for (final raw in d['example_session'] as List) {
        final request = (raw as Map).cast<String, dynamic>();
        if (request['document'] is String) {
          request['document'] = d['example_document'];
        }
        final response = await h.call(request);
        expect(
          response['ok'],
          isTrue,
          reason: '$request → ${response['error']}',
        );
      }
    });
  });

  group('portable.export / portable.import', () {
    test('export needs the acknowledgement', () async {
      final h = _Harness();
      for (final ack in [null, false, 'true', 1]) {
        final e = await h.error({
          'request_id': 1,
          'op': 'portable.export',
          'ack_plaintext': ?ack,
        });
        expect(e['code'], 'acknowledgement_required');
      }
      final doc = await h.data({
        'request_id': 1,
        'op': 'portable.export',
        'ack_plaintext': true,
      });
      expect(doc['format'], 'morphhealth-export');
      expect(doc['version'], 1);
      expect(doc['exported_at'], '2026-09-23T08:00:00+02:00');
      expect(doc['intake'], isEmpty);
    });

    test(
      'import needs the confirmation and changes nothing without it',
      () async {
        final h = _Harness();
        await h.importExample();
        final e = await h.error({
          'request_id': 1,
          'op': 'portable.import',
          'document': {'format': 'morphhealth-export', 'version': 1},
        });
        expect(e['code'], 'confirmation_required');
        final doc = await h.data({
          'request_id': 2,
          'op': 'portable.export',
          'ack_plaintext': true,
        });
        expect(doc['intake'], hasLength(7));
      },
    );

    test('import replaces everything and reports counts', () async {
      final h = _Harness();
      await h.importExample();
      final report = await h.data({
        'request_id': 1,
        'op': 'portable.import',
        'confirm_replace': true,
        'document': {
          'format': 'morphhealth-export',
          'version': 1,
          'weights': [
            {'date': '2026-09-01', 'weight_kg': 70, 'gadget': true},
          ],
        },
      });
      expect(report['replaced'], isTrue);
      expect((report['counts'] as Map)['weights'], 1);
      expect((report['counts'] as Map)['intake'], 0);
      expect((report['previous_counts'] as Map)['intake'], 7);
      expect(report['entries_total'], 1);
      expect(report['warning_count'], 1);
      expect(
        ((report['warnings'] as List).single as Map)['path'],
        'weights[0].gadget',
      );
      final doc = await h.data({
        'request_id': 2,
        'op': 'portable.export',
        'ack_plaintext': true,
      });
      expect(doc['foods'], isEmpty);
      expect((doc['settings'] as Map)['online_food_search'], 'ask');
    });

    test('export → import → export is stable', () async {
      final h = _Harness();
      await h.importExample();
      final first = await h.data({
        'request_id': 1,
        'op': 'portable.export',
        'ack_plaintext': true,
      });
      await h.data({
        'request_id': 2,
        'op': 'portable.import',
        'confirm_replace': true,
        'document': first,
      });
      final second = await h.data({
        'request_id': 3,
        'op': 'portable.export',
        'ack_plaintext': true,
      });
      expect(jsonEncode(second), jsonEncode(first));
    });

    test('a document passed as JSON text is accepted', () async {
      final h = _Harness();
      final report = await h.data({
        'request_id': 1,
        'op': 'portable.import',
        'confirm_replace': true,
        'document': jsonEncode(exampleDocument()),
      });
      expect((report['counts'] as Map)['periods'], 8);
    });

    test('a faulty document is rejected as a whole, with paths', () async {
      final h = _Harness();
      await h.importExample();
      final e = await h.error({
        'request_id': 1,
        'op': 'portable.import',
        'confirm_replace': true,
        'document': {
          'format': 'morphhealth-export',
          'version': 1,
          'weights': [
            {'date': '2026-09-01', 'weight_kg': 70},
            {'date': 'gestern', 'weight_kg': -1},
          ],
        },
      });
      expect(e['code'], 'import_rejected');
      final details = e['details'] as Map;
      expect(details['error_count'], 2);
      expect((details['errors'] as List).map((x) => (x as Map)['path']), [
        'weights[1].date',
        'weights[1].weight_kg',
      ]);
      // The previous data are untouched.
      final doc = await h.data({
        'request_id': 2,
        'op': 'portable.export',
        'ack_plaintext': true,
      });
      expect(doc['weights'], hasLength(4));
    });

    test('missing or malformed documents', () async {
      final h = _Harness();
      expect(
        (await h.error({
          'request_id': 1,
          'op': 'portable.import',
          'confirm_replace': true,
        }))['code'],
        'invalid_argument',
      );
      expect(
        (await h.error({
          'request_id': 1,
          'op': 'portable.import',
          'confirm_replace': true,
          'document': '{kaputt',
        }))['code'],
        'invalid_argument',
      );
      expect(
        (await h.error({
          'request_id': 1,
          'op': 'portable.import',
          'confirm_replace': true,
          'document': [1],
        }))['code'],
        'import_rejected',
      );
    });
  });

  group('nutrition.day and cycle.forecast', () {
    test('return the figures of the app', () async {
      final h = _Harness();
      await h.importExample();
      final day = await h.data({
        'request_id': 1,
        'op': 'nutrition.day',
        'date': '2026-09-22',
      });
      expect((day['totals'] as Map)['energy_kcal'], 595.9);
      expect((day['water'] as Map)['total_ml'], 1080);
      final forecast = await h.data({
        'request_id': 2,
        'op': 'cycle.forecast',
        'on': '2026-09-23',
      });
      expect((forecast['next_period'] as Map)['expected_start'], '2026-10-14');
    });

    test('the viewing day decides, not the clock', () async {
      final h = _Harness();
      await h.importExample();
      Future<Map<String, dynamic>> on(String day) =>
          h.data({'request_id': 1, 'op': 'cycle.forecast', 'on': day});
      expect((await on('2026-02-01'))['status'], 'no_data');
      expect((await on('2026-03-03'))['status'], 'insufficient_data');
      final mid = await on('2026-06-01');
      expect(mid['ignored_future_periods'], 4);
      expect((mid['next_period'] as Map)['expected_start'], '2026-06-23');
      expect((await on('2026-10-14'))['status'], 'due');
      expect((await on('2026-10-20'))['status'], 'late');
      expect((await on('2027-03-01'))['status'], 'stale');
    });

    test('a day without entries is answered with zeros', () async {
      final h = _Harness();
      final day = await h.data({
        'request_id': 1,
        'op': 'nutrition.day',
        'date': '2020-02-29',
      });
      expect(day['entry_count'], 0);
      expect((day['totals'] as Map)['energy_kcal'], 0);
    });

    test('dates are validated', () async {
      final h = _Harness();
      for (final request in [
        {'request_id': 1, 'op': 'nutrition.day'},
        {'request_id': 1, 'op': 'nutrition.day', 'date': '2026-02-30'},
        {'request_id': 1, 'op': 'nutrition.day', 'date': 20260922},
        {'request_id': 1, 'op': 'cycle.forecast', 'date': '2026-09-22'},
        {'request_id': 1, 'op': 'cycle.forecast', 'on': '22.09.2026'},
      ]) {
        final e = await h.error(request);
        expect(e['code'], 'invalid_argument', reason: '$request');
        expect((e['details'] as Map)['field'], anyOf('date', 'on'));
      }
    });
  });

  group('food.search and food.lookup', () {
    test('pass query and page to the food service', () async {
      final h = _Harness(
        food: (uri) => TransportResponse(
          200,
          const {},
          utf8.encode(
            jsonEncode({
              'count': 21,
              'page': 2,
              'page_size': 20,
              'products': [
                {
                  'code': '4000000000013',
                  'product_name': 'Creme',
                  'nutriments': {'energy-kcal_100g': 539},
                },
              ],
            }),
          ),
        ),
      );
      final page = await h.data({
        'request_id': 1,
        'op': 'food.search',
        'q': 'creme',
        'page': 2,
      });
      expect(
        h.transports.single.requests.single.query,
        startsWith(
          'search_terms=creme&search_simple=1&action=process&json=1&page=2&page_size=20',
        ),
      );
      expect(h.transports.single.closed, isTrue);
      expect(page['page'], 2);
      expect(page['page_count'], 2);
      final product = (page['products'] as List).single as Map;
      expect(product['barcode'], '4000000000013');
      expect((product['nutrients'] as Map)['energy_kcal'], 539);
      expect(product['source'], 'open_food_facts');
    });

    test('page defaults to 1; invalid arguments are refused', () async {
      final h = _Harness();
      await h.data({'request_id': 1, 'op': 'food.search', 'q': 'brot'});
      expect(h.transports.last.requests.single.query, contains('&page=1&'));
      for (final request in [
        {'request_id': 1, 'op': 'food.search'},
        {'request_id': 1, 'op': 'food.search', 'q': ''},
        {'request_id': 1, 'op': 'food.search', 'q': 'x'},
        {'request_id': 1, 'op': 'food.search', 'q': 'brot', 'page': 0},
        {'request_id': 1, 'op': 'food.search', 'q': 'brot', 'page': 'zwei'},
        {'request_id': 1, 'op': 'food.lookup'},
        {'request_id': 1, 'op': 'food.lookup', 'barcode': 'abc'},
        {'request_id': 1, 'op': 'food.lookup', 'barcode': '123'},
      ]) {
        expect(
          (await h.error(request))['code'],
          'invalid_argument',
          reason: '$request',
        );
      }
    });

    test('lookup reports found and not found', () async {
      final found = _Harness(
        food: (uri) => TransportResponse(
          200,
          const {},
          utf8.encode(
            jsonEncode({
              'status': 'success',
              'product': {'code': '4000000000013', 'product_name': 'Creme'},
            }),
          ),
        ),
      );
      final a = await found.data({
        'request_id': 1,
        'op': 'food.lookup',
        'barcode': 4000000000013,
      });
      expect(a['found'], isTrue);
      expect((a['product'] as Map)['name'], 'Creme');
      expect(
        found.transports.single.requests.single.path,
        '/api/v3.6/product/4000000000013.json',
      );

      final missing = _Harness(
        food: (uri) => TransportResponse(
          404,
          const {},
          utf8.encode(
            jsonEncode({
              'status': 'failure',
              'result': {'id': 'product_not_found'},
            }),
          ),
        ),
      );
      final b = await missing.data({
        'request_id': 1,
        'op': 'food.lookup',
        'barcode': '4000000000013',
      });
      expect(b, {
        'requested_barcode': '4000000000013',
        'found': false,
        'reason': 'product_not_found',
        'product': null,
      });
    });

    test('service failures become food_* errors', () async {
      final h = _Harness(food: (uri) => const TransportResponse(503, {}, []));
      final e = await h.error({
        'request_id': 1,
        'op': 'food.search',
        'q': 'brot',
      });
      expect(e['code'], 'food_server_error');
      expect((e['details'] as Map)['http_status'], 503);
    });

    test('an explicit "disabled" in the settings is respected', () async {
      final h = _Harness();
      await h.data({
        'request_id': 1,
        'op': 'portable.import',
        'confirm_replace': true,
        'document': {
          'format': 'morphhealth-export',
          'version': 1,
          'settings': {'online_food_search': 'disabled'},
        },
      });
      for (final request in [
        {'request_id': 2, 'op': 'food.search', 'q': 'brot'},
        {'request_id': 3, 'op': 'food.lookup', 'barcode': '4000000000013'},
      ]) {
        expect((await h.error(request))['code'], 'online_disabled');
      }
      expect(
        h.transports.expand((t) => t.requests),
        isEmpty,
        reason: 'no request may leave the process',
      );
    });

    test('lookups work even if the data directory cannot be opened', () async {
      final h = _Harness()
        ..openError = const StoreException('wrong_key', 'wrong key');
      expect(
        (await h.call({
          'request_id': 1,
          'op': 'food.search',
          'q': 'brot',
        }))['ok'],
        isTrue,
      );
    });

    test('names follow the language of the stored settings', () async {
      Map<String, dynamic> product(Uri _) => {
        'status': 'success',
        'product': {
          'code': '4000000000013',
          'product_name': 'Original',
          'product_name_de': 'Deutsch',
          'product_name_en': 'English',
        },
      };
      final h = _Harness(
        food: (uri) => TransportResponse(
          200,
          const {},
          utf8.encode(jsonEncode(product(uri))),
        ),
      );
      Future<Object?> name() async =>
          ((await h.data({
                'request_id': 1,
                'op': 'food.lookup',
                'barcode': '4000000000013',
              }))['product']
              as Map)['name'];
      expect(await name(), 'Deutsch');
      await h.data({
        'request_id': 2,
        'op': 'portable.import',
        'confirm_replace': true,
        'document': {
          'format': 'morphhealth-export',
          'version': 1,
          'settings': {'language': 'en'},
        },
      });
      expect(await name(), 'English');
    });
  });

  group('data directory problems', () {
    test('are reported per request with a store_* code', () async {
      final h = _Harness()
        ..openError = const StoreException('wrong_key', 'wrong key');
      for (final request in [
        {'request_id': 1, 'op': 'portable.export', 'ack_plaintext': true},
        {'request_id': 2, 'op': 'nutrition.day', 'date': '2026-09-22'},
        {'request_id': 3, 'op': 'cycle.forecast', 'on': '2026-09-22'},
      ]) {
        expect((await h.error(request))['code'], 'store_wrong_key');
      }
      // Once the problem is gone the next request works.
      h.openError = null;
      expect(
        (await h.call({
          'request_id': 4,
          'op': 'nutrition.day',
          'date': '2026-09-22',
        }))['ok'],
        isTrue,
      );
    });

    test('key file problems keep their own code', () async {
      final h = _Harness()
        ..openError = const MhError('key_file_invalid', 'too short');
      final e = await h.error({
        'request_id': 1,
        'op': 'nutrition.day',
        'date': '2026-09-22',
      });
      expect(e['code'], 'key_file_invalid');
    });
  });
}
