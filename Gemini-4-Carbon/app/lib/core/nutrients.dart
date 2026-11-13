/// Complete macro-, extended-, and micronutrient taxonomy (31 nutrients).
///
/// Covers all nutrients required by P03:
/// - Calories, Protein, Carbohydrates, Fat
/// - Saturated Fat, Sugar, Fiber, Salt, Sodium, Caffeine
/// - Vitamins A, C, D, E, K, B1, B2, B3, B5, B6, B7, B9, B12
/// - Minerals Calcium, Iron, Magnesium, Potassium, Zinc, Selenium, Iodine, Phosphorus
library;

enum NutrientCategory {
  macro,
  extended,
  vitamin,
  mineral,
}

enum NutrientKey {
  // Core Macros (4)
  caloriesKcal(
    jsonKey: 'calories_kcal',
    unit: 'kcal',
    category: NutrientCategory.macro,
    labelDe: 'Kalorien',
    labelEn: 'Calories',
    shortDe: 'Kcal',
    shortEn: 'Kcal',
    decimals: 0,
    gramsToUnitFactor: 1.0,
    offKeys: ['energy-kcal'],
  ),
  proteinG(
    jsonKey: 'protein_g',
    unit: 'g',
    category: NutrientCategory.macro,
    labelDe: 'Protein',
    labelEn: 'Protein',
    shortDe: 'Protein',
    shortEn: 'Protein',
    decimals: 1,
    gramsToUnitFactor: 1.0,
    offKeys: ['proteins'],
  ),
  carbsG(
    jsonKey: 'carbs_g',
    unit: 'g',
    category: NutrientCategory.macro,
    labelDe: 'Kohlenhydrate',
    labelEn: 'Carbohydrates',
    shortDe: 'KH',
    shortEn: 'Carbs',
    decimals: 1,
    gramsToUnitFactor: 1.0,
    offKeys: ['carbohydrates'],
  ),
  fatG(
    jsonKey: 'fat_g',
    unit: 'g',
    category: NutrientCategory.macro,
    labelDe: 'Fett',
    labelEn: 'Fat',
    shortDe: 'Fett',
    shortEn: 'Fat',
    decimals: 1,
    gramsToUnitFactor: 1.0,
    offKeys: ['fat'],
  ),

  // Extended Nutrients (6)
  saturatedFatG(
    jsonKey: 'saturated_fat_g',
    unit: 'g',
    category: NutrientCategory.extended,
    labelDe: 'Gesättigte Fettsäuren',
    labelEn: 'Saturated fat',
    shortDe: 'Ges. Fett',
    shortEn: 'Sat. fat',
    decimals: 1,
    gramsToUnitFactor: 1.0,
    offKeys: ['saturated-fat'],
  ),
  sugarG(
    jsonKey: 'sugar_g',
    unit: 'g',
    category: NutrientCategory.extended,
    labelDe: 'Zucker',
    labelEn: 'Sugars',
    shortDe: 'Zucker',
    shortEn: 'Sugar',
    decimals: 1,
    gramsToUnitFactor: 1.0,
    offKeys: ['sugars'],
  ),
  fiberG(
    jsonKey: 'fiber_g',
    unit: 'g',
    category: NutrientCategory.extended,
    labelDe: 'Ballaststoffe',
    labelEn: 'Fiber',
    shortDe: 'Ballastst.',
    shortEn: 'Fiber',
    decimals: 1,
    gramsToUnitFactor: 1.0,
    offKeys: ['fiber'],
  ),
  saltG(
    jsonKey: 'salt_g',
    unit: 'g',
    category: NutrientCategory.extended,
    labelDe: 'Salz',
    labelEn: 'Salt',
    shortDe: 'Salz',
    shortEn: 'Salt',
    decimals: 2,
    gramsToUnitFactor: 1.0,
    offKeys: ['salt'],
  ),
  sodiumMg(
    jsonKey: 'sodium_mg',
    unit: 'mg',
    category: NutrientCategory.extended,
    labelDe: 'Natrium',
    labelEn: 'Sodium',
    shortDe: 'Natrium',
    shortEn: 'Sodium',
    decimals: 1,
    gramsToUnitFactor: 1000.0,
    offKeys: ['sodium'],
  ),
  caffeineMg(
    jsonKey: 'caffeine_mg',
    unit: 'mg',
    category: NutrientCategory.extended,
    labelDe: 'Koffein',
    labelEn: 'Caffeine',
    shortDe: 'Koffein',
    shortEn: 'Caffeine',
    decimals: 1,
    gramsToUnitFactor: 1000.0,
    offKeys: ['caffeine'],
  ),

