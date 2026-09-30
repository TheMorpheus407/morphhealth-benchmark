import '../util/json_reader.dart';
import 'enums.dart';

/// Optional daily goals chosen by the user. A null value means "no goal".
class Goals {
  const Goals({
    this.energyKcal,
    this.proteinG,
    this.carbohydratesG,
    this.fatG,
    this.waterMl,
  });

  final double? energyKcal;
  final double? proteinG;
  final double? carbohydratesG;
  final double? fatG;
  final double? waterMl;

  static const Map<String, double> maxima = {
    'energy_kcal': 20000,
    'protein_g': 2000,
    'carbohydrates_g': 2000,
    'fat_g': 2000,
    'water_ml': 20000,
  };

  /// Goal for a nutrient key (`energy_kcal`, `protein_g`, …) or `water_ml`.
  double? forKey(String key) => switch (key) {
    'energy_kcal' => energyKcal,
    'protein_g' => proteinG,
    'carbohydrates_g' => carbohydratesG,
    'fat_g' => fatG,
    'water_ml' => waterMl,
    _ => null,
  };

  bool get isEmpty =>
      energyKcal == null &&
      proteinG == null &&
      carbohydratesG == null &&
      fatG == null &&
      waterMl == null;

  Goals withKey(String key, double? value) => Goals(
    energyKcal: key == 'energy_kcal' ? value : energyKcal,
    proteinG: key == 'protein_g' ? value : proteinG,
    carbohydratesG: key == 'carbohydrates_g' ? value : carbohydratesG,
    fatG: key == 'fat_g' ? value : fatG,
    waterMl: key == 'water_ml' ? value : waterMl,
  );

  Map<String, Object?> toJson() => {
    'energy_kcal': energyKcal,
    'protein_g': proteinG,
    'carbohydrates_g': carbohydratesG,
    'fat_g': fatG,
    'water_ml': waterMl,
  };

  static Goals read(JsonReader? r) {
    if (r == null) return const Goals();
    r.warnUnknownKeys(maxima.keys.toSet());
    double? g(String key) =>
        r.number(key, min: 0, exclusiveMin: true, max: maxima[key]);
    return Goals(
      energyKcal: g('energy_kcal'),
      proteinG: g('protein_g'),
      carbohydratesG: g('carbohydrates_g'),
      fatG: g('fat_g'),
      waterMl: g('water_ml'),
    );
  }
}

/// User preferences that are part of the portable data set.
class Settings {
  const Settings({
    this.language = AppLanguage.de,
    this.weightUnit = WeightUnit.kg,
    this.overviewAreas = const {
      Area.nutrition,
      Area.cycle,
      Area.weight,
      Area.symptoms,
    },
    this.waterQuickMl = defaultWaterQuickMl,
    this.caffeineQuickMg = defaultCaffeineQuickMg,
    this.cyclePredictions = true,
    this.onlineFoodSearch = true,
    this.goals = const Goals(),
  });

  static const List<int> defaultWaterQuickMl = [150, 250, 330, 500];
  static const List<int> defaultCaffeineQuickMg = [40, 80, 120];

  final AppLanguage language;
  final WeightUnit weightUnit;

  /// Areas shown on the overview.
  final Set<Area> overviewAreas;

  /// Quick-add buttons for water (ml).
  final List<int> waterQuickMl;

  /// Quick-add buttons for additional caffeine (mg).
  final List<int> caffeineQuickMg;

  /// When false the cycle tracker works as a pure diary without estimates.
  final bool cyclePredictions;

  /// When false the app never contacts the online food database.
  final bool onlineFoodSearch;

  final Goals goals;

  Settings copyWith({
    AppLanguage? language,
    WeightUnit? weightUnit,
    Set<Area>? overviewAreas,
    List<int>? waterQuickMl,
    List<int>? caffeineQuickMg,
    bool? cyclePredictions,
    bool? onlineFoodSearch,
    Goals? goals,
  }) => Settings(
    language: language ?? this.language,
    weightUnit: weightUnit ?? this.weightUnit,
    overviewAreas: overviewAreas ?? this.overviewAreas,
    waterQuickMl: waterQuickMl ?? this.waterQuickMl,
    caffeineQuickMg: caffeineQuickMg ?? this.caffeineQuickMg,
    cyclePredictions: cyclePredictions ?? this.cyclePredictions,
    onlineFoodSearch: onlineFoodSearch ?? this.onlineFoodSearch,
    goals: goals ?? this.goals,
  );

  Map<String, Object?> toJson() => {
    'language': language.json,
    'weight_unit': weightUnit.json,
    'overview_areas': [
      for (final a in Area.values)
        if (overviewAreas.contains(a)) a.json,
    ],
    'water_quick_ml': waterQuickMl,
    'caffeine_quick_mg': caffeineQuickMg,
    'cycle_predictions': cyclePredictions,
    'online_food_search': onlineFoodSearch,
    'goals': goals.toJson(),
  };

  static Settings read(JsonReader? r) {
    if (r == null) return const Settings();
    r.warnUnknownKeys({
      'language',
      'weight_unit',
      'overview_areas',
      'water_quick_ml',
      'caffeine_quick_mg',
      'cycle_predictions',
      'online_food_search',
      'goals',
    });
    final language = r.enumValue('language', AppLanguage.byJson);
    final weightUnit = r.enumValue('weight_unit', WeightUnit.byJson);
    Set<Area>? areas;
    final al = r.list('overview_areas');
    if (al != null) {
      areas = {};
      for (var i = 0; i < al.length; i++) {
        final a = al[i] is String ? Area.byJson[al[i]] : null;
        if (a == null) {
          r.issues.error(
            '${r.path}.overview_areas[$i]',
            'expected one of ${Area.byJson.keys.join(', ')}',
          );
        } else {
          areas.add(a);
        }
      }
    }
    List<int>? quick(String key, int max) {
      final l = r.list(key);
      if (l == null) return null;
      final result = <int>[];
      for (var i = 0; i < l.length; i++) {
        final v = l[i];
        if (v is num && v == v.roundToDouble() && v > 0 && v <= max) {
          result.add(v.toInt());
        } else {
          r.issues.error(
            '${r.path}.$key[$i]',
            'expected an integer between 1 and $max',
          );
        }
      }
      if (result.length > 6) {
        r.issues.error('${r.path}.$key', 'at most 6 values');
      }
      return result;
    }

    final water = quick('water_quick_ml', 5000);
    final caffeine = quick('caffeine_quick_mg', 1000);
    return Settings(
      language: language ?? AppLanguage.de,
      weightUnit: weightUnit ?? WeightUnit.kg,
      overviewAreas: areas ?? const Settings().overviewAreas,
      waterQuickMl: water ?? defaultWaterQuickMl,
      caffeineQuickMg: caffeine ?? defaultCaffeineQuickMg,
      cyclePredictions: r.boolean('cycle_predictions') ?? true,
      onlineFoodSearch: r.boolean('online_food_search') ?? true,
      goals: Goals.read(r.object('goals')),
    );
  }
}
