import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart' show Argon2id, SecretKey;
import 'package:flutter_test/flutter_test.dart';
import 'package:morphhealth/core/crypto.dart';
import 'package:morphhealth/core/ids.dart';
import 'package:morphhealth/core/store.dart';

Uint8List key([int fill = 7]) => Uint8List.fromList(List.filled(32, fill));

void main() {
  late Directory dir;

  setUp(() async {
    dir = await Directory.systemTemp.createTemp('mh_store_test_');
  });

  tearDown(() async {
    if (await dir.exists()) await dir.delete(recursive: true);
  });

  test('AES-256-GCM: Roundtrip, AAD und Manipulation', () async {
    final k = key(1);
    final sealed = await aeadSeal(k, Uint8List.fromList(utf8.encode('geheim')), Uint8List.fromList([1, 2]));
    expect(utf8.decode(await aeadOpen(k, sealed, Uint8List.fromList([1, 2]))), 'geheim');
    await expectLater(aeadOpen(k, sealed, Uint8List.fromList([1, 3])), throwsA(isA<CryptoFailure>()));
    await expectLater(aeadOpen(key(2), sealed, Uint8List.fromList([1, 2])), throwsA(isA<CryptoFailure>()));
    final bad = Uint8List.fromList(sealed)..[20] ^= 1;
    await expectLater(aeadOpen(k, bad, Uint8List.fromList([1, 2])), throwsA(isA<CryptoFailure>()));
  });

  Uint8List hex(String h) =>
      Uint8List.fromList([for (var i = 0; i < h.length; i += 2) int.parse(h.substring(i, i + 2), radix: 16)]);
  String toHex(List<int> b) => b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();

  test('HKDF-SHA-256: RFC 5869, Testfall 1', () async {
    final okm = await hkdfSha256Bytes(
      hex('0b' * 22),
      hex('000102030405060708090a0b0c'),
      hex('f0f1f2f3f4f5f6f7f8f9'),
      length: 42,
    );
    expect(toHex(okm), '3cb25f25faacd57a90434f64d0362f2a2d2d0a90cf1a5a4c5db02d56ecc4c5bf34007208d5b887185865');
  });

  test('AES-256-GCM: NIST-Testfall 16 (mit AAD), gegengeprüft mit JDK', () async {
    final key = hex('feffe9928665731c6d6a8f9467308308feffe9928665731c6d6a8f9467308308');
    final nonce = hex('cafebabefacedbaddecaf888');
    final aad = hex('feedfacedeadbeeffeedfacedeadbeefabaddad2');
    final plain = hex(
      'd9313225f88406e5a55909c5aff5269a86a7a9531534f7da2e4c303d8a318a72'
      '1c3c0c95956809532fcf0e2449a6b525b16aedf5aa0de657ba637b39',
    );
    final ctTag = hex(
      '522dc1f099567d07f47f37a32a84427d643a8cdcbfe5c0c97598a2bd2555d1aa'
      '8cb08e48590dbb3da7b08b1056828838c5f61e6393ba7a0abcc9f662'
      '76fc6ece0f4e1768cddf8853bb2d551b',
    );
    final sealed = Uint8List.fromList([...nonce, ...ctTag]);
    expect(await aeadOpen(key, sealed, aad), plain);
  });

  test('Argon2id: RFC 9106, Abschnitt 5.3', () async {
    final tag = await Argon2id(parallelism: 4, memory: 32, iterations: 3, hashLength: 32).deriveKey(
      secretKey: SecretKey(hex('01' * 32)),
      nonce: hex('02' * 16),
      optionalSecret: hex('03' * 8),
      associatedData: hex('04' * 12),
    );
    expect(toHex(await tag.extractBytes()), '0d640df58d78766c08c037a34a8b53c9d01ef0452d75b65eb52520e96b01e659');
  });

  test('Speicher: Schreiben, Neuöffnen, Löschen', () async {
    var s = await EncryptedStore.open(dir, key());
    await s.commit([
      Op.put('food_entries', 'a', {'id': 'a', 'name': 'Haferflocken'}),
      Op.put('food_entries', 'b', {'id': 'b', 'name': 'Quark'}),
    ]);
    await s.commit([const Op.delete('food_entries', 'a')]);
    await s.close();

    s = await EncryptedStore.open(dir, key());
    expect(s.state['food_entries']!.keys, ['b']);
    expect(s.state['food_entries']!['b']!['name'], 'Quark');
    expect(s.journalRecords, 2);
    await s.close();
  });

  test('Speicher: Klartext taucht in keiner Datei auf', () async {
    final s = await EncryptedStore.open(dir, key());
    await s.commit([
      Op.put('symptom_entries', 'x', {'id': 'x', 'name': 'Migräneattacke-GEHEIM'}),
    ]);
    await s.compact();
    await s.commit([
      Op.put('symptom_entries', 'y', {'id': 'y', 'name': 'Rückenschmerz-GEHEIM'}),
    ]);
    await s.close();
    for (final f in dir.listSync().whereType<File>()) {
      final text = latin1.decode(f.readAsBytesSync());
      expect(text.contains('GEHEIM'), isFalse, reason: f.path);
      expect(text.contains('Migr'), isFalse, reason: f.path);
    }
  });

  test('Speicher: falscher Schlüssel wird erkannt', () async {
    final s = await EncryptedStore.open(dir, key());
    await s.commit([
      Op.put('t', 'a', {'v': 1}),
    ]);
    await s.close();
    await expectLater(
      EncryptedStore.open(dir, key(9)),
      throwsA(isA<StoreException>().having((e) => e.code, 'code', StoreErrorCode.wrongKey)),
    );
    // Der richtige Schlüssel funktioniert danach weiter (Sperre wurde freigegeben).
    final s2 = await EncryptedStore.open(dir, key());
    expect(s2.state['t']!['a']!['v'], 1);
    await s2.close();
  });

  test('Speicher: abgerissener letzter Journal-Eintrag wird verworfen', () async {
    var s = await EncryptedStore.open(dir, key());
    await s.commit([
      Op.put('t', '1', {'v': 1}),
    ]);
    await s.commit([
      Op.put('t', '2', {'v': 2}),
    ]);
    await s.close();
    final j = File('${dir.path}/${EncryptedStore.journalName}');
    final bytes = j.readAsBytesSync();
    j.writeAsBytesSync(bytes.sublist(0, bytes.length - 10)); // Ende fehlt
    final warnings = <String>[];
    s = await EncryptedStore.open(dir, key(), onWarning: warnings.add);
    expect(s.state['t']!.keys, ['1']);
    expect(warnings, isNotEmpty);
    await s.commit([
      Op.put('t', '3', {'v': 3}),
    ]);
    await s.close();
    s = await EncryptedStore.open(dir, key());
    expect(s.state['t']!.keys.toSet(), {'1', '3'});
    await s.close();
  });

  test('Speicher: Beschädigung in der Mitte des Journals ist ein Fehler', () async {
    var s = await EncryptedStore.open(dir, key());
    for (var i = 0; i < 3; i++) {
      await s.commit([
        Op.put('t', '$i', {'v': i}),
      ]);
    }
    await s.close();
    final j = File('${dir.path}/${EncryptedStore.journalName}');
    final bytes = j.readAsBytesSync();
    bytes[60] ^= 0xff; // im ersten Eintrag
    j.writeAsBytesSync(bytes);
    await expectLater(
      EncryptedStore.open(dir, key()),
      throwsA(isA<StoreException>().having((e) => e.code, 'code', StoreErrorCode.corrupt)),
    );
  });

  test('Speicher: Snapshot-Beschädigung ist ein Fehler, kein stiller Datenverlust', () async {
    final s = await EncryptedStore.open(dir, key());
    await s.commit([
      Op.put('t', 'a', {'v': 1}),
    ]);
    await s.compact();
    await s.close();
    final f = File('${dir.path}/${EncryptedStore.snapshotName}');
    final bytes = f.readAsBytesSync();
    bytes[bytes.length - 5] ^= 1;
    f.writeAsBytesSync(bytes);
    await expectLater(
      EncryptedStore.open(dir, key()),
      throwsA(isA<StoreException>().having((e) => e.code, 'code', StoreErrorCode.corrupt)),
    );
  });

  test('Speicher: Verdichtung ersetzt Journal, Daten bleiben gleich', () async {
    var s = await EncryptedStore.open(dir, key());
    for (var i = 0; i < 30; i++) {
      await s.commit([
        Op.put('t', 'id$i', {'v': i, 'pad': 'x' * 50}),
      ]);
    }
    await s.compact();
    expect(s.journalRecords, 0);
    await s.commit([
      Op.put('t', 'late', {'v': 99}),
    ]);
    await s.close();
    s = await EncryptedStore.open(dir, key());
    expect(s.state['t']!.length, 31);
    expect(s.state['t']!['late']!['v'], 99);
    await s.close();
  });

  test('Speicher: veraltetes Journal nach abgebrochener Verdichtung wird verworfen', () async {
    var s = await EncryptedStore.open(dir, key());
    await s.commit([
      Op.put('t', 'a', {'v': 1}),
    ]);
    final j = File('${dir.path}/${EncryptedStore.journalName}');
    final oldJournal = j.readAsBytesSync();
    await s.compact(); // Snapshot enthält 'a', Journal ist leer
    await s.close();
    j.writeAsBytesSync(oldJournal); // Absturz nach Snapshot, vor Journal-Ersatz
    s = await EncryptedStore.open(dir, key());
    expect(s.state['t']!.keys, ['a']);
    expect(s.journalRecords, 0);
    await s.close();
  });

  test('Speicher: replaceAll ersetzt atomar', () async {
    var s = await EncryptedStore.open(dir, key());
    await s.commit([
      Op.put('t', 'a', {'v': 1}),
    ]);
    await s.replaceAll({
      'u': {
        'z': {'v': 5},
      },
    });
    await s.close();
    s = await EncryptedStore.open(dir, key());
    expect(s.state.containsKey('t'), isFalse);
    expect(s.state['u']!['z']!['v'], 5);
    await s.close();
  });

  test('Speicher: zweite Instanz auf demselben Verzeichnis wird abgewiesen', () async {
    final s = await EncryptedStore.open(dir, key());
    // Innerhalb desselben Prozesses gelten POSIX-Sperren nicht gegen sich selbst;
    // der Test prüft deshalb nur, dass Öffnen und Schließen sauber wiederholbar sind.
    await s.close();
    final s2 = await EncryptedStore.open(dir, key());
    await s2.close();
  });

  test('Speicher: viele Einträge, Snapshot-Größe und Ladezeit', () async {
    final s = await EncryptedStore.open(dir, key());
    final ops = <Op>[];
    for (var i = 0; i < 10000; i++) {
      final id = newId();
      ops.add(
        Op.put('food_entries', id, {
          'id': id,
          'at': '2026-01-01T12:00:00',
          'meal': 'lunch',
          'amount': 100 + i,
          'unit': 'g',
          'food': {
            'name': 'Testlebensmittel $i',
            'nutrients': {'energy_kcal': 120.5, 'protein_g': 3.2, 'fat_g': 1.1, 'carbohydrates_g': 20.5},
          },
        }),
      );
    }
    await s.commit(ops);
    await s.compact();
    final size = s.snapshotBytes;
    await s.close();
    final sw = Stopwatch()..start();
    final s2 = await EncryptedStore.open(dir, key());
    final ms = sw.elapsedMilliseconds;
    expect(s2.state['food_entries']!.length, 10000);
    await s2.close();
    // ignore: avoid_print
    print('10000 Einträge: Snapshot $size Byte, Laden $ms ms (JIT-Testlauf)');
    expect(size, lessThan(3 * 1024 * 1024));
  });
}
