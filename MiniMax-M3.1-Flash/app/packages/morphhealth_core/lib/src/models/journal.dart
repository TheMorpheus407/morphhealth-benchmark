import 'package:meta/meta.dart';

/// Meal a journal entry belongs to.
enum MealSlot {
  breakfast,
  lunch,
  dinner,
  snack;

  static MealSlot parse(String? value) => MealSlot.values.firstWhere(
        (MealSlot m) => m.name == value,
        orElse: () => MealSlot.snack,
      );
}

/// Unit a logged quantity is expressed in.
enum QuantityUnit {
  gram,
  milliliter,
  portion;

  static QuantityUnit parse(String? value) => QuantityUnit.values.firstWhere(
        (QuantityUnit u) => u.name == value,
        orElse: () => QuantityUnit.gram,
      );
}

/// A consumed food inside the journal.
///
/// The entry stores a snapshot of the food name so that history stays
/// readable even if the food item is edited or deleted later.
@immutable
class JournalEntry {
  const JournalEntry({
    required this.id,
    required this.foodId,
    required this.foodName,
    required this.quantity,
    required this.unit,
    required this.meal,
    required this.date,
    required this.loggedAtMs,
    this.portionLabel,
    this.portionGrams,
    this.note,
    this.brand,
    this.nutrientsPer100Snapshot = const <String, double>{},
    this.createdAtMs = 0,
    this.updatedAtMs = 0,
  });

  final String id;
  final String foodId;
  final String foodName;
  final String? brand;

  /// Numeric amount as entered: grams, millilitres or portion count.
  final double quantity;
  final QuantityUnit unit;
  final MealSlot meal;

  /// Local calendar day (YYYY-MM-DD) the entry belongs to.
  final String date;

  /// Epoch milliseconds of the logged moment (UTC).
  final int loggedAtMs;

  /// Label of the chosen portion, when the unit is [QuantityUnit.portion].
  final String? portionLabel;

  /// Grams that the chosen portion stands for.
  final double? portionGrams;
  final String? note;

  /// Nutrient values of the food at the time of logging.
  ///
  /// They are used as a fallback when the referenced food was deleted, so
  /// that history stays numerically correct.
  final Map<String, double> nutrientsPer100Snapshot;
  final int createdAtMs;
  final int updatedAtMs;

