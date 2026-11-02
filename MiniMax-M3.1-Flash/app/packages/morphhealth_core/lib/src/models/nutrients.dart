/// Nutrient registry for MorphHealth.
///
/// Every mass nutrient is stored internally in **grams per 100 g of product**
/// (the unit used by Open Food Facts). Energy is stored in kcal / kJ per 100 g.
/// The display unit is only a presentation concern and is derived from the
/// registry below.
library;

import 'package:meta/meta.dart';

/// Coarse grouping used by the UI to structure nutrient lists.
enum NutrientGroup {
  energy,
  macro,
  extended,
  vitamin,
  mineral,
}

/// Display unit for a nutrient.
enum NutrientUnit {
  kcal,
  kj,
  g,
  mg,
  ug,
}

/// Static metadata of a single tracked nutrient.
@immutable
class NutrientSpec {
  const NutrientSpec({
    required this.id,
    required this.group,
    required this.unit,
    required this.deLabel,
    required this.enLabel,
    this.noteDe,
    this.noteEn,
  });

  /// Stable machine readable identifier. It is part of the portable export
  /// format and of the `mh` JSON output, so it never changes.
  final String id;
  final NutrientGroup group;

  /// Unit used for presentation.
  final NutrientUnit unit;

  final String deLabel;
  final String enLabel;
  final String? noteDe;
  final String? noteEn;

  /// Converts an internal gram value into the display unit.
  double toDisplay(double grams) => switch (unit) {
        NutrientUnit.kcal => grams,
        NutrientUnit.kj => grams,
        NutrientUnit.g => grams,
        NutrientUnit.mg => grams * 1000.0,
        NutrientUnit.ug => grams * 1000000.0,
      };

  /// Unit suffix for the display unit.
  String get unitLabel => switch (unit) {
        NutrientUnit.kcal => 'kcal',
        NutrientUnit.kj => 'kJ',
        NutrientUnit.g => 'g',
        NutrientUnit.mg => 'mg',
        NutrientUnit.ug => 'µg',
      };

  String label(String lang) => lang == 'en' ? enLabel : deLabel;
  String? note(String lang) => lang == 'en' ? noteEn : noteDe;

  @override
  String toString() => 'NutrientSpec($id)';
}

/// Registry of every nutrient MorphHealth tracks.
///
/// The set intentionally covers the whole scope of the product order:
/// energy, the three macros, the extended values (saturated fat, sugars,
/// fibre, salt, sodium, caffeine), 13 vitamins and 8 minerals.
abstract final class Nutrients {
  static const String energyKcal = 'energy_kcal';
  static const String energyKj = 'energy_kj';
  static const String protein = 'protein';
  static const String carbohydrates = 'carbohydrates';
  static const String fat = 'fat';
  static const String saturatedFat = 'saturated_fat';
  static const String sugars = 'sugars';
  static const String fiber = 'fiber';
  static const String salt = 'salt';
  static const String sodium = 'sodium';
  static const String caffeine = 'caffeine';

  static const String vitaminA = 'vitamin_a';
  static const String vitaminC = 'vitamin_c';
  static const String vitaminD = 'vitamin_d';
  static const String vitaminE = 'vitamin_e';
  static const String vitaminK = 'vitamin_k';
  static const String vitaminB1 = 'vitamin_b1';
  static const String vitaminB2 = 'vitamin_b2';
  static const String vitaminB3 = 'vitamin_b3';
  static const String vitaminB5 = 'vitamin_b5';
  static const String vitaminB6 = 'vitamin_b6';
  static const String vitaminB7 = 'vitamin_b7';
  static const String vitaminB9 = 'vitamin_b9';
  static const String vitaminB12 = 'vitamin_b12';

  static const String calcium = 'calcium';
  static const String iron = 'iron';
  static const String magnesium = 'magnesium';
  static const String potassium = 'potassium';
  static const String zinc = 'zinc';
  static const String selenium = 'selenium';
  static const String iodine = 'iodine';
  static const String phosphorus = 'phosphorus';

