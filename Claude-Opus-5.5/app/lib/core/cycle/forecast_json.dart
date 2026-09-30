import '../l10n/format.dart';
import '../l10n/strings.dart';
import '../nutrition/nutrition.dart';
import 'forecast.dart';

/// JSON form of a [CycleForecast] as returned by `cycle.forecast`. Texts
/// are the same ones the app shows, in the configured language.
Map<String, Object?> forecastToJson(CycleForecast f, S s, Fmt fmt) {
  String? iso(dynamic d) => d?.toIso();
  final period = f.currentPeriod;
  return {
    'on': f.on.toIso(),
    'predictions_enabled': f.predictionsEnabled,
    'status': f.status.json,
    'periods_considered': f.periodsConsidered,
    'last_period_start': iso(f.lastPeriodStart),
    'cycle_day': f.cycleDay,
    'current_period': period == null
        ? null
        : {
            'id': period.id,
            'start': period.start.toIso(),
            'end': period.end != null && period.end!.isAtOrBefore(f.on)
                ? period.end!.toIso()
                : null,
            'day': f.currentPeriodDay,
            'expected_end': iso(f.expectedCurrentEnd),
          },
    'next_period': f.hasEstimate
        ? {
            'expected_start': iso(f.expectedStart),
            'window_start': iso(f.windowStart),
            'window_end': iso(f.windowEnd),
            'days_until_expected_start': f.daysUntilExpected,
            'days_after_window': f.daysAfterWindow,
            'expected_length_days': f.medianPeriodLength,
          }
        : null,
    'upcoming_periods': [
      for (final p in f.upcoming) {'start': p.start.toIso(), 'end': iso(p.end)},
    ],
    'confidence': f.confidence?.json,
    'basis': {
      'method':
          'median of the last up to ${CycleForecaster.maxCyclesUsed} plausible '
          'cycle lengths (days between period starts, 15–90 days); window = '
          'median ± max(1, ceil(sample standard deviation)) days, ± 3 days '
          'with a single cycle',
      'cycles_used': [
        for (final c in f.cycles) {'start': c.start.toIso(), 'length_days': c.length},
      ],
      'cycle_lengths': [for (final c in f.cycles) c.length],
      'excluded_cycles': [
        for (final e in f.excluded)
          {
            'start': e.sample.start.toIso(),
            'length_days': e.sample.length,
            'reason': e.reason.json,
          },
      ],
      'median_cycle_length': f.medianCycleLength,
      'mean_cycle_length': f.meanCycleLength == null ? null : round3(f.meanCycleLength!),
      'sd_cycle_length': f.sdCycleLength == null ? null : round3(f.sdCycleLength!),
      'min_cycle_length': f.minCycleLength,
      'max_cycle_length': f.maxCycleLength,
      'window_half_width_days': f.windowHalfWidth,
      'period_lengths': f.periodLengths,
      'median_period_length': f.medianPeriodLength,
    },
    'summary': {
      'headline': s.cycleHeadline(f, fmt),
      'detail': s.cycleSubline(f, fmt),
    },
    'explanation': s.cycleExplanation(f, fmt),
    'language': s.language.json,
    'disclaimer': s.disclaimer,
  };
}
