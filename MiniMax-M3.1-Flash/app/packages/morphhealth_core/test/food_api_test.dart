import 'dart:convert';
import 'dart:io';

import 'package:morphhealth_core/morphhealth_core.dart';
import 'package:test/test.dart';

/// Serves the read only Open Food Facts contract on a random local port.
///
/// The test therefore proves that the integration runs unchanged against a
/// different origin of the same contract (P08).
class _FakeFoodService {
  _FakeFoodService._(this._server);

  static Future<_FakeFoodService> start() async {
    final HttpServer server =
        await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    final _FakeFoodService service = _FakeFoodService._(server);
    unawaited(service._serve());
    return service;
  }

  final HttpServer _server;
  final List<HttpRequest> requests = <HttpRequest>[];

  String get baseUrl => 'http://127.0.0.1:${_server.port}';

  Future<void> _serve() async {
    await for (final HttpRequest request in _server) {
      requests.add(request);
      final String path = request.uri.path;
      if (path == '/cgi/search.pl') {
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode(_searchResponse));
      } else if (path.startsWith('/api/v3.6/product/')) {
        request.response.headers.contentType = ContentType.json;
        request.response.write(jsonEncode(_productResponse));
      } else {
        request.response.statusCode = HttpStatus.notFound;
      }
      await request.response.close();
    }
  }

  Future<void> close() => _server.close(force: true);
}

void unawaited(Future<void> future) {}

const Map<String, dynamic> _searchResponse = <String, dynamic>{
  'count': 348,
  'page': 1,
  'page_size': 20,
  'products': <Map<String, dynamic>>[
    <String, dynamic>{
      'code': '4056489983477',
      'product_name_de': 'Bio Hafermilch',
      'brands': 'Lidl',
      'quantity': '1l',
      'nutriscore_grade': 'b',
      'nova_group': 4,
      'serving_quantity': '100',
      'serving_quantity_unit': 'g',
      'nutriments': <String, dynamic>{
        'energy-kcal_100g': 33.0,
        'energy-kcal_unit': 'kcal',
        'energy-kj_100g': 136.6,
        'proteins_100g': 0.6,
        'proteins_unit': 'g',
        'carbohydrates_100g': 3.7,
        'fat_100g': 1.5,
        'saturated-fat_100g': 0.2,
        'sugars_100g': 1.2,
        'fiber_100g': 1.0,
        'salt_100g': 0.09,
        'sodium_100g': 0.036,
        'calcium_100g': 0.12,
        'calcium_unit': 'g',
        'iron_100g': 0.0004,
        'iron_unit': 'g',
        'vitamin-c_100g': 0.0001,
        'vitamin-c_unit': 'g',
      },
    },
  ],
};

const Map<String, dynamic> _productResponse = <String, dynamic>{
  'status': 'success',
  'result': <String, dynamic>{'id': 'ok'},
  'product': <String, dynamic>{
    'code': '5411188137979',
    'product_name': 'Soja Natur',
    'brands': 'Alpro',
    'serving_size': '100 g',
    'nutrition': <String, dynamic>{
      'aggregated_set': <String, dynamic>{
        'nutrients': <String, dynamic>{
          'energy-kcal': <String, dynamic>{'unit': 'kcal', 'value': 49.0},
          'energy-kj': <String, dynamic>{'unit': 'kJ', 'value': 204.0},
          'protein': <String, dynamic>{'unit': 'g', 'value': 5.0},
          'carbohydrates': <String, dynamic>{'unit': 'g', 'value': 1.0},
          'fat': <String, dynamic>{'unit': 'g', 'value': 3.0},
          'saturated-fat': <String, dynamic>{'unit': 'g', 'value': 0.4},
          'sugars': <String, dynamic>{'unit': 'g', 'value': 0.5},
          'fiber': <String, dynamic>{'unit': 'g', 'value': 0.9},
          'salt': <String, dynamic>{'unit': 'g', 'value': 0.42},
          'sodium': <String, dynamic>{'unit': 'g', 'value': 0.16},
          'vitamin-b12': <String, dynamic>{'unit': 'g', 'value': 3.8e-07},
          'selenium': <String, dynamic>{'unit': 'g', 'value': 1.4e-07},
          'zinc': <String, dynamic>{'unit': 'g', 'value': 0.0003},
          'iodine': <String, dynamic>{'unit': 'g', 'value': 9.8e-08},
        },
      },
    },
  },
};

