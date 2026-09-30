import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../cycle/forecast.dart';
import '../food/off_client.dart';
import '../food/off_parser.dart';
import '../history/history.dart';
import '../l10n/format.dart';
import '../l10n/strings.dart';
import '../model/cycle_records.dart';
import '../model/dataset.dart';
import '../model/entries.dart';
import '../model/enums.dart';
import '../model/food.dart';
import '../model/settings.dart';
import '../nutrition/nutrition.dart';
import '../portable/backup.dart';
import '../portable/portable_codec.dart';
import '../storage/encrypted_store.dart';
import '../util/clock.dart';
import '../util/json_reader.dart';
import '../util/local_date.dart';
import 'repository.dart';

const String appVersion = '1.0.0';

/// A validation problem in a user action, identified by a stable code.
class DomainException implements Exception {
  DomainException(this.code, [this.message = '']);
  final String code;
  final String message;
  @override
  String toString() => 'DomainException($code) $message';
}

class ImportReport {
  ImportReport({
    required this.previousCounts,
    required this.importedCounts,
    required this.warnings,
    required this.generatedIds,
    required this.importedAt,
  });

  final Map<String, int> previousCounts;
  final Map<String, int> importedCounts;
  final List<Issue> warnings;
  final int generatedIds;
  final DateTime importedAt;

  int get diaryEntries => importedCounts.entries
      .where((e) => e.key != Collection.foods.json)
      .fold(0, (s, e) => s + e.value);

  Map<String, Object?> toJson() => {
    'replaced': true,
    'imported_at': formatInstant(importedAt),
    'previous_counts': previousCounts,
    'imported_counts': importedCounts,
    'diary_entries': diaryEntries,
    'generated_ids': generatedIds,
    'warnings': [for (final w in warnings.take(200)) w.toJson()],
    'warning_count': warnings.length,
  };
}

/// A food matched locally (library food or recently logged food).
class LocalFoodHit {
  LocalFoodHit({required this.profile, this.food, this.lastEntry});

  final FoodProfile profile;

  /// The library food, if this hit is a custom food or favorite.
  final Food? food;

  /// The most recent diary entry with this food, if any.
  final FoodEntry? lastEntry;

  bool get isFavorite => food?.favorite ?? false;

  Map<String, Object?> toJson() => {
    'kind': food != null ? 'library' : 'recent',
    'food_id': food?.id,
    'favorite': isFavorite,
    'last_logged': lastEntry?.date.toIso(),
    'food': profile.toJson(),
  };
}

class FoodSearchResult {
  FoodSearchResult({
    required this.query,
    required this.page,
    required this.local,
    this.online,
    this.onlineError,
    required this.onlineEnabled,
  });

  final String query;
  final int page;
  final List<LocalFoodHit> local;
  final OffSearchPage? online;
  final FoodApiException? onlineError;
  final bool onlineEnabled;
}

class FoodLookupResult {
  FoodLookupResult({
    required this.barcode,
    required this.local,
    this.online,
    this.onlineError,
    required this.onlineEnabled,
    required this.checkDigitValid,
  });

  final String barcode;
  final List<LocalFoodHit> local;
  final OnlineFood? online;
  final FoodApiException? onlineError;
  final bool onlineEnabled;
  final bool? checkDigitValid;

  bool get found => online != null || local.isNotEmpty;
}

/// Daily maximum intensity of one symptom.
class SymptomSeries {
  SymptomSeries(this.name, this.days, this.values, this.entries);

  final String name;
  final List<LocalDate> days;
  final List<int?> values;
  final List<SymptomEntry> entries;

  int get daysWithData => values.whereType<int>().length;

  double? get averageIntensity => entries.isEmpty
      ? null
      : entries.map((e) => e.intensity).reduce((a, b) => a + b) / entries.length;

  int? get maxIntensity => entries.isEmpty
      ? null
      : entries.map((e) => e.intensity).reduce((a, b) => a > b ? a : b);
}

