/// Read-only Open Food Facts API client supporting the P08 contract:
/// - GET {base}/api/v3.6/product/{barcode}.json
/// - GET {base}/cgi/search.pl?search_terms={q}&search_simple=1&action=process&json=1&page={p}&page_size=20
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'clock.dart';
import 'models.dart';
import 'nutrients.dart';

class FoodApiException implements Exception {
  final String code;
  final String message;
  final int? statusCode;

  const FoodApiException(this.code, this.message, {this.statusCode});

  @override
  String toString() => 'FoodApiException($code): $message';
}

class FoodNotFoundException extends FoodApiException {
  final String barcode;
  const FoodNotFoundException(this.barcode)
      : super(
          'PRODUCT_NOT_FOUND',
          'No product found in Open Food Facts for barcode "$barcode".',
          statusCode: 404,
        );
}

class FoodSearchPage {
  final String query;
  final int page;
  final int pageSize;
  final int totalCount;
  final int pageCount;
  final List<FoodItem> items;

  const FoodSearchPage({
    required this.query,
    required this.page,
    required this.pageSize,
    required this.totalCount,
    required this.pageCount,
    required this.items,
  });

  Map<String, dynamic> toJson() => {
        'query': query,
        'page': page,
        'page_size': pageSize,
        'total_count': totalCount,
        'page_count': pageCount,
        'items': items.map((e) => e.toJson()).toList(),
      };
}

class OpenFoodFactsClient {
  static const String defaultProductionBaseUrl = 'https://world.openfoodfacts.org';
  static const String defaultUserAgent = 'MorphHealth/1.0';

  static const String _projectedFields =
      'code,product_name,product_name_de,product_name_en,generic_name,generic_name_de,'
      'brands,quantity,serving_size,serving_quantity,serving_quantity_unit,'
      'nutrition_data_per,nutriments,nutrition';

  final String baseUrl;
  final String userAgent;
  final http.Client _httpClient;
  final AppClock _clock;
  final Duration timeout;

  OpenFoodFactsClient({
    required String baseUrl,
    required String userAgent,
    http.Client? httpClient,
    AppClock clock = const SystemClock(),
    this.timeout = const Duration(seconds: 12),
    bool requireHttps = true,
  })  : baseUrl = _normalizeBaseUrl(baseUrl, requireHttps: requireHttps),
        userAgent = userAgent.trim().isEmpty ? defaultUserAgent : userAgent.trim(),
        _httpClient = httpClient ?? http.Client(),
        _clock = clock;

  static String _normalizeBaseUrl(String raw, {required bool requireHttps}) {
    var trimmed = raw.trim();
    if (trimmed.isEmpty) {
      trimmed = defaultProductionBaseUrl;
    }
    while (trimmed.endsWith('/')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasAuthority) {
      throw FoodApiException(
        'INVALID_BASE_URL',
        'Invalid Open Food Facts origin URL: "$raw".',
      );
    }
    if (requireHttps && uri.scheme != 'https') {
      throw FoodApiException(
        'INSECURE_BASE_URL',
        'Open Food Facts origin must use HTTPS (got "${uri.scheme}").',
      );
    }
    return trimmed;
  }

  Map<String, String> get _headers => {
        'User-Agent': userAgent,
        'Accept': 'application/json',
      };

