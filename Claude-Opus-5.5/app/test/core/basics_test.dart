import 'dart:convert';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphhealth/core/l10n/format.dart';
import 'package:morphhealth/core/model/enums.dart';
import 'package:morphhealth/core/storage/crypto.dart';
import 'package:morphhealth/core/util/clock.dart';
import 'package:morphhealth/core/util/local_date.dart';

String hex(List<int> b) => b.map((x) => x.toRadixString(16).padLeft(2, '0')).join();
List<int> unhex(String s) => [
  for (var i = 0; i < s.length; i += 2) int.parse(s.substring(i, i + 2), radix: 16),
];

void main() {
  group('LocalDate', () {
    test('parses and validates ISO dates', () {
      expect(LocalDate.parse('2024-02-29').toIso(), '2024-02-29');
      expect(LocalDate.tryParse('2023-02-29'), isNull);
      expect(LocalDate.tryParse('2026-13-01'), isNull);
      expect(LocalDate.tryParse('2026-1-01'), isNull);
      expect(LocalDate.tryParse('20260101'), isNull);
    });

    test('day arithmetic is independent of daylight saving time', () {
      final d = LocalDate(2026, 3, 28);
      expect(d.addDays(2).toIso(), '2026-03-30');
      expect(LocalDate(2026, 10, 24).addDays(2).toIso(), '2026-10-26');
      expect(LocalDate(2026, 1, 1).daysUntil(LocalDate(2026, 12, 31)), 364);
      expect(LocalDate(2026, 1, 31).addMonths(1).toIso(), '2026-02-28');
      expect(LocalDate(2026, 12, 15).addMonths(1).toIso(), '2027-01-15');
      expect(LocalDate(2026, 9, 23).weekday, DateTime.wednesday);
    });

    test('time of day', () {
      expect(TimeOfDayMinutes.parse('07:45'), 465);
      expect(TimeOfDayMinutes.format(465), '07:45');
      expect(TimeOfDayMinutes.tryParse('24:00'), isNull);
      expect(TimeOfDayMinutes.tryParse('7:45'), isNull);
    });
  });

  group('FixedClock', () {
    test('uses the offset of the RFC 3339 timestamp for the local day', () {
      final c = FixedClock.parseRfc3339('2026-09-23T00:30:00+02:00');
      expect(c.today().toIso(), '2026-09-23');
      expect(c.nowUtc().toIso8601String(), '2026-09-22T22:30:00.000Z');
      expect(c.minutesOfDay(), 30);
      final z = FixedClock.parseRfc3339('2026-09-23T23:59:59.123Z');
      expect(z.today().toIso(), '2026-09-23');
      final neg = FixedClock.parseRfc3339('2026-01-01T01:00:00-05:00');
      expect(neg.nowUtc().toIso8601String(), '2026-01-01T06:00:00.000Z');
    });

    test('rejects invalid timestamps', () {
      expect(() => FixedClock.parseRfc3339('2026-09-23'), throwsFormatException);
      expect(() => FixedClock.parseRfc3339('2026-09-23T10:00:00'), throwsFormatException);
      expect(() => FixedClock.parseRfc3339('2026-02-30T10:00:00Z'), throwsFormatException);
    });
  });

  group('crypto', () {
    test('HKDF-SHA256 matches RFC 5869 test case 1', () {
      final okm = hkdfSha256(
        unhex('0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b0b'),
        salt: unhex('000102030405060708090a0b0c'),
        info: unhex('f0f1f2f3f4f5f6f7f8f9'),
        length: 42,
      );
      expect(
        hex(okm),
        '3cb25f25faacd57a90434f64d0362f2a2d2d0a90cf1a5a4c5db02d56ecc4c5bf'
        '34007208d5b887185865',
      );
    });

    test('AES-256-GCM seals, opens and detects tampering', () {
      final key = List<int>.generate(32, (i) => i);
      final sealed = Aead.seal(key, utf8.encode('Gesundheitsdaten'), utf8.encode('aad'));
      expect(utf8.decode(Aead.open(key, sealed, utf8.encode('aad'))), 'Gesundheitsdaten');
      final tampered = List<int>.of(sealed)..[20] ^= 1;
      expect(() => Aead.open(key, tampered, utf8.encode('aad')),
          throwsA(isA<AeadAuthenticationException>()));
      expect(() => Aead.open(key, sealed, utf8.encode('other')),
          throwsA(isA<AeadAuthenticationException>()));
      final wrongKey = List<int>.generate(32, (i) => 31 - i);
      expect(() => Aead.open(wrongKey, sealed, utf8.encode('aad')),
          throwsA(isA<AeadAuthenticationException>()));
    });

    test('AES-256-GCM matches a NIST SP 800-38D test vector', () {
      // gcmEncryptExtIV256.rsp, Count 0 with 128-bit plaintext.
      final algorithm = DartAesGcm.with256bits();
      final box = algorithm.encryptSync(
        unhex('2db5168e932556f8089a0622981d017d'),
        secretKeyData: SecretKeyData(unhex(
          '31bdadd96698c204aa9ce1448ea94ae1fb4a9a0b3c9d773b51bb1822666b8f22',
        )),
        nonce: unhex('0d18e06c7c725ac9e362e1ce'),
      );
      expect(hex(box.cipherText), 'fa4362189661d163fcd6a56d8bf0405a');
      expect(hex(box.mac.bytes), 'd636ac1bbedd5cc3ee727dc2ab4a9489');
    });

    test('Argon2id matches the RFC 9106 test vector', () async {
      final algorithm = DartArgon2id(parallelism: 4, memory: 32, iterations: 3, hashLength: 32);
      final key = await algorithm.deriveKey(
        secretKey: SecretKey(List.filled(32, 1)),
        nonce: List.filled(16, 2),
        optionalSecret: List.filled(8, 3),
        associatedData: List.filled(12, 4),
      );
      expect(
        hex(await key.extractBytes()),
        '0d640df58d78766c08c037a34a8b53c9d01ef0452d75b65eb52520e96b01e659',
      );
    });
  });

  group('Fmt', () {
    setUpAll(initializeFormatting);

    test('parses numbers with either decimal separator', () {
      expect(Fmt.parseNumber('1,5'), 1.5);
      expect(Fmt.parseNumber('1.5'), 1.5);
      expect(Fmt.parseNumber(' 250 '), 250);
      expect(Fmt.parseNumber('1.234,5'), 1234.5);
      expect(Fmt.parseNumber('1,234.5'), 1234.5);
      expect(Fmt.parseNumber('abc'), isNull);
      expect(Fmt.parseNumber(''), isNull);
    });

    test('formats in German and English', () {
      final de = Fmt(AppLanguage.de);
      final en = Fmt(AppLanguage.en);
      expect(de.number(1234.56, 1), '1.234,6');
      expect(en.number(1234.56, 1), '1,234.6');
      expect(de.medium(LocalDate(2026, 9, 23)), contains('2026'));
      expect(de.time(8 * 60 + 5), '08:05');
      expect(en.time(13 * 60 + 5), '1:05 PM');
    });
  });
}