/// The product functions of MorphHealth. The Flutter app and the `mh`
/// maintenance process both call exactly these methods.
class MorphHealthService {
  MorphHealthService({
    required this.repo,
    required this.clock,
    required this.defaultFoodApi,
    http.Client? httpClient,
  }) : _httpClient = httpClient;

  final Repository repo;
  final Clock clock;

  /// Food database origin and User-Agent configured for this build/process.
  final FoodApiConfig defaultFoodApi;
  final http.Client? _httpClient;

  OffClient? _client;
  String? _clientKey;

  Dataset get data => repo.data;
  Settings get settings => data.settings;
  S get strings => S.of(settings.language);
  Fmt get fmt => Fmt(settings.language);
  LocalDate get today => clock.today();
  DateTime get _now => clock.nowUtc();

  // =======================================================================
  // Food database

  /// Effective configuration: user override (device state) or default.
  FoodApiConfig get foodApiConfig {
    final override = repo.device.foodApiBaseUrl;
    if (override != null && FoodApiConfig.parseBaseUrl(override) != null) {
      return FoodApiConfig(override, defaultFoodApi.userAgent);
    }
    return defaultFoodApi;
  }

  OffClient get _off {
    final config = foodApiConfig;
    final key = '${config.baseUrl}|${config.userAgent}';
    if (_client == null || _clientKey != key) {
      _client = OffClient(config, httpClient: _httpClient);
      _clientKey = key;
    }
    return _client!;
  }

  final Map<String, (DateTime, OffSearchPage)> _searchCache = {};
  final Map<String, (DateTime, OnlineFood?)> _lookupCache = {};
  static const Duration _cacheTtl = Duration(minutes: 10);

  String get _lang => settings.language.json;

  /// Searches the library and recently logged foods on this device.
  List<LocalFoodHit> searchLocalFoods(String query, {int limit = 30}) {
    final tokens = query
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
    if (tokens.isEmpty) return const [];
    bool matches(FoodProfile p) {
      final text = '${p.name} ${p.brand ?? ''} ${p.barcode ?? ''}'.toLowerCase();
      return tokens.every(text.contains);
    }

    int rank(FoodProfile p, bool favorite) {
      final name = p.name.toLowerCase();
      var r = 0;
      if (favorite) r -= 100;
      if (name.startsWith(tokens.first)) r -= 10;
      return r;
    }

    final hits = <LocalFoodHit>[];
    final seen = <String>{};
    for (final food in data.foods.values) {
      if (!matches(food.profile)) continue;
      hits.add(LocalFoodHit(profile: food.profile, food: food));
      seen.add(_foodKey(food.profile, food.id));
    }
    for (final recent in recentFoods(limit: 400)) {
      if (!matches(recent.profile)) continue;
      final key = _foodKey(recent.profile, recent.lastEntry?.foodRef);
      if (seen.contains(key)) continue;
      seen.add(key);
      hits.add(recent);
    }
    hits.sort(
      (a, b) => rank(a.profile, a.isFavorite).compareTo(rank(b.profile, b.isFavorite)),
    );
    return hits.take(limit).toList();
  }

  String _foodKey(FoodProfile p, String? ref) {
    if (ref != null && data.foods.containsKey(ref)) return 'id:$ref';
    if (p.barcode != null) return 'ean:${p.barcode}';
    return 'name:${p.name.toLowerCase()}|${(p.brand ?? '').toLowerCase()}';
  }

  int _recentVersion = -1;
  List<LocalFoodHit> _recentCache = const [];

