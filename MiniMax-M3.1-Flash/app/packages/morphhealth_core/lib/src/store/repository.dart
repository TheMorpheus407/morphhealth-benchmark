import 'dart:io';

import '../clock.dart';
import '../models/food.dart';
import '../models/journal.dart';
import '../models/records.dart';
import 'record_store.dart';

/// The complete, in-memory state of one MorphHealth installation.
class HealthData {
  HealthData({
    Map<String, FoodItem>? foods,
    List<JournalEntry>? journalEntries,
    List<IntakeEntry>? intakes,
    List<PeriodRecord>? periods,
    List<WeightEntry>? weights,
    List<SymptomEntry>? symptoms,
    Goals? goals,
    AppSettings? settings,
  })  : foods = foods ?? <String, FoodItem>{},
        journalEntries = journalEntries ?? <JournalEntry>[],
        intakes = intakes ?? <IntakeEntry>[],
        periods = periods ?? <PeriodRecord>[],
        weights = weights ?? <WeightEntry>[],
        symptoms = symptoms ?? <SymptomEntry>[],
        goals = goals ?? Goals.none,
        settings = settings ?? const AppSettings();

  final Map<String, FoodItem> foods;
  final List<JournalEntry> journalEntries;
  final List<IntakeEntry> intakes;
  final List<PeriodRecord> periods;
  final List<WeightEntry> weights;
  final List<SymptomEntry> symptoms;
  Goals goals;
  AppSettings settings;

  bool get isEmpty =>
      foods.isEmpty &&
      journalEntries.isEmpty &&
      intakes.isEmpty &&
      periods.isEmpty &&
      weights.isEmpty &&
      symptoms.isEmpty;

  /// Total number of user records (excluding settings and goals).
  int get recordCount =>
      foods.length +
      journalEntries.length +
      intakes.length +
      periods.length +
      weights.length +
      symptoms.length;
}

/// Repository that owns the encrypted store and the in-memory state.
///
/// All product features (app and `mh` CLI) go through this class, so the
/// maintenance access and the graphical interface always see the same data
/// and the same behaviour.
class HealthRepository {
  HealthRepository._(this._store, this._clock, this._data);

  final RecordStore _store;
  final AppClock _clock;
  HealthData _data;

  /// Opens the repository for a working directory.
  static Future<HealthRepository> open({
    required Directory directory,
    required List<int> masterKey,
    AppClock? clock,
  }) async {
    final RecordStore store = await RecordStore.open(
      directory: directory,
      masterKey: masterKey,
    );
    return HealthRepository._(store, clock ?? const SystemClock(), HealthData());
  }

  /// Current state.
  HealthData get data => _data;

  AppClock get clock => _clock;

  RecordStore get store => _store;

  /// Loads every record from the store into memory.
  Future<void> load() async {
    final Map<String, FoodItem> foods = <String, FoodItem>{};
    final List<JournalEntry> journal = <JournalEntry>[];
    final List<IntakeEntry> intakes = <IntakeEntry>[];
    final List<PeriodRecord> periods = <PeriodRecord>[];
    final List<WeightEntry> weights = <WeightEntry>[];
    final List<SymptomEntry> symptoms = <SymptomEntry>[];
    Goals goals = Goals.none;
    AppSettings settings = const AppSettings();

    for (final StoreOperation op in _store.records.values) {
      final Map<String, dynamic>? payload = op.data;
      if (payload == null) continue;
      switch (op.kind) {
        case RecordKind.food:
          final FoodItem item = FoodItem.fromJson(payload);
          foods[item.id] = item;
        case RecordKind.journalEntry:
          journal.add(JournalEntry.fromJson(payload));
        case RecordKind.intake:
          intakes.add(IntakeEntry.fromJson(payload));
        case RecordKind.period:
          periods.add(PeriodRecord.fromJson(payload));
        case RecordKind.weight:
          weights.add(WeightEntry.fromJson(payload));
        case RecordKind.symptom:
          symptoms.add(SymptomEntry.fromJson(payload));
        case RecordKind.goals:
          goals = Goals.fromJson(payload);
        case RecordKind.settings:
          settings = AppSettings.fromJson(payload);
      }
    }

    journal.sort(_byDateThenTime);
    intakes.sort(_byDateThenTime);
    weights.sort(_byDateThenTime);
    symptoms.sort(_byDateThenTime);
    periods.sort((PeriodRecord a, PeriodRecord b) =>
        a.startDate.compareTo(b.startDate));

    _data = HealthData(
      foods: foods,
      journalEntries: journal,
      intakes: intakes,
      periods: periods,
      weights: weights,
      symptoms: symptoms,
      goals: goals,
      settings: settings,
    );
  }

