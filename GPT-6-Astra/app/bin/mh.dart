import 'dart:convert';
import 'dart:io';
import 'package:morphhealth/core/core.dart';

const _usage =
    'mh --data-dir ABS --key-file ABS [--now RFC3339] [--food-base-url HTTPS_ORIGIN] [--food-user-agent STRING]';

Future<void> main(List<String> arguments) async {
  Store? store;
  try {
    final options = <String, String>{};
    const accepted = [
      '--data-dir',
      '--key-file',
      '--now',
      '--food-base-url',
      '--food-user-agent',
    ];
    for (var i = 0; i < arguments.length; i += 2) {
      if (!accepted.contains(arguments[i]) ||
          i + 1 == arguments.length ||
          options.containsKey(arguments[i])) {
        throw const CoreException('invalid_arguments', _usage);
      }
      options[arguments[i]] = arguments[i + 1];
    }
    final dataPath = options['--data-dir'];
    final keyPath = options['--key-file'];
    if (dataPath == null ||
        keyPath == null ||
        !dataPath.startsWith('/') ||
        !keyPath.startsWith('/')) {
      throw const CoreException('invalid_arguments', _usage);
    }
    final fixedClock = options['--now'] == null
        ? null
        : _clock(options['--now']!);
    final keyFile = File(keyPath);
    if (!await keyFile.exists() || await keyFile.length() != 32) {
      throw const CoreException(
        'invalid_key',
        'Key file must exist and contain exactly 32 raw bytes.',
      );
    }
    final directory = Directory(dataPath);
    await directory.create(recursive: true);
    final realDir = await directory.resolveSymbolicLinks();
    final realKey = await keyFile.resolveSymbolicLinks();
    final directoryPrefix = realDir.endsWith('/') ? realDir : '$realDir/';
    if (realKey == realDir || realKey.startsWith(directoryPrefix)) {
      throw const CoreException(
        'invalid_key_location',
        'Key file must be outside data-dir.',
      );
    }
    final environment = File.fromUri(
      Platform.script.resolve('../../ENVIRONMENT.json'),
    );
    Json config = {};
    if (await environment.exists()) {
      config = (jsonDecode(await environment.readAsString()) as Map)
          .cast<String, dynamic>();
    }
    final base = options['--food-base-url'] ?? config['food_api_base_url'];
    final userAgent =
        options['--food-user-agent'] ?? config['food_api_user_agent'];
    if (base is! String || userAgent is! String) {
      throw const CoreException(
        'missing_food_configuration',
        'Provide food API flags or ENVIRONMENT.json alongside app/.',
      );
    }
    final food = FoodApi(baseUrl: base, userAgent: userAgent);
    store = Store(directory, await keyFile.readAsBytes());
    await store.open();
    await for (final line
        in stdin.transform(utf8.decoder).transform(const LineSplitter())) {
      dynamic id;
      Json response;
      try {
        if (line.length > 64 * 1024 * 1024) {
          throw const CoreException(
            'request_too_large',
            'Request exceeds 64 MiB.',
          );
        }
        final decoded = jsonDecode(line);
        if (decoded is! Map || !decoded.containsKey('request_id')) {
          throw const CoreException(
            'invalid_request',
            'A request object with request_id is required.',
          );
        }
        final request = Map<String, dynamic>.from(decoded);
        id = request['request_id'];
        final data = await _dispatch(
          request,
          store,
          food,
          fixedClock ?? DateTime.now(),
        );
        response = {'request_id': id, 'ok': true, 'data': data};
      } on CoreException catch (e) {
        response = {
          'request_id': id,
          'ok': false,
          'error': {'code': e.code, 'message': e.message},
        };
      } on FormatException {
        response = {
          'request_id': id,
          'ok': false,
          'error': {
            'code': 'invalid_json',
            'message': 'Request line is not valid JSON.',
          },
        };
      } on FileSystemException {
        response = {
          'request_id': id,
          'ok': false,
          'error': {
            'code': 'storage_error',
            'message': 'Data could not be committed to local storage.',
          },
        };
      } catch (_) {
        response = {
          'request_id': id,
          'ok': false,
          'error': {
            'code': 'internal_error',
            'message': 'The operation could not be completed.',
          },
        };
      }
      stdout.writeln(jsonEncode(response));
      await stdout.flush();
    }
  } on CoreException catch (e) {
    stderr.writeln(e);
    exitCode = 64;
  } on FileSystemException catch (e) {
    stderr.writeln('storage_error: ${e.message}');
    exitCode = 74;
  } catch (e) {
    stderr.writeln('startup_error: $e');
    exitCode = 70;
  } finally {
    await store?.close();
  }
}

DateTime _clock(String value) {
  if (!RegExp(
    r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,6})?(?:Z|[+-]\d{2}:\d{2})$',
  ).hasMatch(value)) {
    throw const CoreException(
      'invalid_now',
      '--now must be RFC3339 with a timezone.',
    );
  }
  // Reuse the same strict timestamp validation that Android writes through.
  validateItem('weights', {'id': 'clock', 'at': value, 'kg': 1});
  // Preserve the supplied civil date and time for day-context defaults.
  return DateTime.parse(
    value.replaceFirst(RegExp(r'(Z|[+-]\d{2}:\d{2})$'), ''),
  );
}

