// Tagesauswertung der Ernährung: Nährstoffsummen pro Tag und Mahlzeit.
library;

import '../core/parse.dart';
import '../model/document.dart';
import '../model/entries.dart';
import '../model/settings.dart';
import '../nutrients/nutrients.dart';

/// Ergebnis der Nährwertberechnung für einen Tag.
class DayNutrition {
  final String date;
  /// Summen aus Lebensmitteleinträgen (31 Nährstoffe, kanonisch).
  final Map<String, double> totals;
  /// Summe der Wassereinträge (ml).
  final double waterMl;
  /// Summe der manuellen Koffeineinträge (mg).
  final double caffeineManualMg;
  /// Summen pro Mahlzeit.
  final Map<Meal, Map<String, double>> mealTotals;
  final int entryCount;

  DayNutrition({
    required this.date,
    required this.totals,
    required this.waterMl,
    required this.caffeineManualMg,
    required this.mealTotals,
    required this.entryCount,
  });

  /// Koffein gesamt (Lebensmittel + manuelle Einträge).
  double get caffeineTotalMg => (totals['caffeine_mg'] ?? 0) + caffeineManualMg;

  /// Zielerreichung in Prozent (null, wenn kein Ziel gesetzt).
  double? percentOfGoal(String nutrientKey, Goals goals) {
    final double? goal = _goalFor(nutrientKey, goals);
    if (goal == null || goal <= 0) return null;
    final double value = totals[nutrientKey] ?? 0;
    return value / goal * 100;
  }

  double? waterPercentOfGoal(Goals goals) {
    if (goals.waterMl == null || goals.waterMl! <= 0) return null;
    return waterMl / goals.waterMl! * 100;
  }

  static double? _goalFor(String nutrientKey, Goals goals) {
    switch (nutrientKey) {
      case 'energy_kcal':
        return goals.energyKcal;
      case 'protein_g':
        return goals.proteinG;
      case 'carbohydrates_g':
        return goals.carbohydratesG;
      case 'fat_g':
        return goals.fatG;
      default:
        return null;
    }
  }

  /// JSON-Darstellung (für UI und CLI `nutrition.day`).
  Map<String, dynamic> toJson({Goals? goals}) => <String, dynamic>{
        'date': date,
        'totals': <String, dynamic>{
          for (final MapEntry<String, double> e in totals.entries) e.key: _round(e.value),
        },
        'water_ml': _round(waterMl),
        'caffeine_mg': _round(caffeineTotalMg),
        'caffeine_manual_mg': _round(caffeineManualMg),
        'meals': <String, dynamic>{
          for (final MapEntry<Meal, Map<String, double>> e in mealTotals.entries)
            e.key.name: <String, dynamic>{
              for (final MapEntry<String, double> n in e.value.entries) n.key: _round(n.value),
            },
        },
        'entry_count': entryCount,
        if (goals != null) 'goals': <String, dynamic>{
          if (goals.waterMl != null) 'water_ml': goals.waterMl,
          if (goals.energyKcal != null) 'energy_kcal': goals.energyKcal,
          if (goals.proteinG != null) 'protein_g': goals.proteinG,
          if (goals.carbohydratesG != null) 'carbohydrates_g': goals.carbohydratesG,
          if (goals.fatG != null) 'fat_g': goals.fatG,
        },
      };

  static double _round(double v) => (v * 100).round() / 100;
}

/// Nährwerte eines einzelnen Eintrags (kanonisch).
Map<String, double> entryNutrients(NutritionEntry entry) {
  final double factor = entry.effectiveGrams() / 100;
  final Map<String, double> out = <String, double>{};
  for (final NutrientDef def in nutrientDefs) {
    out[def.key] = (entry.foodPer100[def.key] ?? 0) * factor;
  }
  return out;
}

/// Berechnet die Tagesauswertung.
DayNutrition computeDayNutrition(MorphDocument doc, String date) {
  final Map<String, double> totals = emptyNutrientMap();
  final Map<Meal, Map<String, double>> mealTotals = <Meal, Map<String, double>>{
    for (final Meal m in Meal.values) m: emptyNutrientMap(),
  };
  double waterMl = 0;
  double caffeineManualMg = 0;
  int entryCount = 0;

  for (final NutritionEntry e in doc.nutritionEntries) {
    if (e.date != date) continue;
    entryCount++;
    final Map<String, double> n = entryNutrients(e);
    for (final MapEntry<String, double> kv in n.entries) {
      totals[kv.key] = (totals[kv.key] ?? 0) + kv.value;
    }
    final Map<String, double> meal = mealTotals[e.meal]!;
    for (final MapEntry<String, double> kv in n.entries) {
      meal[kv.key] = (meal[kv.key] ?? 0) + kv.value;
    }
  }
  for (final WaterEntry e in doc.waterEntries) {
    if (e.date == date) waterMl += e.amountMl;
  }
  for (final CaffeineEntry e in doc.caffeineEntries) {
    if (e.date == date) caffeineManualMg += e.amountMg;
  }
  return DayNutrition(
    date: date,
    totals: totals,
    waterMl: waterMl,
    caffeineManualMg: caffeineManualMg,
    mealTotals: mealTotals,
    entryCount: entryCount,
  );
}

/// Summiert Nährwerte über einen Datumsbereich (für Verläufe).
///
/// Rückgabe: Liste von `{date, totals, water_ml, caffeine_mg}`.
List<Map<String, dynamic>> computeNutrientSeries(
  MorphDocument doc,
  String fromDate,
  String toDate,
) {
  final List<Map<String, dynamic>> out = <Map<String, dynamic>>[];
  final DateTime? start = parseDate(fromDate);
  final DateTime? end = parseDate(toDate);
  if (start == null || end == null) return out;
  DateTime d = start;
  while (d.isBefore(end) || d.isAtSameMomentAs(end)) {
    final String ds = formatDate(d);
    final DayNutrition day = computeDayNutrition(doc, ds);
    out.add(<String, dynamic>{
      'date': ds,
      'totals': day.totals,
      'water_ml': day.waterMl,
      'caffeine_mg': day.caffeineTotalMg,
    });
    d = d.add(const Duration(days: 1));
  }
  return out;
}
