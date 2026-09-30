import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'model.dart';
import 'nutrients.dart';

const foodProjection =
    'code,product_name,product_name_de,product_name_en,brands,nutriments,nutrition,serving_size,serving_quantity,nutrition_data_per';
const foodAttribution = {
  'name': 'Open Food Facts',
  'license': 'ODbL 1.0',
  'url': 'https://world.openfoodfacts.org',
};

class FoodApi {
  final Uri origin;
  final String userAgent;
  FoodApi(String base, this.userAgent) : origin = Uri.parse(base) {
    if (origin.scheme != 'https' ||
        origin.host.isEmpty ||
        origin.userInfo.isNotEmpty ||
        (origin.path.isNotEmpty && origin.path != '/') ||
        origin.hasQuery ||
        origin.hasFragment) {
      throw const FormatException('https_origin_required');
    }
    if (userAgent.trim().isEmpty ||
        userAgent.contains('\n') ||
        userAgent.contains('\r')) {
      throw const FormatException('invalid_user_agent');
    }
  }
  Future<Json> _get(
    String path,
    Map<String, String> query, {
    bool notFound = false,
  }) async {
    final client = HttpClient()
      ..connectionTimeout = const Duration(seconds: 15);
    try {
      final uri = origin.replace(path: path, queryParameters: query);
      final request = await client
          .getUrl(uri)
          .timeout(const Duration(seconds: 20));
      request.headers.set(HttpHeaders.userAgentHeader, userAgent);
      request.headers.set(HttpHeaders.acceptHeader, 'application/json');
      final response = await request.close().timeout(
        const Duration(seconds: 20),
      );
      if (response.statusCode == 404 && notFound) return {};
      if (response.statusCode == 429) throw const FoodApiError('rate_limited');
      if (response.statusCode != 200) {
        throw FoodApiError('http_${response.statusCode}');
      }
      final bytes = <int>[];
      await for (final chunk in response.timeout(const Duration(seconds: 20))) {
        bytes.addAll(chunk);
        if (bytes.length > 16 * 1024 * 1024) {
          throw const FoodApiError('response_too_large');
        }
      }
      return object(jsonDecode(utf8.decode(bytes)), 'api_response');
    } on SocketException {
      throw const FoodApiError('network_unavailable');
    } on HandshakeException {
      throw const FoodApiError('tls_error');
    } on TimeoutException {
      throw const FoodApiError('request_timeout');
    } finally {
      client.close(force: true);
    }
  }

  Future<Json> search(String q, int page) async {
    if (q.trim().isEmpty || q.length > 500 || page < 1) {
      throw const FormatException('invalid_search');
    }
    final result = await _get('/cgi/search.pl', {
      'search_terms': q.trim(),
      'search_simple': '1',
      'action': 'process',
      'json': '1',
      'page': page.toString(),
      'page_size': '20',
      'fields': foodProjection,
    });
    final raw = result['products'];
    if (raw is! List) throw const FoodApiError('invalid_response');
    final products = raw
        .map((p) => normalizeFood(object(p, 'product')))
        .whereType<Json>()
        .toList();
    final count = number(result['count'])?.toInt();
    return {
      'query': q.trim(),
      'page': page,
      'page_size': 20,
      'count': count,
      'has_more': count == null ? raw.length >= 20 : page * 20 < count,
      'products': products,
      'attribution': foodAttribution,
    };
  }

  Future<Json> lookup(String barcode) async {
    if (!RegExp(r'^\d{4,24}$').hasMatch(barcode)) {
      throw const FormatException('invalid_barcode');
    }
    final result = await _get('/api/v3.6/product/$barcode.json', {
      'fields': foodProjection,
    }, notFound: true);
    final product = result['product'] is Map
        ? normalizeFood(object(result['product'], 'product'))
        : null;
    return {
      'barcode': barcode,
      'found': product != null,
      'product': product,
      'attribution': foodAttribution,
    };
  }
}

class FoodApiError implements Exception {
  final String code;
  const FoodApiError(this.code);
  @override
  String toString() => code;
}

