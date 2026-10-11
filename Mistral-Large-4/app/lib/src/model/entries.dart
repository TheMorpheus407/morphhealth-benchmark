// Datenmodelle: Verzehreinträge, Wasser- und Koffeineinträge.
library;

import '../core/parse.dart';

/// Mahlzeit eines Verzehreintrags.
enum Meal {
  breakfast,
  lunch,
  dinner,
  snack;

  static Meal fromString(String? value) {
    switch (value) {
      case 'lunch':
        return Meal.lunch;
      case 'dinner':
        return Meal.dinner;
      case 'snack':
        return Meal.snack;
      default:
        return Meal.breakfast;
    }
  }
}

/// Mengeneinheit eines Verzehreintrags.
enum QuantityUnit {
  /// Gramm.
  g,
  /// Milliliter (Dichte 1 g/ml für die Nährwertberechnung).
  ml,
  /// Portionen (eine Portion = Lebensmittel-Portionsgröße, sonst 100 g).
  portion;

  static QuantityUnit fromString(String? value) {
    switch (value) {
      case 'ml':
        return QuantityUnit.ml;
      case 'portion':
        return QuantityUnit.portion;
      default:
        return QuantityUnit.g;
    }
  }
}

/// Ein protokollierter Verzehr.
///
/// `foodPer100` ist ein Schnappschuss der Nährwerte zum Zeitpunkt der
/// Erfassung — spätere Änderungen am Lebensmittel ändern den Eintrag nicht.
class NutritionEntry {
  String id;
  String foodId;
  String foodName;
  Map<String, double> foodPer100;
  double? foodServingGrams;
  String date; // YYYY-MM-DD
  String? time; // HH:MM (lokal), optional
  Meal meal;
  double quantity;
  QuantityUnit unit;
  String? note;
  DateTime createdAt;

  NutritionEntry({
    required this.id,
    required this.foodId,
    required this.foodName,
    required this.foodPer100,
    this.foodServingGrams,
    required this.date,
    this.time,
    required this.meal,
    required this.quantity,
    required this.unit,
    this.note,
    required this.createdAt,
  });

  /// Effektive Masse in Gramm (ml ⇒ 1 g/ml, Portion ⇒ Portionsgröße).
  double effectiveGrams() {
    switch (unit) {
      case QuantityUnit.g:
        return quantity;
      case QuantityUnit.ml:
        return quantity;
      case QuantityUnit.portion:
        return quantity * (foodServingGrams ?? 100);
    }
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'food_id': foodId,
        'food_name': foodName,
        'food_per100': <String, dynamic>{
          for (final MapEntry<String, double> e in foodPer100.entries) e.key: e.value,
        },
        if (foodServingGrams != null) 'food_serving_grams': foodServingGrams,
        'date': date,
        if (time != null) 'time': time,
        'meal': meal.name,
        'quantity': quantity,
        'unit': unit.name,
        if (note != null) 'note': note,
        'created_at': createdAt.toUtc().toIso8601String(),
      };

  static NutritionEntry fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic>? per100Raw = getMap(json, 'food_per100');
    return NutritionEntry(
      id: getString(json, 'id') ?? '',
      foodId: getString(json, 'food_id') ?? '',
      foodName: getString(json, 'food_name') ?? '',
      foodPer100: <String, double>{
        for (final MapEntry<String, dynamic> e in (per100Raw ?? <String, dynamic>{}).entries)
          e.key: (e.value is num) ? (e.value as num).toDouble() : 0,
      },
      foodServingGrams: getDouble(json, 'food_serving_grams'),
      date: getString(json, 'date') ?? '',
      time: getString(json, 'time'),
      meal: Meal.fromString(getString(json, 'meal')),
      quantity: getDouble(json, 'quantity') ?? 0,
      unit: QuantityUnit.fromString(getString(json, 'unit')),
      note: getString(json, 'note'),
      createdAt: DateTime.tryParse(getString(json, 'created_at') ?? '') ?? DateTime.now().toUtc(),
    );
  }
}

/// Ein Wassereintrag (ml).
class WaterEntry {
  String id;
  String date;
  String? time;
  double amountMl;
  String? note;

  WaterEntry({
    required this.id,
    required this.date,
    this.time,
    required this.amountMl,
    this.note,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'date': date,
        if (time != null) 'time': time,
        'amount_ml': amountMl,
        if (note != null) 'note': note,
      };

  static WaterEntry fromJson(Map<String, dynamic> json) => WaterEntry(
        id: getString(json, 'id') ?? '',
        date: getString(json, 'date') ?? '',
        time: getString(json, 'time'),
        amountMl: getDouble(json, 'amount_ml') ?? 0,
        note: getString(json, 'note'),
      );
}

/// Ein zusätzlicher Koffeinfall (mg), z. B. eine Tasse Kaffee.
class CaffeineEntry {
  String id;
  String date;
  String? time;
  double amountMg;
  String? note;

  CaffeineEntry({
    required this.id,
    required this.date,
    this.time,
    required this.amountMg,
    this.note,
  });

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'date': date,
        if (time != null) 'time': time,
        'amount_mg': amountMg,
        if (note != null) 'note': note,
      };

  static CaffeineEntry fromJson(Map<String, dynamic> json) => CaffeineEntry(
        id: getString(json, 'id') ?? '',
        date: getString(json, 'date') ?? '',
        time: getString(json, 'time'),
        amountMg: getDouble(json, 'amount_mg') ?? 0,
        note: getString(json, 'note'),
      );
}
