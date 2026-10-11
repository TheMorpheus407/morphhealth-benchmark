// Kanonische Nährstoffliste von MorphHealth.
//
// Alle Nährwerte werden pro 100 g Lebensmittel in kanonischen Einheiten
// gespeichert. Die Open-Food-Facts-Abbildung (Schlüssel + Einheiten der
// API) liegt ebenfalls hier, damit Fachlogik und API-Vertrag an einer
// Stelle gekoppelt sind.
library;

/// Gruppe eines Nährstoffs (für Darstellung und Tagesziele).
enum NutrientGroup { main, vitamin, mineral }

/// Kanonische Einheit.
enum NutrientUnit { kcal, g, mg, ug }

class NutrientDef {
  /// Kanonischer Schlüssel, z. B. `energy_kcal`, `vitamin_b9_ug`.
  final String key;
  /// OFF-Schlüssel (ohne `_100g`-Suffix), z. B. `energy-kcal`, `vitamin-b9`.
  final String offKey;
  /// Alternative OFF-Schlüssel (z. B. `pantothenic-acid` für B5).
  final List<String> altOffKeys;
  final NutrientUnit unit;
  final NutrientGroup group;
  const NutrientDef(this.key, this.offKey, this.unit, this.group,
      {this.altOffKeys = const []});

  /// Faktor, mit dem ein Gramm-Wert in die kanonische Einheit umgerechnet wird.
  double get gramsToCanonical {
    switch (unit) {
      case NutrientUnit.g:
        return 1;
      case NutrientUnit.mg:
        return 1000;
      case NutrientUnit.ug:
        return 1000000;
      case NutrientUnit.kcal:
        return 1; // Sonderfall Energie, siehe offValueToCanonical
    }
  }

  /// Offizieller Umrechnungsfaktor kJ → kcal.
  static const double kjPerKcal = 4.184;
}

const List<NutrientDef> nutrientDefs = <NutrientDef>[
  // Hauptnährstoffe
  NutrientDef('energy_kcal', 'energy-kcal', NutrientUnit.kcal, NutrientGroup.main),
  NutrientDef('protein_g', 'proteins', NutrientUnit.g, NutrientGroup.main),
  NutrientDef('carbohydrates_g', 'carbohydrates', NutrientUnit.g, NutrientGroup.main),
  NutrientDef('fat_g', 'fat', NutrientUnit.g, NutrientGroup.main),
  NutrientDef('saturated_fat_g', 'saturated-fat', NutrientUnit.g, NutrientGroup.main),
  NutrientDef('sugars_g', 'sugars', NutrientUnit.g, NutrientGroup.main),
  NutrientDef('fiber_g', 'fiber', NutrientUnit.g, NutrientGroup.main),
  NutrientDef('salt_g', 'salt', NutrientUnit.g, NutrientGroup.main),
  NutrientDef('sodium_mg', 'sodium', NutrientUnit.mg, NutrientGroup.main),
  NutrientDef('caffeine_mg', 'caffeine', NutrientUnit.mg, NutrientGroup.main),
  // Vitamine
  NutrientDef('vitamin_a_ug', 'vitamin-a', NutrientUnit.ug, NutrientGroup.vitamin),
  NutrientDef('vitamin_c_mg', 'vitamin-c', NutrientUnit.mg, NutrientGroup.vitamin),
  NutrientDef('vitamin_d_ug', 'vitamin-d', NutrientUnit.ug, NutrientGroup.vitamin),
  NutrientDef('vitamin_e_mg', 'vitamin-e', NutrientUnit.mg, NutrientGroup.vitamin),
  NutrientDef('vitamin_k_ug', 'vitamin-k', NutrientUnit.ug, NutrientGroup.vitamin),
  NutrientDef('vitamin_b1_mg', 'vitamin-b1', NutrientUnit.mg, NutrientGroup.vitamin),
  NutrientDef('vitamin_b2_mg', 'vitamin-b2', NutrientUnit.mg, NutrientGroup.vitamin),
  NutrientDef('vitamin_b3_mg', 'vitamin-b3', NutrientUnit.mg, NutrientGroup.vitamin, altOffKeys: ['niacin']),
  NutrientDef('vitamin_b5_mg', 'pantothenic-acid', NutrientUnit.mg, NutrientGroup.vitamin, altOffKeys: ['vitamin-b5']),
  NutrientDef('vitamin_b6_mg', 'vitamin-b6', NutrientUnit.mg, NutrientGroup.vitamin),
  NutrientDef('vitamin_b7_ug', 'vitamin-b7', NutrientUnit.ug, NutrientGroup.vitamin, altOffKeys: ['biotin']),
  NutrientDef('vitamin_b9_ug', 'vitamin-b9', NutrientUnit.ug, NutrientGroup.vitamin, altOffKeys: ['folate', 'folic-acid']),
  NutrientDef('vitamin_b12_ug', 'vitamin-b12', NutrientUnit.ug, NutrientGroup.vitamin),
  // Mineralstoffe
  NutrientDef('calcium_mg', 'calcium', NutrientUnit.mg, NutrientGroup.mineral),
  NutrientDef('iron_mg', 'iron', NutrientUnit.mg, NutrientGroup.mineral),
  NutrientDef('magnesium_mg', 'magnesium', NutrientUnit.mg, NutrientGroup.mineral),
  NutrientDef('potassium_mg', 'potassium', NutrientUnit.mg, NutrientGroup.mineral),
  NutrientDef('zinc_mg', 'zinc', NutrientUnit.mg, NutrientGroup.mineral),
  NutrientDef('selenium_ug', 'selenium', NutrientUnit.ug, NutrientGroup.mineral),
  NutrientDef('iodine_ug', 'iodine', NutrientUnit.ug, NutrientGroup.mineral),
  NutrientDef('phosphorus_mg', 'phosphorus', NutrientUnit.mg, NutrientGroup.mineral),
];