  // Vitamins (13)
  vitaminAUg(
    jsonKey: 'vitamin_a_ug',
    unit: 'µg',
    category: NutrientCategory.vitamin,
    labelDe: 'Vitamin A',
    labelEn: 'Vitamin A',
    shortDe: 'Vit. A',
    shortEn: 'Vit. A',
    decimals: 1,
    gramsToUnitFactor: 1000000.0,
    offKeys: ['vitamin-a', 'retinol'],
  ),
  vitaminCMg(
    jsonKey: 'vitamin_c_mg',
    unit: 'mg',
    category: NutrientCategory.vitamin,
    labelDe: 'Vitamin C',
    labelEn: 'Vitamin C',
    shortDe: 'Vit. C',
    shortEn: 'Vit. C',
    decimals: 1,
    gramsToUnitFactor: 1000.0,
    offKeys: ['vitamin-c', 'ascorbic-acid'],
  ),
  vitaminDUg(
    jsonKey: 'vitamin_d_ug',
    unit: 'µg',
    category: NutrientCategory.vitamin,
    labelDe: 'Vitamin D',
    labelEn: 'Vitamin D',
    shortDe: 'Vit. D',
    shortEn: 'Vit. D',
    decimals: 2,
    gramsToUnitFactor: 1000000.0,
    offKeys: ['vitamin-d', 'cholecalciferol'],
  ),
  vitaminEMg(
    jsonKey: 'vitamin_e_mg',
    unit: 'mg',
    category: NutrientCategory.vitamin,
    labelDe: 'Vitamin E',
    labelEn: 'Vitamin E',
    shortDe: 'Vit. E',
    shortEn: 'Vit. E',
    decimals: 2,
    gramsToUnitFactor: 1000.0,
    offKeys: ['vitamin-e', 'tocopherol'],
  ),
  vitaminKUg(
    jsonKey: 'vitamin_k_ug',
    unit: 'µg',
    category: NutrientCategory.vitamin,
    labelDe: 'Vitamin K',
    labelEn: 'Vitamin K',
    shortDe: 'Vit. K',
    shortEn: 'Vit. K',
    decimals: 1,
    gramsToUnitFactor: 1000000.0,
    offKeys: ['vitamin-k', 'phylloquinone', 'vitamin-k1'],
  ),
  vitaminB1Mg(
    jsonKey: 'vitamin_b1_mg',
    unit: 'mg',
    category: NutrientCategory.vitamin,
    labelDe: 'Vitamin B1 (Thiamin)',
    labelEn: 'Vitamin B1 (Thiamin)',
    shortDe: 'Vit. B1',
    shortEn: 'Vit. B1',
    decimals: 2,
    gramsToUnitFactor: 1000.0,
    offKeys: ['vitamin-b1', 'thiamin'],
  ),
  vitaminB2Mg(
    jsonKey: 'vitamin_b2_mg',
    unit: 'mg',
    category: NutrientCategory.vitamin,
    labelDe: 'Vitamin B2 (Riboflavin)',
    labelEn: 'Vitamin B2 (Riboflavin)',
    shortDe: 'Vit. B2',
    shortEn: 'Vit. B2',
    decimals: 2,
    gramsToUnitFactor: 1000.0,
    offKeys: ['vitamin-b2', 'riboflavin'],
  ),
  vitaminB3Mg(
    jsonKey: 'vitamin_b3_mg',
    unit: 'mg',
    category: NutrientCategory.vitamin,
    labelDe: 'Vitamin B3 (Niacin)',
    labelEn: 'Vitamin B3 (Niacin)',
    shortDe: 'Vit. B3',
    shortEn: 'Vit. B3',
    decimals: 2,
    gramsToUnitFactor: 1000.0,
    offKeys: ['vitamin-pp', 'vitamin-b3', 'niacin'],
  ),
  vitaminB5Mg(
    jsonKey: 'vitamin_b5_mg',
    unit: 'mg',
    category: NutrientCategory.vitamin,
    labelDe: 'Vitamin B5 (Pantothensäure)',
    labelEn: 'Vitamin B5 (Pantothenic acid)',
    shortDe: 'Vit. B5',
    shortEn: 'Vit. B5',
    decimals: 2,
    gramsToUnitFactor: 1000.0,
    offKeys: ['pantothenic-acid', 'vitamin-b5'],
  ),
  vitaminB6Mg(
    jsonKey: 'vitamin_b6_mg',
    unit: 'mg',
    category: NutrientCategory.vitamin,
    labelDe: 'Vitamin B6',
    labelEn: 'Vitamin B6',
    shortDe: 'Vit. B6',
    shortEn: 'Vit. B6',
    decimals: 2,
    gramsToUnitFactor: 1000.0,
    offKeys: ['vitamin-b6', 'pyridoxine'],
  ),
  vitaminB7Ug(
    jsonKey: 'vitamin_b7_ug',
    unit: 'µg',
    category: NutrientCategory.vitamin,
    labelDe: 'Vitamin B7 (Biotin)',
    labelEn: 'Vitamin B7 (Biotin)',
    shortDe: 'Vit. B7',
    shortEn: 'Vit. B7',
    decimals: 1,
    gramsToUnitFactor: 1000000.0,
    offKeys: ['biotin', 'vitamin-b7', 'vitamin-b8'],
  ),
  vitaminB9Ug(
    jsonKey: 'vitamin_b9_ug',
    unit: 'µg',
    category: NutrientCategory.vitamin,
    labelDe: 'Vitamin B9 (Folsäure)',
    labelEn: 'Vitamin B9 (Folate)',
    shortDe: 'Vit. B9',
    shortEn: 'Vit. B9',
    decimals: 1,
    gramsToUnitFactor: 1000000.0,
    offKeys: ['vitamin-b9', 'folates', 'folic-acid'],
  ),
  vitaminB12Ug(
    jsonKey: 'vitamin_b12_ug',
    unit: 'µg',
    category: NutrientCategory.vitamin,
    labelDe: 'Vitamin B12',
    labelEn: 'Vitamin B12',
    shortDe: 'Vit. B12',
    shortEn: 'Vit. B12',
    decimals: 2,
    gramsToUnitFactor: 1000000.0,
    offKeys: ['vitamin-b12', 'cobalamin'],
  ),

