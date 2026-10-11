// Tests für core/parse.dart (Datum/Uhrzeit/JSON-Helfer).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:morphhealth/src/core/parse.dart';

void main() {
  group('parseDate', () {
    test('gültiges Datum wird als UTC-Mitternacht geparst', () {
      final DateTime? d = parseDate('2026-09-23');
      expect(d, isNotNull);
      expect(d!.year, 2026);
      expect(d.month, 9);
      expect(d.day, 23);
      expect(d.isUtc, isTrue);
    });

    test('ungültige Eingaben liefern null', () {
      expect(parseDate(null), isNull);
      expect(parseDate(''), isNull);
      expect(parseDate('23.09.2026'), isNull);
      expect(parseDate('2026/09/23'), isNull);
      expect(parseDate('2026-9-23'), isNull);
      expect(parseDate('2026-13-01'), isNull); // Monat 13
      expect(parseDate('2026-02-30'), isNull); // 30. Februar
      expect(parseDate('2026-00-10'), isNull);
      expect(parseDate('2026-09-23T12:00:00Z'), isNull); // nur Datum erlaubt
    });

    test('Schaltjahr wird berücksichtigt', () {
      expect(parseDate('2028-02-29'), isNotNull);
      expect(parseDate('2026-02-29'), isNull);
    });
  });

  group('formatDate', () {
    test('formatiert als YYYY-MM-DD mit führenden Nullen', () {
      expect(formatDate(DateTime.utc(2026, 1, 5)), '2026-01-05');
      expect(formatDate(DateTime.utc(2026, 12, 31)), '2026-12-31');
    });

    test('Roundtrip mit parseDate', () {
      const String iso = '2026-09-23';
      expect(formatDate(parseDate(iso)!), iso);
    });
  });

  group('parseTimeOfDay / formatTimeOfDay', () {
    test('gültige Uhrzeiten', () {
      final DateTime? t = parseTimeOfDay('07:30');
      expect(t, isNotNull);
      expect(t!.hour, 7);
      expect(t.minute, 30);
      expect(parseTimeOfDay('7:05')!.hour, 7);
      expect(parseTimeOfDay('23:59'), isNotNull);
      expect(parseTimeOfDay('00:00'), isNotNull);
    });

    test('ungültige Uhrzeiten liefern null', () {
      expect(parseTimeOfDay(null), isNull);
      expect(parseTimeOfDay(''), isNull);
      expect(parseTimeOfDay('24:00'), isNull);
      expect(parseTimeOfDay('12:60'), isNull);
      expect(parseTimeOfDay('7:5'), isNull);
      expect(parseTimeOfDay('07:30:00'), isNull);
    });

    test('formatTimeOfDay füllt führende Nullen', () {
      expect(formatTimeOfDay(DateTime.utc(2000, 1, 1, 7, 5)), '07:05');
      expect(formatTimeOfDay(parseTimeOfDay('23:59')!), '23:59');
    });
  });

  group('todayString', () {
    test('verwendet lokale Felder des Zeitpunkts', () {
      expect(todayString(DateTime.utc(2026, 9, 23, 23, 59)), '2026-09-23');
      expect(todayString(DateTime(2026, 1, 2, 3, 4, 5)), '2026-01-02');
    });
  });

  group('dateDiffDays', () {
    test('Differenz in Tagen (b - a)', () {
      expect(dateDiffDays('2026-01-01', '2026-01-10'), 9);
      expect(dateDiffDays('2026-01-10', '2026-01-01'), -9);
      expect(dateDiffDays('2026-01-01', '2026-01-01'), 0);
      expect(dateDiffDays('2026-12-31', '2027-01-01'), 1);
    });

    test('wirft ArgumentError bei ungültigem Datum', () {
      expect(() => dateDiffDays('2026-01-01', 'kein-datum'),
          throwsArgumentError);
    });
  });

  group('JSON-Helfer', () {
    final Map<String, dynamic> map = <String, dynamic>{
      's': 'text',
      'n': 42,
      'd': 13.5,
      'comma': '1,5',
      'i': 7,
      'b': true,
      'l': <dynamic>[1, 2],
      'm': <String, dynamic>{'x': 1},
      'nested': <dynamic>[<String, dynamic>{'y': 2}],
    };

    test('getString akzeptiert String und num', () {
      expect(getString(map, 's'), 'text');
      expect(getString(map, 'n'), '42');
      expect(getString(map, 'd'), '13.5');
      expect(getString(map, 'missing'), isNull);
      expect(getString(null, 's'), isNull);
    });

    test('getDouble parst num und String (mit Komma)', () {
      expect(getDouble(map, 'd'), 13.5);
      expect(getDouble(map, 'i'), 7);
      expect(getDouble(map, 'comma'), 1.5);
      expect(getDouble(map, 's'), isNull);
      expect(getDouble(map, 'missing'), isNull);
    });

    test('getInt parst int, num und String', () {
      expect(getInt(map, 'i'), 7);
      expect(getInt(map, 'd'), 13);
      expect(getInt(map, 's'), isNull);
      expect(getInt(map, 'missing'), isNull);
    });

    test('getBool liefert nur echte Booleans', () {
      expect(getBool(map, 'b'), isTrue);
      expect(getBool(map, 's'), isNull);
      expect(getBool(map, 'i'), isNull);
    });

    test('getList und getMap', () {
      expect(getList(map, 'l'), <dynamic>[1, 2]);
      expect(getList(map, 's'), isNull);
      expect(getMap(map, 'm'), <String, dynamic>{'x': 1});
      // Untypisierte Maps werden gecastet.
      final Map<String, dynamic> untyped =
          getMap(<String, dynamic>{'raw': <dynamic, dynamic>{'a': 1}}, 'raw')!;
      expect(untyped, <String, dynamic>{'a': 1});
      expect(getMap(map, 'l'), isNull);
    });
  });
}
