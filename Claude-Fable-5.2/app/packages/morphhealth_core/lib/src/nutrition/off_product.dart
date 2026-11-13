import '../model/food.dart';
import '../model/nutrients.dart';
import '../util/dates.dart';
import '../util/json_reader.dart';

/// A product as read from Open Food Facts, normalized to MorphHealth's units.
class CatalogProduct {
  /// Barcode as normalized by the service.
  final String barcode;
  final String name;

  /// False if the service has no product name and [name] is a stand-in
  /// (brand or barcode).
  final bool hasName;
  final String? brand;

  /// Package size as printed, for example "400 g".
  final String? quantity;
  final FoodBasis basis;

  /// Size of one serving in the basis unit (g or ml), if known.
  final double? servingSize;
  final String? servingLabel;

  /// Amounts per 100 g or per 100 ml in MorphHealth's units.
  final NutrientValues nutrients;

  /// Keys of nutrients whose value is an estimate (source "estimate" or a
  /// value marked with `~`, `<`, `>`).
  final Set<String> estimated;

  /// True if the values describe the prepared product.
  final bool prepared;

  /// Product schema version reported by the service, if any.
  final int? schemaVersion;

  /// Remarks about ignored values, for diagnostics.
  final List<String> notes;

  CatalogProduct({
    required this.barcode,
    required this.name,
    this.hasName = true,
    this.brand,
    this.quantity,
    this.basis = FoodBasis.per100g,
    this.servingSize,
    this.servingLabel,
    NutrientValues? nutrients,
    this.estimated = const {},
    this.prepared = false,
    this.schemaVersion,
    this.notes = const [],
  }) : nutrients = nutrients ?? NutrientValues();

  bool get hasNutrition => !nutrients.isEmpty;

  /// Whether calories and all three macronutrients are known.
  bool get hasMainNutrients => Nutrients.main.every(nutrients.has);

  Map<String, dynamic> toJson() => {
    'barcode': barcode,
    'name': name,
    'name_available': hasName,
    'brand': brand,
    'quantity': quantity,
    'basis': basis.code,
    'serving_size': servingSize == null ? null : roundForJson(servingSize!),
    'serving_unit': servingSize == null ? null : basis.unit,
    'serving_label': servingLabel,
    'prepared': prepared,
    'has_nutrition': hasNutrition,
    'nutrients': nutrients.toJson(),
    'estimated_nutrients': [
      for (final n in Nutrients.all)
        if (estimated.contains(n.key)) n.key,
    ],
    'source': 'open_food_facts',
    'schema_version': schemaVersion,
    if (notes.isNotEmpty) 'notes': notes,
  };

  /// A local food record for this product.
  Food toFood({required String id, required LocalDateTime now}) => Food(
    id: id,
    source: FoodSource.openFoodFacts,
    name: name,
    brand: brand,
    barcode: barcode,
    basis: basis,
    servingSize: servingSize,
    servingLabel: servingLabel,
    packageQuantity: quantity,
    nutrients: nutrients.copy(),
    estimated: Set.of(estimated),
    prepared: prepared,
    createdAt: now,
    updatedAt: now,
    fetchedAt: now,
  );
}

/// Applies the barcode normalization of Open Food Facts: leading zeros are
/// removed; codes of up to 7 digits are padded to 8, codes of 9 to 12 digits
/// to 13. Returns null if [input] is not a plausible barcode.
String? normalizeBarcode(String input) {
  final digits = input.replaceAll(RegExp(r'[\s\-]'), '');
  if (!RegExp(r'^[0-9]{1,24}$').hasMatch(digits)) return null;
  final stripped = digits.replaceFirst(RegExp(r'^0+'), '');
  if (stripped.isEmpty) return null;
  if (stripped.length <= 7) return stripped.padLeft(8, '0');
  if (stripped.length >= 9 && stripped.length <= 12) {
    return stripped.padLeft(13, '0');
  }
  return stripped;
}

/// Whether the last digit of a GTIN-8/12/13/14 matches its check digit.
bool hasValidGtinCheckDigit(String digits) {
  if (!RegExp(r'^[0-9]+$').hasMatch(digits)) return false;
  if (![8, 12, 13, 14].contains(digits.length)) return false;
  var sum = 0;
  for (var i = 0; i < digits.length - 1; i++) {
    final d = digits.codeUnitAt(digits.length - 2 - i) - 0x30;
    sum += i.isEven ? d * 3 : d;
  }
  final check = (10 - sum % 10) % 10;
  return check == digits.codeUnitAt(digits.length - 1) - 0x30;
}

