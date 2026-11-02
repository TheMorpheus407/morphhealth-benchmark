/// `mh` – the narrow local maintenance access of MorphHealth.
///
/// The process reads one JSON object per line from stdin and answers with one
/// JSON object per line on stdout. It runs the very same product code as the
/// graphical app: the same encrypted store, the same nutrition and cycle
/// logic, the same Open Food Facts client.
///
/// ```
/// ./mh --data-dir /abs/path --key-file /abs/path/to/key.bin
/// ```
///
/// See README.md for the complete protocol description.
library;

import 'dart:convert';
import 'dart:io';

import 'package:morphhealth_core/morphhealth_core.dart';

const String _usage = '''
mh – MorphHealth local maintenance access (JSON lines over stdin/stdout)

Usage:
  mh --data-dir <absolute path> --key-file <absolute path>
     [--now <RFC3339>] [--food-base-url <https origin>] [--food-user-agent <string>]

Options:
  --data-dir        Working data directory (created when missing).
  --key-file        File with 32 raw key bytes. Must not live inside --data-dir.
  --now             Fixes the business clock of this process (RFC3339).
  --food-base-url   Origin of the read only Open Food Facts endpoint.
  --food-user-agent User agent used for the food service.
  --help            Show this text.

Protocol: one JSON request per line on stdin, one JSON response per line on
stdout. Every response repeats the request_id and carries "ok" plus "data" or
"error". EOF ends the process.
''';

Future<int> main(List<String> arguments) async {
  String? dataDir;
  String? keyFile;
  String? now;
  String? foodBaseUrl;
  String? foodUserAgent;

  for (int i = 0; i < arguments.length; i++) {
    final String arg = arguments[i];
    switch (arg) {
      case '--data-dir':
        dataDir = _valueOf(arguments, ++i, '--data-dir');
      case '--key-file':
        keyFile = _valueOf(arguments, ++i, '--key-file');
      case '--now':
        now = _valueOf(arguments, ++i, '--now');
      case '--food-base-url':
        foodBaseUrl = _valueOf(arguments, ++i, '--food-base-url');
      case '--food-user-agent':
        foodUserAgent = _valueOf(arguments, ++i, '--food-user-agent');
      case '--help':
      case '-h':
        stdout.write(_usage);
        return 0;
      default:
        stderr.writeln('Unknown argument: $arg');
        stderr.write(_usage);
        return 2;
    }
  }

  if (dataDir == null || keyFile == null) {
    stderr.writeln('Both --data-dir and --key-file are required.');
    stderr.write(_usage);
    return 2;
  }

  final Directory directory = Directory(dataDir).absolute;
  final File key = File(keyFile).absolute;

  if (_isInside(directory.path, key.path)) {
    stderr.writeln('The key file must not be stored inside the data directory.');
    return 2;
  }
  if (!await key.exists()) {
    stderr.writeln('Key file not found: ${key.path}');
    return 2;
  }

  final List<int> masterKey = await key.readAsBytes();
  if (masterKey.length != 32) {
    stderr.writeln(
      'The key file must contain exactly 32 raw bytes, got ${masterKey.length}.',
    );
    return 2;
  }

  AppClock clock = const SystemClock();
  if (now != null) {
    final DateTime? parsed = DateTime.tryParse(now);
    if (parsed == null) {
      stderr.writeln('Invalid RFC3339 timestamp: $now');
      return 2;
    }
    clock = FixedClock(parsed.toLocal());
  }

  await directory.create(recursive: true);
  final StoreLock? lock = await StoreLock.tryAcquire(directory);
  if (lock == null) {
    stderr.writeln(
      'The data directory is locked by another process: ${directory.path}',
    );
    return 3;
  }

  final FoodApiClient foodClient = FoodApiClient(
    baseUrl: foodBaseUrl ?? kFoodApiBaseUrl,
    userAgent: foodUserAgent ?? kFoodApiUserAgent,
  );

  int exitCode = 0;
  try {
    final HealthRepository repository = await HealthRepository.open(
      directory: directory,
      masterKey: masterKey,
      clock: clock,
    );
    await repository.load();

    final _Server server = _Server(
      repository: repository,
      foodClient: foodClient,
    );

    await for (final String line
        in stdin.transform(utf8.decoder).transform(const LineSplitter())) {
      final String trimmed = line.trim();
      if (trimmed.isEmpty) continue;
      await server.handleLine(trimmed);
    }
    await repository.close();
  } on Object catch (error) {
    stderr.writeln('Fatal: $error');
    exitCode = 1;
  } finally {
    foodClient.close();
    await lock.release();
  }
  return exitCode;
}

