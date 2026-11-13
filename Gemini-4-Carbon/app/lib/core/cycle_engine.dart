/// Personal menstrual cycle analysis and transparent forecast engine (P04).
///
/// Strictly personal planning based on the user's own recorded history.
/// No ovulation estimation, contraception claims, or medical diagnosis.
library;

import 'dart:math';

import 'clock.dart';
import 'models.dart';

class CycleStatistics {
  final int recordedPeriodsCount;
  final int standaloneSpottingCount;
  final int completedCyclesTotal;
  final int cyclesUsedCount;
  final int excludedOutliersCount;
  final List<int> cycleLengthsDays;
  final int? minCycleDays;
  final int? maxCycleDays;
  final double? meanCycleDays;
  final double? medianCycleDays;
  final double? stdDevDays;

  const CycleStatistics({
    required this.recordedPeriodsCount,
    required this.standaloneSpottingCount,
    required this.completedCyclesTotal,
    required this.cyclesUsedCount,
    required this.excludedOutliersCount,
    required this.cycleLengthsDays,
    this.minCycleDays,
    this.maxCycleDays,
    this.meanCycleDays,
    this.medianCycleDays,
    this.stdDevDays,
  });

  Map<String, dynamic> toJson() => {
        'recorded_periods_count': recordedPeriodsCount,
        'standalone_spotting_count': standaloneSpottingCount,
        'completed_cycles_total': completedCyclesTotal,
        'cycles_used_count': cyclesUsedCount,
        'excluded_outliers_count': excludedOutliersCount,
        'cycle_lengths_days': cycleLengthsDays,
        'min_cycle_days': minCycleDays,
        'max_cycle_days': maxCycleDays,
        'mean_cycle_days': meanCycleDays,
        'median_cycle_days': medianCycleDays,
        'std_dev_days': stdDevDays,
      };
}

class CycleForecastResult {
  final String onDate; // YYYY-MM-DD
  final String status; // 'no_history' | 'awaiting_second_period' | 'low_confidence' | 'personal_forecast'
  final String confidence; // 'none' | 'low' | 'medium' | 'high' | 'variable'
  final bool diaryOnlyMode;
  final bool isPeriodActiveOnDate;
  final String? activePeriodId;
  final FlowIntensity? activeFlowIntensity;
  final int? currentCycleDay;
  final String? lastPeriodStart;
  final String? lastPeriodEnd;
  final String? predictedNextStart;
  final String? predictedNextEnd;
  final String? predictedWindowStart;
  final String? predictedWindowEnd;
  final int? daysUntilExpectedStart;
  final int? expectedCycleLengthDays;
  final int? expectedPeriodDurationDays;
  final double? variabilityDays;
  final CycleStatistics statistics;
  final String explanationDe;
  final String explanationEn;

  const CycleForecastResult({
    required this.onDate,
    required this.status,
    required this.confidence,
    required this.diaryOnlyMode,
    required this.isPeriodActiveOnDate,
    this.activePeriodId,
    this.activeFlowIntensity,
    this.currentCycleDay,
    this.lastPeriodStart,
    this.lastPeriodEnd,
    this.predictedNextStart,
    this.predictedNextEnd,
    this.predictedWindowStart,
    this.predictedWindowEnd,
    this.daysUntilExpectedStart,
    this.expectedCycleLengthDays,
    this.expectedPeriodDurationDays,
    this.variabilityDays,
    required this.statistics,
    required this.explanationDe,
    required this.explanationEn,
  });

  String explanation(String locale) =>
      locale == 'en' ? explanationEn : explanationDe;

  bool isDateInPredictedWindow(String dateIso) {
    if (diaryOnlyMode ||
        predictedWindowStart == null ||
        predictedWindowEnd == null) {
      return false;
    }
    return IsoDate.daysBetween(predictedWindowStart!, dateIso) >= 0 &&
        IsoDate.daysBetween(dateIso, predictedWindowEnd!) >= 0;
  }

  bool isDateInPredictedPeriod(String dateIso) {
    if (diaryOnlyMode || predictedNextStart == null || predictedNextEnd == null) {
      return false;
    }
    return IsoDate.daysBetween(predictedNextStart!, dateIso) >= 0 &&
        IsoDate.daysBetween(dateIso, predictedNextEnd!) >= 0;
  }

