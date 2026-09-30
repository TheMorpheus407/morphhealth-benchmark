import '../util/clock.dart';
import '../util/ids.dart';
import '../util/json_reader.dart';
import '../util/local_date.dart';
import 'enums.dart';
import 'food.dart';
import 'record.dart';

export 'record.dart';

String? _formatTime(int? minutes) =>
    minutes == null ? null : TimeOfDayMinutes.format(minutes);

Map<String, Object?> _stamps(Record r) => {
  'created_at': formatInstant(r.createdAt),
  'updated_at': formatInstant(r.updatedAt),
};

const Set<String> _stampKeys = {'id', 'created_at', 'updated_at'};

/// A logged food ("Verzehreintrag").
class FoodEntry implements DatedRecord {
  FoodEntry({
    required this.id,
    required this.date,
    required this.time,
    required this.meal,
    required this.amount,
    required this.unit,
    required this.food,
    this.foodRef,
    this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  factory FoodEntry.create({
    required LocalDate date,
    required int? time,
    required Meal meal,
    required double amount,
    required AmountUnit unit,
    required FoodProfile food,
    String? foodRef,
    String? note,
    required DateTime now,
  }) => FoodEntry(
    id: newId(),
    date: date,
    time: time,
    meal: meal,
    amount: amount,
    unit: unit,
    food: food,
    foodRef: foodRef,
    note: note,
    createdAt: now,
    updatedAt: now,
  );

  @override
  final String id;
  @override
  final LocalDate date;
  @override
  final int? time;
  final Meal meal;
  final double amount;
  final AmountUnit unit;

  /// Snapshot of the food as logged.
  final FoodProfile food;

  /// Id of the library food this entry was created from, if any.
  final String? foodRef;
  final String? note;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;

  /// Logged amount in the food's basis unit (g or ml).
  double? get quantity => food.quantityInBasis(amount, unit);

  /// Amount of a nutrient in this entry, or null if the food lacks the value.
  double? nutrient(String key) {
    final q = quantity;
    if (q == null) return null;
    return food.valueFor(key, q);
  }

  FoodEntry copyWith({
    LocalDate? date,
    int? Function()? time,
    Meal? meal,
    double? amount,
    AmountUnit? unit,
    FoodProfile? food,
    String? Function()? foodRef,
    String? Function()? note,
    required DateTime updatedAt,
  }) => FoodEntry(
    id: id,
    date: date ?? this.date,
    time: time != null ? time() : this.time,
    meal: meal ?? this.meal,
    amount: amount ?? this.amount,
    unit: unit ?? this.unit,
    food: food ?? this.food,
    foodRef: foodRef != null ? foodRef() : this.foodRef,
    note: note != null ? note() : this.note,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );

  @override
  Map<String, Object?> toJson() => {
    'id': id,
    'date': date.toIso(),
    'time': _formatTime(time),
    'meal': meal.json,
    'amount': amount,
    'unit': unit.json,
    'food': {'ref': foodRef, ...food.toJson()},
    'note': note,
    ..._stamps(this),
  };

  static const double maxAmountGramOrMl = 100000;
  static const double maxPortions = 1000;

  static FoodEntry? fromJson(
    Object? json,
    String path,
    Issues issues,
    DateTime now,
  ) {
    final r = JsonReader.of(json, path, issues);
    if (r == null) return null;
    final before = issues.errors.length;
    r.warnUnknownKeys({
      ..._stampKeys,
      'date',
      'time',
      'meal',
      'amount',
      'unit',
      'food',
      'note',
    });
    final id = readId(r);
    final date = r.date('date', required: true);
    final time = r.time('time');
    final meal = r.enumValue('meal', Meal.byJson, required: true);
    final amount = r.number('amount', required: true, min: 0, exclusiveMin: true);
    final unit = r.enumValue('unit', AmountUnit.byJson, required: true);
    final fr = r.object('food', required: true);
    FoodProfile? food;
    String? ref;
    if (fr != null) {
      fr.warnUnknownKeys({...FoodProfile.jsonKeys, 'ref'});
      ref = fr.string('ref', maxLength: 64);
      food = FoodProfile.read(fr);
    }
    final note = r.string('note', maxLength: 2000);
    final created = r.instant('created_at') ?? now;
    final updated = r.instant('updated_at') ?? created;
    if (amount != null && unit != null) {
      final max = unit == AmountUnit.portion ? maxPortions : maxAmountGramOrMl;
      if (amount > max) issues.error('$path.amount', 'must be at most $max');
    }
    if (unit == AmountUnit.portion && food != null && !food.hasServing) {
      issues.error(
        '$path.unit',
        '"portion" requires food.serving_size',
      );
    }
    if (issues.errors.length != before) return null;
    return FoodEntry(
      id: id,
      date: date!,
      time: time,
      meal: meal!,
      amount: amount!,
      unit: unit!,
      food: food!,
      foodRef: ref,
      note: note,
      createdAt: created,
      updatedAt: updated,
    );
  }
}

/// Water logged in the nutrition diary.
class WaterEntry implements DatedRecord {
  WaterEntry({
    required this.id,
    required this.date,
    required this.time,
    required this.amountMl,
    required this.createdAt,
    required this.updatedAt,
  });

  factory WaterEntry.create(LocalDate date, int? time, double ml, DateTime now) =>
      WaterEntry(
        id: newId(),
        date: date,
        time: time,
        amountMl: ml,
        createdAt: now,
        updatedAt: now,
      );

  @override
  final String id;
  @override
  final LocalDate date;
  @override
  final int? time;
  final double amountMl;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;

  static const double maxMl = 10000;

  WaterEntry copyWith({
    LocalDate? date,
    int? Function()? time,
    double? amountMl,
    required DateTime updatedAt,
  }) => WaterEntry(
    id: id,
    date: date ?? this.date,
    time: time != null ? time() : this.time,
    amountMl: amountMl ?? this.amountMl,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );

  @override
  Map<String, Object?> toJson() => {
    'id': id,
    'date': date.toIso(),
    'time': _formatTime(time),
    'amount_ml': amountMl,
    ..._stamps(this),
  };

  static WaterEntry? fromJson(
    Object? json,
    String path,
    Issues issues,
    DateTime now,
  ) {
    final r = JsonReader.of(json, path, issues);
    if (r == null) return null;
    final before = issues.errors.length;
    r.warnUnknownKeys({..._stampKeys, 'date', 'time', 'amount_ml'});
    final id = readId(r);
    final date = r.date('date', required: true);
    final time = r.time('time');
    final ml = r.number(
      'amount_ml',
      required: true,
      min: 0,
      exclusiveMin: true,
      max: maxMl,
    );
    final created = r.instant('created_at') ?? now;
    final updated = r.instant('updated_at') ?? created;
    if (issues.errors.length != before) return null;
    return WaterEntry(
      id: id,
      date: date!,
      time: time,
      amountMl: ml!,
      createdAt: created,
      updatedAt: updated,
    );
  }
}

/// Caffeine logged in addition to the caffeine contained in logged foods.
class CaffeineEntry implements DatedRecord {
  CaffeineEntry({
    required this.id,
    required this.date,
    required this.time,
    required this.amountMg,
    this.label,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CaffeineEntry.create(
    LocalDate date,
    int? time,
    double mg,
    String? label,
    DateTime now,
  ) => CaffeineEntry(
    id: newId(),
    date: date,
    time: time,
    amountMg: mg,
    label: label,
    createdAt: now,
    updatedAt: now,
  );

  @override
  final String id;
  @override
  final LocalDate date;
  @override
  final int? time;
  final double amountMg;
  final String? label;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;

  static const double maxMg = 2000;

  CaffeineEntry copyWith({
    LocalDate? date,
    int? Function()? time,
    double? amountMg,
    String? Function()? label,
    required DateTime updatedAt,
  }) => CaffeineEntry(
    id: id,
    date: date ?? this.date,
    time: time != null ? time() : this.time,
    amountMg: amountMg ?? this.amountMg,
    label: label != null ? label() : this.label,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );

  @override
  Map<String, Object?> toJson() => {
    'id': id,
    'date': date.toIso(),
    'time': _formatTime(time),
    'amount_mg': amountMg,
    'label': label,
    ..._stamps(this),
  };

  static CaffeineEntry? fromJson(
    Object? json,
    String path,
    Issues issues,
    DateTime now,
  ) {
    final r = JsonReader.of(json, path, issues);
    if (r == null) return null;
    final before = issues.errors.length;
    r.warnUnknownKeys({..._stampKeys, 'date', 'time', 'amount_mg', 'label'});
    final id = readId(r);
    final date = r.date('date', required: true);
    final time = r.time('time');
    final mg = r.number(
      'amount_mg',
      required: true,
      min: 0,
      exclusiveMin: true,
      max: maxMg,
    );
    final label = r.string('label', maxLength: 60);
    final created = r.instant('created_at') ?? now;
    final updated = r.instant('updated_at') ?? created;
    if (issues.errors.length != before) return null;
    return CaffeineEntry(
      id: id,
      date: date!,
      time: time,
      amountMg: mg!,
      label: label,
      createdAt: created,
      updatedAt: updated,
    );
  }
}

/// A body weight measurement, stored in the unit it was entered in.
class WeightEntry implements DatedRecord {
  WeightEntry({
    required this.id,
    required this.date,
    required this.time,
    required this.value,
    required this.unit,
    this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  factory WeightEntry.create({
    required LocalDate date,
    required int? time,
    required double value,
    required WeightUnit unit,
    String? note,
    required DateTime now,
  }) => WeightEntry(
    id: newId(),
    date: date,
    time: time,
    value: value,
    unit: unit,
    note: note,
    createdAt: now,
    updatedAt: now,
  );

  @override
  final String id;
  @override
  final LocalDate date;
  @override
  final int? time;
  final double value;
  final WeightUnit unit;
  final String? note;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;

  static const double minKg = 1;
  static const double maxKg = 700;

  double get kg => unit.toKg(value);

  double valueIn(WeightUnit target) =>
      target == unit ? value : target.fromKg(kg);

  WeightEntry copyWith({
    LocalDate? date,
    int? Function()? time,
    double? value,
    WeightUnit? unit,
    String? Function()? note,
    required DateTime updatedAt,
  }) => WeightEntry(
    id: id,
    date: date ?? this.date,
    time: time != null ? time() : this.time,
    value: value ?? this.value,
    unit: unit ?? this.unit,
    note: note != null ? note() : this.note,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );

  @override
  Map<String, Object?> toJson() => {
    'id': id,
    'date': date.toIso(),
    'time': _formatTime(time),
    'value': value,
    'unit': unit.json,
    'note': note,
    ..._stamps(this),
  };

  static WeightEntry? fromJson(
    Object? json,
    String path,
    Issues issues,
    DateTime now,
  ) {
    final r = JsonReader.of(json, path, issues);
    if (r == null) return null;
    final before = issues.errors.length;
    r.warnUnknownKeys({..._stampKeys, 'date', 'time', 'value', 'unit', 'note'});
    final id = readId(r);
    final date = r.date('date', required: true);
    final time = r.time('time');
    final value = r.number('value', required: true, min: 0, exclusiveMin: true);
    final unit = r.enumValue('unit', WeightUnit.byJson, required: true);
    final note = r.string('note', maxLength: 2000);
    final created = r.instant('created_at') ?? now;
    final updated = r.instant('updated_at') ?? created;
    if (value != null && unit != null) {
      final kg = unit.toKg(value);
      if (kg < minKg || kg > maxKg) {
        issues.error('$path.value', 'must correspond to 1–700 kg');
      }
    }
    if (issues.errors.length != before) return null;
    return WeightEntry(
      id: id,
      date: date!,
      time: time,
      value: value!,
      unit: unit!,
      note: note,
      createdAt: created,
      updatedAt: updated,
    );
  }
}

/// A freely named symptom with an intensity from 0 to 10.
class SymptomEntry implements DatedRecord {
  SymptomEntry({
    required this.id,
    required this.date,
    required this.time,
    required this.name,
    required this.intensity,
    this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SymptomEntry.create({
    required LocalDate date,
    required int? time,
    required String name,
    required int intensity,
    String? note,
    required DateTime now,
  }) => SymptomEntry(
    id: newId(),
    date: date,
    time: time,
    name: name,
    intensity: intensity,
    note: note,
    createdAt: now,
    updatedAt: now,
  );

  @override
  final String id;
  @override
  final LocalDate date;
  @override
  final int? time;
  final String name;
  final int intensity;
  final String? note;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;

  static const int maxNameLength = 60;

  /// Case-insensitive key used to group entries of the same symptom.
  String get nameKey => normalizeSymptomName(name);

  SymptomEntry copyWith({
    LocalDate? date,
    int? Function()? time,
    String? name,
    int? intensity,
    String? Function()? note,
    required DateTime updatedAt,
  }) => SymptomEntry(
    id: id,
    date: date ?? this.date,
    time: time != null ? time() : this.time,
    name: name ?? this.name,
    intensity: intensity ?? this.intensity,
    note: note != null ? note() : this.note,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );

  @override
  Map<String, Object?> toJson() => {
    'id': id,
    'date': date.toIso(),
    'time': _formatTime(time),
    'name': name,
    'intensity': intensity,
    'note': note,
    ..._stamps(this),
  };

  static SymptomEntry? fromJson(
    Object? json,
    String path,
    Issues issues,
    DateTime now,
  ) {
    final r = JsonReader.of(json, path, issues);
    if (r == null) return null;
    final before = issues.errors.length;
    r.warnUnknownKeys({
      ..._stampKeys,
      'date',
      'time',
      'name',
      'intensity',
      'note',
    });
    final id = readId(r);
    final date = r.date('date', required: true);
    final time = r.time('time');
    final name = r.string('name', required: true, maxLength: maxNameLength);
    final intensity = r.integer('intensity', required: true, min: 0, max: 10);
    final note = r.string('note', maxLength: 2000);
    final created = r.instant('created_at') ?? now;
    final updated = r.instant('updated_at') ?? created;
    if (issues.errors.length != before) return null;
    return SymptomEntry(
      id: id,
      date: date!,
      time: time,
      name: name!,
      intensity: intensity!,
      note: note,
      createdAt: created,
      updatedAt: updated,
    );
  }
}

String normalizeSymptomName(String name) =>
    name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