  /// Orders two records by calendar day and then by their moment.
  static int _byDateThenTime(
    dynamic a,
    dynamic b,
  ) {
    final int byDate = (a.date as String).compareTo(b.date as String);
    if (byDate != 0) return byDate;
    return _timestampOf(a).compareTo(_timestampOf(b));
  }

  /// The moment of a record. Symptoms carry their own timestamp field.
  static int _timestampOf(dynamic entry) {
    if (entry is SymptomEntry) return entry.occurredAtMs;
    return entry.loggedAtMs as int;
  }

  // ---------------------------------------------------------------- foods

  List<FoodItem> get foods => _data.foods.values.toList(growable: false);

  List<FoodItem> get favoriteFoods =>
      foods.where((FoodItem f) => f.isFavorite).toList(growable: false);

  FoodItem? foodById(String id) => _data.foods[id];

  FoodItem? foodByBarcode(String barcode) {
    for (final FoodItem food in _data.foods.values) {
      if (food.barcode == barcode) return food;
    }
    return null;
  }

  Future<void> upsertFood(FoodItem food) async {
    final FoodItem stamped = food.copyWith(
      createdAtMs: food.createdAtMs == 0 ? _nowMs() : food.createdAtMs,
      updatedAtMs: _nowMs(),
    );
    await _store.put(RecordKind.food, stamped.id, stamped.toJson());
    _data.foods[stamped.id] = stamped;
  }

  Future<void> deleteFood(String id) async {
    await _store.delete(RecordKind.food, id);
    _data.foods.remove(id);
  }

  // -------------------------------------------------------- journal entries

  List<JournalEntry> get journalEntries =>
      List<JournalEntry>.unmodifiable(_data.journalEntries);

  JournalEntry? journalEntryById(String id) {
    for (final JournalEntry entry in _data.journalEntries) {
      if (entry.id == id) return entry;
    }
    return null;
  }

  Future<void> upsertJournalEntry(JournalEntry entry) async {
    final JournalEntry stamped = entry.copyWith(
      createdAtMs: entry.createdAtMs == 0 ? _nowMs() : entry.createdAtMs,
      updatedAtMs: _nowMs(),
    );
    await _store.put(RecordKind.journalEntry, stamped.id, stamped.toJson());
    _insertSorted(_data.journalEntries, stamped, _byDateThenTime);
  }

  Future<void> deleteJournalEntry(String id) async {
    await _store.delete(RecordKind.journalEntry, id);
    _data.journalEntries.removeWhere((JournalEntry e) => e.id == id);
  }

  // ---------------------------------------------------------- quick intakes

  List<IntakeEntry> get intakeEntries =>
      List<IntakeEntry>.unmodifiable(_data.intakes);

  IntakeEntry? intakeEntryById(String id) {
    for (final IntakeEntry entry in _data.intakes) {
      if (entry.id == id) return entry;
    }
    return null;
  }

  Future<void> upsertIntake(IntakeEntry entry) async {
    final IntakeEntry stamped = entry.copyWith(
      createdAtMs: entry.createdAtMs == 0 ? _nowMs() : entry.createdAtMs,
      updatedAtMs: _nowMs(),
    );
    await _store.put(RecordKind.intake, stamped.id, stamped.toJson());
    _insertSorted(_data.intakes, stamped, _byDateThenTime);
  }

  Future<void> deleteIntake(String id) async {
    await _store.delete(RecordKind.intake, id);
    _data.intakes.removeWhere((IntakeEntry e) => e.id == id);
  }

  // --------------------------------------------------------------- periods

  List<PeriodRecord> get periods => List<PeriodRecord>.unmodifiable(_data.periods);

  PeriodRecord? periodById(String id) {
    for (final PeriodRecord record in _data.periods) {
      if (record.id == id) return record;
    }
    return null;
  }

  Future<void> upsertPeriod(PeriodRecord record) async {
    final PeriodRecord stamped = record.copyWith(
      createdAtMs: record.createdAtMs == 0 ? _nowMs() : record.createdAtMs,
      updatedAtMs: _nowMs(),
    );
    await _store.put(RecordKind.period, stamped.id, stamped.toJson());
    _data.periods.removeWhere((PeriodRecord p) => p.id == stamped.id);
    _data.periods.add(stamped);
    _data.periods.sort((PeriodRecord a, PeriodRecord b) =>
        a.startDate.compareTo(b.startDate));
  }

