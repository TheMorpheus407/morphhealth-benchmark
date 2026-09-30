import 'issues.dart';

/// Gruppen des Nährstoffkatalogs.
enum NutrientGroup { energy, macro, detail, vitamin, mineral }

/// Ein Nährstoff des Katalogs. Der Schlüssel trägt die Einheit im Namen
/// (`sodium_mg`), damit Datenformat und Ausgaben ohne Rückfrage eindeutig sind.
final class NutrientDef {
  /// Stabiler Schlüssel in allen Datenformaten, z. B. `vitamin_d_ug`.
  final String key;

  /// Einheit der Werte: kcal, g, mg oder µg.
  final String unit;

  final NutrientGroup group;

  /// Nachkommastellen in der Darstellung.
  final int decimals;

  /// Namen des Nährstoffs bei Open Food Facts (Reihenfolge = Vorrang).
  final List<String> offIds;

  /// Faktor von Gramm (Einheit bei Open Food Facts) in [unit].
  final double offFactor;

  const NutrientDef(this.key, this.unit, this.group, this.decimals, this.offIds, this.offFactor);

  /// ASCII-Schreibweise der Einheit für Datenformate.
  String get unitAscii => unit == 'µg' ? 'ug' : unit;
}

const double _g = 1;
const double _mg = 1000;
const double _ug = 1000000;

/// Alle unterstützten Nährstoffe. Die Reihenfolge ist die Darstellungs- und
/// Ausgabereihenfolge.
const List<NutrientDef> nutrientCatalog = [
  NutrientDef('energy_kcal', 'kcal', NutrientGroup.energy, 0, ['energy-kcal'], 1),
  NutrientDef('protein_g', 'g', NutrientGroup.macro, 1, ['proteins'], _g),
  NutrientDef('carbohydrates_g', 'g', NutrientGroup.macro, 1, ['carbohydrates'], _g),
  NutrientDef('fat_g', 'g', NutrientGroup.macro, 1, ['fat'], _g),
  NutrientDef('saturated_fat_g', 'g', NutrientGroup.detail, 1, ['saturated-fat'], _g),
  NutrientDef('sugars_g', 'g', NutrientGroup.detail, 1, ['sugars'], _g),
  NutrientDef('fiber_g', 'g', NutrientGroup.detail, 1, ['fiber'], _g),
  NutrientDef('salt_g', 'g', NutrientGroup.detail, 2, ['salt'], _g),
  NutrientDef('sodium_mg', 'mg', NutrientGroup.detail, 0, ['sodium'], _mg),
  NutrientDef('caffeine_mg', 'mg', NutrientGroup.detail, 0, ['caffeine'], _mg),
  NutrientDef('vitamin_a_ug', 'µg', NutrientGroup.vitamin, 1, ['vitamin-a'], _ug),
  NutrientDef('vitamin_c_mg', 'mg', NutrientGroup.vitamin, 1, ['vitamin-c'], _mg),
  NutrientDef('vitamin_d_ug', 'µg', NutrientGroup.vitamin, 1, ['vitamin-d'], _ug),
  NutrientDef('vitamin_e_mg', 'mg', NutrientGroup.vitamin, 1, ['vitamin-e'], _mg),
  NutrientDef('vitamin_k_ug', 'µg', NutrientGroup.vitamin, 1, ['vitamin-k', 'phylloquinone'], _ug),
  NutrientDef('vitamin_b1_mg', 'mg', NutrientGroup.vitamin, 2, ['vitamin-b1', 'thiamin'], _mg),
  NutrientDef('vitamin_b2_mg', 'mg', NutrientGroup.vitamin, 2, ['vitamin-b2', 'riboflavin'], _mg),
  NutrientDef('vitamin_b3_mg', 'mg', NutrientGroup.vitamin, 1, ['vitamin-pp', 'niacin', 'vitamin-b3'], _mg),
  NutrientDef('vitamin_b5_mg', 'mg', NutrientGroup.vitamin, 2, ['pantothenic-acid', 'vitamin-b5'], _mg),
  NutrientDef('vitamin_b6_mg', 'mg', NutrientGroup.vitamin, 2, ['vitamin-b6'], _mg),
  NutrientDef('vitamin_b7_ug', 'µg', NutrientGroup.vitamin, 1, ['biotin', 'vitamin-b7', 'vitamin-h'], _ug),
  NutrientDef('vitamin_b9_ug', 'µg', NutrientGroup.vitamin, 1, ['vitamin-b9', 'folates', 'folic-acid'], _ug),
  NutrientDef('vitamin_b12_ug', 'µg', NutrientGroup.vitamin, 2, ['vitamin-b12'], _ug),
  NutrientDef('calcium_mg', 'mg', NutrientGroup.mineral, 0, ['calcium'], _mg),
  NutrientDef('iron_mg', 'mg', NutrientGroup.mineral, 1, ['iron'], _mg),
  NutrientDef('magnesium_mg', 'mg', NutrientGroup.mineral, 0, ['magnesium'], _mg),
  NutrientDef('potassium_mg', 'mg', NutrientGroup.mineral, 0, ['potassium'], _mg),
  NutrientDef('zinc_mg', 'mg', NutrientGroup.mineral, 1, ['zinc'], _mg),
  NutrientDef('selenium_ug', 'µg', NutrientGroup.mineral, 1, ['selenium'], _ug),
  NutrientDef('iodine_ug', 'µg', NutrientGroup.mineral, 1, ['iodine'], _ug),
  NutrientDef('phosphorus_mg', 'mg', NutrientGroup.mineral, 0, ['phosphorus'], _mg),
];

