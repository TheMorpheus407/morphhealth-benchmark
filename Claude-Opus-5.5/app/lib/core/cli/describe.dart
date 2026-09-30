import '../l10n/strings.dart';
import '../model/enums.dart';
import '../model/nutrients.dart';
import '../portable/backup.dart';
import '../portable/portable_codec.dart';
import '../service/morphhealth_service.dart';
import '../storage/encrypted_store.dart';
import 'protocol.dart';

Map<String, Object?> _field(
  String type, {
  bool required = false,
  required String description,
  List<String>? values,
  num? min,
  num? max,
}) => {
  'type': type,
  'required': required,
  'description': description,
  'values': ?values,
  'min': ?min,
  'max': ?max,
};

List<String> _names(List<Enum> values) =>
    [for (final v in values) (v as dynamic).json as String];

const String _idText =
    'Record id: 1–64 characters [A-Za-z0-9._:-]; optional on import '
    '(generated if missing), unique within the collection';
const String _stampText =
    'RFC 3339 timestamp with zone; optional on import (defaults to import time)';

Map<String, Object?> _stamps() => {
  'created_at': _field('string (RFC 3339)', description: _stampText),
  'updated_at': _field('string (RFC 3339)', description: _stampText),
};

Map<String, Object?> _foodFields({required bool entrySnapshot}) => {
  if (entrySnapshot)
    'ref': _field(
      'string|null',
      description: 'id of the library food this entry was logged from (informational)',
    ),
  'source': _field(
    'string',
    description: 'origin of the food data (default custom)',
    values: _names(FoodSource.values),
  ),
  'name': _field('string', required: true, description: 'food name (1–200 characters)'),
  'brand': _field('string|null', description: 'brand (≤ 200 characters)'),
  'barcode': _field('string|null', description: 'GTIN/EAN, digits only'),
  'basis': _field(
    'string',
    description: 'nutrient values refer to 100 g or 100 ml (default g)',
    values: _names(Basis.values),
  ),
  'serving_size': _field(
    'number|null',
    description: 'size of one portion in basis units (> 0); required for unit "portion"',
    min: 0,
    max: 100000,
  ),
  'serving_label': _field('string|null', description: 'portion description, e.g. "1 Scheibe"'),
  'density_g_per_ml': _field(
    'number|null',
    description: 'density for g↔ml conversion; 1.0 is assumed when null',
    min: 0.05,
    max: 25,
  ),
  'nutrients': _field(
    'object',
    description:
        'nutrient values per 100 basis units, keyed by nutrient key (see '
        '"nutrients"); missing key = unknown (not zero). If only salt or only '
        'sodium is given, the other is derived (salt g = sodium mg / 1000 × 2.5)',
  ),
  'estimated_nutrients': _field(
    'array of string',
    description: 'nutrient keys whose values are estimates (e.g. Open Food Facts "estimate")',
  ),
};