final Map<String, NutrientDef> _byKey = <String, NutrientDef>{
  for (final NutrientDef d in nutrientDefs) d.key: d,
};

NutrientDef? nutrientByKey(String key) => _byKey[key];

List<NutrientDef> get mainNutrients =>
    nutrientDefs.where((NutrientDef d) => d.group == NutrientGroup.main).toList();

List<NutrientDef> get vitaminNutrients =>
    nutrientDefs.where((NutrientDef d) => d.group == NutrientGroup.vitamin).toList();

List<NutrientDef> get mineralNutrients =>
    nutrientDefs.where((NutrientDef d) => d.group == NutrientGroup.mineral).toList();

/// Schlüssel der Makronährstoffe, für die Tagesziele angeboten werden.
const List<String> macroGoalKeys = <String>['protein_g', 'carbohydrates_g', 'fat_g'];

/// Leere Nährwerttabelle (alle 31 Nährstoffe, Wert 0).
Map<String, double> emptyNutrientMap() => <String, double>{
      for (final NutrientDef d in nutrientDefs) d.key: 0,
    };

/// Wandelt einen Gramm-Wert in die kanonische Einheit des Nährstoffs um.
double gramsToCanonical(String nutrientKey, double grams) {
  final NutrientDef? def = _byKey[nutrientKey];
  if (def == null) return grams;
  return grams * def.gramsToCanonical;
}

/// Normalisiert eine OFF-Einheit zu einem Faktor auf Gramm.
///
/// Unbekannte/fehlende Einheiten werden gemäß Vertrag als Gramm angenommen
/// (der bereitgestellte Datenvertrag normalisiert Masse auf g/100 g).
double? offUnitToGramsFactor(String? unit) {
  if (unit == null || unit.isEmpty) return 1; // Annahme: g
  switch (unit) {
    case 'g':
      return 1;
    case 'mg':
      return 0.001;
    case 'µg':
    case 'ug':
    case 'μg':
      return 0.000001;
    case 'kg':
      return 1000;
    default:
      return null; // z. B. 'kcal', 'kJ', '% vol' — fachlich nicht umrechenbar
  }
}

/// Rechnet einen OFF-Nährwert (Wert + Einheit) in die kanonische Einheit um.
///
/// Energie wird besonders behandelt: kcal direkt, kJ über 4.184.
/// Liefert null, wenn der Wert nicht sinnvoll umgerechnet werden kann.
double? offValueToCanonical(NutrientDef def, num? value, String? unit) {
  if (value == null) return null;
  final double v = value.toDouble();
  if (def.unit == NutrientUnit.kcal) {
    if (unit == null || unit == 'kcal') return v;
    if (unit == 'kJ') return v / NutrientDef.kjPerKcal;
    return null;
  }
  final double? f = offUnitToGramsFactor(unit);
  if (f == null) return null;
  return v * f * def.gramsToCanonical;
}
