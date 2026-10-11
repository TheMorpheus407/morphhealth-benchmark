// Bootstrap der App: Speicherpfade, Schlüsseldatei, verschlüsselter Store.
//
// Getrennt von main() und der App-Wurzel, damit beide Seiten ohne
// zirkuläre Imports darauf zugreifen können.
library;

import 'dart:io';

import 'package:path_provider/path_provider.dart';

import '../core/exceptions.dart';
import '../data/repository.dart';
import '../food/off_client.dart';
import '../model/document.dart';
import '../store/store.dart';

/// App-Version (per --dart-define aus build.sh, sonst pubspec-Wert).
const String appVersion =
    String.fromEnvironment('MH_APP_VERSION', defaultValue: '1.0.0+1');

/// Standard-Origin der Open-Food-Facts-API für Produktinstallationen
/// (build.sh übergibt die Werte aus ENVIRONMENT.json per --dart-define).
const String foodBaseUrl = String.fromEnvironment(
  'FOOD_API_BASE_URL',
  defaultValue: 'https://world.openfoodfacts.org',
);

/// Standard-User-Agent der Open-Food-Facts-API.
const String foodUserAgent = String.fromEnvironment(
  'FOOD_API_USER_AGENT',
  defaultValue: 'MorphHealth/1.0 (local app)',
);

/// Ergebnis des App-Bootstrap.
class Bootstrap {
  final MorphRepository? repository;
  final OffConfig offConfig;
  final AppInfo appInfo;
  final Directory? dataDir;
  final File? keyFile;
  final MorphException? error;

  const Bootstrap({
    required this.offConfig,
    required this.appInfo,
    this.repository,
    this.dataDir,
    this.keyFile,
    this.error,
  });

  bool get ok => repository != null;
}

/// Öffnet den verschlüsselten Datenbestand der App.
Future<Bootstrap> bootstrapApp() async {
  final OffConfig offConfig =
      OffConfig(baseUrl: foodBaseUrl, userAgent: foodUserAgent);
  final AppInfo appInfo = AppInfo(name: 'MorphHealth', version: appVersion);
  try {
    final Directory support = await getApplicationSupportDirectory();
    final Directory root = Directory('${support.path}/morphhealth');
    final Directory dataDir = Directory('${root.path}/data');
    final File keyFile = File('${root.path}/master.key');
    // Schlüsseldatei liegt außerhalb des Datenverzeichnisses.
    final List<int> keyBytes = await KeyFile.loadOrCreate(keyFile);
    final EncryptedStore store = EncryptedStore(
        dataDir: dataDir, keyBytes: keyBytes, appInfo: appInfo);
    final MorphRepository repo =
        MorphRepository(FileStoreBackend(store), appInfo: appInfo);
    await repo.load();
    return Bootstrap(
      repository: repo,
      offConfig: offConfig,
      appInfo: appInfo,
      dataDir: dataDir,
      keyFile: keyFile,
    );
  } on MorphException catch (e) {
    return Bootstrap(
      repository: null,
      offConfig: offConfig,
      appInfo: appInfo,
      error: e,
    );
  } catch (e) {
    return Bootstrap(
      repository: null,
      offConfig: offConfig,
      appInfo: appInfo,
      error: MorphException('app.bootstrap_failed',
          'Die App konnte nicht gestartet werden: $e'),
    );
  }
}
