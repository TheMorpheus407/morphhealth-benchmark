import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'model.dart';

const _offKeys = <String, List<String>>{
  'energy': ['energy-kcal', 'energy-kj', 'energy'],
  'protein': ['proteins'],
  'carbs': ['carbohydrates'],
  'fat': ['fat'],
  'saturatedFat': ['saturated-fat'],
  'sugar': ['sugars'],
  'fiber': ['fiber'],
  'salt': ['salt'],
  'sodium': ['sodium'],
  'caffeine': ['caffeine'],
  'vitaminA': ['vitamin-a', 'retinol'],
  'vitaminC': ['vitamin-c'],
  'vitaminD': ['vitamin-d'],
  'vitaminE': ['vitamin-e'],
  'vitaminK': ['vitamin-k'],
  'vitaminB1': ['vitamin-b1', 'thiamin'],
  'vitaminB2': ['vitamin-b2', 'riboflavin'],
  'vitaminB3': ['vitamin-pp', 'niacin', 'vitamin-b3'],
  'vitaminB5': ['pantothenic-acid', 'vitamin-b5'],
  'vitaminB6': ['vitamin-b6'],
  'vitaminB7': ['biotin', 'vitamin-b7'],
  'vitaminB9': ['vitamin-b9', 'folates', 'folic-acid'],
  'vitaminB12': ['vitamin-b12'],
  'calcium': ['calcium'],
  'iron': ['iron'],
  'magnesium': ['magnesium'],
  'potassium': ['potassium'],
  'zinc': ['zinc'],
  'selenium': ['selenium'],
  'iodine': ['iodine'],
  'phosphorus': ['phosphorus'],
};

double? _offNumber(dynamic value) {
  final n = numeric(value) ?? (value is String ? double.tryParse(value) : null);
  return n != null && n.isFinite && n >= 0 ? n : null;
}

String _text(dynamic value) => value is String ? value.trim() : '';

double? _convert(double value, String unit, String target) {
  unit = unit.toLowerCase().replaceAll('μ', 'µ');
  if (target == 'kcal') {
    if (unit == 'kcal') return value;
    if (unit == 'kj') return value / 4.184;
    return null;
  }
  final grams = switch (unit) {
    'g' => 1.0,
    'mg' => 0.001,
    'µg' || 'ug' || 'mcg' => 0.000001,
    _ => null,
  };
  if (grams == null) return null; // Do not invent conversions for IU or % DV.
  return value *
      grams /
      switch (target) {
        'g' => 1.0,
        'mg' => 0.001,
        _ => 0.000001,
      };
}

