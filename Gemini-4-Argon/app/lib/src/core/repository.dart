import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'crypto_vault.dart';
import 'cycle_engine.dart';
import 'models.dart';
import 'nutrients.dart';
import 'nutrition_engine.dart';

class HistoryRecord {
  final String id;
  final String domain; // 'nutrition', 'cycle', 'weight', 'symptoms'
  final String subType; // 'food', 'water', 'caffeine', 'period', 'weight', 'symptom'
  final String date; // YYYY-MM-DD
  final String timestamp; // RFC3339
  final String title;
  final String subtitle;
  final String? notes;
  final Object rawEntry;

  const HistoryRecord({
    required this.id,
    required this.domain,
    required this.subType,
    required this.date,
    required this.timestamp,
    required this.title,
    required this.subtitle,
    this.notes,
    required this.rawEntry,
  });
}

class MorphHealthRepository {
  static const String portableSchemaVersion = 'morphhealth.portable.v1';
  static const String vaultFileName = 'vault.mhv';

  final String dataDirPath;
  final String keyFilePath;
  final DateTime Function() clock;

  late Uint8List _masterKey;

  UserSettings _settings = const UserSettings();
  final Map<String, FoodItem> _customFoods = {};
  final Map<String, FoodItem> _favoriteFoods = {};
  final List<FoodDiaryEntry> _foodEntries = [];
  final List<WaterEntry> _waterEntries = [];
  final List<CaffeineEntry> _caffeineEntries = [];
  final List<PeriodEntry> _periodEntries = [];
  final List<WeightEntry> _weightEntries = [];
  final List<SymptomEntry> _symptomEntries = [];

  // Date indexes for O(1) day & range lookups on 10,000+ entries
  final Map<String, List<FoodDiaryEntry>> _foodByDate = {};
  final Map<String, List<WaterEntry>> _waterByDate = {};
  final Map<String, List<CaffeineEntry>> _caffeineByDate = {};
  final Map<String, List<WeightEntry>> _weightByDate = {};
  final Map<String, List<SymptomEntry>> _symptomsByDate = {};

  int _idCounter = 0;

  MorphHealthRepository({
    required this.dataDirPath,
    required this.keyFilePath,
    DateTime Function()? clock,
  }) : clock = clock ?? DateTime.now;

  DateTime get now => clock();

  String get todayYmd {
    final dt = now;
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }

  String get nowIso => now.toUtc().toIso8601String();

  File get _vaultFile =>
      File('${Directory(dataDirPath).absolute.path}${Platform.pathSeparator}$vaultFileName');

  String generateId(String prefix) {
    _idCounter++;
    final micros = now.microsecondsSinceEpoch;
    final rand = Random().nextInt(900000) + 100000;
    return '${prefix}_${micros}_${_idCounter}_$rand';
  }

  /// Initializes the repository by validating/loading the 32-byte master key
  /// and decrypting `vault.mhv` if present in `data-dir`.
  Future<void> initialize({bool createKeyIfMissing = true}) async {
    final dataDir = Directory(dataDirPath).absolute;
    if (!dataDir.existsSync()) {
      dataDir.createSync(recursive: true);
    }
    _masterKey = CryptoVault.loadOrCreateMasterKey(
      dataDirPath: dataDir.path,
      keyFilePath: keyFilePath,
      createIfMissing: createKeyIfMissing && !_vaultFile.existsSync(),
    );

    if (_vaultFile.existsSync()) {
      final bytes = _vaultFile.readAsBytesSync();
      final decoded =
          await CryptoVault.decryptVaultPayload(Uint8List.fromList(bytes), _masterKey);
      _applyPortableMap(decoded);
    } else {
      _rebuildIndexes();
      await save();
    }
  }

  Future<void> save() async {
    final doc = _buildPortableMap();
    final encrypted = await CryptoVault.encryptVaultPayload(doc, _masterKey);
    final tmpFile = File('${_vaultFile.path}.tmp');
    tmpFile.writeAsBytesSync(encrypted, flush: true);
    tmpFile.renameSync(_vaultFile.path);
  }

  // Getters
  UserSettings get settings => _settings;
  List<FoodItem> get customFoods =>
      _customFoods.values.toList()..sort((a, b) => a.name.compareTo(b.name));
  List<FoodItem> get favoriteFoods =>
      _favoriteFoods.values.toList()..sort((a, b) => a.name.compareTo(b.name));
  List<FoodDiaryEntry> get allFoodEntries => List.unmodifiable(_foodEntries);
  List<WaterEntry> get allWaterEntries => List.unmodifiable(_waterEntries);
  List<CaffeineEntry> get allCaffeineEntries =>
      List.unmodifiable(_caffeineEntries);
  List<PeriodEntry> get allPeriodEntries => List.unmodifiable(_periodEntries);
  List<WeightEntry> get allWeightEntries => List.unmodifiable(_weightEntries);
  List<SymptomEntry> get allSymptomEntries => List.unmodifiable(_symptomEntries);

  int get totalDiaryEntryCount =>
      _foodEntries.length +
      _waterEntries.length +
      _caffeineEntries.length +
      _periodEntries.length +
      _weightEntries.length +
      _symptomEntries.length;