String _valueOf(List<String> arguments, int index, String name) {
  if (index >= arguments.length) {
    stderr.writeln('Missing value for $name');
    exit(2);
  }
  return arguments[index];
}

bool _isInside(String directoryPath, String filePath) {
  final String dir = directoryPath.endsWith('/')
      ? directoryPath.substring(0, directoryPath.length - 1)
      : directoryPath;
  return filePath == dir || filePath.startsWith('$dir/');
}

/// Handles the JSON lines protocol.
class _Server {
  _Server({required this.repository, required this.foodClient});

  final HealthRepository repository;
  final FoodApiClient foodClient;

  Future<void> handleLine(String line) async {
    dynamic decoded;
    try {
      decoded = jsonDecode(line);
    } on Object {
      await _write(_error(null, 'invalid_json', 'Line is not valid JSON.'));
      return;
    }
    if (decoded is! Map<String, dynamic>) {
      await _write(_error(null, 'invalid_request', 'Request must be an object.'));
      return;
    }
    final dynamic requestId = decoded['request_id'];
    final String? op = decoded['op'] as String?;
    if (op == null) {
      await _write(_error(requestId, 'missing_op', 'The request has no "op".'));
      return;
    }
    try {
      final Map<String, dynamic> data = await _dispatch(op, decoded);
      await _write(<String, dynamic>{
        'request_id': requestId,
        'ok': true,
        'data': data,
      });
    } on _RequestError catch (error) {
      await _write(_error(requestId, error.code, error.message));
    } on Object catch (error) {
      await _write(_error(requestId, 'internal_error', '$error'));
    }
  }

  Future<Map<String, dynamic>> _dispatch(
    String op,
    Map<String, dynamic> request,
  ) async {
    switch (op) {
      case 'describe':
        return _describe();
      case 'portable.export':
        if (request['ack_plaintext'] != true) {
          throw const _RequestError(
            'ack_required',
            'portable.export needs "ack_plaintext": true, because the export '
                'is not encrypted.',
          );
        }
        return _export();
      case 'portable.import':
        return _import(request);
      case 'nutrition.day':
        final String? date = request['date'] as String?;
        if (date == null) {
          throw const _RequestError('missing_field', '"date" is required.');
        }
        _requireDate(date);
        return _nutritionDay(date);
      case 'cycle.forecast':
        final String? on = request['on'] as String?;
        if (on == null) {
          throw const _RequestError('missing_field', '"on" is required.');
        }
        _requireDate(on);
        return _cycleForecast(on, request['lang'] as String?);
      case 'food.search':
        final String? query = request['q'] as String?;
        if (query == null) {
          throw const _RequestError('missing_field', '"q" is required.');
        }
        final int page = (request['page'] as num?)?.toInt() ?? 1;
        final FoodSearchResult result =
            await foodClient.search(query, page: page);
        return result.toJson();
      case 'food.lookup':
        final String? barcode = request['barcode'] as String?;
        if (barcode == null) {
          throw const _RequestError('missing_field', '"barcode" is required.');
        }
        final FoodLookupResult result = await foodClient.lookup(barcode);
        return result.toJson();
      default:
        throw _RequestError('unknown_op', 'Unknown op: $op');
    }
  }

