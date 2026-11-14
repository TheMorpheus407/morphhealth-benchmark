import "dart:convert";
import "dart:io";
import "models.dart";

// Read-only Open Food Facts client (P08). Base URL / user agent are injected, never hard-coded
// into fachlogik beyond defaults in settings.
class OffClient {
  final String baseUrl;
  final String userAgent;
  OffClient(this.baseUrl, this.userAgent);
  String get _base => baseUrl.endsWith("/") ? baseUrl.substring(0, baseUrl.length - 1) : baseUrl;

  Future<Map<String, dynamic>> _getJson(Uri uri) async {
    final c = HttpClient();
    try {
      final req = await c.getUrl(uri);
      req.headers.set(HttpHeaders.userAgentHeader, userAgent);
      req.headers.set(HttpHeaders.acceptHeader, "application/json");
      final res = await req.close();
      final body = await res.transform(utf8.decoder).join();
      if (res.statusCode != 200) throw FormatException("food api http ${res.statusCode}");
      return jsonDecode(body) as Map<String, dynamic>;
    } finally { c.close(); }
  }

  Future<Map<String, dynamic>> search(String q, int page) async {
    final uri = Uri.parse("$_base/cgi/search.pl?search_terms=${Uri.encodeComponent(q)}&search_simple=1&action=process&json=1&page=$page&page_size=20");
    final j = await _getJson(uri);
    final products = (j["products"] as List? ?? []).cast<Map<String, dynamic>>();
    return {"q": q, "page": page, "count": j["count"] ?? products.length, "page_count": j["page_count"] ?? 1,
      "results": [for (final p in products) _summary(p)]};
  }

  Future<Map<String, dynamic>> lookup(String barcode) async {
    final uri = Uri.parse("$_base/api/v3.6/product/$barcode.json");
    final j = await _getJson(uri);
    if (j["status"] == "failure" || j["product"] == null) {
      return {"barcode": barcode, "found": false, "result": j["result"], "errors": j["errors"]};
    }
    final p = j["product"] as Map<String, dynamic>;
    return {"barcode": barcode, "found": true, "product": _full(p)};
  }

