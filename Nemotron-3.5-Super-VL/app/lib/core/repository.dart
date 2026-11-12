library morphhealth.core.repository;

import 'dart:convert';
import 'dart:io';

import 'package:intl/intl.dart';

import 'model/entries.dart';
import 'model/food.dart';
import 'model/nutrients.dart';
import 'service/off_client.dart';
import 'storage/encrypted_store.dart';

export 'model/entries.dart';
export 'model/food.dart';
export 'model/nutrients.dart';

/// Zentrale Datenhaltung für App und `mh`-CLI (gleiche Implementierung).
///
/// Der gesamte Datenbestand liegt im Arbeitsspeicher und wird verschlüsselt
/// in einer einzigen Datei abgelegt. Jede Änderung wird sofort gespeichert.
class HealthRepository {
  HealthRepository({
    required EncryptedStore store,
    required String dataPath,
    required this.now,
    OpenFoodFactsClient? foodClient,
  })  : _store = store,
        _dataPath = dataPath,
        _foodClient = foodClient,
        _data = HealthData();

  final EncryptedStore _store;
  final String _dataPath;
  final DateTime Function() now;
  final OpenFoodFactsClient? _foodClient;

  /// Offene Lebensmittelsuche (P08). Gleicher Client wie im `mh`-CLI.
  OpenFoodFactsClient? get foodClient => _foodClient;

  /// Pfad der verschlüsselten Datendatei (auch für Backup/Restore nutzbar).
  String get dataPath => _dataPath;

  HealthData _data;

  /// Ob bereits Daten geladen wurden.
  bool get isLoaded => _data.createdAt != null || _isDirty;

  bool _isDirty = false;

  /// Datenbestand aus der verschlüsselten Datei laden. Fehlt die Datei, wird
  /// ein leerer Bestand erzeugt.
  Future<void> load() async {
    final plaintext = await _store.readPlaintext(_dataPath);
    if (plaintext.trim().isEmpty) {
      _data = HealthData(createdAt: now());
    } else {
      _data = HealthData.fromJson(jsonDecode(plaintext) as Map<String, dynamic>);
    }
    _isDirty = false;
  }

  /// Datenbestand verschlüsselt speichern.
  Future<void> save() async {
    final snapshot = HealthData(
      localFoods: _data.localFoods,
      cachedProducts: _data.cachedProducts,
      nutritionEntries: _data.nutritionEntries,
      waterEntries: _data.waterEntries,
      caffeineEntries: _data.caffeineEntries,
      cycleEntries: _data.cycleEntries,
      symptomEntries: _data.symptomEntries,
      weightEntries: _data.weightEntries,
      goals: _data.goals,
      settings: _data.settings,
      format: 'morphhealth.v1',
      createdAt: now(),
    );
    await _store.writePlaintext(_dataPath, jsonEncode(snapshot.toJson()));
    _isDirty = false;
  }

  /* ============================ Lebensmittel ============================ */

  List<LocalFood> get localFoods => List.unmodifiable(_data.localFoods);

  LocalFood? findLocalFood(String id) =>
      _data.localFoods.firstWhere((f) => f.id == id, orElse: () => throw Exception('Eintrag nicht gefunden'));

  OffProduct? findCachedProduct(String id) {
    for (final p in _data.cachedProducts) {
      if (p.id == id) return p;
    }
    return null;
  }

  LocalFood addLocalFood(LocalFood food) {
    final entry = LocalFood(
      id: food.id.isEmpty ? uuid() : food.id,
      name: food.name,
      brand: food.brand,
      profile: food.profile,
      servingSizeGrams: food.servingSizeGrams,
      imageUrl: food.imageUrl,
      createdAt: now(),
      updatedAt: now(),
    );
    _data.localFoods.add(entry);
    _isDirty = true;
    return entry;
  }

  LocalFood updateLocalFood(String id, LocalFood updated) {
    final index = _data.localFoods.indexWhere((f) => f.id == id);
    if (index < 0) throw Exception('Eintrag nicht gefunden');
    final entry = LocalFood(
      id: id,
      name: updated.name,
      brand: updated.brand,
      profile: updated.profile,
      servingSizeGrams: updated.servingSizeGrams,
      imageUrl: updated.imageUrl,
      createdAt: _data.localFoods[index].createdAt,
      updatedAt: now(),
    );
    _data.localFoods[index] = entry;
    _isDirty = true;
    return entry;
  }

