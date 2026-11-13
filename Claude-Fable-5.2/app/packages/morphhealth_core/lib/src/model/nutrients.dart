import 'dart:typed_data';

import '../util/json_reader.dart';

enum NutrientGroup { energy, macro, detail, vitamin, mineral }

/// One nutrient the app understands: its key in all data formats, its unit and
/// how it maps to Open Food Facts.
class Nutrient {
  final int index;

  /// Stable key used in the store, in exports and by the maintenance access.
  /// The unit is part of the key, for example `vitamin_c_mg`.
  final String key;

  /// `kcal`, `g`, `mg` or `µg`.
  final String unit;

  final NutrientGroup group;
  final String labelDe;
  final String labelEn;

  /// Nutrient ids in Open Food Facts, in order of preference.
  final List<String> offIds;

  /// How many of [unit] make one gram (1, 1000 or 1000000). Unused for energy.
  final double unitsPerGram;

  const Nutrient._(
    this.index,
    this.key,
    this.unit,
    this.group,
    this.labelDe,
    this.labelEn,
    this.offIds,
    this.unitsPerGram,
  );

  String label(String language) => language == 'en' ? labelEn : labelDe;

  @override
  String toString() => key;
}

/// The complete nutrient catalogue of MorphHealth (31 values).
abstract final class Nutrients {
  static const energy = Nutrient._(
    0,
    'energy_kcal',
    'kcal',
    NutrientGroup.energy,
    'Kalorien',
    'Calories',
    ['energy-kcal'],
    1,
  );
  static const protein = Nutrient._(
    1,
    'protein_g',
    'g',
    NutrientGroup.macro,
    'Eiweiß',
    'Protein',
    ['proteins'],
    1,
  );
  static const carbohydrates = Nutrient._(
    2,
    'carbohydrates_g',
    'g',
    NutrientGroup.macro,
    'Kohlenhydrate',
    'Carbohydrates',
    ['carbohydrates'],
    1,
  );
  static const fat = Nutrient._(
    3,
    'fat_g',
    'g',
    NutrientGroup.macro,
    'Fett',
    'Fat',
    ['fat'],
    1,
  );
  static const saturatedFat = Nutrient._(
    4,
    'saturated_fat_g',
    'g',
    NutrientGroup.detail,
    'Gesättigte Fettsäuren',
    'Saturated fat',
    ['saturated-fat'],
    1,
  );
  static const sugars = Nutrient._(
    5,
    'sugars_g',
    'g',
    NutrientGroup.detail,
    'Zucker',
    'Sugars',
    ['sugars'],
    1,
  );
  static const fiber = Nutrient._(
    6,
    'fiber_g',
    'g',
    NutrientGroup.detail,
    'Ballaststoffe',
    'Fiber',
    ['fiber'],
    1,
  );
  static const salt = Nutrient._(
    7,
    'salt_g',
    'g',
    NutrientGroup.detail,
    'Salz',
    'Salt',
    ['salt'],
    1,
  );
  static const sodium = Nutrient._(
    8,
    'sodium_mg',
    'mg',
    NutrientGroup.detail,
    'Natrium',
    'Sodium',
    ['sodium'],
    1000,
  );
  static const caffeine = Nutrient._(
    9,
    'caffeine_mg',
    'mg',
    NutrientGroup.detail,
    'Koffein',
    'Caffeine',
    ['caffeine'],
    1000,
  );

