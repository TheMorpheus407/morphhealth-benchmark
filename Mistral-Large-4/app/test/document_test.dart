// Tests für model/document.dart (Daten-Dokument + portables Exportformat)
// und die JSON-Roundtrips aller Modelle (SPEC P07).
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:morphhealth/src/core/exceptions.dart';
import 'package:morphhealth/src/model/cycle.dart';
import 'package:morphhealth/src/model/document.dart';
import 'package:morphhealth/src/model/entries.dart';
import 'package:morphhealth/src/model/food.dart';
import 'package:morphhealth/src/model/settings.dart';

import 'helpers.dart';

/// Ein Dokument mit je einem Datensatz pro Bereich.
MorphDocument vollesDokument() {
  return MorphDocument(
    settings: AppSettings(
      language: 'de',
      weightUnit: 'lb',
      visibleAreas: <String>['nutrition', 'weight'],
      goals: const Goals(waterMl: 2000, energyKcal: 2200, proteinG: 90),
    ),
    foods: <FoodItem>[
      makeFood(id: 'f1', name: 'Haferflocken', brand: 'Beispiel',
          serving: const Serving(grams: 40, label: '1 Portion'),
          isFavorite: true),
      makeFood(id: 'f2', name: 'Vollmilch', source: FoodSource.off,
          barcode: '4008400404125'),
    ],
    nutritionEntries: <NutritionEntry>[
      makeNutritionEntry(id: 'e1', time: '07:30', meal: Meal.breakfast,
          quantity: 1.5, unit: QuantityUnit.portion, foodServingGrams: 40,
          note: 'mit Milch'),
      makeNutritionEntry(id: 'e2', foodId: 'f2', foodName: 'Vollmilch',
          date: '2026-09-22', time: '08:00', meal: Meal.snack,
          quantity: 250, unit: QuantityUnit.ml),
    ],
    waterEntries: <WaterEntry>[makeWaterEntry(id: 'w1', amountMl: 500)],
    caffeineEntries: <CaffeineEntry>[
      makeCaffeineEntry(id: 'c1', amountMg: 80, note: 'Kaffee'),
    ],
    periods: <PeriodRecord>[
      makePeriod(id: 'p1', start: '2026-08-28', end: '2026-09-01',
          flow: FlowLevel.heavy, flowByDay: <String, int>{'2026-08-28': 3}),
      makePeriod(id: 'p2', start: '2026-09-25', end: null),
    ],
    weightEntries: <WeightEntry>[makeWeightEntry(id: 'g1', weightKg: 72.5)],
    symptomEntries: <SymptomEntry>[
      makeSymptomEntry(id: 's1', name: 'Kopfschmerzen', intensity: 4),
    ],
  );
}

