library morphhealth.core.model.food;

import 'package:morphhealth/core/model/nutrients.dart';

/// Quelle eines Lebensmittels in einem Verzehreintrag.
enum FoodSource { local, off }

/// Ein Lebensmittel, das im Tagebuch verwendet werden kann.
abstract class Food {
  const Food({
    required this.id,
    required this.name,
    required this.source,
    required this.profile,
    this.brand,
    this.servingSizeGrams,
    this.imageUrl,
  });

  /// Stabiles, eindeutiges ID (Barcode bei OFF, UUID bei lokalen Lebensmitteln).
  final String id;
  final String name;
  final FoodSource source;
  final String? brand;
  /// Portionsgröße in Gramm, falls bekannt.
  final double? servingSizeGrams;
  final NutrientProfile profile;
  final String? imageUrl;

  Map<String, dynamic> toJson();

  @override
  String toString() => name;
}

/// Lokales, vom Nutzer angelegtes und bearbeitbares Lebensmittel.
class LocalFood extends Food {
  const LocalFood({
    required super.id,
    required super.name,
    super.brand,
    super.profile = const NutrientProfile(),
    super.servingSizeGrams,
    super.imageUrl,
    this.createdAt,
    this.updatedAt,
  }) : super(source: FoodSource.local);

  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory LocalFood.fromJson(Map<String, dynamic> json) => LocalFood(
        id: json['id'] as String,
        name: json['name'] as String,
        brand: json['brand'] as String?,
        profile: NutrientProfile.fromJson(
          Map<String, dynamic>.from(json['profile'] ?? <String, dynamic>{}),
        ),
        servingSizeGrams:
            (json['servingSizeGrams'] as num?)?.toDouble(),
        imageUrl: json['imageUrl'] as String?,
        createdAt: json['createdAt'] == null
            ? null
            : DateTime.parse(json['createdAt'] as String),
        updatedAt: json['updatedAt'] == null
            ? null
            : DateTime.parse(json['updatedAt'] as String),
      );

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'brand': brand,
        'profile': profile.toJson(),
        'servingSizeGrams': servingSizeGrams,
        'imageUrl': imageUrl,
        'createdAt': createdAt?.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
      };
}

/// Ein über Open Food Facts geladenes Produkt (schreibgeschützter Cache).
class OffProduct extends Food {
  const OffProduct({
    required super.id,
    required super.name,
    super.brand,
    super.profile = const NutrientProfile(),
    super.servingSizeGrams,
    super.imageUrl,
    this.categories = const [],
    this.fetchedAt,
    this.raw,
  }) : super(source: FoodSource.off);

  final List<String> categories;
  final DateTime? fetchedAt;
  final Map<String, dynamic>? raw;

  factory OffProduct.fromJson(Map<String, dynamic> json) => OffProduct(
        id: json['id'] as String,
        name: json['name'] as String,
        brand: json['brand'] as String?,
        profile: NutrientProfile.fromJson(
          Map<String, dynamic>.from(json['profile'] ?? <String, dynamic>{}),
        ),
        servingSizeGrams:
            (json['servingSizeGrams'] as num?)?.toDouble(),
        imageUrl: json['imageUrl'] as String?,
        categories: List<String>.from(json['categories'] ?? <String>[]),
        fetchedAt: json['fetchedAt'] == null
            ? null
            : DateTime.parse(json['fetchedAt'] as String),
        raw: json['raw'] == null ? null : Map<String, dynamic>.from(json['raw']),
      );

  @override
  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'brand': brand,
        'profile': profile.toJson(),
        'servingSizeGrams': servingSizeGrams,
        'imageUrl': imageUrl,
        'categories': categories,
        'fetchedAt': fetchedAt?.toIso8601String(),
        'raw': raw,
      };
}