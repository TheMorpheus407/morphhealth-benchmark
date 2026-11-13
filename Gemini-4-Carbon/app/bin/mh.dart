import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:args/args.dart';
import 'package:path/path.dart' as p;

import 'package:morphhealth/core/clock.dart';
import 'package:morphhealth/core/crypto_vault.dart';
import 'package:morphhealth/core/mh_rpc_handler.dart';
import 'package:morphhealth/core/open_food_facts_client.dart';
import 'package:morphhealth/core/store.dart';

Future<void> main(List<String> arguments) async {
  final parser = ArgParser(allowTrailingOptions: true)
    ..addOption(
      'data-dir',
      help: 'Absolute path to persistent encrypted working data directory.',
    )
    ..addOption(
      'key-file',
      help: 'Absolute path to 32-byte raw master key file (outside data-dir).',
    )
    ..addOption(
      'now',
      help: 'Optional RFC3339 timestamp fixing the domain clock for this process.',
    )
    ..addOption(
      'food-base-url',
      help: 'HTTPS origin for Open Food Facts compatible endpoint.',
    )
    ..addOption(
      'food-user-agent',
      help: 'HTTP User-Agent string for Open Food Facts requests.',
    )
    ..addFlag(
      'help',
      abbr: 'h',
      negatable: false,
      help: 'Show CLI usage on stderr.',
    );

  ArgResults parsed;
  try {
    parsed = parser.parse(arguments);
  } catch (e) {
    stderr.writeln('Argument error: $e');
    exit(2);
  }

  if (parsed['help'] == true) {
    stderr.writeln(
      'Usage: ./mh --data-dir ABS --key-file ABS [--now RFC3339] '
      '[--food-base-url HTTPS_ORIGIN] [--food-user-agent STRING]',
    );
    stderr.writeln(parser.usage);
    exit(0);
  }

  if (parsed.rest.isNotEmpty) {
    stderr.writeln('Unexpected positional arguments: ${parsed.rest.join(' ')}');
    exit(2);
  }

  final dataDirRaw = parsed['data-dir'] as String?;
  final keyFileRaw = parsed['key-file'] as String?;
  if (dataDirRaw == null ||
      dataDirRaw.trim().isEmpty ||
      keyFileRaw == null ||
      keyFileRaw.trim().isEmpty) {
    stderr.writeln('Both --data-dir ABS and --key-file ABS are required.');
    exit(2);
  }

  if (!p.isAbsolute(dataDirRaw) || !p.isAbsolute(keyFileRaw)) {
    stderr.writeln('--data-dir and --key-file must be absolute paths.');
    exit(2);
  }

  final normDataDir = p.canonicalize(dataDirRaw);
  final normKeyFile = p.canonicalize(keyFileRaw);
  if (p.equals(normDataDir, normKeyFile) || p.isWithin(normDataDir, normKeyFile)) {
    stderr.writeln('--key-file must be located outside --data-dir.');
    exit(2);
  }

  final keyFile = File(keyFileRaw);
  if (!keyFile.existsSync()) {
    stderr.writeln('Key file does not exist: $keyFileRaw');
    exit(2);
  }

  Uint8List masterKey;
  try {
    masterKey = await keyFile.readAsBytes();
    VaultCrypto.validateMasterKey(masterKey);
  } catch (e) {
    stderr.writeln('Invalid key file: $e');
    exit(2);
  }

  AppClock clock = const SystemClock();
  final nowRaw = parsed['now'] as String?;
  if (nowRaw != null && nowRaw.trim().isNotEmpty) {
    try {
      clock = FixedClock.fromRfc3339(nowRaw);
    } catch (e) {
      stderr.writeln('Invalid --now value: $e');
      exit(2);
    }
  }

  final envDefaults = _loadEnvironmentFoodDefaults();
  final foodBaseUrl =
      (parsed['food-base-url'] as String?)?.trim().isNotEmpty == true
          ? (parsed['food-base-url'] as String).trim()
          : (envDefaults.$1 ?? OpenFoodFactsClient.defaultProductionBaseUrl);
  final foodUserAgent =
      (parsed['food-user-agent'] as String?)?.trim().isNotEmpty == true
          ? (parsed['food-user-agent'] as String).trim()
          : (envDefaults.$2 ?? OpenFoodFactsClient.defaultUserAgent);

  OpenFoodFactsClient foodClient;
  try {
    foodClient = OpenFoodFactsClient(
      baseUrl: foodBaseUrl,
      userAgent: foodUserAgent,
      clock: clock,
    );
  } catch (e) {
    stderr.writeln('Invalid Open Food Facts configuration: $e');
    exit(2);
  }

  MorphHealthStore store;
  try {
    store = await MorphHealthStore.open(
      dataDir: normDataDir,
      masterKey: masterKey,
      clock: clock,
    );
  } catch (e) {
    foodClient.close();
    stderr.writeln('Failed to open encrypted working directory: $e');
    exit(1);
  }

  final handler = MhRpcHandler(
    store: store,
    foodClient: foodClient,
    clock: clock,
  );

  try {
    final lines = stdin.transform(utf8.decoder).transform(const LineSplitter());
    await for (final line in lines) {
      if (line.trim().isEmpty) continue;
      final resp = await handler.handleRawJsonLine(line);
      stdout.writeln(jsonEncode(resp));
      await stdout.flush();
    }
  } finally {
    foodClient.close();
  }
}

(String?, String?) _loadEnvironmentFoodDefaults() {
  final candidates = <String>[
    if (Platform.environment['MORPHHEALTH_ENV_FILE'] != null)
      Platform.environment['MORPHHEALTH_ENV_FILE']!,
    p.join(Directory.current.path, 'ENVIRONMENT.json'),
    p.join(p.dirname(Platform.resolvedExecutable), '..', 'ENVIRONMENT.json'),
  ];

  for (final candidate in candidates) {
    final f = File(candidate);
    if (f.existsSync()) {
      try {
        final decoded = jsonDecode(f.readAsStringSync());
        if (decoded is Map<String, dynamic>) {
          final base = decoded['food_api_base_url'];
          final ua = decoded['food_api_user_agent'];
          return (
            base is String && base.trim().isNotEmpty ? base.trim() : null,
            ua is String && ua.trim().isNotEmpty ? ua.trim() : null,
          );
        }
      } catch (_) {
        // Ignore malformed optional manifest and continue fallback chain
      }
    }
  }
  return (null, null);
}
