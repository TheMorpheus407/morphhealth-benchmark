import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:morphhealth_core/morphhealth_core.dart';

import '../services/platform_services.dart';

/// Central state of the app.
///
/// It owns the encrypted repository, the product services and the current
/// user settings, and notifies the widget tree after every change.
class AppState extends ChangeNotifier {
  AppState({
    required this.repository,
    required this.directories,
    required FoodApiClient foodClient,
    required this.strings,
  }) : _foodClient = foodClient {
    _settings = repository.settings;
    _selectedDate = DateMath.format(DateTime.now());
    locale.value = Locale(_settings.languageCode);
  }

  final HealthRepository repository;
  final AppDirectories directories;

  FoodApiClient _foodClient;

  /// Localized catalogue that matches the current language.
  Strings strings;

  late AppSettings _settings;
  late String _selectedDate;

  bool _busy = false;
  String? _lastError;

  /// The interface language, only changed when the user switches it.
  final ValueNotifier<Locale> locale = ValueNotifier<Locale>(const Locale('de'));

  AppSettings get settings => _settings;

  /// The calendar day the nutrition and cycle pages show.
  String get selectedDate => _selectedDate;

  FoodApiClient get foodClient => _foodClient;

  bool get busy => _busy;

  String? get lastError => _lastError;

  NutritionService get nutrition => NutritionService(repository);

  CycleService get cycle => CycleService(repository, strings: strings);

  WeightService get weight => WeightService(repository);

  /// The daily goals chosen by the user.
  Goals get goals => repository.goals;

  SymptomService get symptoms => SymptomService(repository);

  HistoryService get history => HistoryService(repository);

  /// Visible areas of the overview.
  Set<AppArea> get visibleAreas => _settings.visibleAreas;

  /// Opens the app on a fresh or existing encrypted store.
  static Future<AppState> bootstrap() async {
    final AppDirectories directories = await AppDirectories.resolve();
    final KeyStoreService keyStore = const KeyStoreService();
    final List<int> masterKey = await keyStore.masterKey(directories.support);
    final HealthRepository repository = await HealthRepository.open(
      directory: directories.documents,
      masterKey: masterKey,
    );
    await repository.load();
    final AppSettings settings = repository.settings;
    final FoodApiClient client = FoodApiClient(
      baseUrl: settings.foodBaseUrlOverride ?? kFoodApiBaseUrl,
      userAgent: settings.foodUserAgentOverride ?? kFoodApiUserAgent,
    );
    return AppState(
      repository: repository,
      directories: directories,
      foodClient: client,
      strings: settings.languageCode == 'en' ? Strings.en : Strings.de,
    );
  }

  /// The origin of the food service, taking the user override into account.
  String get foodBaseUrl => _settings.foodBaseUrlOverride ?? kFoodApiBaseUrl;

  String get foodUserAgent =>
      _settings.foodUserAgentOverride ?? kFoodApiUserAgent;

  /// Reloads everything from the encrypted store.
  Future<void> refresh() async {
    await repository.load();
    notifyListeners();
  }

  void setSelectedDate(String date) {
    if (_selectedDate == date) return;
    _selectedDate = date;
    notifyListeners();
  }

  /// Changes the interface language.
  Future<void> setLanguage(String languageCode) async {
    if (_settings.languageCode == languageCode) return;
    _settings = _settings.copyWith(languageCode: languageCode);
    strings = languageCode == 'en' ? Strings.en : Strings.de;
    locale.value = Locale(languageCode);
    await repository.setSettings(_settings);
    notifyListeners();
  }

  /// Changes the weight display unit.
  Future<void> setWeightUnit(WeightUnit unit) async {
    _settings = _settings.copyWith(weightUnit: unit);
    await repository.setSettings(_settings);
    notifyListeners();
  }

  /// Shows or hides an area in the overview.
  Future<void> setAreaVisible(AppArea area, bool visible) async {
    final Set<AppArea> areas = Set<AppArea>.of(_settings.visibleAreas);
    if (visible) {
      areas.add(area);
    } else {
      areas.remove(area);
    }
    _settings = _settings.copyWith(visibleAreas: areas);
    await repository.setSettings(_settings);
    notifyListeners();
  }

  /// Stores the daily goals.
  Future<void> setGoals(Goals goals) async {
    await repository.setGoals(goals);
    notifyListeners();
  }

