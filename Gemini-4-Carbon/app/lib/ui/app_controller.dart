/// Central reactive application controller coordinating encrypted store,
/// Open Food Facts client, selected date, and platform file/keystore actions.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../core/clock.dart';
import '../core/crypto_vault.dart';
import '../core/models.dart';
import '../core/open_food_facts_client.dart';
import '../core/store.dart';
import 'l10n.dart';
import 'platform_bridge.dart';

class AppController extends ChangeNotifier {
  static const String envFoodBaseUrl = String.fromEnvironment(
    'FOOD_API_BASE_URL',
    defaultValue: OpenFoodFactsClient.defaultProductionBaseUrl,
  );
  static const String envFoodUserAgent = String.fromEnvironment(
    'FOOD_API_USER_AGENT',
    defaultValue: OpenFoodFactsClient.defaultUserAgent,
  );

  final MorphHealthStore store;
  final PlatformBridge platformBridge;
  OpenFoodFactsClient _foodClient;
  String _selectedDate;
  int _activeNavIndex = 0;

  AppController({
    required this.store,
    required this.platformBridge,
    OpenFoodFactsClient? foodClient,
    String? initialDate,
  })  : _selectedDate = initialDate ?? store.clock.todayIso(),
        _foodClient = foodClient ??
            OpenFoodFactsClient(
              baseUrl: _effectiveBaseUrl(store.preferences),
              userAgent: envFoodUserAgent,
              clock: store.clock,
            );

  static String _effectiveBaseUrl(UserPreferences prefs) {
    final custom = prefs.customFoodApiBaseUrl?.trim();
    if (custom != null && custom.isNotEmpty) return custom;
    return envFoodBaseUrl;
  }

  String get selectedDate => _selectedDate;
  String get todayDate => store.clock.todayIso();
  bool get isOnToday => _selectedDate == todayDate;
  int get activeNavIndex => _activeNavIndex;

  String get localeCode => store.preferences.localeCode;
  MhStrings get strings => MhStrings(localeCode);
  UserPreferences get preferences => store.preferences;
  NutritionGoals get goals => store.goals;
  OpenFoodFactsClient get foodClient => _foodClient;
  String get activeFoodBaseUrl => _foodClient.baseUrl;

  void setNavIndex(int index) {
    if (_activeNavIndex == index) return;
    _activeNavIndex = index;
    notifyListeners();
  }

  void setSelectedDate(String dateIso) {
    if (!IsoDate.isValid(dateIso) || _selectedDate == dateIso) return;
    _selectedDate = dateIso;
    notifyListeners();
  }

  void stepSelectedDate(int deltaDays) {
    _selectedDate = IsoDate.addDays(_selectedDate, deltaDays);
    notifyListeners();
  }

  void jumpToToday() {
    setSelectedDate(todayDate);
  }

  String defaultTimestampForSelectedDate() {
    if (_selectedDate == todayDate) {
      return store.clock.nowRfc3339();
    }
    final hm = IsoDate.extractTimeHm(store.clock.nowRfc3339());
    return IsoDate.combineDateAndHm(_selectedDate, hm);
  }

  Future<void> updatePreferences(UserPreferences next) async {
    final prevUrl = _effectiveBaseUrl(store.preferences);
    final nextUrl = _effectiveBaseUrl(next);
    if (prevUrl != nextUrl) {
      final newClient = OpenFoodFactsClient(
        baseUrl: nextUrl,
        userAgent: envFoodUserAgent,
        clock: store.clock,
      );
      _foodClient.close();
      _foodClient = newClient;
    }
    await store.updatePreferences(next);
    notifyListeners();
  }

  Future<void> toggleOverviewModule(AppModule module) async {
    final current = List<AppModule>.from(store.preferences.visibleOverviewModules);
    if (current.contains(module)) {
      current.remove(module);
    } else {
      // Preserve canonical module order
      current.add(module);
      current.sort((a, b) => a.index.compareTo(b.index));
    }
    await updatePreferences(
      store.preferences.copyWith(visibleOverviewModules: current),
    );
  }

  Future<void> updateGoals(NutritionGoals next) async {
    await store.updateGoals(next);
    notifyListeners();
  }

  // --- Nutrition mutations ---

  Future<FoodItem> saveCustomFood(FoodItem item) async {
    final saved = await store.saveFoodExact(item);
    notifyListeners();
    return saved;
  }

  Future<void> deleteCustomFood(String foodId) async {
    await store.deleteCustomFood(foodId);
    notifyListeners();
  }

  Future<FoodItem> toggleFavoriteFood(FoodItem item) async {
    final toggled = await store.toggleFavoriteFood(item);
    notifyListeners();
    return toggled;
  }

  Future<FoodDiaryEntry> saveMealEntry(
    FoodDiaryEntry entry, {
    FoodItem? foodToPersist,
  }) async {
    final saved = await store.upsertMealEntry(
      entry,
      ensureFoodInCatalog: foodToPersist,
    );
    notifyListeners();
    return saved;
  }