  /// Distinct foods from the diary, most recently logged first.
  List<LocalFoodHit> recentFoods({int limit = 50}) {
    if (_recentVersion != data.version) {
      final entries = data.foodEntries.values.toList()
        ..sort((a, b) {
          final c = b.date.compareTo(a.date);
          if (c != 0) return c;
          return b.updatedAt.compareTo(a.updatedAt);
        });
      final seen = <String>{};
      final result = <LocalFoodHit>[];
      for (final e in entries) {
        final key = _foodKey(e.food, e.foodRef);
        if (!seen.add(key)) continue;
        final libraryFood = e.foodRef == null ? null : data.foods[e.foodRef];
        result.add(
          LocalFoodHit(
            profile: libraryFood?.profile ?? e.food,
            food: libraryFood,
            lastEntry: e,
          ),
        );
        if (result.length >= 400) break;
      }
      _recentCache = result;
      _recentVersion = data.version;
    }
    return _recentCache.take(limit).toList();
  }

  List<Food> favoriteFoods() =>
      data.foods.values.where((f) => f.favorite).toList()
        ..sort((a, b) => a.profile.name.toLowerCase().compareTo(b.profile.name.toLowerCase()));

  List<Food> customFoods() =>
      data.foods.values.where((f) => f.isCustom).toList()
        ..sort((a, b) => a.profile.name.toLowerCase().compareTo(b.profile.name.toLowerCase()));

  /// The implemented food search: local matches (first page only) plus the
  /// online database when enabled.
  Future<FoodSearchResult> searchFood(String query, int page) async {
    final q = query.trim();
    if (q.isEmpty) throw DomainException('invalid_query', 'q must not be empty');
    if (q.length > 200) throw DomainException('invalid_query', 'q is too long');
    if (page < 1 || page > 1000) {
      throw DomainException('invalid_page', 'page must be between 1 and 1000');
    }
    final local = page == 1 ? searchLocalFoods(q) : <LocalFoodHit>[];
    if (!settings.onlineFoodSearch) {
      return FoodSearchResult(
        query: q,
        page: page,
        local: local,
        onlineEnabled: false,
      );
    }
    try {
      final online = await searchOnline(q, page);
      return FoodSearchResult(
        query: q,
        page: page,
        local: local,
        online: online,
        onlineEnabled: true,
      );
    } on FoodApiException catch (e) {
      return FoodSearchResult(
        query: q,
        page: page,
        local: local,
        onlineError: e,
        onlineEnabled: true,
      );
    }
  }

  /// Online search only (throws [FoodApiException]).
  Future<OffSearchPage> searchOnline(String query, int page) async {
    if (!settings.onlineFoodSearch) {
      throw DomainException('online_disabled');
    }
    final key = '${foodApiConfig.baseUrl}|$_lang|$page|${query.toLowerCase()}';
    final cached = _searchCache[key];
    if (cached != null && _now.difference(cached.$1) < _cacheTtl) return cached.$2;
    final result = await _off.search(query, page, language: _lang);
    if (_searchCache.length > 50) _searchCache.clear();
    _searchCache[key] = (_now, result);
    return result;
  }

  /// The implemented product lookup by barcode: local foods with this
  /// barcode plus the online product (when enabled).
  Future<FoodLookupResult> lookupBarcode(String input) async {
    final code = Gtin.sanitize(input);
    if (code == null || code.length > 14 || code.length < 4) {
      throw DomainException(
        'invalid_barcode',
        'barcode must consist of 4 to 14 digits',
      );
    }
    final local = [
      for (final f in data.foods.values)
        if (f.profile.barcode == code) LocalFoodHit(profile: f.profile, food: f),
    ];
    final check = Gtin.hasValidCheckDigit(code);
    if (!settings.onlineFoodSearch) {
      return FoodLookupResult(
        barcode: code,
        local: local,
        onlineEnabled: false,
        checkDigitValid: check,
      );
    }
    try {
      final online = await fetchProduct(code);
      return FoodLookupResult(
        barcode: code,
        local: local,
        online: online,
        onlineEnabled: true,
        checkDigitValid: check,
      );
    } on FoodApiException catch (e) {
      return FoodLookupResult(
        barcode: code,
        local: local,
        onlineError: e,
        onlineEnabled: true,
        checkDigitValid: check,
      );
    }
  }

