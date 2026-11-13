/// Core domain models for MorphHealth across Nutrition, Cycle, Weight, and Symptoms.
library;

import 'dart:math';

import 'clock.dart';
import 'nutrients.dart';

const double kPoundsToKg = 0.45359237;

String generateEntityId(String prefix) {
  final rng = Random.secure();
  final bytes = List<int>.generate(12, (_) => rng.nextInt(256));
  final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${prefix}_$hex';
}

enum AppModule {
  nutrition('nutrition', 'Ernährung', 'Nutrition'),
  cycle('cycle', 'Zyklus', 'Cycle'),
  weight('weight', 'Gewicht', 'Weight'),
  symptoms('symptoms', 'Symptome', 'Symptoms');

  final String jsonKey;
  final String labelDe;
  final String labelEn;

  const AppModule(this.jsonKey, this.labelDe, this.labelEn);

  String label(String locale) => locale == 'en' ? labelEn : labelDe;

  static AppModule? fromJson(String? raw) {
    for (final m in AppModule.values) {
      if (m.jsonKey == raw) return m;
    }
    return null;
  }
}

enum MealType {
  breakfast('breakfast', 'Frühstück', 'Breakfast'),
  lunch('lunch', 'Mittagessen', 'Lunch'),
  dinner('dinner', 'Abendessen', 'Dinner'),
  snack('snack', 'Snack', 'Snack');

  final String jsonKey;
  final String labelDe;
  final String labelEn;

  const MealType(this.jsonKey, this.labelDe, this.labelEn);

  String label(String locale) => locale == 'en' ? labelEn : labelDe;

  static MealType fromJson(String raw) {
    for (final m in MealType.values) {
      if (m.jsonKey == raw) return m;
    }
    throw FormatValidationException('Invalid meal_type "$raw".');
  }
}

enum AmountUnit {
  g('g', 'g', 'g'),
  ml('ml', 'ml', 'ml'),
  portion('portion', 'Portion', 'Portion');

  final String jsonKey;
  final String labelDe;
  final String labelEn;

  const AmountUnit(this.jsonKey, this.labelDe, this.labelEn);

  String label(String locale) => locale == 'en' ? labelEn : labelDe;

  static AmountUnit fromJson(String raw) {
    for (final u in AmountUnit.values) {
      if (u.jsonKey == raw) return u;
    }
    throw FormatValidationException('Invalid unit "$raw". Expected g, ml, or portion.');
  }
}

enum FoodSource {
  custom('custom'),
  openFoodFacts('open_food_facts');

  final String jsonKey;
  const FoodSource(this.jsonKey);

  static FoodSource fromJson(String raw) {
    for (final s in FoodSource.values) {
      if (s.jsonKey == raw) return s;
    }
    throw FormatValidationException('Invalid food source "$raw".');
  }
}

class FoodItem {
  final String id;
  final FoodSource source;
  final String? barcode;
  final String name;
  final String? nameDe;
  final String? nameEn;
  final String? brand;
  final String nutritionBasis; // '100g' or '100ml'
  final double servingQuantity; // g or ml per 1 portion
  final String? servingLabel;
  final NutrientProfile nutrientsPer100;
  final bool isFavorite;
  final String createdAt;
  final String updatedAt;

