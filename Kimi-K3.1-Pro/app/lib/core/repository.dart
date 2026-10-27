import 'dart:async';

import 'health.dart';
import 'nutrition.dart';
import 'utils.dart';

abstract interface class StateStore {
  Future<AppState?> load();
  Future<void> save(AppState state);
  Future<void> clear();
}

class HealthRepository {
  HealthRepository._(this._store, this._state, this._clock);

  final StateStore _store;
  final DateTime Function() _clock;
  final _changes = StreamController<AppState>.broadcast(sync: true);
  AppState _state;
  Future<void> _queue = Future.value();

  AppState get state => _state;
  Stream<AppState> get changes => _changes.stream;
  DateTime get now => _clock();

  static Future<HealthRepository> open(
    StateStore store, {
    DateTime Function()? clock,
  }) async {
    final loaded = await store.load();
    final repository = HealthRepository._(
      store,
      loaded ?? AppState.initial(),
      clock ?? DateTime.now,
    );
    if (loaded == null) await store.save(repository.state);
    return repository;
  }

  Future<T> _serialized<T>(Future<T> Function() operation) {
    final result = _queue.then((_) => operation());
    _queue = result.then((_) {}, onError: (_, _) {});
    return result;
  }

  Future<void> _update(AppState Function(AppState current) update) =>
      _serialized(() async {
        final next = update(_state);
        next.validate();
        await _store.save(next);
        _state = next;
        _changes.add(next);
      });

  Future<void> saveFood(Food food) => _update((current) {
    final exists = current.foods.any((item) => item.id == food.id);
    return current.copyWith(
      foods: exists
          ? current.foods
                .map((item) => item.id == food.id ? food : item)
                .toList()
          : [...current.foods, food],
    );
  });

  Future<void> deleteFood(String id) => _update((current) {
    if (current.intakes.any((entry) => entry.foodId == id)) {
      throw StateError('food_in_use');
    }
    return current.copyWith(
      foods: current.foods.where((item) => item.id != id).toList(),
    );
  });

  Future<void> saveIntake(IntakeEntry entry) => _update((current) {
    final exists = current.intakes.any((item) => item.id == entry.id);
    return current.copyWith(
      intakes: exists
          ? current.intakes
                .map((item) => item.id == entry.id ? entry : item)
                .toList()
          : [...current.intakes, entry],
    );
  });

  Future<void> deleteIntake(String id) => _update(
    (current) => current.copyWith(
      intakes: current.intakes.where((item) => item.id != id).toList(),
    ),
  );

  Future<void> repeatIntake(String id, {DateTime? at}) => _update((current) {
    final original = current.intakes.firstWhere(
      (entry) => entry.id == id,
      orElse: () => throw StateError('intake_not_found'),
    );
    final timestamp = (at ?? _clock()).toUtc();
    final copy = IntakeEntry(
      id: newId(),
      kind: original.kind,
      occurredAt: timestamp,
      meal: original.meal,
      foodId: original.foodId,
      foodName: original.foodName,
      brand: original.brand,
      amount: original.amount,
      unit: original.unit,
      portionSize: original.portionSize,
      nutrients: original.nutrients,
      notes: original.notes,
      createdAt: timestamp,
      updatedAt: timestamp,
    );
    return current.copyWith(intakes: [...current.intakes, copy]);
  });

  Future<void> addWater(double amountMl, {DateTime? at}) =>
      _addSimpleIntake(IntakeKind.water, amountMl, 'ml', at);

  Future<void> addCaffeine(double amountMg, {DateTime? at}) =>
      _addSimpleIntake(IntakeKind.caffeine, amountMg, 'mg', at);

  Future<void> _addSimpleIntake(
    IntakeKind kind,
    double amount,
    String unit,
    DateTime? at,
  ) {
    if (!amount.isFinite || amount <= 0)
      throw ArgumentError.value(amount, 'amount');
    return _update((current) {
      final timestamp = (at ?? _clock()).toUtc();
      return current.copyWith(
        intakes: [
          ...current.intakes,
          IntakeEntry(
            id: newId(),
            kind: kind,
            occurredAt: timestamp,
            meal: 'snack',
            amount: amount,
            unit: unit,
            nutrients: const {},
            createdAt: timestamp,
            updatedAt: timestamp,
          ),
        ],
      );
    });
  }

  Future<void> savePeriod(Period period) => _update((current) {
    final exists = current.periods.any((item) => item.id == period.id);
    return current.copyWith(
      periods: exists
          ? current.periods
                .map((item) => item.id == period.id ? period : item)
                .toList()
          : [...current.periods, period],
    );
  });

  Future<void> deletePeriod(String id) => _update(
    (current) => current.copyWith(
      periods: current.periods.where((item) => item.id != id).toList(),
    ),
  );

  Future<void> saveWeight(WeightEntry entry) => _update((current) {
    final exists = current.weights.any((item) => item.id == entry.id);
    return current.copyWith(
      weights: exists
          ? current.weights
                .map((item) => item.id == entry.id ? entry : item)
                .toList()
          : [...current.weights, entry],
    );
  });

  Future<void> deleteWeight(String id) => _update(
    (current) => current.copyWith(
      weights: current.weights.where((item) => item.id != id).toList(),
    ),
  );

  Future<void> saveSymptom(SymptomEntry entry) => _update((current) {
    final exists = current.symptoms.any((item) => item.id == entry.id);
    return current.copyWith(
      symptoms: exists
          ? current.symptoms
                .map((item) => item.id == entry.id ? entry : item)
                .toList()
          : [...current.symptoms, entry],
    );
  });

  Future<void> deleteSymptom(String id) => _update(
    (current) => current.copyWith(
      symptoms: current.symptoms.where((item) => item.id != id).toList(),
    ),
  );

  Future<void> updateSettings(Settings settings) =>
      _update((current) => current.copyWith(settings: settings));

  Future<void> replaceAll(AppState replacement) => _update((_) => replacement);

  Future<void> wipe() => _serialized(() async {
    await _store.clear();
    final initial = AppState.initial();
    await _store.save(initial);
    _state = initial;
    _changes.add(initial);
  });

  NutritionDay nutritionDay(String date) =>
      summarizeNutrition(date, _state.intakes);

  Future<void> close() async {
    await _queue;
    await _changes.close();
  }
}
