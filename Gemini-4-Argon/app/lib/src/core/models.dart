import 'nutrients.dart';

class MealType {
  static const String breakfast = 'breakfast';
  static const String lunch = 'lunch';
  static const String dinner = 'dinner';
  static const String snack = 'snack';

  static const List<String> all = [breakfast, lunch, dinner, snack];

  static String normalize(String? raw) {
    final s = (raw ?? '').trim().toLowerCase();
    if (all.contains(s)) return s;
    if (s == 'frühstück' || s == 'fruhstuck') return breakfast;
    if (s == 'mittagessen' || s == 'mittag') return lunch;
    if (s == 'abendessen' || s == 'abend') return dinner;
    return snack;
  }

  static String label(String meal, String lang) {
    switch (normalize(meal)) {
      case breakfast:
        return lang == 'en' ? 'Breakfast' : 'Frühstück';
      case lunch:
        return lang == 'en' ? 'Lunch' : 'Mittagessen';
      case dinner:
        return lang == 'en' ? 'Dinner' : 'Abendessen';
      case snack:
      default:
        return 'Snack';
    }
  }
}

class FoodUnit {
  static const String gram = 'g';
  static const String milliliter = 'ml';
  static const String portion = 'portion';

  static const List<String> all = [gram, milliliter, portion];

  static String normalize(String? raw) {
    final s = (raw ?? '').trim().toLowerCase();
    if (s == 'ml' || s == 'milliliter' || s == 'milliliters') return milliliter;
    if (s == 'portion' ||
        s == 'portions' ||
        s == 'serving' ||
        s == 'servings' ||
        s == 'stück' ||
        s == 'stueck') {
      return portion;
    }
    return gram;
  }

  static String label(String unit, String lang) {
    switch (normalize(unit)) {
      case milliliter:
        return 'ml';
      case portion:
        return lang == 'en' ? 'Portion' : 'Portion';
      case gram:
      default:
        return 'g';
    }
  }
}

class BleedingIntensity {
  static const String spotting = 'spotting';
  static const String light = 'light';
  static const String medium = 'medium';
  static const String heavy = 'heavy';

  static const List<String> all = [spotting, light, medium, heavy];

  static String normalize(String? raw) {
    final s = (raw ?? '').trim().toLowerCase();
    if (all.contains(s)) return s;
    if (s == 'schmierblutung') return spotting;
    if (s == 'leicht') return light;
    if (s == 'stark') return heavy;
    return medium;
  }

  static String label(String intensity, String lang) {
    switch (normalize(intensity)) {
      case spotting:
        return lang == 'en' ? 'Spotting' : 'Schmierblutung (Spotting)';
      case light:
        return lang == 'en' ? 'Light' : 'Leicht';
      case heavy:
        return lang == 'en' ? 'Heavy' : 'Stark';
      case medium:
      default:
        return lang == 'en' ? 'Medium' : 'Mittel';
    }
  }
}

class FoodItem {
  final String id;
  final String? barcode;
  final String name;
  final String? nameDe;
  final String? nameEn;
  final String? brand;
  final bool isCustom;
  final bool isFavorite;
  final String defaultUnit; // 'g' or 'ml'
  final String? servingSizeLabel;
  final double servingQuantityG; // grams or ml per 1 portion
  final NutrientProfile nutrientsPer100g;
  final String updatedAt;

  const FoodItem({
    required this.id,
    this.barcode,
    required this.name,
    this.nameDe,
    this.nameEn,
    this.brand,
    this.isCustom = false,
    this.isFavorite = false,
    this.defaultUnit = FoodUnit.gram,
    this.servingSizeLabel,
    this.servingQuantityG = 100.0,
    required this.nutrientsPer100g,
    required this.updatedAt,
  });

  String displayName(String lang) {
    if (lang == 'de' && nameDe != null && nameDe!.trim().isNotEmpty) {
      return nameDe!.trim();
    }
    if (lang == 'en' && nameEn != null && nameEn!.trim().isNotEmpty) {
      return nameEn!.trim();
    }
    return name;
  }

