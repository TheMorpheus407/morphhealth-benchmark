import '../cycle/cycle_forecast.dart';
import '../cycle/symptom_patterns.dart';
import '../model/app_data.dart';
import '../model/entries.dart';
import '../model/food.dart';
import '../model/nutrients.dart';
import '../model/settings.dart';
import '../nutrition/nutrition_day.dart';
import '../nutrition/off_client.dart';
import '../portable/backup.dart';
import '../portable/example_document.dart';
import '../store/crypto.dart';
import '../store/data_store.dart';
import '../util/dates.dart';
import '../util/json_reader.dart';
import '../version.dart';

/// The answer of the `describe` operation: a complete description of the
/// maintenance access, of all data formats and of every input and output,
/// with an example document that can be imported as it is.
Map<String, dynamic> describeAccess({
  required String foodBaseUrl,
  required String foodUserAgent,
  required LocalDateTime now,
  required bool clockIsFixed,
}) {
  final example = exampleDocument();
  final exampleData = AppData.fromDocument(example, IssueLog(), now: now)!;
  final exampleDay = exampleToday.addDays(-1);
  final exampleNutrition = NutritionDay.compute(exampleData, exampleDay);
  final exampleForecast = cycleAssessment(exampleData, exampleToday);

  return {
    'application': {
      'name': 'MorphHealth',
      'version': morphHealthVersion,
      'summary':
          'Local maintenance access (JSON Lines) to the data and '
          'functions of the MorphHealth app. Every operation calls the same '
          'Dart code the Android app runs; there is no second implementation.',
    },
    'invocation': {
      'command':
          './mh --data-dir ABS --key-file ABS [--now RFC3339] '
          '[--food-base-url HTTPS_ORIGIN] [--food-user-agent STRING]',
      'options': {
        '--data-dir':
            'Absolute path of the persistent working data set. '
            'Created if missing. Holds only encrypted files '
            '(see formats.store).',
        '--key-file':
            'Absolute path of a file with exactly 32 raw bytes '
            '(see formats.key_file). Must lie outside --data-dir. It is only '
            'read, never written.',
        '--now':
            'Sets the business clock of this process, for example '
            '2026-09-23T08:00:00+02:00. The clock stands still at this '
            'value. Date and time are taken exactly as written; they are not '
            'converted to the time zone of the host. Without this option the '
            'system clock in local time is used.',
        '--food-base-url':
            'HTTPS origin of the food service (scheme, host, '
            'optional port). Default: food_api_base_url from '
            'ENVIRONMENT.json next to the mh script, otherwise '
            '${FoodApiClient.productionOrigin}.',
        '--food-user-agent':
            'User-Agent sent to the food service. Default: '
            'food_api_user_agent from ENVIRONMENT.json, otherwise '
            '"MorphHealth/$morphHealthVersion".',
      },
      'current': {
        'now': now.toIso(),
        'clock': clockIsFixed ? 'fixed by --now' : 'system clock',
        'food_base_url': foodBaseUrl,
        'food_user_agent': foodUserAgent,
      },
      'exit':
          'End of input (EOF) ends the process with exit code 0. Invalid '
          'command line options end it with exit code 64 and a message on '
          'stderr; nothing is written to stdout in that case.',
    },
    'protocol': {
      'transport':
          'One JSON object per line on stdin, one JSON object per '
          'line on stdout, UTF-8. Each answer is written and flushed before '
          'the next request is read. Nothing else is written to stdout; '
          'diagnostics go to stderr.',
      'request': {
        'request_id':
            'Required. String or number chosen by the caller; '
            'returned unchanged.',
        'op': 'Required. Name of the operation, see "operations".',
        '…':
            'Further members depend on the operation. Unknown members are '
            'ignored.',
      },
      'response_success': {'request_id': '…', 'ok': true, 'data': '…'},
      'response_failure': {
        'request_id': '…',
        'ok': false,
        'error': {
          'code': 'stable machine-readable code',
          'message': 'explanation in English',
          'details': 'optional object with further information',
        },
      },
      'error_codes': {
        'invalid_json': 'The line is not a JSON object. request_id is null.',
        'invalid_request':
            'request_id or op is missing or has the wrong '
            'type.',
        'unknown_op': 'The operation does not exist.',
        'invalid_argument':
            'A member of the request is missing or invalid; '
            'details.field names it.',
        'acknowledgement_required':
            'portable.export without '
            '"ack_plaintext": true.',
        'confirmation_required':
            'portable.import without '
            '"confirm_replace": true. Nothing was changed.',
        'import_rejected':
            'The document has errors; details.errors lists '
            'them with JSON paths. Nothing was changed.',
        'store_wrong_key':
            'The key file does not open the data directory '
            '(or its files were modified).',
        'store_corrupt': 'The data directory is damaged or incomplete.',
        'store_unsupported':
            'The data directory was written by a newer '
            'version.',
        'store_io': 'The data directory cannot be read or written.',
        'key_file_invalid':
            'The key file is missing, unreadable, not '
            'exactly 32 bytes long or lies inside the data directory.',
        'online_disabled':
            'The stored settings switch the online food '
            'lookup off ("online_food_search": "disabled").',
        'food_network': 'The food service cannot be reached.',
        'food_timeout': 'The food service did not answer in time.',
        'food_tls': 'The certificate of the food service was not accepted.',
        'food_rate_limited':
            'The food service asked to slow down '
            '(HTTP 429).',
        'food_server_error': 'The food service failed (HTTP 5xx).',
        'food_bad_response':
            'The answer of the food service does not '
            'follow the contract.',
        'internal_error': 'Unexpected failure; message has details.',
      },
      'persistence':
          'All changes are written to --data-dir before the '
          'answer is sent. A later process with the same --data-dir and '
          '--key-file sees them. Operations lock the data directory, so '
          'several processes may use it one after another or at the same '
          'time.',
    },
    'operations': {
      'describe': {
        'purpose': 'Returns this description.',
        'input': <String, dynamic>{},
        'output': 'This object.',
      },
      'portable.export': {
        'purpose': 'Complete export of all user data.',
        'input': {
          'ack_plaintext':
              'Required, must be true. Acknowledges that the '
              'answer contains all health data unencrypted.',
        },
        'output':
            'The export document itself (formats.export). It can be '
            'passed unchanged as "document" to portable.import.',
        'example_request': {
          'request_id': 1,
          'op': 'portable.export',
          'ack_plaintext': true,
        },
      },
      'portable.import': {
        'purpose':
            'Replaces the complete working data set by a document in '
            'the export format.',
        'input': {
          'document':
              'Required. An export document (formats.export) as a '
              'JSON object. A string that contains the JSON text is accepted '
              'as well.',
          'confirm_replace':
              'Required, must be true. Confirms that all '
              'existing data are replaced.',
        },
        'behaviour':
            'The whole document is validated first. If it has any '
            'error the answer is import_rejected and the existing data stay '
            'unchanged. Otherwise everything is replaced in one atomic step.',
        'output': {
          'replaced': 'true',
          'imported_at': 'business clock at the time of the import',
          'counts': 'records per collection after the import',
          'entries_total': 'sum of counts without foods',
          'previous_counts': 'records per collection that were replaced',
          'warning_count': 'number of warnings',
          'warnings':
              'list of {path, message}: tolerated issues such as '
              'unknown members',
        },
        'example_request': {
          'request_id': 2,
          'op': 'portable.import',
          'confirm_replace': true,
          'document': '<export document, for example example_document>',
        },
        'example_response_data': {
          'replaced': true,
          'imported_at': now.toIso(),
          'counts': exampleData.counts,
          'entries_total': exampleData.entryCount,
          'previous_counts': AppData().counts,
          'warning_count': 0,
          'warnings': <Object>[],
        },
      },
      'nutrition.day': {
        'purpose': 'The nutrition figures the app shows for one day.',
        'input': {'date': 'Required. Calendar day as YYYY-MM-DD.'},
        'output': {
          'date': 'the requested day',
          'entry_count': 'number of food entries on that day',
          'meals':
              'always four objects in the order breakfast, lunch, '
              'dinner, snack: {meal, entries[], totals{}}',
          'meals[].entries[]': {
            'id': 'id of the intake record',
            'at': 'local date-time',
            'meal': Meal.codes.join(' | '),
            'food_id': 'id of the food',
            'food_name': 'name of the food',
            'brand': 'brand or null',
            'amount': 'amount as entered',
            'unit': 'g | ml | portion',
            'portion_size':
                'only for unit portion: size of one portion in '
                'quantity_unit',
            'quantity': 'consumed quantity in quantity_unit',
            'quantity_unit': 'g or ml: the basis unit of the food',
            'nutrients':
                'amounts of this entry: {nutrient key: number}; '
                'only nutrients the food has a value for',
            'estimated_nutrients':
                'optional list of nutrient keys whose '
                'value is an estimate',
            'note': 'optional',
          },
          'meals[].totals': 'sum per nutrient for the meal; all 31 keys',
          'totals':
              'sum per nutrient for the day; all 31 keys. A nutrient '
              'that no entry has a value for is 0; see coverage.',
          'coverage':
              'per nutrient key: {entries_with_value, '
              'entries_total, estimated_entries}. Tells how many entries '
              'contributed to a total, because a missing value is unknown, '
              'not zero.',
          'water': '{total_ml, entries[{id, at, amount_ml}]}',
          'caffeine':
              '{total_mg, from_food_mg, additional_mg, entries[{id, '
              'at, amount_mg, label?}]}. total_mg = caffeine contained in '
              'the foods of the day (totals.caffeine_mg) + separately '
              'recorded caffeine.',
          'goals':
              'for water_ml, energy_kcal, protein_g, carbohydrates_g '
              'and fat_g: null if no goal is set, otherwise {goal, actual, '
              'remaining, percent}',
        },
        'calculation':
            'quantity = amount (same unit as the basis of the '
            'food), amount × portion_size (unit portion), or converted '
            'between g and ml with density_g_per_ml of the food (1 if not '
            'set). Nutrient amount = value per 100 × quantity / 100. Salt '
            'and sodium are derived from each other when a food states only '
            'one (salt_g = sodium_mg × 2.5 / 1000). Numbers are rounded to '
            'six decimal places.',
        'example_request': {
          'request_id': 3,
          'op': 'nutrition.day',
          'date': exampleDay.toString(),
        },
        'example_response_data': exampleNutrition.toJson(),
      },
      'cycle.forecast': {
        'purpose':
            'The personal cycle assessment of the app for a viewing '
            'day.',
        'input': {'on': 'Required. Viewing day as YYYY-MM-DD.'},
        'semantics':
            'The answer is what the app shows on the day "on", '
            'given the stored periods. Periods that start after "on" are '
            'ignored (reported in ignored_future_periods). The result does '
            'not depend on --now.',
        'output': {
          'on': 'the viewing day',
          'status': {
            'disabled':
                'estimates are switched off (settings.'
                'cycle_predictions = false); only "today" is filled',
            'no_data': 'no period recorded up to "on"',
            'insufficient_data':
                'fewer than two period starts and no '
                'typical_cycle_length_days in the settings',
            'upcoming': 'an estimate exists; "on" lies before its window',
            'due': '"on" lies inside the window',
            'late': 'the window has passed without a new period',
            'stale':
                'the last recorded start is more than 1.6 × the '
                'typical cycle length ago; no estimate is given',
          },
          'predictions_enabled': 'settings.cycle_predictions',
          'today': {
            'cycle_day':
                'day in the current cycle; 1 = first day of the '
                'last period',
            'in_period': 'whether "on" is a day of the last period',
            'period_day': 'day in the current period or null',
            'current_period_expected_end': 'date or null',
            'last_period':
                '{id, start, end, length_days, end_missing} or '
                'null',
          },
          'next_period':
              'null without estimate, otherwise {expected_start, '
              'window{earliest, latest}, expected_end, expected_length_days, '
              'days_until_expected_start, days_until_window, days_late}',
          'following_periods':
              'up to three further periods with wider '
              'windows: [{expected_start, window, expected_end, '
              'expected_length_days}]; empty when late or stale',
          'basis': {
            'method': 'weighted_mean_of_recent_cycles',
            'cycles_recorded': 'cycles up to "on"',
            'cycles_considered':
                'the most recent ones, at most '
                '${CycleForecast.recentCycles}',
            'cycles_used': 'cycles that entered the estimate',
            'cycles':
                '[{start, next_start, length_days, used, weight?, '
                'excluded_reason?}] with excluded_reason too_short | '
                'too_long | likely_missing_entry | unusually_short',
            'typical_cycle_length_days': 'rounded weighted mean',
            'mean_cycle_length_days': 'weighted mean',
            'shortest_cycle_days / longest_cycle_days': 'of the used cycles',
            'spread_sd_days': 'standard deviation behind the window',
            'window_half_width_days': 'days before and after expected_start',
            'regularity':
                'very_regular | regular | variable | '
                'very_variable (range of the used cycles ≤ 2, ≤ 5, ≤ 9, '
                '> 9 days)',
            'typical_period_length_days':
                'median of the last completed '
                'periods, 5 without any',
            'period_length_basis': 'history | default',
            'stated_typical_cycle_length_days': 'from the settings or null',
            'stated_length_used':
                'true while fewer than three own cycles '
                'exist and a stated length is set',
            'confidence': 'low | medium | high',
          },
          'backtest':
              'null or {evaluated_cycles, start_within_window, '
              'mean_absolute_error_days}: the same calculation applied to '
              'earlier cycles',
          'patterns':
              'symptoms that recur around period starts: [{symptom, '
              'phase (before_period | during_period), cycles_with_symptom, '
              'cycles_considered, typical_offset_days, mean_intensity}]',
          'explanation':
              '{de: [paragraphs], en: [paragraphs]}: the '
              'explanation the app shows',
          'disclaimer': '{de, en}',
          'ignored_future_periods': 'periods starting after "on"',
        },
        'method': [
          'Cycles are the distances between consecutive period starts on or '
              'before "on"; the ${CycleForecast.recentCycles} most recent '
              'are considered.',
          'Cycles shorter than ${CycleForecast.minPlausibleLength} or '
              'longer than ${CycleForecast.maxPlausibleLength} days are '
              'excluded. With at least ${CycleForecast.outlierMinCycles} '
              'cycles, those above ${CycleForecast.outlierRatio} × median '
              'or below median / ${CycleForecast.outlierRatio} are excluded '
              'too.',
          'Typical length = weighted mean; the weight falls by 15 % per '
              'cycle into the past. expected_start = start of the last '
              'period + rounded typical length.',
          'Window half width = max(1, round(1.2816 × sd)); sd combines the '
              'weighted variance of the used cycles with a prior of '
              '${CycleForecast.priorSd} days (weight '
              '${CycleForecast.priorWeight.toInt()}) and grows when few '
              'cycles are available.',
          'expected_end = expected_start + typical period length − 1.',
        ],
        'limits':
            'Planning aid based on the recorded history only. No '
            'ovulation or fertility calculation, no diagnosis, not suitable '
            'for contraception.',
        'example_request': {
          'request_id': 4,
          'op': 'cycle.forecast',
          'on': exampleToday.toString(),
        },
        'example_response_data': exampleForecast,
      },
      'food.search': {
        'purpose': 'Name search in Open Food Facts, as used by the app.',
        'input': {
          'q': 'Required. Search text, 2 to 200 characters.',
          'page': 'Optional, integer ≥ 1. Default 1.',
        },
        'upstream':
            'GET {food_base_url}/cgi/search.pl?search_terms={q}'
            '&search_simple=1&action=process&json=1&page={page}'
            '&page_size=${FoodApiClient.pageSize}&fields=…',
        'output': {
          'query': 'the search text as sent',
          'page': 'page number',
          'page_size': '${FoodApiClient.pageSize}',
          'total_count': 'matching products in total',
          'page_count':
              'number of pages = floor((total_count − 1) / '
              'page_size) + 1',
          'has_more': 'whether a further page exists',
          'products': 'list of products, see product',
        },
        'product': _productDescription,
        'example_request': {
          'request_id': 5,
          'op': 'food.search',
          'q': 'haferflocken',
          'page': 1,
        },
      },
      'food.lookup': {
        'purpose':
            'Product lookup by barcode in Open Food Facts, as used '
            'by the app.',
        'input': {
          'barcode':
              'Required. 7 to 14 digits as a string (a number is '
              'accepted). Spaces and hyphens are ignored.',
        },
        'upstream':
            'GET {food_base_url}/api/v3.6/product/{barcode}.json'
            '?fields=…',
        'output': {
          'requested_barcode': 'the digits that were asked for',
          'found': 'true or false',
          'reason':
              'null when found, otherwise product_not_found | '
              'invalid_code | other_product_type',
          'product': 'null or a product, see product',
        },
        'product': _productDescription,
        'example_request': {
          'request_id': 6,
          'op': 'food.lookup',
          'barcode': '4000000000013',
        },
      },
    },
    'food_service': {
      'contract':
          'Read-only Open Food Facts API. Product lookups use API '
          'v3.6 (product schema 1004, nutrition facts in '
          '"nutrition.aggregated_set"); the search endpoint still answers '
          'in the older schema ("nutriments"). Both shapes are read.',
      'fields_projection': FoodApiClient.fields,
      'normalization':
          'Open Food Facts states masses in grams. They are '
          'converted to the unit of each nutrient key (g, mg, µg). Energy '
          'is taken in kcal, or converted from kJ (÷ 4.184) when only kJ is '
          'given. Values per serving are scaled to 100 g or 100 ml when the '
          'serving size is known. Impossible values (more than 100 g of a '
          'nutrient per 100 g) are dropped.',
      'robustness':
          'Timeout 10 s per attempt, at most 3 attempts with '
          'exponential backoff for network errors, timeouts, HTTP 429 and '
          '5xx; Retry-After up to 5 s is honoured. Redirects to another '
          'origin are never followed. TLS certificates are always verified.',
      'user_control':
          'In the app the lookup has to be switched on by the '
          'user. The maintenance access performs lookups on request unless '
          'the stored settings say "online_food_search": "disabled".',
    },
    'formats': {
      'export': _exportFormat(),
      'backup': {
        'name': BackupCodec.format,
        'version': BackupCodec.version,
        'file_extension': BackupCodec.fileExtension,
        'description':
            'Passphrase-protected backup, created and restored '
            'in the app (Einstellungen → Daten). A JSON envelope around the '
            'encrypted, gzip-compressed export document.',
        'members': {
          'format': '"${BackupCodec.format}"',
          'version': '${BackupCodec.version}',
          'created_at': 'local date-time',
          'app_version': 'version of the app that wrote the file',
          'kdf':
              '{algorithm: "argon2id", version: 19, memory_kib, '
              'iterations, parallelism, salt (base64, 16 bytes)}; written '
              'with memory_kib ${Argon2Params.standard.memoryKib}, '
              'iterations ${Argon2Params.standard.iterations}, parallelism '
              '${Argon2Params.standard.parallelism}',
          'cipher': '"xchacha20-poly1305"',
          'compression': '"gzip"',
          'data':
              'base64 of nonce (24 bytes) || ciphertext || tag '
              '(16 bytes)',
        },
        'key': 'Argon2id(passphrase as UTF-8, salt) → 32 bytes',
        'associated_data':
            'format, version, created_at, app_version, '
            'kdf.algorithm, kdf.version, kdf.memory_kib, kdf.iterations, '
            'kdf.parallelism, kdf.salt, cipher, compression: joined with '
            '"\\n" as UTF-8',
        'plaintext': 'gzip(UTF-8 JSON of an export document)',
        'note':
            'The maintenance access has no backup operation; '
            'portable.export and portable.import carry the same content '
            'unencrypted.',
      },
      'store': {
        'description':
            'Content of --data-dir (and of the app\'s private '
            'data directory). All files are encrypted with '
            'XChaCha20-Poly1305 under a key derived from the 32-byte master '
            'key: HKDF-SHA-256(key, salt = "MorphHealth", info = '
            '"morphhealth/store/v1").',
        'files': {
          EncryptedFileStore.snapshotName:
              '"MHSNAP1\\n" (8 bytes) || '
              'generation (16 random bytes) || nonce (24) || ciphertext || '
              'tag (16). Associated data: the first 24 bytes. Plaintext: '
              'gzip(JSON {"schema": 1, "document": <export document>, '
              '"local": {…}}). Replaced atomically (temporary file, sync, '
              'rename).',
          EncryptedFileStore.journalName:
              '"MHJRNL1\\n" || generation, '
              'followed by records: length (uint32, big endian) || nonce '
              '(24) || ciphertext || tag (16). Associated data of record '
              'n: "MHJRNL1\\n" || generation || n (uint64, big endian). '
              'Plaintext: JSON array of operations {op: put | set | del, '
              'c: collection, v: record | id: key}. One record per change, '
              'synced to disk before the change is confirmed.',
          EncryptedFileStore.lockName:
              'empty; carries the advisory lock '
              'between processes',
        },
        'recovery':
            'A journal that belongs to an older snapshot '
            '(different generation) is ignored. An incomplete last record '
            'is dropped. After '
            '${EncryptedFileStore.compactAfterRecords} records or '
            '${EncryptedFileStore.compactAfterBytes ~/ 1024} KiB the '
            'journal is folded into a new snapshot.',
      },
      'key_file': {
        'description':
            'Exactly 32 raw bytes (no hex, no line break): the '
            'master key of the data directory. Create one with: head -c 32 '
            '/dev/urandom > /abs/path/mh.key',
        'rules': [
          'The file must exist, be readable and be exactly 32 bytes long.',
          'It must not lie inside --data-dir.',
          'mh only reads it. The key is kept in memory and never written '
              'to the data directory, to stdout or to stderr.',
          'A data directory can only be opened with the key it was created '
              'with; another key yields store_wrong_key and changes '
              'nothing.',
          'On Android the app creates its own random master key and keeps '
              'it wrapped by a key of the Android Keystore.',
        ],
      },
    },
    'nutrients': [
      for (final n in Nutrients.all)
        {
          'key': n.key,
          'unit': n.unit,
          'group': n.group.name,
          'label_de': n.labelDe,
          'label_en': n.labelEn,
          'open_food_facts_ids': n.offIds,
        },
    ],
    'example_document': example,
    'example_session': [
      {'request_id': 'a', 'op': 'describe'},
      {
        'request_id': 'b',
        'op': 'portable.import',
        'confirm_replace': true,
        'document': '<example_document>',
      },
      {'request_id': 'c', 'op': 'nutrition.day', 'date': exampleDay.toString()},
      {
        'request_id': 'd',
        'op': 'cycle.forecast',
        'on': exampleToday.toString(),
      },
      {'request_id': 'e', 'op': 'food.search', 'q': 'haferflocken', 'page': 1},
      {'request_id': 'f', 'op': 'food.lookup', 'barcode': '4000000000013'},
      {'request_id': 'g', 'op': 'portable.export', 'ack_plaintext': true},
    ],
  };
}

