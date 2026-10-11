// Read-only-Client für den Open-Food-Facts-Datenvertrag (SPEC P08).
//
// Einstiegspunkte (lesend):
//   GET {base}/api/v3.6/product/{barcode}.json
//   GET {base}/cgi/search.pl?search_terms={q}&search_simple=1&action=process&json=1&page={p}&page_size=20
//
// Origin und User-Agent kommen aus der Konfiguration (ENVIRONMENT.json /
// --dart-define bzw. CLI-Flags) — die Fachlogik ist origin-unabhängig.
// TLS wird nicht umgangen; der System-Trust-Store wird verwendet.
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/exceptions.dart';
import 'off_mapping.dart';

class OffConfig {
  final String baseUrl;
  final String userAgent;
  const OffConfig({required this.baseUrl, required this.userAgent});

  /// Basis-URL ohne führenden Slash am Ende.
  String get normalizedBaseUrl => baseUrl.endsWith('/') ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;
}

class OffSearchResult {
  final int count;
  final int page;
  final int pageCount;
  final List<OffProduct> products;
  const OffSearchResult({
    required this.count,
    required this.page,
    required this.pageCount,
    required this.products,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'count': count,
        'page': page,
        'page_count': pageCount,
        'products': <dynamic>[for (final OffProduct p in products) p.toJson()],
      };
}

class OffClient {
  final OffConfig config;
  final http.Client _http;
  final Duration timeout;

  OffClient(this.config, {http.Client? httpClient, this.timeout = const Duration(seconds: 20)})
      : _http = httpClient ?? http.Client();

  /// Normalisiert eine Barcode-Eingabe (nur Ziffern, 6–14 Stellen).
  static String? normalizeBarcode(String input) {
    final String digits = input.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length < 6 || digits.length > 14) return null;
    return digits;
  }

  /// Produktsuche über search.pl.
  Future<OffSearchResult> search(String query, {int page = 1, int pageSize = 20}) async {
    final String q = query.trim();
    if (q.isEmpty) {
      throw MorphException('off.empty_query', 'Suchbegriff darf nicht leer sein.');
    }
    final Uri uri = Uri.parse(
      '${config.normalizedBaseUrl}/cgi/search.pl?search_terms=${Uri.encodeQueryComponent(q)}'
      '&search_simple=1&action=process&json=1&page=$page&page_size=$pageSize'
      '&fields=code,product_name,product_name_de,generic_name,brands,quantity,'
      'serving_size,serving_quantity,serving_quantity_unit,'
      'image_front_small_url,nutriments',
    );
    final Map<String, dynamic> json = await _getJson(uri);
    final List<OffProduct> out = <OffProduct>[];
    final dynamic rawProducts = json['products'];
    if (rawProducts is List) {
      for (final dynamic p in rawProducts) {
        if (p is Map<String, dynamic>) {
          final OffProduct? product = OffProduct.fromProductJson(p);
          if (product != null) out.add(product);
        } else if (p is Map) {
          final OffProduct? product = OffProduct.fromProductJson(p.cast<String, dynamic>());
          if (product != null) out.add(product);
        }
      }
    }
    return OffSearchResult(
      count: (json['count'] is num) ? (json['count'] as num).toInt() : out.length,
      page: (json['page'] is num) ? (json['page'] as num).toInt() : page,
      pageCount: (json['page_count'] is num) ? (json['page_count'] as num).toInt() : 1,
      products: out,
    );
  }

  /// Produktabruf über die v3.6-API. Liefert null, wenn das Produkt nicht
  /// existiert (HTTP 404 / status "failure").
  Future<OffProduct?> lookup(String barcode) async {
    final String? code = normalizeBarcode(barcode);
    if (code == null) {
      throw MorphException('off.invalid_barcode', 'Ungültige Barcode-Nummer: $barcode');
    }
    final Uri uri = Uri.parse(
      '${config.normalizedBaseUrl}/api/v3.6/product/$code.json'
      '?fields=code,product_name,product_name_de,product_name_en,generic_name,brands,quantity,'
      'serving_size,serving_quantity,serving_quantity_unit,'
      'image_front_url,image_front_small_url,ingredients_text,allergens,link,'
      'nutrition,nutriments',
    );
    try {
      final Map<String, dynamic> json = await _getJson(uri);
      final dynamic product = json['product'];
      if (product is Map<String, dynamic>) {
        return OffProduct.fromProductJson(product);
      }
      if (product is Map) {
        return OffProduct.fromProductJson(product.cast<String, dynamic>());
      }
      return null;
    } on MorphException catch (e) {
      if (e.code == 'off.not_found') return null;
      rethrow;
    }
  }

  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    final http.Response response;
    try {
      response = await _http
          .get(uri, headers: <String, String>{
            'User-Agent': config.userAgent,
            'Accept': 'application/json',
          })
          .timeout(timeout);
    } on MorphException {
      rethrow;
    } catch (e) {
      throw MorphException('off.unreachable',
          'Der Open-Food-Facts-Endpunkt ist nicht erreichbar (${config.normalizedBaseUrl}): $e');
    }
    if (response.statusCode == 404) {
      throw MorphException('off.not_found', 'Produkt nicht gefunden (HTTP 404).');
    }
    if (response.statusCode != 200) {
      throw MorphException('off.http_status',
          'Unerwarteter HTTP-Status ${response.statusCode} von ${uri.path}.');
    }
    try {
      final dynamic decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) return decoded.cast<String, dynamic>();
      throw const FormatException('Antwort ist kein JSON-Objekt');
    } catch (e) {
      throw MorphException('off.parse_error', 'Antwort konnte nicht verarbeitet werden: $e');
    }
  }
}
