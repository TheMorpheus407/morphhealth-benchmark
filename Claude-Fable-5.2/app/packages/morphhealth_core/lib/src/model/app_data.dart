import '../util/dates.dart';
import '../util/ids.dart';
import '../util/json_reader.dart';
import 'entries.dart';
import 'food.dart';
import 'settings.dart';

/// Items of one kind grouped by calendar day.
class _DayIndex<T> {
  final Map<int, List<T>> _byDay = {};

  void add(Day day, T item) => (_byDay[day.epochDay] ??= []).add(item);

  void remove(Day day, T item) {
    final list = _byDay[day.epochDay];
    if (list == null) return;
    list.remove(item);
    if (list.isEmpty) _byDay.remove(day.epochDay);
  }

  List<T> on(Day day) => _byDay[day.epochDay] ?? const [];

  bool hasAny(Day day) => _byDay.containsKey(day.epochDay);

  void clear() => _byDay.clear();
}

/// The complete data set of one installation, held in memory.
///
/// All reads of the app and of the maintenance access go through this class.
/// Day lookups use an index, so that a day view stays fast with many thousand
/// entries.
class AppData {
  static const String documentFormat = 'morphhealth-export';
  static const int documentVersion = 1;

  Settings settings;
  Goals goals;

  final Map<String, Food> _foods = {};
  final Map<String, IntakeEntry> _intake = {};
  final Map<String, WaterEntry> _water = {};
  final Map<String, CaffeineEntry> _caffeine = {};
  final Map<String, WeightEntry> _weights = {};
  final Map<String, SymptomEntry> _symptoms = {};
  final Map<String, Period> _periods = {};
  final Map<int, CycleDay> _cycleDays = {};

  final _DayIndex<IntakeEntry> _intakeByDay = _DayIndex();
  final _DayIndex<WaterEntry> _waterByDay = _DayIndex();
  final _DayIndex<CaffeineEntry> _caffeineByDay = _DayIndex();
  final _DayIndex<WeightEntry> _weightsByDay = _DayIndex();
  final _DayIndex<SymptomEntry> _symptomsByDay = _DayIndex();

  List<Period>? _periodsSorted;
  List<WeightEntry>? _weightsSorted;

  /// Increases with every change; lets callers cache derived values.
  int revision = 0;

  AppData({this.settings = const Settings(), this.goals = const Goals()});

  // ---------------------------------------------------------------- foods

  Iterable<Food> get foods => _foods.values;
  int get foodCount => _foods.length;
  Food? food(String id) => _foods[id];

  void putFood(Food food) {
    _foods[food.id] = food;
    revision++;
  }

  bool removeFood(String id) {
    final removed = _foods.remove(id) != null;
    if (removed) revision++;
    return removed;
  }

  /// Number of diary entries that refer to the food [id].
  int intakeCountForFood(String id) {
    var c = 0;
    for (final e in _intake.values) {
      if (e.foodId == id) c++;
    }
    return c;
  }

  /// The locally kept food with [barcode] (already normalized), if any;
  /// optionally only foods of [source].
  Food? foodByBarcode(String barcode, {FoodSource? source}) {
    Food? archived;
    for (final f in _foods.values) {
      if (f.barcode == barcode && (source == null || f.source == source)) {
        if (!f.archived) return f;
        archived = f;
      }
    }
    return archived;
  }

  // --------------------------------------------------------------- intake

  Iterable<IntakeEntry> get intake => _intake.values;
  int get intakeCount => _intake.length;
  IntakeEntry? intakeEntry(String id) => _intake[id];

  void putIntake(IntakeEntry entry) {
    final old = _intake[entry.id];
    if (old != null) _intakeByDay.remove(old.day, old);
    _intake[entry.id] = entry;
    _intakeByDay.add(entry.day, entry);
    revision++;
  }

  bool removeIntake(String id) {
    final old = _intake.remove(id);
    if (old == null) return false;
    _intakeByDay.remove(old.day, old);
    revision++;
    return true;
  }

