import '../util/json_reader.dart';

/// The four areas of the app. They can be shown or hidden on the overview.
enum Area {
  nutrition,
  cycle,
  weight,
  symptoms;

  String get code => name;

  static Area? byCode(String? code) {
    for (final v in values) {
      if (v.name == code) return v;
    }
    return null;
  }

  static Iterable<String> get codes => values.map((e) => e.name);
}

/// The user's decision about the online food lookup.
enum OnlineFoodSearch {
  /// Not decided yet; the app asks before the first request.
  ask,
  enabled,
  disabled;

  String get code => name;

  static OnlineFoodSearch? byCode(String? code) {
    for (final v in values) {
      if (v.name == code) return v;
    }
    return null;
  }

  static Iterable<String> get codes => values.map((e) => e.name);
}

/// Preferences that belong to the user's data and travel with exports and
/// backups.
class Settings {
  static const List<String> languages = ['de', 'en'];
  static const List<String> weightUnits = ['kg', 'lb'];
  static const List<String> themes = ['system', 'light', 'dark'];
  static const List<int> defaultWaterQuickAmounts = [150, 250, 330, 500];
  static const int minCycleLength = 15;
  static const int maxCycleLength = 90;

  /// `de` (default) or `en`.
  final String language;

  /// `kg` or `lb`: unit for entering and showing weights.
  final String weightUnit;

  /// `system`, `light` or `dark`.
  final String theme;

  /// Areas shown on the overview.
  final Set<Area> overviewSections;

  /// False: the period tracker is used as a diary only, without estimates.
  final bool cyclePredictions;

  /// Cycle length the user states as typical; used only while fewer than
  /// three own cycles are recorded.
  final int? typicalCycleLengthDays;

  final OnlineFoodSearch onlineFoodSearch;

  /// Amounts offered for adding water with one tap, in millilitres.
  final List<int> waterQuickAmountsMl;

  const Settings({
    this.language = 'de',
    this.weightUnit = 'kg',
    this.theme = 'system',
    this.overviewSections = const {
      Area.nutrition,
      Area.cycle,
      Area.weight,
      Area.symptoms,
    },
    this.cyclePredictions = true,
    this.typicalCycleLengthDays,
    this.onlineFoodSearch = OnlineFoodSearch.ask,
    this.waterQuickAmountsMl = defaultWaterQuickAmounts,
  });

  Settings copyWith({
    String? language,
    String? weightUnit,
    String? theme,
    Set<Area>? overviewSections,
    bool? cyclePredictions,
    Object? typicalCycleLengthDays = _keep,
    OnlineFoodSearch? onlineFoodSearch,
    List<int>? waterQuickAmountsMl,
  }) => Settings(
    language: language ?? this.language,
    weightUnit: weightUnit ?? this.weightUnit,
    theme: theme ?? this.theme,
    overviewSections: overviewSections ?? this.overviewSections,
    cyclePredictions: cyclePredictions ?? this.cyclePredictions,
    typicalCycleLengthDays: identical(typicalCycleLengthDays, _keep)
        ? this.typicalCycleLengthDays
        : typicalCycleLengthDays as int?,
    onlineFoodSearch: onlineFoodSearch ?? this.onlineFoodSearch,
    waterQuickAmountsMl: waterQuickAmountsMl ?? this.waterQuickAmountsMl,
  );

  Map<String, dynamic> toJson() => {
    'language': language,
    'weight_unit': weightUnit,
    'theme': theme,
    'overview_sections': [
      for (final a in Area.values)
        if (overviewSections.contains(a)) a.code,
    ],
    'cycle_predictions': cyclePredictions,
    'typical_cycle_length_days': typicalCycleLengthDays,
    'online_food_search': onlineFoodSearch.code,
    'water_quick_amounts_ml': waterQuickAmountsMl,
  };

