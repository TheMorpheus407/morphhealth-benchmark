import 'dart:async';

import '../model/app_data.dart';
import '../model/entries.dart';
import '../model/food.dart';
import '../model/settings.dart';
import '../nutrition/off_product.dart';
import '../util/dates.dart';
import '../util/ids.dart';
import '../util/json_reader.dart';
import '../version.dart';
import 'data_store.dart';

/// A change was refused because it would make the data inconsistent.
class ValidationException implements Exception {
  /// Stable code, for example `period_overlap`.
  final String code;
  final String message;

  /// Additional values for building a localized message.
  final Map<String, Object?> details;

  const ValidationException(this.code, this.message, [this.details = const {}]);

  @override
  String toString() => 'ValidationException($code): $message';
}

/// Outcome of deleting a food.
enum FoodDeletion {
  /// The food was removed completely.
  removed,

  /// Diary entries still use the food. It was hidden from all lists but kept,
  /// so that those entries stay intact.
  archived,
}

/// The single entry point for reading and changing the user's data.
///
/// The repository keeps the whole data set in memory ([data]) and writes every
/// change to the [DataStore] before it becomes visible. The Android app and
/// the maintenance access `mh` both work through this class.
class HealthRepository {
  static const int _stateSchema = 1;

  final DataStore store;
  final Clock clock;
  final String Function() _newId;

  AppData _data = AppData();
  LocalState _local = const LocalState();
  bool _journalDamaged = false;
  Future<void> _queue = Future.value();
  final List<void Function()> _listeners = [];

  HealthRepository._(this.store, this.clock, this._newId);

  /// Opens [store] and loads its content. A new store starts empty.
  static Future<HealthRepository> open(
    DataStore store, {
    Clock clock = const SystemClock(),
    String Function()? idFactory,
  }) async {
    final repo = HealthRepository._(store, clock, idFactory ?? newId);
    await store.exclusive(repo._load);
    return repo;
  }

  /// The current data. Treat as read-only; change it through the methods of
  /// this class.
  AppData get data => _data;

  LocalState get local => _local;

  /// True if the store had to drop unreadable journal records when loading.
  bool get journalWasDamaged => _journalDamaged;

  /// A fresh record id.
  String createId() => _newId();

  LocalDateTime get now => clock.now();

  Day get today => clock.now().day;

  void addListener(void Function() listener) => _listeners.add(listener);

  void removeListener(void Function() listener) => _listeners.remove(listener);

  void _notify() {
    for (final l in List.of(_listeners)) {
      l();
    }
  }

  // ------------------------------------------------------------ loading

  Future<void> _load() async {
    final state = await store.load();
    final snapshot = state.snapshot;
    if (snapshot == null) {
      _data = AppData();
      _local = const LocalState();
      _journalDamaged = false;
      await store.writeSnapshot(_stateJson());
      return;
    }
    final schema = snapshot['schema'];
    if (schema is! int || schema > _stateSchema) {
      throw const StoreException(
        'unsupported',
        'The data were written by a newer version of MorphHealth.',
      );
    }
    final log = IssueLog();
    final data = AppData.fromDocument(
      snapshot['document'],
      log,
      now: clock.now(),
    );
    if (data == null) {
      throw StoreException(
        'corrupt',
        'The stored data are inconsistent: ${log.errors.first}',
      );
    }
    final localJson = snapshot['local'];
    var local = localJson is Map
        ? LocalState.fromJson(
            ObjectReader(localJson.cast<String, dynamic>(), 'local', log),
          )
        : const LocalState();
    for (final tx in state.journal) {
      for (final op in tx) {
        local = _applyStored(data, local, op);
      }
    }
    _data = data;
    _local = local;
    _journalDamaged = state.journalDamaged;
    if (state.journalDamaged) {
      // Make the recovered state the new baseline.
      await store.writeSnapshot(_stateJson());
    }
  }

