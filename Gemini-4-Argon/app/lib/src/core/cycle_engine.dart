import 'dart:math' as math;
import 'models.dart';

class CycleForecastResult {
  final String referenceDate;
  final bool hasSufficientData;
  final bool hasPersonalCycleIntervals;
  final int recordedPeriodsCount;
  final int completedCyclesCount;
  final int skippedOutlierGapsCount;
  final String status;
  final int? currentCycleDay;
  final String? lastPeriodStart;
  final String? lastPeriodEnd;
  final double? averageCycleLengthDays;
  final double? weightedCycleLengthDays;
  final double? medianCycleLengthDays;
  final int? minCycleLengthDays;
  final int? maxCycleLengthDays;
  final double? cycleVariabilityDays;
  final double? averagePeriodDurationDays;
  final List<int> cycleLengthsHistoryDays;
  final int? predictedCycleLengthDays;
  final String? expectedStartDate;
  final String? expectedEndDate;
  final String? windowStartDate;
  final String? windowEndDate;
  final int? daysUntilExpectedStart;
  final String confidence;
  final String explanationDe;
  final String explanationEn;

  const CycleForecastResult({
    required this.referenceDate,
    required this.hasSufficientData,
    required this.hasPersonalCycleIntervals,
    required this.recordedPeriodsCount,
    required this.completedCyclesCount,
    required this.skippedOutlierGapsCount,
    required this.status,
    this.currentCycleDay,
    this.lastPeriodStart,
    this.lastPeriodEnd,
    this.averageCycleLengthDays,
    this.weightedCycleLengthDays,
    this.medianCycleLengthDays,
    this.minCycleLengthDays,
    this.maxCycleLengthDays,
    this.cycleVariabilityDays,
    this.averagePeriodDurationDays,
    required this.cycleLengthsHistoryDays,
    this.predictedCycleLengthDays,
    this.expectedStartDate,
    this.expectedEndDate,
    this.windowStartDate,
    this.windowEndDate,
    this.daysUntilExpectedStart,
    required this.confidence,
    required this.explanationDe,
    required this.explanationEn,
  });

  String explanation(String lang) =>
      lang == 'en' ? explanationEn : explanationDe;

  bool isPredictedPeriodDate(String date) {
    if (expectedStartDate == null || expectedEndDate == null) return false;
    return date.compareTo(expectedStartDate!) >= 0 &&
        date.compareTo(expectedEndDate!) <= 0;
  }

  bool isPredictedWindowDate(String date) {
    if (windowStartDate == null || windowEndDate == null) return false;
    return date.compareTo(windowStartDate!) >= 0 &&
        date.compareTo(windowEndDate!) <= 0;
  }

  Map<String, dynamic> toJson() => {
        'reference_date': referenceDate,
        'on': referenceDate,
        'has_sufficient_data': hasSufficientData,
        'has_personal_cycle_intervals': hasPersonalCycleIntervals,
        'recorded_periods_count': recordedPeriodsCount,
        'completed_cycles_count': completedCyclesCount,
        'skipped_outlier_gaps_count': skippedOutlierGapsCount,
        'status': status,
        'current_cycle_day': currentCycleDay,
        'last_period_start': lastPeriodStart,
        'last_period_end': lastPeriodEnd,
        'expected_start_date': expectedStartDate,
        'expected_end_date': expectedEndDate,
        'window_start_date': windowStartDate,
        'window_end_date': windowEndDate,
        'days_until_expected_start': daysUntilExpectedStart,
        'predicted_cycle_length_days': predictedCycleLengthDays,
        'confidence': confidence,
        'statistics': {
          'average_cycle_length_days': averageCycleLengthDays,
          'weighted_cycle_length_days': weightedCycleLengthDays,
          'median_cycle_length_days': medianCycleLengthDays,
          'min_cycle_length_days': minCycleLengthDays,
          'max_cycle_length_days': maxCycleLengthDays,
          'cycle_variability_days': cycleVariabilityDays,
          'average_period_duration_days': averagePeriodDurationDays,
          'cycle_lengths_history_days': cycleLengthsHistoryDays,
        },
        'prediction': {
          'expected_start_date': expectedStartDate,
          'expected_end_date': expectedEndDate,
          'window_start_date': windowStartDate,
          'window_end_date': windowEndDate,
          'days_until_expected_start': daysUntilExpectedStart,
          'predicted_cycle_length_days': predictedCycleLengthDays,
          'confidence': confidence,
        },
        'explanation_de': explanationDe,
        'explanation_en': explanationEn,
        'explanation': {
          'de': explanationDe,
          'en': explanationEn,
        },
        'disclaimer': {
          'de':
              'Persönliche Orientierung zur Planung auf Basis eigener Einträge. Keine medizinische Diagnose, keine Eisprungberechnung und nicht zur Verhütung geeignet.',
          'en':
              'Personal planning orientation based on your own entries. Not a medical diagnosis, not an ovulation calculator, and not suitable for contraception.',
        },
      };
}

