import 'dart:math' as math;

import 'civil.dart';
import 'forecast_text.dart';
import 'models.dart';
import 'nutrients.dart' show roundTo;

/// Kürzester und längster Abstand zwischen zwei Periodenbeginnen, der als
/// Zyklus in die Einschätzung eingeht. Alles außerhalb gilt als fehlender oder
/// doppelter Eintrag.
const int kMinCycleDays = 15;
const int kMaxCycleDays = 60;

/// Es zählen die letzten sechs brauchbaren Zyklen.
const int kCycleWindow = 6;

enum ForecastStatus {
  /// Keine Periode bis zum Betrachtungstag erfasst.
  noData('no_data'),

  /// Zu wenig Daten für eine persönliche Einschätzung.
  insufficientData('insufficient_data'),

  /// Der Betrachtungstag liegt in einer erfassten Periode.
  inPeriod('in_period'),

  /// Der berechnete Beginn liegt heute oder in der Zukunft.
  predicted('predicted'),

  /// Der berechnete Beginn liegt in der Vergangenheit, eine neue Periode fehlt.
  overdue('overdue'),

  /// Der letzte erfasste Beginn liegt mehr als 60 Tage zurück.
  stale('stale'),

  /// Die Prognose ist ausgeschaltet (Tagebuchmodus).
  disabled('disabled');

  final String id;

  const ForecastStatus(this.id);
}

/// Der Abstand zwischen zwei aufeinanderfolgenden Periodenbeginnen.
final class CycleInterval {
  final Day start;
  final Day nextStart;
  final int days;
  final bool used;

  /// `too_short`, `too_long` oder `older_than_window`, wenn nicht verwendet.
  final String? excludedReason;

  const CycleInterval(this.start, this.nextStart, this.days, this.used, this.excludedReason);

  Map<String, Object?> toJson() => {
    'start': start.toString(),
    'next_start': nextStart.toString(),
    'days': days,
    'used': used,
    'excluded_reason': excludedReason,
  };
}

/// Ein voraussichtlicher Periodenbeginn mit Zeitfenster.
final class UpcomingPeriod {
  final Day predictedStart;
  final Day earliest;
  final Day latest;

  const UpcomingPeriod(this.predictedStart, this.earliest, this.latest);

  Map<String, Object?> toJson() => {
    'predicted_start': predictedStart.toString(),
    'earliest': earliest.toString(),
    'latest': latest.toString(),
  };
}

/// Die persönliche Zykluseinschätzung für einen Betrachtungstag.
final class Forecast {
  final Day on;
  final ForecastStatus status;

  /// `history` (aus den eigenen Abständen), `manual` (vom Nutzer festgelegte
  /// Zykluslänge) oder `none`.
  final String basis;

  /// `none`, `low`, `medium` oder `high`.
  final String confidence;

  final Day? lastPeriodStart;

  /// Tag des aktuellen Zyklus (1 = Beginn der letzten Periode).
  final int? cycleDay;

  /// Tag der laufenden Periode (1 = Beginn), sonst null.
  final int? periodDay;

  final Day? predictedStart;
  final Day? earliest;
  final Day? latest;

  /// Tage bis zum berechneten Beginn (0 = heute), nur bei `predicted`/`in_period`.
  final int? daysUntil;

  /// Tage seit dem berechneten Beginn, nur bei `overdue`.
  final int? daysOverdue;

  final int? predictedPeriodDays;
  final Day? predictedEnd;

  final double? averageCycleDays;
  final double? spreadDays;
  final int? predictedCycleDays;
  final List<int> usedLengths;
  final List<CycleInterval> intervals;
  final List<UpcomingPeriod> upcoming;

  const Forecast({
    required this.on,
    required this.status,
    this.basis = 'none',
    this.confidence = 'none',
    this.lastPeriodStart,
    this.cycleDay,
    this.periodDay,
    this.predictedStart,
    this.earliest,
    this.latest,
    this.daysUntil,
    this.daysOverdue,
    this.predictedPeriodDays,
    this.predictedEnd,
    this.averageCycleDays,
    this.spreadDays,
    this.predictedCycleDays,
    this.usedLengths = const [],
    this.intervals = const [],
    this.upcoming = const [],
  });

  /// Es gibt einen berechneten nächsten Beginn.
  bool get available => predictedStart != null;

