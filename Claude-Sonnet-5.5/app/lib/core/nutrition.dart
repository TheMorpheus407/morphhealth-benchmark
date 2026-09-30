import 'civil.dart';
import 'db.dart';
import 'models.dart';
import 'nutrients.dart';

/// Ergebnis für eine Mahlzeit eines Tages.
final class MealSummary {
  final Meal meal;
  final List<FoodEntry> entries;
  final Nutrients totals;

  const MealSummary(this.meal, this.entries, this.totals);
}

/// Fortschritt zu einem freiwilligen Tagesziel.
final class GoalProgress {
  final double value;
  final double goal;

  const GoalProgress(this.value, this.goal);

  double get remaining => goal - value;

  /// Prozent des Ziels (kann über 100 liegen).
  double get percent => goal > 0 ? value / goal * 100 : 0;
}

/// Alle Ernährungsangaben eines Tages: das, was die Übersicht, das
/// Ernährungstagebuch und der Wartungszugang (`nutrition.day`) ausgeben.
final class DayNutrition {
  final Day day;

  /// Verzehreinträge des Tages, nach Uhrzeit sortiert.
  final List<FoodEntry> entries;

  /// Alle vier Mahlzeiten, auch leere.
  final List<MealSummary> meals;

  /// Summe aller Nährwerte aus Lebensmitteln (ohne zusätzliches Koffein).
  final Nutrients foodTotals;

  /// Tagessumme einschließlich zusätzlich erfasstem Koffein.
  final Nutrients totals;

  /// Je Nährstoff: Zahl der Verzehreinträge, die einen Wert liefern.
  final Map<String, int> entriesWithData;

  final List<WaterEntry> waterEntries;
  final double waterMl;

  final List<CaffeineEntry> caffeineEntries;
  final double caffeineFromFoodsMg;
  final double caffeineAdditionalMg;

  final Goals goals;

  const DayNutrition({
    required this.day,
    required this.entries,
    required this.meals,
    required this.foodTotals,
    required this.totals,
    required this.entriesWithData,
    required this.waterEntries,
    required this.waterMl,
    required this.caffeineEntries,
    required this.caffeineFromFoodsMg,
    required this.caffeineAdditionalMg,
    required this.goals,
  });

  double get caffeineTotalMg => caffeineFromFoodsMg + caffeineAdditionalMg;

  bool get hasAnyData => entries.isNotEmpty || waterEntries.isNotEmpty || caffeineEntries.isNotEmpty;

  /// Fortschritte für gesetzte Ziele, nach Zielschlüssel (`water_ml` und die
  /// Nährstoffschlüssel `energy_kcal`, `protein_g`, `carbohydrates_g`, `fat_g`).
  Map<String, GoalProgress> get progress {
    final out = <String, GoalProgress>{};
    if (goals.waterMl != null) out['water_ml'] = GoalProgress(waterMl, goals.waterMl!);
    for (final k in [kEnergy, kProtein, kCarbs, kFat]) {
      final g = goals.forNutrient(k);
      if (g != null) out[k] = GoalProgress(totals.get0(k), g);
    }
    return out;
  }

  Map<String, Object?> toJson() => {
    'date': day.toString(),
    'entry_count': entries.length,
    'totals': _complete(totals),
    'entries_with_data': {for (final n in nutrientCatalog) n.key: entriesWithData[n.key] ?? 0},
    'water_ml': roundTo(waterMl, 4),
    'caffeine': {
      'total_mg': roundTo(caffeineTotalMg, 4),
      'from_foods_mg': roundTo(caffeineFromFoodsMg, 4),
      'additional_mg': roundTo(caffeineAdditionalMg, 4),
    },
    'meals': [
      for (final m in meals)
        {
          'meal': m.meal.name,
          'entry_count': m.entries.length,
          'totals': {for (final k in _mealKeys) k: roundTo(m.totals.get0(k), 4)},
        },
    ],
    'entries': [
      for (final e in entries)
        {
          'id': e.id,
          'time': '${e.at.hour.toString().padLeft(2, '0')}:${e.at.minute.toString().padLeft(2, '0')}',
          'at': e.at.toString(),
          'meal': e.meal.name,
          'food_id': e.foodId,
          'name': e.food.name,
          'brand': e.food.brand,
          'barcode': e.food.barcode,
          'amount': e.amount,
          'unit': e.unit.name,
          'amount_base': roundTo(e.baseAmount, 4),
          'basis': e.food.basis.name,
          'note': e.note,
          'nutrients': e.nutrients.toJson(rounded: true),
        },
    ],
    'water_entries': [
      for (final w in waterEntries) {'id': w.id, 'at': w.at.toString(), 'ml': w.ml},
    ],
    'caffeine_entries': [
      for (final c in caffeineEntries) {'id': c.id, 'at': c.at.toString(), 'mg': c.mg, 'label': c.label},
    ],
    'goals': goals.toJson(),
    'goal_progress': {
      for (final e in progress.entries)
        e.key: {
          'value': roundTo(e.value.value, 4),
          'goal': e.value.goal,
          'remaining': roundTo(e.value.remaining, 4),
          'percent': roundTo(e.value.percent, 1),
        },
    },
  };
}

