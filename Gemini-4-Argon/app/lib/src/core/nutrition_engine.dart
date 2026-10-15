import 'models.dart';
import 'nutrients.dart';

class MealSummary {
  final String meal;
  final List<FoodDiaryEntry> entries;
  final NutrientProfile totals;

  const MealSummary({
    required this.meal,
    required this.entries,
    required this.totals,
  });

  Map<String, dynamic> toJson() => {
        'meal': meal,
        'entry_count': entries.length,
        'calories_kcal':
            (totals.caloriesKcal * 10).roundToDouble() / 10.0,
        'protein_g': (totals.proteinG * 10).roundToDouble() / 10.0,
        'carbohydrates_g':
            (totals.carbohydratesG * 10).roundToDouble() / 10.0,
        'fat_g': (totals.fatG * 10).roundToDouble() / 10.0,
        'nutrients': totals.toJson(),
        'entries': entries.map((e) => e.toJson()).toList(),
      };
}

class NutritionDaySummary {
  final String date;
  final List<FoodDiaryEntry> foodEntries;
  final List<WaterEntry> waterEntries;
  final List<CaffeineEntry> caffeineEntries;
  final Map<String, MealSummary> meals;
  final NutrientProfile foodNutrients;
  final NutrientProfile totalNutrients; // includes standalone caffeine_mg
  final double waterMl;
  final double caffeineFromFoodMg;
  final double caffeineFromDrinksMg;
  final double totalCaffeineMg;
  final NutritionGoals goals;

  const NutritionDaySummary({
    required this.date,
    required this.foodEntries,
    required this.waterEntries,
    required this.caffeineEntries,
    required this.meals,
    required this.foodNutrients,
    required this.totalNutrients,
    required this.waterMl,
    required this.caffeineFromFoodMg,
    required this.caffeineFromDrinksMg,
    required this.totalCaffeineMg,
    required this.goals,
  });

  Map<String, dynamic> toJson() {
    final flatNutrients = totalNutrients.toJson();
    final grouped = totalNutrients.toGroupedJson();
    final roundedWater = (waterMl * 10).roundToDouble() / 10.0;
    final roundedCaffeine = (totalCaffeineMg * 10).roundToDouble() / 10.0;
    final roundedCafFood = (caffeineFromFoodMg * 10).roundToDouble() / 10.0;
    final roundedCafDrinks = (caffeineFromDrinksMg * 10).roundToDouble() / 10.0;

    return {
      'date': date,
      'calories_kcal': flatNutrients['calories_kcal'] ?? 0.0,
      'protein_g': flatNutrients['protein_g'] ?? 0.0,
      'carbohydrates_g': flatNutrients['carbohydrates_g'] ?? 0.0,
      'fat_g': flatNutrients['fat_g'] ?? 0.0,
      'water_ml': roundedWater,
      'caffeine_mg': roundedCaffeine,
      'caffeine_from_food_mg': roundedCafFood,
      'caffeine_from_drinks_mg': roundedCafDrinks,
      'totals': {
        ...flatNutrients,
        'water_ml': roundedWater,
        'caffeine_mg': roundedCaffeine,
        'caffeine_from_food_mg': roundedCafFood,
        'caffeine_from_drinks_mg': roundedCafDrinks,
        ...grouped,
      },
      'nutrients': flatNutrients,
      'macros': grouped['macros'],
      'extended': grouped['extended'],
      'vitamins': grouped['vitamins'],
      'minerals': grouped['minerals'],
      'goals': goals.toJson(),
      'meals': {
        for (final m in MealType.all) m: meals[m]!.toJson(),
      },
      'food_entries': foodEntries.map((e) => e.toJson()).toList(),
      'water_entries': waterEntries.map((e) => e.toJson()).toList(),
      'caffeine_entries': caffeineEntries.map((e) => e.toJson()).toList(),
    };
  }
}

class NutritionEngine {
  static NutritionDaySummary summarizeDay({
    required String date,
    required List<FoodDiaryEntry> foodEntries,
    required List<WaterEntry> waterEntries,
    required List<CaffeineEntry> caffeineEntries,
    required NutritionGoals goals,
  }) {
    final dayFoods = foodEntries.where((e) => e.date == date).toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final dayWaters = waterEntries.where((e) => e.date == date).toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    final dayCaffeines = caffeineEntries.where((e) => e.date == date).toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final mealMap = <String, MealSummary>{};
    var foodProfile = NutrientProfile();

    for (final mealKey in MealType.all) {
      final mealItems = dayFoods
          .where((e) => MealType.normalize(e.meal) == mealKey)
          .toList();
      var mealProfile = NutrientProfile();
      for (final item in mealItems) {
        final n = item.nutrients;
        mealProfile = mealProfile + n;
        foodProfile = foodProfile + n;
      }
      mealMap[mealKey] = MealSummary(
        meal: mealKey,
        entries: mealItems,
        totals: mealProfile,
      );
    }

    double waterTotal = 0.0;
    for (final w in dayWaters) {
      waterTotal += w.amountMl;
    }

    double drinksCaffeineTotal = 0.0;
    for (final c in dayCaffeines) {
      drinksCaffeineTotal += c.amountMg;
    }

    final foodCaffeine = foodProfile.caffeineMg;
    final totalCaffeine = foodCaffeine + drinksCaffeineTotal;
    final totalProfile =
        foodProfile.copyWithValue('caffeine_mg', totalCaffeine);

    return NutritionDaySummary(
      date: date,
      foodEntries: dayFoods,
      waterEntries: dayWaters,
      caffeineEntries: dayCaffeines,
      meals: mealMap,
      foodNutrients: foodProfile,
      totalNutrients: totalProfile,
      waterMl: waterTotal,
      caffeineFromFoodMg: foodCaffeine,
      caffeineFromDrinksMg: drinksCaffeineTotal,
      totalCaffeineMg: totalCaffeine,
      goals: goals,
    );
  }
}