  void _rebuildIndexes() {
    _foodByDate.clear();
    for (final e in _foodEntries) {
      (_foodByDate[e.date] ??= []).add(e);
    }
    _waterByDate.clear();
    for (final e in _waterEntries) {
      (_waterByDate[e.date] ??= []).add(e);
    }
    _caffeineByDate.clear();
    for (final e in _caffeineEntries) {
      (_caffeineByDate[e.date] ??= []).add(e);
    }
    _weightByDate.clear();
    for (final e in _weightEntries) {
      (_weightByDate[e.date] ??= []).add(e);
    }
    _symptomsByDate.clear();
    for (final e in _symptomEntries) {
      (_symptomsByDate[e.date] ??= []).add(e);
    }
  }

  // Settings
  Future<void> updateSettings(UserSettings newSettings) async {
    _settings = newSettings;
    await save();
  }

  // Custom & Favorite Foods
  bool isFoodFavorite(String foodId, {String? barcode}) {
    if (_favoriteFoods.containsKey(foodId)) return true;
    if (barcode != null && barcode.isNotEmpty) {
      return _favoriteFoods.values.any((f) => f.barcode == barcode);
    }
    return false;
  }

  Future<FoodItem> saveCustomFood(FoodItem item) async {
    final normalized = item.copyWith(
      isCustom: true,
      isFavorite: _favoriteFoods.containsKey(item.id) || item.isFavorite,
      updatedAt: nowIso,
    );
    _customFoods[normalized.id] = normalized;
    if (normalized.isFavorite) {
      _favoriteFoods[normalized.id] = normalized;
    }
    // Update embedded food snapshots for existing diary entries of this custom food
    for (int i = 0; i < _foodEntries.length; i++) {
      if (_foodEntries[i].food.id == normalized.id) {
        _foodEntries[i] = _foodEntries[i].copyWith(
          food: normalized,
          servingQuantityG: normalized.servingQuantityG,
        );
      }
    }
    _rebuildIndexes();
    await save();
    return normalized;
  }

  Future<void> deleteCustomFood(String id) async {
    _customFoods.remove(id);
    _favoriteFoods.remove(id);
    await save();
  }

  Future<bool> toggleFavoriteFood(FoodItem item) async {
    final existingKey = _favoriteFoods.containsKey(item.id)
        ? item.id
        : _favoriteFoods.entries
            .where((e) => item.barcode != null && e.value.barcode == item.barcode)
            .map((e) => e.key)
            .firstOrNull;

    final bool nowFav;
    if (existingKey != null) {
      _favoriteFoods.remove(existingKey);
      if (_customFoods.containsKey(item.id)) {
        _customFoods[item.id] =
            _customFoods[item.id]!.copyWith(isFavorite: false);
      }
      nowFav = false;
    } else {
      final favItem = item.copyWith(isFavorite: true, updatedAt: nowIso);
      _favoriteFoods[favItem.id] = favItem;
      if (_customFoods.containsKey(favItem.id)) {
        _customFoods[favItem.id] = favItem.copyWith(isCustom: true);
      }
      nowFav = true;
    }
    await save();
    return nowFav;
  }

  /// Returns recently logged distinct FoodDiaryEntry templates (most recent first)
  /// for fast 1-tap re-logging.
  List<FoodDiaryEntry> getRecentFoodEntries({int limit = 25}) {
    final sorted = List<FoodDiaryEntry>.from(_foodEntries)
      ..sort((a, b) => b.timestamp.compareTo(a.timestamp));
    final seen = <String>{};
    final out = <FoodDiaryEntry>[];
    for (final e in sorted) {
      final key = '${e.food.id}_${e.unit}_${e.amount}';
      if (seen.add(key)) {
        out.add(e);
        if (out.length >= limit) break;
      }
    }
    return out;
  }

  /// Searches local custom foods and favorites by name/brand/barcode.
  List<FoodItem> searchLocalFoods(String query) {
    final q = query.trim().toLowerCase();
    final combined = <String, FoodItem>{
      ..._favoriteFoods,
      ..._customFoods,
    };
    if (q.isEmpty) {
      return combined.values.toList()
        ..sort((a, b) => a.name.compareTo(b.name));
    }
    return combined.values.where((f) {
      return f.name.toLowerCase().contains(q) ||
          (f.nameDe?.toLowerCase().contains(q) ?? false) ||
          (f.nameEn?.toLowerCase().contains(q) ?? false) ||
          (f.brand?.toLowerCase().contains(q) ?? false) ||
          (f.barcode?.toLowerCase().contains(q) ?? false);
    }).toList()
      ..sort((a, b) => a.name.compareTo(b.name));
  }

  // Food Diary CRUD
  Future<FoodDiaryEntry> upsertFoodEntry(FoodDiaryEntry entry) async {
    final idx = _foodEntries.indexWhere((e) => e.id == entry.id);
    if (idx >= 0) {
      _foodEntries[idx] = entry;
    } else {
      _foodEntries.add(entry);
    }
    _rebuildIndexes();
    await save();
    return entry;
  }

