import 'dart:math' as math;

import '../model/entries.dart';
import '../util/dates.dart';
import '../util/json_reader.dart';

/// Headline classification of a [CycleForecast].
enum ForecastStatus {
  /// Estimates are switched off; the tracker is used as a diary only.
  disabled('disabled'),

  /// No period is recorded up to the viewing day.
  noData('no_data'),

  /// Fewer than two period starts and no stated typical length.
  insufficientData('insufficient_data'),

  /// An estimate exists and the viewing day lies before its time window.
  upcoming('upcoming'),

  /// The viewing day lies inside the time window; no new period recorded yet.
  due('due'),

  /// The time window has passed without a new period being recorded.
  late('late'),

  /// The last recorded period is too long ago for a meaningful estimate.
  stale('stale');

  final String code;
  const ForecastStatus(this.code);
}

enum Confidence {
  low,
  medium,
  high;

  String get code => name;
}

/// How much the cycles that entered the estimate differ from each other.
enum Regularity {
  /// Longest and shortest cycle differ by at most 2 days.
  veryRegular('very_regular'),

  /// … by at most 5 days.
  regular('regular'),

  /// … by at most 9 days.
  variable('variable'),

  /// … by more than 9 days.
  veryVariable('very_variable');

  final String code;
  const Regularity(this.code);
}

/// One recorded cycle: from the start of a period to the start of the next.
class CycleRecord {
  final Day start;
  final Day nextStart;
  final int lengthDays;

  /// Whether the cycle entered the estimate.
  final bool used;

  /// Why it did not: `too_short`, `too_long`, `likely_missing_entry` or
  /// `unusually_short`.
  final String? excludedReason;

  /// Relative weight in the estimate (the most recent used cycle has 1).
  final double weight;

  const CycleRecord({
    required this.start,
    required this.nextStart,
    required this.lengthDays,
    required this.used,
    this.excludedReason,
    this.weight = 0,
  });

  Map<String, dynamic> toJson() => {
    'start': start.toString(),
    'next_start': nextStart.toString(),
    'length_days': lengthDays,
    'used': used,
    if (excludedReason != null) 'excluded_reason': excludedReason,
    if (used) 'weight': roundForJson((weight * 100).roundToDouble() / 100),
  };
}

/// An estimated future period.
class PredictedPeriod {
  /// The single most likely first day.
  final Day expectedStart;

  /// The time window in which the first day is likely to fall.
  final Day earliestStart;
  final Day latestStart;

  /// Expected last day, from the typical length of recorded periods.
  final Day expectedEnd;

  const PredictedPeriod({
    required this.expectedStart,
    required this.earliestStart,
    required this.latestStart,
    required this.expectedEnd,
  });

  int get expectedLengthDays => expectedEnd.daysSince(expectedStart) + 1;

  /// Whether [day] is one of the expected days of bleeding.
  bool isExpectedDay(Day day) => day >= expectedStart && day <= expectedEnd;

  /// Whether [day] lies in the window for the first day.
  bool isInStartWindow(Day day) => day >= earliestStart && day <= latestStart;

  Map<String, dynamic> toJson() => {
    'expected_start': expectedStart.toString(),
    'window': {
      'earliest': earliestStart.toString(),
      'latest': latestStart.toString(),
    },
    'expected_end': expectedEnd.toString(),
    'expected_length_days': expectedLengthDays,
  };
}

/// How well the same calculation would have predicted earlier cycles.
class ForecastBacktest {
  final int evaluated;
  final int withinWindow;
  final double meanAbsoluteErrorDays;

  const ForecastBacktest({
    required this.evaluated,
    required this.withinWindow,
    required this.meanAbsoluteErrorDays,
  });

  Map<String, dynamic> toJson() => {
    'evaluated_cycles': evaluated,
    'start_within_window': withinWindow,
    'mean_absolute_error_days': roundForJson(
      (meanAbsoluteErrorDays * 10).roundToDouble() / 10,
    ),
  };
}

/// The personal cycle assessment for one viewing day.
///
/// It is derived only from the periods the user recorded. It helps to plan
/// for the next period. It is not a medical statement, no ovulation or
/// fertility calculation and not suitable for contraception.
///
/// How it works, in short:
///
/// 1. Cycles are the distances between consecutive period starts. Only
///    periods that started on or before the viewing day count; the twelve
///    most recent cycles are considered.
/// 2. Cycles outside 15–90 days are set aside. With at least four cycles,
///    those longer than 1.6 times the median (a period was probably not
///    recorded in between) or shorter than the median divided by 1.6 are set
///    aside as well.
/// 3. The typical length is the weighted mean of the remaining cycles; each
///    step into the past lowers the weight by 15 %.
/// 4. The time window follows from how much these cycles varied. With few
///    cycles it is deliberately wider, and it is never narrower than one day
///    either side.
/// 5. The expected end uses the median length of the last completed periods.
class CycleForecast {
  /// Cycles considered at most.
  static const int recentCycles = 12;
  static const int minPlausibleLength = 15;
  static const int maxPlausibleLength = 90;
  static const double outlierRatio = 1.6;
  static const int outlierMinCycles = 4;
  static const double decay = 0.85;

