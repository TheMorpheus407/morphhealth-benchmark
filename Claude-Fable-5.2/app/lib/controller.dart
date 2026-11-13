import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:morphhealth_core/morphhealth_core.dart';

import 'platform/platform_bridge.dart';

/// Values fixed when the app is built.
class AppConfig {
  /// Origin of the food service unless the user chose another one.
  /// build.sh takes it from ENVIRONMENT.json (`food_api_base_url`).
  final String defaultFoodBaseUrl;

  /// User-Agent sent to the food service (`food_api_user_agent`).
  final String foodUserAgent;

  const AppConfig({
    required this.defaultFoodBaseUrl,
    required this.foodUserAgent,
  });

  static const AppConfig fromBuild = AppConfig(
    defaultFoodBaseUrl: String.fromEnvironment(
      'FOOD_API_BASE_URL',
      defaultValue: FoodApiClient.productionOrigin,
    ),
    foodUserAgent: String.fromEnvironment(
      'FOOD_API_USER_AGENT',
      defaultValue: 'MorphHealth/$morphHealthVersion (Android)',
    ),
  );
}

typedef FoodClientFactory =
    FoodApiClient Function(
      Uri origin,
      String userAgent,
      List<String> languages,
    );

FoodApiClient _defaultFoodClient(
  Uri origin,
  String userAgent,
  List<String> languages,
) => FoodApiClient(
  origin: origin,
  userAgent: userAgent,
  transport: IoHttpTransport(),
  languages: languages,
);

/// Encrypts and decrypts backups. The key derivation is deliberately slow,
/// so the default implementation works in a background isolate.
class BackupWorker {
  const BackupWorker();

  Future<Uint8List> seal(
    Map<String, dynamic> document,
    String passphrase,
    LocalDateTime createdAt,
  ) => compute(_sealBackup, (document, passphrase, createdAt));

  Future<Map<String, dynamic>> open(Uint8List bytes, String passphrase) =>
      compute(_openBackup, (bytes, passphrase));
}

Future<Uint8List> _sealBackup(
  (Map<String, dynamic>, String, LocalDateTime) args,
) => BackupCodec.seal(args.$1, args.$2, createdAt: args.$3);

Future<Map<String, dynamic>> _openBackup((Uint8List, String) args) =>
    BackupCodec.open(args.$1, args.$2);

/// The state of the running app: the repository plus values derived from it.
///
/// Widgets read from here and rebuild when it notifies. All calculations are
/// done by `morphhealth_core`; this class only caches their results until the
/// data change.
class AppController extends ChangeNotifier with WidgetsBindingObserver {
  final HealthRepository repository;
  final PlatformBridge platform;
  final AppConfig config;
  final FoodClientFactory _foodClientFactory;
  final BackupWorker backups;

  /// Opens the data store again from scratch (after everything was deleted).
  final Future<void> Function() _restart;

  /// True if this run began by deleting everything; the welcome screen then
  /// confirms that the data are gone.
  final bool afterWipe;

  Timer? _dayTimer;
  Day _lastToday;

  AppController({
    required this.repository,
    required this.platform,
    required Future<void> Function() restart,
    this.config = AppConfig.fromBuild,
    this.backups = const BackupWorker(),
    this.afterWipe = false,
    FoodClientFactory? foodClientFactory,
    bool watchClock = true,
  }) : _foodClientFactory = foodClientFactory ?? _defaultFoodClient,
       _restart = restart,
       _lastToday = repository.today {
    repository.addListener(_onDataChanged);
    if (watchClock) {
      WidgetsBinding.instance.addObserver(this);
      _dayTimer = Timer.periodic(
        const Duration(seconds: 30),
        (_) => _checkDay(),
      );
    }
  }

  AppData get data => repository.data;
  Settings get settings => repository.data.settings;
  Goals get goals => repository.data.goals;
  LocalState get local => repository.local;
  Day get today => repository.today;
  LocalDateTime get now => repository.now;
  PortableService get portable => PortableService(repository);

  void _onDataChanged() {
    _invalidate();
    notifyListeners();
  }

