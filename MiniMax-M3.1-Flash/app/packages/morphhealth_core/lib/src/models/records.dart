import 'package:meta/meta.dart';

/// Recorded bleeding strength.
enum FlowStrength {
  none,
  spotting,
  light,
  medium,
  heavy;

  static FlowStrength parse(String? value) => FlowStrength.values.firstWhere(
        (FlowStrength f) => f.name == value,
        orElse: () => FlowStrength.medium,
      );
}

/// One recorded period (or spotting period).
@immutable
class PeriodRecord {
  const PeriodRecord({
    required this.id,
    required this.startDate,
    this.endDate,
    this.flow = FlowStrength.medium,
    this.spotting = false,
    this.note,
    this.createdAtMs = 0,
    this.updatedAtMs = 0,
  });

  final String id;

  /// Local calendar day (YYYY-MM-DD) of the first day.
  final String startDate;

  /// Local calendar day (YYYY-MM-DD) of the last day, if the period ended.
  final String? endDate;

  final FlowStrength flow;

  /// Whether this record only describes spotting.
  final bool spotting;

  final String? note;
  final int createdAtMs;
  final int updatedAtMs;

  /// Length of the period in days (inclusive) when an end date is known.
  int? get lengthDays {
    final String? end = endDate;
    if (end == null) return null;
    final int days = DateMath.dayDiff(startDate, end);
    return days < 0 ? null : days + 1;
  }

  PeriodRecord copyWith({
    String? startDate,
    String? endDate,
    bool clearEnd = false,
    FlowStrength? flow,
    bool? spotting,
    String? note,
    int? createdAtMs,
    int? updatedAtMs,
  }) {
    return PeriodRecord(
      id: id,
      startDate: startDate ?? this.startDate,
      endDate: clearEnd ? null : (endDate ?? this.endDate),
      flow: flow ?? this.flow,
      spotting: spotting ?? this.spotting,
      note: note ?? this.note,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'start_date': startDate,
        if (endDate != null) 'end_date': endDate,
        'flow': flow.name,
        'spotting': spotting,
        if (note != null) 'note': note,
        'created_at_ms': createdAtMs,
        'updated_at_ms': updatedAtMs,
      };

  static PeriodRecord fromJson(Map<String, dynamic> json) => PeriodRecord(
        id: json['id'] as String,
        startDate: json['start_date'] as String? ?? '',
        endDate: json['end_date'] as String?,
        flow: FlowStrength.parse(json['flow'] as String?),
        spotting: json['spotting'] == true,
        note: json['note'] as String?,
        createdAtMs: (json['created_at_ms'] as num?)?.toInt() ?? 0,
        updatedAtMs: (json['updated_at_ms'] as num?)?.toInt() ?? 0,
      );
}

/// A weight measurement.
@immutable
class WeightEntry {
  const WeightEntry({
    required this.id,
    required this.date,
    required this.valueKg,
    required this.loggedAtMs,
    this.note,
    this.createdAtMs = 0,
    this.updatedAtMs = 0,
  });

  final String id;
  final String date;

  /// Weight is always stored in kilograms; the display unit is a setting.
  final double valueKg;
  final int loggedAtMs;
  final String? note;
  final int createdAtMs;
  final int updatedAtMs;

  WeightEntry copyWith({
    String? date,
    double? valueKg,
    int? loggedAtMs,
    String? note,
    int? createdAtMs,
    int? updatedAtMs,
  }) {
    return WeightEntry(
      id: id,
      date: date ?? this.date,
      valueKg: valueKg ?? this.valueKg,
      loggedAtMs: loggedAtMs ?? this.loggedAtMs,
      note: note ?? this.note,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'date': date,
        'value_kg': valueKg,
        'logged_at_ms': loggedAtMs,
        if (note != null) 'note': note,
        'created_at_ms': createdAtMs,
        'updated_at_ms': updatedAtMs,
      };

  static WeightEntry fromJson(Map<String, dynamic> json) => WeightEntry(
        id: json['id'] as String,
        date: json['date'] as String? ?? '',
        valueKg: (json['value_kg'] as num?)?.toDouble() ?? 0,
        loggedAtMs: (json['logged_at_ms'] as num?)?.toInt() ?? 0,
        note: json['note'] as String?,
        createdAtMs: (json['created_at_ms'] as num?)?.toInt() ?? 0,
        updatedAtMs: (json['updated_at_ms'] as num?)?.toInt() ?? 0,
      );
}

/// A symptom with an intensity from 0 to 10.
@immutable
class SymptomEntry {
  const SymptomEntry({
    required this.id,
    required this.name,
    required this.intensity,
    required this.date,
    required this.occurredAtMs,
    this.note,
    this.createdAtMs = 0,
    this.updatedAtMs = 0,
  });

