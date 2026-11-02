import 'dart:io';

import 'package:morphhealth_core/morphhealth_core.dart';
import 'package:test/test.dart';

void main() {
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('morphhealth_store_test');
  });

  tearDown(() async {
    if (await temp.exists()) {
      await temp.delete(recursive: true);
    }
  });

  test('store keeps records across a restart', () async {
    final List<int> key = Crypto.newMasterKey();
    final HealthRepository repository = await HealthRepository.open(
      directory: Directory('${temp.path}/data'),
      masterKey: key,
    );
    await repository.load();
    await repository.upsertFood(FoodItem(
      id: 'f1',
      name: 'Test food',
      source: FoodSource.custom,
      nutrientsPer100: const NutrientProfile(<String, double>{
        Nutrients.energyKcal: 100,
      }),
    ));
    await repository.close();

    final HealthRepository reopened = await HealthRepository.open(
      directory: Directory('${temp.path}/data'),
      masterKey: key,
    );
    await reopened.load();
    expect(reopened.foods, hasLength(1));
    expect(reopened.foods.first.name, 'Test food');
    await reopened.close();
  });

  test('a wrong key cannot read the store', () async {
    final HealthRepository repository = await HealthRepository.open(
      directory: Directory('${temp.path}/data'),
      masterKey: Crypto.newMasterKey(),
    );
    await repository.load();
    await repository.upsertSymptom(SymptomEntry(
      id: 's1',
      name: 'Headache',
      intensity: 5,
      date: '2026-09-23',
      occurredAtMs: 0,
    ));
    await repository.close();

    await expectLater(
      HealthRepository.open(
        directory: Directory('${temp.path}/data'),
        masterKey: Crypto.newMasterKey(),
      ),
      throwsA(anything),
    );
  });

  test('the log file does not contain readable health data', () async {
    final HealthRepository repository = await HealthRepository.open(
      directory: Directory('${temp.path}/data'),
      masterKey: Crypto.newMasterKey(),
    );
    await repository.load();
    await repository.upsertSymptom(SymptomEntry(
      id: 's1',
      name: 'VerySecretSymptom',
      intensity: 5,
      date: '2026-09-23',
      occurredAtMs: 0,
    ));
    await repository.close();

    final File log = File('${temp.path}/data/records.bin');
    expect(await log.exists(), isTrue);
    final List<int> bytes = await log.readAsBytes();
    final String raw = String.fromCharCodes(bytes);
    expect(raw.contains('VerySecretSymptom'), isFalse);
  });

  test('deletions are persisted as tombstones', () async {
    final List<int> key = Crypto.newMasterKey();
    final Directory dir = Directory('${temp.path}/data');
    final HealthRepository repository =
        await HealthRepository.open(directory: dir, masterKey: key);
    await repository.load();
    await repository.upsertWeight(WeightEntry(
      id: 'w1',
      date: '2026-09-23',
      valueKg: 70,
      loggedAtMs: 0,
    ));
    await repository.deleteWeight('w1');
    await repository.close();

    final HealthRepository reopened =
        await HealthRepository.open(directory: dir, masterKey: key);
    await reopened.load();
    expect(reopened.weightEntries, isEmpty);
    await reopened.close();
  });

  test('compaction keeps the data intact', () async {
    final List<int> key = Crypto.newMasterKey();
    final Directory dir = Directory('${temp.path}/data');
    final HealthRepository repository =
        await HealthRepository.open(directory: dir, masterKey: key);
    await repository.load();
    for (int i = 0; i < 50; i++) {
      await repository.upsertSymptom(SymptomEntry(
        id: 's$i',
        name: 'Symptom $i',
        intensity: i % 11,
        date: '2026-09-23',
        occurredAtMs: i,
      ));
    }
    for (int i = 0; i < 25; i++) {
      await repository.deleteSymptom('s$i');
    }
    await repository.store.compact();
    await repository.close();

    final HealthRepository reopened =
        await HealthRepository.open(directory: dir, masterKey: key);
    await reopened.load();
    expect(reopened.symptomEntries, hasLength(25));
    await reopened.close();
  });

  test('the store lock prevents a second writer', () async {
    final Directory dir = Directory('${temp.path}/data');
    await dir.create(recursive: true);
    final StoreLock? first = await StoreLock.tryAcquire(dir);
    expect(first, isNotNull);
    final StoreLock? second = await StoreLock.tryAcquire(dir);
    expect(second, isNull);
    await first!.release();
    final StoreLock? third = await StoreLock.tryAcquire(dir);
    expect(third, isNotNull);
    await third!.release();
  });

  test('replaceAll swaps the complete data set', () async {
    final HealthRepository repository = await HealthRepository.open(
      directory: Directory('${temp.path}/data'),
      masterKey: Crypto.newMasterKey(),
    );
    await repository.load();
    await repository.upsertSymptom(SymptomEntry(
      id: 'old',
      name: 'Old',
      intensity: 1,
      date: '2026-09-23',
      occurredAtMs: 0,
    ));
    await repository.replaceAll(HealthData(
      symptoms: <SymptomEntry>[
        SymptomEntry(
          id: 'new',
          name: 'New',
          intensity: 2,
          date: '2026-09-24',
          occurredAtMs: 0,
        ),
      ],
    ));
    expect(repository.symptomEntries, hasLength(1));
    expect(repository.symptomEntries.first.name, 'New');
    await repository.close();
  });
}
