import 'dart:math';
import 'model.dart';

double _median(List<num> values) {
  final sorted = values.map((v) => v.toDouble()).toList()..sort();
  final middle = sorted.length ~/ 2;
  return sorted.length.isOdd
      ? sorted[middle]
      : (sorted[middle - 1] + sorted[middle]) / 2;
}

/// Personal planning estimate, not an ovulation/fertility/diagnostic model.
/// No population/default cycle length is used. Only observations available by
/// the requested day are read, and an overdue estimate is never silently rolled
/// into a fictional new cycle.
Json cycleForecast(Json document, String on) {
  final day = parseDay(on);
  final enabled = (document['settings'] as Map)['cyclePredictions'] != false;
  final starts = <DateTime>[];
  var spottingCount = 0;
  for (final raw in document['periods'] as List) {
    final p = raw as Map;
    final start = parseDay(p['start'] as String);
    if (start.isAfter(day)) continue;
    if (p['flow'] == 'spotting') {
      spottingCount++;
    } else if (!starts.contains(start)) {
      starts.add(start);
    }
  }
  starts.sort();
  final lastStart = starts.isEmpty ? null : starts.last;
  final recent = starts.length > 13
      ? starts.sublist(starts.length - 13)
      : starts;
  final rawIntervals = <int>[
    for (var i = 1; i < recent.length; i++)
      recent[i].difference(recent[i - 1]).inDays,
  ];
  // Broad plausibility boundary only detects probable fragments or missing
  // records. Report every exclusion; neither boundary supplies a prediction.
  final plausible = rawIntervals.where((n) => n >= 10 && n <= 120).toList();
  var usable = List<int>.of(plausible);
  var outliers = 0;
  if (plausible.length >= 4) {
    final median = _median(plausible);
    final mad = _median(plausible.map((n) => (n - median).abs()).toList());
    final threshold = max(7.0, 3 * mad);
    final retained = plausible
        .where((n) => (n - median).abs() <= threshold)
        .toList();
    if (retained.length >= 3) {
      usable = retained;
      outliers = plausible.length - retained.length;
    }
  }
  final base = <String, dynamic>{
    'status': enabled ? 'insufficient' : 'disabled',
    'on': on,
    'intervals': usable,
    'observedIntervals': rawIntervals,
    'sampleSize': usable.length,
    'periodCount': starts.length,
    'excludedIntervals': rawIntervals.length - usable.length,
    'spottingExcluded': spottingCount,
    'cycleLength': null,
    'predictedStart': null,
    'earliest': null,
    'latest': null,
    'lastStart': lastStart == null ? null : dateKey(lastStart),
    'daysSinceLastStart': lastStart == null
        ? null
        : day.difference(lastStart).inDays,
    'overdueDays': 0,
    'confidence': 'insufficient',
    'method': 'recent-median-mad-v1',
  };
  if (!enabled) {
    return {
      ...base,
      'explanation': {
        'de':
            'Tagebuchmodus: Persönliche Einschätzungen sind ausgeschaltet. Deine Aufzeichnungen bleiben erhalten.',
        'en':
            'Diary mode: personal estimates are turned off. Your records are retained.',
      },
    };
  }
  if (usable.length < 2 || lastStart == null) {
    return {
      ...base,
      'explanation': {
        'de':
            'Für eine persönliche Einschätzung werden mindestens drei Periodenbeginne mit zwei auswertbaren Abständen benötigt. Spotting zählt nicht als Periodenbeginn. Es wird kein Standardzyklus angenommen.',
        'en':
            'A personal estimate needs at least three period starts and two usable intervals. Spotting is not counted as a period start. No default cycle length is assumed.',
      },
    };
  }
  final length = _median(usable);
  final mad = _median(usable.map((n) => (n - length).abs()).toList());
  final minimum = usable.reduce(min);
  final maximum = usable.reduce(max);
  // An observed range with a small uncertainty margin is more honest than a
  // narrow statistical confidence interval for sparse self-reported records.
  final margin = usable.length < 4 ? 3 : 2;
  final spread = max(margin.toDouble(), (1.4826 * mad).ceilToDouble());
  final earliestDays = max(1, min(minimum - margin, (length - spread).floor()));
  final latestDays = max(maximum + margin, (length + spread).ceil());
  final predicted = lastStart.add(Duration(days: length.round()));
  final earliest = lastStart.add(Duration(days: earliestDays));
  final latest = lastStart.add(Duration(days: latestDays));
  final overdue = max(0, day.difference(latest).inDays);
  final irregular = maximum - minimum > 9 || outliers > 0;
  final stale = day.difference(lastStart).inDays > max(120, latestDays * 2);
  final confidence = stale
      ? 'stale'
      : (usable.length < 4 || irregular ? 'limited' : 'moderate');
  final excluded = rawIntervals.length - usable.length;
  final de =
      'Die Mitte deiner ${usable.length} zuletzt auswertbaren Zyklusabstände liegt bei ${length == length.roundToDouble() ? length.toInt() : length} Tagen. '
      'Das Zeitfenster berücksichtigt deine beobachtete Streuung und eine Unsicherheit von mindestens $margin Tagen. '
      '${excluded > 0 ? '$excluded auffällige Abstände wurden für die Schätzung ausgelassen; die Aufzeichnungen bleiben sichtbar. ' : ''}'
      '${usable.length < 4 ? 'Wenige Aufzeichnungen: Die Einschätzung ist noch unsicher. ' : ''}'
      '${irregular ? 'Die Abstände schwanken; das Zeitfenster ist nur eine grobe Planungshilfe. ' : ''}'
      '${overdue > 0 ? 'Das geschätzte Zeitfenster ist vergangen. Ergänze gegebenenfalls fehlende Aufzeichnungen; es wird kein neuer Zyklus unterstellt. ' : ''}'
      '${stale ? 'Die Historie ist für eine aktuelle Planung nicht mehr verlässlich. ' : ''}'
      'Spotting wird nicht als Beginn gezählt. Keine Aussage zu Eisprung oder Verhütung.';
  final en =
      'The median of your ${usable.length} most recent usable cycle intervals is ${length == length.roundToDouble() ? length.toInt() : length} days. '
      'The window reflects your observed variation and at least $margin days of uncertainty. '
      '${excluded > 0 ? '$excluded unusual intervals were left out of the estimate; their records are retained. ' : ''}'
      '${usable.length < 4 ? 'Few records: this estimate remains uncertain. ' : ''}'
      '${irregular ? 'Your intervals vary; this window is only a rough planning aid. ' : ''}'
      '${overdue > 0 ? 'The estimated window has passed. Add missing records if appropriate; a new cycle is not assumed. ' : ''}'
      '${stale ? 'This history is no longer reliable for current planning. ' : ''}'
      'Spotting is not counted as a start. This does not estimate ovulation or contraception.';
  return {
    ...base,
    'status': 'ready',
    'cycleLength': length,
    'predictedStart': dateKey(predicted),
    'earliest': dateKey(earliest),
    'latest': dateKey(latest),
    'overdueDays': overdue,
    'confidence': confidence,
    'explanation': {'de': de, 'en': en},
  };
}