  static const List<NutrientSpec> all = <NutrientSpec>[
    NutrientSpec(
      id: energyKcal,
      group: NutrientGroup.energy,
      unit: NutrientUnit.kcal,
      deLabel: 'Energie',
      enLabel: 'Energy',
      noteDe: 'Kilokalorien',
      noteEn: 'Kilocalories',
    ),
    NutrientSpec(
      id: energyKj,
      group: NutrientGroup.energy,
      unit: NutrientUnit.kj,
      deLabel: 'Energie',
      enLabel: 'Energy',
      noteDe: 'Kilojoule',
      noteEn: 'Kilojoules',
    ),
    NutrientSpec(
      id: protein,
      group: NutrientGroup.macro,
      unit: NutrientUnit.g,
      deLabel: 'Protein',
      enLabel: 'Protein',
    ),
    NutrientSpec(
      id: carbohydrates,
      group: NutrientGroup.macro,
      unit: NutrientUnit.g,
      deLabel: 'Kohlenhydrate',
      enLabel: 'Carbohydrates',
    ),
    NutrientSpec(
      id: fat,
      group: NutrientGroup.macro,
      unit: NutrientUnit.g,
      deLabel: 'Fett',
      enLabel: 'Fat',
    ),
    NutrientSpec(
      id: saturatedFat,
      group: NutrientGroup.extended,
      unit: NutrientUnit.g,
      deLabel: 'Gesättigte Fettsäuren',
      enLabel: 'Saturated fat',
    ),
    NutrientSpec(
      id: sugars,
      group: NutrientGroup.extended,
      unit: NutrientUnit.g,
      deLabel: 'Zucker',
      enLabel: 'Sugars',
    ),
    NutrientSpec(
      id: fiber,
      group: NutrientGroup.extended,
      unit: NutrientUnit.g,
      deLabel: 'Ballaststoffe',
      enLabel: 'Fibre',
    ),
    NutrientSpec(
      id: salt,
      group: NutrientGroup.extended,
      unit: NutrientUnit.g,
      deLabel: 'Salz',
      enLabel: 'Salt',
    ),
    NutrientSpec(
      id: sodium,
      group: NutrientGroup.extended,
      unit: NutrientUnit.mg,
      deLabel: 'Natrium',
      enLabel: 'Sodium',
    ),
    NutrientSpec(
      id: caffeine,
      group: NutrientGroup.extended,
      unit: NutrientUnit.mg,
      deLabel: 'Koffein',
      enLabel: 'Caffeine',
    ),
    NutrientSpec(
      id: vitaminA,
      group: NutrientGroup.vitamin,
      unit: NutrientUnit.ug,
      deLabel: 'Vitamin A',
      enLabel: 'Vitamin A',
    ),
    NutrientSpec(
      id: vitaminC,
      group: NutrientGroup.vitamin,
      unit: NutrientUnit.mg,
      deLabel: 'Vitamin C',
      enLabel: 'Vitamin C',
    ),
    NutrientSpec(
      id: vitaminD,
      group: NutrientGroup.vitamin,
      unit: NutrientUnit.ug,
      deLabel: 'Vitamin D',
      enLabel: 'Vitamin D',
    ),
    NutrientSpec(
      id: vitaminE,
      group: NutrientGroup.vitamin,
      unit: NutrientUnit.mg,
      deLabel: 'Vitamin E',
      enLabel: 'Vitamin E',
    ),
    NutrientSpec(
      id: vitaminK,
      group: NutrientGroup.vitamin,
      unit: NutrientUnit.ug,
      deLabel: 'Vitamin K',
      enLabel: 'Vitamin K',
    ),
    NutrientSpec(
      id: vitaminB1,
      group: NutrientGroup.vitamin,
      unit: NutrientUnit.mg,
      deLabel: 'Vitamin B1 (Thiamin)',
      enLabel: 'Vitamin B1 (thiamine)',
    ),
    NutrientSpec(
      id: vitaminB2,
      group: NutrientGroup.vitamin,
      unit: NutrientUnit.mg,
      deLabel: 'Vitamin B2 (Riboflavin)',
      enLabel: 'Vitamin B2 (riboflavin)',
    ),
    NutrientSpec(
      id: vitaminB3,
      group: NutrientGroup.vitamin,
      unit: NutrientUnit.mg,
      deLabel: 'Vitamin B3 (Niacin)',
      enLabel: 'Vitamin B3 (niacin)',
    ),
    NutrientSpec(
      id: vitaminB5,
      group: NutrientGroup.vitamin,
      unit: NutrientUnit.mg,
      deLabel: 'Vitamin B5 (Pantothensäure)',
      enLabel: 'Vitamin B5 (pantothenic acid)',
    ),
    NutrientSpec(
      id: vitaminB6,
      group: NutrientGroup.vitamin,
      unit: NutrientUnit.mg,
      deLabel: 'Vitamin B6',
      enLabel: 'Vitamin B6',
    ),
    NutrientSpec(
      id: vitaminB7,
      group: NutrientGroup.vitamin,
      unit: NutrientUnit.ug,
      deLabel: 'Vitamin B7 (Biotin)',
      enLabel: 'Vitamin B7 (biotin)',
    ),
    NutrientSpec(
      id: vitaminB9,
      group: NutrientGroup.vitamin,
      unit: NutrientUnit.ug,
      deLabel: 'Vitamin B9 (Folsäure)',
      enLabel: 'Vitamin B9 (folate)',
    ),
    NutrientSpec(
      id: vitaminB12,
      group: NutrientGroup.vitamin,
      unit: NutrientUnit.ug,
      deLabel: 'Vitamin B12',
      enLabel: 'Vitamin B12',
    ),
    NutrientSpec(
      id: calcium,
      group: NutrientGroup.mineral,
      unit: NutrientUnit.mg,
      deLabel: 'Kalzium',
      enLabel: 'Calcium',
    ),
    NutrientSpec(
      id: iron,
      group: NutrientGroup.mineral,
      unit: NutrientUnit.mg,
      deLabel: 'Eisen',
      enLabel: 'Iron',
    ),
    NutrientSpec(
      id: magnesium,
      group: NutrientGroup.mineral,
      unit: NutrientUnit.mg,
      deLabel: 'Magnesium',
      enLabel: 'Magnesium',
    ),
    NutrientSpec(
      id: potassium,
      group: NutrientGroup.mineral,
      unit: NutrientUnit.mg,
      deLabel: 'Kalium',
      enLabel: 'Potassium',
    ),
    NutrientSpec(
      id: zinc,
      group: NutrientGroup.mineral,
      unit: NutrientUnit.mg,
      deLabel: 'Zink',
      enLabel: 'Zinc',
    ),
    NutrientSpec(
      id: selenium,
      group: NutrientGroup.mineral,
      unit: NutrientUnit.ug,
      deLabel: 'Selen',
      enLabel: 'Selenium',
    ),
    NutrientSpec(
      id: iodine,
      group: NutrientGroup.mineral,
      unit: NutrientUnit.ug,
      deLabel: 'Jod',
      enLabel: 'Iodine',
    ),
    NutrientSpec(
      id: phosphorus,
      group: NutrientGroup.mineral,
      unit: NutrientUnit.mg,
      deLabel: 'Phosphor',
      enLabel: 'Phosphorus',
    ),
  ];