  Future<FoodDiaryEntry> relogFoodEntry(
    FoodDiaryEntry source, {
    required String targetDate,
    String? targetMeal,
  }) async {
    final copy = FoodDiaryEntry(
      id: generateId('fe'),
      date: targetDate,
      timestamp: nowIso,
      meal: targetMeal ?? source.meal,
      food: source.food,
      amount: source.amount,
      unit: source.unit,
      servingQuantityG: source.servingQuantityG,
      notes: source.notes,
    );
    return upsertFoodEntry(copy);
  }

  Future<void> deleteFoodEntry(String id) async {
    _foodEntries.removeWhere((e) => e.id == id);
    _rebuildIndexes();
    await save();
  }

  // Water CRUD
  Future<WaterEntry> upsertWaterEntry(WaterEntry entry) async {
    final idx = _waterEntries.indexWhere((e) => e.id == entry.id);
    if (idx >= 0) {
      _waterEntries[idx] = entry;
    } else {
      _waterEntries.add(entry);
    }
    _rebuildIndexes();
    await save();
    return entry;
  }

  Future<WaterEntry> quickAddWater({
    required String date,
    required double amountMl,
    String? notes,
  }) async {
    final entry = WaterEntry(
      id: generateId('we'),
      date: date,
      timestamp: nowIso,
      amountMl: amountMl,
      notes: notes,
    );
    return upsertWaterEntry(entry);
  }

  Future<void> deleteWaterEntry(String id) async {
    _waterEntries.removeWhere((e) => e.id == id);
    _rebuildIndexes();
    await save();
    return;
  }

  // Caffeine CRUD
  Future<CaffeineEntry> upsertCaffeineEntry(CaffeineEntry entry) async {
    final idx = _caffeineEntries.indexWhere((e) => e.id == entry.id);
    if (idx >= 0) {
      _caffeineEntries[idx] = entry;
    } else {
      _caffeineEntries.add(entry);
    }
    _rebuildIndexes();
    await save();
    return entry;
  }

  Future<void> deleteCaffeineEntry(String id) async {
    _caffeineEntries.removeWhere((e) => e.id == id);
    _rebuildIndexes();
    await save();
  }

  // Period CRUD
  Future<PeriodEntry> upsertPeriodEntry(PeriodEntry entry) async {
    final idx = _periodEntries.indexWhere((e) => e.id == entry.id);
    if (idx >= 0) {
      _periodEntries[idx] = entry;
    } else {
      _periodEntries.add(entry);
    }
    _periodEntries.sort((a, b) => b.startDate.compareTo(a.startDate));
    await save();
    return entry;
  }

  Future<void> deletePeriodEntry(String id) async {
    _periodEntries.removeWhere((e) => e.id == id);
    await save();
  }

  List<PeriodEntry> periodsForDate(String date) {
    return _periodEntries.where((p) => p.containsDate(date)).toList();
  }

  // Weight CRUD
  Future<WeightEntry> upsertWeightEntry(WeightEntry entry) async {
    final idx = _weightEntries.indexWhere((e) => e.id == entry.id);
    if (idx >= 0) {
      _weightEntries[idx] = entry;
    } else {
      _weightEntries.add(entry);
    }
    _weightEntries.sort((a, b) => b.date.compareTo(a.date));
    _rebuildIndexes();
    await save();
    return entry;
  }

  Future<void> deleteWeightEntry(String id) async {
    _weightEntries.removeWhere((e) => e.id == id);
    _rebuildIndexes();
    await save();
  }

  List<WeightEntry> weightsForDate(String date) =>
      List.unmodifiable(_weightByDate[date] ?? const []);

  WeightEntry? latestWeightOnOrBefore(String date) {
    WeightEntry? best;
    for (final w in _weightEntries) {
      if (w.date.compareTo(date) <= 0) {
        if (best == null ||
            w.date.compareTo(best.date) > 0 ||
            (w.date == best.date && w.timestamp.compareTo(best.timestamp) > 0)) {
          best = w;
        }
      }
    }
    return best;
  }

  // Symptom CRUD
  Future<SymptomEntry> upsertSymptomEntry(SymptomEntry entry) async {
    final idx = _symptomEntries.indexWhere((e) => e.id == entry.id);
    if (idx >= 0) {
      _symptomEntries[idx] = entry;
    } else {
      _symptomEntries.add(entry);
    }
    _symptomEntries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    _rebuildIndexes();
    await save();
    return entry;
  }

  Future<void> deleteSymptomEntry(String id) async {
    _symptomEntries.removeWhere((e) => e.id == id);
    _rebuildIndexes();
    await save();
  }

  List<SymptomEntry> symptomsForDate(String date) =>
      List.unmodifiable(_symptomsByDate[date] ?? const []);

  List<String> get distinctSymptomNames {
    final names = <String>{};
    for (final s in _symptomEntries) {
      if (s.name.trim().isNotEmpty) {
        names.add(s.name.trim());
      }
    }
    final list = names.toList()..sort();
    return list;
  }

  // Aggregations & Engines
  NutritionDaySummary getNutritionDay(String date) {
    return NutritionEngine.summarizeDay(
      date: date,
      foodEntries: _foodByDate[date] ?? const [],
      waterEntries: _waterByDate[date] ?? const [],
      caffeineEntries: _caffeineByDate[date] ?? const [],
      goals: _settings.goals,
    );
  }