/// Reads one product object of an Open Food Facts response.
///
/// Understands both shapes the read contract uses:
///
/// * product schema 1003 and later (API v3.5+): `nutrition.aggregated_set`
///   with one object per nutrient (`value`, `unit`, `source`, `modifier`);
/// * the older flat `nutriments` map with `<id>_100g` members, as still
///   returned by the search endpoint.
///
/// Whatever the response contains is used; no assumption is made about which
/// endpoint returns which shape. Returns null if [product] has no barcode.
CatalogProduct? parseOffProduct(
  Map<String, dynamic> product, {
  List<String> languages = const ['de', 'en'],
  String? fallbackBarcode,
}) {
  final code =
      _text(product['code']) ?? _text(product['_id']) ?? fallbackBarcode;
  if (code == null || code.isEmpty) return null;

  final notes = <String>[];
  final brand = _brand(product);

  String? name;
  for (final key in [
    for (final l in languages) 'product_name_$l',
    'product_name',
    for (final l in ['de', 'en']) 'product_name_$l',
    for (final l in languages) 'generic_name_$l',
    'generic_name',
    'abbreviated_product_name',
  ]) {
    name = _text(product[key]);
    if (name != null) break;
  }
  final hasName = name != null;
  name ??= brand ?? code;
  if (name.length > 200) name = name.substring(0, 200);

  final servingQuantityRaw = _number(product['serving_quantity']);
  final servingUnitRaw = _text(product['serving_quantity_unit'])?.toLowerCase();
  final servingText = _text(product['serving_size']);

  _Extract? extract;
  final nutrition = product['nutrition'];
  if (nutrition is Map) {
    extract = _fromNutrition(
      nutrition.cast<String, dynamic>(),
      servingQuantityRaw,
      servingUnitRaw,
      notes,
    );
  }
  final nutriments = product['nutriments'];
  if ((extract == null || extract.values.isEmpty) && nutriments is Map) {
    extract = _fromNutriments(
      nutriments.cast<String, dynamic>(),
      product,
      servingQuantityRaw,
      servingUnitRaw,
      notes,
    );
  }

  var basis = extract?.basis;
  if (basis == null) {
    final unit = _text(product['product_quantity_unit'])?.toLowerCase();
    basis = unit == 'ml' || servingUnitRaw == 'ml'
        ? FoodBasis.per100ml
        : FoodBasis.per100g;
  }

  // Serving size, in g or ml.
  double? servingSize = servingQuantityRaw;
  if (servingSize == null && servingText != null) {
    servingSize = _servingFromText(servingText, servingUnitRaw);
  }
  if (servingSize != null && (servingSize <= 0 || servingSize > 5000)) {
    servingSize = null;
  }
  var servingLabel = servingText;
  if (servingLabel != null && servingLabel.length > 100) {
    servingLabel = servingLabel.substring(0, 100);
  }
  if (servingSize == null) servingLabel = null;

  var quantity = _text(product['quantity']);
  if (quantity != null && quantity.length > 100) {
    quantity = quantity.substring(0, 100);
  }

  final schema = product['schema_version'];
  return CatalogProduct(
    barcode: code,
    name: name,
    hasName: hasName,
    brand: brand,
    quantity: quantity,
    basis: basis,
    servingSize: servingSize,
    servingLabel: servingLabel,
    nutrients: extract?.values,
    estimated: extract?.estimated ?? const {},
    prepared: extract?.prepared ?? false,
    schemaVersion: schema is int ? schema : null,
    notes: notes,
  );
}

class _Extract {
  final NutrientValues values = NutrientValues();
  final Set<String> estimated = {};
  FoodBasis? basis;
  bool prepared = false;
}

const double _maxGramsPer100 = 100.0001;
const double _maxKcalPer100 = 1000;

/// Stores [grams] (per 100 g/ml after scaling) for [n], unless impossible.
void _putMass(_Extract out, Nutrient n, double grams, List<String> notes) {
  if (grams.isNaN || grams.isInfinite || grams < 0) return;
  if (grams > _maxGramsPer100) {
    notes.add('${n.key}: implausible value ignored');
    return;
  }
  out.values[n] = grams * n.unitsPerGram;
}

void _putEnergy(_Extract out, double kcal, List<String> notes) {
  if (kcal.isNaN || kcal.isInfinite || kcal < 0) return;
  if (kcal > _maxKcalPer100) {
    notes.add('${Nutrients.energy.key}: implausible value ignored');
    return;
  }
  out.values[Nutrients.energy] = kcal;
}

/// Grams per one of [unit], or null if the unit is not a mass.
double? _gramsPer(String? unit) {
  final u = (unit ?? 'g').trim().toLowerCase();
  switch (u) {
    case '':
    case 'g':
      return 1;
    case 'mg':
      return 1e-3;
    case 'µg': // micro sign
    case 'μg': // greek mu
    case 'mcg':
    case 'ug':
      return 1e-6;
    case 'kg':
      return 1000;
  }
  return null;
}

// ------------------------------------------------- schema 1003+: nutrition

