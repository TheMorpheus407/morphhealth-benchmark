import 'civil.dart';
import 'clock.dart';
import 'db.dart';
import 'issues.dart';
import 'models.dart';
import 'store.dart';

/// Kennung und Version des Austauschformats.
const String portableFormat = 'morphhealth-portable';
const int portableVersion = 1;

/// Version der App, wie sie im Export und im User-Agent-Standard erscheint.
const String kAppVersion = '1.0.0';

/// Ergebnisbericht eines Imports.
final class ImportReport {
  /// Anzahl importierter Datensätze je Abschnitt.
  final Map<String, int> imported;
  final bool settingsImported;
  final bool goalsImported;
  final List<Issue> warnings;
  final int droppedWarnings;

  const ImportReport(this.imported, this.settingsImported, this.goalsImported, this.warnings, this.droppedWarnings);

  int get total => imported.values.fold(0, (a, b) => a + b);

  Map<String, Object?> toJson() => {
    'replaced': true,
    'imported': imported,
    'total_records': total,
    'settings_imported': settingsImported,
    'goals_imported': goalsImported,
    'warning_count': warnings.length + droppedWarnings,
    'warnings': [for (final w in warnings.take(50)) w.toJson()],
  };
}

/// Ein geprüftes Dokument, bereit zum Ersetzen des Bestands.
final class ParsedImport {
  final State state;
  final ImportReport report;

  const ParsedImport(this.state, this.report);
}

/// Der vollständige Datenexport als JSON-Objekt (Format `morphhealth-portable`).
Map<String, Object?> exportPortable(Db db, Clock clock) {
  final foods = db.foods.toList()
    ..sort((a, b) {
      final c = a.info.name.toLowerCase().compareTo(b.info.name.toLowerCase());
      return c != 0 ? c : a.id.compareTo(b.id);
    });
  int byAt(LocalDateTime a, LocalDateTime b, String ia, String ib) {
    final c = a.compareTo(b);
    return c != 0 ? c : ia.compareTo(ib);
  }

  final entries = db.entries.all.toList()..sort((a, b) => byAt(a.at, b.at, a.id, b.id));
  final water = db.water.all.toList()..sort((a, b) => byAt(a.at, b.at, a.id, b.id));
  final caffeine = db.caffeine.all.toList()..sort((a, b) => byAt(a.at, b.at, a.id, b.id));
  final weights = db.weights.all.toList()..sort((a, b) => byAt(a.at, b.at, a.id, b.id));
  final symptoms = db.symptoms.all.toList()..sort((a, b) => byAt(a.at, b.at, a.id, b.id));
  return {
    'format': portableFormat,
    'version': portableVersion,
    'exported_at': rfc3339(clock.now()),
    'app': {'name': 'MorphHealth', 'version': kAppVersion},
    'settings': db.settings.toJson(portable: true),
    'goals': db.goals.toJson(),
    'foods': [for (final f in foods) f.toJson()],
    'food_entries': [for (final e in entries) e.toJson()],
    'water_entries': [for (final w in water) w.toJson()],
    'caffeine_entries': [for (final c in caffeine) c.toJson()],
    'weight_entries': [for (final w in weights) w.toJson()],
    'periods': [for (final p in db.periods) p.toJson()],
    'symptom_entries': [for (final s in symptoms) s.toJson()],
  };
}

