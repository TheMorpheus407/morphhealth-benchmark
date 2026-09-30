import 'package:morphhealth/core/civil.dart';
import 'package:morphhealth/core/clock.dart';
import 'package:morphhealth/core/core.dart';
import 'package:morphhealth/core/db.dart';
import 'package:morphhealth/core/models.dart';
import 'package:morphhealth/core/nutrients.dart';
import 'package:morphhealth/core/store.dart';

/// Ein Kern im Speicher mit angehaltener Uhr (2026-09-29 12:00 Ortszeit).
Future<MorphCore> memoryCore({DateTime? now}) =>
    MorphCore.open(persistence: MemoryPersistence(), clock: FixedClock(now ?? DateTime(2026, 9, 29, 12)));

FoodInfo oats({FoodSource source = FoodSource.custom}) => FoodInfo(
  name: 'Haferflocken',
  source: source,
  serving: const Serving(40, '1 Portion'),
  nutrients: Nutrients.of({'energy_kcal': 372, 'protein_g': 13.5, 'carbohydrates_g': 58.7, 'fat_g': 7, 'iron_mg': 4.6}),
);

FoodEntry entryOf(
  FoodInfo food,
  String at, {
  double amount = 100,
  AmountUnit unit = AmountUnit.g,
  Meal meal = Meal.breakfast,
  String id = '',
  String? foodId,
}) => FoodEntry(
  id: id.isEmpty ? 'e$at$amount' : id,
  foodId: foodId,
  food: food,
  amount: amount,
  unit: unit,
  meal: meal,
  at: LocalDateTime.parse(at),
);

Day day(String s) => Day.parse(s);

Future<Db> memoryDb({DateTime? now}) async => (await memoryCore(now: now)).db;