  CycleForecastResult getCycleForecast(String onDate) {
    return CycleForecastEngine.evaluate(
      periods: _periodEntries,
      onDate: onDate,
    );
  }

  /// Generates a daily series ending on [endDate] over [days] (e.g. 7 or 28)
  /// for a selected nutrient key (or `'water_ml'`).
  List<({String date, double value})> getNutrientSeries({
    required String endDate,
    required int days,
    required String metricKey,
  }) {
    final endDt = DateTime.parse('${endDate.substring(0, 10)}T00:00:00Z');
    final out = <({String date, double value})>[];
    for (int i = days - 1; i >= 0; i--) {
      final dt = endDt.subtract(Duration(days: i));
      final ymd = _formatYmd(dt);
      final summary = getNutritionDay(ymd);
      final double val;
      if (metricKey == 'water_ml') {
        val = summary.waterMl;
      } else if (metricKey == 'caffeine_mg') {
        val = summary.totalCaffeineMg;
      } else {
        val = summary.totalNutrients[metricKey];
      }
      out.add((date: ymd, value: val));
    }
    return out;
  }

  /// Returns weight series within `[endDate - days + 1 .. endDate]` (or all if days <= 0).
  List<WeightEntry> getWeightSeries({
    required String endDate,
    required int days,
  }) {
    if (days <= 0) {
      final all = List<WeightEntry>.from(_weightEntries)
        ..sort((a, b) => a.date.compareTo(b.date));
      return all;
    }
    final endDt = DateTime.parse('${endDate.substring(0, 10)}T00:00:00Z');
    final startYmd = _formatYmd(endDt.subtract(Duration(days: days - 1)));
    final filtered = _weightEntries
        .where((w) =>
            w.date.compareTo(startYmd) >= 0 && w.date.compareTo(endDate) <= 0)
        .toList()
      ..sort((a, b) => a.date.compareTo(b.date));
    return filtered;
  }