  /// Reads settings; every missing member keeps its default.
  static Settings fromJson(ObjectReader? r) {
    const d = Settings();
    if (r == null) return d;
    final language = r.choice('language', languages);
    final weightUnit = r.choice('weight_unit', weightUnits);
    final theme = r.choice('theme', themes);
    Set<Area>? sections;
    final list = r.list('overview_sections');
    if (list != null) {
      sections = {};
      for (var i = 0; i < list.length; i++) {
        final a = list[i] is String ? Area.byCode(list[i] as String) : null;
        if (a == null) {
          r.log.error(
            '${r.path}.overview_sections[$i]',
            'must be one of: ${Area.codes.join(', ')}',
          );
        } else {
          sections.add(a);
        }
      }
    }
    final predictions = r.boolean('cycle_predictions');
    final typical = r.integer(
      'typical_cycle_length_days',
      min: minCycleLength,
      max: maxCycleLength,
    );
    final online = r.choice('online_food_search', OnlineFoodSearch.codes);
    List<int>? quick;
    final q = r.list('water_quick_amounts_ml');
    if (q != null) {
      quick = [];
      for (var i = 0; i < q.length; i++) {
        final v = q[i];
        if (v is num && v == v.roundToDouble() && v >= 10 && v <= 5000) {
          if (!quick.contains(v.toInt())) quick.add(v.toInt());
        } else {
          r.log.error(
            '${r.path}.water_quick_amounts_ml[$i]',
            'must be a whole number of millilitres from 10 to 5000',
          );
        }
      }
      if (quick.length > 6) {
        r.log.error(
          '${r.path}.water_quick_amounts_ml',
          'must have at most 6 amounts',
        );
      }
      if (quick.isEmpty) quick = null;
    }
    r.warnUnknown();
    return Settings(
      language: language ?? d.language,
      weightUnit: weightUnit ?? d.weightUnit,
      theme: theme ?? d.theme,
      overviewSections: sections ?? d.overviewSections,
      cyclePredictions: predictions ?? d.cyclePredictions,
      typicalCycleLengthDays: typical,
      onlineFoodSearch: OnlineFoodSearch.byCode(online) ?? d.onlineFoodSearch,
      waterQuickAmountsMl: quick ?? d.waterQuickAmountsMl,
    );
  }
}

/// Voluntary daily goals. Null means "no goal".
class Goals {
  final double? waterMl;
  final double? energyKcal;
  final double? proteinG;
  final double? carbohydratesG;
  final double? fatG;

  const Goals({
    this.waterMl,
    this.energyKcal,
    this.proteinG,
    this.carbohydratesG,
    this.fatG,
  });

  bool get isEmpty =>
      waterMl == null &&
      energyKcal == null &&
      proteinG == null &&
      carbohydratesG == null &&
      fatG == null;

  Map<String, dynamic> toJson() => {
    'water_ml': _n(waterMl),
    'energy_kcal': _n(energyKcal),
    'protein_g': _n(proteinG),
    'carbohydrates_g': _n(carbohydratesG),
    'fat_g': _n(fatG),
  };

  static num? _n(double? v) => v == null ? null : roundForJson(v);

  static Goals fromJson(ObjectReader? r) {
    if (r == null) return const Goals();
    final g = Goals(
      waterMl: r.number('water_ml', min: 0, max: 20000, exclusiveMin: true),
      energyKcal: r.number(
        'energy_kcal',
        min: 0,
        max: 20000,
        exclusiveMin: true,
      ),
      proteinG: r.number('protein_g', min: 0, max: 2000, exclusiveMin: true),
      carbohydratesG: r.number(
        'carbohydrates_g',
        min: 0,
        max: 5000,
        exclusiveMin: true,
      ),
      fatG: r.number('fat_g', min: 0, max: 2000, exclusiveMin: true),
    );
    r.warnUnknown();
    return g;
  }
}

/// State that belongs to this installation only. It is stored encrypted with
/// the other data but is not part of exports and backups.
class LocalState {
  /// The welcome screen has been completed.
  final bool onboardingDone;

  /// Food service origin chosen in the app instead of the built-in one.
  final String? foodApiBaseUrl;

  const LocalState({this.onboardingDone = false, this.foodApiBaseUrl});

  LocalState copyWith({bool? onboardingDone, Object? foodApiBaseUrl = _keep}) =>
      LocalState(
        onboardingDone: onboardingDone ?? this.onboardingDone,
        foodApiBaseUrl: identical(foodApiBaseUrl, _keep)
            ? this.foodApiBaseUrl
            : foodApiBaseUrl as String?,
      );

  Map<String, dynamic> toJson() => {
    'onboarding_done': onboardingDone,
    if (foodApiBaseUrl != null) 'food_api_base_url': foodApiBaseUrl,
  };

  static LocalState fromJson(ObjectReader? r) {
    if (r == null) return const LocalState();
    return LocalState(
      onboardingDone: r.boolean('onboarding_done') ?? false,
      foodApiBaseUrl: r.string('food_api_base_url', maxLength: 300),
    );
  }
}

const Object _keep = Object();
