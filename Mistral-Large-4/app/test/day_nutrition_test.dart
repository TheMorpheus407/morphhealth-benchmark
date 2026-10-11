// Tests für nutrition/day.dart (Tagesauswertung + Verlaufsserien — SPEC P03/P06).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:morphhealth/src/model/document.dart';
import 'package:morphhealth/src/model/entries.dart';
import 'package:morphhealth/src/model/settings.dart';
import 'package:morphhealth/src/nutrition/day.dart';

import 'helpers.dart';

void main() {
  group('entryNutrients', () {
    test('skaliert pro-100-g-Werte auf die effektive Menge', () {
      final NutritionEntry e = makeNutritionEntry(
        quantity: 150,
        foodPer100: nutrientsWith(<String, double>{
          'energy_kcal': 200,
          'protein_g': 10,
        }),
      );
      final Map<String, double> n = entryNutrients(e);
      expect(n.length, 31); // alle Nährstoffe
      expect(n['energy_kcal'], 300);
      expect(n['protein_g'], 15);
      expect(n['fat_g'], 0);
    });

    test('Portionen und Milliliter verwenden die effektive Masse', () {
      final NutritionEntry portion = makeNutritionEntry(
        quantity: 2,
        unit: QuantityUnit.portion,
        foodServingGrams: 40,
        foodPer100: nutrientsWith(<String, double>{'energy_kcal': 200}),
      );
      expect(entryNutrients(portion)['energy_kcal'], 160); // 80 g
      final NutritionEntry ml = makeNutritionEntry(
        quantity: 250,
        unit: QuantityUnit.ml,
        foodPer100: nutrientsWith(<String, double>{'energy_kcal': 60}),
      );
      expect(entryNutrients(ml)['energy_kcal'], 150); // 250 g
    });
  });

  group('computeDayNutrition', () {
    test('summiert Einträge, Wasser und Koffein eines Tages', () {
      final MorphDocument doc = MorphDocument(
        nutritionEntries: <NutritionEntry>[
          makeNutritionEntry(
            id: 'e1',
            time: '07:30',
            meal: Meal.breakfast,
            quantity: 100,
            foodPer100: nutrientsWith(<String, double>{
              'energy_kcal': 372,
              'protein_g': 13.5,
              'caffeine_mg': 0,
            }),
          ),
          makeNutritionEntry(
            id: 'e2',
            time: '12:00',
            meal: Meal.lunch,
            quantity: 200,
            foodPer100: nutrientsWith(<String, double>{
              'energy_kcal': 100,
              'protein_g': 5,
              'caffeine_mg': 40,
            }),
          ),
          // Anderer Tag — darf nicht mitzählen.
          makeNutritionEntry(
            id: 'e3',
            date: '2026-09-22',
            foodPer100: nutrientsWith(<String, double>{'energy_kcal': 9999}),
          ),
        ],
        waterEntries: <WaterEntry>[
          makeWaterEntry(id: 'w1', amountMl: 250),
          makeWaterEntry(id: 'w2', amountMl: 500, time: '10:00'),
          makeWaterEntry(id: 'w3', date: '2026-09-22', amountMl: 1000),
        ],
        caffeineEntries: <CaffeineEntry>[
          makeCaffeineEntry(id: 'c1', amountMg: 80),
        ],
      );
      final DayNutrition day =
          computeDayNutrition(doc, '2026-09-23');
      expect(day.date, '2026-09-23');
      expect(day.entryCount, 2);
      expect(day.totals.length, 31);
      expect(day.totals['energy_kcal'], 372 + 200);
      expect(day.totals['protein_g'], 23.5); // 13,5 + (200 g × 5 g/100 g)
      expect(day.waterMl, 750);
      expect(day.caffeineManualMg, 80);
      // 80 mg aus dem Lebensmittel (40 mg/100 g × 200 g) + 80 mg manuell.
      expect(day.caffeineTotalMg, 160);
      // Mahlzeitensummen
      expect(day.mealTotals[Meal.breakfast]!['energy_kcal'], 372);
      expect(day.mealTotals[Meal.lunch]!['energy_kcal'], 200);
      expect(day.mealTotals[Meal.dinner]!['energy_kcal'], 0);
      expect(day.mealTotals.length, Meal.values.length);
    });

    test('leerer Tag liefert Nullen', () {
      final DayNutrition day =
          computeDayNutrition(MorphDocument.empty(), '2026-09-23');
      expect(day.entryCount, 0);
      expect(day.waterMl, 0);
      expect(day.totals.values.every((double v) => v == 0), isTrue);
    });

    test('Zielerreichung in Prozent (null ohne Ziel)', () {
      final MorphDocument doc = MorphDocument(
        nutritionEntries: <NutritionEntry>[
          makeNutritionEntry(
            foodPer100: nutrientsWith(<String, double>{
              'energy_kcal': 1000,
              'protein_g': 50,
            }),
          ),
        ],
        waterEntries: <WaterEntry>[makeWaterEntry(amountMl: 1000)],
      );
      final DayNutrition day = computeDayNutrition(doc, '2026-09-23');
      const Goals goals =
          Goals(energyKcal: 2000, proteinG: 100, waterMl: 2000);
      expect(day.percentOfGoal('energy_kcal', goals), 50);
      expect(day.percentOfGoal('protein_g', goals), 50);
      expect(day.percentOfGoal('fat_g', goals), isNull); // kein Ziel
      expect(day.percentOfGoal('sodium_mg', goals), isNull); // kein Makro-Ziel
      expect(day.waterPercentOfGoal(goals), 50);
      expect(day.waterPercentOfGoal(const Goals()), isNull);
      expect(
          day.percentOfGoal('energy_kcal', const Goals(energyKcal: 0)), isNull);
    });

    test('toJson enthält alle dokumentierten Felder', () {
      final MorphDocument doc = MorphDocument(
        nutritionEntries: <NutritionEntry>[makeNutritionEntry()],
        waterEntries: <WaterEntry>[makeWaterEntry()],
      );
      final DayNutrition day = computeDayNutrition(doc, '2026-09-23');
      final Map<String, dynamic> json =
          day.toJson(goals: const Goals(energyKcal: 2000, waterMl: 2000));
      expect(json['date'], '2026-09-23');
      expect((json['totals'] as Map<String, dynamic>).length, 31);
      expect(json['water_ml'], 250);
      expect(json['caffeine_mg'], 0);
      expect(json['caffeine_manual_mg'], 0);
      expect(json['entry_count'], 1);
      expect((json['meals'] as Map<String, dynamic>).keys.toSet(),
          Meal.values.map((Meal m) => m.name).toSet());
      expect(json['goals'], <String, dynamic>{'energy_kcal': 2000, 'water_ml': 2000});
    });
  });

  group('computeNutrientSeries', () {
    test('liefert einen Punkt pro Tag im Bereich (inklusive)', () {
      final MorphDocument doc = MorphDocument(
        nutritionEntries: <NutritionEntry>[
          makeNutritionEntry(
            date: '2026-09-02',
            foodPer100: nutrientsWith(<String, double>{'energy_kcal': 500}),
          ),
        ],
        waterEntries: <WaterEntry>[makeWaterEntry(date: '2026-09-03', amountMl: 300)],
      );
      final List<Map<String, dynamic>> serie =
          computeNutrientSeries(doc, '2026-09-01', '2026-09-03');
      expect(serie.length, 3);
      expect(serie[0]['date'], '2026-09-01');
      expect((serie[0]['totals'] as Map<String, dynamic>)['energy_kcal'], 0);
      expect((serie[1]['totals'] as Map<String, dynamic>)['energy_kcal'], 500);
      expect(serie[2]['water_ml'], 300);
      expect(serie[2]['caffeine_mg'], 0);
    });

    test('ein Tag Bereich liefert genau einen Punkt', () {
      final List<Map<String, dynamic>> serie =
          computeNutrientSeries(MorphDocument.empty(), '2026-09-23', '2026-09-23');
      expect(serie.length, 1);
    });

    test('ungültige Daten liefern eine leere Serie', () {
      expect(computeNutrientSeries(MorphDocument.empty(), 'x', '2026-09-23'),
          isEmpty);
      expect(computeNutrientSeries(MorphDocument.empty(), '2026-09-23', 'y'),
          isEmpty);
    });

    test('Monatsgrenze wird korrekt überschritten', () {
      final List<Map<String, dynamic>> serie = computeNutrientSeries(
          MorphDocument.empty(), '2026-02-27', '2026-03-02');
      expect(serie.map((Map<String, dynamic> m) => m['date']).toList(),
          <String>['2026-02-27', '2026-02-28', '2026-03-01', '2026-03-02']);
    });
  });
}