  /// Entries of [day] in chronological order.
  List<IntakeEntry> intakeOn(Day day) =>
      _sorted(_intakeByDay.on(day), (a, b) => _byTime(a.at, a.id, b.at, b.id));

  // ---------------------------------------------------------------- water

  Iterable<WaterEntry> get water => _water.values;
  int get waterCount => _water.length;
  WaterEntry? waterEntry(String id) => _water[id];

  void putWater(WaterEntry entry) {
    final old = _water[entry.id];
    if (old != null) _waterByDay.remove(old.day, old);
    _water[entry.id] = entry;
    _waterByDay.add(entry.day, entry);
    revision++;
  }

  bool removeWater(String id) {
    final old = _water.remove(id);
    if (old == null) return false;
    _waterByDay.remove(old.day, old);
    revision++;
    return true;
  }

  List<WaterEntry> waterOn(Day day) =>
      _sorted(_waterByDay.on(day), (a, b) => _byTime(a.at, a.id, b.at, b.id));

  // ------------------------------------------------------------- caffeine

  Iterable<CaffeineEntry> get caffeine => _caffeine.values;
  int get caffeineCount => _caffeine.length;
  CaffeineEntry? caffeineEntry(String id) => _caffeine[id];

  void putCaffeine(CaffeineEntry entry) {
    final old = _caffeine[entry.id];
    if (old != null) _caffeineByDay.remove(old.day, old);
    _caffeine[entry.id] = entry;
    _caffeineByDay.add(entry.day, entry);
    revision++;
  }

  bool removeCaffeine(String id) {
    final old = _caffeine.remove(id);
    if (old == null) return false;
    _caffeineByDay.remove(old.day, old);
    revision++;
    return true;
  }

  List<CaffeineEntry> caffeineOn(Day day) => _sorted(
    _caffeineByDay.on(day),
    (a, b) => _byTime(a.at, a.id, b.at, b.id),
  );

  // -------------------------------------------------------------- weights

  Iterable<WeightEntry> get weights => _weights.values;
  int get weightCount => _weights.length;
  WeightEntry? weightEntry(String id) => _weights[id];

  void putWeight(WeightEntry entry) {
    final old = _weights[entry.id];
    if (old != null) _weightsByDay.remove(old.date, old);
    _weights[entry.id] = entry;
    _weightsByDay.add(entry.date, entry);
    _weightsSorted = null;
    revision++;
  }

  bool removeWeight(String id) {
    final old = _weights.remove(id);
    if (old == null) return false;
    _weightsByDay.remove(old.date, old);
    _weightsSorted = null;
    revision++;
    return true;
  }

  List<WeightEntry> weightsOn(Day day) => _sorted(
    _weightsByDay.on(day),
    (a, b) => _byTime(a.createdAt, a.id, b.createdAt, b.id),
  );

  /// All weights, oldest first.
  List<WeightEntry> get weightsSorted =>
      _weightsSorted ??= (_weights.values.toList()
        ..sort((a, b) {
          final c = a.date.compareTo(b.date);
          return c != 0 ? c : _byTime(a.createdAt, a.id, b.createdAt, b.id);
        }));

  /// The weight of [day]: the mean if several values were recorded.
  double? weightKgOn(Day day) {
    final list = _weightsByDay.on(day);
    if (list.isEmpty) return null;
    var sum = 0.0;
    for (final w in list) {
      sum += w.weightKg;
    }
    return sum / list.length;
  }

  // ------------------------------------------------------------- symptoms

  Iterable<SymptomEntry> get symptoms => _symptoms.values;
  int get symptomCount => _symptoms.length;
  SymptomEntry? symptomEntry(String id) => _symptoms[id];

  void putSymptom(SymptomEntry entry) {
    final old = _symptoms[entry.id];
    if (old != null) _symptomsByDay.remove(old.day, old);
    _symptoms[entry.id] = entry;
    _symptomsByDay.add(entry.day, entry);
    revision++;
  }

  bool removeSymptom(String id) {
    final old = _symptoms.remove(id);
    if (old == null) return false;
    _symptomsByDay.remove(old.day, old);
    revision++;
    return true;
  }

