import 'dart:convert';
import 'dart:io';

import 'package:morphhealth_core/morphhealth_core.dart';
import 'package:test/test.dart';

/// Answers requests from a script and records what was asked.
class FakeTransport implements HttpTransport {
  final List<Object Function(Uri uri)> script;
  final List<Uri> requests = [];
  final List<Map<String, String>> headers = [];
  bool closed = false;

  FakeTransport(this.script);

  @override
  Future<TransportResponse> get(
    Uri uri, {
    required Map<String, String> headers,
    required Duration timeout,
  }) async {
    requests.add(uri);
    this.headers.add(headers);
    final step =
        script[requests.length - 1 < script.length
            ? requests.length - 1
            : script.length - 1];
    final result = step(uri);
    if (result is FoodApiException) throw result;
    return result as TransportResponse;
  }

  @override
  void close() => closed = true;
}

TransportResponse _json(Object body, [int status = 200]) => TransportResponse(
  status,
  const {'content-type': 'application/json'},
  utf8.encode(jsonEncode(body)),
);

TransportResponse _status(
  int status, [
  Map<String, String> headers = const {},
]) => TransportResponse(status, headers, utf8.encode('<html>error</html>'));

String _fixture(String name) => File('test/fixtures/$name').readAsStringSync();

({FoodApiClient client, FakeTransport transport, List<Duration> sleeps})
_client(
  List<Object Function(Uri uri)> script, {
  String origin = 'https://food.example:8443',
}) {
  final transport = FakeTransport(script);
  final sleeps = <Duration>[];
  final client = FoodApiClient(
    origin: FoodApiClient.parseOrigin(origin),
    userAgent: 'MorphHealth/test (unit)',
    transport: transport,
    sleep: (d) async => sleeps.add(d),
  );
  return (client: client, transport: transport, sleeps: sleeps);
}

Matcher _fails(String code) =>
    throwsA(isA<FoodApiException>().having((e) => e.code, 'code', code));

