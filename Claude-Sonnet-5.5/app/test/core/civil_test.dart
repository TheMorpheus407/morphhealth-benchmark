import 'package:flutter_test/flutter_test.dart';
import 'package:morphhealth/core/civil.dart';

void main() {
  test('Day: Parsen, Rechnen, Wochentag', () {
    final d = Day.parse('2026-09-29');
    expect(d.weekday, 2); // Dienstag
    expect(d.addDays(1).toString(), '2026-09-30');
    expect(d.addDays(2).toString(), '2026-10-01');
    expect(d.addDays(-29).toString(), '2026-08-31');
    expect(Day.parse('2024-02-28').addDays(1).toString(), '2024-02-29');
    expect(Day.parse('2023-02-28').addDays(1).toString(), '2023-03-01');
    expect(Day.parse('1970-01-01').epochDay, 0);
    expect(Day.parse('1970-01-01').weekday, 4); // Donnerstag
    expect(Day.parse('2000-03-01').daysUntil(Day.parse('2000-03-31')), 30);
    expect(Day.parse('2026-01-31').addMonths(1).toString(), '2026-02-28');
    expect(Day.parse('2026-01-31').addMonths(-2).toString(), '2025-11-30');
    expect(Day.tryParse('2026-02-30'), isNull);
    expect(Day.tryParse('26-02-03'), isNull);
    expect(Day.tryParse('2026-13-01'), isNull);
  });

  test('Day: Umrechnung ist über viele Jahre umkehrbar', () {
    var d = Day.parse('1900-01-01');
    var n = d.epochDay;
    for (var i = 0; i < 299 * 366; i += 7) {
      final e = Day.fromEpochDay(n + i);
      expect(Day.parse(e.toString()), e);
      expect(e.epochDay, n + i);
    }
    d = Day.parse('2199-12-31');
    n = d.epochDay;
    expect(Day.fromEpochDay(n), d);
  });

  test('LocalDateTime: Formate und Zeitzonen-Suffix', () {
    expect(LocalDateTime.parse('2026-09-29').toString(), '2026-09-29T00:00:00');
    expect(LocalDateTime.parse('2026-09-29T08:15').toString(), '2026-09-29T08:15:00');
    expect(LocalDateTime.parse('2026-09-29T08:15:30.123').second, 30);
    expect(LocalDateTime.parse('2026-09-29T23:30:00+02:00').toString(), '2026-09-29T23:30:00');
    expect(LocalDateTime.parse('2026-09-29T23:30:00Z').day.toString(), '2026-09-29');
    expect(LocalDateTime.tryParse('2026-09-29T25:00'), isNull);
    expect(LocalDateTime.parse('2026-09-29T08:00').compareTo(LocalDateTime.parse('2026-09-29T08:01')), lessThan(0));
  });
}
