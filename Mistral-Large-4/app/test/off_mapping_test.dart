// Tests für food/off_mapping.dart (OFF-Abbildung, SPEC P08).
//
// Prüft beide Nährwert-Formate desselben Vertrags (flache `nutriments`
// und aggregiertes `nutrition.aggregated_set.nutrients`), Einheiten-
// Umrechnung, Alternativschlüssel, Portionsgrößen und Produkt-Abbildung.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:morphhealth/src/food/off_mapping.dart';
import 'package:morphhealth/src/model/food.dart';

void main() {
  group('mapFlatNutriments', () {
    test('bildet alle Einheiten korrekt ab (g, mg, µg, kcal)', () {
      final Map<String, double> out = mapFlatNutriments(<String, dynamic>{
        'energy-kcal_100g': 250,
        'energy-kcal_unit': 'kcal',
        'proteins_100g': 10.5,
        'proteins_unit': 'g',
        'sodium_100g': 400,
        'sodium_unit': 'mg',
        'vitamin-c_100g': 90,
        'vitamin-c_unit': 'mg',
        'vitamin-a_100g': 800,
        'vitamin-a_unit': 'µg',
        'fiber_100g': 3.5,
        'fiber_unit': 'g',
      });
      expect(out['energy_kcal'], 250);
      expect(out['protein_g'], 10.5);
      expect(out['sodium_mg'], 400);
      expect(out['vitamin_c_mg'], 90);
      expect(out['vitamin_a_ug'], closeTo(800, 1e-9));
      expect(out['fiber_g'], 3.5);
      expect(out.containsKey('fat_g'), isFalse); // nicht gemeldet
    });

    test('Alternativschlüssel (niacin, biotin, folate) werden erkannt', () {
      final Map<String, double> out = mapFlatNutriments(<String, dynamic>{
        'niacin_100g': 16,
        'niacin_unit': 'mg',
        'biotin_100g': 30,
        'biotin_unit': 'µg',
        'folate_100g': 40,
        'folate_unit': 'µg',
        'pantothenic-acid_100g': 5,
        'pantothenic-acid_unit': 'mg',
      });
      expect(out['vitamin_b3_mg'], 16);
      expect(out['vitamin_b7_ug'], closeTo(30, 1e-9));
      expect(out['vitamin_b9_ug'], 40);
      expect(out['vitamin_b5_mg'], 5);
    });

    test('Energie-Fallback: kJ wird in kcal umgerechnet', () {
      final Map<String, double> out = mapFlatNutriments(<String, dynamic>{
        'energy-kj_100g': 1046,
        'energy-kj_unit': 'kJ',
      });
      expect(out['energy_kcal'], closeTo(250, 0.001));
    });

    test('Energie-Fallback: generischer energy-Schlüssel ohne Einheit', () {
      final Map<String, double> out = mapFlatNutriments(<String, dynamic>{
        'energy_100g': 418.4,
      });
      expect(out['energy_kcal'], closeTo(100, 0.001));
    });

    test('kcal hat Vorrang vor kJ-Fallback', () {
      final Map<String, double> out = mapFlatNutriments(<String, dynamic>{
        'energy-kcal_100g': 111,
        'energy-kcal_unit': 'kcal',
        'energy-kj_100g': 9999,
        'energy-kj_unit': 'kJ',
      });
      expect(out['energy_kcal'], 111);
    });

    test('null/leer → leere Map', () {
      expect(mapFlatNutriments(null), isEmpty);
      expect(mapFlatNutriments(<String, dynamic>{}), isEmpty);
    });
  });

  group('mapAggregatedNutrients', () {
    test('liest Werte + Einheiten aus der aggregierten Struktur', () {
      final Map<String, double> out =
          mapAggregatedNutrients(<String, dynamic>{
        'nutrients': <String, dynamic>{
          'energy-kcal': <String, dynamic>{'value': 250, 'unit': 'kcal'},
          'proteins': <String, dynamic>{
            'value': 10.5,
            'unit': 'g',
            'source_per': '100g',
          },
          'calcium': <String, dynamic>{
            'value': 120,
            'unit': 'mg',
            'source_per': '100g',
          },
        },
      });
      expect(out['energy_kcal'], 250);
      expect(out['protein_g'], 10.5);
      expect(out['calcium_mg'], 120);
    });

    test('Einträge pro Portion (source_per != 100g) werden übersprungen', () {
      final Map<String, double> out =
          mapAggregatedNutrients(<String, dynamic>{
        'nutrients': <String, dynamic>{
          'iron': <String, dynamic>{
            'value': 2,
            'unit': 'mg',
            'source_per': 'serving',
          },
        },
      });
      expect(out.containsKey('iron_mg'), isFalse);
    });

    test('kJ-Fallback in der aggregierten Struktur', () {
      final Map<String, double> out =
          mapAggregatedNutrients(<String, dynamic>{
        'nutrients': <String, dynamic>{
          'energy-kj': <String, dynamic>{'value': 1046, 'unit': 'kJ'},
        },
      });
      expect(out['energy_kcal'], closeTo(250, 0.001));
    });

    test('null/leer → leere Map', () {
      expect(mapAggregatedNutrients(null), isEmpty);
      expect(mapAggregatedNutrients(<String, dynamic>{}), isEmpty);
    });
  });

  group('parseServing', () {
    test('serving_quantity + unit (g/ml)', () {
      final Serving? s = parseServing(<String, dynamic>{
        'serving_quantity': 250,
        'serving_quantity_unit': 'ml',
        'serving_size': '250 ml',
      });
      expect(s, isNotNull);
      expect(s!.grams, 250);
      expect(s.label, '250 ml');
    });

    test('serving_size als Fallback ("100.0g", "2 g")', () {
      expect(
          parseServing(<String, dynamic>{'serving_size': '100.0g'})!.grams, 100);
      expect(parseServing(<String, dynamic>{'serving_size': '2 g'})!.grams, 2);
      expect(
          parseServing(<String, dynamic>{'serving_size': '1,5 g'})!.grams, 1.5);
    });

    test('nicht parsebare Angaben liefern null', () {
      expect(parseServing(<String, dynamic>{'serving_size': '1 Portion'}),
          isNull);
      expect(parseServing(<String, dynamic>{}), isNull);
    });
  });

  group('OffProduct.fromProductJson', () {
    test('bevorzugt deutsche Namen, ersten Markennamen, beide Nährwert-Formate '
        '(flache Werte gewinnen)', () {
      final OffProduct? p = OffProduct.fromProductJson(<String, dynamic>{
        'code': '3017620422003',
        'product_name_de': 'Nutella',
        'product_name': 'Nutella EN',
        'brands': 'Ferrero, Andere',
        'quantity': '400 g',
        'image_front_small_url': 'https://img.example/s.jpg',
        'link': 'https://world.openfoodfacts.org/product/3017620422003',
        'nutriments': <String, dynamic>{
          'energy-kcal_100g': 539,
          'energy-kcal_unit': 'kcal',
          'proteins_100g': 6.3,
          'proteins_unit': 'g',
        },
        'nutrition': <String, dynamic>{
          'aggregated_set': <String, dynamic>{
            'nutrients': <String, dynamic>{
              'energy-kcal': <String, dynamic>{'value': 1, 'unit': 'kcal'},
              'fat': <String, dynamic>{
                'value': 30,
                'unit': 'g',
                'source_per': '100g',
              },
            },
          },
        },
        'serving_size': '15 g',
      });
      expect(p, isNotNull);
      expect(p!.barcode, '3017620422003');
      expect(p.name, 'Nutella');
      expect(p.brand, 'Ferrero');
      expect(p.per100['energy_kcal'], 539); // flach gewinnt
      expect(p.per100['protein_g'], 6.3);
      expect(p.per100['fat_g'], 30); // aus aggregierter Struktur ergänzt
      expect(p.serving!.grams, 15);
      expect(p.imageUrl, 'https://img.example/s.jpg');
      expect(p.link, contains('openfoodfacts.org'));
    });

    test('Barcode-Fallback über _id; ohne Namen → Barcode als Name', () {
      final OffProduct? p = OffProduct.fromProductJson(<String, dynamic>{
        '_id': '4006381333931',
      });
      expect(p, isNotNull);
      expect(p!.barcode, '4006381333931');
      expect(p.name, '4006381333931');
    });

    test('ohne Barcode → null', () {
      expect(OffProduct.fromProductJson(<String, dynamic>{'product_name': 'x'}),
          isNull);
    });

    test('toFoodItemSnapshot erzeugt ein OFF-FoodItem', () {
      final OffProduct p = OffProduct.fromProductJson(<String, dynamic>{
        'code': '3017620422003',
        'product_name': 'Nutella',
        'nutriments': <String, dynamic>{'proteins_100g': 6.3, 'proteins_unit': 'g'},
      })!;
      final FoodItem f = p.toFoodItemSnapshot();
      expect(f.source, FoodSource.off);
      expect(f.barcode, '3017620422003');
      expect(f.per100['protein_g'], 6.3);
      expect(f.isCustom, isFalse);
    });

    test('toJson enthält Barcode, Name und Nährwerte', () {
      final OffProduct p = OffProduct.fromProductJson(produktFixtureJson())!;
      final Map<String, dynamic> json = p.toJson();
      expect(json['barcode'], '3017620422003');
      expect(json['name'], 'Nutella');
      expect((json['per100'] as Map<String, dynamic>)['energy_kcal'], 539);
    });
  });
}

Map<String, dynamic> produktFixtureJson() => <String, dynamic>{
      'code': '3017620422003',
      'product_name_de': 'Nutella',
      'nutriments': <String, dynamic>{
        'energy-kcal_100g': 539,
        'energy-kcal_unit': 'kcal',
      },
    };
