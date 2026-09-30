import 'dart:math' as math;

import '../model/cycle_records.dart';
import '../util/local_date.dart';

/// Where the viewing day stands relative to the personal estimate.
enum CycleStatus {
  /// No period recorded up to the viewing day.
  noData('no_data'),

  /// Periods exist but no plausible complete cycle yet (fewer than two
  /// period starts), so no personal estimate is possible.
  insufficientData('insufficient_data'),

  /// The viewing day lies within a recorded period.
  inPeriod('in_period'),

  /// Before the estimated window of the next period.
  beforeWindow('before_window'),

  /// Inside the estimated window of the next period.
  inWindow('in_window'),

  /// After the estimated window, and no new period has been recorded.
  afterWindow('after_window'),

  /// Predictions are switched off (diary mode); only recorded facts shown.
  diaryOnly('diary_only');

  const CycleStatus(this.json);
  final String json;
}

enum ForecastConfidence {
  low('low'),
  medium('medium'),
  high('high');

  const ForecastConfidence(this.json);
  final String json;
}

class CycleSample {
  const CycleSample(this.start, this.length);

  /// First day of the period that opened this cycle.
  final LocalDate start;

  /// Days until the next period started.
  final int length;
}

enum ExclusionReason {
  tooShort('shorter_than_15_days'),
  tooLong('longer_than_90_days');

  const ExclusionReason(this.json);
  final String json;
}

class ExcludedCycle {
  const ExcludedCycle(this.sample, this.reason);

  final CycleSample sample;
  final ExclusionReason reason;
}

class PredictedPeriod {
  const PredictedPeriod(this.start, this.end);

  final LocalDate start;

  /// Estimated last day (null if the typical period length is unknown).
  final LocalDate? end;
}

/// The personal cycle estimate for one viewing day, with everything needed
/// to explain how it was derived.
class CycleForecast {
  CycleForecast({
    required this.on,
    required this.predictionsEnabled,
    required this.status,
    required this.periodsConsidered,
    this.currentPeriod,
    this.currentPeriodDay,
    this.lastPeriodStart,
    this.cycleDay,
    this.cycles = const [],
    this.excluded = const [],
    this.medianCycleLength,
    this.meanCycleLength,
    this.sdCycleLength,
    this.windowHalfWidth,
    this.periodLengths = const [],
    this.medianPeriodLength,
    this.expectedStart,
    this.windowStart,
    this.windowEnd,
    this.expectedCurrentEnd,
    this.upcoming = const [],
    this.confidence,
  });

  final LocalDate on;
  final bool predictionsEnabled;
  final CycleStatus status;

  /// Number of recorded periods that started on or before [on].
  final int periodsConsidered;

  final Period? currentPeriod;

  /// 1-based day within the current period.
  final int? currentPeriodDay;
  final LocalDate? lastPeriodStart;

  /// 1-based day of the current cycle (day 1 = first day of last period).
  final int? cycleDay;

  /// Cycles used for the estimate (most recent last).
  final List<CycleSample> cycles;
  final List<ExcludedCycle> excluded;
  final int? medianCycleLength;
  final double? meanCycleLength;
  final double? sdCycleLength;
  final int? windowHalfWidth;
  final List<int> periodLengths;
  final int? medianPeriodLength;
  final LocalDate? expectedStart;
  final LocalDate? windowStart;
  final LocalDate? windowEnd;

  /// Estimated last day of an ongoing period.
  final LocalDate? expectedCurrentEnd;
  final List<PredictedPeriod> upcoming;
  final ForecastConfidence? confidence;

  bool get hasEstimate => expectedStart != null;

  int? get daysUntilExpected =>
      expectedStart == null ? null : on.daysUntil(expectedStart!);

  int? get daysAfterWindow => windowEnd == null || !on.isAfter(windowEnd!)
      ? null
      : windowEnd!.daysUntil(on);

  int? get minCycleLength =>
      cycles.isEmpty ? null : cycles.map((c) => c.length).reduce(math.min);

