import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:morphhealth/core/food_api.dart';
import 'package:morphhealth/core/nutrition.dart';

void main() {
  FoodApi apiFor(
    Future<http.Response> Function(http.Request request) handler, {
    Duration requestTimeout = const Duration(seconds: 20),
  }) {
    final api = FoodApi(
      'https://food.example',
      'MorphHealth tests',
      client: MockClient(handler),
      requestTimeout: requestTimeout,
    );
    addTearDown(api.close);
    return api;
  }

  Future<http.Response> jsonResponse(Object? body, [int status = 200]) async =>
      http.Response(
        jsonEncode(body),
        status,
        headers: {'content-type': 'application/json; charset=utf-8'},
      );

  group('Konfiguration und Eingaben', () {
    test(
      'nur HTTPS-Origins ohne Benutzerinfo, Pfad, Query oder Fragment sind erlaubt',
      () {
        for (final value in [
          'http://food.example',
          'https://',
          'https://user@food.example',
          'https://food.example/path',
          'https://food.example?x=1',
          'https://food.example#fragment',
          'not a uri',
        ]) {
          expect(
            () => FoodApi(value, 'agent'),
            throwsArgumentError,
            reason: value,
          );
        }
        final withSlash = FoodApi(
          'https://food.example/',
          'agent',
          client: MockClient((_) async => http.Response('{}', 200)),
        );
        addTearDown(withSlash.close);
        expect(withSlash.base.origin, 'https://food.example');
      },
    );

    test('Suche und Barcode validieren Eingaben vor einem Request', () async {
      var requests = 0;
      final api = apiFor((request) async {
        requests++;
        return http.Response('{}', 200);
      });
      await expectLater(api.search(' ', 1), throwsArgumentError);
      await expectLater(api.search('x', 0), throwsArgumentError);
      for (final barcode in [
        '1234567',
        '123456789012345',
        'abcdefgh',
        '1234 5678',
      ]) {
        await expectLater(
          api.lookup(barcode),
          throwsArgumentError,
          reason: barcode,
        );
      }
      expect(requests, 0);
      expect(
        const FoodApiException('code', 'message').toString(),
        'code: message',
      );
    });
  });

  group('OFF-Mapping', () {
    test(
      'Suche mappt alle 31 Nährstoffe und ihre Einheiten vollständig',
      () async {
        late http.Request captured;
        final api = apiFor((request) async {
          captured = request;
          return jsonResponse({
            'count': 1,
            'products': [completeOffProduct()],
          });
        });
        final result = await api.search('  Müsli  ', 2);
        expect(result.page, 2);
        expect(result.total, 1);
        expect(result.foods, hasLength(1));
        expect(result.toJson()['page_size'], 20);
        expect(result.toJson()['returned'], 1);
        expect(captured.method, 'GET');
        expect(captured.url.path, '/cgi/search.pl');
        expect(captured.url.queryParameters['search_terms'], 'Müsli');
        expect(captured.url.queryParameters['search_simple'], '1');
        expect(captured.url.queryParameters['action'], 'process');
        expect(captured.url.queryParameters['json'], '1');
        expect(captured.url.queryParameters['page'], '2');
        expect(captured.url.queryParameters['page_size'], '20');
        expect(
          captured.url.queryParameters['fields']!.split(','),
          containsAll([
            'code',
            'product_name',
            'product_name_de',
            'brands',
            'serving_size',
            'nutriments',
          ]),
        );
        expect(captured.headers['user-agent'], 'MorphHealth tests');
        expect(captured.headers['accept'], 'application/json');
        final food = result.foods.single;
        expect(food.id, 'off:4001234567890');
        expect(food.name, 'Deutsches Müsli');
        expect(food.brand, 'Testmarke');
        expect(food.source, 'openfoodfacts');
        expect(food.measure, 'g');
        expect(food.portionSize, 33.5);
        expect(food.barcode, '4001234567890');
        expect(food.favorite, isFalse);
        expect(food.createdAt, food.updatedAt);
        expect(food.createdAt.isUtc, isTrue);
        final expected = <String, double>{
          'calories': 252,
          'protein': 12,
          'carbs': 5,
          'fat': 2,
          'saturated_fat': 3,
          'sugar': 0.004,
          'fiber': 7,
          'salt': 1.5,
          'sodium': 500,
          'caffeine': 80,
          'vitamin_a': 800,
          'vitamin_c': 50,
          'vitamin_d': 20,
          'vitamin_e': 12,
          'vitamin_k': 30,
          'vitamin_b1': 1,
          'vitamin_b2': 1,
          'vitamin_b3': 16,
          'vitamin_b5': 5,
          'vitamin_b6': 1.4,
          'vitamin_b7': 50,
          'vitamin_b9': 200,
          'vitamin_b12': 1,
          'calcium': 100,
          'iron': 14,
          'magnesium': 100,
          'potassium': 1000,
          'zinc': 10,
          'selenium': 50,
          'iodine': 150,
          'phosphorus': 200,
        };
        expect(expected, hasLength(31));
        expect(food.nutrients, hasLength(31));
        for (final nutrient in Nutrient.values) {
          expect(
            food.nutrients[nutrient.id],
            closeTo(expected[nutrient.id]!, 1e-9),
            reason: nutrient.id,
          );
        }
      },
    );

    test(
      'kJ, alternative OFF-Schlüssel und ungültige Primärwerte werden korrekt behandelt',
      () async {
        final product = <String, dynamic>{
          'code': '12345678',
          'nutriments': <String, dynamic>{
            'energy-kcal_100g': 418.4,
            'energy-kcal_unit': 'kJ',
            'vitamin-b3_100g': 'invalid',
            'vitamin-pp_100g': 16,
            'vitamin-pp_unit': 'mg',
            'pantothenic-acid_100g': 5,
            'pantothenic-acid_unit': 'mg',
            'biotin_100g': 50,
            'biotin_unit': 'mcg',
            'vitamin-b9_100g': -1,
            'folates_100g': 'invalid',
            'folic-acid_100g': 0.2,
            'folic-acid_unit': 'mg',
            'proteins_100g': -5,
            'proteins_unit': 'g',
          },
        };
        final api = apiFor(
          (_) => jsonResponse({
            'products': [product],
          }),
        );
        final food = (await api.search('x', 1)).foods.single;
        expect(food.nutrients[Nutrient.calories.id], closeTo(100, 1e-12));
        expect(food.nutrients[Nutrient.vitaminB3.id], 16);
        expect(food.nutrients[Nutrient.vitaminB5.id], 5);
        expect(food.nutrients[Nutrient.vitaminB7.id], 50);
        expect(food.nutrients[Nutrient.vitaminB9.id], closeTo(200, 1e-12));
        expect(food.nutrients.containsKey(Nutrient.protein.id), isFalse);
        expect(food.nutrients, hasLength(5));
      },
    );

    test(
      'Namensfallback, Portionsfallback und ungültige Produkte sind robust',
      () async {
        final validWithoutCode = <String, dynamic>{
          'serving_size': '1 Stück',
          'serving_quantity': 25,
          'nutriments': <String, dynamic>{},
        };
        final named = <String, dynamic>{
          'code': '12345678',
          'product_name_de': ' ',
          'product_name': ' English fallback ',
          'serving_size': '250 ml',
          'nutriments': <String, dynamic>{},
        };
        final api = apiFor(
          (_) => jsonResponse({
            'count': 9,
            'products': ['invalid', validWithoutCode, 42, named],
          }),
        );
        final result = await api.search('x', 1);
        expect(result.total, 9);
        expect(result.foods, hasLength(2));
        expect(result.foods[0].name, 'Open Food Facts');
        expect(result.foods[0].id, matches(RegExp(r'^[0-9a-f]{32}$')));
        expect(result.foods[0].barcode, isNull);
        expect(result.foods[0].portionSize, 25);
        expect(result.foods[1].name, 'English fallback');
        expect(result.foods[1].portionSize, 250);
      },
    );
  });

  group('Barcode-Lookup', () {
    test(
      'Lookup verwendet v3.6 und liefert ein vollständiges Ergebnis',
      () async {
        late http.Request captured;
        final api = apiFor((request) async {
          captured = request;
          return jsonResponse({'status': 1, 'product': completeOffProduct()});
        });
        final result = await api.lookup(' 4001234567890 ');
        expect(result.barcode, '4001234567890');
        expect(result.food, isNotNull);
        expect(result.toJson()['found'], isTrue);
        expect(captured.url.path, '/api/v3.6/product/4001234567890.json');
        expect(captured.url.queryParameters, isEmpty);
      },
    );

    test(
      '404, Status 0 und unbrauchbare Produkte bedeuten nicht gefunden',
      () async {
        final notFound = apiFor((_) async => http.Response('not json', 404));
        final missing = await notFound.lookup('12345678');
        expect(missing.food, isNull);
        expect(missing.toJson(), {
          'barcode': '12345678',
          'found': false,
          'food': null,
        });
        for (final body in [
          {'status': 0, 'product': completeOffProduct()},
          {'status': 1, 'product': null},
          {'status': 1, 'product': []},
        ]) {
          final api = apiFor((_) => jsonResponse(body));
          expect((await api.lookup('12345678')).food, isNull);
        }
      },
    );

    test(
      'fehlender Produktcode nutzt den gesuchten Barcode als Fallback',
      () async {
        final api = apiFor(
          (_) => jsonResponse({
            'status': 1,
            'product': {'nutriments': <String, dynamic>{}},
          }),
        );
        final result = await api.lookup('12345678');
        expect(result.food, isNotNull);
        expect(result.food!.id, 'off:12345678');
        expect(result.food!.barcode, '12345678');
        expect(result.food!.name, 'Open Food Facts 12345678');
      },
    );
  });

  group('Fehlerfälle', () {
    test('HTTP-Fehler erhalten stabile Codes', () async {
      for (final status in [404, 429, 500, 503]) {
        final api = apiFor((_) async => http.Response('error', status));
        await expectLater(
          api.search('x', 1),
          throwsA(
            isA<FoodApiException>().having(
              (error) => error.code,
              'code',
              'http_$status',
            ),
          ),
        );
      }
      final lookupApi = apiFor((_) async => http.Response('error', 500));
      await expectLater(
        lookupApi.lookup('12345678'),
        throwsA(
          isA<FoodApiException>().having(
            (error) => error.code,
            'code',
            'http_500',
          ),
        ),
      );
    });

    test(
      'ungültiges JSON, falscher Wurzeltyp und ungültiges UTF-8 werden invalid_response',
      () async {
        final responses = <http.Response>[
          http.Response('not-json', 200),
          http.Response('[]', 200),
          http.Response.bytes(const [0xff, 0xfe, 0xfd], 200),
        ];
        for (final response in responses) {
          final api = apiFor((_) async => response);
          await expectLater(
            api.search('x', 1),
            throwsA(
              isA<FoodApiException>().having(
                (error) => error.code,
                'code',
                'invalid_response',
              ),
            ),
          );
        }
      },
    );

    test(
      'Netzwerkfehler und Timeout werden von anderen Fehlern unterschieden',
      () async {
        final network = apiFor(
          (_) async => throw http.ClientException('offline'),
        );
        await expectLater(
          network.search('x', 1),
          throwsA(
            isA<FoodApiException>().having(
              (error) => error.code,
              'code',
              'network',
            ),
          ),
        );
        final pending = Completer<http.Response>();
        final timeout = apiFor(
          (_) => pending.future,
          requestTimeout: const Duration(milliseconds: 20),
        );
        await expectLater(
          timeout.lookup('12345678'),
          throwsA(
            isA<FoodApiException>().having(
              (error) => error.code,
              'code',
              'timeout',
            ),
          ),
        );
      },
    );
  });
}