  /// Fetches full product data (v3.6 nutrition schema); throws
  /// [FoodApiException] on connection problems, returns null if unknown.
  Future<OnlineFood?> fetchProduct(String barcode) async {
    if (!settings.onlineFoodSearch) throw DomainException('online_disabled');
    final key = '${foodApiConfig.baseUrl}|$_lang|$barcode';
    final cached = _lookupCache[key];
    if (cached != null && _now.difference(cached.$1) < _cacheTtl) return cached.$2;
    final result = await _off.lookup(barcode, language: _lang);
    if (_lookupCache.length > 100) _lookupCache.clear();
    _lookupCache[key] = (_now, result.food);
    return result.food;
  }

  // =======================================================================
  // Nutrition diary

  DayNutrition nutritionDay(LocalDate date) => buildDayNutrition(data, date);

  DailySeries nutritionTrend(String metric, LocalDate end, int days) =>
      nutritionSeries(data, metric, end, days);

  Future<FoodEntry> addFoodEntry({
    required LocalDate date,
    required int? time,
    required Meal meal,
    required double amount,
    required AmountUnit unit,
    required FoodProfile food,
    String? foodRef,
    String? note,
  }) async {
    _checkAmount(food, amount, unit);
    final entry = FoodEntry.create(
      date: date,
      time: time,
      meal: meal,
      amount: amount,
      unit: unit,
      food: food,
      foodRef: foodRef,
      note: note,
      now: _now,
    );
    await repo.put(Collection.foodEntries, entry);
    return entry;
  }

  Future<void> updateFoodEntry(FoodEntry entry) async {
    _checkAmount(entry.food, entry.amount, entry.unit);
    await repo.put(Collection.foodEntries, entry);
  }

  void _checkAmount(FoodProfile food, double amount, AmountUnit unit) {
    final max = unit == AmountUnit.portion
        ? FoodEntry.maxPortions
        : FoodEntry.maxAmountGramOrMl;
    if (amount <= 0 || amount > max || amount.isNaN) {
      throw DomainException('invalid_amount');
    }
    if (unit == AmountUnit.portion && !food.hasServing) {
      throw DomainException('portion_needs_serving');
    }
  }

  /// Logs an existing entry again ("erneut erfassen").
  Future<FoodEntry> relogEntry(
    FoodEntry entry, {
    required LocalDate date,
    required int? time,
    Meal? meal,
  }) {
    return addFoodEntry(
      date: date,
      time: time,
      meal: meal ?? entry.meal,
      amount: entry.amount,
      unit: entry.unit,
      food: entry.food,
      foodRef: entry.foodRef,
      note: entry.note,
    );
  }

  Future<void> deleteRecord(Collection collection, String id) =>
      repo.delete(collection, id);

  /// Restores a deleted record (undo).
  Future<void> restoreRecord(Collection collection, Record record) =>
      repo.put(collection, record);

  Future<WaterEntry> addWater(LocalDate date, double ml, {int? time}) async {
    if (ml <= 0 || ml > WaterEntry.maxMl) throw DomainException('invalid_amount');
    final entry = WaterEntry.create(date, time ?? clock.minutesOfDay(), ml, _now);
    await repo.put(Collection.waterEntries, entry);
    return entry;
  }

  Future<void> updateWater(WaterEntry entry) async {
    if (entry.amountMl <= 0 || entry.amountMl > WaterEntry.maxMl) {
      throw DomainException('invalid_amount');
    }
    await repo.put(Collection.waterEntries, entry);
  }

  Future<CaffeineEntry> addCaffeine(
    LocalDate date,
    double mg, {
    int? time,
    String? label,
  }) async {
    if (mg <= 0 || mg > CaffeineEntry.maxMg) throw DomainException('invalid_amount');
    final entry = CaffeineEntry.create(
      date,
      time ?? clock.minutesOfDay(),
      mg,
      label,
      _now,
    );
    await repo.put(Collection.caffeineEntries, entry);
    return entry;
  }

