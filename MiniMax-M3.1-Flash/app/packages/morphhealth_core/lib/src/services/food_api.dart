import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../clock.dart';
import '../models/food.dart';
import '../models/nutrients.dart';

/// A single hit of the food search.
class FoodSearchItem {
  const FoodSearchItem({
    required this.code,
    required this.name,
    this.brand,
    this.imageUrl,
    this.quantityLabel,
    this.servingGrams,
    this.servingLabel,
    this.energyKcalPer100,
    this.nutriscoreGrade,
    this.novaGroup,
    this.nutrientsPer100,
  });

  /// Barcode of the product, empty when the product has none.
  final String code;
  final String name;
  final String? brand;
  final String? imageUrl;
  final String? quantityLabel;
  final double? servingGrams;
  final String? servingLabel;
  final double? energyKcalPer100;
  final String? nutriscoreGrade;
  final int? novaGroup;

  /// Nutrients per 100 g as far as the search response already carries them.
  final NutrientProfile? nutrientsPer100;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'barcode': code,
        'name': name,
        if (brand != null) 'brand': brand,
        if (imageUrl != null) 'image_url': imageUrl,
        if (quantityLabel != null) 'quantity': quantityLabel,
        if (servingGrams != null) 'serving_g': servingGrams,
        if (servingLabel != null) 'serving_label': servingLabel,
        if (energyKcalPer100 != null) 'energy_kcal_per_100': energyKcalPer100,
        if (nutriscoreGrade != null) 'nutriscore': nutriscoreGrade,
        if (novaGroup != null) 'nova_group': novaGroup,
        if (nutrientsPer100 != null && nutrientsPer100!.values.isNotEmpty)
          'nutrients_per_100': nutrientsPer100!.toJson(),
      };
}

/// Result page of a food search.
class FoodSearchResult {
  const FoodSearchResult({
    required this.query,
    required this.page,
    required this.pageSize,
    required this.totalCount,
    required this.items,
  });

  final String query;
  final int page;
  final int pageSize;
  final int totalCount;
  final List<FoodSearchItem> items;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'query': query,
        'page': page,
        'page_size': pageSize,
        'total': totalCount,
        'count': items.length,
        'items': items.map((FoodSearchItem i) => i.toJson()).toList(growable: false),
      };
}

/// Result of a barcode lookup.
class FoodLookupResult {
  const FoodLookupResult({
    required this.found,
    this.food,
    this.message,
  });

  final bool found;
  final FoodItem? food;
  final String? message;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'found': found,
        if (message != null) 'message': message,
        if (food != null) 'food': _foodToJson(food!),
      };
}

/// Read only client for the Open Food Facts contract (P08).
///
/// The base URL and the user agent are injected so that the very same code
/// runs against any endpoint that implements the same read only contract.
class FoodApiClient {
  FoodApiClient({
    required this.baseUrl,
    required this.userAgent,
    HttpClient? httpClient,
    this.timeout = const Duration(seconds: 20),
  }) : _http = httpClient ?? HttpClient();

  final String baseUrl;
  final String userAgent;
  final Duration timeout;
  final HttpClient _http;

  void close() => _http.close(force: true);

  String _url(String path, Map<String, String> query) {
    final Uri base = Uri.parse(baseUrl.endsWith('/')
        ? baseUrl.substring(0, baseUrl.length - 1)
        : baseUrl);
    final Map<String, String> merged = <String, String>{...query};
    return base.replace(
      path: '${base.path}$path',
      queryParameters: merged,
    ).toString();
  }

  /// Searches the database by free text.
  ///
  /// Uses `GET {base}/cgi/search.pl` exactly as described by the contract.
  Future<FoodSearchResult> search(
    String query, {
    int page = 1,
    int pageSize = 20,
  }) async {
    final String trimmed = query.trim();
    if (trimmed.isEmpty) {
      return FoodSearchResult(
        query: trimmed,
        page: page,
        pageSize: pageSize,
        totalCount: 0,
        items: const <FoodSearchItem>[],
      );
    }
    final String url = _url('/cgi/search.pl', <String, String>{
      'search_terms': trimmed,
      'search_simple': '1',
      'action': 'process',
      'json': '1',
      'page': '$page',
      'page_size': '$pageSize',
    });
    final dynamic decoded = jsonDecode(await _readBody(url));
    if (decoded is! Map<String, dynamic>) {
      throw const FoodApiException('Unexpected search response');
    }
    final List<dynamic> products =
        (decoded['products'] as List<dynamic>?) ?? const <dynamic>[];
    final List<FoodSearchItem> items = <FoodSearchItem>[];
    for (final dynamic raw in products) {
      if (raw is! Map<String, dynamic>) continue;
      final FoodSearchItem? item = _searchItemFrom(raw);
      if (item != null) items.add(item);
    }
    return FoodSearchResult(
      query: trimmed,
      page: page,
      pageSize: pageSize,
      totalCount: (decoded['count'] as num?)?.toInt() ?? items.length,
      items: items,
    );
  }