  int? get maxCycleLength =>
      cycles.isEmpty ? null : cycles.map((c) => c.length).reduce(math.max);

  /// Whether [day] is an estimated (not recorded) period day.
  bool isPredictedPeriodDay(LocalDate day) {
    for (final p in upcoming) {
      final end = p.end ?? p.start;
      if (day.isWithin(p.start, end)) return true;
    }
    return false;
  }

  /// Whether [day] lies in the window of the next expected period start.
  bool isInWindow(LocalDate day) =>
      windowStart != null && day.isWithin(windowStart!, windowEnd!);
}

/// Computes personal cycle estimates from the recorded period history.
///
/// Method (documented in the app's explanation and the README):
/// 1. Only periods that started on or before the viewing day are used.
/// 2. Cycle length = days between consecutive period starts. Lengths below
///    15 or above 90 days are excluded as likely missing/extra entries.
/// 3. The last up to 6 plausible cycles are used. The expected next start is
///    the last start plus the median cycle length.
/// 4. The window is ± max(1, ⌈standard deviation⌉) days, at most ± 10;
///    with a single cycle ± 3 days.
/// 5. Confidence: high for ≥ 3 cycles with SD ≤ 2 days, medium for SD ≤ 4
///    days, otherwise (or with a single cycle) low.
/// 6. Typical period length = median of the last up to 6 finished periods.
class CycleForecaster {
  const CycleForecaster();

  static const int maxCyclesUsed = 6;
  static const int minPlausibleCycle = 15;
  static const int maxPlausibleCycle = 90;
  static const int upcomingCount = 3;

