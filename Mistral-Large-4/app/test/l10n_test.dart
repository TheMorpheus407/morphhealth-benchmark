// Tests für l10n/ (de/en-Texte + Formatierung — SPEC P02).
//
// Deutsch ist Standard; beide Sprachen müssen dieselbe Oberfläche bieten.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:morphhealth/src/l10n/app_strings.dart';
import 'package:morphhealth/src/l10n/app_strings_de.dart';
import 'package:morphhealth/src/l10n/app_strings_en.dart';
import 'package:morphhealth/src/model/cycle.dart';
import 'package:morphhealth/src/model/entries.dart';
import 'package:morphhealth/src/model/settings.dart';
import 'package:morphhealth/src/nutrients/nutrients.dart';

void main() {
  final DeStrings de = DeStrings();
  final EnStrings en = EnStrings();

  group('Sprachauswahl', () {
    test('Deutsch ist Standard', () {
      expect(de.lang, 'de');
      expect(en.lang, 'en');
      expect(normalizeLanguage(null), 'de');
      expect(normalizeLanguage('de'), 'de');
      expect(normalizeLanguage('en'), 'en');
      expect(normalizeLanguage('fr'), 'de'); // unbekannt → de
      expect(stringsFor(null), isA<DeStrings>());
      expect(stringsFor('en'), isA<EnStrings>());
      expect(stringsFor('de'), isA<DeStrings>());
    });

    test('App-Name und Kernbegriffe in beiden Sprachen', () {
      expect(de.appName, 'MorphHealth');
      expect(en.appName, 'MorphHealth');
      expect(de.cancel, isNotEmpty);
      expect(en.cancel, isNotEmpty);
      expect(de.today, 'Heute');
      expect(en.today, 'Today');
      expect(de.errorGeneric, isNotEmpty);
      expect(en.errorGeneric, isNotEmpty);
    });
  });

  group('Zahlenformatierung', () {
    test('formatNumber: Tausendertrennung und Dezimalkomma je Sprache', () {
      expect(de.formatNumber(1234.5), '1.234,5');
      expect(en.formatNumber(1234.5), '1,234.5');
      expect(de.formatNumber(2), '2');
      expect(en.formatNumber(2), '2');
      expect(de.formatNumber(0.25), '0,3'); // 1 Nachkommastelle, gerundet
      expect(de.formatNumber(1234.5, fractionDigits: 0), '1.235'); // rundet
      expect(de.formatNumber(-12.5), '-12,5');
      expect(en.formatNumber(-12.5), '-12.5');
    });

    test('formatInteger/formatPercent/formatMl/formatMg', () {
      expect(de.formatInteger(1234), '1.234');
      expect(en.formatInteger(1234), '1,234');
      expect(de.formatPercent(50), '50 %');
      expect(en.formatPercent(50), '50 %');
      expect(de.formatMl(500), '500 ml');
      expect(en.formatMl(500), '500 ml');
      expect(de.formatMg(80), '80 mg');
      expect(en.formatMg(80), '80 mg');
    });

    test('formatWeight rechnet kg → lb um', () {
      expect(de.formatWeight(72.5, 'kg'), '72,5 kg');
      expect(en.formatWeight(72.5, 'kg'), '72.5 kg');
      expect(de.formatWeight(72.5, 'lb'), '159,8 lb');
      expect(en.formatWeight(72.5, 'lb'), '159.8 lb');
    });
  });

  group('Nährstoffe: Namen, Einheiten, Formatierung', () {
    test('alle 31 Nährstoffe haben Namen und Kürzel in beiden Sprachen', () {
      for (final NutrientDef def in nutrientDefs) {
        expect(de.nutrientName(def.key), isNotEmpty, reason: def.key);
        expect(en.nutrientName(def.key), isNotEmpty, reason: def.key);
        expect(de.nutrientShort(def.key), isNotEmpty, reason: def.key);
        expect(en.nutrientShort(def.key), isNotEmpty, reason: def.key);
        expect(de.nutrientUnit(def.key), isNotEmpty, reason: def.key);
        expect(en.nutrientUnit(def.key), isNotEmpty, reason: def.key);
      }
    });

    test('Namen spot-check (de/en)', () {
      expect(de.nutrientName('energy_kcal'), 'Kalorien');
      expect(en.nutrientName('energy_kcal'), 'Calories');
      expect(de.nutrientName('vitamin_b9_ug'), 'Vitamin B9 (Folsäure)');
      expect(en.nutrientName('vitamin_b12_ug'), 'Vitamin B12');
      expect(de.nutrientName('selenium_ug'), 'Selen');
      expect(en.nutrientName('iodine_ug'), 'Iodine');
      expect(de.nutrientShort('sodium_mg'), 'Natrium');
      expect(en.nutrientShort('sodium_mg'), 'Sodium');
    });

    test('Einheiten und Nachkommastellen', () {
      expect(de.nutrientUnit('energy_kcal'), 'kcal');
      expect(de.nutrientUnit('protein_g'), 'g');
      expect(de.nutrientUnit('sodium_mg'), 'mg');
      expect(de.nutrientUnit('vitamin_a_ug'), 'µg');
      expect(en.nutrientUnit('vitamin_a_ug'), 'µg');
      expect(de.nutrientUnit('unbekannt'), '');
      expect(de.nutrientFractionDigits('energy_kcal'), 0);
      expect(de.nutrientFractionDigits('protein_g'), 1);
      expect(de.nutrientAmount('protein_g', 13.5), '13,5 g');
      expect(en.nutrientAmount('protein_g', 13.5), '13.5 g');
      expect(en.nutrientAmount('energy_kcal', 372), '372 kcal');
    });

    test('trendMetricName deckt Spezialschlüssel ab', () {
      expect(de.trendMetricName('water'), 'Wasser');
      expect(en.trendMetricName('water'), 'Water');
      expect(de.trendMetricName('weight'), 'Gewicht');
      expect(de.trendMetricName('energy_kcal'), 'Kalorien');
      expect(en.trendMetricName('caffeine'), 'Caffeine');
    });
  });

  group('Bereiche, Mahlzeiten, Einheiten, Blutung', () {
    test('areaName für alle Bereiche + Übersicht', () {
      for (final String key in <String>[...areaKeys, 'overview']) {
        expect(de.areaName(key), isNotEmpty, reason: key);
        expect(en.areaName(key), isNotEmpty, reason: key);
      }
      expect(de.areaName('nutrition'), 'Ernährung');
      expect(en.areaName('nutrition'), 'Nutrition');
      expect(de.areaName('cycle'), 'Zyklus');
      expect(en.areaName('symptoms'), 'Symptoms');
      expect(de.areaName('overview'), 'Übersicht');
      expect(en.areaName('overview'), 'Overview');
    });

    test('mealName', () {
      expect(de.mealName(Meal.breakfast), 'Frühstück');
      expect(de.mealName(Meal.lunch), 'Mittagessen');
      expect(de.mealName(Meal.dinner), 'Abendessen');
      expect(de.mealName(Meal.snack), 'Snack');
      expect(en.mealName(Meal.breakfast), 'Breakfast');
      expect(en.mealName(Meal.dinner), 'Dinner');
    });

    test('quantityUnitName', () {
      expect(de.quantityUnitName(QuantityUnit.g), 'Gramm');
      expect(de.quantityUnitName(QuantityUnit.ml), 'Milliliter');
      expect(de.quantityUnitName(QuantityUnit.portion), 'Portion');
      expect(en.quantityUnitName(QuantityUnit.g), 'Grams');
      expect(en.quantityUnitName(QuantityUnit.portion), 'Serving');
    });

    test('flowName', () {
      expect(de.flowName(FlowLevel.spotting), 'Spotting');
      expect(de.flowName(FlowLevel.light), 'leicht');
      expect(de.flowName(FlowLevel.medium), 'mittel');
      expect(de.flowName(FlowLevel.heavy), 'stark');
      expect(en.flowName(FlowLevel.light), 'Light');
      expect(en.flowName(FlowLevel.heavy), 'Heavy');
    });
  });

  group('Datum/Uhrzeit und Zähltexte', () {
    final DateTime mittwoch = DateTime(2026, 9, 23); // Mittwoch

    test('formatDateShort/Long', () {
      expect(de.formatDateShort(mittwoch), '23.09.2026');
      expect(en.formatDateShort(mittwoch), '2026-09-23');
      expect(de.formatDateLong(mittwoch), 'Mittwoch, 23. September 2026');
      expect(en.formatDateLong(mittwoch), 'Wednesday, September 23, 2026');
    });

    test('Wochentage und Monate', () {
      expect(de.weekdayName(1), 'Montag');
      expect(de.weekdayName(7), 'Sonntag');
      expect(en.weekdayName(1), 'Monday');
      expect(en.weekdayName(7), 'Sunday');
      expect(de.weekdayShort(3), 'Mi');
      expect(en.weekdayShort(3), 'Wed');
      expect(de.monthName(9), 'September');
      expect(en.monthName(9), 'September');
      expect(de.monthShort(12), 'Dez');
      expect(en.monthShort(12), 'Dec');
    });

    test('Zähltexte mit korrekter Singular/Plural-Form', () {
      expect(de.daysCount(1), '1 Tag');
      expect(de.daysCount(7), '7 Tage');
      expect(en.daysCount(1), '1 day');
      expect(en.daysCount(7), '7 days');
      expect(de.entriesCount(1), '1 Eintrag');
      expect(de.entriesCount(2), '2 Einträge');
      expect(en.entriesCount(1), '1 entry');
      expect(en.entriesCount(2), '2 entries');
      expect(de.resultsCount(1), '1 Treffer');
      expect(en.resultsCount(3), '3 results');
      expect(de.cycleDayLabel(3), 'Zyklustag 3');
      expect(en.cycleDayLabel(3), 'Cycle day 3');
      expect(de.intensityValue(4), 'Intensität 4/10');
      expect(en.intensityValue(4), 'Intensity 4/10');
    });

    test('imported/savedAt/percentOfGoal', () {
      expect(de.imported('Ernährung', 3), 'Ernährung: 3');
      expect(en.imported('Nutrition', 3), 'Nutrition: 3');
      expect(de.savedAt('/tmp/x.json'), 'Gespeichert unter: /tmp/x.json');
      expect(en.savedAt('/tmp/x.json'), 'Saved to: /tmp/x.json');
      expect(de.percentOfGoal(50), '50 % vom Ziel');
      expect(en.percentOfGoal(50), '50 % of goal');
    });
  });

  group('Barrierefreiheit (Accessibility-Labels)', () {
    test('a11y-Labels sind in beiden Sprachen belegt', () {
      final List<String Function(AppStrings)> felder = <String Function(AppStrings)>[
        (AppStrings s) => s.a11yBack,
        (AppStrings s) => s.a11yMenu,
        (AppStrings s) => s.a11yAdd,
        (AppStrings s) => s.a11yEdit,
        (AppStrings s) => s.a11yDelete,
        (AppStrings s) => s.a11ySearch,
        (AppStrings s) => s.a11yFavorite,
        (AppStrings s) => s.a11yIncrement,
        (AppStrings s) => s.a11yDecrement,
        (AppStrings s) => s.a11yCalendar,
        (AppStrings s) => s.a11yClose,
      ];
      for (final String Function(AppStrings) f in felder) {
        expect(f(de), isNotEmpty);
        expect(f(en), isNotEmpty);
      }
    });
  });
}