  List<SymptomEntry> symptomsOn(Day day) => _sorted(
    _symptomsByDay.on(day),
    (a, b) => _byTime(a.at, a.id, b.at, b.id),
  );

  bool hasSymptomsOn(Day day) => _symptomsByDay.hasAny(day);

  // -------------------------------------------------------------- periods

  Iterable<Period> get periods => _periods.values;
  int get periodCount => _periods.length;
  Period? period(String id) => _periods[id];

  void putPeriod(Period period) {
    _periods[period.id] = period;
    _periodsSorted = null;
    revision++;
  }

  bool removePeriod(String id) {
    final removed = _periods.remove(id) != null;
    if (removed) {
      _periodsSorted = null;
      revision++;
    }
    return removed;
  }

  /// All periods, earliest first.
  List<Period> get periodsSorted =>
      _periodsSorted ??= (_periods.values.toList()
        ..sort((a, b) {
          final c = a.start.compareTo(b.start);
          return c != 0 ? c : a.id.compareTo(b.id);
        }));

  /// The last day shown as belonging to [period] when looking on [asOf]: its
  /// recorded end, or for a period without end the running days, never
  /// reaching into the next recorded period.
  Day periodLastDay(Period period, Day asOf) {
    var last = period.lastCoveredDay(asOf);
    if (period.end == null) {
      for (final other in periodsSorted) {
        if (other.start > period.start) {
          final before = other.start.addDays(-1);
          if (before < last) last = before;
          break;
        }
      }
    }
    return last < period.start ? period.start : last;
  }

  /// The period that covers [day] as seen on [asOf], if any.
  Period? periodOn(Day day, Day asOf) {
    for (final p in periodsSorted) {
      if (p.start > day) break;
      if (day <= periodLastDay(p, asOf)) return p;
    }
    return null;
  }

  /// A recorded period that would overlap [candidate], ignoring the record
  /// with the same id. Open periods count from their start to the day before
  /// the next period (or to [Period.maxLengthDays]).
  Period? overlappingPeriod(Period candidate) {
    Day endOf(Period p) => p.end ?? p.start;
    final cEnd = endOf(candidate);
    for (final p in _periods.values) {
      if (p.id == candidate.id) continue;
      if (candidate.start <= endOf(p) && p.start <= cEnd) return p;
    }
    return null;
  }

  // ----------------------------------------------------------- cycle days

  Iterable<CycleDay> get cycleDays => _cycleDays.values;
  int get cycleDayCount => _cycleDays.length;
  CycleDay? cycleDay(Day day) => _cycleDays[day.epochDay];

  /// Stores [value]; an empty record (no spotting, no note) removes the day.
  void putCycleDay(CycleDay value) {
    if (value.isEmpty) {
      _cycleDays.remove(value.date.epochDay);
    } else {
      _cycleDays[value.date.epochDay] = value;
    }
    revision++;
  }

  bool removeCycleDay(Day day) {
    final removed = _cycleDays.remove(day.epochDay) != null;
    if (removed) revision++;
    return removed;
  }

  // ------------------------------------------------------------- overview

  /// Number of records per collection, as reported by import and export.
  Map<String, int> get counts => {
    'foods': _foods.length,
    'intake': _intake.length,
    'water': _water.length,
    'caffeine': _caffeine.length,
    'weights': _weights.length,
    'symptoms': _symptoms.length,
    'periods': _periods.length,
    'cycle_days': _cycleDays.length,
  };

  /// Number of diary entries across all areas (foods are not entries).
  int get entryCount =>
      _intake.length +
      _water.length +
      _caffeine.length +
      _weights.length +
      _symptoms.length +
      _periods.length +
      _cycleDays.length;

  bool get isEmpty => entryCount == 0 && _foods.isEmpty;

