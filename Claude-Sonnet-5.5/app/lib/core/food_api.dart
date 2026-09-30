import 'dart:convert';

import 'package:characters/characters.dart';

import 'http.dart';
import 'models.dart';
import 'nutrients.dart';

/// Fehler beim Zugriff auf die Lebensmitteldatenbank mit stabilem Code:
/// `disabled`, `invalid_base_url`, `empty_query`, `invalid_barcode`,
/// `offline`, `timeout`, `tls`, `not_found`, `rate_limited`, `http_error`,
/// `bad_response`.
final class FoodApiException implements Exception {
  final String code;
  final String message;

  const FoodApiException(this.code, this.message);

  @override
  String toString() => 'FoodApiException($code): $message';
}

/// Ergebnisseite einer Suche.
final class FoodSearchPage {
  final String query;
  final int page;
  final int pageSize;

  /// Gesamtzahl der Treffer laut Datenbank.
  final int total;
  final List<FoodInfo> items;

  const FoodSearchPage({
    required this.query,
    required this.page,
    required this.pageSize,
    required this.total,
    required this.items,
  });

  bool get hasMore => page * pageSize < total;

  Map<String, Object?> toJson() => {
    'query': query,
    'page': page,
    'page_size': pageSize,
    'total': total,
    'has_more': hasMore,
    'results': [for (final f in items) f.toJson(rounded: true)],
  };
}

/// Ein abgerufenes Produkt samt Herkunft der Nährwerte.
final class FoodLookup {
  final FoodInfo food;

  /// `input_set`, `aggregated_set` oder `legacy_nutriments`.
  final String nutritionSource;

  const FoodLookup(this.food, this.nutritionSource);
}

/// Feste Feldauswahl (Feldprojektion nach dem API-Vertrag) für Suche und Abruf.
const String kOffFields =
    'code,product_name,product_name_de,product_name_en,generic_name,generic_name_de,'
    'brands,quantity,serving_size,serving_quantity,serving_quantity_unit,product_quantity,product_quantity_unit,'
    'nutrition_data_per,nutrition_data_prepared_per,nutrition,nutriments,lang';

/// Lesender Client für Open Food Facts (Vertrag: `GET /api/v3.6/product/{code}.json`
/// und `GET /cgi/search.pl`). Der Ursprung und der User-Agent sind Parameter.
final class FoodApi {
  static const int pageSize = 20;
  static const Duration timeout = Duration(seconds: 20);

  final Uri base;
  final String userAgent;
  final HttpTransport transport;

  /// Sprache für Produktnamen (`de` oder `en`).
  final String language;

  FoodApi._(this.base, this.userAgent, this.transport, this.language);

  /// [baseUrl] ist ein HTTPS-Ursprung wie `https://world.openfoodfacts.org`.
  factory FoodApi({
    required String baseUrl,
    required String userAgent,
    required HttpTransport transport,
    String language = 'de',
  }) {
    return FoodApi._(parseBaseUrl(baseUrl), userAgent, transport, language);
  }

  /// Prüft einen Ursprung und gibt ihn ohne Pfad und ohne Schrägstrich zurück.
  static Uri parseBaseUrl(String baseUrl) {
    final u = Uri.tryParse(baseUrl.trim());
    if (u == null || u.scheme != 'https' || u.host.isEmpty || u.hasQuery || u.hasFragment || u.userInfo.isNotEmpty) {
      throw const FoodApiException(
        'invalid_base_url',
        'Der Ursprung der Lebensmittel-API muss https://host[:port] sein',
      );
    }
    if (u.path.isNotEmpty && u.path != '/') {
      throw const FoodApiException('invalid_base_url', 'Der Ursprung darf keinen Pfad enthalten');
    }
    return Uri(scheme: 'https', host: u.host, port: u.hasPort ? u.port : null);
  }

  Uri _url(String path, String query) => Uri.parse('${base.toString().replaceAll(RegExp(r'/$'), '')}$path?$query');

  Map<String, String> get _headers => {'user-agent': userAgent, 'accept': 'application/json'};