/// Handles v3.5+ structured nutrition and legacy CGI search projections.
/// Missing values remain null; OFF legacy `_100g` mass values are normalized g,
/// independent of the original label's `_unit`. New units are explicit.
Json mapOffProduct(Json product) {
  final barcode = '${product['code'] ?? product['_id'] ?? ''}';
  var name = _text(product['product_name_de']);
  if (name.isEmpty) name = _text(product['product_name']);
  if (name.isEmpty) name = _text(product['product_name_en']);
  if (name.isEmpty) name = _text(product['generic_name']);
  if (name.isEmpty) name = barcode.isEmpty ? 'Open Food Facts' : barcode;
  String brand = _text(product['brands']);
  if (brand.isEmpty && product['brands_tags'] is List) {
    brand = (product['brands_tags'] as List)
        .whereType<String>()
        .map((s) => s.replaceFirst(RegExp(r'^[a-z]{2}:'), ''))
        .join(', ');
  }
  var basis = 'g';
  var perScale = 1.0;
  Map? structured;
  final nutrition = product['nutrition'];
  if (nutrition is Map) {
    final aggregate = nutrition['aggregated_set'];
    if (aggregate is Map && aggregate['preparation'] != 'prepared') {
      structured = aggregate;
    }
    if (structured == null && nutrition['input_sets'] is List) {
      for (final s in nutrition['input_sets'] as List) {
        if (s is Map &&
            s['preparation'] != 'prepared' &&
            ['100g', '100ml'].contains(s['per'])) {
          structured = s;
          break;
        }
      }
    }
  }
  Map modernNutrients = {};
  if (structured != null) {
    final per = structured['per'];
    if (per == '100g' || per == '100ml') {
      basis = per == '100ml' ? 'ml' : 'g';
      if (structured['nutrients'] is Map) {
        modernNutrients = structured['nutrients'] as Map;
      }
    } else {
      final quantity = _offNumber(structured['per_quantity']);
      final unit = structured['per_unit'];
      if (quantity != null && quantity > 0 && ['g', 'ml'].contains(unit)) {
        basis = unit as String;
        perScale = 100 / quantity;
        if (structured['nutrients'] is Map) {
          modernNutrients = structured['nutrients'] as Map;
        }
      }
    }
  } else if (product['nutrition_data_per'] == '100ml') {
    basis = 'ml';
  }
  final legacy = product['nutriments'] is Map
      ? product['nutriments'] as Map
      : <dynamic, dynamic>{};
  final values = <String, dynamic>{};
  for (final n in nutrients) {
    double? mapped;
    for (final key in _offKeys[n.key]!) {
      if (structured != null) {
        final raw = modernNutrients[key];
        if (raw is! Map) continue;
        final value =
            _offNumber(raw['value']) ?? _offNumber(raw['value_computed']);
        if (value == null) continue;
        // '< 0.1 g' is an upper bound, not a measured zero; preserve missingness
        // instead of presenting a falsely exact value in a personal diary.
        if (raw['modifier'] == '<' || raw['modifier'] == '>') continue;
        mapped = _convert(value, _text(raw['unit']), n.unit);
        if (mapped != null) mapped *= perScale;
      } else {
        final value = _offNumber(legacy['${key}_100g']);
        if (value == null) continue;
        if (legacy['${key}_modifier'] == '<' ||
            legacy['${key}_modifier'] == '>') {
          continue;
        }
        mapped = _convert(
          value,
          n.key == 'energy' ? (key == 'energy-kcal' ? 'kcal' : 'kJ') : 'g',
          n.unit,
        );
      }
      if (mapped != null && mapped.isFinite && mapped <= 1000000000) break;
      mapped = null;
    }
    values[n.key] = mapped;
  }
  // Salt and sodium are a defined equivalence used by OFF (salt = sodium*2.5).
  if (values['sodium'] == null && values['salt'] != null) {
    values['sodium'] = (values['salt'] as num) / 2.5;
  }
  if (values['salt'] == null && values['sodium'] != null) {
    values['salt'] = (values['sodium'] as num) * 2.5;
  }
  double? serving;
  final servingUnit = _text(product['serving_quantity_unit']);
  final quantity = _offNumber(product['serving_quantity']);
  if (quantity != null &&
      quantity > 0 &&
      (servingUnit == basis || (servingUnit.isEmpty && basis == 'g'))) {
    serving = quantity;
  }
  if (serving == null) {
    final match = RegExp(
      r'(\d+(?:[.,]\d+)?)\s*(g|ml)\b',
      caseSensitive: false,
    ).firstMatch(_text(product['serving_size']));
    if (match != null && match[2]!.toLowerCase() == basis) {
      serving = double.tryParse(match[1]!.replaceAll(',', '.'));
    }
  }
  if (serving != null && (serving <= 0 || serving > 1000000)) serving = null;
  return validateFood({
    'id': barcode.isEmpty ? newId() : 'off-$barcode',
    'name': name.length > 500 ? name.substring(0, 500) : name,
    'source': 'off',
    'barcode': barcode,
    'brand': brand.length > 1000 ? brand.substring(0, 1000) : brand,
    'basis': basis,
    'servingSize': serving,
    'nutrients': values,
    'favorite': false,
  });
}

class FoodApi {
  final Uri _base;
  final String userAgent;
  FoodApi({required String baseUrl, required this.userAgent})
    : _base = Uri.parse(baseUrl) {
    if (_base.scheme != 'https' ||
        _base.host.isEmpty ||
        _base.userInfo.isNotEmpty ||
        _base.hasQuery ||
        _base.hasFragment ||
        (_base.path.isNotEmpty && _base.path != '/')) {
      throw const CoreException(
        'invalid_origin',
        'Food API base URL must be an HTTPS origin without path, query or credentials.',
      );
    }
    if (userAgent.trim().isEmpty ||
        userAgent.contains('\n') ||
        userAgent.contains('\r')) {
      throw const CoreException(
        'invalid_user_agent',
        'A non-empty User-Agent is required.',
      );
    }
  }
  static const _fields =
      'code,product_name,product_name_de,product_name_en,generic_name,brands,brands_tags,nutrition,nutriments,nutrition_data_per,serving_size,serving_quantity,serving_quantity_unit,product_quantity_unit';

