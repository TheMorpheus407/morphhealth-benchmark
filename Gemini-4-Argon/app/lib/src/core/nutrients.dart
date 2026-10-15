enum NutrientCategory {
  macro,
  extended,
  vitamin,
  mineral,
}

class NutrientMeta {
  final String key;
  final String shortKey;
  final List<String> aliases;
  final List<String> offKeys;
  final NutrientCategory category;
  final String unit;
  final String nameDe;
  final String nameEn;
  final int decimals;

  const NutrientMeta({
    required this.key,
    required this.shortKey,
    this.aliases = const [],
    required this.offKeys,
    required this.category,
    required this.unit,
    required this.nameDe,
    required this.nameEn,
    this.decimals = 1,
  });

  String label(String lang) => lang == 'en' ? nameEn : nameDe;
}

class NutrientCatalog {
  static const List<NutrientMeta> all = [
    // Main Macros (4)
    NutrientMeta(
      key: 'calories_kcal',
      shortKey: 'calories',
      aliases: ['energy_kcal', 'energy-kcal', 'kcal'],
      offKeys: ['energy-kcal'],
      category: NutrientCategory.macro,
      unit: 'kcal',
      nameDe: 'Kalorien',
      nameEn: 'Calories',
      decimals: 0,
    ),
    NutrientMeta(
      key: 'protein_g',
      shortKey: 'protein',
      aliases: ['proteins', 'proteins_g'],
      offKeys: ['proteins', 'protein'],
      category: NutrientCategory.macro,
      unit: 'g',
      nameDe: 'Protein',
      nameEn: 'Protein',
      decimals: 1,
    ),
    NutrientMeta(
      key: 'carbohydrates_g',
      shortKey: 'carbohydrates',
      aliases: ['carbs', 'carbs_g'],
      offKeys: ['carbohydrates'],
      category: NutrientCategory.macro,
      unit: 'g',
      nameDe: 'Kohlenhydrate',
      nameEn: 'Carbohydrates',
      decimals: 1,
    ),
    NutrientMeta(
      key: 'fat_g',
      shortKey: 'fat',
      aliases: ['fats', 'fats_g'],
      offKeys: ['fat'],
      category: NutrientCategory.macro,
      unit: 'g',
      nameDe: 'Fett',
      nameEn: 'Fat',
      decimals: 1,
    ),

    // Extended Macros & Additional Nutrients (6)
    NutrientMeta(
      key: 'saturated_fat_g',
      shortKey: 'saturated_fat',
      aliases: ['saturated-fat', 'saturated_fats_g'],
      offKeys: ['saturated-fat'],
      category: NutrientCategory.extended,
      unit: 'g',
      nameDe: 'Gesättigte Fettsäuren',
      nameEn: 'Saturated Fat',
      decimals: 1,
    ),
    NutrientMeta(
      key: 'sugars_g',
      shortKey: 'sugars',
      aliases: ['sugar', 'sugar_g'],
      offKeys: ['sugars', 'sugar'],
      category: NutrientCategory.extended,
      unit: 'g',
      nameDe: 'Zucker',
      nameEn: 'Sugars',
      decimals: 1,
    ),
    NutrientMeta(
      key: 'fiber_g',
      shortKey: 'fiber',
      aliases: ['fibre', 'fibre_g'],
      offKeys: ['fiber', 'fibre'],
      category: NutrientCategory.extended,
      unit: 'g',
      nameDe: 'Ballaststoffe',
      nameEn: 'Fiber',
      decimals: 1,
    ),
    NutrientMeta(
      key: 'salt_g',
      shortKey: 'salt',
      aliases: [],
      offKeys: ['salt'],
      category: NutrientCategory.extended,
      unit: 'g',
      nameDe: 'Salz',
      nameEn: 'Salt',
      decimals: 2,
    ),
    NutrientMeta(
      key: 'sodium_mg',
      shortKey: 'sodium',
      aliases: ['sodium_g'],
      offKeys: ['sodium'],
      category: NutrientCategory.extended,
      unit: 'mg',
      nameDe: 'Natrium',
      nameEn: 'Sodium',
      decimals: 1,
    ),
    NutrientMeta(
      key: 'caffeine_mg',
      shortKey: 'caffeine',
      aliases: ['caffeine_g'],
      offKeys: ['caffeine'],
      category: NutrientCategory.extended,
      unit: 'mg',
      nameDe: 'Koffein',
      nameEn: 'Caffeine',
      decimals: 1,
    ),

    // Vitamins (13)
    NutrientMeta(
      key: 'vitamin_a_ug',
      shortKey: 'vitamin_a',
      aliases: ['vitamin-a', 'vitamin_a_mcg'],
      offKeys: ['vitamin-a', 'retinol', 'beta-carotene'],
      category: NutrientCategory.vitamin,
      unit: 'µg',
      nameDe: 'Vitamin A',
      nameEn: 'Vitamin A',
      decimals: 1,
    ),
    NutrientMeta(
      key: 'vitamin_c_mg',
      shortKey: 'vitamin_c',
      aliases: ['vitamin-c'],
      offKeys: ['vitamin-c', 'ascorbic-acid', 'l-ascorbic-acid'],
      category: NutrientCategory.vitamin,
      unit: 'mg',
      nameDe: 'Vitamin C',
      nameEn: 'Vitamin C',
      decimals: 1,
    ),
    NutrientMeta(
      key: 'vitamin_d_ug',
      shortKey: 'vitamin_d',
      aliases: ['vitamin-d', 'vitamin_d_mcg'],
      offKeys: ['vitamin-d', 'cholecalciferol', 'ergocalciferol'],
      category: NutrientCategory.vitamin,
      unit: 'µg',
      nameDe: 'Vitamin D',
      nameEn: 'Vitamin D',
      decimals: 2,
    ),
    NutrientMeta(
      key: 'vitamin_e_mg',
      shortKey: 'vitamin_e',
      aliases: ['vitamin-e'],
      offKeys: ['vitamin-e', 'tocopherol', 'alpha-tocopherol'],
      category: NutrientCategory.vitamin,
      unit: 'mg',
      nameDe: 'Vitamin E',
      nameEn: 'Vitamin E',
      decimals: 2,
    ),
    NutrientMeta(
      key: 'vitamin_k_ug',
      shortKey: 'vitamin_k',
      aliases: ['vitamin-k', 'vitamin_k_mcg'],
      offKeys: ['vitamin-k', 'phylloquinone', 'menaquinone', 'phytomenadione'],
      category: NutrientCategory.vitamin,
      unit: 'µg',
      nameDe: 'Vitamin K',
      nameEn: 'Vitamin K',
      decimals: 1,
    ),
    NutrientMeta(
      key: 'vitamin_b1_mg',
      shortKey: 'vitamin_b1',
      aliases: ['vitamin-b1', 'thiamin', 'thiamine'],
      offKeys: ['vitamin-b1', 'thiamin', 'thiamine'],
      category: NutrientCategory.vitamin,
      unit: 'mg',
      nameDe: 'Vitamin B1 (Thiamin)',
      nameEn: 'Vitamin B1 (Thiamin)',
      decimals: 2,
    ),
    NutrientMeta(
      key: 'vitamin_b2_mg',
      shortKey: 'vitamin_b2',
      aliases: ['vitamin-b2', 'riboflavin'],
      offKeys: ['vitamin-b2', 'riboflavin'],
      category: NutrientCategory.vitamin,
      unit: 'mg',
      nameDe: 'Vitamin B2 (Riboflavin)',
      nameEn: 'Vitamin B2 (Riboflavin)',
      decimals: 2,
    ),
    NutrientMeta(
      key: 'vitamin_b3_mg',
      shortKey: 'vitamin_b3',
      aliases: ['vitamin-b3', 'vitamin-pp', 'niacin'],
      offKeys: ['vitamin-b3', 'vitamin-pp', 'niacin'],
      category: NutrientCategory.vitamin,
      unit: 'mg',
      nameDe: 'Vitamin B3 (Niacin)',
      nameEn: 'Vitamin B3 (Niacin)',
      decimals: 2,
    ),
    NutrientMeta(
      key: 'vitamin_b5_mg',
      shortKey: 'vitamin_b5',
      aliases: ['vitamin-b5', 'pantothenic-acid', 'pantothenic_acid'],
      offKeys: ['pantothenic-acid', 'vitamin-b5', 'pantothenate'],
      category: NutrientCategory.vitamin,
      unit: 'mg',
      nameDe: 'Vitamin B5 (Pantothensäure)',
      nameEn: 'Vitamin B5 (Pantothenic Acid)',
      decimals: 2,
    ),
    NutrientMeta(
      key: 'vitamin_b6_mg',
      shortKey: 'vitamin_b6',
      aliases: ['vitamin-b6', 'pyridoxine'],
      offKeys: ['vitamin-b6', 'pyridoxine'],
      category: NutrientCategory.vitamin,
      unit: 'mg',
      nameDe: 'Vitamin B6 (Pyridoxin)',
      nameEn: 'Vitamin B6 (Pyridoxine)',
      decimals: 2,
    ),
    NutrientMeta(
      key: 'vitamin_b7_ug',
      shortKey: 'vitamin_b7',
      aliases: ['vitamin-b7', 'biotin', 'vitamin_b7_mcg', 'vitamin-b8'],
      offKeys: ['biotin', 'vitamin-b7', 'vitamin-b8', 'vitamin-h'],
      category: NutrientCategory.vitamin,
      unit: 'µg',
      nameDe: 'Vitamin B7 (Biotin)',
      nameEn: 'Vitamin B7 (Biotin)',
      decimals: 1,
    ),
    NutrientMeta(
      key: 'vitamin_b9_ug',
      shortKey: 'vitamin_b9',
      aliases: ['vitamin-b9', 'folate', 'folic_acid', 'folates', 'vitamin_b9_mcg'],
      offKeys: ['vitamin-b9', 'folates', 'folic-acid', 'folate'],
      category: NutrientCategory.vitamin,
      unit: 'µg',
      nameDe: 'Vitamin B9 (Folat)',
      nameEn: 'Vitamin B9 (Folate)',
      decimals: 1,
    ),
    NutrientMeta(
      key: 'vitamin_b12_ug',
      shortKey: 'vitamin_b12',
      aliases: ['vitamin-b12', 'cobalamin', 'vitamin_b12_mcg'],
      offKeys: ['vitamin-b12', 'cobalamin', 'cyanocobalamin'],
      category: NutrientCategory.vitamin,
      unit: 'µg',
      nameDe: 'Vitamin B12 (Cobalamin)',
      nameEn: 'Vitamin B12 (Cobalamin)',
      decimals: 2,
    ),

    // Minerals (8)
    NutrientMeta(
      key: 'calcium_mg',
      shortKey: 'calcium',
      aliases: [],
      offKeys: ['calcium'],
      category: NutrientCategory.mineral,
      unit: 'mg',
      nameDe: 'Kalzium',
      nameEn: 'Calcium',
      decimals: 1,
    ),
    NutrientMeta(
      key: 'iron_mg',
      shortKey: 'iron',
      aliases: [],
      offKeys: ['iron'],
      category: NutrientCategory.mineral,
      unit: 'mg',
      nameDe: 'Eisen',
      nameEn: 'Iron',
      decimals: 2,
    ),
    NutrientMeta(
      key: 'magnesium_mg',
      shortKey: 'magnesium',
      aliases: [],
      offKeys: ['magnesium'],
      category: NutrientCategory.mineral,
      unit: 'mg',
      nameDe: 'Magnesium',
      nameEn: 'Magnesium',
      decimals: 1,
    ),
    NutrientMeta(
      key: 'potassium_mg',
      shortKey: 'potassium',
      aliases: [],
      offKeys: ['potassium'],
      category: NutrientCategory.mineral,
      unit: 'mg',
      nameDe: 'Kalium',
      nameEn: 'Potassium',
      decimals: 1,
    ),
    NutrientMeta(
      key: 'zinc_mg',
      shortKey: 'zinc',
      aliases: [],
      offKeys: ['zinc'],
      category: NutrientCategory.mineral,
      unit: 'mg',
      nameDe: 'Zink',
      nameEn: 'Zinc',
      decimals: 2,
    ),
    NutrientMeta(
      key: 'selenium_ug',
      shortKey: 'selenium',
      aliases: ['selenium_mcg'],
      offKeys: ['selenium'],
      category: NutrientCategory.mineral,
      unit: 'µg',
      nameDe: 'Selen',
      nameEn: 'Selenium',
      decimals: 1,
    ),
    NutrientMeta(
      key: 'iodine_ug',
      shortKey: 'iodine',
      aliases: ['iodine_mcg'],
      offKeys: ['iodine'],
      category: NutrientCategory.mineral,
      unit: 'µg',
      nameDe: 'Jod',
      nameEn: 'Iodine',
      decimals: 1,
    ),
    NutrientMeta(
      key: 'phosphorus_mg',
      shortKey: 'phosphorus',
      aliases: [],
      offKeys: ['phosphorus'],
      category: NutrientCategory.mineral,
      unit: 'mg',
      nameDe: 'Phosphor',
      nameEn: 'Phosphorus',
      decimals: 1,
    ),
  ];