Map<String, dynamic> completeOffProduct() {
  final nutriments = <String, dynamic>{};
  void add(String key, num value, String unit) {
    nutriments['${key}_100g'] = value;
    nutriments['${key}_unit'] = unit;
  }

  add('energy-kcal', 252, 'kcal');
  add('proteins', 12, 'g');
  add('carbohydrates', 5000, 'mg');
  add('fat', 0.002, 'kg');
  add('saturated-fat', 3000, 'mg');
  add('sugars', 4000, 'µg');
  add('fiber', 7, 'g');
  add('salt', 1.5, 'g');
  add('sodium', 0.5, 'g');
  add('caffeine', 80, 'mg');
  add('vitamin-a', 0.8, 'mg');
  add('vitamin-c', 0.05, 'g');
  add('vitamin-d', 20, 'µg');
  add('vitamin-e', 12, 'mg');
  add('vitamin-k', 0.03, 'mg');
  add('vitamin-b1', 1000, 'ug');
  add('vitamin-b2', 0.001, 'g');
  add('vitamin-b3', 16, 'mg');
  add('vitamin-b5', 5, 'mg');
  add('vitamin-b6', 1.4, 'mg');
  add('vitamin-b7', 50, 'µg');
  add('vitamin-b9', 0.2, 'mg');
  add('vitamin-b12', 0.001, 'mg');
  add('calcium', 0.1, 'g');
  add('iron', 14, 'mg');
  add('magnesium', 100000, 'µg');
  add('potassium', 0.001, 'kg');
  add('zinc', 10, 'mg');
  add('selenium', 0.05, 'mg');
  add('iodine', 150, 'µg');
  add('phosphorus', 0.2, 'g');
  return <String, dynamic>{
    'code': '4001234567890',
    'product_name_de': ' Deutsches Müsli ',
    'product_name': 'English name',
    'product_name_en': 'English name',
    'brands': ' Testmarke ',
    'serving_size': '33,5 g',
    'nutriments': nutriments,
  };
}