  Future<void> updateCaffeine(CaffeineEntry entry) async {
    if (entry.amountMg <= 0 || entry.amountMg > CaffeineEntry.maxMg) {
      throw DomainException('invalid_amount');
    }
    await repo.put(Collection.caffeineEntries, entry);
  }

  /// Number of diary entries created from library food [foodId].
  int entriesUsingFood(String foodId) =>
      data.foodEntries.values.where((e) => e.foodRef == foodId).length;

  /// Creates or updates a library food. With [updateEntries] every diary
  /// entry created from this food receives the new nutrition data.
  Future<Food> saveFood(Food food, {bool updateEntries = false}) async {
    final changes = <Change>[PutChange(Collection.foods, food)];
    if (updateEntries) {
      for (final e in data.foodEntries.values) {
        if (e.foodRef != food.id) continue;
        var unit = e.unit;
        var amount = e.amount;
        if (unit == AmountUnit.portion && !food.profile.hasServing) {
          // Keep the logged quantity if the portion definition was removed.
          final q = e.quantity ?? e.amount;
          unit = food.profile.basis == Basis.g ? AmountUnit.g : AmountUnit.ml;
          amount = q;
        }
        changes.add(
          PutChange(
            Collection.foodEntries,
            e.copyWith(food: food.profile, unit: unit, amount: amount, updatedAt: _now),
          ),
        );
      }
    }
    await repo.batch(changes);
    return food;
  }

  Future<Food> createCustomFood(FoodProfile profile, {bool favorite = false}) =>
      saveFood(Food.create(profile, _now, favorite: favorite));

  Future<void> deleteFood(String foodId) => repo.delete(Collection.foods, foodId);

  /// Library food with the given barcode or identity, if saved.
  Food? libraryFoodFor(FoodProfile profile, {String? foodRef}) {
    if (foodRef != null && data.foods.containsKey(foodRef)) return data.foods[foodRef];
    if (profile.barcode != null) {
      for (final f in data.foods.values) {
        if (f.profile.barcode == profile.barcode &&
            f.profile.source == profile.source) {
          return f;
        }
      }
    }
    return null;
  }

  /// Marks a food as favorite (saving online products in the library) or
  /// removes the mark. Returns the library food, or null if it was removed.
  Future<Food?> setFavorite(
    FoodProfile profile,
    bool favorite, {
    String? foodRef,
  }) async {
    final existing = libraryFoodFor(profile, foodRef: foodRef);
    if (existing != null) {
      if (!favorite && !existing.isCustom) {
        await repo.delete(Collection.foods, existing.id);
        return null;
      }
      final updated = existing.copyWith(favorite: favorite, updatedAt: _now);
      await repo.put(Collection.foods, updated);
      return updated;
    }
    if (!favorite) return null;
    final food = Food.create(profile, _now, favorite: true);
    await repo.put(Collection.foods, food);
    return food;
  }

  // =======================================================================
  // Cycle

  CycleForecast cycleForecast(LocalDate on) => const CycleForecaster().forecast(
    data.periodsSorted,
    on,
    predictionsEnabled: settings.cyclePredictions,
  );

  /// Validates [period] against the other periods; throws [DomainException].
  void validatePeriod(Period period) {
    if (period.start.isAfter(today)) {
      throw DomainException('period_start_in_future');
    }
    final end = period.end;
    if (end != null) {
      if (end.isBefore(period.start)) throw DomainException('period_end_before_start');
      if (period.start.daysUntil(end) + 1 > Period.maxLengthDays) {
        throw DomainException('period_too_long');
      }
    }
    for (final other in data.periods.values) {
      if (other.id == period.id) continue;
      final otherEnd = other.end ?? LocalDate.max;
      final thisEnd = end ?? LocalDate.max;
      final overlaps =
          !period.start.isAfter(otherEnd) && !other.start.isAfter(thisEnd);
      if (overlaps) throw DomainException('period_overlap');
      if (end == null && other.start.isAfter(period.start)) {
        throw DomainException('only_latest_ongoing');
      }
    }
  }