  static final Map<String, NutrientMeta> byKey = {
    for (final m in all) m.key: m,
  };

  static List<NutrientMeta> byCategory(NutrientCategory cat) =>
      all.where((m) => m.category == cat).toList(growable: false);

  static NutrientMeta? resolveKey(String rawKey) {
    final normalized = rawKey.trim().toLowerCase();
    for (final m in all) {
      if (m.key == normalized ||
          m.shortKey == normalized ||
          m.aliases.contains(normalized) ||
          m.offKeys.contains(normalized)) {
        return m;
      }
    }
    return null;
  }

  /// Converts a mass or energy value from [sourceUnit] into [targetUnit].
  /// In Open Food Facts, mass nutrients in `_100g` and `aggregated_set` are
  /// stored in grams ('g') by default unless specified otherwise.
  static double convertUnit(
    double value,
    String? sourceUnit,
    String targetUnit,
  ) {
    if (value.isNaN || value.isInfinite) return 0.0;
    final src = (sourceUnit ?? '').trim().toLowerCase();
    final dst = targetUnit.trim().toLowerCase();

    if (dst == 'kcal') {
      if (src == 'kj') {
        return value / 4.184;
      }
      return value;
    }

    // Mass conversions: convert source to grams first
    double inGrams;
    if (src == '' || src == 'g' || src == 'gram' || src == 'grams') {
      inGrams = value;
    } else if (src == 'mg' || src == 'milligram' || src == 'milligrams') {
      inGrams = value / 1000.0;
    } else if (src == 'µg' ||
        src == 'μg' ||
        src == 'ug' ||
        src == 'mcg' ||
        src == 'microgram' ||
        src == 'micrograms') {
      inGrams = value / 1000000.0;
    } else if (src == 'kg') {
      inGrams = value * 1000.0;
    } else {
      inGrams = value;
    }

    if (dst == 'g') return inGrams;
    if (dst == 'mg') return inGrams * 1000.0;
    if (dst == 'µg' || dst == 'μg' || dst == 'ug' || dst == 'mcg') {
      return inGrams * 1000000.0;
    }
    return inGrams;
  }
}

