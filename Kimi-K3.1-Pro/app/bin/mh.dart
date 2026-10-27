import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:morphhealth/core/cycle.dart';
import 'package:morphhealth/core/encrypted_store.dart';
import 'package:morphhealth/core/food_api.dart';
import 'package:morphhealth/core/health.dart';
import 'package:morphhealth/core/nutrition.dart';
import 'package:morphhealth/core/portable.dart';
import 'package:morphhealth/core/repository.dart';
import 'package:morphhealth/core/utils.dart';

Future<void> main(List<String> arguments) async {
  late _Options options;
  try {
    options = _Options.parse(arguments);
  } catch (error) {
    stderr.writeln('mh: $error');
    stderr.writeln(
      'Usage: mh --data-dir ABS --key-file ABS [--now RFC3339] '
      '[--food-base-url HTTPS_ORIGIN] [--food-user-agent STRING]',
    );
    exitCode = 64;
    return;
  }

  late HealthRepository repository;
  late FoodApi foodApi;
  try {
    final dataDirectory = Directory(options.dataDir);
    final keyFile = File(options.keyFile);
    if (!await keyFile.exists())
      throw const FormatException('key file does not exist');
    final key = await keyFile.readAsBytes();
    if (key.length != 32)
      throw const FormatException('key file must contain exactly 32 raw bytes');
    final store = EncryptedFileStore(
      File('${dataDirectory.path}/state.enc'),
      key,
    );
    await dataDirectory.create(recursive: true);
    final fixedNow = options.now;
    repository = await HealthRepository.open(
      store,
      clock: fixedNow == null ? DateTime.now : () => fixedNow,
    );
    foodApi = FoodApi(
      options.foodBaseUrl,
      options.foodUserAgent,
      clock: fixedNow == null ? DateTime.now : () => fixedNow,
    );
  } catch (error) {
    stderr.writeln('mh: cannot open local data: $error');
    exitCode = 1;
    return;
  }

  final lines = stdin.transform(utf8.decoder).transform(const LineSplitter());
  await for (final line in lines) {
    if (line.trim().isEmpty) continue;
    Object? requestId;
    try {
      final decoded = jsonDecode(line);
      final request = jsonMap(decoded, 'request');
      requestId = request['request_id'];
      if (requestId == null)
        throw const FormatException('request_id is required');
      final operation = jsonString(request['op'], 'request.op');
      final data = await _execute(operation, request, repository, foodApi);
      await _respond({'request_id': requestId, 'ok': true, 'data': data});
    } catch (error) {
      await _respond({
        'request_id': requestId,
        'ok': false,
        'error': {'code': _errorCode(error), 'message': error.toString()},
      });
    }
  }
  foodApi.close();
  await repository.close();
}

Future<Object?> _execute(
  String operation,
  Map<String, dynamic> request,
  HealthRepository repository,
  FoodApi foodApi,
) async {
  switch (operation) {
    case 'describe':
      return _describe();
    case 'portable.export':
      if (request['ack_plaintext'] != true) {
        throw const FormatException('ack_plaintext: true is required');
      }
      return createPortableDocument(repository.state, repository.now);
    case 'portable.import':
      if (request['confirm_replace'] != true) {
        throw const FormatException('confirm_replace: true is required');
      }
      final replacement = parsePortableDocument(request['document']);
      await repository.replaceAll(replacement);
      return {'replaced': true, 'counts': _counts(replacement)};
    case 'nutrition.day':
      final date = jsonString(request['date'], 'date');
      final result = repository.nutritionDay(date).toJson();
      result['goals'] = repository.state.settings.goals.toJson();
      return result;
    case 'cycle.forecast':
      final on = jsonString(request['on'], 'on');
      return {
        ...forecastCycle(repository.state.periods, on).toJson(),
        'forecast_enabled_in_app':
            repository.state.settings.cycleForecastEnabled,
      };
    case 'food.search':
      _requireOnline(repository.state);
      final query = jsonString(request['q'], 'q');
      final page = jsonInt(request['page'], 'page', min: 1);
      final result = await foodApi.search(query, page);
      return result.toJson();
    case 'food.lookup':
      _requireOnline(repository.state);
      final barcode = jsonString(request['barcode'], 'barcode');
      final result = await foodApi.lookup(barcode);
      return result.toJson();
    default:
      throw FormatException('Unknown operation: $operation');
  }
}

void _requireOnline(AppState state) {
  if (!state.settings.onlineEnabled) throw StateError('online_disabled');
}

Map<String, int> _counts(AppState state) => {
  'foods': state.foods.length,
  'intakes': state.intakes.length,
  'periods': state.periods.length,
  'weights': state.weights.length,
  'symptoms': state.symptoms.length,
};