  /// Applies one journal operation to [data]; returns the local state.
  LocalState _applyStored(
    AppData data,
    LocalState local,
    Map<String, dynamic> op,
  ) {
    final log = IssueLog();
    final now = clock.now();
    final kind = op['op'];
    final collection = op['c'];
    T need<T>(T? value) {
      if (value == null || log.hasErrors) {
        throw StoreException(
          'corrupt',
          'A journal record cannot be applied: ${log.errors.isEmpty ? op['c'] : log.errors.first}',
        );
      }
      return value;
    }

    if (kind == 'put' || kind == 'set') {
      final v = op['v'];
      if (v is! Map) {
        throw const StoreException('corrupt', 'A journal record has no value.');
      }
      final r = ObjectReader(v.cast<String, dynamic>(), '$collection', log);
      switch (collection) {
        case 'foods':
          data.putFood(need(Food.fromJson(r, now: now, idFactory: _newId)));
        case 'intake':
          data.putIntake(
            need(IntakeEntry.fromJson(r, now: now, idFactory: _newId)),
          );
        case 'water':
          data.putWater(
            need(WaterEntry.fromJson(r, now: now, idFactory: _newId)),
          );
        case 'caffeine':
          data.putCaffeine(
            need(CaffeineEntry.fromJson(r, now: now, idFactory: _newId)),
          );
        case 'weights':
          data.putWeight(
            need(WeightEntry.fromJson(r, now: now, idFactory: _newId)),
          );
        case 'symptoms':
          data.putSymptom(
            need(SymptomEntry.fromJson(r, now: now, idFactory: _newId)),
          );
        case 'periods':
          data.putPeriod(need(Period.fromJson(r, now: now, idFactory: _newId)));
        case 'cycle_days':
          data.putCycleDay(need(CycleDay.fromJson(r, now: now)));
        case 'settings':
          data.settings = need(Settings.fromJson(r));
        case 'goals':
          data.goals = need(Goals.fromJson(r));
        case 'local':
          return need(LocalState.fromJson(r));
        default:
          throw StoreException(
            'corrupt',
            'Unknown collection in journal: $collection',
          );
      }
    } else if (kind == 'del') {
      final id = op['id'];
      if (id is! String) {
        throw const StoreException('corrupt', 'A journal record has no id.');
      }
      switch (collection) {
        case 'foods':
          data.removeFood(id);
        case 'intake':
          data.removeIntake(id);
        case 'water':
          data.removeWater(id);
        case 'caffeine':
          data.removeCaffeine(id);
        case 'weights':
          data.removeWeight(id);
        case 'symptoms':
          data.removeSymptom(id);
        case 'periods':
          data.removePeriod(id);
        case 'cycle_days':
          final d = Day.tryParse(id);
          if (d != null) data.removeCycleDay(d);
        default:
          throw StoreException(
            'corrupt',
            'Unknown collection in journal: $collection',
          );
      }
    } else {
      throw StoreException('corrupt', 'Unknown journal operation: $kind');
    }
    return local;
  }

  Map<String, dynamic> _stateJson() => {
    'schema': _stateSchema,
    'document': _data.toDocument(
      exportedAt: clock.now(),
      appVersion: morphHealthVersion,
    ),
    'local': _local.toJson(),
  };

  // ------------------------------------------------------------ writing

  /// Writes [ops] as one transaction, then runs [apply] on the in-memory data
  /// and notifies listeners. Changes are strictly serialized.
  Future<void> _commit(List<Map<String, dynamic>> ops, void Function() apply) {
    final done = _queue.then((_) async {
      await store.append(ops);
      apply();
      if (store.wantsCompaction) {
        await store.writeSnapshot(_stateJson());
      }
    });
    _queue = done.catchError((Object _) {});
    return done.then((_) => _notify());
  }

  static Map<String, dynamic> _put(String c, Map<String, dynamic> v) => {
    'op': 'put',
    'c': c,
    'v': v,
  };

  static Map<String, dynamic> _set(String c, Map<String, dynamic> v) => {
    'op': 'set',
    'c': c,
    'v': v,
  };

  static Map<String, dynamic> _del(String c, String id) => {
    'op': 'del',
    'c': c,
    'id': id,
  };

  /// Runs [action] with the store locked against other processes, after
  /// picking up changes another process may have written. Used by `mh`.
  Future<T> session<T>(Future<T> Function() action) =>
      store.exclusive(() async {
        if (await store.hasChangedOutside()) {
          await _load();
          _notify();
        }
        return action();
      });

  // -------------------------------------------------------------- foods

  /// Creates or updates a food.
  Future<Food> saveFood(Food food) async {
    if (food.name.trim().isEmpty) {
      throw const ValidationException('name_required', 'A food needs a name.');
    }
    final stored = food.copyWith(updatedAt: clock.now());
    await _commit([
      _put('foods', stored.toJson()),
    ], () => _data.putFood(stored));
    return stored;
  }

  Future<void> setFavorite(String foodId, bool favorite) async {
    final food = _data.food(foodId);
    if (food == null || food.favorite == favorite) return;
    await saveFood(food.copyWith(favorite: favorite));
  }

