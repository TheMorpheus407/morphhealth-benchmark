// Persönliche Zyklusauswertung: Prognose der nächsten Periode aus der
// eigenen Historie (keine medizinische Berechnung, siehe SPEC P04).
library;

import '../core/parse.dart';
import '../model/cycle.dart';
import '../model/document.dart';

/// Ergebnis der persönlichen Zykluseinschätzung.
class CycleForecast {
  /// Betrachtungsstichtag (YYYY-MM-DD).
  final String on;
  final int periodsRecorded;
  final int cyclesMeasured;
  final double? averageCycleDays;
  final int? cycleDaysMin;
  final int? cycleDaysMax;
  final double? averagePeriodDays;
  final int? periodDaysMin;
  final int? periodDaysMax;
  final String? lastPeriodStart;
  final int? currentCycleDay;
  final String? nextPeriodStartEstimate;
  final String? nextPeriodStartRangeStart;
  final String? nextPeriodStartRangeEnd;
  final String? nextPeriodEndEstimate;
  /// confidence: low | medium | high | null (keine Daten).
  final String? confidence;
  /// state: no_data | insufficient_data | before_next | within_predicted |
  ///        within_recorded | between_predicted
  final String state;

  const CycleForecast({
    required this.on,
    required this.periodsRecorded,
    required this.cyclesMeasured,
    this.averageCycleDays,
    this.cycleDaysMin,
    this.cycleDaysMax,
    this.averagePeriodDays,
    this.periodDaysMin,
    this.periodDaysMax,
    this.lastPeriodStart,
    this.currentCycleDay,
    this.nextPeriodStartEstimate,
    this.nextPeriodStartRangeStart,
    this.nextPeriodStartRangeEnd,
    this.nextPeriodEndEstimate,
    this.confidence,
    required this.state,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'on': on,
        'basis': <String, dynamic>{
          'periods_recorded': periodsRecorded,
          'cycles_measured': cyclesMeasured,
          if (averageCycleDays != null) 'average_cycle_days': averageCycleDays,
          if (cycleDaysMin != null) 'cycle_days_min': cycleDaysMin,
          if (cycleDaysMax != null) 'cycle_days_max': cycleDaysMax,
          if (averagePeriodDays != null) 'average_period_days': averagePeriodDays,
          if (periodDaysMin != null) 'period_days_min': periodDaysMin,
          if (periodDaysMax != null) 'period_days_max': periodDaysMax,
        },
        if (lastPeriodStart != null) 'last_period_start': lastPeriodStart,
        if (currentCycleDay != null) 'current_cycle_day': currentCycleDay,
        if (nextPeriodStartEstimate != null) 'next_period_start_estimate': nextPeriodStartEstimate,
        if (nextPeriodStartRangeStart != null || nextPeriodStartRangeEnd != null)
          'next_period_start_range': <String?>[nextPeriodStartRangeStart, nextPeriodStartRangeEnd],
        if (nextPeriodEndEstimate != null) 'next_period_end_estimate': nextPeriodEndEstimate,
        if (confidence != null) 'confidence': confidence,
        'state': state,
      };

  /// Verständliche Erklärung auf Deutsch.
  String explanationDe() => _explanation('de');

  /// Verständliche Erklärung auf Englisch.
  String explanationEn() => _explanation('en');

  String _explanation(String lang) {
    final bool de = lang == 'de';
    String t(String deText, String enText) => de ? deText : enText;
    final StringBuffer b = StringBuffer();
    if (periodsRecorded == 0) {
      b.write(t(
        'Es sind noch keine Perioden aufgezeichnet. Trage deine erste Periode ein, '
        'damit MorphHealth deinen Zyklus auswerten kann.',
        'No periods have been recorded yet. Log your first period so MorphHealth '
        'can evaluate your cycle.',
      ));
      return b.toString();
    }
    b.write(t(
      'Auswertung deiner persönlichen Aufzeichnungen: $periodsRecorded Periode(n) '
      'aufgezeichnet, $cyclesMeasured Zykluslänge(n) gemessen. ',
      'Evaluation of your personal records: $periodsRecorded period(s) recorded, '
      '$cyclesMeasured cycle length(s) measured. ',
    ));
    if (averageCycleDays != null) {
      final String avg = averageCycleDays!.toStringAsFixed(1);
      final String range = (cycleDaysMin != null && cycleDaysMax != null)
          ? t(' ($cycleDaysMin–$cycleDaysMax Tage)', ' ($cycleDaysMin–$cycleDaysMax days)')
          : '';
      b.write(t(
        'Deine durchschnittliche Zykluslänge beträgt $avg Tage$range. ',
        'Your average cycle length is $avg days$range. ',
      ));
    }
    if (averagePeriodDays != null) {
      final String avg = averagePeriodDays!.toStringAsFixed(1);
      final String range = (periodDaysMin != null && periodDaysMax != null)
          ? t(' ($periodDaysMin–$periodDaysMax Tage)', ' ($periodDaysMin–$periodDaysMax days)')
          : '';
      b.write(t(
        'Die durchschnittliche Blutungsdauer beträgt $avg Tage$range. ',
        'The average bleeding duration is $avg days$range. ',
      ));
    }
    if (nextPeriodStartEstimate != null) {
      final String conf = t(
        confidence == 'high'
            ? 'Hohe Übereinstimmung deiner bisherigen Zyklen.'
            : confidence == 'medium'
                ? 'Mittlere Übereinstimmung deiner bisherigen Zyklen.'
                : 'Wenige Messungen — die Einschätzung ist unsicher.',
        confidence == 'high'
            ? 'High consistency across your recorded cycles.'
            : confidence == 'medium'
                ? 'Moderate consistency across your recorded cycles.'
                : 'Few measurements — this estimate is uncertain.',
      );
      b.write(t('Die nächste Periode beginnt voraussichtlich am ', 'The next period is expected to start on '));
      b.write(_fmtDate(nextPeriodStartEstimate!, de));
      if (nextPeriodStartRangeStart != null && nextPeriodStartRangeEnd != null) {
        b.write(t(
          ' (unsicherer Bereich: ${_fmtDate(nextPeriodStartRangeStart!, de)} bis ${_fmtDate(nextPeriodStartRangeEnd!, de)}). ',
          ' (uncertain range: ${_fmtDate(nextPeriodStartRangeStart!, de)} to ${_fmtDate(nextPeriodStartRangeEnd!, de)}). ',
        ));
      } else {
        b.write('. ');
      }
      if (nextPeriodEndEstimate != null) {
        b.write(t(
          'Sie dauert voraussichtlich bis ${_fmtDate(nextPeriodEndEstimate!, de)}. ',
          'It is expected to last until ${_fmtDate(nextPeriodEndEstimate!, de)}. ',
        ));
      }
      b.write('$conf ');
    } else if (cyclesMeasured == 0) {
      b.write(t(
        'Für eine Prognose wird mindestens eine zweite Periode benötigt. ',
        'At least a second period is needed for a forecast. ',
      ));
    }
    if (currentCycleDay != null && lastPeriodStart != null) {
      b.write(t(
        'Heute ist Zyklustag $currentCycleDay (seit ${_fmtDate(lastPeriodStart!, de)}). ',
        'Today is cycle day $currentCycleDay (since ${_fmtDate(lastPeriodStart!, de)}). ',
      ));
    }
    b.write(t(
      'Dies ist eine persönliche Schätzung aus deinen eigenen Aufzeichnungen '
      'und keine medizinische Vorhersage oder Diagnose.',
      'This is a personal estimate based on your own records, not a medical '
      'prediction or diagnosis.',
    ));
    return b.toString().trim();
  }

  static String _fmtDate(String iso, bool de) {
    final DateTime? d = parseDate(iso);
    if (d == null) return iso;
    final String day = d.day.toString().padLeft(2, '0');
    final String month = d.month.toString().padLeft(2, '0');
    return de ? '$day.$month.${d.year}' : '${d.year}-$month-$day';
  }
}

/// Berechnet die persönliche Zykluseinschätzung für den Tag `on`.
CycleForecast computeCycleForecast(MorphDocument doc, String on) {
  final List<PeriodRecord> periods = doc.periods
      .where((PeriodRecord p) => parseDate(p.start) != null)
      .toList()
    ..sort((PeriodRecord a, PeriodRecord b) => a.start.compareTo(b.start));

  if (periods.isEmpty) {
    return CycleForecast(
      on: on,
      periodsRecorded: 0,
      cyclesMeasured: 0,
      state: 'no_data',
    );
  }

  final int n = periods.length;
  final List<int> intervals = <int>[];
  for (int i = 1; i < n; i++) {
    intervals.add(dateDiffDays(periods[i - 1].start, periods[i].start));
  }
  final List<int> durations = <int>[];
  for (final PeriodRecord p in periods) {
    if (p.end != null) {
      durations.add(dateDiffDays(p.start, p.end!) + 1);
    }
  }

  final String lastStart = periods.last.start;
  final DateTime? onDate = parseDate(on);
  final int? currentCycleDay = onDate == null
      ? null
      : (on.compareTo(lastStart) >= 0 ? dateDiffDays(lastStart, on) + 1 : null);

  double? avgCycle;
  int? cycleMin;
  int? cycleMax;
  if (intervals.isNotEmpty) {
    avgCycle = intervals.reduce((int a, int b) => a + b) / intervals.length;
    cycleMin = intervals.reduce((int a, int b) => a < b ? a : b);
    cycleMax = intervals.reduce((int a, int b) => a > b ? a : b);
    if (intervals.length == 1) {
      // Nur eine gemessene Zykluslänge: unsicheren Bereich um ±2 Tage angeben.
      cycleMin = cycleMin - 2;
      cycleMax = cycleMax + 2;
    }
  }

  double? avgPeriod;
  int? periodMin;
  int? periodMax;
  if (durations.isNotEmpty) {
    avgPeriod = durations.reduce((int a, int b) => a + b) / durations.length;
    periodMin = durations.reduce((int a, int b) => a < b ? a : b);
    periodMax = durations.reduce((int a, int b) => a > b ? a : b);
  }

  String? confidence;
  if (intervals.length >= 3 && (cycleMax! - cycleMin!) <= 4) {
    confidence = 'high';
  } else if (intervals.length >= 2) {
    confidence = 'medium';
  } else {
    confidence = 'low';
  }

  // Aufzeichnungsstatus am Betrachtungsstichtag.
  String state = 'insufficient_data';
  for (final PeriodRecord p in periods) {
    final String last = p.end ?? on;
    if (on.compareTo(p.start) >= 0 && on.compareTo(last) <= 0) {
      state = 'within_recorded';
      break;
    }
  }

  String? nextStart;
  String? rangeStart;
  String? rangeEnd;
  String? nextEnd;

  if (avgCycle != null && onDate != null) {
    // Basis so weit vorschieben, dass die Vorhersage den Stichtag erreicht.
    DateTime base = parseDate(lastStart)!;
    final int maxPeriod = periodMax ?? 5;
    while (base.add(Duration(days: avgCycle.round() + maxPeriod)).isBefore(onDate)) {
      base = base.add(Duration(days: avgCycle.round()));
    }
    final DateTime est = base.add(Duration(days: avgCycle.round()));
    nextStart = formatDate(est);
    rangeStart = formatDate(base.add(Duration(days: cycleMin!)));
    rangeEnd = formatDate(base.add(Duration(days: cycleMax!)));
    if (avgPeriod != null) {
      nextEnd = formatDate(est.add(Duration(days: avgPeriod.round() - 1)));
    }
    if (state != 'within_recorded') {
      if (on.compareTo(nextStart) < 0) {
        state = 'before_next';
      } else if (nextEnd != null && on.compareTo(nextEnd) <= 0) {
        state = 'within_predicted';
      } else {
        state = 'between_predicted';
      }
    }
  }

  return CycleForecast(
    on: on,
    periodsRecorded: n,
    cyclesMeasured: intervals.length,
    averageCycleDays: avgCycle,
    cycleDaysMin: cycleMin,
    cycleDaysMax: cycleMax,
    averagePeriodDays: avgPeriod,
    periodDaysMin: periodMin,
    periodDaysMax: periodMax,
    lastPeriodStart: lastStart,
    currentCycleDay: currentCycleDay,
    nextPeriodStartEstimate: nextStart,
    nextPeriodStartRangeStart: rangeStart,
    nextPeriodStartRangeEnd: rangeEnd,
    nextPeriodEndEstimate: nextEnd,
    confidence: avgCycle == null ? null : confidence,
    state: state,
  );
}