  /// The first and last day that carry any entry, or null if there is none.
  ({Day first, Day last})? get dateRange {
    int? lo, hi;
    void see(int d) {
      if (lo == null || d < lo!) lo = d;
      if (hi == null || d > hi!) hi = d;
    }

    for (final e in _intake.values) {
      see(e.day.epochDay);
    }
    for (final e in _water.values) {
      see(e.day.epochDay);
    }
    for (final e in _caffeine.values) {
      see(e.day.epochDay);
    }
    for (final e in _weights.values) {
      see(e.date.epochDay);
    }
    for (final e in _symptoms.values) {
      see(e.day.epochDay);
    }
    for (final p in _periods.values) {
      see(p.start.epochDay);
      see((p.end ?? p.start).epochDay);
    }
    for (final d in _cycleDays.keys) {
      see(d);
    }
    if (lo == null) return null;
    return (first: Day.fromEpochDay(lo!), last: Day.fromEpochDay(hi!));
  }

  // -------------------------------------------------------------- document

  /// The complete data set as a portable document (see README, "Datenformat").
  /// Collections are sorted, so that two exports of the same data are equal.
  Map<String, dynamic> toDocument({
    required LocalDateTime exportedAt,
    required String appVersion,
  }) {
    final foods = _foods.values.toList()
      ..sort((a, b) => _byTime(a.createdAt, a.id, b.createdAt, b.id));
    final intake = _intake.values.toList()
      ..sort((a, b) => _byTime(a.at, a.id, b.at, b.id));
    final water = _water.values.toList()
      ..sort((a, b) => _byTime(a.at, a.id, b.at, b.id));
    final caffeine = _caffeine.values.toList()
      ..sort((a, b) => _byTime(a.at, a.id, b.at, b.id));
    final symptoms = _symptoms.values.toList()
      ..sort((a, b) => _byTime(a.at, a.id, b.at, b.id));
    final days = _cycleDays.values.toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return {
      'format': documentFormat,
      'version': documentVersion,
      'exported_at': exportedAt.toIso(),
      'app_version': appVersion,
      'settings': settings.toJson(),
      'goals': goals.toJson(),
      'foods': [for (final f in foods) f.toJson()],
      'intake': [for (final e in intake) e.toJson()],
      'water': [for (final e in water) e.toJson()],
      'caffeine': [for (final e in caffeine) e.toJson()],
      'weights': [for (final e in weightsSorted) e.toJson()],
      'symptoms': [for (final e in symptoms) e.toJson()],
      'periods': [for (final p in periodsSorted) p.toJson()],
      'cycle_days': [for (final d in days) d.toJson()],
    };
  }

