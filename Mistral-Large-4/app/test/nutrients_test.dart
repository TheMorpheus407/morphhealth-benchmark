// Tests für nutrients/nutrients.dart (kanonische Nährstoffliste + OFF-Umrechnung).
//
// SPEC P03 verlangt alle 31 Nährstoffe (10 Haupt-, 13 Vitamin-, 8 Mineralstoffe).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:morphhealth/src/nutrients/nutrients.dart';

void main() {
  group('Nährstoffliste', () {
    test('genau 31 Nährstoffe (SPEC P03)', () {
      expect(nutrientDefs.length, 31);
      expect(mainNutrients.length, 10);
      expect(vitaminNutrients.length, 13);
      expect(mineralNutrients.length, 8);
    });

    test('alle geforderten Makro-/Mikronährstoffe vorhanden', () {
      const List<String> erwartet = <String>[
        // Hauptnährstoffe
        'energy_kcal', 'protein_g', 'carbohydrates_g', 'fat_g',
        'saturated_fat_g', 'sugars_g', 'fiber_g', 'salt_g', 'sodium_mg',
        'caffeine_mg',
        // Vitamine A, C, D, E, K, B1, B2, B3, B5, B6, B7, B9, B12
        'vitamin_a_ug', 'vitamin_c_mg', 'vitamin_d_ug', 'vitamin_e_mg',
        'vitamin_k_ug', 'vitamin_b1_mg', 'vitamin_b2_mg', 'vitamin_b3_mg',
        'vitamin_b5_mg', 'vitamin_b6_mg', 'vitamin_b7_ug', 'vitamin_b9_ug',
        'vitamin_b12_ug',
        // Mineralstoffe
        'calcium_mg', 'iron_mg', 'magnesium_mg', 'potassium_mg', 'zinc_mg',
        'selenium_ug', 'iodine_ug', 'phosphorus_mg',
      ];
      expect(nutrientDefs.map((NutrientDef d) => d.key).toList(),
          containsAll(erwartet));
    });

    test('Schlüssel eindeutig, nutrientByKey konsistent', () {
      final Set<String> keys =
          nutrientDefs.map((NutrientDef d) => d.key).toSet();
      expect(keys.length, nutrientDefs.length);
      for (final NutrientDef d in nutrientDefs) {
        expect(nutrientByKey(d.key), same(d));
      }
      expect(nutrientByKey('unbekannt'), isNull);
    });

    test('leere Tabelle enthält alle 31 Schlüssel mit 0', () {
      final Map<String, double> m = emptyNutrientMap();
      expect(m.length, 31);
      expect(m.values.every((double v) => v == 0), isTrue);
    });

    test('macroGoalKeys sind Protein, Kohlenhydrate, Fett', () {
      expect(macroGoalKeys,
          <String>['protein_g', 'carbohydrates_g', 'fat_g']);
    });
  });

  group('gramsToCanonical', () {
    test('rechnet Gramm in die kanonische Einheit um', () {
      expect(gramsToCanonical('protein_g', 10), 10);
      expect(gramsToCanonical('sodium_mg', 0.4), 400);
      expect(gramsToCanonical('vitamin_a_ug', 0.0008), 800);
      expect(gramsToCanonical('energy_kcal', 250), 250);
    });

    test('unbekannter Schlüssel liefert den Wert unverändert', () {
      expect(gramsToCanonical('unbekannt', 5), 5);
    });
  });

  group('offUnitToGramsFactor', () {
    test('bekannte Masseneinheiten', () {
      expect(offUnitToGramsFactor('g'), 1);
      expect(offUnitToGramsFactor('mg'), 0.001);
      expect(offUnitToGramsFactor('µg'), 0.000001);
      expect(offUnitToGramsFactor('ug'), 0.000001);
      expect(offUnitToGramsFactor('μg'), 0.000001);
      expect(offUnitToGramsFactor('kg'), 1000);
    });

    test('fehlende Einheit wird als Gramm angenommen', () {
      expect(offUnitToGramsFactor(null), 1);
      expect(offUnitToGramsFactor(''), 1);
    });

    test('nicht umrechenbare Einheiten liefern null', () {
      expect(offUnitToGramsFactor('kcal'), isNull);
      expect(offUnitToGramsFactor('kJ'), isNull);
      expect(offUnitToGramsFactor('% vol'), isNull);
    });
  });

  group('offValueToCanonical', () {
    final NutrientDef energy = nutrientByKey('energy_kcal')!;
    final NutrientDef protein = nutrientByKey('protein_g')!;
    final NutrientDef sodium = nutrientByKey('sodium_mg')!;
    final NutrientDef vitA = nutrientByKey('vitamin_a_ug')!;

    test('Energie: kcal direkt, kJ über 4,184', () {
      expect(offValueToCanonical(energy, 250, 'kcal'), 250);
      expect(offValueToCanonical(energy, 250, null), 250);
      expect(offValueToCanonical(energy, 1046, 'kJ'), closeTo(250, 0.001));
      expect(offValueToCanonical(energy, 1046, 'kj'), isNull);
    });

    test('Massewerte werden über die Einheit umgerechnet', () {
      expect(offValueToCanonical(protein, 10.5, 'g'), 10.5);
      expect(offValueToCanonical(protein, 10500, 'mg'), 10.5);
      expect(offValueToCanonical(sodium, 400, 'mg'), 400);
      expect(offValueToCanonical(sodium, 0.4, 'g'), 400);
      // Gleitkomma-Artefakte bei der µg-Umrechnung werden toleriert.
      expect(offValueToCanonical(vitA, 800, 'µg'), closeTo(800, 1e-9));
      expect(offValueToCanonical(vitA, 0.0008, 'g'), closeTo(800, 1e-9));
    });

    test('null-Wert und unpassende Einheit liefern null', () {
      expect(offValueToCanonical(protein, null, 'g'), isNull);
      expect(offValueToCanonical(protein, 10, 'kcal'), isNull);
      expect(offValueToCanonical(protein, 10, '% vol'), isNull);
    });
  });
}
