import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:morphhealth/core/cli/describe.dart';
import 'package:morphhealth/core/portable/backup.dart';
import 'package:morphhealth/core/portable/portable_codec.dart';
import 'package:morphhealth/core/storage/crypto.dart';
import 'package:morphhealth/core/util/json_reader.dart';

import '../support/helpers.dart';

Map<String, Object?> copy(Map<String, Object?> doc) =>
    jsonDecode(jsonEncode(doc)) as Map<String, Object?>;

void main() {
  final now = DateTime.utc(2026, 9, 23, 8);

  test('the describe example document is valid and round-trips', () {
    final example = exampleDocument();
    final decoded = decodePortable(example, now: now);
    expect(decoded.warnings, isEmpty);
    expect(decoded.dataset.foodEntries.length, 4);
    expect(decoded.dataset.periods.length, 4);
    final exported = encodePortable(decoded.dataset, exportedAt: now, appVersion: 'x');
    final again = decodePortable(copy(exported), now: now);
    final exportedAgain = encodePortable(again.dataset, exportedAt: now, appVersion: 'x');
    expect(jsonEncode(exportedAgain), jsonEncode(exported));
  });

  test('salt and sodium complement each other', () {
    final doc = copy(exampleDocument());
    final oats = (doc['foods'] as List).first as Map<String, Object?>;
    final nutrients = oats['nutrients'] as Map<String, Object?>;
    expect(nutrients.containsKey('sodium_mg'), isFalse);
    final decoded = decodePortable(doc, now: now);
    expect(decoded.dataset.foods['food-oats']!.profile.nutrients['sodium_mg'], 4.0);
  });

  test('generates missing ids and warns about unknown fields', () {
    final doc = {
      'format': 'morphhealth.portable',
      'version': 1,
      'weight_entries': [
        {'date': '2026-09-01', 'value': 70, 'unit': 'kg', 'colour': 'blue'},
      ],
      'extra': true,
    };
    final decoded = decodePortable(doc, now: now);
    expect(decoded.generatedIds, 1);
    expect(decoded.dataset.weightEntries.values.single.id, hasLength(24));
    expect(decoded.warnings.map((w) => w.path), containsAll(['extra', 'weight_entries[0].colour']));
  });

  test('rejects invalid documents with precise paths', () {
    Map<String, Object?> base() => {'format': 'morphhealth.portable', 'version': 1};

    List<String> errorPaths(Map<String, Object?> doc) {
      try {
        decodePortable(doc, now: now);
      } on ValidationException catch (e) {
        return e.errors.map((i) => i.path).toList();
      }
      fail('expected a ValidationException');
    }

    expect(errorPaths({'format': 'other', 'version': 1}), ['format']);
    expect(errorPaths({'format': 'morphhealth.portable', 'version': 2}), ['version']);
    expect(
      errorPaths({
        ...base(),
        'symptom_entries': [
          {'date': '2026-09-01', 'name': 'Kopfschmerzen', 'intensity': 11},
          {'date': '2026-09-31', 'name': 'X', 'intensity': 3},
        ],
      }),
      ['symptom_entries[0].intensity', 'symptom_entries[1].date'],
    );
    expect(
      errorPaths({
        ...base(),
        'food_entries': [
          {
            'date': '2026-09-01',
            'meal': 'brunch',
            'amount': 1,
            'unit': 'portion',
            'food': {'name': 'Brot', 'nutrients': {'energy_kcal': -5}},
          },
        ],
      }),
      containsAll([
        'food_entries[0].meal',
        'food_entries[0].food.nutrients.energy_kcal',
      ]),
    );
    expect(
      errorPaths({
        ...base(),
        'food_entries': [
          {
            'date': '2026-09-01',
            'meal': 'lunch',
            'amount': 1,
            'unit': 'portion',
            'food': {'name': 'Brot'},
          },
        ],
      }),
      ['food_entries[0].unit'],
    );
    expect(
      errorPaths({
        ...base(),
        'periods': [
          {'id': 'a', 'start': '2026-09-01', 'end': '2026-09-05'},
          {'id': 'b', 'start': '2026-09-04', 'end': '2026-09-06'},
        ],
      }),
      ['periods'],
    );
    expect(
      errorPaths({
        ...base(),
        'periods': [
          {'id': 'a', 'start': '2026-08-01'},
          {'id': 'b', 'start': '2026-09-04', 'end': '2026-09-06'},
        ],
      }),
      ['periods'],
    );
    expect(
      errorPaths({
        ...base(),
        'water_entries': [
          {'id': 'w', 'date': '2026-09-01', 'amount_ml': 200},
          {'id': 'w', 'date': '2026-09-02', 'amount_ml': 300},
        ],
      }),
      ['water_entries[1].id'],
    );
    expect(
      errorPaths({
        ...base(),
        'cycle_days': [
          {'date': '2026-09-01', 'flow': 'light'},
          {'date': '2026-09-01', 'note': 'x'},
        ],
      }),
      ['cycle_days'],
    );
  });

  group('encrypted backup', () {
    const fast = Argon2Params(memoryKib: 8192, iterations: 1, parallelism: 1);

    test('round-trips with the right passphrase', () async {
      final bytes = await createBackup(exampleDocument(), 'korrekt pferd batterie', now: now, params: fast);
      final text = utf8.decode(bytes);
      expect(text.contains('Haferflocken'), isFalse, reason: 'payload is encrypted');
      final doc = await openBackup(bytes, 'korrekt pferd batterie');
      expect(jsonEncode(doc), jsonEncode(exampleDocument()));
    });

    test('rejects a wrong passphrase and modified parameters', () async {
      final bytes = await createBackup(exampleDocument(), 'korrekt pferd batterie', now: now, params: fast);
      await expectLater(openBackup(bytes, 'falsch'), throwsA(isA<BackupAuthenticationException>()));
      final file = jsonDecode(utf8.decode(bytes)) as Map<String, Object?>;
      file['created_at'] = '2020-01-01T00:00:00.000Z';
      await expectLater(
        openBackup(utf8.encode(jsonEncode(file)), 'korrekt pferd batterie'),
        throwsA(isA<BackupAuthenticationException>()),
      );
    });

    test('rejects files that are not backups', () async {
      await expectLater(openBackup(utf8.encode('{"a":1}'), 'x'), throwsA(isA<BackupFormatException>()));
      await expectLater(openBackup([1, 2, 3], 'x'), throwsA(isA<BackupFormatException>()));
      final bytes = await createBackup(exampleDocument(), 'korrekt pferd batterie', now: now, params: fast);
      final file = jsonDecode(utf8.decode(bytes)) as Map<String, Object?>;
      (file['kdf'] as Map)['memory_kib'] = 1 << 30;
      await expectLater(
        openBackup(utf8.encode(jsonEncode(file)), 'korrekt pferd batterie'),
        throwsA(isA<BackupFormatException>()),
      );
    });

    test('a backup restores into a fresh store (new installation)', () async {
      final (source, sourceRepo, _) = await openService();
      await source.importDocument(exampleDocument());
      final bytes = await createBackup(source.exportDocument(), 'eine lange passphrase', now: now, params: fast);
      await sourceRepo.close();

      // Different directory and a different device key.
      final (target, targetRepo, _) = await openService(key: testKey(99));
      final doc = await openBackup(bytes, 'eine lange passphrase');
      final report = await target.importDocument(doc);
      expect(report.diaryEntries, 22);
      expect(target.nutritionDay(source.today.addDays(-1)).entries.length, 4);
      await targetRepo.close();
    });
  });

  test('base64 helpers', () {
    expect(decodeBase64Flexible(base64UrlNoPad([255, 254, 253])), [255, 254, 253]);
  });
}
