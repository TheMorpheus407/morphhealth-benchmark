import '../util/dates.dart';
import '../util/json_reader.dart';
import 'nutrients.dart';

/// Where a food record comes from.
enum FoodSource {
  /// Created and maintained by the user.
  custom('custom'),

  /// Taken over from Open Food Facts and kept locally.
  openFoodFacts('open_food_facts');

  final String code;
  const FoodSource(this.code);

  static FoodSource? byCode(String? code) {
    for (final v in values) {
      if (v.code == code) return v;
    }
    return null;
  }

  static Iterable<String> get codes => values.map((e) => e.code);
}

/// The reference quantity of a food's nutrient values.
enum FoodBasis {
  per100g('100g', 'g'),
  per100ml('100ml', 'ml');

  /// Value in data formats: `100g` or `100ml`.
  final String code;

  /// Unit of the reference quantity: `g` or `ml`.
  final String unit;

  const FoodBasis(this.code, this.unit);

  static FoodBasis? byCode(String? code) {
    for (final v in values) {
      if (v.code == code) return v;
    }
    return null;
  }

  static Iterable<String> get codes => values.map((e) => e.code);
}

/// A food the user can log: an own food or a product kept from Open Food Facts.
class Food {
  final String id;
  final FoodSource source;
  final String name;
  final String? brand;
  final String? barcode;
  final FoodBasis basis;

  /// Size of one portion in the basis unit (g or ml), if defined.
  final double? servingSize;

  /// Free description of a portion, for example "1 Scheibe".
  final String? servingLabel;

  /// Package size as printed, for example "400 g". Informational.
  final String? packageQuantity;

  /// Grams per millilitre for converting between g and ml; 1.0 if unknown.
  final double? densityGPerMl;

  /// Nutrient amounts per 100 g or per 100 ml, see [basis].
  final NutrientValues nutrients;

  /// Keys of nutrients whose amount is an estimate rather than a label value.
  final Set<String> estimated;

  /// True if the amounts describe the prepared product (Open Food Facts).
  final bool prepared;

  final bool favorite;

  /// Hidden from lists but kept because diary entries still refer to it.
  final bool archived;

  final String? note;
  final LocalDateTime createdAt;
  final LocalDateTime updatedAt;

  /// When the product data was last fetched from Open Food Facts.
  final LocalDateTime? fetchedAt;

  Food({
    required this.id,
    required this.source,
    required this.name,
    this.brand,
    this.barcode,
    this.basis = FoodBasis.per100g,
    this.servingSize,
    this.servingLabel,
    this.packageQuantity,
    this.densityGPerMl,
    NutrientValues? nutrients,
    Set<String>? estimated,
    this.prepared = false,
    this.favorite = false,
    this.archived = false,
    this.note,
    required this.createdAt,
    required this.updatedAt,
    this.fetchedAt,
  }) : nutrients = nutrients ?? NutrientValues(),
       estimated = estimated ?? const {};

  NutrientValues? _completed;

  /// [nutrients] with salt and sodium derived from each other where only one
  /// of them is known. This is what all calculations use.
  NutrientValues get completedNutrients =>
      _completed ??= nutrients.copy()..completeSaltAndSodium();

  double get density {
    final d = densityGPerMl;
    return d == null || d <= 0 ? 1.0 : d;
  }

  bool get isCustom => source == FoodSource.custom;

  /// Name with brand, for lists and search.
  String get displayName {
    final b = brand;
    return b == null || b.isEmpty ? name : '$name · $b';
  }