  Future<void> savePeriod(Period period) async {
    validatePeriod(period);
    await repo.put(Collection.periods, period);
  }

  /// Starts a new period on [day] (e.g. "period started today").
  Future<Period> startPeriod(LocalDate day, {LocalDate? end, String? note}) async {
    // Close an older ongoing period the day before, if any.
    final changes = <Change>[];
    for (final p in data.periods.values) {
      if (p.end == null && p.start.isBefore(day)) {
        final closeOn = day.addDays(-1);
        final lastDay = p.start.daysUntil(closeOn) + 1 > Period.maxLengthDays
            ? p.start.addDays(Period.maxLengthDays - 1)
            : closeOn;
        changes.add(PutChange(Collection.periods, p.copyWith(end: () => lastDay, updatedAt: _now)));
      }
    }
    final period = Period.create(start: day, end: end, note: note, now: _now);
    // Validate against the state after closing older periods.
    final closedIds = {for (final c in changes) (c as PutChange).record.id};
    for (final other in data.periods.values) {
      if (closedIds.contains(other.id)) continue;
      final otherEnd = other.end ?? LocalDate.max;
      final thisEnd = end ?? LocalDate.max;
      if (!day.isAfter(otherEnd) && !other.start.isAfter(thisEnd)) {
        throw DomainException('period_overlap');
      }
      if (end == null && other.start.isAfter(day)) {
        throw DomainException('only_latest_ongoing');
      }
    }
    if (day.isAfter(today)) throw DomainException('period_start_in_future');
    changes.add(PutChange(Collection.periods, period));
    await repo.batch(changes);
    return period;
  }

  Future<void> endPeriod(Period period, LocalDate lastDay) =>
      savePeriod(period.copyWith(end: () => lastDay, updatedAt: _now));

  /// Deletes a period and the bleeding intensities recorded on its days
  /// (notes on those days are kept).
  Future<void> deletePeriod(Period period) async {
    final end = period.end ?? today;
    final changes = <Change>[DeleteChange(Collection.periods, period.id)];
    for (final d in data.cycleDays.values) {
      if (!d.date.isWithin(period.start, end) || d.flow == null) continue;
      if (d.note == null || d.note!.isEmpty) {
        changes.add(DeleteChange(Collection.cycleDays, d.id));
      } else {
        changes.add(PutChange(Collection.cycleDays, d.copyWith(flow: () => null, updatedAt: _now)));
      }
    }
    await repo.batch(changes);
  }

  /// Sets (or clears) bleeding intensity and note for a day.
  Future<void> setCycleDay(LocalDate date, {Flow? flow, String? note}) async {
    final existing = data.cycleDayOn(date);
    final cleanNote = note == null || note.trim().isEmpty ? null : note.trim();
    if (flow == null && cleanNote == null) {
      if (existing != null) await repo.delete(Collection.cycleDays, existing.id);
      return;
    }
    final record = existing == null
        ? CycleDay.create(date: date, flow: flow, note: cleanNote, now: _now)
        : existing.copyWith(flow: () => flow, note: () => cleanNote, updatedAt: _now);
    await repo.put(Collection.cycleDays, record);
  }

  /// The period that ends the day before [day] (candidate for extension).
  Period? periodEndingBefore(LocalDate day) {
    for (final p in data.periods.values) {
      if (p.end != null && p.end!.addDays(1) == day) return p;
    }
    return null;
  }

  // =======================================================================
  // Weight & symptoms

