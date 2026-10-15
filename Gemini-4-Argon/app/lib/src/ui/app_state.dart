import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../core/cycle_engine.dart';
import '../core/models.dart';
import '../core/nutrition_engine.dart';
import '../core/off_client.dart';
import '../core/repository.dart';
import 'i18n.dart';

class MorphHealthController extends ChangeNotifier {
  static const MethodChannel _platformChannel =
      MethodChannel('de.themorpheus.morphhealth.local/platform');

  late final MorphHealthRepository repository;
  late OpenFoodFactsClient offClient;
  late final String exportsDirPath;

  bool _initialized = false;
  String? _initError;
  String _selectedDate = '';
  int _selectedTrendDays = 7; // 7 or 28
  String _selectedNutrientKey = 'calories_kcal';
  String? _selectedSymptomForTrend;

  String _foodApiBaseUrl = 'https://localhost:8788';
  String _foodApiUserAgent = 'MorphHealth/1.0-rc3 (benchmark build)';

  MorphHealthController();

  bool get isInitialized => _initialized;
  String? get initError => _initError;
  String get selectedDate => _selectedDate;
  int get selectedTrendDays => _selectedTrendDays;
  String get selectedNutrientKey => _selectedNutrientKey;
  String? get selectedSymptomForTrend => _selectedSymptomForTrend;
  String get foodApiBaseUrl => _foodApiBaseUrl;
  String get foodApiUserAgent => _foodApiUserAgent;

  UserSettings get settings => repository.settings;
  String get lang => settings.language;
  AppStrings get s => AppStrings(lang);

  Future<void> init({
    String? overrideDataDir,
    String? overrideKeyFile,
    DateTime Function()? clock,
  }) async {
    try {
      final defaults = OpenFoodFactsClient.loadDefaultConfig();
      _foodApiBaseUrl = defaults.baseUrl;
      _foodApiUserAgent = defaults.userAgent;

      String dataDir;
      String keyFile;
      String exportsDir;

      if (overrideDataDir != null && overrideKeyFile != null) {
        dataDir = overrideDataDir;
        keyFile = overrideKeyFile;
        exportsDir = '$overrideDataDir/../exports';
      } else {
        try {
          final res = await _platformChannel
              .invokeMapMethod<String, String>('getPaths');
          if (res != null &&
              res['dataDir'] != null &&
              res['keyFile'] != null) {
            dataDir = res['dataDir']!;
            keyFile = res['keyFile']!;
            exportsDir = res['exportsDir'] ?? '${res['dataDir']!}_exports';
          } else {
            throw Exception('Empty paths from platform channel');
          }
        } catch (_) {
          // Fallback for widget tests or desktop execution
          final base = Directory.systemTemp.createTempSync('morphhealth_app_');
          dataDir = '${base.path}/data';
          keyFile = '${base.path}/master.key';
          exportsDir = '${base.path}/exports';
        }
      }

      exportsDirPath = exportsDir;
      Directory(exportsDirPath).createSync(recursive: true);

      repository = MorphHealthRepository(
        dataDirPath: dataDir,
        keyFilePath: keyFile,
        clock: clock,
      );
      await repository.initialize(createKeyIfMissing: true);

      offClient = OpenFoodFactsClient(
        baseUrl: _foodApiBaseUrl,
        userAgent: _foodApiUserAgent,
        nowIsoProvider: () => repository.nowIso,
      );

      _selectedDate = repository.todayYmd;
      final symptoms = repository.distinctSymptomNames;
      if (symptoms.isNotEmpty) {
        _selectedSymptomForTrend = symptoms.first;
      }

      _initialized = true;
      notifyListeners();
    } catch (e) {
      _initError = e.toString();
      notifyListeners();
    }
  }

  void setSelectedDate(String ymd) {
    final clean = ymd.trim().substring(0, 10);
    if (_selectedDate != clean) {
      _selectedDate = clean;
      notifyListeners();
    }
  }

  void shiftSelectedDate(int deltaDays) {
    final dt = DateTime.parse('${_selectedDate}T00:00:00Z')
        .add(Duration(days: deltaDays));
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    setSelectedDate('$y-$m-$d');
  }

  void jumpToToday() {
    setSelectedDate(repository.todayYmd);
  }

