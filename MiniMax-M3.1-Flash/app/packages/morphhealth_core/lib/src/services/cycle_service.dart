import '../l10n/strings.dart';
import '../models/records.dart';
import '../store/repository.dart';

/// Personal cycle assessment for one calendar day.
///
/// The assessment is derived exclusively from the periods the user recorded.
/// It is a documentation and planning aid, not a medical or contraception
/// calculation.
class CycleForecast {
  const CycleForecast({
    required this.date,
    required this.hasData,
    required this.recordsUsed,
    required this.explanation,
    this.cycleDay,
    this.averageCycleLength,
    this.minCycleLength,
    this.maxCycleLength,
    this.averagePeriodLength,
    this.lastPeriodStart,
    this.lastPeriodEnd,
    this.predictedNextStart,
    this.predictedWindowStart,
    this.predictedWindowEnd,
    this.daysUntilPredictedStart,
    this.beyondObservedRange = false,
    this.insideRecordedPeriod = false,
  });

  /// The day the assessment belongs to.
  final String date;

  /// Whether at least one period was recorded.
  final bool hasData;

  /// Number of recorded periods that were evaluated.
  final int recordsUsed;

  /// Day within the current cycle, 1 being the first day of the last period.
  final int? cycleDay;

  /// Average length of the observed cycles, in days.
  final double? averageCycleLength;

  /// Shortest observed cycle.
  final int? minCycleLength;

  /// Longest observed cycle.
  final int? maxCycleLength;

  /// Average length of the periods with a known end date, in days.
  final double? averagePeriodLength;

  final String? lastPeriodStart;
  final String? lastPeriodEnd;

  /// Expected start of the next period, derived from the average.
  final String? predictedNextStart;

  /// Earliest start that fits the observed cycle lengths.
  final String? predictedWindowStart;

  /// Latest start that fits the observed cycle lengths.
  final String? predictedWindowEnd;

  final int? daysUntilPredictedStart;

  /// Whether the assessed day lies behind the longest observed cycle.
  final bool beyondObservedRange;

  /// Whether the assessed day lies inside a recorded period.
  final bool insideRecordedPeriod;

  /// Human readable explanation, already localized.
  final List<String> explanation;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'date': date,
        'has_data': hasData,
        'records_used': recordsUsed,
        'cycle_day': cycleDay,
        'average_cycle_length': averageCycleLength,
        'min_cycle_length': minCycleLength,
        'max_cycle_length': maxCycleLength,
        'average_period_length': averagePeriodLength,
        'last_period_start': lastPeriodStart,
        'last_period_end': lastPeriodEnd,
        'predicted_next_start': predictedNextStart,
        'predicted_window_start': predictedWindowStart,
        'predicted_window_end': predictedWindowEnd,
        'days_until_predicted_start': daysUntilPredictedStart,
        'beyond_observed_range': beyondObservedRange,
        'inside_recorded_period': insideRecordedPeriod,
        'explanation': explanation,
      };
}

/// Evaluates the recorded cycle history.
class CycleService {
  CycleService(this._repository, {Strings? strings})
      : strings = strings ?? Strings.de;

  final HealthRepository _repository;
  final Strings strings;

  /// Periods that were used for the statistics (spotting excluded).
  List<PeriodRecord> get cycleRecords {
    final List<PeriodRecord> all = _repository.periods
        .where((PeriodRecord p) => !p.spotting)
        .toList(growable: false)
      ..sort((PeriodRecord a, PeriodRecord b) => a.startDate.compareTo(b.startDate));
    return all;
  }

  /// All recorded periods including spotting.
  List<PeriodRecord> get allRecords => _repository.periods;