  void deleteLocalFood(String id) {
    final found = _data.localFoods.any((f) => f.id == id);
    _data.localFoods.removeWhere((f) => f.id == id);
    if (!found) {
      throw Exception('Eintrag nicht gefunden');
    }
    _isDirty = true;
  }

  /// OFF-Produkt in den lokalen Cache übernehmen (schreibgeschützt).
  void cacheProduct(OffProduct product) {
    final index = _data.cachedProducts.indexWhere((p) => p.id == product.id);
    if (index >= 0) {
      _data.cachedProducts[index] = product;
    } else {
      _data.cachedProducts.add(product);
    }
    _isDirty = true;
  }

  /// Alle Lebensmittel (lokale + gecachte OFF-Produkte) durchsuchbar.
  List<Food> searchFoods(String query) {
    final q = query.toLowerCase();
    return <Food>[
      ..._data.localFoods.where((f) => f.name.toLowerCase().contains(q)),
      ..._data.cachedProducts.where((p) => p.name.toLowerCase().contains(q)),
    ];
  }

  /* ============================ Ernährung ============================ */

  List<NutritionEntry> get nutritionEntries => List.unmodifiable(_data.nutritionEntries);

  List<NutritionEntry> nutritionEntriesForDay(DateTime day) {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    final result = _data.nutritionEntries
        .where((e) => e.occurredAt.isAfter(start.subtract(const Duration(seconds: 1))) &&
            e.occurredAt.isBefore(end))
        .toList();
    result.sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
    return result;
  }

  List<NutritionEntry> nutritionEntriesInRange(DateTime start, DateTime end) =>
      _data.nutritionEntries
          .where((e) =>
              !e.occurredAt.isBefore(start) && e.occurredAt.isBefore(end))
          .toList();

  NutritionEntry addNutritionEntry(NutritionEntry entry) {
    final created = NutritionEntry(
      id: entry.id.isEmpty ? uuid() : entry.id,
      foodSource: entry.foodSource,
      foodId: entry.foodId,
      foodName: entry.foodName,
      profilePer100g: entry.profilePer100g,
      amountGrams: entry.amountGrams,
      amountMilliliters: entry.amountMilliliters,
      servingCount: entry.servingCount,
      occurredAt: entry.occurredAt,
      meal: entry.meal,
      createdAt: now(),
      updatedAt: now(),
    );
    _data.nutritionEntries.add(created);
    _isDirty = true;
    return created;
  }

  NutritionEntry updateNutritionEntry(String id, NutritionEntry updated) {
    final index = _data.nutritionEntries.indexWhere((e) => e.id == id);
    if (index < 0) throw Exception('Eintrag nicht gefunden');
    final entry = NutritionEntry(
      id: id,
      foodSource: updated.foodSource,
      foodId: updated.foodId,
      foodName: updated.foodName,
      profilePer100g: updated.profilePer100g,
      amountGrams: updated.amountGrams,
      amountMilliliters: updated.amountMilliliters,
      servingCount: updated.servingCount,
      occurredAt: updated.occurredAt,
      meal: updated.meal,
      createdAt: _data.nutritionEntries[index].createdAt,
      updatedAt: now(),
    );
    _data.nutritionEntries[index] = entry;
    _isDirty = true;
    return entry;
  }

  void deleteNutritionEntry(String id) {
    final found = _data.nutritionEntries.any((e) => e.id == id);
    _data.nutritionEntries.removeWhere((e) => e.id == id);
    if (!found) {
      throw Exception('Eintrag nicht gefunden');
    }
    _isDirty = true;
  }

  /// Tageszusammenfassung Ernährung für einen Tag.
  NutritionDaySummary nutritionDaySummary(DateTime day) {
    final entries = nutritionEntriesForDay(day);
    final total = entries.fold<NutrientProfile>(
      const NutrientProfile(),
      (sum, e) => sum.add(e.nutrients),
    );
    return NutritionDaySummary(
      date: day,
      entries: entries,
      total: total,
    );
  }

  /// Wasser- und Koffein-Einträge.
  List<WaterEntry> get waterEntries => List.unmodifiable(_data.waterEntries);
  List<CaffeineEntry> get caffeineEntries => List.unmodifiable(_data.caffeineEntries);