  /// Spread assumed before the user's own data say otherwise (days).
  static const double priorSd = 2.5;
  static const double priorWeight = 2;

  /// Normal quantile for a two-sided 80 % interval.
  static const double windowZ = 1.2816;
  static const int defaultPeriodLength = 5;
  static const int periodLengthSamples = 6;
  static const int backtestCycles = 6;

  /// The viewing day ("Betrachtungstag").
  final Day on;
  final ForecastStatus status;
  final bool predictionsEnabled;

  /// The most recent period that started on or before [on].
  final Period? lastPeriod;

  /// Day within the current cycle; day 1 is the first day of [lastPeriod].
  final int? cycleDay;

  /// Whether [on] is a day of [lastPeriod].
  final bool inPeriod;

  /// Day within the current period, if [inPeriod].
  final int? periodDay;

  /// When the current period is expected to end, if [inPeriod].
  final Day? currentPeriodExpectedEnd;

  /// The last period has no recorded end although it started more than
  /// [Period.openPeriodDays] days ago.
  final bool lastPeriodEndMissing;

  /// The next period, if an estimate exists.
  final PredictedPeriod? next;

  /// Further periods after [next], with widening windows.
  final List<PredictedPeriod> following;

  /// Days by which [on] lies after the time window (0 unless late).
  final int daysLate;

  /// The considered cycles, oldest first.
  final List<CycleRecord> cycles;

  /// Cycles recorded up to [on] (before limiting to [recentCycles]).
  final int cyclesRecorded;
  final int cyclesUsed;

  /// Weighted mean length of the used cycles in days.
  final double? meanLengthDays;

  /// [meanLengthDays] rounded: the expected length of the current cycle.
  final int? typicalLengthDays;
  final int? shortestDays;
  final int? longestDays;

  /// Standard deviation used for the window, in days.
  final double? spreadDays;

  /// Half width of the time window of [next] in days.
  final int? variationDays;

  final int typicalPeriodLengthDays;

  /// False while the period length is the default of 5 days.
  final bool periodLengthFromHistory;

  /// The typical cycle length stated by the user, if any.
  final int? statedTypicalLengthDays;

  /// Whether the stated length entered the estimate.
  final bool statedLengthUsed;

  final Confidence? confidence;
  final Regularity? regularity;
  final ForecastBacktest? backtest;

  /// Periods that start after [on] and were therefore not considered.
  final int ignoredFuturePeriods;

  const CycleForecast._({
    required this.on,
    required this.status,
    required this.predictionsEnabled,
    this.lastPeriod,
    this.cycleDay,
    this.inPeriod = false,
    this.periodDay,
    this.currentPeriodExpectedEnd,
    this.lastPeriodEndMissing = false,
    this.next,
    this.following = const [],
    this.daysLate = 0,
    this.cycles = const [],
    this.cyclesRecorded = 0,
    this.cyclesUsed = 0,
    this.meanLengthDays,
    this.typicalLengthDays,
    this.shortestDays,
    this.longestDays,
    this.spreadDays,
    this.variationDays,
    this.typicalPeriodLengthDays = defaultPeriodLength,
    this.periodLengthFromHistory = false,
    this.statedTypicalLengthDays,
    this.statedLengthUsed = false,
    this.confidence,
    this.regularity,
    this.backtest,
    this.ignoredFuturePeriods = 0,
  });

  bool get hasEstimate => next != null;

  /// Days from [on] to the expected start (negative once it has passed).
  int? get daysUntilExpectedStart => next?.expectedStart.daysSince(on);

  /// Days from [on] to the beginning of the time window (0 inside or after).
  int? get daysUntilWindow {
    final n = next;
    if (n == null) return null;
    final d = n.earliestStart.daysSince(on);
    return d < 0 ? 0 : d;
  }

  /// All estimated periods: [next] followed by [following].
  List<PredictedPeriod> get predictedPeriods => [?next, ...following];

