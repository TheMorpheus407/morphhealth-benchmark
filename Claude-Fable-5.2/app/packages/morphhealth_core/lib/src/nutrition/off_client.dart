import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'off_product.dart';

/// A request to the food service could not be answered.
class FoodApiException implements Exception {
  /// * `invalid_argument` – the request was not sent (bad query, barcode or
  ///   origin).
  /// * `network` – no connection (DNS, refused, reset).
  /// * `timeout` – no answer in time.
  /// * `tls` – the certificate was not accepted.
  /// * `rate_limited` – the service asked to slow down (HTTP 429).
  /// * `server_error` – the service failed (HTTP 5xx).
  /// * `bad_response` – the answer does not follow the contract.
  final String code;
  final String message;
  final int? statusCode;
  final int? retryAfterSeconds;

  const FoodApiException(
    this.code,
    this.message, {
    this.statusCode,
    this.retryAfterSeconds,
  });

  Map<String, dynamic> toJson() => {
    'code': code,
    'message': message,
    if (statusCode != null) 'http_status': statusCode,
    if (retryAfterSeconds != null) 'retry_after_seconds': retryAfterSeconds,
  };

  @override
  String toString() => 'FoodApiException($code): $message';
}

class TransportResponse {
  final int statusCode;

  /// Header names in lower case.
  final Map<String, String> headers;
  final List<int> body;

  const TransportResponse(this.statusCode, this.headers, this.body);
}

/// Performs a single HTTP GET. Redirects are not followed.
abstract class HttpTransport {
  Future<TransportResponse> get(
    Uri uri, {
    required Map<String, String> headers,
    required Duration timeout,
  });

  void close();
}

/// [HttpTransport] on `dart:io`. Certificates are verified against the trust
/// store of the platform; there is no way to switch verification off.
class IoHttpTransport implements HttpTransport {
  /// Larger answers are refused.
  static const int maxBodyBytes = 8 * 1024 * 1024;

  final HttpClient _client;

  IoHttpTransport()
    : _client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 8)
        ..idleTimeout = const Duration(seconds: 15)
        ..autoUncompress = true;

  @override
  Future<TransportResponse> get(
    Uri uri, {
    required Map<String, String> headers,
    required Duration timeout,
  }) async {
    Future<TransportResponse> run() async {
      final request = await _client.getUrl(uri);
      request.followRedirects = false;
      headers.forEach(request.headers.set);
      final response = await request.close();
      final body = BytesBuilder(copy: false);
      await for (final chunk in response) {
        body.add(chunk);
        if (body.length > maxBodyBytes) {
          throw const FoodApiException(
            'bad_response',
            'The answer of the food service is too large.',
          );
        }
      }
      final responseHeaders = <String, String>{};
      response.headers.forEach((name, values) {
        responseHeaders[name.toLowerCase()] = values.join(', ');
      });
      return TransportResponse(
        response.statusCode,
        responseHeaders,
        body.takeBytes(),
      );
    }

    try {
      return await run().timeout(timeout);
    } on TimeoutException {
      throw const FoodApiException(
        'timeout',
        'The food service did not answer in time.',
      );
    } on HandshakeException catch (e) {
      throw FoodApiException(
        'tls',
        'The secure connection to the food service failed: ${e.message}',
      );
    } on TlsException catch (e) {
      throw FoodApiException(
        'tls',
        'The secure connection to the food service failed: ${e.message}',
      );
    } on SocketException catch (e) {
      throw FoodApiException(
        'network',
        'The food service cannot be reached: ${e.message}',
      );
    } on HttpException catch (e) {
      throw FoodApiException(
        'network',
        'The connection to the food service broke: ${e.message}',
      );
    }
  }

  @override
  void close() => _client.close(force: true);
}

/// One page of search results.
class FoodSearchPage {
  final String query;
  final int page;
  final int pageSize;

  /// Number of matching products in total.
  final int totalCount;
  final List<CatalogProduct> products;

  const FoodSearchPage({
    required this.query,
    required this.page,
    required this.pageSize,
    required this.totalCount,
    required this.products,
  });