class NutrientProfile {
  final Map<String, double> values;

  NutrientProfile([Map<String, double>? initial])
      : values = {
          for (final m in NutrientCatalog.all)
            m.key: _sanitize(initial?[m.key] ?? 0.0),
        };

  static double _sanitize(double v) {
    if (v.isNaN || v.isInfinite || v < 0) return 0.0;
    return v;
  }

  double operator [](String key) {
    final resolved = NutrientCatalog.byKey[key] ?? NutrientCatalog.resolveKey(key);
    if (resolved == null) return 0.0;
    return values[resolved.key] ?? 0.0;
  }

  double get caloriesKcal => values['calories_kcal'] ?? 0.0;
  double get proteinG => values['protein_g'] ?? 0.0;
  double get carbohydratesG => values['carbohydrates_g'] ?? 0.0;
  double get fatG => values['fat_g'] ?? 0.0;
  double get saturatedFatG => values['saturated_fat_g'] ?? 0.0;
  double get sugarsG => values['sugars_g'] ?? 0.0;
  double get fiberG => values['fiber_g'] ?? 0.0;
  double get saltG => values['salt_g'] ?? 0.0;
  double get sodiumMg => values['sodium_mg'] ?? 0.0;
  double get caffeineMg => values['caffeine_mg'] ?? 0.0;