  /// Computes the assessment as it presents itself on the day [on].
  ///
  /// Periods that start after [on] are ignored, so that the result is what
  /// the app shows (or would have shown) on that day.
  factory CycleForecast.compute(
    Iterable<Period> periods,
    Day on, {
    bool predictionsEnabled = true,
    int? statedTypicalLength,
    int followingPeriods = 3,
    bool withBacktest = true,
  }) {
    final all = periods.toList();
    final known = all.where((p) => p.start <= on).toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    final ignored = all.length - known.length;

    if (known.isEmpty) {
      return CycleForecast._(
        on: on,
        status: predictionsEnabled
            ? ForecastStatus.noData
            : ForecastStatus.disabled,
        predictionsEnabled: predictionsEnabled,
        statedTypicalLengthDays: statedTypicalLength,
        ignoredFuturePeriods: ignored,
      );
    }

    final last = known.last;
    final elapsed = on.daysSince(last.start);
    final cycleDay = elapsed + 1;
    final lastEnd = last.end;
    final inPeriod = lastEnd != null
        ? on <= lastEnd
        : elapsed < Period.openPeriodDays;
    final endMissing = lastEnd == null && !inPeriod;

    // Typical length of a period: median of the last completed ones.
    final durations = [
      for (final p in known)
        if (p.lengthDays != null) p.lengthDays!,
    ];
    final recentDurations = durations.length > periodLengthSamples
        ? durations.sublist(durations.length - periodLengthSamples)
        : durations;
    final fromHistory = recentDurations.isNotEmpty;
    final periodLength = fromHistory
        ? _median(recentDurations).round()
        : defaultPeriodLength;

    Day? currentEnd;
    if (inPeriod) {
      currentEnd = lastEnd ?? Day.max(last.start.addDays(periodLength - 1), on);
    }

    // Cycles between consecutive starts.
    final lengths = <int>[];
    for (var i = 0; i + 1 < known.length; i++) {
      lengths.add(known[i + 1].start.daysSince(known[i].start));
    }
    final cyclesRecorded = lengths.length;
    final firstIndex = lengths.length > recentCycles
        ? lengths.length - recentCycles
        : 0;

    final reasons = <int, String>{};
    final plausible = <int>[];
    for (var i = firstIndex; i < lengths.length; i++) {
      final l = lengths[i];
      if (l < minPlausibleLength) {
        reasons[i] = 'too_short';
      } else if (l > maxPlausibleLength) {
        reasons[i] = 'too_long';
      } else {
        plausible.add(i);
      }
    }
    if (plausible.length >= outlierMinCycles) {
      final median = _median([for (final i in plausible) lengths[i]]);
      for (final i in plausible) {
        if (lengths[i] > median * outlierRatio) {
          reasons[i] = 'likely_missing_entry';
        } else if (lengths[i] < median / outlierRatio) {
          reasons[i] = 'unusually_short';
        }
      }
    }
    final usedIdx = [
      for (final i in plausible)
        if (!reasons.containsKey(i)) i,
    ];
    final n = usedIdx.length;
    final weights = <int, double>{
      for (var j = 0; j < n; j++)
        usedIdx[j]: math.pow(decay, n - 1 - j).toDouble(),
    };
    final cycles = [
      for (var i = firstIndex; i < lengths.length; i++)
        CycleRecord(
          start: known[i].start,
          nextStart: known[i + 1].start,
          lengthDays: lengths[i],
          used: weights.containsKey(i),
          excludedReason: reasons[i],
          weight: weights[i] ?? 0,
        ),
    ];

    CycleForecast factsOnly(ForecastStatus status) => CycleForecast._(
      on: on,
      status: status,
      predictionsEnabled: predictionsEnabled,
      lastPeriod: last,
      cycleDay: cycleDay,
      inPeriod: inPeriod,
      periodDay: inPeriod ? cycleDay : null,
      // In diary mode only a recorded end is reported, never an estimate.
      currentPeriodExpectedEnd: status == ForecastStatus.disabled
          ? (inPeriod ? lastEnd : null)
          : currentEnd,
      lastPeriodEndMissing: endMissing,
      cycles: cycles,
      cyclesRecorded: cyclesRecorded,
      cyclesUsed: n,
      shortestDays: n == 0
          ? null
          : usedIdx.map((i) => lengths[i]).reduce(math.min),
      longestDays: n == 0
          ? null
          : usedIdx.map((i) => lengths[i]).reduce(math.max),
      typicalPeriodLengthDays: periodLength,
      periodLengthFromHistory: fromHistory,
      statedTypicalLengthDays: statedTypicalLength,
      ignoredFuturePeriods: ignored,
    );

    if (!predictionsEnabled) return factsOnly(ForecastStatus.disabled);
    if (n == 0 && statedTypicalLength == null) {
      return factsOnly(ForecastStatus.insufficientData);
    }

    // Weighted mean and spread.
    double mean;
    double sd;
    var statedUsed = false;
    if (n == 0) {
      mean = statedTypicalLength!.toDouble();
      sd = priorSd * math.sqrt2;
      statedUsed = true;
    } else {
      var sumW = 0.0, sumW2 = 0.0, sumWx = 0.0;
      for (final i in usedIdx) {
        final w = weights[i]!;
        sumW += w;
        sumW2 += w * w;
        sumWx += w * lengths[i];
      }
      if (statedTypicalLength != null && n < 3) {
        mean = (sumWx + statedTypicalLength) / (sumW + 1);
        statedUsed = true;
      } else {
        mean = sumWx / sumW;
      }
      var varSum = 0.0;
      for (final i in usedIdx) {
        final d = lengths[i] - mean;
        varSum += weights[i]! * d * d;
      }
      final variance = varSum / sumW;
      final nEff = sumW * sumW / sumW2;
      final shrunk =
          (priorWeight * priorSd * priorSd + nEff * variance) /
          (priorWeight + nEff);
      sd = math.sqrt(shrunk * (1 + 1 / nEff));
    }

    final typical = (mean + 0.5).floor();
    final half = math.max(1, (windowZ * sd).round());
    final expected = last.start.addDays(typical);
    final next = PredictedPeriod(
      expectedStart: expected,
      earliestStart: Day.max(expected.addDays(-half), last.start.addDays(1)),
      latestStart: expected.addDays(half),
      expectedEnd: expected.addDays(periodLength - 1),
    );

    final ForecastStatus status;
    var daysLate = 0;
    if (elapsed > (mean * outlierRatio).floor()) {
      status = ForecastStatus.stale;
    } else if (on > next.latestStart) {
      status = ForecastStatus.late;
      daysLate = on.daysSince(next.latestStart);
    } else if (on >= next.earliestStart) {
      status = ForecastStatus.due;
    } else {
      status = ForecastStatus.upcoming;
    }

    final following = <PredictedPeriod>[];
    if (status == ForecastStatus.upcoming || status == ForecastStatus.due) {
      for (var j = 2; j <= followingPeriods + 1; j++) {
        final start = last.start.addDays((mean * j + 0.5).floor());
        final h = math.max(1, (windowZ * sd * math.sqrt(j)).round());
        following.add(
          PredictedPeriod(
            expectedStart: start,
            earliestStart: start.addDays(-h),
            latestStart: start.addDays(h),
            expectedEnd: start.addDays(periodLength - 1),
          ),
        );
      }
    }

    final shortest = n == 0
        ? null
        : usedIdx.map((i) => lengths[i]).reduce(math.min);
    final longest = n == 0
        ? null
        : usedIdx.map((i) => lengths[i]).reduce(math.max);

    final Confidence confidence;
    if (n >= 6 && half <= 2) {
      confidence = Confidence.high;
    } else if (n >= 3 && half <= 4) {
      confidence = Confidence.medium;
    } else {
      confidence = Confidence.low;
    }

    Regularity? regularity;
    if (n >= 2) {
      final range = longest! - shortest!;
      regularity = range <= 2
          ? Regularity.veryRegular
          : range <= 5
          ? Regularity.regular
          : range <= 9
          ? Regularity.variable
          : Regularity.veryVariable;
    }

    ForecastBacktest? backtest;
    if (withBacktest && n >= 2) {
      var evaluated = 0, hits = 0, absError = 0;
      final candidates = usedIdx.where((i) => i >= 1).toList();
      final start = candidates.length > backtestCycles
          ? candidates.length - backtestCycles
          : 0;
      for (final i in candidates.sublist(start)) {
        final past = CycleForecast.compute(
          known.sublist(0, i + 1),
          known[i].start,
          statedTypicalLength: statedTypicalLength,
          followingPeriods: 0,
          withBacktest: false,
        );
        final p = past.next;
        if (p == null) continue;
        final actual = known[i + 1].start;
        evaluated++;
        absError += actual.daysSince(p.expectedStart).abs();
        if (p.isInStartWindow(actual)) hits++;
      }
      if (evaluated > 0) {
        backtest = ForecastBacktest(
          evaluated: evaluated,
          withinWindow: hits,
          meanAbsoluteErrorDays: absError / evaluated,
        );
      }
    }

    return CycleForecast._(
      on: on,
      status: status,
      predictionsEnabled: true,
      lastPeriod: last,
      cycleDay: cycleDay,
      inPeriod: inPeriod,
      periodDay: inPeriod ? cycleDay : null,
      currentPeriodExpectedEnd: currentEnd,
      lastPeriodEndMissing: endMissing,
      next: status == ForecastStatus.stale ? null : next,
      following: following,
      daysLate: daysLate,
      cycles: cycles,
      cyclesRecorded: cyclesRecorded,
      cyclesUsed: n,
      meanLengthDays: mean,
      typicalLengthDays: typical,
      shortestDays: shortest,
      longestDays: longest,
      spreadDays: sd,
      variationDays: half,
      typicalPeriodLengthDays: periodLength,
      periodLengthFromHistory: fromHistory,
      statedTypicalLengthDays: statedTypicalLength,
      statedLengthUsed: statedUsed,
      confidence: confidence,
      regularity: regularity,
      backtest: backtest,
      ignoredFuturePeriods: ignored,
    );
  }

