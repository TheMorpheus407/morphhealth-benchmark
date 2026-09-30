import 'model.dart';
import 'nutrients.dart';

Json exampleDocument() {
  final data = HealthData.empty();
  final food = <String, dynamic>{
    'id': 'example-oats',
    'name': 'Haferflocken',
    'name_en': 'Oats',
    'source': 'custom',
    'base_unit': 'g',
    'serving_size': 40,
    'grams_per_ml': null,
    'favorite': true,
    'nutrients': {
      for (final n in nutrients)
        n.id: n.id == 'calories'
            ? 370
            : n.id == 'protein'
            ? 13
            : n.id == 'carbs'
            ? 59
            : n.id == 'fat'
            ? 7
            : null,
    },
  };
  data['foods'].add(food);
  data['consumption'].add({
    'id': 'example-meal',
    'at': '2026-09-20T08:00:00',
    'food_id': food['id'],
    'food': food,
    'amount': 1,
    'unit': 'portion',
    'meal': 'breakfast',
    'note': '',
  });
  data['drinks'].add({
    'id': 'example-water',
    'at': '2026-09-20T08:15:00',
    'kind': 'water',
    'amount': 250,
  });
  data['weights'].add({'id': 'example-weight', 'date': '2026-09-20', 'kg': 70});
  data['periods'].addAll([
    {
      'id': 'example-period-1',
      'start': '2026-07-25',
      'end': '2026-07-29',
      'strength': 'medium',
    },
    {
      'id': 'example-period-2',
      'start': '2026-08-22',
      'end': '2026-08-26',
      'strength': 'light',
    },
    {
      'id': 'example-period-3',
      'start': '2026-09-20',
      'end': null,
      'strength': 'medium',
    },
  ]);
  data['symptoms'].add({
    'id': 'example-symptom',
    'at': '2026-09-20T09:00:00',
    'name': 'Kopfschmerz',
    'intensity': 3,
    'note': 'Nach dem Aufstehen',
  });
  return data.export(DateTime(2026, 9, 20, 12));
}

