import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import 'off_parser.dart';

/// Default origin for a normal product installation.
const String defaultFoodApiBaseUrl = 'https://world.openfoodfacts.org';

/// Default User-Agent (Open Food Facts asks apps to identify themselves).
const String defaultFoodApiUserAgent =
    'MorphHealth/1.0 (de.themorpheus.morphhealth.local)';

/// Connection settings for the read-only Open Food Facts contract.
class FoodApiConfig {
  FoodApiConfig._(this.baseUri, this.userAgent);

  /// Validates [baseUrl] (an HTTPS origin, optionally with a path prefix).
  factory FoodApiConfig(String baseUrl, String userAgent) {
    final uri = parseBaseUrl(baseUrl);
    if (uri == null) {
      throw ArgumentError.value(baseUrl, 'baseUrl', 'expected an HTTPS origin');
    }
    final agent = userAgent.trim().isEmpty ? defaultFoodApiUserAgent : userAgent.trim();
    return FoodApiConfig._(uri, agent);
  }

  final Uri baseUri;
  final String userAgent;

  String get baseUrl {
    final s = baseUri.toString();
    return s.endsWith('/') ? s.substring(0, s.length - 1) : s;
  }

  /// Parses and validates a base URL; returns null if unusable.
  static Uri? parseBaseUrl(String text) {
    final uri = Uri.tryParse(text.trim());
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        uri.userInfo.isNotEmpty) {
      return null;
    }
    return uri;
  }

  Uri _endpoint(String path, Map<String, String> query) {
    var basePath = baseUri.path;
    if (basePath.endsWith('/')) basePath = basePath.substring(0, basePath.length - 1);
    return baseUri.replace(path: '$basePath$path', queryParameters: query);
  }

  /// `GET {base}/api/v3.6/product/{barcode}.json`
  Uri productUri(String barcode) => _endpoint(
    '/api/v3.6/product/$barcode.json',
    {'fields': OffClient.productFields},
  );

  /// `GET {base}/cgi/search.pl?search_terms=…&search_simple=1&action=process
  /// &json=1&page=…&page_size=20`
  Uri searchUri(String query, int page) => _endpoint('/cgi/search.pl', {
    'search_terms': query,
    'search_simple': '1',
    'action': 'process',
    'json': '1',
    'page': '$page',
    'page_size': '${OffClient.pageSize}',
    'fields': OffClient.searchFields,
  });
}

enum FoodApiErrorKind {
  /// No connection, DNS failure, connection refused.
  network,
  timeout,

  /// TLS handshake or certificate problem.
  tls,
  rateLimited,

  /// Unexpected HTTP status.
  http,

  /// Response was not the expected JSON.
  invalidResponse,
}

class FoodApiException implements Exception {
  FoodApiException(this.kind, this.message, {this.statusCode});

  final FoodApiErrorKind kind;
  final String message;
  final int? statusCode;

  String get code => switch (kind) {
    FoodApiErrorKind.network => 'network_error',
    FoodApiErrorKind.timeout => 'network_timeout',
    FoodApiErrorKind.tls => 'tls_error',
    FoodApiErrorKind.rateLimited => 'rate_limited',
    FoodApiErrorKind.http => 'upstream_http_error',
    FoodApiErrorKind.invalidResponse => 'upstream_invalid_response',
  };

  @override
  String toString() => 'FoodApiException($code): $message';
}

class OffSearchPage {
  OffSearchPage({
    required this.query,
    required this.page,
    required this.pageSize,
    required this.count,
    required this.items,
    required this.skipped,
  });

  final String query;
  final int page;
  final int pageSize;

  /// Total number of matching products reported by the server.
  final int count;
  final List<OnlineFood> items;

  /// Products that were returned but could not be used (e.g. no barcode).
  final int skipped;

  int get pageCount => count == 0 ? 0 : (count + pageSize - 1) ~/ pageSize;
  bool get hasMore => page < pageCount;

  Map<String, Object?> toJson() => {
    'query': query,
    'page': page,
    'page_size': pageSize,
    'count': count,
    'page_count': pageCount,
    'has_more': hasMore,
    'skipped': skipped,
    'products': [for (final i in items) i.toJson()],
  };
}

class OffLookupResult {
  OffLookupResult(this.barcode, this.food);

  final String barcode;
  final OnlineFood? food;

