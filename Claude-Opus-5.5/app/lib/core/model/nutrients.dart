/// The nutrient catalogue of MorphHealth.
///
/// Every nutrient has a stable key that includes its unit (for example
/// `vitamin_c_mg`). Food values are stored per 100 g or per 100 ml of the
/// food's basis unit; diary values are derived from the logged amount.
library;

enum NutrientGroup { energy, macro, detail, vitamin, mineral }

class Nutrient {
  const Nutrient({
    required this.key,
    required this.unit,
    required this.group,
    required this.offIds,
    required this.fromGrams,
    required this.decimals,
    required this.maxPer100,
  });

  /// Stable identifier used in the data format, e.g. `protein_g`.
  final String key;

  /// Display and storage unit: `kcal`, `g`, `mg` or `µg`.
  final String unit;

  final NutrientGroup group;

  /// Open Food Facts nutrient ids, in order of preference.
  final List<String> offIds;

  /// Factor converting Open Food Facts' normalized gram values into [unit].
  /// Not used for energy (which is handled separately).
  final double fromGrams;

  /// Decimal places used when displaying values.
  final int decimals;

  /// Largest plausible value per 100 g/ml; larger values are rejected.
  final double maxPer100;

  bool get isMicronutrient =>
      group == NutrientGroup.vitamin || group == NutrientGroup.mineral;
}

class Nutrients {
  const Nutrients._();

  static const energy = Nutrient(
    key: 'energy_kcal',
    unit: 'kcal',
    group: NutrientGroup.energy,
    offIds: ['energy-kcal'],
    fromGrams: 1,
    decimals: 0,
    maxPer100: 1000,
  );
  static const protein = Nutrient(
    key: 'protein_g',
    unit: 'g',
    group: NutrientGroup.macro,
    offIds: ['proteins'],
    fromGrams: 1,
    decimals: 1,
    maxPer100: 100,
  );
  static const carbohydrates = Nutrient(
    key: 'carbohydrates_g',
    unit: 'g',
    group: NutrientGroup.macro,
    offIds: ['carbohydrates'],
    fromGrams: 1,
    decimals: 1,
    maxPer100: 100,
  );
  static const fat = Nutrient(
    key: 'fat_g',
    unit: 'g',
    group: NutrientGroup.macro,
    offIds: ['fat'],
    fromGrams: 1,
    decimals: 1,
    maxPer100: 100,
  );
  static const saturatedFat = Nutrient(
    key: 'saturated_fat_g',
    unit: 'g',
    group: NutrientGroup.detail,
    offIds: ['saturated-fat'],
    fromGrams: 1,
    decimals: 1,
    maxPer100: 100,
  );
  static const sugars = Nutrient(
    key: 'sugars_g',
    unit: 'g',
    group: NutrientGroup.detail,
    offIds: ['sugars'],
    fromGrams: 1,
    decimals: 1,
    maxPer100: 100,
  );
  static const fiber = Nutrient(
    key: 'fiber_g',
    unit: 'g',
    group: NutrientGroup.detail,
    offIds: ['fiber'],
    fromGrams: 1,
    decimals: 1,
    maxPer100: 100,
  );
  static const salt = Nutrient(
    key: 'salt_g',
    unit: 'g',
    group: NutrientGroup.detail,
    offIds: ['salt'],
    fromGrams: 1,
    decimals: 2,
    maxPer100: 100,
  );
  static const sodium = Nutrient(
    key: 'sodium_mg',
    unit: 'mg',
    group: NutrientGroup.detail,
    offIds: ['sodium'],
    fromGrams: 1000,
    decimals: 0,
    maxPer100: 40000,
  );
  static const caffeine = Nutrient(
    key: 'caffeine_mg',
    unit: 'mg',
    group: NutrientGroup.detail,
    offIds: ['caffeine'],
    fromGrams: 1000,
    decimals: 0,
    maxPer100: 100000,
  );