  NutrientProfile scale(double factor) {
    final f = factor.isNaN || factor.isInfinite || factor < 0 ? 0.0 : factor;
    return NutrientProfile({
      for (final m in NutrientCatalog.all) m.key: (values[m.key] ?? 0.0) * f,
    });
  }

  NutrientProfile operator +(NutrientProfile other) {
    return NutrientProfile({
      for (final m in NutrientCatalog.all)
        m.key: (values[m.key] ?? 0.0) + (other.values[m.key] ?? 0.0),
    });
  }

  NutrientProfile copyWithValue(String key, double value) {
    final resolved = NutrientCatalog.byKey[key] ?? NutrientCatalog.resolveKey(key);
    if (resolved == null) return NutrientProfile(values);
    final next = Map<String, double>.from(values);
    next[resolved.key] = _sanitize(value);
    return NutrientProfile(next);
  }

  Map<String, double> toJson({int roundDecimals = 4}) {
    final factor = _pow10(roundDecimals);
    return {
      for (final m in NutrientCatalog.all)
        m.key: ((values[m.key] ?? 0.0) * factor).roundToDouble() / factor,
    };
  }

  Map<String, dynamic> toGroupedJson() {
    return {
      'macros': {
        for (final m in NutrientCatalog.byCategory(NutrientCategory.macro))
          m.key: _round(values[m.key] ?? 0.0, 2),
      },
      'extended': {
        for (final m in NutrientCatalog.byCategory(NutrientCategory.extended))
          m.key: _round(values[m.key] ?? 0.0, 3),
      },
      'vitamins': {
        for (final m in NutrientCatalog.byCategory(NutrientCategory.vitamin))
          m.key: _round(values[m.key] ?? 0.0, 3),
      },
      'minerals': {
        for (final m in NutrientCatalog.byCategory(NutrientCategory.mineral))
          m.key: _round(values[m.key] ?? 0.0, 3),
      },
    };
  }

