import 'utils.dart';

enum NutrientGroup { main, additional, vitamin, mineral }

enum Nutrient {
  calories('calories', 'kcal', NutrientGroup.main, ['energy-kcal']),
  protein('protein', 'g', NutrientGroup.main, ['proteins']),
  carbs('carbs', 'g', NutrientGroup.main, ['carbohydrates']),
  fat('fat', 'g', NutrientGroup.main, ['fat']),
  saturatedFat('saturated_fat', 'g', NutrientGroup.additional, [
    'saturated-fat',
  ]),
  sugar('sugar', 'g', NutrientGroup.additional, ['sugars']),
  fiber('fiber', 'g', NutrientGroup.additional, ['fiber']),
  salt('salt', 'g', NutrientGroup.additional, ['salt']),
  sodium('sodium', 'mg', NutrientGroup.additional, ['sodium']),
  caffeine('caffeine', 'mg', NutrientGroup.additional, ['caffeine']),
  vitaminA('vitamin_a', 'µg', NutrientGroup.vitamin, ['vitamin-a']),
  vitaminC('vitamin_c', 'mg', NutrientGroup.vitamin, ['vitamin-c']),
  vitaminD('vitamin_d', 'µg', NutrientGroup.vitamin, ['vitamin-d']),
  vitaminE('vitamin_e', 'mg', NutrientGroup.vitamin, ['vitamin-e']),
  vitaminK('vitamin_k', 'µg', NutrientGroup.vitamin, ['vitamin-k']),
  vitaminB1('vitamin_b1', 'mg', NutrientGroup.vitamin, ['vitamin-b1']),
  vitaminB2('vitamin_b2', 'mg', NutrientGroup.vitamin, ['vitamin-b2']),
  vitaminB3('vitamin_b3', 'mg', NutrientGroup.vitamin, [
    'vitamin-b3',
    'vitamin-pp',
  ]),
  vitaminB5('vitamin_b5', 'mg', NutrientGroup.vitamin, [
    'vitamin-b5',
    'pantothenic-acid',
  ]),
  vitaminB6('vitamin_b6', 'mg', NutrientGroup.vitamin, ['vitamin-b6']),
  vitaminB7('vitamin_b7', 'µg', NutrientGroup.vitamin, [
    'vitamin-b7',
    'biotin',
  ]),
  vitaminB9('vitamin_b9', 'µg', NutrientGroup.vitamin, [
    'vitamin-b9',
    'folates',
    'folic-acid',
  ]),
  vitaminB12('vitamin_b12', 'µg', NutrientGroup.vitamin, ['vitamin-b12']),
  calcium('calcium', 'mg', NutrientGroup.mineral, ['calcium']),
  iron('iron', 'mg', NutrientGroup.mineral, ['iron']),
  magnesium('magnesium', 'mg', NutrientGroup.mineral, ['magnesium']),
  potassium('potassium', 'mg', NutrientGroup.mineral, ['potassium']),
  zinc('zinc', 'mg', NutrientGroup.mineral, ['zinc']),
  selenium('selenium', 'µg', NutrientGroup.mineral, ['selenium']),
  iodine('iodine', 'µg', NutrientGroup.mineral, ['iodine']),
  phosphorus('phosphorus', 'mg', NutrientGroup.mineral, ['phosphorus']);

  const Nutrient(this.id, this.unit, this.group, this.offKeys);

  final String id;
  final String unit;
  final NutrientGroup group;
  final List<String> offKeys;

  static Nutrient byId(String id) => values.firstWhere(
    (nutrient) => nutrient.id == id,
    orElse: () => throw FormatException('Unknown nutrient: $id'),
  );
}

class Food {
  const Food({
    required this.id,
    required this.name,
    required this.brand,
    required this.source,
    required this.measure,
    required this.nutrients,
    required this.favorite,
    required this.createdAt,
    required this.updatedAt,
    this.barcode,
    this.portionSize,
  });

  final String id;
  final String name;
  final String brand;
  final String source;
  final String measure;
  final double? portionSize;
  final Map<String, double> nutrients;
  final bool favorite;
  final String? barcode;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isCustom => source == 'custom';