  /// Looks a product up by barcode.
  ///
  /// Uses `GET {base}/api/v3.6/product/{barcode}.json`.
  Future<FoodLookupResult> lookup(String barcode) async {
    final String code = barcode.trim();
    if (code.isEmpty) {
      return const FoodLookupResult(found: false, message: 'empty_barcode');
    }
    final String url =
        _url('/api/v3.6/product/${Uri.encodeComponent(code)}.json', <String, String>{});
    final String body = await _readBody(url);
    final dynamic decoded = jsonDecode(body);
    if (decoded is! Map<String, dynamic>) {
      throw const FoodApiException('Unexpected product response');
    }
    final String status = decoded['status'] as String? ?? 'unknown';
    if (status != 'success') {
      return FoodLookupResult(
        found: false,
        message: (decoded['result'] as Map<String, dynamic>?)?['id'] as String? ??
            'not_found',
      );
    }
    final Map<String, dynamic> product =
        (decoded['product'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final FoodItem? food = _foodFromV36(product, code);
    if (food == null) {
      return const FoodLookupResult(found: false, message: 'no_nutrition_data');
    }
    return FoodLookupResult(found: true, food: food);
  }

  Future<String> _readBody(String url) async {
    final HttpClientRequest request = await _http.getUrl(Uri.parse(url));
    request.headers.set(HttpHeaders.userAgentHeader, userAgent);
    request.headers.set(HttpHeaders.acceptHeader, 'application/json');
    final HttpClientResponse response = await request.close().timeout(timeout);
    final String body = await response.transform(utf8.decoder).join();
    if (response.statusCode != 200) {
      throw FoodApiException(
        'Open Food Facts request failed with status ${response.statusCode}',
      );
    }
    return body;
  }

  FoodSearchItem? _searchItemFrom(Map<String, dynamic> raw) {
    final String code = (raw['code'] as String? ?? raw['_id'] as String? ?? '').trim();
    final String name = _productName(raw);
    if (name.isEmpty && code.isEmpty) return null;
    final Map<String, dynamic> nutriments =
        (raw['nutriments'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final double? kcal = _legacyPer100(nutriments, 'energy-kcal');
    final double? servingGrams = _servingGrams(raw);
    return FoodSearchItem(
      code: code,
      name: name.isEmpty ? code : name,
      brand: _clean(raw['brands'] as String?),
      imageUrl: _clean(
        raw['image_front_small_url'] as String? ?? raw['image_small_url'] as String?,
      ),
      quantityLabel: _clean(raw['quantity'] as String?),
      servingGrams: servingGrams,
      servingLabel: _servingLabel(raw, servingGrams),
      energyKcalPer100: kcal,
      nutriscoreGrade: _clean(raw['nutriscore_grade'] as String?),
      novaGroup: (raw['nova_group'] as num?)?.toInt(),
      nutrientsPer100: _legacyProfile(nutriments),
    );
  }

  FoodItem? _foodFromV36(Map<String, dynamic> product, String code) {
    final Map<String, dynamic> nutrition =
        (product['nutrition'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final Map<String, dynamic> aggregated =
        (nutrition['aggregated_set'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    final Map<String, dynamic> nutrients =
        (aggregated['nutrients'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    if (nutrients.isEmpty) return null;

    final double? servingGrams = _servingGrams(product);
    final String per = aggregated['per'] as String? ?? '100g';
    final double perFactor = _perFactor(per, servingGrams);

    final Map<String, double> values = <String, double>{};
    nutrients.forEach((String key, dynamic raw) {
      if (raw is! Map<String, dynamic>) return;
      final String? nutrientId = _nutrientIdFor(key);
      if (nutrientId == null) return;
      final double? value = (raw['value'] as num?)?.toDouble() ??
          (raw['value_computed'] as num?)?.toDouble();
      if (value == null) return;
      final String unit = raw['unit'] as String? ?? 'g';
      final double normalized = _normalizeMass(value, unit);
      final double amount = normalized * perFactor;
      // Two spellings of the same nutrient must not be added up.
      if (!values.containsKey(nutrientId)) values[nutrientId] = amount;
    });

    if (values.isEmpty) return null;

    final String name = _productName(product);
    final List<Portion> portions = <Portion>[];
    if (servingGrams != null && servingGrams > 0) {
      portions.add(Portion(
        label: _servingLabel(product, servingGrams) ?? '1 Portion',
        amountGrams: servingGrams,
        isDefault: true,
      ));
    }

    return FoodItem(
      id: 'off-${code.isEmpty ? Ids.newId() : code}',
      name: name.isEmpty ? code : name,
      source: FoodSource.openFoodFacts,
      brand: _clean(product['brands'] as String?),
      barcode: code.isEmpty ? null : code,
      nutrientsPer100: NutrientProfile(values),
      servingGrams: servingGrams,
      servingLabel: _servingLabel(product, servingGrams),
      portions: portions,
      imageUrl: _clean(
        product['image_front_small_url'] as String? ??
            product['image_small_url'] as String?,
      ),
    );
  }

  static double _perFactor(String per, double? servingGrams) {
    if (per == '100g') return 1.0;
    if (per == 'serving' && servingGrams != null && servingGrams > 0) {
      return 100.0 / servingGrams;
    }
    return 1.0;
  }
}

/// Maps an Open Food Facts nutrient name onto a MorphHealth nutrient id.
///
/// The database uses two spellings for the same nutrients (`proteins` and
/// `protein`, `vitamin-b12` and `vitamin_b12`), so the name is normalised
/// before it is matched.
String? _nutrientIdFor(String offName) {
  final String name = offName.trim().toLowerCase().replaceAll('_', '-');
  switch (name) {
    case 'energy-kcal':
      return Nutrients.energyKcal;
    case 'energy-kj':
      return Nutrients.energyKj;
    case 'proteins':
    case 'protein':
      return Nutrients.protein;
    case 'carbohydrates':
      return Nutrients.carbohydrates;
    case 'fat':
      return Nutrients.fat;
    case 'saturated-fat':
      return Nutrients.saturatedFat;
    case 'sugars':
    case 'sugar':
      return Nutrients.sugars;
    case 'fiber':
    case 'fibres':
      return Nutrients.fiber;
    case 'salt':
      return Nutrients.salt;
    case 'sodium':
      return Nutrients.sodium;
    case 'caffeine':
      return Nutrients.caffeine;
    case 'vitamin-a':
      return Nutrients.vitaminA;
    case 'vitamin-c':
      return Nutrients.vitaminC;
    case 'vitamin-d':
      return Nutrients.vitaminD;
    case 'vitamin-e':
      return Nutrients.vitaminE;
    case 'vitamin-k':
      return Nutrients.vitaminK;
    case 'vitamin-b1':
      return Nutrients.vitaminB1;
    case 'vitamin-b2':
      return Nutrients.vitaminB2;
    case 'vitamin-pp':
    case 'vitamin-b3':
      return Nutrients.vitaminB3;
    case 'pantothenic-acid':
    case 'vitamin-b5':
      return Nutrients.vitaminB5;
    case 'vitamin-b6':
      return Nutrients.vitaminB6;
    case 'biotin':
    case 'vitamin-b7':
      return Nutrients.vitaminB7;
    case 'folic-acid':
    case 'vitamin-b9':
      return Nutrients.vitaminB9;
    case 'vitamin-b12':
      return Nutrients.vitaminB12;
    case 'calcium':
      return Nutrients.calcium;
    case 'iron':
      return Nutrients.iron;
    case 'magnesium':
      return Nutrients.magnesium;
    case 'potassium':
      return Nutrients.potassium;
    case 'zinc':
      return Nutrients.zinc;
    case 'selenium':
      return Nutrients.selenium;
    case 'iodine':
      return Nutrients.iodine;
    case 'phosphorus':
      return Nutrients.phosphorus;
    default:
      return null;
  }
}

/// Normalises a mass into grams.
double _normalizeMass(double value, String unit) {
  switch (unit.trim().toLowerCase()) {
    case 'mg':
      return value / 1000.0;
    case 'µg':
    case 'ug':
    case 'mcg':
      return value / 1000000.0;
    default:
      return value;
  }
}

/// The nutrient names the legacy `nutriments` map uses.
const List<String> kLegacyNutrientNames = <String>[
  'energy-kcal',
  'energy-kj',
  'proteins',
  'carbohydrates',
  'fat',
  'saturated-fat',
  'sugars',
  'fiber',
  'salt',
  'sodium',
  'caffeine',
  'vitamin-a',
  'vitamin-c',
  'vitamin-d',
  'vitamin-e',
  'vitamin-k',
  'vitamin-b1',
  'vitamin-b2',
  'vitamin-pp',
  'vitamin-b3',
  'pantothenic-acid',
  'vitamin-b5',
  'vitamin-b6',
  'biotin',
  'vitamin-b7',
  'vitamin-b9',
  'vitamin-b12',
  'calcium',
  'iron',
  'magnesium',
  'potassium',
  'zinc',
  'selenium',
  'iodine',
  'phosphorus',
];

/// Builds the nutrient profile of a legacy `nutriments` map.
NutrientProfile _legacyProfile(Map<String, dynamic> nutriments) {
  final Map<String, double> values = <String, double>{};
  for (final String base in kLegacyNutrientNames) {
    final String? id = _nutrientIdFor(base);
    if (id == null) continue;
    final double? value = _legacyPer100(nutriments, base);
    if (value == null) continue;
    values[id] = value;
  }
  return NutrientProfile(values);
}

/// Reads the per 100 g value of a legacy `nutriments` map.
double? _legacyPer100(Map<String, dynamic> nutriments, String base) {
  final List<String> candidates = <String>[
    '${base}_prepared_100g',
    '${base}_100g',
  ];
  for (final String candidate in candidates) {
    final dynamic raw = nutriments[candidate];
    if (raw is num) {
      final String unit = nutriments['${base}_unit'] as String? ?? 'g';
      if (base.startsWith('energy')) return raw.toDouble();
      return _normalizeMass(raw.toDouble(), unit);
    }
  }
  return null;
}

String _productName(Map<String, dynamic> raw) {
  final List<String> keys = <String>[
    'product_name_de',
    'product_name',
    'abbreviated_product_name',
    'generic_name_de',
    'generic_name',
    'product_name_en',
  ];
  for (final String key in keys) {
    final String? value = _clean(raw[key] as String?);
    if (value != null && value.isNotEmpty) return value;
  }
  return '';
}

String? _clean(String? value) {
  if (value == null) return null;
  final String trimmed = value.trim();
  return trimmed.isEmpty ? null : trimmed;
}

/// Reads a number that the database may deliver as a number or as a string.
double? _toDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) {
    return double.tryParse(value.trim().replaceAll(',', '.'));
  }
  return null;
}

double? _servingGrams(Map<String, dynamic> raw) {
  final double? servingQuantity = _toDouble(raw['serving_quantity']);
  final String unit = (raw['serving_quantity_unit'] as String? ?? 'g').toLowerCase();
  if (servingQuantity != null && servingQuantity > 0) {
    return unit == 'ml'
        ? servingQuantity.toDouble()
        : servingQuantity.toDouble();
  }
  final String? servingSize = raw['serving_size'] as String?;
  if (servingSize != null) {
    final RegExpMatch? match =
        RegExp(r'([0-9]+(?:[.,][0-9]+)?)\s*(g|ml|gr)?', caseSensitive: false)
            .firstMatch(servingSize);
    if (match != null) {
      final double value =
          double.tryParse(match.group(1)!.replaceAll(',', '.')) ?? 0;
      if (value > 0) return value;
    }
  }
  return null;
}

String? _servingLabel(Map<String, dynamic> raw, double? servingGrams) {
  final String? servingSize = _clean(raw['serving_size'] as String?);
  if (servingSize != null) return servingSize;
  if (servingGrams != null) {
    final num? quantity = raw['product_quantity'] as num?;
    if (quantity != null) {
      final String unit = raw['product_quantity_unit'] as String? ?? 'g';
      return '1 Portion (${_trim(servingGrams)} $unit) / ${_trim(quantity.toDouble())} $unit';
    }
    return '1 Portion (${_trim(servingGrams)} g)';
  }
  return null;
}

String _trim(double value) {
  if (value == value.roundToDouble()) return value.toInt().toString();
  return value.toStringAsFixed(1);
}

Map<String, dynamic> _foodToJson(FoodItem food) => <String, dynamic>{
      'id': food.id,
      'name': food.name,
      'source': food.source == FoodSource.custom ? 'custom' : 'open_food_facts',
      if (food.brand != null) 'brand': food.brand,
      if (food.barcode != null) 'barcode': food.barcode,
      'nutrients_per_100': food.nutrientsPer100.toJson(),
      if (food.servingGrams != null) 'serving_g': food.servingGrams,
      if (food.servingLabel != null) 'serving_label': food.servingLabel,
      if (food.portions.isNotEmpty)
        'portions': food.portions
            .map((Portion p) => p.toJson())
            .toList(growable: false),
      if (food.imageUrl != null) 'image_url': food.imageUrl,
    };

/// Raised when the food service cannot be reached or answers unexpectedly.
class FoodApiException implements Exception {
  const FoodApiException(this.message);

  final String message;

  @override
  String toString() => 'FoodApiException: $message';
}