  NutrientProfile nutrientsForQuantity(
    double amount,
    String unit, {
    double? customServingQuantityG,
  }) {
    final normUnit = FoodUnit.normalize(unit);
    final effectiveServing = (customServingQuantityG != null &&
            customServingQuantityG > 0)
        ? customServingQuantityG
        : (servingQuantityG > 0 ? servingQuantityG : 100.0);
    final double gramsOrMl =
        normUnit == FoodUnit.portion ? amount * effectiveServing : amount;
    return nutrientsPer100g.scale(gramsOrMl / 100.0);
  }

  FoodItem copyWith({
    String? id,
    String? barcode,
    String? name,
    String? nameDe,
    String? nameEn,
    String? brand,
    bool? isCustom,
    bool? isFavorite,
    String? defaultUnit,
    String? servingSizeLabel,
    double? servingQuantityG,
    NutrientProfile? nutrientsPer100g,
    String? updatedAt,
  }) {
    return FoodItem(
      id: id ?? this.id,
      barcode: barcode ?? this.barcode,
      name: name ?? this.name,
      nameDe: nameDe ?? this.nameDe,
      nameEn: nameEn ?? this.nameEn,
      brand: brand ?? this.brand,
      isCustom: isCustom ?? this.isCustom,
      isFavorite: isFavorite ?? this.isFavorite,
      defaultUnit: defaultUnit ?? this.defaultUnit,
      servingSizeLabel: servingSizeLabel ?? this.servingSizeLabel,
      servingQuantityG: servingQuantityG ?? this.servingQuantityG,
      nutrientsPer100g: nutrientsPer100g ?? this.nutrientsPer100g,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'barcode': barcode,
      'code': barcode,
      'name': name,
      'name_de': nameDe,
      'name_en': nameEn,
      'brand': brand,
      'is_custom': isCustom,
      'is_favorite': isFavorite,
      'default_unit': defaultUnit,
      'serving_size': servingSizeLabel ?? '${servingQuantityG.toStringAsFixed(0)} $defaultUnit',
      'serving_quantity_g': servingQuantityG,
      'nutrients_per_100g': nutrientsPer100g.toJson(),
      'updated_at': updatedAt,
    };
  }

  factory FoodItem.fromJson(Map<String, dynamic> json) {
    final barcode = (json['barcode'] ?? json['code'])?.toString();
    final name = (json['name'] ??
            json['name_de'] ??
            json['name_en'] ??
            json['product_name'] ??
            'Lebensmittel')
        .toString();
    final servingQty = _parseDouble(json['serving_quantity_g'] ??
            json['serving_quantity'] ??
            _extractGramsFromText(json['serving_size']?.toString())) ??
        100.0;
    final rawNutrients = json['nutrients_per_100g'] is Map
        ? Map<String, dynamic>.from(json['nutrients_per_100g'] as Map)
        : (json['nutrients'] is Map
            ? Map<String, dynamic>.from(json['nutrients'] as Map)
            : json);
    return FoodItem(
      id: (json['id'] ?? (barcode != null ? 'off_$barcode' : 'food_${name.hashCode}')).toString(),
      barcode: barcode,
      name: name,
      nameDe: json['name_de']?.toString(),
      nameEn: json['name_en']?.toString(),
      brand: json['brand']?.toString() ?? json['brands']?.toString(),
      isCustom: json['is_custom'] == true,
      isFavorite: json['is_favorite'] == true,
      defaultUnit: FoodUnit.normalize(json['default_unit']?.toString()) == FoodUnit.milliliter
          ? FoodUnit.milliliter
          : FoodUnit.gram,
      servingSizeLabel: json['serving_size']?.toString(),
      servingQuantityG: servingQty > 0 ? servingQty : 100.0,
      nutrientsPer100g: NutrientProfile.fromJson(rawNutrients),
      updatedAt: (json['updated_at'] ?? DateTime.now().toUtc().toIso8601String()).toString(),
    );
  }