  Map<String, dynamic> toJson() {
    final last = lastPeriod;
    final n = next;
    return {
      'on': on.toString(),
      'status': status.code,
      'predictions_enabled': predictionsEnabled,
      'today': {
        'cycle_day': cycleDay,
        'in_period': inPeriod,
        'period_day': periodDay,
        'current_period_expected_end': currentPeriodExpectedEnd?.toString(),
        'last_period': last == null
            ? null
            : {
                'id': last.id,
                'start': last.start.toString(),
                'end': last.end?.toString(),
                'length_days': last.lengthDays,
                'end_missing': lastPeriodEndMissing,
              },
      },
      'next_period': n == null
          ? null
          : {
              ...n.toJson(),
              'days_until_expected_start': daysUntilExpectedStart,
              'days_until_window': daysUntilWindow,
              'days_late': daysLate,
            },
      'following_periods': [for (final p in following) p.toJson()],
      'basis': {
        'method': 'weighted_mean_of_recent_cycles',
        'cycles_recorded': cyclesRecorded,
        'cycles_considered': cycles.length,
        'cycles_used': cyclesUsed,
        'cycles': [for (final c in cycles) c.toJson()],
        'typical_cycle_length_days': typicalLengthDays,
        'mean_cycle_length_days': meanLengthDays == null
            ? null
            : roundForJson((meanLengthDays! * 100).roundToDouble() / 100),
        'shortest_cycle_days': shortestDays,
        'longest_cycle_days': longestDays,
        'spread_sd_days': spreadDays == null
            ? null
            : roundForJson((spreadDays! * 100).roundToDouble() / 100),
        'window_half_width_days': variationDays,
        'regularity': regularity?.code,
        'typical_period_length_days': typicalPeriodLengthDays,
        'period_length_basis': periodLengthFromHistory ? 'history' : 'default',
        'stated_typical_cycle_length_days': statedTypicalLengthDays,
        'stated_length_used': statedLengthUsed,
        'confidence': confidence?.code,
      },
      'backtest': backtest?.toJson(),
      'ignored_future_periods': ignoredFuturePeriods,
      'explanation': {'de': explain('de'), 'en': explain('en')},
      'disclaimer': {'de': disclaimer('de'), 'en': disclaimer('en')},
    };
  }

