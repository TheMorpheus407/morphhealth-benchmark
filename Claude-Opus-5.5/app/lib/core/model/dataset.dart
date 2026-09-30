import '../util/local_date.dart';
import 'cycle_records.dart';
import 'entries.dart';
import 'food.dart';
import 'settings.dart';

/// The record collections of a data set, with their JSON names.
enum Collection {
  foods('foods'),
  foodEntries('food_entries'),
  waterEntries('water_entries'),
  caffeineEntries('caffeine_entries'),
  periods('periods'),
  cycleDays('cycle_days'),
  weightEntries('weight_entries'),
  symptomEntries('symptom_entries');

  const Collection(this.json);
  final String json;

  static final Map<String, Collection> byJson = {
    for (final v in values) v.json: v,
  };

  /// Diary entries count towards the "Tagebucheinträge" of a data set.
  bool get isDiary => this != Collection.foods;
}

/// The complete personal data set held in memory.
///
/// Mutations go through [put] and [remove]; every mutation increments
/// [version], which lazily invalidates the per-day indexes.
class Dataset {
  Dataset({Settings? settings}) : settings = settings ?? const Settings();

  Settings settings;

  final Map<String, Food> foods = {};
  final Map<String, FoodEntry> foodEntries = {};
  final Map<String, WaterEntry> waterEntries = {};
  final Map<String, CaffeineEntry> caffeineEntries = {};
  final Map<String, Period> periods = {};
  final Map<String, CycleDay> cycleDays = {};
  final Map<String, WeightEntry> weightEntries = {};
  final Map<String, SymptomEntry> symptomEntries = {};

  int _version = 0;
  int get version => _version;

  void touch() => _version++;

  Map<String, Record> table(Collection c) => switch (c) {
    Collection.foods => foods,
    Collection.foodEntries => foodEntries,
    Collection.waterEntries => waterEntries,
    Collection.caffeineEntries => caffeineEntries,
    Collection.periods => periods,
    Collection.cycleDays => cycleDays,
    Collection.weightEntries => weightEntries,
    Collection.symptomEntries => symptomEntries,
  };

  /// Inserts or replaces a record. The record type must match [c].
  void put(Collection c, Object record) {
    switch (c) {
      case Collection.foods:
        final r = record as Food;
        foods[r.id] = r;
      case Collection.foodEntries:
        final r = record as FoodEntry;
        foodEntries[r.id] = r;
      case Collection.waterEntries:
        final r = record as WaterEntry;
        waterEntries[r.id] = r;
      case Collection.caffeineEntries:
        final r = record as CaffeineEntry;
        caffeineEntries[r.id] = r;
      case Collection.periods:
        final r = record as Period;
        periods[r.id] = r;
      case Collection.cycleDays:
        final r = record as CycleDay;
        cycleDays[r.id] = r;
      case Collection.weightEntries:
        final r = record as WeightEntry;
        weightEntries[r.id] = r;
      case Collection.symptomEntries:
        final r = record as SymptomEntry;
        symptomEntries[r.id] = r;
    }
    touch();
  }

  void remove(Collection c, String id) {
    switch (c) {
      case Collection.foods:
        foods.remove(id);
      case Collection.foodEntries:
        foodEntries.remove(id);
      case Collection.waterEntries:
        waterEntries.remove(id);
      case Collection.caffeineEntries:
        caffeineEntries.remove(id);
      case Collection.periods:
        periods.remove(id);
      case Collection.cycleDays:
        cycleDays.remove(id);
      case Collection.weightEntries:
        weightEntries.remove(id);
      case Collection.symptomEntries:
        symptomEntries.remove(id);
    }
    touch();
  }

  Object? get(Collection c, String id) => switch (c) {
    Collection.foods => foods[id],
    Collection.foodEntries => foodEntries[id],
    Collection.waterEntries => waterEntries[id],
    Collection.caffeineEntries => caffeineEntries[id],
    Collection.periods => periods[id],
    Collection.cycleDays => cycleDays[id],
    Collection.weightEntries => weightEntries[id],
    Collection.symptomEntries => symptomEntries[id],
  };