  /// Number of pages; computed as the service documents it.
  int get pageCount => totalCount <= 0 ? 0 : (totalCount - 1) ~/ pageSize + 1;

  bool get hasMore => page < pageCount;

  Map<String, dynamic> toJson() => {
    'query': query,
    'page': page,
    'page_size': pageSize,
    'total_count': totalCount,
    'page_count': pageCount,
    'has_more': hasMore,
    'products': [for (final p in products) p.toJson()],
  };
}

/// The answer to a barcode lookup.
class FoodLookup {
  /// The barcode as it was asked for (digits only).
  final String requestedBarcode;
  final bool found;
  final CatalogProduct? product;

  /// If not found: `product_not_found`, `invalid_code` or
  /// `other_product_type` (the code belongs to a non-food database).
  final String? reason;

  const FoodLookup({
    required this.requestedBarcode,
    required this.found,
    this.product,
    this.reason,
  });

  Map<String, dynamic> toJson() => {
    'requested_barcode': requestedBarcode,
    'found': found,
    'reason': reason,
    'product': product?.toJson(),
  };
}

/// Read-only client for the Open Food Facts contract of this release:
///
/// ```text
/// GET {origin}/api/v3.6/product/{barcode}.json
/// GET {origin}/cgi/search.pl?search_terms={q}&search_simple=1&action=process&json=1&page={p}&page_size=20
/// ```
///
/// The origin and the User-Agent are configuration; nothing in this class
/// names a particular server. Requests carry a `fields` projection, as the
/// contract allows, so that answers stay small.
class FoodApiClient {
  static const int pageSize = 20;

  /// Origin of a regular product installation.
  static const String productionOrigin = 'https://world.openfoodfacts.org';

  /// Fields requested from both endpoints. `nutrition` is the structure of
  /// product schema 1003 and later, `nutriments` the older one.
  static const List<String> fields = [
    'code',
    'product_name',
    'product_name_de',
    'product_name_en',
    'generic_name',
    'generic_name_de',
    'generic_name_en',
    'brands',
    'brands_tags',
    'quantity',
    'product_quantity',
    'product_quantity_unit',
    'serving_size',
    'serving_quantity',
    'serving_quantity_unit',
    'nutrition_data_per',
    'nutrition',
    'nutriments',
    'schema_version',
  ];

  final Uri origin;
  final String userAgent;
  final HttpTransport transport;

  /// Time allowed for one attempt.
  final Duration timeout;

  /// Attempts per request, including the first one.
  final int maxAttempts;

  /// Longest wait the client accepts when the service names one.
  final Duration maxRetryAfter;

  /// After this time no further attempt is started.
  final Duration maxTotalTime;

  /// Preferred languages for product names.
  final List<String> languages;

  final Future<void> Function(Duration) _sleep;
  final math.Random _random = math.Random();

  FoodApiClient({
    required this.origin,
    required this.userAgent,
    required this.transport,
    this.timeout = const Duration(seconds: 10),
    this.maxAttempts = 3,
    this.maxRetryAfter = const Duration(seconds: 5),
    this.maxTotalTime = const Duration(seconds: 15),
    this.languages = const ['de', 'en'],
    Future<void> Function(Duration)? sleep,
  }) : _sleep = sleep ?? Future<void>.delayed;

