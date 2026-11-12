library morphhealth.core.model.entries;

import 'dart:math' as math;

import 'package:morphhealth/core/model/food.dart';
import 'package:morphhealth/core/model/nutrients.dart';

/// Mahlzeitenzuordnung für Verzehreinträge.
enum Meal { breakfast, lunch, dinner, snack }

extension MealX on Meal {
  String get key => toString().split('.').last;
}
Meal mealFromKey(String k) {
  switch (k) {
    case 'breakfast':
      return Meal.breakfast;
    case 'lunch':
      return Meal.lunch;
    case 'dinner':
      return Meal.dinner;
    default:
      return Meal.snack;
  }
}

/// Blutungsstärke im Periodentracker.
enum PeriodIntensity { spotting, light, medium, heavy }

extension PeriodIntensityX on PeriodIntensity {
  String get key => toString().split('.').last;
}
PeriodIntensity periodIntensityFromKey(String k) {
  switch (k) {
    case 'light':
      return PeriodIntensity.light;
    case 'medium':
      return PeriodIntensity.medium;
    case 'heavy':
      return PeriodIntensity.heavy;
    default:
      return PeriodIntensity.spotting;
  }
}

/// Einheit für Gewichtseinträge.
enum WeightUnit { kg, lb }

extension WeightUnitX on WeightUnit {
  String get key => toString().split('.').last;

  /// Umrechnung in Kilogramm.
  double toKg(double value) {
    switch (this) {
      case WeightUnit.kg:
        return value;
      case WeightUnit.lb:
        return value * 0.45359237;
    }
  }

  /// Umrechnung aus Kilogramm in diese Einheit.
  double fromKg(double kg) {
    switch (this) {
      case WeightUnit.kg:
        return kg;
      case WeightUnit.lb:
        return kg / 0.45359237;
    }
  }
}

WeightUnit weightUnitFromKey(String k) => k == 'lb' ? WeightUnit.lb : WeightUnit.kg;