void main() {
  group('MorphDocument: Daten-Roundtrip', () {
    test('leeres Dokument hat alle 8 Datenfelder', () {
      final Map<String, dynamic> json = MorphDocument.empty().toDataJson();
      expect(json.keys.toSet(), <String>{
        'settings', 'foods', 'nutrition_entries', 'water_entries',
        'caffeine_entries', 'periods', 'weight_entries', 'symptom_entries',
      });
    });

    test('Daten-Roundtrip erhält alle Datensätze und Felder', () {
      final MorphDocument original = vollesDokument();
      final MorphDocument copy =
          MorphDocument.fromDataJson(original.toDataJson());
      expect(copy.settings.language, 'de');
      expect(copy.settings.weightUnit, 'lb');
      expect(copy.settings.visibleAreas, <String>['nutrition', 'weight']);
      expect(copy.settings.goals.waterMl, 2000);
      expect(copy.settings.goals.proteinG, 90);
      expect(copy.settings.goals.fatG, isNull);
      expect(copy.foods.length, 2);
      expect(copy.foods[0].serving!.grams, 40);
      expect(copy.foods[0].isFavorite, isTrue);
      expect(copy.foods[1].source, FoodSource.off);
      expect(copy.nutritionEntries.length, 2);
      expect(copy.nutritionEntries[0].meal, Meal.breakfast);
      expect(copy.nutritionEntries[0].unit, QuantityUnit.portion);
      expect(copy.nutritionEntries[1].quantity, 250);
      expect(copy.waterEntries.single.amountMl, 500);
      expect(copy.caffeineEntries.single.note, 'Kaffee');
      expect(copy.periods.length, 2);
      expect(copy.periods[0].flow, FlowLevel.heavy);
      expect(copy.periods[0].flowByDay['2026-08-28'], 3);
      expect(copy.periods[1].isOngoing, isTrue);
      expect(copy.weightEntries.single.weightKg, 72.5);
      expect(copy.symptomEntries.single.intensity, 4);
    });

    test('Daten-JSON ist UTF-8-JSON-serialisierbar (keine DateTime-Lecks)', () {
      final MorphDocument doc = vollesDokument();
      final String encoded = jsonEncode(doc.toDataJson());
      expect(encoded, isNotEmpty);
      // createdAt/updatedAt müssen als ISO-Strings serialisiert sein.
      expect(encoded, contains('2026-09-23T08:00:00.000Z'));
    });
  });

  group('MorphDocument: portables Format', () {
    test('Portable-Roundtrip erhält den vollständigen Datenbestand', () {
      final MorphDocument original = vollesDokument();
      final Map<String, dynamic> portable = original.toPortableJson(
        const AppInfo(name: 'MorphHealth', version: '1.0.0+1'),
        exportedAt: DateTime.utc(2026, 9, 23, 12),
      );
      expect(portable['format'], 'morphhealth.portable');
      expect(portable['format_version'], 1);
      expect(portable['generator'], isA<Map<String, dynamic>>());

      final MorphDocument copy = MorphDocument.fromPortableJson(portable);
      expect(copy.foods.length, 2);
      expect(copy.nutritionEntries.length, 2);
      expect(copy.waterEntries.length, 1);
      expect(copy.caffeineEntries.length, 1);
      expect(copy.periods.length, 2);
      expect(copy.weightEntries.length, 1);
      expect(copy.symptomEntries.length, 1);
      expect(copy.settings.weightUnit, 'lb');
    });

    test('portables Dokument ist JSON-serialisierbar', () {
      final Map<String, dynamic> portable =
          vollesDokument().toPortableJson(const AppInfo());
      expect(() => jsonEncode(portable), returnsNormally);
    });

    test('falsche Formatkennung wird abgelehnt', () {
      final Map<String, dynamic> doc = vollesDokument()
          .toPortableJson(const AppInfo())
          .cast<String, dynamic>();
      doc['format'] = 'anderes.format';
      expect(() => MorphDocument.fromPortableJson(doc),
          throwsA(isA<MorphException>()
              .having((MorphException e) => e.code, 'code', 'portable.invalid_format')));
    });

    test('neuere Formatversion wird abgelehnt', () {
      final Map<String, dynamic> doc = vollesDokument()
          .toPortableJson(const AppInfo())
          .cast<String, dynamic>();
      doc['format_version'] = 99;
      expect(() => MorphDocument.fromPortableJson(doc),
          throwsA(isA<MorphException>()
              .having((MorphException e) => e.code, 'code', 'portable.unsupported_version')));
    });

    test('fehlendes data-Objekt wird abgelehnt', () {
      expect(
          () => MorphDocument.fromPortableJson(<String, dynamic>{
                'format': 'morphhealth.portable',
                'format_version': 1,
              }),
          throwsA(isA<MorphException>()
              .having((MorphException e) => e.code, 'code', 'portable.missing_data')));
    });

    test('unbekannte Bereichsschlüssel in visible_areas werden verworfen', () {
      final Map<String, dynamic> data = MorphDocument.empty().toDataJson();
      data['settings'] = <String, dynamic>{
        'visible_areas': <String>['nutrition', 'hack', 'cycle'],
      };
      final MorphDocument doc = MorphDocument.fromDataJson(data);
      expect(doc.settings.visibleAreas, <String>['nutrition', 'cycle']);
    });

    test('leere/unbekannte visible_areas fallen auf alle Bereiche zurück', () {
      final Map<String, dynamic> data = MorphDocument.empty().toDataJson();
      data['settings'] = <String, dynamic>{'visible_areas': <String>[]};
      expect(MorphDocument.fromDataJson(data).settings.visibleAreas.length, 4);
      data['settings'] = <String, dynamic>{'visible_areas': <String>['x']};
      expect(MorphDocument.fromDataJson(data).settings.visibleAreas.length, 4);
    });
  });

  group('MorphDocument: importReport', () {
    test('zählt die Datensätze pro Bereich', () {
      final Map<String, int> report = vollesDokument().importReport();
      expect(report, <String, int>{
        'foods': 2,
        'nutrition_entries': 2,
        'water_entries': 1,
        'caffeine_entries': 1,
        'periods': 2,
        'weight_entries': 1,
        'symptom_entries': 1,
      });
    });
  });

  group('Modelle: Randfälle', () {
    test('SymptomEntry clamped Intensität auf 0..10', () {
      expect(makeSymptomEntry(intensity: 99).intensity, 10);
      expect(makeSymptomEntry(intensity: -5).intensity, 0);
      // Auch über JSON.
      final SymptomEntry e = SymptomEntry.fromJson(
          makeSymptomEntry(id: 'x', intensity: 42).toJson());
      expect(e.intensity, 10);
    });

    test('PeriodRecord.covers respektiert laufende Perioden', () {
      final PeriodRecord laufend =
          makePeriod(start: '2026-09-20', end: null);
      expect(laufend.covers('2026-09-19'), isFalse);
      expect(laufend.covers('2026-09-20'), isTrue);
      expect(laufend.covers('2026-09-23'), isTrue);
      expect(laufend.covers('2026-09-23', today: '2026-09-22'), isFalse);
      final PeriodRecord fertig = makePeriod(start: '2026-09-01', end: '2026-09-05');
      expect(fertig.covers('2026-09-05'), isTrue);
      expect(fertig.covers('2026-09-06'), isFalse);
    });

    test('PeriodRecord.flowOn nutzt tagesgenauen Override', () {
      final PeriodRecord p = makePeriod(
          flow: FlowLevel.light,
          flowByDay: <String, int>{'2026-08-28': 3, '2026-08-29': 0});
      expect(p.flowOn('2026-08-28'), FlowLevel.heavy);
      expect(p.flowOn('2026-08-29'), FlowLevel.spotting);
      expect(p.flowOn('2026-08-30'), FlowLevel.light);
    });

    test('NutritionEntry.effectiveGrams für g, ml und Portionen', () {
      expect(makeNutritionEntry(quantity: 150, unit: QuantityUnit.g)
          .effectiveGrams(), 150);
      expect(makeNutritionEntry(quantity: 250, unit: QuantityUnit.ml)
          .effectiveGrams(), 250);
      expect(
          makeNutritionEntry(
                  quantity: 2,
                  unit: QuantityUnit.portion,
                  foodServingGrams: 40)
              .effectiveGrams(),
          80);
      // Ohne Portionsgröße: 1 Portion = 100 g.
      expect(
          makeNutritionEntry(quantity: 1.5, unit: QuantityUnit.portion)
              .effectiveGrams(),
          150);
    });

    test('FoodItem.copy ist unabhängig vom Original', () {
      final FoodItem f = makeFood();
      final FoodItem c = f.copy();
      c.per100['protein_g'] = 99;
      c.name = 'Anderer Name';
      expect(f.per100['protein_g'], 13.5);
      expect(f.name, 'Haferflocken');
    });

    test('Meal/QuantityUnit/FlowLevel: fromString-Fallbacks', () {
      expect(Meal.fromString('lunch'), Meal.lunch);
      expect(Meal.fromString('unbekannt'), Meal.breakfast);
      expect(QuantityUnit.fromString('ml'), QuantityUnit.ml);
      expect(QuantityUnit.fromString('unbekannt'), QuantityUnit.g);
      expect(FlowLevel.fromString('heavy'), FlowLevel.heavy);
      expect(FlowLevel.fromString('unbekannt'), FlowLevel.spotting);
      expect(FlowLevel.fromInt(0), FlowLevel.spotting);
      expect(FlowLevel.fromInt(1), FlowLevel.light);
      expect(FlowLevel.fromInt(2), FlowLevel.medium);
      expect(FlowLevel.fromInt(3), FlowLevel.heavy);
      expect(FlowLevel.fromInt(null), FlowLevel.medium);
    });
  });

  group('AppSettings', () {
    test('Standardwerte: alle Bereiche sichtbar, kg, keine Ziele', () {
      final AppSettings s = AppSettings();
      expect(s.language, isNull);
      expect(s.weightUnit, 'kg');
      expect(s.visibleAreas, areaKeys);
      expect(s.isAreaVisible('cycle'), isTrue);
      expect(s.goals.waterMl, isNull);
    });

    test('isAreaVisible prüft die Liste', () {
      final AppSettings s =
          AppSettings(visibleAreas: <String>['nutrition']);
      expect(s.isAreaVisible('nutrition'), isTrue);
      expect(s.isAreaVisible('cycle'), isFalse);
    });

    test('weight_unit wird auf kg/lb normalisiert', () {
      final Map<String, dynamic> data = MorphDocument.empty().toDataJson();
      data['settings'] = <String, dynamic>{'weight_unit': 'lb'};
      expect(MorphDocument.fromDataJson(data).settings.weightUnit, 'lb');
      data['settings'] = <String, dynamic>{'weight_unit': 'stone'};
      expect(MorphDocument.fromDataJson(data).settings.weightUnit, 'kg');
    });
  });
}