Map<String, Object?> _collections() => {
  'foods': {
    'description': 'Library: own (custom) foods and saved favorite products',
    'fields': {
      'id': _field('string', description: _idText),
      ..._foodFields(entrySnapshot: false),
      'favorite': _field('boolean', description: 'shown under favorites (default false)'),
      ..._stamps(),
    },
  },
  'food_entries': {
    'description':
        'Logged foods. Each entry keeps a snapshot of the food data it was '
        'logged with, so history stays stable when a library food changes.',
    'fields': {
      'id': _field('string', description: _idText),
      'date': _field('string (YYYY-MM-DD)', required: true, description: 'diary day'),
      'time': _field('string (HH:mm)|null', description: 'local time of consumption'),
      'meal': _field('string', required: true, description: 'meal', values: _names(Meal.values)),
      'amount': _field(
        'number',
        required: true,
        description: '> 0; at most 100000 for g/ml and 1000 portions',
      ),
      'unit': _field(
        'string',
        required: true,
        description:
            'g or ml (converted to the food basis with density_g_per_ml, '
            'default 1.0) or portion (× serving_size)',
        values: _names(AmountUnit.values),
      ),
      'food': {
        'type': 'object',
        'required': true,
        'description': 'food snapshot',
        'fields': _foodFields(entrySnapshot: true),
      },
      'note': _field('string|null', description: '≤ 2000 characters'),
      ..._stamps(),
    },
  },
  'water_entries': {
    'description': 'Water intake',
    'fields': {
      'id': _field('string', description: _idText),
      'date': _field('string (YYYY-MM-DD)', required: true, description: 'diary day'),
      'time': _field('string (HH:mm)|null', description: 'local time'),
      'amount_ml': _field('number', required: true, description: 'millilitres', min: 0, max: 10000),
      ..._stamps(),
    },
  },
  'caffeine_entries': {
    'description':
        'Caffeine taken in addition to caffeine contained in logged foods '
        '(e.g. coffee not logged as a food)',
    'fields': {
      'id': _field('string', description: _idText),
      'date': _field('string (YYYY-MM-DD)', required: true, description: 'diary day'),
      'time': _field('string (HH:mm)|null', description: 'local time'),
      'amount_mg': _field('number', required: true, description: 'milligrams', min: 0, max: 2000),
      'label': _field('string|null', description: 'e.g. "Espresso" (≤ 60 characters)'),
      ..._stamps(),
    },
  },
  'periods': {
    'description':
        'Menstrual periods. Periods must not overlap; only the latest may be '
        'ongoing (end null).',
    'fields': {
      'id': _field('string', description: _idText),
      'start': _field('string (YYYY-MM-DD)', required: true, description: 'first day'),
      'end': _field(
        'string (YYYY-MM-DD)|null',
        description: 'last day (inclusive), null while ongoing; at most 60 days after start',
      ),
      'note': _field('string|null', description: '≤ 2000 characters'),
      ..._stamps(),
    },
  },
  'cycle_days': {
    'description':
        'Per-day bleeding intensity (including spotting, also outside periods) '
        'and/or note. At most one record per date; flow or note required.',
    'fields': {
      'id': _field('string', description: _idText),
      'date': _field('string (YYYY-MM-DD)', required: true, description: 'day'),
      'flow': _field('string|null', description: 'bleeding intensity', values: _names(Flow.values)),
      'note': _field('string|null', description: '≤ 2000 characters'),
      ..._stamps(),
    },
  },
  'weight_entries': {
    'description': 'Body weight, stored in the unit it was entered in',
    'fields': {
      'id': _field('string', description: _idText),
      'date': _field('string (YYYY-MM-DD)', required: true, description: 'day'),
      'time': _field('string (HH:mm)|null', description: 'local time'),
      'value': _field('number', required: true, description: 'weight; must correspond to 1–700 kg'),
      'unit': _field(
        'string',
        required: true,
        description: 'kg or lb (1 lb = 0.45359237 kg)',
        values: _names(WeightUnit.values),
      ),
      'note': _field('string|null', description: '≤ 2000 characters'),
      ..._stamps(),
    },
  },
  'symptom_entries': {
    'description': 'Freely named symptoms with intensity 0–10',
    'fields': {
      'id': _field('string', description: _idText),
      'date': _field('string (YYYY-MM-DD)', required: true, description: 'day'),
      'time': _field('string (HH:mm)|null', description: 'local time'),
      'name': _field(
        'string',
        required: true,
        description: '1–60 characters; entries are grouped case-insensitively by name',
      ),
      'intensity': _field('integer', required: true, description: '0 (none) … 10 (strongest)', min: 0, max: 10),
      'note': _field('string|null', description: '≤ 2000 characters'),
      ..._stamps(),
    },
  },
};

Map<String, Object?> _settingsFields() => {
  'language': _field('string', description: 'UI language (default de)', values: _names(AppLanguage.values)),
  'weight_unit': _field('string', description: 'display/input unit (default kg)', values: _names(WeightUnit.values)),
  'overview_areas': _field(
    'array of string',
    description: 'areas shown on the overview (default: all)',
    values: _names(Area.values),
  ),
  'water_quick_ml': _field('array of integer', description: 'quick-add water buttons, ≤ 6 values 1–5000'),
  'caffeine_quick_mg': _field('array of integer', description: 'quick-add caffeine buttons, ≤ 6 values 1–1000'),
  'cycle_predictions': _field('boolean', description: 'false = cycle tracker as pure diary (default true)'),
  'online_food_search': _field('boolean', description: 'false = never contact the food database (default true)'),
  'goals': {
    'type': 'object',
    'description': 'optional daily goals chosen by the user; null = no goal',
    'fields': {
      'energy_kcal': _field('number|null', description: 'kcal', max: 20000),
      'protein_g': _field('number|null', description: 'g', max: 2000),
      'carbohydrates_g': _field('number|null', description: 'g', max: 2000),
      'fat_g': _field('number|null', description: 'g', max: 2000),
      'water_ml': _field('number|null', description: 'ml', max: 20000),
    },
  },
};