  /// Validates an origin such as `https://world.openfoodfacts.org`.
  ///
  /// Only HTTPS is accepted, and only scheme, host and port: no path, query
  /// or credentials. Throws [FoodApiException] `invalid_argument` otherwise.
  static Uri parseOrigin(String value) {
    final text = value.trim();
    final uri = Uri.tryParse(text);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw FoodApiException(
        'invalid_argument',
        'The food service origin "$value" is not a URL.',
      );
    }
    if (uri.scheme.toLowerCase() != 'https') {
      throw const FoodApiException(
        'invalid_argument',
        'The food service origin must use https.',
      );
    }
    if (uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment ||
        (uri.path.isNotEmpty && uri.path != '/')) {
      throw const FoodApiException(
        'invalid_argument',
        'The food service origin must consist of scheme, host and optional '
            'port only, for example https://world.openfoodfacts.org',
      );
    }
    return Uri(
      scheme: 'https',
      host: uri.host.toLowerCase(),
      port: uri.hasPort ? uri.port : null,
    );
  }

  String get _base {
    final s = origin.toString();
    return s.endsWith('/') ? s.substring(0, s.length - 1) : s;
  }

  /// Searches products by name. [page] starts at 1.
  Future<FoodSearchPage> search(String query, {int page = 1}) async {
    final q = query.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (q.length < 2) {
      throw const FoodApiException(
        'invalid_argument',
        'The search term needs at least two characters.',
      );
    }
    if (q.length > 200) {
      throw const FoodApiException(
        'invalid_argument',
        'The search term is too long.',
      );
    }
    if (page < 1 || page > 100000) {
      throw const FoodApiException(
        'invalid_argument',
        'The page must be 1 or greater.',
      );
    }
    final uri = Uri.parse(
      '$_base/cgi/search.pl'
      '?search_terms=${Uri.encodeQueryComponent(q)}'
      '&search_simple=1&action=process&json=1'
      '&page=$page&page_size=$pageSize'
      '&fields=${fields.join(',')}',
    );
    final response = await _request(uri);
    if (response.statusCode != 200) {
      throw FoodApiException(
        'bad_response',
        'The food service answered with status ${response.statusCode}.',
        statusCode: response.statusCode,
      );
    }
    final json = _decodeObject(response);
    final list = json['products'];
    if (list is! List) {
      throw const FoodApiException(
        'bad_response',
        'The answer of the food service contains no product list.',
      );
    }
    final products = <CatalogProduct>[];
    for (final raw in list) {
      if (raw is! Map) continue;
      final p = parseOffProduct(
        raw.cast<String, dynamic>(),
        languages: languages,
      );
      if (p != null) products.add(p);
    }
    final size = _integer(json['page_size']) ?? pageSize;
    return FoodSearchPage(
      query: q,
      page: _integer(json['page']) ?? page,
      pageSize: size < 1 ? pageSize : size,
      totalCount: math.max(_integer(json['count']) ?? products.length, 0),
      products: products,
    );
  }

  /// Fetches the product with [barcode] (7 to 14 digits; spaces and hyphens
  /// are ignored).
  Future<FoodLookup> lookup(String barcode) async {
    final digits = barcode.replaceAll(RegExp(r'[\s\-]'), '');
    if (!RegExp(r'^[0-9]{7,14}$').hasMatch(digits)) {
      throw const FoodApiException(
        'invalid_argument',
        'A barcode consists of 7 to 14 digits.',
      );
    }
    final uri = Uri.parse(
      '$_base/api/v3.6/product/$digits.json?fields=${fields.join(',')}',
    );
    final response = await _request(uri, allowForeignRedirect: true);

    if (response.statusCode >= 300 && response.statusCode < 400) {
      // The contract redirects codes of other product types (cosmetics, pet
      // food, …) to a different server. That server is not asked.
      return FoodLookup(
        requestedBarcode: digits,
        found: false,
        reason: 'other_product_type',
      );
    }
    if (response.statusCode != 200 && response.statusCode != 404) {
      throw FoodApiException(
        'bad_response',
        'The food service answered with status ${response.statusCode}.',
        statusCode: response.statusCode,
      );
    }
    final Map<String, dynamic> json;
    try {
      json = _decodeObject(response);
    } on FoodApiException {
      if (response.statusCode == 404) {
        throw const FoodApiException(
          'bad_response',
          'The product endpoint does not exist at this origin (HTTP 404 '
              'without a product answer).',
          statusCode: 404,
        );
      }
      rethrow;
    }
    final product = json['product'];
    final status = json['status'];
    final resultId = json['result'] is Map
        ? (json['result'] as Map)['id']
        : null;
    final failed =
        status == 'failure' ||
        status == 0 ||
        resultId == 'product_not_found' ||
        response.statusCode == 404;
    if (failed || product is! Map) {
      var reason = 'product_not_found';
      final errors = json['errors'];
      if (errors is List) {
        for (final e in errors) {
          if (e is Map && e['message'] is Map) {
            if ((e['message'] as Map)['id'] == 'invalid_code') {
              reason = 'invalid_code';
            }
          }
        }
      }
      if (!failed && product is! Map) {
        throw const FoodApiException(
          'bad_response',
          'The answer of the food service contains no product.',
        );
      }
      return FoodLookup(requestedBarcode: digits, found: false, reason: reason);
    }
    final parsed = parseOffProduct(
      product.cast<String, dynamic>(),
      languages: languages,
      fallbackBarcode:
          json['code'] is String && (json['code'] as String).isNotEmpty
          ? json['code'] as String
          : digits,
    );
    if (parsed == null) {
      throw const FoodApiException(
        'bad_response',
        'The product in the answer of the food service has no barcode.',
      );
    }
    return FoodLookup(requestedBarcode: digits, found: true, product: parsed);
  }

  /// Sends a GET with retries for temporary failures.
  Future<TransportResponse> _request(
    Uri uri, {
    bool allowForeignRedirect = false,
  }) async {
    final headers = {'user-agent': userAgent, 'accept': 'application/json'};
    var current = uri;
    var redirects = 0;
    FoodApiException? last;
    final started = DateTime.now();
    for (var attempt = 1; attempt <= maxAttempts; attempt++) {
      if (last != null && DateTime.now().difference(started) > maxTotalTime) {
        break;
      }
      Duration? wait;
      try {
        final response = await transport.get(
          current,
          headers: headers,
          timeout: timeout,
        );
        final status = response.statusCode;
        if (status >= 300 && status < 400) {
          final location = response.headers['location'];
          final target = location == null ? null : current.resolve(location);
          if (target != null &&
              target.scheme == 'https' &&
              target.host == origin.host &&
              target.port == origin.port &&
              redirects < 3) {
            redirects++;
            current = target;
            attempt--;
            continue;
          }
          if (allowForeignRedirect) return response;
          throw FoodApiException(
            'bad_response',
            'The food service redirects to another address, which is not '
                'followed.',
            statusCode: status,
          );
        }
        if (status == 429 || status >= 500) {
          final retryAfter = int.tryParse(
            (response.headers['retry-after'] ?? '').trim(),
          );
          last = FoodApiException(
            status == 429 ? 'rate_limited' : 'server_error',
            status == 429
                ? 'The food service asks for fewer requests. Try again '
                      'in a moment.'
                : 'The food service is temporarily unavailable '
                      '(status $status).',
            statusCode: status,
            retryAfterSeconds: retryAfter,
          );
          if (retryAfter != null && retryAfter >= 0) {
            if (Duration(seconds: retryAfter) > maxRetryAfter) throw last;
            wait = Duration(seconds: retryAfter);
          }
        } else {
          return response;
        }
      } on FoodApiException catch (e) {
        if (e.code != 'network' && e.code != 'timeout') rethrow;
        last = e;
      }
      if (attempt < maxAttempts) {
        // Exponential backoff with jitter, as the service documentation asks.
        final base = 400 * (1 << (attempt - 1));
        await _sleep(
          wait ?? Duration(milliseconds: base + _random.nextInt(base ~/ 2 + 1)),
        );
      }
    }
    throw last ??
        const FoodApiException(
          'network',
          'The food service cannot be reached.',
        );
  }

  static Map<String, dynamic> _decodeObject(TransportResponse response) {
    try {
      final decoded = jsonDecode(utf8.decode(response.body));
      if (decoded is Map<String, dynamic>) return decoded;
    } on FormatException {
      // handled below
    }
    throw FoodApiException(
      'bad_response',
      'The answer of the food service is not valid JSON.',
      statusCode: response.statusCode,
    );
  }

  static int? _integer(Object? v) {
    if (v is int) return v;
    if (v is double && v == v.roundToDouble()) return v.toInt();
    if (v is String) return int.tryParse(v.trim());
    return null;
  }

  void close() => transport.close();
}