  /// Suche nach Namen. [page] beginnt bei 1.
  Future<FoodSearchPage> search(String query, {int page = 1}) async {
    final q = query.trim();
    if (q.isEmpty) throw const FoodApiException('empty_query', 'Der Suchbegriff ist leer');
    final p = page < 1 ? 1 : page;
    final uri = _url(
      '/cgi/search.pl',
      'search_terms=${Uri.encodeQueryComponent(q)}&search_simple=1&action=process&json=1&page=$p&page_size=$pageSize'
          '&fields=${Uri.encodeQueryComponent(kOffFields)}',
    );
    final json = await _getJson(uri);
    if (json is! Map || json['products'] is! List) {
      throw const FoodApiException('bad_response', 'Die Suchantwort enthält keine Produktliste');
    }
    final seen = <String>{};
    final items = <FoodInfo>[];
    for (final raw in json['products'] as List) {
      if (raw is! Map) continue;
      final parsed = parseOffProduct(raw.cast<String, Object?>(), language: language);
      if (parsed == null || parsed.food.name == parsed.food.barcode) continue;
      final key = parsed.food.barcode ?? parsed.food.name;
      if (seen.add(key)) items.add(parsed.food);
    }
    return FoodSearchPage(
      query: q,
      page: p,
      pageSize: _asInt(json['page_size']) ?? pageSize,
      total: _asInt(json['count']) ?? items.length,
      items: items,
    );
  }

  /// Ein Produkt über die Barcode-Nummer abrufen.
  Future<FoodLookup> lookup(String barcode) async {
    final code = normalizeBarcode(barcode);
    final uri = _url('/api/v3.6/product/$code.json', 'fields=${Uri.encodeQueryComponent(kOffFields)}');
    final json = await _getJson(uri, notFoundIsError: true);
    if (json is! Map) throw const FoodApiException('bad_response', 'Die Produktantwort ist kein Objekt');
    final status = json['status'];
    final product = json['product'];
    if (product is! Map || status == 'failure' || status == 0) {
      throw FoodApiException('not_found', 'Zu $code wurde kein Produkt gefunden');
    }
    final parsed = parseOffProduct(product.cast<String, Object?>(), language: language, fallbackCode: code);
    if (parsed == null) throw FoodApiException('not_found', 'Zu $code wurde kein Produkt gefunden');
    return parsed;
  }

  /// Entfernt Leerzeichen und Bindestriche und prüft die Länge (8 bis 14 Ziffern).
  static String normalizeBarcode(String input) {
    final code = input.replaceAll(RegExp(r'[\s-]'), '');
    if (!RegExp(r'^\d{8,14}$').hasMatch(code)) {
      throw const FoodApiException('invalid_barcode', 'Eine Barcode-Nummer hat 8 bis 14 Ziffern');
    }
    return code;
  }

  Future<Object?> _getJson(Uri uri, {bool notFoundIsError = false}) async {
    final HttpResponse res;
    try {
      res = await transport.get(uri, headers: _headers, timeout: timeout);
    } on HttpFailure catch (e) {
      throw FoodApiException(e.code == 'io' || e.code == 'too_large' ? 'http_error' : e.code, e.message);
    }
    if (res.status == 404) {
      if (notFoundIsError) {
        throw const FoodApiException('not_found', 'Produkt nicht gefunden');
      }
      throw const FoodApiException('http_error', 'HTTP 404');
    }
    if (res.status == 429 || res.status == 503) {
      throw FoodApiException('rate_limited', 'Die Datenbank ist gerade überlastet (HTTP ${res.status})');
    }
    if (res.status < 200 || res.status >= 300) {
      throw FoodApiException('http_error', 'HTTP ${res.status}');
    }
    try {
      return jsonDecode(utf8.decode(res.body));
    } on FormatException {
      throw const FoodApiException('bad_response', 'Die Antwort ist kein gültiges JSON');
    }
  }
}

int? _asInt(Object? v) {
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v.trim());
  return null;
}

double? _asNum(Object? v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.trim().replaceAll(',', '.'));
  return null;
}

String? _asText(Object? v) {
  if (v is! String) return null;
  final t = v.trim();
  return t.isEmpty ? null : t;
}

/// Kürzt auf höchstens [max] Zeichen (Grapheme), ohne ein Zeichen zu zerreißen.
String _clip(String s, int max) =>
    s.length <= max || s.characters.length <= max ? s : s.characters.take(max).toString();