  bool get found => food != null;
}

/// Minimal client for the two read-only endpoints of the contract.
class OffClient {
  OffClient(this.config, {http.Client? httpClient, Duration? timeout})
    : _http = httpClient ?? http.Client(),
      _timeout = timeout ?? const Duration(seconds: 20);

  static const int pageSize = 20;

  static const String _commonFields =
      'code,product_name,product_name_de,product_name_en,generic_name,'
      'generic_name_de,generic_name_en,abbreviated_product_name,brands,'
      'quantity,product_quantity,product_quantity_unit,serving_size,'
      'serving_quantity,serving_quantity_unit,nutrition_data_per';

  /// Field projection for product lookups (new nutrition schema).
  static const String productFields = '$_commonFields,nutrition,nutriments';

  /// Field projection for searches (legacy nutriments on this endpoint).
  static const String searchFields = '$_commonFields,nutriments,nutrition';

  final FoodApiConfig config;
  final http.Client _http;
  final Duration _timeout;

  Future<OffSearchPage> search(
    String query,
    int page, {
    required String language,
  }) async {
    final response = await _get(config.searchUri(query, page));
    if (response.statusCode != 200) throw _statusError(response.statusCode);
    final json = _decode(response);
    final products = json['products'];
    if (products is! List) {
      throw FoodApiException(
        FoodApiErrorKind.invalidResponse,
        'Search response has no product list',
      );
    }
    final items = <OnlineFood>[];
    var skipped = 0;
    for (final p in products) {
      final parsed = p is Map<String, Object?>
          ? OffParser.parse(p, language: language)
          : null;
      if (parsed == null) {
        skipped++;
      } else {
        items.add(parsed);
      }
    }
    return OffSearchPage(
      query: query,
      page: _int(json['page']) ?? page,
      pageSize: _int(json['page_size']) ?? pageSize,
      count: _int(json['count']) ?? items.length,
      items: items,
      skipped: skipped,
    );
  }

  Future<OffLookupResult> lookup(
    String barcode, {
    required String language,
  }) async {
    final response = await _get(config.productUri(barcode));
    if (response.statusCode == 404) {
      return OffLookupResult(barcode, null);
    }
    if (response.statusCode != 200) throw _statusError(response.statusCode);
    final json = _decode(response);
    final status = json['status'];
    final product = json['product'];
    if (status == 'failure' || product is! Map<String, Object?>) {
      return OffLookupResult(barcode, null);
    }
    return OffLookupResult(barcode, OffParser.parse(product, language: language));
  }

  void close() => _http.close();

  Future<http.Response> _get(Uri uri) async {
    try {
      return await _http
          .get(
            uri,
            headers: {
              'User-Agent': config.userAgent,
              'Accept': 'application/json',
            },
          )
          .timeout(_timeout);
    } on TimeoutException {
      throw FoodApiException(FoodApiErrorKind.timeout, 'The request timed out');
    } on HandshakeException catch (e) {
      throw FoodApiException(FoodApiErrorKind.tls, 'TLS error: ${e.message}');
    } on TlsException catch (e) {
      throw FoodApiException(FoodApiErrorKind.tls, 'TLS error: ${e.message}');
    } on SocketException catch (e) {
      throw FoodApiException(FoodApiErrorKind.network, 'No connection: ${e.message}');
    } on http.ClientException catch (e) {
      throw FoodApiException(FoodApiErrorKind.network, 'Request failed: ${e.message}');
    } on HttpException catch (e) {
      throw FoodApiException(FoodApiErrorKind.network, 'Request failed: ${e.message}');
    }
  }

  FoodApiException _statusError(int status) {
    if (status == 429) {
      return FoodApiException(
        FoodApiErrorKind.rateLimited,
        'Too many requests, please try again later',
        statusCode: status,
      );
    }
    return FoodApiException(
      FoodApiErrorKind.http,
      'Server answered with HTTP $status',
      statusCode: status,
    );
  }

  Map<String, Object?> _decode(http.Response response) {
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, Object?>) return decoded;
    } catch (_) {
      // Fall through.
    }
    throw FoodApiException(
      FoodApiErrorKind.invalidResponse,
      'The server did not return valid JSON',
    );
  }

  static int? _int(Object? v) {
    if (v is int) return v;
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v);
    return null;
  }
}
