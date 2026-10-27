import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:path_provider/path_provider.dart';

import 'core/encrypted_store.dart';
import 'core/food_api.dart';
import 'core/repository.dart';
import 'ui/app.dart';

export 'ui/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Future.wait([
    initializeDateFormatting('de'),
    initializeDateFormatting('en'),
  ]);
  try {
    const secureStorage = FlutterSecureStorage(
      aOptions: AndroidOptions(
        encryptedSharedPreferences: true,
        resetOnError: false,
      ),
    );
    const keyName = 'morphhealth_database_key_v1';
    final stored = await secureStorage.read(key: keyName);
    late final List<int> key;
    if (stored == null) {
      key = randomBytes(32);
      await secureStorage.write(key: keyName, value: base64Encode(key));
    } else {
      key = base64Decode(stored);
      if (key.length != 32) throw const FormatException('Invalid database key');
    }
    final support = await getApplicationSupportDirectory();
    final store = EncryptedFileStore(File('${support.path}/state.enc'), key);
    final repository = await HealthRepository.open(store);
    const baseUrl = String.fromEnvironment(
      'FOOD_BASE_URL',
      defaultValue: 'https://world.openfoodfacts.org',
    );
    const userAgent = String.fromEnvironment(
      'FOOD_USER_AGENT',
      defaultValue: 'MorphHealth/1.0',
    );
    runApp(
      MorphHealthApp(
        repository: repository,
        foodApi: FoodApi(baseUrl, userAgent),
      ),
    );
  } catch (_) {
    runApp(const StartupErrorApp());
  }
}