  static double _round(double val, int decimals) {
    final f = _pow10(decimals);
    return (val * f).roundToDouble() / f;
  }

  static double _pow10(int exp) {
    double r = 1.0;
    for (int i = 0; i < exp; i++) {
      r *= 10.0;
    }
    return r;
  }

  factory NutrientProfile.fromJson(Map<String, dynamic>? json) {
    if (json == null) return NutrientProfile();
    final map = <String, double>{};

    void absorbMap(Map<dynamic, dynamic> src) {
      for (final entry in src.entries) {
        final k = entry.key.toString();
        final v = entry.value;
        if (v is Map) {
          absorbMap(v);
        } else {
          final numVal = _parseDouble(v);
          if (numVal != null) {
            final meta = NutrientCatalog.byKey[k] ?? NutrientCatalog.resolveKey(k);
            if (meta != null) {
              map[meta.key] = numVal;
            }
          }
        }
      }
    }

    absorbMap(json);
    return NutrientProfile(map);
  }

  /// Extracts all 31 nutrients per 100g/100ml from an Open Food Facts product
  /// payload, supporting both v3.6 (`nutrition.aggregated_set` / `input_sets`)
  /// and v1/v2 (`nutriments`).
  factory NutrientProfile.fromOpenFoodFactsProduct(
    Map<String, dynamic> product,
  ) {
    final result = <String, double>{};

    // 1. Collect v3.6 nutrient maps (preferring 100g/100ml aggregated_set, then input_sets)
    final v3Nutrients = <String, Map<String, dynamic>>{};
    final nutrition = product['nutrition'];
    if (nutrition is Map) {
      final agg = nutrition['aggregated_set'];
      if (agg is Map && agg['nutrients'] is Map) {
        final aggNutrients = agg['nutrients'] as Map;
        for (final e in aggNutrients.entries) {
          if (e.value is Map) {
            v3Nutrients[e.key.toString()] =
                Map<String, dynamic>.from(e.value as Map);
          }
        }
      }
      final inputSets = nutrition['input_sets'];
      if (inputSets is List) {
        for (final s in inputSets) {
          if (s is Map && s['nutrients'] is Map) {
            final per = (s['per'] ?? '').toString().toLowerCase();
            final perQty = _parseDouble(s['per_quantity']) ?? 100.0;
            final scaleTo100 =
                (per == '100g' || per == '100ml' || perQty <= 0)
                    ? 1.0
                    : (100.0 / perQty);
            final setNutrients = s['nutrients'] as Map;
            for (final e in setNutrients.entries) {
              final k = e.key.toString();
              if (!v3Nutrients.containsKey(k) && e.value is Map) {
                final item = Map<String, dynamic>.from(e.value as Map);
                final rawVal =
                    _parseDouble(item['value'] ?? item['value_computed']);
                if (rawVal != null) {
                  item['value'] = rawVal * scaleTo100;
                  v3Nutrients[k] = item;
                }
              }
            }
          }
        }
      }
    }

    // 2. Collect v1/v2 `nutriments` map
    final nutriments = product['nutriments'] is Map
        ? Map<String, dynamic>.from(product['nutriments'] as Map)
        : const <String, dynamic>{};

    double? extractOffKey(String offKey, String targetUnit) {
      // Check v3.6 first
      final v3Entry = v3Nutrients[offKey];
      if (v3Entry != null) {
        final rawVal =
            _parseDouble(v3Entry['value'] ?? v3Entry['value_computed']);
        if (rawVal != null) {
          final unit = v3Entry['unit']?.toString();
          return NutrientCatalog.convertUnit(rawVal, unit, targetUnit);
        }
      }

      // Check v1/v2 nutriments
      if (nutriments.isNotEmpty) {
        final val100g = _parseDouble(nutriments['${offKey}_100g']) ??
            _parseDouble(nutriments[offKey]) ??
            _parseDouble(nutriments['${offKey}_value']);
        if (val100g != null) {
          final unit = nutriments['${offKey}_unit']?.toString();
          // Note: in OFF nutriments, <key>_100g is normalized to 'g' for mass
          // nutrients and 'kcal'/'kJ' for energy. If only _value was present,
          // unit applies directly. If _100g is present, check if unit is 'g'/'kcal'/'kJ'.
          final effectiveUnit = nutriments.containsKey('${offKey}_100g')
              ? ((unit == 'kcal' || unit == 'kJ' || unit == 'kj') ? unit : 'g')
              : unit;
          return NutrientCatalog.convertUnit(val100g, effectiveUnit, targetUnit);
        }
      }
      return null;
    }

    for (final meta in NutrientCatalog.all) {
      double? found;
      for (final offKey in meta.offKeys) {
        found = extractOffKey(offKey, meta.unit);
        if (found != null && found > 0) break;
      }
      if (found == null) {
        for (final offKey in meta.offKeys) {
          found = extractOffKey(offKey, meta.unit);
          if (found != null) break;
        }
      }

      // Special fallback for calories from kJ if energy-kcal is absent
      if (meta.key == 'calories_kcal' && (found == null || found == 0)) {
        final kj = extractOffKey('energy-kj', 'kcal') ??
            extractOffKey('energy', 'kcal');
        if (kj != null && kj > 0) {
          found = kj;
        }
      }

      if (found != null) {
        result[meta.key] = _sanitize(found);
      }
    }

    // Fallback between salt and sodium if only one is reported by the product
    if ((result['sodium_mg'] == null || result['sodium_mg'] == 0) &&
        (result['salt_g'] != null && result['salt_g']! > 0)) {
      result['sodium_mg'] = (result['salt_g']! / 2.5) * 1000.0;
    } else if ((result['salt_g'] == null || result['salt_g'] == 0) &&
        (result['sodium_mg'] != null && result['sodium_mg']! > 0)) {
      result['salt_g'] = (result['sodium_mg']! / 1000.0) * 2.5;
    }

    return NutrientProfile(result);
  }

  static double? _parseDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) {
      final cleaned = v.trim().replaceAll(',', '.');
      return double.tryParse(cleaned);
    }
    return null;
  }
}