  Food copyWith({
    String? name,
    String? brand,
    String? measure,
    double? portionSize,
    bool clearPortion = false,
    Map<String, double>? nutrients,
    bool? favorite,
    DateTime? updatedAt,
  }) => Food(
    id: id,
    name: name ?? this.name,
    brand: brand ?? this.brand,
    source: source,
    measure: measure ?? this.measure,
    portionSize: clearPortion ? null : portionSize ?? this.portionSize,
    nutrients: nutrients ?? this.nutrients,
    favorite: favorite ?? this.favorite,
    barcode: barcode,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'brand': brand,
    'source': source,
    'measure': measure,
    'portion_size': portionSize,
    'nutrients_per_100': nutrients,
    'favorite': favorite,
    'barcode': barcode,
    'created_at': formatInstant(createdAt),
    'updated_at': formatInstant(updatedAt),
  };

  factory Food.fromJson(Object? value, [String path = 'food']) {
    final json = jsonMap(value, path);
    final source = jsonString(json['source'], '$path.source');
    if (!{'custom', 'openfoodfacts'}.contains(source)) {
      throw FormatException('$path.source is invalid');
    }
    final measure = jsonString(json['measure'], '$path.measure');
    if (!{'g', 'ml'}.contains(measure))
      throw FormatException('$path.measure is invalid');
    final nutrients = jsonNumberMap(
      json['nutrients_per_100'],
      '$path.nutrients_per_100',
    );
    for (final id in nutrients.keys) Nutrient.byId(id);
    final portion = jsonOptionalDouble(
      json['portion_size'],
      '$path.portion_size',
      min: 0,
    );
    if (portion == 0)
      throw FormatException('$path.portion_size must be positive');
    return Food(
      id: jsonString(json['id'], '$path.id'),
      name: jsonString(json['name'], '$path.name'),
      brand: jsonString(json['brand'], '$path.brand', allowEmpty: true),
      source: source,
      measure: measure,
      portionSize: portion,
      nutrients: nutrients,
      favorite: jsonBool(json['favorite'], '$path.favorite'),
      barcode: jsonOptionalString(json['barcode'], '$path.barcode'),
      createdAt: parseInstant(json['created_at'], '$path.created_at'),
      updatedAt: parseInstant(json['updated_at'], '$path.updated_at'),
    );
  }
}

enum IntakeKind { food, water, caffeine }

class IntakeEntry {
  const IntakeEntry({
    required this.id,
    required this.kind,
    required this.occurredAt,
    required this.meal,
    required this.amount,
    required this.unit,
    required this.nutrients,
    required this.createdAt,
    required this.updatedAt,
    this.foodId,
    this.foodName = '',
    this.brand = '',
    this.portionSize,
    this.notes = '',
  });

  final String id;
  final IntakeKind kind;
  final DateTime occurredAt;
  final String meal;
  final String? foodId;
  final String foodName;
  final String brand;
  final double amount;
  final String unit;
  final double? portionSize;
  final Map<String, double> nutrients;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  double get nutrientFactor {
    if (kind != IntakeKind.food) return 0;
    if (unit == 'portion') return amount * (portionSize ?? 0) / 100;
    return amount / 100;
  }

  double? amountOf(Nutrient nutrient) {
    if (kind == IntakeKind.water)
      return nutrient == Nutrient.calories ? 0 : null;
    if (kind == IntakeKind.caffeine) {
      return nutrient == Nutrient.caffeine
          ? amount
          : nutrient == Nutrient.calories
          ? 0
          : null;
    }
    final value = nutrients[nutrient.id];
    return value == null ? null : value * nutrientFactor;
  }

  IntakeEntry copyWith({
    DateTime? occurredAt,
    String? meal,
    double? amount,
    String? unit,
    double? portionSize,
    Map<String, double>? nutrients,
    String? notes,
    DateTime? updatedAt,
  }) => IntakeEntry(
    id: id,
    kind: kind,
    occurredAt: occurredAt ?? this.occurredAt,
    meal: meal ?? this.meal,
    foodId: foodId,
    foodName: foodName,
    brand: brand,
    amount: amount ?? this.amount,
    unit: unit ?? this.unit,
    portionSize: portionSize ?? this.portionSize,
    nutrients: nutrients ?? this.nutrients,
    notes: notes ?? this.notes,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind.name,
    'occurred_at': formatInstant(occurredAt),
    'meal': meal,
    'food_id': foodId,
    'food_name': foodName,
    'brand': brand,
    'amount': amount,
    'unit': unit,
    'portion_size': portionSize,
    'nutrients_per_100_snapshot': nutrients,
    'notes': notes,
    'created_at': formatInstant(createdAt),
    'updated_at': formatInstant(updatedAt),
  };

