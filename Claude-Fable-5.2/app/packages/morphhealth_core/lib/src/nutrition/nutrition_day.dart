import '../model/app_data.dart';
import '../model/entries.dart';
import '../model/food.dart';
import '../model/nutrients.dart';
import '../model/settings.dart';
import '../util/dates.dart';
import '../util/json_reader.dart';

/// The nutrient amounts of [quantity] (in the basis unit, g or ml) of [food].
NutrientValues nutrientsOf(Food food, double quantity) =>
    food.completedNutrients.scaled(quantity / 100.0);

/// One diary entry with the amounts it contributes.
class IntakeNutrition {
  final IntakeEntry entry;

  /// The food of the entry; null only if the data are inconsistent.
  final Food? food;

  /// Consumed quantity in the food's basis unit, null if it cannot be
  /// determined (portion without size).
  final double? quantity;

  /// Nutrient amounts of this entry. Unknown stays unknown.
  final NutrientValues nutrients;

  IntakeNutrition._(this.entry, this.food, this.quantity, this.nutrients);

  factory IntakeNutrition.of(IntakeEntry entry, Food? food) {
    if (food == null) {
      return IntakeNutrition._(entry, null, null, NutrientValues());
    }
    final q = entry.basisQuantity(food);
    return IntakeNutrition._(
      entry,
      food,
      q,
      q == null ? NutrientValues() : nutrientsOf(food, q),
    );
  }

  bool isEstimated(Nutrient n) => food?.estimated.contains(n.key) ?? false;

  Map<String, dynamic> toJson() => {
    'id': entry.id,
    'at': entry.at.toIso(),
    'meal': entry.meal.code,
    'food_id': entry.foodId,
    'food_name': food?.name,
    'brand': food?.brand,
    'amount': roundForJson(entry.amount),
    'unit': entry.unit.code,
    if (entry.unit == AmountUnit.portion)
      'portion_size': entry.portionSize == null
          ? null
          : roundForJson(entry.portionSize!),
    'quantity': quantity == null ? null : roundForJson(quantity!),
    'quantity_unit': food?.basis.unit,
    'nutrients': nutrients.toJson(),
    if (food != null && food!.estimated.isNotEmpty)
      'estimated_nutrients': [
        for (final n in Nutrients.all)
          if (food!.estimated.contains(n.key) && nutrients.has(n)) n.key,
      ],
    if (entry.note != null) 'note': entry.note,
  };
}

/// How a day's amount relates to the user's goal.
class GoalProgress {
  final double goal;
  final double actual;

  const GoalProgress(this.goal, this.actual);

  /// Positive while below the goal, negative above it.
  double get remaining => goal - actual;

  /// 0 … 1 and beyond.
  double get fraction => goal <= 0 ? 0 : actual / goal;

  Map<String, dynamic> toJson() => {
    'goal': roundForJson(goal),
    'actual': roundForJson(actual),
    'remaining': roundForJson(remaining),
    'percent': roundForJson(fraction * 100),
  };
}

/// Everything the app shows about the nutrition of one day.
///
/// This is the single place where day totals are calculated: the diary, the
/// overview, the day detail, the trends and `mh nutrition.day` all use it.
class NutritionDay {
  final Day day;

  /// Entries in chronological order.
  final List<IntakeNutrition> entries;

  /// Sum of the known amounts of all entries, per nutrient.
  final NutrientValues totals;

  /// Sum per meal.
  final Map<Meal, NutrientValues> mealTotals;

  /// Per nutrient index: number of entries that have a value.
  final List<int> knownCounts;

  /// Per nutrient index: number of contributing entries whose value is an
  /// estimate.
  final List<int> estimatedCounts;

  final List<WaterEntry> water;
  final double waterMl;

  final List<CaffeineEntry> caffeine;

  /// Caffeine from separately recorded intake (coffee, tea, …).
  final double caffeineAdditionalMg;

  /// Caffeine contained in logged foods.
  final double caffeineFoodMg;

  final Goals goals;

