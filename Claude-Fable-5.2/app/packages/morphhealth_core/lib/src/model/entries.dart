import '../util/dates.dart';
import '../util/json_reader.dart';
import 'food.dart';

/// The meal a consumed food belongs to.
enum Meal {
  breakfast,
  lunch,
  dinner,
  snack;

  String get code => name;

  static Meal? byCode(String? code) {
    for (final v in values) {
      if (v.name == code) return v;
    }
    return null;
  }

  static Iterable<String> get codes => values.map((e) => e.name);

  /// A sensible default for an entry made at [time].
  static Meal suggestFor(LocalDateTime time) {
    final minutes = time.hour * 60 + time.minute;
    if (minutes >= 4 * 60 && minutes < 10 * 60 + 30) return Meal.breakfast;
    if (minutes >= 10 * 60 + 30 && minutes < 14 * 60 + 30) return Meal.lunch;
    if (minutes >= 17 * 60 + 30 && minutes < 22 * 60) return Meal.dinner;
    return Meal.snack;
  }
}

/// Unit in which the amount of a diary entry was entered.
enum AmountUnit {
  g,
  ml,
  portion;

  String get code => name;

  static AmountUnit? byCode(String? code) {
    for (final v in values) {
      if (v.name == code) return v;
    }
    return null;
  }

  static Iterable<String> get codes => values.map((e) => e.name);
}

/// One consumed food ("Verzehreintrag").
class IntakeEntry {
  final String id;
  final String foodId;
  final LocalDateTime at;
  final Meal meal;

  /// Amount in [unit].
  final double amount;
  final AmountUnit unit;

  /// For [AmountUnit.portion]: size of one portion in the food's basis unit
  /// (g or ml) as it was when the entry was made. Keeps old entries stable
  /// when the portion size of the food is changed later.
  final double? portionSize;

  final String? note;
  final LocalDateTime createdAt;
  final LocalDateTime updatedAt;

