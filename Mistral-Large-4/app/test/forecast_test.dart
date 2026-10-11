// Tests für cycle/forecast.dart (persönliche Zykluseinschätzung — SPEC P04).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:morphhealth/src/cycle/forecast.dart';
import 'package:morphhealth/src/model/cycle.dart';
import 'package:morphhealth/src/model/document.dart';

import 'helpers.dart';

/// Baut ein Dokument mit `starts` (jeweils 5 Tage Periode, Medium).
MorphDocument docMitPerioden(List<String> starts) {
  return MorphDocument(
    periods: <PeriodRecord>[
      for (int i = 0; i < starts.length; i++)
        makePeriod(
          id: 'p$i',
          start: starts[i],
          end: _plusTage(starts[i], 4),
        ),
    ],
  );
}

String _plusTage(String iso, int tage) {
  final DateTime d = DateTime.utc(
      int.parse(iso.substring(0, 4)),
      int.parse(iso.substring(5, 7)),
      int.parse(iso.substring(8, 10)));
  final DateTime p = d.add(Duration(days: tage));
  return '${p.year.toString().padLeft(4, '0')}-'
      '${p.month.toString().padLeft(2, '0')}-'
      '${p.day.toString().padLeft(2, '0')}';
}

void main() {
  group('computeCycleForecast: Datenlage', () {
    test('keine Perioden → state no_data', () {
      final CycleForecast f =
          computeCycleForecast(MorphDocument.empty(), '2026-09-23');
      expect(f.state, 'no_data');
      expect(f.periodsRecorded, 0);
      expect(f.cyclesMeasured, 0);
      expect(f.averageCycleDays, isNull);
      expect(f.nextPeriodStartEstimate, isNull);
      expect(f.confidence, isNull);
      expect(f.explanationDe(), contains('keine Perioden'));
      expect(f.explanationEn(), contains('No periods'));
    });

    test('eine Periode → noch keine Prognose (insufficient_data)', () {
      final CycleForecast f = computeCycleForecast(
          docMitPerioden(<String>['2026-08-28']), '2026-09-23');
      expect(f.periodsRecorded, 1);
      expect(f.cyclesMeasured, 0);
      expect(f.averageCycleDays, isNull);
      expect(f.nextPeriodStartEstimate, isNull);
      expect(f.confidence, isNull);
      expect(f.averagePeriodDays, 5);
      expect(f.state, 'insufficient_data');
      // Aber: durchschnittliche Blutungsdauer ist bekannt.
      expect(f.periodDaysMin, 5);
      expect(f.periodDaysMax, 5);
      expect(f.explanationDe(), contains('zweite Periode'));
    });

    test('Betrachtungstag innerhalb einer aufgezeichneten Periode', () {
      // Letzte Periode beginnt am 2026-09-25 — der Zyklustag wird relativ
      // zum letzten aufgezeichneten Beginn gerechnet.
      final CycleForecast f = computeCycleForecast(
          docMitPerioden(<String>['2026-08-28', '2026-09-25']),
          '2026-09-27');
      expect(f.state, 'within_recorded');
      expect(f.currentCycleDay, 3);
    });
  });

  group('computeCycleForecast: Prognose', () {
    // Drei regelmäßige 28-Tage-Zyklen, je 5 Tage Periode.
    final MorphDocument regular = docMitPerioden(<String>[
      '2026-01-01',
      '2026-01-29',
      '2026-02-26',
    ]);

    test('regelmäßige Historie: Mittelwert, Bereich, Konfidenz', () {
      final CycleForecast f = computeCycleForecast(regular, '2026-03-05');
      expect(f.periodsRecorded, 3);
      expect(f.cyclesMeasured, 2);
      expect(f.averageCycleDays, 28);
      expect(f.cycleDaysMin, 28);
      expect(f.cycleDaysMax, 28);
      expect(f.averagePeriodDays, 5);
      expect(f.lastPeriodStart, '2026-02-26');
      expect(f.currentCycleDay, 8); // 2026-03-05 ist 7 Tage nach Beginn
      expect(f.nextPeriodStartEstimate, '2026-03-26');
      expect(f.nextPeriodStartRangeStart, '2026-03-26');
      expect(f.nextPeriodStartRangeEnd, '2026-03-26');
      expect(f.nextPeriodEndEstimate, '2026-03-30');
      expect(f.confidence, 'medium'); // 2 Messungen
      expect(f.state, 'before_next');
    });

    test('innerhalb der vorhergesagten Periode', () {
      final CycleForecast f = computeCycleForecast(regular, '2026-03-27');
      expect(f.state, 'within_predicted');
      expect(f.nextPeriodStartEstimate, '2026-03-26');
    });

    test('zwischen zwei Vorhersagen', () {
      final CycleForecast f = computeCycleForecast(regular, '2026-03-31');
      expect(f.state, 'between_predicted');
    });

    test('hohe Konfidenz bei 3+ regelmäßigen Messungen', () {
      final MorphDocument sehrRegelmaessig = docMitPerioden(<String>[
        '2026-01-01',
        '2026-01-29',
        '2026-02-26',
        '2026-03-26',
      ]);
      final CycleForecast f =
          computeCycleForecast(sehrRegelmaessig, '2026-04-10');
      expect(f.cyclesMeasured, 3);
      expect(f.confidence, 'high');
      expect(f.nextPeriodStartEstimate, '2026-04-23');
    });

    test('nur eine gemessene Zykluslänge → unsicherer Bereich ±2 Tage, '
        'niedrige Konfidenz', () {
      final MorphDocument eineMessung = docMitPerioden(<String>[
        '2026-01-01',
        '2026-01-29',
      ]);
      final CycleForecast f =
          computeCycleForecast(eineMessung, '2026-02-10');
      expect(f.cyclesMeasured, 1);
      expect(f.averageCycleDays, 28);
      expect(f.cycleDaysMin, 26);
      expect(f.cycleDaysMax, 30);
      expect(f.confidence, 'low');
      expect(f.nextPeriodStartEstimate, '2026-02-26');
      expect(f.nextPeriodStartRangeStart, '2026-02-24');
      expect(f.nextPeriodStartRangeEnd, '2026-02-28');
    });

    test('unregelmäßige Zyklen → Bereich aus Min/Max, mittlere Konfidenz', () {
      final MorphDocument unregelmaessig = docMitPerioden(<String>[
        '2026-01-01',
        '2026-01-29', // 28
        '2026-03-02', // 32
      ]);
      final CycleForecast f =
          computeCycleForecast(unregelmaessig, '2026-03-10');
      expect(f.averageCycleDays, 30);
      expect(f.cycleDaysMin, 28);
      expect(f.cycleDaysMax, 32);
      expect(f.confidence, 'medium');
      expect(f.nextPeriodStartEstimate, '2026-04-01'); // 03-02 + 30
    });

    test('laufende Periode am Stichtag', () {
      final MorphDocument laufend = MorphDocument(
        periods: <PeriodRecord>[
          makePeriod(id: 'p1', start: '2026-01-01', end: '2026-01-05'),
          makePeriod(id: 'p2', start: '2026-01-29', end: '2026-02-02'),
          makePeriod(id: 'p3', start: '2026-02-26', end: null), // läuft
        ],
      );
      final CycleForecast f = computeCycleForecast(laufend, '2026-02-28');
      expect(f.state, 'within_recorded');
      expect(f.currentCycleDay, 3);
      // Prognose basiert trotzdem auf dem letzten Beginn.
      expect(f.nextPeriodStartEstimate, '2026-03-26');
    });

    test('Erklärungen sind sprachgetrennt und nicht leer', () {
      final CycleForecast f = computeCycleForecast(regular, '2026-03-05');
      final String de = f.explanationDe();
      final String en = f.explanationEn();
      expect(de, contains('Zyklustag 8'));
      expect(de, contains('26.03.2026'));
      expect(de, contains('keine medizinische'));
      expect(en, contains('cycle day 8'));
      expect(en, contains('2026-03-26'));
      expect(en, contains('not a medical'));
      expect(de, isNot(en));
    });

    test('toJson enthält alle dokumentierten Felder', () {
      final CycleForecast f = computeCycleForecast(regular, '2026-03-05');
      final Map<String, dynamic> json = f.toJson();
      expect(json['on'], '2026-03-05');
      expect(json['basis']['periods_recorded'], 3);
      expect(json['basis']['average_cycle_days'], 28);
      expect(json['last_period_start'], '2026-02-26');
      expect(json['current_cycle_day'], 8);
      expect(json['next_period_start_estimate'], '2026-03-26');
      expect(json['next_period_start_range'], <String>['2026-03-26', '2026-03-26']);
      expect(json['next_period_end_estimate'], '2026-03-30');
      expect(json['confidence'], 'medium');
      expect(json['state'], 'before_next');
    });
  });
}
