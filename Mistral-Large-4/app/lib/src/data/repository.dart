// Repository: zentrale Datenhaltung und CRUD-Operationen.
//
// Reiner Dart (ohne Flutter), damit App und Wartungszugang (mh) exakt
// dieselben Funktionen verwenden. Die UI hängt über Listener an.
library;

import 'dart:async';

import '../core/clock.dart';
import '../core/ids.dart';
import '../model/cycle.dart';
import '../model/document.dart';
import '../model/entries.dart';
import '../model/food.dart';
import '../model/settings.dart';
import '../store/store.dart';

/// Persistenz-Schnittstelle (Datei-Store in App und CLI).
abstract class StoreBackend {
  Future<MorphDocument> load();
  Future<void> save(MorphDocument doc);
  Future<void> deleteAll();
}

/// Datei-basierter Backend über EncryptedStore.
class FileStoreBackend implements StoreBackend {
  final EncryptedStore store;
  final Clock clock;
  FileStoreBackend(this.store, {Clock? clock}) : clock = clock ?? SystemClock();

  @override
  Future<MorphDocument> load() => store.load(clock: clock);

  @override
  Future<void> save(MorphDocument doc) => store.save(doc, clock: clock);

  @override
  Future<void> deleteAll() => store.deleteAll();
}

class MorphRepository {
  final StoreBackend _backend;
  final Clock clock;
  final AppInfo appInfo;

  MorphDocument _doc = MorphDocument.empty();
  final List<void Function()> _listeners = <void Function()>[];
  Timer? _persistTimer;
  bool _disposed = false;
  bool _loaded = false;

  MorphRepository(this._backend, {this.clock = const SystemClock(), this.appInfo = const AppInfo()});

  // ---------------------------------------------------------------- Lifecycle

  Future<void> load() async {
    _doc = await _backend.load();
    _loaded = true;
  }

  bool get isLoaded => _loaded;

  MorphDocument get document => _doc;
  AppSettings get settings => _doc.settings;

  void addListener(void Function() listener) => _listeners.add(listener);
  void removeListener(void Function() listener) => _listeners.remove(listener);

  void _notify() {
    for (final void Function() l in List<void Function()>.of(_listeners)) {
      l();
    }
  }

  /// Persistiert sofort (asynchron, ohne Debounce).
  Future<void> persistNow() async {
    _persistTimer?.cancel();
    _persistTimer = null;
    if (_loaded && !_disposed) {
      await _backend.save(_doc);
    }
  }

  /// Persistiert verzögert (Debounce für schnelle Erfassungsfolgen).
  void schedulePersist() {
    if (_disposed) return;
    _persistTimer?.cancel();
    _persistTimer = Timer(const Duration(milliseconds: 400), () {
      _persistTimer = null;
      if (!_disposed) {
        unawaited(persistNow());
      }
    });
  }

  Future<void> dispose() async {
    // Erst persistieren (persistNow prüft _disposed), dann abschalten —
    // sonst gingen ausstehende Debounce-Änderungen verloren.
    _persistTimer?.cancel();
    await persistNow();
    _disposed = true;
  }

  /// Übernimmt ein Dokument als Ersatz des Arbeitsdatenbestands.
  Future<Map<String, int>> replaceDocument(MorphDocument doc) async {
    _doc = doc;
    final Map<String, int> report = doc.importReport();
    await persistNow();
    _notify();
    return report;
  }

  /// Löscht den gesamten lokalen Datenbestand.
  Future<void> deleteAllData() async {
    _doc = MorphDocument.empty();
    await _backend.deleteAll();
    await persistNow();
    _notify();
  }

  Map<String, dynamic> exportPortable({DateTime? exportedAt}) =>
      _doc.toPortableJson(appInfo, exportedAt: exportedAt ?? clock.now());

  // ---------------------------------------------------------------- Settings

  Future<void> updateSettings(AppSettings Function(AppSettings s) change) async {
    _doc.settings = change(_doc.settings);
    schedulePersist();
    _notify();
  }

  // ---------------------------------------------------------------- Foods

