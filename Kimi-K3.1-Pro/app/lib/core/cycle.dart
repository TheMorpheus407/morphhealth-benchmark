import 'health.dart';
import 'utils.dart';

class CycleForecast {
  const CycleForecast({
    required this.on,
    required this.sampleSize,
    required this.cycleLengths,
    required this.excludedIntervals,
    this.predictedStart,
    this.earliestStart,
    this.latestStart,
    this.predictedEnd,
    this.medianCycleDays,
    this.medianPeriodDays,
  });

  final String on;
  final int sampleSize;
  final List<int> cycleLengths;
  final int excludedIntervals;
  final String? predictedStart;
  final String? earliestStart;
  final String? latestStart;
  final String? predictedEnd;
  final double? medianCycleDays;
  final double? medianPeriodDays;

  bool get available => predictedStart != null;
  String get confidence => sampleSize >= 4
      ? 'medium'
      : sampleSize >= 2
      ? 'low'
      : 'very_low';

  Map<String, dynamic> toJson() => {
    'on': on,
    'available': available,
    'confidence': available ? confidence : 'none',
    'sample_size': sampleSize,
    'cycle_lengths_days': cycleLengths,
    'excluded_implausible_intervals': excludedIntervals,
    'median_cycle_days': medianCycleDays,
    'median_period_days': medianPeriodDays,
    'predicted_start': predictedStart,
    'earliest_start': earliestStart,
    'latest_start': latestStart,
    'predicted_end': predictedEnd,
    'method': 'median_of_up_to_6_recent_start_to_start_cycles_with_mad_range',
    'explanation': available
        ? 'The estimate uses the median of $sampleSize recent recorded start-to-start '
              'cycle(s): ${cycleLengths.join(', ')} days. The range is the median plus/minus '
              'the median absolute deviation, with a minimum width of two days. Intervals '
              'outside 15–90 days are excluded. This is a personal planning estimate, not a '
              'diagnosis, ovulation calculation or contraception method.'
        : 'At least one plausible recorded start-to-start interval is required. Add past '
              'period start dates to receive a personal estimate. No ovulation or fertility '
              'estimate is made.',
  };
}

double median(List<num> source) {
  if (source.isEmpty) throw ArgumentError('median of empty list');
  final values = [...source]..sort();
  final middle = values.length ~/ 2;
  return values.length.isOdd
      ? values[middle].toDouble()
      : (values[middle - 1] + values[middle]) / 2;
}

int _calendarDaysBetween(String start, String end) {
  final first = parseDate(start);
  final second = parseDate(end);
  return DateTime.utc(
    second.year,
    second.month,
    second.day,
  ).difference(DateTime.utc(first.year, first.month, first.day)).inDays;
}

CycleForecast forecastCycle(List<Period> source, String on) {
  parseDate(on, 'on');
  final periods =
      source.where((period) => period.start.compareTo(on) <= 0).toList()
        ..sort((a, b) => a.start.compareTo(b.start));
  final allIntervals = <int>[];
  for (var index = 1; index < periods.length; index++) {
    allIntervals.add(
      _calendarDaysBetween(periods[index - 1].start, periods[index].start),
    );
  }
  final plausible = allIntervals
      .where((days) => days >= 15 && days <= 90)
      .toList();
  final recent = plausible.length > 6
      ? plausible.sublist(plausible.length - 6)
      : plausible;
  if (recent.isEmpty || periods.isEmpty) {
    return CycleForecast(
      on: on,
      sampleSize: 0,
      cycleLengths: const [],
      excludedIntervals: allIntervals.length - plausible.length,
    );
  }
  final typicalCycle = median(recent);
  final deviations = recent.map((days) => (days - typicalCycle).abs()).toList();
  final width = median(deviations).round().clamp(2, 30);
  final lastStart = parseDate(periods.last.start);
  final predicted = addDays(lastStart, typicalCycle.round());
  final periodLengths = periods
      .where((period) => period.end != null)
      .map((period) => _calendarDaysBetween(period.start, period.end!) + 1)
      .where((days) => days >= 1 && days <= 30)
      .toList();
  final recentPeriodLengths = periodLengths.length > 6
      ? periodLengths.sublist(periodLengths.length - 6)
      : periodLengths;
  final typicalPeriod = recentPeriodLengths.isEmpty
      ? null
      : median(recentPeriodLengths);
  return CycleForecast(
    on: on,
    sampleSize: recent.length,
    cycleLengths: recent,
    excludedIntervals: allIntervals.length - plausible.length,
    medianCycleDays: typicalCycle,
    medianPeriodDays: typicalPeriod,
    predictedStart: dateKey(predicted),
    earliestStart: dateKey(addDays(lastStart, (typicalCycle - width).round())),
    latestStart: dateKey(addDays(lastStart, (typicalCycle + width).round())),
    predictedEnd: typicalPeriod == null
        ? null
        : dateKey(addDays(predicted, typicalPeriod.round() - 1)),
  );
}
