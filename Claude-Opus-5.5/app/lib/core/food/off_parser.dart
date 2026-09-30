import '../model/enums.dart';
import '../model/food.dart';
import '../model/nutrients.dart';

/// A product returned by the online food database, converted into a
/// MorphHealth [FoodProfile].
class OnlineFood {
  OnlineFood({
    required this.profile,
    this.quantityLabel,
    required this.nutritionSource,
  });

  final FoodProfile profile;

  /// Package size as printed, e.g. "500 g".
  final String? quantityLabel;

  /// `aggregated_set` (API v3.5+ nutrition schema), `nutriments` (legacy
  /// flat schema) or `none`.
  final String nutritionSource;

  String get barcode => profile.barcode ?? '';

  bool get hasEnergy => profile.nutrients.containsKey(Nutrients.energy.key);

  Map<String, Object?> toJson() => {
    'barcode': profile.barcode,
    'name': profile.name,
    'brand': profile.brand,
    'quantity_label': quantityLabel,
    'basis': profile.basis.json,
    'serving_size': profile.servingSize,
    'serving_label': profile.servingLabel,
    'nutrients_per_100': {
      for (final n in Nutrients.all)
        if (profile.nutrients.containsKey(n.key)) n.key: profile.nutrients[n.key],
    },
    'estimated_nutrients': [
      for (final n in Nutrients.all)
        if (profile.estimatedNutrients.contains(n.key)) n.key,
    ],
    'nutrition_source': nutritionSource,
    'food': profile.toJson(),
  };
}

/// Converts Open Food Facts product objects into [OnlineFood]s.
///
/// Two nutrition layouts are supported:
/// * API v3.5+ `nutrition.aggregated_set.nutrients` – values normalized to
///   g (kcal/kJ for energy) per 100 g or 100 ml with a `source` per value;
///   values with source `estimate` are flagged as estimates.
/// * the legacy flat `nutriments` object (`<id>_100g`, normalized to g),
///   still returned by the search endpoint.
class OffParser {
  const OffParser._();

  static OnlineFood? parse(Map<String, Object?> product, {required String language}) {
    final code = _string(product['code']) ?? _string(product['_id']);
    if (code == null || !RegExp(r'^\d{1,32}$').hasMatch(code)) return null;

    final name =
        _string(product['product_name_$language']) ??
        _string(product['product_name']) ??
        _string(product['product_name_en']) ??
        _string(product['product_name_de']) ??
        _string(product['generic_name_$language']) ??
        _string(product['generic_name']) ??
        _string(product['abbreviated_product_name']) ??
        code;

    final brand = _firstBrand(_string(product['brands']));

    final nutrition = product['nutrition'];
    final aggregated = nutrition is Map ? nutrition['aggregated_set'] : null;
    final aggregatedNutrients = aggregated is Map
        ? aggregated['nutrients']
        : null;

    final values = <String, double>{};
    final estimated = <String>{};
    String source;
    if (aggregatedNutrients is Map && aggregatedNutrients.isNotEmpty) {
      source = 'aggregated_set';
      _readAggregated(aggregatedNutrients, values, estimated);
    } else if (product['nutriments'] is Map &&
        (product['nutriments'] as Map).isNotEmpty) {
      source = 'nutriments';
      _readLegacy(product['nutriments'] as Map, values);
    } else {
      source = 'none';
    }

    final normalized = Nutrients.normalize(values);
    if (estimated.contains(Nutrients.salt.key) &&
        !values.containsKey(Nutrients.sodium.key)) {
      estimated.add(Nutrients.sodium.key);
    }
    if (estimated.contains(Nutrients.sodium.key) &&
        !values.containsKey(Nutrients.salt.key)) {
      estimated.add(Nutrients.salt.key);
    }
    estimated.retainWhere(normalized.containsKey);

    final per = aggregated is Map ? _string(aggregated['per']) : null;
    final quantityUnit = _string(product['product_quantity_unit'])?.toLowerCase();
    final basis = (per == '100ml' || quantityUnit == 'ml') ? Basis.ml : Basis.g;

    double? servingSize = _number(product['serving_quantity']);
    final servingUnit = _string(product['serving_quantity_unit'])?.toLowerCase();
    if (servingSize != null &&
        (servingSize <= 0 ||
            servingSize > 100000 ||
            (servingUnit != null && servingUnit != 'g' && servingUnit != 'ml'))) {
      servingSize = null;
    }
    var servingLabel = _string(product['serving_size']);
    if (servingLabel != null && servingLabel.length > 100) {
      servingLabel = servingLabel.substring(0, 100);
    }
    if (servingSize == null) servingLabel = null;

    return OnlineFood(
      profile: FoodProfile(
        source: FoodSource.openFoodFacts,
        name: name.length > 200 ? name.substring(0, 200) : name,
        brand: brand,
        barcode: code,
        basis: basis,
        servingSize: servingSize == null ? null : _round(servingSize, 3),
        servingLabel: servingLabel,
        nutrients: normalized,
        estimatedNutrients: estimated,
      ),
      quantityLabel: _string(product['quantity']),
      nutritionSource: source,
    );
  }

