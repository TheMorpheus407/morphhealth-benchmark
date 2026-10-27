import 'nutrition.dart';
import 'utils.dart';

class Goals {
  const Goals({
    this.waterMl,
    this.calories,
    this.protein,
    this.carbs,
    this.fat,
  });

  final double? waterMl;
  final double? calories;
  final double? protein;
  final double? carbs;
  final double? fat;

  double? forNutrient(Nutrient nutrient) => switch (nutrient) {
    Nutrient.calories => calories,
    Nutrient.protein => protein,
    Nutrient.carbs => carbs,
    Nutrient.fat => fat,
    _ => null,
  };

  Map<String, dynamic> toJson() => {
    'water_ml': waterMl,
    'calories': calories,
    'protein': protein,
    'carbs': carbs,
    'fat': fat,
  };

  factory Goals.fromJson(Object? value) {
    final json = jsonMap(value, 'settings.goals');
    return Goals(
      waterMl: jsonOptionalDouble(
        json['water_ml'],
        'settings.goals.water_ml',
        min: 0,
      ),
      calories: jsonOptionalDouble(
        json['calories'],
        'settings.goals.calories',
        min: 0,
      ),
      protein: jsonOptionalDouble(
        json['protein'],
        'settings.goals.protein',
        min: 0,
      ),
      carbs: jsonOptionalDouble(json['carbs'], 'settings.goals.carbs', min: 0),
      fat: jsonOptionalDouble(json['fat'], 'settings.goals.fat', min: 0),
    );
  }
}

class Settings {
  const Settings({
    this.language = 'de',
    this.weightUnit = 'kg',
    this.showNutrition = true,
    this.showCycle = true,
    this.showWeight = true,
    this.showSymptoms = true,
    this.onlineEnabled = true,
    this.cycleForecastEnabled = true,
    this.goals = const Goals(),
  });

  final String language;
  final String weightUnit;
  final bool showNutrition;
  final bool showCycle;
  final bool showWeight;
  final bool showSymptoms;
  final bool onlineEnabled;
  final bool cycleForecastEnabled;
  final Goals goals;

  Settings copyWith({
    String? language,
    String? weightUnit,
    bool? showNutrition,
    bool? showCycle,
    bool? showWeight,
    bool? showSymptoms,
    bool? onlineEnabled,
    bool? cycleForecastEnabled,
    Goals? goals,
  }) => Settings(
    language: language ?? this.language,
    weightUnit: weightUnit ?? this.weightUnit,
    showNutrition: showNutrition ?? this.showNutrition,
    showCycle: showCycle ?? this.showCycle,
    showWeight: showWeight ?? this.showWeight,
    showSymptoms: showSymptoms ?? this.showSymptoms,
    onlineEnabled: onlineEnabled ?? this.onlineEnabled,
    cycleForecastEnabled: cycleForecastEnabled ?? this.cycleForecastEnabled,
    goals: goals ?? this.goals,
  );

  Map<String, dynamic> toJson() => {
    'language': language,
    'weight_unit': weightUnit,
    'show_nutrition': showNutrition,
    'show_cycle': showCycle,
    'show_weight': showWeight,
    'show_symptoms': showSymptoms,
    'online_enabled': onlineEnabled,
    'cycle_forecast_enabled': cycleForecastEnabled,
    'goals': goals.toJson(),
  };

  factory Settings.fromJson(Object? value) {
    final json = jsonMap(value, 'settings');
    final language = jsonString(json['language'], 'settings.language');
    final weightUnit = jsonString(json['weight_unit'], 'settings.weight_unit');
    if (!{'de', 'en'}.contains(language) ||
        !{'kg', 'lb'}.contains(weightUnit)) {
      throw FormatException('settings contain an unsupported locale or unit');
    }
    return Settings(
      language: language,
      weightUnit: weightUnit,
      showNutrition: jsonBool(
        json['show_nutrition'],
        'settings.show_nutrition',
      ),
      showCycle: jsonBool(json['show_cycle'], 'settings.show_cycle'),
      showWeight: jsonBool(json['show_weight'], 'settings.show_weight'),
      showSymptoms: jsonBool(json['show_symptoms'], 'settings.show_symptoms'),
      onlineEnabled: jsonBool(
        json['online_enabled'],
        'settings.online_enabled',
      ),
      cycleForecastEnabled: jsonBool(
        json['cycle_forecast_enabled'],
        'settings.cycle_forecast_enabled',
      ),
      goals: Goals.fromJson(json['goals']),
    );
  }
}