// ---------------------------------------------------------------------------
// Auswertung eines Produkts
// ---------------------------------------------------------------------------

const double _kcalPerKj = 1 / 4.184;

/// Wertet ein Produkt-JSON aus. Unterstützt beide Nährwertformate:
///
/// * neu (Produktschema 1003 und höher, API v3.5+): `nutrition.input_sets`
///   und `nutrition.aggregated_set`;
/// * klassisch: `nutriments` mit `<name>_100g`.
///
/// Grundsätze: Es zählen nur angegebene Werte (Herkunft `packaging`,
/// `manufacturer`, ...), nie Schätzungen aus der Zutatenliste (`estimate`).
/// Bevorzugt wird ein Satz "wie verkauft" je 100 g/ml; danach je Portion
/// (umgerechnet), danach "zubereitet".
FoodLookup? parseOffProduct(Map<String, Object?> p, {String language = 'de', String? fallbackCode}) {
  final code = _asText(p['code']) ?? _asText(p['_id']) ?? fallbackCode;
  final name = _name(p, language) ?? code;
  if (name == null) return null;
  final brand = _asText(p['brands'])?.split(',').first.trim();

  final liquid = _isLiquid(p);
  _Parsed parsed = _Parsed.empty();
  final nutrition = p['nutrition'];
  if (nutrition is Map) {
    parsed = _fromNewSchema(nutrition.cast<String, Object?>(), liquid: liquid);
  }
  if (parsed.nutrients.isEmpty && p['nutriments'] is Map) {
    parsed = _fromLegacy((p['nutriments'] as Map).cast<String, Object?>(), p, liquid: liquid);
  }
  final basis = parsed.basis ?? (liquid ? Basis.ml : Basis.g);
  var serving = _serving(p, basis);
  if (serving == null && parsed.servingAmount != null) {
    final a = parsed.servingAmount!;
    if (a > 0 && a <= 100000) serving = Serving(double.parse(a.toStringAsFixed(3)));
  }
  return FoodLookup(
    FoodInfo(
      name: name,
      brand: (brand == null || brand.isEmpty) ? null : _clip(brand, 200),
      barcode: code,
      source: FoodSource.off,
      basis: basis,
      serving: serving,
      nutrients: parsed.nutrients,
      prepared: parsed.prepared,
    ),
    parsed.source,
  );
}

String? _name(Map<String, Object?> p, String lang) {
  final keys = ['product_name_$lang', 'product_name', 'product_name_en', 'generic_name_$lang', 'generic_name'];
  for (final k in keys) {
    final v = _asText(p[k]);
    if (v != null) return _clip(v, 200);
  }
  return null;
}

/// Ein Getränk (Menge in ml): dann gelten die Nährwerte je 100 ml.
bool _isLiquid(Map<String, Object?> p) {
  final pq = _asText(p['product_quantity_unit'])?.toLowerCase();
  if (pq == 'ml' || pq == 'cl' || pq == 'l') return true;
  if (pq == 'g' || pq == 'kg') return false;
  return _asText(p['serving_quantity_unit'])?.toLowerCase() == 'ml';
}

final class _Parsed {
  final Nutrients nutrients;
  final Basis? basis;
  final bool prepared;
  final String source;

  /// Portionsgröße aus einem Eingabesatz "je Portion", falls das Produkt
  /// selbst keine angibt.
  final double? servingAmount;

  const _Parsed(this.nutrients, this.basis, this.prepared, this.source, [this.servingAmount]);

  factory _Parsed.empty() => const _Parsed(Nutrients.none, null, false, 'none');
}

double? _unitToGrams(String unit, double v, NutrientDef def) {
  switch (unit.trim().toLowerCase()) {
    case 'g':
      return v;
    case 'mg':
      return v / 1e3;
    case 'µg':
    case 'μg':
    case 'mcg':
    case 'ug':
      return v / 1e6;
    case 'kg':
      return v * 1e3;
    case 'iu':
      // Internationale Einheiten: nur für die Vitamine mit festem Umrechnungsfaktor.
      return switch (def.key) {
        'vitamin_a_ug' => v * 0.3 / 1e6,
        'vitamin_d_ug' => v * 0.025 / 1e6,
        'vitamin_e_mg' => v * 0.67 / 1e3,
        _ => null,
      };
    default:
      return null;
  }
}