  final String id;
  final String name;

  /// 0 (barely noticeable) to 10 (very strong).
  final int intensity;
  final String date;
  final int occurredAtMs;
  final String? note;
  final int createdAtMs;
  final int updatedAtMs;

  SymptomEntry copyWith({
    String? name,
    int? intensity,
    String? date,
    int? occurredAtMs,
    String? note,
    int? createdAtMs,
    int? updatedAtMs,
  }) {
    return SymptomEntry(
      id: id,
      name: name ?? this.name,
      intensity: intensity ?? this.intensity,
      date: date ?? this.date,
      occurredAtMs: occurredAtMs ?? this.occurredAtMs,
      note: note ?? this.note,
      createdAtMs: createdAtMs ?? this.createdAtMs,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'id': id,
        'name': name,
        'intensity': intensity,
        'date': date,
        'occurred_at_ms': occurredAtMs,
        if (note != null) 'note': note,
        'created_at_ms': createdAtMs,
        'updated_at_ms': updatedAtMs,
      };

  static SymptomEntry fromJson(Map<String, dynamic> json) => SymptomEntry(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        intensity: ((json['intensity'] as num?)?.toInt() ?? 0).clamp(0, 10),
        date: json['date'] as String? ?? '',
        occurredAtMs: (json['occurred_at_ms'] as num?)?.toInt() ?? 0,
        note: json['note'] as String?,
        createdAtMs: (json['created_at_ms'] as num?)?.toInt() ?? 0,
        updatedAtMs: (json['updated_at_ms'] as num?)?.toInt() ?? 0,
      );
}

/// Optional daily goals chosen by the user.
@immutable
class Goals {
  const Goals({
    this.waterMl,
    this.caloriesKcal,
    this.proteinG,
    this.carbohydratesG,
    this.fatG,
  });

  final double? waterMl;
  final double? caloriesKcal;
  final double? proteinG;
  final double? carbohydratesG;
  final double? fatG;

  static const Goals none = Goals();

  bool get isEmpty =>
      waterMl == null &&
      caloriesKcal == null &&
      proteinG == null &&
      carbohydratesG == null &&
      fatG == null;

  Goals copyWith({
    double? waterMl,
    bool clearWater = false,
    double? caloriesKcal,
    bool clearCalories = false,
    double? proteinG,
    bool clearProtein = false,
    double? carbohydratesG,
    bool clearCarbs = false,
    double? fatG,
    bool clearFat = false,
  }) {
    return Goals(
      waterMl: clearWater ? null : (waterMl ?? this.waterMl),
      caloriesKcal:
          clearCalories ? null : (caloriesKcal ?? this.caloriesKcal),
      proteinG: clearProtein ? null : (proteinG ?? this.proteinG),
      carbohydratesG: clearCarbs ? null : (carbohydratesG ?? this.carbohydratesG),
      fatG: clearFat ? null : (fatG ?? this.fatG),
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        if (waterMl != null) 'water_ml': waterMl,
        if (caloriesKcal != null) 'calories_kcal': caloriesKcal,
        if (proteinG != null) 'protein_g': proteinG,
        if (carbohydratesG != null) 'carbohydrates_g': carbohydratesG,
        if (fatG != null) 'fat_g': fatG,
      };

  static Goals fromJson(Map<String, dynamic> json) => Goals(
        waterMl: _num(json['water_ml']),
        caloriesKcal: _num(json['calories_kcal']),
        proteinG: _num(json['protein_g']),
        carbohydratesG: _num(json['carbohydrates_g']),
        fatG: _num(json['fat_g']),
      );
}

double? _num(dynamic v) => v is num ? v.toDouble() : null;

/// The four product areas the user can show or hide in the overview.
enum AppArea {
  nutrition,
  cycle,
  weight,
  symptoms;

  static AppArea parse(String? value) => AppArea.values.firstWhere(
        (AppArea a) => a.name == value,
        orElse: () => AppArea.nutrition,
      );
}

/// Weight display unit.
enum WeightUnit {
  kg,
  lb;

  static WeightUnit parse(String? value) => WeightUnit.values.firstWhere(
        (WeightUnit u) => u.name == value,
        orElse: () => WeightUnit.kg,
      );
}

/// User settings.
@immutable
class AppSettings {
  const AppSettings({
    this.languageCode = 'de',
    this.weightUnit = WeightUnit.kg,
    this.visibleAreas = const <AppArea>{
      AppArea.nutrition,
      AppArea.cycle,
      AppArea.weight,
      AppArea.symptoms,
    },
    this.foodBaseUrlOverride,
    this.foodUserAgentOverride,
    this.waterQuickAmountsMl = const <double>[200, 250, 500],
  });