  const FoodItem({
    required this.id,
    required this.source,
    this.barcode,
    required this.name,
    this.nameDe,
    this.nameEn,
    this.brand,
    this.nutritionBasis = '100g',
    this.servingQuantity = 100.0,
    this.servingLabel,
    required this.nutrientsPer100,
    this.isFavorite = false,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isCustom => source == FoodSource.custom;

  String localizedName(String locale) {
    if (locale == 'de' && nameDe != null && nameDe!.trim().isNotEmpty) {
      return nameDe!.trim();
    }
    if (locale == 'en' && nameEn != null && nameEn!.trim().isNotEmpty) {
      return nameEn!.trim();
    }
    return name;
  }

  double computeGramsOrMlEquivalent(double amount, AmountUnit unit) {
    switch (unit) {
      case AmountUnit.g:
      case AmountUnit.ml:
        return amount;
      case AmountUnit.portion:
        final perPortion = servingQuantity > 0 ? servingQuantity : 100.0;
        return amount * perPortion;
    }
  }

  NutrientProfile computeNutrientsFor(double amount, AmountUnit unit) {
    final eq = computeGramsOrMlEquivalent(amount, unit);
    return nutrientsPer100.scale(eq / 100.0);
  }

  FoodItem copyWith({
    String? id,
    FoodSource? source,
    String? barcode,
    bool clearBarcode = false,
    String? name,
    String? nameDe,
    String? nameEn,
    String? brand,
    bool clearBrand = false,
    String? nutritionBasis,
    double? servingQuantity,
    String? servingLabel,
    bool clearServingLabel = false,
    NutrientProfile? nutrientsPer100,
    bool? isFavorite,
    String? createdAt,
    String? updatedAt,
  }) {
    return FoodItem(
      id: id ?? this.id,
      source: source ?? this.source,
      barcode: clearBarcode ? null : (barcode ?? this.barcode),
      name: name ?? this.name,
      nameDe: nameDe ?? this.nameDe,
      nameEn: nameEn ?? this.nameEn,
      brand: clearBrand ? null : (brand ?? this.brand),
      nutritionBasis: nutritionBasis ?? this.nutritionBasis,
      servingQuantity: servingQuantity ?? this.servingQuantity,
      servingLabel: clearServingLabel ? null : (servingLabel ?? this.servingLabel),
      nutrientsPer100: nutrientsPer100 ?? this.nutrientsPer100,
      isFavorite: isFavorite ?? this.isFavorite,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'source': source.jsonKey,
        if (barcode != null && barcode!.isNotEmpty) 'barcode': barcode,
        'name': name,
        if (nameDe != null && nameDe!.isNotEmpty) 'name_de': nameDe,
        if (nameEn != null && nameEn!.isNotEmpty) 'name_en': nameEn,
        if (brand != null && brand!.isNotEmpty) 'brand': brand,
        'nutrition_basis': nutritionBasis,
        'serving_quantity': servingQuantity,
        if (servingLabel != null && servingLabel!.isNotEmpty)
          'serving_label': servingLabel,
        'nutrients_per_100': nutrientsPer100.toSparseJson(),
        'is_favorite': isFavorite,
        'created_at': createdAt,
        'updated_at': updatedAt,
      };

  factory FoodItem.fromJson(Map<String, dynamic> json) {
    final id = (json['id'] as String?)?.trim() ?? '';
    final name = (json['name'] as String?)?.trim() ?? '';
    if (id.isEmpty || name.isEmpty) {
      throw const FormatValidationException('FoodItem requires non-empty id and name.');
    }
    final source = FoodSource.fromJson(
      (json['source'] as String?) ?? FoodSource.custom.jsonKey,
    );
    final basis = (json['nutrition_basis'] as String?) == '100ml' ? '100ml' : '100g';
    final servingQtyRaw = json['serving_quantity'];
    final servingQty = servingQtyRaw is num && servingQtyRaw > 0
        ? servingQtyRaw.toDouble()
        : 100.0;
    final createdAt = (json['created_at'] as String?) ?? '2026-01-01T00:00:00Z';
    final updatedAt = (json['updated_at'] as String?) ?? createdAt;
    final nutrRaw = json['nutrients_per_100'];
    if (nutrRaw != null && nutrRaw is! Map<String, dynamic>) {
      throw const FormatValidationException('FoodItem.nutrients_per_100 must be an object.');
    }
    return FoodItem(
      id: id,
      source: source,
      barcode: (json['barcode'] as String?)?.trim(),
      name: name,
      nameDe: (json['name_de'] as String?)?.trim(),
      nameEn: (json['name_en'] as String?)?.trim(),
      brand: (json['brand'] as String?)?.trim(),
      nutritionBasis: basis,
      servingQuantity: servingQty,
      servingLabel: (json['serving_label'] as String?)?.trim(),
      nutrientsPer100: NutrientProfile.fromJson(nutrRaw as Map<String, dynamic>?),
      isFavorite: json['is_favorite'] == true,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

class FoodDiaryEntry {
  final String id;
  final String date; // YYYY-MM-DD
  final String recordedAt; // RFC3339
  final MealType mealType;
  final String foodId;
  final String foodNameSnapshot;
  final String? brandSnapshot;
  final double amount;
  final AmountUnit unit;
  final double servingQuantitySnapshot;
  final NutrientProfile nutrientsPer100Snapshot;
  final String? note;

  const FoodDiaryEntry({
    required this.id,
    required this.date,
    required this.recordedAt,
    required this.mealType,
    required this.foodId,
    required this.foodNameSnapshot,
    this.brandSnapshot,
    required this.amount,
    required this.unit,
    this.servingQuantitySnapshot = 100.0,
    this.nutrientsPer100Snapshot = NutrientProfile.empty,
    this.note,
  });

  double effectiveServingQuantity(FoodItem? liveFood) {
    final candidate = liveFood?.servingQuantity ?? servingQuantitySnapshot;
    return candidate > 0 ? candidate : 100.0;
  }

  double gramsOrMlEquivalent([FoodItem? liveFood]) {
    switch (unit) {
      case AmountUnit.g:
      case AmountUnit.ml:
        return amount;
      case AmountUnit.portion:
        return amount * effectiveServingQuantity(liveFood);
    }
  }

  NutrientProfile computeNutrients([FoodItem? liveFood]) {
    final baseProfile = liveFood?.nutrientsPer100 ?? nutrientsPer100Snapshot;
    final eq = gramsOrMlEquivalent(liveFood);
    return baseProfile.scale(eq / 100.0);
  }

  String displayName(FoodItem? liveFood, String locale) =>
      liveFood?.localizedName(locale) ?? foodNameSnapshot;

  String? displayBrand(FoodItem? liveFood) => liveFood?.brand ?? brandSnapshot;

  FoodDiaryEntry copyWith({
    String? id,
    String? date,
    String? recordedAt,
    MealType? mealType,
    String? foodId,
    String? foodNameSnapshot,
    String? brandSnapshot,
    double? amount,
    AmountUnit? unit,
    double? servingQuantitySnapshot,
    NutrientProfile? nutrientsPer100Snapshot,
    String? note,
    bool clearNote = false,
  }) {
    return FoodDiaryEntry(
      id: id ?? this.id,
      date: date ?? this.date,
      recordedAt: recordedAt ?? this.recordedAt,
      mealType: mealType ?? this.mealType,
      foodId: foodId ?? this.foodId,
      foodNameSnapshot: foodNameSnapshot ?? this.foodNameSnapshot,
      brandSnapshot: brandSnapshot ?? this.brandSnapshot,
      amount: amount ?? this.amount,
      unit: unit ?? this.unit,
      servingQuantitySnapshot:
          servingQuantitySnapshot ?? this.servingQuantitySnapshot,
      nutrientsPer100Snapshot:
          nutrientsPer100Snapshot ?? this.nutrientsPer100Snapshot,
      note: clearNote ? null : (note ?? this.note),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date,
        'recorded_at': recordedAt,
        'meal_type': mealType.jsonKey,
        'food_id': foodId,
        'food_name_snapshot': foodNameSnapshot,
        if (brandSnapshot != null && brandSnapshot!.isNotEmpty)
          'brand_snapshot': brandSnapshot,
        'amount': amount,
        'unit': unit.jsonKey,
        'serving_quantity_snapshot': servingQuantitySnapshot,
        'nutrients_per_100_snapshot': nutrientsPer100Snapshot.toSparseJson(),
        if (note != null && note!.isNotEmpty) 'note': note,
      };

  factory FoodDiaryEntry.fromJson(Map<String, dynamic> json) {
    final id = (json['id'] as String?)?.trim() ?? '';
    final date = (json['date'] as String?)?.trim() ?? '';
    if (id.isEmpty || !IsoDate.isValid(date)) {
      throw FormatValidationException('Invalid FoodDiaryEntry id/date: "$id" / "$date".');
    }
    final amountRaw = json['amount'];
    if (amountRaw is! num || amountRaw <= 0 || !amountRaw.toDouble().isFinite) {
      throw const FormatValidationException('FoodDiaryEntry.amount must be > 0.');
    }
    final recordedAt =
        (json['recorded_at'] as String?) ?? '${date}T12:00:00Z';
    Rfc3339.parseStrict(recordedAt);
    final foodId = (json['food_id'] as String?)?.trim() ?? '';
    final snapName = (json['food_name_snapshot'] as String?)?.trim() ?? '';
    if (foodId.isEmpty || snapName.isEmpty) {
      throw const FormatValidationException(
        'FoodDiaryEntry requires food_id and food_name_snapshot.',
      );
    }
    final servingSnap = json['serving_quantity_snapshot'];
    return FoodDiaryEntry(
      id: id,
      date: date,
      recordedAt: recordedAt,
      mealType: MealType.fromJson((json['meal_type'] as String?) ?? ''),
      foodId: foodId,
      foodNameSnapshot: snapName,
      brandSnapshot: (json['brand_snapshot'] as String?)?.trim(),
      amount: amountRaw.toDouble(),
      unit: AmountUnit.fromJson((json['unit'] as String?) ?? ''),
      servingQuantitySnapshot:
          servingSnap is num && servingSnap > 0 ? servingSnap.toDouble() : 100.0,
      nutrientsPer100Snapshot: NutrientProfile.fromJson(
        json['nutrients_per_100_snapshot'] as Map<String, dynamic>?,
      ),
      note: (json['note'] as String?)?.trim(),
    );
  }
}

class WaterEntry {
  final String id;
  final String date;
  final String recordedAt;
  final double amountMl;
  final String? note;

  const WaterEntry({
    required this.id,
    required this.date,
    required this.recordedAt,
    required this.amountMl,
    this.note,
  });

  WaterEntry copyWith({
    String? date,
    String? recordedAt,
    double? amountMl,
    String? note,
    bool clearNote = false,
  }) {
    return WaterEntry(
      id: id,
      date: date ?? this.date,
      recordedAt: recordedAt ?? this.recordedAt,
      amountMl: amountMl ?? this.amountMl,
      note: clearNote ? null : (note ?? this.note),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date,
        'recorded_at': recordedAt,
        'amount_ml': amountMl,
        if (note != null && note!.isNotEmpty) 'note': note,
      };

  factory WaterEntry.fromJson(Map<String, dynamic> json) {
    final id = (json['id'] as String?)?.trim() ?? '';
    final date = (json['date'] as String?)?.trim() ?? '';
    if (id.isEmpty || !IsoDate.isValid(date)) {
      throw FormatValidationException('Invalid WaterEntry id/date: "$id" / "$date".');
    }
    final ml = json['amount_ml'];
    if (ml is! num || ml <= 0 || !ml.toDouble().isFinite) {
      throw const FormatValidationException('WaterEntry.amount_ml must be > 0.');
    }
    final recordedAt = (json['recorded_at'] as String?) ?? '${date}T12:00:00Z';
    Rfc3339.parseStrict(recordedAt);
    return WaterEntry(
      id: id,
      date: date,
      recordedAt: recordedAt,
      amountMl: ml.toDouble(),
      note: (json['note'] as String?)?.trim(),
    );
  }
}

class CaffeineEntry {
  final String id;
  final String date;
  final String recordedAt;
  final double amountMg;
  final String? sourceLabel;
  final String? note;

  const CaffeineEntry({
    required this.id,
    required this.date,
    required this.recordedAt,
    required this.amountMg,
    this.sourceLabel,
    this.note,
  });

  CaffeineEntry copyWith({
    String? date,
    String? recordedAt,
    double? amountMg,
    String? sourceLabel,
    bool clearSource = false,
    String? note,
    bool clearNote = false,
  }) {
    return CaffeineEntry(
      id: id,
      date: date ?? this.date,
      recordedAt: recordedAt ?? this.recordedAt,
      amountMg: amountMg ?? this.amountMg,
      sourceLabel: clearSource ? null : (sourceLabel ?? this.sourceLabel),
      note: clearNote ? null : (note ?? this.note),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date,
        'recorded_at': recordedAt,
        'amount_mg': amountMg,
        if (sourceLabel != null && sourceLabel!.isNotEmpty)
          'source_label': sourceLabel,
        if (note != null && note!.isNotEmpty) 'note': note,
      };

  factory CaffeineEntry.fromJson(Map<String, dynamic> json) {
    final id = (json['id'] as String?)?.trim() ?? '';
    final date = (json['date'] as String?)?.trim() ?? '';
    if (id.isEmpty || !IsoDate.isValid(date)) {
      throw FormatValidationException('Invalid CaffeineEntry id/date: "$id" / "$date".');
    }
    final mg = json['amount_mg'];
    if (mg is! num || mg <= 0 || !mg.toDouble().isFinite) {
      throw const FormatValidationException('CaffeineEntry.amount_mg must be > 0.');
    }
    final recordedAt = (json['recorded_at'] as String?) ?? '${date}T12:00:00Z';
    Rfc3339.parseStrict(recordedAt);
    return CaffeineEntry(
      id: id,
      date: date,
      recordedAt: recordedAt,
      amountMg: mg.toDouble(),
      sourceLabel: (json['source_label'] as String?)?.trim(),
      note: (json['note'] as String?)?.trim(),
    );
  }
}

enum FlowIntensity {
  spotting('spotting', 'Spotting (Schmierblutung)', 'Spotting', 1),
  light('light', 'Leicht', 'Light', 2),
  medium('medium', 'Mittel', 'Medium', 3),
  heavy('heavy', 'Stark', 'Heavy', 4);

  final String jsonKey;
  final String labelDe;
  final String labelEn;
  final int level;

  const FlowIntensity(this.jsonKey, this.labelDe, this.labelEn, this.level);

  String label(String locale) => locale == 'en' ? labelEn : labelDe;

  static FlowIntensity fromJson(String raw) {
    for (final f in FlowIntensity.values) {
      if (f.jsonKey == raw) return f;
    }
    throw FormatValidationException('Invalid flow intensity "$raw".');
  }
}

class PeriodEntry {
  final String id;
  final String startDate; // YYYY-MM-DD
  final String? endDate; // YYYY-MM-DD or null if ongoing
  final FlowIntensity intensity;
  final Map<String, FlowIntensity> dailyFlows;
  final bool countsAsPeriod; // false if standalone intermenstrual spotting
  final String? note;

  const PeriodEntry({
    required this.id,
    required this.startDate,
    this.endDate,
    required this.intensity,
    this.dailyFlows = const {},
    this.countsAsPeriod = true,
    this.note,
  });

  bool get isOngoing => endDate == null;

  int? get completedDurationDays =>
      endDate == null ? null : IsoDate.daysBetween(startDate, endDate!) + 1;

  bool coversDate(String dateIso, {String? referenceTodayIso}) {
    if (IsoDate.daysBetween(startDate, dateIso) < 0) return false;
    if (endDate != null) {
      return IsoDate.daysBetween(dateIso, endDate!) >= 0;
    }
    // Ongoing period: active from startDate up to min(referenceTodayIso, startDate + 13 days)
    final capEnd = referenceTodayIso != null &&
            IsoDate.daysBetween(startDate, referenceTodayIso) >= 0 &&
            IsoDate.daysBetween(startDate, referenceTodayIso) <= 13
        ? referenceTodayIso
        : startDate;
    return IsoDate.daysBetween(dateIso, capEnd) >= 0;
  }

  FlowIntensity intensityForDate(String dateIso) =>
      dailyFlows[dateIso] ?? intensity;

  PeriodEntry copyWith({
    String? startDate,
    String? endDate,
    bool clearEndDate = false,
    FlowIntensity? intensity,
    Map<String, FlowIntensity>? dailyFlows,
    bool? countsAsPeriod,
    String? note,
    bool clearNote = false,
  }) {
    return PeriodEntry(
      id: id,
      startDate: startDate ?? this.startDate,
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
      intensity: intensity ?? this.intensity,
      dailyFlows: dailyFlows ?? this.dailyFlows,
      countsAsPeriod: countsAsPeriod ?? this.countsAsPeriod,
      note: clearNote ? null : (note ?? this.note),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'start_date': startDate,
        'end_date': endDate,
        'intensity': intensity.jsonKey,
        if (dailyFlows.isNotEmpty)
          'daily_flows': {
            for (final e in dailyFlows.entries) e.key: e.value.jsonKey,
          },
        'counts_as_period': countsAsPeriod,
        if (note != null && note!.isNotEmpty) 'note': note,
      };

  factory PeriodEntry.fromJson(Map<String, dynamic> json) {
    final id = (json['id'] as String?)?.trim() ?? '';
    final start = (json['start_date'] as String?)?.trim() ?? '';
    if (id.isEmpty || !IsoDate.isValid(start)) {
      throw FormatValidationException('Invalid PeriodEntry id/start_date: "$id" / "$start".');
    }
    final endRaw = (json['end_date'] as String?)?.trim();
    String? end;
    if (endRaw != null && endRaw.isNotEmpty) {
      if (!IsoDate.isValid(endRaw)) {
        throw FormatValidationException('Invalid PeriodEntry.end_date: "$endRaw".');
      }
      if (IsoDate.daysBetween(start, endRaw) < 0) {
        throw const FormatValidationException(
          'PeriodEntry.end_date cannot be before start_date.',
        );
      }
      end = endRaw;
    }
    final flows = <String, FlowIntensity>{};
    final flowsRaw = json['daily_flows'];
    if (flowsRaw is Map) {
      flowsRaw.forEach((k, v) {
        if (k is String && IsoDate.isValid(k) && v is String) {
          flows[k] = FlowIntensity.fromJson(v);
        }
      });
    }
    return PeriodEntry(
      id: id,
      startDate: start,
      endDate: end,
      intensity: FlowIntensity.fromJson(
        (json['intensity'] as String?) ?? FlowIntensity.medium.jsonKey,
      ),
      dailyFlows: flows,
      countsAsPeriod: json['counts_as_period'] != false,
      note: (json['note'] as String?)?.trim(),
    );
  }
}

enum WeightUnit {
  kg('kg'),
  lb('lb');

  final String jsonKey;
  const WeightUnit(this.jsonKey);

  static WeightUnit fromJson(String raw) {
    if (raw == 'lb') return WeightUnit.lb;
    if (raw == 'kg') return WeightUnit.kg;
    throw FormatValidationException('Invalid weight unit "$raw". Expected kg or lb.');
  }
}

class WeightEntry {
  final String id;
  final String date; // YYYY-MM-DD
  final String recordedAt; // RFC3339
  final double weightKg;
  final WeightUnit inputUnit;
  final double inputValue;
  final String? note;

  const WeightEntry({
    required this.id,
    required this.date,
    required this.recordedAt,
    required this.weightKg,
    required this.inputUnit,
    required this.inputValue,
    this.note,
  });

  factory WeightEntry.fromInput({
    required String id,
    required String date,
    required String recordedAt,
    required double value,
    required WeightUnit unit,
    String? note,
  }) {
    if (value <= 0 || !value.isFinite) {
      throw const FormatValidationException('Weight value must be > 0.');
    }
    final kg = unit == WeightUnit.kg ? value : value * kPoundsToKg;
    return WeightEntry(
      id: id,
      date: date,
      recordedAt: recordedAt,
      weightKg: (kg * 10000).roundToDouble() / 10000.0,
      inputUnit: unit,
      inputValue: (value * 100).roundToDouble() / 100.0,
      note: note,
    );
  }

  double valueIn(WeightUnit targetUnit) {
    if (targetUnit == inputUnit) return inputValue;
    if (targetUnit == WeightUnit.kg) return weightKg;
    return weightKg / kPoundsToKg;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date,
        'recorded_at': recordedAt,
        'weight_kg': weightKg,
        'input_unit': inputUnit.jsonKey,
        'input_value': inputValue,
        if (note != null && note!.isNotEmpty) 'note': note,
      };

  factory WeightEntry.fromJson(Map<String, dynamic> json) {
    final id = (json['id'] as String?)?.trim() ?? '';
    final date = (json['date'] as String?)?.trim() ?? '';
    if (id.isEmpty || !IsoDate.isValid(date)) {
      throw FormatValidationException('Invalid WeightEntry id/date: "$id" / "$date".');
    }
    final kgRaw = json['weight_kg'];
    if (kgRaw is! num || kgRaw <= 0 || !kgRaw.toDouble().isFinite) {
      throw const FormatValidationException('WeightEntry.weight_kg must be > 0.');
    }
    final recordedAt = (json['recorded_at'] as String?) ?? '${date}T08:00:00Z';
    Rfc3339.parseStrict(recordedAt);
    final unit = WeightUnit.fromJson((json['input_unit'] as String?) ?? 'kg');
    final inputRaw = json['input_value'];
    final kg = kgRaw.toDouble();
    final inputVal = inputRaw is num && inputRaw > 0
        ? inputRaw.toDouble()
        : (unit == WeightUnit.kg ? kg : kg / kPoundsToKg);
    return WeightEntry(
      id: id,
      date: date,
      recordedAt: recordedAt,
      weightKg: kg,
      inputUnit: unit,
      inputValue: inputVal,
      note: (json['note'] as String?)?.trim(),
    );
  }
}

class SymptomEntry {
  final String id;
  final String date; // YYYY-MM-DD
  final String recordedAt; // RFC3339
  final String name;
  final int intensity; // 0..10
  final String? note;

  const SymptomEntry({
    required this.id,
    required this.date,
    required this.recordedAt,
    required this.name,
    required this.intensity,
    this.note,
  });

  SymptomEntry copyWith({
    String? date,
    String? recordedAt,
    String? name,
    int? intensity,
    String? note,
    bool clearNote = false,
  }) {
    return SymptomEntry(
      id: id,
      date: date ?? this.date,
      recordedAt: recordedAt ?? this.recordedAt,
      name: name ?? this.name,
      intensity: intensity ?? this.intensity,
      note: clearNote ? null : (note ?? this.note),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date,
        'recorded_at': recordedAt,
        'name': name,
        'intensity': intensity,
        if (note != null && note!.isNotEmpty) 'note': note,
      };

  factory SymptomEntry.fromJson(Map<String, dynamic> json) {
    final id = (json['id'] as String?)?.trim() ?? '';
    final date = (json['date'] as String?)?.trim() ?? '';
    final name = (json['name'] as String?)?.trim() ?? '';
    if (id.isEmpty || !IsoDate.isValid(date) || name.isEmpty) {
      throw const FormatValidationException(
        'SymptomEntry requires valid id, date, and non-empty name.',
      );
    }
    final intensityRaw = json['intensity'];
    if (intensityRaw is! int || intensityRaw < 0 || intensityRaw > 10) {
      throw const FormatValidationException(
        'SymptomEntry.intensity must be an integer between 0 and 10.',
      );
    }
    final recordedAt = (json['recorded_at'] as String?) ?? '${date}T12:00:00Z';
    Rfc3339.parseStrict(recordedAt);
    return SymptomEntry(
      id: id,
      date: date,
      recordedAt: recordedAt,
      name: name,
      intensity: intensityRaw,
      note: (json['note'] as String?)?.trim(),
    );
  }
}

class NutritionGoals {
  final double? waterMl;
  final double? caloriesKcal;
  final double? proteinG;
  final double? carbsG;
  final double? fatG;

  const NutritionGoals({
    this.waterMl,
    this.caloriesKcal,
    this.proteinG,
    this.carbsG,
    this.fatG,
  });

  bool get hasAnyGoal =>
      waterMl != null ||
      caloriesKcal != null ||
      proteinG != null ||
      carbsG != null ||
      fatG != null;

  Map<String, dynamic> toJson() => {
        'water_ml': waterMl,
        'calories_kcal': caloriesKcal,
        'protein_g': proteinG,
        'carbs_g': carbsG,
        'fat_g': fatG,
      };

  factory NutritionGoals.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const NutritionGoals();
    double? parseOpt(String k) {
      final v = json[k];
      if (v == null) return null;
      if (v is num && v > 0 && v.toDouble().isFinite) return v.toDouble();
      throw FormatValidationException('Goal "$k" must be null or > 0.');
    }

    return NutritionGoals(
      waterMl: parseOpt('water_ml'),
      caloriesKcal: parseOpt('calories_kcal'),
      proteinG: parseOpt('protein_g'),
      carbsG: parseOpt('carbs_g'),
      fatG: parseOpt('fat_g'),
    );
  }
}

class UserPreferences {
  final String localeCode; // 'de' or 'en'
  final WeightUnit weightUnit;
  final List<AppModule> visibleOverviewModules;
  final bool cycleDiaryOnlyMode;
  final bool onlineFoodEnabled;
  final String? customFoodApiBaseUrl;
  final List<int> waterQuickAmountsMl;

  const UserPreferences({
    this.localeCode = 'de',
    this.weightUnit = WeightUnit.kg,
    this.visibleOverviewModules = const [
      AppModule.nutrition,
      AppModule.cycle,
      AppModule.weight,
      AppModule.symptoms,
    ],
    this.cycleDiaryOnlyMode = false,
    this.onlineFoodEnabled = true,
    this.customFoodApiBaseUrl,
    this.waterQuickAmountsMl = const [150, 250, 330, 500],
  });

  UserPreferences copyWith({
    String? localeCode,
    WeightUnit? weightUnit,
    List<AppModule>? visibleOverviewModules,
    bool? cycleDiaryOnlyMode,
    bool? onlineFoodEnabled,
    String? customFoodApiBaseUrl,
    bool clearCustomFoodApiBaseUrl = false,
    List<int>? waterQuickAmountsMl,
  }) {
    return UserPreferences(
      localeCode: localeCode ?? this.localeCode,
      weightUnit: weightUnit ?? this.weightUnit,
      visibleOverviewModules:
          visibleOverviewModules ?? this.visibleOverviewModules,
      cycleDiaryOnlyMode: cycleDiaryOnlyMode ?? this.cycleDiaryOnlyMode,
      onlineFoodEnabled: onlineFoodEnabled ?? this.onlineFoodEnabled,
      customFoodApiBaseUrl: clearCustomFoodApiBaseUrl
          ? null
          : (customFoodApiBaseUrl ?? this.customFoodApiBaseUrl),
      waterQuickAmountsMl: waterQuickAmountsMl ?? this.waterQuickAmountsMl,
    );
  }

  Map<String, dynamic> toJson() => {
        'locale_code': localeCode,
        'weight_unit': weightUnit.jsonKey,
        'visible_overview_modules':
            visibleOverviewModules.map((m) => m.jsonKey).toList(),
        'cycle_diary_only_mode': cycleDiaryOnlyMode,
        'online_food_enabled': onlineFoodEnabled,
        if (customFoodApiBaseUrl != null && customFoodApiBaseUrl!.isNotEmpty)
          'custom_food_api_base_url': customFoodApiBaseUrl,
        'water_quick_amounts_ml': waterQuickAmountsMl,
      };

  factory UserPreferences.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const UserPreferences();
    final locale = json['locale_code'] == 'en' ? 'en' : 'de';
    final unit = WeightUnit.fromJson((json['weight_unit'] as String?) ?? 'kg');
    final visRaw = json['visible_overview_modules'];
    List<AppModule> visible = AppModule.values;
    if (visRaw is List) {
      visible = visRaw
          .whereType<String>()
          .map(AppModule.fromJson)
          .whereType<AppModule>()
          .toSet()
          .toList();
    }
    final quickRaw = json['water_quick_amounts_ml'];
    List<int> quick = const [150, 250, 330, 500];
    if (quickRaw is List) {
      final parsed = quickRaw
          .whereType<num>()
          .map((n) => n.round())
          .where((n) => n > 0 && n <= 5000)
          .toList();
      if (parsed.isNotEmpty) quick = parsed;
    }
    return UserPreferences(
      localeCode: locale,
      weightUnit: unit,
      visibleOverviewModules: visible,
      cycleDiaryOnlyMode: json['cycle_diary_only_mode'] == true,
      onlineFoodEnabled: json['online_food_enabled'] != false,
      customFoodApiBaseUrl: (json['custom_food_api_base_url'] as String?)?.trim(),
      waterQuickAmountsMl: quick,
    );
  }
}
