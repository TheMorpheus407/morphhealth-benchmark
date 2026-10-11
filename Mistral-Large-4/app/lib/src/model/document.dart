// Wurzel-Dokument des Datenbestands und das portable Export-/Import-Format.
//
// Dasselbe Dokument liegt
//   1. verschlüsselt im lokalen Speicher (AES-256-GCM-Container),
//   2. als Klartext-Export (portable.export / Datei-Export),
//   3. als Nutzlast einer passphrasengeschützten Sicherung,
//   4. als Arbeitsdokument des Wartungszugangs `mh`.
library;

import '../core/exceptions.dart';
import '../core/parse.dart';
import 'cycle.dart';
import 'entries.dart';
import 'food.dart';
import 'settings.dart';

/// Kennung des portablen Formats.
const String portableFormat = 'morphhealth.portable';

/// Unterstützte Formatversion.
const int portableFormatVersion = 1;

/// App-Kennung (Version siehe pubspec; Laufzeitwert wird injiziert).
class AppInfo {
  final String name;
  final String version;
  const AppInfo({this.name = 'MorphHealth', this.version = '1.0.0+1'});
}

/// Der gesamte Datenbestand einer Installation.
class MorphDocument {
  AppSettings settings;
  List<FoodItem> foods;
  List<NutritionEntry> nutritionEntries;
  List<WaterEntry> waterEntries;
  List<CaffeineEntry> caffeineEntries;
  List<PeriodRecord> periods;
  List<WeightEntry> weightEntries;
  List<SymptomEntry> symptomEntries;

  MorphDocument({
    AppSettings? settings,
    List<FoodItem>? foods,
    List<NutritionEntry>? nutritionEntries,
    List<WaterEntry>? waterEntries,
    List<CaffeineEntry>? caffeineEntries,
    List<PeriodRecord>? periods,
    List<WeightEntry>? weightEntries,
    List<SymptomEntry>? symptomEntries,
  })  : settings = settings ?? AppSettings(),
        foods = foods ?? <FoodItem>[],
        nutritionEntries = nutritionEntries ?? <NutritionEntry>[],
        waterEntries = waterEntries ?? <WaterEntry>[],
        caffeineEntries = caffeineEntries ?? <CaffeineEntry>[],
        periods = periods ?? <PeriodRecord>[],
        weightEntries = weightEntries ?? <WeightEntry>[],
        symptomEntries = symptomEntries ?? <SymptomEntry>[];

  factory MorphDocument.empty() => MorphDocument();

  /// Interne (flachen) JSON-Darstellung — ohne Export-Metadaten.
  Map<String, dynamic> toDataJson() => <String, dynamic>{
        'settings': settings.toJson(),
        'foods': <dynamic>[for (final FoodItem f in foods) f.toJson()],
        'nutrition_entries': <dynamic>[for (final NutritionEntry e in nutritionEntries) e.toJson()],
        'water_entries': <dynamic>[for (final WaterEntry e in waterEntries) e.toJson()],
        'caffeine_entries': <dynamic>[for (final CaffeineEntry e in caffeineEntries) e.toJson()],
        'periods': <dynamic>[for (final PeriodRecord p in periods) p.toJson()],
        'weight_entries': <dynamic>[for (final WeightEntry e in weightEntries) e.toJson()],
        'symptom_entries': <dynamic>[for (final SymptomEntry e in symptomEntries) e.toJson()],
      };

  /// Vollständiges portables Dokument (Export-Format).
  Map<String, dynamic> toPortableJson(AppInfo info, {DateTime? exportedAt}) => <String, dynamic>{
        'format': portableFormat,
        'format_version': portableFormatVersion,
        'generator': <String, dynamic>{
          'app': info.name,
          'version': info.version,
          'exported_at': (exportedAt ?? DateTime.now()).toUtc().toIso8601String(),
        },
        'data': toDataJson(),
      };

  /// Parst den `data`-Teil eines portablen Dokuments (oder eines
  /// nackten Daten-Objekts) und validiert die Struktur.
  static MorphDocument fromDataJson(Map<String, dynamic> data) {
    MorphDocument doc = MorphDocument();
    doc.settings = AppSettings.fromJson(getMap(data, 'settings'));
    doc.foods = _parseList(data, 'foods', FoodItem.fromJson);
    doc.nutritionEntries = _parseList(data, 'nutrition_entries', NutritionEntry.fromJson);
    doc.waterEntries = _parseList(data, 'water_entries', WaterEntry.fromJson);
    doc.caffeineEntries = _parseList(data, 'caffeine_entries', CaffeineEntry.fromJson);
    doc.periods = _parseList(data, 'periods', PeriodRecord.fromJson);
    doc.weightEntries = _parseList(data, 'weight_entries', WeightEntry.fromJson);
    doc.symptomEntries = _parseList(data, 'symptom_entries', SymptomEntry.fromJson);
    return doc;
  }

  /// Parst ein vollständiges portables Dokument und validiert Formatkennung
  /// und Version. Wirft MorphException bei ungültigem Dokument.
  static MorphDocument fromPortableJson(Map<String, dynamic> json) {
    final String? format = getString(json, 'format');
    if (format != portableFormat) {
      throw MorphException('portable.invalid_format',
          'Unbekanntes Format "$format" (erwartet: $portableFormat).');
    }
    final int? version = getInt(json, 'format_version');
    if (version == null || version > portableFormatVersion) {
      throw MorphException('portable.unsupported_version',
          'Formatversion ${version ?? "unbekannt"} wird nicht unterstützt (max. $portableFormatVersion).');
    }
    final data = getMap(json, 'data');
    if (data == null) {
      throw MorphException('portable.missing_data', 'Das Dokument enthält kein "data"-Objekt.');
    }
    return fromDataJson(data);
  }

  static List<T> _parseList<T>(Map<String, dynamic> data, String key, T Function(Map<String, dynamic>) fromJson) {
    final List<dynamic>? raw = getList(data, key);
    if (raw == null) return <T>[];
    final List<T> out = <T>[];
    for (final dynamic item in raw) {
      if (item is Map<String, dynamic>) {
        out.add(fromJson(item));
      } else if (item is Map) {
        out.add(fromJson(item.cast<String, dynamic>()));
      }
    }
    return out;
  }

  /// Import-Bericht (Anzahl übernommener Datensätze pro Bereich).
  Map<String, int> importReport() => <String, int>{
        'foods': foods.length,
        'nutrition_entries': nutritionEntries.length,
        'water_entries': waterEntries.length,
        'caffeine_entries': caffeineEntries.length,
        'periods': periods.length,
        'weight_entries': weightEntries.length,
        'symptom_entries': symptomEntries.length,
      };
}