  List<WaterEntry> waterEntriesForDay(DateTime day) => _filterOnDay(
        _data.waterEntries,
        day,
        (e) => e.occurredAt,
      );
  List<CaffeineEntry> caffeineEntriesForDay(DateTime day) => _filterOnDay(
        _data.caffeineEntries,
        day,
        (e) => e.occurredAt,
      );

  WaterEntry addWaterEntry(WaterEntry entry) {
    final created = WaterEntry(
      id: entry.id.isEmpty ? uuid() : entry.id,
      amountMilliliters: entry.amountMilliliters,
      occurredAt: entry.occurredAt,
      createdAt: now(),
      updatedAt: now(),
    );
    _data.waterEntries.add(created);
    _isDirty = true;
    return created;
  }

  WaterEntry updateWaterEntry(String id, WaterEntry updated) {
    final index = _data.waterEntries.indexWhere((e) => e.id == id);
    if (index < 0) throw Exception('Eintrag nicht gefunden');
    final entry = WaterEntry(
      id: id,
      amountMilliliters: updated.amountMilliliters,
      occurredAt: updated.occurredAt,
      createdAt: _data.waterEntries[index].createdAt,
      updatedAt: now(),
    );
    _data.waterEntries[index] = entry;
    _isDirty = true;
    return entry;
  }

  void deleteWaterEntry(String id) {
    final found = _data.waterEntries.any((e) => e.id == id);
    _data.waterEntries.removeWhere((e) => e.id == id);
    if (!found) {
      throw Exception('Eintrag nicht gefunden');
    }
    _isDirty = true;
  }

  CaffeineEntry addCaffeineEntry(CaffeineEntry entry) {
    final created = CaffeineEntry(
      id: entry.id.isEmpty ? uuid() : entry.id,
      amountMg: entry.amountMg,
      occurredAt: entry.occurredAt,
      createdAt: now(),
      updatedAt: now(),
    );
    _data.caffeineEntries.add(created);
    _isDirty = true;
    return created;
  }

  CaffeineEntry updateCaffeineEntry(String id, CaffeineEntry updated) {
    final index = _data.caffeineEntries.indexWhere((e) => e.id == id);
    if (index < 0) throw Exception('Eintrag nicht gefunden');
    final entry = CaffeineEntry(
      id: id,
      amountMg: updated.amountMg,
      occurredAt: updated.occurredAt,
      createdAt: _data.caffeineEntries[index].createdAt,
      updatedAt: now(),
    );
    _data.caffeineEntries[index] = entry;
    _isDirty = true;
    return entry;
  }

  void deleteCaffeineEntry(String id) {
    final found = _data.caffeineEntries.any((e) => e.id == id);
    _data.caffeineEntries.removeWhere((e) => e.id == id);
    if (!found) {
      throw Exception('Eintrag nicht gefunden');
    }
    _isDirty = true;
  }

  /// Tageszusammenfassung Wasser/Koffein.
  WaterCaffeineSummary waterCaffeineDaySummary(DateTime day) {
    final water = waterEntriesForDay(day);
    final caffeine = caffeineEntriesForDay(day);
    return WaterCaffeineSummary(
      date: day,
      waterMilliliters: water.fold<double>(0, (s, e) => s + e.amountMilliliters),
      caffeineMg: caffeine.fold<double>(0, (s, e) => s + e.amountMg),
    );
  }

  /* ============================ Zyklus ============================ */

  List<CycleEntry> get cycleEntries => List.unmodifiable(_data.cycleEntries);

  List<CycleEntry> cycleEntriesForMonth(DateTime month) {
    final start = DateTime(month.year, month.month, 1);
    final end = DateTime(month.year, month.month + 1, 1);
    final result = _data.cycleEntries
        .where((e) => e.startDate.isAfter(start.subtract(const Duration(days: 1))) &&
            e.startDate.isBefore(end))
        .toList();
    result.sort((a, b) => a.startDate.compareTo(b.startDate));
    return result;
  }

  List<CycleEntry> cycleEntriesInRange(DateTime start, DateTime end) =>
      _data.cycleEntries
          .where((e) =>
              !e.startDate.isBefore(start) && e.startDate.isBefore(end))
          .toList();