/// The `describe` document.
Map<String, Object?> describeInterface(
  ProtocolContext context,
  MorphHealthService? service,
  StoreException? storeError,
) {
  final de = S.of(AppLanguage.de);
  final en = S.of(AppLanguage.en);
  return {
    'name': 'MorphHealth maintenance interface',
    'app_version': appVersion,
    'protocol': {
      'transport': 'JSON Lines on stdin/stdout (UTF-8), one request per line',
      'request': {
        'request_id': 'required; any JSON value (typically a string or number), echoed unchanged',
        'op': 'operation name',
      },
      'response': {
        'request_id': 'same as request (null if unreadable)',
        'ok': 'boolean',
        'data': 'result (when ok)',
        'error': '{code, message, details?} (when not ok)',
      },
      'notes': [
        'Responses are written and flushed after each request, in order.',
        'Nothing but responses is written to stdout; diagnostics go to stderr.',
        'EOF on stdin ends the process after pending writes are flushed.',
      ],
    },
    'invocation': {
      'command':
          './mh --data-dir ABS --key-file ABS [--now RFC3339] '
          '[--food-base-url HTTPS_ORIGIN] [--food-user-agent STRING]',
      'data_dir':
          'absolute path of the persistent working data store; created if '
          'missing. Same encrypted store format as the Android app.',
      'key_file':
          'absolute path of a file with exactly 32 raw bytes (the master key), '
          'outside the data directory. It is used as HKDF-SHA256 input key '
          'material; the derived key encrypts the store with AES-256-GCM. A new '
          'data directory is bound to the key used first; a different key is '
          'rejected (store_wrong_key). Example: head -c 32 /dev/urandom > key.bin',
      'now':
          'RFC 3339 instant for the business clock of this process (frozen); '
          'the local calendar day is taken from its UTC offset. Default: system clock.',
      'food_base_url':
          'HTTPS origin of an Open Food Facts compatible server; the ./mh '
          'starter defaults to food_api_base_url from ENVIRONMENT.json, the '
          'binary itself to https://world.openfoodfacts.org',
      'food_user_agent': 'User-Agent sent to the food server',
    },
    'clock': clockInfo(context),
    'store': {
      'data_dir': context.dataDir,
      'status': storeError == null ? 'open' : storeError.code,
      if (storeError != null) 'error': storeError.message,
      if (service != null) 'counts': service.data.counts(),
      if (service != null) 'diary_entries': service.data.diaryEntryCount,
      'format':
          '${EncryptedStore.formatId} v${EncryptedStore.formatVersion}: '
          'morphhealth.snapshot (MHSTORE1 + JSON header as AAD + '
          'AES-256-GCM(gzip(JSON))) and morphhealth.journal (MHJRNL01 + '
          'length-prefixed AES-256-GCM records); see SECURITY.md',
    },
    'food_api': {
      'base_url': service?.foodApiConfig.baseUrl ?? context.foodApi.baseUrl,
      'user_agent': context.foodApi.userAgent,
      'online_enabled': service?.settings.onlineFoodSearch,
      'endpoints': [
        'GET {base}/api/v3.6/product/{barcode}.json?fields=…',
        'GET {base}/cgi/search.pl?search_terms={q}&search_simple=1&action=process&json=1&page={p}&page_size=20&fields=…',
      ],
    },
    'operations': _operations(),
    'error_codes': {
      'invalid_json': 'request line is not JSON',
      'invalid_request': 'request is not an object or lacks request_id/op',
      'unknown_op': 'op is not supported',
      'invalid_parameter': 'a parameter is missing or has a wrong type/format (details.parameter)',
      'confirmation_required': 'ack_plaintext / confirm_replace must be true',
      'validation_failed': 'import document invalid (details.errors: [{path, message}])',
      'invalid_query': 'search text empty or too long',
      'invalid_page': 'page out of range',
      'invalid_barcode': 'barcode is not 4–14 digits',
      'network_error': 'food server not reachable',
      'network_timeout': 'food server did not answer within 20 s',
      'tls_error': 'TLS handshake/certificate failure',
      'rate_limited': 'food server answered HTTP 429',
      'upstream_http_error': 'unexpected HTTP status (details.http_status)',
      'upstream_invalid_response': 'food server response was not the expected JSON',
      'store_wrong_key': 'key file does not match the data store',
      'store_corrupted': 'data store damaged',
      'store_unsupported': 'data store written by a newer version',
      'store_locked': 'data directory in use by another process',
      'store_io_error': 'file system error',
      'internal_error': 'unexpected failure (details in message)',
    },
    'formats': {
      'portable': {
        'format': PortableFormat.formatId,
        'version': PortableFormat.version,
        'media_type': 'application/json',
        'description':
            'Complete, documented, machine-readable data set used for export, '
            'import, as payload of encrypted backups and as store content. '
            'Import replaces the whole data set; unknown fields are ignored '
            'with a warning; any error rejects the whole document.',
        'top_level': {
          'format': _field('string', required: true, description: 'must be "${PortableFormat.formatId}"'),
          'version': _field('integer', required: true, description: 'must be ≤ ${PortableFormat.version}'),
          'exported_at': _field('string (RFC 3339)', description: 'informational'),
          'app': _field('object', description: 'informational {name, version}'),
          'settings': {'type': 'object', 'description': 'user preferences (defaults apply to missing fields)', 'fields': _settingsFields()},
          for (final e in _collections().entries)
            e.key: {'type': 'array', 'description': 'optional list of records', 'items': e.value},
        },
        'nutrients': [
          for (final n in Nutrients.all)
            {
              'key': n.key,
              'unit': n.unit,
              'group': n.group.name,
              'name_de': de.nutrientName(n.key),
              'name_en': en.nutrientName(n.key),
              'open_food_facts_ids': n.offIds,
              'max_per_100': n.maxPer100,
            },
        ],
        'calculation':
            'entry quantity (basis units) = amount (unit == basis) | amount × '
            'serving_size (portion) | amount × density (ml→g) | amount / density '
            '(g→ml); nutrient = value_per_100 × quantity / 100',
      },
      'backup': {
        'format': BackupFormat.formatId,
        'version': BackupFormat.version,
        'file_extension': BackupFormat.fileExtension,
        'description':
            'JSON {format, version, created_at, kdf: {algorithm: argon2id, '
            'version: 19, memory_kib, iterations, parallelism, salt (base64)}, '
            'cipher: {algorithm: aes-256-gcm}, compression: gzip, payload: '
            'base64(nonce(12) || ciphertext || tag(16))}. Key = Argon2id(passphrase, '
            'salt, 32 bytes). AAD = UTF-8 JSON of all fields except payload in '
            'the order listed. Plaintext = gzip(portable document). Created '
            'and restored in the app (Settings → Data & backup).',
      },
    },
    'results': {
      'nutrition.day':
          'date, entry_count, totals {nutrient_key: number|null}, totals_detail '
          '{nutrient_key: {unit, entries_with_value, includes_estimates}}, meals '
          '{meal: {entry_count, totals}}, entries [{id, time, meal, name, brand, '
          'barcode, source, amount, unit, quantity, quantity_unit, nutrients, '
          'estimated_nutrients}], water {total_ml, entries}, caffeine '
          '{from_foods_mg, additional_mg, total_mg, entries}, goals, goal_progress. '
          'A total is null if no entry of the day has a value for the nutrient. '
          'Numbers are rounded to 3 decimals.',
      'cycle.forecast':
          'on, predictions_enabled, status (${[for (final s in const ['no_data', 'insufficient_data', 'in_period', 'before_window', 'in_window', 'after_window', 'diary_only']) s].join('|')}), '
          'periods_considered, last_period_start, cycle_day, current_period, '
          'next_period {expected_start, window_start, window_end, '
          'days_until_expected_start, days_after_window, expected_length_days}, '
          'upcoming_periods, confidence (low|medium|high), basis (method and '
          'statistics), summary {headline, detail}, explanation [paragraphs], '
          'language, disclaimer. Only periods starting on or before "on" are '
          'used (the estimate as it would have been shown on that day).',
      'food.search':
          'query, page, online_enabled, source, local_results [library/recent '
          'foods on page 1], online {query, page, page_size, count, page_count, '
          'has_more, skipped, products [{barcode, name, brand, quantity_label, '
          'basis, serving_size, serving_label, nutrients_per_100, '
          'estimated_nutrients, nutrition_source, food}]}',
      'food.lookup':
          'barcode, found, online_found, check_digit_valid, online_enabled, '
          'source, product (same shape as search products, from the v3.6 '
          'product endpoint, or null), local_matches',
    },
    'example_document': exampleDocument(),
  };
}

