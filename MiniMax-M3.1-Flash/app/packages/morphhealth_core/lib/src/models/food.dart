import 'package:meta/meta.dart';

import 'nutrients.dart';

/// Where a food item originates from.
enum FoodSource {
  /// Retrieved from the Open Food Facts database.
  openFoodFacts,

  /// Created by the user inside the app.
  custom,
}

/// A named portion of a food (e.g. "1 Scheibe = 35 g").
@immutable
class Portion {
  const Portion({
    required this.label,
    required this.amountGrams,
    this.isDefault = false,
  });

  final String label;

  /// Grams (or millilitres) this portion corresponds to.
  final double amountGrams;

  /// Whether this portion is preselected when adding the food.
  final bool isDefault;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'label': label,
        'amount_g': amountGrams,
        'default': isDefault,
      };

  static Portion fromJson(Map<String, dynamic> json) => Portion(
        label: json['label'] as String? ?? '',
        amountGrams: _toDouble(json['amount_g']) ?? 0,
        isDefault: json['default'] == true,
      );
}

/// A food that can be logged in the journal.
@immutable
class FoodItem {
  const FoodItem({
    required this.id,
    required this.name,
    required this.source,
    required this.nutrientsPer100,
    this.brand,
    this.barcode,
    this.servingGrams,
    this.servingLabel,
    this.portions = const <Portion>[],
    this.imageUrl,
    this.isFavorite = false,
    this.createdAtMs = 0,
    this.updatedAtMs = 0,
    this.note,
  });

  final String id;
  final String name;
  final FoodSource source;
  final String? brand;
  final String? barcode;

  /// Nutrition values per 100 g (energy in kcal / kJ, mass nutrients in g).
  final NutrientProfile nutrientsPer100;

  /// Grams per default serving, when known.
  final double? servingGrams;

  /// Human readable serving description, e.g. "1 Scheibe (35 g)".
  final String? servingLabel;

  final List<Portion> portions;
  final String? imageUrl;
  final bool isFavorite;
  final int createdAtMs;
  final int updatedAtMs;
  final String? note;

  bool get isCustom => source == FoodSource.custom;

  double get energyKcal => nutrientsPer100[Nutrients.energyKcal];

  FoodItem copyWith({
    String? name,
    FoodSource? source,
    String? brand,
    bool clearBrand = false,
    String? barcode,
    bool clearBarcode = false,
    NutrientProfile? nutrientsPer100,
    double? servingGrams,
    bool clearServing = false,
    String? servingLabel,
    List<Portion>? portions,
    String? imageUrl,
    bool? isFavorite,
    int? createdAtMs,
    int? updatedAtMs,
    String? note,
  }) {
    return FoodItem(
      id: id,
      name: name ?? this.name,
      source: source ?? this.source,
      brand: clearBrand ? null : (brand ?? this.brand),
      barcode: clearBarcode ? null : (barcode ?? this.barcode),
      nutrientsPer100: nutrientsPer100 ?? this.nutrientsPer100,
      servingGrams: clearServing ? null : (servingGrams ?? this.servingGrams),
      servingLabel: servingLabel ?? this.servingLabel,
      portions: portions ?? this.portions,
      imageUrl: imageUrl ?? this.imageUrl,
      isFavorite: isFavorite ?? this.isFavorite,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
      note: note ?? this.note,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'source': source == FoodSource.custom ? 'custom' : 'open_food_facts',
        if (brand != null) 'brand': brand,
        if (barcode != null) 'barcode': barcode,
        'nutrients_per_100': nutrientsPer100.toJson(),
        if (servingGrams != null) 'serving_g': servingGrams,
        if (servingLabel != null) 'serving_label': servingLabel,
        if (portions.isNotEmpty)
          'portions':
              portions.map((Portion p) => p.toJson()).toList(growable: false),
        if (imageUrl != null) 'image_url': imageUrl,
        'favorite': isFavorite,
        'created_at_ms': createdAtMs,
        'updated_at_ms': updatedAtMs,
        if (note != null) 'note': note,
      };

  static FoodItem fromJson(Map<String, dynamic> json) => FoodItem(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        source: json['source'] == 'custom'
            ? FoodSource.custom
            : FoodSource.openFoodFacts,
        brand: json['brand'] as String?,
        barcode: json['barcode'] as String?,
        nutrientsPer100: NutrientProfile.fromJson(
          (json['nutrients_per_100'] as Map<String, dynamic>?) ??
              const <String, dynamic>{},
        ),
        servingGrams: _toDouble(json['serving_g']),
        servingLabel: json['serving_label'] as String?,
        portions: ((json['portions'] as List<dynamic>?) ?? const <dynamic>[])
            .map((dynamic e) => Portion.fromJson(e as Map<String, dynamic>))
            .toList(growable: false),
        imageUrl: json['image_url'] as String?,
        isFavorite: json['favorite'] == true,
        createdAtMs: _toInt(json['created_at_ms']) ?? 0,
        updatedAtMs: _toInt(json['updated_at_ms']) ?? 0,
        note: json['note'] as String?,
      );
}

double? _toDouble(dynamic v) => v is num ? v.toDouble() : null;

int? _toInt(dynamic v) => v is num ? v.toInt() : null;