/// Wert eines Nährstoffs eines Eingabesatzes (`{value, unit, value_computed}`)
/// in der Katalogeinheit, hochgerechnet mit [factor] auf 100 g/ml.
double? _newSchemaValue(NutrientDef def, Object? node, double factor) {
  if (node is! Map) return null;
  final v = _asNum(node['value']) ?? _asNum(node['value_computed']);
  if (v == null || v < 0) return null;
  final unit = _asText(node['unit']) ?? '';
  double? out;
  if (def.key == kEnergy) {
    out = unit.toLowerCase() == 'kcal' ? v : null;
  } else {
    final g = _unitToGrams(unit, v, def);
    out = g == null ? null : g * def.offFactor;
  }
  return out == null ? null : out * factor;
}

/// Die Nährwerte der Bezugsgröße 100 g/100 ml, so wie Open Food Facts sie
/// liefert: kcal direkt, sonst aus kJ umgerechnet.
Nutrients _collectNewSchema(Map<String, Object?> nutrients, double factor) {
  final out = <String, double>{};
  for (final def in nutrientCatalog) {
    double? v;
    for (final id in def.offIds) {
      v = _newSchemaValue(def, nutrients[id], factor);
      if (v != null) break;
    }
    if (def.key == kEnergy && v == null) {
      final kj = nutrients['energy-kj'] ?? nutrients['energy'];
      if (kj is Map) {
        final raw = _asNum(kj['value']) ?? _asNum(kj['value_computed']);
        final unit = (_asText(kj['unit']) ?? 'kJ').toLowerCase();
        if (raw != null && raw >= 0 && unit == 'kj') v = raw * _kcalPerKj * factor;
      }
    }
    if (v != null) out[def.key] = v;
  }
  return Nutrients.of(out);
}

final class _Candidate {
  final int index;
  final int rank;
  final bool prepared;
  final bool perServing;
  final String unit; // g oder ml
  final double factor; // auf 100 g/ml
  final Map<String, Object?> nutrients;

  const _Candidate(this.index, this.rank, this.prepared, this.perServing, this.unit, this.factor, this.nutrients);
}

int _sourceRank(String s) => switch (s) {
  'manufacturer' => 0,
  'packaging' => 1,
  'usda' => 2,
  _ => 3,
};

/// Menge in g oder ml mit Einheit, umgerechnet in (Betrag, "g" oder "ml").
(double, String)? _quantity(Object? q, Object? unit) {
  final v = _asNum(q);
  final u = _asText(unit)?.toLowerCase();
  if (v == null || v <= 0 || u == null) return null;
  return switch (u) {
    'g' => (v, 'g'),
    'kg' => (v * 1000, 'g'),
    'ml' => (v, 'ml'),
    'cl' => (v * 10, 'ml'),
    'dl' => (v * 100, 'ml'),
    'l' => (v * 1000, 'ml'),
    _ => null,
  };
}

