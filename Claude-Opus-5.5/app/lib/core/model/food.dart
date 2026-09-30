import '../util/clock.dart';
import '../util/ids.dart';
import '../util/json_reader.dart';
import 'enums.dart';
import 'nutrients.dart';
import 'record.dart';

/// Everything needed to compute nutrition for a food: its identity, the
/// reference basis (per 100 g or 100 ml), an optional portion size and the
/// nutrient values per 100 basis units.
///
/// Diary entries keep a copy of the profile that was used when they were
/// logged, so history stays stable even if a library food changes later.
class FoodProfile {
  FoodProfile({
    required this.source,
    required this.name,
    this.brand,
    this.barcode,
    this.basis = Basis.g,
    this.servingSize,
    this.servingLabel,
    this.densityGPerMl,
    Map<String, double>? nutrients,
    Set<String>? estimatedNutrients,
  }) : nutrients = Map.unmodifiable(nutrients ?? const {}),
       estimatedNutrients = Set.unmodifiable(estimatedNutrients ?? const {});

  final FoodSource source;
  final String name;
  final String? brand;
  final String? barcode;
  final Basis basis;

  /// Size of one portion in [basis] units, if known.
  final double? servingSize;

  /// Human-readable portion description, e.g. "1 Scheibe".
  final String? servingLabel;

  /// Density used to convert between g and ml; 1.0 is assumed when null.
  final double? densityGPerMl;

  /// Nutrient values per 100 [basis] units, keyed by [Nutrient.key].
  final Map<String, double> nutrients;

  /// Keys of values that are estimates (e.g. Open Food Facts "estimate from
  /// ingredients") rather than declared on the package.
  final Set<String> estimatedNutrients;

  double get density => densityGPerMl ?? 1.0;

  bool get hasServing => servingSize != null && servingSize! > 0;

  /// Units in which this food can be logged.
  List<AmountUnit> get supportedUnits => [
    basis == Basis.g ? AmountUnit.g : AmountUnit.ml,
    basis == Basis.g ? AmountUnit.ml : AmountUnit.g,
    if (hasServing) AmountUnit.portion,
  ];

  /// Whether logging in [unit] needs a g↔ml conversion with an assumed
  /// density of 1 g/ml.
  bool usesAssumedDensity(AmountUnit unit) {
    if (densityGPerMl != null) return false;
    return (unit == AmountUnit.g && basis == Basis.ml) ||
        (unit == AmountUnit.ml && basis == Basis.g);
  }

  /// Converts a logged amount into [basis] units, or null if not possible.
  double? quantityInBasis(double amount, AmountUnit unit) {
    switch (unit) {
      case AmountUnit.portion:
        return hasServing ? amount * servingSize! : null;
      case AmountUnit.g:
        return basis == Basis.g ? amount : amount / density;
      case AmountUnit.ml:
        return basis == Basis.ml ? amount : amount * density;
    }
  }

  /// Nutrient amount for [quantity] basis units, or null if unknown.
  double? valueFor(String key, double quantity) {
    final per100 = nutrients[key];
    if (per100 == null) return null;
    return per100 * quantity / 100.0;
  }

  String get displayName => brand == null ? name : '$name · $brand';

  FoodProfile copyWith({
    FoodSource? source,
    String? name,
    String? Function()? brand,
    String? Function()? barcode,
    Basis? basis,
    double? Function()? servingSize,
    String? Function()? servingLabel,
    double? Function()? densityGPerMl,
    Map<String, double>? nutrients,
    Set<String>? estimatedNutrients,
  }) {
    return FoodProfile(
      source: source ?? this.source,
      name: name ?? this.name,
      brand: brand != null ? brand() : this.brand,
      barcode: barcode != null ? barcode() : this.barcode,
      basis: basis ?? this.basis,
      servingSize: servingSize != null ? servingSize() : this.servingSize,
      servingLabel: servingLabel != null ? servingLabel() : this.servingLabel,
      densityGPerMl: densityGPerMl != null
          ? densityGPerMl()
          : this.densityGPerMl,
      nutrients: nutrients ?? this.nutrients,
      estimatedNutrients: estimatedNutrients ?? this.estimatedNutrients,
    );
  }

  /// True if both profiles describe the same nutrition data.
  bool sameNutritionAs(FoodProfile other) {
    if (basis != other.basis ||
        servingSize != other.servingSize ||
        densityGPerMl != other.densityGPerMl ||
        nutrients.length != other.nutrients.length) {
      return false;
    }
    for (final e in nutrients.entries) {
      if (other.nutrients[e.key] != e.value) return false;
    }
    return true;
  }

  static const Set<String> jsonKeys = {
    'source',
    'name',
    'brand',
    'barcode',
    'basis',
    'serving_size',
    'serving_label',
    'density_g_per_ml',
    'nutrients',
    'estimated_nutrients',
  };

  Map<String, Object?> toJson() => {
    'source': source.json,
    'name': name,
    'brand': brand,
    'barcode': barcode,
    'basis': basis.json,
    'serving_size': servingSize,
    'serving_label': servingLabel,
    'density_g_per_ml': densityGPerMl,
    'nutrients': {
      for (final n in Nutrients.all)
        if (nutrients.containsKey(n.key)) n.key: nutrients[n.key],
    },
    'estimated_nutrients': [
      for (final n in Nutrients.all)
        if (estimatedNutrients.contains(n.key)) n.key,
    ],
  };