  void _checkDay() {
    final today = repository.today;
    if (today != _lastToday) {
      _lastToday = today;
      _invalidate();
      notifyListeners();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _checkDay();
  }

  @override
  void dispose() {
    _dayTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    repository.removeListener(_onDataChanged);
    _foodClient?.close();
    super.dispose();
  }

  // -------------------------------------------------------------- caches

  final Map<int, NutritionDay> _nutritionDays = {};
  CycleForecast? _forecast;
  List<SymptomPattern>? _patterns;
  HistoryIndex? _history;
  String? _historyLanguage;
  List<SymptomName>? _symptomNames;

  void _invalidate() {
    _nutritionDays.clear();
    _forecast = null;
    _patterns = null;
    _history = null;
    _symptomNames = null;
  }

  /// The nutrition figures of [day].
  NutritionDay nutritionDay(Day day) {
    if (_nutritionDays.length > 120) _nutritionDays.clear();
    return _nutritionDays[day.epochDay] ??= NutritionDay.compute(data, day);
  }

  /// The cycle assessment for today, with estimates for the months ahead.
  CycleForecast get forecast => _forecast ??= CycleForecast.compute(
    data.periods,
    today,
    predictionsEnabled: settings.cyclePredictions,
    statedTypicalLength: settings.typicalCycleLengthDays,
    followingPeriods: 6,
  );

  /// Symptoms that recur around period starts; empty in diary mode.
  List<SymptomPattern> get patterns => _patterns ??= settings.cyclePredictions
      ? symptomPatterns(data, today)
      : const [];

  /// The symptom names the user has used, most recent first.
  List<SymptomName> get usedSymptoms => _symptomNames ??= symptomNames(data);

  /// The searchable list of all entries. [labels] are the words of the
  /// current language that should be findable, see [HistoryIndex.build].
  HistoryIndex history(Map<String, String> labels, String language) {
    final cached = _history;
    if (cached != null && _historyLanguage == language) return cached;
    _historyLanguage = language;
    return _history = HistoryIndex.build(data, labels: labels);
  }

  // ------------------------------------------------------- food service

  FoodApiClient? _foodClient;
  String? _foodClientKey;

  /// The origin in use: the user's choice or the built-in one.
  String get foodBaseUrl {
    final custom = local.foodApiBaseUrl;
    return custom == null || custom.isEmpty
        ? config.defaultFoodBaseUrl
        : custom;
  }

  /// Client for the configured food service.
  FoodApiClient get foodClient {
    final languages = settings.language == 'en'
        ? const ['en', 'de']
        : const ['de', 'en'];
    final key = '$foodBaseUrl|${languages.first}';
    final existing = _foodClient;
    if (existing != null && _foodClientKey == key) return existing;
    existing?.close();
    _foodClientKey = key;
    return _foodClient = _foodClientFactory(
      FoodApiClient.parseOrigin(foodBaseUrl),
      config.foodUserAgent,
      languages,
    );
  }

  bool get onlineSearchEnabled =>
      settings.onlineFoodSearch == OnlineFoodSearch.enabled;

  // ------------------------------------------------------------- actions

  Future<void> updateSettings(Settings Function(Settings s) change) =>
      repository.updateSettings(change(settings));

  Future<void> setAreaVisible(Area area, bool visible) => updateSettings(
    (s) => s.copyWith(
      overviewSections: {
        for (final a in Area.values)
          if (a == area ? visible : s.overviewSections.contains(a)) a,
      },
    ),
  );

  /// Deletes everything on this device: the stored files and the encryption
  /// key. Afterwards the app starts again as after a fresh installation.
  Future<void> wipeEverything() async {
    await repository.destroy();
    await platform.resetMasterKey();
    await _restart();
  }
}

/// Makes the [AppController] available to the widget tree and rebuilds
/// dependants when it notifies.
class AppScope extends InheritedNotifier<AppController> {
  const AppScope({
    super.key,
    required AppController controller,
    required super.child,
  }) : super(notifier: controller);

  /// The controller; the calling widget rebuilds on every change.
  static AppController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  /// The controller without subscribing to changes (for callbacks).
  static AppController read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