  factory FoodItem.fromOpenFoodFactsProduct(
    Map<String, dynamic> p, {
    String? nowIso,
  }) {
    final code = (p['code'] ?? p['_id'] ?? '').toString().trim();
    final nameDe = _nonEmpty(p['product_name_de']) ??
        _nonEmpty(p['product_name_de_imported']) ??
        _nonEmpty(p['generic_name_de']);
    final nameEn = _nonEmpty(p['product_name_en']) ??
        _nonEmpty(p['generic_name_en']);
    final fallbackName = _nonEmpty(p['product_name']) ??
        nameDe ??
        nameEn ??
        _nonEmpty(p['generic_name']) ??
        _nonEmpty(p['abbreviated_product_name']) ??
        (code.isNotEmpty ? 'Produkt $code' : 'Unbekanntes Produkt');
    final primaryName = nameDe ?? fallbackName;
    final brand = _nonEmpty(p['brands']);
    final servingLabel = _nonEmpty(p['serving_size']) ?? _nonEmpty(p['quantity']);
    final servingQty = _parseDouble(p['serving_quantity']) ??
        _extractGramsFromText(servingLabel) ??
        100.0;

    final qtyUnit = (p['product_quantity_unit'] ??
            p['serving_quantity_unit'] ??
            p['nutrition_data_per'] ??
            '')
        .toString()
        .toLowerCase();
    final isLiquid = qtyUnit.contains('ml') ||
        qtyUnit == 'l' ||
        (servingLabel != null &&
            (servingLabel.toLowerCase().contains('ml') ||
                servingLabel.toLowerCase().endsWith(' l')));

    return FoodItem(
      id: code.isNotEmpty ? 'off_$code' : 'off_${primaryName.hashCode}',
      barcode: code.isNotEmpty ? code : null,
      name: primaryName,
      nameDe: nameDe ?? primaryName,
      nameEn: nameEn ?? fallbackName,
      brand: brand,
      isCustom: false,
      isFavorite: false,
      defaultUnit: isLiquid ? FoodUnit.milliliter : FoodUnit.gram,
      servingSizeLabel: servingLabel,
      servingQuantityG: servingQty > 0 ? servingQty : 100.0,
      nutrientsPer100g: NutrientProfile.fromOpenFoodFactsProduct(p),
      updatedAt: nowIso ?? DateTime.now().toUtc().toIso8601String(),
    );
  }

  static String? _nonEmpty(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  static double? _parseDouble(dynamic v) {
    if (v == null) return null;
    if (v is num) return v.toDouble();
    if (v is String) {
      return double.tryParse(v.trim().replaceAll(',', '.'));
    }
    return null;
  }

  static double? _extractGramsFromText(String? text) {
    if (text == null || text.trim().isEmpty) return null;
    final match = RegExp(r'(\d+(?:[.,]\d+)?)\s*(?:g|ml)\b', caseSensitive: false)
        .firstMatch(text);
    if (match != null) {
      return double.tryParse(match.group(1)!.replaceAll(',', '.'));
    }
    final numMatch = RegExp(r'(\d+(?:[.,]\d+)?)').firstMatch(text);
    if (numMatch != null) {
      return double.tryParse(numMatch.group(1)!.replaceAll(',', '.'));
    }
    return null;
  }
}

class FoodDiaryEntry {
  final String id;
  final String date; // YYYY-MM-DD
  final String timestamp; // RFC3339
  final String meal; // breakfast, lunch, dinner, snack
  final FoodItem food;
  final double amount;
  final String unit; // g, ml, portion
  final double servingQuantityG;
  final String? notes;

  const FoodDiaryEntry({
    required this.id,
    required this.date,
    required this.timestamp,
    required this.meal,
    required this.food,
    required this.amount,
    required this.unit,
    this.servingQuantityG = 100.0,
    this.notes,
  });