  bool hasPeriodOnDate(DateTime day) {
    final start = DateTime(day.year, day.month, day.day);
    return _data.cycleEntries.any((e) {
      final entryEnd = e.endDate ?? e.startDate;
      return !start.isBefore(e.startDate) && !start.isAfter(entryEnd);
    });
  }

  CycleEntry addCycleEntry(CycleEntry entry) {
    final created = CycleEntry(
      id: entry.id.isEmpty ? uuid() : entry.id,
      startDate: entry.startDate,
      endDate: entry.endDate,
      intensity: entry.intensity,
      notes: entry.notes,
      createdAt: now(),
      updatedAt: now(),
    );
    _data.cycleEntries.add(created);
    _isDirty = true;
    return created;
  }

  CycleEntry updateCycleEntry(String id, CycleEntry updated) {
    final index = _data.cycleEntries.indexWhere((e) => e.id == id);
    if (index < 0) throw Exception('Eintrag nicht gefunden');
    final entry = CycleEntry(
      id: id,
      startDate: updated.startDate,
      endDate: updated.endDate,
      intensity: updated.intensity,
      notes: updated.notes,
      createdAt: _data.cycleEntries[index].createdAt,
      updatedAt: now(),
    );
    _data.cycleEntries[index] = entry;
    _isDirty = true;
    return entry;
  }

  void deleteCycleEntry(String id) {
    final found = _data.cycleEntries.any((e) => e.id == id);
    _data.cycleEntries.removeWhere((e) => e.id == id);
    if (!found) {
      throw Exception('Eintrag nicht gefunden');
    }
    _isDirty = true;
  }

  /// Persönliche Zykluseinschätzung für einen Betrachtungstag (P04).
  CycleForecast forecastFor(DateTime on, {String locale = 'de'}) {
    final entries = List<CycleEntry>.from(_data.cycleEntries)
      ..sort((a, b) => a.startDate.compareTo(b.startDate));
    final starts = entries.map((e) => e.startDate).toList();
    final periodsWithEnd = entries.where((e) => e.endDate != null).toList();

    List<int> cycleLengths = [];
    for (var i = 1; i < starts.length; i++) {
      cycleLengths.add(starts[i].difference(starts[i - 1]).inDays);
    }
    List<int> periodLengths = periodsWithEnd.map((e) => e.durationDays).toList();

    final avgCycle = cycleLengths.isEmpty ? null : cycleLengths.reduce((a, b) => a + b) / cycleLengths.length;
    final avgPeriod = periodLengths.isEmpty ? null : periodLengths.reduce((a, b) => a + b) / periodLengths.length;

    final lastStart = starts.isNotEmpty ? starts.last : null;
    DateTime? predictedStart;
    DateTime? predictedEnd;
    if (lastStart != null && avgCycle != null) {
      predictedStart = lastStart.add(Duration(days: avgCycle.round()));
      if (avgPeriod != null) {
        predictedEnd = predictedStart.add(Duration(days: avgPeriod.round() - 1));
      }
    }

    String explanation;
    if (cycleLengths.isEmpty) {
      explanation = _forecastExplanation(locale, 'none');
    } else {
      explanation = cycleLengths.length < 3
          ? _forecastExplanation(locale, 'few')
          : _forecastExplanation(locale, 'full');
    }

    return CycleForecast(
      referenceDay: on,
      lastPeriodStart: lastStart,
      averageCycleLengthDays: avgCycle,
      averagePeriodLengthDays: avgPeriod,
      cyclesRecorded: cycleLengths.length,
      predictedNextStart: predictedStart,
      predictedNextEnd: predictedEnd,
      explanation: explanation,
    );
  }

  /* ============================ Symptome ============================ */

  List<SymptomEntry> get symptomEntries => List.unmodifiable(_data.symptomEntries);

  List<SymptomEntry> symptomEntriesForDay(DateTime day) => _filterOnDay(
        _data.symptomEntries,
        day,
        (e) => e.occurredAt,
      );

  List<SymptomEntry> symptomEntriesForSymptom(String name) {
    final result = _data.symptomEntries.where((e) => e.name == name).toList();
    result.sort((a, b) => a.occurredAt.compareTo(b.occurredAt));
    return result;
  }

  List<String> get symptomNames {
    final result = _data.symptomEntries.map((e) => e.name).toSet().toList();
    result.sort();
    return result;
  }

