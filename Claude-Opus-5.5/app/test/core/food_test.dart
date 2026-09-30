import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:morphhealth/core/food/off_client.dart';
import 'package:morphhealth/core/food/off_parser.dart';
import 'package:morphhealth/core/model/enums.dart';

Map<String, Object?> fixture(String name) =>
    jsonDecode(File('test/fixtures/$name').readAsStringSync()) as Map<String, Object?>;

void main() {
  group('OffParser', () {
    test('reads the v3.6 aggregated nutrition set with estimates', () {
      final product = fixture('off_product_v36_marzipan.json')['product'] as Map<String, Object?>;
      final food = OffParser.parse(product, language: 'de')!;
      final p = food.profile;
      expect(p.barcode, '4000417025005');
      expect(p.name, 'Marzipan');
      expect(OffParser.parse(product, language: 'en')!.profile.name, 'Marzipane chocolate');
      expect(p.brand, 'Ritter Sport');
      expect(p.source, FoodSource.openFoodFacts);
      expect(p.basis, Basis.g);
      expect(p.servingSize, 6.52);
      expect(p.servingLabel, '1 Cube (6.52 g)');
      expect(food.nutritionSource, 'aggregated_set');
      expect(p.nutrients['energy_kcal'], 496);
      expect(p.nutrients['protein_g'], 7);
      expect(p.nutrients['salt_g'], 1);
      expect(p.nutrients['sodium_mg'], 400);
      // Normalized grams → mg / µg.
      expect(p.nutrients['calcium_mg'], closeTo(47.085, 0.001));
      expect(p.nutrients['iodine_ug'], closeTo(0.576, 0.001));
      // Vitamin K comes from "phylloquinone", B3 from "vitamin-pp".
      expect(p.nutrients.containsKey('vitamin_k_ug'), isTrue);
      expect(p.nutrients['vitamin_b3_mg'], closeTo(0.5775, 1e-6));
      expect(p.estimatedNutrients, contains('calcium_mg'));
      expect(p.estimatedNutrients, isNot(contains('energy_kcal')));
      expect(p.estimatedNutrients, isNot(contains('salt_g')));
    });

    test('recognizes liquids and legacy nutriments from the search endpoint', () {
      final drink = fixture('off_product_v36_drink.json')['product'] as Map<String, Object?>;
      expect(OffParser.parse(drink, language: 'de')!.profile.basis, Basis.ml);

      final search = fixture('off_search_milch.json');
      final products = (search['products'] as List).cast<Map<String, Object?>>();
      final parsed = products.map((p) => OffParser.parse(p, language: 'de')).toList();
      expect(parsed.whereType<OnlineFood>().length, products.length);
      final almond = parsed.firstWhere((f) => f!.barcode == '5411188112709')!;
      expect(almond.nutritionSource, 'nutriments');
      expect(almond.profile.nutrients['energy_kcal'], 14);
      expect(almond.profile.nutrients['calcium_mg'], 120);
      expect(almond.profile.nutrients['vitamin_d_ug'], closeTo(0.75, 1e-9));
      expect(almond.profile.nutrients['vitamin_b12_ug'], closeTo(0.38, 1e-9));
      expect(almond.profile.basis, Basis.ml);
    });

    test('falls back to kJ and ignores unusable values', () {
      final food = OffParser.parse({
        'code': '12345678',
        'product_name': 'Test',
        'nutrition': {
          'aggregated_set': {
            'per': '100g',
            'nutrients': {
              'energy-kj': {'value': 418.4, 'unit': 'kJ', 'source': 'packaging'},
              'fat': {'value': 250, 'unit': 'g'},
              'vitamin-c': {'value': 12, 'unit': 'mg'},
              'vitamin-a': {'value': 5, 'unit': 'IU'},
              'sodium': {'value': 0.2, 'unit': 'g', 'source': 'estimate'},
            },
          },
        },
      }, language: 'de')!;
      final n = food.profile.nutrients;
      expect(n['energy_kcal'], 100);
      expect(n.containsKey('fat_g'), isFalse, reason: 'implausible value dropped');
      expect(n['vitamin_c_mg'], 12);
      expect(n.containsKey('vitamin_a_ug'), isFalse);
      expect(n['salt_g'], closeTo(0.5, 1e-9));
      expect(food.profile.estimatedNutrients, containsAll(['sodium_mg', 'salt_g']));
    });

    test('products without a usable barcode are skipped', () {
      expect(OffParser.parse({'product_name': 'x'}, language: 'de'), isNull);
    });
  });

  group('Gtin', () {
    test('sanitizes and validates check digits', () {
      expect(Gtin.sanitize(' 4000417-025005 '), '4000417025005');
      expect(Gtin.sanitize('40004a'), isNull);
      expect(Gtin.hasValidCheckDigit('4000417025005'), isTrue);
      expect(Gtin.hasValidCheckDigit('4000417025006'), isFalse);
      expect(Gtin.hasValidCheckDigit('20005825'), isTrue);
      expect(Gtin.hasValidCheckDigit('12345'), isNull);
      expect(Gtin.looksLikeBarcode('4000417025005'), isTrue);
      expect(Gtin.looksLikeBarcode('Nutella'), isFalse);
    });
  });

  group('OffClient', () {
    test('builds the contract URLs from a configurable origin', () {
      final config = FoodApiConfig('https://localhost:8788/', 'UA/1');
      expect(
        config.productUri('4000417025005').toString(),
        startsWith('https://localhost:8788/api/v3.6/product/4000417025005.json?fields='),
      );
      final search = config.searchUri('vollkorn brot', 2);
      expect(search.path, '/cgi/search.pl');
      expect(search.queryParameters['search_terms'], 'vollkorn brot');
      expect(search.queryParameters['search_simple'], '1');
      expect(search.queryParameters['action'], 'process');
      expect(search.queryParameters['json'], '1');
      expect(search.queryParameters['page'], '2');
      expect(search.queryParameters['page_size'], '20');
      final prefixed = FoodApiConfig('https://mirror.example/off', 'UA');
      expect(prefixed.productUri('1').path, '/off/api/v3.6/product/1.json');
      expect(() => FoodApiConfig('http://insecure.example', 'UA'), throwsArgumentError);
      expect(FoodApiConfig.parseBaseUrl('ftp://x'), isNull);
    });

    test('sends the User-Agent and maps responses', () async {
      final requests = <http.Request>[];
      final client = MockClient((request) async {
        requests.add(request);
        if (request.url.path.endsWith('/0000000000000.json')) {
          return http.Response(File('test/fixtures/off_product_not_found.json').readAsStringSync(), 404);
        }
        if (request.url.path.startsWith('/api/v3.6/product/')) {
          return http.Response.bytes(
            File('test/fixtures/off_product_v36_marzipan.json').readAsBytesSync(),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }
        if (request.url.path == '/cgi/search.pl') {
          return http.Response.bytes(
            File('test/fixtures/off_search_milch.json').readAsBytesSync(),
            200,
          );
        }
        return http.Response('nope', 500);
      });
      final off = OffClient(FoodApiConfig('https://food.test', 'MorphHealthTest/1'), httpClient: client);
      final found = await off.lookup('4000417025005', language: 'de');
      expect(found.found, isTrue);
      expect(requests.last.headers['User-Agent'], 'MorphHealthTest/1');
      final missing = await off.lookup('0000000000000', language: 'de');
      expect(missing.found, isFalse);
      final page = await off.search('milch', 1, language: 'de');
      expect(page.count, 12624);
      expect(page.items, hasLength(20));
      expect(page.pageCount, 632);
      expect(page.hasMore, isTrue);
    });

    test('reports network, HTTP and format errors with codes', () async {
      Future<FoodApiException> failure(http.Client c) async {
        try {
          await OffClient(FoodApiConfig('https://food.test', 'UA'), httpClient: c)
              .search('x', 1, language: 'de');
        } on FoodApiException catch (e) {
          return e;
        }
        fail('expected FoodApiException');
      }

      expect((await failure(MockClient((_) async => throw const SocketException('down')))).code,
          'network_error');
      expect((await failure(MockClient((_) async => http.Response('', 429)))).code, 'rate_limited');
      expect((await failure(MockClient((_) async => http.Response('', 503)))).code,
          'upstream_http_error');
      expect((await failure(MockClient((_) async => http.Response('<html>', 200)))).code,
          'upstream_invalid_response');
    });
  });
}
