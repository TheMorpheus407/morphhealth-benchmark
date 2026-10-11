// Einstellungen der Anwendung (im verschlüsselten Dokument gespeichert).
library;

import '../core/parse.dart';

/// Die vier Produktbereiche.
const List<String> areaKeys = <String>['nutrition', 'cycle', 'weight', 'symptoms'];

/// Tagesziele (freiwillig, null = kein Ziel).
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

  Map<String, dynamic> toJson() => <String, dynamic>{
        if (waterMl != null) 'water_ml': waterMl,
        if (energyKcal != null) 'energy_kcal': energyKcal,
        if (proteinG != null) 'protein_g': proteinG,
        if (carbohydratesG != null) 'carbohydrates_g': carbohydratesG,
        if (fatG != null) 'fat_g': fatG,
      };

  static Goals fromJson(Map<String, dynamic>? json) {
    json ??= <String, dynamic>{};
    return Goals(
      waterMl: getDouble(json, 'water_ml'),
      energyKcal: getDouble(json, 'energy_kcal'),
      proteinG: getDouble(json, 'protein_g'),
      carbohydratesG: getDouble(json, 'carbohydrates_g'),
      fatG: getDouble(json, 'fat_g'),
    );
  }
}

class AppSettings {
  /// Sprache: 'de' | 'en' | null (Systemeinstellung, soweit unterstützt).
  String? language;
  /// Anzeigeeinheit Gewicht: 'kg' | 'lb'.
  String weightUnit;
  /// In der Übersicht sichtbare Bereiche (Schlüssel aus areaKeys).
  List<String> visibleAreas;
  Goals goals;

  AppSettings({
    this.language,
    this.weightUnit = 'kg',
    List<String>? visibleAreas,
    Goals? goals,
  })  : visibleAreas = visibleAreas ?? List<String>.of(areaKeys),
        goals = goals ?? const Goals();

  bool isAreaVisible(String area) => visibleAreas.contains(area);

  Map<String, dynamic> toJson() => <String, dynamic>{
        if (language != null) 'language': language,
        'weight_unit': weightUnit,
        'visible_areas': <String>[...visibleAreas],
        'goals': goals.toJson(),
      };

  static AppSettings fromJson(Map<String, dynamic>? json) {
    json ??= <String, dynamic>{};
    final areas = getList(json, 'visible_areas')
        ?.whereType<String>()
        .where(areaKeys.contains)
        .toList();
    return AppSettings(
      language: getString(json, 'language'),
      weightUnit: getString(json, 'weight_unit') == 'lb' ? 'lb' : 'kg',
      visibleAreas: areas == null || areas.isEmpty ? null : areas,
      goals: Goals.fromJson(getMap(json, 'goals')),
    );
  }
}