  Map<String, dynamic> _export() {
    final Map<String, dynamic> document = PortableFormat.exportDocument(
      repository.data,
      exportedAt: repository.clock.now(),
    );
    return <String, dynamic>{
      'document': document,
      'format': PortableFormat.formatId,
      'version': PortableFormat.version,
      'counts': document['counts'],
    };
  }

  Future<Map<String, dynamic>> _import(Map<String, dynamic> request) async {
    if (request['confirm_replace'] != true) {
      throw const _RequestError(
        'confirm_required',
        'portable.import needs "confirm_replace": true, because it replaces '
            'the working data set.',
      );
    }
    final dynamic raw = request['document'];
    if (raw == null) {
      throw const _RequestError('missing_field', '"document" is required.');
    }
    final Map<String, dynamic> document = raw is String
        ? PortableFormat.decode(raw)
        : raw is Map<String, dynamic>
            ? raw
            : <String, dynamic>{};
    final HealthData data;
    try {
      data = PortableFormat.importDocument(document);
    } on PortableFormatException catch (error) {
      throw _RequestError('invalid_document', error.message);
    }
    await repository.replaceAll(data);
    return <String, dynamic>{
      'imported': true,
      'counts': <String, int>{
        'foods': data.foods.length,
        'journal_entries': data.journalEntries.length,
        'intake_entries': data.intakes.length,
        'periods': data.periods.length,
        'weights': data.weights.length,
        'symptoms': data.symptoms.length,
      },
    };
  }

  Map<String, dynamic> _nutritionDay(String date) {
    final NutritionService service = NutritionService(repository);
    final DayNutrition day = service.day(date);
    return day.toJson();
  }

  Map<String, dynamic> _cycleForecast(String on, String? lang) {
    final CycleService service = CycleService(
      repository,
      strings: lang == 'en' ? Strings.en : Strings.de,
    );
    return service.forecast(on).toJson();
  }