  List<FoodItem> get foods => _doc.foods;

  List<FoodItem> get favoriteFoods =>
      _doc.foods.where((FoodItem f) => f.isFavorite).toList();

  List<FoodItem> get customFoods =>
      _doc.foods.where((FoodItem f) => f.isCustom).toList();

  FoodItem? foodById(String id) {
    for (final FoodItem f in _doc.foods) {
      if (f.id == id) return f;
    }
    return null;
  }

  Future<FoodItem> addFood(FoodItem food) async {
    _doc.foods.add(food);
    schedulePersist();
    _notify();
    return food;
  }

  Future<void> updateFood(FoodItem food) async {
    final int i = _doc.foods.indexWhere((FoodItem f) => f.id == food.id);
    if (i >= 0) {
      food.updatedAt = clock.now().toUtc();
      _doc.foods[i] = food;
      schedulePersist();
      _notify();
    }
  }

  Future<void> deleteFood(String id) async {
    _doc.foods.removeWhere((FoodItem f) => f.id == id);
    schedulePersist();
    _notify();
  }

  Future<void> toggleFoodFavorite(String id, bool favorite) async {
    final FoodItem? f = foodById(id);
    if (f != null) {
      f.isFavorite = favorite;
      f.updatedAt = clock.now().toUtc();
      schedulePersist();
      _notify();
    }
  }

  /// Legt einen OFF-Schnappschuss als FoodItem an (oder aktualisiert ihn).
  Future<FoodItem> upsertOffSnapshot(FoodItem snapshot) async {
    final int i = _doc.foods.indexWhere((FoodItem f) =>
        f.source == FoodSource.off && f.barcode != null && f.barcode == snapshot.barcode);
    if (i >= 0) {
      final FoodItem old = _doc.foods[i];
      snapshot.id = old.id;
      snapshot.isFavorite = old.isFavorite;
      snapshot.createdAt = old.createdAt;
      snapshot.updatedAt = clock.now().toUtc();
      _doc.foods[i] = snapshot;
    } else {
      snapshot.id = newId();
      snapshot.createdAt = clock.now().toUtc();
      snapshot.updatedAt = snapshot.createdAt;
      _doc.foods.add(snapshot);
    }
    schedulePersist();
    _notify();
    return snapshot;
  }

  // ---------------------------------------------------------------- Nutrition

  List<NutritionEntry> get nutritionEntries => _doc.nutritionEntries;
  List<WaterEntry> get waterEntries => _doc.waterEntries;
  List<CaffeineEntry> get caffeineEntries => _doc.caffeineEntries;

  List<NutritionEntry> nutritionEntriesForDate(String date) =>
      _doc.nutritionEntries.where((NutritionEntry e) => e.date == date).toList()
        ..sort(_compareEntryTime);

  List<WaterEntry> waterEntriesForDate(String date) =>
      _doc.waterEntries.where((WaterEntry e) => e.date == date).toList()
        ..sort(_compareEntryTime);

  List<CaffeineEntry> caffeineEntriesForDate(String date) =>
      _doc.caffeineEntries.where((CaffeineEntry e) => e.date == date).toList()
        ..sort(_compareEntryTime);

  NutritionEntry? nutritionEntryById(String id) =>
      _whereById(_doc.nutritionEntries, id);

  Future<NutritionEntry> addNutritionEntry(NutritionEntry entry) async {
    entry.id = newId();
    entry.createdAt = clock.now().toUtc();
    _doc.nutritionEntries.add(entry);
    schedulePersist();
    _notify();
    return entry;
  }

  Future<void> updateNutritionEntry(NutritionEntry entry) async {
    final int i = _doc.nutritionEntries.indexWhere((NutritionEntry e) => e.id == entry.id);
    if (i >= 0) {
      _doc.nutritionEntries[i] = entry;
      schedulePersist();
      _notify();
    }
  }

  Future<void> deleteNutritionEntry(String id) async {
    _doc.nutritionEntries.removeWhere((NutritionEntry e) => e.id == id);
    schedulePersist();
    _notify();
  }