void main() {
  group('origin', () {
    test('accepts https origins and normalizes them', () {
      expect(
        FoodApiClient.parseOrigin('https://world.openfoodfacts.org').toString(),
        'https://world.openfoodfacts.org',
      );
      expect(
        FoodApiClient.parseOrigin(' https://LOCALHOST:8788/ ').toString(),
        'https://localhost:8788',
      );
    });

    test('refuses everything that is not a plain https origin', () {
      for (final bad in [
        'http://localhost:8788',
        'localhost:8788',
        'https://',
        'https://host/path',
        'https://host?x=1',
        'https://user:pw@host',
        'ftp://host',
        '',
      ]) {
        expect(
          () => FoodApiClient.parseOrigin(bad),
          _fails('invalid_argument'),
          reason: bad,
        );
      }
    });
  });

  group('lookup', () {
    test(
      'requests the v3.6 product endpoint of the configured origin',
      () async {
        final c = _client([
          (_) => _json(
            jsonDecode(_fixture('product_3017620425035.json')) as Object,
          ),
        ]);
        final result = await c.client.lookup('3017620425035');

        final uri = c.transport.requests.single;
        expect(uri.scheme, 'https');
        expect(uri.host, 'food.example');
        expect(uri.port, 8443);
        expect(uri.path, '/api/v3.6/product/3017620425035.json');
        expect(uri.queryParameters.keys, ['fields']);
        expect(
          uri.queryParameters['fields']!.split(','),
          containsAll(['code', 'product_name', 'nutrition', 'nutriments']),
        );
        expect(
          c.transport.headers.single['user-agent'],
          'MorphHealth/test (unit)',
        );

        expect(result.found, isTrue);
        expect(result.product!.name, 'Nutella');
        expect(result.product!.nutrients[Nutrients.energy], 539);
      },
    );

    test('not found: HTTP 404 with a failure answer', () async {
      final c = _client([
        (_) =>
            _json(jsonDecode(_fixture('product_missing.json')) as Object, 404),
      ]);
      final result = await c.client.lookup('4000000000013');
      expect(result.found, isFalse);
      expect(result.reason, 'product_not_found');
      expect(result.product, isNull);
      expect(c.transport.requests, hasLength(1), reason: 'no retry on 404');
    });

    test('success with warnings (normalized code) is a success', () async {
      final c = _client([
        (_) => _json({
          'code': '80176800',
          'status': 'success_with_warnings',
          'result': {'id': 'product_found'},
          'warnings': [
            {
              'message': {'id': 'different_normalized_product_code'},
            },
          ],
          'product': {'code': '80176800', 'product_name': 'Creme'},
        }),
      ]);
      final result = await c.client.lookup('0000080176800');
      expect(result.found, isTrue);
      expect(result.requestedBarcode, '0000080176800');
      expect(result.product!.barcode, '80176800');
    });

    test('invalid input is refused without a request', () async {
      final c = _client([(_) => _status(500)]);
      for (final bad in [
        '',
        'abc',
        '12 34',
        '123456',
        '123456789012345',
        '4008400x01621',
      ]) {
        await expectLater(
          c.client.lookup(bad),
          _fails('invalid_argument'),
          reason: bad,
        );
      }
      expect(c.transport.requests, isEmpty);
    });

    test('spaces and hyphens in a barcode are ignored', () async {
      final c = _client([
        (_) =>
            _json(jsonDecode(_fixture('product_missing.json')) as Object, 404),
      ]);
      await c.client.lookup(' 4008 4004-01621 ');
      expect(
        c.transport.requests.single.path,
        '/api/v3.6/product/4008400401621.json',
      );
    });

    test('a redirect to another server is not followed', () async {
      final c = _client([
        (_) => _status(302, {
          'location': 'https://world.openbeautyfacts.org/api/v3/product/1',
        }),
      ]);
      final result = await c.client.lookup('8710447445990');
      expect(result.found, isFalse);
      expect(result.reason, 'other_product_type');
      expect(c.transport.requests, hasLength(1));
    });

    test('a redirect within the origin is followed', () async {
      final c = _client([
        (_) => _status(301, {
          'location': '/api/v3.6/product/80176800.json?fields=code',
        }),
        (_) => _json({
          'status': 'success',
          'product': {'code': '80176800', 'product_name': 'Creme'},
        }),
      ]);
      final result = await c.client.lookup('0080176800');
      expect(result.found, isTrue);
      expect(c.transport.requests, hasLength(2));
      expect(c.transport.requests.last.host, 'food.example');
    });

    test(
      'an origin without the endpoint is an error, not "not found"',
      () async {
        final c = _client([(_) => _status(404)]);
        await expectLater(
          c.client.lookup('4008400401621'),
          _fails('bad_response'),
        );
      },
    );

    test('an answer that is not JSON is an error', () async {
      final c = _client([(_) => _status(200)]);
      await expectLater(
        c.client.lookup('4008400401621'),
        _fails('bad_response'),
      );
    });
  });

  group('search', () {
    test('requests search.pl exactly as the contract describes', () async {
      final c = _client([
        (_) => _json(jsonDecode(_fixture('search_cola_zero.json')) as Object),
      ]);
      final page = await c.client.search('  Cola   Zero ', page: 3);

      final uri = c.transport.requests.single;
      expect(uri.path, '/cgi/search.pl');
      expect(
        uri.query,
        startsWith(
          'search_terms=Cola+Zero&search_simple=1&action=process&json=1'
          '&page=3&page_size=20&fields=',
        ),
      );
      expect(page.query, 'Cola Zero');
      expect(page.products, hasLength(5));
      expect(page.products.first.barcode, '5449000214799');
    });

    test('the number of pages is computed from count and page size', () async {
      // The service's "page_count" is the number of products on this page.
      final c = _client([
        (_) => _json({
          'count': 104,
          'page': 6,
          'page_count': 4,
          'page_size': 20,
          'skip': 100,
          'products': [
            for (var i = 0; i < 4; i++)
              {'code': '4000000000$i', 'product_name': 'P$i'},
          ],
        }),
      ]);
      final page = await c.client.search('nutella', page: 6);
      expect(page.totalCount, 104);
      expect(page.pageCount, 6);
      expect(page.hasMore, isFalse);
      final json = page.toJson();
      expect(json['page_count'], 6);
      expect(json['total_count'], 104);
      expect((json['products'] as List), hasLength(4));
    });

    test('no result', () async {
      final c = _client([
        (_) => _json({
          'count': 0,
          'page': 1,
          'page_count': 0,
          'page_size': 20,
          'products': <Object>[],
        }),
      ]);
      final page = await c.client.search('zzzzqqqq');
      expect(page.products, isEmpty);
      expect(page.pageCount, 0);
      expect(page.hasMore, isFalse);
    });

    test('umlauts and special characters are encoded', () async {
      final c = _client([
        (_) => _json({'count': 0, 'products': <Object>[]}),
      ]);
      await c.client.search('Müsli & Früchte');
      expect(
        c.transport.requests.single.query,
        contains('search_terms=M%C3%BCsli+%26+Fr%C3%BCchte&'),
      );
    });

    test(
      'counts given as strings and products without code are tolerated',
      () async {
        final c = _client([
          (_) => _json({
            'count': '41',
            'page': '2',
            'page_size': '20',
            'products': [
              {'product_name': 'ohne Code'},
              'kaputt',
              {'code': '4000000000013', 'product_name': 'gut'},
            ],
          }),
        ]);
        final page = await c.client.search('test', page: 2);
        expect((page.totalCount, page.page, page.pageCount), (41, 2, 3));
        expect(page.products.single.name, 'gut');
        expect(page.hasMore, isTrue);
      },
    );

    test('invalid input is refused without a request', () async {
      final c = _client([(_) => _status(500)]);
      await expectLater(c.client.search(''), _fails('invalid_argument'));
      await expectLater(c.client.search(' a '), _fails('invalid_argument'));
      await expectLater(
        c.client.search('ab', page: 0),
        _fails('invalid_argument'),
      );
      await expectLater(c.client.search('x' * 201), _fails('invalid_argument'));
      expect(c.transport.requests, isEmpty);
    });

    test('an answer without product list is an error', () async {
      final c = _client([
        (_) => _json({'count': 3}),
      ]);
      await expectLater(c.client.search('test'), _fails('bad_response'));
    });
  });

  group('temporary failures', () {
    final ok = _json({'count': 0, 'products': <Object>[]});

    test('503 is retried with growing pauses', () async {
      final c = _client([(_) => _status(503), (_) => _status(503), (_) => ok]);
      await c.client.search('test');
      expect(c.transport.requests, hasLength(3));
      expect(c.sleeps, hasLength(2));
      expect(c.sleeps[0].inMilliseconds, inInclusiveRange(400, 600));
      expect(c.sleeps[1].inMilliseconds, inInclusiveRange(800, 1200));
    });

    test('gives up after three attempts', () async {
      final c = _client([(_) => _status(503)]);
      await expectLater(c.client.search('test'), _fails('server_error'));
      expect(c.transport.requests, hasLength(3));
    });

    test('429 honours a short Retry-After', () async {
      final c = _client([
        (_) => _status(429, {'retry-after': '2'}),
        (_) => ok,
      ]);
      await c.client.search('test');
      expect(c.sleeps.single, const Duration(seconds: 2));
    });

    test(
      '429 with a long Retry-After fails at once and reports the wait',
      () async {
        final c = _client([
          (_) => _status(429, {'retry-after': '120'}),
        ]);
        await expectLater(
          c.client.search('test'),
          throwsA(
            isA<FoodApiException>()
                .having((e) => e.code, 'code', 'rate_limited')
                .having((e) => e.retryAfterSeconds, 'retryAfter', 120),
          ),
        );
        expect(c.transport.requests, hasLength(1));
      },
    );

    test('network errors and timeouts are retried', () async {
      final c = _client([
        (_) => const FoodApiException('network', 'refused'),
        (_) => const FoodApiException('timeout', 'slow'),
        (_) => ok,
      ]);
      await c.client.search('test');
      expect(c.transport.requests, hasLength(3));

      final down = _client([
        (_) => const FoodApiException('network', 'refused'),
      ]);
      await expectLater(down.client.search('test'), _fails('network'));
      expect(down.transport.requests, hasLength(3));
    });

    test('certificate problems and client errors are not retried', () async {
      final tls = _client([(_) => const FoodApiException('tls', 'untrusted')]);
      await expectLater(tls.client.search('test'), _fails('tls'));
      expect(tls.transport.requests, hasLength(1));

      final forbidden = _client([(_) => _status(403)]);
      await expectLater(
        forbidden.client.search('test'),
        _fails('bad_response'),
      );
      expect(forbidden.transport.requests, hasLength(1));
    });
  });

  test('the same client works against any origin of the contract', () async {
    for (final origin in [
      'https://world.openfoodfacts.org',
      'https://localhost:8788',
    ]) {
      final c = _client([
        (_) => _json({'count': 0, 'products': <Object>[]}),
      ], origin: origin);
      await c.client.search('test');
      expect(
        c.transport.requests.single.toString(),
        startsWith('$origin/cgi/search.pl?search_terms=test&'),
      );
    }
  });

  test('close closes the transport', () {
    final c = _client([(_) => _status(200)]);
    c.client.close();
    expect(c.transport.closed, isTrue);
  });
}
