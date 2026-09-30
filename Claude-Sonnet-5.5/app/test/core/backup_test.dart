import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:morphhealth/core/backup.dart';
import 'package:morphhealth/core/crypto.dart';
import 'package:morphhealth/core/describe.dart';

import 'helpers.dart';

// Schnelle Parameter für Tests; die Vorgabe (64 MiB) wird einmal getestet.
const fast = Argon2Params(memoryKiB: 64, iterations: 1, parallelism: 1);

void main() {
  test('Sicherung: Roundtrip, Wiederherstellung auf einer frischen Installation', () async {
    final a = await memoryCore();
    await a.importDocument(exampleImportDocument());
    final bytes = await a.createBackupFile('korrekt pferd batterie', params: fast);
    expect(bytes.sublist(0, 4), utf8.encode('MHB1'));

    // Frische Installation mit anderem Speicher: nur Datei und Passphrase.
    final b = await memoryCore();
    final report = await b.restoreBackupFile(bytes, 'korrekt pferd batterie');
    expect(report.total, 16);
    expect(b.db.entries.length, 3);
    expect(b.db.periods.length, 4);
    expect(b.db.goals.energyKcal, 2200);
    expect(b.db.settings.language, 'de');
  });

  test('Sicherung enthält keinen Klartext', () async {
    final a = await memoryCore();
    await a.importDocument(exampleImportDocument());
    final bytes = await a.createBackupFile('passphrase-123', params: fast);
    final text = latin1.decode(bytes);
    for (final s in ['Haferflocken', 'Kopfschmerz', 'Krämpfe', 'food_entries', 'morphhealth']) {
      expect(text.contains(s), isFalse, reason: s);
    }
  });

  test('Falsche Passphrase, Manipulation und fremde Dateien werden erkannt', () async {
    final a = await memoryCore();
    await a.importDocument(exampleImportDocument());
    final bytes = await a.createBackupFile('richtige-passphrase', params: fast);
    await expectLater(
      openBackup(bytes, 'falsche-passphrase'),
      throwsA(isA<BackupException>().having((e) => e.code, 'code', 'wrong_passphrase')),
    );
    final tampered = Uint8List.fromList(bytes)..[bytes.length - 20] ^= 1;
    await expectLater(openBackup(tampered, 'richtige-passphrase'), throwsA(isA<BackupException>()));
    // Ein manipulierter Kopf (Parameter) fällt über die authentifizierten Zusatzdaten auf.
    final head = Uint8List.fromList(bytes)..[12] = 2; // Durchläufe 1 -> 2
    await expectLater(openBackup(head, 'richtige-passphrase'), throwsA(isA<BackupException>()));
    await expectLater(
      openBackup(Uint8List.fromList(utf8.encode('{"format":"morphhealth-portable"}')), 'x'),
      throwsA(isA<BackupException>().having((e) => e.code, 'code', 'not_a_backup')),
    );
    await expectLater(openBackup(Uint8List(10), 'x'), throwsA(isA<BackupException>()));
  });

  test('Zu kurze Passphrase wird abgewiesen, Parameter-Obergrenzen gelten', () async {
    final a = await memoryCore();
    await expectLater(
      a.createBackupFile('kurz'),
      throwsA(isA<BackupException>().having((e) => e.code, 'code', 'weak_passphrase')),
    );
    final bytes = await a.createBackupFile('lange-passphrase', params: fast);
    final greedy = Uint8List.fromList(bytes);
    ByteData.sublistView(greedy).setUint32(5, 4 * 1024 * 1024, Endian.big); // 4 GiB
    await expectLater(
      openBackup(greedy, 'lange-passphrase'),
      throwsA(isA<BackupException>().having((e) => e.code, 'code', 'unsupported')),
    );
  });

  test('Standardparameter (Argon2id 64 MiB, 3 Durchläufe) funktionieren', () async {
    final a = await memoryCore();
    await a.importDocument(exampleImportDocument());
    final sw = Stopwatch()..start();
    final bytes = await a.createBackupFile('standard-parameter-test');
    final doc = await openBackup(bytes, 'standard-parameter-test');
    // ignore: avoid_print
    print('Sicherung mit Standardparametern: ${sw.elapsedMilliseconds} ms für Erstellen und Öffnen (JIT)');
    expect(doc['format'], 'morphhealth-portable');
    final view = ByteData.sublistView(bytes);
    expect(view.getUint32(5, Endian.big), 65536);
    expect(view.getUint32(9, Endian.big), 3);
  });
}
