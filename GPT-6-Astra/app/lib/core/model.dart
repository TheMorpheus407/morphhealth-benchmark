import 'dart:convert';
import 'dart:math';

typedef Json = Map<String, dynamic>;

class CoreException implements Exception {
  final String code;
  final String message;
  const CoreException(this.code, this.message);
  @override
  String toString() => '$code: $message';
}

class Nutrient {
  final String key, de, en, unit;
  const Nutrient(this.key, this.de, this.en, this.unit);
}

const nutrients = <Nutrient>[
  Nutrient('energy', 'Energie', 'Energy', 'kcal'),
  Nutrient('protein', 'Protein', 'Protein', 'g'),
  Nutrient('carbs', 'Kohlenhydrate', 'Carbohydrates', 'g'),
  Nutrient('fat', 'Fett', 'Fat', 'g'),
  Nutrient('saturatedFat', 'Gesättigte Fettsäuren', 'Saturated fat', 'g'),
  Nutrient('sugar', 'Zucker', 'Sugar', 'g'),
  Nutrient('fiber', 'Ballaststoffe', 'Fiber', 'g'),
  Nutrient('salt', 'Salz', 'Salt', 'g'),
  Nutrient('sodium', 'Natrium', 'Sodium', 'g'),
  Nutrient('caffeine', 'Koffein', 'Caffeine', 'mg'),
  Nutrient('vitaminA', 'Vitamin A', 'Vitamin A', 'µg'),
  Nutrient('vitaminC', 'Vitamin C', 'Vitamin C', 'mg'),
  Nutrient('vitaminD', 'Vitamin D', 'Vitamin D', 'µg'),
  Nutrient('vitaminE', 'Vitamin E', 'Vitamin E', 'mg'),
  Nutrient('vitaminK', 'Vitamin K', 'Vitamin K', 'µg'),
  Nutrient('vitaminB1', 'Vitamin B1', 'Vitamin B1', 'mg'),
  Nutrient('vitaminB2', 'Vitamin B2', 'Vitamin B2', 'mg'),
  Nutrient('vitaminB3', 'Vitamin B3', 'Vitamin B3', 'mg'),
  Nutrient('vitaminB5', 'Vitamin B5', 'Vitamin B5', 'mg'),
  Nutrient('vitaminB6', 'Vitamin B6', 'Vitamin B6', 'mg'),
  Nutrient('vitaminB7', 'Vitamin B7 (Biotin)', 'Vitamin B7 (biotin)', 'µg'),
  Nutrient('vitaminB9', 'Vitamin B9 (Folat)', 'Vitamin B9 (folate)', 'µg'),
  Nutrient('vitaminB12', 'Vitamin B12', 'Vitamin B12', 'µg'),
  Nutrient('calcium', 'Kalzium', 'Calcium', 'mg'),
  Nutrient('iron', 'Eisen', 'Iron', 'mg'),
  Nutrient('magnesium', 'Magnesium', 'Magnesium', 'mg'),
  Nutrient('potassium', 'Kalium', 'Potassium', 'mg'),
  Nutrient('zinc', 'Zink', 'Zinc', 'mg'),
  Nutrient('selenium', 'Selen', 'Selenium', 'µg'),
  Nutrient('iodine', 'Jod', 'Iodine', 'µg'),
  Nutrient('phosphorus', 'Phosphor', 'Phosphorus', 'mg'),
];

const collections = [
  'foods',
  'meals',
  'drinks',
  'periods',
  'weights',
  'symptoms',
];
const areas = ['nutrition', 'cycle', 'weight', 'symptoms'];
final _random = Random.secure();
String newId() => List.generate(
  16,
  (_) => _random.nextInt(256).toRadixString(16).padLeft(2, '0'),
).join();
String dateKey(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-${value.month.toString().padLeft(2, '0')}-${value.day.toString().padLeft(2, '0')}';

/// Calendar date arithmetic uses UTC midnight to avoid DST's 23/25-hour days.
DateTime parseDay(String value) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    throw const CoreException('invalid_date', 'Expected YYYY-MM-DD.');
  }
  final parts = value.split('-').map(int.parse).toList();
  final result = DateTime.utc(parts[0], parts[1], parts[2]);
  if (dateKey(result) != value || parts[0] < 1) {
    throw const CoreException('invalid_date', 'Date does not exist.');
  }
  return result;
}

double? numeric(dynamic value) {
  if (value is num && value.isFinite) return value.toDouble();
  return null;
}