  /// What the assessment must not be used for.
  static String disclaimer(String language) => language == 'en'
      ? 'This estimate is based only on your own entries. It is a planning '
            'aid, not a medical statement. It is not suitable for contraception '
            'or for determining fertile days.'
      : 'Die Einschätzung beruht allein auf deinen Einträgen. Sie ist eine '
            'Planungshilfe und keine medizinische Aussage. Sie eignet sich weder '
            'zur Verhütung noch zur Bestimmung fruchtbarer Tage.';

  /// A plain-language explanation of this assessment, one paragraph per item.
  List<String> explain(String language) {
    final en = language == 'en';
    String d(Day day) => formatDayLong(day, language);
    String days(int n) =>
        en ? (n == 1 ? '1 day' : '$n days') : (n == 1 ? '1 Tag' : '$n Tage');
    // German dative ("von 28 Tagen", "seit 3 Tagen").
    String daysDat(int n) => en ? days(n) : (n == 1 ? '1 Tag' : '$n Tagen');
    final out = <String>[];

    switch (status) {
      case ForecastStatus.disabled:
        out.add(
          en
              ? 'Estimates are switched off. The period tracker works as a '
                    'diary: it shows what you recorded and calculates nothing '
                    'about the future. You can switch estimates on in the '
                    'settings.'
              : 'Einschätzungen sind ausgeschaltet. Der Periodentracker '
                    'arbeitet als Tagebuch: Er zeigt, was du erfasst hast, und '
                    'berechnet nichts über die Zukunft. Einschalten kannst du die '
                    'Einschätzung in den Einstellungen.',
        );
        return out;
      case ForecastStatus.noData:
        out.add(
          en
              ? 'No period has been recorded yet. Once you enter the first day '
                    'of a period, MorphHealth shows your cycle day. A personal '
                    'estimate becomes possible with two recorded periods.'
              : 'Es ist noch keine Periode erfasst. Sobald du den ersten Tag '
                    'einer Periode einträgst, zeigt MorphHealth deinen Zyklustag. '
                    'Eine persönliche Einschätzung ist ab zwei erfassten Perioden '
                    'möglich.',
        );
        return out;
      case ForecastStatus.insufficientData:
        final excluded = cycles.where((c) => !c.used).length;
        if (excluded > 0) {
          out.add(
            en
                ? 'The recorded cycles cannot be used for an estimate: their '
                      'lengths lie outside the range of '
                      '$minPlausibleLength to $maxPlausibleLength days.'
                : 'Die erfassten Zyklen lassen sich nicht für eine Einschätzung '
                      'verwenden: Ihre Längen liegen außerhalb von '
                      '$minPlausibleLength bis $maxPlausibleLength Tagen.',
          );
        } else {
          out.add(
            en
                ? 'One period is recorded so far (it started on '
                      '${d(lastPeriod!.start)}). A personal estimate needs at '
                      'least two period starts, because the length of your cycle '
                      'only follows from the distance between them.'
                : 'Bisher ist eine Periode erfasst (Beginn am '
                      '${d(lastPeriod!.start)}). Für eine persönliche Einschätzung '
                      'braucht es mindestens zwei Periodenbeginne, denn erst aus '
                      'ihrem Abstand ergibt sich die Länge deines Zyklus.',
          );
        }
        out.add(
          en
              ? 'If you know your usual cycle length, you can state it in the '
                    'settings. It then serves as a starting value until your own '
                    'records are sufficient.'
              : 'Wenn du deine übliche Zykluslänge kennst, kannst du sie in den '
                    'Einstellungen angeben. Sie dient dann als Ausgangswert, bis '
                    'genügend eigene Einträge vorliegen.',
        );
        return out;
      default:
        break;
    }

    final used = cycles.where((c) => c.used).toList();
    final excluded = cycles.where((c) => !c.used).toList();

    // 1. Basis.
    if (used.isEmpty) {
      out.add(
        en
            ? 'No complete cycle of your own is recorded yet. The estimate uses '
                  'the usual cycle length you stated: '
                  '${days(statedTypicalLengthDays!)}.'
            : 'Es ist noch kein vollständiger eigener Zyklus erfasst. Die '
                  'Einschätzung verwendet die von dir angegebene übliche '
                  'Zykluslänge von ${daysDat(statedTypicalLengthDays!)}.',
      );
    } else if (used.length == 1) {
      out.add(
        en
            ? 'The estimate is based on your one recorded cycle, from '
                  '${d(used.first.start)} to ${d(used.first.nextStart)}. It '
                  'lasted ${days(used.first.lengthDays)}.'
            : 'Grundlage ist dein bisher einziger erfasster Zyklus vom '
                  '${d(used.first.start)} bis zum ${d(used.first.nextStart)}. Er '
                  'dauerte ${days(used.first.lengthDays)}.',
      );
    } else {
      final list = _joinList([for (final c in used) '${c.lengthDays}'], en);
      out.add(
        en
            ? 'The estimate is based on your last ${used.length} cycles, '
                  'recorded between ${d(used.first.start)} and '
                  '${d(used.last.nextStart)}. They lasted $list days.'
            : 'Grundlage sind deine letzten ${used.length} Zyklen, erfasst '
                  'zwischen dem ${d(used.first.start)} und dem '
                  '${d(used.last.nextStart)}. Sie dauerten $list Tage.',
      );
    }
    if (excluded.isNotEmpty) {
      final missing = excluded
          .where(
            (c) =>
                c.excludedReason == 'likely_missing_entry' ||
                c.excludedReason == 'too_long',
          )
          .toList();
      final short = excluded
          .where(
            (c) =>
                c.excludedReason == 'unusually_short' ||
                c.excludedReason == 'too_short',
          )
          .toList();
      if (missing.isNotEmpty) {
        final list = _joinList([
          for (final c in missing) '${c.lengthDays}',
        ], en);
        out.add(
          en
              ? (missing.length == 1
                    ? 'One cycle of $list days was left out: it is much longer '
                          'than your other cycles, so a period was probably not '
                          'recorded in between.'
                    : '${missing.length} cycles of $list days were left out: '
                          'they are much longer than your other cycles, so periods '
                          'were probably not recorded in between.')
              : (missing.length == 1
                    ? 'Ein Zyklus von $list Tagen blieb unberücksichtigt: Er ist '
                          'deutlich länger als deine übrigen Zyklen, vermutlich '
                          'fehlt dazwischen ein Eintrag.'
                    : '${missing.length} Zyklen von $list Tagen blieben '
                          'unberücksichtigt: Sie sind deutlich länger als deine '
                          'übrigen Zyklen, vermutlich fehlen dazwischen Einträge.'),
        );
      }
      if (short.isNotEmpty) {
        final list = _joinList([for (final c in short) '${c.lengthDays}'], en);
        out.add(
          en
              ? (short.length == 1
                    ? 'One cycle of $list days was left out because it is much '
                          'shorter than your other cycles.'
                    : '${short.length} cycles of $list days were left out because '
                          'they are much shorter than your other cycles.')
              : (short.length == 1
                    ? 'Ein Zyklus von $list Tagen blieb unberücksichtigt, weil er '
                          'deutlich kürzer ist als deine übrigen Zyklen.'
                    : '${short.length} Zyklen von $list Tagen blieben '
                          'unberücksichtigt, weil sie deutlich kürzer sind als '
                          'deine übrigen Zyklen.'),
        );
      }
    }
    if (statedLengthUsed && used.isNotEmpty) {
      out.add(
        en
            ? 'Because fewer than three cycles of your own are recorded, the '
                  'usual length you stated (${days(statedTypicalLengthDays!)}) is '
                  'included as well.'
            : 'Weil weniger als drei eigene Zyklen vorliegen, fließt zusätzlich '
                  'die von dir angegebene übliche Länge von '
                  '${daysDat(statedTypicalLengthDays!)} ein.',
      );
    }

    // 2. Typical length.
    if (used.length >= 2) {
      out.add(
        en
            ? 'This gives a typical cycle length of ${days(typicalLengthDays!)}. '
                  'Recent cycles count more than older ones.'
            : 'Daraus ergibt sich eine typische Zykluslänge von '
                  '${daysDat(typicalLengthDays!)}. Jüngere Zyklen zählen dabei '
                  'stärker als ältere.',
      );
    }

    // 3. Window and expected date.
    final n = next;
    if (n != null) {
      final spread = used.length >= 2
          ? (en
                ? 'Your cycles varied between $shortestDays and $longestDays '
                      'days.'
                : 'Deine Zyklen schwankten zwischen $shortestDays und '
                      '$longestDays Tagen.')
          : (en
                ? 'How much your cycles vary cannot be read from your records '
                      'yet, so the time window is deliberately wide.'
                : 'Wie stark deine Zyklen schwanken, lässt sich aus deinen '
                      'Einträgen noch nicht ablesen. Das Zeitfenster ist deshalb '
                      'bewusst weit gefasst.');
      out.add(
        en
            ? '$spread The next period is therefore expected in a window of '
                  '${days(variationDays!)} either side: from '
                  '${d(n.earliestStart)} to ${d(n.latestStart)}. The most likely '
                  'first day is ${d(n.expectedStart)}, which is '
                  '${days(typicalLengthDays!)} after the start of your last '
                  'period on ${d(lastPeriod!.start)}.'
            : '$spread Die nächste Periode wird deshalb in einem Zeitfenster von '
                  '${daysDat(variationDays!)} davor und danach erwartet: vom '
                  '${d(n.earliestStart)} bis zum ${d(n.latestStart)}. Am '
                  'wahrscheinlichsten beginnt sie am ${d(n.expectedStart)}, das '
                  'sind ${days(typicalLengthDays!)} nach dem Beginn deiner '
                  'letzten Periode am ${d(lastPeriod!.start)}.',
      );
      out.add(
        periodLengthFromHistory
            ? (en
                  ? 'Your recent periods usually lasted '
                        '${days(typicalPeriodLengthDays)}, so the expected last day '
                        'is ${d(n.expectedEnd)}.'
                  : 'Deine letzten Perioden dauerten meist '
                        '${days(typicalPeriodLengthDays)}. Daraus ergibt sich als '
                        'voraussichtlich letzter Tag der ${d(n.expectedEnd)}.')
            : (en
                  ? 'No completed period is recorded yet, so a length of '
                        '${days(defaultPeriodLength)} is assumed for the expected '
                        'end (${d(n.expectedEnd)}).'
                  : 'Es ist noch keine abgeschlossene Periode erfasst. Für das '
                        'voraussichtliche Ende (${d(n.expectedEnd)}) wird deshalb '
                        'eine Dauer von ${daysDat(defaultPeriodLength)} angenommen.'),
      );
    }

    // 4. Current situation.
    if (status == ForecastStatus.late) {
      out.add(
        en
            ? 'The time window ended ${days(daysLate)} ago and no new period '
                  'has been recorded. Cycles can shift. Enter the first day when '
                  'your period starts; later dates are then calculated anew.'
            : 'Das Zeitfenster ist seit ${daysDat(daysLate)} vorbei, ohne dass '
                  'eine neue Periode eingetragen wurde. Zyklen können sich '
                  'verschieben. Trage den ersten Tag ein, sobald deine Periode '
                  'beginnt; spätere Termine werden danach neu berechnet.',
      );
    } else if (status == ForecastStatus.stale) {
      out.add(
        en
            ? 'Your last recorded period started ${days(cycleDay! - 1)} ago. '
                  'That is far longer than your usual cycle, so entries are '
                  'probably missing. An estimate is possible again once a current '
                  'period is recorded.'
            : 'Deine letzte erfasste Periode begann vor ${daysDat(cycleDay! - 1)}. '
                  'Das ist weit länger als dein üblicher Zyklus, vermutlich '
                  'fehlen Einträge. Eine Einschätzung ist wieder möglich, sobald '
                  'eine aktuelle Periode erfasst ist.',
      );
    }

    // 5. Confidence.
    final c = confidence;
    if (c != null && n != null) {
      final String reason;
      if (used.isEmpty) {
        reason = en
            ? 'it rests on your stated cycle length only'
            : 'sie beruht nur auf der angegebenen Zykluslänge';
      } else if (c == Confidence.high) {
        reason = en
            ? '${used.length} cycles are available and they differ little'
            : 'es liegen ${used.length} Zyklen vor, die wenig voneinander '
                  'abweichen';
      } else if (used.length < 3) {
        reason = en
            ? (used.length == 1
                  ? 'only one cycle is available so far'
                  : 'only ${used.length} cycles are available so far')
            : (used.length == 1
                  ? 'bisher liegt erst ein Zyklus vor'
                  : 'bisher liegen erst ${used.length} Zyklen vor');
      } else if (c == Confidence.medium) {
        reason = en
            ? (used.length < 6
                  ? '${used.length} cycles are available; with six or more the '
                        'estimate becomes firmer'
                  : 'your cycles differ noticeably from each other')
            : (used.length < 6
                  ? 'es liegen ${used.length} Zyklen vor; ab sechs Zyklen wird '
                        'die Einschätzung belastbarer'
                  : 'deine Zyklen weichen merklich voneinander ab');
      } else {
        reason = en
            ? 'your cycles differ strongly from each other'
            : 'deine Zyklen weichen stark voneinander ab';
      }
      final label = en
          ? {
              Confidence.low: 'low',
              Confidence.medium: 'medium',
              Confidence.high: 'high',
            }[c]!
          : {
              Confidence.low: 'gering',
              Confidence.medium: 'mittel',
              Confidence.high: 'hoch',
            }[c]!;
      out.add(
        en
            ? 'Reliability of this estimate: $label, because $reason.'
            : 'Verlässlichkeit dieser Einschätzung: $label, denn $reason.',
      );
    }

    // 6. Backtest.
    final b = backtest;
    if (b != null && b.evaluated >= 2) {
      final err = (b.meanAbsoluteErrorDays * 10).round() / 10;
      final errText = en
          ? err.toStringAsFixed(1)
          : err.toStringAsFixed(1).replaceAll('.', ',');
      out.add(
        en
            ? 'Looking back: applied to your last ${b.evaluated} cycles, the '
                  'same calculation would have placed the start inside its window '
                  '${b.withinWindow} times. On average the most likely day was '
                  'off by $errText days.'
            : 'Rückblick: Auf deine letzten ${b.evaluated} Zyklen angewendet, '
                  'hätte dieselbe Berechnung den Beginn ${b.withinWindow}-mal '
                  'innerhalb ihres Zeitfensters getroffen. Der wahrscheinlichste '
                  'Tag lag im Mittel $errText Tage daneben.',
      );
    }
    return out;
  }
}

double _median(List<int> values) {
  final s = List<int>.of(values)..sort();
  final m = s.length ~/ 2;
  return s.length.isOdd ? s[m].toDouble() : (s[m - 1] + s[m]) / 2;
}

String _joinList(List<String> items, bool en) {
  if (items.length <= 1) return items.join();
  final head = items.sublist(0, items.length - 1).join(', ');
  return en ? '$head and ${items.last}' : '$head und ${items.last}';
}

const List<String> _monthsDe = [
  'Januar', 'Februar', 'März', 'April', 'Mai', 'Juni', 'Juli', 'August',
  'September', 'Oktober', 'November', 'Dezember', //
];

const List<String> _monthsEn = [
  'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August',
  'September', 'October', 'November', 'December', //
];

/// `3. November 2026` (de) or `3 November 2026` (en).
String formatDayLong(Day day, String language) => language == 'en'
    ? '${day.day} ${_monthsEn[day.month - 1]} ${day.year}'
    : '${day.day}. ${_monthsDe[day.month - 1]} ${day.year}';