  JournalEntry copyWith({
    String? foodId,
    String? foodName,
    String? brand,
    bool clearBrand = false,
    double? quantity,
    QuantityUnit? unit,
    MealSlot? meal,
    String? date,
    int? loggedAtMs,
    String? portionLabel,
    bool clearPortion = false,
    double? portionGrams,
    String? note,
    Map<String, double>? nutrientsPer100Snapshot,
    int? createdAtMs,
    int? updatedAtMs,
  }) {
    return JournalEntry(
      id: id,
      foodId: foodId ?? this.foodId,
      foodName: foodName ?? this.foodName,
      brand: clearBrand ? null : (brand ?? this.brand),
      quantity: quantity ?? this.quantity,
      unit: unit ?? this.unit,
      meal: meal ?? this.meal,
      date: date ?? this.date,
      loggedAtMs: loggedAtMs ?? this.loggedAtMs,
      portionLabel:
          clearPortion ? null : (portionLabel ?? this.portionLabel),
      portionGrams: clearPortion ? null : (portionGrams ?? this.portionGrams),
      note: note ?? this.note,
      nutrientsPer100Snapshot:
          nutrientsPer100Snapshot ?? this.nutrientsPer100Snapshot,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'food_id': foodId,
        'food_name': foodName,
        if (brand != null) 'brand': brand,
        'quantity': quantity,
        'unit': unit.name,
        'meal': meal.name,
        'date': date,
        'logged_at_ms': loggedAtMs,
        if (portionLabel != null) 'portion_label': portionLabel,
        if (portionGrams != null) 'portion_grams': portionGrams,
        if (note != null) 'note': note,
        'nutrients_per_100': nutrientsPer100Snapshot,
        'created_at_ms': createdAtMs,
        'updated_at_ms': updatedAtMs,
      };

  static JournalEntry fromJson(Map<String, dynamic> json) => JournalEntry(
        id: json['id'] as String,
        foodId: json['food_id'] as String? ?? '',
        foodName: json['food_name'] as String? ?? '',
        brand: json['brand'] as String?,
        quantity: (json['quantity'] as num?)?.toDouble() ?? 0,
        unit: QuantityUnit.parse(json['unit'] as String?),
        meal: MealSlot.parse(json['meal'] as String?),
        date: json['date'] as String? ?? '',
        loggedAtMs: (json['logged_at_ms'] as num?)?.toInt() ?? 0,
        portionLabel: json['portion_label'] as String?,
        portionGrams: (json['portion_grams'] as num?)?.toDouble(),
        note: json['note'] as String?,
        nutrientsPer100Snapshot: _snapshotFrom(
          json['nutrients_per_100'] as Map<String, dynamic>?,
        ),
        createdAtMs: (json['created_at_ms'] as num?)?.toInt() ?? 0,
        updatedAtMs: (json['updated_at_ms'] as num?)?.toInt() ?? 0,
      );
}

Map<String, double> _snapshotFrom(Map<String, dynamic>? json) {
  if (json == null) return const <String, double>{};
  final Map<String, double> out = <String, double>{};
  json.forEach((String key, dynamic value) {
    if (value is num) out[key] = value.toDouble();
  });
  return out;
}

/// Kind of quick intake (water or additional caffeine).
enum IntakeKind {
  water,
  caffeine;

  static IntakeKind parse(String? value) => IntakeKind.values.firstWhere(
        (IntakeKind k) => k.name == value,
        orElse: () => IntakeKind.water,
      );
}

/// Water or additional caffeine logged directly in the journal.
///
/// Water is stored in millilitres, caffeine in milligrams.
@immutable
class IntakeEntry {
  const IntakeEntry({
    required this.id,
    required this.kind,
    required this.amount,
    required this.date,
    required this.loggedAtMs,
    this.note,
    this.createdAtMs = 0,
    this.updatedAtMs = 0,
  });

  final String id;
  final IntakeKind kind;

  /// Millilitres for water, milligrams for caffeine.
  final double amount;
  final String date;
  final int loggedAtMs;
  final String? note;
  final int createdAtMs;
  final int updatedAtMs;

  IntakeEntry copyWith({
    IntakeKind? kind,
    double? amount,
    String? date,
    int? loggedAtMs,
    String? note,
    int? createdAtMs,
    int? updatedAtMs,
  }) {
    return IntakeEntry(
      id: id,
      kind: kind ?? this.kind,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      loggedAtMs: loggedAtMs ?? this.loggedAtMs,
      note: note ?? this.note,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'kind': kind.name,
        'amount': amount,
        'unit': kind == IntakeKind.water ? 'ml' : 'mg',
        'date': date,
        'logged_at_ms': loggedAtMs,
        if (note != null) 'note': note,
        'created_at_ms': createdAtMs,
        'updated_at_ms': updatedAtMs,
      };

  static IntakeEntry fromJson(Map<String, dynamic> json) => IntakeEntry(
        id: json['id'] as String,
        kind: IntakeKind.parse(json['kind'] as String?),
        amount: (json['amount'] as num?)?.toDouble() ?? 0,
        date: json['date'] as String? ?? '',
        loggedAtMs: (json['logged_at_ms'] as num?)?.toInt() ?? 0,
        note: json['note'] as String?,
        createdAtMs: (json['created_at_ms'] as num?)?.toInt() ?? 0,
        updatedAtMs: (json['updated_at_ms'] as num?)?.toInt() ?? 0,
      );
}