  Future<void> saveWeight(WeightEntry entry) async {
    final kg = entry.kg;
    if (kg < WeightEntry.minKg || kg > WeightEntry.maxKg) {
      throw DomainException('invalid_weight');
    }
    await repo.put(Collection.weightEntries, entry);
  }

  Future<void> saveSymptom(SymptomEntry entry) async {
    if (entry.name.trim().isEmpty ||
        entry.name.length > SymptomEntry.maxNameLength ||
        entry.intensity < 0 ||
        entry.intensity > 10) {
      throw DomainException('invalid_symptom');
    }
    await repo.put(Collection.symptomEntries, entry);
  }

  /// Distinct symptom names, most frequently used first.
  List<String> knownSymptomNames() {
    final counts = <String, int>{};
    final display = <String, String>{};
    final latest = <String, DateTime>{};
    for (final e in data.symptomEntries.values) {
      final key = e.nameKey;
      counts[key] = (counts[key] ?? 0) + 1;
      if (latest[key] == null || e.updatedAt.isAfter(latest[key]!)) {
        latest[key] = e.updatedAt;
        display[key] = e.name.trim();
      }
    }
    final keys = counts.keys.toList()
      ..sort((a, b) {
        final c = counts[b]!.compareTo(counts[a]!);
        return c != 0 ? c : a.compareTo(b);
      });
    return [for (final k in keys) display[k]!];
  }

  SymptomSeries symptomSeries(String name, LocalDate end, int dayCount) {
    final key = normalizeSymptomName(name);
    final days = [for (var i = dayCount - 1; i >= 0; i--) end.addDays(-i)];
    final values = <int?>[];
    final entries = <SymptomEntry>[];
    for (final day in days) {
      int? max;
      for (final e in data.symptomsOn(day)) {
        if (e.nameKey != key) continue;
        entries.add(e);
        if (max == null || e.intensity > max) max = e.intensity;
      }
      values.add(max);
    }
    return SymptomSeries(name, days, values, entries);
  }

  /// All entries of a symptom, newest first.
  List<SymptomEntry> symptomEntriesNamed(String name) {
    final key = normalizeSymptomName(name);
    return data.symptomEntries.values.where((e) => e.nameKey == key).toList()
      ..sort((a, b) => compareDated(b, a));
  }

  // =======================================================================
  // History

  HistoryIndex? _history;

  HistoryIndex historyIndex() {
    final current = _history;
    if (current != null &&
        current.version == data.version &&
        current.language == settings.language) {
      return current;
    }
    return _history = HistoryIndex.build(data, strings, fmt, today);
  }

  // =======================================================================
  // Settings

  Future<void> updateSettings(Settings settings) => repo.updateSettings(settings);

  Future<void> updateDevice(DeviceState device) => repo.updateDevice(device);

  // =======================================================================
  // Export, import, backup

  Map<String, Object?> exportDocument() =>
      encodePortable(data, exportedAt: _now, appVersion: appVersion);

  /// Validates [document] and replaces the whole data set with it.
  Future<ImportReport> importDocument(Object? document) =>
      importDecoded(decodePortable(document, now: _now));

  /// Replaces the data set with an already validated document (the app
  /// validates large documents in a background isolate).
  Future<ImportReport> importDecoded(DecodedPortable decoded) async {
    final previous = data.counts();
    await repo.replaceAll(decoded.dataset);
    return ImportReport(
      previousCounts: previous,
      importedCounts: data.counts(),
      warnings: decoded.warnings,
      generatedIds: decoded.generatedIds,
      importedAt: _now,
    );
  }

  Future<Uint8List> createBackupFile(String passphrase) {
    if (passphrase.length < BackupFormat.minPassphraseLength) {
      throw DomainException('passphrase_too_short');
    }
    return createBackup(exportDocument(), passphrase, now: _now);
  }

  Future<ImportReport> restoreBackupFile(List<int> bytes, String passphrase) async {
    final document = await openBackup(bytes, passphrase);
    return importDocument(document);
  }
}