  Future<WaterEntry> addWaterEntry(WaterEntry entry) async {
    entry.id = newId();
    _doc.waterEntries.add(entry);
    schedulePersist();
    _notify();
    return entry;
  }

  Future<void> updateWaterEntry(WaterEntry entry) async {
    final int i = _doc.waterEntries.indexWhere((WaterEntry e) => e.id == entry.id);
    if (i >= 0) {
      _doc.waterEntries[i] = entry;
      schedulePersist();
      _notify();
    }
  }

  Future<void> deleteWaterEntry(String id) async {
    _doc.waterEntries.removeWhere((WaterEntry e) => e.id == id);
    schedulePersist();
    _notify();
  }

  Future<CaffeineEntry> addCaffeineEntry(CaffeineEntry entry) async {
    entry.id = newId();
    _doc.caffeineEntries.add(entry);
    schedulePersist();
    _notify();
    return entry;
  }

  Future<void> updateCaffeineEntry(CaffeineEntry entry) async {
    final int i = _doc.caffeineEntries.indexWhere((CaffeineEntry e) => e.id == entry.id);
    if (i >= 0) {
      _doc.caffeineEntries[i] = entry;
      schedulePersist();
      _notify();
    }
  }

  Future<void> deleteCaffeineEntry(String id) async {
    _doc.caffeineEntries.removeWhere((CaffeineEntry e) => e.id == id);
    schedulePersist();
    _notify();
  }

