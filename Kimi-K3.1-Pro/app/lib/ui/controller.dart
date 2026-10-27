import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/food_api.dart';
import '../core/health.dart';
import '../core/nutrition.dart';
import '../core/repository.dart';
import '../core/utils.dart';

class AppController extends ChangeNotifier {
  AppController(this.repository, this.foodApi) {
    _subscription = repository.changes.listen((_) => notifyListeners());
  }

  final HealthRepository repository;
  final FoodApi foodApi;
  late final StreamSubscription<AppState> _subscription;
  int _navigationIndex = 0;
  late String selectedDate = instantDateKey(DateTime.now());

  AppState get state => repository.state;
  Settings get settings => state.settings;
  DateTime get now => repository.now;
  int get navigationIndex => _navigationIndex;

  void navigate(int index) {
    if (index == _navigationIndex) return;
    _navigationIndex = index;
    notifyListeners();
  }

  void selectDate(String date) {
    parseDate(date);
    if (date == selectedDate) return;
    selectedDate = date;
    notifyListeners();
  }

  Future<Food> importFood(Food incoming) async {
    final existing = state.foods.where((food) {
      return incoming.barcode != null &&
          food.source == 'openfoodfacts' &&
          food.barcode == incoming.barcode;
    }).firstOrNull;
    if (existing == null) {
      await repository.saveFood(incoming);
      return incoming;
    }
    final updated = Food(
      id: existing.id,
      name: incoming.name,
      brand: incoming.brand,
      source: incoming.source,
      measure: incoming.measure,
      portionSize: incoming.portionSize,
      nutrients: incoming.nutrients,
      favorite: existing.favorite,
      barcode: incoming.barcode,
      createdAt: existing.createdAt,
      updatedAt: now,
    );
    await repository.saveFood(updated);
    return updated;
  }

  @override
  void dispose() {
    unawaited(_subscription.cancel());
    unawaited(repository.close());
    foodApi.close();
    super.dispose();
  }
}
