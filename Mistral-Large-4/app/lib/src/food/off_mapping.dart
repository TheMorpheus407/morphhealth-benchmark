// Abbildung Open-Food-Facts-Produkt → MorphHealth-Lebensmittel.
//
// Unterstützt beide Formate desselben Vertrags:
//   1. flache `nutriments` (`<key>_100g` + `<key>_unit`) — search.pl und ältere v3.x
//   2. aggregiertes `nutrition.aggregated_set.nutrients` (`<key>` → {unit, value})
//      — Open-Food-Facts-API v3.5/v3.6
//
// Einheiten des Vertrags: Masse in g/100 g (mg/µg werden umgerechnet),
// Energie in kcal bzw. kJ.
library;

import '../core/parse.dart';
import '../model/food.dart';
import '../nutrients/nutrients.dart';

/// Liest Nährwerte aus der flachen `nutriments`-Struktur.
Map<String, double> mapFlatNutriments(Map<String, dynamic>? nutriments) {
  final Map<String, double> out = <String, double>{};
  if (nutriments == null) return out;
  for (final NutrientDef def in nutrientDefs) {
    for (final String key in <String>[def.offKey, ...def.altOffKeys]) {
      final double? v = getDouble(nutriments, '${key}_100g');
      if (v == null) continue;
      final String? unit = getString(nutriments, '${key}_unit');
      final double? canonical = offValueToCanonical(def, v, unit);
      if (canonical != null) {
        out[def.key] = canonical;
        break;
      }
    }
  }
  // Energie-Fallback: kJ → kcal.
  if (!out.containsKey('energy_kcal')) {
    for (final String key in <String>['energy-kj', 'energy']) {
      final double? v = getDouble(nutriments, '${key}_100g');
      if (v == null) continue;
      final String? unit = getString(nutriments, '${key}_unit');
      if (unit == null || unit == 'kJ') {
        out['energy_kcal'] = v / NutrientDef.kjPerKcal;
        break;
      }
    }
  }
  return out;
}

/// Liest Nährwerte aus der aggregierten Struktur
/// (`nutrition.aggregated_set.nutrients`).
Map<String, double> mapAggregatedNutrients(Map<String, dynamic>? aggregated) {
  final Map<String, double> out = <String, double>{};
  final Map<String, dynamic>? nutrients = getMap(aggregated, 'nutrients');
  if (nutrients == null) return out;
  for (final NutrientDef def in nutrientDefs) {
    for (final String key in <String>[def.offKey, ...def.altOffKeys]) {
      final Map<String, dynamic>? entry = getMap(nutrients, key);
      if (entry == null) continue;
      final String? sourcePer = getString(entry, 'source_per');
      if (sourcePer != null && sourcePer != '100g') continue; // z. B. pro Portion
      final double? v = getDouble(entry, 'value');
      if (v == null) continue;
      final String? unit = getString(entry, 'unit');
      final double? canonical = offValueToCanonical(def, v, unit);
      if (canonical != null) {
        out[def.key] = canonical;
        break;
      }
    }
  }
  // Energie-Fallback: kJ → kcal.
  if (!out.containsKey('energy_kcal')) {
    for (final String key in <String>['energy-kj', 'energy']) {
      final Map<String, dynamic>? entry = getMap(nutrients, key);
      if (entry == null) continue;
      final String? sourcePer = getString(entry, 'source_per');
      if (sourcePer != null && sourcePer != '100g') continue;
      final double? v = getDouble(entry, 'value');
      final String? unit = getString(entry, 'unit');
      if (v != null && (unit == null || unit == 'kJ')) {
        out['energy_kcal'] = v / NutrientDef.kjPerKcal;
        break;
      }
    }
  }
  return out;
}