  Future<FoodItem> lookupBarcode(String rawBarcode) async {
    final barcode = rawBarcode.trim();
    if (barcode.isEmpty || !RegExp(r'^[A-Za-z0-9_-]{4,32}$').hasMatch(barcode)) {
      throw const FoodApiException(
        'INVALID_ARGUMENT',
        'Barcode must be 4–32 alphanumeric/digit characters.',
      );
    }

    final uri = Uri.parse(
      '$baseUrl/api/v3.6/product/${Uri.encodeComponent(barcode)}.json',
    ).replace(queryParameters: {'fields': _projectedFields});

    http.Response response;
    try {
      response = await _httpClient.get(uri, headers: _headers).timeout(timeout);
    } on TimeoutException {
      throw const FoodApiException(
        'TIMEOUT',
        'Open Food Facts product lookup timed out.',
      );
    } catch (e) {
      throw FoodApiException(
        'NETWORK_ERROR',
        'Unable to reach Open Food Facts endpoint: $e',
      );
    }

    if (response.statusCode == 404) {
      throw FoodNotFoundException(barcode);
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FoodApiException(
        'UPSTREAM_HTTP_ERROR',
        'Open Food Facts returned HTTP ${response.statusCode}.',
        statusCode: response.statusCode,
      );
    }

    Map<String, dynamic> body;
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Expected JSON object');
      }
      body = decoded;
    } catch (e) {
      throw FoodApiException(
        'UPSTREAM_PARSE_ERROR',
        'Invalid JSON response from Open Food Facts: $e',
      );
    }

    final status = body['status'];
    if (status == 'failure' || status == 0 || status == '0') {
      throw FoodNotFoundException(barcode);
    }
    final prod = body['product'];
    if (prod is! Map<String, dynamic> || prod.isEmpty) {
      throw FoodNotFoundException(barcode);
    }

    final parsed = parseOffProduct(prod, fallbackBarcode: barcode, clock: _clock);
    if (parsed == null) {
      throw FoodNotFoundException(barcode);
    }
    return parsed;
  }

  Future<FoodSearchPage> searchProducts({
    required String query,
    int page = 1,
    int pageSize = 20,
  }) async {
    final q = query.trim();
    if (q.isEmpty) {
      throw const FoodApiException(
        'INVALID_ARGUMENT',
        'Search query "q" must not be empty.',
      );
    }
    if (page < 1) {
      throw const FoodApiException(
        'INVALID_ARGUMENT',
        'Page number must be >= 1.',
      );
    }
    final clampedPageSize = pageSize.clamp(1, 50);

    final uri = Uri.parse('$baseUrl/cgi/search.pl').replace(
      queryParameters: {
        'search_terms': q,
        'search_simple': '1',
        'action': 'process',
        'json': '1',
        'page': page.toString(),
        'page_size': clampedPageSize.toString(),
        'fields': _projectedFields,
      },
    );

    http.Response response;
    try {
      response = await _httpClient.get(uri, headers: _headers).timeout(timeout);
    } on TimeoutException {
      throw const FoodApiException(
        'TIMEOUT',
        'Open Food Facts search timed out.',
      );
    } catch (e) {
      throw FoodApiException(
        'NETWORK_ERROR',
        'Unable to reach Open Food Facts search endpoint: $e',
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw FoodApiException(
        'UPSTREAM_HTTP_ERROR',
        'Open Food Facts search returned HTTP ${response.statusCode}.',
        statusCode: response.statusCode,
      );
    }

    Map<String, dynamic> body;
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is! Map<String, dynamic>) {
        throw const FormatException('Expected JSON object');
      }
      body = decoded;
    } catch (e) {
      throw FoodApiException(
        'UPSTREAM_PARSE_ERROR',
        'Invalid JSON response from Open Food Facts search: $e',
      );
    }

    final rawProducts = body['products'];
    final items = <FoodItem>[];
    if (rawProducts is List) {
      for (final raw in rawProducts) {
        if (raw is Map<String, dynamic>) {
          final item = parseOffProduct(raw, clock: _clock);
          if (item != null) {
            items.add(item);
          }
        }
      }
    }

    final totalCount = _asInt(body['count']) ?? items.length;
    final totalPages = totalCount == 0
        ? 0
        : ((totalCount + clampedPageSize - 1) ~/ clampedPageSize);

    return FoodSearchPage(
      query: q,
      page: _asInt(body['page']) ?? page,
      pageSize: clampedPageSize,
      totalCount: totalCount,
      pageCount: totalPages,
      items: items,
    );
  }

  static FoodItem? parseOffProduct(
    Map<String, dynamic> prod, {
    String? fallbackBarcode,
    AppClock clock = const SystemClock(),
  }) {
    final code = _nonEmptyStr(prod['code']) ?? fallbackBarcode;
    final nameDe =
        _nonEmptyStr(prod['product_name_de']) ?? _nonEmptyStr(prod['generic_name_de']);
    final nameEn =
        _nonEmptyStr(prod['product_name_en']) ?? _nonEmptyStr(prod['generic_name']);
    final generic = _nonEmptyStr(prod['product_name']) ??
        nameDe ??
        nameEn ??
        _nonEmptyStr(prod['generic_name']);

    final primaryName = nameDe ?? generic ?? nameEn ?? (code != null ? 'Produkt $code' : null);
    if (primaryName == null || primaryName.isEmpty) {
      return null;
    }

    final brandsRaw = _nonEmptyStr(prod['brands']);
    final brand = brandsRaw?.split(',').first.trim();

    final servingLabel = _nonEmptyStr(prod['serving_size']);
    final servingQty = _extractServingQuantity(
      prod['serving_quantity'],
      servingLabel,
    );

    final basis = _extractBasis(prod);
    final nutrients = _extractNutrientsPer100(prod);
    final stamp = clock.nowRfc3339();
    final id = code != null && code.isNotEmpty
        ? 'off:$code'
        : generateEntityId('off');

    return FoodItem(
      id: id,
      source: FoodSource.openFoodFacts,
      barcode: code,
      name: primaryName,
      nameDe: nameDe,
      nameEn: nameEn,
      brand: (brand != null && brand.isNotEmpty) ? brand : null,
      nutritionBasis: basis,
      servingQuantity: servingQty,
      servingLabel: servingLabel,
      nutrientsPer100: nutrients,
      isFavorite: false,
      createdAt: stamp,
      updatedAt: stamp,
    );
  }

  static String _extractBasis(Map<String, dynamic> prod) {
    final per = _nonEmptyStr(prod['nutrition_data_per'])?.toLowerCase();
    if (per == '100ml') return '100ml';
    final sqUnit = _nonEmptyStr(prod['serving_quantity_unit'])?.toLowerCase();
    if (sqUnit == 'ml' || sqUnit == 'cl' || sqUnit == 'l') {
      final nutrition = prod['nutrition'];
      if (nutrition is Map<String, dynamic>) {
        final agg = nutrition['aggregated_set'];
        if (agg is Map<String, dynamic>) {
          final nutrients = agg['nutrients'];
          if (nutrients is Map<String, dynamic>) {
            final kcal = nutrients['energy-kcal'];
            if (kcal is Map && kcal['source_per'] == '100ml') {
              return '100ml';
            }
          }
        }
      }
    }
    return '100g';
  }

  static double _extractServingQuantity(dynamic rawQty, String? servingSizeStr) {
    final direct = _asDouble(rawQty);
    if (direct != null && direct > 0 && direct <= 5000) {
      return direct;
    }
    if (servingSizeStr != null) {
      // Prefer parenthesized weight/volume first e.g. "4 pieces (33.3 g)" -> 33.3
      final parenMatch = RegExp(
        r'\((\d+(?:[.,]\d+)?)\s*(g|ml|cl|l)\)',
        caseSensitive: false,
      ).firstMatch(servingSizeStr);
      if (parenMatch != null) {
        final v = double.tryParse(parenMatch.group(1)!.replaceAll(',', '.'));
        final u = parenMatch.group(2)!.toLowerCase();
        if (v != null && v > 0) {
          if (u == 'cl') return v * 10.0;
          if (u == 'l') return v * 1000.0;
          return v;
        }
      }
      final plainMatch = RegExp(
        r'(\d+(?:[.,]\d+)?)\s*(g|ml|cl|l)\b',
        caseSensitive: false,
      ).firstMatch(servingSizeStr);
      if (plainMatch != null) {
        final v = double.tryParse(plainMatch.group(1)!.replaceAll(',', '.'));
        final u = plainMatch.group(2)!.toLowerCase();
        if (v != null && v > 0) {
          if (u == 'cl') return v * 10.0;
          if (u == 'l') return v * 1000.0;
          return v;
        }
      }
    }
    return 100.0;
  }

  static NutrientProfile _extractNutrientsPer100(Map<String, dynamic> prod) {
    final values = <NutrientKey, double>{};

    // 1. OFF API v3.6 structured `nutrition.aggregated_set.nutrients`
    final nutrition = prod['nutrition'];
    if (nutrition is Map<String, dynamic>) {
      final agg = nutrition['aggregated_set'];
      if (agg is Map<String, dynamic>) {
        final nutrientsMap = agg['nutrients'];
        if (nutrientsMap is Map<String, dynamic> && nutrientsMap.isNotEmpty) {
          _populateFromV36Aggregated(nutrientsMap, values);
        }
      }
    }

    // 2. OFF Search v1 / legacy `nutriments` (`<key>_100g` normalized to grams / kcal)
    final nutriments = prod['nutriments'];
    if (nutriments is Map<String, dynamic> && nutriments.isNotEmpty) {
      _populateFromLegacyNutriments(nutriments, values);
    }

    return values.isEmpty ? NutrientProfile.empty : NutrientProfile(values);
  }

  static void _populateFromV36Aggregated(
    Map<String, dynamic> aggNutrients,
    Map<NutrientKey, double> out,
  ) {
    for (final nutrientKey in NutrientKey.values) {
      if (out.containsKey(nutrientKey)) continue;
      if (nutrientKey == NutrientKey.caloriesKcal) {
        final kcalEntry = aggNutrients['energy-kcal'];
        final kcalVal = _v36PackagingValue(kcalEntry);
        if (kcalVal != null) {
          out[nutrientKey] = nutrientKey.convertFromOffUnit(
            kcalVal.$1,
            kcalVal.$2 ?? 'kcal',
          );
          continue;
        }
        final kjVal =
            _v36PackagingValue(aggNutrients['energy-kj']) ??
            _v36PackagingValue(aggNutrients['energy']);
        if (kjVal != null) {
          out[nutrientKey] = nutrientKey.convertFromOffUnit(
            kjVal.$1,
            kjVal.$2 ?? 'kJ',
          );
        }
        continue;
      }

      for (final offKey in nutrientKey.offKeys) {
        final entry = aggNutrients[offKey];
        final extracted = _v36PackagingValue(entry);
        if (extracted != null) {
          final converted = nutrientKey.convertFromOffUnit(
            extracted.$1,
            extracted.$2,
          );
          if (converted.isFinite && converted >= 0) {
            out[nutrientKey] = converted;
            break;
          }
        }
      }
    }
  }

  static (double, String?)? _v36PackagingValue(dynamic entry) {
    if (entry is! Map<String, dynamic>) return null;
    // Skip purely estimated ingredient-derived guesses so v3.6 matches packaging data
    if (entry['source'] == 'estimate') return null;
    final val = _asDouble(entry['value']);
    if (val == null || !val.isFinite || val < 0) return null;
    final unit = _nonEmptyStr(entry['unit']);
    return (val, unit);
  }

  static void _populateFromLegacyNutriments(
    Map<String, dynamic> nutriments,
    Map<NutrientKey, double> out,
  ) {
    for (final nutrientKey in NutrientKey.values) {
      if (out.containsKey(nutrientKey)) continue;
      if (nutrientKey == NutrientKey.caloriesKcal) {
        final kcal = _asDouble(nutriments['energy-kcal_100g']);
        if (kcal != null && kcal >= 0) {
          out[nutrientKey] = kcal;
          continue;
        }
        final kj = _asDouble(nutriments['energy-kj_100g']);
        if (kj != null && kj >= 0) {
          out[nutrientKey] = kj / 4.184;
          continue;
        }
        final energy = _asDouble(nutriments['energy_100g']);
        if (energy != null && energy >= 0) {
          final u = _nonEmptyStr(nutriments['energy_unit'])?.toLowerCase();
          out[nutrientKey] = u == 'kcal' ? energy : (energy / 4.184);
        }
        continue;
      }

      for (final offKey in nutrientKey.offKeys) {
        // In OFF `nutriments`, `<key>_100g` is canonically stored in grams ('g').
        final gramsPer100 = _asDouble(nutriments['${offKey}_100g']);
        if (gramsPer100 != null && gramsPer100.isFinite && gramsPer100 >= 0) {
          out[nutrientKey] = gramsPer100 * nutrientKey.gramsToUnitFactor;
          break;
        }
      }
    }
  }

  static String? _nonEmptyStr(dynamic v) {
    if (v is String) {
      final t = v.trim();
      return t.isEmpty ? null : t;
    }
    return null;
  }

  static double? _asDouble(dynamic v) {
    if (v is num) return v.toDouble();
    if (v is String) {
      return double.tryParse(v.trim().replaceAll(',', '.'));
    }
    return null;
  }

  static int? _asInt(dynamic v) {
    if (v is int) return v;
    if (v is num) return v.round();
    if (v is String) return int.tryParse(v.trim());
    return null;
  }

  void close() {
    _httpClient.close();
  }
}