  /// Builds a data set from a portable document.
  ///
  /// The whole document is checked; all problems are recorded in [log]. If
  /// there is any error, null is returned and nothing is taken over.
  static AppData? fromDocument(
    Object? document,
    IssueLog log, {
    required LocalDateTime now,
    String Function()? idFactory,
  }) {
    final makeId = idFactory ?? newId;
    if (document is! Map) {
      log.error('', 'the document must be a JSON object');
      return null;
    }
    final root = ObjectReader(document.cast<String, dynamic>(), '', log);
    final format = root.raw('format');
    if (format != documentFormat) {
      log.error('format', 'must be "$documentFormat"');
    }
    final version = root.raw('version');
    if (version is! int) {
      log.error('version', 'must be the integer $documentVersion');
    } else if (version > documentVersion) {
      log.error(
        'version',
        'version $version is newer than this app supports ($documentVersion)',
      );
    } else if (version < 1) {
      log.error('version', 'must be the integer $documentVersion');
    }
    root.raw('exported_at');
    root.raw('app_version');

    final data = AppData(
      settings: Settings.fromJson(root.object('settings')),
      goals: Goals.fromJson(root.object('goals')),
    );

    void readList(String key, void Function(ObjectReader r, String path) read) {
      final list = root.list(key);
      if (list == null) return;
      for (var i = 0; i < list.length; i++) {
        final item = list[i];
        final path = '$key[$i]';
        if (item is! Map) {
          log.error(path, 'must be an object');
          continue;
        }
        read(ObjectReader(item.cast<String, dynamic>(), path, log), path);
      }
    }

    bool unique(Map<String, Object?> seen, String id, String path) {
      if (seen.containsKey(id)) {
        log.error('$path.id', 'the id "$id" is used more than once');
        return false;
      }
      return true;
    }

    readList('foods', (r, path) {
      final f = Food.fromJson(r, now: now, idFactory: makeId);
      if (f != null && unique(data._foods, f.id, path)) data.putFood(f);
    });
    readList('intake', (r, path) {
      final e = IntakeEntry.fromJson(r, now: now, idFactory: makeId);
      if (e == null || !unique(data._intake, e.id, path)) return;
      final food = data._foods[e.foodId];
      if (food == null) {
        log.error(
          '$path.food_id',
          'refers to the food "${e.foodId}", which is not in "foods"',
        );
        return;
      }
      if (e.unit == AmountUnit.portion &&
          e.portionSize == null &&
          food.servingSize == null) {
        log.error(
          '$path.portion_size',
          'is required because the food "${food.id}" defines no '
              'serving_size',
        );
        return;
      }
      data.putIntake(e);
    });
    readList('water', (r, path) {
      final e = WaterEntry.fromJson(r, now: now, idFactory: makeId);
      if (e != null && unique(data._water, e.id, path)) data.putWater(e);
    });
    readList('caffeine', (r, path) {
      final e = CaffeineEntry.fromJson(r, now: now, idFactory: makeId);
      if (e != null && unique(data._caffeine, e.id, path)) data.putCaffeine(e);
    });
    readList('weights', (r, path) {
      final e = WeightEntry.fromJson(r, now: now, idFactory: makeId);
      if (e != null && unique(data._weights, e.id, path)) data.putWeight(e);
    });
    readList('symptoms', (r, path) {
      final e = SymptomEntry.fromJson(r, now: now, idFactory: makeId);
      if (e != null && unique(data._symptoms, e.id, path)) data.putSymptom(e);
    });
    final periodPaths = <String, String>{};
    readList('periods', (r, path) {
      final p = Period.fromJson(r, now: now, idFactory: makeId);
      if (p != null && unique(data._periods, p.id, path)) {
        data.putPeriod(p);
        periodPaths[p.id] = path;
      }
    });
    readList('cycle_days', (r, path) {
      final d = CycleDay.fromJson(r, now: now);
      if (d == null) return;
      if (data._cycleDays.containsKey(d.date.epochDay)) {
        log.error('$path.date', 'the date ${d.date} is used more than once');
        return;
      }
      data.putCycleDay(d);
    });
    root.warnUnknown();

    // Periods must not overlap.
    final sorted = data.periodsSorted;
    for (var i = 1; i < sorted.length; i++) {
      final prev = sorted[i - 1];
      final cur = sorted[i];
      final prevEnd = prev.end ?? prev.start;
      if (cur.start <= prevEnd) {
        log.error(
          periodPaths[cur.id] ?? 'periods',
          'overlaps the period that starts on ${prev.start} '
          '(${periodPaths[prev.id]})',
        );
      }
    }

    if (log.hasErrors) return null;
    data.revision = 0;
    return data;
  }

  /// A deep, independent copy.
  AppData clone() {
    final copy = AppData(settings: settings, goals: goals);
    _foods.values.forEach(copy.putFood);
    _intake.values.forEach(copy.putIntake);
    _water.values.forEach(copy.putWater);
    _caffeine.values.forEach(copy.putCaffeine);
    _weights.values.forEach(copy.putWeight);
    _symptoms.values.forEach(copy.putSymptom);
    _periods.values.forEach(copy.putPeriod);
    _cycleDays.values.forEach(copy.putCycleDay);
    copy.revision = 0;
    return copy;
  }
}

List<T> _sorted<T>(List<T> source, int Function(T a, T b) compare) {
  if (source.length < 2) return List<T>.of(source);
  return List<T>.of(source)..sort(compare);
}

int _byTime(LocalDateTime a, String aId, LocalDateTime b, String bId) {
  final c = a.compareTo(b);
  return c != 0 ? c : aId.compareTo(bId);
}