  bool get inPeriod => status == ForecastStatus.inPeriod;

  /// Tage von [earliest] bis [latest] (Zeitfenster) als Menge.
  Set<Day> get windowDays {
    if (earliest == null || latest == null) return const {};
    return {for (var d = earliest!; !d.isAfter(latest!); d = d.addDays(1)) d};
  }

  /// Die voraussichtlichen Periodentage (Beginn bis Beginn + Dauer - 1).
  Set<Day> get predictedPeriodDaySet {
    if (predictedStart == null) return const {};
    final n = predictedPeriodDays ?? 1;
    return {for (var i = 0; i < n; i++) predictedStart!.addDays(i)};
  }

  Map<String, Object?> toJson() => {
    'on': on.toString(),
    'status': status.id,
    'available': available,
    'basis': basis,
    'confidence': confidence,
    'in_period': inPeriod,
    'period_day': periodDay,
    'cycle_day': cycleDay,
    'last_period_start': lastPeriodStart?.toString(),
    'predicted_start': predictedStart?.toString(),
    'window_earliest': earliest?.toString(),
    'window_latest': latest?.toString(),
    'days_until_predicted': daysUntil,
    'days_overdue': daysOverdue,
    'predicted_period_length_days': predictedPeriodDays,
    'predicted_end': predictedEnd?.toString(),
    'average_cycle_length_days': averageCycleDays == null ? null : roundTo(averageCycleDays!, 2),
    'cycle_length_std_days': spreadDays == null ? null : roundTo(spreadDays!, 2),
    'predicted_cycle_length_days': predictedCycleDays,
    'cycles_used': usedLengths.length,
    'cycle_lengths_used': usedLengths,
    'cycle_intervals': [for (final i in intervals) i.toJson()],
    'upcoming': [for (final u in upcoming) u.toJson()],
    'rules': {
      'plausible_cycle_days': [kMinCycleDays, kMaxCycleDays],
      'window_cycles': kCycleWindow,
      'spotting_only_records_ignored': true,
      'as_of': 'Es zählen nur Perioden mit Beginn bis einschließlich "on".',
    },
    'explanation': {'de': explainForecast(this, 'de'), 'en': explainForecast(this, 'en')},
  };
}

double _mean(List<int> v) => v.reduce((a, b) => a + b) / v.length;

double _sampleStd(List<int> v) {
  if (v.length < 2) return 0;
  final m = _mean(v);
  var s = 0.0;
  for (final x in v) {
    s += (x - m) * (x - m);
  }
  return math.sqrt(s / (v.length - 1));
}

