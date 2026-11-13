// Checks that the encrypted store handles a multi-year diary with more than
// 10,000 entries quickly. The limits are generous so that slow machines pass;
// the measured values are printed.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:morphhealth_core/morphhealth_core.dart';
import 'package:morphhealth_core/src/testing/sample_data.dart';
import 'package:test/test.dart';

final _clock = FixedClock(LocalDateTime.parse('2026-09-23T08:00:00+02:00'));
final _key = Uint8List.fromList(List<int>.generate(32, (i) => i * 7 % 256));

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('mh_perf_test_');
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  test('10,000 entries: import, reopen, change, export', () async {
    final big = generateSampleDiary(end: _clock.today);
    expect(big.entryCount, greaterThanOrEqualTo(10000));
    final document = jsonDecode(
      jsonEncode(big.toDocument(exportedAt: _clock.now(), appVersion: 'test')),
    );

    var repo = await HealthRepository.open(
      EncryptedFileStore(dir, _key),
      clock: _clock,
    );
    var watch = Stopwatch()..start();
    final report = await PortableService(repo).importDocument(document);
    final importMs = watch.elapsedMilliseconds;
    expect(report.counts, big.counts);

    watch = Stopwatch()..start();
    repo = await HealthRepository.open(
      EncryptedFileStore(dir, _key),
      clock: _clock,
    );
    final openMs = watch.elapsedMilliseconds;
    expect(repo.data.entryCount, big.entryCount);

    watch = Stopwatch()..start();
    for (var i = 0; i < 50; i++) {
      await repo.addWater(250);
    }
    final writeMs = watch.elapsedMilliseconds / 50;

    watch = Stopwatch()..start();
    final exported = PortableService(repo).exportBytes(pretty: false);
    final exportMs = watch.elapsedMilliseconds;

    final snapshot = File(
      '${dir.path}/${EncryptedFileStore.snapshotName}',
    ).lengthSync();
    // ignore: avoid_print
    print(
      'entries=${big.entryCount} import=${importMs}ms open=${openMs}ms '
      'write=${writeMs.toStringAsFixed(2)}ms/change export=${exportMs}ms '
      'export=${exported.length ~/ 1024}KiB snapshot=${snapshot ~/ 1024}KiB',
    );

    expect(importMs, lessThan(8000));
    expect(openMs, lessThan(5000));
    expect(writeMs, lessThan(100));
    expect(exportMs, lessThan(5000));
    expect(
      snapshot,
      lessThan(exported.length),
      reason: 'the snapshot is compressed',
    );
  });
}