  Food copyWith({
    String? name,
    Object? brand = _keep,
    Object? barcode = _keep,
    FoodBasis? basis,
    Object? servingSize = _keep,
    Object? servingLabel = _keep,
    Object? packageQuantity = _keep,
    Object? densityGPerMl = _keep,
    NutrientValues? nutrients,
    Set<String>? estimated,
    bool? prepared,
    bool? favorite,
    bool? archived,
    Object? note = _keep,
    LocalDateTime? updatedAt,
    Object? fetchedAt = _keep,
  }) => Food(
    id: id,
    source: source,
    name: name ?? this.name,
    brand: identical(brand, _keep) ? this.brand : brand as String?,
    barcode: identical(barcode, _keep) ? this.barcode : barcode as String?,
    basis: basis ?? this.basis,
    servingSize: identical(servingSize, _keep)
        ? this.servingSize
        : servingSize as double?,
    servingLabel: identical(servingLabel, _keep)
        ? this.servingLabel
        : servingLabel as String?,
    packageQuantity: identical(packageQuantity, _keep)
        ? this.packageQuantity
        : packageQuantity as String?,
    densityGPerMl: identical(densityGPerMl, _keep)
        ? this.densityGPerMl
        : densityGPerMl as double?,
    nutrients: nutrients ?? this.nutrients,
    estimated: estimated ?? this.estimated,
    prepared: prepared ?? this.prepared,
    favorite: favorite ?? this.favorite,
    archived: archived ?? this.archived,
    note: identical(note, _keep) ? this.note : note as String?,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    fetchedAt: identical(fetchedAt, _keep)
        ? this.fetchedAt
        : fetchedAt as LocalDateTime?,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'source': source.code,
    'name': name,
    if (brand != null) 'brand': brand,
    if (barcode != null) 'barcode': barcode,
    'basis': basis.code,
    if (servingSize != null) 'serving_size': roundForJson(servingSize!),
    if (servingLabel != null) 'serving_label': servingLabel,
    if (packageQuantity != null) 'package_quantity': packageQuantity,
    if (densityGPerMl != null) 'density_g_per_ml': roundForJson(densityGPerMl!),
    'nutrients': nutrients.toJson(),
    if (estimated.isNotEmpty)
      'estimated_nutrients': [
        for (final n in Nutrients.all)
          if (estimated.contains(n.key)) n.key,
      ],
    if (prepared) 'prepared': true,
    'favorite': favorite,
    if (archived) 'archived': true,
    if (note != null) 'note': note,
    'created_at': createdAt.toIso(),
    'updated_at': updatedAt.toIso(),
    if (fetchedAt != null) 'fetched_at': fetchedAt!.toIso(),
  };

  /// Reads and validates a food. Problems are recorded in the reader's log;
  /// null is returned if the record cannot be used.
  static Food? fromJson(
    ObjectReader r, {
    required LocalDateTime now,
    required String Function() idFactory,
  }) {
    final before = r.log.errorCount;
    final id = r.string('id', maxLength: 100) ?? idFactory();
    final sourceCode = r.choice('source', FoodSource.codes);
    final name = r.string('name', required: true, maxLength: 200);
    final brand = r.string('brand', maxLength: 200);
    final barcode = r.string('barcode', maxLength: 32);
    if (barcode != null && !RegExp(r'^[0-9]{1,24}$').hasMatch(barcode)) {
      r.log.error('${r.path}.barcode', 'must consist of digits only');
    }
    final basisCode = r.choice('basis', FoodBasis.codes);
    final servingSize = r.number(
      'serving_size',
      min: 0,
      max: 100000,
      exclusiveMin: true,
    );
    final servingLabel = r.string('serving_label', maxLength: 100);
    final packageQuantity = r.string('package_quantity', maxLength: 100);
    final density = r.number('density_g_per_ml', min: 0.05, max: 25);
    final nutrients = NutrientValues.fromJson(r.object('nutrients'));
    final estimated = <String>{};
    final est = r.list('estimated_nutrients');
    if (est != null) {
      for (var i = 0; i < est.length; i++) {
        final k = est[i];
        if (k is String && Nutrients.byKey(k) != null) {
          estimated.add(k);
        } else {
          r.log.warning(
            '${r.path}.estimated_nutrients[$i]',
            'unknown nutrient key was ignored',
          );
        }
      }
    }
    final prepared = r.boolean('prepared') ?? false;
    final favorite = r.boolean('favorite') ?? false;
    final archived = r.boolean('archived') ?? false;
    final note = r.string('note', maxLength: 2000);
    final createdAt = r.dateTime('created_at') ?? now;
    final updatedAt = r.dateTime('updated_at') ?? createdAt;
    final fetchedAt = r.dateTime('fetched_at');
    r.warnUnknown();
    if (r.log.errorCount != before || name == null) return null;
    return Food(
      id: id,
      source: FoodSource.byCode(sourceCode) ?? FoodSource.custom,
      name: name,
      brand: brand,
      barcode: barcode,
      basis: FoodBasis.byCode(basisCode) ?? FoodBasis.per100g,
      servingSize: servingSize,
      servingLabel: servingLabel,
      packageQuantity: packageQuantity,
      densityGPerMl: density,
      nutrients: nutrients,
      estimated: estimated,
      prepared: prepared,
      favorite: favorite,
      archived: archived,
      note: note,
      createdAt: createdAt,
      updatedAt: updatedAt,
      fetchedAt: fetchedAt,
    );
  }
}

const Object _keep = Object();