  static const vitaminA = Nutrient(
    key: 'vitamin_a_ug',
    unit: 'µg',
    group: NutrientGroup.vitamin,
    offIds: ['vitamin-a'],
    fromGrams: 1e6,
    decimals: 0,
    maxPer100: 1e8,
  );
  static const vitaminC = Nutrient(
    key: 'vitamin_c_mg',
    unit: 'mg',
    group: NutrientGroup.vitamin,
    offIds: ['vitamin-c'],
    fromGrams: 1000,
    decimals: 1,
    maxPer100: 1e5,
  );
  static const vitaminD = Nutrient(
    key: 'vitamin_d_ug',
    unit: 'µg',
    group: NutrientGroup.vitamin,
    offIds: ['vitamin-d'],
    fromGrams: 1e6,
    decimals: 1,
    maxPer100: 1e8,
  );
  static const vitaminE = Nutrient(
    key: 'vitamin_e_mg',
    unit: 'mg',
    group: NutrientGroup.vitamin,
    offIds: ['vitamin-e'],
    fromGrams: 1000,
    decimals: 1,
    maxPer100: 1e5,
  );
  static const vitaminK = Nutrient(
    key: 'vitamin_k_ug',
    unit: 'µg',
    group: NutrientGroup.vitamin,
    offIds: ['vitamin-k', 'phylloquinone'],
    fromGrams: 1e6,
    decimals: 1,
    maxPer100: 1e8,
  );
  static const vitaminB1 = Nutrient(
    key: 'vitamin_b1_mg',
    unit: 'mg',
    group: NutrientGroup.vitamin,
    offIds: ['vitamin-b1'],
    fromGrams: 1000,
    decimals: 2,
    maxPer100: 1e5,
  );
  static const vitaminB2 = Nutrient(
    key: 'vitamin_b2_mg',
    unit: 'mg',
    group: NutrientGroup.vitamin,
    offIds: ['vitamin-b2'],
    fromGrams: 1000,
    decimals: 2,
    maxPer100: 1e5,
  );
  static const vitaminB3 = Nutrient(
    key: 'vitamin_b3_mg',
    unit: 'mg',
    group: NutrientGroup.vitamin,
    offIds: ['vitamin-pp', 'vitamin-b3'],
    fromGrams: 1000,
    decimals: 1,
    maxPer100: 1e5,
  );
  static const vitaminB5 = Nutrient(
    key: 'vitamin_b5_mg',
    unit: 'mg',
    group: NutrientGroup.vitamin,
    offIds: ['pantothenic-acid', 'vitamin-b5'],
    fromGrams: 1000,
    decimals: 2,
    maxPer100: 1e5,
  );
  static const vitaminB6 = Nutrient(
    key: 'vitamin_b6_mg',
    unit: 'mg',
    group: NutrientGroup.vitamin,
    offIds: ['vitamin-b6'],
    fromGrams: 1000,
    decimals: 2,
    maxPer100: 1e5,
  );
  static const vitaminB7 = Nutrient(
    key: 'vitamin_b7_ug',
    unit: 'µg',
    group: NutrientGroup.vitamin,
    offIds: ['biotin', 'vitamin-b7'],
    fromGrams: 1e6,
    decimals: 1,
    maxPer100: 1e8,
  );
  static const vitaminB9 = Nutrient(
    key: 'vitamin_b9_ug',
    unit: 'µg',
    group: NutrientGroup.vitamin,
    offIds: ['vitamin-b9', 'folates', 'folic-acid'],
    fromGrams: 1e6,
    decimals: 0,
    maxPer100: 1e8,
  );
  static const vitaminB12 = Nutrient(
    key: 'vitamin_b12_ug',
    unit: 'µg',
    group: NutrientGroup.vitamin,
    offIds: ['vitamin-b12'],
    fromGrams: 1e6,
    decimals: 2,
    maxPer100: 1e8,
  );