  NutritionDay._({
    required this.day,
    required this.entries,
    required this.totals,
    required this.mealTotals,
    required this.knownCounts,
    required this.estimatedCounts,
    required this.water,
    required this.waterMl,
    required this.caffeine,
    required this.caffeineAdditionalMg,
    required this.caffeineFoodMg,
    required this.goals,
  });

  factory NutritionDay.compute(AppData data, Day day) {
    final entries = [
      for (final e in data.intakeOn(day))
        IntakeNutrition.of(e, data.food(e.foodId)),
    ];
    final totals = NutrientValues();
    final mealTotals = {for (final m in Meal.values) m: NutrientValues()};
    final known = List<int>.filled(Nutrients.count, 0);
    final estimated = List<int>.filled(Nutrients.count, 0);
    for (final e in entries) {
      totals.add(e.nutrients);
      mealTotals[e.entry.meal]!.add(e.nutrients);
      for (final n in Nutrients.all) {
        if (e.nutrients.has(n)) {
          known[n.index]++;
          if (e.isEstimated(n)) estimated[n.index]++;
        }
      }
    }
    final water = data.waterOn(day);
    var waterMl = 0.0;
    for (final w in water) {
      waterMl += w.amountMl;
    }
    final caffeine = data.caffeineOn(day);
    var extra = 0.0;
    for (final c in caffeine) {
      extra += c.amountMg;
    }
    return NutritionDay._(
      day: day,
      entries: entries,
      totals: totals,
      mealTotals: mealTotals,
      knownCounts: known,
      estimatedCounts: estimated,
      water: water,
      waterMl: waterMl,
      caffeine: caffeine,
      caffeineAdditionalMg: extra,
      caffeineFoodMg: totals.valueOrZero(Nutrients.caffeine),
      goals: data.goals,
    );
  }

  int get entryCount => entries.length;

  bool get isEmpty => entries.isEmpty && water.isEmpty && caffeine.isEmpty;

  double get caffeineTotalMg => caffeineFoodMg + caffeineAdditionalMg;

  double get energyKcal => totals.valueOrZero(Nutrients.energy);

  /// The day's total of [n], with unknown counted as zero. For caffeine this
  /// is the amount from foods only; see [caffeineTotalMg].
  double total(Nutrient n) => totals.valueOrZero(n);

  List<IntakeNutrition> entriesOf(Meal meal) => [
    for (final e in entries)
      if (e.entry.meal == meal) e,
  ];

  /// Progress towards the goal of [n], if the user set one.
  GoalProgress? goalProgress(Nutrient n) {
    final goal = switch (n.key) {
      'energy_kcal' => goals.energyKcal,
      'protein_g' => goals.proteinG,
      'carbohydrates_g' => goals.carbohydratesG,
      'fat_g' => goals.fatG,
      _ => null,
    };
    return goal == null ? null : GoalProgress(goal, total(n));
  }

  GoalProgress? get waterProgress =>
      goals.waterMl == null ? null : GoalProgress(goals.waterMl!, waterMl);

  Map<String, dynamic> toJson() {
    Map<String, dynamic> full(NutrientValues v) => {
      for (final n in Nutrients.all) n.key: roundForJson(v.valueOrZero(n)),
    };
    GoalProgress? p(double? goal, double actual) =>
        goal == null ? null : GoalProgress(goal, actual);
    return {
      'date': day.toString(),
      'entry_count': entries.length,
      'meals': [
        for (final m in Meal.values)
          {
            'meal': m.code,
            'entries': [for (final e in entriesOf(m)) e.toJson()],
            'totals': full(mealTotals[m]!),
          },
      ],
      'totals': full(totals),
      'coverage': {
        for (final n in Nutrients.all)
          n.key: {
            'entries_with_value': knownCounts[n.index],
            'entries_total': entries.length,
            'estimated_entries': estimatedCounts[n.index],
          },
      },
      'water': {
        'total_ml': roundForJson(waterMl),
        'entries': [
          for (final w in water)
            {
              'id': w.id,
              'at': w.at.toIso(),
              'amount_ml': roundForJson(w.amountMl),
            },
        ],
      },
      'caffeine': {
        'total_mg': roundForJson(caffeineTotalMg),
        'from_food_mg': roundForJson(caffeineFoodMg),
        'additional_mg': roundForJson(caffeineAdditionalMg),
        'entries': [
          for (final c in caffeine)
            {
              'id': c.id,
              'at': c.at.toIso(),
              'amount_mg': roundForJson(c.amountMg),
              if (c.label != null) 'label': c.label,
            },
        ],
      },
      'goals': {
        'water_ml': p(goals.waterMl, waterMl)?.toJson(),
        'energy_kcal': p(goals.energyKcal, total(Nutrients.energy))?.toJson(),
        'protein_g': p(goals.proteinG, total(Nutrients.protein))?.toJson(),
        'carbohydrates_g': p(
          goals.carbohydratesG,
          total(Nutrients.carbohydrates),
        )?.toJson(),
        'fat_g': p(goals.fatG, total(Nutrients.fat))?.toJson(),
      },
    };
  }
}