  static FoodProfile? read(JsonReader r) {
    final errorsBefore = r.issues.errors.length;
    final source =
        r.enumValue('source', FoodSource.byJson) ?? FoodSource.custom;
    final name = r.string('name', required: true, maxLength: 200);
    final brand = r.string('brand', maxLength: 200);
    final barcode = r.string('barcode', maxLength: 32);
    if (barcode != null && !RegExp(r'^[0-9]{1,32}$').hasMatch(barcode)) {
      r.issues.error('${r.path}.barcode', 'must contain digits only');
    }
    final basis = r.enumValue('basis', Basis.byJson) ?? Basis.g;
    final servingSize = r.number(
      'serving_size',
      min: 0,
      exclusiveMin: true,
      max: 100000,
    );
    final servingLabel = r.string('serving_label', maxLength: 100);
    final density = r.number(
      'density_g_per_ml',
      min: 0.05,
      max: 25,
    );
    final nutrients = <String, double>{};
    final nr = r.object('nutrients');
    if (nr != null) {
      for (final key in nr.map.keys) {
        final n = Nutrients.tryGet(key);
        if (n == null) {
          r.issues.warn('${nr.path}.$key', 'unknown nutrient ignored');
          continue;
        }
        final v = nr.number(key, min: 0, max: n.maxPer100);
        if (v != null) nutrients[key] = v;
      }
    }
    final estimated = <String>{};
    final el = r.list('estimated_nutrients');
    if (el != null) {
      for (var i = 0; i < el.length; i++) {
        final v = el[i];
        if (v is String && Nutrients.tryGet(v) != null) {
          estimated.add(v);
        } else {
          r.issues.warn(
            '${r.path}.estimated_nutrients[$i]',
            'unknown nutrient ignored',
          );
        }
      }
    }
    if (r.issues.errors.length != errorsBefore || name == null) return null;
    final normalized = Nutrients.normalize(nutrients);
    // A derived salt/sodium value inherits the "estimated" flag.
    if (!nutrients.containsKey(Nutrients.sodium.key) &&
        normalized.containsKey(Nutrients.sodium.key) &&
        estimated.contains(Nutrients.salt.key)) {
      estimated.add(Nutrients.sodium.key);
    }
    if (!nutrients.containsKey(Nutrients.salt.key) &&
        normalized.containsKey(Nutrients.salt.key) &&
        estimated.contains(Nutrients.sodium.key)) {
      estimated.add(Nutrients.salt.key);
    }
    estimated.retainWhere(normalized.containsKey);
    return FoodProfile(
      source: source,
      name: name,
      brand: brand,
      barcode: barcode,
      basis: basis,
      servingSize: servingSize,
      servingLabel: servingLabel,
      densityGPerMl: density,
      nutrients: normalized,
      estimatedNutrients: estimated,
    );
  }
}

/// A food in the user's library: a custom food or a saved (favorite) product.
class Food implements Record {
  Food({
    required this.id,
    required this.profile,
    this.favorite = false,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Food.create(FoodProfile profile, DateTime now, {bool favorite = false}) =>
      Food(
        id: newId(),
        profile: profile,
        favorite: favorite,
        createdAt: now,
        updatedAt: now,
      );

  @override
  final String id;
  final FoodProfile profile;
  final bool favorite;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;

  bool get isCustom => profile.source == FoodSource.custom;

  Food copyWith({FoodProfile? profile, bool? favorite, DateTime? updatedAt}) =>
      Food(
        id: id,
        profile: profile ?? this.profile,
        favorite: favorite ?? this.favorite,
        createdAt: createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );

  @override
  Map<String, Object?> toJson() => {
    'id': id,
    ...profile.toJson(),
    'favorite': favorite,
    'created_at': formatInstant(createdAt),
    'updated_at': formatInstant(updatedAt),
  };

  static Food? fromJson(
    Object? json,
    String path,
    Issues issues,
    DateTime now,
  ) {
    final r = JsonReader.of(json, path, issues);
    if (r == null) return null;
    final before = issues.errors.length;
    r.warnUnknownKeys({
      ...FoodProfile.jsonKeys,
      'id',
      'favorite',
      'created_at',
      'updated_at',
    });
    final id = readId(r);
    final profile = FoodProfile.read(r);
    final favorite = r.boolean('favorite') ?? false;
    final created = r.instant('created_at') ?? now;
    final updated = r.instant('updated_at') ?? created;
    if (issues.errors.length != before || profile == null) return null;
    return Food(
      id: id,
      profile: profile,
      favorite: favorite,
      createdAt: created,
      updatedAt: updated,
    );
  }
}

/// Reads an optional record id; generates one when absent.
String readId(JsonReader r) {
  final id = r.string('id', maxLength: 64);
  if (id == null) return newId();
  if (!isValidId(id)) {
    r.issues.error(
      '${r.path}.id',
      'may only contain letters, digits and . _ : -',
    );
  }
  return id;
}
