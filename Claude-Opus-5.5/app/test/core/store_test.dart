import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:morphhealth/core/model/dataset.dart';
import 'package:morphhealth/core/model/entries.dart';
import 'package:morphhealth/core/model/enums.dart';
import 'package:morphhealth/core/service/repository.dart';
import 'package:morphhealth/core/storage/encrypted_store.dart';
import 'package:morphhealth/core/util/json_reader.dart';
import 'package:morphhealth/core/util/local_date.dart';

import '../support/helpers.dart';

void main() {
  final clock = clockAt('2026-09-23T10:00:00+02:00');

  WeightEntry weight(int day, double kg) => WeightEntry.create(
    date: LocalDate(2026, 9, day),
    time: 7 * 60,
    value: kg,
    unit: WeightUnit.kg,
    now: clock.nowUtc(),
  );

  test('creates, persists and reopens an encrypted store', () async {
    final dir = await createTempDir('store');
    var repo = await Repository.open(directory: dir, masterKey: testKey(), clock: clock);
    await repo.put(Collection.weightEntries, weight(1, 70));
    await repo.put(Collection.weightEntries, weight(2, 69.5));
    await repo.close();

    // Nothing is stored in plaintext.
    for (final f in dir.listSync().whereType<File>()) {
      final text = String.fromCharCodes(f.readAsBytesSync());
      expect(text.contains('69.5'), isFalse, reason: f.path);
      expect(text.contains('weight_entries'), isFalse, reason: f.path);
    }

    repo = await Repository.open(directory: dir, masterKey: testKey(), clock: clock);
    expect(repo.data.weightEntries.length, 2);
    expect(repo.data.weightsOn(LocalDate(2026, 9, 2)).single.value, 69.5);
    await repo.close();
  });

  test('rejects a wrong key with a clear error', () async {
    final dir = await createTempDir('store');
    final repo = await Repository.open(directory: dir, masterKey: testKey(1), clock: clock);
    await repo.close();
    await expectLater(
      Repository.open(directory: dir, masterKey: testKey(2), clock: clock),
      throwsA(isA<StoreException>().having((e) => e.code, 'code', 'store_wrong_key')),
    );
  });

  test('detects a damaged snapshot', () async {
    final dir = await createTempDir('store');
    final repo = await Repository.open(directory: dir, masterKey: testKey(), clock: clock);
    await repo.put(Collection.weightEntries, weight(1, 70));
    await repo.compact();
    await repo.close();
    final snap = File('${dir.path}/${EncryptedStore.snapshotName}');
    final bytes = snap.readAsBytesSync();
    bytes[bytes.length - 20] ^= 0x55;
    snap.writeAsBytesSync(bytes);
    await expectLater(
      Repository.open(directory: dir, masterKey: testKey(), clock: clock),
      throwsA(isA<StoreException>().having((e) => e.code, 'code', 'store_corrupted')),
    );
  });

  test('drops an incomplete trailing journal record (interrupted write)', () async {
    final dir = await createTempDir('store');
    final repo = await Repository.open(directory: dir, masterKey: testKey(), clock: clock);
    await repo.put(Collection.weightEntries, weight(1, 70));
    await repo.put(Collection.weightEntries, weight(2, 71));
    await repo.close();
    final journal = File('${dir.path}/${EncryptedStore.journalName}');
    final bytes = journal.readAsBytesSync();
    journal.writeAsBytesSync(bytes.sublist(0, bytes.length - 7));

    final reopened = await Repository.open(directory: dir, masterKey: testKey(), clock: clock);
    expect(reopened.data.weightEntries.length, 1);
    expect(reopened.openWarnings, isNotEmpty);
    await reopened.put(Collection.weightEntries, weight(3, 72));
    await reopened.close();
    final again = await Repository.open(directory: dir, masterKey: testKey(), clock: clock);
    expect(again.data.weightEntries.length, 2);
    await again.close();
  });

  test('stops at a tampered journal record and keeps earlier changes', () async {
    final dir = await createTempDir('store');
    final repo = await Repository.open(directory: dir, masterKey: testKey(), clock: clock);
    await repo.put(Collection.weightEntries, weight(1, 70));
    await repo.put(Collection.weightEntries, weight(2, 71));
    await repo.close();
    final journal = File('${dir.path}/${EncryptedStore.journalName}');
    final bytes = journal.readAsBytesSync();
    bytes[bytes.length - 3] ^= 0x01; // inside the last record's tag
    journal.writeAsBytesSync(bytes);

    final reopened = await Repository.open(directory: dir, masterKey: testKey(), clock: clock);
    expect(reopened.data.weightEntries.length, 1);
    expect(reopened.openWarnings.join(), contains('damaged'));
    await reopened.close();
    expect(
      dir.listSync().any((e) => e.path.contains('.damaged-')),
      isTrue,
      reason: 'damaged journal is kept for inspection',
    );
  });

  test('compacts the journal automatically and survives a stale journal', () async {
    final dir = await createTempDir('store');
    final repo = await Repository.open(directory: dir, masterKey: testKey(), clock: clock);
    for (var i = 0; i < EncryptedStore.compactAfterRecords + 5; i++) {
      await repo.put(
        Collection.waterEntries,
        WaterEntry.create(LocalDate(2026, 9, 1 + i % 28), 600, 100, clock.nowUtc()),
      );
    }
    await repo.close();
    final journal = File('${dir.path}/${EncryptedStore.journalName}');
    expect(journal.lengthSync(), lessThan(4000), reason: 'journal was compacted');

    final again = await Repository.open(directory: dir, masterKey: testKey(), clock: clock);
    expect(again.data.waterEntries.length, EncryptedStore.compactAfterRecords + 5);
    await again.close();
  });

  test('invalid records are rejected before they reach the journal', () async {
    final dir = await createTempDir('store');
    final repo = await Repository.open(directory: dir, masterKey: testKey(), clock: clock);
    await repo.put(Collection.weightEntries, weight(1, 70));
    await expectLater(
      repo.put(Collection.weightEntries, weight(2, 0.2)), // below 1 kg
      throwsA(isA<ValidationException>()),
    );
    await expectLater(
      repo.batch([
        PutChange(Collection.weightEntries, weight(3, 71)),
        PutChange(Collection.weightEntries, weight(4, 5000)),
      ]),
      throwsA(isA<ValidationException>()),
    );
    expect(repo.data.weightEntries, hasLength(1), reason: 'batch is atomic');
    await repo.put(Collection.weightEntries, weight(5, 72));
    await repo.close();
    final again = await Repository.open(directory: dir, masterKey: testKey(), clock: clock);
    expect(again.openWarnings, isEmpty);
    expect(again.data.weightEntries.values.map((w) => w.value).toSet(), {70.0, 72.0});
    await again.close();
  });

  test('a second process cannot open the same data directory', () async {
    final dir = await createTempDir('store');
    final repo = await Repository.open(directory: dir, masterKey: testKey(), clock: clock);
    // File locks are per process on Linux, so check from a child process.
    final script = File('${dir.parent.path}/lock_probe_${dir.hashCode}.dart');
    script.writeAsStringSync('''
import 'dart:io';
Future<void> main() async {
  final f = await File('${dir.path}/${EncryptedStore.lockName}').open(mode: FileMode.append);
  try { await f.lock(FileLock.exclusive); stdout.write('acquired'); }
  on FileSystemException { stdout.write('locked'); }
}
''');
    final result = await Process.run(Platform.resolvedExecutable.contains('flutter_tester')
        ? 'dart'
        : Platform.resolvedExecutable, [script.path]);
    expect(result.stdout, 'locked');
    await repo.close();
    script.deleteSync();
  });
}