  Future<Json?> _get(String path, Map<String, String> parameters) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final uri = _base.replace(path: path, queryParameters: parameters);
      final request = await client
          .getUrl(uri)
          .timeout(const Duration(seconds: 20));
      request.headers.set(HttpHeaders.userAgentHeader, userAgent);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      request.followRedirects =
          false; // Do not silently send a search to another origin.
      final response = await request.close().timeout(
        const Duration(seconds: 20),
      );
      if (response.statusCode == 404) {
        await response.drain<void>();
        return null;
      }
      if (response.statusCode == 429) {
        throw const CoreException(
          'food_rate_limited',
          'Too many requests. Please try again later.',
        );
      }
      if (response.statusCode != 200) {
        throw CoreException(
          'food_http',
          'Food service returned HTTP ${response.statusCode}.',
        );
      }
      final bytes = <int>[];
      await for (final part in response.timeout(const Duration(seconds: 20))) {
        if (bytes.length + part.length > 16 * 1024 * 1024) {
          throw const CoreException(
            'food_response_too_large',
            'Food response exceeds 16 MiB.',
          );
        }
        bytes.addAll(part);
      }
      final decoded = jsonDecode(utf8.decode(bytes));
      if (decoded is! Map) {
        throw const CoreException(
          'food_invalid_response',
          'Food response must be an object.',
        );
      }
      return Map<String, dynamic>.from(decoded);
    } on CoreException {
      rethrow;
    } on TimeoutException {
      throw const CoreException('food_timeout', 'Food service timed out.');
    } on HandshakeException {
      throw const CoreException(
        'food_tls',
        'The food service certificate could not be verified.',
      );
    } on SocketException {
      throw const CoreException(
        'food_offline',
        'Food service is not reachable.',
      );
    } on HttpException {
      throw const CoreException(
        'food_network',
        'Food connection was interrupted.',
      );
    } on FormatException {
      throw const CoreException(
        'food_invalid_response',
        'Food service returned invalid JSON.',
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<Json> search(String q, {int page = 1}) async {
    q = q.trim();
    if (q.isEmpty || q.length > 200) {
      throw const CoreException(
        'invalid_query',
        'Search requires 1–200 characters.',
      );
    }
    if (page < 1 || page > 100000) {
      throw const CoreException(
        'invalid_page',
        'Page must be between 1 and 100000.',
      );
    }
    final response = await _get('/cgi/search.pl', {
      'search_terms': q,
      'search_simple': '1',
      'action': 'process',
      'json': '1',
      'page': '$page',
      'page_size': '20',
      'fields': _fields,
    });
    if (response == null || response['products'] is! List) {
      throw const CoreException(
        'food_invalid_response',
        'Search response contains no product list.',
      );
    }
    final products = <Json>[];
    for (final raw in (response['products'] as List).take(20)) {
      if (raw is! Map) continue;
      products.add(mapOffProduct(Map<String, dynamic>.from(raw)));
    }
    return {
      'page': page,
      'count': (_offNumber(response['count']) ?? products.length).toInt(),
      'pageSize': 20,
      'products': products,
      'attribution': 'Open Food Facts · ODbL · https://openfoodfacts.org',
    };
  }

  Future<Json?> lookup(String barcode) async {
    barcode = barcode.trim();
    if (!RegExp(r'^\d{4,24}$').hasMatch(barcode)) {
      throw const CoreException(
        'invalid_barcode',
        'Barcode requires 4–24 digits.',
      );
    }
    final response = await _get('/api/v3.6/product/$barcode.json', {
      'fields': _fields,
    });
    if (response == null ||
        response['status'] == 0 ||
        response['result'] is Map &&
            response['result']['id'] == 'product_not_found') {
      return null;
    }
    if (response['product'] is! Map) {
      throw const CoreException(
        'food_invalid_response',
        'Product response contains no product.',
      );
    }
    final p = Map<String, dynamic>.from(response['product'] as Map);
    p['code'] ??= barcode;
    return mapOffProduct(p);
  }
}