  Future<void> deletePeriod(String id) async {
    await _store.delete(RecordKind.period, id);
    _data.periods.removeWhere((PeriodRecord p) => p.id == id);
  }

  // --------------------------------------------------------------- weights

  List<WeightEntry> get weightEntries =>
      List<WeightEntry>.unmodifiable(_data.weights);

  WeightEntry? weightEntryById(String id) {
    for (final WeightEntry entry in _data.weights) {
      if (entry.id == id) return entry;
    }
    return null;
  }

  Future<void> upsertWeight(WeightEntry entry) async {
    final WeightEntry stamped = entry.copyWith(
      createdAtMs: entry.createdAtMs == 0 ? _nowMs() : entry.createdAtMs,
      updatedAtMs: _nowMs(),
    );
    await _store.put(RecordKind.weight, stamped.id, stamped.toJson());
    _insertSorted(_data.weights, stamped, _byDateThenTime);
  }

  Future<void> deleteWeight(String id) async {
    await _store.delete(RecordKind.weight, id);
    _data.weights.removeWhere((WeightEntry e) => e.id == id);
  }

  // -------------------------------------------------------------- symptoms

  List<SymptomEntry> get symptomEntries =>
      List<SymptomEntry>.unmodifiable(_data.symptoms);

  SymptomEntry? symptomEntryById(String id) {
    for (final SymptomEntry entry in _data.symptoms) {
      if (entry.id == id) return entry;
    }
    return null;
  }

  Future<void> upsertSymptom(SymptomEntry entry) async {
    final SymptomEntry stamped = entry.copyWith(
      createdAtMs: entry.createdAtMs == 0 ? _nowMs() : entry.createdAtMs,
      updatedAtMs: _nowMs(),
    );
    await _store.put(RecordKind.symptom, stamped.id, stamped.toJson());
    _insertSorted(_data.symptoms, stamped, _byDateThenTime);
  }

  Future<void> deleteSymptom(String id) async {
    await _store.delete(RecordKind.symptom, id);
    _data.symptoms.removeWhere((SymptomEntry e) => e.id == id);
  }

  // ------------------------------------------------------- goals, settings

  Goals get goals => _data.goals;

  Future<void> setGoals(Goals goals) async {
    await _store.put(RecordKind.goals, 'goals', goals.toJson());
    _data.goals = goals;
  }

  AppSettings get settings => _data.settings;

  Future<void> setSettings(AppSettings settings) async {
    await _store.put(RecordKind.settings, 'settings', settings.toJson());
    _data.settings = settings;
  }

  // ------------------------------------------------------------ bulk work

  /// Replaces the whole data set (used by import and by "delete everything").
  Future<void> replaceAll(HealthData replacement) async {
    await _store.clear();
    for (final FoodItem food in replacement.foods.values) {
      await _store.put(RecordKind.food, food.id, food.toJson());
    }
    for (final JournalEntry entry in replacement.journalEntries) {
      await _store.put(RecordKind.journalEntry, entry.id, entry.toJson());
    }
    for (final IntakeEntry entry in replacement.intakes) {
      await _store.put(RecordKind.intake, entry.id, entry.toJson());
    }
    for (final PeriodRecord record in replacement.periods) {
      await _store.put(RecordKind.period, record.id, record.toJson());
    }
    for (final WeightEntry entry in replacement.weights) {
      await _store.put(RecordKind.weight, entry.id, entry.toJson());
    }
    for (final SymptomEntry entry in replacement.symptoms) {
      await _store.put(RecordKind.symptom, entry.id, entry.toJson());
    }
    await _store.put(RecordKind.goals, 'goals', replacement.goals.toJson());
    await _store.put(
      RecordKind.settings,
      'settings',
      replacement.settings.toJson(),
    );
    await load();
  }

  /// Removes every record from the local data set.
  Future<void> deleteEverything() async {
    await _store.clear();
    _data = HealthData();
  }

  /// Flushes pending writes.
  Future<void> close() => _store.close();

  int _nowMs() => _clock.now().millisecondsSinceEpoch;

  static void _insertSorted<T>(
    List<T> list,
    T value,
    int Function(T a, T b) compare,
  ) {
    final int index = list.indexWhere((T e) => compare(e, value) > 0);
    if (index < 0) {
      list.add(value);
    } else {
      list.insert(index, value);
    }
  }
}
