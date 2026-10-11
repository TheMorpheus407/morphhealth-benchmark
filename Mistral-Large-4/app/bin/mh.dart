// MorphHealth Wartungszugang `mh` (SPEC P10).
//
// Schlanker lokaler JSON-Lines-Zugang zu den tatsächlichen Daten und
// Funktionen derselben Anwendung (siehe lib/src/cli/mh_service.dart).
// Läuft als gesonderter Linux-Prozess; liest Anfragen zeilenweise von stdin,
// schreibt Antworten zeilenweise nach stdout (jeweils geflusht), EOF beendet.
//
// Aufruf:
//   ./mh --data-dir ABS --key-file ABS [--now RFC3339]
//        [--food-base-url HTTPS_ORIGIN] [--food-user-agent STRING]
library;

import 'dart:convert';
import 'dart:io';

import 'package:morphhealth/src/cli/mh_service.dart';
import 'package:morphhealth/src/core/clock.dart';
import 'package:morphhealth/src/core/exceptions.dart';
import 'package:morphhealth/src/data/repository.dart';
import 'package:morphhealth/src/food/off_client.dart';
import 'package:morphhealth/src/model/document.dart';
import 'package:morphhealth/src/store/store.dart';

/// Standard-Origin für eine normale Produktinstallation (per --dart-define
/// bzw. --food-base-url überschreibbar; siehe build.sh / README).
const String defaultFoodBaseUrl = String.fromEnvironment(
  'FOOD_API_BASE_URL',
  defaultValue: 'https://world.openfoodfacts.org',
);

/// Standard-User-Agent für eine normale Produktinstallation.
const String defaultFoodUserAgent = String.fromEnvironment(
  'FOOD_API_USER_AGENT',
  defaultValue: 'MorphHealth/1.0 (local maintenance)',
);

const String usage = '''MorphHealth Wartungszugang (mh)

Aufruf:
  ./mh --data-dir ABS --key-file ABS [--now RFC3339]
       [--food-base-url HTTPS_ORIGIN] [--food-user-agent STRING]

  --data-dir        Persistenter Arbeitsdatenbestand (Verzeichnis).
  --key-file        Schlüsseldatiei mit 32 rohen Bytes (außerhalb des Datenverzeichnisses).
  --now             Fachliche Uhr für diesen Prozess (RFC3339); sonst Systemuhr.
  --food-base-url   Origin der Open-Food-Facts-API (HTTPS).
  --food-user-agent User-Agent für die Open-Food-Facts-API.

Protokoll: JSON Lines auf stdin/stdout. Anfrage: {"request_id": ..., "op": ...}.
Antwort: {"request_id": ..., "ok": true, "data": ...} oder
{"request_id": ..., "ok": false, "error": {...}}. EOF beendet den Prozess.
Operationen: describe, portable.export, portable.import, nutrition.day,
cycle.forecast, food.search, food.lookup. Details: op "describe".
''';