  Future<FoodDiaryEntry> relogMealEntry(
    FoodDiaryEntry source, {
    String? targetDate,
    MealType? targetMealType,
  }) async {
    final d = targetDate ?? _selectedDate;
    final recordedAt = d == todayDate
        ? store.clock.nowRfc3339()
        : IsoDate.combineDateAndHm(d, IsoDate.extractTimeHm(source.recordedAt));
    final clone = FoodDiaryEntry(
      id: generateEntityId('meal'),
      date: d,
      recordedAt: recordedAt,
      mealType: targetMealType ?? source.mealType,
      foodId: source.foodId,
      foodNameSnapshot: source.foodNameSnapshot,
      brandSnapshot: source.brandSnapshot,
      amount: source.amount,
      unit: source.unit,
      servingQuantitySnapshot: source.servingQuantitySnapshot,
      nutrientsPer100Snapshot: source.nutrientsPer100Snapshot,
      note: source.note,
    );
    final saved = await store.upsertMealEntry(clone);
    notifyListeners();
    return saved;
  }

  Future<void> deleteMealEntry(String id) async {
    await store.deleteMealEntry(id);
    notifyListeners();
  }

  Future<WaterEntry> quickAddWater(double amountMl, {String? note}) async {
    final entry = WaterEntry(
      id: generateEntityId('water'),
      date: _selectedDate,
      recordedAt: defaultTimestampForSelectedDate(),
      amountMl: amountMl,
      note: note,
    );
    await store.upsertWaterEntry(entry);
    notifyListeners();
    return entry;
  }

  Future<WaterEntry> saveWaterEntry(WaterEntry entry) async {
    final saved = await store.upsertWaterEntry(entry);
    notifyListeners();
    return saved;
  }

  Future<void> deleteWaterEntry(String id) async {
    await store.deleteWaterEntry(id);
    notifyListeners();
  }

  Future<CaffeineEntry> quickAddCaffeine(
    double amountMg, {
    String? sourceLabel,
    String? note,
  }) async {
    final entry = CaffeineEntry(
      id: generateEntityId('caff'),
      date: _selectedDate,
      recordedAt: defaultTimestampForSelectedDate(),
      amountMg: amountMg,
      sourceLabel: sourceLabel,
      note: note,
    );
    await store.upsertCaffeineEntry(entry);
    notifyListeners();
    return entry;
  }

  Future<CaffeineEntry> saveCaffeineEntry(CaffeineEntry entry) async {
    final saved = await store.upsertCaffeineEntry(entry);
    notifyListeners();
    return saved;
  }

  Future<void> deleteCaffeineEntry(String id) async {
    await store.deleteCaffeineEntry(id);
    notifyListeners();
  }

  // --- Cycle, Weight & Symptoms mutations ---

  Future<PeriodEntry> savePeriodEntry(PeriodEntry entry) async {
    final saved = await store.upsertPeriodEntry(entry);
    notifyListeners();
    return saved;
  }

  Future<void> deletePeriodEntry(String id) async {
    await store.deletePeriodEntry(id);
    notifyListeners();
  }

  Future<WeightEntry> saveWeightEntry(WeightEntry entry) async {
    final saved = await store.upsertWeightEntry(entry);
    notifyListeners();
    return saved;
  }

  Future<void> deleteWeightEntry(String id) async {
    await store.deleteWeightEntry(id);
    notifyListeners();
  }

  Future<SymptomEntry> saveSymptomEntry(SymptomEntry entry) async {
    final saved = await store.upsertSymptomEntry(entry);
    notifyListeners();
    return saved;
  }

  Future<void> deleteSymptomEntry(String id) async {
    await store.deleteSymptomEntry(id);
    notifyListeners();
  }

  // --- Portability, Encrypted Backup & Wipe ---

  String exportPortableJsonPretty() {
    final doc = store.exportPortableDocument();
    return const JsonEncoder.withIndent('  ').convert(doc);
  }

  Future<Map<String, dynamic>> importPortableJsonText(String rawJson) async {
    final decoded = jsonDecode(rawJson);
    if (decoded is! Map<String, dynamic>) {
      throw const FormatValidationException('Imported JSON root must be an object.');
    }
    final report = await store.importPortableDocument(decoded);
    notifyListeners();
    return report;
  }

  Future<String> createEncryptedBackupString(String passphrase) async {
    return EncryptedBackupCodec.createEncryptedBackup(
      passphrase: passphrase,
      portableDocument: store.exportPortableDocument(),
      createdAtRfc3339: store.clock.nowRfc3339(),
    );
  }

  Future<Map<String, dynamic>> restoreEncryptedBackupString({
    required String passphrase,
    required String backupText,
  }) async {
    final portableDoc = await EncryptedBackupCodec.decryptEncryptedBackup(
      passphrase: passphrase,
      backupJsonText: backupText,
    );
    final report = await store.importPortableDocument(portableDoc);
    notifyListeners();
    return report;
  }

  Future<void> wipeAllLocalData() async {
    final rotatedKey = await platformBridge.rotateMasterKey();
    await store.wipeAllData(newMasterKey: rotatedKey);
    _selectedDate = store.clock.todayIso();
    notifyListeners();
  }

  @override
  void dispose() {
    _foodClient.close();
    super.dispose();
  }
}