  const IntakeEntry({
    required this.id,
    required this.foodId,
    required this.at,
    required this.meal,
    required this.amount,
    required this.unit,
    this.portionSize,
    this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  Day get day => at.day;

  /// The consumed quantity in the basis unit of [food] (g or ml).
  ///
  /// Grams and millilitres are converted with the food's density (1 g per ml
  /// unless the food says otherwise). Returns null for a portion entry when
  /// neither the entry nor the food defines a portion size.
  double? basisQuantity(Food food) {
    switch (unit) {
      case AmountUnit.g:
        return food.basis == FoodBasis.per100g ? amount : amount / food.density;
      case AmountUnit.ml:
        return food.basis == FoodBasis.per100ml
            ? amount
            : amount * food.density;
      case AmountUnit.portion:
        final size = portionSize ?? food.servingSize;
        return size == null ? null : amount * size;
    }
  }

  IntakeEntry copyWith({
    String? id,
    String? foodId,
    LocalDateTime? at,
    Meal? meal,
    double? amount,
    AmountUnit? unit,
    Object? portionSize = _keep,
    Object? note = _keep,
    LocalDateTime? createdAt,
    LocalDateTime? updatedAt,
  }) => IntakeEntry(
    id: id ?? this.id,
    foodId: foodId ?? this.foodId,
    at: at ?? this.at,
    meal: meal ?? this.meal,
    amount: amount ?? this.amount,
    unit: unit ?? this.unit,
    portionSize: identical(portionSize, _keep)
        ? this.portionSize
        : portionSize as double?,
    note: identical(note, _keep) ? this.note : note as String?,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'food_id': foodId,
    'at': at.toIso(),
    'meal': meal.code,
    'amount': roundForJson(amount),
    'unit': unit.code,
    if (portionSize != null) 'portion_size': roundForJson(portionSize!),
    if (note != null) 'note': note,
    'created_at': createdAt.toIso(),
    'updated_at': updatedAt.toIso(),
  };

  static IntakeEntry? fromJson(
    ObjectReader r, {
    required LocalDateTime now,
    required String Function() idFactory,
  }) {
    final before = r.log.errorCount;
    final id = r.string('id', maxLength: 100) ?? idFactory();
    final foodId = r.string('food_id', required: true, maxLength: 100);
    final at = r.dateTime('at', required: true);
    final mealCode = r.choice('meal', Meal.codes);
    final amount = r.number(
      'amount',
      required: true,
      min: 0,
      max: 100000,
      exclusiveMin: true,
    );
    final unitCode = r.choice('unit', AmountUnit.codes, required: true);
    final portionSize = r.number(
      'portion_size',
      min: 0,
      max: 100000,
      exclusiveMin: true,
    );
    final note = r.string('note', maxLength: 2000);
    final createdAt = r.dateTime('created_at') ?? at ?? now;
    final updatedAt = r.dateTime('updated_at') ?? createdAt;
    r.warnUnknown();
    if (r.log.errorCount != before ||
        foodId == null ||
        at == null ||
        amount == null ||
        unitCode == null) {
      return null;
    }
    return IntakeEntry(
      id: id,
      foodId: foodId,
      at: at,
      meal: Meal.byCode(mealCode) ?? Meal.suggestFor(at),
      amount: amount,
      unit: AmountUnit.byCode(unitCode)!,
      portionSize: portionSize,
      note: note,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

/// Water drunk, in millilitres.
class WaterEntry {
  final String id;
  final LocalDateTime at;
  final double amountMl;
  final LocalDateTime createdAt;
  final LocalDateTime updatedAt;

  const WaterEntry({
    required this.id,
    required this.at,
    required this.amountMl,
    required this.createdAt,
    required this.updatedAt,
  });

  Day get day => at.day;

  WaterEntry copyWith({
    LocalDateTime? at,
    double? amountMl,
    LocalDateTime? updatedAt,
  }) => WaterEntry(
    id: id,
    at: at ?? this.at,
    amountMl: amountMl ?? this.amountMl,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'at': at.toIso(),
    'amount_ml': roundForJson(amountMl),
    'created_at': createdAt.toIso(),
    'updated_at': updatedAt.toIso(),
  };

  static WaterEntry? fromJson(
    ObjectReader r, {
    required LocalDateTime now,
    required String Function() idFactory,
  }) {
    final before = r.log.errorCount;
    final id = r.string('id', maxLength: 100) ?? idFactory();
    final at = r.dateTime('at', required: true);
    final amount = r.number(
      'amount_ml',
      required: true,
      min: 0,
      max: 20000,
      exclusiveMin: true,
    );
    final createdAt = r.dateTime('created_at') ?? at ?? now;
    final updatedAt = r.dateTime('updated_at') ?? createdAt;
    r.warnUnknown();
    if (r.log.errorCount != before || at == null || amount == null) return null;
    return WaterEntry(
      id: id,
      at: at,
      amountMl: amount,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

/// Caffeine taken in addition to logged foods (coffee, tea, tablets …), in
/// milligrams.
class CaffeineEntry {
  final String id;
  final LocalDateTime at;
  final double amountMg;

  /// What it was, for example "Espresso".
  final String? label;
  final LocalDateTime createdAt;
  final LocalDateTime updatedAt;

  const CaffeineEntry({
    required this.id,
    required this.at,
    required this.amountMg,
    this.label,
    required this.createdAt,
    required this.updatedAt,
  });

  Day get day => at.day;

  CaffeineEntry copyWith({
    LocalDateTime? at,
    double? amountMg,
    Object? label = _keep,
    LocalDateTime? updatedAt,
  }) => CaffeineEntry(
    id: id,
    at: at ?? this.at,
    amountMg: amountMg ?? this.amountMg,
    label: identical(label, _keep) ? this.label : label as String?,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'at': at.toIso(),
    'amount_mg': roundForJson(amountMg),
    if (label != null) 'label': label,
    'created_at': createdAt.toIso(),
    'updated_at': updatedAt.toIso(),
  };

  static CaffeineEntry? fromJson(
    ObjectReader r, {
    required LocalDateTime now,
    required String Function() idFactory,
  }) {
    final before = r.log.errorCount;
    final id = r.string('id', maxLength: 100) ?? idFactory();
    final at = r.dateTime('at', required: true);
    final amount = r.number(
      'amount_mg',
      required: true,
      min: 0,
      max: 5000,
      exclusiveMin: true,
    );
    final label = r.string('label', maxLength: 100);
    final createdAt = r.dateTime('created_at') ?? at ?? now;
    final updatedAt = r.dateTime('updated_at') ?? createdAt;
    r.warnUnknown();
    if (r.log.errorCount != before || at == null || amount == null) return null;
    return CaffeineEntry(
      id: id,
      at: at,
      amountMg: amount,
      label: label,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

/// A body weight for a calendar day. Always stored in kilograms.
class WeightEntry {
  static const double kgPerLb = 0.45359237;
  static const double minKg = 1;
  static const double maxKg = 700;

  final String id;
  final Day date;
  final double weightKg;
  final String? note;
  final LocalDateTime createdAt;
  final LocalDateTime updatedAt;

  const WeightEntry({
    required this.id,
    required this.date,
    required this.weightKg,
    this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  double get weightLb => weightKg / kgPerLb;

  WeightEntry copyWith({
    Day? date,
    double? weightKg,
    Object? note = _keep,
    LocalDateTime? updatedAt,
  }) => WeightEntry(
    id: id,
    date: date ?? this.date,
    weightKg: weightKg ?? this.weightKg,
    note: identical(note, _keep) ? this.note : note as String?,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date.toString(),
    'weight_kg': roundForJson(weightKg),
    if (note != null) 'note': note,
    'created_at': createdAt.toIso(),
    'updated_at': updatedAt.toIso(),
  };

  static WeightEntry? fromJson(
    ObjectReader r, {
    required LocalDateTime now,
    required String Function() idFactory,
  }) {
    final before = r.log.errorCount;
    final id = r.string('id', maxLength: 100) ?? idFactory();
    final date = r.day('date', required: true);
    final kg = r.number('weight_kg', required: true, min: minKg, max: maxKg);
    final note = r.string('note', maxLength: 2000);
    final createdAt = r.dateTime('created_at') ?? now;
    final updatedAt = r.dateTime('updated_at') ?? createdAt;
    r.warnUnknown();
    if (r.log.errorCount != before || date == null || kg == null) return null;
    return WeightEntry(
      id: id,
      date: date,
      weightKg: kg,
      note: note,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

/// A symptom with a freely chosen name and an intensity from 0 to 10.
class SymptomEntry {
  final String id;
  final String name;

  /// 0 (not noticeable) … 10 (strongest).
  final int intensity;
  final LocalDateTime at;
  final String? note;
  final LocalDateTime createdAt;
  final LocalDateTime updatedAt;

  const SymptomEntry({
    required this.id,
    required this.name,
    required this.intensity,
    required this.at,
    this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  Day get day => at.day;

  /// Key under which entries of the same symptom are grouped: the name without
  /// regard to case and surrounding or repeated spaces.
  String get nameKey => normalizeName(name);

  static String normalizeName(String name) =>
      name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

  SymptomEntry copyWith({
    String? name,
    int? intensity,
    LocalDateTime? at,
    Object? note = _keep,
    LocalDateTime? updatedAt,
  }) => SymptomEntry(
    id: id,
    name: name ?? this.name,
    intensity: intensity ?? this.intensity,
    at: at ?? this.at,
    note: identical(note, _keep) ? this.note : note as String?,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'intensity': intensity,
    'at': at.toIso(),
    if (note != null) 'note': note,
    'created_at': createdAt.toIso(),
    'updated_at': updatedAt.toIso(),
  };

  static SymptomEntry? fromJson(
    ObjectReader r, {
    required LocalDateTime now,
    required String Function() idFactory,
  }) {
    final before = r.log.errorCount;
    final id = r.string('id', maxLength: 100) ?? idFactory();
    final name = r.string('name', required: true, maxLength: 80);
    final intensity = r.integer('intensity', required: true, min: 0, max: 10);
    final at = r.dateTime('at', required: true);
    final note = r.string('note', maxLength: 2000);
    final createdAt = r.dateTime('created_at') ?? at ?? now;
    final updatedAt = r.dateTime('updated_at') ?? createdAt;
    r.warnUnknown();
    if (r.log.errorCount != before ||
        name == null ||
        intensity == null ||
        at == null) {
      return null;
    }
    return SymptomEntry(
      id: id,
      name: name,
      intensity: intensity,
      at: at,
      note: note,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

/// Bleeding strength of one day.
enum FlowLevel {
  spotting,
  light,
  medium,
  heavy;

  String get code => name;

  static FlowLevel? byCode(String? code) {
    for (final v in values) {
      if (v.name == code) return v;
    }
    return null;
  }

  static Iterable<String> get codes => values.map((e) => e.name);
}

/// A menstrual period with its first and (once known) last day.
class Period {
  /// A period without end is treated as still running for this many days
  /// after its start; later it counts as "end not recorded".
  static const int openPeriodDays = 14;

  /// Longest period that can be recorded.
  static const int maxLengthDays = 60;

  final String id;
  final Day start;

  /// Last day of bleeding (inclusive); null while the period is running.
  final Day? end;

  /// Bleeding strength per day, for days within the period.
  final Map<Day, FlowLevel> flow;

  final String? note;
  final LocalDateTime createdAt;
  final LocalDateTime updatedAt;

  const Period({
    required this.id,
    required this.start,
    this.end,
    this.flow = const {},
    this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Number of days from start to end, or null while the end is open.
  int? get lengthDays => end == null ? null : end!.daysSince(start) + 1;

  /// The last day covered by this record as seen on [asOf]: the recorded end,
  /// or for an open period the day [asOf] itself, limited to
  /// [openPeriodDays].
  Day lastCoveredDay(Day asOf) {
    final e = end;
    if (e != null) return e;
    final limit = start.addDays(openPeriodDays - 1);
    if (asOf < start) return start;
    return asOf < limit ? asOf : limit;
  }

  /// Whether [day] is a day of this period as seen on [asOf].
  bool covers(Day day, Day asOf) => day >= start && day <= lastCoveredDay(asOf);

  /// Whether the period has no recorded end and is still within
  /// [openPeriodDays] on [asOf].
  bool isRunning(Day asOf) =>
      end == null && asOf >= start && asOf.daysSince(start) < openPeriodDays;

  Period copyWith({
    Day? start,
    Object? end = _keep,
    Map<Day, FlowLevel>? flow,
    Object? note = _keep,
    LocalDateTime? updatedAt,
  }) => Period(
    id: id,
    start: start ?? this.start,
    end: identical(end, _keep) ? this.end : end as Day?,
    flow: flow ?? this.flow,
    note: identical(note, _keep) ? this.note : note as String?,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  /// Removes flow values that lie outside the period.
  Period normalized() {
    final last = end ?? start.addDays(maxLengthDays - 1);
    if (flow.keys.every((d) => d >= start && d <= last)) return this;
    return copyWith(
      flow: {
        for (final e in flow.entries)
          if (e.key >= start && e.key <= last) e.key: e.value,
      },
    );
  }

  Map<String, dynamic> toJson() {
    final days = flow.keys.toList()..sort();
    return {
      'id': id,
      'start': start.toString(),
      'end': end?.toString(),
      if (flow.isNotEmpty)
        'flow': {for (final d in days) d.toString(): flow[d]!.code},
      if (note != null) 'note': note,
      'created_at': createdAt.toIso(),
      'updated_at': updatedAt.toIso(),
    };
  }

  static Period? fromJson(
    ObjectReader r, {
    required LocalDateTime now,
    required String Function() idFactory,
  }) {
    final before = r.log.errorCount;
    final id = r.string('id', maxLength: 100) ?? idFactory();
    final start = r.day('start', required: true);
    final end = r.day('end');
    if (start != null && end != null) {
      if (end < start) {
        r.log.error('${r.path}.end', 'must not be before start');
      } else if (end.daysSince(start) + 1 > maxLengthDays) {
        r.log.error(
          '${r.path}.end',
          'a period can cover at most $maxLengthDays days',
        );
      }
    }
    final flow = <Day, FlowLevel>{};
    final flowReader = r.object('flow');
    if (flowReader != null && start != null) {
      final last = end ?? start.addDays(maxLengthDays - 1);
      for (final key in flowReader.map.keys) {
        final path = '${flowReader.path}.$key';
        final d = Day.tryParse(key);
        final level = flowReader.choice(key, FlowLevel.codes);
        if (d == null) {
          r.log.error(path, 'key must be a date as YYYY-MM-DD');
        } else if (level != null) {
          if (d < start || d > last) {
            r.log.warning(path, 'lies outside the period and was ignored');
          } else {
            flow[d] = FlowLevel.byCode(level)!;
          }
        }
      }
    }
    final note = r.string('note', maxLength: 2000);
    final createdAt = r.dateTime('created_at') ?? now;
    final updatedAt = r.dateTime('updated_at') ?? createdAt;
    r.warnUnknown();
    if (r.log.errorCount != before || start == null) return null;
    return Period(
      id: id,
      start: start,
      end: end,
      flow: flow,
      note: note,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

/// Cycle diary information for a single day outside of period records:
/// spotting between periods and a free note.
class CycleDay {
  final Day date;
  final bool spotting;
  final String? note;
  final LocalDateTime updatedAt;

  const CycleDay({
    required this.date,
    this.spotting = false,
    this.note,
    required this.updatedAt,
  });

  bool get isEmpty => !spotting && (note == null || note!.isEmpty);

  Map<String, dynamic> toJson() => {
    'date': date.toString(),
    'spotting': spotting,
    if (note != null) 'note': note,
    'updated_at': updatedAt.toIso(),
  };

  static CycleDay? fromJson(ObjectReader r, {required LocalDateTime now}) {
    final before = r.log.errorCount;
    final date = r.day('date', required: true);
    final spotting = r.boolean('spotting') ?? false;
    final note = r.string('note', maxLength: 2000);
    final updatedAt = r.dateTime('updated_at') ?? now;
    r.warnUnknown();
    if (r.log.errorCount != before || date == null) return null;
    return CycleDay(
      date: date,
      spotting: spotting,
      note: note,
      updatedAt: updatedAt,
    );
  }
}

const Object _keep = Object();