Future<void> main(List<String> arguments) async {
  Map<String, String> args;
  try {
    args = _parseArgs(arguments);
  } on MorphException catch (e) {
    stderr.writeln('mh: ${e.message}');
    stderr.writeln(usage);
    exitCode = 2;
    return;
  }
  if (args.containsKey('help')) {
    stdout.write(usage);
    return;
  }

  final Directory dataDir = Directory(args['data-dir']!);
  final File keyFile = File(args['key-file']!);
  final Clock clock;
  String clockSource = 'system';
  if (args.containsKey('now')) {
    final DateTime? parsed = DateTime.tryParse(args['now']!);
    if (parsed == null) {
      stderr.writeln('mh: --now erwartet einen RFC3339-Zeitstempel, z. B. 2026-09-23T12:00:00+02:00');
      exitCode = 2;
      return;
    }
    clock = FixedClock(parsed);
    clockSource = '--now';
  } else {
    clock = SystemClock();
  }

  final String foodBaseUrl = args['food-base-url'] ??
      Platform.environment['MH_FOOD_BASE_URL'] ??
      defaultFoodBaseUrl;
  final String foodUserAgent = args['food-user-agent'] ??
      Platform.environment['MH_FOOD_USER_AGENT'] ??
      defaultFoodUserAgent;

  try {
    await dataDir.create(recursive: true);
    final List<int> keyBytes = await KeyFile.loadStrict(keyFile);
    final AppInfo appInfo = _appInfo();
    final MhConfig config = MhConfig(
      dataDir: dataDir,
      keyFile: keyFile,
      clock: clock,
      clockSource: clockSource,
      offConfig: OffConfig(baseUrl: foodBaseUrl, userAgent: foodUserAgent),
      appInfo: appInfo,
    );
    final EncryptedStore store = EncryptedStore(
      dataDir: dataDir,
      keyBytes: keyBytes,
      appInfo: appInfo,
    );
    final MorphRepository repo = MorphRepository(
      FileStoreBackend(store, clock: clock),
      clock: clock,
      appInfo: appInfo,
    );
    await repo.load();
    final MhService service = MhService(repo, config);

    await for (final String line
        in stdin.transform(utf8.decoder).transform(const LineSplitter())) {
      final String trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      Map<String, dynamic> request;
      try {
        final dynamic decoded = jsonDecode(trimmed);
        if (decoded is Map<String, dynamic>) {
          request = decoded;
        } else if (decoded is Map) {
          request = decoded.cast<String, dynamic>();
        } else {
          throw const FormatException('Zeile ist kein JSON-Objekt');
        }
      } catch (e) {
        request = <String, dynamic>{
          'request_id': null,
          'op': null,
          '__parse_error': '$e',
        };
      }
      final Map<String, dynamic> response;
      if (request.containsKey('__parse_error')) {
        response = <String, dynamic>{
          'request_id': null,
          'ok': false,
          'error': <String, dynamic>{
            'code': 'request.invalid_json',
            'message': 'Die Anfrage-Zeile ist kein gültiges JSON-Objekt: ${request['__parse_error']}',
          },
        };
      } else {
        response = await service.handleRequest(request);
      }
      stdout.write('${jsonEncode(response)}\n');
      await stdout.flush();
    }
    // EOF: persistieren und sauber beenden.
    await repo.dispose();
  } on MorphException catch (e) {
    stderr.writeln('mh: [${e.code}] ${e.message}');
    exitCode = 1;
  } catch (e) {
    stderr.writeln('mh: Interner Fehler: $e');
    exitCode = 1;
  }
}

AppInfo _appInfo() {
  // Version aus --dart-define (build.sh), sonst pubspec-Fallback.
  const String version = String.fromEnvironment('MH_APP_VERSION', defaultValue: '1.0.0+1');
  return AppInfo(name: 'MorphHealth', version: version);
}

Map<String, String> _parseArgs(List<String> arguments) {
  final Map<String, String> out = <String, String>{};
  for (int i = 0; i < arguments.length; i++) {
    final String arg = arguments[i];
    switch (arg) {
      case '--help':
      case '-h':
        out['help'] = 'true';
        break;
      case '--data-dir':
      case '--key-file':
      case '--now':
      case '--food-base-url':
      case '--food-user-agent':
        if (i + 1 >= arguments.length) {
          throw MorphException('args.missing_value', 'Option $arg erwartet einen Wert.');
        }
        out[arg.substring(2)] = arguments[++i];
        break;
      default:
        if (arg.startsWith('--data-dir=')) {
          out['data-dir'] = arg.substring('--data-dir='.length);
        } else if (arg.startsWith('--key-file=')) {
          out['key-file'] = arg.substring('--key-file='.length);
        } else if (arg.startsWith('--now=')) {
          out['now'] = arg.substring('--now='.length);
        } else if (arg.startsWith('--food-base-url=')) {
          out['food-base-url'] = arg.substring('--food-base-url='.length);
        } else if (arg.startsWith('--food-user-agent=')) {
          out['food-user-agent'] = arg.substring('--food-user-agent='.length);
        } else {
          throw MorphException('args.unknown', 'Unbekannte Option: $arg');
        }
    }
  }
  if (!out.containsKey('data-dir')) {
    throw MorphException('args.missing_data_dir', 'Erforderlich: --data-dir ABS');
  }
  if (!out.containsKey('key-file')) {
    throw MorphException('args.missing_key_file', 'Erforderlich: --key-file ABS');
  }
  return out;
}
