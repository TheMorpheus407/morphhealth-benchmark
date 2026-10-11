// Tests für food/off_client.dart (HTTP-Vertrag, SPEC P08) mit Mock-HTTP.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:morphhealth/src/core/exceptions.dart';
import 'package:morphhealth/src/food/off_client.dart';
import 'package:morphhealth/src/food/off_mapping.dart';

/// Antwort-Helfer: JSON mit Status 200.
http.Response jsonResponse(Map<String, dynamic> body, {int status = 200}) =>
    http.Response(jsonEncode(body), status,
        headers: <String, String>{'content-type': 'application/json'});

const OffConfig testConfig = OffConfig(
  baseUrl: 'https://foodapi.example',
  userAgent: 'MorphHealth/1.0 (test)',
);

/// Ein Produkt im Antwort-Format der v3.6-API.
Map<String, dynamic> produktFixture({
  String code = '3017620422003',
  String name = 'Nutella',
}) {
  return <String, dynamic>{
    'code': code,
    'product_name_de': name,
    'product_name': 'Product EN',
    'brands': 'Ferrero, Andere',
    'quantity': '400 g',
    'serving_size': '15 g',
    'image_front_small_url': 'https://img.example/front.jpg',
    'nutriments': <String, dynamic>{
      'energy-kcal_100g': 539,
      'energy-kcal_unit': 'kcal',
      'proteins_100g': 6.3,
      'proteins_unit': 'g',
    },
  };
}