final Map<String, NutrientDef> nutrientByKey = {for (final n in nutrientCatalog) n.key: n};

/// Schlüssel in Katalogreihenfolge.
final List<String> nutrientKeys = [for (final n in nutrientCatalog) n.key];

List<NutrientDef> nutrientsOfGroup(NutrientGroup g) => [
  for (final n in nutrientCatalog)
    if (n.group == g) n,
];

/// Schlüssel der fünf Hauptgrößen.
const String kEnergy = 'energy_kcal';
const String kProtein = 'protein_g';
const String kCarbs = 'carbohydrates_g';
const String kFat = 'fat_g';
const String kCaffeine = 'caffeine_mg';

/// Rundet auf [decimals] Stellen und entfernt negative Nullen.
double roundTo(double v, int decimals) {
  if (v.isNaN || v.isInfinite) return v;
  var p = 1.0;
  for (var i = 0; i < decimals; i++) {
    p *= 10;
  }
  final r = (v * p).round() / p;
  return r == 0 ? 0.0 : r;
}

/// Kurzschreibweisen, die beim Einlesen zusätzlich akzeptiert werden. Nur
/// Größen mit eindeutiger Einheit (kcal, g, mg für Koffein).
const Map<String, String> _aliases = {
  'kcal': 'energy_kcal',
  'calories': 'energy_kcal',
  'protein': 'protein_g',
  'proteins': 'protein_g',
  'carbs': 'carbohydrates_g',
  'carbohydrates': 'carbohydrates_g',
  'carbohydrate': 'carbohydrates_g',
  'fat': 'fat_g',
  'fats': 'fat_g',
  'saturated_fat': 'saturated_fat_g',
  'saturates': 'saturated_fat_g',
  'sugar': 'sugars_g',
  'sugars': 'sugars_g',
  'fiber': 'fiber_g',
  'fibre': 'fiber_g',
  'salt': 'salt_g',
  'caffeine': 'caffeine_mg',
};

/// Nährwerte als unveränderliche Zuordnung Schlüssel -> Wert. Ein fehlender
/// Schlüssel heißt "keine Angabe" und ist nicht dasselbe wie 0.
/// Größter erlaubter Nährwert je 100 g beziehungsweise 100 ml (in der Einheit des Nährstoffs).
const double kMaxNutrientValue = 10000000;

final class Nutrients {
  final Map<String, double> _m;

  const Nutrients._(this._m);

  static const Nutrients none = Nutrients._({});

  /// Übernimmt nur Schlüssel des Katalogs mit endlichen Werten von 0 bis [kMaxNutrientValue].
  factory Nutrients.of(Map<String, double> values) {
    final out = <String, double>{};
    for (final n in nutrientCatalog) {
      final v = values[n.key];
      if (v != null && v.isFinite && v >= 0 && v <= kMaxNutrientValue) out[n.key] = v;
    }
    return out.isEmpty ? none : Nutrients._(Map.unmodifiable(out));
  }

  bool get isEmpty => _m.isEmpty;
  bool get isNotEmpty => _m.isNotEmpty;
  int get length => _m.length;

  double? operator [](String key) => _m[key];

  /// Wert oder 0, wenn keine Angabe vorliegt.
  double get0(String key) => _m[key] ?? 0;

  bool has(String key) => _m.containsKey(key);

  Iterable<String> get keys => _m.keys;

  Nutrients scaled(double factor) {
    if (_m.isEmpty) return this;
    return Nutrients._({for (final e in _m.entries) e.key: e.value * factor});
  }

  Nutrients plus(Nutrients other) {
    if (other._m.isEmpty) return this;
    if (_m.isEmpty) return other;
    final out = Map<String, double>.of(_m);
    for (final e in other._m.entries) {
      out[e.key] = (out[e.key] ?? 0) + e.value;
    }
    return Nutrients._(out);
  }

