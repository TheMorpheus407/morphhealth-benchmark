library morphhealth.ui.main;

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:morphhealth/core/repository.dart';
import 'package:morphhealth/core/service/off_client.dart';
import 'package:morphhealth/core/storage/encrypted_store.dart';
import 'package:morphhealth/ui/app.dart';
import 'package:path_provider/path_provider.dart';

const _keyName = 'morphhealth_data_key';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final dir = await getApplicationDocumentsDirectory();
  final dataPath = '${dir.path}/data.json.enc';

  final storage = FlutterSecureStorage();
  final existing = await storage.read(key: _keyName);
  Uint8List keyBytes;
  if (existing != null && existing.isNotEmpty) {
    keyBytes = base64Url.decode(existing);
  } else {
    final secure = Random.secure();
    keyBytes = Uint8List.fromList(List<int>.generate(32, (_) => secure.nextInt(256)));
    await storage.write(key: _keyName, value: base64Url.encode(keyBytes));
  }

  final store = EncryptedStore(keyBytes);
  final repository = HealthRepository(
    store: store,
    dataPath: dataPath,
    now: () => DateTime.now(),
    foodClient: OpenFoodFactsClient(
      baseUrl: const String.fromEnvironment('FOOD_BASE_URL', defaultValue: 'https://localhost:8788'),
      userAgent: const String.fromEnvironment('FOOD_USER_AGENT',
          defaultValue: 'MorphHealth/1.0-rc3 (benchmark build)'),
    ),
  );
  await repository.load();

  final localeCode = repository.settings.locale;
  runApp(MorphHealthApp(
    repository: repository,
    initialLocale: Locale(localeCode == 'de' ? 'de' : 'en'),
  ));
}