  static const vitaminA = Nutrient._(
    10,
    'vitamin_a_ug',
    'µg',
    NutrientGroup.vitamin,
    'Vitamin A',
    'Vitamin A',
    ['vitamin-a'],
    1e6,
  );
  static const vitaminC = Nutrient._(
    11,
    'vitamin_c_mg',
    'mg',
    NutrientGroup.vitamin,
    'Vitamin C',
    'Vitamin C',
    ['vitamin-c'],
    1000,
  );
  static const vitaminD = Nutrient._(
    12,
    'vitamin_d_ug',
    'µg',
    NutrientGroup.vitamin,
    'Vitamin D',
    'Vitamin D',
    ['vitamin-d'],
    1e6,
  );
  static const vitaminE = Nutrient._(
    13,
    'vitamin_e_mg',
    'mg',
    NutrientGroup.vitamin,
    'Vitamin E',
    'Vitamin E',
    ['vitamin-e'],
    1000,
  );
  static const vitaminK = Nutrient._(
    14,
    'vitamin_k_ug',
    'µg',
    NutrientGroup.vitamin,
    'Vitamin K',
    'Vitamin K',
    ['vitamin-k', 'phylloquinone'],
    1e6,
  );
  static const vitaminB1 = Nutrient._(
    15,
    'vitamin_b1_mg',
    'mg',
    NutrientGroup.vitamin,
    'Vitamin B1 (Thiamin)',
    'Vitamin B1 (thiamin)',
    ['vitamin-b1'],
    1000,
  );
  static const vitaminB2 = Nutrient._(
    16,
    'vitamin_b2_mg',
    'mg',
    NutrientGroup.vitamin,
    'Vitamin B2 (Riboflavin)',
    'Vitamin B2 (riboflavin)',
    ['vitamin-b2'],
    1000,
  );
  static const vitaminB3 = Nutrient._(
    17,
    'vitamin_b3_mg',
    'mg',
    NutrientGroup.vitamin,
    'Vitamin B3 (Niacin)',
    'Vitamin B3 (niacin)',
    ['vitamin-pp'],
    1000,
  );
  static const vitaminB5 = Nutrient._(
    18,
    'vitamin_b5_mg',
    'mg',
    NutrientGroup.vitamin,
    'Vitamin B5 (Pantothensäure)',
    'Vitamin B5 (pantothenic acid)',
    ['pantothenic-acid'],
    1000,
  );
  static const vitaminB6 = Nutrient._(
    19,
    'vitamin_b6_mg',
    'mg',
    NutrientGroup.vitamin,
    'Vitamin B6',
    'Vitamin B6',
    ['vitamin-b6'],
    1000,
  );
  static const vitaminB7 = Nutrient._(
    20,
    'vitamin_b7_ug',
    'µg',
    NutrientGroup.vitamin,
    'Vitamin B7 (Biotin)',
    'Vitamin B7 (biotin)',
    ['biotin'],
    1e6,
  );
  static const vitaminB9 = Nutrient._(
    21,
    'vitamin_b9_ug',
    'µg',
    NutrientGroup.vitamin,
    'Vitamin B9 (Folat)',
    'Vitamin B9 (folate)',
    ['vitamin-b9', 'folates'],
    1e6,
  );
  static const vitaminB12 = Nutrient._(
    22,
    'vitamin_b12_ug',
    'µg',
    NutrientGroup.vitamin,
    'Vitamin B12',
    'Vitamin B12',
    ['vitamin-b12'],
    1e6,
  );

  static const calcium = Nutrient._(
    23,
    'calcium_mg',
    'mg',
    NutrientGroup.mineral,
    'Kalzium',
    'Calcium',
    ['calcium'],
    1000,
  );
  static const iron = Nutrient._(
    24,
    'iron_mg',
    'mg',
    NutrientGroup.mineral,
    'Eisen',
    'Iron',
    ['iron'],
    1000,
  );
  static const magnesium = Nutrient._(
    25,
    'magnesium_mg',
    'mg',
    NutrientGroup.mineral,
    'Magnesium',
    'Magnesium',
    ['magnesium'],
    1000,
  );
  static const potassium = Nutrient._(
    26,
    'potassium_mg',
    'mg',
    NutrientGroup.mineral,
    'Kalium',
    'Potassium',
    ['potassium'],
    1000,
  );
  static const zinc = Nutrient._(
    27,
    'zinc_mg',
    'mg',
    NutrientGroup.mineral,
    'Zink',
    'Zinc',
    ['zinc'],
    1000,
  );
  static const selenium = Nutrient._(
    28,
    'selenium_ug',
    'µg',
    NutrientGroup.mineral,
    'Selen',
    'Selenium',
    ['selenium'],
    1e6,
  );
  static const iodine = Nutrient._(
    29,
    'iodine_ug',
    'µg',
    NutrientGroup.mineral,
    'Jod',
    'Iodine',
    ['iodine'],
    1e6,
  );
  static const phosphorus = Nutrient._(
    30,
    'phosphorus_mg',
    'mg',
    NutrientGroup.mineral,
    'Phosphor',
    'Phosphorus',
    ['phosphorus'],
    1000,
  );

