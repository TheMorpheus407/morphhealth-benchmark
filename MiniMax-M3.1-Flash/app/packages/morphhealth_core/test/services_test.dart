import 'dart:io';

import 'package:morphhealth_core/morphhealth_core.dart';
import 'package:test/test.dart';

/// Builds a repository with a small, realistic data set.
Future<HealthRepository> buildRepository(Directory temp) async {
  final HealthRepository repository = await HealthRepository.open(
    directory: Directory('${temp.path}/data'),
    masterKey: Crypto.newMasterKey(),
  );
  await repository.load();
  return repository;
}

void main() {
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('morphhealth_service_test');
  });

  tearDown(() async {
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  group('nutrition', () {
    test('sums a day over grams, millilitres and portions', () async {
      final HealthRepository repository = await buildRepository(temp);
      final FoodItem food = FoodItem(
        id: 'f1',
        name: 'Haferflocken',
        source: FoodSource.custom,
        nutrientsPer100: const NutrientProfile(<String, double>{
          Nutrients.energyKcal: 400,
          Nutrients.protein: 12,
          Nutrients.carbohydrates: 60,
          Nutrients.fat: 8,
        }),
        servingGrams: 50,
        portions: const <Portion>[
          Portion(label: 'Portion', amountGrams: 50, isDefault: true),
        ],
      );
      await repository.upsertFood(food);

      await repository.upsertJournalEntry(JournalEntry(
        id: 'e1',
        foodId: food.id,
        foodName: food.name,
        quantity: 50,
        unit: QuantityUnit.gram,
        meal: MealSlot.breakfast,
        date: '2026-09-23',
        loggedAtMs: 0,
        nutrientsPer100Snapshot: food.nutrientsPer100.values,
      ));
      await repository.upsertJournalEntry(JournalEntry(
        id: 'e2',
        foodId: food.id,
        foodName: food.name,
        quantity: 1,
        unit: QuantityUnit.portion,
        portionLabel: 'Portion',
        portionGrams: 50,
        meal: MealSlot.lunch,
        date: '2026-09-23',
        loggedAtMs: 0,
        nutrientsPer100Snapshot: food.nutrientsPer100.values,
      ));
      await repository.upsertIntake(IntakeEntry(
        id: 'i1',
        kind: IntakeKind.water,
        amount: 500,
        date: '2026-09-23',
        loggedAtMs: 0,
      ));
      await repository.upsertIntake(IntakeEntry(
        id: 'i2',
        kind: IntakeKind.caffeine,
        amount: 80,
        date: '2026-09-23',
        loggedAtMs: 0,
      ));

      final NutritionService service = NutritionService(repository);
      final DayNutrition day = service.day('2026-09-23');
      expect(day.caloriesKcal, closeTo(400, 1e-6));
      expect(day.proteinG, closeTo(12, 1e-6));
      expect(day.carbohydratesG, closeTo(60, 1e-6));
      expect(day.fatG, closeTo(8, 1e-6));
      expect(day.waterMl, 500);
      expect(day.extraCaffeineMg, 80);
      expect(day.entries, hasLength(2));
      expect(day.entriesForMeal(MealSlot.breakfast), hasLength(1));

      final NutrientProfile lunch = service.totalsForMeal(day, MealSlot.lunch);
      expect(lunch[Nutrients.energyKcal], closeTo(200, 1e-6));
      await repository.close();
    });

    test('keeps the numbers when the food was deleted', () async {
      final HealthRepository repository = await buildRepository(temp);
      final FoodItem food = FoodItem(
        id: 'f1',
        name: 'Quark',
        source: FoodSource.custom,
        nutrientsPer100: const NutrientProfile(<String, double>{
          Nutrients.energyKcal: 100,
          Nutrients.protein: 10,
        }),
      );
      await repository.upsertFood(food);
      await repository.upsertJournalEntry(JournalEntry(
        id: 'e1',
        foodId: food.id,
        foodName: food.name,
        quantity: 100,
        unit: QuantityUnit.gram,
        meal: MealSlot.snack,
        date: '2026-09-23',
        loggedAtMs: 0,
        nutrientsPer100Snapshot: food.nutrientsPer100.values,
      ));
      await repository.deleteFood(food.id);

      final DayNutrition day = NutritionService(repository).day('2026-09-23');
      expect(day.caloriesKcal, closeTo(100, 1e-6));
      expect(day.proteinG, closeTo(10, 1e-6));
      await repository.close();
    });

    test('counts caffeine from food and from extra entries', () async {
      final HealthRepository repository = await buildRepository(temp);
      final FoodItem coffee = FoodItem(
        id: 'c1',
        name: 'Kaffee',
        source: FoodSource.custom,
        nutrientsPer100: const NutrientProfile(<String, double>{
          Nutrients.energyKcal: 5,
          Nutrients.caffeine: 0.03,
        }),
      );
      await repository.upsertFood(coffee);
      await repository.upsertJournalEntry(JournalEntry(
        id: 'e1',
        foodId: coffee.id,
        foodName: coffee.name,
        quantity: 200,
        unit: QuantityUnit.milliliter,
        meal: MealSlot.breakfast,
        date: '2026-09-23',
        loggedAtMs: 0,
        nutrientsPer100Snapshot: coffee.nutrientsPer100.values,
      ));
      await repository.upsertIntake(IntakeEntry(
        id: 'i1',
        kind: IntakeKind.caffeine,
        amount: 50,
        date: '2026-09-23',
        loggedAtMs: 0,
      ));
      final DayNutrition day = NutritionService(repository).day('2026-09-23');
      expect(day.caffeineFromFoodMg, closeTo(60, 1e-6));
      expect(day.caffeineMg, closeTo(110, 1e-6));
      await repository.close();
    });
  });

  group('cycle', () {
    test('evaluates the recorded history', () async {
      final HealthRepository repository = await buildRepository(temp);
      for (final List<String> period in <List<String>>[
        <String>['2026-06-01', '2026-06-05'],
        <String>['2026-07-01', '2026-07-05'],
        <String>['2026-08-02', '2026-08-06'],
      ]) {
        await repository.upsertPeriod(PeriodRecord(
          id: 'p${period.first}',
          startDate: period.first,
          endDate: period.last,
          flow: FlowStrength.medium,
        ));
      }

      final CycleService service = CycleService(repository);
      final CycleForecast forecast = service.forecast('2026-08-20');
      expect(forecast.hasData, isTrue);
      expect(forecast.recordsUsed, 3);
      expect(forecast.averageCycleLength, closeTo(31, 0.001));
      expect(forecast.minCycleLength, 30);
      expect(forecast.maxCycleLength, 32);
      expect(forecast.averagePeriodLength, closeTo(5, 0.001));
      expect(forecast.cycleDay, 19);
      expect(forecast.predictedNextStart, '2026-09-02');
      expect(forecast.explanation, isNotEmpty);
      expect(forecast.explanation.join(' '), contains('31'));
      await repository.close();
    });

    test('reports missing data honestly', () async {
      final HealthRepository repository = await buildRepository(temp);
      final CycleForecast forecast = CycleService(repository).forecast('2026-09-23');
      expect(forecast.hasData, isFalse);
      expect(forecast.explanation.first, contains('Noch keine Periode'));
      await repository.close();
    });

    test('ignores spotting records for the cycle statistics', () async {
      final HealthRepository repository = await buildRepository(temp);
      await repository.upsertPeriod(PeriodRecord(
        id: 'p1',
        startDate: '2026-08-01',
        endDate: '2026-08-05',
      ));
      await repository.upsertPeriod(PeriodRecord(
        id: 'p2',
        startDate: '2026-08-20',
        spotting: true,
      ));
      final CycleService service = CycleService(repository);
      expect(service.cycleRecords, hasLength(1));
      expect(service.allRecords, hasLength(2));
      await repository.close();
    });
  });

  group('history', () {
    test('filters by area, date range and free text', () async {
      final HealthRepository repository = await buildRepository(temp);
      await repository.upsertSymptom(SymptomEntry(
        id: 's1',
        name: 'Kopfschmerzen',
        intensity: 4,
        date: '2026-09-20',
        occurredAtMs: 0,
      ));
      await repository.upsertWeight(WeightEntry(
        id: 'w1',
        date: '2026-09-21',
        valueKg: 70,
        loggedAtMs: 0,
      ));
      final HistoryService service = HistoryService(repository);

      expect(service.query(), hasLength(2));
      expect(
        service.query(areas: <AppArea>{AppArea.symptoms}),
        hasLength(1),
      );
      expect(
        service.query(from: '2026-09-21', to: '2026-09-21'),
        hasLength(1),
      );
      expect(service.query(text: 'kopfschmerz'), hasLength(1));
      expect(service.query(text: 'nothing'), isEmpty);
      await repository.close();
    });
  });

  group('portable format', () {
    test('exports and imports the complete data set', () async {
      final HealthRepository repository = await buildRepository(temp);
      final FoodItem food = FoodItem(
        id: 'f1',
        name: 'Reis',
        source: FoodSource.custom,
        nutrientsPer100: const NutrientProfile(<String, double>{
          Nutrients.energyKcal: 350,
        }),
      );
      await repository.upsertFood(food);
      await repository.upsertJournalEntry(JournalEntry(
        id: 'e1',
        foodId: food.id,
        foodName: food.name,
        quantity: 200,
        unit: QuantityUnit.gram,
        meal: MealSlot.lunch,
        date: '2026-09-23',
        loggedAtMs: 0,
        nutrientsPer100Snapshot: food.nutrientsPer100.values,
      ));
      await repository.setGoals(const Goals(waterMl: 2000, caloriesKcal: 2200));

      final Map<String, dynamic> document = PortableFormat.exportDocument(
        repository.data,
        exportedAt: DateTime.utc(2026, 9, 23),
      );
      final HealthData restored = PortableFormat.importDocument(document);
      expect(restored.foods, hasLength(1));
      expect(restored.journalEntries, hasLength(1));
      expect(restored.goals.waterMl, 2000);

      final String encoded = PortableFormat.encode(document);
      expect(PortableFormat.decode(encoded)['format'], PortableFormat.formatId);
      await repository.close();
    });

    test('rejects a foreign document', () {
      expect(
        () => PortableFormat.importDocument(<String, dynamic>{'format': 'other'}),
        throwsA(isA<PortableFormatException>()),
      );
    });

    test('the encrypted backup needs the right passphrase', () async {
      final Map<String, dynamic> document = <String, dynamic>{
        'format': PortableFormat.formatId,
        'version': 1,
        'hello': 'world',
      };
      final List<int> sealed = await BackupContainer.seal(document, 'correct horse');
      expect(utf8Like(sealed), isFalse);
      final Map<String, dynamic> opened =
          await BackupContainer.open(sealed, 'correct horse');
      expect(opened['hello'], 'world');
      await expectLater(
        BackupContainer.open(sealed, 'wrong passphrase'),
        throwsA(isA<BackupException>()),
      );
    });
  });
}

/// The backup container must not contain the plaintext.
bool utf8Like(List<int> bytes) {
  final String raw = String.fromCharCodes(bytes);
  return raw.contains('world');
}