List<Map<String, Object?>> _operations() => [
  {
    'op': 'describe',
    'input': {},
    'output': 'this document',
  },
  {
    'op': 'portable.export',
    'input': {'ack_plaintext': 'true (required): acknowledges an unencrypted export'},
    'output': 'the complete data set as a ${PortableFormat.formatId} document',
  },
  {
    'op': 'portable.import',
    'input': {
      'document': 'a ${PortableFormat.formatId} document (object)',
      'confirm_replace': 'true (required): the working data set is replaced',
    },
    'output':
        'report {replaced, imported_at, previous_counts, imported_counts, '
        'diary_entries, generated_ids, warnings [{path, message}], warning_count}',
  },
  {
    'op': 'nutrition.day',
    'input': {'date': 'YYYY-MM-DD'},
    'output': 'see results["nutrition.day"]',
  },
  {
    'op': 'cycle.forecast',
    'input': {'on': 'YYYY-MM-DD (viewing day)'},
    'output': 'see results["cycle.forecast"]',
  },
  {
    'op': 'food.search',
    'input': {'q': 'search text', 'page': 'integer ≥ 1 (default 1), 20 per page'},
    'output': 'see results["food.search"]',
  },
  {
    'op': 'food.lookup',
    'input': {'barcode': 'digits (spaces and dashes are removed)'},
    'output': 'see results["food.lookup"]; found=false if unknown',
  },
];