  static const calcium = Nutrient(
    key: 'calcium_mg',
    unit: 'mg',
    group: NutrientGroup.mineral,
    offIds: ['calcium'],
    fromGrams: 1000,
    decimals: 0,
    maxPer100: 1e5,
  );
  static const iron = Nutrient(
    key: 'iron_mg',
    unit: 'mg',
    group: NutrientGroup.mineral,
    offIds: ['iron'],
    fromGrams: 1000,
    decimals: 1,
    maxPer100: 1e5,
  );
  static const magnesium = Nutrient(
    key: 'magnesium_mg',
    unit: 'mg',
    group: NutrientGroup.mineral,
    offIds: ['magnesium'],
    fromGrams: 1000,
    decimals: 0,
    maxPer100: 1e5,
  );
  static const potassium = Nutrient(
    key: 'potassium_mg',
    unit: 'mg',
    group: NutrientGroup.mineral,
    offIds: ['potassium'],
    fromGrams: 1000,
    decimals: 0,
    maxPer100: 1e5,
  );
  static const zinc = Nutrient(
    key: 'zinc_mg',
    unit: 'mg',
    group: NutrientGroup.mineral,
    offIds: ['zinc'],
    fromGrams: 1000,
    decimals: 1,
    maxPer100: 1e5,
  );
  static const selenium = Nutrient(
    key: 'selenium_ug',
    unit: 'µg',
    group: NutrientGroup.mineral,
    offIds: ['selenium'],
    fromGrams: 1e6,
    decimals: 1,
    maxPer100: 1e8,
  );
  static const iodine = Nutrient(
    key: 'iodine_ug',
    unit: 'µg',
    group: NutrientGroup.mineral,
    offIds: ['iodine'],
    fromGrams: 1e6,
    decimals: 1,
    maxPer100: 1e8,
  );
  static const phosphorus = Nutrient(
    key: 'phosphorus_mg',
    unit: 'mg',
    group: NutrientGroup.mineral,
    offIds: ['phosphorus'],
    fromGrams: 1000,
    decimals: 0,
    maxPer100: 1e5,
  );

  /// All nutrients in display order.
  static const List<Nutrient> all = [
    energy,
    protein,
    carbohydrates,
    fat,
    saturatedFat,
    sugars,
    fiber,
    salt,
    sodium,
    caffeine,
    vitaminA,
    vitaminC,
    vitaminD,
    vitaminE,
    vitaminK,
    vitaminB1,
    vitaminB2,
    vitaminB3,
    vitaminB5,
    vitaminB6,
    vitaminB7,
    vitaminB9,
    vitaminB12,
    calcium,
    iron,
    magnesium,
    potassium,
    zinc,
    selenium,
    iodine,
    phosphorus,
  ];

  static final Map<String, Nutrient> byKey = {for (final n in all) n.key: n};

  static Nutrient? tryGet(String key) => byKey[key];

  static Iterable<Nutrient> inGroup(NutrientGroup group) =>
      all.where((n) => n.group == group);

  /// Salt (g) = sodium (g) × 2.5, the conversion used on EU food labels.
  static const double saltPerSodium = 2.5;

  /// kcal = kJ / 4.184
  static const double kjPerKcal = 4.184;

  /// Fills in salt from sodium or sodium from salt when only one is known,
  /// and drops values that are negative, non-finite or implausibly large.
  static Map<String, double> normalize(Map<String, double> values) {
    final result = <String, double>{};
    values.forEach((key, value) {
      final n = byKey[key];
      if (n == null) return;
      if (value.isNaN || value.isInfinite || value < 0) return;
      if (value > n.maxPer100) return;
      result[key] = value;
    });
    final saltG = result[salt.key];
    final sodiumMg = result[sodium.key];
    if (saltG != null && sodiumMg == null) {
      result[sodium.key] = _round(saltG / saltPerSodium * 1000, 6);
    } else if (sodiumMg != null && saltG == null) {
      result[salt.key] = _round(sodiumMg / 1000 * saltPerSodium, 6);
    }
    return result;
  }

  static double _round(double value, int decimals) {
    final text = value.toStringAsFixed(decimals);
    return double.parse(text);
  }
}
