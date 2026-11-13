/// Daily nutrition aggregation service shared between Flutter UI and `./mh`.
library;

import 'clock.dart';
import 'models.dart';
import 'nutrients.dart';

class ResolvedMealEntry {
  final FoodDiaryEntry entry;
  final FoodItem? food;
  final double gramsOrMlEquivalent;
  final NutrientProfile nutrients;

  const ResolvedMealEntry({
    required this.entry,
    required this.food,
    required this.gramsOrMlEquivalent,
    required this.nutrients,
  });

  Map<String, dynamic> toJson(String locale) => {
        'id': entry.id,
        'date': entry.date,
        'recorded_at': entry.recordedAt,
        'meal_type': entry.mealType.jsonKey,
        'food_id': entry.foodId,
        'food_name': entry.displayName(food, locale),
        if (entry.displayBrand(food) != null) 'brand': entry.displayBrand(food),
        'amount': entry.amount,
        'unit': entry.unit.jsonKey,
        'grams_or_ml_equivalent':
            (gramsOrMlEquivalent * 100).roundToDouble() / 100.0,
        'nutrients': nutrients.toDenseJson(),
        if (entry.note != null && entry.note!.isNotEmpty) 'note': entry.note,
      };
}

class MealGroupSummary {
  final MealType mealType;
  final List<ResolvedMealEntry> entries;
  final NutrientProfile totals;

  const MealGroupSummary({
    required this.mealType,
    required this.entries,
    required this.totals,
  });

  Map<String, dynamic> toJson(String locale) => {
        'meal_type': mealType.jsonKey,
        'entry_count': entries.length,
        'totals': totals.toDenseJson(),
        'entries': entries.map((e) => e.toJson(locale)).toList(),
      };
}

class NutritionDaySummary {
  final String date; // YYYY-MM-DD
  final NutrientProfile foodNutrients;
  final NutrientProfile combinedNutrients; // includes direct caffeine in caffeine_mg
  final double waterMl;
  final double caffeineFromFoodsMg;
  final double caffeineDirectMg;
  final double totalCaffeineMg;
  final NutritionGoals goals;
  final Map<MealType, MealGroupSummary> meals;
  final List<ResolvedMealEntry> allMealEntries;
  final List<WaterEntry> waterEntries;
  final List<CaffeineEntry> caffeineEntries;

  const NutritionDaySummary({
    required this.date,
    required this.foodNutrients,
    required this.combinedNutrients,
    required this.waterMl,
    required this.caffeineFromFoodsMg,
    required this.caffeineDirectMg,
    required this.totalCaffeineMg,
    required this.goals,
    required this.meals,
    required this.allMealEntries,
    required this.waterEntries,
    required this.caffeineEntries,
  });

  double valueForMetric(String metricKey) {
    if (metricKey == 'water_ml') return waterMl;
    final nKey = NutrientKey.byJsonKey[metricKey];
    if (nKey != null) return combinedNutrients.valueOrZero(nKey);
    return 0.0;
  }

  Map<String, dynamic> toJson({String locale = 'de'}) {
    double? ratio(double actual, double? target) {
      if (target == null || target <= 0) return null;
      return ((actual / target) * 1000).roundToDouble() / 1000.0;
    }

    return {
      'date': date,
      'water_ml': _round2(waterMl),
      'caffeine_from_foods_mg': _round2(caffeineFromFoodsMg),
      'caffeine_direct_mg': _round2(caffeineDirectMg),
      'total_caffeine_mg': _round2(totalCaffeineMg),
      'nutrients': combinedNutrients.toDenseJson(),
      'goals': {
        'targets': goals.toJson(),
        'progress_ratio': {
          'water_ml': ratio(waterMl, goals.waterMl),
          'calories_kcal': ratio(
            combinedNutrients.valueOrZero(NutrientKey.caloriesKcal),
            goals.caloriesKcal,
          ),
          'protein_g': ratio(
            combinedNutrients.valueOrZero(NutrientKey.proteinG),
            goals.proteinG,
          ),
          'carbs_g': ratio(
            combinedNutrients.valueOrZero(NutrientKey.carbsG),
            goals.carbsG,
          ),
          'fat_g': ratio(
            combinedNutrients.valueOrZero(NutrientKey.fatG),
            goals.fatG,
          ),
        },
      },
      'meals': {
        for (final mt in MealType.values)
          mt.jsonKey: meals[mt]!.toJson(locale),
      },
      'meal_entries': allMealEntries.map((e) => e.toJson(locale)).toList(),
      'water_entries': waterEntries.map((w) => w.toJson()).toList(),
      'caffeine_entries': caffeineEntries.map((c) => c.toJson()).toList(),
    };
  }

