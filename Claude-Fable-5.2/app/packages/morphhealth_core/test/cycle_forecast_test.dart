import 'package:morphhealth_core/morphhealth_core.dart';
import 'package:morphhealth_core/src/portable/example_document.dart';
import 'package:test/test.dart';

final _stamp = LocalDateTime.parse('2026-01-01T08:00:00');

/// Periods of [length] days that start [first] and then follow each other at
/// the given cycle lengths.
List<Period> _periods(String first, List<int> cycles, {int length = 5}) {
  final out = <Period>[];
  var start = Day.parse(first);
  for (var i = 0; i <= cycles.length; i++) {
    out.add(
      Period(
        id: 'p$i',
        start: start,
        end: start.addDays(length - 1),
        createdAt: _stamp,
        updatedAt: _stamp,
      ),
    );
    if (i < cycles.length) start = start.addDays(cycles[i]);
  }
  return out;
}

void main() {
  group('regular cycles', () {
    final periods = _periods('2026-01-05', [28, 28, 28, 28, 28, 28]);
    final lastStart = periods.last.start; // 2026-06-22
    final f = CycleForecast.compute(periods, lastStart.addDays(9));

    test('expects the next period one typical cycle after the last start', () {
      expect(f.status, ForecastStatus.upcoming);
      expect(f.typicalLengthDays, 28);
      expect(f.next!.expectedStart, lastStart.addDays(28));
      expect(f.next!.expectedEnd, lastStart.addDays(28 + 4));
      expect(f.typicalPeriodLengthDays, 5);
      expect(f.periodLengthFromHistory, isTrue);
    });

    test('names a narrow but not overconfident window', () {
      expect(f.variationDays, 2);
      expect(f.next!.earliestStart, lastStart.addDays(26));
      expect(f.next!.latestStart, lastStart.addDays(30));
      expect(f.confidence, Confidence.high);
      expect(f.regularity, Regularity.veryRegular);
    });

    test('describes the viewing day', () {
      expect(f.cycleDay, 10);
      expect(f.inPeriod, isFalse);
      expect(f.daysUntilExpectedStart, 19);
      expect(f.daysUntilWindow, 17);
      expect(f.lastPeriod!.id, periods.last.id);
    });

    test('projects further periods with widening windows', () {
      expect(f.following.map((p) => p.expectedStart), [
        for (final k in [2, 3, 4]) lastStart.addDays(28 * k),
      ]);
      final widths = [
        for (final p in f.predictedPeriods)
          p.latestStart.daysSince(p.earliestStart),
      ];
      expect(widths, orderedEquals([...widths]..sort()));
      expect(widths.last, greaterThan(widths.first));
    });

    test('twelve identical cycles tighten the window to one day', () {
      final many = _periods('2025-01-06', List.filled(12, 28));
      final g = CycleForecast.compute(many, many.last.start.addDays(3));
      expect(g.variationDays, 1);
      expect(g.cyclesUsed, 12);
    });

    test('only the twelve most recent cycles are considered', () {
      final many = _periods('2024-01-01', [
        ...List.filled(10, 35),
        ...List.filled(12, 27),
      ]);
      final g = CycleForecast.compute(many, many.last.start.addDays(3));
      expect(g.cyclesRecorded, 22);
      expect(g.cycles.length, 12);
      expect(g.typicalLengthDays, 27);
    });
  });

  group('status over time', () {
    final periods = _periods('2026-01-05', [28, 28, 28, 28, 28, 28]);
    final last = periods.last.start;
    CycleForecast on(int daysAfterLastStart) =>
        CycleForecast.compute(periods, last.addDays(daysAfterLastStart));

    test('in period', () {
      final f = on(2);
      expect(f.inPeriod, isTrue);
      expect(f.periodDay, 3);
      expect(f.currentPeriodExpectedEnd, last.addDays(4));
      expect(f.status, ForecastStatus.upcoming);
    });

    test('upcoming → due → late → stale', () {
      expect(on(25).status, ForecastStatus.upcoming);
      expect(on(26).status, ForecastStatus.due);
      expect(on(28).status, ForecastStatus.due);
      expect(on(30).status, ForecastStatus.due);
      final late = on(33);
      expect(late.status, ForecastStatus.late);
      expect(late.daysLate, 3);
      expect(late.next!.expectedStart, last.addDays(28));
      expect(late.following, isEmpty);
      expect(on(44).status, ForecastStatus.late);
      final stale = on(45);
      expect(stale.status, ForecastStatus.stale);
      expect(stale.next, isNull);
      expect(stale.cycleDay, 46);
    });

    test('the estimate uses only what was recorded by the viewing day', () {
      // Looking from the middle of the history: later periods are ignored.
      final viewing = periods[3].start.addDays(10);
      final f = CycleForecast.compute(periods, viewing);
      expect(f.ignoredFuturePeriods, 3);
      expect(f.lastPeriod!.id, 'p3');
      expect(f.cyclesUsed, 3);
      expect(f.next!.expectedStart, periods[4].start);
    });

    test('before the first recorded period there is nothing to assess', () {
      final f = CycleForecast.compute(periods, Day(2025, 12, 1));
      expect(f.status, ForecastStatus.noData);
      expect(f.ignoredFuturePeriods, 7);
    });
  });

  group('little data', () {
    test('no period', () {
      final f = CycleForecast.compute(const [], Day(2026, 9, 23));
      expect(f.status, ForecastStatus.noData);
      expect(f.hasEstimate, isFalse);
      expect(f.explain('de').single, contains('noch keine Periode'));
    });

    test('one period: cycle day, but no invented forecast', () {
      final f = CycleForecast.compute(
        _periods('2026-09-10', const []),
        Day(2026, 9, 23),
      );
      expect(f.status, ForecastStatus.insufficientData);
      expect(f.cycleDay, 14);
      expect(f.next, isNull);
      expect(f.explain('de').first, contains('mindestens zwei'));
      expect(f.explain('en').first, contains('at least two'));
    });

    test('two periods: an estimate with a wide window and low confidence', () {
      final periods = _periods('2026-08-01', [30]);
      final f = CycleForecast.compute(periods, Day(2026, 9, 5));
      expect(f.status, ForecastStatus.upcoming);
      expect(f.next!.expectedStart, Day(2026, 8, 31).addDays(30));
      expect(f.variationDays, 4);
      expect(f.confidence, Confidence.low);
      expect(f.regularity, isNull);
      expect(f.backtest, isNull);
    });

    test('a stated typical length helps until three own cycles exist', () {
      final one = _periods('2026-09-10', const []);
      final f = CycleForecast.compute(
        one,
        Day(2026, 9, 23),
        statedTypicalLength: 30,
      );
      expect(f.status, ForecastStatus.upcoming);
      expect(f.statedLengthUsed, isTrue);
      expect(f.next!.expectedStart, Day(2026, 10, 10));
      expect(f.confidence, Confidence.low);
      expect(f.variationDays, 5);

      // One observed cycle of 26 days and a stated 30 → 28.
      final two = _periods('2026-08-01', [26]);
      final g = CycleForecast.compute(
        two,
        Day(2026, 9, 1),
        statedTypicalLength: 30,
      );
      expect(g.typicalLengthDays, 28);
      expect(g.statedLengthUsed, isTrue);

      // With three own cycles the stated value no longer counts.
      final four = _periods('2026-05-01', [26, 26, 26]);
      final h = CycleForecast.compute(
        four,
        four.last.start.addDays(3),
        statedTypicalLength: 35,
      );
      expect(h.typicalLengthDays, 26);
      expect(h.statedLengthUsed, isFalse);
    });
  });

  group('irregular histories', () {
    test('varying cycles widen the window and lower the confidence', () {
      final periods = _periods('2026-01-01', [26, 32, 28, 35, 27, 30]);
      final f = CycleForecast.compute(periods, periods.last.start.addDays(5));
      expect(f.typicalLengthDays, 30);
      expect(f.variationDays, 4);
      expect((f.shortestDays, f.longestDays), (26, 35));
      expect(f.confidence, Confidence.medium);
      expect(f.regularity, Regularity.variable);
      expect(f.next!.earliestStart, periods.last.start.addDays(26));
      expect(f.next!.latestStart, periods.last.start.addDays(34));
    });

    test('recent cycles count more than old ones', () {
      final shortening = _periods('2026-01-01', [32, 32, 32, 27, 27, 27]);
      final f = CycleForecast.compute(
        shortening,
        shortening.last.start.addDays(2),
      );
      expect(f.meanLengthDays, lessThan(29.5));
      expect(f.typicalLengthDays, 29);
    });

    test('a cycle with a probably missing entry is set aside', () {
      final periods = _periods('2026-01-01', [28, 29, 56, 28, 27]);
      final f = CycleForecast.compute(periods, periods.last.start.addDays(2));
      final excluded = f.cycles.where((c) => !c.used).single;
      expect(excluded.lengthDays, 56);
      expect(excluded.excludedReason, 'likely_missing_entry');
      expect(f.cyclesUsed, 4);
      expect(f.typicalLengthDays, 28);
      expect(
        f.explain('de').join(' '),
        contains('56 Tagen blieb unberücksichtigt'),
      );
    });

    test('implausible cycle lengths never enter the estimate', () {
      final periods = _periods('2026-01-01', [7, 120], length: 3);
      final f = CycleForecast.compute(periods, periods.last.start.addDays(2));
      expect(f.status, ForecastStatus.insufficientData);
      expect(f.cycles.map((c) => c.excludedReason), ['too_short', 'too_long']);
    });

    test('consistently long cycles are respected, not treated as errors', () {
      final periods = _periods('2025-01-01', [44, 47, 45, 46, 44]);
      final f = CycleForecast.compute(periods, periods.last.start.addDays(10));
      expect(f.cyclesUsed, 5);
      expect(f.typicalLengthDays, 45);
      expect(f.status, ForecastStatus.upcoming);
    });
  });

  group('running and unfinished periods', () {
    Period open(String start) => Period(
      id: 'open',
      start: Day.parse(start),
      createdAt: _stamp,
      updatedAt: _stamp,
    );

    test('a period without end is running and gets an expected end', () {
      final periods = [
        ..._periods('2026-06-01', [28, 28]),
        open('2026-08-24'),
      ];
      final f = CycleForecast.compute(periods, Day(2026, 8, 25));
      expect(f.inPeriod, isTrue);
      expect(f.periodDay, 2);
      expect(f.currentPeriodExpectedEnd, Day(2026, 8, 28));
      expect(f.next!.expectedStart, Day(2026, 9, 21));
      // Longer than usual: the expected end moves with the viewing day.
      final later = CycleForecast.compute(periods, Day(2026, 9, 1));
      expect(later.inPeriod, isTrue);
      expect(later.currentPeriodExpectedEnd, Day(2026, 9, 1));
    });

    test(
      'after 14 days without end the period no longer counts as running',
      () {
        final periods = [
          ..._periods('2026-06-01', [28, 28]),
          open('2026-08-24'),
        ];
        final f = CycleForecast.compute(periods, Day(2026, 9, 10));
        expect(f.inPeriod, isFalse);
        expect(f.lastPeriodEndMissing, isTrue);
      },
    );

    test('without any completed period a length of five days is assumed', () {
      final f = CycleForecast.compute(
        [open('2026-08-24')],
        Day(2026, 8, 24),
        statedTypicalLength: 28,
      );
      expect(f.periodLengthFromHistory, isFalse);
      expect(f.typicalPeriodLengthDays, 5);
      expect(f.currentPeriodExpectedEnd, Day(2026, 8, 28));
    });
  });

  test('diary mode gives facts only', () {
    final periods = _periods('2026-01-05', [28, 28, 28]);
    final f = CycleForecast.compute(
      periods,
      periods.last.start.addDays(1),
      predictionsEnabled: false,
    );
    expect(f.status, ForecastStatus.disabled);
    expect(f.next, isNull);
    expect(f.following, isEmpty);
    expect(f.cycleDay, 2);
    expect(f.inPeriod, isTrue);
    expect(f.currentPeriodExpectedEnd, periods.last.end);
    expect(f.confidence, isNull);
    final json = f.toJson();
    expect(json['next_period'], isNull);
    expect((json['basis'] as Map)['typical_cycle_length_days'], isNull);
  });

  test('backtest measures how earlier cycles would have been predicted', () {
    final periods = _periods('2026-01-01', [28, 29, 28, 27, 28, 29, 28]);
    final f = CycleForecast.compute(periods, periods.last.start.addDays(3));
    final b = f.backtest!;
    expect(b.evaluated, 6);
    expect(b.withinWindow, 6);
    expect(b.meanAbsoluteErrorDays, lessThan(1.5));
  });

  group('explanation', () {
    final periods = _periods('2026-01-05', [28, 29, 28, 30, 28, 28]);
    final f = CycleForecast.compute(periods, periods.last.start.addDays(9));

    test('names basis, typical length, window and reliability', () {
      final de = f.explain('de').join('\n');
      expect(de, contains('deine letzten 6 Zyklen'));
      expect(de, contains('28, 29, 28, 30, 28 und 28 Tage'));
      expect(de, contains('typische Zykluslänge von 28 Tagen'));
      expect(de, contains('Zeitfenster'));
      expect(de, contains('Verlässlichkeit'));
      expect(de, contains('Rückblick'));
      final en = f.explain('en').join('\n');
      expect(en, contains('your last 6 cycles'));
      expect(en, contains('28, 29, 28, 30, 28 and 28 days'));
      expect(en, contains('Reliability'));
    });

    test('states the limits of the assessment in both languages', () {
      expect(CycleForecast.disclaimer('de'), contains('Verhütung'));
      expect(CycleForecast.disclaimer('en'), contains('contraception'));
    });

    test('late and stale situations are explained without alarm', () {
      final late = CycleForecast.compute(
        periods,
        periods.last.start.addDays(34),
      );
      expect(late.explain('de').join(' '), contains('seit 4 Tagen vorbei'));
      final stale = CycleForecast.compute(
        periods,
        periods.last.start.addDays(80),
      );
      expect(stale.explain('de').join(' '), contains('vor 80 Tagen'));
      expect(stale.explain('en').join(' '), contains('80 days ago'));
    });
  });

  group('JSON form', () {
    final data = AppData.fromDocument(
      exampleDocument(),
      IssueLog(),
      now: _stamp,
    )!;
    final json = cycleAssessment(data, exampleToday);

    test('has the documented members', () {
      expect(
        json.keys,
        containsAll([
          'on', 'status', 'predictions_enabled', 'today', 'next_period',
          'following_periods', 'basis', 'backtest', 'patterns', 'explanation',
          'disclaimer', 'ignored_future_periods', //
        ]),
      );
      expect(json['status'], 'upcoming');
      final next = json['next_period'] as Map;
      expect(next['expected_start'], '2026-10-14');
      expect(next['window'], {
        'earliest': '2026-10-12',
        'latest': '2026-10-16',
      });
      expect(next['days_until_expected_start'], 21);
      expect((json['today'] as Map)['cycle_day'], 8);
    });

    test('reports recurring symptoms around period starts', () {
      final patterns = (json['patterns'] as List).cast<Map<String, dynamic>>();
      expect(patterns.map((p) => (p['symptom'], p['phase'])), [
        ('Kopfschmerzen', 'before_period'),
        ('Krämpfe', 'during_period'),
      ]);
      expect(patterns.first['cycles_with_symptom'], 4);
      expect(patterns.first['typical_offset_days'], -1);
      expect(patterns.last['typical_offset_days'], 0);
    });

    test('diary mode hides estimates and patterns', () {
      data.settings = data.settings.copyWith(cyclePredictions: false);
      final diary = cycleAssessment(data, exampleToday);
      expect(diary['status'], 'disabled');
      expect(diary['next_period'], isNull);
      expect(diary['patterns'], isEmpty);
    });
  });

  test('symptom patterns need at least three matching cycles', () {
    final data = AppData();
    final periods = _periods('2026-05-01', [28, 28, 28, 28]);
    periods.forEach(data.putPeriod);
    var n = 0;
    void symptom(Day day, String name) => data.putSymptom(
      SymptomEntry(
        id: 's${n++}',
        name: name,
        intensity: 5,
        at: LocalDateTime(day, 10, 0),
        createdAt: _stamp,
        updatedAt: _stamp,
      ),
    );
    symptom(periods[1].start.addDays(-2), 'Rückenschmerzen');
    symptom(periods[2].start.addDays(-2), 'Rückenschmerzen');
    expect(symptomPatterns(data, periods.last.start.addDays(3)), isEmpty);
    symptom(periods[3].start.addDays(-3), 'rückenschmerzen');
    symptom(periods[4].start.addDays(-1), 'Rückenschmerzen');
    final pattern = symptomPatterns(data, periods.last.start.addDays(3)).single;
    expect(pattern.cyclesWith, 4);
    expect(pattern.cyclesTotal, 5);
    expect(pattern.phase, PatternPhase.beforePeriod);
    expect(pattern.typicalOffsetDays, -2);
    // Symptoms after the viewing day are not known yet.
    expect(symptomPatterns(data, periods[2].start), isEmpty);
  });
}
