/// Encrypted local store and indexed query engine shared by Android UI and `./mh`.
///
/// Designed to sustain 10,000+ multi-year diary entries with sub-millisecond
/// day lookups, 7d/28d trend generation, and fast multi-domain history filtering.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:path/path.dart' as p;

import 'clock.dart';
import 'crypto_vault.dart';
import 'cycle_engine.dart';
import 'models.dart';
import 'nutrients.dart';
import 'nutrition_service.dart';
import 'portable_codec.dart';

enum HistoryRecordKind {
  meal,
  water,
  caffeine,
  period,
  weight,
  symptom,
}

class UnifiedHistoryItem {
  final String id;
  final AppModule module;
  final HistoryRecordKind kind;
  final String date; // YYYY-MM-DD
  final String sortTimestamp;
  final String title;
  final String subtitle;
  final String searchBlobLower;
  final Object record;

  const UnifiedHistoryItem({
    required this.id,
    required this.module,
    required this.kind,
    required this.date,
    required this.sortTimestamp,
    required this.title,
    required this.subtitle,
    required this.searchBlobLower,
    required this.record,
  });
}

class TrendPoint {
  final String date; // YYYY-MM-DD
  final double? value;
  final bool hasEntry;

  const TrendPoint({
    required this.date,
    required this.value,
    required this.hasEntry,
  });
}

class DayOverviewBundle {
  final String date;
  final NutritionDaySummary nutrition;
  final CycleForecastResult cycleForecast;
  final List<PeriodEntry> periodsCoveringDay;
  final List<WeightEntry> weightEntries;
  final List<SymptomEntry> symptomEntries;

  const DayOverviewBundle({
    required this.date,
    required this.nutrition,
    required this.cycleForecast,
    required this.periodsCoveringDay,
    required this.weightEntries,
    required this.symptomEntries,
  });
}

class MorphHealthStore {
  static const String snapshotFileName = 'vault.mhv1';
  static const String walFileName = 'vault.wal.mhv1';
  static const int walCompactThreshold = 150;

  final String dataDir;
  Uint8List _masterKey;
  final AppClock clock;

  late Uint8List _epochId;
  late Uint8List _salt;
  late SecretKey _walSecretKey;
  int _walSequence = 0;

  UserPreferences _preferences = const UserPreferences();
  NutritionGoals _goals = const NutritionGoals();

  final Map<String, FoodItem> _foods = {};
  final Map<String, FoodDiaryEntry> _mealEntries = {};
  final Map<String, List<FoodDiaryEntry>> _mealsByDate = {};

  final Map<String, WaterEntry> _waterEntries = {};
  final Map<String, List<WaterEntry>> _waterByDate = {};

  final Map<String, CaffeineEntry> _caffeineEntries = {};
  final Map<String, List<CaffeineEntry>> _caffeineByDate = {};

  final Map<String, PeriodEntry> _periods = {};

  final Map<String, WeightEntry> _weightEntries = {};
  final Map<String, List<WeightEntry>> _weightsByDate = {};

  final Map<String, SymptomEntry> _symptomEntries = {};
  final Map<String, List<SymptomEntry>> _symptomsByDate = {};

  MorphHealthStore._({
    required this.dataDir,
    required Uint8List masterKey,
    required this.clock,
  }) : _masterKey = Uint8List.fromList(masterKey);

  static Future<MorphHealthStore> open({
    required String dataDir,
    required Uint8List masterKey,
    AppClock clock = const SystemClock(),
  }) async {
    VaultCrypto.validateMasterKey(masterKey);
    final dir = Directory(dataDir);
    if (!dir.existsSync()) {
      await dir.create(recursive: true);
    }

    final store = MorphHealthStore._(
      dataDir: dir.absolute.path,
      masterKey: masterKey,
      clock: clock,
    );
    await store._loadFromDisk();
    return store;
  }

  File get _snapshotFile => File(p.join(dataDir, snapshotFileName));
  File get _walFile => File(p.join(dataDir, walFileName));

  UserPreferences get preferences => _preferences;
  NutritionGoals get goals => _goals;
  Map<String, FoodItem> get foodsById => Map.unmodifiable(_foods);