Json emptyDocument() => {
  'format': 'morphhealth',
  'version': 1,
  'settings': {
    'language': 'de',
    'weightUnit': 'kg',
    'onlineFood': false,
    'cyclePredictions': true,
    'visible': {for (final area in areas) area: true},
    'goals': {
      for (final k in ['water', 'energy', 'protein', 'carbs', 'fat']) k: null,
    },
  },
  for (final c in collections) c: <Json>[],
};

Json cloneJson(Json value) =>
    (jsonDecode(jsonEncode(value)) as Map).cast<String, dynamic>();

Never _invalid(String field, String reason) =>
    throw CoreException('invalid_document', '$field: $reason');
Json _object(dynamic value, String field) {
  if (value is! Map || value.keys.any((k) => k is! String)) {
    _invalid(field, 'expected object');
  }
  return Map<String, dynamic>.from(value);
}

void _keys(Json obj, Iterable<String> allowed, String field) {
  for (final key in obj.keys) {
    if (!allowed.contains(key)) _invalid('$field.$key', 'unknown field');
  }
}

String _string(
  dynamic value,
  String field, {
  bool empty = false,
  int max = 4000,
}) {
  if (value is! String ||
      value.length > max ||
      (!empty && value.trim().isEmpty)) {
    _invalid(
      field,
      'expected ${empty ? '' : 'non-empty '}string, maximum $max characters',
    );
  }
  return value;
}

String _choice(dynamic value, List<String> choices, String field) {
  if (value is! String || !choices.contains(value)) {
    _invalid(field, 'expected one of ${choices.join(', ')}');
  }
  return value;
}

double _number(
  dynamic value,
  String field, {
  double min = 0,
  double max = 1000000000,
  bool positive = false,
}) {
  final n = numeric(value);
  if (n == null || n < min || n > max || (positive && n == 0)) {
    _invalid(field, 'number outside permitted range');
  }
  return n;
}

bool _bool(dynamic value, String field) {
  if (value is! bool) _invalid(field, 'expected boolean');
  return value;
}

String _day(dynamic value, String field) {
  final s = _string(value, field, max: 10);
  try {
    parseDay(s);
  } on CoreException {
    _invalid(field, 'expected a valid YYYY-MM-DD date');
  }
  return s;
}

String _timestamp(dynamic value, String field) {
  final s = _string(value, field, max: 40);
  // A local civil timestamp is accepted as emitted by Android's DateTime.
  // A supplied offset is retained: entries belong to the entered calendar day.
  if (!RegExp(
    r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,6})?(?:Z|[+-]\d{2}:\d{2})?$',
  ).hasMatch(s)) {
    _invalid(field, 'expected ISO8601 timestamp');
  }
  _day(s.substring(0, 10), field);
  final hour = int.parse(s.substring(11, 13));
  final minute = int.parse(s.substring(14, 16));
  final second = int.parse(s.substring(17, 19));
  if (hour > 23 || minute > 59 || second > 59 || DateTime.tryParse(s) == null) {
    _invalid(field, 'invalid clock time');
  }
  final offset = RegExp(r'([+-])(\d{2}):(\d{2})$').firstMatch(s);
  if (offset != null &&
      (int.parse(offset[2]!) > 23 || int.parse(offset[3]!) > 59)) {
    _invalid(field, 'invalid time-zone offset');
  }
  return s;
}

Json validateSettings(dynamic value) {
  final m = _object(value, 'settings');
  _keys(m, [
    'language',
    'weightUnit',
    'onlineFood',
    'cyclePredictions',
    'visible',
    'goals',
  ], 'settings');
  final defaults = emptyDocument()['settings'] as Json;
  final visible = _object(
    m['visible'] ?? defaults['visible'],
    'settings.visible',
  );
  final goals = _object(m['goals'] ?? defaults['goals'], 'settings.goals');
  _keys(visible, areas, 'settings.visible');
  _keys(goals, [
    'water',
    'energy',
    'protein',
    'carbs',
    'fat',
  ], 'settings.goals');
  return {
    'language': _choice(m['language'] ?? 'de', [
      'de',
      'en',
    ], 'settings.language'),
    'weightUnit': _choice(m['weightUnit'] ?? 'kg', [
      'kg',
      'lb',
    ], 'settings.weightUnit'),
    'onlineFood': _bool(m['onlineFood'] ?? false, 'settings.onlineFood'),
    'cyclePredictions': _bool(
      m['cyclePredictions'] ?? true,
      'settings.cyclePredictions',
    ),
    'visible': {
      for (final area in areas)
        area: _bool(visible[area] ?? true, 'settings.visible.$area'),
    },
    'goals': {
      for (final k in ['water', 'energy', 'protein', 'carbs', 'fat'])
        k: goals[k] == null
            ? null
            : _number(goals[k], 'settings.goals.$k', positive: true),
    },
  };
}