/// Berechnet die persönliche Einschätzung für den Betrachtungstag [on] aus den
/// erfassten [periods]. Es zählen nur Perioden mit Beginn bis einschließlich
/// [on]; Einträge, die nur Spotting enthalten, zählen nicht als Periodenbeginn.
///
/// Verfahren: Abstände zwischen aufeinanderfolgenden Periodenbeginnen (15 bis
/// 60 Tage), Mittelwert der letzten sechs, nächster Beginn = letzter Beginn +
/// gerundeter Mittelwert. Das Zeitfenster folgt der Standardabweichung
/// (mindestens ±1 Tag, höchstens ±7 Tage).
Forecast computeForecast(List<PeriodRecord> periods, Day on, {bool enabled = true, int? manualCycleLength}) {
  if (!enabled) return Forecast(on: on, status: ForecastStatus.disabled);

  final byStart = <Day, PeriodRecord>{};
  for (final p in periods) {
    if (p.start.isAfter(on) || p.spottingOnly) continue;
    byStart.putIfAbsent(p.start, () => p);
  }
  final starts = byStart.keys.toList()..sort();
  if (starts.isEmpty) return Forecast(on: on, status: ForecastStatus.noData);

  final last = starts.last;
  final cycleDay = last.daysUntil(on) + 1;

  // Abstände und ihre Verwendbarkeit.
  final raw = <(Day, Day, int)>[];
  for (var i = 1; i < starts.length; i++) {
    raw.add((starts[i - 1], starts[i], starts[i - 1].daysUntil(starts[i])));
  }
  final plausible = <int>[
    for (var i = 0; i < raw.length; i++)
      if (raw[i].$3 >= kMinCycleDays && raw[i].$3 <= kMaxCycleDays) i,
  ];
  final usedIdx = (plausible.length > kCycleWindow ? plausible.sublist(plausible.length - kCycleWindow) : plausible)
      .toSet();
  final intervals = <CycleInterval>[
    for (var i = 0; i < raw.length; i++)
      CycleInterval(
        raw[i].$1,
        raw[i].$2,
        raw[i].$3,
        usedIdx.contains(i),
        usedIdx.contains(i)
            ? null
            : raw[i].$3 < kMinCycleDays
            ? 'too_short'
            : raw[i].$3 > kMaxCycleDays
            ? 'too_long'
            : 'older_than_window',
      ),
  ];
  final used = [for (final i in usedIdx.toList()..sort()) raw[i].$3];

  // Typische Periodendauer aus abgeschlossenen Perioden.
  final done = <int>[
    for (final s in starts)
      if (byStart[s]!.lengthDays != null) byStart[s]!.lengthDays!,
  ];
  final periodDays = done.isEmpty
      ? null
      : _mean(done.length > kCycleWindow ? done.sublist(done.length - kCycleWindow) : done).round();

  // Grundlage und Länge.
  String basis = 'none';
  int? length;
  double? avg;
  double? sd;
  int k = 0;
  String confidence = 'none';
  if (used.isNotEmpty) {
    basis = 'history';
    avg = _mean(used);
    length = avg.round();
    sd = used.length >= 2 ? _sampleStd(used) : null;
    final sdc = sd == null ? 0 : sd.ceil();
    if (used.length >= 3) {
      k = math.max(1, sdc).clamp(1, 7);
    } else if (used.length == 2) {
      k = math.max(2, sdc).clamp(2, 7);
    } else {
      k = 3;
    }
    if (used.length >= 4 && (sd ?? 99) <= 2) {
      confidence = 'high';
    } else if (used.length >= 3 && (sd ?? 99) <= 4) {
      confidence = 'medium';
    } else {
      confidence = 'low';
    }
  } else if (manualCycleLength != null) {
    basis = 'manual';
    length = manualCycleLength;
    k = 3;
    confidence = 'low';
  }

  // Laufende Periode?
  PeriodRecord? cover;
  for (final s in starts.reversed) {
    final p = byStart[s]!;
    if (p.coversDay(on, on)) {
      cover = p;
      break;
    }
  }

  final sinceLast = last.daysUntil(on);
  Day? predicted;
  Day? earliest;
  Day? latest;
  List<UpcomingPeriod> upcoming = const [];
  if (length != null) {
    predicted = last.addDays(length);
    earliest = predicted.addDays(-k);
    latest = predicted.addDays(k);
  }

  ForecastStatus status;
  if (cover != null) {
    status = ForecastStatus.inPeriod;
  } else if (length == null) {
    status = ForecastStatus.insufficientData;
  } else if (sinceLast > kMaxCycleDays) {
    status = ForecastStatus.stale;
    predicted = null;
    earliest = null;
    latest = null;
  } else {
    status = on.daysUntil(predicted!) >= 0 ? ForecastStatus.predicted : ForecastStatus.overdue;
  }

  if (predicted != null && length != null) {
    upcoming = [
      for (var i = 1; i <= 3; i++)
        () {
          final s = last.addDays(length! * i);
          final w = i == 1 ? k : math.min(10, (k * math.sqrt(i)).ceil());
          return UpcomingPeriod(s, s.addDays(-w), s.addDays(w));
        }(),
    ];
  }

  final until = predicted == null ? null : on.daysUntil(predicted);
  return Forecast(
    on: on,
    status: status,
    basis: basis,
    confidence: predicted == null ? 'none' : confidence,
    lastPeriodStart: last,
    cycleDay: cycleDay,
    periodDay: cover == null ? null : cover.start.daysUntil(on) + 1,
    predictedStart: predicted,
    earliest: earliest,
    latest: latest,
    daysUntil: status == ForecastStatus.overdue ? null : until,
    daysOverdue: status == ForecastStatus.overdue ? -until! : null,
    predictedPeriodDays: predicted == null ? null : periodDays,
    predictedEnd: predicted == null || periodDays == null ? null : predicted.addDays(periodDays - 1),
    averageCycleDays: avg,
    spreadDays: sd,
    predictedCycleDays: length,
    usedLengths: used,
    intervals: intervals,
    upcoming: upcoming,
  );
}