/// The cycle assessment exactly as `cycle.forecast` returns it: the forecast
/// of the app plus recurring symptom patterns.
Map<String, dynamic> cycleAssessment(AppData data, Day on) {
  final forecast = CycleForecast.compute(
    data.periods,
    on,
    predictionsEnabled: data.settings.cyclePredictions,
    statedTypicalLength: data.settings.typicalCycleLengthDays,
  );
  final json = forecast.toJson();
  json['patterns'] = [
    if (data.settings.cyclePredictions)
      for (final p in symptomPatterns(data, on)) p.toJson(),
  ];
  return json;
}

const Map<String, String> _productDescription = {
  'barcode': 'barcode as normalized by the service',
  'name': 'product name (German or English name preferred if present)',
  'name_available':
      'false if the service has no name; "name" then holds '
      'the brand or the barcode',
  'brand': 'up to three brands, comma separated, or null',
  'quantity': 'package size as printed, or null',
  'basis': '100g | 100ml: reference quantity of "nutrients"',
  'serving_size': 'size of one serving in serving_unit, or null',
  'serving_unit': 'g | ml, or null',
  'serving_label': 'serving description as printed, or null',
  'prepared': 'true if the values describe the prepared product',
  'has_nutrition': 'false if the product has no usable nutrition facts',
  'nutrients':
      '{nutrient key: amount per 100 g or 100 ml}; keys and units '
      'as in "nutrients"',
  'estimated_nutrients': 'nutrient keys whose value is an estimate',
  'source': '"open_food_facts"',
  'schema_version':
      'product schema version reported by the service, or '
      'null',
  'notes': 'optional remarks about ignored values',
};