  /// Overrides the origin of the food service.
  Future<void> setFoodService({String? baseUrl, String? userAgent}) async {
    _settings = _settings.copyWith(
      foodBaseUrlOverride: baseUrl,
      clearFoodBaseUrl: baseUrl == null || baseUrl.isEmpty,
      foodUserAgentOverride: userAgent,
      clearFoodUserAgent: userAgent == null || userAgent.isEmpty,
    );
    await repository.setSettings(_settings);
    final FoodApiClient old = _foodClient;
    _foodClient = FoodApiClient(
      baseUrl: foodBaseUrl,
      userAgent: foodUserAgent,
    );
    old.close();
    notifyListeners();
  }

  // ------------------------------------------------------------- mutations

  Future<void> upsertFood(FoodItem food) =>
      _mutate(() => repository.upsertFood(food));

  Future<void> deleteFood(String id) => _mutate(() => repository.deleteFood(id));

  Future<void> upsertJournalEntry(JournalEntry entry) =>
      _mutate(() => repository.upsertJournalEntry(entry));

  Future<void> deleteJournalEntry(String id) =>
      _mutate(() => repository.deleteJournalEntry(id));

  Future<void> upsertIntake(IntakeEntry entry) =>
      _mutate(() => repository.upsertIntake(entry));

  Future<void> deleteIntake(String id) =>
      _mutate(() => repository.deleteIntake(id));

  Future<void> upsertPeriod(PeriodRecord record) =>
      _mutate(() => repository.upsertPeriod(record));

  Future<void> deletePeriod(String id) =>
      _mutate(() => repository.deletePeriod(id));

  Future<void> upsertWeight(WeightEntry entry) =>
      _mutate(() => repository.upsertWeight(entry));

  Future<void> deleteWeight(String id) =>
      _mutate(() => repository.deleteWeight(id));

  Future<void> upsertSymptom(SymptomEntry entry) =>
      _mutate(() => repository.upsertSymptom(entry));

  Future<void> deleteSymptom(String id) =>
      _mutate(() => repository.deleteSymptom(id));

  /// Removes the complete local data set.
  Future<void> deleteEverything() =>
      _mutate(() => repository.deleteEverything());

  /// Replaces the complete data set, used by import and restore.
  ///
  /// The settings of the imported document (including the interface
  /// language) take effect immediately.
  Future<void> replaceAll(HealthData replacement) async {
    _busy = true;
    notifyListeners();
    try {
      await repository.replaceAll(replacement);
      _settings = repository.settings;
      strings = _settings.languageCode == 'en' ? Strings.en : Strings.de;
      locale.value = Locale(_settings.languageCode);
      _lastError = null;
    } on Object catch (error) {
      _lastError = '$error';
      rethrow;
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  Future<void> _mutate(Future<void> Function() action) async {
    _busy = true;
    notifyListeners();
    try {
      await action();
      _lastError = null;
    } on Object catch (error) {
      _lastError = '$error';
    } finally {
      _busy = false;
      notifyListeners();
    }
  }

  /// Shows a message in the UI.
  void reportError(Object error) {
    _lastError = '$error';
    notifyListeners();
  }

  void clearError() {
    if (_lastError == null) return;
    _lastError = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _foodClient.close();
    // The encrypted store is closed by the operating system when the process
    // ends; closing it here would mean awaiting inside dispose().
    super.dispose();
  }
}

/// Provides the [AppState] to the widget tree.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({required AppState state, required super.child, super.key})
      : super(notifier: state);

  static AppState of(BuildContext context) {
    final AppScope? scope =
        context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'No AppScope found in the widget tree.');
    return scope!.notifier!;
  }

  /// Reads the state without subscribing to changes.
  static AppState read(BuildContext context) {
    final AppScope? scope =
        context.getElementForInheritedWidgetOfExactType<AppScope>()?.widget
            as AppScope?;
    if (scope == null) {
      throw StateError('No AppScope found in the widget tree.');
    }
    final AppState? notifier = scope.notifier;
    if (notifier == null) {
      throw StateError('The AppScope has no state.');
    }
    return notifier;
  }
}

/// Deletes a file or directory, ignoring errors.
Future<void> deleteQuietly(FileSystemEntity entity) async {
  try {
    if (entity is File) {
      await entity.delete();
    } else if (entity is Directory) {
      await entity.delete(recursive: true);
    }
  } on Object {
    // Best effort clean up.
  }
}
