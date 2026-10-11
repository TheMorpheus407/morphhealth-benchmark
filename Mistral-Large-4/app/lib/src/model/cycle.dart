// Datenmodelle: Zyklus (Perioden), Gewicht, Symptome.
library;

import '../core/parse.dart';

/// Blutungsstärke (inkl. Spotting).
enum FlowLevel {
  spotting,
  light,
  medium,
  heavy;

  static FlowLevel fromString(String? value) {
    switch (value) {
      case 'light':
        return FlowLevel.light;
      case 'medium':
        return FlowLevel.medium;
      case 'heavy':
        return FlowLevel.heavy;
      default:
        return FlowLevel.spotting;
    }
  }

  static FlowLevel fromInt(int? value) {
    if (value == null) return FlowLevel.medium;
    if (value <= 0) return FlowLevel.spotting;
    if (value == 1) return FlowLevel.light;
    if (value == 2) return FlowLevel.medium;
    return FlowLevel.heavy;
  }

  int get level => FlowLevel.values.indexOf(this);
}

/// Eine aufgezeichnete Periode.
///
/// `start` und `end` sind inklusive Kalendertage (`YYYY-MM-DD`).
/// `end == null` bedeutet: Periode läuft noch.
/// `flowByDay` erlaubt tagesgenaue Abweichungen von `flow`.
class PeriodRecord {
  String id;
  String start;
  String? end;
  FlowLevel flow;
  Map<String, int> flowByDay;
  String? note;

  PeriodRecord({
    required this.id,
    required this.start,
    this.end,
    this.flow = FlowLevel.medium,
    Map<String, int>? flowByDay,
    this.note,
  }) : flowByDay = flowByDay ?? <String, int>{};

  bool get isOngoing => end == null;

  /// Blutungsstärke an einem Tag (tagesgenauer Override oder Standard).
  FlowLevel flowOn(String date) {
    final int? v = flowByDay[date];
    if (v == null) return flow;
    return FlowLevel.fromInt(v);
  }

  /// Liefert true, wenn der Tag in [start, end] (bzw. start..heute) liegt.
  bool covers(String date, {String? today}) {
    if (date.compareTo(start) < 0) return false;
    final String last = end ?? today ?? date;
    return date.compareTo(last) <= 0;
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'start': start,
        if (end != null) 'end': end,
        'flow': flow.name,
        'flow_by_day': <String, dynamic>{
          for (final MapEntry<String, int> e in flowByDay.entries) e.key: e.value,
        },
        if (note != null) 'note': note,
      };

  static PeriodRecord fromJson(Map<String, dynamic> json) {
    final raw = getMap(json, 'flow_by_day') ?? <String, dynamic>{};
    return PeriodRecord(
      id: getString(json, 'id') ?? '',
      start: getString(json, 'start') ?? '',
      end: getString(json, 'end'),
      flow: FlowLevel.fromString(getString(json, 'flow')),
      flowByDay: <String, int>{
        for (final MapEntry<String, dynamic> e in raw.entries)
          e.key: (e.value is num) ? (e.value as num).toInt() : 2,
      },
      note: getString(json, 'note'),
    );
  }
}

/// Ein Gewichtseintrag. Gespeichert wird Kilogramm (kanonisch).
class WeightEntry {
  String id;
  String date; // YYYY-MM-DD
  String? time; // HH:MM
  double weightKg;
  String? note;

  WeightEntry({
    required this.id,
    required this.date,
    this.time,
    required this.weightKg,
    this.note,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'date': date,
        if (time != null) 'time': time,
        'weight_kg': weightKg,
        if (note != null) 'note': note,
      };

  static WeightEntry fromJson(Map<String, dynamic> json) => WeightEntry(
        id: getString(json, 'id') ?? '',
        date: getString(json, 'date') ?? '',
        time: getString(json, 'time'),
        weightKg: getDouble(json, 'weight_kg') ?? 0,
        note: getString(json, 'note'),
      );
}

/// Ein Symptom (frei wählbarer Name, Intensität 0–10).
class SymptomEntry {
  String id;
  String name;
  int intensity; // 0..10
  String date; // YYYY-MM-DD
  String? time; // HH:MM
  String? note;

  SymptomEntry({
    required this.id,
    required this.name,
    required int intensity,
    required this.date,
    this.time,
    this.note,
  }) : intensity = intensity.clamp(0, 10);

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'intensity': intensity,
        'date': date,
        if (time != null) 'time': time,
        if (note != null) 'note': note,
      };

  static SymptomEntry fromJson(Map<String, dynamic> json) => SymptomEntry(
        id: getString(json, 'id') ?? '',
        name: getString(json, 'name') ?? '',
        intensity: getInt(json, 'intensity') ?? 0,
        date: getString(json, 'date') ?? '',
        time: getString(json, 'time'),
        note: getString(json, 'note'),
      );
}