String _string(Json request, String key, {String? fallback}) {
  final value = request[key] ?? fallback;
  if (value is! String) {
    throw CoreException('invalid_request', '$key must be a string.');
  }
  return value;
}

Future<dynamic> _dispatch(
  Json request,
  Store store,
  FoodApi food,
  DateTime clock,
) async {
  switch (request['op']) {
    case 'describe':
      return _describe(clock);
    case 'portable.export':
      if (request['ack_plaintext'] != true) {
        throw const CoreException(
          'confirmation_required',
          'Export requires ack_plaintext:true. The response contains unencrypted health data.',
        );
      }
      return store.document;
    case 'portable.import':
      if (request['confirm_replace'] != true) {
        throw const CoreException(
          'confirmation_required',
          'Import requires confirm_replace:true.',
        );
      }
      if (request['document'] is! Map) {
        throw const CoreException(
          'invalid_request',
          'document must be a portable JSON object.',
        );
      }
      await store.replace(
        Map<String, dynamic>.from(request['document'] as Map),
      );
      return {
        'replaced': true,
        'counts': {
          for (final c in collections) c: (store.document[c] as List).length,
        },
      };
    case 'nutrition.day':
      return nutritionDay(
        store.document,
        _string(request, 'date', fallback: dateKey(clock)),
      );
    case 'cycle.forecast':
      return cycleForecast(
        store.document,
        _string(request, 'on', fallback: dateKey(clock)),
      );
    case 'food.search':
      final page = request['page'] ?? 1;
      if (page is! int) {
        throw const CoreException(
          'invalid_request',
          'page must be an integer.',
        );
      }
      return food.search(_string(request, 'q'), page: page);
    case 'food.lookup':
      return food.lookup(_string(request, 'barcode'));
    default:
      throw const CoreException(
        'unknown_operation',
        'Unknown op. Use describe for available operations.',
      );
  }
}

