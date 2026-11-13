import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:morphhealth_core/morphhealth_core.dart';
import 'package:test/test.dart';

final _clock = FixedClock(LocalDateTime.parse('2026-09-23T08:00:00+02:00'));
final _keyA = Uint8List.fromList(List<int>.generate(32, (i) => i + 1));
final _keyB = Uint8List.fromList(List<int>.generate(32, (i) => 255 - i));

Future<HealthRepository> _open(Directory dir, [Uint8List? key]) =>
    HealthRepository.open(EncryptedFileStore(dir, key ?? _keyA), clock: _clock);

File _snapshot(Directory dir) =>
    File('${dir.path}/${EncryptedFileStore.snapshotName}');

File _journal(Directory dir) =>
    File('${dir.path}/${EncryptedFileStore.journalName}');

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('mh_store_test_');
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  test(
    'a new directory starts empty and is bound to its key at once',
    () async {
      final repo = await _open(dir);
      expect(repo.data.isEmpty, isTrue);
      expect(await _snapshot(dir).exists(), isTrue);
      await expectLater(
        _open(dir, _keyB),
        throwsA(
          isA<StoreException>().having((e) => e.code, 'code', 'wrong_key'),
        ),
      );
    },
  );

  test('changes survive closing and reopening', () async {
    final repo = await _open(dir);
    final food = await repo.saveFood(
      Food(
        id: 'f1',
        source: FoodSource.custom,
        name: 'Geheimes Müsli',
        nutrients: NutrientValues()..[Nutrients.energy] = 380,
        createdAt: _clock.now(),
        updatedAt: _clock.now(),
      ),
    );
    final entry = await repo.logIntake(
      foodId: food.id,
      amount: 60,
      unit: AmountUnit.g,
    );
    await repo.addWater(250);
    await repo.addWeight(Day(2026, 9, 23), 68.2, note: 'morgens');
    await repo.addSymptom('Kopfschmerzen', 4, note: 'nach der Arbeit');
    final period = await repo.startPeriod(Day(2026, 9, 16));
    await repo.savePeriod(period.copyWith(end: Day(2026, 9, 20)));
    await repo.saveCycleDay(Day(2026, 9, 2), spotting: true, note: 'leicht');
    await repo.updateSettings(repo.data.settings.copyWith(language: 'en'));
    await repo.updateGoals(const Goals(energyKcal: 2000));
    await repo.updateLocal(const LocalState(onboardingDone: true));
    await repo.deleteIntake(entry.id);
    final second = await repo.logIntake(
      foodId: food.id,
      amount: 45,
      unit: AmountUnit.g,
    );

    final again = await _open(dir);
    expect(again.data.counts, repo.data.counts);
    expect(again.data.food('f1')!.name, 'Geheimes Müsli');
    expect(again.data.intakeEntry(entry.id), isNull);
    expect(again.data.intakeEntry(second.id)!.amount, 45);
    expect(again.data.periodsSorted.single.end, Day(2026, 9, 20));
    expect(again.data.cycleDay(Day(2026, 9, 2))!.note, 'leicht');
    expect(again.data.settings.language, 'en');
    expect(again.data.goals.energyKcal, 2000);
    expect(again.local.onboardingDone, isTrue);
    expect(again.journalWasDamaged, isFalse);
  });

  test('no health data is readable in the stored files', () async {
    final repo = await _open(dir);
    await repo.saveFood(
      Food(
        id: 'f1',
        source: FoodSource.custom,
        name: 'Geheimes Müsli',
        createdAt: _clock.now(),
        updatedAt: _clock.now(),
      ),
    );
    await repo.addSymptom('Kopfschmerzen', 4, note: 'vertrauliche Notiz');
    await repo.compact();
    await repo.addSymptom('Kopfschmerzen', 6, note: 'vertrauliche Notiz');

    for (final entity in dir.listSync()) {
      if (entity is! File) continue;
      final bytes = await entity.readAsBytes();
      final text = latin1.decode(bytes);
      for (final secret in [
        'Geheim',
        'Kopfschmerz',
        'vertraulich',
        'symptoms',
        'intensity',
        '"name"',
      ]) {
        expect(
          text.contains(secret),
          isFalse,
          reason: '${entity.path} contains "$secret"',
        );
      }
      for (final packed in [gzip.encode(utf8.encode('Kopfschmerzen'))]) {
        expect(_indexOf(bytes, packed.sublist(10, packed.length - 8)), -1);
      }
    }
  });

  test('the journal is folded into a snapshot when it has grown', () async {
    final repo = await _open(dir);
    for (var i = 0; i < EncryptedFileStore.compactAfterRecords + 5; i++) {
      await repo.addWater(100 + i.toDouble());
    }
    // After compaction only the five newest changes are in the journal.
    final journalBytes = await _journal(dir).length();
    expect(journalBytes, lessThan(5 * 600));
    final again = await _open(dir);
    expect(again.data.waterCount, EncryptedFileStore.compactAfterRecords + 5);
  });

  test('an interrupted last write is dropped, earlier ones are kept', () async {
    final repo = await _open(dir);
    await repo.addWater(100);
    await repo.addWater(200);
    final complete = await _journal(dir).length();
    await repo.addWater(300);
    final full = await _journal(dir).readAsBytes();

    // Simulate a power cut in the middle of the third record.
    await _journal(
      dir,
    ).writeAsBytes(full.sublist(0, complete + (full.length - complete) ~/ 2));
    final again = await _open(dir);
    expect(again.data.water.map((w) => w.amountMl).toSet(), {100.0, 200.0});
    expect(again.journalWasDamaged, isFalse);

    // The store keeps working after the recovery.
    await again.addWater(400);
    final third = await _open(dir);
    expect(third.data.water.map((w) => w.amountMl).toSet(), {
      100.0,
      200.0,
      400.0,
    });
  });

  test(
    'a manipulated journal record stops the replay and is reported',
    () async {
      final repo = await _open(dir);
      await repo.addWater(100);
      final firstEnd = await _journal(dir).length();
      await repo.addWater(200);
      await repo.addWater(300);
      final bytes = await _journal(dir).readAsBytes();
      bytes[firstEnd + 40] ^= 0xff; // inside the second record
      await _journal(dir).writeAsBytes(bytes);

      final again = await _open(dir);
      expect(again.data.water.map((w) => w.amountMl), [100.0]);
      expect(again.journalWasDamaged, isTrue);
      expect(
        File(
          '${dir.path}/${EncryptedFileStore.journalName}.damaged',
        ).existsSync(),
        isTrue,
      );
    },
  );

  test('journal records cannot be reordered or replayed', () async {
    final repo = await _open(dir);
    await repo.addWater(100);
    final a = await _journal(dir).length();
    await repo.addWater(200);
    final bytes = await _journal(dir).readAsBytes();
    const header = 24;
    final first = bytes.sublist(header, a);
    final second = bytes.sublist(a);
    // Swap the two records.
    await _journal(
      dir,
    ).writeAsBytes([...bytes.sublist(0, header), ...second, ...first]);
    final again = await _open(dir);
    expect(again.data.waterCount, 0);
    expect(again.journalWasDamaged, isTrue);
  });

  test('a journal of an older snapshot is ignored', () async {
    final repo = await _open(dir);
    await repo.addWater(100);
    final oldJournal = await _journal(dir).readAsBytes();
    await repo.compact();
    await repo.addWater(200);
    // A crash between writing the snapshot and resetting the journal would
    // leave the old journal behind.
    await repo.compact();
    await _journal(dir).writeAsBytes(oldJournal);
    final again = await _open(dir);
    expect(again.data.water.map((w) => w.amountMl).toSet(), {100.0, 200.0});
    expect(again.journalWasDamaged, isFalse);
    await again.addWater(300);
    expect((await _open(dir)).data.waterCount, 3);
  });

  test('a modified snapshot is refused', () async {
    final repo = await _open(dir);
    await repo.addWater(100);
    await repo.compact();
    final bytes = await _snapshot(dir).readAsBytes();
    for (final index in [10, 30, bytes.length - 1]) {
      final copy = Uint8List.fromList(bytes)..[index] ^= 0x01;
      await _snapshot(dir).writeAsBytes(copy);
      await expectLater(
        _open(dir),
        throwsA(isA<StoreException>()),
        reason: 'byte $index',
      );
    }
    await _snapshot(dir).writeAsBytes(utf8.encode('not a snapshot at all'));
    await expectLater(
      _open(dir),
      throwsA(isA<StoreException>().having((e) => e.code, 'code', 'corrupt')),
    );
  });

  test('a journal without snapshot is reported as corrupt', () async {
    final repo = await _open(dir);
    await repo.addWater(100);
    await _snapshot(dir).delete();
    await expectLater(
      _open(dir),
      throwsA(isA<StoreException>().having((e) => e.code, 'code', 'corrupt')),
    );
  });

  test('replaceAll and wipe rewrite everything', () async {
    final repo = await _open(dir);
    await repo.addWater(100);
    final other = AppData()
      ..putWeight(
        WeightEntry(
          id: 'w',
          date: Day(2026, 9, 1),
          weightKg: 70,
          createdAt: _clock.now(),
          updatedAt: _clock.now(),
        ),
      );
    await repo.replaceAll(other);
    var again = await _open(dir);
    expect(again.data.waterCount, 0);
    expect(again.data.weightCount, 1);

    await again.wipe();
    again = await _open(dir);
    expect(again.data.isEmpty, isTrue);
    expect(again.local.onboardingDone, isFalse);
  });

  test('two processes on one directory see each other\'s changes', () async {
    final a = await _open(dir);
    final b = await _open(dir);
    await a.session(() => a.addWater(100));
    // b notices the change before it reads or writes.
    await b.session(() async {
      expect(b.data.waterCount, 1);
      await b.addWater(200);
    });
    await a.session(() async {
      expect(a.data.waterCount, 2);
      await a.replaceAll(AppData());
    });
    await b.session(() async => expect(b.data.waterCount, 0));
  });

  test('the master key must be 32 bytes', () {
    expect(() => EncryptedFileStore(dir, Uint8List(16)), throwsArgumentError);
  });
}

int _indexOf(List<int> haystack, List<int> needle) {
  if (needle.isEmpty) return -1;
  outer:
  for (var i = 0; i + needle.length <= haystack.length; i++) {
    for (var j = 0; j < needle.length; j++) {
      if (haystack[i + j] != needle[j]) continue outer;
    }
    return i;
  }
  return -1;
}