/// A selectable quantity for trend charts: any nutrient, water or the total
/// caffeine of a day.
class NutritionMetric {
  final String key;
  final String unit;
  final Nutrient? nutrient;

  const NutritionMetric._(this.key, this.unit, this.nutrient);

  static const NutritionMetric water = NutritionMetric._(
    'water_ml',
    'ml',
    null,
  );

  /// Caffeine from foods plus separately recorded caffeine.
  static const NutritionMetric caffeineTotal = NutritionMetric._(
    'caffeine_total_mg',
    'mg',
    null,
  );

  factory NutritionMetric.nutrient(Nutrient n) =>
      NutritionMetric._(n.key, n.unit, n);

  /// Calories, macros, water and caffeine first, then all other nutrients.
  static final List<NutritionMetric> all = [
    NutritionMetric.nutrient(Nutrients.energy),
    NutritionMetric.nutrient(Nutrients.protein),
    NutritionMetric.nutrient(Nutrients.carbohydrates),
    NutritionMetric.nutrient(Nutrients.fat),
    water,
    caffeineTotal,
    for (final n in Nutrients.all)
      if (n.group != NutrientGroup.energy &&
          n.group != NutrientGroup.macro &&
          n != Nutrients.caffeine)
        NutritionMetric.nutrient(n),
  ];

  double valueOf(NutritionDay day) {
    final n = nutrient;
    if (n != null) return day.total(n);
    return key == water.key ? day.waterMl : day.caffeineTotalMg;
  }

  /// The user's goal for this quantity, if one is set.
  double? goalIn(Goals goals) => switch (key) {
    'water_ml' => goals.waterMl,
    'energy_kcal' => goals.energyKcal,
    'protein_g' => goals.proteinG,
    'carbohydrates_g' => goals.carbohydratesG,
    'fat_g' => goals.fatG,
    _ => null,
  };

  @override
  bool operator ==(Object other) =>
      other is NutritionMetric && other.key == key;

  @override
  int get hashCode => key.hashCode;
}

/// One value of a daily series; [value] is null when the day has no data.
class DayValue {
  final Day day;
  final double? value;

  const DayValue(this.day, this.value);
}

/// Daily values of [metric] from [from] to [to] (inclusive). A day without
/// any matching entry has a null value, so that charts can leave a gap.
List<DayValue> nutritionSeries(
  AppData data,
  NutritionMetric metric,
  Day from,
  Day to,
) {
  final out = <DayValue>[];
  for (var d = from; d <= to; d = d.addDays(1)) {
    final day = NutritionDay.compute(data, d);
    final bool hasData;
    if (metric.nutrient != null) {
      hasData = day.entries.isNotEmpty;
    } else if (metric.key == NutritionMetric.water.key) {
      hasData = day.water.isNotEmpty;
    } else {
      hasData =
          day.caffeine.isNotEmpty ||
          day.knownCounts[Nutrients.caffeine.index] > 0;
    }
    out.add(DayValue(d, hasData ? metric.valueOf(day) : null));
  }
  return out;
}