  /// Deletes a food. If diary entries refer to it, it is archived instead.
  Future<FoodDeletion> deleteFood(String foodId) async {
    final food = _data.food(foodId);
    if (food == null) return FoodDeletion.removed;
    if (_data.intakeCountForFood(foodId) > 0) {
      final archived = food.copyWith(
        archived: true,
        favorite: false,
        updatedAt: clock.now(),
      );
      await _commit([
        _put('foods', archived.toJson()),
      ], () => _data.putFood(archived));
      return FoodDeletion.archived;
    }
    await _commit([_del('foods', foodId)], () => _data.removeFood(foodId));
    return FoodDeletion.removed;
  }

  /// Keeps a product from Open Food Facts as a local food, so that it can be
  /// logged again without a connection. A product that is already kept
  /// (same barcode) is refreshed and keeps its id and favorite mark.
  Future<Food> adoptProduct(CatalogProduct product) {
    final barcode = normalizeBarcode(product.barcode) ?? product.barcode;
    final existing = _data.foodByBarcode(
      barcode,
      source: FoodSource.openFoodFacts,
    );
    final now = clock.now();
    if (existing != null) {
      return saveFood(
        existing.copyWith(
          name: product.name,
          brand: product.brand,
          basis: product.basis,
          servingSize: product.servingSize ?? existing.servingSize,
          servingLabel: product.servingSize == null
              ? existing.servingLabel
              : product.servingLabel,
          packageQuantity: product.quantity,
          nutrients: product.nutrients.copy(),
          estimated: Set.of(product.estimated),
          prepared: product.prepared,
          archived: false,
          fetchedAt: now,
        ),
      );
    }
    return saveFood(
      product.toFood(id: _newId(), now: now).copyWith(barcode: barcode),
    );
  }

  // ------------------------------------------------------------- intake

  /// Creates or updates a diary entry for a consumed food.
  Future<IntakeEntry> saveIntake(IntakeEntry entry) async {
    final food = _data.food(entry.foodId);
    if (food == null) {
      throw const ValidationException(
        'food_missing',
        'The food of this entry does not exist.',
      );
    }
    if (!(entry.amount > 0) || entry.amount.isInfinite) {
      throw const ValidationException(
        'amount_invalid',
        'The amount must be greater than zero.',
      );
    }
    var stored = entry.copyWith(updatedAt: clock.now());
    if (stored.unit == AmountUnit.portion) {
      final size = stored.portionSize ?? food.servingSize;
      if (size == null || !(size > 0)) {
        throw const ValidationException(
          'portion_size_missing',
          'A portion size is needed to log portions of this food.',
        );
      }
      stored = stored.copyWith(portionSize: size);
    } else if (stored.portionSize != null) {
      stored = stored.copyWith(portionSize: null);
    }
    await _commit([
      _put('intake', stored.toJson()),
    ], () => _data.putIntake(stored));
    return stored;
  }

  /// Logs a food.
  Future<IntakeEntry> logIntake({
    required String foodId,
    required double amount,
    required AmountUnit unit,
    LocalDateTime? at,
    Meal? meal,
    double? portionSize,
    String? note,
  }) {
    final time = at ?? clock.now();
    return saveIntake(
      IntakeEntry(
        id: _newId(),
        foodId: foodId,
        at: time,
        meal: meal ?? Meal.suggestFor(time),
        amount: amount,
        unit: unit,
        portionSize: portionSize,
        note: note,
        createdAt: clock.now(),
        updatedAt: clock.now(),
      ),
    );
  }

  /// Logs the same food and amount as [entryId] again, at [at] (default: now)
  /// and in the same meal unless [meal] is given.
  Future<IntakeEntry> relogIntake(
    String entryId, {
    LocalDateTime? at,
    Meal? meal,
  }) {
    final source = _data.intakeEntry(entryId);
    if (source == null) {
      throw const ValidationException(
        'entry_missing',
        'The entry to repeat does not exist.',
      );
    }
    return saveIntake(
      IntakeEntry(
        id: _newId(),
        foodId: source.foodId,
        at: at ?? clock.now(),
        meal: meal ?? source.meal,
        amount: source.amount,
        unit: source.unit,
        portionSize: source.portionSize,
        note: null,
        createdAt: clock.now(),
        updatedAt: clock.now(),
      ),
    );
  }

  Future<void> deleteIntake(String id) async {
    if (_data.intakeEntry(id) == null) return;
    await _commit([_del('intake', id)], () => _data.removeIntake(id));
  }

