import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import 'nutrition.dart';
import 'utils.dart';

class FoodApiException implements Exception {
  const FoodApiException(this.code, this.message);
  final String code;
  final String message;

  @override
  String toString() => '$code: $message';
}

class FoodSearchResult {
  const FoodSearchResult({
    required this.query,
    required this.page,
    required this.total,
    required this.foods,
  });

  final String query;
  final int page;
  final int total;
  final List<Food> foods;

  Map<String, dynamic> toJson() => {
    'query': query,
    'page': page,
    'page_size': 20,
    'total_results': total,
    'returned': foods.length,
    'products': foods.map((food) => food.toJson()).toList(),
  };
}

class FoodLookupResult {
  const FoodLookupResult(this.barcode, this.food);
  final String barcode;
  final Food? food;

  Map<String, dynamic> toJson() => {
    'barcode': barcode,
    'found': food != null,
    'food': food?.toJson(),
  };
}

class FoodApi {
  FoodApi(
    String baseUrl,
    this.userAgent, {
    http.Client? client,
    DateTime Function()? clock,
    this.requestTimeout = const Duration(seconds: 20),
  }) : base = _validateBase(baseUrl),
       _client = client ?? http.Client(),
       _clock = clock ?? DateTime.now;

  final Uri base;
  final String userAgent;
  final http.Client _client;
  final DateTime Function() _clock;
  final Duration requestTimeout;

