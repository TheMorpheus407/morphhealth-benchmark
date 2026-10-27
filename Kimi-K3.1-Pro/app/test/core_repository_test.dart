import 'package:flutter_test/flutter_test.dart';
import 'package:morphhealth/core/health.dart';
import 'package:morphhealth/core/nutrition.dart';
import 'package:morphhealth/core/repository.dart';

import 'core_fixtures.dart';

void main() {
  late List<HealthRepository> repositories;

  setUp(() => repositories = []);
  tearDown(() async {
    for (final repository in repositories) await repository.close();
  });

  Future<HealthRepository> openRepository(
    MemoryStateStore store, {
    DateTime Function()? clock,
  }) async {
    final repository = await HealthRepository.open(store, clock: clock);
    repositories.add(repository);
    return repository;
  }

  group('Öffnen und CRUD', () {
    test(
      'initialisiert einen leeren Bestand oder lädt den vorhandenen unverändert',
      () async {
        final emptyStore = MemoryStateStore();
        final empty = await openRepository(emptyStore);
        expect(emptyStore.loadCount, 1);
        expect(emptyStore.saveCount, 1);
        expect(empty.state.toJson(), AppState.initial().toJson());
        expect(emptyStore.stored?.toJson(), AppState.initial().toJson());

        final existing = fullTestState();
        final existingStore = MemoryStateStore(existing);
        final loaded = await openRepository(existingStore);
        expect(loaded.state, same(existing));
        expect(existingStore.saveCount, 0);
        expect(loaded.now, isA<DateTime>());
      },
    );

    test(
      'Lebensmittel und Intakes werden aktualisiert und Löschschutz bleibt atomar',
      () async {
        final store = MemoryStateStore();
        final repository = await openRepository(store);
        final food = testFood();
        await repository.saveFood(food);
        expect(repository.state.foods, [food]);
        final renamed = food.copyWith(name: 'Umbenannt');
        await repository.saveFood(renamed);
        expect(repository.state.foods, hasLength(1));
        expect(repository.state.foods.single.name, 'Umbenannt');
        final intake = testFoodIntake(nutrients: food.nutrients);
        await repository.saveIntake(intake);
        final beforeDelete = repository.state;
        final saveCount = store.saveCount;
        await expectLater(repository.deleteFood(food.id), throwsStateError);
        expect(repository.state, same(beforeDelete));
        expect(store.saveCount, saveCount);
        final updatedIntake = intake.copyWith(amount: 150, notes: 'korrigiert');
        await repository.saveIntake(updatedIntake);
        expect(repository.state.intakes.single.amount, 150);
        expect(repository.state.intakes.single.notes, 'korrigiert');
        await repository.deleteIntake(intake.id);
        expect(repository.state.intakes, isEmpty);
        await repository.deleteFood(food.id);
        expect(repository.state.foods, isEmpty);
      },
    );

    test(
      'Perioden, Gewicht, Symptome und Einstellungen unterstützen Upsert und Delete',
      () async {
        final store = MemoryStateStore();
        final repository = await openRepository(store);
        await repository.savePeriod(testPeriod());
        await repository.savePeriod(testPeriod(notes: 'neu'));
        expect(repository.state.periods.single.notes, 'neu');
        await repository.saveWeight(testWeight());
        await repository.saveWeight(testWeight(kg: 72));
        expect(repository.state.weights.single.kg, 72);
        await repository.saveSymptom(testSymptom());
        await repository.saveSymptom(testSymptom(intensity: 7));
        expect(repository.state.symptoms.single.intensity, 7);
        const settings = Settings(
          language: 'en',
          weightUnit: 'lb',
          onlineEnabled: false,
        );
        await repository.updateSettings(settings);
        expect(repository.state.settings.toJson(), settings.toJson());
        await repository.deletePeriod('period-1');
        await repository.deleteWeight('weight-1');
        await repository.deleteSymptom('symptom-1');
        expect(repository.state.periods, isEmpty);
        expect(repository.state.weights, isEmpty);
        expect(repository.state.symptoms, isEmpty);
        expect(store.stored?.toJson(), repository.state.toJson());
      },
    );

    test(
      'ungültige Upserts verändern weder Zustand noch gespeicherte Daten',
      () async {
        final store = MemoryStateStore();
        final repository = await openRepository(store);
        await repository.savePeriod(testPeriod(end: '2026-01-05'));
        final before = repository.state;
        final stored = store.stored;
        final saves = store.saveCount;
        await expectLater(
          repository.savePeriod(
            testPeriod(id: 'period-2', start: '2026-01-05', end: '2026-01-08'),
          ),
          throwsFormatException,
        );
        expect(repository.state, same(before));
        expect(store.stored, same(stored));
        expect(store.saveCount, saves);
        await expectLater(
          repository.saveIntake(testFoodIntake()),
          throwsFormatException,
        );
        expect(repository.state, same(before));
      },
    );
  });

  group('Wiederholung und Schnellerfassung', () {
    test(
      'repeatIntake kopiert Fachdaten und Snapshot mit neuem Zeitstempel und neuer ID',
      () async {
        final store = MemoryStateStore();
        final repository = await openRepository(store);
        final food = testFood();
        final original = testFoodIntake(
          amount: 1.5,
          unit: 'portion',
          portionSize: 40,
          notes: 'Original',
          nutrients: food.nutrients,
        );
        await repository.saveFood(food);
        await repository.saveIntake(original);
        final at = DateTime.parse('2026-02-01T12:00:00+02:00');
        await repository.repeatIntake(original.id, at: at);
        expect(repository.state.intakes, hasLength(2));
        final copy = repository.state.intakes.singleWhere(
          (entry) => entry.id != original.id,
        );
        expect(copy.id, isNot(original.id));
        expect(copy.kind, original.kind);
        expect(copy.occurredAt, DateTime.utc(2026, 2, 1, 10));
        expect(copy.createdAt, copy.occurredAt);
        expect(copy.updatedAt, copy.occurredAt);
        expect(copy.meal, original.meal);
        expect(copy.foodId, original.foodId);
        expect(copy.foodName, original.foodName);
        expect(copy.brand, original.brand);
        expect(copy.amount, original.amount);
        expect(copy.unit, original.unit);
        expect(copy.portionSize, original.portionSize);
        expect(copy.nutrients, original.nutrients);
        expect(copy.notes, original.notes);
        await expectLater(repository.repeatIntake('missing'), throwsStateError);
        expect(repository.state.intakes, hasLength(2));
      },
    );

    test(
      'Wasser und Koffein verwenden feste Einheiten, UTC und die injizierte Uhr',
      () async {
        final now = DateTime.utc(2026, 3, 1, 8, 30);
        final repository = await openRepository(
          MemoryStateStore(),
          clock: () => now,
        );
        expect(repository.now, now);
        await repository.addWater(250);
        await repository.addCaffeine(
          80,
          at: DateTime.parse('2026-03-01T10:00:00+01:00'),
        );
        final water = repository.state.intakes[0];
        final caffeine = repository.state.intakes[1];
        expect(water.kind, IntakeKind.water);
        expect(water.unit, 'ml');
        expect(water.amount, 250);
        expect(water.occurredAt, now);
        expect(water.createdAt, now);
        expect(water.meal, 'snack');
        expect(caffeine.kind, IntakeKind.caffeine);
        expect(caffeine.unit, 'mg');
        expect(caffeine.amount, 80);
        expect(caffeine.occurredAt, DateTime.utc(2026, 3, 1, 9));
        for (final amount in [0.0, -1.0, double.nan, double.infinity]) {
          expect(() => repository.addWater(amount), throwsArgumentError);
          expect(() => repository.addCaffeine(amount), throwsArgumentError);
        }
        expect(repository.state.intakes, hasLength(2));
      },
    );
  });

  group('Atomarität, Ereignisse und Wartung', () {
    test(
      'replaceAll ersetzt erst nach erfolgreicher Validierung und Persistierung',
      () async {
        final store = MemoryStateStore();
        final repository = await openRepository(store);
        await repository.saveFood(testFood(id: 'old', name: 'Alter Bestand'));
        final before = repository.state;
        final storedBefore = store.stored;
        final invalid = testState(intakes: [testFoodIntake(id: 'dangling')]);
        final saves = store.saveCount;
        await expectLater(
          repository.replaceAll(invalid),
          throwsFormatException,
        );
        expect(repository.state, same(before));
        expect(store.stored, same(storedBefore));
        expect(store.saveCount, saves);

        final replacement = testState(
          foods: [testFood(id: 'new', name: 'Neuer Bestand')],
          settings: const Settings(language: 'en'),
        );
        store.saveFailure = StateError('disk_full');
        await expectLater(repository.replaceAll(replacement), throwsStateError);
        expect(repository.state, same(before));
        expect(store.stored, same(storedBefore));

        store.saveFailure = null;
        await repository.replaceAll(replacement);
        expect(repository.state.toJson(), replacement.toJson());
        expect(store.stored?.toJson(), replacement.toJson());
        expect(repository.nutritionDay('2026-01-15').foodEntryCount, 0);
      },
    );

    test(
      'parallele Schreibvorgänge werden serialisiert und vollständig gespeichert',
      () async {
        final store = MemoryStateStore();
        final repository = await openRepository(store);
        await Future.wait([
          for (var index = 0; index < 25; index++)
            repository.saveWeight(
              testWeight(id: 'weight-$index', kg: 60 + index.toDouble()),
            ),
        ]);
        expect(repository.state.weights, hasLength(25));
        expect(
          repository.state.weights.map((entry) => entry.id).toSet(),
          hasLength(25),
        );
        expect(store.stored?.weights, hasLength(25));
        expect(store.stored?.toJson(), repository.state.toJson());
      },
    );

    test(
      'changes meldet nur persistierte Zustände und wipe setzt vollständig zurück',
      () async {
        final store = MemoryStateStore();
        final repository = await openRepository(store);
        final events = <AppState>[];
        final subscription = repository.changes.listen(events.add);
        addTearDown(subscription.cancel);
        await repository.saveFood(testFood());
        await repository.updateSettings(const Settings(language: 'en'));
        expect(events, hasLength(2));
        expect(events.last.settings.language, 'en');
        store.saveFailure = StateError('no write');
        await expectLater(repository.wipe(), throwsStateError);
        expect(repository.state.settings.language, 'en');
        expect(store.clearCount, 1);
        store.saveFailure = null;
        await repository.wipe();
        expect(repository.state.toJson(), AppState.initial().toJson());
        expect(store.stored?.toJson(), AppState.initial().toJson());
        expect(events, hasLength(3));
        expect(events.last.toJson(), AppState.initial().toJson());
      },
    );
  });
}