/// Prüft ein Dokument vollständig und baut daraus den neuen Bestand.
/// Wirft [ValidationException], wenn irgendetwas ungültig ist; dann bleibt der
/// vorhandene Bestand unberührt.
ParsedImport parsePortable(Object? document) {
  final issues = Issues();
  final root = Obj.from(document, r'$', issues);
  if (root == null) {
    throw ValidationException('Das Dokument muss ein JSON-Objekt sein', issues.errors);
  }

  final format = root.string('format', max: 100);
  if (format == null) {
    issues.warn(root.at('format'), 'fehlt, erwartet "$portableFormat"');
  } else if (format != portableFormat) {
    issues.error(root.at('format'), 'erwartet "$portableFormat", gefunden "$format"');
  }
  final version = root.integer('version', min: 1);
  if (version != null && version > portableVersion) {
    issues.error(root.at('version'), 'Version $version ist neuer als diese App versteht ($portableVersion)');
  }
  root.raw('exported_at');
  root.raw('app');

  final settingsObj = root.object('settings');
  final goalsObj = root.object('goals');
  final settings = AppSettings.read(settingsObj);
  final goals = Goals.read(goalsObj);

  final state = <String, Records>{};
  final counts = <String, int>{};

  void collect<T>(
    String key,
    String table,
    T? Function(Obj) read,
    String Function(T) idOf,
    Map<String, Object?> Function(T) toJson,
  ) {
    final list = root.objects(key);
    final seen = <String>{};
    final recs = <String, Map<String, Object?>>{};
    if (list != null) {
      for (final o in list) {
        final v = read(o);
        if (v == null) continue;
        final id = idOf(v);
        if (!seen.add(id)) {
          issues.error(o.at('id'), 'ID "$id" kommt in $key mehrfach vor');
          continue;
        }
        recs[id] = toJson(v);
      }
    }
    state[table] = recs;
    counts[key] = recs.length;
  }

  // Bibliothek zuerst, damit Einträge per food_id darauf verweisen können.
  final libraryInfo = <String, FoodInfo>{};
  collect<Food>(
    'foods',
    tFoods,
    (o) {
      final f = Food.read(o);
      if (f != null) libraryInfo[f.id] = f.info;
      return f;
    },
    (f) => f.id,
    (f) => f.toJson(),
  );
  collect<FoodEntry>(
    'food_entries',
    tEntries,
    (o) => FoodEntry.read(o, foodLookup: (id) => libraryInfo[id]),
    (e) => e.id,
    (e) => e.toJson(),
  );
  collect<WaterEntry>('water_entries', tWater, WaterEntry.read, (e) => e.id, (e) => e.toJson());
  collect<CaffeineEntry>('caffeine_entries', tCaffeine, CaffeineEntry.read, (e) => e.id, (e) => e.toJson());
  collect<WeightEntry>('weight_entries', tWeights, WeightEntry.read, (e) => e.id, (e) => e.toJson());
  final periods = <PeriodRecord>[];
  collect<PeriodRecord>(
    'periods',
    tPeriods,
    (o) {
      final p = PeriodRecord.read(o);
      if (p != null) periods.add(p);
      return p;
    },
    (p) => p.id,
    (p) => p.toJson(),
  );
  collect<SymptomEntry>('symptom_entries', tSymptoms, SymptomEntry.read, (e) => e.id, (e) => e.toJson());
  root.finish();

  // Überschneidende Perioden sind zulässig, aber auffällig. Eine Periode ohne Ende endet
  // spätestens vor der nächsten und überschneidet sich deshalb nie mit ihr.
  periods.sort((a, b) => a.start.compareTo(b.start));
  for (var i = 1; i < periods.length; i++) {
    final prev = periods[i - 1];
    final cur = periods[i];
    if (prev.end != null && !cur.start.isAfter(prev.end!)) {
      issues.warn(r'$.periods', 'Perioden ab ${prev.start} und ab ${cur.start} überschneiden sich');
    }
  }

  if (issues.hasErrors) {
    throw ValidationException(
      'Das Dokument ist ungültig (${issues.errors.length + issues.droppedErrors} Fehler)',
      issues.errors,
    );
  }

  state[tMeta] = {
    if (settingsObj != null) kSettingsId: settings.toJson(),
    if (goalsObj != null) kGoalsId: goals.toJson(),
  };
  return ParsedImport(
    state,
    ImportReport(counts, settingsObj != null, goalsObj != null, issues.warnings, issues.droppedWarnings),
  );
}