  static void _readAggregated(
    Map<Object?, Object?> nutrients,
    Map<String, double> out,
    Set<String> estimated,
  ) {
    // Energy: prefer declared kcal, otherwise convert kJ.
    final kcal = _aggregatedValue(nutrients['energy-kcal']);
    if (kcal != null && _unitOf(nutrients['energy-kcal']) != 'kj') {
      out[Nutrients.energy.key] = _round(kcal, 3);
      if (_isEstimate(nutrients['energy-kcal'])) estimated.add(Nutrients.energy.key);
    } else {
      for (final id in const ['energy-kj', 'energy']) {
        final kj = _aggregatedValue(nutrients[id]);
        if (kj != null) {
          out[Nutrients.energy.key] = _round(kj / Nutrients.kjPerKcal, 3);
          if (_isEstimate(nutrients[id])) estimated.add(Nutrients.energy.key);
          break;
        }
      }
    }
    for (final n in Nutrients.all) {
      if (n.group == NutrientGroup.energy) continue;
      for (final id in n.offIds) {
        final entry = nutrients[id];
        final value = _aggregatedValue(entry);
        if (value == null) continue;
        final grams = _toGrams(value, _unitOf(entry));
        if (grams == null) continue;
        out[n.key] = _round(grams * n.fromGrams, 6);
        if (_isEstimate(entry)) estimated.add(n.key);
        break;
      }
    }
  }

  static void _readLegacy(Map<Object?, Object?> nutriments, Map<String, double> out) {
    final kcal = _number(nutriments['energy-kcal_100g']);
    if (kcal != null) {
      out[Nutrients.energy.key] = _round(kcal, 3);
    } else {
      final kj =
          _number(nutriments['energy-kj_100g']) ??
          _number(nutriments['energy_100g']);
      if (kj != null) {
        out[Nutrients.energy.key] = _round(kj / Nutrients.kjPerKcal, 3);
      }
    }
    for (final n in Nutrients.all) {
      if (n.group == NutrientGroup.energy) continue;
      for (final id in n.offIds) {
        final grams = _number(nutriments['${id}_100g']);
        if (grams == null) continue;
        out[n.key] = _round(grams * n.fromGrams, 6);
        break;
      }
    }
  }

  static double? _aggregatedValue(Object? entry) {
    if (entry is! Map) return null;
    return _number(entry['value']) ?? _number(entry['value_computed']);
  }

  static String? _unitOf(Object? entry) =>
      entry is Map ? _string(entry['unit'])?.toLowerCase() : null;

  static bool _isEstimate(Object? entry) =>
      entry is Map && entry['source'] == 'estimate';

  static double? _toGrams(double value, String? unit) => switch (unit) {
    null || 'g' => value,
    'mg' => value / 1000,
    'µg' || 'μg' || 'mcg' || 'ug' => value / 1e6,
    _ => null,
  };

  static String? _firstBrand(String? brands) {
    if (brands == null) return null;
    final first = brands.split(',').first.trim();
    if (first.isEmpty) return null;
    return first.length > 200 ? first.substring(0, 200) : first;
  }

  static String? _string(Object? value) {
    if (value is String) {
      final t = value.trim();
      return t.isEmpty ? null : t;
    }
    if (value is num) return value.toString();
    return null;
  }

  static double? _number(Object? value) {
    double? d;
    if (value is num) {
      d = value.toDouble();
    } else if (value is String) {
      d = double.tryParse(value.trim().replaceAll(',', '.'));
    }
    if (d == null || d.isNaN || d.isInfinite) return null;
    return d;
  }

  static double _round(double value, int decimals) =>
      double.parse(value.toStringAsFixed(decimals));
}

/// GTIN/EAN helpers for barcode entry.
class Gtin {
  const Gtin._();

  /// Removes spaces and dashes; returns null if anything else is not a digit.
  static String? sanitize(String input) {
    final cleaned = input.replaceAll(RegExp(r'[\s-]'), '');
    if (cleaned.isEmpty || !RegExp(r'^\d+$').hasMatch(cleaned)) return null;
    return cleaned;
  }

  /// True if [input] looks like a barcode the user typed into a search box.
  static bool looksLikeBarcode(String input) {
    final s = sanitize(input);
    return s != null && s.length >= 6 && s.length <= 14;
  }

  /// Validates the GS1 check digit for 8, 12, 13 and 14 digit codes.
  /// Returns null for other lengths (no check possible).
  static bool? hasValidCheckDigit(String code) {
    if (![8, 12, 13, 14].contains(code.length)) return null;
    var sum = 0;
    for (var i = 0; i < code.length - 1; i++) {
      final digit = code.codeUnitAt(code.length - 2 - i) - 48;
      sum += digit * (i.isEven ? 3 : 1);
    }
    final check = (10 - sum % 10) % 10;
    return check == code.codeUnitAt(code.length - 1) - 48;
  }
}