void main() {
  group('food service contract', () {
    late _FakeFoodService service;
    late FoodApiClient client;

    setUp(() async {
      service = await _FakeFoodService.start();
      client = FoodApiClient(
        baseUrl: service.baseUrl,
        userAgent: 'MorphHealth/test (origin check)',
      );
    });

    tearDown(() async {
      client.close();
      await service.close();
    });

    test('search uses the documented endpoint and maps the answer', () async {
      final FoodSearchResult result = await client.search('hafermilch');

      expect(service.requests, hasLength(1));
      expect(service.requests.single.uri.path, '/cgi/search.pl');
      expect(
        service.requests.single.uri.queryParameters['search_terms'],
        'hafermilch',
      );
      expect(service.requests.single.uri.queryParameters['json'], '1');
      expect(
        service.requests.single.headers.value('user-agent'),
        'MorphHealth/test (origin check)',
      );

      expect(result.totalCount, 348);
      expect(result.items, hasLength(1));
      final FoodSearchItem item = result.items.single;
      expect(item.code, '4056489983477');
      expect(item.name, 'Bio Hafermilch');
      expect(item.brand, 'Lidl');
      expect(item.energyKcalPer100, 33.0);
      expect(item.nutriscoreGrade, 'b');
      expect(item.novaGroup, 4);
      expect(item.servingGrams, 100.0);

      // The search answer already carries nutrients; they are mapped.
      expect(item.nutrientsPer100, isNotNull);
      expect(item.nutrientsPer100!.values[Nutrients.energyKcal], 33.0);
      expect(item.nutrientsPer100!.values[Nutrients.protein], 0.6);
      expect(item.nutrientsPer100!.values[Nutrients.salt], 0.09);
      expect(item.nutrientsPer100!.values[Nutrients.calcium], 0.12);
    });

    test('lookup uses the documented endpoint and maps every nutrient', () async {
      final FoodLookupResult result = await client.lookup('5411188137979');

      expect(service.requests, hasLength(1));
      expect(
        service.requests.single.uri.path,
        '/api/v3.6/product/5411188137979.json',
      );
      expect(result.found, isTrue);

      final FoodItem food = result.food!;
      expect(food.id, 'off-5411188137979');
      expect(food.name, 'Soja Natur');
      expect(food.brand, 'Alpro');
      expect(food.barcode, '5411188137979');
      expect(food.source, FoodSource.openFoodFacts);
      expect(food.nutrientsPer100.values[Nutrients.energyKcal], 49.0);
      expect(food.nutrientsPer100.values[Nutrients.protein], 5.0);
      expect(food.nutrientsPer100.values[Nutrients.vitaminB12], 3.8e-07);
      expect(food.nutrientsPer100.values[Nutrients.selenium], 1.4e-07);
      expect(food.nutrientsPer100.values[Nutrients.zinc], 0.0003);
      expect(food.nutrientsPer100.values[Nutrients.iodine], 9.8e-08);
    });

    test('the same client code works against a different origin', () async {
      // The endpoint of the environment is not contacted here; only the
      // contract matters.
      final FoodApiClient other = FoodApiClient(
        baseUrl: '${service.baseUrl}/',
        userAgent: 'MorphHealth/test (origin check)',
      );
      final FoodSearchResult result = await other.search('hafermilch');
      expect(result.items, hasLength(1));
      expect(result.items.single.name, 'Bio Hafermilch');
      other.close();
    });
  });
}
