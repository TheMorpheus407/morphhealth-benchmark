import 'package:morphhealth_core/morphhealth_core.dart';
import 'package:test/test.dart';

void main() {
  group('Day', () {
    test('parses and prints ISO dates', () {
      final d = Day.parse('2026-11-09');
      expect((d.year, d.month, d.day), (2026, 11, 9));
      expect(d.toString(), '2026-11-09');
      expect(d.weekday, DateTime.monday);
    });

    test('rejects impossible and malformed dates', () {
      for (final s in [
        '2026-02-30',
        '2026-13-01',
        '26-11-09',
        '2026-1-9',
        '2026-11-09T10:00',
        '',
        'heute',
        '2026/11/09',
      ]) {
        expect(Day.tryParse(s), isNull, reason: s);
      }
      expect(() => Day(2025, 2, 29), throwsFormatException);
      expect(Day(2024, 2, 29).toString(), '2024-02-29');
    });

    test('arithmetic is independent of daylight saving time', () {
      // Europe/Berlin switches on 2026-03-29 and 2026-10-25.
      expect(Day(2026, 3, 28).addDays(2), Day(2026, 3, 30));
      expect(Day(2026, 10, 26).daysSince(Day(2026, 10, 24)), 2);
      expect(Day(2027, 1, 1).daysSince(Day(2026, 1, 1)), 365);
      expect(Day(1969, 12, 31).addDays(1), Day(1970, 1, 1));
      expect(Day(1969, 12, 31).toString(), '1969-12-31');
    });

    test('adds months with clamping', () {
      expect(Day(2026, 1, 31).addMonths(1), Day(2026, 2, 28));
      expect(Day(2026, 12, 15).addMonths(1), Day(2027, 1, 15));
      expect(Day(2026, 1, 15).addMonths(-1), Day(2025, 12, 15));
      expect(Day(2026, 2, 1).daysInMonth, 28);
    });

    test('compares', () {
      expect(Day(2026, 1, 1) < Day(2026, 1, 2), isTrue);
      expect(Day(2026, 1, 2) >= Day(2026, 1, 2), isTrue);
      expect({Day(2026, 1, 1), Day(2026, 1, 1)}.length, 1);
    });
  });

  group('LocalDateTime', () {
    test('keeps the wall-clock time exactly as written', () {
      final a = LocalDateTime.parse('2026-11-03T23:30:00+01:00');
      expect(a.day, Day(2026, 11, 3));
      expect((a.hour, a.minute, a.offsetMinutes), (23, 30, 60));
      expect(a.toIso(), '2026-11-03T23:30:00+01:00');

      // A UTC timestamp late in the evening stays on its written day.
      final z = LocalDateTime.parse('2026-11-03T23:30:00Z');
      expect(z.day, Day(2026, 11, 3));
      expect(z.toIso(), '2026-11-03T23:30:00+00:00');
    });

    test('accepts common variants', () {
      expect(
        LocalDateTime.parse('2026-11-09T07:45').toIso(),
        '2026-11-09T07:45:00',
      );
      expect(LocalDateTime.parse('2026-11-09 07:45:10').second, 10);
      expect(LocalDateTime.parse('2026-11-09T07:45:10.123456Z').second, 10);
      expect(
        LocalDateTime.parse('2026-11-09T07:45:10-0530').offsetMinutes,
        -330,
      );
      expect(LocalDateTime.parse('2026-11-09T07:45:10+02').offsetMinutes, 120);
    });

    test('a date without time is placed at noon and reported', () {
      final p = LocalDateTime.tryParseDetailed('2026-11-09')!;
      expect(p.dateOnly, isTrue);
      expect(p.value.hhmm, '12:00');
    });

    test('rejects invalid values', () {
      for (final s in [
        '2026-11-09T24:00',
        '2026-11-09T12:60',
        '2026-02-30T10:00',
        'T10:00',
        '2026-11-09T',
        '2026-11-09Z',
        '2026-11-09T10:00+25:00',
      ]) {
        expect(LocalDateTime.tryParse(s), isNull, reason: s);
      }
    });

    test('orders by wall clock', () {
      final a = LocalDateTime.parse('2026-11-09T07:45:00+01:00');
      final b = LocalDateTime.parse('2026-11-09T08:00:00-05:00');
      expect(a.compareTo(b), lessThan(0));
    });
  });

  test('FixedClock stands still', () {
    final clock = FixedClock(LocalDateTime.parse('2026-09-23T08:00:00+02:00'));
    expect(clock.today, Day(2026, 9, 23));
    expect(clock.now(), clock.now());
  });
}