  SymptomEntry addSymptomEntry(SymptomEntry entry) {
    final created = SymptomEntry(
      id: entry.id.isEmpty ? uuid() : entry.id,
      name: entry.name,
      intensity: entry.intensity.clamp(0, 10),
      occurredAt: entry.occurredAt,
      notes: entry.notes,
      createdAt: now(),
      updatedAt: now(),
    );
    _data.symptomEntries.add(created);
    _isDirty = true;
    return created;
  }

  SymptomEntry updateSymptomEntry(String id, SymptomEntry updated) {
    final index = _data.symptomEntries.indexWhere((e) => e.id == id);
    if (index < 0) throw Exception('Eintrag nicht gefunden');
    final entry = SymptomEntry(
      id: id,
      name: updated.name,
      intensity: updated.intensity.clamp(0, 10),
      occurredAt: updated.occurredAt,
      notes: updated.notes,
      createdAt: _data.symptomEntries[index].createdAt,
      updatedAt: now(),
    );
    _data.symptomEntries[index] = entry;
    _isDirty = true;
    return entry;
  }

  void deleteSymptomEntry(String id) {
    final found = _data.symptomEntries.any((e) => e.id == id);
    _data.symptomEntries.removeWhere((e) => e.id == id);
    if (!found) {
      throw Exception('Eintrag nicht gefunden');
    }
    _isDirty = true;
  }

  /* ============================ Gewicht ============================ */

  List<WeightEntry> get weightEntries => List.unmodifiable(_data.weightEntries);

  List<WeightEntry> weightEntriesForDay(DateTime day) => _filterOnDay(
        _data.weightEntries,
        day,
        (e) => e.date,
      );

  WeightEntry addWeightEntry(WeightEntry entry) {
    final created = WeightEntry(
      id: entry.id.isEmpty ? uuid() : entry.id,
      date: entry.date,
      value: entry.value,
      unit: entry.unit,
      createdAt: now(),
      updatedAt: now(),
    );
    _data.weightEntries.add(created);
    _isDirty = true;
    return created;
  }

  WeightEntry updateWeightEntry(String id, WeightEntry updated) {
    final index = _data.weightEntries.indexWhere((e) => e.id == id);
    if (index < 0) throw Exception('Eintrag nicht gefunden');
    final entry = WeightEntry(
      id: id,
      date: updated.date,
      value: updated.value,
      unit: updated.unit,
      createdAt: _data.weightEntries[index].createdAt,
      updatedAt: now(),
    );
    _data.weightEntries[index] = entry;
    _isDirty = true;
    return entry;
  }

  void deleteWeightEntry(String id) {
    final found = _data.weightEntries.any((e) => e.id == id);
    _data.weightEntries.removeWhere((e) => e.id == id);
    if (!found) {
      throw Exception('Eintrag nicht gefunden');
    }
    _isDirty = true;
  }

  /* ============================ Ziele & Einstellungen ============================ */

  UserGoals get goals => _data.goals;
  AppSettings get settings => _data.settings;

  void setGoals(UserGoals goals) {
    _data.goals = goals;
    _isDirty = true;
  }

  void setSettings(AppSettings settings) {
    _data.settings = settings;
    _isDirty = true;
  }

  /// Portables Dokument exportieren (gleicher Aufruf wie im mh-CLI).
  Future<Map<String, dynamic>> exportDocument() async {
    await save();
    final snapshot = HealthData(
      localFoods: _data.localFoods,
      cachedProducts: _data.cachedProducts,
      nutritionEntries: _data.nutritionEntries,
      waterEntries: _data.waterEntries,
      caffeineEntries: _data.caffeineEntries,
      cycleEntries: _data.cycleEntries,
      symptomEntries: _data.symptomEntries,
      weightEntries: _data.weightEntries,
      goals: _data.goals,
      settings: _data.settings,
      format: 'morphhealth.v1',
      createdAt: now(),
    );
    return <String, dynamic>{
      'format': 'morphhealth.v1',
      'createdAt': snapshot.createdAt?.toIso8601String(),
      'document': snapshot.toJson(),
    };
  }

