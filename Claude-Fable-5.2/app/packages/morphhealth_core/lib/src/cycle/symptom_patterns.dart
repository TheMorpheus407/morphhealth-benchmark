import '../model/app_data.dart';
import '../util/dates.dart';
import '../util/json_reader.dart';

/// Where in the cycle a symptom keeps appearing.
enum PatternPhase {
  /// In the seven days before a period starts.
  beforePeriod('before_period'),

  /// In the first five days of a period.
  duringPeriod('during_period');

  final String code;
  const PatternPhase(this.code);
}

/// A symptom that the user recorded around the start of several periods.
///
/// This is a description of the user's own diary ("in 4 of your last 5
/// cycles …"), not a diagnosis and not a statement about causes.
class SymptomPattern {
  /// The symptom name as the user last wrote it.
  final String name;
  final String nameKey;
  final PatternPhase phase;

  /// Cycles in which the symptom was recorded in this phase.
  final int cyclesWith;

  /// Cycles that were looked at.
  final int cyclesTotal;

  /// Median distance to the first day of the period: -2 means two days
  /// before, 0 the first day, 1 the second day.
  final int typicalOffsetDays;

  /// Mean recorded intensity (1–10) of the matching entries.
  final double meanIntensity;

  const SymptomPattern({
    required this.name,
    required this.nameKey,
    required this.phase,
    required this.cyclesWith,
    required this.cyclesTotal,
    required this.typicalOffsetDays,
    required this.meanIntensity,
  });

  Map<String, dynamic> toJson() => {
    'symptom': name,
    'phase': phase.code,
    'cycles_with_symptom': cyclesWith,
    'cycles_considered': cyclesTotal,
    'typical_offset_days': typicalOffsetDays,
    'mean_intensity': roundForJson((meanIntensity * 10).roundToDouble() / 10),
  };
}

/// Finds symptoms that recur around period starts, looking at the last
/// [cycles] periods that started on or before [asOf].
///
/// A pattern is reported when the symptom (intensity 1 or more) was recorded
/// in the same phase in at least three cycles and in at least 60 % of the
/// cycles considered.
List<SymptomPattern> symptomPatterns(AppData data, Day asOf, {int cycles = 6}) {
  const daysBefore = 7;
  const daysDuring = 5;
  const minCycles = 3;

  final starts = [
    for (final p in data.periodsSorted)
      if (p.start <= asOf) p.start,
  ];
  if (starts.length < minCycles) return const [];
  final considered = starts.length > cycles
      ? starts.sublist(starts.length - cycles)
      : starts;

  // nameKey -> phase -> start index -> offsets
  final hits = <String, Map<PatternPhase, Map<int, List<int>>>>{};
  final intensity = <String, Map<PatternPhase, List<int>>>{};
  final display = <String, ({String name, LocalDateTime at})>{};

  for (var i = 0; i < considered.length; i++) {
    final start = considered[i];
    for (var offset = -daysBefore; offset < daysDuring; offset++) {
      final day = start.addDays(offset);
      if (day > asOf) break;
      // With very short cycles a day could belong to two starts; it counts
      // for the nearer one.
      if (i > 0 && offset < 0) {
        final previous = considered[i - 1];
        if (day.daysSince(previous) < -offset) continue;
      }
      if (i + 1 < considered.length && offset >= 0) {
        final next = considered[i + 1];
        if (next.daysSince(day) <= offset) continue;
      }
      for (final s in data.symptomsOn(day)) {
        if (s.intensity < 1) continue;
        final phase = offset < 0
            ? PatternPhase.beforePeriod
            : PatternPhase.duringPeriod;
        hits
            .putIfAbsent(s.nameKey, () => {})
            .putIfAbsent(phase, () => {})
            .putIfAbsent(i, () => [])
            .add(offset);
        intensity
            .putIfAbsent(s.nameKey, () => {})
            .putIfAbsent(phase, () => [])
            .add(s.intensity);
        final known = display[s.nameKey];
        if (known == null || s.at.compareTo(known.at) > 0) {
          display[s.nameKey] = (name: s.name, at: s.at);
        }
      }
    }
  }

  final out = <SymptomPattern>[];
  hits.forEach((key, phases) {
    phases.forEach((phase, byCycle) {
      final count = byCycle.length;
      if (count < minCycles || count * 10 < considered.length * 6) return;
      // One representative offset per cycle (its first occurrence), then the
      // median across cycles.
      final firsts = [
        for (final offsets in byCycle.values)
          offsets.reduce((a, b) => a < b ? a : b),
      ]..sort();
      final values = intensity[key]![phase]!;
      out.add(
        SymptomPattern(
          name: display[key]!.name,
          nameKey: key,
          phase: phase,
          cyclesWith: count,
          cyclesTotal: considered.length,
          typicalOffsetDays: firsts[(firsts.length - 1) ~/ 2],
          meanIntensity: values.reduce((a, b) => a + b) / values.length,
        ),
      );
    });
  });
  out.sort((a, b) {
    final c = b.cyclesWith.compareTo(a.cyclesWith);
    if (c != 0) return c;
    final p = a.phase.index.compareTo(b.phase.index);
    return p != 0 ? p : a.nameKey.compareTo(b.nameKey);
  });
  return out;
}