Json describeContract() => {
  'name': 'MorphHealth',
  'protocol': 'MH-PERSONAL-3',
  'portable_format': 'morphhealth',
  'portable_version': 1,
  'clock':
      'Local wall time. at = YYYY-MM-DDTHH:mm:ss[.ffffff], dates = YYYY-MM-DD. --now preserves the supplied RFC3339 wall time. No implicit timezone shifts.',
  'document':
      'UTF-8 JSON. Required format/version; optional settings and tables default to empty/default. Unknown fields and nutrients, invalid types, duplicate IDs, overlapping periods, invalid amounts and impossible dates are rejected before replacement.',
  'tables': {
    'foods': {
      'required': ['id', 'name', 'source', 'base_unit', 'nutrients'],
      'optional': [
        'name_en',
        'brand',
        'barcode',
        'serving_size',
        'grams_per_ml',
        'favorite',
        'estimated',
      ],
      'source': ['custom', 'off'],
      'base_unit': ['g', 'ml'],
      'serving_size':
          'positive amount in base_unit per portion; null if unknown',
      'grams_per_ml': 'positive density for g↔ml conversions; null if unknown',
      'nutrients': 'per 100 base_unit; numeric ≥0 or null/omitted = unknown',
      'estimated':
          'list of nutrient IDs with estimated/qualified source values',
    },
    'consumption': {
      'required': ['id', 'at', 'food_id', 'amount', 'unit', 'meal'],
      'optional': ['food', 'note'],
      'food':
          'immutable food snapshot; resolved from foods by food_id on import if omitted',
      'unit': ['g', 'ml', 'portion'],
      'meal': ['breakfast', 'lunch', 'dinner', 'snack'],
    },
    'drinks': {
      'required': ['id', 'at', 'kind', 'amount'],
      'optional': ['note'],
      'kind': {'water': 'ml', 'caffeine': 'mg'},
      'amount': 'positive number',
    },
    'weights': {
      'required': ['id', 'date', 'kg'],
      'optional': ['note'],
      'kg':
          'positive number, lb input/display converted using 1 lb = 0.45359237 kg',
    },
    'periods': {
      'required': ['id', 'start', 'strength'],
      'optional': ['end', 'note'],
      'end': 'inclusive date or null for ongoing',
      'strength': ['spotting', 'light', 'medium', 'heavy'],
      'overlap': 'not permitted',
    },
    'bleeding': {
      'required': ['id', 'date', 'strength'],
      'optional': ['note'],
      'strength': ['none', 'spotting', 'light', 'medium', 'heavy'],
      'meaning':
          'one daily override per date; does not create a forecast start',
    },
    'symptoms': {
      'required': ['id', 'at', 'name', 'intensity'],
      'optional': ['note'],
      'intensity': 'integer 0..10',
    },
  },
  'settings': {
    'language': ['de', 'en'],
    'weight_unit': ['kg', 'lb'],
    'sections': {for (final a in areaNames) a: 'boolean'},
    'goals': {
      'water': 'ml',
      'calories': 'kcal',
      'protein': 'g',
      'carbs': 'g',
      'fat': 'g',
    },
    'online_enabled':
        'boolean, default false; CLI food operations are explicit online requests',
    'cycle_prediction': 'boolean, default true; false means journal-only',
  },
  'nutrient_units': {for (final n in nutrients) n.id: n.unit},
  'operations': {
    'describe': {
      'input': {},
      'output': 'This contract including an importable example_document',
    },
    'portable.export': {
      'input': {'ack_plaintext': true},
      'output': 'Complete plaintext portable document',
    },
    'portable.import': {
      'input': {'document': 'portable document', 'confirm_replace': true},
      'output': 'replaced=true and counts by table',
    },
    'nutrition.day': {
      'input': {'date': 'YYYY-MM-DD'},
      'output': {
        'date': 'string',
        'nutrients': 'all nutrient IDs → number or null',
        'units': 'ID → unit',
        'known_food_count': 'ID → integer count of foods with a known value',
        'food_count': 'integer',
        'incomplete_nutrients': 'IDs with unknown food contributions',
        'water_ml': 'number',
        'additional_caffeine_mg': 'number',
        'goals': 'settings goals',
        'entries': 'consumption rows with calculated base_amount and nutrients',
        'drinks': 'drink rows',
      },
    },
    'cycle.forecast': {
      'input': {'on': 'YYYY-MM-DD'},
      'output': {
        'on': 'date string',
        'enabled': 'boolean',
        'recorded_starts': 'integer',
        'median_absolute_deviation_days': 'number or null',
        'observed_min_days': 'integer or null',
        'observed_max_days': 'integer or null',
        'median_bleeding_days': 'integer or null',
        'latest_start': 'date string or null',
        'cycle_day': 'integer or null, 1-based from latest recorded start',
        'recorded_period': 'period object or null',
        'explanation':
            'object: boolean uses_recorded_starts_only, boolean excludes_future_and_spotting_starts, string window_rule, boolean missed_prediction_is_not_advanced',
        'method': 'median_last_6_start_intervals or journal_only',
        'intervals_days': 'last ≤6 observed intervals',
        'predicted_start': 'date or null',
        'window_start': 'date or null',
        'window_end': 'date or null',
        'estimated_end': 'date or null',
        'median_cycle_days': 'number or null',
        'sample_count': 'integer',
        'status': [
          'journal_only',
          'insufficient_history',
          'upcoming',
          'in_window',
          'past_window',
        ],
        'variability': [
          'unknown',
          'limited_history',
          'variable',
          'more_consistent',
        ],
        'other_fields':
            'on, enabled, recorded_starts, median_absolute_deviation_days, observed_min_days, observed_max_days, median_bleeding_days, latest_start, cycle_day, recorded_period, explanation',
      },
    },
    'food.search': {
      'input': {'q': 'nonempty string', 'page': 'integer ≥1'},
      'output':
          'query, page, page_size=20, count (integer or null), has_more (boolean), products (food rows), attribution',
    },
    'food.lookup': {
      'input': {'barcode': '4..24 digit string, preserve leading zeroes'},
      'output':
          'barcode, found (boolean), product (food row or null), attribution',
    },
  },
  'storage':
      'health.mhv: AES-256-GCM authenticated JSON envelope. CLI key-file is exactly 32 raw bytes, external to data-dir. Exclusive process lock. Backup: morphhealth-backup version 1, PBKDF2-HMAC-SHA256 600000 rounds, 16-byte random salt, AES-256-GCM.',
  'example_document': exampleDocument(),
};