  Map<String, dynamic> toJson() => {
        'on': onDate,
        'status': status,
        'confidence': confidence,
        'diary_only_mode': diaryOnlyMode,
        'is_period_active_on_date': isPeriodActiveOnDate,
        'active_period_id': activePeriodId,
        'active_flow_intensity': activeFlowIntensity?.jsonKey,
        'current_cycle_day': currentCycleDay,
        'last_period_start': lastPeriodStart,
        'last_period_end': lastPeriodEnd,
        'predicted_next_start': diaryOnlyMode ? null : predictedNextStart,
        'predicted_next_end': diaryOnlyMode ? null : predictedNextEnd,
        'predicted_window_start': diaryOnlyMode ? null : predictedWindowStart,
        'predicted_window_end': diaryOnlyMode ? null : predictedWindowEnd,
        'days_until_expected_start':
            diaryOnlyMode ? null : daysUntilExpectedStart,
        'expected_cycle_length_days':
            diaryOnlyMode ? null : expectedCycleLengthDays,
        'expected_period_duration_days': expectedPeriodDurationDays,
        'variability_days': variabilityDays,
        'statistics': statistics.toJson(),
        'explanation': {
          'de': explanationDe,
          'en': explanationEn,
        },
      };
}

class CycleForecastEngine {
  static const int minPlausibleCycleDays = 15;
  static const int maxPlausibleCycleDays = 90;
  static const int maxRecentCyclesUsed = 12;