  // Minerals (8)
  calciumMg(
    jsonKey: 'calcium_mg',
    unit: 'mg',
    category: NutrientCategory.mineral,
    labelDe: 'Kalzium',
    labelEn: 'Calcium',
    shortDe: 'Kalzium',
    shortEn: 'Calcium',
    decimals: 1,
    gramsToUnitFactor: 1000.0,
    offKeys: ['calcium'],
  ),
  ironMg(
    jsonKey: 'iron_mg',
    unit: 'mg',
    category: NutrientCategory.mineral,
    labelDe: 'Eisen',
    labelEn: 'Iron',
    shortDe: 'Eisen',
    shortEn: 'Iron',
    decimals: 2,
    gramsToUnitFactor: 1000.0,
    offKeys: ['iron'],
  ),
  magnesiumMg(
    jsonKey: 'magnesium_mg',
    unit: 'mg',
    category: NutrientCategory.mineral,
    labelDe: 'Magnesium',
    labelEn: 'Magnesium',
    shortDe: 'Magnesium',
    shortEn: 'Magnesium',
    decimals: 1,
    gramsToUnitFactor: 1000.0,
    offKeys: ['magnesium'],
  ),
  potassiumMg(
    jsonKey: 'potassium_mg',
    unit: 'mg',
    category: NutrientCategory.mineral,
    labelDe: 'Kalium',
    labelEn: 'Potassium',
    shortDe: 'Kalium',
    shortEn: 'Potassium',
    decimals: 1,
    gramsToUnitFactor: 1000.0,
    offKeys: ['potassium'],
  ),
  zincMg(
    jsonKey: 'zinc_mg',
    unit: 'mg',
    category: NutrientCategory.mineral,
    labelDe: 'Zink',
    labelEn: 'Zinc',
    shortDe: 'Zink',
    shortEn: 'Zinc',
    decimals: 2,
    gramsToUnitFactor: 1000.0,
    offKeys: ['zinc'],
  ),
  seleniumUg(
    jsonKey: 'selenium_ug',
    unit: 'µg',
    category: NutrientCategory.mineral,
    labelDe: 'Selen',
    labelEn: 'Selenium',
    shortDe: 'Selen',
    shortEn: 'Selenium',
    decimals: 1,
    gramsToUnitFactor: 1000000.0,
    offKeys: ['selenium'],
  ),
  iodineUg(
    jsonKey: 'iodine_ug',
    unit: 'µg',
    category: NutrientCategory.mineral,
    labelDe: 'Jod',
    labelEn: 'Iodine',
    shortDe: 'Jod',
    shortEn: 'Iodine',
    decimals: 1,
    gramsToUnitFactor: 1000000.0,
    offKeys: ['iodine'],
  ),
  phosphorusMg(
    jsonKey: 'phosphorus_mg',
    unit: 'mg',
    category: NutrientCategory.mineral,
    labelDe: 'Phosphor',
    labelEn: 'Phosphorus',
    shortDe: 'Phosphor',
    shortEn: 'Phosphorus',
    decimals: 1,
    gramsToUnitFactor: 1000.0,
    offKeys: ['phosphorus'],
  );