  /// Returns symptom intensity series for a specific symptom name.
  List<SymptomEntry> getSymptomSeries({
    required String symptomName,
    String? endDate,
    int days = 28,
  }) {
    final target = symptomName.trim().toLowerCase();
    Iterable<SymptomEntry> iter =
        _symptomEntries.where((s) => s.name.trim().toLowerCase() == target);
    if (endDate != null && days > 0) {
      final endDt = DateTime.parse('${endDate.substring(0, 10)}T00:00:00Z');
      final startYmd = _formatYmd(endDt.subtract(Duration(days: days - 1)));
      iter = iter.where((s) =>
          s.date.compareTo(startYmd) >= 0 && s.date.compareTo(endDate) <= 0);
    }
    final list = iter.toList()
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));
    return list;
  }

  /// Cross-domain searchable history supporting date range, domain, and free-text filters.
  /// Optimized to handle 10,000+ entries smoothly.
  List<HistoryRecord> searchHistory({
    String? fromDate,
    String? toDate,
    String? domain, // null/'all', 'nutrition', 'cycle', 'weight', 'symptoms'
    String? query,
    String lang = 'de',
  }) {
    final cleanDomain = (domain == null || domain == 'all' || domain.isEmpty)
        ? null
        : domain.toLowerCase();
    final q = (query ?? '').trim().toLowerCase();
    final weightUnit = _settings.weightUnit;

    bool dateMatches(String d) {
      if (fromDate != null &&
          fromDate.isNotEmpty &&
          d.compareTo(fromDate) < 0) {
        return false;
      }
      if (toDate != null && toDate.isNotEmpty && d.compareTo(toDate) > 0) {
        return false;
      }
      return true;
    }

    bool textMatches(String title, String subtitle, String? notes) {
      if (q.isEmpty) return true;
      if (title.toLowerCase().contains(q)) return true;
      if (subtitle.toLowerCase().contains(q)) return true;
      if (notes != null && notes.toLowerCase().contains(q)) return true;
      return false;
    }

    final records = <HistoryRecord>[];

    if (cleanDomain == null || cleanDomain == 'nutrition') {
      for (final f in _foodEntries) {
        if (!dateMatches(f.date)) continue;
        final mealLabel = MealType.label(f.meal, lang);
        final foodName = f.food.displayName(lang);
        final brandPart =
            (f.food.brand != null && f.food.brand!.isNotEmpty)
                ? ' (${f.food.brand})'
                : '';
        final title = '$foodName$brandPart';
        final kcal = f.nutrients.caloriesKcal.round();
        final subtitle =
            '$mealLabel · ${f.amount.toStringAsFixed(f.amount == f.amount.roundToDouble() ? 0 : 1)} ${FoodUnit.label(f.unit, lang)} · $kcal kcal';
        if (textMatches(title, subtitle, f.notes)) {
          records.add(
            HistoryRecord(
              id: f.id,
              domain: 'nutrition',
              subType: 'food',
              date: f.date,
              timestamp: f.timestamp,
              title: title,
              subtitle: subtitle,
              notes: f.notes,
              rawEntry: f,
            ),
          );
        }
      }
      for (final w in _waterEntries) {
        if (!dateMatches(w.date)) continue;
        final title = lang == 'en' ? 'Water' : 'Wasser';
        final subtitle = '${w.amountMl.round()} ml';
        if (textMatches(title, subtitle, w.notes)) {
          records.add(
            HistoryRecord(
              id: w.id,
              domain: 'nutrition',
              subType: 'water',
              date: w.date,
              timestamp: w.timestamp,
              title: title,
              subtitle: subtitle,
              notes: w.notes,
              rawEntry: w,
            ),
          );
        }
      }
      for (final c in _caffeineEntries) {
        if (!dateMatches(c.date)) continue;
        final bev = (c.beverageName != null && c.beverageName!.trim().isNotEmpty)
            ? c.beverageName!.trim()
            : (lang == 'en' ? 'Caffeine' : 'Koffein');
        final subtitle = '${c.amountMg.round()} mg ${lang == 'en' ? 'Caffeine' : 'Koffein'}';
        if (textMatches(bev, subtitle, c.notes)) {
          records.add(
            HistoryRecord(
              id: c.id,
              domain: 'nutrition',
              subType: 'caffeine',
              date: c.date,
              timestamp: c.timestamp,
              title: bev,
              subtitle: subtitle,
              notes: c.notes,
              rawEntry: c,
            ),
          );
        }
      }
    }

    if (cleanDomain == null || cleanDomain == 'cycle') {
      for (final p in _periodEntries) {
        final end = p.endDate ?? p.startDate;
        final inRange = (fromDate == null ||
                fromDate.isEmpty ||
                end.compareTo(fromDate) >= 0) &&
            (toDate == null ||
                toDate.isEmpty ||
                p.startDate.compareTo(toDate) <= 0);
        if (!inRange) continue;
        final title = lang == 'en'
            ? 'Period (${p.startDate}${p.endDate != null ? ' – ${p.endDate}' : ''})'
            : 'Periode (${p.startDate}${p.endDate != null ? ' – ${p.endDate}' : ''})';
        final subtitle =
            '${BleedingIntensity.label(p.intensity, lang)} · ${p.durationDays} ${lang == 'en' ? 'days' : 'Tage'}';
        if (textMatches(title, subtitle, p.notes)) {
          records.add(
            HistoryRecord(
              id: p.id,
              domain: 'cycle',
              subType: 'period',
              date: p.startDate,
              timestamp: '${p.startDate}T09:00:00Z',
              title: title,
              subtitle: subtitle,
              notes: p.notes,
              rawEntry: p,
            ),
          );
        }
      }
    }

    if (cleanDomain == null || cleanDomain == 'weight') {
      for (final w in _weightEntries) {
        if (!dateMatches(w.date)) continue;
        final val = w.valueInUnit(weightUnit);
        final title = lang == 'en' ? 'Weight' : 'Gewicht';
        final subtitle = '${val.toStringAsFixed(1)} $weightUnit';
        if (textMatches(title, subtitle, w.notes)) {
          records.add(
            HistoryRecord(
              id: w.id,
              domain: 'weight',
              subType: 'weight',
              date: w.date,
              timestamp: w.timestamp,
              title: title,
              subtitle: subtitle,
              notes: w.notes,
              rawEntry: w,
            ),
          );
        }
      }
    }

    if (cleanDomain == null || cleanDomain == 'symptoms') {
      for (final s in _symptomEntries) {
        if (!dateMatches(s.date)) continue;
        final title = s.name;
        final subtitle = lang == 'en'
            ? 'Intensity: ${s.intensity}/10'
            : 'Intensität: ${s.intensity}/10';
        if (textMatches(title, subtitle, s.notes)) {
          records.add(
            HistoryRecord(
              id: s.id,
              domain: 'symptoms',
              subType: 'symptom',
              date: s.date,
              timestamp: s.timestamp,
              title: title,
              subtitle: subtitle,
              notes: s.notes,
              rawEntry: s,
            ),
          );
        }
      }
    }

    records.sort((a, b) {
      final cmpDate = b.date.compareTo(a.date);
      if (cmpDate != 0) return cmpDate;
      return b.timestamp.compareTo(a.timestamp);
    });
    return records;
  }

  // Portability & Backups
  Map<String, dynamic> exportPortableDocument({required bool ackPlaintext}) {
    if (!ackPlaintext) {
      throw ArgumentError(
        'ack_plaintext: true is required to export unencrypted portable data.',
      );
    }
    return _buildPortableMap();
  }

  Future<Map<String, dynamic>> importPortableDocument({
    required Map<String, dynamic> document,
    required bool confirmReplace,
  }) async {
    if (!confirmReplace) {
      throw ArgumentError(
        'confirm_replace: true is required to replace working dataset.',
      );
    }
    final unwrapped = (document['document'] is Map &&
            !document.containsKey('schema_version') &&
            !document.containsKey('food_entries'))
        ? Map<String, dynamic>.from(document['document'] as Map)
        : document;

    final schema = unwrapped['schema_version']?.toString();
    if (schema != null &&
        schema.isNotEmpty &&
        schema != portableSchemaVersion) {
      throw FormatException(
        'Unsupported portable document schema_version: $schema (expected $portableSchemaVersion)',
      );
    }

    _applyPortableMap(unwrapped);
    await save();

    return {
      'replaced': true,
      'schema_version': portableSchemaVersion,
      'imported_at': nowIso,
      'counts': {
        'custom_foods': _customFoods.length,
        'favorite_foods': _favoriteFoods.length,
        'food_entries': _foodEntries.length,
        'water_entries': _waterEntries.length,
        'caffeine_entries': _caffeineEntries.length,
        'period_entries': _periodEntries.length,
        'weight_entries': _weightEntries.length,
        'symptom_entries': _symptomEntries.length,
        'total_entries': totalDiaryEntryCount,
      },
    };
  }

  Future<Map<String, dynamic>> createEncryptedBackup(String passphrase) async {
    final doc = _buildPortableMap();
    return CryptoVault.createEncryptedBackup(
      portableDocument: doc,
      passphrase: passphrase,
      createdAtIso: nowIso,
    );
  }

  Future<Map<String, dynamic>> restoreEncryptedBackup({
    required Map<String, dynamic> backupEnvelope,
    required String passphrase,
  }) async {
    final doc = await CryptoVault.decryptEncryptedBackup(
      backupEnvelope: backupEnvelope,
      passphrase: passphrase,
    );
    return importPortableDocument(document: doc, confirmReplace: true);
  }

  Future<void> deleteAllData() async {
    _settings = const UserSettings();
    _customFoods.clear();
    _favoriteFoods.clear();
    _foodEntries.clear();
    _waterEntries.clear();
    _caffeineEntries.clear();
    _periodEntries.clear();
    _weightEntries.clear();
    _symptomEntries.clear();
    _rebuildIndexes();
    await save();
  }

  Map<String, dynamic> _buildPortableMap() {
    return {
      'schema_version': portableSchemaVersion,
      'application': 'MorphHealth',
      'exported_at': nowIso,
      'settings': _settings.toJson(),
      'custom_foods': _customFoods.values.map((e) => e.toJson()).toList(),
      'favorite_foods': _favoriteFoods.values.map((e) => e.toJson()).toList(),
      'food_entries': _foodEntries.map((e) => e.toJson()).toList(),
      'water_entries': _waterEntries.map((e) => e.toJson()).toList(),
      'caffeine_entries': _caffeineEntries.map((e) => e.toJson()).toList(),
      'period_entries': _periodEntries.map((e) => e.toJson()).toList(),
      'weight_entries': _weightEntries.map((e) => e.toJson()).toList(),
      'symptom_entries': _symptomEntries.map((e) => e.toJson()).toList(),
    };
  }

  void _applyPortableMap(Map<String, dynamic> map) {
    _settings = UserSettings.fromJson(
      map['settings'] is Map
          ? Map<String, dynamic>.from(map['settings'] as Map)
          : null,
    );

    _customFoods.clear();
    if (map['custom_foods'] is List) {
      for (final raw in map['custom_foods'] as List) {
        if (raw is Map) {
          final item =
              FoodItem.fromJson(Map<String, dynamic>.from(raw)).copyWith(isCustom: true);
          _customFoods[item.id] = item;
        }
      }
    }

    _favoriteFoods.clear();
    if (map['favorite_foods'] is List) {
      for (final raw in map['favorite_foods'] as List) {
        if (raw is Map) {
          final item =
              FoodItem.fromJson(Map<String, dynamic>.from(raw)).copyWith(isFavorite: true);
          _favoriteFoods[item.id] = item;
        }
      }
    }

    _foodEntries.clear();
    if (map['food_entries'] is List) {
      for (final raw in map['food_entries'] as List) {
        if (raw is Map) {
          _foodEntries.add(
            FoodDiaryEntry.fromJson(Map<String, dynamic>.from(raw)),
          );
        }
      }
    }

    _waterEntries.clear();
    if (map['water_entries'] is List) {
      for (final raw in map['water_entries'] as List) {
        if (raw is Map) {
          _waterEntries.add(
            WaterEntry.fromJson(Map<String, dynamic>.from(raw)),
          );
        }
      }
    }

    _caffeineEntries.clear();
    if (map['caffeine_entries'] is List) {
      for (final raw in map['caffeine_entries'] as List) {
        if (raw is Map) {
          _caffeineEntries.add(
            CaffeineEntry.fromJson(Map<String, dynamic>.from(raw)),
          );
        }
      }
    }

    _periodEntries.clear();
    if (map['period_entries'] is List) {
      for (final raw in map['period_entries'] as List) {
        if (raw is Map) {
          _periodEntries.add(
            PeriodEntry.fromJson(Map<String, dynamic>.from(raw)),
          );
        }
      }
      _periodEntries.sort((a, b) => b.startDate.compareTo(a.startDate));
    }

    _weightEntries.clear();
    if (map['weight_entries'] is List) {
      for (final raw in map['weight_entries'] as List) {
        if (raw is Map) {
          _weightEntries.add(
            WeightEntry.fromJson(Map<String, dynamic>.from(raw)),
          );
        }
      }
      _weightEntries.sort((a, b) => b.date.compareTo(a.date));
    }

    _symptomEntries.clear();
    if (map['symptom_entries'] is List) {
      for (final raw in map['symptom_entries'] as List) {
        if (raw is Map) {
          _symptomEntries.add(
            SymptomEntry.fromJson(Map<String, dynamic>.from(raw)),
          );
        }
      }
      _symptomEntries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    }

    _rebuildIndexes();
  }

  /// Generates a complete, valid example document suitable for `portable.import`
  /// and returned by `mh` `describe`.
  static Map<String, dynamic> buildExamplePortableDocument({
    String referenceDate = '2026-10-15',
  }) {
    final oatNutrients = NutrientProfile({
      'calories_kcal': 372.0,
      'protein_g': 13.5,
      'carbohydrates_g': 58.7,
      'fat_g': 7.0,
      'saturated_fat_g': 1.3,
      'sugars_g': 0.7,
      'fiber_g': 10.0,
      'salt_g': 0.02,
      'sodium_mg': 8.0,
      'caffeine_mg': 0.0,
      'vitamin_a_ug': 0.0,
      'vitamin_c_mg': 0.0,
      'vitamin_d_ug': 0.0,
      'vitamin_e_mg': 0.8,
      'vitamin_k_ug': 2.0,
      'vitamin_b1_mg': 0.6,
      'vitamin_b2_mg': 0.15,
      'vitamin_b3_mg': 1.0,
      'vitamin_b5_mg': 1.1,
      'vitamin_b6_mg': 0.16,
      'vitamin_b7_ug': 20.0,
      'vitamin_b9_ug': 56.0,
      'vitamin_b12_ug': 0.0,
      'calcium_mg': 54.0,
      'iron_mg': 4.3,
      'magnesium_mg': 130.0,
      'potassium_mg': 350.0,
      'zinc_mg': 3.6,
      'selenium_ug': 7.0,
      'iodine_ug': 1.5,
      'phosphorus_mg': 430.0,
    });

    final oats = FoodItem(
      id: 'custom_oats_1',
      barcode: '20003166',
      name: 'Vollkorn-Haferflocken',
      nameDe: 'Vollkorn-Haferflocken',
      nameEn: 'Wholegrain Rolled Oats',
      brand: 'Crownfield',
      isCustom: true,
      isFavorite: true,
      defaultUnit: 'g',
      servingSizeLabel: '50 g',
      servingQuantityG: 50.0,
      nutrientsPer100g: oatNutrients,
      updatedAt: '${referenceDate}T08:00:00Z',
    );

    return {
      'schema_version': portableSchemaVersion,
      'application': 'MorphHealth',
      'exported_at': '${referenceDate}T08:00:00Z',
      'settings': const UserSettings(
        language: 'de',
        weightUnit: 'kg',
        goals: NutritionGoals(
          waterMl: 2000.0,
          caloriesKcal: 2100.0,
          proteinG: 90.0,
          carbohydratesG: 240.0,
          fatG: 70.0,
        ),
      ).toJson(),
      'custom_foods': [oats.toJson()],
      'favorite_foods': [oats.toJson()],
      'food_entries': [
        FoodDiaryEntry(
          id: 'fe_example_1',
          date: referenceDate,
          timestamp: '${referenceDate}T07:45:00Z',
          meal: MealType.breakfast,
          food: oats,
          amount: 1.5,
          unit: FoodUnit.portion,
          servingQuantityG: 50.0,
          notes: 'Mit warmem Wasser und Zimt',
        ).toJson(),
      ],
      'water_entries': [
        WaterEntry(
          id: 'we_example_1',
          date: referenceDate,
          timestamp: '${referenceDate}T08:00:00Z',
          amountMl: 300.0,
          notes: 'Morgens',
        ).toJson(),
        WaterEntry(
          id: 'we_example_2',
          date: referenceDate,
          timestamp: '${referenceDate}T12:30:00Z',
          amountMl: 500.0,
        ).toJson(),
      ],
      'caffeine_entries': [
        CaffeineEntry(
          id: 'ce_example_1',
          date: referenceDate,
          timestamp: '${referenceDate}T08:15:00Z',
          amountMg: 80.0,
          beverageName: 'Espresso Doppio',
        ).toJson(),
      ],
      'period_entries': [
        const PeriodEntry(
          id: 'pe_example_1',
          startDate: '2026-07-10',
          endDate: '2026-07-14',
          intensity: BleedingIntensity.medium,
          notes: 'Normaler Verlauf',
        ).toJson(),
        const PeriodEntry(
          id: 'pe_example_2',
          startDate: '2026-08-07',
          endDate: '2026-08-11',
          intensity: BleedingIntensity.medium,
        ).toJson(),
        const PeriodEntry(
          id: 'pe_example_3',
          startDate: '2026-09-05',
          endDate: '2026-09-09',
          intensity: BleedingIntensity.heavy,
          dailyFlow: {
            '2026-09-05': BleedingIntensity.spotting,
            '2026-09-06': BleedingIntensity.heavy,
            '2026-09-07': BleedingIntensity.medium,
            '2026-09-08': BleedingIntensity.light,
            '2026-09-09': BleedingIntensity.spotting,
          },
          notes: 'Tag 1 Schmierblutung',
        ).toJson(),
        const PeriodEntry(
          id: 'pe_example_4',
          startDate: '2026-10-03',
          endDate: '2026-10-07',
          intensity: BleedingIntensity.medium,
        ).toJson(),
      ],
      'weight_entries': [
        WeightEntry(
          id: 'wt_example_1',
          date: referenceDate,
          timestamp: '${referenceDate}T07:15:00Z',
          weightKg: 64.5,
          inputUnit: 'kg',
          notes: 'Morgens nüchtern',
        ).toJson(),
      ],
      'symptom_entries': [
        SymptomEntry(
          id: 'sy_example_1',
          date: referenceDate,
          timestamp: '${referenceDate}T14:00:00Z',
          name: 'Kopfschmerzen',
          intensity: 3,
          notes: 'Leichter Druck am Nachmittag',
        ).toJson(),
      ],
    };
  }

  /// Populates a large synthetic multi-year dataset (e.g. [targetTotalEntries] = 10000)
  /// for performance verification or interactive stress testing.
  Future<void> generateBulkDataset({int targetTotalEntries = 10000}) async {
    _customFoods.clear();
    _favoriteFoods.clear();
    _foodEntries.clear();
    _waterEntries.clear();
    _caffeineEntries.clear();
    _periodEntries.clear();
    _weightEntries.clear();
    _symptomEntries.clear();

    final baseFood = FoodItem(
      id: 'custom_bulk_oats',
      barcode: '20003166',
      name: 'Haferflocken Zart',
      nameDe: 'Haferflocken Zart',
      nameEn: 'Rolled Oats',
      brand: 'MorphHealth',
      isCustom: true,
      isFavorite: true,
      defaultUnit: 'g',
      servingQuantityG: 50.0,
      nutrientsPer100g: NutrientProfile({
        'calories_kcal': 370.0,
        'protein_g': 13.0,
        'carbohydrates_g': 59.0,
        'fat_g': 7.0,
        'fiber_g': 10.0,
        'iron_mg': 4.2,
        'magnesium_mg': 130.0,
        'zinc_mg': 3.5,
        'vitamin_b1_mg': 0.5,
      }),
      updatedAt: nowIso,
    );
    _customFoods[baseFood.id] = baseFood;
    _favoriteFoods[baseFood.id] = baseFood;

    final endDt = DateTime.parse('${todayYmd}T00:00:00Z');
    int created = 0;
    int dayOffset = 0;

    // Add 24 monthly periods over ~2 years
    for (int p = 0; p < 24 && created < targetTotalEntries; p++) {
      final startDt = endDt.subtract(Duration(days: p * 28 + 10));
      final endPeriodDt = startDt.add(const Duration(days: 4));
      _periodEntries.add(
        PeriodEntry(
          id: 'pe_bulk_$p',
          startDate: _formatYmd(startDt),
          endDate: _formatYmd(endPeriodDt),
          intensity: BleedingIntensity.medium,
          notes: 'Zyklus #${24 - p}',
        ),
      );
      created++;
    }

    final symptoms = ['Kopfschmerzen', 'Müdigkeit', 'Krämpfe', 'Rückenschmerzen'];
    while (created < targetTotalEntries) {
      final dt = endDt.subtract(Duration(days: dayOffset));
      final ymd = _formatYmd(dt);

      for (final meal in MealType.all) {
        if (created >= targetTotalEntries) break;
        _foodEntries.add(
          FoodDiaryEntry(
            id: 'fe_bulk_$created',
            date: ymd,
            timestamp: '${ymd}T08:00:00Z',
            meal: meal,
            food: baseFood,
            amount: 100.0 + (created % 50),
            unit: FoodUnit.gram,
            servingQuantityG: 50.0,
          ),
        );
        created++;
      }

      if (created < targetTotalEntries) {
        _waterEntries.add(
          WaterEntry(
            id: 'we_bulk_$created',
            date: ymd,
            timestamp: '${ymd}T10:00:00Z',
            amountMl: 500.0,
          ),
        );
        created++;
      }

      if (created < targetTotalEntries) {
        _caffeineEntries.add(
          CaffeineEntry(
            id: 'ce_bulk_$created',
            date: ymd,
            timestamp: '${ymd}T09:00:00Z',
            amountMg: 80.0,
            beverageName: 'Kaffee',
          ),
        );
        created++;
      }

      if (created < targetTotalEntries) {
        _weightEntries.add(
          WeightEntry(
            id: 'wt_bulk_$created',
            date: ymd,
            timestamp: '${ymd}T07:00:00Z',
            weightKg: 65.0 + ((dayOffset % 20) * 0.1),
          ),
        );
        created++;
      }

      if (created < targetTotalEntries) {
        _symptomEntries.add(
          SymptomEntry(
            id: 'sy_bulk_$created',
            date: ymd,
            timestamp: '${ymd}T18:00:00Z',
            name: symptoms[dayOffset % symptoms.length],
            intensity: (dayOffset % 8) + 1,
          ),
        );
        created++;
      }

      dayOffset++;
    }

    _rebuildIndexes();
    await save();
  }

  static String _formatYmd(DateTime dt) {
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    return '$y-$m-$d';
  }
}