  Map<String, dynamic> _describe() {
    final Map<String, dynamic> sample = PortableFormat.exportDocument(
      _sampleData(),
      exportedAt: repository.clock.now(),
    );
    return <String, dynamic>{
      'protocol': <String, dynamic>{
        'transport': 'JSON lines over stdin/stdout',
        'request': <String, dynamic>{
          'request_id': 'string or number, echoed in the response',
          'op': 'one of the operations listed below',
          'fields': 'operation specific, see below',
        },
        'response': <String, dynamic>{
          'request_id': 'the request_id of the request',
          'ok': 'boolean',
          'data': 'object, present when ok is true',
          'error': <String, dynamic>{
            'code': 'machine readable error code',
            'message': 'human readable message',
          },
        },
        'notes': <String>[
          'One response line is written per request and flushed immediately.',
          'EOF on stdin ends the process.',
          'Nothing but response lines is written to stdout.',
        ],
      },
      'operations': <Map<String, dynamic>>[
        <String, dynamic>{
          'op': 'describe',
          'input': <String, dynamic>{},
          'output': 'this document',
        },
        <String, dynamic>{
          'op': 'portable.export',
          'input': <String, dynamic>{
            'ack_plaintext': 'true, required acknowledgement',
          },
          'output': <String, dynamic>{
            'document': 'the complete export in the portable format',
            'format': PortableFormat.formatId,
            'version': PortableFormat.version,
            'counts': 'number of records per section',
          },
        },
        <String, dynamic>{
          'op': 'portable.import',
          'input': <String, dynamic>{
            'document': 'a portable document (object or JSON string)',
            'confirm_replace': 'true, required confirmation',
          },
          'output': <String, dynamic>{
            'imported': 'true',
            'counts': 'number of imported records per section',
          },
        },
        <String, dynamic>{
          'op': 'nutrition.day',
          'input': <String, dynamic>{'date': 'YYYY-MM-DD'},
          'output': <String, dynamic>{
            'date': 'the calendar day',
            'calories_kcal': 'energy of the day',
            'protein_g': 'grams',
            'carbohydrates_g': 'grams',
            'fat_g': 'grams',
            'saturated_fat_g': 'grams',
            'sugars_g': 'grams',
            'fiber_g': 'grams',
            'salt_g': 'grams',
            'sodium_mg': 'milligrams',
            'caffeine_mg': 'milligrams, food plus extra',
            'water_ml': 'millilitres',
            'nutrients': 'all tracked nutrients of the day, grams (energy kcal)',
            'entries': 'the journal entries of the day',
            'water_entries': 'the water entries of the day',
            'caffeine_entries': 'the additional caffeine entries of the day',
          },
        },
        <String, dynamic>{
          'op': 'cycle.forecast',
          'input': <String, dynamic>{
            'on': 'YYYY-MM-DD',
            'lang': 'optional, "de" (default) or "en"',
          },
          'output': <String, dynamic>{
            'date': 'the assessed day',
            'has_data': 'whether a period was recorded',
            'records_used': 'number of evaluated periods',
            'cycle_day': 'day within the current cycle',
            'average_cycle_length': 'days',
            'min_cycle_length': 'days',
            'max_cycle_length': 'days',
            'average_period_length': 'days',
            'last_period_start': 'YYYY-MM-DD',
            'last_period_end': 'YYYY-MM-DD or null',
            'predicted_next_start': 'YYYY-MM-DD or null',
            'predicted_window_start': 'YYYY-MM-DD or null',
            'predicted_window_end': 'YYYY-MM-DD or null',
            'days_until_predicted_start': 'days',
            'beyond_observed_range': 'boolean',
            'inside_recorded_period': 'boolean',
            'explanation': 'list of sentences explaining the assessment',
          },
        },
        <String, dynamic>{
          'op': 'food.search',
          'input': <String, dynamic>{
            'q': 'search term',
            'page': 'optional page number, default 1',
          },
          'output': <String, dynamic>{
            'query': 'the search term',
            'page': 'the page',
            'page_size': 'results per page',
            'total': 'total number of hits',
            'count': 'number of returned items',
            'items': 'list of products',
          },
        },
        <String, dynamic>{
          'op': 'food.lookup',
          'input': <String, dynamic>{'barcode': 'product barcode'},
          'output': <String, dynamic>{
            'found': 'boolean',
            'message': 'reason when nothing was found',
            'food': 'the product with its nutrients per 100 g',
          },
        },
      ],
      'formats': <Map<String, dynamic>>[
        <String, dynamic>{
          'name': 'portable document',
          'format': PortableFormat.formatId,
          'version': PortableFormat.version,
          'description':
              'JSON object with the sections foods, journal_entries, '
              'intake_entries, periods, weights, symptoms, goals and '
              'settings. This format is used by portable.export and '
              'portable.import.',
          'sections': <String, String>{
            'foods': 'food items with nutrients_per_100 (grams, energy kcal)',
            'journal_entries': 'logged foods with quantity, unit and meal',
            'intake_entries': 'water (ml) and additional caffeine (mg)',
            'periods': 'period records with start_date, end_date, flow',
            'weights': 'weight entries with value_kg',
            'symptoms': 'symptom entries with name and intensity (0..10)',
            'goals': 'optional daily goals',
            'settings': 'language, weight unit, visible areas',
          },
          'example': sample,
        },
        <String, dynamic>{
          'name': 'local store',
          'format': RecordStore.storeFormat,
          'version': RecordStore.storeVersion,
          'description':
              'The working directory holds manifest.json (format metadata and '
              'the HKDF salt, no health data) and records.bin (append only '
              'log of AES-256-GCM encrypted records). The key is derived from '
              'the 32 byte master key of the key file with HKDF-SHA256.',
          'files': <String>['manifest.json', 'records.bin', 'store.lock'],
        },
        <String, dynamic>{
          'name': 'encrypted backup',
          'description':
              'Binary container with the magic "MHBACKUP", the Argon2id '
              'parameters, salt, nonce and the AES-256-GCM encrypted portable '
              'document. Suitable for a fresh installation.',
        },
      ],
      'food_service': <String, dynamic>{
        'base_url': foodClient.baseUrl,
        'user_agent': foodClient.userAgent,
        'search_endpoint': 'GET {base}/cgi/search.pl',
        'lookup_endpoint': 'GET {base}/api/v3.6/product/{barcode}.json',
      },
      'data_dir': repository.store.manifestFile.parent.path,
    };
  }