_Parsed _fromNewSchema(Map<String, Object?> nutrition, {required bool liquid}) {
  final sets = nutrition['input_sets'];
  final cands = <_Candidate>[];
  if (sets is List) {
    for (var i = 0; i < sets.length; i++) {
      final s = sets[i];
      if (s is! Map) continue;
      final source = _asText(s['source']) ?? '';
      if (source == 'estimate') continue;
      final per = _asText(s['per']) ?? '';
      var q = _quantity(s['per_quantity'], s['per_unit']);
      if (q == null && per == '100g') q = (100, 'g');
      if (q == null && per == '100ml') q = (100, 'ml');
      if (q == null) continue;
      final n = s['nutrients'];
      if (n is! Map) continue;
      cands.add(
        _Candidate(
          i,
          _sourceRank(source),
          _asText(s['preparation']) == 'prepared',
          per == 'serving',
          q.$2,
          100 / q.$1,
          n.cast<String, Object?>(),
        ),
      );
    }
  }
  if (cands.isNotEmpty) {
    int mismatch(_Candidate c) => (liquid && c.unit != 'ml') || (!liquid && c.unit == 'ml') ? 1 : 0;
    cands.sort((a, b) {
      final keys = [
        (a.prepared ? 1 : 0).compareTo(b.prepared ? 1 : 0),
        (a.perServing ? 1 : 0).compareTo(b.perServing ? 1 : 0),
        mismatch(a).compareTo(mismatch(b)),
        a.rank.compareTo(b.rank),
        a.index.compareTo(b.index),
      ];
      for (final k in keys) {
        if (k != 0) return k;
      }
      return 0;
    });
    final primary = cands.first;
    var merged = _collectNewSchema(primary.nutrients, primary.factor);
    // Fehlende Werte aus weiteren angegebenen Sätzen derselben Art auffüllen.
    for (final c in cands.skip(1)) {
      if (c.prepared != primary.prepared || c.unit != primary.unit) continue;
      final extra = _collectNewSchema(c.nutrients, c.factor);
      for (final k in extra.keys) {
        if (!merged.has(k)) merged = merged.with_(k, extra[k]);
      }
    }
    if (merged.isNotEmpty) {
      final basis = (primary.unit == 'ml' || liquid) ? Basis.ml : Basis.g;
      final src = primary.perServing ? 'input_set_per_serving' : 'input_set';
      double? serving;
      for (final c in cands) {
        if (c.perServing && c.unit == primary.unit) {
          serving = 100 / c.factor;
          break;
        }
      }
      return _Parsed(merged, basis, primary.prepared, src, serving);
    }
  }
  // Kein brauchbarer Eingabesatz: zusammengeführten Satz verwenden, aber ohne
  // Schätzungen.
  final agg = nutrition['aggregated_set'];
  if (agg is Map) {
    final nutrients = agg['nutrients'];
    if (nutrients is Map) {
      final declared = <String, Object?>{
        for (final e in nutrients.entries)
          if (e.value is Map && _asText((e.value as Map)['source']) != 'estimate') e.key.toString(): e.value,
      };
      final per = _asText(agg['per']);
      final merged = _collectNewSchema(declared, 1);
      if (merged.isNotEmpty) {
        return _Parsed(
          merged,
          per == '100ml' || liquid ? Basis.ml : Basis.g,
          _asText(agg['preparation']) == 'prepared',
          'aggregated_set',
        );
      }
    }
  }
  return _Parsed.empty();
}

_Parsed _fromLegacy(Map<String, Object?> n, Map<String, Object?> p, {required bool liquid}) {
  Nutrients collect(String suffix) {
    final out = <String, double>{};
    for (final def in nutrientCatalog) {
      double? v;
      for (final id in def.offIds) {
        final raw = _asNum(n['$id$suffix']);
        if (raw != null && raw >= 0) {
          v = raw * def.offFactor;
          break;
        }
      }
      if (def.key == kEnergy && v == null) {
        final kj = _asNum(n['energy-kj$suffix']) ?? _asNum(n['energy$suffix']);
        if (kj != null && kj >= 0) v = kj * _kcalPerKj;
      }
      if (v != null) out[def.key] = v;
    }
    return Nutrients.of(out);
  }

  var nutrients = collect('_100g');
  var prepared = false;
  const mainKeys = [kEnergy, kProtein, kCarbs, kFat];
  if (!mainKeys.any(nutrients.has)) {
    final prep = collect('_prepared_100g');
    if (mainKeys.any(prep.has)) {
      nutrients = prep;
      prepared = true;
    }
  }
  final per = _asText(p['nutrition_data_per']);
  return _Parsed(nutrients, (per == '100ml' || liquid) ? Basis.ml : Basis.g, prepared, 'legacy_nutriments');
}

Serving? _serving(Map<String, Object?> p, Basis basis) {
  double? amount;
  final q = _quantity(p['serving_quantity'], p['serving_quantity_unit'] ?? (basis == Basis.ml ? 'ml' : 'g'));
  if (q != null) amount = q.$1;
  final text = _asText(p['serving_size']);
  if (amount == null && text != null) {
    final m = RegExp(r'(\d+(?:[.,]\d+)?)\s*(kg|g|ml|cl|dl|l)\b', caseSensitive: false).firstMatch(text);
    if (m != null) {
      final conv = _quantity(m[1]!.replaceAll(',', '.'), m[2]);
      if (conv != null) amount = conv.$1;
    }
  }
  if (amount == null || amount <= 0 || amount > 100000) return null;
  final label = text == null ? null : _clip(text, 100);
  return Serving(amount, label);
}
