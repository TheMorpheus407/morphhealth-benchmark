import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'models.dart';

class OffException implements Exception {
  final String code;
  final String message;
  final int? statusCode;

  const OffException(this.code, this.message, {this.statusCode});

  @override
  String toString() => 'OffException($code): $message';
}

class FoodSearchResult {
  final String query;
  final int page;
  final int pageSize;
  final int totalCount;
  final List<FoodItem> products;

  const FoodSearchResult({
    required this.query,
    required this.page,
    required this.pageSize,
    required this.totalCount,
    required this.products,
  });

  Map<String, dynamic> toJson() => {
        'query': query,
        'q': query,
        'page': page,
        'page_size': pageSize,
        'count': totalCount,
        'total_count': totalCount,
        'products': products.map((p) => p.toJson()).toList(),
        'items': products.map((p) => p.toJson()).toList(),
      };
}

class OpenFoodFactsClient {
  final String baseUrl;
  final String userAgent;
  final http.Client _httpClient;
  final String Function()? _nowIsoProvider;

  OpenFoodFactsClient({
    required String baseUrl,
    required this.userAgent,
    http.Client? httpClient,
    String Function()? nowIsoProvider,
  })  : baseUrl = _normalizeBaseUrl(baseUrl),
        _httpClient = httpClient ?? http.Client(),
        _nowIsoProvider = nowIsoProvider;

  static String _normalizeBaseUrl(String raw) {
    var trimmed = raw.trim();
    while (trimmed.endsWith('/')) {
      trimmed = trimmed.substring(0, trimmed.length - 1);
    }
    return trimmed.isEmpty ? 'https://world.openfoodfacts.org' : trimmed;
  }

  /// Loads `food_api_base_url` and `food_api_user_agent` from ENVIRONMENT.json
  /// if available on disk, falling back to provided defaults.
  static ({String baseUrl, String userAgent}) loadDefaultConfig({
    String? candidateEnvPath,
  }) {
    final paths = <String>[
      ?candidateEnvPath,
      'ENVIRONMENT.json',
      '../ENVIRONMENT.json',
    ];
    for (final p in paths) {
      try {
        final f = File(p);
        if (f.existsSync()) {
          final parsed = jsonDecode(f.readAsStringSync());
          if (parsed is Map) {
            final url = parsed['food_api_base_url']?.toString().trim();
            final ua = parsed['food_api_user_agent']?.toString().trim();
            if (url != null && url.isNotEmpty) {
              return (
                baseUrl: url,
                userAgent: (ua != null && ua.isNotEmpty)
                    ? ua
                    : 'MorphHealth/1.0-rc3',
              );
            }
          }
        }
      } catch (_) {}
    }
    return (
      baseUrl: 'https://localhost:8788',
      userAgent: 'MorphHealth/1.0-rc3 (benchmark build)',
    );
  }

  Map<String, String> get _headers => {
        'User-Agent': userAgent,
        'Accept': 'application/json',
      };

  Future<FoodSearchResult> search({
    required String query,
    int page = 1,
    int pageSize = 20,
  }) async {
    final cleanQuery = query.trim();
    if (cleanQuery.isEmpty) {
      throw const OffException(
        'invalid_query',
        'Search query (q) must not be empty.',
      );
    }
    final safePage = page < 1 ? 1 : page;
    final safePageSize = pageSize.clamp(1, 50);

    final uri = Uri.parse('$baseUrl/cgi/search.pl').replace(
      queryParameters: {
        'search_terms': cleanQuery,
        'search_simple': '1',
        'action': 'process',
        'json': '1',
        'page': safePage.toString(),
        'page_size': safePageSize.toString(),
      },
    );

    http.Response response;
    try {
      response = await _httpClient
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      throw OffException(
        'network_error',
        'Failed to reach Open Food Facts endpoint ($baseUrl): $e',
      );
    }

    if (response.statusCode != 200) {
      throw OffException(
        'http_error',
        'Open Food Facts search returned HTTP ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }

    final dynamic decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } catch (e) {
      throw OffException(
        'parse_error',
        'Invalid JSON response from Open Food Facts search: $e',
      );
    }

    if (decoded is! Map) {
      throw const OffException(
        'parse_error',
        'Expected JSON object from Open Food Facts search',
      );
    }

    final rawProducts = decoded['products'];
    final nowIso =
        _nowIsoProvider?.call() ?? DateTime.now().toUtc().toIso8601String();
    final items = <FoodItem>[];
    if (rawProducts is List) {
      for (final raw in rawProducts) {
        if (raw is Map) {
          items.add(
            FoodItem.fromOpenFoodFactsProduct(
              Map<String, dynamic>.from(raw),
              nowIso: nowIso,
            ),
          );
        }
      }
    }

    final totalCount = (decoded['count'] is num)
        ? (decoded['count'] as num).toInt()
        : (int.tryParse(decoded['count']?.toString() ?? '') ?? items.length);

    return FoodSearchResult(
      query: cleanQuery,
      page: safePage,
      pageSize: safePageSize,
      totalCount: totalCount,
      products: items,
    );
  }

  Future<FoodItem> lookupBarcode(String barcode) async {
    final cleanCode = barcode.trim();
    if (cleanCode.isEmpty) {
      throw const OffException(
        'invalid_barcode',
        'Barcode must not be empty.',
      );
    }

    final uri = Uri.parse(
      '$baseUrl/api/v3.6/product/${Uri.encodeComponent(cleanCode)}.json',
    );

    http.Response response;
    try {
      response = await _httpClient
          .get(uri, headers: _headers)
          .timeout(const Duration(seconds: 15));
    } catch (e) {
      throw OffException(
        'network_error',
        'Failed to reach Open Food Facts endpoint ($baseUrl): $e',
      );
    }

    if (response.statusCode == 404) {
      throw OffException(
        'product_not_found',
        'No product found for barcode $cleanCode',
        statusCode: 404,
      );
    }

    if (response.statusCode != 200) {
      throw OffException(
        'http_error',
        'Open Food Facts product lookup returned HTTP ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }

    final dynamic decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } catch (e) {
      throw OffException(
        'parse_error',
        'Invalid JSON response from Open Food Facts lookup: $e',
      );
    }

    if (decoded is! Map) {
      throw const OffException(
        'parse_error',
        'Expected JSON object from Open Food Facts lookup',
      );
    }

    final status = decoded['status'];
    final productMap = decoded['product'];
    if (status == 'failure' || status == 0 || productMap is! Map) {
      throw OffException(
        'product_not_found',
        'No product found for barcode $cleanCode',
        statusCode: 404,
      );
    }

    final nowIso =
        _nowIsoProvider?.call() ?? DateTime.now().toUtc().toIso8601String();
    final mapCopy = Map<String, dynamic>.from(productMap);
    if ((mapCopy['code'] ?? '').toString().trim().isEmpty) {
      mapCopy['code'] = cleanCode;
    }

    return FoodItem.fromOpenFoodFactsProduct(
      mapCopy,
      nowIso: nowIso,
    );
  }

  void close() {
    _httpClient.close();
  }
}
