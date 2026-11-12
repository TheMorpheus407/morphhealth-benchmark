library morphhealth.core.tests.repository;

import 'dart:io';
import 'dart:typed_data';

import 'package:morphhealth/core/model/entries.dart';
import 'package:morphhealth/core/model/food.dart';
import 'package:morphhealth/core/model/nutrients.dart';
import 'package:morphhealth/core/repository.dart';
import 'package:morphhealth/core/storage/encrypted_store.dart';
import 'package:test/test.dart';

Future<Directory> _tempDir() => Directory.systemTemp.createTemp('morphhealth_test');

void main() {
  group('HealthRepository', () {
    test('roundtrip: speichern, laden, importieren/exportieren', () async {
      final dir = await _tempDir();
      final path = '${dir.path}/data.json.enc';
      final key = List<int>.generate(32, (_) => 42);
      final repo = HealthRepository(
        store: EncryptedStore(Uint8List.fromList(key)),
        dataPath: path,
        now: () => DateTime.parse('2026-09-23T12:00:00+02:00'),
      );
      await repo.load();

      await repo.addNutritionEntry(NutritionEntry(
        id: '',
        foodSource: FoodSource.local,
        foodId: 'f1',
        foodName: 'Testbrot',
        profilePer100g: const NutrientProfile(energyKcal: 250, proteinG: 9, carbsG: 48, fatG: 3),
        amountGrams: 60,
        amountMilliliters: 0,
        servingCount: 0,
        occurredAt: DateTime.parse('2026-09-23T08:30:00+02:00'),
        meal: Meal.breakfast,
      ));
      await repo.addWaterEntry(WaterEntry(
        id: '', amountMilliliters: 500, occurredAt: DateTime.parse('2026-09-23T09:00:00+02:00'),
      ));
      await repo.addCycleEntry(CycleEntry(
        id: '', startDate: DateTime.parse('2026-09-01'), endDate: DateTime.parse('2026-09-05'),
        intensity: PeriodIntensity.medium,
      ));
      await repo.addCycleEntry(CycleEntry(
        id: '', startDate: DateTime.parse('2026-09-29'), endDate: DateTime.parse('2026-10-03'),
        intensity: PeriodIntensity.light,
      ));
      await repo.addSymptomEntry(SymptomEntry(
        id: '', name: 'Kopfschmerzen', intensity: 6,
        occurredAt: DateTime.parse('2026-09-23T10:00:00+02:00'),
      ));
      await repo.addWeightEntry(WeightEntry(
        id: '', date: DateTime.parse('2026-09-23'), value: 70.5, unit: WeightUnit.kg,
      ));
      await repo.save();

      // Tageszusammenfassung
      final summary = repo.nutritionDaySummary(DateTime.parse('2026-09-23'));
      expect(summary.energyKcal, 150.0);
      expect(repo.waterCaffeineDaySummary(DateTime.parse('2026-09-23')).waterMilliliters, 500);

      // Zyklusprognose mit zwei Zyklen
      final forecast = repo.forecastFor(DateTime.parse('2026-09-23'));
      expect(forecast.cyclesRecorded, 1);
      expect(forecast.averageCycleLengthDays, 28);
      expect(forecast.hasPrediction, isTrue);

      // Historie über alle Bereiche
      final history = repo.history();
      expect(history.length, 6);

      // Export/Import-Rundgang
      final exported = await repo.exportDocument();
      final doc = exported['document'] as Map<String, dynamic>;
      await repo.reset();
      expect(repo.nutritionEntries, isEmpty);
      final report = await repo.importDocument(doc);
      expect(report['replaced'], isTrue);
      expect(repo.nutritionEntries.length, 1);
      expect((repo.nutritionEntries.first as NutritionEntry).foodName, 'Testbrot');

      // Neu laden aus der verschlüsselten Datei
      final repo2 = HealthRepository(
        store: EncryptedStore(Uint8List.fromList(key)),
        dataPath: path,
        now: repo.now,
      );
      await repo2.load();
      expect(repo2.nutritionEntries.length, 1);
      expect(repo2.waterEntries.length, 1);
      expect(repo2.cycleEntries.length, 2);
      expect(repo2.symptomEntries.length, 1);
      expect(repo2.weightEntries.length, 1);

      // Löschen
      repo2.deleteNutritionEntry(repo2.nutritionEntries.first.id);
      expect(repo2.nutritionEntries, isEmpty);
      repo2.deleteCycleEntry(repo2.cycleEntries.first.id);
      expect(repo2.cycleEntries.length, 1);
      repo2.deleteSymptomEntry(repo2.symptomEntries.first.id);
      repo2.deleteWeightEntry(repo2.weightEntries.first.id);
      repo2.deleteWaterEntry(repo2.waterEntries.first.id);
      expect(repo2.symptomEntries, isEmpty);
      expect(repo2.weightEntries, isEmpty);
      expect(repo2.waterEntries, isEmpty);

      await dir.delete(recursive: true);
    });

    test('Lebensmittelverwaltung', () async {
      final dir = await _tempDir();
      final repo = HealthRepository(
        store: EncryptedStore(Uint8List.fromList(List<int>.generate(32, (_) => 7))),
        dataPath: '${dir.path}/data.json.enc',
        now: () => DateTime.now(),
      );
      await repo.load();

      final food = await repo.addLocalFood(LocalFood(
        id: '', name: 'Selbstgemachtes Müsli',
        profile: const NutrientProfile(energyKcal: 400, proteinG: 10, sugarG: 20),
        servingSizeGrams: 50,
      ));
      expect(food.name, 'Selbstgemachtes Müsli');
      expect(food.id.isNotEmpty, isTrue);

final found = repo.findLocalFood(food.id)!;
expect(found.name, 'Selbstgemachtes Müsli');

await repo.updateLocalFood(food.id, LocalFood(
  id: food.id, name: 'Selbstgemachtes Müsli (update)', profile: food.profile,
));
expect(repo.findLocalFood(food.id)!.name, 'Selbstgemachtes Müsli (update)');

final results = repo.searchFoods('Müsli');
expect(results.length, 1);

repo.deleteLocalFood(food.id);
expect(() => repo.findLocalFood(food.id), throwsA(isA<Exception>()));

      await dir.delete(recursive: true);
    });

    test('Prognose ohne Daten', () async {
      final dir = await _tempDir();
      final repo = HealthRepository(
        store: EncryptedStore(Uint8List.fromList(List<int>.generate(32, (_) => 9))),
        dataPath: '${dir.path}/data.json.enc',
        now: () => DateTime.now(),
      );
      await repo.load();
      final forecast = repo.forecastFor(DateTime.parse('2026-09-23'));
      expect(forecast.cyclesRecorded, 0);
      expect(forecast.hasPrediction, isFalse);
      await dir.delete(recursive: true);
    });
  });
}