Json validateFood(dynamic value, [String path = 'food']) {
  final m = _object(value, path);
  _keys(m, [
    'id',
    'name',
    'source',
    'barcode',
    'brand',
    'basis',
    'servingSize',
    'nutrients',
    'favorite',
  ], path);
  final ns = _object(m['nutrients'] ?? {}, '$path.nutrients');
  _keys(ns, nutrients.map((n) => n.key), '$path.nutrients');
  return {
    'id': _string(m['id'], '$path.id', max: 200),
    'name': _string(m['name'], '$path.name', max: 500),
    'source': _choice(m['source'] ?? 'custom', [
      'custom',
      'off',
    ], '$path.source'),
    if (m['barcode'] != null)
      'barcode': _string(m['barcode'], '$path.barcode', empty: true, max: 100),
    if (m['brand'] != null)
      'brand': _string(m['brand'], '$path.brand', empty: true, max: 1000),
    'basis': _choice(m['basis'] ?? 'g', ['g', 'ml'], '$path.basis'),
    'servingSize': m['servingSize'] == null
        ? null
        : _number(
            m['servingSize'],
            '$path.servingSize',
            positive: true,
            max: 1000000,
          ),
    'nutrients': {
      for (final n in nutrients)
        n.key: ns[n.key] == null
            ? null
            : _number(ns[n.key], '$path.nutrients.${n.key}'),
    },
    'favorite': _bool(m['favorite'] ?? false, '$path.favorite'),
  };
}

Json validateItem(String collection, dynamic value) {
  if (!collections.contains(collection)) {
    _invalid('collection', 'unknown collection');
  }
  if (collection == 'foods') return validateFood(value, 'foods');
  final m = _object(value, collection);
  final result = <String, dynamic>{
    'id': _string(m['id'], '$collection.id', max: 200),
    'note': _string(
      m['note'] ?? '',
      '$collection.note',
      empty: true,
      max: 10000,
    ),
  };
  if (collection != 'periods') {
    result['at'] = _timestamp(m['at'], '$collection.at');
  }
  switch (collection) {
    case 'meals':
      _keys(m, [
        'id',
        'food',
        'amount',
        'unit',
        'at',
        'meal',
        'note',
      ], collection);
      final food = validateFood(m['food'], 'meals.food');
      final unit = _choice(m['unit'], ['g', 'ml', 'serving'], 'meals.unit');
      if (unit != food['basis'] && unit != 'serving') {
        _invalid(
          'meals.unit',
          'grams and millilitres cannot be interchanged without density',
        );
      }
      if (unit == 'serving' && food['servingSize'] == null) {
        _invalid('meals.unit', 'serving requires a servingSize');
      }
      result.addAll({
        'food': food,
        'unit': unit,
        'amount': _number(
          m['amount'],
          'meals.amount',
          positive: true,
          max: 1000000,
        ),
        'meal': _choice(m['meal'], [
          'breakfast',
          'lunch',
          'dinner',
          'snack',
        ], 'meals.meal'),
      });
    case 'drinks':
      _keys(m, ['id', 'kind', 'amount', 'at', 'note'], collection);
      result.addAll({
        'kind': _choice(m['kind'], ['water', 'caffeine'], 'drinks.kind'),
        'amount': _number(
          m['amount'],
          'drinks.amount',
          positive: true,
          max: 1000000,
        ),
      });
    case 'periods':
      _keys(m, ['id', 'start', 'end', 'flow', 'note'], collection);
      final start = _day(m['start'], 'periods.start');
      final end = m['end'] == null ? null : _day(m['end'], 'periods.end');
      if (end != null && end.compareTo(start) < 0) {
        _invalid('periods.end', 'end precedes start');
      }
      result.addAll({
        'start': start,
        'end': end,
        'flow': _choice(m['flow'], [
          'spotting',
          'light',
          'medium',
          'heavy',
        ], 'periods.flow'),
      });
    case 'weights':
      _keys(m, ['id', 'at', 'kg', 'note'], collection);
      result['kg'] = _number(m['kg'], 'weights.kg', positive: true, max: 2000);
    case 'symptoms':
      _keys(m, ['id', 'at', 'name', 'intensity', 'note'], collection);
      result['name'] = _string(m['name'], 'symptoms.name', max: 500);
      final intensity = _number(m['intensity'], 'symptoms.intensity', max: 10);
      if (intensity != intensity.roundToDouble()) {
        _invalid('symptoms.intensity', 'expected integer');
      }
      result['intensity'] = intensity.toInt();
  }
  return result;
}