  /// Neuester bekannter Name eines Lebensmittels (Vorschlagsliste).
  List<String> knownFoodNames() {
    final Set<String> names = <String>{};
    for (final NutritionEntry e in _doc.nutritionEntries) {
      if (e.foodName.trim().isNotEmpty) names.add(e.foodName.trim());
    }
    for (final FoodItem f in _doc.foods) {
      if (f.name.trim().isNotEmpty) names.add(f.name.trim());
    }
    final List<String> sorted = names.toList()..sort((String a, String b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return sorted;
  }

  // ---------------------------------------------------------------- Cycle

  List<PeriodRecord> get periods => _doc.periods;

  List<PeriodRecord> get sortedPeriods {
    final List<PeriodRecord> list = List<PeriodRecord>.of(_doc.periods);
    list.sort((PeriodRecord a, PeriodRecord b) => a.start.compareTo(b.start));
    return list;
  }

  PeriodRecord? periodById(String id) => _whereById(_doc.periods, id);

  /// Liefert die Periode, die an `date` läuft (inkl. laufender Periode).
  PeriodRecord? periodOn(String date, {String? today}) {
    for (final PeriodRecord p in sortedPeriods) {
      if (p.covers(date, today: today)) return p;
    }
    return null;
  }

  Future<PeriodRecord> addPeriod(PeriodRecord period) async {
    period.id = newId();
    _doc.periods.add(period);
    schedulePersist();
    _notify();
    return period;
  }

  Future<void> updatePeriod(PeriodRecord period) async {
    final int i = _doc.periods.indexWhere((PeriodRecord p) => p.id == period.id);
    if (i >= 0) {
      _doc.periods[i] = period;
      schedulePersist();
      _notify();
    }
  }

  Future<void> deletePeriod(String id) async {
    _doc.periods.removeWhere((PeriodRecord p) => p.id == id);
    schedulePersist();
    _notify();
  }

  // ---------------------------------------------------------------- Weight

  List<WeightEntry> get weightEntries => _doc.weightEntries;

  List<WeightEntry> get sortedWeightEntries {
    final List<WeightEntry> list = List<WeightEntry>.of(_doc.weightEntries);
    list.sort((WeightEntry a, WeightEntry b) => a.date.compareTo(b.date));
    return list;
  }

  WeightEntry? weightEntryById(String id) => _whereById(_doc.weightEntries, id);

  WeightEntry? weightEntryOn(String date) {
    for (final WeightEntry e in sortedWeightEntries) {
      if (e.date == date) return e;
    }
    return null;
  }

  WeightEntry? latestWeightEntry({String? before}) {
    final List<WeightEntry> list = sortedWeightEntries;
    if (before != null) {
      for (int i = list.length - 1; i >= 0; i--) {
        if (list[i].date.compareTo(before) <= 0) return list[i];
      }
      return null;
    }
    return list.isEmpty ? null : list.last;
  }

  Future<WeightEntry> addWeightEntry(WeightEntry entry) async {
    entry.id = newId();
    _doc.weightEntries.add(entry);
    schedulePersist();
    _notify();
    return entry;
  }

  Future<void> updateWeightEntry(WeightEntry entry) async {
    final int i = _doc.weightEntries.indexWhere((WeightEntry e) => e.id == entry.id);
    if (i >= 0) {
      _doc.weightEntries[i] = entry;
      schedulePersist();
      _notify();
    }
  }

  Future<void> deleteWeightEntry(String id) async {
    _doc.weightEntries.removeWhere((WeightEntry e) => e.id == id);
    schedulePersist();
    _notify();
  }

  // ---------------------------------------------------------------- Symptoms

  List<SymptomEntry> get symptomEntries => _doc.symptomEntries;

  List<SymptomEntry> get sortedSymptomEntries {
    final List<SymptomEntry> list = List<SymptomEntry>.of(_doc.symptomEntries);
    list.sort((SymptomEntry a, SymptomEntry b) {
      final int c = b.date.compareTo(a.date);
      if (c != 0) return c;
      return (b.time ?? '').compareTo(a.time ?? '');
    });
    return list;
  }

  SymptomEntry? symptomEntryById(String id) => _whereById(_doc.symptomEntries, id);

  List<SymptomEntry> symptomEntriesForDate(String date) =>
      _doc.symptomEntries.where((SymptomEntry e) => e.date == date).toList()
        ..sort(_compareEntryTime);

  List<SymptomEntry> symptomEntriesForName(String name) {
    final String n = name.trim().toLowerCase();
    return sortedSymptomEntries
        .where((SymptomEntry e) => e.name.trim().toLowerCase() == n)
        .toList();
  }

  List<String> knownSymptomNames() {
    final Set<String> names = <String>{};
    for (final SymptomEntry e in _doc.symptomEntries) {
      if (e.name.trim().isNotEmpty) names.add(e.name.trim());
    }
    final List<String> sorted = names.toList()..sort((String a, String b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return sorted;
  }

  Future<SymptomEntry> addSymptomEntry(SymptomEntry entry) async {
    entry.id = newId();
    _doc.symptomEntries.add(entry);
    schedulePersist();
    _notify();
    return entry;
  }

  Future<void> updateSymptomEntry(SymptomEntry entry) async {
    final int i = _doc.symptomEntries.indexWhere((SymptomEntry e) => e.id == entry.id);
    if (i >= 0) {
      _doc.symptomEntries[i] = entry;
      schedulePersist();
      _notify();
    }
  }

  Future<void> deleteSymptomEntry(String id) async {
    _doc.symptomEntries.removeWhere((SymptomEntry e) => e.id == id);
    schedulePersist();
    _notify();
  }

  // ---------------------------------------------------------------- History

  /// Durchsuchbare Historie über alle vier Bereiche.
  ///
  /// Filter: Datumsbereich (from/to, inkl.), Bereich, Freitext.
  List<HistoryHit> searchHistory({
    String? from,
    String? to,
    String? area,
    String? query,
  }) {
    final String q = (query ?? '').trim().toLowerCase();
    final List<HistoryHit> hits = <HistoryHit>[];

    bool inRange(String date) {
      if (from != null && date.compareTo(from) < 0) return false;
      if (to != null && date.compareTo(to) > 0) return false;
      return true;
    }

    bool matches(String text) => q.isEmpty || text.toLowerCase().contains(q);

    if (area == null || area == 'nutrition') {
      for (final NutritionEntry e in _doc.nutritionEntries) {
        if (!inRange(e.date)) continue;
        if (!matches(e.foodName) && !matches(e.note ?? '')) continue;
        hits.add(HistoryHit(
          area: 'nutrition',
          kind: 'nutrition_entry',
          id: e.id,
          date: e.date,
          time: e.time,
          title: e.foodName,
          subtitle: _mealName(e.meal),
        ));
      }
      for (final WaterEntry e in _doc.waterEntries) {
        if (!inRange(e.date)) continue;
        if (!matches('Wasser') && !matches(e.note ?? '')) continue;
        hits.add(HistoryHit(
          area: 'nutrition',
          kind: 'water_entry',
          id: e.id,
          date: e.date,
          time: e.time,
          title: 'Wasser',
          subtitle: '${e.amountMl.toStringAsFixed(0)} ml',
        ));
      }
      for (final CaffeineEntry e in _doc.caffeineEntries) {
        if (!inRange(e.date)) continue;
        if (!matches('Koffein') && !matches(e.note ?? '')) continue;
        hits.add(HistoryHit(
          area: 'nutrition',
          kind: 'caffeine_entry',
          id: e.id,
          date: e.date,
          time: e.time,
          title: 'Koffein',
          subtitle: '${e.amountMg.toStringAsFixed(0)} mg',
        ));
      }
    }
    if (area == null || area == 'cycle') {
      for (final PeriodRecord p in _doc.periods) {
        if (!inRange(p.start)) continue;
        final String text = 'Periode ${p.note ?? ''}';
        if (!matches(text)) continue;
        hits.add(HistoryHit(
          area: 'cycle',
          kind: 'period',
          id: p.id,
          date: p.start,
          time: null,
          title: 'Periode',
          subtitle: p.end == null ? 'Beginn ${p.start} (läuft)' : '${p.start} – ${p.end}',
        ));
      }
    }
    if (area == null || area == 'weight') {
      for (final WeightEntry e in _doc.weightEntries) {
        if (!inRange(e.date)) continue;
        if (!matches(e.note ?? '')) continue;
        hits.add(HistoryHit(
          area: 'weight',
          kind: 'weight_entry',
          id: e.id,
          date: e.date,
          time: e.time,
          title: 'Gewicht',
          subtitle: '${e.weightKg.toStringAsFixed(1)} kg',
        ));
      }
    }
    if (area == null || area == 'symptoms') {
      for (final SymptomEntry e in _doc.symptomEntries) {
        if (!inRange(e.date)) continue;
        if (!matches(e.name) && !matches(e.note ?? '')) continue;
        hits.add(HistoryHit(
          area: 'symptoms',
          kind: 'symptom_entry',
          id: e.id,
          date: e.date,
          time: e.time,
          title: e.name,
          subtitle: 'Intensität ${e.intensity}/10',
        ));
      }
    }
    hits.sort((HistoryHit a, HistoryHit b) {
      final int c = b.date.compareTo(a.date);
      if (c != 0) return c;
      return (b.time ?? '').compareTo(a.time ?? '');
    });
    return hits;
  }

  String _mealName(Meal meal) {
    switch (meal) {
      case Meal.breakfast:
        return 'Frühstück';
      case Meal.lunch:
        return 'Mittagessen';
      case Meal.dinner:
        return 'Abendessen';
      case Meal.snack:
        return 'Snack';
    }
  }

  static int _compareEntryTime(dynamic a, dynamic b) {
    final String ta = (a.time ?? '').toString();
    final String tb = (b.time ?? '').toString();
    return ta.compareTo(tb);
  }

  static T? _whereById<T>(List<T> list, String id) {
    for (final T item in list) {
      final dynamic d = item;
      if (d.id == id) return item;
    }
    return null;
  }
}

/// Ein Treffer der globalen Historie-Suche.
class HistoryHit {
  final String area; // nutrition | cycle | weight | symptoms
  final String kind; // nutrition_entry | water_entry | caffeine_entry | period | weight_entry | symptom_entry
  final String id;
  final String date;
  final String? time;
  final String title;
  final String subtitle;

  const HistoryHit({
    required this.area,
    required this.kind,
    required this.id,
    required this.date,
    this.time,
    required this.title,
    required this.subtitle,
  });
}