  void setTrendDays(int days) {
    final normalized = days == 28 ? 28 : 7;
    if (_selectedTrendDays != normalized) {
      _selectedTrendDays = normalized;
      notifyListeners();
    }
  }

  void setSelectedNutrientKey(String key) {
    if (_selectedNutrientKey != key) {
      _selectedNutrientKey = key;
      notifyListeners();
    }
  }

  void setSelectedSymptomForTrend(String? symptom) {
    if (_selectedSymptomForTrend != symptom) {
      _selectedSymptomForTrend = symptom;
      notifyListeners();
    }
  }

  void updateFoodApiBaseUrl(String newUrl) {
    final clean = newUrl.trim();
    if (clean.isNotEmpty && clean != _foodApiBaseUrl) {
      _foodApiBaseUrl = clean;
      offClient = OpenFoodFactsClient(
        baseUrl: _foodApiBaseUrl,
        userAgent: _foodApiUserAgent,
        nowIsoProvider: () => repository.nowIso,
      );
      notifyListeners();
    }
  }

  // Computed properties for selectedDate
  NutritionDaySummary get currentDayNutrition =>
      repository.getNutritionDay(_selectedDate);

  CycleForecastResult get currentCycleForecast =>
      repository.getCycleForecast(_selectedDate);

  List<PeriodEntry> get selectedDayPeriods =>
      repository.periodsForDate(_selectedDate);

  List<WeightEntry> get selectedDayWeights =>
      repository.weightsForDate(_selectedDate);

  WeightEntry? get latestWeight =>
      repository.latestWeightOnOrBefore(_selectedDate);

  List<SymptomEntry> get selectedDaySymptoms =>
      repository.symptomsForDate(_selectedDate);

  // Settings mutations
  Future<void> updateSettings(UserSettings next) async {
    await repository.updateSettings(next);
    notifyListeners();
  }

  Future<void> setLanguage(String language) async {
    await updateSettings(
      settings.copyWith(language: language == 'en' ? 'en' : 'de'),
    );
  }

  Future<void> setWeightUnit(String unit) async {
    await updateSettings(
      settings.copyWith(weightUnit: unit == 'lb' ? 'lb' : 'kg'),
    );
  }

  // Nutrition mutations
  Future<FoodItem> saveCustomFood(FoodItem item) async {
    final saved = await repository.saveCustomFood(item);
    notifyListeners();
    return saved;
  }

  Future<void> deleteCustomFood(String id) async {
    await repository.deleteCustomFood(id);
    notifyListeners();
  }

  Future<bool> toggleFavoriteFood(FoodItem item) async {
    final res = await repository.toggleFavoriteFood(item);
    notifyListeners();
    return res;
  }

  Future<void> saveFoodEntry(FoodDiaryEntry entry) async {
    await repository.upsertFoodEntry(entry);
    notifyListeners();
  }

  Future<void> relogFoodEntry(
    FoodDiaryEntry source, {
    String? targetDate,
    String? targetMeal,
  }) async {
    await repository.relogFoodEntry(
      source,
      targetDate: targetDate ?? _selectedDate,
      targetMeal: targetMeal,
    );
    notifyListeners();
  }

  Future<void> deleteFoodEntry(String id) async {
    await repository.deleteFoodEntry(id);
    notifyListeners();
  }

  Future<void> quickAddWater(double amountMl, {String? notes}) async {
    await repository.quickAddWater(
      date: _selectedDate,
      amountMl: amountMl,
      notes: notes,
    );
    notifyListeners();
  }

  Future<void> saveWaterEntry(WaterEntry entry) async {
    await repository.upsertWaterEntry(entry);
    notifyListeners();
  }

  Future<void> deleteWaterEntry(String id) async {
    await repository.deleteWaterEntry(id);
    notifyListeners();
  }

  Future<void> saveCaffeineEntry(CaffeineEntry entry) async {
    await repository.upsertCaffeineEntry(entry);
    notifyListeners();
  }

  Future<void> deleteCaffeineEntry(String id) async {
    await repository.deleteCaffeineEntry(id);
    notifyListeners();
  }

  // Cycle mutations
  Future<void> savePeriodEntry(PeriodEntry entry) async {
    await repository.upsertPeriodEntry(entry);
    notifyListeners();
  }