_Extract? _fromNutrition(
  Map<String, dynamic> nutrition,
  double? servingQuantity,
  String? servingUnit,
  List<String> notes,
) {
  Map<String, dynamic>? set;
  final aggregated = nutrition['aggregated_set'];
  if (aggregated is Map &&
      aggregated['nutrients'] is Map &&
      (aggregated['nutrients'] as Map).isNotEmpty) {
    set = aggregated.cast<String, dynamic>();
  } else {
    // Without an aggregated set, choose the best input set ourselves, in the
    // documented order of preference of the sources.
    final inputs = nutrition['input_sets'];
    if (inputs is List) {
      var best = 1 << 30;
      for (final raw in inputs) {
        if (raw is! Map ||
            raw['nutrients'] is! Map ||
            (raw['nutrients'] as Map).isEmpty) {
          continue;
        }
        const order = ['manufacturer', 'packaging', 'usda', 'estimate'];
        final sourceRank = order.indexOf('${raw['source']}');
        final score =
            (sourceRank < 0 ? 3 : sourceRank) * 4 +
            (raw['preparation'] == 'prepared' ? 2 : 0) +
            (raw['per'] == 'serving' ? 1 : 0);
        if (score < best) {
          best = score;
          set = raw.cast<String, dynamic>();
        }
      }
    }
  }
  if (set == null) return null;

  final out = _Extract()..prepared = set['preparation'] == 'prepared';
  final per = '${set['per'] ?? '100g'}';
  var scale = 1.0;
  if (per == '100ml') {
    out.basis = FoodBasis.per100ml;
  } else if (per == 'serving') {
    final quantity = _number(set['per_quantity']) ?? servingQuantity;
    final unit = (_text(set['per_unit']) ?? servingUnit)?.toLowerCase();
    if (quantity == null || quantity <= 0) {
      notes.add('nutrition is given per serving of unknown size');
      return out;
    }
    scale = 100 / quantity;
    out.basis = unit == 'ml' ? FoodBasis.per100ml : FoodBasis.per100g;
  } else {
    out.basis = FoodBasis.per100g;
  }

  final nutrients = (set['nutrients'] as Map).cast<String, dynamic>();
  final setIsEstimate = set['source'] == 'estimate';

  ({double value, String? unit, bool estimated})? read(String id) {
    final raw = nutrients[id];
    if (raw is! Map) return null;
    final value = _number(raw['value']) ?? _number(raw['value_computed']);
    if (value == null) return null;
    final modifier = _text(raw['modifier']);
    return (
      value: value * scale,
      unit: _text(raw['unit']),
      estimated:
          setIsEstimate || raw['source'] == 'estimate' || modifier != null,
    );
  }

  // Energy: kilocalories if stated, otherwise converted from kilojoules.
  final kcal = read('energy-kcal');
  if (kcal != null && (kcal.unit ?? 'kcal').toLowerCase() == 'kcal') {
    _putEnergy(out, kcal.value, notes);
    if (kcal.estimated) out.estimated.add(Nutrients.energy.key);
  } else {
    final kj = read('energy-kj') ?? read('energy');
    if (kj != null && (kj.unit ?? 'kj').toLowerCase() == 'kj') {
      _putEnergy(out, kj.value / Nutrients.kjPerKcal, notes);
      if (kj.estimated) out.estimated.add(Nutrients.energy.key);
    }
  }

  for (final n in Nutrients.all) {
    if (n == Nutrients.energy) continue;
    for (final id in n.offIds) {
      final v = read(id);
      if (v == null) continue;
      final factor = _gramsPer(v.unit);
      if (factor == null) {
        notes.add('${n.key}: unit "${v.unit}" not understood');
        continue;
      }
      _putMass(out, n, v.value * factor, notes);
      if (out.values.has(n)) {
        if (v.estimated) out.estimated.add(n.key);
        break;
      }
    }
  }
  return out;
}

// ------------------------------------------------ older schema: nutriments