  static double _round2(double v) => (v * 100).roundToDouble() / 100.0;
}

class NutritionService {
  static NutritionDaySummary summarizeDay({
    required String date,
    required List<FoodDiaryEntry> dayFoodEntries,
    required List<WaterEntry> dayWaterEntries,
    required List<CaffeineEntry> dayCaffeineEntries,
    required Map<String, FoodItem> foodCatalog,
    required NutritionGoals goals,
  }) {
    if (!IsoDate.isValid(date)) {
      throw FormatValidationException(
        'Invalid date "$date". Expected YYYY-MM-DD.',
      );
    }

    final buckets = <MealType, List<ResolvedMealEntry>>{
      for (final mt in MealType.values) mt: <ResolvedMealEntry>[],
    };
    final allResolved = <ResolvedMealEntry>[];
    var foodTotals = NutrientProfile.empty;

    final sortedFoods = List<FoodDiaryEntry>.from(dayFoodEntries)
      ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));

    for (final entry in sortedFoods) {
      final liveFood = foodCatalog[entry.foodId];
      final eq = entry.gramsOrMlEquivalent(liveFood);
      final nut = entry.computeNutrients(liveFood);
      final resolved = ResolvedMealEntry(
        entry: entry,
        food: liveFood,
        gramsOrMlEquivalent: eq,
        nutrients: nut,
      );
      buckets[entry.mealType]!.add(resolved);
      allResolved.add(resolved);
      foodTotals = foodTotals + nut;
    }

    final mealGroups = <MealType, MealGroupSummary>{};
    for (final mt in MealType.values) {
      final list = buckets[mt]!;
      var mtTotals = NutrientProfile.empty;
      for (final r in list) {
        mtTotals = mtTotals + r.nutrients;
      }
      mealGroups[mt] = MealGroupSummary(
        mealType: mt,
        entries: list,
        totals: mtTotals,
      );
    }

    final sortedWater = List<WaterEntry>.from(dayWaterEntries)
      ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
    var waterSum = 0.0;
    for (final w in sortedWater) {
      waterSum += w.amountMl;
    }

    final sortedCaffeine = List<CaffeineEntry>.from(dayCaffeineEntries)
      ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
    var directCaffSum = 0.0;
    for (final c in sortedCaffeine) {
      directCaffSum += c.amountMg;
    }

    final foodCaff = foodTotals.valueOrZero(NutrientKey.caffeineMg);
    final totalCaff = foodCaff + directCaffSum;
    final combined = directCaffSum > 0
        ? (foodTotals + NutrientProfile({NutrientKey.caffeineMg: directCaffSum}))
        : foodTotals;

    return NutritionDaySummary(
      date: date,
      foodNutrients: foodTotals,
      combinedNutrients: combined,
      waterMl: waterSum,
      caffeineFromFoodsMg: foodCaff,
      caffeineDirectMg: directCaffSum,
      totalCaffeineMg: totalCaff,
      goals: goals,
      meals: mealGroups,
      allMealEntries: allResolved,
      waterEntries: sortedWater,
      caffeineEntries: sortedCaffeine,
    );
  }
}
