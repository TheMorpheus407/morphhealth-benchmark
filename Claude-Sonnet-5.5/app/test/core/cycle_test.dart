import 'package:flutter_test/flutter_test.dart';
import 'package:morphhealth/core/civil.dart';
import 'package:morphhealth/core/cycle.dart';
import 'package:morphhealth/core/models.dart';

Day d(String s) => Day.parse(s);

PeriodRecord p(String start, {String? end, FlowLevel? flow = FlowLevel.medium}) =>
    PeriodRecord(id: 'p$start', start: d(start), end: end == null ? null : d(end), flow: flow);

void main() {
  // Zyklen mit 28, 29, 27, 28 Tagen.
  final history = [
    p('2026-01-05', end: '2026-01-09'),
    p('2026-02-02', end: '2026-02-06'),
    p('2026-03-03', end: '2026-03-08'),
    p('2026-03-30', end: '2026-04-03'),
    p('2026-04-27', end: '2026-05-01'),
  ];

  test('Ohne Perioden: no_data', () {
    final f = computeForecast(const [], d('2026-05-10'));
    expect(f.status, ForecastStatus.noData);
    expect(f.available, isFalse);
    expect(f.toJson()['explanation'], isNotNull);
  });

  test('Eine Periode: insufficient_data, mit eigener Zykluslänge manual', () {
    final f = computeForecast([p('2026-05-01', end: '2026-05-05')], d('2026-05-20'));
    expect(f.status, ForecastStatus.insufficientData);
    expect(f.predictedStart, isNull);
    expect(f.cycleDay, 20);
    final m = computeForecast([p('2026-05-01', end: '2026-05-05')], d('2026-05-20'), manualCycleLength: 30);
    expect(m.status, ForecastStatus.predicted);
    expect(m.basis, 'manual');
    expect(m.predictedStart.toString(), '2026-05-31');
    expect(m.confidence, 'low');
  });

  test('Vorhersage: Mittelwert der Abstände, Zeitfenster, Tage bis', () {
    final f = computeForecast(history, d('2026-05-10'));
    expect(f.status, ForecastStatus.predicted);
    expect(f.usedLengths, [28, 29, 27, 28]);
    expect(f.averageCycleDays, closeTo(28.0, 1e-9));
    expect(f.predictedStart.toString(), '2026-05-25'); // 27.4. + 28
    expect(f.daysUntil, 15);
    expect(f.cycleDay, 14);
    expect(f.earliest!.isBefore(f.predictedStart!), isTrue);
    expect(f.latest!.isAfter(f.predictedStart!), isTrue);
    expect(f.predictedPeriodDays, 5);
    expect(f.predictedEnd.toString(), '2026-05-29');
    expect(f.confidence, 'high');
    expect(f.upcoming.length, 3);
    expect(f.upcoming[1].predictedStart.toString(), '2026-06-22');
  });

  test('Periode läuft: in_period mit Periodentag', () {
    final f = computeForecast(history, d('2026-04-29'));
    expect(f.status, ForecastStatus.inPeriod);
    expect(f.periodDay, 3);
    expect(f.predictedStart, isNotNull);
  });

  test('Überfällig und veraltet', () {
    final f = computeForecast(history, d('2026-05-28'));
    expect(f.status, ForecastStatus.overdue);
    expect(f.daysOverdue, 3);
    expect(f.daysUntil, isNull);
    final s = computeForecast(history, d('2026-08-01'));
    expect(s.status, ForecastStatus.stale);
    expect(s.predictedStart, isNull);
    expect(s.available, isFalse);
  });

  test('Betrachtungstag in der Vergangenheit: nur bis dahin bekannte Perioden zählen', () {
    final f = computeForecast(history, d('2026-03-15'));
    expect(f.lastPeriodStart.toString(), '2026-03-03');
    expect(f.usedLengths, [28, 29]);
    expect(f.predictedStart.toString(), '2026-04-01'); // 3.3. + round(28.5) = 29 Tage
  });

  test('Ausreißer werden ausgeschlossen, Fenster begrenzt auf sechs Zyklen', () {
    final list = [
      p('2025-01-01'),
      p('2025-03-20'), // 78 Tage: zu lang
      p('2025-04-18'), // 29
      p('2025-05-17'), // 29
      p('2025-05-20'), // 3: zu kurz
      p('2025-06-14'), // 28 (von 17.5.)? nein, von 20.5.: 25
      p('2025-07-12'), // 28
      p('2025-08-09'), // 28
      p('2025-09-06'), // 28
      p('2025-10-04'), // 28
      p('2025-11-01'), // 28
    ];
    final f = computeForecast(list, d('2025-11-10'));
    expect(f.usedLengths.length, kCycleWindow);
    expect(f.intervals.where((i) => i.excludedReason == 'too_long').length, 1);
    expect(f.intervals.where((i) => i.excludedReason == 'too_short').length, 1);
    expect(f.intervals.any((i) => i.excludedReason == 'older_than_window'), isTrue);
    expect(f.predictedCycleDays, 28);
  });

  test('Spotting allein zählt nicht als Periodenbeginn', () {
    final list = [...history, p('2026-05-12', end: '2026-05-12', flow: FlowLevel.spotting)];
    final f = computeForecast(list, d('2026-05-13'));
    expect(f.lastPeriodStart.toString(), '2026-04-27');
    expect(f.usedLengths, [28, 29, 27, 28]);
  });

  test('Unregelmäßige Zyklen: breiteres Fenster, geringere Verlässlichkeit', () {
    final list = [
      p('2026-01-01'),
      p('2026-01-24'), // 23
      p('2026-02-28'), // 35
      p('2026-03-24'), // 24
      p('2026-04-29'), // 36
    ];
    final f = computeForecast(list, d('2026-05-05'));
    expect(f.spreadDays!, greaterThan(5));
    expect(f.confidence, 'low');
    expect(f.latest!.daysUntil(f.earliest!).abs(), greaterThan(8));
  });

  test('Prognose aus: disabled', () {
    final f = computeForecast(history, d('2026-05-10'), enabled: false);
    expect(f.status, ForecastStatus.disabled);
    expect(f.predictedStart, isNull);
  });

  test('Erklärung liegt auf Deutsch und Englisch vor', () {
    final f = computeForecast(history, d('2026-05-10'));
    final de = f.toJson()['explanation'] as Map;
    expect((de['de'] as List).join(' '), contains('Mittelwert'));
    expect((de['en'] as List).join(' '), contains('Average'));
  });
}