  /// Assesses the cycle for [on].
  CycleForecast forecast(String on) {
    final List<PeriodRecord> records = cycleRecords;
    if (records.isEmpty) {
      return CycleForecast(
        date: on,
        hasData: false,
        recordsUsed: 0,
        explanation: <String>[
          strings.t('cycle.before_first'),
          strings.t('cycle.not_a_medical_advice'),
        ],
      );
    }

    final PeriodRecord last = records.last;
    final List<int> cycleLengths = <int>[];
    for (int i = 1; i < records.length; i++) {
      final int diff =
          DateMath.dayDiff(records[i - 1].startDate, records[i].startDate);
      if (diff > 0) cycleLengths.add(diff);
    }

    final List<int> periodLengths = <int>[];
    for (final PeriodRecord record in records) {
      final int? length = record.lengthDays;
      if (length != null && length > 0) periodLengths.add(length);
    }

    final double? averageCycle = cycleLengths.isEmpty
        ? null
        : cycleLengths.reduce((int a, int b) => a + b) / cycleLengths.length;
    final double? averagePeriod = periodLengths.isEmpty
        ? null
        : periodLengths.reduce((int a, int b) => a + b) / periodLengths.length;

    final int? minCycle = cycleLengths.isEmpty
        ? null
        : cycleLengths.reduce((int a, int b) => a < b ? a : b);
    final int? maxCycle = cycleLengths.isEmpty
        ? null
        : cycleLengths.reduce((int a, int b) => a > b ? a : b);

    final int daysSinceLast = DateMath.dayDiff(last.startDate, on);
    final int? cycleDay = daysSinceLast >= 0 ? daysSinceLast + 1 : null;

    String? predictedStart;
    String? windowStart;
    String? windowEnd;
    if (averageCycle != null) {
      predictedStart = DateMath.addDays(
        last.startDate,
        averageCycle.round(),
      );
      if (minCycle != null) {
        windowStart = DateMath.addDays(last.startDate, minCycle);
      }
      if (maxCycle != null) {
        windowEnd = DateMath.addDays(last.startDate, maxCycle);
      }
    }

    final bool beyond = maxCycle != null && daysSinceLast > maxCycle;
    final bool inside = _isInsidePeriod(last, on);
    final int? daysUntil = predictedStart == null
        ? null
        : DateMath.dayDiff(on, predictedStart);

    final List<String> explanation = <String>[];
    explanation.add(strings.t(
      'cycle.basis_records',
      <String, String>{'count': '${records.length}'},
    ));
    if (cycleDay != null) {
      explanation.add(strings.t(
        'cycle.day_of_cycle',
        <String, String>{'day': '$cycleDay'},
      ));
    } else {
      explanation.add(strings.t(
        'cycle.since_last',
        <String, String>{'days': '${daysSinceLast.abs()}'},
      ));
    }
    if (averageCycle != null) {
      explanation.add(strings.t(
        'cycle.avg_length',
        <String, String>{'avg': averageCycle.toStringAsFixed(1)},
      ));
      explanation.add(strings.t(
        'cycle.expected_range',
        <String, String>{
          'min': '$minCycle',
          'max': '$maxCycle',
        },
      ));
      explanation.add(strings.t(
        'cycle.predicted_start',
        <String, String>{'date': predictedStart ?? ''},
      ));
    } else {
      explanation.add(strings.t('cycle.only_one'));
    }
    if (averagePeriod != null) {
      explanation.add(strings.t(
        'cycle.period_length',
        <String, String>{'avg': averagePeriod.toStringAsFixed(1)},
      ));
    }
    if (last.endDate != null) {
      explanation.add(strings.t(
        'cycle.recorded',
        <String, String>{
          'start': last.startDate,
          'end': last.endDate ?? '',
        },
      ));
    } else {
      explanation.add(strings.t(
        'cycle.recorded_open',
        <String, String>{'start': last.startDate},
      ));
    }
    if (beyond) {
      explanation.add(strings.t('cycle.beyond_range'));
    }
    explanation.add(strings.t('cycle.not_a_medical_advice'));

    return CycleForecast(
      date: on,
      hasData: true,
      recordsUsed: records.length,
      cycleDay: cycleDay,
      averageCycleLength: averageCycle,
      minCycleLength: minCycle,
      maxCycleLength: maxCycle,
      averagePeriodLength: averagePeriod,
      lastPeriodStart: last.startDate,
      lastPeriodEnd: last.endDate,
      predictedNextStart: predictedStart,
      predictedWindowStart: windowStart,
      predictedWindowEnd: windowEnd,
      daysUntilPredictedStart: daysUntil,
      beyondObservedRange: beyond,
      insideRecordedPeriod: inside,
      explanation: explanation,
    );
  }

  bool _isInsidePeriod(PeriodRecord record, String date) {
    if (DateMath.before(date, record.startDate)) return false;
    final String? end = record.endDate;
    if (end == null) return true;
    return !DateMath.after(date, end);
  }

  /// All calendar days that belong to a recorded period.
  Set<String> periodDays() {
    final Set<String> days = <String>{};
    for (final PeriodRecord record in _repository.periods) {
      final String? end = record.endDate;
      if (end == null) {
        days.add(record.startDate);
      } else {
        days.addAll(DateMath.range(record.startDate, end));
      }
    }
    return days;
  }

  /// Days that belong to a period that is currently running.
  Set<String> openPeriodDays() {
    final Set<String> days = <String>{};
    for (final PeriodRecord record in _repository.periods) {
      if (record.endDate != null) continue;
      days.add(record.startDate);
    }
    return days;
  }

  /// Length of every recorded cycle, in days.
  List<int> observedCycleLengths() {
    final List<PeriodRecord> records = cycleRecords;
    final List<int> lengths = <int>[];
    for (int i = 1; i < records.length; i++) {
      final int diff =
          DateMath.dayDiff(records[i - 1].startDate, records[i].startDate);
      if (diff > 0) lengths.add(diff);
    }
    return lengths;
  }
}