/// Reject overlapping non-spotting episodes, while allowing independent
/// spotting records. A null end means ongoing, so only the latest can be open.
void validatePeriodOverlaps(List<dynamic> periods) {
  final bleeding = periods.where((e) => e['flow'] != 'spotting').toList()
    ..sort((a, b) => (a['start'] as String).compareTo(b['start'] as String));
  for (var i = 1; i < bleeding.length; i++) {
    final previousEnd = bleeding[i - 1]['end'];
    if (previousEnd == null ||
        (previousEnd as String).compareTo(bleeding[i]['start'] as String) >=
            0) {
      throw const CoreException(
        'overlapping_periods',
        'Bleeding episodes overlap. Close or correct the earlier episode first.',
      );
    }
  }
}

/// Validates and returns a detached, normalized document. Unknown fields,
/// malformed dates, duplicate IDs, unsupported versions and invalid units fail
/// before any live state is modified.
Json validateDocument(dynamic value) {
  final m = _object(value, 'document');
  _keys(m, ['format', 'version', 'settings', ...collections], 'document');
  if (m['format'] != 'morphhealth' || m['version'] != 1) {
    _invalid('format/version', 'expected morphhealth version 1');
  }
  final result = <String, dynamic>{
    'format': 'morphhealth',
    'version': 1,
    'settings': validateSettings(m['settings']),
  };
  var total = 0;
  for (final c in collections) {
    if (m[c] is! List) _invalid(c, 'expected array');
    final input = m[c] as List;
    total += input.length;
    if (total > 100000) _invalid(c, 'maximum 100000 records per document');
    final ids = <String>{};
    result[c] = input.map((e) {
      final item = validateItem(c, e);
      if (!ids.add(item['id'] as String)) {
        _invalid('$c.id', 'duplicate identifier');
      }
      return item;
    }).toList();
  }
  validatePeriodOverlaps(result['periods'] as List);
  return result;
}

/// A complete small document, deliberately containing every collection and all
/// micronutrient keys so CLI clients can import and extend it directly.
Json exampleDocument() {
  final doc = emptyDocument();
  final food = validateFood({
    'id': 'example-food',
    'name': 'Haferflocken / oats',
    'basis': 'g',
    'servingSize': 50,
    'nutrients': {
      'energy': 370,
      'protein': 13,
      'carbs': 59,
      'fat': 7,
      'fiber': 10,
      'salt': 0.01,
      'sodium': 0.004,
      'iron': 4.2,
      'vitaminB1': 0.46,
    },
  });
  doc['foods'] = [food];
  doc['meals'] = [
    validateItem('meals', {
      'id': 'example-meal',
      'food': food,
      'amount': 1,
      'unit': 'serving',
      'at': '2026-09-17T08:00:00+02:00',
      'meal': 'breakfast',
      'note': '',
    }),
  ];
  doc['drinks'] = [
    validateItem('drinks', {
      'id': 'example-water',
      'kind': 'water',
      'amount': 250,
      'at': '2026-09-17T08:00:00+02:00',
    }),
  ];
  doc['periods'] = [
    for (final d in ['2026-06-21', '2026-07-20', '2026-08-19', '2026-09-17'])
      validateItem('periods', {
        'id': 'period-$d',
        'start': d,
        'end': dateKey(parseDay(d).add(const Duration(days: 4))),
        'flow': 'medium',
      }),
  ];
  doc['weights'] = [
    validateItem('weights', {
      'id': 'example-weight',
      'at': '2026-09-17T07:00:00+02:00',
      'kg': 65,
    }),
  ];
  doc['symptoms'] = [
    validateItem('symptoms', {
      'id': 'example-symptom',
      'at': '2026-09-17T09:00:00+02:00',
      'name': 'Kopfschmerz / headache',
      'intensity': 3,
    }),
  ];
  return doc;
}