  static Uri _validateBase(String value) {
    final uri = Uri.tryParse(value);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/')) {
      throw ArgumentError('food base URL must be an HTTPS origin');
    }
    return uri;
  }

  static const _fields = [
    'code',
    'product_name',
    'product_name_de',
    'product_name_en',
    'brands',
    'quantity',
    'serving_size',
    'serving_quantity',
    'nutriments',
  ];

  Future<FoodSearchResult> search(String query, int page) async {
    if (query.trim().isEmpty) throw ArgumentError('q must not be empty');
    if (page < 1) throw ArgumentError('page must be at least 1');
    final uri = base.replace(
      path: '/cgi/search.pl',
      queryParameters: {
        'search_terms': query.trim(),
        'search_simple': '1',
        'action': 'process',
        'json': '1',
        'page': '$page',
        'page_size': '20',
        'fields': _fields.join(','),
      },
    );
    final json = await _getJson(uri);
    final products = jsonList(
      json['products'] ?? const [],
      'response.products',
    );
    final foods = <Food>[];
    for (var index = 0; index < products.length; index++) {
      try {
        foods.add(_foodFromProduct(products[index]));
      } on FormatException {
        continue;
      }
    }
    final count = json['count'];
    return FoodSearchResult(
      query: query,
      page: page,
      total: count is num ? count.toInt() : foods.length,
      foods: foods,
    );
  }

  Future<FoodLookupResult> lookup(String barcode) async {
    final normalized = barcode.trim();
    if (!RegExp(r'^\d{8,14}$').hasMatch(normalized)) {
      throw ArgumentError('barcode must contain 8 to 14 digits');
    }
    final uri = base.replace(path: '/api/v3.6/product/$normalized.json');
    final response = await _get(uri, allowNotFound: true);
    if (response.statusCode == 404) return FoodLookupResult(normalized, null);
    final json = _decode(response);
    final status = json['status'];
    if (status == 0 || json['product'] == null || json['product'] is! Map) {
      return FoodLookupResult(normalized, null);
    }
    try {
      return FoodLookupResult(
        normalized,
        _foodFromProduct(json['product'], fallbackBarcode: normalized),
      );
    } on FormatException {
      return FoodLookupResult(normalized, null);
    }
  }

  Future<Map<String, dynamic>> _getJson(Uri uri) async =>
      _decode(await _get(uri));

  Future<http.Response> _get(Uri uri, {bool allowNotFound = false}) async {
    try {
      final response = await _client
          .get(
            uri,
            headers: {'User-Agent': userAgent, 'Accept': 'application/json'},
          )
          .timeout(requestTimeout);
      if (response.statusCode == 404 && allowNotFound) return response;
      if (response.statusCode != 200) {
        throw FoodApiException(
          'http_${response.statusCode}',
          'Open Food Facts returned an error',
        );
      }
      return response;
    } on FoodApiException {
      rethrow;
    } on TimeoutException {
      throw const FoodApiException(
        'timeout',
        'Open Food Facts request timed out',
      );
    } on Exception catch (error) {
      throw FoodApiException('network', error.toString());
    }
  }

  Map<String, dynamic> _decode(http.Response response) {
    try {
      return jsonMap(jsonDecode(utf8.decode(response.bodyBytes)), 'response');
    } on Exception {
      throw const FoodApiException(
        'invalid_response',
        'Open Food Facts returned invalid JSON',
      );
    }
  }

  Food _foodFromProduct(Object? value, {String? fallbackBarcode}) {
    final product = jsonMap(value, 'product');
    final code = (product['code'] ?? fallbackBarcode ?? '').toString().trim();
    final name =
        [
              product['product_name_de'],
              product['product_name'],
              product['product_name_en'],
            ]
            .whereType<String>()
            .map((item) => item.trim())
            .firstWhere(
              (item) => item.isNotEmpty,
              orElse: () =>
                  code.isEmpty ? 'Open Food Facts' : 'Open Food Facts $code',
            );
    final nutriments = product['nutriments'] is Map
        ? jsonMap(product['nutriments'], 'product.nutriments')
        : <String, dynamic>{};
    final nutrients = <String, double>{};
    for (final nutrient in Nutrient.values) {
      for (final key in nutrient.offKeys) {
        final raw = nutriments['${key}_100g'];
        if (raw is! num || !raw.isFinite || raw < 0) continue;
        final unit = nutriments['${key}_unit']?.toString().toLowerCase();
        nutrients[nutrient.id] = _convert(raw.toDouble(), unit, nutrient);
        break;
      }
    }
    final portion = _portionSize(product);
    final timestamp = _clock().toUtc();
    return Food(
      id: code.isEmpty ? newId() : 'off:$code',
      name: name,
      brand: product['brands']?.toString().trim() ?? '',
      source: 'openfoodfacts',
      measure: 'g',
      portionSize: portion,
      nutrients: nutrients,
      favorite: false,
      barcode: code.isEmpty ? fallbackBarcode : code,
      createdAt: timestamp,
      updatedAt: timestamp,
    );
  }

  static double? _portionSize(Map<String, dynamic> product) {
    final serving = product['serving_size']?.toString() ?? '';
    final match = RegExp(
      r'(\d+(?:[.,]\d+)?)\s*(g|ml)\b',
      caseSensitive: false,
    ).firstMatch(serving);
    if (match != null) {
      final value = double.tryParse(match.group(1)!.replaceAll(',', '.'));
      if (value != null && value > 0) return value;
    }
    final quantity = product['serving_quantity'];
    if (quantity is num && quantity.isFinite && quantity > 0)
      return quantity.toDouble();
    return null;
  }

  static double _convert(double value, String? sourceUnit, Nutrient nutrient) {
    if (nutrient == Nutrient.calories) {
      return sourceUnit == 'kj' ? value / 4.184 : value;
    }
    final unit = switch (sourceUnit) {
      'ug' || 'µg' || 'mcg' => 'µg',
      null || '' => 'g',
      _ => sourceUnit,
    };
    final inGrams = switch (unit) {
      'kg' => value * 1000,
      'g' => value,
      'mg' => value / 1000,
      'µg' => value / 1000000,
      _ => value,
    };
    return switch (nutrient.unit) {
      'g' => inGrams,
      'mg' => inGrams * 1000,
      'µg' => inGrams * 1000000,
      _ => value,
    };
  }

  void close() => _client.close();
}
