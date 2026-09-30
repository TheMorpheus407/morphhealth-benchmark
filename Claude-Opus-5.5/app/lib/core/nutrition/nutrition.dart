import '../model/dataset.dart';
import '../model/entries.dart';
import '../model/enums.dart';
import '../model/nutrients.dart';
import '../model/settings.dart';
import '../util/local_date.dart';

/// Rounds away floating point noise for output (3 decimal places).
double round3(double value) => (value * 1000).roundToDouble() / 1000;

/// Sum of nutrients over a set of diary entries.
///
/// A nutrient total is only known if at least one entry has a value for it;
/// [knownCount] tells how many entries contributed, so incomplete data
/// (common for micronutrients) is visible instead of silently counted as 0.
class NutrientTotals {
  NutrientTotals._(this.values, this.knownCount, this.estimated, this.entryCount);

  factory NutrientTotals.of(Iterable<FoodEntry> entries) {
    final values = <String, double>{};
    final known = <String, int>{};
    final estimated = <String>{};
    var count = 0;
    for (final entry in entries) {
      count++;
      final quantity = entry.quantity;
      if (quantity == null) continue;
      entry.food.nutrients.forEach((key, per100) {
        values[key] = (values[key] ?? 0) + per100 * quantity / 100.0;
        known[key] = (known[key] ?? 0) + 1;
        if (entry.food.estimatedNutrients.contains(key)) estimated.add(key);
      });
    }
    return NutrientTotals._(values, known, estimated, count);
  }

  static final NutrientTotals empty = NutrientTotals._({}, {}, {}, 0);

  final Map<String, double> values;
  final Map<String, int> knownCount;
  final Set<String> estimated;
  final int entryCount;

  double? operator [](String key) => values[key];

  double valueOrZero(String key) => values[key] ?? 0;

  /// True if every entry has a value for [key].
  bool isComplete(String key) =>
      entryCount > 0 && (knownCount[key] ?? 0) == entryCount;

  Map<String, Object?> totalsJson() => {
    for (final n in Nutrients.all)
      n.key: values.containsKey(n.key) ? round3(values[n.key]!) : null,
  };

  Map<String, Object?> detailJson() => {
    for (final n in Nutrients.all)
      n.key: {
        'unit': n.unit,
        'entries_with_value': knownCount[n.key] ?? 0,
        'includes_estimates': estimated.contains(n.key),
      },
  };
}

/// Everything the nutrition diary shows for one day.
class DayNutrition {
  DayNutrition({
    required this.date,
    required this.entries,
    required this.water,
    required this.caffeine,
    required this.goals,
  }) : totals = NutrientTotals.of(entries),
       mealTotals = {
         for (final meal in Meal.values)
           meal: NutrientTotals.of(entries.where((e) => e.meal == meal)),
       };

  final LocalDate date;

  /// Entries ordered by meal (breakfast → snack), then time.
  final List<FoodEntry> entries;
  final List<WaterEntry> water;
  final List<CaffeineEntry> caffeine;
  final Goals goals;
  final NutrientTotals totals;
  final Map<Meal, NutrientTotals> mealTotals;

  List<FoodEntry> entriesFor(Meal meal) =>
      entries.where((e) => e.meal == meal).toList();

  double get waterMl => water.fold(0.0, (s, e) => s + e.amountMl);
  double get caffeineFromFoodsMg => totals.valueOrZero(Nutrients.caffeine.key);
  double get caffeineAdditionalMg =>
      caffeine.fold(0.0, (s, e) => s + e.amountMg);
  double get caffeineTotalMg => caffeineFromFoodsMg + caffeineAdditionalMg;

  bool get isEmpty => entries.isEmpty && water.isEmpty && caffeine.isEmpty;

  /// The structure returned by the `nutrition.day` maintenance operation.
  Map<String, Object?> toJson() => {
    'date': date.toIso(),
    'entry_count': entries.length,
    'totals': totals.totalsJson(),
    'totals_detail': totals.detailJson(),
    'meals': {
      for (final meal in Meal.values)
        meal.json: {
          'entry_count': mealTotals[meal]!.entryCount,
          'totals': mealTotals[meal]!.totalsJson(),
        },
    },
    'entries': [for (final e in entries) entryJson(e)],
    'water': {
      'total_ml': round3(waterMl),
      'entries': [
        for (final w in water)
          {
            'id': w.id,
            'time': w.time == null ? null : TimeOfDayMinutes.format(w.time!),
            'amount_ml': w.amountMl,
          },
      ],
    },
    'caffeine': {
      'from_foods_mg': round3(caffeineFromFoodsMg),
      'additional_mg': round3(caffeineAdditionalMg),
      'total_mg': round3(caffeineTotalMg),
      'entries': [
        for (final c in caffeine)
          {
            'id': c.id,
            'time': c.time == null ? null : TimeOfDayMinutes.format(c.time!),
            'amount_mg': c.amountMg,
            'label': c.label,
          },
      ],
    },
    'goals': goals.toJson(),
    'goal_progress': {
      for (final key in const [
        'energy_kcal',
        'protein_g',
        'carbohydrates_g',
        'fat_g',
        'water_ml',
      ])
        key: _progress(key),
    },
  };