  CycleForecast forecast(
    List<Period> periodsSortedByStart,
    LocalDate on, {
    bool predictionsEnabled = true,
  }) {
    final known = periodsSortedByStart
        .where((p) => p.start.isAtOrBefore(on))
        .toList();
    if (known.isEmpty) {
      return CycleForecast(
        on: on,
        predictionsEnabled: predictionsEnabled,
        status: predictionsEnabled ? CycleStatus.noData : CycleStatus.diaryOnly,
        periodsConsidered: 0,
      );
    }

    final last = known.last;
    // As of [on], a period that ends later is still ongoing.
    final lastEnd = last.end != null && last.end!.isAtOrBefore(on)
        ? last.end
        : null;
    final inPeriod = lastEnd == null || on.isAtOrBefore(lastEnd);
    final cycleDay = last.start.daysUntil(on) + 1;

    // Cycle lengths between consecutive starts.
    final samples = <CycleSample>[];
    final excluded = <ExcludedCycle>[];
    for (var i = 1; i < known.length; i++) {
      final sample = CycleSample(
        known[i - 1].start,
        known[i - 1].start.daysUntil(known[i].start),
      );
      if (sample.length < minPlausibleCycle) {
        excluded.add(ExcludedCycle(sample, ExclusionReason.tooShort));
      } else if (sample.length > maxPlausibleCycle) {
        excluded.add(ExcludedCycle(sample, ExclusionReason.tooLong));
      } else {
        samples.add(sample);
      }
    }
    final used = samples.length > maxCyclesUsed
        ? samples.sublist(samples.length - maxCyclesUsed)
        : samples;

    // Typical period length from finished periods (as of [on]).
    final finishedLengths = <int>[
      for (final p in known)
        if (p.end != null && p.end!.isAtOrBefore(on)) p.lengthDays!,
    ];
    final recentLengths = finishedLengths.length > maxCyclesUsed
        ? finishedLengths.sublist(finishedLengths.length - maxCyclesUsed)
        : finishedLengths;
    final medianPeriod = recentLengths.isEmpty
        ? null
        : _medianRounded(recentLengths);

    final currentPeriod = inPeriod ? last : null;
    final currentDay = inPeriod ? cycleDay : null;
    LocalDate? expectedCurrentEnd;
    if (inPeriod && lastEnd == null && medianPeriod != null) {
      expectedCurrentEnd = last.start.addDays(medianPeriod - 1);
      if (expectedCurrentEnd.isBefore(on)) expectedCurrentEnd = null;
    }

    if (!predictionsEnabled) {
      return CycleForecast(
        on: on,
        predictionsEnabled: false,
        status: CycleStatus.diaryOnly,
        periodsConsidered: known.length,
        currentPeriod: currentPeriod,
        currentPeriodDay: currentDay,
        lastPeriodStart: last.start,
        cycleDay: cycleDay,
        periodLengths: recentLengths,
        medianPeriodLength: medianPeriod,
      );
    }

    if (used.isEmpty) {
      return CycleForecast(
        on: on,
        predictionsEnabled: true,
        status: inPeriod ? CycleStatus.inPeriod : CycleStatus.insufficientData,
        periodsConsidered: known.length,
        currentPeriod: currentPeriod,
        currentPeriodDay: currentDay,
        lastPeriodStart: last.start,
        cycleDay: cycleDay,
        excluded: excluded,
        periodLengths: recentLengths,
        medianPeriodLength: medianPeriod,
        expectedCurrentEnd: expectedCurrentEnd,
      );
    }

    final lengths = used.map((c) => c.length).toList();
    final median = _medianRounded(lengths);
    final mean = lengths.reduce((a, b) => a + b) / lengths.length;
    double? sd;
    if (lengths.length >= 2) {
      final variance =
          lengths.map((l) => (l - mean) * (l - mean)).reduce((a, b) => a + b) /
          (lengths.length - 1);
      sd = math.sqrt(variance);
    }
    final halfWidth = sd == null ? 3 : sd.ceil().clamp(1, 10);

    final expected = last.start.addDays(median);
    final windowStart = expected.addDays(-halfWidth);
    final windowEnd = expected.addDays(halfWidth);

    ForecastConfidence confidence;
    if (sd == null) {
      confidence = ForecastConfidence.low;
    } else if (lengths.length >= 3 && sd <= 2) {
      confidence = ForecastConfidence.high;
    } else if (sd <= 4) {
      confidence = ForecastConfidence.medium;
    } else {
      confidence = ForecastConfidence.low;
    }

    CycleStatus status;
    if (inPeriod) {
      status = CycleStatus.inPeriod;
    } else if (on.isBefore(windowStart)) {
      status = CycleStatus.beforeWindow;
    } else if (on.isAtOrBefore(windowEnd)) {
      status = CycleStatus.inWindow;
    } else {
      status = CycleStatus.afterWindow;
    }

    final upcoming = <PredictedPeriod>[];
    for (var k = 1; k <= upcomingCount + 1 && upcoming.length < upcomingCount; k++) {
      final start = last.start.addDays(median * k);
      // An overdue estimate is not drawn into the past.
      if (start.isBefore(on) && !inPeriod) continue;
      upcoming.add(
        PredictedPeriod(
          start,
          medianPeriod == null ? null : start.addDays(medianPeriod - 1),
        ),
      );
    }

    return CycleForecast(
      on: on,
      predictionsEnabled: true,
      status: status,
      periodsConsidered: known.length,
      currentPeriod: currentPeriod,
      currentPeriodDay: currentDay,
      lastPeriodStart: last.start,
      cycleDay: cycleDay,
      cycles: used,
      excluded: excluded,
      medianCycleLength: median,
      meanCycleLength: mean,
      sdCycleLength: sd,
      windowHalfWidth: halfWidth,
      periodLengths: recentLengths,
      medianPeriodLength: medianPeriod,
      expectedStart: expected,
      windowStart: windowStart,
      windowEnd: windowEnd,
      expectedCurrentEnd: expectedCurrentEnd,
      upcoming: upcoming,
      confidence: confidence,
    );
  }

  static int _medianRounded(List<int> values) {
    final sorted = [...values]..sort();
    final mid = sorted.length ~/ 2;
    if (sorted.length.isOdd) return sorted[mid];
    return ((sorted[mid - 1] + sorted[mid]) / 2).round();
  }
}
