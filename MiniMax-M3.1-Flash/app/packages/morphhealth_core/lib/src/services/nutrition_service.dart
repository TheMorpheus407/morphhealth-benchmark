import '../models/food.dart';
import '../models/journal.dart';
import '../models/nutrients.dart';
import '../models/records.dart';
import '../store/repository.dart';

/// Nutrition values of one calendar day.
class DayNutrition {
  const DayNutrition({
    required this.date,
    required this.entries,
    required this.intakes,
    required this.totals,
    required this.waterMl,
    required this.extraCaffeineMg,
  });

  final String date;
  final List<JournalEntry> entries;
  final List<IntakeEntry> intakes;

  /// Totals of the day. Energy in kcal/kJ, mass nutrients in grams.
  final NutrientProfile totals;

  /// Water in millilitres.
  final double waterMl;

  /// Caffeine added on top of the food, in milligrams.
  final double extraCaffeineMg;

  double get caloriesKcal => totals[Nutrients.energyKcal];
  double get proteinG => totals[Nutrients.protein];
  double get carbohydratesG => totals[Nutrients.carbohydrates];
  double get fatG => totals[Nutrients.fat];
  double get fiberG => totals[Nutrients.fiber];
  double get sugarsG => totals[Nutrients.sugars];
  double get saturatedFatG => totals[Nutrients.saturatedFat];
  double get saltG => totals[Nutrients.salt];

  /// Caffeine from food in milligrams.
  double get caffeineFromFoodMg => totals[Nutrients.caffeine] * 1000.0;

  /// Caffeine from food plus the extra caffeine, in milligrams.
  double get caffeineMg => caffeineFromFoodMg + extraCaffeineMg;

  bool get isEmpty => entries.isEmpty && intakes.isEmpty;

  /// Entries of one meal.
  List<JournalEntry> entriesForMeal(MealSlot meal) =>
      entries.where((JournalEntry e) => e.meal == meal).toList(growable: false);

  Map<String, dynamic> toJson() => <String, dynamic>{
        'date': date,
        'calories_kcal': caloriesKcal,
        'protein_g': proteinG,
        'carbohydrates_g': carbohydratesG,
        'fat_g': fatG,
        'saturated_fat_g': saturatedFatG,
        'sugars_g': sugarsG,
        'fiber_g': fiberG,
        'salt_g': saltG,
        'sodium_mg': totals[Nutrients.sodium] * 1000.0,
        'caffeine_mg': caffeineMg,
        'caffeine_from_food_mg': caffeineFromFoodMg,
        'water_ml': waterMl,
        'entry_count': entries.length,
        'intake_count': intakes.length,
        'nutrients': totals.toJson(),
        'entries': entries.map(_entryToJson).toList(growable: false),
        'water_entries': intakes
            .where((IntakeEntry e) => e.kind == IntakeKind.water)
            .map(_intakeToJson)
            .toList(growable: false),
        'caffeine_entries': intakes
            .where((IntakeEntry e) => e.kind == IntakeKind.caffeine)
            .map(_intakeToJson)
            .toList(growable: false),
      };

  static Map<String, dynamic> _entryToJson(JournalEntry entry) =>
      <String, dynamic>{
        'id': entry.id,
        'food_id': entry.foodId,
        'food_name': entry.foodName,
        if (entry.brand != null) 'brand': entry.brand,
        'quantity': entry.quantity,
        'unit': entry.unit.name,
        'meal': entry.meal.name,
        'date': entry.date,
        'logged_at_ms': entry.loggedAtMs,
        if (entry.portionLabel != null) 'portion_label': entry.portionLabel,
        if (entry.portionGrams != null) 'portion_grams': entry.portionGrams,
        if (entry.note != null) 'note': entry.note,
      };

  static Map<String, dynamic> _intakeToJson(IntakeEntry entry) =>
      <String, dynamic>{
        'id': entry.id,
        'kind': entry.kind.name,
        'amount': entry.amount,
        'unit': entry.kind == IntakeKind.water ? 'ml' : 'mg',
        'date': entry.date,
        'logged_at_ms': entry.loggedAtMs,
        if (entry.note != null) 'note': entry.note,
      };
}

/// Calculates the nutrition of a day, a period and the journal totals.
class NutritionService {
  NutritionService(this._repository);

