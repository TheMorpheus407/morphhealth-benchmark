// Gemeinsame Test-Hilfen: In-Memory-Store-Backend und Modell-Builder.
//
// Der MemoryStoreBackend serialisiert das Dokument bei jedem Speichern über
// JSON (wie der echte Datei-Store), damit Mutation-/Serialisierungsfehler
// in Tests sichtbar werden.
library;

import 'dart:convert';

import 'package:morphhealth/src/core/clock.dart';
import 'package:morphhealth/src/data/repository.dart';
import 'package:morphhealth/src/model/cycle.dart';
import 'package:morphhealth/src/model/document.dart';
import 'package:morphhealth/src/model/entries.dart';
import 'package:morphhealth/src/model/food.dart';
import 'package:morphhealth/src/nutrients/nutrients.dart';

/// Store-Backend, das das Dokument im Speicher hält (mit JSON-Roundtrip).
class MemoryStoreBackend implements StoreBackend {
  MorphDocument? _doc;
  bool deleteAllCalled = false;
  int saveCount = 0;

  @override
  Future<MorphDocument> load() async {
    final MorphDocument? current = _doc;
    if (current == null) return MorphDocument.empty();
    // Deep Copy über JSON — wie ein echter Persistenz- roundtrip.
    return MorphDocument.fromDataJson(
        jsonDecode(jsonEncode(current.toDataJson())) as Map<String, dynamic>);
  }

  @override
  Future<void> save(MorphDocument doc) async {
    saveCount++;
    _doc = MorphDocument.fromDataJson(
        jsonDecode(jsonEncode(doc.toDataJson())) as Map<String, dynamic>);
  }

  @override
  Future<void> deleteAll() async {
    deleteAllCalled = true;
    _doc = null;
  }
}

/// Baut ein Repository mit festem Datum (2026-09-23, 12:00 UTC).
Future<MorphRepository> makeRepo({MemoryStoreBackend? backend}) async {
  final MemoryStoreBackend b = backend ?? MemoryStoreBackend();
  final MorphRepository repo = MorphRepository(
    b,
    clock: FixedClock(DateTime.utc(2026, 9, 23, 12)),
    appInfo: const AppInfo(name: 'MorphHealth', version: '1.0.0+1'),
  );
  await repo.load();
  return repo;
}

/// Festes Datum für Fabrikfunktionen.
final DateTime testCreatedAt = DateTime.utc(2026, 9, 23, 8);

/// Ein Lebensmittel mit realistischen Nährwerten pro 100 g.
FoodItem makeFood({
  String id = 'food-1',
  String name = 'Haferflocken',
  String? brand,
  String? barcode,
  FoodSource source = FoodSource.custom,
  Map<String, double>? per100,
  Serving? serving,
  bool isFavorite = false,
}) {
  return FoodItem(
    id: id,
    name: name,
    brand: brand,
    barcode: barcode,
    source: source,
    per100: per100 ??
        <String, double>{
          'energy_kcal': 372,
          'protein_g': 13.5,
          'carbohydrates_g': 58.7,
          'fat_g': 7,
          'fiber_g': 10,
          'calcium_mg': 54,
          'iron_mg': 4.3,
        },
    serving: serving,
    isFavorite: isFavorite,
    createdAt: testCreatedAt,
    updatedAt: testCreatedAt,
  );
}

/// Ein Verzehreintrag (Standard: 100 g Haferflocken an einem Tag).
NutritionEntry makeNutritionEntry({
  String id = 'entry-1',
  String foodId = 'food-1',
  String foodName = 'Haferflocken',
  Map<String, double>? foodPer100,
  double? foodServingGrams,
  String date = '2026-09-23',
  String? time = '07:30',
  Meal meal = Meal.breakfast,
  double quantity = 100,
  QuantityUnit unit = QuantityUnit.g,
  String? note,
}) {
  return NutritionEntry(
    id: id,
    foodId: foodId,
    foodName: foodName,
    foodPer100: foodPer100 ??
        <String, double>{
          'energy_kcal': 372,
          'protein_g': 13.5,
        },
    foodServingGrams: foodServingGrams,
    date: date,
    time: time,
    meal: meal,
    quantity: quantity,
    unit: unit,
    note: note,
    createdAt: testCreatedAt,
  );
}

WaterEntry makeWaterEntry({
  String id = 'water-1',
  String date = '2026-09-23',
  String? time = '08:00',
  double amountMl = 250,
  String? note,
}) =>
    WaterEntry(id: id, date: date, time: time, amountMl: amountMl, note: note);

CaffeineEntry makeCaffeineEntry({
  String id = 'caffeine-1',
  String date = '2026-09-23',
  String? time = '09:15',
  double amountMg = 80,
  String? note,
}) =>
    CaffeineEntry(id: id, date: date, time: time, amountMg: amountMg, note: note);

PeriodRecord makePeriod({
  String id = 'period-1',
  String start = '2026-08-28',
  String? end = '2026-09-01',
  FlowLevel flow = FlowLevel.medium,
  Map<String, int>? flowByDay,
  String? note,
}) =>
    PeriodRecord(
        id: id, start: start, end: end, flow: flow, flowByDay: flowByDay, note: note);

WeightEntry makeWeightEntry({
  String id = 'weight-1',
  String date = '2026-09-23',
  String? time = '07:00',
  double weightKg = 72.5,
  String? note,
}) =>
    WeightEntry(id: id, date: date, time: time, weightKg: weightKg, note: note);

SymptomEntry makeSymptomEntry({
  String id = 'symptom-1',
  String name = 'Kopfschmerzen',
  int intensity = 4,
  String date = '2026-09-23',
  String? time = '14:00',
  String? note,
}) =>
    SymptomEntry(
        id: id,
        name: name,
        intensity: intensity,
        date: date,
        time: time,
        note: note);

/// Leere Nährwerttabelle mit einem gesetzten Wert (für kompakte Fixtures).
Map<String, double> nutrientsWith(Map<String, double> values) {
  final Map<String, double> m = emptyNutrientMap();
  m.addAll(values);
  return m;
}