_Extract? _fromNutriments(
  Map<String, dynamic> m,
  Map<String, dynamic> product,
  double? servingQuantity,
  String? servingUnit,
  List<String> notes,
) {
  if (m.isEmpty) return null;
  const probes = [
    'energy-kcal',
    'energy',
    'energy-kj',
    'proteins',
    'carbohydrates',
    'fat',
  ];

  // Preference: as sold per 100, prepared per 100, as sold per serving,
  // prepared per serving.
  String? variant;
  var perServing = false;
  for (final candidate in const [
    ('', false),
    ('_prepared', false),
    ('', true),
    ('_prepared', true),
  ]) {
    final suffix = '${candidate.$1}${candidate.$2 ? '_serving' : '_100g'}';
    if (probes.any((id) => _number(m['$id$suffix']) != null)) {
      variant = candidate.$1;
      perServing = candidate.$2;
      break;
    }
  }
  // No main nutrient at all: still take what is given per 100.
  variant ??= '';

  final out = _Extract()..prepared = variant == '_prepared';
  var scale = 1.0;
  final dataPer = _text(product['nutrition_data_per'])?.toLowerCase();
  if (perServing) {
    if (servingQuantity == null || servingQuantity <= 0) {
      notes.add('nutrition is given per serving of unknown size');
      return out;
    }
    scale = 100 / servingQuantity;
    out.basis = servingUnit == 'ml' ? FoodBasis.per100ml : FoodBasis.per100g;
  } else if (dataPer == '100ml') {
    out.basis = FoodBasis.per100ml;
  } else if (dataPer == '100g') {
    out.basis = FoodBasis.per100g;
  }
  final suffix = '$variant${perServing ? '_serving' : '_100g'}';

  double? read(String id) {
    final v = _number(m['$id$suffix']);
    return v == null ? null : v * scale;
  }

  bool marked(String id) => _text(m['${id}_modifier']) != null;

  final kcal = read('energy-kcal');
  if (kcal != null) {
    _putEnergy(out, kcal, notes);
    if (marked('energy-kcal')) out.estimated.add(Nutrients.energy.key);
  } else {
    final kj = read('energy-kj') ?? read('energy');
    if (kj != null) {
      _putEnergy(out, kj / Nutrients.kjPerKcal, notes);
      if (marked('energy')) out.estimated.add(Nutrients.energy.key);
    }
  }

  // In this schema all "_100g" and "_serving" amounts are in grams.
  for (final n in Nutrients.all) {
    if (n == Nutrients.energy) continue;
    for (final id in n.offIds) {
      final grams = read(id);
      if (grams == null) continue;
      _putMass(out, n, grams, notes);
      if (out.values.has(n)) {
        if (marked(id)) out.estimated.add(n.key);
        break;
      }
    }
  }
  return out;
}

// ----------------------------------------------------------------- helpers

String? _text(Object? v) {
  if (v == null) return null;
  if (v is! String && v is! num) return null;
  final s = _decodeEntities('$v').replaceAll(RegExp(r'\s+'), ' ').trim();
  return s.isEmpty ? null : s;
}

String _decodeEntities(String s) {
  if (!s.contains('&')) return s;
  return s
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&apos;', "'")
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&amp;', '&');
}

/// A finite, non-negative number from a JSON number or numeric string.
double? _number(Object? v) {
  double? d;
  if (v is num) {
    d = v.toDouble();
  } else if (v is String) {
    d = double.tryParse(v.trim().replaceAll(',', '.'));
  }
  if (d == null || d.isNaN || d.isInfinite || d < 0) return null;
  return d;
}

String? _brand(Map<String, dynamic> product) {
  final parts = <String>[];
  final raw = _text(product['brands']);
  if (raw != null) {
    parts.addAll(raw.split(','));
  } else {
    final tags = product['brands_tags'];
    if (tags is List) {
      for (final t in tags) {
        if (t is String) {
          parts.add(
            t.replaceFirst(RegExp(r'^[a-z]{2}:'), '').replaceAll('-', ' '),
          );
        }
      }
    }
  }
  final seen = <String>{};
  final out = <String>[];
  for (final p in parts) {
    final t = p.trim();
    if (t.isEmpty || !seen.add(t.toLowerCase())) continue;
    out.add(t);
    if (out.length == 3) break;
  }
  if (out.isEmpty) return null;
  final joined = out.join(', ');
  return joined.length > 200 ? joined.substring(0, 200) : joined;
}

final RegExp _quantityInText = RegExp(
  r'(\d+(?:[.,]\d+)?)\s*(kg|g|ml|cl|dl|l)\b',
  caseSensitive: false,
);

/// Extracts a size in g or ml from texts such as "30 g", "1 Glas (250 ml)" or
/// "33" (with [defaultUnit]).
double? _servingFromText(String text, String? defaultUnit) {
  final inParens = RegExp(r'\(([^)]*)\)').firstMatch(text);
  final match =
      (inParens == null
          ? null
          : _quantityInText.firstMatch(inParens.group(1)!)) ??
      _quantityInText.firstMatch(text);
  if (match != null) {
    final value = double.tryParse(match.group(1)!.replaceAll(',', '.'));
    if (value == null) return null;
    switch (match.group(2)!.toLowerCase()) {
      case 'kg':
      case 'l':
        return value * 1000;
      case 'dl':
        return value * 100;
      case 'cl':
        return value * 10;
      default:
        return value;
    }
  }
  if (defaultUnit != null && RegExp(r'^\d+(?:[.,]\d+)?$').hasMatch(text)) {
    return double.tryParse(text.replaceAll(',', '.'));
  }
  return null;
}