Map<String, dynamic> _describe() => {
  'protocol': 'MorphHealth local JSON Lines, version 1',
  'transport': {
    'input':
        'One JSON object per line on stdin; request_id and op are required.',
    'output':
        'One JSON object per request on stdout, flushed immediately. '
        'Successful responses have ok=true and data; errors have ok=false and error.',
    'error': {
      'code': 'stable category such as format_exception or state_error',
      'message': 'human-readable detail',
    },
    'termination': 'EOF terminates the process. Blank lines are ignored.',
  },
  'storage': {
    'file': 'state.enc below --data-dir',
    'format':
        'morphhealth.encrypted-state.v1; AES-256-GCM with 12-byte nonce and 16-byte MAC',
    'key':
        '--key-file names exactly 32 raw key bytes outside --data-dir; it is not a passphrase.',
  },
  'formats': {
    'portable':
        'morphhealth.portable.v1 JSON object: format, app_version, exported_at, state.',
    'encrypted_backup':
        'morphhealth.encrypted-backup.v1; PBKDF2-HMAC-SHA256 (600000 iterations) '
        'and AES-256-GCM; used by the Android backup UI.',
    'timestamps':
        'UTC RFC3339 strings with Z. occurred_at is grouped using the process/device local timezone.',
    'dates': 'YYYY-MM-DD calendar dates.',
    'nutrient_units': {
      for (final nutrient in Nutrient.values) nutrient.id: nutrient.unit,
    },
    'food_nutrients':
        'foods.nutrients_per_100 contains known canonical values per 100 g/ml; '
        'missing keys mean unknown, not zero. portion_size is in the food measure unit.',
    'intake_nutrients':
        'nutrients_per_100_snapshot preserves historical values. '
        'For food, amount/unit is g, ml or portion; portion uses portion_size. '
        'Water uses ml, additional caffeine uses mg.',
    'enums': {
      'food.source': ['custom', 'openfoodfacts'],
      'food.measure': ['g', 'ml'],
      'intake.kind': ['food', 'water', 'caffeine'],
      'intake.meal': ['breakfast', 'lunch', 'dinner', 'snack'],
      'period.flow': ['spotting', 'light', 'medium', 'heavy'],
      'settings.language': ['de', 'en'],
      'settings.weight_unit': ['kg', 'lb'],
    },
  },
  'operations': {
    'describe': {'input': {}, 'output': 'This description.'},
    'portable.export': {
      'input': {'ack_plaintext': true},
      'output': 'The complete portable document directly in data.',
    },
    'portable.import': {
      'input': {
        'document': 'portable document object',
        'confirm_replace': true,
      },
      'output':
          '{replaced: true, counts: {foods, intakes, periods, weights, symptoms}}. '
          'Validation finishes before the existing state is replaced.',
    },
    'nutrition.day': {
      'input': {'date': 'YYYY-MM-DD'},
      'output':
          'date, water_ml, totals, nutrient_units, goals, entry list with '
          'calculated_nutrients, and known-food coverage per nutrient.',
    },
    'cycle.forecast': {
      'input': {'on': 'YYYY-MM-DD'},
      'output':
          'Personal median forecast, source intervals, range, confidence and explanation.',
    },
    'food.search': {
      'input': {'q': 'non-empty search text', 'page': 'integer >= 1'},
      'output': 'query, page, page_size=20, total_results, returned, products.',
    },
    'food.lookup': {
      'input': {'barcode': '8 to 14 digits'},
      'output': '{barcode, found, food}; food is null when not found.',
    },
  },
  'portable_import_example': portableExample(),
};

String _errorCode(Object error) {
  if (error is FormatException ||
      error is ArgumentError ||
      error is TypeError) {
    return 'invalid_request';
  }
  if (error is FoodApiException) return error.code;
  if (error is StateError) return error.message;
  return 'operation_failed';
}

Future<void> _respond(Map<String, dynamic> response) async {
  stdout.writeln(jsonEncode(response));
  await stdout.flush();
}

class _Options {
  const _Options({
    required this.dataDir,
    required this.keyFile,
    required this.foodBaseUrl,
    required this.foodUserAgent,
    this.now,
  });

  final String dataDir;
  final String keyFile;
  final DateTime? now;
  final String foodBaseUrl;
  final String foodUserAgent;

  static _Options parse(List<String> arguments) {
    final values = <String, String>{};
    const allowed = {
      'data-dir',
      'key-file',
      'now',
      'food-base-url',
      'food-user-agent',
    };
    for (var index = 0; index < arguments.length; index += 2) {
      final argument = arguments[index];
      if (!argument.startsWith('--') || index + 1 >= arguments.length) {
        throw FormatException('invalid arguments near $argument');
      }
      final name = argument.substring(2);
      if (!allowed.contains(name) || values.containsKey(name)) {
        throw FormatException('unknown or repeated option: $argument');
      }
      values[name] = arguments[index + 1];
    }
    String absolute(String name) {
      final value = values[name];
      if (value == null || !Uri.file(value).isAbsolute) {
        throw FormatException('--$name must be an absolute path');
      }
      return Uri.file(value).normalizePath().toFilePath();
    }

    final dataDir = absolute('data-dir');
    final keyFile = absolute('key-file');
    final prefix = dataDir.endsWith('/') ? dataDir : '$dataDir/';
    if (keyFile.startsWith(prefix) || keyFile == dataDir) {
      throw const FormatException('key file must be outside data-dir');
    }
    final nowText = values['now'];
    final now = nowText == null ? null : parseInstant(nowText, 'now');
    final base =
        values['food-base-url'] ??
        Platform.environment['MH_FOOD_BASE_URL'] ??
        const String.fromEnvironment(
          'FOOD_BASE_URL',
          defaultValue: 'https://world.openfoodfacts.org',
        );
    FoodApi(base, '');
    final userAgent =
        values['food-user-agent'] ??
        Platform.environment['MH_FOOD_USER_AGENT'] ??
        const String.fromEnvironment(
          'FOOD_USER_AGENT',
          defaultValue: 'MorphHealth/1.0',
        );
    if (userAgent.trim().isEmpty)
      throw const FormatException('food user agent must not be empty');
    return _Options(
      dataDir: dataDir,
      keyFile: keyFile,
      now: now,
      foodBaseUrl: base,
      foodUserAgent: userAgent,
    );
  }
}