  Map<String, dynamic> _summary(Map<String, dynamic> p) => {
    "barcode": (p["code"] ?? p["_id"] ?? "").toString(),
    "name": _name(p), "brand": (p["brands"] ?? "").toString(),
    "nutriments_per_100": _nutriments(p),
  };
  Map<String, dynamic> _full(Map<String, dynamic> p) => {
    ..._summary(p),
    "serving_size": (p["serving_size"] ?? "").toString(),
    "quantity": (p["quantity"] ?? "").toString(),
    "categories": (p["categories"] ?? "").toString(),
    "image_url": (p["image_url"] ?? p["image_front_url"] ?? "").toString(),
  };
  String _name(Map<String, dynamic> p) {
    for (final k in ["product_name_de", "product_name", "abbreviated_product_name_de", "abbreviated_product_name"]) {
      final v = (p[k] ?? "").toString().trim();
      if (v.isNotEmpty) return v;
    }
    return "Unnamed product";
  }
  Map<String, double> _nutriments(Map<String, dynamic> p) {
    // Search payloads carry flat *_100g values; the product v3.6 payload nests
    // them under nutrition.aggregated_set.nutrients with per-100g "value" + unit.
    // Both shapes are supported; the live test server uses the nested form for
    // product lookups, so lookup must read it.
    final out = emptyNutrients();
    dynamic n = p["nutriments"];
    bool nested = false;
    if (n is Map && n.isEmpty) {
      final agg = p["nutrition"];
      if (agg is Map && agg["aggregated_set"] is Map) {
        final nn = (agg["aggregated_set"] as Map)["nutrients"];
        if (nn is Map) { n = nn; nested = true; }
      }
    }
    if (n is! Map) return out;
    if (nested) {
      double v(String key, double factor) {
        final e = n[key];
        if (e is! Map) return 0.0;
        final raw = e["value"];
        if (raw is! num) return 0.0;
        var val = raw.toDouble();
        final unit = (e["unit"] ?? "").toString();
        // Normalize known OFF units to the target factor basis: most are g,
        // caffeine is mg, minerals in g; vitamins in g.
        if (unit == "mg") val = val / 1000.0;
        if (unit == "ug" || unit == "µg") val = val / 1e6;
        return val * factor;
      }
      out["kcal"] = v("energy-kcal", 1);
      out["protein"] = v("proteins", 1); out["carbs"] = v("carbohydrates", 1); out["fat"] = v("fat", 1);
      out["satFat"] = v("saturated-fat", 1); out["sugars"] = v("sugars", 1); out["fiber"] = v("fiber", 1);
      out["salt"] = v("salt", 1);
      out["sodium"] = v("sodium", 1000);
      out["caffeine"] = v("caffeine", 1000); // OFF caffeine unit is mg -> g basis handled by v/1000 then *1000
      out["vitA"] = v("vitamin-a", 1e6); out["vitC"] = v("vitamin-c", 1000); out["vitD"] = v("vitamin-d", 1e6);
      out["vitE"] = v("vitamin-e", 1000); out["vitK"] = v("vitamin-k", 1e6);
      out["vitB1"] = v("vitamin-b1", 1000); out["vitB2"] = v("vitamin-b2", 1000); out["vitB3"] = v("vitamin-b3", 1000);
      out["vitB5"] = v("vitamin-b5", 1000); out["vitB6"] = v("vitamin-b6", 1000); out["vitB7"] = v("vitamin-b7", 1e6);
      out["vitB9"] = v("vitamin-b9", 1e6); out["vitB12"] = v("vitamin-b12", 1e6);
      out["calcium"] = v("calcium", 1000); out["iron"] = v("iron", 1000); out["magnesium"] = v("magnesium", 1000);
      out["potassium"] = v("potassium", 1000); out["zinc"] = v("zinc", 1000); out["selenium"] = v("selenium", 1e6);
      out["iodine"] = v("iodine", 1e6); out["phosphorus"] = v("phosphorus", 1000);
      return out;
    }
    double g(String key, double factor) { final val = n["${key}_100g"]; return val is num ? val.toDouble() * factor : 0.0; }
    out["kcal"] = g("energy-kcal", 1);
    out["protein"] = g("proteins", 1); out["carbs"] = g("carbohydrates", 1); out["fat"] = g("fat", 1);
    out["satFat"] = g("saturated-fat", 1); out["sugars"] = g("sugars", 1); out["fiber"] = g("fiber", 1);
    out["salt"] = g("salt", 1);
    out["sodium"] = g("sodium", 1000); // OFF sodium_100g is in g -> mg
    out["caffeine"] = g("caffeine", 1); // OFF caffeine_100g is in mg
    out["vitA"] = g("vitamin-a", 1e6); out["vitC"] = g("vitamin-c", 1000); out["vitD"] = g("vitamin-d", 1e6);
    out["vitE"] = g("vitamin-e", 1000); out["vitK"] = g("vitamin-k", 1e6);
    out["vitB1"] = g("vitamin-b1", 1000); out["vitB2"] = g("vitamin-b2", 1000); out["vitB3"] = g("vitamin-b3", 1000);
    out["vitB5"] = g("vitamin-b5", 1000); out["vitB6"] = g("vitamin-b6", 1000); out["vitB7"] = g("vitamin-b7", 1e6);
    out["vitB9"] = g("vitamin-b9", 1e6); out["vitB12"] = g("vitamin-b12", 1e6);
    out["calcium"] = g("calcium", 1000); out["iron"] = g("iron", 1000); out["magnesium"] = g("magnesium", 1000);
    out["potassium"] = g("potassium", 1000); out["zinc"] = g("zinc", 1000); out["selenium"] = g("selenium", 1e6);
    out["iodine"] = g("iodine", 1e6); out["phosphorus"] = g("phosphorus", 1000);
    return out;
  }
}