  List<FoodItem> get allFoods {
    final list = _foods.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  List<FoodItem> get customFoods =>
      allFoods.where((f) => f.isCustom).toList(growable: false);

  List<FoodItem> get favoriteFoods =>
      allFoods.where((f) => f.isFavorite).toList(growable: false);

  List<PeriodEntry> get allPeriods {
    final list = _periods.values.toList()
      ..sort((a, b) => b.startDate.compareTo(a.startDate));
    return list;
  }

  List<WeightEntry> get allWeights {
    final list = _weightEntries.values.toList()
      ..sort((a, b) {
        final c = b.date.compareTo(a.date);
        return c != 0 ? c : b.recordedAt.compareTo(a.recordedAt);
      });
    return list;
  }

  List<SymptomEntry> get allSymptoms {
    final list = _symptomEntries.values.toList()
      ..sort((a, b) {
        final c = b.date.compareTo(a.date);
        return c != 0 ? c : b.recordedAt.compareTo(a.recordedAt);
      });
    return list;
  }

  int get totalDiaryEntriesCount =>
      _mealEntries.length +
      _waterEntries.length +
      _caffeineEntries.length +
      _periods.length +
      _weightEntries.length +
      _symptomEntries.length;

  List<String> get distinctSymptomNames {
    final counts = <String, int>{};
    for (final s in _symptomEntries.values) {
      counts[s.name] = (counts[s.name] ?? 0) + 1;
    }
    final names = counts.keys.toList()
      ..sort((a, b) {
        final diff = counts[b]!.compareTo(counts[a]!);
        return diff != 0 ? diff : a.toLowerCase().compareTo(b.toLowerCase());
      });
    return names;
  }

  /// Recent distinct food diary entries for fast 1-tap re-logging ("Erneut erfassen").
  List<FoodDiaryEntry> recentLoggedMealTemplates({int limit = 25}) {
    final sorted = _mealEntries.values.toList()
      ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    final seenKey = <String>{};
    final out = <FoodDiaryEntry>[];
    for (final e in sorted) {
      final sig = '${e.foodId}|${e.amount}|${e.unit.jsonKey}';
      if (seenKey.add(sig)) {
        out.add(e);
        if (out.length >= limit) break;
      }
    }
    return out;
  }

  Future<void> _loadFromDisk() async {
    final snapFile = _snapshotFile;
    if (!snapFile.existsSync()) {
      _epochId = VaultCrypto.randomBytes(16);
      _salt = VaultCrypto.randomBytes(16);
      _walSecretKey = await VaultCrypto.deriveWalKey(_masterKey, _salt);
      _walSequence = 0;
      await _writeFullSnapshot();
      return;
    }

    final snapBytes = await snapFile.readAsBytes();
    final decrypted = await VaultCrypto.decryptSnapshot(
      masterKey: _masterKey,
      fileBytes: snapBytes,
    );
    _epochId = decrypted.epochId;
    _salt = decrypted.salt;
    _walSecretKey = await VaultCrypto.deriveWalKey(_masterKey, _salt);

    final bundle = PortableCodec.decodeAndValidate(decrypted.payload);
    _populateInMemoryFromBundle(bundle);

    final walFile = _walFile;
    if (walFile.existsSync()) {
      final walBytes = await walFile.readAsBytes();
      final ops = await VaultCrypto.decryptWalFile(
        walKey: _walSecretKey,
        expectedEpochId: _epochId,
        fileBytes: walBytes,
      );
      for (final op in ops) {
        _applyWalOpInMemory(op);
      }
      _walSequence = ops.length;
      if (_walSequence >= walCompactThreshold) {
        await _writeFullSnapshot();
      }
    } else {
      _walSequence = 0;
    }
  }

  void _clearInMemory() {
    _preferences = const UserPreferences();
    _goals = const NutritionGoals();
    _foods.clear();
    _mealEntries.clear();
    _mealsByDate.clear();
    _waterEntries.clear();
    _waterByDate.clear();
    _caffeineEntries.clear();
    _caffeineByDate.clear();
    _periods.clear();
    _weightEntries.clear();
    _weightsByDate.clear();
    _symptomEntries.clear();
    _symptomsByDate.clear();
  }

  void _populateInMemoryFromBundle(PortableBundle bundle) {
    _clearInMemory();
    _preferences = bundle.preferences;
    _goals = bundle.goals;
    for (final f in bundle.foods) {
      _foods[f.id] = f;
    }
    for (final e in bundle.mealEntries) {
      _indexMealEntry(e);
    }
    for (final e in bundle.waterEntries) {
      _indexWaterEntry(e);
    }
    for (final e in bundle.caffeineEntries) {
      _indexCaffeineEntry(e);
    }
    for (final pEntry in bundle.periods) {
      _periods[pEntry.id] = pEntry;
    }
    for (final w in bundle.weightEntries) {
      _indexWeightEntry(w);
    }
    for (final s in bundle.symptomEntries) {
      _indexSymptomEntry(s);
    }
  }

  void _indexMealEntry(FoodDiaryEntry e) {
    final prev = _mealEntries[e.id];
    if (prev != null) {
      _mealsByDate[prev.date]?.removeWhere((x) => x.id == e.id);
    }
    _mealEntries[e.id] = e;
    (_mealsByDate[e.date] ??= <FoodDiaryEntry>[]).add(e);
  }

  void _removeMealEntry(String id) {
    final prev = _mealEntries.remove(id);
    if (prev != null) {
      final list = _mealsByDate[prev.date];
      list?.removeWhere((x) => x.id == id);
      if (list != null && list.isEmpty) _mealsByDate.remove(prev.date);
    }
  }

  void _indexWaterEntry(WaterEntry e) {
    final prev = _waterEntries[e.id];
    if (prev != null) {
      _waterByDate[prev.date]?.removeWhere((x) => x.id == e.id);
    }
    _waterEntries[e.id] = e;
    (_waterByDate[e.date] ??= <WaterEntry>[]).add(e);
  }

  void _removeWaterEntry(String id) {
    final prev = _waterEntries.remove(id);
    if (prev != null) {
      final list = _waterByDate[prev.date];
      list?.removeWhere((x) => x.id == id);
      if (list != null && list.isEmpty) _waterByDate.remove(prev.date);
    }
  }

  void _indexCaffeineEntry(CaffeineEntry e) {
    final prev = _caffeineEntries[e.id];
    if (prev != null) {
      _caffeineByDate[prev.date]?.removeWhere((x) => x.id == e.id);
    }
    _caffeineEntries[e.id] = e;
    (_caffeineByDate[e.date] ??= <CaffeineEntry>[]).add(e);
  }

  void _removeCaffeineEntry(String id) {
    final prev = _caffeineEntries.remove(id);
    if (prev != null) {
      final list = _caffeineByDate[prev.date];
      list?.removeWhere((x) => x.id == id);
      if (list != null && list.isEmpty) _caffeineByDate.remove(prev.date);
    }
  }

  void _indexWeightEntry(WeightEntry e) {
    final prev = _weightEntries[e.id];
    if (prev != null) {
      _weightsByDate[prev.date]?.removeWhere((x) => x.id == e.id);
    }
    _weightEntries[e.id] = e;
    (_weightsByDate[e.date] ??= <WeightEntry>[]).add(e);
  }

  void _removeWeightEntry(String id) {
    final prev = _weightEntries.remove(id);
    if (prev != null) {
      final list = _weightsByDate[prev.date];
      list?.removeWhere((x) => x.id == id);
      if (list != null && list.isEmpty) _weightsByDate.remove(prev.date);
    }
  }

  void _indexSymptomEntry(SymptomEntry e) {
    final prev = _symptomEntries[e.id];
    if (prev != null) {
      _symptomsByDate[prev.date]?.removeWhere((x) => x.id == e.id);
    }
    _symptomEntries[e.id] = e;
    (_symptomsByDate[e.date] ??= <SymptomEntry>[]).add(e);
  }

  void _removeSymptomEntry(String id) {
    final prev = _symptomEntries.remove(id);
    if (prev != null) {
      final list = _symptomsByDate[prev.date];
      list?.removeWhere((x) => x.id == id);
      if (list != null && list.isEmpty) _symptomsByDate.remove(prev.date);
    }
  }

  void _applyWalOpInMemory(Map<String, dynamic> op) {
    final kind = op['t'] as String?;
    final data = op['d'];
    switch (kind) {
      case 'prefs':
        _preferences = UserPreferences.fromJson(data as Map<String, dynamic>);
      case 'goals':
        _goals = NutritionGoals.fromJson(data as Map<String, dynamic>);
      case 'put_food':
        final f = FoodItem.fromJson(data as Map<String, dynamic>);
        _foods[f.id] = f;
      case 'del_food':
        _foods.remove(data as String);
      case 'put_meal':
        _indexMealEntry(FoodDiaryEntry.fromJson(data as Map<String, dynamic>));
      case 'del_meal':
        _removeMealEntry(data as String);
      case 'put_water':
        _indexWaterEntry(WaterEntry.fromJson(data as Map<String, dynamic>));
      case 'del_water':
        _removeWaterEntry(data as String);
      case 'put_caff':
        _indexCaffeineEntry(
          CaffeineEntry.fromJson(data as Map<String, dynamic>),
        );
      case 'del_caff':
        _removeCaffeineEntry(data as String);
      case 'put_period':
        final pe = PeriodEntry.fromJson(data as Map<String, dynamic>);
        _periods[pe.id] = pe;
      case 'del_period':
        _periods.remove(data as String);
      case 'put_weight':
        _indexWeightEntry(WeightEntry.fromJson(data as Map<String, dynamic>));
      case 'del_weight':
        _removeWeightEntry(data as String);
      case 'put_symptom':
        _indexSymptomEntry(SymptomEntry.fromJson(data as Map<String, dynamic>));
      case 'del_symptom':
        _removeSymptomEntry(data as String);
    }
  }

  Future<void> _appendWalOrCompact(Map<String, dynamic> deltaOp) async {
    if (_walSequence >= walCompactThreshold) {
      await _writeFullSnapshot();
      return;
    }
    final nextSeq = _walSequence + 1;
    final frameBytes = await VaultCrypto.encryptWalFrame(
      walKey: _walSecretKey,
      epochId: _epochId,
      sequence: nextSeq,
      deltaOp: deltaOp,
    );
    final wal = _walFile;
    final raf = await wal.open(mode: FileMode.append);
    try {
      if (nextSeq == 1 && await raf.length() == 0) {
        await raf.writeFrom(VaultCrypto.buildWalHeader(_epochId));
      }
      await raf.writeFrom(frameBytes);
      await raf.flush();
    } finally {
      await raf.close();
    }
    _walSequence = nextSeq;
  }

  PortableBundle buildPortableBundle() {
    return PortableBundle(
      exportedAt: clock.nowRfc3339(),
      preferences: _preferences,
      goals: _goals,
      foods: allFoods,
      mealEntries: _mealEntries.values.toList()
        ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt)),
      waterEntries: _waterEntries.values.toList()
        ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt)),
      caffeineEntries: _caffeineEntries.values.toList()
        ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt)),
      periods: _periods.values.toList()
        ..sort((a, b) => a.startDate.compareTo(b.startDate)),
      weightEntries: _weightEntries.values.toList()
        ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt)),
      symptomEntries: _symptomEntries.values.toList()
        ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt)),
    );
  }

  Map<String, dynamic> exportPortableDocument() =>
      PortableCodec.encode(buildPortableBundle());

  Future<void> _writeFullSnapshot() async {
    _epochId = VaultCrypto.randomBytes(16);
    _salt = VaultCrypto.randomBytes(16);
    _walSecretKey = await VaultCrypto.deriveWalKey(_masterKey, _salt);

    final doc = exportPortableDocument();
    final encrypted = await VaultCrypto.encryptSnapshot(
      masterKey: _masterKey,
      epochId: _epochId,
      salt: _salt,
      payload: doc,
    );

    final tmpFile = File(p.join(dataDir, '$snapshotFileName.tmp'));
    final raf = await tmpFile.open(mode: FileMode.writeOnly);
    try {
      await raf.writeFrom(encrypted);
      await raf.flush();
    } finally {
      await raf.close();
    }
    await tmpFile.rename(_snapshotFile.path);

    if (_walFile.existsSync()) {
      await _walFile.delete();
    }
    _walSequence = 0;
  }

  // --- Mutations ---

  Future<Map<String, dynamic>> importPortableDocument(
    Map<String, dynamic> document,
  ) async {
    final bundle = PortableCodec.decodeAndValidate(document);
    _populateInMemoryFromBundle(bundle);
    await _writeFullSnapshot();
    return {
      'replaced': true,
      'imported_at': clock.nowRfc3339(),
      'counts': bundle.countsSummary,
    };
  }

  Future<void> wipeAllData({Uint8List? newMasterKey}) async {
    if (newMasterKey != null) {
      VaultCrypto.validateMasterKey(newMasterKey);
      _masterKey = Uint8List.fromList(newMasterKey);
    }
    _clearInMemory();
    await _writeFullSnapshot();
  }

  Future<void> updatePreferences(UserPreferences next) async {
    _preferences = next;
    await _appendWalOrCompact({'t': 'prefs', 'd': next.toJson()});
  }

  Future<void> updateGoals(NutritionGoals next) async {
    _goals = next;
    await _appendWalOrCompact({'t': 'goals', 'd': next.toJson()});
  }

  Future<FoodItem> upsertFood(FoodItem item) async {
    final existing = _foods[item.id];
    final merged = existing != null
        ? item.copyWith(
            isFavorite: item.isFavorite || existing.isFavorite,
            createdAt: existing.createdAt,
            updatedAt: clock.nowRfc3339(),
          )
        : item;
    _foods[merged.id] = merged;
    await _appendWalOrCompact({'t': 'put_food', 'd': merged.toJson()});
    return merged;
  }

  Future<FoodItem> saveFoodExact(FoodItem item) async {
    final updated = item.copyWith(updatedAt: clock.nowRfc3339());
    _foods[updated.id] = updated;
    await _appendWalOrCompact({'t': 'put_food', 'd': updated.toJson()});
    return updated;
  }

  Future<FoodItem> toggleFavoriteFood(FoodItem item) async {
    final current = _foods[item.id] ?? item;
    final toggled = current.copyWith(
      isFavorite: !current.isFavorite,
      updatedAt: clock.nowRfc3339(),
    );
    _foods[toggled.id] = toggled;
    await _appendWalOrCompact({'t': 'put_food', 'd': toggled.toJson()});
    return toggled;
  }

  Future<void> deleteCustomFood(String foodId) async {
    final f = _foods[foodId];
    if (f == null || !f.isCustom) return;
    _foods.remove(foodId);
    await _appendWalOrCompact({'t': 'del_food', 'd': foodId});
  }

  Future<FoodDiaryEntry> upsertMealEntry(
    FoodDiaryEntry entry, {
    FoodItem? ensureFoodInCatalog,
  }) async {
    if (ensureFoodInCatalog != null && !_foods.containsKey(ensureFoodInCatalog.id)) {
      _foods[ensureFoodInCatalog.id] = ensureFoodInCatalog;
      await _appendWalOrCompact({
        't': 'put_food',
        'd': ensureFoodInCatalog.toJson(),
      });
    }
    _indexMealEntry(entry);
    await _appendWalOrCompact({'t': 'put_meal', 'd': entry.toJson()});
    return entry;
  }

  Future<void> deleteMealEntry(String id) async {
    _removeMealEntry(id);
    await _appendWalOrCompact({'t': 'del_meal', 'd': id});
  }

  Future<WaterEntry> upsertWaterEntry(WaterEntry entry) async {
    _indexWaterEntry(entry);
    await _appendWalOrCompact({'t': 'put_water', 'd': entry.toJson()});
    return entry;
  }

  Future<void> deleteWaterEntry(String id) async {
    _removeWaterEntry(id);
    await _appendWalOrCompact({'t': 'del_water', 'd': id});
  }

  Future<CaffeineEntry> upsertCaffeineEntry(CaffeineEntry entry) async {
    _indexCaffeineEntry(entry);
    await _appendWalOrCompact({'t': 'put_caff', 'd': entry.toJson()});
    return entry;
  }

  Future<void> deleteCaffeineEntry(String id) async {
    _removeCaffeineEntry(id);
    await _appendWalOrCompact({'t': 'del_caff', 'd': id});
  }

  Future<PeriodEntry> upsertPeriodEntry(PeriodEntry entry) async {
    if (entry.endDate != null &&
        IsoDate.daysBetween(entry.startDate, entry.endDate!) < 0) {
      throw const FormatValidationException(
        'End date cannot be earlier than start date.',
      );
    }
    _periods[entry.id] = entry;
    await _appendWalOrCompact({'t': 'put_period', 'd': entry.toJson()});
    return entry;
  }

  Future<void> deletePeriodEntry(String id) async {
    _periods.remove(id);
    await _appendWalOrCompact({'t': 'del_period', 'd': id});
  }

  Future<WeightEntry> upsertWeightEntry(WeightEntry entry) async {
    _indexWeightEntry(entry);
    await _appendWalOrCompact({'t': 'put_weight', 'd': entry.toJson()});
    return entry;
  }

  Future<void> deleteWeightEntry(String id) async {
    _removeWeightEntry(id);
    await _appendWalOrCompact({'t': 'del_weight', 'd': id});
  }

  Future<SymptomEntry> upsertSymptomEntry(SymptomEntry entry) async {
    if (entry.intensity < 0 || entry.intensity > 10) {
      throw const FormatValidationException('Intensity must be 0..10.');
    }
    _indexSymptomEntry(entry);
    await _appendWalOrCompact({'t': 'put_symptom', 'd': entry.toJson()});
    return entry;
  }

  Future<void> deleteSymptomEntry(String id) async {
    _removeSymptomEntry(id);
    await _appendWalOrCompact({'t': 'del_symptom', 'd': id});
  }

  // --- Queries & Aggregations ---

  NutritionDaySummary nutritionForDay(String dateIso) {
    return NutritionService.summarizeDay(
      date: dateIso,
      dayFoodEntries: _mealsByDate[dateIso] ?? const [],
      dayWaterEntries: _waterByDate[dateIso] ?? const [],
      dayCaffeineEntries: _caffeineByDate[dateIso] ?? const [],
      foodCatalog: _foods,
      goals: _goals,
    );
  }

  CycleForecastResult cycleForecastOn(String dateIso) {
    return CycleForecastEngine.evaluate(
      allPeriods: _periods.values.toList(),
      onDate: dateIso,
      diaryOnlyMode: _preferences.cycleDiaryOnlyMode,
    );
  }

  List<PeriodEntry> periodsCoveringDate(String dateIso) {
    final today = clock.todayIso();
    return _periods.values
        .where((pe) => pe.coversDate(dateIso, referenceTodayIso: today))
        .toList()
      ..sort((a, b) => b.startDate.compareTo(a.startDate));
  }

  List<WeightEntry> weightsForDay(String dateIso) {
    final list = List<WeightEntry>.from(_weightsByDate[dateIso] ?? const [])
      ..sort((a, b) => b.recordedAt.compareTo(a.recordedAt));
    return list;
  }

  List<SymptomEntry> symptomsForDay(String dateIso) {
    final list = List<SymptomEntry>.from(_symptomsByDate[dateIso] ?? const [])
      ..sort((a, b) => a.recordedAt.compareTo(b.recordedAt));
    return list;
  }

  DayOverviewBundle overviewForDay(String dateIso) {
    return DayOverviewBundle(
      date: dateIso,
      nutrition: nutritionForDay(dateIso),
      cycleForecast: cycleForecastOn(dateIso),
      periodsCoveringDay: periodsCoveringDate(dateIso),
      weightEntries: weightsForDay(dateIso),
      symptomEntries: symptomsForDay(dateIso),
    );
  }

  /// Search local foods (favorites + custom + previously logged OFF foods).
  List<FoodItem> searchLocalFoods(String query, {bool favoritesOnly = false}) {
    final q = query.trim().toLowerCase();
    final tokens = q.isEmpty ? const <String>[] : q.split(RegExp(r'\s+'));
    final out = <FoodItem>[];
    for (final f in _foods.values) {
      if (favoritesOnly && !f.isFavorite) continue;
      if (tokens.isNotEmpty) {
        final hay =
            '${f.name} ${f.nameDe ?? ''} ${f.nameEn ?? ''} ${f.brand ?? ''} ${f.barcode ?? ''}'
                .toLowerCase();
        var matchAll = true;
        for (final t in tokens) {
          if (!hay.contains(t)) {
            matchAll = false;
            break;
          }
        }
        if (!matchAll) continue;
      }
      out.add(f);
    }
    out.sort((a, b) {
      if (a.isFavorite != b.isFavorite) return a.isFavorite ? -1 : 1;
      if (a.isCustom != b.isCustom) return a.isCustom ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return out;
  }

  /// 7-day or 28-day series for any nutrient JSON key or `'water_ml'`.
  List<TrendPoint> nutrientTrendSeries({
    required String endDateIso,
    required int days,
    required String metricKey,
  }) {
    final startIso = IsoDate.addDays(endDateIso, -(days - 1));
    final dates = IsoDate.rangeInclusive(startIso, endDateIso);
    return dates.map((d) {
      final hasAny = (_mealsByDate[d]?.isNotEmpty ?? false) ||
          (_waterByDate[d]?.isNotEmpty ?? false) ||
          (_caffeineByDate[d]?.isNotEmpty ?? false);
      if (!hasAny) {
        return TrendPoint(date: d, value: 0.0, hasEntry: false);
      }
      final day = nutritionForDay(d);
      return TrendPoint(
        date: d,
        value: day.valueForMetric(metricKey),
        hasEntry: true,
      );
    }).toList(growable: false);
  }

  /// 7-day or 28-day weight trend series in the requested display unit.
  List<TrendPoint> weightTrendSeries({
    required String endDateIso,
    required int days,
    required WeightUnit unit,
  }) {
    final startIso = IsoDate.addDays(endDateIso, -(days - 1));
    final dates = IsoDate.rangeInclusive(startIso, endDateIso);
    return dates.map((d) {
      final list = _weightsByDate[d];
      if (list == null || list.isEmpty) {
        return TrendPoint(date: d, value: null, hasEntry: false);
      }
      // Latest entry of that day
      var latest = list.first;
      for (final w in list) {
        if (w.recordedAt.compareTo(latest.recordedAt) > 0) latest = w;
      }
      return TrendPoint(
        date: d,
        value: latest.valueIn(unit),
        hasEntry: true,
      );
    }).toList(growable: false);
  }

  /// 7-day or 28-day symptom intensity series (max intensity logged on each day for that symptom).
  List<TrendPoint> symptomTrendSeries({
    required String endDateIso,
    required int days,
    required String symptomName,
  }) {
    final target = symptomName.trim().toLowerCase();
    final startIso = IsoDate.addDays(endDateIso, -(days - 1));
    final dates = IsoDate.rangeInclusive(startIso, endDateIso);
    return dates.map((d) {
      final list = _symptomsByDate[d];
      if (list == null || list.isEmpty) {
        return TrendPoint(date: d, value: null, hasEntry: false);
      }
      int? maxInt;
      for (final s in list) {
        if (s.name.trim().toLowerCase() == target) {
          if (maxInt == null || s.intensity > maxInt) {
            maxInt = s.intensity;
          }
        }
      }
      if (maxInt == null) {
        return TrendPoint(date: d, value: null, hasEntry: false);
      }
      return TrendPoint(date: d, value: maxInt.toDouble(), hasEntry: true);
    }).toList(growable: false);
  }

  /// Fast unified searchable history across all 4 modules (supports 10,000+ entries).
  List<UnifiedHistoryItem> searchHistory({
    String query = '',
    AppModule? moduleFilter,
    String? startDateIso,
    String? endDateIso,
    String locale = 'de',
  }) {
    final q = query.trim().toLowerCase();
    final tokens = q.isEmpty ? const <String>[] : q.split(RegExp(r'\s+'));

    bool dateMatches(String d) {
      if (startDateIso != null && d.compareTo(startDateIso) < 0) return false;
      if (endDateIso != null && d.compareTo(endDateIso) > 0) return false;
      return true;
    }

    bool textMatches(String lowerBlob) {
      if (tokens.isEmpty) return true;
      for (final t in tokens) {
        if (!lowerBlob.contains(t)) return false;
      }
      return true;
    }

    final results = <UnifiedHistoryItem>[];

    if (moduleFilter == null || moduleFilter == AppModule.nutrition) {
      for (final e in _mealEntries.values) {
        if (!dateMatches(e.date)) continue;
        final liveFood = _foods[e.foodId];
        final name = e.displayName(liveFood, locale);
        final brand = e.displayBrand(liveFood) ?? '';
        final mealLbl = e.mealType.label(locale);
        final kcal = e
            .computeNutrients(liveFood)
            .valueOrZero(NutrientKey.caloriesKcal)
            .round();
        final blob =
            '$name $brand $mealLbl ${e.note ?? ''} ${liveFood?.barcode ?? ''} ${e.date}'
                .toLowerCase();
        if (!textMatches(blob)) continue;
        results.add(
          UnifiedHistoryItem(
            id: e.id,
            module: AppModule.nutrition,
            kind: HistoryRecordKind.meal,
            date: e.date,
            sortTimestamp: e.recordedAt,
            title: name,
            subtitle:
                '$mealLbl · ${_fmtNum(e.amount)} ${e.unit.label(locale)} · $kcal kcal',
            searchBlobLower: blob,
            record: e,
          ),
        );
      }

      for (final w in _waterEntries.values) {
        if (!dateMatches(w.date)) continue;
        final waterTitle = locale == 'en' ? 'Water' : 'Wasser';
        final blob = '$waterTitle wasser water ${w.amountMl.round()} ml ${w.note ?? ''} ${w.date}'
            .toLowerCase();
        if (!textMatches(blob)) continue;
        results.add(
          UnifiedHistoryItem(
            id: w.id,
            module: AppModule.nutrition,
            kind: HistoryRecordKind.water,
            date: w.date,
            sortTimestamp: w.recordedAt,
            title: '$waterTitle (${w.amountMl.round()} ml)',
            subtitle: w.note != null && w.note!.isNotEmpty
                ? '${IsoDate.extractTimeHm(w.recordedAt)} · ${w.note}'
                : IsoDate.extractTimeHm(w.recordedAt),
            searchBlobLower: blob,
            record: w,
          ),
        );
      }

      for (final c in _caffeineEntries.values) {
        if (!dateMatches(c.date)) continue;
        final caffWord = locale == 'en' ? 'Caffeine' : 'Koffein';
        final title = c.sourceLabel != null && c.sourceLabel!.isNotEmpty
            ? '${c.sourceLabel} (${c.amountMg.round()} mg $caffWord)'
            : '$caffWord (${c.amountMg.round()} mg)';
        final blob =
            '$caffWord koffein caffeine ${c.sourceLabel ?? ''} ${c.amountMg.round()} mg ${c.note ?? ''} ${c.date}'
                .toLowerCase();
        if (!textMatches(blob)) continue;
        results.add(
          UnifiedHistoryItem(
            id: c.id,
            module: AppModule.nutrition,
            kind: HistoryRecordKind.caffeine,
            date: c.date,
            sortTimestamp: c.recordedAt,
            title: title,
            subtitle: c.note != null && c.note!.isNotEmpty
                ? '${IsoDate.extractTimeHm(c.recordedAt)} · ${c.note}'
                : IsoDate.extractTimeHm(c.recordedAt),
            searchBlobLower: blob,
            record: c,
          ),
        );
      }
    }

    if (moduleFilter == null || moduleFilter == AppModule.cycle) {
      for (final pe in _periods.values) {
        // Match if period start or end intersects [startDateIso..endDateIso]
        final peEnd = pe.endDate ?? pe.startDate;
        if (startDateIso != null && peEnd.compareTo(startDateIso) < 0) continue;
        if (endDateIso != null && pe.startDate.compareTo(endDateIso) > 0) {
          continue;
        }
        final kindLabel = pe.countsAsPeriod
            ? (locale == 'en' ? 'Period' : 'Periode')
            : (locale == 'en' ? 'Spotting' : 'Spotting');
        final rangeText = pe.endDate != null
            ? '${pe.startDate} – ${pe.endDate}'
            : (locale == 'en'
                ? '${pe.startDate} (ongoing)'
                : '${pe.startDate} (laufend)');
        final flowLabel = pe.intensity.label(locale);
        final blob =
            '$kindLabel periode period zyklus ${pe.intensity.labelDe} ${pe.intensity.labelEn} ${pe.note ?? ''} $rangeText'
                .toLowerCase();
        if (!textMatches(blob)) continue;
        results.add(
          UnifiedHistoryItem(
            id: pe.id,
            module: AppModule.cycle,
            kind: HistoryRecordKind.period,
            date: pe.startDate,
            sortTimestamp: '${pe.startDate}T12:00:00Z',
            title: '$kindLabel · $rangeText',
            subtitle: pe.note != null && pe.note!.isNotEmpty
                ? '$flowLabel · ${pe.note}'
                : flowLabel,
            searchBlobLower: blob,
            record: pe,
          ),
        );
      }
    }

    if (moduleFilter == null || moduleFilter == AppModule.weight) {
      final dispUnit = _preferences.weightUnit;
      for (final w in _weightEntries.values) {
        if (!dateMatches(w.date)) continue;
        final val = w.valueIn(dispUnit);
        final valStr = val.toStringAsFixed(1);
        final wLabel = locale == 'en' ? 'Weight' : 'Gewicht';
        final blob =
            '$wLabel gewicht weight $valStr ${dispUnit.jsonKey} ${w.weightKg.toStringAsFixed(1)} kg ${w.note ?? ''} ${w.date}'
                .toLowerCase();
        if (!textMatches(blob)) continue;
        results.add(
          UnifiedHistoryItem(
            id: w.id,
            module: AppModule.weight,
            kind: HistoryRecordKind.weight,
            date: w.date,
            sortTimestamp: w.recordedAt,
            title: '$wLabel: $valStr ${dispUnit.jsonKey}',
            subtitle: w.note != null && w.note!.isNotEmpty
                ? '${w.date} · ${w.note}'
                : w.date,
            searchBlobLower: blob,
            record: w,
          ),
        );
      }
    }

    if (moduleFilter == null || moduleFilter == AppModule.symptoms) {
      for (final s in _symptomEntries.values) {
        if (!dateMatches(s.date)) continue;
        final intLabel = locale == 'en'
            ? 'Intensity ${s.intensity}/10'
            : 'Intensität ${s.intensity}/10';
        final blob =
            'symptom ${s.name} ${s.intensity}/10 ${s.note ?? ''} ${s.date}'
                .toLowerCase();
        if (!textMatches(blob)) continue;
        results.add(
          UnifiedHistoryItem(
            id: s.id,
            module: AppModule.symptoms,
            kind: HistoryRecordKind.symptom,
            date: s.date,
            sortTimestamp: s.recordedAt,
            title: '${s.name} (${s.intensity}/10)',
            subtitle: s.note != null && s.note!.isNotEmpty
                ? '$intLabel · ${IsoDate.extractTimeHm(s.recordedAt)} · ${s.note}'
                : '$intLabel · ${IsoDate.extractTimeHm(s.recordedAt)}',
            searchBlobLower: blob,
            record: s,
          ),
        );
      }
    }

    results.sort((a, b) {
      final dc = b.date.compareTo(a.date);
      if (dc != 0) return dc;
      return b.sortTimestamp.compareTo(a.sortTimestamp);
    });
    return results;
  }

  static String _fmtNum(double v) {
    if (v == v.roundToDouble()) return v.round().toString();
    return v.toStringAsFixed(1);
  }
}