  final String jsonKey;
  final String unit;
  final NutrientCategory category;
  final String labelDe;
  final String labelEn;
  final String shortDe;
  final String shortEn;
  final int decimals;
  final double gramsToUnitFactor;
  final List<String> offKeys;

  const NutrientKey({
    required this.jsonKey,
    required this.unit,
    required this.category,
    required this.labelDe,
    required this.labelEn,
    required this.shortDe,
    required this.shortEn,
    required this.decimals,
    required this.gramsToUnitFactor,
    required this.offKeys,
  });

  String label(String localeCode) => localeCode == 'en' ? labelEn : labelDe;
  String shortLabel(String localeCode) => localeCode == 'en' ? shortEn : shortDe;

  static final Map<String, NutrientKey> byJsonKey = {
    for (final k in NutrientKey.values) k.jsonKey: k,
  };

  static List<NutrientKey> byCategory(NutrientCategory category) =>
      NutrientKey.values.where((k) => k.category == category).toList(growable: false);

  /// Converts a mass value from an Open Food Facts unit ('g', 'mg', 'µg'/'ug'/'mcg')
  /// into this nutrient's canonical display/storage unit.
  double convertFromOffUnit(double rawValue, String? offUnit) {
    if (this == NutrientKey.caloriesKcal) {
      final u = (offUnit ?? 'kcal').trim().toLowerCase();
      if (u == 'kj') return rawValue / 4.184;
      return rawValue;
    }
    final u = (offUnit ?? 'g').trim().toLowerCase();
    double grams;
    if (u == 'g' || u.isEmpty) {
      grams = rawValue;
    } else if (u == 'mg') {
      grams = rawValue / 1000.0;
    } else if (u == 'µg' || u == 'μg' || u == 'ug' || u == 'mcg') {
      grams = rawValue / 1000000.0;
    } else if (u == 'kg' || u == 'l') {
      grams = rawValue * 1000.0;
    } else {
      grams = rawValue;
    }
    return grams * gramsToUnitFactor;
  }
}

/// Immutable nutrient map supporting sparse food profiles and dense daily totals.
class NutrientProfile {
  final Map<NutrientKey, double> _values;

  const NutrientProfile([this._values = const {}]);

  static const NutrientProfile empty = NutrientProfile();

  double? operator [](NutrientKey key) => _values[key];

  double valueOrZero(NutrientKey key) => _values[key] ?? 0.0;

  bool containsKey(NutrientKey key) => _values.containsKey(key);

  bool get isEmpty => _values.isEmpty;

  Iterable<MapEntry<NutrientKey, double>> get entries => _values.entries;

  NutrientProfile scale(double factor) {
    if (_values.isEmpty) return empty;
    final next = <NutrientKey, double>{};
    _values.forEach((k, v) {
      next[k] = _cleanDouble(v * factor);
    });
    return NutrientProfile(next);
  }

  NutrientProfile operator +(NutrientProfile other) {
    if (_values.isEmpty) return other;
    if (other._values.isEmpty) return this;
    final next = Map<NutrientKey, double>.from(_values);
    other._values.forEach((k, v) {
      next[k] = _cleanDouble((next[k] ?? 0.0) + v);
    });
    return NutrientProfile(next);
  }

  /// Sparse JSON (only known keys; used on FoodItem so unknown micronutrients remain null/absent).
  Map<String, dynamic> toSparseJson() {
    final out = <String, dynamic>{};
    for (final k in NutrientKey.values) {
      final val = _values[k];
      if (val != null && val.isFinite && val >= 0) {
        out[k.jsonKey] = _round6(val);
      }
    }
    return out;
  }

  /// Dense JSON (all 31 nutrients present with numeric values; used on daily totals & entries).
  Map<String, double> toDenseJson() {
    return {
      for (final k in NutrientKey.values) k.jsonKey: _round4(_values[k] ?? 0.0),
    };
  }

  factory NutrientProfile.fromJson(Map<String, dynamic>? json) {
    if (json == null || json.isEmpty) return empty;
    final map = <NutrientKey, double>{};
    json.forEach((rawKey, rawVal) {
      final key = NutrientKey.byJsonKey[rawKey];
      if (key != null && rawVal is num) {
        final d = rawVal.toDouble();
        if (d.isFinite && d >= 0) {
          map[key] = d;
        }
      }
    });
    return map.isEmpty ? empty : NutrientProfile(map);
  }

  static double _cleanDouble(double v) => (!v.isFinite || v < 0) ? 0.0 : v;
  static double _round4(double v) => (v * 10000).roundToDouble() / 10000.0;
  static double _round6(double v) => (v * 1000000).roundToDouble() / 1000000.0;
}
