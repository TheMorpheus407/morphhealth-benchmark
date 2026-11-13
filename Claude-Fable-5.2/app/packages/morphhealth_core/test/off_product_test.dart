// The fixtures in test/fixtures are answers of the Open Food Facts read API
// (database contents under the Open Database License), fetched with the field
// projection of FoodApiClient.
import 'dart:convert';
import 'dart:io';

import 'package:morphhealth_core/morphhealth_core.dart';
import 'package:test/test.dart';

Map<String, dynamic> _fixture(String name) =>
    jsonDecode(File('test/fixtures/$name').readAsStringSync())
        as Map<String, dynamic>;

CatalogProduct _product(
  String barcode, {
  List<String> languages = const ['de', 'en'],
}) => parseOffProduct(
  _fixture('product_$barcode.json')['product'] as Map<String, dynamic>,
  languages: languages,
)!;

void main() {
  group('product schema 1004 (API v3.6): nutrition.aggregated_set', () {
    test('reads the nutrition facts although "nutriments" is empty', () {
      final raw = _fixture('product_3017620425035.json')['product'] as Map;
      expect(raw['nutriments'], isEmpty);
      expect(raw['schema_version'], 1004);

      final p = _product('3017620425035');
      expect(p.barcode, '3017620425035');
      expect(p.name, 'Nutella');
      expect(p.brand, 'Nutella, FERRERO FRANCE COMMERCIALE');
      expect(p.quantity, '1 kg');
      expect(p.basis, FoodBasis.per100g);
      expect(p.schemaVersion, 1004);
      expect(p.prepared, isFalse);
      expect(p.nutrients[Nutrients.energy], 539);
      expect(p.nutrients[Nutrients.protein], 6.3);
      expect(p.nutrients[Nutrients.carbohydrates], 57.5);
      expect(p.nutrients[Nutrients.fat], 30.9);
      expect(p.nutrients[Nutrients.saturatedFat], 10.6);
      expect(p.nutrients[Nutrients.sugars], 56.3);
      expect(p.nutrients[Nutrients.salt], 0.107);
      expect(p.hasMainNutrients, isTrue);
    });

    test('converts grams to the unit of each nutrient', () {
      final p = _product('3017620425035');
      // 0.0428 g sodium → 42.8 mg
      expect(p.nutrients[Nutrients.sodium], closeTo(42.8, 1e-9));
      final oats = _product('4061464911895');
      expect(
        oats.nutrients[Nutrients.calcium],
        closeTo(84.3, 1e-9),
      ); // 0.0843 g
      expect(
        oats.nutrients[Nutrients.iodine],
        closeTo(0.5, 1e-9),
      ); // 5e-07 g → µg
      expect(
        oats.nutrients[Nutrients.vitaminB9],
        closeTo(39.6, 1e-9),
      ); // 3.96e-05 g
      expect(oats.nutrients[Nutrients.sodium], closeTo(8, 1e-9));
    });

    test('marks estimated values', () {
      final oats = _product('4061464911895');
      // Calcium comes from source "estimate", energy from the packaging.
      expect(oats.estimated, contains('calcium_mg'));
      expect(oats.estimated, contains('vitamin_b12_ug'));
      expect(oats.estimated, isNot(contains('energy_kcal')));
      // Sodium of the spread carries the modifier "~".
      expect(_product('3017620425035').estimated, contains('sodium_mg'));
    });

    test('prefers vitamin K over phylloquinone when both are present', () {
      final oats = _product('4061464911895');
      expect(oats.nutrients[Nutrients.vitaminK], 0);
      expect(oats.estimated, isNot(contains('vitamin_k_ug')));
    });

    test('beverages: per 100 ml, serving in millilitres', () {
      final p = _product('5449000131836');
      expect(p.basis, FoodBasis.per100ml);
      expect(p.servingSize, 500);
      expect(p.servingLabel, '1 Flasche (500 ml)');
      expect(p.nutrients[Nutrients.energy], 0.2);
      expect(p.nutrients[Nutrients.caffeine], closeTo(10, 1e-9)); // 0.01 g
      expect(p.nutrients[Nutrients.salt], 0.05);
      expect(p.nutrients[Nutrients.sodium], closeTo(20, 1e-9));
    });

    test('prepared products are taken and flagged', () {
      final p = _product('4337256382304');
      expect(p.prepared, isTrue);
      expect(p.nutrients[Nutrients.energy], 38);
      expect(p.servingSize, 15);
    });

    test('values the service scaled from a serving are used as given', () {
      final p = _product('5010029201246');
      expect(p.nutrients[Nutrients.energy], closeTo(368.888889, 1e-6));
      expect(p.nutrients[Nutrients.vitaminB12], closeTo(0.0888889, 1e-6)); // µg
      expect(p.nutrients[Nutrients.iron], closeTo(1.7777778, 1e-6)); // mg
      expect(p.servingSize, 45);
    });

    test('a product without nutrition facts is still a product', () {
      final p = _product('4067796001471');
      expect(p.name, 'Apfel Mango Saft');
      expect(p.hasNutrition, isFalse);
      expect(p.nutrients.isEmpty, isTrue);
      expect(p.toJson()['has_nutrition'], isFalse);
    });

    test('names fall back across languages', () {
      // product_name and product_name_de are empty; only English exists.
      final p = _product('20289119');
      expect(p.name, 'Effervescent MultiVitamin - Orange Flavour');
      expect(p.hasName, isTrue);
      expect(p.brand, 'MinaVit, Optisana');
      expect(p.servingSize, isNull, reason: '"1 Tablet" has no size');
      // The preferred language wins when it exists.
      expect(_product('5449000131836').name, 'Zero Zucker');
      expect(
        _product('5449000131836', languages: const ['en', 'de']).name,
        'Coca-Cola Zero 500ml',
      );
    });
  });

  group('older schema: flat nutriments (search endpoint)', () {
    final products = [
      for (final raw in _fixture('search_cola_zero.json')['products'] as List)
        parseOffProduct((raw as Map).cast<String, dynamic>())!,
    ];
    CatalogProduct byCode(String code) =>
        products.firstWhere((p) => p.barcode == code);

    test('reads _100g members and converts their units', () {
      final p = byCode('5449000131836');
      expect(p.basis, FoodBasis.per100ml);
      expect(p.nutrients[Nutrients.energy], 0.2);
      expect(p.nutrients[Nutrients.caffeine], closeTo(10, 1e-9));
      expect(p.nutrients[Nutrients.sodium], closeTo(20, 1e-9));
      expect(p.servingSize, 500);
    });

    test('falls back to prepared values when nothing else is given', () {
      final p = byCode('5000112611762');
      expect(p.prepared, isTrue);
      expect(p.nutrients[Nutrients.energy], 0.4);
      expect(p.servingSize, 250);
    });

    test('both schemas give the same result for the same product', () {
      final viaSearch = byCode('5449000131836');
      final viaProduct = _product('5449000131836');
      for (final n in [
        Nutrients.energy,
        Nutrients.protein,
        Nutrients.salt,
        Nutrients.sodium,
        Nutrients.caffeine,
      ]) {
        expect(
          viaSearch.nutrients[n],
          closeTo(viaProduct.nutrients[n]!, 1e-9),
          reason: n.key,
        );
      }
      expect(viaSearch.basis, viaProduct.basis);
      expect(viaSearch.name, viaProduct.name);
    });
  });

  group('robustness against unusual data', () {
    CatalogProduct parse(Map<String, dynamic> product) =>
        parseOffProduct({'code': '4000000000013', ...product})!;

    test('numbers as strings, kJ only, salt only', () {
      final p = parse({
        'product_name': '  Test&amp;Produkt  ',
        'nutriments': {
          'energy_100g': '1000',
          'proteins_100g': '5,5',
          'salt_100g': 1.25,
        },
      });
      expect(p.name, 'Test&Produkt');
      expect(p.nutrients[Nutrients.energy], closeTo(1000 / 4.184, 1e-9));
      expect(p.nutrients[Nutrients.protein], 5.5);
      expect(
        p.nutrients[Nutrients.sodium],
        isNull,
        reason: 'derived later, when amounts are calculated',
      );
      final food = p.toFood(
        id: 'x',
        now: LocalDateTime.parse('2026-09-23T10:00:00'),
      );
      expect(food.completedNutrients[Nutrients.sodium], closeTo(500, 1e-9));
    });

    test('units in the nutrition structure are honoured', () {
      final p = parse({
        'nutrition': {
          'aggregated_set': {
            'per': '100g',
            'nutrients': {
              'vitamin-c': {'value': 60, 'unit': 'mg'},
              'vitamin-d': {'value': 5, 'unit': 'µg'},
              'vitamin-b12': {'value': 2.5, 'unit': 'mcg'},
              'calcium': {'value': 0.12, 'unit': 'g'},
              'energy-kj': {'value': 418.4, 'unit': 'kJ'},
              'iron': {'value': 15, 'unit': '% DV'},
              'zinc': {'value_computed': 0.002, 'unit': 'g'},
            },
          },
        },
      });
      expect(p.nutrients[Nutrients.vitaminC], closeTo(60, 1e-9));
      expect(p.nutrients[Nutrients.vitaminD], closeTo(5, 1e-9));
      expect(p.nutrients[Nutrients.vitaminB12], closeTo(2.5, 1e-9));
      expect(p.nutrients[Nutrients.calcium], closeTo(120, 1e-9));
      expect(p.nutrients[Nutrients.energy], closeTo(100, 1e-9));
      expect(p.nutrients[Nutrients.iron], isNull);
      expect(p.nutrients[Nutrients.zinc], closeTo(2, 1e-9));
      expect(p.notes.single, contains('iron_mg'));
    });

    test('values per serving are scaled to 100', () {
      final viaNutrition = parse({
        'nutrition': {
          'aggregated_set': {
            'per': 'serving',
            'per_quantity': 250,
            'per_unit': 'ml',
            'nutrients': {
              'energy-kcal': {'value': 105, 'unit': 'kcal'},
              'sugars': {'value': 26.5, 'unit': 'g'},
            },
          },
        },
      });
      expect(viaNutrition.basis, FoodBasis.per100ml);
      expect(viaNutrition.nutrients[Nutrients.energy], closeTo(42, 1e-9));
      expect(viaNutrition.nutrients[Nutrients.sugars], closeTo(10.6, 1e-9));

      final viaNutriments = parse({
        'serving_quantity': '30',
        'serving_quantity_unit': 'g',
        'serving_size': '30 g',
        'nutriments': {'energy-kcal_serving': 120, 'fat_serving': 3},
      });
      expect(viaNutriments.nutrients[Nutrients.energy], closeTo(400, 1e-9));
      expect(viaNutriments.nutrients[Nutrients.fat], closeTo(10, 1e-9));

      final unknownServing = parse({
        'nutriments': {'energy-kcal_serving': 120},
      });
      expect(unknownServing.hasNutrition, isFalse);
      expect(unknownServing.notes.single, contains('per serving'));
    });

    test('without an aggregated set the best input set is chosen', () {
      final p = parse({
        'nutrition': {
          'input_sets': [
            {
              'source': 'estimate',
              'per': '100g',
              'preparation': 'as_sold',
              'nutrients': {
                'proteins': {'value': 1, 'unit': 'g'},
              },
            },
            {
              'source': 'packaging',
              'per': '100g',
              'preparation': 'as_sold',
              'nutrients': {
                'proteins': {'value': 7, 'unit': 'g'},
              },
            },
          ],
        },
      });
      expect(p.nutrients[Nutrients.protein], 7);
      expect(p.estimated, isEmpty);
    });

    test('impossible values are dropped with a note', () {
      final p = parse({
        'nutriments': {
          'carbohydrates_100g': 5750,
          'energy-kcal_100g': 99999,
          'fat_100g': -3,
          'proteins_100g': 12,
        },
      });
      expect(p.nutrients[Nutrients.carbohydrates], isNull);
      expect(p.nutrients[Nutrients.energy], isNull);
      expect(p.nutrients[Nutrients.fat], isNull);
      expect(p.nutrients[Nutrients.protein], 12);
      expect(p.notes, hasLength(2));
    });

    test('serving sizes from free text', () {
      double? size(String text, [String? unit]) => parse({
        'serving_size': text,
        'serving_quantity_unit': ?unit,
      }).servingSize;
      expect(size('30 g'), 30);
      expect(size('1 Glas (0,25 l)'), 250);
      expect(size('2 Scheiben (50g)'), 50);
      expect(size('33', 'g'), 33);
      expect(size('25 cl'), 250);
      expect(size('eine Handvoll'), isNull);
    });

    test('missing pieces never break parsing', () {
      expect(parseOffProduct({'product_name': 'ohne Code'}), isNull);
      final bare = parseOffProduct({'code': 20415655})!;
      expect(bare.barcode, '20415655');
      expect(bare.name, '20415655');
      expect(bare.hasName, isFalse);
      final odd = parse({
        'product_name': 12345,
        'brands': ['kein', 'Text'],
        'nutrition': 'kaputt',
        'nutriments': <Object>[],
        'serving_quantity': {'x': 1},
        'quantity': null,
      });
      expect(odd.name, '12345');
      expect(odd.hasNutrition, isFalse);
      final tags = parse({
        'brands_tags': ['xx:alnatura', 'xx:dm-bio'],
      });
      expect(tags.brand, 'alnatura, dm bio');
      expect(tags.name, 'alnatura, dm bio');
    });
  });

  group('barcodes', () {
    test('normalization follows Open Food Facts', () {
      expect(normalizeBarcode('034000470693'), '0034000470693');
      expect(normalizeBarcode('0000080176800'), '80176800');
      expect(normalizeBarcode('1234567'), '01234567');
      expect(normalizeBarcode('4008400401621'), '4008400401621');
      expect(normalizeBarcode('4008 4004-01621'), '4008400401621');
      expect(normalizeBarcode('abc'), isNull);
      expect(normalizeBarcode('0000'), isNull);
      expect(normalizeBarcode(''), isNull);
    });

    test('check digits', () {
      expect(hasValidGtinCheckDigit('4008400401621'), isTrue);
      expect(hasValidGtinCheckDigit('4008400401622'), isFalse);
      expect(hasValidGtinCheckDigit('80176800'), isTrue);
      expect(hasValidGtinCheckDigit('3017620425035'), isTrue);
      expect(hasValidGtinCheckDigit('12345'), isFalse);
    });
  });
}