  /// All nutrients in display order; `all[i].index == i`.
  static const List<Nutrient> all = [
    energy, protein, carbohydrates, fat, saturatedFat, sugars, fiber, salt,
    sodium, caffeine, vitaminA, vitaminC, vitaminD, vitaminE, vitaminK,
    vitaminB1, vitaminB2, vitaminB3, vitaminB5, vitaminB6, vitaminB7,
    vitaminB9, vitaminB12, calcium, iron, magnesium, potassium, zinc,
    selenium, iodine, phosphorus, //
  ];

  static const int count = 31;

  /// Calories and the three macronutrients, as shown for every entry.
  static const List<Nutrient> main = [energy, protein, carbohydrates, fat];

  static final Map<String, Nutrient> _byKey = {for (final n in all) n.key: n};

  static Nutrient? byKey(String key) => _byKey[key];

  static Iterable<Nutrient> inGroup(NutrientGroup group) =>
      all.where((n) => n.group == group);

  /// Grams of salt that correspond to one milligram of sodium.
  static const double saltGramsPerSodiumMg = 2.5 / 1000;

  /// Kilojoules in one kilocalorie.
  static const double kjPerKcal = 4.184;
}

/// Amounts of all nutrients, each either known or unknown.
///
/// "Unknown" is not zero: many products list no vitamins at all, and sums
/// have to say how many entries actually contributed a value.
class NutrientValues {
  final Float64List _v;

  NutrientValues() : _v = Float64List(Nutrients.count) {
    _v.fillRange(0, Nutrients.count, double.nan);
  }

  NutrientValues._(this._v);

  /// The amount of [n], or null if unknown.
  double? operator [](Nutrient n) {
    final v = _v[n.index];
    return v.isNaN ? null : v;
  }

  void operator []=(Nutrient n, double? value) {
    _v[n.index] = value ?? double.nan;
  }

  bool has(Nutrient n) => !_v[n.index].isNaN;

  /// The amount of [n], with unknown counted as zero.
  double valueOrZero(Nutrient n) {
    final v = _v[n.index];
    return v.isNaN ? 0 : v;
  }

  bool get isEmpty => knownCount == 0;

  int get knownCount {
    var c = 0;
    for (var i = 0; i < _v.length; i++) {
      if (!_v[i].isNaN) c++;
    }
    return c;
  }

  NutrientValues copy() => NutrientValues._(Float64List.fromList(_v));

  /// All known amounts multiplied by [factor].
  NutrientValues scaled(double factor) {
    final out = Float64List(Nutrients.count);
    for (var i = 0; i < out.length; i++) {
      out[i] = _v[i] * factor; // NaN stays NaN
    }
    return NutrientValues._(out);
  }

  /// Adds the known amounts of [other]; unknown amounts leave a value as is.
  void add(NutrientValues other) {
    for (var i = 0; i < _v.length; i++) {
      final o = other._v[i];
      if (o.isNaN) continue;
      _v[i] = _v[i].isNaN ? o : _v[i] + o;
    }
  }

  /// Fills in salt from sodium or sodium from salt when only one is known.
  /// Returns the keys that were derived.
  List<String> completeSaltAndSodium() {
    final derived = <String>[];
    final salt = this[Nutrients.salt];
    final sodium = this[Nutrients.sodium];
    if (salt == null && sodium != null) {
      this[Nutrients.salt] = sodium * Nutrients.saltGramsPerSodiumMg;
      derived.add(Nutrients.salt.key);
    } else if (sodium == null && salt != null) {
      this[Nutrients.sodium] = salt / Nutrients.saltGramsPerSodiumMg;
      derived.add(Nutrients.sodium.key);
    }
    return derived;
  }

  /// Known amounts as `{key: number}` in catalogue order.
  Map<String, dynamic> toJson() => {
    for (final n in Nutrients.all)
      if (!_v[n.index].isNaN) n.key: roundForJson(_v[n.index]),
  };

  /// Reads `{key: number}`; unknown keys are reported as warnings.
  static NutrientValues fromJson(ObjectReader? reader) {
    final out = NutrientValues();
    if (reader == null) return out;
    for (final n in Nutrients.all) {
      final v = reader.number(n.key, min: 0, max: 1e7);
      if (v != null) out[n] = v;
    }
    reader.warnUnknown();
    return out;
  }

  @override
  bool operator ==(Object other) {
    if (other is! NutrientValues) return false;
    for (var i = 0; i < _v.length; i++) {
      final a = _v[i], b = other._v[i];
      if (a.isNaN != b.isNaN) return false;
      if (!a.isNaN && a != b) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAll(_v.map((e) => e.isNaN ? -1.0 : e));
}