  HealthData _sampleData() {
    final DateTime today = repository.clock.now();
    final String date = DateMath.format(today);
    final FoodItem food = FoodItem(
      id: 'sample-food-1',
      name: 'Sample food',
      source: FoodSource.custom,
      nutrientsPer100: const NutrientProfile(<String, double>{
        Nutrients.energyKcal: 100,
        Nutrients.protein: 2,
        Nutrients.carbohydrates: 12,
        Nutrients.fat: 3,
      }),
      servingGrams: 50,
      portions: const <Portion>[
        Portion(label: '1 portion', amountGrams: 50, isDefault: true),
      ],
      createdAtMs: today.millisecondsSinceEpoch,
      updatedAtMs: today.millisecondsSinceEpoch,
    );
    return HealthData(
      foods: <String, FoodItem>{food.id: food},
      journalEntries: <JournalEntry>[
        JournalEntry(
          id: 'sample-entry-1',
          foodId: food.id,
          foodName: food.name,
          quantity: 50,
          unit: QuantityUnit.gram,
          meal: MealSlot.lunch,
          date: date,
          loggedAtMs: today.millisecondsSinceEpoch,
          nutrientsPer100Snapshot: food.nutrientsPer100.values,
          createdAtMs: today.millisecondsSinceEpoch,
          updatedAtMs: today.millisecondsSinceEpoch,
        ),
      ],
      intakes: <IntakeEntry>[
        IntakeEntry(
          id: 'sample-intake-1',
          kind: IntakeKind.water,
          amount: 250,
          date: date,
          loggedAtMs: today.millisecondsSinceEpoch,
          createdAtMs: today.millisecondsSinceEpoch,
          updatedAtMs: today.millisecondsSinceEpoch,
        ),
      ],
      periods: <PeriodRecord>[
        PeriodRecord(
          id: 'sample-period-1',
          startDate: DateMath.addDays(date, -28),
          endDate: DateMath.addDays(date, -24),
          flow: FlowStrength.medium,
          createdAtMs: today.millisecondsSinceEpoch,
          updatedAtMs: today.millisecondsSinceEpoch,
        ),
      ],
      weights: <WeightEntry>[
        WeightEntry(
          id: 'sample-weight-1',
          date: date,
          valueKg: 70,
          loggedAtMs: today.millisecondsSinceEpoch,
          createdAtMs: today.millisecondsSinceEpoch,
          updatedAtMs: today.millisecondsSinceEpoch,
        ),
      ],
      symptoms: <SymptomEntry>[
        SymptomEntry(
          id: 'sample-symptom-1',
          name: 'Headache',
          intensity: 4,
          date: date,
          occurredAtMs: today.millisecondsSinceEpoch,
          createdAtMs: today.millisecondsSinceEpoch,
          updatedAtMs: today.millisecondsSinceEpoch,
        ),
      ],
      goals: const Goals(waterMl: 2000, caloriesKcal: 2000),
      settings: const AppSettings(),
    );
  }

  Future<void> _write(Map<String, dynamic> response) async {
    stdout.add(utf8.encode('${jsonEncode(response)}\n'));
    await stdout.flush();
  }

  Map<String, dynamic> _error(dynamic requestId, String code, String message) =>
      <String, dynamic>{
        'request_id': requestId,
        'ok': false,
        'error': <String, dynamic>{'code': code, 'message': message},
      };
}

/// Error that is reported back to the caller.
class _RequestError implements Exception {
  const _RequestError(this.code, this.message);

  final String code;
  final String message;
}

void _requireDate(String value) {
  try {
    DateMath.parse(value);
  } on FormatException {
    throw _RequestError(
      'invalid_date',
      'Dates must use the format YYYY-MM-DD, got: $value',
    );
  }
}