Json _describe(DateTime clock) => {
  'application': 'MorphHealth',
  'protocol': 'MH-PERSONAL-3',
  'version': 1,
  'clock': clock.toIso8601String(),
  'today': dateKey(clock),
  'transport': {
    'input':
        'One UTF-8 JSON object per line, request_id and op required. EOF ends the process.',
    'success': {
      'request_id': 'echoed unchanged',
      'ok': true,
      'data': 'operation result',
    },
    'failure': {
      'request_id': 'echoed, null if unreadable',
      'ok': false,
      'error': {
        'code': 'stable machine-readable code',
        'message': 'human-readable English explanation',
      },
    },
    'flush':
        'One response is written and flushed after each request. No stdout banner.',
  },
  'operations': {
    'describe': {
      'input': {},
      'output':
          'This description, all units and an importable exampleDocument.',
    },
    'portable.export': {
      'input': {'ack_plaintext': true},
      'output':
          'Complete portable document object. Unencrypted: protect the output yourself.',
    },
    'portable.import': {
      'input': {
        'document': 'portable document object',
        'confirm_replace': true,
      },
      'output': {
        'replaced': 'boolean',
        'counts': 'object: count per collection',
      },
      'semantics':
          'Validate the entire document, then replace atomically. Failure preserves previous state.',
    },
    'nutrition.day': {
      'input': {'date': 'YYYY-MM-DD; omitted = process clock day'},
      'output': {
        'date': 'YYYY-MM-DD',
        'entries': 'meal snapshots plus totals per entry',
        'drinks': 'water and caffeine records',
        'totals': 'all 31 nutrient keys; known sums or null when all unknown',
        'knownCounts':
            'per nutrient: number of meal entries with a known value',
        'completeness':
            'per nutrient: all meal entries known; null on empty day',
        'waterMl': 'number',
        'extraCaffeineMg': 'number',
        'extraCaffeineEntryCount': 'integer',
        'caffeineMg': 'known food caffeine plus extra caffeine, or null',
        'entryCount': 'number of meals',
      },
    },
    'cycle.forecast': {
      'input': {'on': 'YYYY-MM-DD; omitted = process clock day'},
      'output': {
        'status': 'disabled | insufficient | ready',
        'intervals': 'usable recent start-to-start intervals in days',
        'observedIntervals': 'all last 12 recorded intervals',
        'sampleSize': 'integer',
        'cycleLength': 'personal median in days or null',
        'predictedStart': 'YYYY-MM-DD or null',
        'earliest': 'YYYY-MM-DD or null',
        'latest': 'YYYY-MM-DD or null',
        'confidence': 'insufficient | limited | moderate | stale',
        'explanation': {
          'de': 'German explanation',
          'en': 'English explanation',
        },
        'overdueDays':
            'days after latest estimate, never rolls forward automatically',
      },
      'method':
          'At least 3 starts / 2 usable intervals; exclude spotting and future records; median of last 12 intervals, broad 10–120 day plausibility filter and robust MAD outlier handling. Uncertainty includes observed range and minimum 2–3 day margin. No fixed population cycle or fertility inference.',
    },
    'food.search': {
      'input': {
        'q': '1–200 character text',
        'page': 'positive integer, default 1',
      },
      'output': {
        'page': 'integer',
        'count': 'integer',
        'pageSize': 20,
        'products': 'array of food objects',
        'attribution': 'Open Food Facts attribution',
      },
      'network':
          'Explicit CLI request authorizes this read; Android additionally requires the onlineFood setting.',
    },
    'food.lookup': {
      'input': {'barcode': 'string of 4–24 digits'},
      'output':
          'Food object or null if absent; network/server errors return ok:false.',
    },
  },
  'formats': {
    'portable': {
      'format': 'morphhealth',
      'version': 1,
      'encoding': 'UTF-8 JSON',
      'topLevel': {
        'format': 'morphhealth',
        'version': 1,
        'settings': 'object',
        for (final c in collections) c: 'array',
      },
      'settings': {
        'language': 'de | en',
        'weightUnit': 'kg | lb (storage is kg)',
        'onlineFood': 'boolean',
        'cyclePredictions': 'boolean; false means diary-only',
        'visible': 'nutrition, cycle, weight, symptoms booleans',
        'goals':
            'water (ml), energy (kcal), protein/carbs/fat (g): positive number or null',
      },
      'food': {
        'id': 'unique string',
        'name': 'non-empty string',
        'source': 'custom | off',
        'barcode': 'optional string',
        'brand': 'optional string',
        'basis': 'g | ml',
        'servingSize': 'positive size in basis units, or null',
        'nutrients': 'values per 100 basis units, see nutrients metadata',
        'favorite': 'boolean',
      },
      'meal': {
        'id': 'unique string',
        'food': 'complete food snapshot; independent of later food edits',
        'amount': 'positive number',
        'unit': 'g | ml | serving; mass/volume must match food.basis',
        'meal': 'breakfast | lunch | dinner | snack',
        'at': 'ISO8601 timestamp',
        'note': 'string',
      },
      'drink': {
        'id': 'unique string',
        'kind': 'water | caffeine',
        'amount': 'positive ml for water or mg for caffeine',
        'at': 'ISO8601 timestamp',
        'note': 'string',
      },
      'period': {
        'id': 'unique string',
        'start': 'YYYY-MM-DD inclusive',
        'end': 'YYYY-MM-DD inclusive, or null = ongoing',
        'flow': 'spotting | light | medium | heavy',
        'note': 'string',
      },
      'weight': {
        'id': 'unique string',
        'at': 'ISO8601 timestamp',
        'kg': 'positive number',
        'note': 'string',
      },
      'symptom': {
        'id': 'unique string',
        'at': 'ISO8601 timestamp',
        'name': 'non-empty string',
        'intensity': 'integer 0–10',
        'note': 'string',
      },
      'validation':
          'Unknown fields and versions, duplicate IDs per collection, invalid dates, overlap between non-spotting periods, negative quantities, nonfinite numbers and incompatible units are rejected. Missing notes/source/favorite and known settings are normalized. Required arrays must exist. Maximum 100000 total records and 64 MiB plaintext.',
      'calendar':
          'Timestamps retain their original local calendar prefix; no conversion to UTC shifts the selected day. Date arithmetic ignores DST by using UTC civil midnights.',
      'unknown':
          'Missing/null nutrient = unknown; numeric zero = known zero. Partial totals sum known records; inspect knownCounts/completeness.',
      'nutrients': [
        for (final n in nutrients)
          {'key': n.key, 'de': n.de, 'en': n.en, 'unit': n.unit},
      ],
    },
    'local': {
      'file': 'data-dir/health.mhenc',
      'compression':
          'gzip before encryption; absent header accepts original uncompressed v1; decompressed document limited to 64 MiB',
      'encryption':
          'AES-256-GCM, random 12-byte nonce, 16-byte tag, authenticated version/type header',
      'key':
          '32 raw bytes from key-file outside data-dir; never generated or printed by CLI',
      'writes':
          'serialized, ciphertext temp + atomic rename, cooperative exclusive lock; corrupt or wrong-key files are never overwritten',
    },
    'backup': {
      'format': 'morphhealth-encrypted',
      'kind': 'backup',
      'compression':
          'gzip; original v1 backups with no compression header remain readable; header is authenticated',
      'version': 1,
      'cipher': 'AES-256-GCM',
      'kdf':
          'PBKDF2-HMAC-SHA256 / 600000 iterations / random 16-byte salt / 256-bit output',
      'passphrase': '10–1024 exact UTF-8 characters; no normalization',
      'portability':
          'Contains complete portable document and restores under a fresh installation key; no original key needed.',
    },
  },
  'exampleDocument': exampleDocument(),
  'documentation': [
    'docs/FORMAT.md',
    'docs/SECURITY-CORE.md',
    'README.md',
    'SECURITY.md',
  ],
};