  final HealthRepository _repository;

  /// Nutrition of a single calendar day.
  DayNutrition day(String date) {
    final List<JournalEntry> entries = _repository.journalEntries
        .where((JournalEntry e) => e.date == date)
        .toList(growable: false);
    final List<IntakeEntry> intakes = _repository.intakeEntries
        .where((IntakeEntry e) => e.date == date)
        .toList(growable: false);

    NutrientProfile totals = const NutrientProfile(<String, double>{});
    double water = 0;
    double extraCaffeine = 0;
    for (final JournalEntry entry in entries) {
      totals = totals + contributionOf(entry);
    }
    for (final IntakeEntry intake in intakes) {
      if (intake.kind == IntakeKind.water) {
        water += intake.amount;
      } else {
        extraCaffeine += intake.amount;
      }
    }
    return DayNutrition(
      date: date,
      entries: entries,
      intakes: intakes,
      totals: totals,
      waterMl: water,
      extraCaffeineMg: extraCaffeine,
    );
  }

  /// Nutrition of every day between [from] and [to] (inclusive).
  List<DayNutrition> days(String from, String to) {
    final List<String> dates = DateMath.range(from, to);
    return dates.map(day).toList(growable: false);
  }

  /// Sum of all nutrients between [from] and [to] (inclusive).
  NutrientProfile totalsBetween(String from, String to) {
    NutrientProfile sum = const NutrientProfile(<String, double>{});
    for (final DayNutrition day in days(from, to)) {
      sum = sum + day.totals;
    }
    return sum;
  }

  /// Nutrition contributed by a single journal entry.
  ///
  /// The live food is used when it still exists; otherwise the snapshot that
  /// was taken while logging keeps the numbers correct.
  NutrientProfile contributionOf(JournalEntry entry) {
    final NutrientProfile base = _baseProfile(entry);
    return base.scaled(gramsFor(entry) / 100.0);
  }

  /// Sum of one meal of a day.
  NutrientProfile totalsForMeal(DayNutrition day, MealSlot meal) {
    NutrientProfile sum = const NutrientProfile(<String, double>{});
    for (final JournalEntry entry in day.entries) {
      if (entry.meal != meal) continue;
      sum = sum + contributionOf(entry);
    }
    return sum;
  }

  /// Amount of a journal entry in grams.
  double gramsFor(JournalEntry entry) {
    switch (entry.unit) {
      case QuantityUnit.gram:
        return entry.quantity;
      case QuantityUnit.milliliter:
        return entry.quantity;
      case QuantityUnit.portion:
        final double? portionGrams = entry.portionGrams;
        if (portionGrams != null) return entry.quantity * portionGrams;
        final FoodItem? food = _repository.foodById(entry.foodId);
        if (food != null) {
          final String? label = entry.portionLabel;
          if (label != null) {
            for (final Portion portion in food.portions) {
              if (portion.label == label) {
                return entry.quantity * portion.amountGrams;
              }
            }
          }
          final double? serving = food.servingGrams;
          if (serving != null && serving > 0) return entry.quantity * serving;
        }
        return entry.quantity * 100.0;
    }
  }

  NutrientProfile _baseProfile(JournalEntry entry) {
    final FoodItem? food = _repository.foodById(entry.foodId);
    if (food != null) return food.nutrientsPer100;
    if (entry.nutrientsPer100Snapshot.isNotEmpty) {
      return NutrientProfile(entry.nutrientsPer100Snapshot);
    }
    return NutrientProfile.empty;
  }

  /// Number of days in [from, to] that contain at least one entry.
  int daysWithData(String from, String to) => days(from, to)
      .where((DayNutrition d) => !d.isEmpty)
      .length;

  /// Foods that were logged recently, newest first.
  List<FoodItem> recentlyLoggedFoods({int limit = 20}) {
    final Map<String, FoodItem> seen = <String, FoodItem>{};
    final Iterable<JournalEntry> entries = _repository.journalEntries.reversed;
    for (final JournalEntry entry in entries) {
      if (seen.containsKey(entry.foodId)) continue;
      final FoodItem? food = _repository.foodById(entry.foodId);
      if (food != null) seen[food.id] = food;
      if (seen.length >= limit) break;
    }
    return seen.values.toList(growable: false);
  }
}