  static CycleForecastResult evaluate({
    required List<PeriodEntry> allPeriods,
    required String onDate,
    bool diaryOnlyMode = false,
  }) {
    if (!IsoDate.isValid(onDate)) {
      throw FormatValidationException(
        'Invalid reference date "$onDate". Expected YYYY-MM-DD.',
      );
    }

    // Filter to entries starting on or before `onDate` so evaluation is causal.
    final upToOn = allPeriods
        .where((p) => IsoDate.daysBetween(p.startDate, onDate) >= 0)
        .toList();

    final standaloneSpottingCount =
        upToOn.where((p) => !p.countsAsPeriod).length;

    final cyclePeriods = upToOn.where((p) => p.countsAsPeriod).toList()
      ..sort((a, b) => a.startDate.compareTo(b.startDate));

    // Deduplicate identical start dates if any exist
    final deduped = <PeriodEntry>[];
    for (final p in cyclePeriods) {
      if (deduped.isEmpty || deduped.last.startDate != p.startDate) {
        deduped.add(p);
      } else {
        deduped[deduped.length - 1] = p;
      }
    }

    // Check active bleeding on `onDate` across all entries (periods + spotting)
    PeriodEntry? activeEntry;
    for (final p in upToOn.reversed) {
      if (p.coversDate(onDate, referenceTodayIso: onDate)) {
        activeEntry = p;
        break;
      }
    }

    // Typical bleeding duration from completed periods in [1..15] days
    final durations = deduped
        .map((p) => p.completedDurationDays)
        .whereType<int>()
        .where((d) => d >= 1 && d <= 15)
        .toList();
    final typicalDuration = durations.isEmpty
        ? (deduped.isEmpty ? null : 5)
        : _recencyBlendedEstimate(durations).round().clamp(1, 15);

    if (deduped.isEmpty) {
      const stats = CycleStatistics(
        recordedPeriodsCount: 0,
        standaloneSpottingCount: 0,
        completedCyclesTotal: 0,
        cyclesUsedCount: 0,
        excludedOutliersCount: 0,
        cycleLengthsDays: [],
      );
      return CycleForecastResult(
        onDate: onDate,
        status: 'no_history',
        confidence: 'none',
        diaryOnlyMode: diaryOnlyMode,
        isPeriodActiveOnDate: activeEntry != null,
        activePeriodId: activeEntry?.id,
        activeFlowIntensity: activeEntry?.intensityForDate(onDate),
        expectedPeriodDurationDays: null,
        statistics: CycleStatistics(
          recordedPeriodsCount: 0,
          standaloneSpottingCount: standaloneSpottingCount,
          completedCyclesTotal: 0,
          cyclesUsedCount: 0,
          excludedOutliersCount: 0,
          cycleLengthsDays: stats.cycleLengthsDays,
        ),
        explanationDe: diaryOnlyMode
            ? 'Der Tagebuch-Modus ist aktiv. Sobald du Perioden einträgst, werden sie im Kalender und in der Historie dokumentiert.'
            : 'Es sind noch keine Perioden erfasst. Ab zwei eingetragenen Periodenbeginnen wertet MorphHealth deine persönliche Zykluslänge für die Planung aus.',
        explanationEn: diaryOnlyMode
            ? 'Diary-only mode is active. Recorded periods will appear in your calendar and history.'
            : 'No periods recorded yet. Once at least two period start dates are logged, MorphHealth evaluates your personal cycle length for planning.',
      );
    }

    final lastPeriod = deduped.last;
    final currentCycleDay = IsoDate.daysBetween(lastPeriod.startDate, onDate) + 1;

    if (deduped.length == 1) {
      return CycleForecastResult(
        onDate: onDate,
        status: 'awaiting_second_period',
        confidence: 'none',
        diaryOnlyMode: diaryOnlyMode,
        isPeriodActiveOnDate: activeEntry != null,
        activePeriodId: activeEntry?.id,
        activeFlowIntensity: activeEntry?.intensityForDate(onDate),
        currentCycleDay: currentCycleDay,
        lastPeriodStart: lastPeriod.startDate,
        lastPeriodEnd: lastPeriod.endDate,
        expectedPeriodDurationDays: typicalDuration,
        statistics: CycleStatistics(
          recordedPeriodsCount: 1,
          standaloneSpottingCount: standaloneSpottingCount,
          completedCyclesTotal: 0,
          cyclesUsedCount: 0,
          excludedOutliersCount: 0,
          cycleLengthsDays: const [],
        ),
        explanationDe: diaryOnlyMode
            ? 'Tagebuch-Modus aktiv: 1 Periode ab ${lastPeriod.startDate} dokumentiert (Zyklustag $currentCycleDay).'
            : 'Bisher ist 1 Periode ab ${lastPeriod.startDate} erfasst (aktuell Tag $currentCycleDay). MorphHealth verzichtet bewusst auf pauschale 28-Tage-Schätzungen. Mit dem nächsten eingetragenen Periodenbeginn startet die Auswertung deiner persönlichen Zyklusdauer.',
        explanationEn: diaryOnlyMode
            ? 'Diary-only mode active: 1 period logged starting ${lastPeriod.startDate} (cycle day $currentCycleDay).'
            : '1 period starting ${lastPeriod.startDate} is recorded so far (currently day $currentCycleDay). MorphHealth avoids generic population guesses and computes a personal forecast as soon as a second period start is logged.',
      );
    }

    // Compute consecutive cycle intervals
    final rawIntervals = <int>[];
    for (var i = 0; i < deduped.length - 1; i++) {
      final len = IsoDate.daysBetween(
        deduped[i].startDate,
        deduped[i + 1].startDate,
      );
      if (len > 0) {
        rawIntervals.add(len);
      }
    }

    final plausible = rawIntervals
        .where((c) => c >= minPlausibleCycleDays && c <= maxPlausibleCycleDays)
        .toList();
    final excludedCount = rawIntervals.length - plausible.length;

    // Fallback: if all intervals were >90 or <15 (extreme irregularity), still use rawIntervals rather than crashing
    final usableAll = plausible.isNotEmpty ? plausible : rawIntervals;
    final recentCycles = usableAll.length > maxRecentCyclesUsed
        ? usableAll.sublist(usableAll.length - maxRecentCyclesUsed)
        : usableAll;

    final minC = recentCycles.reduce(min);
    final maxC = recentCycles.reduce(max);
    final meanC =
        recentCycles.reduce((a, b) => a + b) / recentCycles.length.toDouble();
    final medC = _median(recentCycles);
    final stdDev = _sampleStdDev(recentCycles, meanC);
    final blendedCenter = _recencyBlendedEstimate(recentCycles);
    final expectedLen = blendedCenter.round().clamp(14, 120);

    final windowRadius = recentCycles.length == 1
        ? 3
        : max(1.5, stdDev).round().clamp(2, 7);

    final predictedStart = IsoDate.addDays(lastPeriod.startDate, expectedLen);
    final dur = typicalDuration ?? 5;
    final predictedEnd = IsoDate.addDays(predictedStart, dur - 1);
    final windowStart = IsoDate.addDays(predictedStart, -windowRadius);
    final windowEnd = IsoDate.addDays(predictedStart, windowRadius);
    final daysUntil = IsoDate.daysBetween(onDate, predictedStart);

    final isSingleCycle = recentCycles.length == 1;
    final status = isSingleCycle ? 'low_confidence' : 'personal_forecast';
    String confidence;
    if (isSingleCycle) {
      confidence = 'low';
    } else if (stdDev > 4.5) {
      confidence = 'variable';
    } else if (recentCycles.length >= 4 && stdDev <= 2.5) {
      confidence = 'high';
    } else {
      confidence = 'medium';
    }

    final stats = CycleStatistics(
      recordedPeriodsCount: deduped.length,
      standaloneSpottingCount: standaloneSpottingCount,
      completedCyclesTotal: rawIntervals.length,
      cyclesUsedCount: recentCycles.length,
      excludedOutliersCount: excludedCount,
      cycleLengthsDays: recentCycles,
      minCycleDays: minC,
      maxCycleDays: maxC,
      meanCycleDays: _round2(meanC),
      medianCycleDays: _round2(medC),
      stdDevDays: _round2(stdDev),
    );

    final outlierNoteDe = excludedCount > 0
        ? ' $excludedCount ungewöhnlich langes oder kurzes Intervall außerhalb von 15–90 Tagen blieb als wahrscheinliche Erfassungslücke unberücksichtigt.'
        : '';
    final outlierNoteEn = excludedCount > 0
        ? ' $excludedCount interval(s) outside 15–90 days were excluded as likely logging gaps.'
        : '';

    final String explDe;
    final String explEn;
    if (diaryOnlyMode) {
      explDe =
          'Der Tagebuch-Modus ist aktiviert: Vorhersagen sind ausgeblendet. Deine Historie umfasst ${deduped.length} erfasste Perioden (Spanne $minC–$maxC Tage, Mittelwert ${_round1(meanC)} Tage).';
      explEn =
          'Diary-only mode is enabled: predictions are hidden. Your history includes ${deduped.length} recorded periods (range $minC–$maxC days, average ${_round1(meanC)} days).';
    } else if (isSingleCycle) {
      explDe =
          'Grundlage ist dein erster abgeschlossener Zyklus von $expectedLen Tagen. Daraus ergibt sich ein voraussichtlicher Beginn um den $predictedStart (Planungsfenster $windowStart bis $windowEnd, ±$windowRadius Tage). Mit weiteren Einträgen passt sich die Auswertung deiner persönlichen Schwankungsbreite an.$outlierNoteDe Diese Einschätzung dient ausschließlich deiner persönlichen Alltagsplanung ohne medizinische Aussage, Eisprungberechnung oder Verhütungszweck.';
      explEn =
          'Based on your first completed cycle of $expectedLen days, the next period is estimated around $predictedStart (planning window $windowStart to $windowEnd, ±$windowRadius days). Additional entries will refine variability.$outlierNoteEn This estimate is strictly for personal planning and excludes medical diagnosis, ovulation calculation, or contraception.';
    } else {
      explDe =
          'Ausgewertet wurden deine letzten ${recentCycles.length} Zyklen ($minC–$maxC Tage, gewichteter Richtwert $expectedLen Tage, Streuung ±${_round1(stdDev)} Tage, typische Blutungsdauer $dur Tage). Nächster erwarteter Beginn um den $predictedStart im persönlichen Planungsfenster $windowStart bis $windowEnd (±$windowRadius Tage).$outlierNoteDe Diese Auswertung dient deiner persönlichen Dokumentation und Planung ohne medizinische Diagnose, Eisprungberechnung oder Verhütungszweck.';
      explEn =
          'Computed from your last ${recentCycles.length} cycles ($minC–$maxC days, recency-weighted estimate $expectedLen days, variability ±${_round1(stdDev)} days, typical duration $dur days). Next expected start around $predictedStart within planning window $windowStart to $windowEnd (±$windowRadius days).$outlierNoteEn Strictly for personal documentation and planning, with no medical diagnosis, ovulation tracking, or contraceptive use.';
    }

    return CycleForecastResult(
      onDate: onDate,
      status: status,
      confidence: confidence,
      diaryOnlyMode: diaryOnlyMode,
      isPeriodActiveOnDate: activeEntry != null,
      activePeriodId: activeEntry?.id,
      activeFlowIntensity: activeEntry?.intensityForDate(onDate),
      currentCycleDay: currentCycleDay,
      lastPeriodStart: lastPeriod.startDate,
      lastPeriodEnd: lastPeriod.endDate,
      predictedNextStart: predictedStart,
      predictedNextEnd: predictedEnd,
      predictedWindowStart: windowStart,
      predictedWindowEnd: windowEnd,
      daysUntilExpectedStart: daysUntil,
      expectedCycleLengthDays: expectedLen,
      expectedPeriodDurationDays: dur,
      variabilityDays: _round2(stdDev),
      statistics: stats,
      explanationDe: explDe,
      explanationEn: explEn,
    );
  }

  static double _recencyBlendedEstimate(List<int> values) {
    if (values.length == 1) return values.first.toDouble();
    var weightedSum = 0.0;
    var totalWeight = 0.0;
    for (var i = 0; i < values.length; i++) {
      final w = (i + 1).toDouble();
      weightedSum += values[i] * w;
      totalWeight += w;
    }
    final weightedMean = weightedSum / totalWeight;
    final med = _median(values);
    return 0.5 * weightedMean + 0.5 * med;
  }

  static double _median(List<int> values) {
    final sorted = List<int>.from(values)..sort();
    final mid = sorted.length ~/ 2;
    if (sorted.length.isOdd) {
      return sorted[mid].toDouble();
    }
    return (sorted[mid - 1] + sorted[mid]) / 2.0;
  }

  static double _sampleStdDev(List<int> values, double mean) {
    if (values.length < 2) return 0.0;
    var sumSq = 0.0;
    for (final v in values) {
      final diff = v - mean;
      sumSq += diff * diff;
    }
    return sqrt(sumSq / (values.length - 1));
  }

  static double _round2(double v) => (v * 100).roundToDouble() / 100.0;
  static String _round1(double v) => v.toStringAsFixed(1);
}
