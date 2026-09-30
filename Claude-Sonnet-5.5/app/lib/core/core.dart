import 'dart:typed_data';

import 'backup.dart';
import 'civil.dart';
import 'clock.dart';
import 'crypto.dart';
import 'cycle.dart';
import 'db.dart';
import 'food_api.dart';
import 'http.dart';
import 'nutrition.dart';
import 'portable.dart';
import 'store.dart';

/// Vorgabe des Builds für den Ursprung der Lebensmittel-API. `build.sh` setzt
/// den Wert aus ENVIRONMENT.json; ohne Angabe gilt der normale Produktions-
/// Ursprung.
const String kDefaultFoodBaseUrl = String.fromEnvironment(
  'MH_FOOD_BASE_URL',
  defaultValue: 'https://world.openfoodfacts.org',
);

/// Vorgabe des Builds für den User-Agent der Lebensmittelabfragen.
const String kDefaultFoodUserAgent = String.fromEnvironment(
  'MH_FOOD_USER_AGENT',
  defaultValue: 'MorphHealth/$kAppVersion (Android app, no telemetry)',
);

/// Die Anwendung ohne Oberfläche: Daten, Berechnungen, Lebensmittelabruf,
/// Export/Import und Sicherung. Die Android-Oberfläche und der Wartungszugang
/// `mh` rufen genau diese Funktionen auf.
final class MorphCore {
  final Db db;
  final Clock clock;
  final HttpTransport transport;

  /// Von der Befehlszeile gesetzte Werte (haben Vorrang).
  final String? baseUrlOverride;
  final String? userAgentOverride;

  MorphCore._(this.db, this.clock, this.transport, this.baseUrlOverride, this.userAgentOverride);

  static Future<MorphCore> open({
    required Persistence persistence,
    Clock? clock,
    HttpTransport? transport,
    String? baseUrlOverride,
    String? userAgentOverride,
  }) async {
    final c = clock ?? SystemClock();
    final db = await Db.open(persistence, c);
    return MorphCore._(db, c, transport ?? IoHttpTransport(), baseUrlOverride, userAgentOverride);
  }

  Future<void> close() => db.close();

  // -- Lebensmittelabruf ----------------------------------------------------

  /// Wirksamer Ursprung: Befehlszeile, dann Einstellung, dann Vorgabe des Builds.
  String get effectiveBaseUrl => baseUrlOverride ?? db.settings.foodBaseUrl ?? kDefaultFoodBaseUrl;

  String get effectiveUserAgent => userAgentOverride ?? kDefaultFoodUserAgent;

  FoodApi foodApi() {
    if (!db.settings.onlineFood) {
      throw const FoodApiException('disabled', 'Die Online-Lebensmittelsuche ist ausgeschaltet');
    }
    return FoodApi(
      baseUrl: effectiveBaseUrl,
      userAgent: effectiveUserAgent,
      transport: transport,
      language: db.settings.language,
    );
  }

  Future<FoodSearchPage> foodSearch(String query, {int page = 1}) => foodApi().search(query, page: page);

  Future<FoodLookup> foodLookup(String barcode) => foodApi().lookup(barcode);

  // -- Berechnungen -----------------------------------------------------------

  DayNutrition nutritionDay(Day day) => dayNutrition(db, day);

  Forecast cycleForecast(Day on) => computeForecast(
    db.periods,
    on,
    enabled: db.settings.cycleForecast,
    manualCycleLength: db.settings.expectedCycleLength,
  );

  // -- Export, Import, Sicherung ----------------------------------------------

  Map<String, Object?> exportDocument() => exportPortable(db, clock);

  /// Prüft [document] und ersetzt danach den gesamten Bestand.
  Future<ImportReport> importDocument(Object? document) async {
    final parsed = parsePortable(document);
    await db.replaceAll(parsed.state);
    return parsed.report;
  }

  /// Prüft, ohne etwas zu ändern (Vorschau für die Oberfläche).
  ParsedImport previewImport(Object? document) => parsePortable(document);

  Future<Uint8List> createBackupFile(String passphrase, {Argon2Params params = Argon2Params.standard}) =>
      createBackup(exportDocument(), passphrase, params: params);

  /// Öffnet eine Sicherung; ersetzt den Bestand erst, wenn alles gültig ist.
  Future<ImportReport> restoreBackupFile(Uint8List bytes, String passphrase) async {
    final doc = await openBackup(bytes, passphrase);
    return importDocument(doc);
  }
}
