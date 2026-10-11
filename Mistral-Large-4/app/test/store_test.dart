// Tests für store/store.dart (verschlüsselter Datei-Store + Schlüsseldatiei).
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:morphhealth/src/core/exceptions.dart';
import 'package:morphhealth/src/core/ids.dart';
import 'package:morphhealth/src/model/document.dart';
import 'package:morphhealth/src/model/food.dart';
import 'package:morphhealth/src/store/store.dart';

import 'helpers.dart';

void main() {
  late Directory tempRoot;
  late Directory dataDir;
  late File keyFile;
  late List<int> key;

  setUp(() async {
    tempRoot = await Directory.systemTemp.createTemp('mh_store_test_');
    dataDir = Directory('${tempRoot.path}/data');
    // Schlüsseldatiei liegt außerhalb des Datenverzeichnisses (wie in der App).
    keyFile = File('${tempRoot.path}/master.key');
    key = randomBytes(32);
    await keyFile.writeAsBytes(key);
  });

  tearDown(() async {
    if (await tempRoot.exists()) {
      await tempRoot.delete(recursive: true);
    }
  });

  group('EncryptedStore', () {
    test('erstes Laden legt ein leeres Dokument an und speichert es', () async {
      final EncryptedStore store =
          EncryptedStore(dataDir: dataDir, keyBytes: key);
      expect(store.exists, isFalse);
      final MorphDocument doc = await store.load();
      expect(doc.foods, isEmpty);
      expect(store.exists, isTrue);
      expect(store.storeFile.lengthSync(), greaterThan(0));
    });

    test('Save/Load-Roundtrip über Datei', () async {
      final EncryptedStore store =
          EncryptedStore(dataDir: dataDir, keyBytes: key);
      final MorphDocument doc = MorphDocument(
        foods: <FoodItem>[makeFood(id: 'f1', name: 'Haferflocken')],
      );
      await store.save(doc);
      final MorphDocument back = await store.load();
      expect(back.foods.single.name, 'Haferflocken');
    });

    test('Datei beginnt mit MHST-Magic und enthält keinen Klartext', () async {
      final EncryptedStore store =
          EncryptedStore(dataDir: dataDir, keyBytes: key);
      await store.save(MorphDocument(
        foods: <FoodItem>[makeFood(id: 'f1', name: 'Klartext-Nicht-Sichtbar')],
      ));
      final List<int> bytes = await store.storeFile.readAsBytes();
      expect(ascii.decode(bytes.sublist(0, 4)), 'MHST');
      expect(utf8.decode(bytes, allowMalformed: true),
          isNot(contains('Klartext-Nicht-Sichtbar')));
    });

    test('Laden mit falschem Schlüssel schlägt fehl', () async {
      final EncryptedStore store =
          EncryptedStore(dataDir: dataDir, keyBytes: key);
      await store.save(MorphDocument(
        foods: <FoodItem>[makeFood(id: 'f1')],
      ));
      final EncryptedStore fremd =
          EncryptedStore(dataDir: dataDir, keyBytes: randomBytes(32));
      expect(
          () => fremd.load(),
          throwsA(isA<MorphException>().having(
              (MorphException e) => e.code, 'code', 'crypto.decrypt_failed')));
    });

    test('beschädigte Datei wird als store.unreadable gemeldet', () async {
      final EncryptedStore store =
          EncryptedStore(dataDir: dataDir, keyBytes: key);
      await store.save(MorphDocument.empty());
      await store.storeFile.writeAsBytes(<int>[1, 2, 3, 4, 5]);
      expect(
          () => store.load(),
          throwsA(isA<MorphException>().having(
              (MorphException e) => e.code, 'code', 'store.invalid_format')));
    });

    test('deleteAll entfernt das Datenverzeichnis', () async {
      final EncryptedStore store =
          EncryptedStore(dataDir: dataDir, keyBytes: key);
      await store.save(MorphDocument.empty());
      expect(await dataDir.exists(), isTrue);
      await store.deleteAll();
      expect(await dataDir.exists(), isFalse);
      // Schlüsseldatei bleibt erhalten.
      expect(keyFile.existsSync(), isTrue);
    });

    test('atomares Schreiben hinterlässt keine tmp-Datei', () async {
      final EncryptedStore store =
          EncryptedStore(dataDir: dataDir, keyBytes: key);
      await store.save(MorphDocument.empty());
      expect(File('${store.storeFile.path}.tmp').existsSync(), isFalse);
    });
  });

  group('KeyFile', () {
    test('loadOrCreate legt eine 32-Byte-Datei an', () async {
      final File neu = File('${tempRoot.path}/neu.key');
      final List<int> k = await KeyFile.loadOrCreate(neu);
      expect(k.length, 32);
      expect(neu.readAsBytesSync().length, 32);
      // Erneutes Laden liefert denselben Schlüssel.
      expect(await KeyFile.loadOrCreate(neu), k);
    });

    test('loadStrict verlangt exakt 32 Bytes', () async {
      final File kurz = File('${tempRoot.path}/kurz.key');
      await kurz.writeAsBytes(<int>[1, 2, 3]);
      expect(
          () => KeyFile.loadStrict(kurz),
          throwsA(isA<MorphException>().having((MorphException e) => e.code,
              'code', 'keyfile.invalid_length')));
    });

    test('loadStrict verlangt eine vorhandene Datei', () async {
      final File fehlt = File('${tempRoot.path}/fehlt.key');
      expect(
          () => KeyFile.loadStrict(fehlt),
          throwsA(isA<MorphException>().having((MorphException e) => e.code,
              'code', 'keyfile.missing')));
    });

    test('loadStrict liest vorhandene 32-Byte-Datei', () async {
      final List<int> k = await KeyFile.loadStrict(keyFile);
      expect(k, key);
    });
  });
}
