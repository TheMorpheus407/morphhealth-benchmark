library morphhealth.core.service.off_client;

import 'dart:convert';

import 'package:http/http.dart' as http;

import '../model/food.dart';
import '../model/nutrients.dart';

/// Lesender Client für den Open-Food-Facts-Vertrag (P08).
///
/// Der Origin (Base-URL) und der User-Agent werden vom Aufrufer übergeben
/// (ENVIRONMENT.json: food_api_base_url / food_api_user_agent), nicht fest in
/// den Fachcode eingebaut. Damit läuft die Integration an jedem anderen
/// Origin desselben Vertrags ohne Fachlogik-Änderung.
class OpenFoodFactsClient {
  OpenFoodFactsClient({
    required this.baseUrl,
    required this.userAgent,
    http.Client? client,
  }) : _client = client ?? http.Client();

  final String baseUrl;
  final String userAgent;
  final http.Client _client;

  /// Produkt per Barcode abrufen. Gibt null zurück, wenn nicht gefunden.
  Future<OffProduct?> lookup(String barcode) async {
    final uri = Uri.parse('${_base(baseUrl)}/api/v3.6/product/$barcode.json');
    final response = await _client.get(uri, headers: {'User-Agent': userAgent});
    if (response.statusCode != 200) {
      return null;
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    if (decoded['status'] != 'success' || decoded['product'] == null) {
      return null;
    }
    return _productFromOff(decoded['product'] as Map<String, dynamic>, barcode);
  }

  /// Volltextsuche nach Lebensmitteln. [pageSize] ist nach Vertrag auf 20
  /// fixiert (Seitenparameter wird trotzdem mitgesendet).
  Future<OffSearchResult> search(String q, {int page = 1, int pageSize = 20}) async {
    final uri = Uri.parse('${_base(baseUrl)}/cgi/search.pl').replace(queryParameters: <String, String>{
      'search_terms': q,
      'search_simple': '1',
      'action': 'process',
      'json': '1',
      'page': page.toString(),
      'page_size': pageSize.toString(),
    });
    final response = await _client.get(uri, headers: {'User-Agent': userAgent});
    if (response.statusCode != 200) {
      return OffSearchResult(products: <OffProduct>[], count: 0, page: page, pageSize: pageSize);
    }
    final decoded = jsonDecode(response.body) as Map<String, dynamic>;
    final count = (decoded['count'] as num?)?.toInt() ?? 0;
    final products = <OffProduct>[];
    for (final item in (decoded['products'] as List<dynamic>?) ?? <dynamic>[]) {
      if (item is! Map<String, dynamic>) continue;
      final code = item['code'] == null ? null : item['code'].toString();
      if (code == null || code.isEmpty) continue;
      products.add(_productFromOff(item, code));
    }
    return OffSearchResult(
      products: products,
      count: count,
      page: page,
      pageSize: pageSize,
    );
  }

  void dispose() => _client.close();

  OffProduct _productFromOff(Map<String, dynamic> p, String code) {
    final nutriments = (p['nutriments'] as Map<String, dynamic>?) ?? <String, dynamic>{};
    return OffProduct(
      id: code,
      name: _str(p['product_name']) ?? _str(p['generic_name']) ?? 'Unbekanntes Produkt',
      brand: _str(p['brands']),
      profile: NutrientProfile(
        energyKcal: _num(nutriments['energy-kcal_100g']),
        proteinG: _num(nutriments['proteins_100g']),
        carbsG: _num(nutriments['carbohydrates_100g']),
        fatG: _num(nutriments['fat_100g']),
        saturatedFatG: _num(nutriments['saturated-fat_100g']),
        sugarG: _num(nutriments['sugars_100g']),
        fiberG: _num(nutriments['fiber_100g']),
        saltG: _num(nutriments['salt_100g']),
        sodiumG: _num(nutriments['sodium_100g']),
        caffeineMg: _num(nutriments['caffeine_100g']),
        vitaminAG: _num(nutriments['vitamin-a_100g']),
        vitaminCG: _num(nutriments['vitamin-c_100g']),
        vitaminDG: _num(nutriments['vitamin-d_100g']),
        vitaminEG: _num(nutriments['vitamin-e_100g']),
        vitaminKG: _num(nutriments['vitamin-k_100g']),
        vitaminB1G: _num(nutriments['vitamin-b1_100g']),
        vitaminB2G: _num(nutriments['vitamin-b2_100g']),
        vitaminB3G: _num(nutriments['vitamin-b3_100g']),
        vitaminB5G: _num(nutriments['vitamin-b5_100g']),
        vitaminB6G: _num(nutriments['vitamin-b6_100g']),
        vitaminB7G: _num(nutriments['vitamin-b7_100g']),
        vitaminB9G: _num(nutriments['vitamin-b9_100g']),
        vitaminB12G: _num(nutriments['vitamin-b12_100g']),
        calciumMg: _num(nutriments['calcium_100g']),
        ironMg: _num(nutriments['iron_100g']),
        magnesiumMg: _num(nutriments['magnesium_100g']),
        potassiumMg: _num(nutriments['potassium_100g']),
        zincMg: _num(nutriments['zinc_100g']),
        seleniumMg: _num(nutriments['selenium_100g']),
        iodineMg: _num(nutriments['iodine_100g']),
        phosphorusMg: _num(nutriments['phosphorus_100g']),
      ),
      servingSizeGrams: _servingSizeGrams(p),
      imageUrl: _str(p['image_url']),
      categories: _categories(p),
      fetchedAt: DateTime.now(),
      raw: p,
    );
  }

  static double? _servingSizeGrams(Map<String, dynamic> p) {
    final qty = _num(p['serving_quantity']);
    final size = _str(p['serving_size']) ?? '';
    if (qty == null) return null;
    final grams = _gramsFromSize(size);
    if (grams != null) return qty * grams;
    return null;
  }

  static double? _gramsFromSize(String size) {
    final match = RegExp(r'([\d.,]+)\s*(g|gramm|grammes)').firstMatch(size);
    if (match != null) return _num(match.group(1)!);
    if (RegExp(r'(portion|piece|stück|unité)', caseSensitive: false).hasMatch(size)) {
      return 100.0;
    }
    return null;
  }

  static List<String> _categories(Map<String, dynamic> p) {
    final raw = p['categories'];
    if (raw == null) return <String>[];
    final text = raw is List ? raw.join(', ') : raw.toString();
    return text.split(',').where((s) => s.trim().isNotEmpty).map((s) => s.trim()).toList();
  }

  static String? _str(dynamic v) => v == null ? null : v.toString();

static double? _num(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString());
  }

  static String _base(String url) => url.replaceFirst(RegExp(r'/+$'), '');
}

/// Ergebnis einer Lebensmittelsuche.
class OffSearchResult {
  const OffSearchResult({
    required this.products,
    required this.count,
    required this.page,
    required this.pageSize,
  });

  final List<OffProduct> products;
  final int count;
  final int page;
  final int pageSize;

  int get pageCount => pageSize > 0 ? (count / pageSize).ceil() : 0;
}