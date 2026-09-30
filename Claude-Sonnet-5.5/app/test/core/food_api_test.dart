import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:morphhealth/core/food_api.dart';
import 'package:morphhealth/core/http.dart';
import 'package:morphhealth/core/models.dart';

class FakeTransport implements HttpTransport {
  final Map<String, (int, String)> routes;
  final List<Uri> requests = [];
  final List<Map<String, String>> requestHeaders = [];

  FakeTransport(this.routes);

  @override
  Future<HttpResponse> get(Uri uri, {required Map<String, String> headers, required Duration timeout}) async {
    requests.add(uri);
    requestHeaders.add(headers);
    for (final e in routes.entries) {
      if (uri.path.contains(e.key)) {
        return HttpResponse(e.value.$1, const {}, Uint8List.fromList(utf8.encode(e.value.$2)));
      }
    }
    throw const HttpFailure('offline', 'Keine Verbindung');
  }
}

String fixture(String name) => File('test/fixtures/off/$name').readAsStringSync();

FoodApi api(FakeTransport t, {String lang = 'de'}) =>
    FoodApi(baseUrl: 'https://localhost:8788', userAgent: 'MorphHealth/1.0-rc3 (test)', transport: t, language: lang);

void main() {
  test('Basis-URL: nur HTTPS-Ursprung', () {
    expect(FoodApi.parseBaseUrl('https://world.openfoodfacts.org/').toString(), 'https://world.openfoodfacts.org');
    expect(FoodApi.parseBaseUrl('https://localhost:8788').port, 8788);
    for (final bad in ['http://x.org', 'ftp://x', 'x.org', 'https://x.org/api', 'https://', '']) {
      expect(() => FoodApi.parseBaseUrl(bad), throwsA(isA<FoodApiException>()), reason: bad);
    }
  });

  test('Barcode: Normalisierung und Prüfung', () {
    expect(FoodApi.normalizeBarcode(' 4008400 402222 '), '4008400402222');
    expect(FoodApi.normalizeBarcode('4008-4004-02222'), '4008400402222');
    for (final bad in ['123', 'abcdefgh', '123456789012345', '']) {
      expect(() => FoodApi.normalizeBarcode(bad), throwsA(isA<FoodApiException>()), reason: bad);
    }
  });

  test('Abruf: Anfrage entspricht dem Vertrag (Pfad, User-Agent)', () async {
    final t = FakeTransport({'/api/v3.6/product/': (200, fixture('lookup_4008400402222.json'))});
    await api(t).lookup('4008400402222');
    expect(t.requests.single.path, '/api/v3.6/product/4008400402222.json');
    expect(t.requests.single.host, 'localhost');
    expect(t.requests.single.port, 8788);
    expect(t.requestHeaders.single['user-agent'], 'MorphHealth/1.0-rc3 (test)');
  });

  test('Abruf Nutella (neues Schema): Packungswerte, keine Schätzungen', () async {
    final t = FakeTransport({'/api/v3.6/product/': (200, fixture('lookup_4008400402222.json'))});
    final r = await api(t).lookup('4008400402222');
    final f = r.food;
    expect(f.name, 'Nutella');
    expect(f.brand, 'Ferrero');
    expect(f.barcode, '4008400402222');
    expect(f.source, FoodSource.off);
    expect(f.basis, Basis.g);
    expect(f.serving!.amount, 15);
    expect(f.nutrients['energy_kcal'], 539);
    expect(f.nutrients['protein_g'], 6.3);
    expect(f.nutrients['carbohydrates_g'], 57.5);
    expect(f.nutrients['fat_g'], 30.9);
    expect(f.nutrients['saturated_fat_g'], 10.6);
    expect(f.nutrients['sugars_g'], 56.3);
    expect(f.nutrients['fiber_g'], 3);
    expect(f.nutrients['salt_g'], 0.11);
    expect(f.nutrients['sodium_mg'], closeTo(44, 1e-9));
    // Kalzium kommt im Datensatz nur als Schätzung aus der Zutatenliste vor.
    expect(f.nutrients.has('calcium_mg'), isFalse);
    expect(f.nutrients.has('iron_mg'), isFalse);
    expect(r.nutritionSource, 'input_set');
    expect(f.prepared, isFalse);
  });

  test('Abruf Getränk: je 100 ml, "wie verkauft" vor "zubereitet"', () async {
    final t = FakeTransport({'/api/v3.6/product/': (200, fixture('lookup_5000112611762.json'))});
    final f = (await api(t).lookup('5000112611762')).food;
    expect(f.basis, Basis.ml);
    expect(f.serving!.amount, 250);
    expect(f.nutrients['energy_kcal'], 0.3);
    expect(f.prepared, isFalse);
  });

  test('Abruf mit widersprüchlichem "zubereitet"-Satz: verkaufter Zustand gewinnt', () async {
    final t = FakeTransport({'/api/v3.6/product/': (200, fixture('lookup_20568610.json'))});
    final f = (await api(t).lookup('20568610')).food;
    expect(f.nutrients['energy_kcal'], 229);
    expect(f.nutrients['protein_g'], 7.7);
    expect(f.prepared, isFalse);
  });

  test('Abruf nicht gefunden: 404 wird zu not_found', () async {
    final t = FakeTransport({'/api/v3.6/product/': (404, fixture('lookup_notfound.json'))});
    await expectLater(
      api(t).lookup('0000000000000'),
      throwsA(isA<FoodApiException>().having((e) => e.code, 'code', 'not_found')),
    );
  });

  test('Netzfehler werden als offline gemeldet', () async {
    final t = FakeTransport({});
    await expectLater(
      api(t).search('milch'),
      throwsA(isA<FoodApiException>().having((e) => e.code, 'code', 'offline')),
    );
  });

  test('HTTP 429 und 503: rate_limited', () async {
    for (final s in [429, 503]) {
      final t = FakeTransport({'/cgi/search.pl': (s, '')});
      await expectLater(
        api(t).search('milch'),
        throwsA(isA<FoodApiException>().having((e) => e.code, 'code', 'rate_limited')),
      );
    }
  });

  test('Suche: Anfrage entspricht dem Vertrag', () async {
    final t = FakeTransport({'/cgi/search.pl': (200, fixture('search_haferflocken.json'))});
    final page = await api(t).search('Hafer flocken äö', page: 2);
    final u = t.requests.single;
    expect(u.path, '/cgi/search.pl');
    expect(
      u.query,
      startsWith('search_terms=Hafer+flocken+%C3%A4%C3%B6&search_simple=1&action=process&json=1&page=2&page_size=20'),
    );
    expect(u.queryParameters['search_terms'], 'Hafer flocken äö');
    expect(u.queryParameters['fields'], contains('nutriments'));
    expect(t.requestHeaders.single['user-agent'], contains('MorphHealth'));
    expect(page.page, 2);
  });

  test('Suche: Ergebnisse (klassisches Schema) werden ausgewertet', () async {
    final t = FakeTransport({'/cgi/search.pl': (200, fixture('search_haferflocken.json'))});
    final page = await api(t).search('haferflocken');
    expect(page.total, 548);
    expect(page.pageSize, 20);
    expect(page.items.length, 20);
    expect(page.hasMore, isTrue);
    final koelln = page.items.firstWhere((f) => f.barcode == '4000540000108');
    expect(koelln.name, 'Vollkorn-Haferflocken');
    expect(koelln.brand, 'Kölln');
    expect(koelln.nutrients['energy_kcal'], 361);
    expect(koelln.serving!.amount, 40);
    expect(koelln.basis, Basis.g);
    expect(page.items.map((f) => f.barcode).toSet().length, page.items.length);
  });

  test('Leere Suche und leerer Barcode werden vor dem Netz abgewiesen', () async {
    final t = FakeTransport({});
    await expectLater(
      api(t).search('  '),
      throwsA(isA<FoodApiException>().having((e) => e.code, 'code', 'empty_query')),
    );
    await expectLater(
      api(t).lookup('12'),
      throwsA(isA<FoodApiException>().having((e) => e.code, 'code', 'invalid_barcode')),
    );
    expect(t.requests, isEmpty);
  });

  test('Klassisches Schema im Produktabruf (ältere Server)', () async {
    final legacy = jsonEncode({
      'code': '4000540000108',
      'status': 1,
      'product': {
        'code': '4000540000108',
        'product_name': 'Testflocken',
        'brands': 'Marke A, Marke B',
        'nutrition_data_per': '100g',
        'serving_size': '40 g',
        'nutriments': {
          'energy-kj_100g': 1500,
          'proteins_100g': 13.5,
          'carbohydrates_100g': 58.7,
          'fat_100g': 7,
          'vitamin-c_100g': 0.012,
          'vitamin-d_100g': 0.0000025,
          'sodium_100g': 0.005,
          'caffeine_100g': 0.032,
        },
      },
    });
    final t = FakeTransport({'/api/v3.6/product/': (200, legacy)});
    final r = await api(t).lookup('4000540000108');
    final f = r.food;
    expect(r.nutritionSource, 'legacy_nutriments');
    expect(f.brand, 'Marke A');
    expect(f.nutrients['energy_kcal'], closeTo(1500 / 4.184, 1e-9));
    expect(f.nutrients['vitamin_c_mg'], closeTo(12, 1e-9));
    expect(f.nutrients['vitamin_d_ug'], closeTo(2.5, 1e-9));
    expect(f.nutrients['sodium_mg'], closeTo(5, 1e-9));
    expect(f.nutrients['caffeine_mg'], closeTo(32, 1e-9));
    expect(f.serving!.amount, 40);
  });

  test('Neues Schema: Einheiten mg und µg, Portionswerte werden auf 100 g umgerechnet', () async {
    final doc = jsonEncode({
      'code': '1234567890123',
      'status': 'success',
      'product': {
        'code': '1234567890123',
        'product_name': 'Kapseln',
        'nutrition': {
          'input_sets': [
            {
              'source': 'manufacturer',
              'per': 'serving',
              'per_quantity': 25,
              'per_unit': 'g',
              'preparation': 'as_sold',
              'nutrients': {
                'energy-kcal': {'value': 100, 'unit': 'kcal'},
                'proteins': {'value': 5, 'unit': 'g'},
                'vitamin-c': {'value': 60, 'unit': 'mg'},
                'vitamin-b12': {'value': 2.5, 'unit': 'µg'},
                'iodine': {'value': 0.00015, 'unit': 'g'},
              },
            },
            {
              'source': 'estimate',
              'per': '100g',
              'per_quantity': 100,
              'per_unit': 'g',
              'preparation': 'as_sold',
              'nutrients': {
                'energy-kcal': {'value': 999, 'unit': 'kcal', 'modifier': '~'},
              },
            },
          ],
        },
      },
    });
    final t = FakeTransport({'/api/v3.6/product/': (200, doc)});
    final r = await api(t).lookup('1234567890123');
    final n = r.food.nutrients;
    expect(r.nutritionSource, 'input_set_per_serving');
    expect(n['energy_kcal'], closeTo(400, 1e-9));
    expect(n['protein_g'], closeTo(20, 1e-9));
    expect(n['vitamin_c_mg'], closeTo(240, 1e-9));
    expect(n['vitamin_b12_ug'], closeTo(10, 1e-9));
    expect(n['iodine_ug'], closeTo(600, 1e-9));
    expect(r.food.serving!.amount, 25); // Portionsgröße aus dem Eingabesatz
  });

  test('Produkt ohne Nährwerte bleibt verwendbar', () async {
    final doc = jsonEncode({
      'code': '1234567890123',
      'status': 'success',
      'product': {
        'code': '1234567890123',
        'product_name': 'Ohne Werte',
        'nutrition': {
          'input_sets': [],
          'aggregated_set': {'nutrients': {}},
        },
      },
    });
    final t = FakeTransport({'/api/v3.6/product/': (200, doc)});
    final f = (await api(t).lookup('1234567890123')).food;
    expect(f.nutrients.isEmpty, isTrue);
    expect(f.name, 'Ohne Werte');
  });

  test('Englischer Produktname bei Sprache en', () async {
    final doc = jsonEncode({
      'code': '1234567890123',
      'status': 'success',
      'product': {
        'code': '1234567890123',
        'product_name': 'Haferflocken',
        'product_name_en': 'Oat flakes',
        'product_name_de': 'Haferflocken',
      },
    });
    final t = FakeTransport({'/api/v3.6/product/': (200, doc)});
    expect((await api(t, lang: 'en').lookup('1234567890123')).food.name, 'Oat flakes');
    expect((await api(t).lookup('1234567890123')).food.name, 'Haferflocken');
  });
}