Map<String, dynamic> _exportFormat() => {
  'name': AppData.documentFormat,
  'version': AppData.documentVersion,
  'media_type': 'application/json',
  'encoding': 'UTF-8',
  'description':
      'One JSON object with the complete user data. Used by '
      'portable.export, portable.import, by the export and import in '
      'the app and as the content of backups.',
  'conventions': {
    'date': 'YYYY-MM-DD, a calendar day without time zone.',
    'date_time':
        'YYYY-MM-DDTHH:MM:SS, optionally followed by a UTC '
        'offset (+01:00 or Z). Diary times are local wall-clock times: '
        'the day and time are taken as written and an offset never '
        'moves an entry to another day. A date without time is '
        'accepted and placed at 12:00 (reported as a warning).',
    'ids':
        'Any non-empty string up to 100 characters, unique within '
        'its collection. Optional on import: a missing id is generated '
        '(UUID v4).',
    'optional_members':
        'Optional members may be omitted or null. '
        'Unknown members are ignored and reported as warnings.',
    'timestamps':
        'created_at and updated_at are optional on import '
        'and default to the business clock.',
    'order':
        'The export sorts every collection (by time, then id), so '
        'that equal data give equal documents.',
  },
  'root': {
    'format': 'Required. "${AppData.documentFormat}".',
    'version': 'Required. ${AppData.documentVersion}.',
    'exported_at': 'date_time of the export (informational).',
    'app_version': 'version of the writing app (informational).',
    'settings':
        'object, see settings. Missing members keep their '
        'defaults.',
    'goals': 'object, see goals.',
    'foods': 'array, see foods.',
    'intake': 'array, see intake.',
    'water': 'array, see water.',
    'caffeine': 'array, see caffeine.',
    'weights': 'array, see weights.',
    'symptoms': 'array, see symptoms.',
    'periods': 'array, see periods.',
    'cycle_days': 'array, see cycle_days.',
  },
  'settings': {
    'language': '${Settings.languages.join(' | ')}. Default de.',
    'weight_unit':
        '${Settings.weightUnits.join(' | ')}: unit for '
        'entering and showing weights. Default kg. Stored weights are '
        'always kilograms.',
    'theme': '${Settings.themes.join(' | ')}. Default system.',
    'overview_sections':
        'array with any of '
        '${Area.codes.join(', ')}: the areas shown on the overview. '
        'Default: all four.',
    'cycle_predictions':
        'boolean. false: the period tracker is a '
        'diary only, without estimates. Default true.',
    'typical_cycle_length_days':
        'integer '
        '${Settings.minCycleLength}–${Settings.maxCycleLength} or null: '
        'the cycle length the user states as typical; used only while '
        'fewer than three own cycles are recorded.',
    'online_food_search':
        '${OnlineFoodSearch.codes.join(' | ')}. ask: '
        'not decided yet. Default ask.',
    'water_quick_amounts_ml':
        'array of 1 to 6 integers 10–5000: '
        'amounts offered for one-tap water entries. Default '
        '${Settings.defaultWaterQuickAmounts}.',
  },
  'goals': {
    'description':
        'Voluntary daily goals; null or missing means no '
        'goal.',
    'water_ml': 'number > 0',
    'energy_kcal': 'number > 0',
    'protein_g': 'number > 0',
    'carbohydrates_g': 'number > 0',
    'fat_g': 'number > 0',
  },
  'foods': {
    'description':
        'Own foods and products kept from Open Food Facts. '
        'Diary entries refer to foods by id.',
    'id': 'string',
    'source': '${FoodSource.codes.join(' | ')}. Default custom.',
    'name': 'Required. String up to 200 characters.',
    'brand': 'optional string',
    'barcode': 'optional string of digits',
    'basis':
        '${FoodBasis.codes.join(' | ')}: reference quantity of '
        'nutrients. Default 100g.',
    'serving_size':
        'optional number > 0: size of one portion in g '
        '(basis 100g) or ml (basis 100ml)',
    'serving_label':
        'optional description of a portion, for example '
        '"1 Scheibe"',
    'package_quantity': 'optional package size as printed',
    'density_g_per_ml':
        'optional number 0.05–25 for converting '
        'between g and ml; 1 if missing',
    'nutrients':
        'object {nutrient key: number ≥ 0} per 100 g or '
        '100 ml. Keys and units: see "nutrients" (31 keys). A missing '
        'key means unknown, not zero.',
    'estimated_nutrients':
        'optional array of nutrient keys whose '
        'value is an estimate',
    'prepared':
        'optional boolean: values describe the prepared '
        'product',
    'favorite': 'boolean. Default false.',
    'archived':
        'optional boolean: deleted by the user but kept '
        'because entries refer to it',
    'note': 'optional string',
    'created_at / updated_at': 'optional date_time',
    'fetched_at':
        'optional date_time of the last fetch from Open Food '
        'Facts',
  },
  'intake': {
    'description': 'Consumed foods (Verzehreinträge).',
    'id': 'string',
    'food_id': 'Required. Id of a record in foods.',
    'at': 'Required. date_time of the consumption.',
    'meal':
        '${Meal.codes.join(' | ')}. If missing it is derived from '
        'the time of day.',
    'amount': 'Required. Number > 0 in unit.',
    'unit': 'Required. ${AmountUnit.codes.join(' | ')}.',
    'portion_size':
        'For unit portion: size of one portion in the '
        'basis unit of the food (g or ml). May be omitted if the food '
        'has a serving_size, which is then used.',
    'note': 'optional string',
    'created_at / updated_at': 'optional date_time',
  },
  'water': {
    'id': 'string',
    'at': 'Required. date_time.',
    'amount_ml': 'Required. Number > 0, at most 20000.',
    'created_at / updated_at': 'optional date_time',
  },
  'caffeine': {
    'description':
        'Caffeine taken in addition to logged foods '
        '(coffee, tea, tablets …).',
    'id': 'string',
    'at': 'Required. date_time.',
    'amount_mg': 'Required. Number > 0, at most 5000.',
    'label': 'optional string, for example "Espresso"',
    'created_at / updated_at': 'optional date_time',
  },
  'weights': {
    'id': 'string',
    'date': 'Required. date.',
    'weight_kg':
        'Required. Number ${WeightEntry.minKg.toInt()}–'
        '${WeightEntry.maxKg.toInt()}. Always kilograms (1 lb = '
        '${WeightEntry.kgPerLb} kg).',
    'note': 'optional string',
    'created_at / updated_at': 'optional date_time',
  },
  'symptoms': {
    'id': 'string',
    'name':
        'Required. Free text up to 80 characters. Entries whose '
        'names differ only in case or spacing count as the same '
        'symptom.',
    'intensity': 'Required. Integer 0–10.',
    'at': 'Required. date_time.',
    'note': 'optional string',
    'created_at / updated_at': 'optional date_time',
  },
  'periods': {
    'description': 'Menstrual periods. Periods must not overlap.',
    'id': 'string',
    'start': 'Required. date of the first day.',
    'end':
        'date of the last day (inclusive), or null while the '
        'period is running. At most ${Period.maxLengthDays} days after '
        'start. A period without end counts as running for '
        '${Period.openPeriodDays} days.',
    'flow':
        'optional object {date: ${FlowLevel.codes.join(' | ')}}: '
        'bleeding strength per day of the period',
    'note': 'optional string',
    'created_at / updated_at': 'optional date_time',
  },
  'cycle_days': {
    'description':
        'Cycle diary for single days outside of periods. '
        'At most one record per date.',
    'date': 'Required. date.',
    'spotting': 'boolean: spotting between periods. Default false.',
    'note': 'optional string',
    'updated_at': 'optional date_time',
  },
};
