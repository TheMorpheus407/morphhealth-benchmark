import '../model/cycle_records.dart';
import '../model/dataset.dart';
import '../model/entries.dart';
import '../model/food.dart';
import '../model/settings.dart';
import '../util/clock.dart';
import '../util/json_reader.dart';

/// The documented, machine-readable MorphHealth data format
/// (`morphhealth.portable`, version 1).
///
/// The same document is used for the plaintext export, as the payload of
/// encrypted backups and as the content of the encrypted local store.
class PortableFormat {
  const PortableFormat._();

  static const String formatId = 'morphhealth.portable';
  static const int version = 1;
  static const String appName = 'MorphHealth';

  /// Top-level keys of a portable document.
  static const Set<String> topLevelKeys = {
    'format',
    'version',
    'exported_at',
    'app',
    'settings',
    'foods',
    'food_entries',
    'water_entries',
    'caffeine_entries',
    'periods',
    'cycle_days',
    'weight_entries',
    'symptom_entries',
  };
}

/// Serializes [data] as a portable document. Records are ordered
/// chronologically so that exports are stable and easy to diff.
Map<String, Object?> encodePortable(
  Dataset data, {
  required DateTime exportedAt,
  required String appVersion,
}) {
  List<Map<String, Object?>> dated<T extends DatedRecord>(Iterable<T> items) =>
      (items.toList()..sort(compareDated)).map((e) => e.toJson()).toList();

  final foods = data.foods.values.toList()
    ..sort((a, b) {
      final c = a.createdAt.compareTo(b.createdAt);
      return c != 0 ? c : a.id.compareTo(b.id);
    });
  final periods = data.periods.values.toList()
    ..sort((a, b) => a.start.compareTo(b.start));

  return {
    'format': PortableFormat.formatId,
    'version': PortableFormat.version,
    'exported_at': formatInstant(exportedAt),
    'app': {'name': PortableFormat.appName, 'version': appVersion},
    'settings': data.settings.toJson(),
    'foods': foods.map((f) => f.toJson()).toList(),
    'food_entries': dated(data.foodEntries.values),
    'water_entries': dated(data.waterEntries.values),
    'caffeine_entries': dated(data.caffeineEntries.values),
    'periods': periods.map((p) => p.toJson()).toList(),
    'cycle_days': dated(data.cycleDays.values),
    'weight_entries': dated(data.weightEntries.values),
    'symptom_entries': dated(data.symptomEntries.values),
  };
}

class DecodedPortable {
  DecodedPortable(this.dataset, this.warnings, this.generatedIds);

  final Dataset dataset;
  final List<Issue> warnings;

  /// Number of records that had no `id` and received a generated one.
  final int generatedIds;
}

/// Validates and reads a portable document.
///
/// Throws [ValidationException] listing every problem if the document is not
/// acceptable; nothing is partially applied.
DecodedPortable decodePortable(Object? json, {required DateTime now}) {
  final issues = Issues();
  final root = JsonReader.of(json, '', issues);
  if (root == null) throw ValidationException(issues.errors);

  final format = root.string('format', required: true);
  if (format != null && format != PortableFormat.formatId) {
    issues.error('format', 'expected "${PortableFormat.formatId}"');
  }
  final version = root.integer('version', required: true, min: 1);
  if (version != null && version > PortableFormat.version) {
    issues.error(
      'version',
      'version $version is newer than supported (${PortableFormat.version})',
    );
  }
  if (issues.hasErrors) throw ValidationException(issues.errors);

  root.warnUnknownKeys(PortableFormat.topLevelKeys);
  root.instant('exported_at');

  final data = Dataset(settings: Settings.read(root.object('settings')));
  var generated = 0;

  void readList<T extends Record>(
    Collection collection,
    T? Function(Object?, String, Issues, DateTime) parse,
  ) {
    final list = root.list(collection.json);
    if (list == null) return;
    final seen = <String>{};
    for (var i = 0; i < list.length; i++) {
      final item = list[i];
      final path = '${collection.json}[$i]';
      final hadId = item is Map && item['id'] != null;
      final record = parse(item, path, issues, now);
      if (record == null) continue;
      if (!hadId) generated++;
      if (!seen.add(record.id)) {
        issues.error('$path.id', 'duplicate id "${record.id}"');
        continue;
      }
      data.put(collection, record);
    }
  }

  readList<Food>(Collection.foods, Food.fromJson);
  readList<FoodEntry>(Collection.foodEntries, FoodEntry.fromJson);
  readList<WaterEntry>(Collection.waterEntries, WaterEntry.fromJson);
  readList<CaffeineEntry>(Collection.caffeineEntries, CaffeineEntry.fromJson);
  readList<Period>(Collection.periods, Period.fromJson);
  readList<CycleDay>(Collection.cycleDays, CycleDay.fromJson);
  readList<WeightEntry>(Collection.weightEntries, WeightEntry.fromJson);
  readList<SymptomEntry>(Collection.symptomEntries, SymptomEntry.fromJson);

  _checkCycleConsistency(data, issues);

  if (issues.hasErrors) {
    throw ValidationException(issues.errors, issues.warnings);
  }
  return DecodedPortable(data, issues.warnings, generated);
}

void _checkCycleConsistency(Dataset data, Issues issues) {
  final byDate = <String, String>{};
  for (final day in data.cycleDays.values) {
    final key = day.date.toIso();
    final other = byDate[key];
    if (other != null) {
      issues.error(
        'cycle_days',
        'more than one entry for $key (ids "$other" and "${day.id}")',
      );
    } else {
      byDate[key] = day.id;
    }
  }
  final periods = data.periods.values.toList()
    ..sort((a, b) => a.start.compareTo(b.start));
  for (var i = 0; i < periods.length; i++) {
    final p = periods[i];
    if (i + 1 < periods.length) {
      final next = periods[i + 1];
      if (p.end == null) {
        issues.error(
          'periods',
          'period "${p.id}" has no end but is followed by "${next.id}"; '
              'only the latest period may be ongoing',
        );
      } else if (!p.end!.isBefore(next.start)) {
        issues.error(
          'periods',
          'periods "${p.id}" and "${next.id}" overlap',
        );
      }
    }
  }
}

/// Reads a single record of [collection]; throws [ValidationException].
Record decodeRecord(Collection collection, Object? json, {required DateTime now}) {
  final issues = Issues();
  final path = collection.json;
  final Record? record = switch (collection) {
    Collection.foods => Food.fromJson(json, path, issues, now),
    Collection.foodEntries => FoodEntry.fromJson(json, path, issues, now),
    Collection.waterEntries => WaterEntry.fromJson(json, path, issues, now),
    Collection.caffeineEntries => CaffeineEntry.fromJson(json, path, issues, now),
    Collection.periods => Period.fromJson(json, path, issues, now),
    Collection.cycleDays => CycleDay.fromJson(json, path, issues, now),
    Collection.weightEntries => WeightEntry.fromJson(json, path, issues, now),
    Collection.symptomEntries => SymptomEntry.fromJson(json, path, issues, now),
  };
  if (record == null || issues.hasErrors) {
    throw ValidationException(issues.errors, issues.warnings);
  }
  return record;
}

/// Reads settings leniently (invalid values fall back to defaults).
Settings settingsFromJson(Object? json, Issues issues) =>
    Settings.read(json == null ? null : JsonReader.of(json, 'settings', issues));
