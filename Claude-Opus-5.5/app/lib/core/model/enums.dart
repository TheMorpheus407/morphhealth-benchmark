/// Enumerations of the MorphHealth data model and their stable JSON names.
library;

/// The four product areas. They can be shown or hidden on the overview.
enum Area {
  nutrition('nutrition'),
  cycle('cycle'),
  weight('weight'),
  symptoms('symptoms');

  const Area(this.json);
  final String json;

  static final Map<String, Area> byJson = {for (final v in values) v.json: v};
}

enum Meal {
  breakfast('breakfast'),
  lunch('lunch'),
  dinner('dinner'),
  snack('snack');

  const Meal(this.json);
  final String json;

  static final Map<String, Meal> byJson = {for (final v in values) v.json: v};

  /// A sensible default meal for a wall-clock time (minutes since midnight).
  static Meal suggestFor(int minutes) {
    if (minutes >= 4 * 60 && minutes < 10 * 60 + 30) return Meal.breakfast;
    if (minutes >= 10 * 60 + 30 && minutes < 14 * 60 + 30) return Meal.lunch;
    if (minutes >= 17 * 60 + 30 && minutes < 22 * 60) return Meal.dinner;
    return Meal.snack;
  }
}

/// Reference quantity of a food's nutrient values: per 100 g or per 100 ml.
enum Basis {
  g('g'),
  ml('ml');

  const Basis(this.json);
  final String json;

  static final Map<String, Basis> byJson = {for (final v in values) v.json: v};
}

/// Unit of a logged amount.
enum AmountUnit {
  g('g'),
  ml('ml'),
  portion('portion');

  const AmountUnit(this.json);
  final String json;

  static final Map<String, AmountUnit> byJson = {
    for (final v in values) v.json: v,
  };
}

enum FoodSource {
  custom('custom'),
  openFoodFacts('open_food_facts');

  const FoodSource(this.json);
  final String json;

  static final Map<String, FoodSource> byJson = {
    for (final v in values) v.json: v,
  };
}

/// Bleeding intensity, from spotting to heavy.
enum Flow {
  spotting('spotting'),
  light('light'),
  medium('medium'),
  heavy('heavy');

  const Flow(this.json);
  final String json;

  static final Map<String, Flow> byJson = {for (final v in values) v.json: v};
}

enum WeightUnit {
  kg('kg'),
  lb('lb');

  const WeightUnit(this.json);
  final String json;

  static final Map<String, WeightUnit> byJson = {
    for (final v in values) v.json: v,
  };

  /// Exact definition of the international avoirdupois pound.
  static const double kgPerLb = 0.45359237;

  double toKg(double value) => this == WeightUnit.kg ? value : value * kgPerLb;
  double fromKg(double kg) => this == WeightUnit.kg ? kg : kg / kgPerLb;
}

enum AppLanguage {
  de('de'),
  en('en');

  const AppLanguage(this.json);
  final String json;

  static final Map<String, AppLanguage> byJson = {
    for (final v in values) v.json: v,
  };
}