class Period {
  const Period({
    required this.id,
    required this.start,
    required this.end,
    required this.flow,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String start;
  final String? end;
  final String flow;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool contains(String date, String today) {
    if (date.compareTo(start) < 0 || (end == null && date.compareTo(today) > 0))
      return false;
    return end == null || date.compareTo(end!) <= 0;
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'start': start,
    'end': end,
    'flow': flow,
    'notes': notes,
    'created_at': formatInstant(createdAt),
    'updated_at': formatInstant(updatedAt),
  };

  factory Period.fromJson(Object? value, [String path = 'period']) {
    final json = jsonMap(value, path);
    final start = jsonString(json['start'], '$path.start');
    parseDate(start, '$path.start');
    final end = jsonOptionalString(json['end'], '$path.end');
    if (end != null) {
      parseDate(end, '$path.end');
      if (end.compareTo(start) < 0)
        throw FormatException('$path.end precedes start');
    }
    final flow = jsonString(json['flow'], '$path.flow');
    if (!{'spotting', 'light', 'medium', 'heavy'}.contains(flow)) {
      throw FormatException('$path.flow is invalid');
    }
    return Period(
      id: jsonString(json['id'], '$path.id'),
      start: start,
      end: end,
      flow: flow,
      notes: jsonString(json['notes'], '$path.notes', allowEmpty: true),
      createdAt: parseInstant(json['created_at'], '$path.created_at'),
      updatedAt: parseInstant(json['updated_at'], '$path.updated_at'),
    );
  }
}

class WeightEntry {
  const WeightEntry({
    required this.id,
    required this.date,
    required this.kg,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String date;
  final double kg;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  double get pounds => kg * 2.2046226218;

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date,
    'kg': kg,
    'notes': notes,
    'created_at': formatInstant(createdAt),
    'updated_at': formatInstant(updatedAt),
  };

  factory WeightEntry.fromJson(Object? value, [String path = 'weight']) {
    final json = jsonMap(value, path);
    final date = jsonString(json['date'], '$path.date');
    parseDate(date, '$path.date');
    return WeightEntry(
      id: jsonString(json['id'], '$path.id'),
      date: date,
      kg: jsonDouble(json['kg'], '$path.kg', min: 0.000001, max: 2000),
      notes: jsonString(json['notes'], '$path.notes', allowEmpty: true),
      createdAt: parseInstant(json['created_at'], '$path.created_at'),
      updatedAt: parseInstant(json['updated_at'], '$path.updated_at'),
    );
  }
}

class SymptomEntry {
  const SymptomEntry({
    required this.id,
    required this.name,
    required this.intensity,
    required this.occurredAt,
    required this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String name;
  final int intensity;
  final DateTime occurredAt;
  final String notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'intensity': intensity,
    'occurred_at': formatInstant(occurredAt),
    'notes': notes,
    'created_at': formatInstant(createdAt),
    'updated_at': formatInstant(updatedAt),
  };

  factory SymptomEntry.fromJson(Object? value, [String path = 'symptom']) {
    final json = jsonMap(value, path);
    return SymptomEntry(
      id: jsonString(json['id'], '$path.id'),
      name: jsonString(json['name'], '$path.name'),
      intensity: jsonInt(json['intensity'], '$path.intensity', min: 0, max: 10),
      occurredAt: parseInstant(json['occurred_at'], '$path.occurred_at'),
      notes: jsonString(json['notes'], '$path.notes', allowEmpty: true),
      createdAt: parseInstant(json['created_at'], '$path.created_at'),
      updatedAt: parseInstant(json['updated_at'], '$path.updated_at'),
    );
  }
}

class AppState {
  const AppState({
    required this.foods,
    required this.intakes,
    required this.periods,
    required this.weights,
    required this.symptoms,
    required this.settings,
  });

  factory AppState.initial() => const AppState(
    foods: [],
    intakes: [],
    periods: [],
    weights: [],
    symptoms: [],
    settings: Settings(),
  );

  final List<Food> foods;
  final List<IntakeEntry> intakes;
  final List<Period> periods;
  final List<WeightEntry> weights;
  final List<SymptomEntry> symptoms;
  final Settings settings;

  AppState copyWith({
    List<Food>? foods,
    List<IntakeEntry>? intakes,
    List<Period>? periods,
    List<WeightEntry>? weights,
    List<SymptomEntry>? symptoms,
    Settings? settings,
  }) => AppState(
    foods: foods ?? this.foods,
    intakes: intakes ?? this.intakes,
    periods: periods ?? this.periods,
    weights: weights ?? this.weights,
    symptoms: symptoms ?? this.symptoms,
    settings: settings ?? this.settings,
  );

  Map<String, dynamic> toJson() => {
    'schema_version': 1,
    'foods': foods.map((item) => item.toJson()).toList(),
    'intakes': intakes.map((item) => item.toJson()).toList(),
    'periods': periods.map((item) => item.toJson()).toList(),
    'weights': weights.map((item) => item.toJson()).toList(),
    'symptoms': symptoms.map((item) => item.toJson()).toList(),
    'settings': settings.toJson(),
  };

  factory AppState.fromJson(Object? value) {
    final json = jsonMap(value, 'state');
    if (jsonInt(json['schema_version'], 'state.schema_version') != 1) {
      throw const FormatException('Unsupported state schema');
    }
    List<T> parseList<T>(String key, T Function(Object?, String) parser) =>
        jsonList(json[key], 'state.$key')
            .toList()
            .asMap()
            .entries
            .map((entry) => parser(entry.value, 'state.$key[${entry.key}]'))
            .toList();

    final state = AppState(
      foods: parseList('foods', (value, path) => Food.fromJson(value, path)),
      intakes: parseList(
        'intakes',
        (value, path) => IntakeEntry.fromJson(value, path),
      ),
      periods: parseList(
        'periods',
        (value, path) => Period.fromJson(value, path),
      ),
      weights: parseList(
        'weights',
        (value, path) => WeightEntry.fromJson(value, path),
      ),
      symptoms: parseList(
        'symptoms',
        (value, path) => SymptomEntry.fromJson(value, path),
      ),
      settings: Settings.fromJson(json['settings']),
    );
    state.validate();
    return state;
  }

  void validate() {
    for (final collection in [foods, intakes, periods, weights, symptoms]) {
      final ids = collection
          .map((item) => (item as dynamic).id as String)
          .toSet();
      if (ids.length != collection.length)
        throw const FormatException('Duplicate entry IDs');
    }
    final foodIds = foods.map((food) => food.id).toSet();
    for (final intake in intakes) {
      if (intake.kind == IntakeKind.food &&
          (intake.foodId == null || intake.foodName.trim().isEmpty)) {
        throw const FormatException(
          'Food intake needs a food ID and name snapshot',
        );
      }
      if (intake.foodId != null && !foodIds.contains(intake.foodId)) {
        throw FormatException('Intake ${intake.id} references a missing food');
      }
    }
    final sortedPeriods = [...periods]
      ..sort((a, b) => a.start.compareTo(b.start));
    for (var index = 1; index < sortedPeriods.length; index++) {
      final previous = sortedPeriods[index - 1];
      final current = sortedPeriods[index];
      if (previous.end == null || current.start.compareTo(previous.end!) <= 0) {
        throw const FormatException('Periods must not overlap');
      }
    }
  }
}