/// Alle Katalog-Nährstoffe als Zahlen (0, wenn nichts erfasst wurde), gerundet.
Map<String, double> _complete(Nutrients n) => {for (final d in nutrientCatalog) d.key: roundTo(n.get0(d.key), 4)};

/// Nährwerte, die je Mahlzeit ausgegeben werden.
const List<String> _mealKeys = [kEnergy, kProtein, kCarbs, kFat];

/// Berechnet die Ernährungsangaben des Tages [day].
DayNutrition dayNutrition(Db db, Day day) {
  final entries = db.entries.on(day);
  final byMeal = {for (final m in Meal.values) m: <FoodEntry>[]};
  var foodTotals = Nutrients.none;
  final mealTotals = {for (final m in Meal.values) m: Nutrients.none};
  final withData = <String, int>{};
  for (final e in entries) {
    byMeal[e.meal]!.add(e);
    final n = e.nutrients;
    foodTotals = foodTotals.plus(n);
    mealTotals[e.meal] = mealTotals[e.meal]!.plus(n);
    for (final k in e.food.nutrients.keys) {
      withData[k] = (withData[k] ?? 0) + 1;
    }
  }
  final waterEntries = db.water.on(day);
  final caffeineEntries = db.caffeine.on(day);
  var water = 0.0;
  for (final w in waterEntries) {
    water += w.ml;
  }
  var extra = 0.0;
  for (final c in caffeineEntries) {
    extra += c.mg;
  }
  final fromFoods = foodTotals.get0(kCaffeine);
  final totals = extra > 0 ? foodTotals.with_(kCaffeine, fromFoods + extra) : foodTotals;
  return DayNutrition(
    day: day,
    entries: entries,
    meals: [for (final m in Meal.values) MealSummary(m, byMeal[m]!, mealTotals[m]!)],
    foodTotals: foodTotals,
    totals: totals,
    entriesWithData: withData,
    waterEntries: waterEntries,
    waterMl: water,
    caffeineEntries: caffeineEntries,
    caffeineFromFoodsMg: fromFoods,
    caffeineAdditionalMg: extra,
    goals: db.goals,
  );
}

/// Ein Tageswert in einer Zeitreihe. [value] ist null, wenn an dem Tag nichts
/// erfasst wurde.
final class DailyPoint {
  final Day day;
  final double? value;

  const DailyPoint(this.day, this.value);
}

/// Eine Zeitreihe über mehrere Tage mit Kennzahlen.
final class DailySeries {
  final String metric;
  final String unit;
  final List<DailyPoint> points;

  const DailySeries(this.metric, this.unit, this.points);

  Iterable<double> get values => points.where((p) => p.value != null).map((p) => p.value!);

  /// Tage mit Angaben.
  int get daysWithData => values.length;

  double? get average {
    final v = values.toList();
    if (v.isEmpty) return null;
    return v.reduce((a, b) => a + b) / v.length;
  }

  double? get minimum => values.isEmpty ? null : values.reduce((a, b) => a < b ? a : b);
  double? get maximum => values.isEmpty ? null : values.reduce((a, b) => a > b ? a : b);

  Map<String, Object?> toJson() => {
    'metric': metric,
    'unit': unit,
    'days': points.length,
    'days_with_data': daysWithData,
    'average': average == null ? null : roundTo(average!, 4),
    'minimum': minimum == null ? null : roundTo(minimum!, 4),
    'maximum': maximum == null ? null : roundTo(maximum!, 4),
    'points': [
      for (final p in points) {'date': p.day.toString(), 'value': p.value == null ? null : roundTo(p.value!, 4)},
    ],
  };
}

/// Kennzahlen, die eine Zeitreihe anbieten kann.
const String kMetricWater = 'water_ml';
const String kMetricWeight = 'weight_kg';

/// Tageswerte eines Nährstoffs (oder `water_ml`) für die [days] Tage bis
/// einschließlich [end].
DailySeries nutritionSeries(Db db, String metric, Day end, int days) {
  final start = end.addDays(-(days - 1));
  final points = <DailyPoint>[];
  final unit = metric == kMetricWater ? 'ml' : (nutrientByKey[metric]?.unit ?? '');
  for (var i = 0; i < days; i++) {
    final d = start.addDays(i);
    double? v;
    if (metric == kMetricWater) {
      final w = db.water.on(d);
      if (w.isNotEmpty) v = w.fold<double>(0, (a, b) => a + b.ml);
    } else if (metric == kCaffeine) {
      final hasFoods = db.entries.on(d).isNotEmpty;
      final extra = db.caffeine.on(d);
      if (hasFoods || extra.isNotEmpty) v = dayNutrition(db, d).totals.get0(kCaffeine);
    } else if (db.entries.on(d).isNotEmpty) {
      v = dayNutrition(db, d).totals.get0(metric);
    }
    points.add(DailyPoint(d, v));
  }
  return DailySeries(metric, unit, points);
}

/// Tagesgewicht (letzter Eintrag des Tages) in kg für die [days] Tage bis [end].
DailySeries weightSeries(Db db, Day end, int days) {
  final start = end.addDays(-(days - 1));
  return DailySeries(kMetricWeight, 'kg', [
    for (var i = 0; i < days; i++) DailyPoint(start.addDays(i), db.weightOn(start.addDays(i))?.kg),
  ]);
}