/// Ein geloggter Verzehr eines Lebensmittels.
class NutritionEntry {
  NutritionEntry({
    required this.id,
    required this.foodSource,
    required this.foodId,
    required this.foodName,
    required this.profilePer100g,
    required this.amountGrams,
    required this.amountMilliliters,
    required this.servingCount,
    required this.occurredAt,
    required this.meal,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final FoodSource foodSource;
  final String foodId; // lokale ID oder OFF-Barcode
  final String foodName;
  /// Gespeicherte Momentaufnahme der Nährwerte pro 100 g zum Erfassungszeitpunkt.
  final NutrientProfile profilePer100g;
  /// Menge in Gramm (bei Festem).
  final double amountGrams;
  /// Menge in Millilitern (bei Flüssigem).
  final double amountMilliliters;
  /// Anzahl Portionen (bei unit == serving).
  final double servingCount;
  final DateTime occurredAt;
  final Meal meal;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory NutritionEntry.fromJson(Map<String, dynamic> json) => NutritionEntry(
        id: json['id'] as String,
        foodSource: (json['foodSource'] as String) == 'local'
            ? FoodSource.local
            : FoodSource.off,
        foodId: json['foodId'] as String,
        foodName: json['foodName'] as String,
        profilePer100g: NutrientProfile.fromJson(
          Map<String, dynamic>.from(json['profilePer100g'] ?? <String, dynamic>{}),
        ),
        amountGrams: (json['amountGrams'] as num?)?.toDouble() ?? 0,
        amountMilliliters: (json['amountMilliliters'] as num?)?.toDouble() ?? 0,
        servingCount: (json['servingCount'] as num?)?.toDouble() ?? 0,
        occurredAt: DateTime.parse(json['occurredAt'] as String),
        meal: mealFromKey(json['meal'] as String? ?? 'snack'),
        createdAt: json['createdAt'] == null
            ? null
            : DateTime.parse(json['createdAt'] as String),
        updatedAt: json['updatedAt'] == null
            ? null
            : DateTime.parse(json['updatedAt'] as String),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'foodSource': foodSource == FoodSource.local ? 'local' : 'off',
        'foodId': foodId,
        'foodName': foodName,
        'profilePer100g': profilePer100g.toJson(),
        'amountGrams': amountGrams,
        'amountMilliliters': amountMilliliters,
        'servingCount': servingCount,
        'occurredAt': occurredAt.toIso8601String(),
        'meal': meal.key,
        'createdAt': createdAt?.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
      };

  /// Umgerechnete Gesamtmenge in Gramm (ml 1:1 als g annehmen, dokumentiert).
  double get effectiveGrams {
    if (amountGrams > 0) return amountGrams;
    if (amountMilliliters > 0) return amountMilliliters;
    return servingCount * 100.0;
  }

  /// Nährwerte dieses Eintrags (berechnet aus der gespeicherten Momentaufnahme).
  NutrientProfile get nutrients {
    final grams = effectiveGrams;
    return profilePer100g.scaled(grams / 100.0);
  }

  double get energyKcal => nutrients.energyKcal ?? 0;
  double get proteinG => nutrients.proteinG ?? 0;
  double get carbsG => nutrients.carbsG ?? 0;
  double get fatG => nutrients.fatG ?? 0;
}

class WaterEntry {
  WaterEntry({
    required this.id,
    required this.amountMilliliters,
    required this.occurredAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final double amountMilliliters;
  final DateTime occurredAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory WaterEntry.fromJson(Map<String, dynamic> json) => WaterEntry(
        id: json['id'] as String,
        amountMilliliters: (json['amountMilliliters'] as num?)?.toDouble() ?? 0,
        occurredAt: DateTime.parse(json['occurredAt'] as String),
        createdAt: json['createdAt'] == null
            ? null
            : DateTime.parse(json['createdAt'] as String),
        updatedAt: json['updatedAt'] == null
            ? null
            : DateTime.parse(json['updatedAt'] as String),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'amountMilliliters': amountMilliliters,
        'occurredAt': occurredAt.toIso8601String(),
        'createdAt': createdAt?.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
      };
}

class CaffeineEntry {
  CaffeineEntry({
    required this.id,
    required this.amountMg,
    required this.occurredAt,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final double amountMg;
  final DateTime occurredAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory CaffeineEntry.fromJson(Map<String, dynamic> json) => CaffeineEntry(
        id: json['id'] as String,
        amountMg: (json['amountMg'] as num?)?.toDouble() ?? 0,
        occurredAt: DateTime.parse(json['occurredAt'] as String),
        createdAt: json['createdAt'] == null
            ? null
            : DateTime.parse(json['createdAt'] as String),
        updatedAt: json['updatedAt'] == null
            ? null
            : DateTime.parse(json['updatedAt'] as String),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'amountMg': amountMg,
        'occurredAt': occurredAt.toIso8601String(),
        'createdAt': createdAt?.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
      };
}

/// Eine dokumentierte Periode (Blutung).
class CycleEntry {
  CycleEntry({
    required this.id,
    required this.startDate,
    this.endDate,
    required this.intensity,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final DateTime startDate; // lokaler Kalendertag (Zeit irrelevant)
  final DateTime? endDate;
  final PeriodIntensity intensity;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory CycleEntry.fromJson(Map<String, dynamic> json) => CycleEntry(
        id: json['id'] as String,
        startDate: DateTime.parse(json['startDate'] as String),
        endDate: json['endDate'] == null
            ? null
            : DateTime.parse(json['endDate'] as String),
        intensity: periodIntensityFromKey(
          json['intensity'] as String? ?? 'spotting',
        ),
        notes: json['notes'] as String?,
        createdAt: json['createdAt'] == null
            ? null
            : DateTime.parse(json['createdAt'] as String),
        updatedAt: json['updatedAt'] == null
            ? null
            : DateTime.parse(json['updatedAt'] as String),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'startDate': _date(startDate),
        'endDate': endDate == null ? null : _date(endDate!),
        'intensity': intensity.key,
        'notes': notes,
        'createdAt': createdAt?.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
      };

  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  int get durationDays {
    if (endDate == null) return 1;
    return endDate!.difference(startDate).inDays + 1;
  }
}

/// Ein Symptom-Eintrag mit freiem Namen, Intensität 0–10, optionaler Notiz.
class SymptomEntry {
  SymptomEntry({
    required this.id,
    required this.name,
    required this.intensity,
    required this.occurredAt,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String name;
  final int intensity; // 0–10
  final DateTime occurredAt;
  final String? notes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory SymptomEntry.fromJson(Map<String, dynamic> json) => SymptomEntry(
        id: json['id'] as String,
        name: json['name'] as String,
        intensity: (json['intensity'] as num?)?.toInt() ?? 0,
        occurredAt: DateTime.parse(json['occurredAt'] as String),
        notes: json['notes'] as String?,
        createdAt: json['createdAt'] == null
            ? null
            : DateTime.parse(json['createdAt'] as String),
        updatedAt: json['updatedAt'] == null
            ? null
            : DateTime.parse(json['updatedAt'] as String),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'intensity': intensity,
        'occurredAt': occurredAt.toIso8601String(),
        'notes': notes,
        'createdAt': createdAt?.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
      };
}

/// Ein Gewichtseintrag für ein gewähltes Datum.
class WeightEntry {
  WeightEntry({
    required this.id,
    required this.date,
    required this.value,
    required this.unit,
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final DateTime date; // lokaler Kalendertag
  final double value;
  final WeightUnit unit;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  factory WeightEntry.fromJson(Map<String, dynamic> json) => WeightEntry(
        id: json['id'] as String,
        date: DateTime.parse(json['date'] as String),
        value: (json['value'] as num?)?.toDouble() ?? 0,
        unit: weightUnitFromKey(json['unit'] as String? ?? 'kg'),
        createdAt: json['createdAt'] == null
            ? null
            : DateTime.parse(json['createdAt'] as String),
        updatedAt: json['updatedAt'] == null
            ? null
            : DateTime.parse(json['updatedAt'] as String),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'date': _date(date),
        'value': value,
        'unit': unit.key,
        'createdAt': createdAt?.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
      };

  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  double get valueInKg => unit.toKg(value);
}

/// Frei wählbare Tagesziele (null = nicht gesetzt).
class UserGoals {
  const UserGoals({
    this.waterMilliliters,
    this.energyKcal,
    this.proteinG,
    this.carbsG,
    this.fatG,
  });

  final double? waterMilliliters;
  final double? energyKcal;
  final double? proteinG;
  final double? carbsG;
  final double? fatG;

  factory UserGoals.fromJson(Map<String, dynamic> json) => UserGoals(
        waterMilliliters: (json['waterMilliliters'] as num?)?.toDouble(),
        energyKcal: (json['energyKcal'] as num?)?.toDouble(),
        proteinG: (json['proteinG'] as num?)?.toDouble(),
        carbsG: (json['carbsG'] as num?)?.toDouble(),
        fatG: (json['fatG'] as num?)?.toDouble(),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'waterMilliliters': waterMilliliters,
        'energyKcal': energyKcal,
        'proteinG': proteinG,
        'carbsG': carbsG,
        'fatG': fatG,
      };
}

/// App-Einstellungen (Nutzerwahl).
class AppSettings {
  const AppSettings({
    this.locale = 'de',
    this.visibleAreas = const {'nutrition', 'cycle', 'weight', 'overview'},
    this.goals,
  });

  final String locale; // 'de' | 'en'
  final Set<String> visibleAreas;
  final UserGoals? goals;

  factory AppSettings.fromJson(Map<String, dynamic> json) => AppSettings(
        locale: json['locale'] as String? ?? 'de',
        visibleAreas: (json['visibleAreas'] as List<dynamic>?)
                ?.cast<String>()
                .toSet() ??
            {'nutrition', 'cycle', 'weight', 'overview'},
        goals: json['goals'] == null
            ? null
            : UserGoals.fromJson(Map<String, dynamic>.from(json['goals'])),
      );

  Map<String, dynamic> toJson() => <String, dynamic>{
        'locale': locale,
        'visibleAreas': visibleAreas.toList(),
        'goals': goals?.toJson(),
      };
}

/// Gesamter, serialisierbarer Datenbestand.
class HealthData {
  HealthData({
    List<LocalFood>? localFoods,
    List<OffProduct>? cachedProducts,
    List<NutritionEntry>? nutritionEntries,
    List<WaterEntry>? waterEntries,
    List<CaffeineEntry>? caffeineEntries,
    List<CycleEntry>? cycleEntries,
    List<SymptomEntry>? symptomEntries,
    List<WeightEntry>? weightEntries,
    this.goals = const UserGoals(),
    this.settings = const AppSettings(),
    this.format = 'morphhealth.v1',
    this.createdAt,
  })  : localFoods = localFoods ?? <LocalFood>[],
        cachedProducts = cachedProducts ?? <OffProduct>[],
        nutritionEntries = nutritionEntries ?? <NutritionEntry>[],
        waterEntries = waterEntries ?? <WaterEntry>[],
        caffeineEntries = caffeineEntries ?? <CaffeineEntry>[],
        cycleEntries = cycleEntries ?? <CycleEntry>[],
        symptomEntries = symptomEntries ?? <SymptomEntry>[],
        weightEntries = weightEntries ?? <WeightEntry>[];

  final String format;
  final DateTime? createdAt;
  final List<LocalFood> localFoods;
  final List<OffProduct> cachedProducts;
  final List<NutritionEntry> nutritionEntries;
  final List<WaterEntry> waterEntries;
  final List<CaffeineEntry> caffeineEntries;
  final List<CycleEntry> cycleEntries;
  final List<SymptomEntry> symptomEntries;
  final List<WeightEntry> weightEntries;
  UserGoals goals;
  AppSettings settings;

  Map<String, dynamic> toJson() => <String, dynamic>{
        'format': format,
        'createdAt': createdAt?.toIso8601String(),
        'localFoods': localFoods.map((e) => e.toJson()).toList(),
        'cachedProducts': cachedProducts.map((e) => e.toJson()).toList(),
        'nutritionEntries': nutritionEntries.map((e) => e.toJson()).toList(),
        'waterEntries': waterEntries.map((e) => e.toJson()).toList(),
        'caffeineEntries': caffeineEntries.map((e) => e.toJson()).toList(),
        'cycleEntries': cycleEntries.map((e) => e.toJson()).toList(),
        'symptomEntries': symptomEntries.map((e) => e.toJson()).toList(),
        'weightEntries': weightEntries.map((e) => e.toJson()).toList(),
        'goals': goals.toJson(),
        'settings': settings.toJson(),
      };

  factory HealthData.fromJson(Map<String, dynamic> json) => HealthData(
        format: json['format'] as String? ?? 'morphhealth.v1',
        createdAt: json['createdAt'] == null
            ? null
            : DateTime.parse(json['createdAt'] as String),
        localFoods: (json['localFoods'] as List<dynamic>?)
                ?.cast<Map<String, dynamic>>()
                .map(LocalFood.fromJson)
                .toList() ??
            [],
        cachedProducts: (json['cachedProducts'] as List<dynamic>?)
                ?.cast<Map<String, dynamic>>()
                .map(OffProduct.fromJson)
                .toList() ??
            [],
        nutritionEntries: (json['nutritionEntries'] as List<dynamic>?)
                ?.cast<Map<String, dynamic>>()
                .map(NutritionEntry.fromJson)
                .toList() ??
            [],
        waterEntries: (json['waterEntries'] as List<dynamic>?)
                ?.cast<Map<String, dynamic>>()
                .map(WaterEntry.fromJson)
                .toList() ??
            [],
        caffeineEntries: (json['caffeineEntries'] as List<dynamic>?)
                ?.cast<Map<String, dynamic>>()
                .map(CaffeineEntry.fromJson)
                .toList() ??
            [],
        cycleEntries: (json['cycleEntries'] as List<dynamic>?)
                ?.cast<Map<String, dynamic>>()
                .map(CycleEntry.fromJson)
                .toList() ??
            [],
        symptomEntries: (json['symptomEntries'] as List<dynamic>?)
                ?.cast<Map<String, dynamic>>()
                .map(SymptomEntry.fromJson)
                .toList() ??
            [],
        weightEntries: (json['weightEntries'] as List<dynamic>?)
                ?.cast<Map<String, dynamic>>()
                .map(WeightEntry.fromJson)
                .toList() ??
            [],
        goals: json['goals'] == null
            ? const UserGoals()
            : UserGoals.fromJson(Map<String, dynamic>.from(json['goals'])),
        settings: json['settings'] == null
            ? const AppSettings()
            : AppSettings.fromJson(Map<String, dynamic>.from(json['settings'])),
      );
}

/// Zufällige UUID (v4-ähnlich).
String uuid() {
  final secure = math.Random.secure();
  final values = List<int>.generate(16, (_) => secure.nextInt(256));
  return [
    _hex(values.sublist(0, 4)),
    _hex(values.sublist(4, 6)),
    _hex(values.sublist(6, 8)),
    _hex(values.sublist(8, 10)),
    _hex(values.sublist(10, 16)),
  ].join('-');
}

String _hex(List<int> bytes) =>
    bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();