void main() {
  group('OffConfig', () {
    test('normalizedBaseUrl entfernt den führenden Schrägstrich am Ende', () {
      expect(
          const OffConfig(baseUrl: 'https://x.example/', userAgent: 'u')
              .normalizedBaseUrl,
          'https://x.example');
      expect(testConfig.normalizedBaseUrl, 'https://foodapi.example');
    });
  });

  group('OffClient.normalizeBarcode', () {
    test('akzeptiert 6–14 Ziffern (mit Trennzeichen)', () {
      expect(OffClient.normalizeBarcode('3017620422003'), '3017620422003');
      expect(OffClient.normalizeBarcode(' 3017-6204 22003 '), '3017620422003');
      expect(OffClient.normalizeBarcode('400638'), '400638');
    });

    test('lehnt ungültige Eingaben ab', () {
      expect(OffClient.normalizeBarcode('12345'), isNull); // zu kurz
      expect(OffClient.normalizeBarcode('123456789012345'), isNull); // zu lang
      expect(OffClient.normalizeBarcode('abc'), isNull);
      expect(OffClient.normalizeBarcode(''), isNull);
    });
  });

  group('OffClient.search', () {
    test('fragt search.pl an und bildet Produkte ab', () async {
      late http.Request captured;
      final MockClient mock = MockClient((http.Request request) async {
        captured = request;
        return jsonResponse(<String, dynamic>{
          'count': 123,
          'page': 2,
          'page_count': 7,
          'products': <dynamic>[
            produktFixture(),
            produktFixture(code: '4006381333931', name: 'Paulaner'),
          ],
        });
      });
      final OffClient client = OffClient(testConfig, httpClient: mock);
      final OffSearchResult result =
          await client.search('nutella', page: 2);

      // Anfrage: richtiger Pfad + Vertrag-Parameter + User-Agent.
      expect(captured.url.path, '/cgi/search.pl');
      final Map<String, String> q = captured.url.queryParameters;
      expect(q['search_terms'], 'nutella');
      expect(q['search_simple'], '1');
      expect(q['action'], 'process');
      expect(q['json'], '1');
      expect(q['page'], '2');
      expect(q['page_size'], '20');
      expect(captured.headers['User-Agent'], 'MorphHealth/1.0 (test)');

      // Ergebnis.
      expect(result.count, 123);
      expect(result.page, 2);
      expect(result.pageCount, 7);
      expect(result.products.length, 2);
      expect(result.products[0].barcode, '3017620422003');
      expect(result.products[0].name, 'Nutella'); // de-Name bevorzugt
      expect(result.products[0].per100['energy_kcal'], 539);
      expect(result.products[0].per100['protein_g'], 6.3);
      expect(result.products[1].brand, 'Ferrero');
    });

    test('Sonderzeichen werden in der URL kodiert', () async {
      late http.Request captured;
      final MockClient mock = MockClient((http.Request request) async {
        captured = request;
        return jsonResponse(<String, dynamic>{
          'count': 0,
          'products': <dynamic>[],
        });
      });
      final OffClient client = OffClient(testConfig, httpClient: mock);
      await client.search('Käse & Müsli');
      expect(captured.url.queryParameters['search_terms'], 'Käse & Müsli');
    });

    test('leere Anfrage wirft off.empty_query (ohne HTTP)', () async {
      final MockClient mock =
          MockClient((http.Request request) => throw StateError('nicht erwartet'));
      final OffClient client = OffClient(testConfig, httpClient: mock);
      expect(
          () => client.search('   '),
          throwsA(isA<MorphException>().having(
              (MorphException e) => e.code, 'code', 'off.empty_query')));
    });
  });

  group('OffClient.lookup', () {
    test('fragt die v3.6-Produkt-API an', () async {
      late http.Request captured;
      final MockClient mock = MockClient((http.Request request) async {
        captured = request;
        return jsonResponse(<String, dynamic>{
          'status': 1,
          'product': produktFixture(),
        });
      });
      final OffClient client = OffClient(testConfig, httpClient: mock);
      final OffProduct? product = await client.lookup('3017620422003');
      expect(captured.url.path, '/api/v3.6/product/3017620422003.json');
      expect(captured.headers['User-Agent'], 'MorphHealth/1.0 (test)');
      expect(product, isNotNull);
      expect(product!.barcode, '3017620422003');
      expect(product.name, 'Nutella');
      expect(product.per100['energy_kcal'], 539);
    });

    test('HTTP 404 → null (nicht gefunden)', () async {
      final MockClient mock = MockClient((http.Request request) async {
        return http.Response('not found', 404);
      });
      final OffClient client = OffClient(testConfig, httpClient: mock);
      expect(await client.lookup('3017620422003'), isNull);
    });

    test('status 0 ohne Produkt → null', () async {
      final MockClient mock = MockClient((http.Request request) async {
        return jsonResponse(<String, dynamic>{'status': 0, 'status_verbose': 'product not found'});
      });
      final OffClient client = OffClient(testConfig, httpClient: mock);
      expect(await client.lookup('3017620422003'), isNull);
    });

    test('ungültige Barcode wirft off.invalid_barcode', () async {
      final OffClient client = OffClient(testConfig,
          httpClient: MockClient((http.Request r) => throw StateError('x')));
      expect(
          () => client.lookup('kurz'),
          throwsA(isA<MorphException>().having(
              (MorphException e) => e.code, 'code', 'off.invalid_barcode')));
    });
  });

  group('OffClient: Fehlerfälle', () {
    test('unerreichbarer Endpunkt → off.unreachable', () async {
      final MockClient mock = MockClient((http.Request request) async {
        throw const SocketExceptionTest('connection refused');
      });
      final OffClient client = OffClient(testConfig, httpClient: mock);
      expect(
          () => client.lookup('3017620422003'),
          throwsA(isA<MorphException>().having(
              (MorphException e) => e.code, 'code', 'off.unreachable')));
    });

    test('unerwarteter HTTP-Status → off.http_status', () async {
      final MockClient mock = MockClient((http.Request request) async {
        return http.Response('oops', 500);
      });
      final OffClient client = OffClient(testConfig, httpClient: mock);
      expect(
          () => client.search('x'),
          throwsA(isA<MorphException>().having(
              (MorphException e) => e.code, 'code', 'off.http_status')));
    });

    test('kaputtes JSON → off.parse_error', () async {
      final MockClient mock = MockClient((http.Request request) async {
        return http.Response('<!doctype html>', 200);
      });
      final OffClient client = OffClient(testConfig, httpClient: mock);
      expect(
          () => client.search('x'),
          throwsA(isA<MorphException>().having(
              (MorphException e) => e.code, 'code', 'off.parse_error')));
    });
  });

  group('OffSearchResult.toJson', () {
    test('enthält count, page, page_count und Produkte', () async {
      final MockClient mock = MockClient((http.Request request) async {
        return jsonResponse(<String, dynamic>{
          'count': 1,
          'products': <dynamic>[produktFixture()],
        });
      });
      final OffClient client = OffClient(testConfig, httpClient: mock);
      final OffSearchResult result = await client.search('nutella');
      final Map<String, dynamic> json = result.toJson();
      expect(json['count'], 1);
      expect(json['page'], 1); // aus Anfrage-Default
      expect((json['products'] as List<dynamic>).single['barcode'],
          '3017620422003');
    });
  });
}

/// Hilfs-Exception für den "unerreichbar"-Test (SocketException-Ersatz).
class SocketExceptionTest implements Exception {
  final String message;
  const SocketExceptionTest(this.message);
  @override
  String toString() => 'SocketExceptionTest: $message';
}