  factory IntakeEntry.fromJson(Object? value, [String path = 'intake']) {
    final json = jsonMap(value, path);
    final kindName = jsonString(json['kind'], '$path.kind');
    final kind = IntakeKind.values
        .where((item) => item.name == kindName)
        .firstOrNull;
    if (kind == null) throw FormatException('$path.kind is invalid');
    final unit = jsonString(json['unit'], '$path.unit');
    final allowedUnits = kind == IntakeKind.food
        ? {'g', 'ml', 'portion'}
        : kind == IntakeKind.water
        ? {'ml'}
        : {'mg'};
    if (!allowedUnits.contains(unit))
      throw FormatException('$path.unit is invalid');
    final meal = jsonString(json['meal'], '$path.meal');
    if (!{'breakfast', 'lunch', 'dinner', 'snack'}.contains(meal)) {
      throw FormatException('$path.meal is invalid');
    }
    final nutrients = jsonNumberMap(
      json['nutrients_per_100_snapshot'],
      '$path.nutrients_per_100_snapshot',
    );
    for (final id in nutrients.keys) Nutrient.byId(id);
    final portion = jsonOptionalDouble(
      json['portion_size'],
      '$path.portion_size',
      min: 0,
    );
    if (unit == 'portion' && (portion == null || portion <= 0)) {
      throw FormatException('$path.portion_size is required for portions');
    }
    return IntakeEntry(
      id: jsonString(json['id'], '$path.id'),
      kind: kind,
      occurredAt: parseInstant(json['occurred_at'], '$path.occurred_at'),
      meal: meal,
      foodId: jsonOptionalString(json['food_id'], '$path.food_id'),
      foodName: jsonString(
        json['food_name'],
        '$path.food_name',
        allowEmpty: true,
      ),
      brand: jsonString(json['brand'], '$path.brand', allowEmpty: true),
      amount: jsonDouble(json['amount'], '$path.amount', min: 0.000001),
      unit: unit,
      portionSize: portion,
      nutrients: nutrients,
      notes: jsonString(json['notes'], '$path.notes', allowEmpty: true),
      createdAt: parseInstant(json['created_at'], '$path.created_at'),
      updatedAt: parseInstant(json['updated_at'], '$path.updated_at'),
    );
  }
}

class NutritionDay {
  const NutritionDay({
    required this.date,
    required this.entries,
    required this.totals,
    required this.waterMl,
    required this.knownFoodEntries,
    required this.foodEntryCount,
  });

  final String date;
  final List<IntakeEntry> entries;
  final Map<String, double> totals;
  final double waterMl;
  final Map<String, int> knownFoodEntries;
  final int foodEntryCount;

  double total(Nutrient nutrient) => totals[nutrient.id] ?? 0;

  Map<String, dynamic> toJson() => {
    'date': date,
    'water_ml': waterMl,
    'totals': totals,
    'nutrient_units': {
      for (final nutrient in Nutrient.values) nutrient.id: nutrient.unit,
    },
    'food_entry_count': foodEntryCount,
    'known_food_entries_per_nutrient': knownFoodEntries,
    'entries': entries.map((entry) {
      final calculated = <String, double?>{};
      for (final nutrient in Nutrient.values)
        calculated[nutrient.id] = entry.amountOf(nutrient);
      return {
        ...entry.toJson(),
        'local_date': instantDateKey(entry.occurredAt),
        'calculated_nutrients': calculated,
      };
    }).toList(),
  };
}

NutritionDay summarizeNutrition(String date, Iterable<IntakeEntry> allEntries) {
  parseDate(date);
  final entries =
      allEntries
          .where((entry) => instantDateKey(entry.occurredAt) == date)
          .toList()
        ..sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
  final totals = <String, double>{
    for (final nutrient in Nutrient.values) nutrient.id: 0,
  };
  final known = <String, int>{
    for (final nutrient in Nutrient.values) nutrient.id: 0,
  };
  var water = 0.0;
  var foodCount = 0;
  for (final entry in entries) {
    if (entry.kind == IntakeKind.water) water += entry.amount;
    if (entry.kind == IntakeKind.food) {
      foodCount++;
      for (final nutrient in Nutrient.values) {
        if (entry.nutrients.containsKey(nutrient.id))
          known[nutrient.id] = known[nutrient.id]! + 1;
      }
    }
    for (final nutrient in Nutrient.values) {
      final value = entry.amountOf(nutrient);
      if (value != null) totals[nutrient.id] = totals[nutrient.id]! + value;
    }
  }
  return NutritionDay(
    date: date,
    entries: entries,
    totals: totals,
    waterMl: water,
    knownFoodEntries: known,
    foodEntryCount: foodCount,
  );
}