  // -------------------------------------------------- water and caffeine

  Future<WaterEntry> saveWater(WaterEntry entry) async {
    if (!(entry.amountMl > 0) || entry.amountMl > 20000) {
      throw const ValidationException(
        'amount_invalid',
        'The amount of water must be between 1 and 20000 ml.',
      );
    }
    final stored = entry.copyWith(updatedAt: clock.now());
    await _commit([
      _put('water', stored.toJson()),
    ], () => _data.putWater(stored));
    return stored;
  }

  Future<WaterEntry> addWater(double amountMl, {LocalDateTime? at}) =>
      saveWater(
        WaterEntry(
          id: _newId(),
          at: at ?? clock.now(),
          amountMl: amountMl,
          createdAt: clock.now(),
          updatedAt: clock.now(),
        ),
      );

  Future<void> deleteWater(String id) async {
    if (_data.waterEntry(id) == null) return;
    await _commit([_del('water', id)], () => _data.removeWater(id));
  }

  Future<CaffeineEntry> saveCaffeine(CaffeineEntry entry) async {
    if (!(entry.amountMg > 0) || entry.amountMg > 5000) {
      throw const ValidationException(
        'amount_invalid',
        'The amount of caffeine must be between 1 and 5000 mg.',
      );
    }
    final stored = entry.copyWith(updatedAt: clock.now());
    await _commit([
      _put('caffeine', stored.toJson()),
    ], () => _data.putCaffeine(stored));
    return stored;
  }

  Future<CaffeineEntry> addCaffeine(
    double amountMg, {
    String? label,
    LocalDateTime? at,
  }) => saveCaffeine(
    CaffeineEntry(
      id: _newId(),
      at: at ?? clock.now(),
      amountMg: amountMg,
      label: label,
      createdAt: clock.now(),
      updatedAt: clock.now(),
    ),
  );

  Future<void> deleteCaffeine(String id) async {
    if (_data.caffeineEntry(id) == null) return;
    await _commit([_del('caffeine', id)], () => _data.removeCaffeine(id));
  }

  // -------------------------------------------------------------- weight

  Future<WeightEntry> saveWeight(WeightEntry entry) async {
    if (!(entry.weightKg >= WeightEntry.minKg) ||
        entry.weightKg > WeightEntry.maxKg) {
      throw const ValidationException(
        'weight_invalid',
        'The weight is outside the supported range.',
      );
    }
    final stored = entry.copyWith(updatedAt: clock.now());
    await _commit([
      _put('weights', stored.toJson()),
    ], () => _data.putWeight(stored));
    return stored;
  }

  Future<WeightEntry> addWeight(Day date, double weightKg, {String? note}) =>
      saveWeight(
        WeightEntry(
          id: _newId(),
          date: date,
          weightKg: weightKg,
          note: note,
          createdAt: clock.now(),
          updatedAt: clock.now(),
        ),
      );

  Future<void> deleteWeight(String id) async {
    if (_data.weightEntry(id) == null) return;
    await _commit([_del('weights', id)], () => _data.removeWeight(id));
  }

  // ------------------------------------------------------------ symptoms

  Future<SymptomEntry> saveSymptom(SymptomEntry entry) async {
    final name = entry.name.trim();
    if (name.isEmpty) {
      throw const ValidationException(
        'name_required',
        'A symptom needs a name.',
      );
    }
    if (entry.intensity < 0 || entry.intensity > 10) {
      throw const ValidationException(
        'intensity_invalid',
        'The intensity must be between 0 and 10.',
      );
    }
    final stored = entry.copyWith(name: name, updatedAt: clock.now());
    await _commit([
      _put('symptoms', stored.toJson()),
    ], () => _data.putSymptom(stored));
    return stored;
  }

  Future<SymptomEntry> addSymptom(
    String name,
    int intensity, {
    LocalDateTime? at,
    String? note,
  }) => saveSymptom(
    SymptomEntry(
      id: _newId(),
      name: name,
      intensity: intensity,
      at: at ?? clock.now(),
      note: note,
      createdAt: clock.now(),
      updatedAt: clock.now(),
    ),
  );

  Future<void> deleteSymptom(String id) async {
    if (_data.symptomEntry(id) == null) return;
    await _commit([_del('symptoms', id)], () => _data.removeSymptom(id));
  }

  // --------------------------------------------------------------- cycle