  Future<void> deletePeriodEntry(String id) async {
    await repository.deletePeriodEntry(id);
    notifyListeners();
  }

  // Weight mutations
  Future<void> saveWeightEntry(WeightEntry entry) async {
    await repository.upsertWeightEntry(entry);
    notifyListeners();
  }

  Future<void> deleteWeightEntry(String id) async {
    await repository.deleteWeightEntry(id);
    notifyListeners();
  }

  // Symptom mutations
  Future<void> saveSymptomEntry(SymptomEntry entry) async {
    await repository.upsertSymptomEntry(entry);
    _selectedSymptomForTrend ??= entry.name;
    notifyListeners();
  }

  Future<void> deleteSymptomEntry(String id) async {
    await repository.deleteSymptomEntry(id);
    notifyListeners();
  }

  // Portability & Backups
  Future<String?> saveWithAndroidDocumentPicker({
    required String suggestedName,
    required String mimeType,
    required String content,
  }) async {
    try {
      final uri = await _platformChannel.invokeMethod<String>(
        'saveDocument',
        {
          'suggestedName': suggestedName,
          'mimeType': mimeType,
          'content': content,
        },
      );
      return uri;
    } catch (_) {
      return null;
    }
  }

  Future<String?> openWithAndroidDocumentPicker() async {
    try {
      final content =
          await _platformChannel.invokeMethod<String>('openDocument');
      return content;
    } catch (_) {
      return null;
    }
  }

  Future<File> saveLocalExportFile(String fileName, String content) async {
    final file = File('$exportsDirPath/$fileName');
    await file.writeAsString(content, flush: true);
    return file;
  }

  List<File> listLocalExportFiles() {
    final dir = Directory(exportsDirPath);
    if (!dir.existsSync()) return const [];
    final files = dir.listSync().whereType<File>().toList()
      ..sort((a, b) => b.path.compareTo(a.path));
    return files;
  }

  Future<Map<String, dynamic>> importPortableJsonString(
    String jsonStr, {
    required bool confirmReplace,
  }) async {
    final decoded = jsonDecode(jsonStr);
    if (decoded is! Map) {
      throw const FormatException('Root JSON must be an object.');
    }
    final res = await repository.importPortableDocument(
      document: Map<String, dynamic>.from(decoded),
      confirmReplace: confirmReplace,
    );
    final symptoms = repository.distinctSymptomNames;
    _selectedSymptomForTrend = symptoms.isNotEmpty ? symptoms.first : null;
    notifyListeners();
    return res;
  }

  Future<String> createEncryptedBackupJsonString(String passphrase) async {
    final env = await repository.createEncryptedBackup(passphrase);
    return const JsonEncoder.withIndent('  ').convert(env);
  }

  Future<Map<String, dynamic>> restoreEncryptedBackupJsonString(
    String jsonStr,
    String passphrase,
  ) async {
    final decoded = jsonDecode(jsonStr);
    if (decoded is! Map) {
      throw const FormatException('Encrypted backup must be a JSON object.');
    }
    final res = await repository.restoreEncryptedBackup(
      backupEnvelope: Map<String, dynamic>.from(decoded),
      passphrase: passphrase,
    );
    final symptoms = repository.distinctSymptomNames;
    _selectedSymptomForTrend = symptoms.isNotEmpty ? symptoms.first : null;
    notifyListeners();
    return res;
  }

  Future<void> loadSampleDataset() async {
    final sample = MorphHealthRepository.buildExamplePortableDocument(
      referenceDate: _selectedDate,
    );
    await repository.importPortableDocument(
      document: sample,
      confirmReplace: true,
    );
    final symptoms = repository.distinctSymptomNames;
    _selectedSymptomForTrend = symptoms.isNotEmpty ? symptoms.first : null;
    notifyListeners();
  }

  Future<void> generateBulk10kDataset() async {
    await repository.generateBulkDataset(targetTotalEntries: 10000);
    final symptoms = repository.distinctSymptomNames;
    _selectedSymptomForTrend = symptoms.isNotEmpty ? symptoms.first : null;
    notifyListeners();
  }

  Future<void> deleteAllData() async {
    await repository.deleteAllData();
    _selectedSymptomForTrend = null;
    notifyListeners();
  }
}