  /// Replaces all content with [other] (used by import and restore).
  void replaceWith(Dataset other) {
    settings = other.settings;
    foods
      ..clear()
      ..addAll(other.foods);
    foodEntries
      ..clear()
      ..addAll(other.foodEntries);
    waterEntries
      ..clear()
      ..addAll(other.waterEntries);
    caffeineEntries
      ..clear()
      ..addAll(other.caffeineEntries);
    periods
      ..clear()
      ..addAll(other.periods);
    cycleDays
      ..clear()
      ..addAll(other.cycleDays);
    weightEntries
      ..clear()
      ..addAll(other.weightEntries);
    symptomEntries
      ..clear()
      ..addAll(other.symptomEntries);
    touch();
  }

  Map<String, int> counts() => {
    for (final c in Collection.values) c.json: table(c).length,
  };

  /// Number of diary entries (everything except library foods).
  int get diaryEntryCount => Collection.values
      .where((c) => c.isDiary)
      .fold(0, (sum, c) => sum + table(c).length);

  // ---------------------------------------------------------------------
  // Lazily rebuilt indexes.

  int _indexVersion = -1;
  final Map<int, List<FoodEntry>> _foodByDay = {};
  final Map<int, List<WaterEntry>> _waterByDay = {};
  final Map<int, List<CaffeineEntry>> _caffeineByDay = {};
  final Map<int, CycleDay> _cycleDayByDay = {};
  final Map<int, List<WeightEntry>> _weightByDay = {};
  final Map<int, List<SymptomEntry>> _symptomsByDay = {};
  List<Period> _periodsSorted = const [];
  List<WeightEntry> _weightsSorted = const [];

  void _ensureIndexes() {
    if (_indexVersion == _version) return;
    void group<T extends DatedRecord>(Iterable<T> items, Map<int, List<T>> into) {
      into.clear();
      for (final item in items) {
        (into[item.date.epochDay] ??= <T>[]).add(item);
      }
      for (final list in into.values) {
        list.sort(compareDated);
      }
    }

    group(foodEntries.values, _foodByDay);
    group(waterEntries.values, _waterByDay);
    group(caffeineEntries.values, _caffeineByDay);
    group(weightEntries.values, _weightByDay);
    group(symptomEntries.values, _symptomsByDay);
    _cycleDayByDay
      ..clear()
      ..addEntries(cycleDays.values.map((d) => MapEntry(d.date.epochDay, d)));
    _periodsSorted = periods.values.toList()
      ..sort((a, b) => a.start.compareTo(b.start));
    _weightsSorted = weightEntries.values.toList()..sort(compareDated);
    _indexVersion = _version;
  }

  List<FoodEntry> foodEntriesOn(LocalDate day) {
    _ensureIndexes();
    return _foodByDay[day.epochDay] ?? const [];
  }

  List<WaterEntry> waterOn(LocalDate day) {
    _ensureIndexes();
    return _waterByDay[day.epochDay] ?? const [];
  }

  List<CaffeineEntry> caffeineOn(LocalDate day) {
    _ensureIndexes();
    return _caffeineByDay[day.epochDay] ?? const [];
  }

  CycleDay? cycleDayOn(LocalDate day) {
    _ensureIndexes();
    return _cycleDayByDay[day.epochDay];
  }

  List<WeightEntry> weightsOn(LocalDate day) {
    _ensureIndexes();
    return _weightByDay[day.epochDay] ?? const [];
  }

  List<SymptomEntry> symptomsOn(LocalDate day) {
    _ensureIndexes();
    return _symptomsByDay[day.epochDay] ?? const [];
  }

  /// Periods sorted by start date (ascending).
  List<Period> get periodsSorted {
    _ensureIndexes();
    return _periodsSorted;
  }

  /// Weight entries sorted by date and time (ascending).
  List<WeightEntry> get weightsSorted {
    _ensureIndexes();
    return _weightsSorted;
  }

  /// The period covering [day], if any.
  Period? periodOn(LocalDate day, LocalDate today) {
    for (final p in periodsSorted.reversed) {
      if (p.start.isAfter(day)) continue;
      return p.contains(day, today: today) ? p : null;
    }
    return null;
  }

  /// True if any diary data exists for [day].
  bool hasDataOn(LocalDate day) =>
      foodEntriesOn(day).isNotEmpty ||
      waterOn(day).isNotEmpty ||
      caffeineOn(day).isNotEmpty ||
      weightsOn(day).isNotEmpty ||
      symptomsOn(day).isNotEmpty ||
      cycleDayOn(day) != null;
}