class CycleForecastEngine {
  static DateTime _parseDateUtc(String ymd) {
    final clean = ymd.trim().substring(0, 10);
    return DateTime.parse('${clean}T00:00:00Z');
  }

  static String _formatDateUtc(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  static double _round1(double v) => (v * 10.0).roundToDouble() / 10.0;

  static CycleForecastResult evaluate({
    required List<PeriodEntry> periods,
    required String onDate,
  }) {
    final refDt = _parseDateUtc(onDate);
    final refYmd = _formatDateUtc(refDt);

    // Filter periods that started on or before referenceDate, sorted chronologically
    final relevant = periods
        .where((p) => p.startDate.compareTo(refYmd) <= 0)
        .toList()
      ..sort((a, b) => a.startDate.compareTo(b.startDate));

    // Deduplicate periods with identical startDate
    final deduped = <PeriodEntry>[];
    for (final p in relevant) {
      if (deduped.isEmpty || deduped.last.startDate != p.startDate) {
        deduped.add(p);
      } else if (p.durationDays > deduped.last.durationDays) {
        deduped[deduped.length - 1] = p;
      }
    }

    if (deduped.isEmpty) {
      return CycleForecastResult(
        referenceDate: refYmd,
        hasSufficientData: false,
        hasPersonalCycleIntervals: false,
        recordedPeriodsCount: 0,
        completedCyclesCount: 0,
        skippedOutlierGapsCount: 0,
        status: 'insufficient_data',
        cycleLengthsHistoryDays: const [],
        confidence: 'none',
        explanationDe:
            'Für den Betrachtungstag $refYmd liegen noch keine Periodeneinträge vor. Sobald mindestens eine Periode erfasst ist, zeigt MorphHealth den aktuellen Zyklustag; ab zwei erfassten Perioden wird deine persönliche Zykluslänge und Schwankungsbreite berechnet.',
        explanationEn:
            'No period entries are recorded on or before $refYmd yet. Once at least one period is logged, MorphHealth displays your current cycle day; with two or more periods, it calculates your personal cycle length and variability.',
      );
    }

    // Calculate durations
    final durations = <int>[];
    for (final p in deduped) {
      if (p.endDate != null && p.endDate!.trim().isNotEmpty) {
        durations.add(p.durationDays.clamp(1, 14));
      } else {
        durations.add(5);
      }
    }
    final avgDuration =
        durations.reduce((a, b) => a + b) / durations.length.toDouble();
    final predictedDurationDays = avgDuration.round().clamp(1, 10);

    // Calculate consecutive cycle intervals
    final validCycles = <int>[];
    int outlierGaps = 0;
    for (int i = 0; i < deduped.length - 1; i++) {
      final startA = _parseDateUtc(deduped[i].startDate);
      final startB = _parseDateUtc(deduped[i + 1].startDate);
      final diff = startB.difference(startA).inDays;
      if (diff >= 15 && diff <= 90) {
        validCycles.add(diff);
      } else if (diff > 90) {
        outlierGaps++;
      }
    }

    final lastPeriod = deduped.last;
    final lastStartDt = _parseDateUtc(lastPeriod.startDate);
    final currentCycleDay = refDt.difference(lastStartDt).inDays + 1;
    final isCurrentlyBleeding = deduped.any((p) => p.containsDate(refYmd));

    if (validCycles.isEmpty) {
      // Only 1 recorded period (or no valid interval between 15 and 90 days)
      const fallbackLength = 28;
      const windowRadius = 3;
      final expStartDt = lastStartDt.add(const Duration(days: fallbackLength));
      final expEndDt =
          expStartDt.add(Duration(days: predictedDurationDays - 1));
      final winStartDt =
          expStartDt.subtract(const Duration(days: windowRadius));
      final winEndDt = expStartDt.add(const Duration(days: windowRadius));
      final daysUntil = expStartDt.difference(refDt).inDays;

      final expStartStr = _formatDateUtc(expStartDt);
      final expEndStr = _formatDateUtc(expEndDt);
      final winStartStr = _formatDateUtc(winStartDt);
      final winEndStr = _formatDateUtc(winEndDt);

      final status = isCurrentlyBleeding
          ? 'active_period'
          : (refYmd.compareTo(winStartStr) >= 0 &&
                  refYmd.compareTo(winEndStr) <= 0
              ? 'upcoming_window'
              : 'in_cycle');

      return CycleForecastResult(
        referenceDate: refYmd,
        hasSufficientData: true,
        hasPersonalCycleIntervals: false,
        recordedPeriodsCount: deduped.length,
        completedCyclesCount: 0,
        skippedOutlierGapsCount: outlierGaps,
        status: status,
        currentCycleDay: currentCycleDay,
        lastPeriodStart: lastPeriod.startDate,
        lastPeriodEnd: lastPeriod.endDate,
        averagePeriodDurationDays: _round1(avgDuration),
        cycleLengthsHistoryDays: const [],
        predictedCycleLengthDays: fallbackLength,
        expectedStartDate: expStartStr,
        expectedEndDate: expEndStr,
        windowStartDate: winStartStr,
        windowEndDate: winEndStr,
        daysUntilExpectedStart: daysUntil,
        confidence: 'low',
        explanationDe:
            'Bisher ist eine Periode ab dem ${lastPeriod.startDate} erfasst (Zyklustag $currentCycleDay am $refYmd). Da für eine persönliche Zykluslängen-Auswertung mindestens zwei Periodenstarts benötigt werden, dient als erste Orientierung ein Referenzintervall von $fallbackLength Tagen (±$windowRadius Tage): voraussichtlicher Zeitraum $winStartStr bis $winEndStr (Schwerpunkt ab $expStartStr). Diese Einschätzung dient ausschließlich der persönlichen Planung.',
        explanationEn:
            'One period starting on ${lastPeriod.startDate} is recorded so far (cycle day $currentCycleDay on $refYmd). Because at least two period start dates are needed to compute your personal cycle interval, an initial $fallbackLength-day reference interval (±$windowRadius days) is used for orientation: expected window $winStartStr to $winEndStr (centered on $expStartStr). This estimate is for personal planning only.',
      );
    }

    // Use up to the last 8 valid cycles for statistical evaluation
    final recentCycles = validCycles.length > 8
        ? validCycles.sublist(validCycles.length - 8)
        : validCycles;
    final n = recentCycles.length;
    final sum = recentCycles.reduce((a, b) => a + b);
    final mean = sum / n.toDouble();

    // Linearly weighted average (more recent cycles carry higher weight: 1..n)
    double weightedSum = 0.0;
    double weightTotal = 0.0;
    for (int i = 0; i < n; i++) {
      final w = (i + 1).toDouble();
      weightedSum += recentCycles[i] * w;
      weightTotal += w;
    }
    final weightedMean = weightedSum / weightTotal;

    // Median, Min, Max
    final sorted = List<int>.from(recentCycles)..sort();
    final minLen = sorted.first;
    final maxLen = sorted.last;
    final double median = n.isOdd
        ? sorted[n ~/ 2].toDouble()
        : (sorted[(n ~/ 2) - 1] + sorted[n ~/ 2]) / 2.0;

    // Sample standard deviation
    double varianceSum = 0.0;
    for (final c in recentCycles) {
      final d = c - mean;
      varianceSum += d * d;
    }
    final double stdDev =
        n > 1 ? math.sqrt(varianceSum / (n - 1)) : 2.0;

    final predictedLen = weightedMean.round().clamp(18, 60);
    final windowRadius = n == 1
        ? 2
        : stdDev.ceil().clamp(1, 5);

    final expStartDt = lastStartDt.add(Duration(days: predictedLen));
    final expEndDt = expStartDt.add(Duration(days: predictedDurationDays - 1));
    final winStartDt = expStartDt.subtract(Duration(days: windowRadius));
    final winEndDt = expStartDt.add(Duration(days: windowRadius));
    final daysUntil = expStartDt.difference(refDt).inDays;

    final expStartStr = _formatDateUtc(expStartDt);
    final expEndStr = _formatDateUtc(expEndDt);
    final winStartStr = _formatDateUtc(winStartDt);
    final winEndStr = _formatDateUtc(winEndDt);

    final String confidence;
    if (n >= 3 && stdDev <= 2.5) {
      confidence = 'high';
    } else if (n >= 2 && stdDev <= 4.5) {
      confidence = 'medium';
    } else {
      confidence = 'low';
    }

    final String status;
    if (isCurrentlyBleeding) {
      status = 'active_period';
    } else if (refYmd.compareTo(winStartStr) >= 0 &&
        refYmd.compareTo(winEndStr) <= 0) {
      status = 'upcoming_window';
    } else if (refYmd.compareTo(winEndStr) > 0) {
      status = 'overdue_or_unlogged';
    } else {
      status = 'in_cycle';
    }

    final historyListStr = recentCycles.join(', ');
    final outlierNoteDe = outlierGaps > 0
        ? ' ($outlierGaps ungewöhnlich lange Erfassungslücke >90 Tage wurde als Ausreißer ignoriert.)'
        : '';
    final outlierNoteEn = outlierGaps > 0
        ? ' ($outlierGaps unusually long logging gap >90 days was excluded as an outlier.)'
        : '';

    final explanationDe =
        'Basierend auf ${deduped.length} erfassten Perioden und $n ausgewerteten Zyklusintervallen ($historyListStr Tage) beträgt deine gewichtete Zykluslänge ${_round1(weightedMean)} Tage (Durchschnitt ${_round1(mean)} Tage, Spannweite $minLen–$maxLen Tage, Streuung ±${_round1(stdDev)} Tage) bei einer typischen Blutungsdauer von ${_round1(avgDuration)} Tagen.$outlierNoteDe '
        'Ausgehend vom letzten Periodenbeginn am ${lastPeriod.startDate} (Zyklustag $currentCycleDay am $refYmd) wird die nächste Periode um den $expStartStr erwartet (Planungsfenster $winStartStr bis $winEndStr, ±$windowRadius Tage). '
        'Hinweis: Diese persönliche Einschätzung dient der eigenen Dokumentation und Alltagsplanung, nicht der medizinischen Diagnose, Eisprungberechnung oder Verhütung.';

    final explanationEn =
        'Based on ${deduped.length} recorded periods and $n evaluated cycle intervals ($historyListStr days), your weighted cycle length is ${_round1(weightedMean)} days (mean ${_round1(mean)} days, range $minLen–$maxLen days, variability ±${_round1(stdDev)} days) with a typical period duration of ${_round1(avgDuration)} days.$outlierNoteEn '
        'Starting from your last period on ${lastPeriod.startDate} (cycle day $currentCycleDay on $refYmd), the next period is estimated around $expStartStr (planning window $winStartStr to $winEndStr, ±$windowRadius days). '
        'Note: This personal assessment is for self-documentation and planning only, not for medical diagnosis, ovulation calculation, or contraception.';

    return CycleForecastResult(
      referenceDate: refYmd,
      hasSufficientData: true,
      hasPersonalCycleIntervals: true,
      recordedPeriodsCount: deduped.length,
      completedCyclesCount: n,
      skippedOutlierGapsCount: outlierGaps,
      status: status,
      currentCycleDay: currentCycleDay,
      lastPeriodStart: lastPeriod.startDate,
      lastPeriodEnd: lastPeriod.endDate,
      averageCycleLengthDays: _round1(mean),
      weightedCycleLengthDays: _round1(weightedMean),
      medianCycleLengthDays: _round1(median),
      minCycleLengthDays: minLen,
      maxCycleLengthDays: maxLen,
      cycleVariabilityDays: _round1(stdDev),
      averagePeriodDurationDays: _round1(avgDuration),
      cycleLengthsHistoryDays: recentCycles,
      predictedCycleLengthDays: predictedLen,
      expectedStartDate: expStartStr,
      expectedEndDate: expEndStr,
      windowStartDate: winStartStr,
      windowEndDate: winEndStr,
      daysUntilExpectedStart: daysUntil,
      confidence: confidence,
      explanationDe: explanationDe,
      explanationEn: explanationEn,
    );
  }
}