  Nutrients with_(String key, double? value) {
    final out = Map<String, double>.of(_m);
    if (value == null) {
      out.remove(key);
    } else {
      out[key] = value;
    }
    return Nutrients.of(out);
  }

  /// Katalogreihenfolge, mit optionaler Rundung für die Ausgabe.
  Map<String, double> toJson({bool rounded = false}) {
    final out = <String, double>{};
    for (final n in nutrientCatalog) {
      final v = _m[n.key];
      if (v != null) out[n.key] = rounded ? roundTo(v, 4) : v;
    }
    return out;
  }

  /// Liest ein Objekt `{schlüssel: zahl}`. Unbekannte Schlüssel ergeben eine
  /// Warnung, ungültige Werte einen Fehler.
  static Nutrients read(Obj? o) {
    if (o == null) return none;
    final out = <String, double>{};
    for (final n in nutrientCatalog) {
      final v = o.number(n.key, min: 0, max: kMaxNutrientValue);
      if (v != null) out[n.key] = v;
    }
    // Übliche Kurzschreibweisen für Größen mit eindeutiger Einheit.
    for (final a in _aliases.entries) {
      if (!o.has(a.key)) continue;
      final v = o.number(a.key, min: 0, max: kMaxNutrientValue);
      if (v != null && !out.containsKey(a.value)) out[a.value] = v;
    }
    o.finish();
    return Nutrients.of(out);
  }

  @override
  bool operator ==(Object other) {
    if (other is! Nutrients || other._m.length != _m.length) return false;
    for (final e in _m.entries) {
      if (other._m[e.key] != e.value) return false;
    }
    return true;
  }

  @override
  int get hashCode => Object.hashAllUnordered(_m.entries.map((e) => Object.hash(e.key, e.value)));
}

/// Deutsche und englische Bezeichnungen der Nährstoffe.
const Map<String, (String, String)> nutrientNames = {
  'energy_kcal': ('Energie', 'Energy'),
  'protein_g': ('Eiweiß', 'Protein'),
  'carbohydrates_g': ('Kohlenhydrate', 'Carbohydrates'),
  'fat_g': ('Fett', 'Fat'),
  'saturated_fat_g': ('Gesättigte Fettsäuren', 'Saturated fat'),
  'sugars_g': ('Zucker', 'Sugars'),
  'fiber_g': ('Ballaststoffe', 'Fiber'),
  'salt_g': ('Salz', 'Salt'),
  'sodium_mg': ('Natrium', 'Sodium'),
  'caffeine_mg': ('Koffein', 'Caffeine'),
  'vitamin_a_ug': ('Vitamin A', 'Vitamin A'),
  'vitamin_c_mg': ('Vitamin C', 'Vitamin C'),
  'vitamin_d_ug': ('Vitamin D', 'Vitamin D'),
  'vitamin_e_mg': ('Vitamin E', 'Vitamin E'),
  'vitamin_k_ug': ('Vitamin K', 'Vitamin K'),
  'vitamin_b1_mg': ('Vitamin B1 (Thiamin)', 'Vitamin B1 (thiamine)'),
  'vitamin_b2_mg': ('Vitamin B2 (Riboflavin)', 'Vitamin B2 (riboflavin)'),
  'vitamin_b3_mg': ('Vitamin B3 (Niacin)', 'Vitamin B3 (niacin)'),
  'vitamin_b5_mg': ('Vitamin B5 (Pantothensäure)', 'Vitamin B5 (pantothenic acid)'),
  'vitamin_b6_mg': ('Vitamin B6', 'Vitamin B6'),
  'vitamin_b7_ug': ('Vitamin B7 (Biotin)', 'Vitamin B7 (biotin)'),
  'vitamin_b9_ug': ('Vitamin B9 (Folat)', 'Vitamin B9 (folate)'),
  'vitamin_b12_ug': ('Vitamin B12', 'Vitamin B12'),
  'calcium_mg': ('Kalzium', 'Calcium'),
  'iron_mg': ('Eisen', 'Iron'),
  'magnesium_mg': ('Magnesium', 'Magnesium'),
  'potassium_mg': ('Kalium', 'Potassium'),
  'zinc_mg': ('Zink', 'Zinc'),
  'selenium_ug': ('Selen', 'Selenium'),
  'iodine_ug': ('Jod', 'Iodine'),
  'phosphorus_mg': ('Phosphor', 'Phosphorus'),
};

/// Bezeichnung in [lang] (`de` oder `en`).
String nutrientName(String key, String lang) {
  final n = nutrientNames[key];
  if (n == null) return key;
  return lang == 'en' ? n.$2 : n.$1;
}