  /// `de` or `en`. German is the default.
  final String languageCode;
  final WeightUnit weightUnit;
  final Set<AppArea> visibleAreas;
  final String? foodBaseUrlOverride;
  final String? foodUserAgentOverride;

  /// Quick add amounts offered for water, in millilitres.
  final List<double> waterQuickAmountsMl;

  AppSettings copyWith({
    String? languageCode,
    WeightUnit? weightUnit,
    Set<AppArea>? visibleAreas,
    String? foodBaseUrlOverride,
    bool clearFoodBaseUrl = false,
    String? foodUserAgentOverride,
    bool clearFoodUserAgent = false,
    List<double>? waterQuickAmountsMl,
  }) {
    return AppSettings(
      languageCode: languageCode ?? this.languageCode,
      weightUnit: weightUnit ?? this.weightUnit,
      visibleAreas: visibleAreas ?? this.visibleAreas,
      foodBaseUrlOverride:
          clearFoodBaseUrl ? null : (foodBaseUrlOverride ?? this.foodBaseUrlOverride),
      foodUserAgentOverride: clearFoodUserAgent
          ? null
          : (foodUserAgentOverride ?? this.foodUserAgentOverride),
      waterQuickAmountsMl: waterQuickAmountsMl ?? this.waterQuickAmountsMl,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'language': languageCode,
        'weight_unit': weightUnit.name,
        'visible_areas':
            visibleAreas.map((AppArea a) => a.name).toList(growable: false)..sort(),
        if (foodBaseUrlOverride != null) 'food_base_url': foodBaseUrlOverride,
        if (foodUserAgentOverride != null) 'food_user_agent': foodUserAgentOverride,
        'water_quick_ml': waterQuickAmountsMl,
      };

  static AppSettings fromJson(Map<String, dynamic> json) {
    final List<dynamic>? areas = json['visible_areas'] as List<dynamic>?;
    final Set<AppArea> parsed = <AppArea>{
      if (areas != null)
        for (final dynamic a in areas)
          if (a is String) AppArea.parse(a),
    };
    final List<dynamic>? quick = json['water_quick_ml'] as List<dynamic>?;
    return AppSettings(
      languageCode: json['language'] as String? ?? 'de',
      weightUnit: WeightUnit.parse(json['weight_unit'] as String?),
      visibleAreas: parsed.isEmpty ? AppSettings().visibleAreas : parsed,
      foodBaseUrlOverride: json['food_base_url'] as String?,
      foodUserAgentOverride: json['food_user_agent'] as String?,
      waterQuickAmountsMl: quick == null
          ? AppSettings().waterQuickAmountsMl
          : <double>[
              for (final dynamic q in quick)
                if (q is num) q.toDouble(),
            ],
    );
  }
}

/// Small date helpers shared by the whole product.
abstract final class DateMath {
  /// Formats a [DateTime] as local calendar day `YYYY-MM-DD`.
  static String format(DateTime value) {
    final String y = value.year.toString().padLeft(4, '0');
    final String m = value.month.toString().padLeft(2, '0');
    final String d = value.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  /// Parses `YYYY-MM-DD` into a local [DateTime] at midnight.
  static DateTime parse(String value) {
    final List<String> parts = value.split('-');
    if (parts.length != 3) throw FormatException('Invalid date: $value');
    return DateTime(
      int.parse(parts[0]),
      int.parse(parts[1]),
      int.parse(parts[2]),
    );
  }

  /// Whether [date] lies between [from] and [to] (inclusive).
  static bool inRange(String date, String from, String to) =>
      date.compareTo(from) >= 0 && date.compareTo(to) <= 0;

  /// Whether [date] is before [other].
  static bool before(String date, String other) => date.compareTo(other) < 0;

  /// Whether [date] is after [other].
  static bool after(String date, String other) => date.compareTo(other) > 0;

  /// Number of days between two calendar days (`b - a`).
  static int dayDiff(String a, String b) =>
      parse(b).difference(parse(a)).inDays;

  /// Adds [days] to a calendar day string.
  static String addDays(String value, int days) =>
      format(parse(value).add(Duration(days: days)));

  /// Inclusive list of calendar days between two days.
  static List<String> range(String from, String to) {
    final List<String> out = <String>[];
    String cursor = from;
    int guard = 0;
    while (dayDiff(cursor, to) >= 0 && guard < 100000) {
      out.add(cursor);
      cursor = addDays(cursor, 1);
      guard++;
    }
    return out;
  }
}