  Object? _progress(String key) {
    final goal = goals.forKey(key);
    if (goal == null) return null;
    final value = key == 'water_ml' ? waterMl : totals.valueOrZero(key);
    return {'goal': goal, 'value': round3(value), 'ratio': round3(value / goal)};
  }

  static Map<String, Object?> entryJson(FoodEntry e) => {
    'id': e.id,
    'time': e.time == null ? null : TimeOfDayMinutes.format(e.time!),
    'meal': e.meal.json,
    'name': e.food.name,
    'brand': e.food.brand,
    'barcode': e.food.barcode,
    'source': e.food.source.json,
    'amount': e.amount,
    'unit': e.unit.json,
    'quantity': e.quantity == null ? null : round3(e.quantity!),
    'quantity_unit': e.food.basis.json,
    'nutrients': {
      for (final n in Nutrients.all)
        if (e.nutrient(n.key) != null) n.key: round3(e.nutrient(n.key)!),
    },
    'estimated_nutrients': [
      for (final n in Nutrients.all)
        if (e.food.estimatedNutrients.contains(n.key)) n.key,
    ],
  };
}

DayNutrition buildDayNutrition(Dataset data, LocalDate date) {
  final entries = [...data.foodEntriesOn(date)]
    ..sort((a, b) {
      final m = a.meal.index.compareTo(b.meal.index);
      return m != 0 ? m : compareDated(a, b);
    });
  return DayNutrition(
    date: date,
    entries: entries,
    water: data.waterOn(date),
    caffeine: data.caffeineOn(date),
    goals: data.settings.goals,
  );
}

/// Metrics available for the nutrition trend: every nutrient key plus
/// water and total caffeine.
class TrendMetric {
  static const String water = 'water_ml';
  static const String caffeineTotal = 'caffeine_total_mg';

  static List<String> get all => [
    for (final n in Nutrients.all) n.key,
    water,
    caffeineTotal,
  ];

  static String unitOf(String key) => switch (key) {
    water => 'ml',
    caffeineTotal => 'mg',
    _ => Nutrients.byKey[key]?.unit ?? '',
  };
}

/// Daily values of one metric over a window of days.
class DailySeries {
  DailySeries(this.metric, this.days, this.values, this.goal);

  final String metric;
  final List<LocalDate> days;

  /// One value per day; null where nothing was logged.
  final List<double?> values;
  final double? goal;

  Iterable<double> get _present => values.whereType<double>();

  int get daysWithData => _present.length;

  double? get average =>
      daysWithData == 0 ? null : _present.reduce((a, b) => a + b) / daysWithData;

  double? get maximum =>
      daysWithData == 0 ? null : _present.reduce((a, b) => a > b ? a : b);

  double? get minimum =>
      daysWithData == 0 ? null : _present.reduce((a, b) => a < b ? a : b);
}

DailySeries nutritionSeries(
  Dataset data,
  String metric,
  LocalDate end,
  int dayCount,
) {
  final days = [
    for (var i = dayCount - 1; i >= 0; i--) end.addDays(-i),
  ];
  final values = <double?>[];
  for (final day in days) {
    switch (metric) {
      case TrendMetric.water:
        final w = data.waterOn(day);
        values.add(w.isEmpty ? null : w.fold<double>(0, (s, e) => s + e.amountMl));
      case TrendMetric.caffeineTotal:
        final entries = data.foodEntriesOn(day);
        final extra = data.caffeineOn(day);
        if (entries.isEmpty && extra.isEmpty) {
          values.add(null);
        } else {
          final fromFood = NutrientTotals.of(entries)
              .valueOrZero(Nutrients.caffeine.key);
          values.add(fromFood + extra.fold<double>(0, (s, e) => s + e.amountMg));
        }
      default:
        final entries = data.foodEntriesOn(day);
        if (entries.isEmpty) {
          values.add(null);
        } else {
          values.add(NutrientTotals.of(entries)[metric]);
        }
    }
  }
  return DailySeries(metric, days, values, data.settings.goals.forKey(metric));
}
