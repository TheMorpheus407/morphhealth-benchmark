import 'dart:convert';

import 'package:morphhealth/core/health.dart';
import 'package:morphhealth/core/nutrition.dart';
import 'package:morphhealth/core/repository.dart';

DateTime testTimestamp([int hour = 12]) => DateTime.utc(2026, 1, 15, hour);

Food testFood({
  String id = 'food-1',
  String name = 'Testmüsli',
  String brand = 'Testmarke',
  String source = 'custom',
  String measure = 'g',
  double? portionSize = 30,
  Map<String, double>? nutrients,
  bool favorite = false,
  String? barcode,
}) => Food(
  id: id,
  name: name,
  brand: brand,
  source: source,
  measure: measure,
  portionSize: portionSize,
  nutrients:
      nutrients ??
      const {
        'calories': 200,
        'protein': 10,
        'carbs': 30,
        'fat': 5,
        'caffeine': 20,
      },
  favorite: favorite,
  barcode: barcode,
  createdAt: testTimestamp(8),
  updatedAt: testTimestamp(9),
);

IntakeEntry testFoodIntake({
  String id = 'intake-1',
  String foodId = 'food-1',
  String foodName = 'Testmüsli',
  String brand = 'Testmarke',
  DateTime? occurredAt,
  String meal = 'breakfast',
  double amount = 100,
  String unit = 'g',
  double? portionSize,
  Map<String, double>? nutrients,
  String notes = '',
}) => IntakeEntry(
  id: id,
  kind: IntakeKind.food,
  occurredAt: occurredAt ?? testTimestamp(),
  meal: meal,
  foodId: foodId,
  foodName: foodName,
  brand: brand,
  amount: amount,
  unit: unit,
  portionSize: portionSize,
  nutrients:
      nutrients ??
      const {
        'calories': 200,
        'protein': 10,
        'carbs': 30,
        'fat': 5,
        'caffeine': 20,
      },
  notes: notes,
  createdAt: testTimestamp(10),
  updatedAt: testTimestamp(11),
);

IntakeEntry testSimpleIntake({
  String id = 'simple-1',
  IntakeKind kind = IntakeKind.water,
  DateTime? occurredAt,
  double amount = 250,
  String notes = '',
}) => IntakeEntry(
  id: id,
  kind: kind,
  occurredAt: occurredAt ?? testTimestamp(),
  meal: 'snack',
  amount: amount,
  unit: kind == IntakeKind.water ? 'ml' : 'mg',
  nutrients: const {},
  notes: notes,
  createdAt: testTimestamp(10),
  updatedAt: testTimestamp(11),
);

Period testPeriod({
  String id = 'period-1',
  String start = '2026-01-01',
  String? end = '2026-01-05',
  String flow = 'medium',
  String notes = '',
}) => Period(
  id: id,
  start: start,
  end: end,
  flow: flow,
  notes: notes,
  createdAt: testTimestamp(8),
  updatedAt: testTimestamp(9),
);

WeightEntry testWeight({
  String id = 'weight-1',
  String date = '2026-01-15',
  double kg = 70,
  String notes = '',
}) => WeightEntry(
  id: id,
  date: date,
  kg: kg,
  notes: notes,
  createdAt: testTimestamp(8),
  updatedAt: testTimestamp(9),
);

SymptomEntry testSymptom({
  String id = 'symptom-1',
  String name = 'Kopfschmerz',
  int intensity = 4,
  DateTime? occurredAt,
  String notes = '',
}) => SymptomEntry(
  id: id,
  name: name,
  intensity: intensity,
  occurredAt: occurredAt ?? testTimestamp(),
  notes: notes,
  createdAt: testTimestamp(8),
  updatedAt: testTimestamp(9),
);

AppState testState({
  List<Food> foods = const [],
  List<IntakeEntry> intakes = const [],
  List<Period> periods = const [],
  List<WeightEntry> weights = const [],
  List<SymptomEntry> symptoms = const [],
  Settings settings = const Settings(),
}) => AppState(
  foods: foods,
  intakes: intakes,
  periods: periods,
  weights: weights,
  symptoms: symptoms,
  settings: settings,
);

AppState fullTestState() {
  final food = testFood(favorite: true, barcode: '4001234567890');
  return testState(
    foods: [food],
    intakes: [
      testFoodIntake(
        portionSize: 30,
        notes: 'Frühstück draußen',
        nutrients: food.nutrients,
      ),
      testSimpleIntake(id: 'water-1', occurredAt: testTimestamp(13)),
      testSimpleIntake(
        id: 'caffeine-1',
        kind: IntakeKind.caffeine,
        occurredAt: testTimestamp(14),
        amount: 75,
      ),
    ],
    periods: [testPeriod(notes: 'Zyklusnotiz')],
    weights: [testWeight(notes: 'Morgens')],
    symptoms: [testSymptom(notes: 'Leicht')],
    settings: const Settings(
      language: 'en',
      weightUnit: 'lb',
      showNutrition: false,
      showCycle: true,
      showWeight: false,
      showSymptoms: true,
      onlineEnabled: false,
      cycleForecastEnabled: false,
      goals: Goals(
        waterMl: 2000,
        calories: 2100,
        protein: 120,
        carbs: 230,
        fat: 70,
      ),
    ),
  );
}

dynamic cloneJson(Object? value) => jsonDecode(jsonEncode(value));

class MemoryStateStore implements StateStore {
  MemoryStateStore([this.stored]);

  AppState? stored;
  Object? saveFailure;
  int loadCount = 0;
  int saveCount = 0;
  int clearCount = 0;

  @override
  Future<AppState?> load() async {
    loadCount++;
    return stored;
  }

  @override
  Future<void> save(AppState state) async {
    saveCount++;
    await Future<void>.delayed(Duration.zero);
    final failure = saveFailure;
    if (failure != null) throw failure;
    stored = state;
  }

  @override
  Future<void> clear() async {
    clearCount++;
    await Future<void>.delayed(Duration.zero);
    stored = null;
  }
}