/// A small but complete example suitable for `portable.import`.
Map<String, Object?> exampleDocument() => {
  'format': PortableFormat.formatId,
  'version': PortableFormat.version,
  'exported_at': '2026-09-23T08:00:00.000Z',
  'app': {'name': 'MorphHealth', 'version': appVersion},
  'settings': {
    'language': 'de',
    'weight_unit': 'kg',
    'overview_areas': ['nutrition', 'cycle', 'weight', 'symptoms'],
    'water_quick_ml': [150, 250, 330, 500],
    'caffeine_quick_mg': [40, 80, 120],
    'cycle_predictions': true,
    'online_food_search': true,
    'goals': {
      'energy_kcal': 2000,
      'protein_g': 80,
      'carbohydrates_g': null,
      'fat_g': null,
      'water_ml': 2000,
    },
  },
  'foods': [
    {
      'id': 'food-oats',
      'source': 'custom',
      'name': 'Haferflocken',
      'brand': null,
      'barcode': null,
      'basis': 'g',
      'serving_size': 40,
      'serving_label': '1 Portion',
      'density_g_per_ml': null,
      'favorite': true,
      'nutrients': {
        'energy_kcal': 372,
        'protein_g': 13.5,
        'carbohydrates_g': 58.7,
        'fat_g': 7,
        'saturated_fat_g': 1.3,
        'sugars_g': 0.7,
        'fiber_g': 10,
        'salt_g': 0.01,
        'vitamin_b1_mg': 0.59,
        'vitamin_b6_mg': 0.12,
        'vitamin_e_mg': 0.8,
        'vitamin_b9_ug': 33,
        'iron_mg': 4.2,
        'magnesium_mg': 130,
        'zinc_mg': 3.1,
        'phosphorus_mg': 400,
        'potassium_mg': 360,
        'calcium_mg': 50,
      },
      'estimated_nutrients': [],
    },
    {
      'id': 'food-oatdrink',
      'source': 'custom',
      'name': 'Haferdrink',
      'brand': 'Beispiel',
      'basis': 'ml',
      'serving_size': 250,
      'serving_label': '1 Glas',
      'favorite': false,
      'nutrients': {
        'energy_kcal': 46,
        'protein_g': 1,
        'carbohydrates_g': 6.7,
        'fat_g': 1.5,
        'sugars_g': 4,
        'salt_g': 0.1,
        'calcium_mg': 120,
        'vitamin_d_ug': 1.1,
        'vitamin_b2_mg': 0.21,
        'vitamin_b12_ug': 0.38,
        'iodine_ug': 22.5,
      },
    },
  ],
  'food_entries': [
    {
      'id': 'entry-1',
      'date': '2026-09-22',
      'time': '07:45',
      'meal': 'breakfast',
      'amount': 60,
      'unit': 'g',
      'food': {
        'ref': 'food-oats',
        'source': 'custom',
        'name': 'Haferflocken',
        'basis': 'g',
        'serving_size': 40,
        'serving_label': '1 Portion',
        'nutrients': {
          'energy_kcal': 372,
          'protein_g': 13.5,
          'carbohydrates_g': 58.7,
          'fat_g': 7,
          'saturated_fat_g': 1.3,
          'sugars_g': 0.7,
          'fiber_g': 10,
          'salt_g': 0.01,
          'iron_mg': 4.2,
          'magnesium_mg': 130,
        },
      },
    },
    {
      'id': 'entry-2',
      'date': '2026-09-22',
      'time': '07:45',
      'meal': 'breakfast',
      'amount': 250,
      'unit': 'ml',
      'food': {
        'ref': 'food-oatdrink',
        'source': 'custom',
        'name': 'Haferdrink',
        'brand': 'Beispiel',
        'basis': 'ml',
        'serving_size': 250,
        'nutrients': {
          'energy_kcal': 46,
          'protein_g': 1,
          'carbohydrates_g': 6.7,
          'fat_g': 1.5,
          'sugars_g': 4,
          'salt_g': 0.1,
          'calcium_mg': 120,
          'vitamin_d_ug': 1.1,
        },
      },
    },
    {
      'id': 'entry-3',
      'date': '2026-09-22',
      'time': '12:30',
      'meal': 'lunch',
      'amount': 1,
      'unit': 'portion',
      'food': {
        'source': 'custom',
        'name': 'Linsensuppe',
        'basis': 'g',
        'serving_size': 350,
        'serving_label': '1 Teller',
        'nutrients': {
          'energy_kcal': 68,
          'protein_g': 4.3,
          'carbohydrates_g': 9.4,
          'fat_g': 1.1,
          'fiber_g': 2.9,
          'salt_g': 0.6,
          'iron_mg': 1.5,
          'potassium_mg': 220,
        },
      },
    },
    {
      'id': 'entry-4',
      'date': '2026-09-22',
      'time': '16:00',
      'meal': 'snack',
      'amount': 30,
      'unit': 'ml',
      'food': {
        'source': 'custom',
        'name': 'Espresso',
        'basis': 'ml',
        'nutrients': {'energy_kcal': 9, 'caffeine_mg': 212},
      },
    },
  ],
  'water_entries': [
    {'id': 'water-1', 'date': '2026-09-22', 'time': '09:00', 'amount_ml': 250},
    {'id': 'water-2', 'date': '2026-09-22', 'time': '13:00', 'amount_ml': 500},
    {'id': 'water-3', 'date': '2026-09-22', 'time': '18:00', 'amount_ml': 330},
  ],
  'caffeine_entries': [
    {
      'id': 'caffeine-1',
      'date': '2026-09-22',
      'time': '10:30',
      'amount_mg': 80,
      'label': 'Kaffee',
    },
  ],
  'periods': [
    {'id': 'period-1', 'start': '2026-06-05', 'end': '2026-06-09'},
    {'id': 'period-2', 'start': '2026-07-03', 'end': '2026-07-07'},
    {'id': 'period-3', 'start': '2026-07-31', 'end': '2026-08-04'},
    {'id': 'period-4', 'start': '2026-08-29', 'end': '2026-09-02', 'note': 'Etwas stärker als sonst'},
  ],
  'cycle_days': [
    {'id': 'cd-1', 'date': '2026-08-29', 'flow': 'heavy'},
    {'id': 'cd-2', 'date': '2026-08-30', 'flow': 'medium'},
    {'id': 'cd-3', 'date': '2026-08-31', 'flow': 'light'},
    {'id': 'cd-4', 'date': '2026-09-01', 'flow': 'light'},
    {'id': 'cd-5', 'date': '2026-09-02', 'flow': 'spotting', 'note': 'Nur morgens'},
    {'id': 'cd-6', 'date': '2026-09-15', 'flow': 'spotting'},
  ],
  'weight_entries': [
    {'id': 'weight-1', 'date': '2026-09-01', 'time': '07:10', 'value': 68.4, 'unit': 'kg'},
    {'id': 'weight-2', 'date': '2026-09-15', 'time': '07:05', 'value': 150.2, 'unit': 'lb'},
  ],
  'symptom_entries': [
    {
      'id': 'symptom-1',
      'date': '2026-08-29',
      'time': '08:00',
      'name': 'Unterleibskrämpfe',
      'intensity': 6,
      'note': 'Wärmflasche half',
    },
    {
      'id': 'symptom-2',
      'date': '2026-09-15',
      'time': '21:00',
      'name': 'Kopfschmerzen',
      'intensity': 3,
    },
  ],
};
