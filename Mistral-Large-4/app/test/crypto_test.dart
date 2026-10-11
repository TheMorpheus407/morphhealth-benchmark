// Tests für crypto/crypto.dart und store/backup.dart
// (AES-256-GCM-Container, PBKDF2-Backup, Datei-Formate — SPEC P07).
//
// Die PBKDF2-Tests nutzen reduzierte Iterationen (fachlich identischer Pfad,
// nur schneller); der Standardwert wird separat geprüft.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:morphhealth/src/core/exceptions.dart';
import 'package:morphhealth/src/core/ids.dart';
import 'package:morphhealth/src/crypto/crypto.dart';
import 'package:morphhealth/src/model/cycle.dart';
import 'package:morphhealth/src/model/document.dart';
import 'package:morphhealth/src/model/entries.dart';
import 'package:morphhealth/src/model/food.dart';
import 'package:morphhealth/src/store/backup.dart';

import 'helpers.dart';

void main() {
  group('AesGcmCodec', () {
    test('Roundtrip entschlüsselt die Klartext-Nachricht', () async {
      final List<int> key = randomBytes(32);
      final List<int> plain = utf8.encode('MorphHealth-Testdaten äöü 123');
      final List<int> blob = await AesGcmCodec.encrypt(plain, key);
      expect(blob.length, greaterThan(plain.length)); // nonce + mac
      final List<int> back = await AesGcmCodec.decrypt(blob, key);
      expect(back, plain);
    });

    test('jeder Aufruf erzeugt einen anderen Blob (Zufalls-Nonce)', () async {
      final List<int> key = randomBytes(32);
      final List<int> plain = utf8.encode('gleich');
      final List<int> a = await AesGcmCodec.encrypt(plain, key);
      final List<int> b = await AesGcmCodec.encrypt(plain, key);
      expect(a, isNot(b));
    });

    test('falscher Schlüssel schlägt fehl', () async {
      final List<int> key = randomBytes(32);
      final List<int> blob =
          await AesGcmCodec.encrypt(utf8.encode(' geheim '), key);
      expect(
          () => AesGcmCodec.decrypt(blob, randomBytes(32)),
          throwsA(isA<MorphException>().having(
              (MorphException e) => e.code, 'code', 'crypto.decrypt_failed')));
    });

    test('manipuliertes Byte schlägt fehl (GCM-MAC)', () async {
      final List<int> key = randomBytes(32);
      final List<int> blob =
          await AesGcmCodec.encrypt(utf8.encode('geheim'), key);
      blob[blob.length - 1] ^= 0x01;
      expect(
          () => AesGcmCodec.decrypt(blob, key),
          throwsA(isA<MorphException>().having(
              (MorphException e) => e.code, 'code', 'crypto.decrypt_failed')));
    });

    test('zu kurzer Blob und falsche Schlüssellänge werden abgelehnt', () async {
      final List<int> key = randomBytes(32);
      expect(
          () => AesGcmCodec.decrypt(<int>[1, 2, 3], key),
          throwsA(isA<MorphException>().having(
              (MorphException e) => e.code, 'code', 'crypto.decrypt_failed')));
      expect(
          () => AesGcmCodec.encrypt(<int>[1], <int>[1, 2, 3]),
          throwsA(isA<MorphException>().having(
              (MorphException e) => e.code, 'code', 'crypto.invalid_key')));
    });
  });

  group('StoreContainer (lokaler Speicher)', () {
    test('Roundtrip + Magic/Version im Header', () async {
      final List<int> key = randomBytes(32);
      final List<int> plain = utf8.encode('{"Hallo":"Welt"}');
      final List<int> blob = await StoreContainer.seal(plain, key);
      expect(ascii.decode(blob.sublist(0, 4)), 'MHST');
      expect(blob[4] | (blob[5] << 8), StoreContainer.version);
      expect(await StoreContainer.open(blob, key), plain);
    });

    test('falsche Magic wird abgelehnt', () async {
      final List<int> key = randomBytes(32);
      final List<int> blob =
          await StoreContainer.seal(utf8.encode('x'), key);
      blob[0] = 0x58; // 'X'
      expect(
          () => StoreContainer.open(blob, key),
          throwsA(isA<MorphException>().having(
              (MorphException e) => e.code, 'code', 'store.invalid_format')));
    });

    test('unbekannte Version wird abgelehnt', () async {
      final List<int> key = randomBytes(32);
      final List<int> blob =
          await StoreContainer.seal(utf8.encode('x'), key);
      blob[4] = 99; // version u16 LE, niederwertiges Byte
      expect(
          () => StoreContainer.open(blob, key),
          throwsA(isA<MorphException>().having((MorphException e) => e.code,
              'code', 'store.unsupported_version')));
    });

    test('falscher Schlüssel wird abgelehnt', () async {
      final List<int> blob = await StoreContainer.seal(
          utf8.encode('x'), randomBytes(32));
      expect(
          () => StoreContainer.open(blob, randomBytes(32)),
          throwsA(isA<MorphException>().having(
              (MorphException e) => e.code, 'code', 'crypto.decrypt_failed')));
    });
  });

  group('BackupContainer (passphrageschützt)', () {
    test('Roundtrip mit Passphrase (reduzierte Iterationen)', () async {
      final List<int> plain = utf8.encode('portables Dokument');
      final List<int> blob = await BackupContainer.seal(
        plain,
        'geheimes-passwort',
        salt: List<int>.filled(16, 7),
        iterations: 1000,
      );
      expect(ascii.decode(blob.sublist(0, 4)), 'MHBK');
      expect(blob[6], BackupContainer.kdfPbkdf2Sha256);
      // iterations u32 LE an Offset 7
      expect(blob[7] | (blob[8] << 8) | (blob[9] << 16) | (blob[10] << 24),
          1000);
      expect(
          await BackupContainer.open(blob, 'geheimes-passwort'), plain);
    });

    test('falsche Passphrase wird als solche gemeldet', () async {
      final List<int> blob = await BackupContainer.seal(
        utf8.encode('x'),
        'richtig',
        iterations: 1000,
      );
      expect(
          () => BackupContainer.open(blob, 'falsch'),
          throwsA(isA<MorphException>().having((MorphException e) => e.code,
              'code', 'backup.wrong_passphrase')));
    });

    test('falsche Magic wird abgelehnt', () async {
      final List<int> blob = await BackupContainer.seal(
          utf8.encode('x'), 'pw', iterations: 1000);
      blob[1] = 0x58;
      expect(
          () => BackupContainer.open(blob, 'pw'),
          throwsA(isA<MorphException>().having((MorphException e) => e.code,
              'code', 'backup.invalid_format')));
    });

    test('Standard-Iterationen entsprechen dem OWASP-Richtwert', () {
      // Der produktive Wert (600.000) ist in SECURITY.md dokumentiert; hier
      // wird nur geprüft, dass der Standard tatsächlich gesetzt ist.
      expect(PassphraseKdf.defaultIterations, 600000);
      expect(PassphraseKdf.saltBytes, 16);
      expect(PassphraseKdf.keyBytes, 32);
    });

    test('gleiche Passphrase + gleiches Salt, aber unterschiedliches Ergebnis '
        'durch Zufalls-Nonce', () async {
      final List<int> salt = List<int>.filled(16, 3);
      final List<int> a = await BackupContainer.seal(
          utf8.encode('daten'), 'pw', salt: salt, iterations: 1000);
      final List<int> b = await BackupContainer.seal(
          utf8.encode('daten'), 'pw', salt: salt, iterations: 1000);
      expect(a, isNot(b));
      expect(await BackupContainer.open(a, 'pw'), utf8.encode('daten'));
      expect(await BackupContainer.open(b, 'pw'), utf8.encode('daten'));
    });
  });

  group('BackupFile (Datei-Ebene)', () {
    test('seal/openBytes-Roundtrip mit einem portablen Dokument', () async {
      final MorphDocument doc = MorphDocument(
        foods: <FoodItem>[makeFood(id: 'f1')],
        nutritionEntries: <NutritionEntry>[makeNutritionEntry(id: 'e1')],
        waterEntries: <WaterEntry>[makeWaterEntry(id: 'w1')],
        caffeineEntries: <CaffeineEntry>[makeCaffeineEntry(id: 'c1')],
        periods: <PeriodRecord>[makePeriod(id: 'p1')],
        weightEntries: <WeightEntry>[makeWeightEntry(id: 'g1')],
        symptomEntries: <SymptomEntry>[makeSymptomEntry(id: 's1')],
      );
      final Map<String, dynamic> portable =
          doc.toPortableJson(const AppInfo(name: 'MorphHealth', version: '1.0.0+1'));
      // Gleiche Nutzlast wie BackupFile.seal, aber mit reduzierten
      // Iterationen (fachlich identischer Pfad, nur schneller im Test).
      final List<int> schnell = await BackupContainer.seal(
        utf8.encode(jsonEncode(portable)),
        'pass phrase mit Leerzeichen',
        iterations: 1000,
      );
      final MorphDocument back = await BackupFile.openBytes(schnell, 'pass phrase mit Leerzeichen');
      expect(back.foods.single.id, 'f1');
      expect(back.nutritionEntries.single.id, 'e1');
      expect(back.waterEntries.single.id, 'w1');
      expect(back.caffeineEntries.single.id, 'c1');
      expect(back.periods.single.id, 'p1');
      expect(back.weightEntries.single.id, 'g1');
      expect(back.symptomEntries.single.id, 's1');
    });

    test('falsche Passphrase wirft backup.wrong_passphrase', () async {
      final Map<String, dynamic> portable =
          MorphDocument.empty().toPortableJson(const AppInfo());
      final List<int> blob = await BackupContainer.seal(
          utf8.encode(jsonEncode(portable)), 'pw', iterations: 1000);
      expect(
          () => BackupFile.openBytes(blob, 'andere'),
          throwsA(isA<MorphException>().having((MorphException e) => e.code,
              'code', 'backup.wrong_passphrase')));
    });

    test('Klartext des Dokuments ist nicht im Blob enthalten', () async {
      final MorphDocument doc = MorphDocument(
        foods: <FoodItem>[makeFood(id: 'f1', name: 'Geheimer-Lebensmittelname')],
      );
      final Map<String, dynamic> portable = doc.toPortableJson(const AppInfo());
      final List<int> blob = await BackupContainer.seal(
          utf8.encode(jsonEncode(portable)), 'pw', iterations: 1000);
      final Uint8List bytes = Uint8List.fromList(blob);
      final List<int> needle = utf8.encode('Geheimer-Lebensmittelname');
      bool gefunden = false;
      for (int i = 0; i + needle.length <= bytes.length; i++) {
        bool gleich = true;
        for (int j = 0; j < needle.length; j++) {
          if (bytes[i + j] != needle[j]) {
            gleich = false;
            break;
          }
        }
        if (gleich) {
          gefunden = true;
          break;
        }
      }
      expect(gefunden, isFalse, reason: 'Klartext darf nicht im Blob stehen');
    });
  });
}
