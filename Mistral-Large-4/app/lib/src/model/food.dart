// Datenmodell: Lebensmittel (eigen oder Open-Food-Facts-Schnappschuss).
library;

import '../core/parse.dart';

/// Woher ein Lebensmittel stammt.
enum FoodSource {
  /// Vom Nutzer selbst angelegt (bearbeitbar).
  custom,
  /// Schnappschuss eines Open-Food-Facts-Produkts (nicht bearbeitbar).
  off,
}

/// Eine Portionsangabe (für Mengeneinheit „Portion“).
class Serving {
  /// Masse der Portion in Gramm (ml werden mit Dichte 1 g/ml angenommen).
  final double? grams;
  /// Anzeigetext, z. B. „1 Scheibe“.
  final String? label;
  const Serving({this.grams, this.label});

  Map<String, dynamic> toJson() => <String, dynamic>{
        if (grams != null) 'grams': grams,
        if (label != null) 'label': label,
      };

  static Serving? fromJson(Map<String, dynamic>? json) {
    if (json == null) return null;
    final double? g = getDouble(json, 'grams');
    final String? l = getString(json, 'label');
    if (g == null && l == null) return null;
    return Serving(grams: g, label: l);
  }
}

/// Ein Lebensmittel (eigenes oder OFF-Schnappschuss).
///
/// Nährwerte liegen kanonisch pro 100 g vor (siehe nutrients.dart).
class FoodItem {
  String id;
  String name;
  String? brand;
  String? barcode;
  FoodSource source;
  Map<String, double> per100;
  Serving? serving;
  bool isFavorite;
  String? imageUrl;
  String? offOrigin;
  DateTime createdAt;
  DateTime updatedAt;

  FoodItem({
    required this.id,
    required this.name,
    this.brand,
    this.barcode,
    required this.source,
    required this.per100,
    this.serving,
    this.isFavorite = false,
    this.imageUrl,
    this.offOrigin,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isCustom => source == FoodSource.custom;

  FoodItem copy() => FoodItem(
        id: id,
        name: name,
        brand: brand,
        barcode: barcode,
        source: source,
        per100: Map<String, double>.of(per100),
        serving: serving,
        isFavorite: isFavorite,
        imageUrl: imageUrl,
        offOrigin: offOrigin,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        if (brand != null) 'brand': brand,
        if (barcode != null) 'barcode': barcode,
        'source': source.name,
        'per100': <String, dynamic>{
          for (final MapEntry<String, double> e in per100.entries) e.key: e.value,
        },
        if (serving != null) 'serving': serving!.toJson(),
        'is_favorite': isFavorite,
        if (imageUrl != null) 'image_url': imageUrl,
        if (offOrigin != null) 'off_origin': offOrigin,
        'created_at': createdAt.toUtc().toIso8601String(),
        'updated_at': updatedAt.toUtc().toIso8601String(),
      };

  static FoodItem fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic>? per100Raw = getMap(json, 'per100');
    return FoodItem(
      id: getString(json, 'id') ?? '',
      name: getString(json, 'name') ?? '',
      brand: getString(json, 'brand'),
      barcode: getString(json, 'barcode'),
      source: getString(json, 'source') == 'off' ? FoodSource.off : FoodSource.custom,
      per100: <String, double>{
        for (final MapEntry<String, dynamic> e in (per100Raw ?? <String, dynamic>{}).entries)
          e.key: (e.value is num) ? (e.value as num).toDouble() : 0,
      },
      serving: Serving.fromJson(getMap(json, 'serving')),
      isFavorite: getBool(json, 'is_favorite') ?? false,
      imageUrl: getString(json, 'image_url'),
      offOrigin: getString(json, 'off_origin'),
      createdAt: DateTime.tryParse(getString(json, 'created_at') ?? '') ?? DateTime.now().toUtc(),
      updatedAt: DateTime.tryParse(getString(json, 'updated_at') ?? '') ?? DateTime.now().toUtc(),
    );
  }
}