  /// Portables Dokument importieren und als aktuellen Bestand ersetzen.
  Future<Map<String, dynamic>> importDocument(Map<String, dynamic> document) async {
    final dataMap = document['document'] != null
        ? Map<String, dynamic>.from(document['document'] as Map)
        : Map<String, dynamic>.from(document);
    final imported = HealthData.fromJson(dataMap);
    _data = imported;
    await save();
    return <String, dynamic>{
      'format': 'morphhealth.v1',
      'replaced': true,
      'counts': <String, int>{
        'localFoods': imported.localFoods.length,
        'nutritionEntries': imported.nutritionEntries.length,
        'waterEntries': imported.waterEntries.length,
        'caffeineEntries': imported.caffeineEntries.length,
        'cycleEntries': imported.cycleEntries.length,
        'symptomEntries': imported.symptomEntries.length,
        'weightEntries': imported.weightEntries.length,
      },
    };
  }

  /// Datenbestand zurücksetzen (leerer Bestand).
  Future<void> reset() async {
    _data = HealthData(createdAt: now());
    await save();
  }

  /// Bestehende verschlüsselte Datendatei ersetzen und neu laden (Wiederherstellung aus Sicherung).
  Future<void> replaceDataFile(String path) async {
    final file = File(path);
    if (!await file.exists()) throw const EncryptedStoreError('Datei nicht gefunden');
    await file.copy(_dataPath);
    await load();
  }

  /* ============================ Suche / Historie ============================ */

  /// Einträge aller Bereiche für die durchsuchbare Historie (P06).
  List<HistoryItem> history({
    DateTime? from,
    DateTime? to,
    String? area,
    String? query,
  }) {
    final items = <HistoryItem>[];
    final q = (query ?? '').toLowerCase();

    void consider(String areaName, String id, DateTime when, String title,
        String subtitle, dynamic entry) {
      if (from != null && when.isBefore(from)) return;
      if (to != null && !when.isBefore(to.add(const Duration(days: 1)))) return;
      if (area != null && area != areaName) return;
      if (q.isNotEmpty &&
          !title.toLowerCase().contains(q) &&
          !subtitle.toLowerCase().contains(q)) return;
      items.add(HistoryItem(area: areaName, id: id, when: when, title: title, subtitle: subtitle, entry: entry));
    }

    for (final e in _data.nutritionEntries) {
      consider('nutrition', e.id, e.occurredAt, e.foodName,
          '${e.meal.key} · ${e.energyKcal.toStringAsFixed(0)} kcal', e);
    }
    for (final e in _data.waterEntries) {
      consider('water', e.id, e.occurredAt, 'Wasser',
          '${e.amountMilliliters.toStringAsFixed(0)} ml', e);
    }
    for (final e in _data.caffeineEntries) {
      consider('caffeine', e.id, e.occurredAt, 'Koffein',
          '${e.amountMg.toStringAsFixed(0)} mg', e);
    }
    for (final e in _data.cycleEntries) {
      consider('cycle', e.id, e.startDate, 'Periode',
          '${e.intensity.key} (${e.durationDays} Tage)', e);
    }
    for (final e in _data.symptomEntries) {
      consider('symptom', e.id, e.occurredAt, e.name,
          'Intensität ${e.intensity}/10', e);
    }
    for (final e in _data.weightEntries) {
      consider('weight', e.id, e.date, 'Gewicht',
          '${e.value.toStringAsFixed(1)} ${e.unit.key.toUpperCase()}', e);
    }

    items.sort((a, b) => b.when.compareTo(a.when));
    return items;
  }

  AppSettings get currentSettings => _data.settings;

  /* ============================ Helfer ============================ */

  List<T> _filterOnDay<T>(List<T> list, DateTime day, DateTime Function(T) at) {
    final start = DateTime(day.year, day.month, day.day);
    final end = start.add(const Duration(days: 1));
    final result = list.where((e) => !at(e).isBefore(start) && at(e).isBefore(end)).toList();
    result.sort((a, b) => at(a).compareTo(at(b)));
    return result;
  }

  Exception get _notFound => const _EntryNotFound();

  void dispose() {}
}

Exception _entryNotFound() => const _EntryNotFound();

class _EntryNotFound implements Exception {
  const _EntryNotFound();
  @override
  String toString() => 'Eintrag nicht gefunden';
}