  /// Creates or updates a period. Refuses records that end before they start,
  /// are too long or overlap another period.
  Future<Period> savePeriod(Period period) async {
    final end = period.end;
    if (end != null && end < period.start) {
      throw const ValidationException(
        'period_end_before_start',
        'A period cannot end before it starts.',
      );
    }
    if (end != null && end.daysSince(period.start) + 1 > Period.maxLengthDays) {
      throw const ValidationException(
        'period_too_long',
        'A period can cover at most ${Period.maxLengthDays} days.',
        {'max_days': Period.maxLengthDays},
      );
    }
    final other = _data.overlappingPeriod(period);
    if (other != null) {
      throw ValidationException(
        'period_overlap',
        'The period overlaps the one that starts on ${other.start}.',
        {'other_start': other.start, 'other_end': other.end},
      );
    }
    final stored = period.normalized().copyWith(updatedAt: clock.now());
    await _commit([
      _put('periods', stored.toJson()),
    ], () => _data.putPeriod(stored));
    return stored;
  }

  /// Starts a period on [start] without an end.
  Future<Period> startPeriod(Day start, {FlowLevel? flow}) => savePeriod(
    Period(
      id: _newId(),
      start: start,
      flow: flow == null ? const {} : {start: flow},
      createdAt: clock.now(),
      updatedAt: clock.now(),
    ),
  );

  Future<void> deletePeriod(String id) async {
    if (_data.period(id) == null) return;
    await _commit([_del('periods', id)], () => _data.removePeriod(id));
  }

  /// Sets or clears (null) the bleeding strength of one day of a period.
  Future<Period> setFlow(String periodId, Day day, FlowLevel? level) {
    final period = _data.period(periodId);
    if (period == null) {
      throw const ValidationException(
        'period_missing',
        'The period does not exist.',
      );
    }
    final flow = Map<Day, FlowLevel>.of(period.flow);
    if (level == null) {
      flow.remove(day);
    } else {
      flow[day] = level;
    }
    return savePeriod(period.copyWith(flow: flow));
  }

  /// Stores spotting and note of a day outside a period; an empty record
  /// removes the day.
  Future<void> saveCycleDay(Day date, {required bool spotting, String? note}) {
    final trimmed = note?.trim();
    final value = CycleDay(
      date: date,
      spotting: spotting,
      note: trimmed == null || trimmed.isEmpty ? null : trimmed,
      updatedAt: clock.now(),
    );
    if (value.isEmpty) {
      if (_data.cycleDay(date) == null) return Future.value();
      return _commit([
        _del('cycle_days', date.toString()),
      ], () => _data.removeCycleDay(date));
    }
    return _commit([
      _put('cycle_days', value.toJson()),
    ], () => _data.putCycleDay(value));
  }

  // ------------------------------------------------- settings and goals

  Future<void> updateSettings(Settings settings) => _commit([
    _set('settings', settings.toJson()),
  ], () => _data.settings = settings);

  Future<void> updateGoals(Goals goals) =>
      _commit([_set('goals', goals.toJson())], () => _data.goals = goals);

  Future<void> updateLocal(LocalState local) =>
      _commit([_set('local', local.toJson())], () => _local = local);

  // ----------------------------------------------------------- bulk work

  /// Replaces all user data by [data] (import and restore). The local state
  /// of this installation is kept.
  Future<void> replaceAll(AppData data) {
    final done = _queue.then((_) async {
      final previous = _data;
      _data = data;
      try {
        await store.writeSnapshot(_stateJson());
      } on Object {
        _data = previous;
        rethrow;
      }
    });
    _queue = done.catchError((Object _) {});
    return done.then((_) => _notify());
  }

  /// Deletes all user data and the local state of this installation.
  Future<void> wipe() {
    final done = _queue.then((_) async {
      await store.wipe();
      _data = AppData();
      _local = const LocalState();
      await store.writeSnapshot(_stateJson());
    });
    _queue = done.catchError((Object _) {});
    return done.then((_) => _notify());
  }

  /// Deletes all stored files and leaves the store empty, without writing a
  /// new one. Used before the encryption key itself is destroyed; the
  /// repository must not be used afterwards.
  Future<void> destroy() {
    final done = _queue.then((_) async {
      await store.wipe();
      _data = AppData();
      _local = const LocalState();
    });
    _queue = done.catchError((Object _) {});
    return done;
  }

  /// Folds the journal into a fresh snapshot.
  Future<void> compact() {
    final done = _queue.then((_) => store.writeSnapshot(_stateJson()));
    _queue = done.catchError((Object _) {});
    return done;
  }

  /// Completes when all changes requested so far are written.
  Future<void> flush() => _queue;
}