  NutrientProfile get nutrients => food.nutrientsForQuantity(
        amount,
        unit,
        customServingQuantityG: servingQuantityG,
      );

  double get effectiveGramsOrMl {
    if (FoodUnit.normalize(unit) == FoodUnit.portion) {
      final sq = servingQuantityG > 0
          ? servingQuantityG
          : (food.servingQuantityG > 0 ? food.servingQuantityG : 100.0);
      return amount * sq;
    }
    return amount;
  }

  FoodDiaryEntry copyWith({
    String? id,
    String? date,
    String? timestamp,
    String? meal,
    FoodItem? food,
    double? amount,
    String? unit,
    double? servingQuantityG,
    String? notes,
  }) {
    return FoodDiaryEntry(
      id: id ?? this.id,
      date: date ?? this.date,
      timestamp: timestamp ?? this.timestamp,
      meal: meal ?? this.meal,
      food: food ?? this.food,
      amount: amount ?? this.amount,
      unit: unit ?? this.unit,
      servingQuantityG: servingQuantityG ?? this.servingQuantityG,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() {
    final calc = nutrients;
    return {
      'id': id,
      'date': date,
      'timestamp': timestamp,
      'meal': MealType.normalize(meal),
      'amount': amount,
      'unit': FoodUnit.normalize(unit),
      'serving_quantity_g': servingQuantityG,
      'effective_grams_or_ml': effectiveGramsOrMl,
      'notes': notes,
      'food': food.toJson(),
      'nutrients': calc.toJson(),
    };
  }

  factory FoodDiaryEntry.fromJson(Map<String, dynamic> json) {
    final foodMap = json['food'] is Map
        ? Map<String, dynamic>.from(json['food'] as Map)
        : <String, dynamic>{
            'name': json['food_name'] ?? json['name'] ?? 'Lebensmittel',
            'nutrients_per_100g': json['nutrients_per_100g'] ?? json['nutrients'] ?? {},
          };
    final food = FoodItem.fromJson(foodMap);
    final ts = (json['timestamp'] ?? '${json['date'] ?? '2026-01-01'}T12:00:00Z').toString();
    final date = (json['date'] ?? ts.substring(0, 10)).toString();
    final amount = (json['amount'] is num)
        ? (json['amount'] as num).toDouble()
        : (double.tryParse(json['amount']?.toString() ?? '100') ?? 100.0);
    final srv = (json['serving_quantity_g'] is num)
        ? (json['serving_quantity_g'] as num).toDouble()
        : food.servingQuantityG;
    return FoodDiaryEntry(
      id: (json['id'] ?? 'fe_${ts.hashCode}').toString(),
      date: date,
      timestamp: ts,
      meal: MealType.normalize(json['meal']?.toString()),
      food: food,
      amount: amount > 0 ? amount : 1.0,
      unit: FoodUnit.normalize(json['unit']?.toString()),
      servingQuantityG: srv > 0 ? srv : 100.0,
      notes: json['notes']?.toString(),
    );
  }
}

class WaterEntry {
  final String id;
  final String date; // YYYY-MM-DD
  final String timestamp; // RFC3339
  final double amountMl;
  final String? notes;

  const WaterEntry({
    required this.id,
    required this.date,
    required this.timestamp,
    required this.amountMl,
    this.notes,
  });

  WaterEntry copyWith({
    String? id,
    String? date,
    String? timestamp,
    double? amountMl,
    String? notes,
  }) {
    return WaterEntry(
      id: id ?? this.id,
      date: date ?? this.date,
      timestamp: timestamp ?? this.timestamp,
      amountMl: amountMl ?? this.amountMl,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date,
        'timestamp': timestamp,
        'amount_ml': amountMl,
        'notes': notes,
      };

  factory WaterEntry.fromJson(Map<String, dynamic> json) {
    final ts = (json['timestamp'] ?? '${json['date'] ?? '2026-01-01'}T12:00:00Z').toString();
    final date = (json['date'] ?? ts.substring(0, 10)).toString();
    final ml = (json['amount_ml'] ?? json['amount'] ?? 250);
    final parsedMl = ml is num ? ml.toDouble() : (double.tryParse(ml.toString()) ?? 250.0);
    return WaterEntry(
      id: (json['id'] ?? 'we_${ts.hashCode}').toString(),
      date: date,
      timestamp: ts,
      amountMl: parsedMl > 0 ? parsedMl : 250.0,
      notes: json['notes']?.toString(),
    );
  }
}

class CaffeineEntry {
  final String id;
  final String date; // YYYY-MM-DD
  final String timestamp; // RFC3339
  final double amountMg;
  final String? beverageName;
  final String? notes;

  const CaffeineEntry({
    required this.id,
    required this.date,
    required this.timestamp,
    required this.amountMg,
    this.beverageName,
    this.notes,
  });

  CaffeineEntry copyWith({
    String? id,
    String? date,
    String? timestamp,
    double? amountMg,
    String? beverageName,
    String? notes,
  }) {
    return CaffeineEntry(
      id: id ?? this.id,
      date: date ?? this.date,
      timestamp: timestamp ?? this.timestamp,
      amountMg: amountMg ?? this.amountMg,
      beverageName: beverageName ?? this.beverageName,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date,
        'timestamp': timestamp,
        'amount_mg': amountMg,
        'beverage_name': beverageName,
        'notes': notes,
      };

  factory CaffeineEntry.fromJson(Map<String, dynamic> json) {
    final ts = (json['timestamp'] ?? '${json['date'] ?? '2026-01-01'}T12:00:00Z').toString();
    final date = (json['date'] ?? ts.substring(0, 10)).toString();
    final mg = (json['amount_mg'] ?? json['amount'] ?? 80);
    final parsedMg = mg is num ? mg.toDouble() : (double.tryParse(mg.toString()) ?? 80.0);
    return CaffeineEntry(
      id: (json['id'] ?? 'ce_${ts.hashCode}').toString(),
      date: date,
      timestamp: ts,
      amountMg: parsedMg >= 0 ? parsedMg : 0.0,
      beverageName: (json['beverage_name'] ?? json['name'])?.toString(),
      notes: json['notes']?.toString(),
    );
  }
}

class PeriodEntry {
  final String id;
  final String startDate; // YYYY-MM-DD
  final String? endDate; // YYYY-MM-DD (inclusive)
  final String intensity; // spotting, light, medium, heavy
  final Map<String, String> dailyFlow; // YYYY-MM-DD -> spotting/light/medium/heavy
  final String? notes;

  const PeriodEntry({
    required this.id,
    required this.startDate,
    this.endDate,
    this.intensity = BleedingIntensity.medium,
    this.dailyFlow = const {},
    this.notes,
  });

  int get durationDays {
    if (endDate == null || endDate!.trim().isEmpty) {
      return 1;
    }
    final s = DateTime.tryParse('${startDate}T00:00:00Z');
    final e = DateTime.tryParse('${endDate}T00:00:00Z');
    if (s == null || e == null || e.isBefore(s)) return 1;
    return e.difference(s).inDays + 1;
  }

  bool containsDate(String date) {
    if (dailyFlow.containsKey(date)) return true;
    final effectiveEnd = (endDate != null && endDate!.trim().isNotEmpty)
        ? endDate!
        : startDate;
    return date.compareTo(startDate) >= 0 && date.compareTo(effectiveEnd) <= 0;
  }

  String? intensityForDate(String date) {
    if (dailyFlow.containsKey(date)) {
      return BleedingIntensity.normalize(dailyFlow[date]);
    }
    if (containsDate(date)) {
      return BleedingIntensity.normalize(intensity);
    }
    return null;
  }

  PeriodEntry copyWith({
    String? id,
    String? startDate,
    String? endDate,
    bool clearEndDate = false,
    String? intensity,
    Map<String, String>? dailyFlow,
    String? notes,
  }) {
    return PeriodEntry(
      id: id ?? this.id,
      startDate: startDate ?? this.startDate,
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
      intensity: intensity ?? this.intensity,
      dailyFlow: dailyFlow ?? this.dailyFlow,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'start_date': startDate,
        'end_date': endDate,
        'duration_days': durationDays,
        'intensity': BleedingIntensity.normalize(intensity),
        'daily_flow': dailyFlow,
        'notes': notes,
      };

  factory PeriodEntry.fromJson(Map<String, dynamic> json) {
    final start = (json['start_date'] ?? json['startDate'] ?? json['date'] ?? '2026-01-01')
        .toString()
        .substring(0, 10);
    final rawEnd = (json['end_date'] ?? json['endDate'])?.toString();
    final end = (rawEnd != null && rawEnd.trim().length >= 10)
        ? rawEnd.trim().substring(0, 10)
        : null;
    final rawDaily = json['daily_flow'] is Map
        ? (json['daily_flow'] as Map).map(
            (k, v) => MapEntry(k.toString(), BleedingIntensity.normalize(v?.toString())),
          )
        : const <String, String>{};
    return PeriodEntry(
      id: (json['id'] ?? 'pe_$start').toString(),
      startDate: start,
      endDate: end,
      intensity: BleedingIntensity.normalize(
        (json['intensity'] ?? json['flow'] ?? BleedingIntensity.medium).toString(),
      ),
      dailyFlow: rawDaily,
      notes: json['notes']?.toString(),
    );
  }
}

class WeightEntry {
  static const double kgToLbFactor = 2.20462262185;

  final String id;
  final String date; // YYYY-MM-DD
  final String timestamp; // RFC3339
  final double weightKg;
  final String inputUnit; // 'kg' or 'lb'
  final String? notes;

  const WeightEntry({
    required this.id,
    required this.date,
    required this.timestamp,
    required this.weightKg,
    this.inputUnit = 'kg',
    this.notes,
  });

  double get weightLb => weightKg * kgToLbFactor;

  double valueInUnit(String unit) =>
      unit.toLowerCase() == 'lb' ? weightLb : weightKg;

  static double toKg(double value, String unit) =>
      unit.toLowerCase() == 'lb' ? (value / kgToLbFactor) : value;

  WeightEntry copyWith({
    String? id,
    String? date,
    String? timestamp,
    double? weightKg,
    String? inputUnit,
    String? notes,
  }) {
    return WeightEntry(
      id: id ?? this.id,
      date: date ?? this.date,
      timestamp: timestamp ?? this.timestamp,
      weightKg: weightKg ?? this.weightKg,
      inputUnit: inputUnit ?? this.inputUnit,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date,
        'timestamp': timestamp,
        'weight_kg': (weightKg * 100).roundToDouble() / 100.0,
        'weight_lb': (weightLb * 100).roundToDouble() / 100.0,
        'input_unit': inputUnit,
        'notes': notes,
      };

  factory WeightEntry.fromJson(Map<String, dynamic> json) {
    final ts = (json['timestamp'] ?? '${json['date'] ?? '2026-01-01'}T08:00:00Z').toString();
    final date = (json['date'] ?? ts.substring(0, 10)).toString();
    final unit = (json['input_unit'] ?? json['unit'] ?? 'kg').toString().toLowerCase();
    double kg;
    if (json['weight_kg'] != null) {
      kg = (json['weight_kg'] is num)
          ? (json['weight_kg'] as num).toDouble()
          : (double.tryParse(json['weight_kg'].toString()) ?? 70.0);
    } else if (json['weight_lb'] != null) {
      final lb = (json['weight_lb'] is num)
          ? (json['weight_lb'] as num).toDouble()
          : (double.tryParse(json['weight_lb'].toString()) ?? 154.0);
      kg = lb / kgToLbFactor;
    } else {
      final raw = (json['weight'] ?? json['value'] ?? 70.0);
      final parsed = raw is num ? raw.toDouble() : (double.tryParse(raw.toString()) ?? 70.0);
      kg = toKg(parsed, unit);
    }
    return WeightEntry(
      id: (json['id'] ?? 'wt_$date').toString(),
      date: date,
      timestamp: ts,
      weightKg: kg > 0 ? kg : 70.0,
      inputUnit: unit == 'lb' ? 'lb' : 'kg',
      notes: json['notes']?.toString(),
    );
  }
}

class SymptomEntry {
  final String id;
  final String date; // YYYY-MM-DD
  final String timestamp; // RFC3339
  final String name;
  final int intensity; // 0..10
  final String? notes;

  const SymptomEntry({
    required this.id,
    required this.date,
    required this.timestamp,
    required this.name,
    required this.intensity,
    this.notes,
  });

  SymptomEntry copyWith({
    String? id,
    String? date,
    String? timestamp,
    String? name,
    int? intensity,
    String? notes,
  }) {
    return SymptomEntry(
      id: id ?? this.id,
      date: date ?? this.date,
      timestamp: timestamp ?? this.timestamp,
      name: name ?? this.name,
      intensity: (intensity ?? this.intensity).clamp(0, 10),
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date,
        'timestamp': timestamp,
        'name': name,
        'intensity': intensity.clamp(0, 10),
        'notes': notes,
      };

  factory SymptomEntry.fromJson(Map<String, dynamic> json) {
    final ts = (json['timestamp'] ?? '${json['date'] ?? '2026-01-01'}T12:00:00Z').toString();
    final date = (json['date'] ?? ts.substring(0, 10)).toString();
    final rawInt = json['intensity'] ?? 5;
    final parsedInt = rawInt is num
        ? rawInt.round()
        : (int.tryParse(rawInt.toString()) ?? 5);
    return SymptomEntry(
      id: (json['id'] ?? 'sy_${ts.hashCode}').toString(),
      date: date,
      timestamp: ts,
      name: (json['name'] ?? json['symptom'] ?? 'Symptom').toString().trim(),
      intensity: parsedInt.clamp(0, 10),
      notes: json['notes']?.toString(),
    );
  }
}

class NutritionGoals {
  final double? waterMl;
  final double? caloriesKcal;
  final double? proteinG;
  final double? carbohydratesG;
  final double? fatG;

  const NutritionGoals({
    this.waterMl,
    this.caloriesKcal,
    this.proteinG,
    this.carbohydratesG,
    this.fatG,
  });

  NutritionGoals copyWith({
    double? waterMl,
    bool clearWater = false,
    double? caloriesKcal,
    bool clearCalories = false,
    double? proteinG,
    bool clearProtein = false,
    double? carbohydratesG,
    bool clearCarbohydrates = false,
    double? fatG,
    bool clearFat = false,
  }) {
    return NutritionGoals(
      waterMl: clearWater ? null : (waterMl ?? this.waterMl),
      caloriesKcal: clearCalories ? null : (caloriesKcal ?? this.caloriesKcal),
      proteinG: clearProtein ? null : (proteinG ?? this.proteinG),
      carbohydratesG:
          clearCarbohydrates ? null : (carbohydratesG ?? this.carbohydratesG),
      fatG: clearFat ? null : (fatG ?? this.fatG),
    );
  }

  Map<String, dynamic> toJson() => {
        'water_ml': waterMl,
        'calories_kcal': caloriesKcal,
        'protein_g': proteinG,
        'carbohydrates_g': carbohydratesG,
        'fat_g': fatG,
      };

  factory NutritionGoals.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const NutritionGoals();
    double? parseOpt(dynamic v) {
      if (v == null) return null;
      if (v is num) return v > 0 ? v.toDouble() : null;
      final d = double.tryParse(v.toString());
      return (d != null && d > 0) ? d : null;
    }

    return NutritionGoals(
      waterMl: parseOpt(json['water_ml']),
      caloriesKcal: parseOpt(json['calories_kcal']),
      proteinG: parseOpt(json['protein_g']),
      carbohydratesG: parseOpt(json['carbohydrates_g']),
      fatG: parseOpt(json['fat_g']),
    );
  }
}

class UserSettings {
  final String language; // 'de' or 'en'
  final String weightUnit; // 'kg' or 'lb'
  final bool onlineFoodSearchEnabled;
  final bool cyclePredictionsEnabled;
  final bool showNutritionInOverview;
  final bool showCycleInOverview;
  final bool showWeightInOverview;
  final bool showSymptomsInOverview;
  final NutritionGoals goals;

  const UserSettings({
    this.language = 'de',
    this.weightUnit = 'kg',
    this.onlineFoodSearchEnabled = true,
    this.cyclePredictionsEnabled = true,
    this.showNutritionInOverview = true,
    this.showCycleInOverview = true,
    this.showWeightInOverview = true,
    this.showSymptomsInOverview = true,
    this.goals = const NutritionGoals(),
  });

  UserSettings copyWith({
    String? language,
    String? weightUnit,
    bool? onlineFoodSearchEnabled,
    bool? cyclePredictionsEnabled,
    bool? showNutritionInOverview,
    bool? showCycleInOverview,
    bool? showWeightInOverview,
    bool? showSymptomsInOverview,
    NutritionGoals? goals,
  }) {
    return UserSettings(
      language: language ?? this.language,
      weightUnit: weightUnit ?? this.weightUnit,
      onlineFoodSearchEnabled:
          onlineFoodSearchEnabled ?? this.onlineFoodSearchEnabled,
      cyclePredictionsEnabled:
          cyclePredictionsEnabled ?? this.cyclePredictionsEnabled,
      showNutritionInOverview:
          showNutritionInOverview ?? this.showNutritionInOverview,
      showCycleInOverview: showCycleInOverview ?? this.showCycleInOverview,
      showWeightInOverview: showWeightInOverview ?? this.showWeightInOverview,
      showSymptomsInOverview:
          showSymptomsInOverview ?? this.showSymptomsInOverview,
      goals: goals ?? this.goals,
    );
  }

  Map<String, dynamic> toJson() => {
        'language': language,
        'weight_unit': weightUnit,
        'online_food_search_enabled': onlineFoodSearchEnabled,
        'cycle_predictions_enabled': cyclePredictionsEnabled,
        'visible_modules': {
          'nutrition': showNutritionInOverview,
          'cycle': showCycleInOverview,
          'weight': showWeightInOverview,
          'symptoms': showSymptomsInOverview,
        },
        'goals': goals.toJson(),
      };

  factory UserSettings.fromJson(Map<String, dynamic>? json) {
    if (json == null) return const UserSettings();
    final vis = json['visible_modules'] is Map
        ? Map<String, dynamic>.from(json['visible_modules'] as Map)
        : const <String, dynamic>{};
    return UserSettings(
      language: json['language'] == 'en' ? 'en' : 'de',
      weightUnit: json['weight_unit'] == 'lb' ? 'lb' : 'kg',
      onlineFoodSearchEnabled: json['online_food_search_enabled'] != false,
      cyclePredictionsEnabled: json['cycle_predictions_enabled'] != false,
      showNutritionInOverview: vis['nutrition'] != false,
      showCycleInOverview: vis['cycle'] != false,
      showWeightInOverview: vis['weight'] != false,
      showSymptomsInOverview: vis['symptoms'] != false,
      goals: NutritionGoals.fromJson(
        json['goals'] is Map
            ? Map<String, dynamic>.from(json['goals'] as Map)
            : null,
      ),
    );
  }
}