/// Tageszusammenfassung Ernährung.
class NutritionDaySummary {
  const NutritionDaySummary({
    required this.date,
    required this.entries,
    required this.total,
  });

  final DateTime date;
  final List<NutritionEntry> entries;
  final NutrientProfile total;

  double get energyKcal => total.energyKcal ?? 0;
  double get proteinG => total.proteinG ?? 0;
  double get carbsG => total.carbsG ?? 0;
  double get fatG => total.fatG ?? 0;

  Map<String, double> get byMeal {
    final result = <String, double>{};
    for (final meal in Meal.values) {
      final sum = entries
          .where((e) => e.meal == meal)
          .fold<NutrientProfile>(const NutrientProfile(), (s, e) => s.add(e.nutrients));
      result[meal.key] = sum.energyKcal ?? 0;
    }
    return result;
  }
}

/// Wasser/Koffein-Tageszusammenfassung.
class WaterCaffeineSummary {
  const WaterCaffeineSummary({
    required this.date,
    required this.waterMilliliters,
    required this.caffeineMg,
  });

  final DateTime date;
  final double waterMilliliters;
  final double caffeineMg;
}

/// Persönliche Zykluseinschätzung.
class CycleForecast {
  const CycleForecast({
    required this.referenceDay,
    this.lastPeriodStart,
    this.averageCycleLengthDays,
    this.averagePeriodLengthDays,
    required this.cyclesRecorded,
    this.predictedNextStart,
    this.predictedNextEnd,
    required this.explanation,
  });

  final DateTime referenceDay;
  final DateTime? lastPeriodStart;
  final double? averageCycleLengthDays;
  final double? averagePeriodLengthDays;
  final int cyclesRecorded;
  final DateTime? predictedNextStart;
  final DateTime? predictedNextEnd;
  final String explanation;

  bool get hasPrediction => predictedNextStart != null;
}

String _forecastExplanation(String locale, String kind) {
  if (locale == 'en') {
    switch (kind) {
      case 'none':
        return 'No periods recorded yet. Log your bleeding days so MorphHealth can '
            'estimate your personal cycle length and predict the next period. '
            'This is documentation only, not a medical diagnosis.';
      case 'few':
        return 'Only a few cycles are recorded. The estimate is based on the '
            'average of your recorded cycle lengths and becomes more reliable '
            'with more entries. This is documentation only, not a medical diagnosis.';
      case 'full':
        return 'The estimate is based on the average of your recorded cycle and '
            'bleeding lengths. The next period is expected to begin around the '
            'calculated start date. Individual cycles may vary. '
            'This is documentation only, not a medical diagnosis, not an ovulation '
            'or contraception prediction.';
    }
  }
  switch (kind) {
    case 'none':
      return 'Noch keine Perioden erfasst. Tragen Sie Ihre Blutungstage ein, damit MorphHealth '
          'Ihre persönliche Zykluslänge schätzen und die nächste Periode vorhersagen kann. '
          'Dies ist reine Dokumentation, keine medizinische Diagnose.';
    case 'few':
      return 'Nur wenige Zyklen sind aufgezeichnet. Die Einschätzung basiert auf dem '
          'Durchschnitt Ihrer erfassten Zykluslängen und wird mit mehr Einträgen zuverlässiger. '
          'Dies ist reine Dokumentation, keine medizinische Diagnose.';
    case 'full':
      return 'Die Einschätzung basiert auf dem Durchschnitt Ihrer aufgezeichneten Zyklus- und '
          'Blutungslängen. Die nächste Periode wird voraussichtlich um den berechneten '
          'Starttermin beginnen. Individuelle Zyklen können davon abweichen. '
          'Dies ist reine Dokumentation, keine medizinische Diagnose, keine Verhütungs- '
          'oder Eisprungvorhersage.';
  }
  return '';
}

/// Ein Historieneintrag über alle vier Bereiche hinweg.
class HistoryItem {
  const HistoryItem({
    required this.area,
    required this.id,
    required this.when,
    required this.title,
    required this.subtitle,
    required this.entry,
  });

  final String area; // nutrition | water | caffeine | cycle | symptom | weight
  final String id;
  final DateTime when;
  final String title;
  final String subtitle;
  final dynamic entry;
}

final _dateFormatter = DateFormat.yMMMd();

String formatDateShort(DateTime d, String locale) =>
    _dateFormatter.format(d);