Json? normalizeFood(Json product) {
  final code = (product['code'] ?? '').toString();
  if (code.isEmpty) return null;
  String? nonempty(dynamic s) =>
      s is String && s.trim().isNotEmpty ? s.trim() : null;
  final name =
      nonempty(product['product_name_de']) ??
      nonempty(product['product_name']) ??
      nonempty(product['product_name_en']) ??
      code;
  final english = nonempty(product['product_name_en']);
  final nutrition = product['nutrition'];
  final aggregate = nutrition is Map ? nutrition['aggregated_set'] : null;
  final structured = aggregate is Map && aggregate['nutrients'] is Map
      ? aggregate['nutrients'] as Map
      : null;
  final legacy = product['nutriments'] is Map
      ? product['nutriments'] as Map
      : {};
  final per = aggregate is Map
      ? aggregate['per']?.toString()
      : product['nutrition_data_per']?.toString();
  final servingText = (product['serving_size'] ?? '').toString().toLowerCase();
  final servingMatch = RegExp(
    r'(\d+(?:[.,]\d+)?)\s*(ml|g)\b',
  ).firstMatch(servingText);
  final servingAmount =
      number(product['serving_quantity']) ?? number(servingMatch?.group(1));
  final base = per == '100ml' ? 'ml' : 'g';
  final compatibleServing =
      servingMatch == null || servingMatch.group(2) == base;
  final values = <String, dynamic>{};
  final estimated = <String>[];
  const aliases = {
    'vitamin_b3': ['vitamin-pp', 'vitamin-b3', 'niacin'],
    'vitamin_b5': ['pantothenic-acid', 'vitamin-b5'],
    'vitamin_b7': ['biotin', 'vitamin-b7'],
    'vitamin_k': ['vitamin-k', 'phylloquinone'],
  };
  for (final n in nutrients) {
    double? value;
    for (final key in aliases[n.id] ?? [n.off]) {
      final s = structured?[key];
      if (s is Map) {
        final raw = number(s['value']);
        final unit = (s['unit'] ?? 'g').toString();
        if (raw != null) {
          value = n.unit == 'kcal'
              ? (unit == 'kcal'
                    ? raw
                    : unit == 'kJ'
                    ? raw / 4.184
                    : null)
              : massConvert(raw, unit, n.unit);
          if (per == 'serving') {
            value = value != null && servingAmount != null && servingAmount > 0
                ? value * 100 / servingAmount
                : null;
          } else if (per != '100g' && per != '100ml') {
            value = null;
          }
          if (value != null &&
              (s['source'] == 'estimate' || s['modifier'] != null)) {
            estimated.add(n.id);
          }
        }
      }
      if (value == null) {
        // Legacy _100g fields are normalized to grams, regardless of the
        // label-input _unit field. They also represent 100ml for liquids.
        final raw = number(legacy['${key}_100g']);
        if (raw != null) {
          value = n.unit == 'kcal' ? raw : gramsToUnit(raw, n.unit);
        }
      }
      if (value != null) break;
    }
    if (n.id == 'calories' && value == null) {
      final energy = structured?['energy-kj'] ?? structured?['energy'];
      if (energy is Map && (energy['unit'] == 'kJ')) {
        value = number(energy['value']);
        if (value != null) value /= 4.184;
        if (per == 'serving') {
          value = value != null && servingAmount != null && servingAmount > 0
              ? value * 100 / servingAmount
              : null;
        }
      } else {
        final kj =
            number(legacy['energy-kj_100g']) ?? number(legacy['energy_100g']);
        value = kj == null ? null : kj / 4.184;
      }
    }
    values[n.id] = value != null && value.isFinite && value >= 0 ? value : null;
  }
  if (values['sodium'] == null && values['salt'] != null) {
    values['sodium'] = number(values['salt'])! * 1000 / 2.5;
    estimated.add('sodium');
  } else if (values['salt'] == null && values['sodium'] != null) {
    values['salt'] = number(values['sodium'])! / 1000 * 2.5;
    estimated.add('salt');
  }
  final food = <String, dynamic>{
    'id': 'off_$code',
    'name': name,
    'name_en': english,
    'brand': nonempty(product['brands']),
    'barcode': code,
    'source': 'off',
    'base_unit': base,
    'serving_size':
        compatibleServing && servingAmount != null && servingAmount > 0
        ? servingAmount
        : null,
    'grams_per_ml': null,
    'nutrients': values,
    'estimated': estimated.toSet().toList(),
    'favorite': false,
  };
  validateFood(food);
  return food;
}