/// Parst die Portionsgröße eines Produkts.
///
/// Bevorzugt `serving_quantity` + `serving_quantity_unit` (g/ml),
/// sonst wird `serving_size` („250 ml“, „100.0g“, „2 g“) ausgewertet.
Serving? parseServing(Map<String, dynamic> product) {
  final double? qty = getDouble(product, 'serving_quantity');
  final String? qtyUnit = getString(product, 'serving_quantity_unit');
  final String? servingSize = getString(product, 'serving_size');
  double? grams;
  String? label;
  if (qty != null && qty > 0 && (qtyUnit == 'g' || qtyUnit == 'ml')) {
    // ml wird mit Dichte 1 g/ml als Gramm gerechnet.
    grams = qty;
    label = servingSize != null && servingSize.isNotEmpty ? servingSize : null;
  } else if (servingSize != null && servingSize.isNotEmpty) {
    final RegExp re = RegExp(r'^\s*([0-9]+[.,]?[0-9]*)\s*(g|ml)?\s*$', caseSensitive: false);
    final RegExpMatch? m = re.firstMatch(servingSize);
    if (m != null) {
      final double v = double.parse(m.group(1)!.replaceAll(',', '.'));
      // Einheit g oder ml — beides wird als Gramm gerechnet (ml ⇒ 1 g/ml).
      grams = v;
      label = servingSize;
    }
  }
  if (grams == null && label == null) return null;
  return Serving(grams: grams, label: label);
}

/// Ein Open-Food-Facts-Produkt (kanonisch abgebildet).
class OffProduct {
  final String barcode;
  final String name;
  final String? brand;
  final Map<String, double> per100;
  final Serving? serving;
  final String? imageUrl;
  final String? quantity;
  final String? ingredientsText;
  final String? allergens;
  final String? link;

  const OffProduct({
    required this.barcode,
    required this.name,
    this.brand,
    required this.per100,
    this.serving,
    this.imageUrl,
    this.quantity,
    this.ingredientsText,
    this.allergens,
    this.link,
  });

  /// Abbildung aus einem Produkt-Objekt der API (beide Nährwert-Formate).
  static OffProduct? fromProductJson(Map<String, dynamic> product) {
    final String? barcode = getString(product, 'code') ?? getString(product, '_id') ?? getString(product, 'id');
    if (barcode == null || barcode.isEmpty) return null;
    final String name = getString(product, 'product_name_de') ??
        getString(product, 'product_name') ??
        getString(product, 'generic_name_de') ??
        getString(product, 'generic_name') ??
        barcode;
    final String? brands = getString(product, 'brands');
    final String? brand = brands == null || brands.isEmpty
        ? null
        : brands.split(',').first.trim();
    final Map<String, dynamic>? nutriments = getMap(product, 'nutriments');
    final Map<String, dynamic>? nutrition = getMap(product, 'nutrition');
    final Map<String, dynamic>? aggregated = getMap(nutrition, 'aggregated_set');
    // Flache Werte haben Vorrang, aggregierte füllen Lücken.
    final Map<String, double> per100 = <String, double>{
      ...mapAggregatedNutrients(aggregated),
      ...mapFlatNutriments(nutriments),
    };
    final Serving? serving = parseServing(product);
    return OffProduct(
      barcode: barcode,
      name: name,
      brand: brand,
      per100: per100,
      serving: serving,
      imageUrl: getString(product, 'image_front_small_url') ?? getString(product, 'image_front_url') ?? getString(product, 'image_url'),
      quantity: getString(product, 'quantity'),
      ingredientsText: getString(product, 'ingredients_text'),
      allergens: getString(product, 'allergens'),
      link: getString(product, 'link'),
    );
  }

  /// Schnappschuss als lokales FoodItem (zum Loggen und für Favoriten).
  FoodItem toFoodItemSnapshot() {
    return FoodItem(
      id: '',
      name: name,
      brand: brand,
      barcode: barcode,
      source: FoodSource.off,
      per100: Map<String, double>.of(per100),
      serving: serving,
      isFavorite: false,
      imageUrl: imageUrl,
      offOrigin: link,
      createdAt: DateTime.now().toUtc(),
      updatedAt: DateTime.now().toUtc(),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'barcode': barcode,
        'name': name,
        if (brand != null) 'brand': brand,
        'per100': <String, dynamic>{
          for (final MapEntry<String, double> e in per100.entries) e.key: e.value,
        },
        if (serving != null) 'serving': serving!.toJson(),
        if (imageUrl != null) 'image_url': imageUrl,
        if (quantity != null) 'quantity': quantity,
        if (ingredientsText != null) 'ingredients_text': ingredientsText,
        if (allergens != null) 'allergens': allergens,
        if (link != null) 'link': link,
      };
}