  static final Map<String, NutrientSpec> byId = <String, NutrientSpec>{
    for (final NutrientSpec spec in all) spec.id: spec,
  };

  static final List<NutrientSpec> vitamins = all
      .where((NutrientSpec s) => s.group == NutrientGroup.vitamin)
      .toList(growable: false);

  static final List<NutrientSpec> minerals = all
      .where((NutrientSpec s) => s.group == NutrientGroup.mineral)
      .toList(growable: false);

  static final List<NutrientSpec> extended = all
      .where((NutrientSpec s) => s.group == NutrientGroup.extended)
      .toList(growable: false);

  static final List<NutrientSpec> macros = all
      .where((NutrientSpec s) => s.group == NutrientGroup.macro)
      .toList(growable: false);

  /// All nutrient ids that are part of a full nutrition profile.
  static final List<String> trackedIds =
      all.map((NutrientSpec s) => s.id).toList(growable: false);

  static NutrientSpec? specOf(String id) => byId[id];
}

/// Immutable set of nutrient amounts, always expressed per 100 g of product
/// for mass nutrients and per 100 g for energy.
class NutrientProfile {
  const NutrientProfile(this.values);

  /// Raw map of nutrient id -> amount per 100 g.
  final Map<String, double> values;

  /// An empty profile.
  static const NutrientProfile empty = NutrientProfile(<String, double>{});

  double operator [](String id) => values[id] ?? 0.0;

  bool has(String id) => (values[id] ?? 0.0) != 0.0;

  /// True when the profile carries no measurable amount at all.
  bool get isEmpty =>
      values.values.every((double v) => v == 0.0) || values.isEmpty;

  int get trackedCount =>
      values.keys.where((String id) => values[id] != 0.0).length;

  NutrientProfile scaled(double factor) {
    if (factor == 1.0) return this;
    return NutrientProfile(<String, double>{
      for (final MapEntry<String, double> e in values.entries)
        e.key: e.value * factor,
    });
  }

  NutrientProfile operator +(NutrientProfile other) {
    final Map<String, double> out = Map<String, double>.of(values);
    other.values.forEach((String key, double v) {
      out[key] = (out[key] ?? 0.0) + v;
    });
    return NutrientProfile(out);
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        for (final MapEntry<String, double> e in values.entries)
          if (e.value != 0.0) e.key: e.value,
      };

  static NutrientProfile fromJson(Map<String, dynamic> json) {
    final Map<String, double> out = <String, double>{};
    json.forEach((String key, dynamic v) {
      if (v is num) out[key] = v.toDouble();
    });
    return NutrientProfile(out);
  }

  @override
  String toString() => 'NutrientProfile(${values.length} values)';
}
