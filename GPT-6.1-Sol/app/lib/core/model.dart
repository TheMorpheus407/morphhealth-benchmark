import 'dart:convert';
import 'dart:math';
import 'nutrients.dart';

const tableNames = [
  'foods',
  'consumption',
  'drinks',
  'weights',
  'periods',
  'bleeding',
  'symptoms',
];
const areaNames = ['nutrition', 'cycle', 'weight', 'symptoms'];

String dateKey(DateTime date) => date.toIso8601String().substring(0, 10);
DateTime parseDay(String value) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    throw const FormatException('invalid_date');
  }
  final d = DateTime.tryParse(value);
  if (d == null || dateKey(d) != value) {
    throw const FormatException('invalid_date');
  }
  return d;
}

int dayDifference(String a, String b) {
  final da = parseDay(a), db = parseDay(b);
  return DateTime.utc(
    da.year,
    da.month,
    da.day,
  ).difference(DateTime.utc(db.year, db.month, db.day)).inDays;
}

String addDays(String day, int days) {
  final d = parseDay(day);
  return dateKey(DateTime(d.year, d.month, d.day + days));
}

String newId() {
  final r = Random.secure();
  return List.generate(
    16,
    (_) => r.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ).join();
}

Json defaultSettings() => {
  'language': 'de',
  'weight_unit': 'kg',
  'sections': {for (final area in areaNames) area: true},
  'goals': <String, dynamic>{},
  'online_enabled': false,
  'cycle_prediction': true,
};

class HealthData {
  final Json settings;
  final Map<String, List<Json>> tables;
  HealthData(this.settings, this.tables);
  factory HealthData.empty() =>
      HealthData(defaultSettings(), {for (final t in tableNames) t: []});
  List<Json> operator [](String name) => tables[name]!;
  Json export(DateTime now) => {
    'format': 'morphhealth',
    'version': 1,
    'exported_at': now.toIso8601String(),
    'settings': settings,
    for (final t in tableNames) t: tables[t],
  };
  HealthData copy() =>
      HealthData.import(jsonDecode(jsonEncode(export(DateTime.now()))));

  /// All validation happens before replacement of the working dataset.
  factory HealthData.import(dynamic input) {
    final d = object(input, 'document');
    keys(d, {
      'format',
      'version',
      'exported_at',
      'settings',
      ...tableNames,
    }, 'document');
    if (d['format'] != 'morphhealth' || d['version'] != 1) {
      fail('unsupported_format');
    }
    if (d['exported_at'] != null) textValue(d, 'exported_at');
    final settings = defaultSettings();
    if (d['settings'] != null) {
      final s = object(d['settings'], 'settings');
      keys(s, {
        'language',
        'weight_unit',
        'sections',
        'goals',
        'online_enabled',
        'cycle_prediction',
      }, 'settings');
      if (s.containsKey('language')) choice(s, 'language', ['de', 'en']);
      if (s.containsKey('weight_unit')) choice(s, 'weight_unit', ['kg', 'lb']);
      for (final k in ['online_enabled', 'cycle_prediction']) {
        if (s.containsKey(k) && s[k] is! bool) fail('invalid_$k');
      }
      settings.addAll(s);
      final sections = object(s['sections'] ?? {}, 'sections');
      keys(sections, areaNames.toSet(), 'sections');
      for (final v in sections.values) {
        if (v is! bool) fail('invalid_sections');
      }
      settings['sections'] = {
        for (final a in areaNames) a: sections[a] ?? true,
      };
      final goals = object(s['goals'] ?? {}, 'goals');
      keys(goals, {'water', 'calories', 'protein', 'carbs', 'fat'}, 'goals');
      for (final k in goals.keys) {
        if (goals[k] != null) positive(goals, k);
      }
      settings['goals'] = goals;
    }
    final tables = <String, List<Json>>{};
    for (final t in tableNames) {
      final raw = d[t] ?? [];
      if (raw is! List) fail('invalid_$t');
      tables[t] = (raw).map((r) => object(r, t)).toList();
      final ids = <String>{};
      for (final r in tables[t]!) {
        textValue(r, 'id', max: 128);
        if (!ids.add(r['id'])) fail('duplicate_id_$t');
      }
    }
    final foods = <String, Json>{};
    for (final f in tables['foods']!) {
      validateFood(f);
      foods[f['id']] = f;
    }
    for (final r in tables['consumption']!) {
      keys(r, {
        'id',
        'at',
        'food_id',
        'food',
        'amount',
        'unit',
        'meal',
        'note',
      }, 'consumption');
      atValue(r);
      textValue(r, 'food_id');
      r['food'] ??= foods[r['food_id']];
      if (r['food'] == null) fail('missing_food_snapshot');
      r['food'] = object(r['food'], 'food');
      validateFood(r['food']);
      if (r['food']['id'] != r['food_id']) fail('food_id_mismatch');
      positive(r, 'amount');
      choice(r, 'unit', ['g', 'ml', 'portion']);
      choice(r, 'meal', ['breakfast', 'lunch', 'dinner', 'snack']);
      optionalNote(r);
      baseQuantity(r['food'], number(r['amount'])!, r['unit']);
    }
    for (final r in tables['drinks']!) {
      keys(r, {'id', 'at', 'kind', 'amount', 'note'}, 'drinks');
      atValue(r);
      choice(r, 'kind', ['water', 'caffeine']);
      positive(r, 'amount');
      optionalNote(r);
    }
    for (final r in tables['weights']!) {
      keys(r, {'id', 'date', 'kg', 'note'}, 'weights');
      dayValue(r, 'date');
      positive(r, 'kg');
      optionalNote(r);
    }
    for (final r in tables['periods']!) {
      keys(r, {'id', 'start', 'end', 'strength', 'note'}, 'periods');
      dayValue(r, 'start');
      if (r['end'] != null) {
        dayValue(r, 'end');
        if ((r['end'] as String).compareTo(r['start']) < 0) {
          fail('end_before_start');
        }
      }
      choice(r, 'strength', ['spotting', 'light', 'medium', 'heavy']);
      optionalNote(r);
    }
    final periods = [...tables['periods']!]
      ..sort((a, b) => (a['start'] as String).compareTo(b['start']));
    for (var i = 1; i < periods.length; i++) {
      final previous = periods[i - 1];
      if (previous['end'] == null ||
          (previous['end'] as String).compareTo(periods[i]['start']) >= 0) {
        fail('periods_overlap');
      }
    }
    final bleedingDates = <String>{};
    for (final r in tables['bleeding']!) {
      keys(r, {'id', 'date', 'strength', 'note'}, 'bleeding');
      dayValue(r, 'date');
      choice(r, 'strength', ['none', 'spotting', 'light', 'medium', 'heavy']);
      optionalNote(r);
      if (!bleedingDates.add(r['date'])) fail('duplicate_bleeding_date');
    }
    for (final r in tables['symptoms']!) {
      keys(r, {'id', 'at', 'name', 'intensity', 'note'}, 'symptoms');
      atValue(r);
      textValue(r, 'name', max: 200);
      nonnegative(r, 'intensity');
      final v = number(r['intensity'])!;
      if (v > 10 || v != v.roundToDouble()) fail('invalid_intensity');
      optionalNote(r);
    }
    return HealthData(settings, tables);
  }
}

Never fail(String message) => throw FormatException(message);
Json object(dynamic value, String field) {
  if (value is! Map) fail('invalid_$field');
  try {
    return Map<String, dynamic>.from(value);
  } catch (_) {
    fail('invalid_$field');
  }
}

void keys(Json value, Set<String> allowed, String field) {
  for (final k in value.keys) {
    if (!allowed.contains(k)) fail('unknown_field:$field.$k');
  }
}

void textValue(Json row, String key, {int max = 1000, bool empty = false}) {
  final v = row[key];
  if (v is! String || (!empty && v.trim().isEmpty) || v.length > max) {
    fail('invalid_$key');
  }
}

void choice(Json row, String key, List<String> choices) {
  if (!choices.contains(row[key])) fail('invalid_$key');
}

void nonnegative(Json row, String key) {
  final value = row[key];
  if (value is! num || !value.isFinite || value < 0) fail('invalid_$key');
}

void positive(Json row, String key) {
  nonnegative(row, key);
  if (number(row[key])! <= 0) fail('invalid_$key');
}

void dayValue(Json row, String key) {
  textValue(row, key);
  parseDay(row[key]);
}

void atValue(Json row) {
  textValue(row, 'at');
  final at = row['at'] as String;
  if (!RegExp(
    r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{1,6})?$',
  ).hasMatch(at)) {
    fail('invalid_at');
  }
  parseDay(at.substring(0, 10));
  final time = at.substring(11).split(':');
  if (int.parse(time[0]) > 23 ||
      int.parse(time[1]) > 59 ||
      double.parse(time[2]) >= 60) {
    fail('invalid_at');
  }
}

void optionalNote(Json row) {
  if (row['note'] != null) textValue(row, 'note', max: 10000, empty: true);
}

void validateFood(Json f) {
  keys(f, {
    'id',
    'name',
    'name_en',
    'brand',
    'barcode',
    'source',
    'base_unit',
    'serving_size',
    'grams_per_ml',
    'nutrients',
    'estimated',
    'favorite',
  }, 'food');
  textValue(f, 'id', max: 128);
  textValue(f, 'name', max: 1000);
  for (final k in ['brand', 'barcode', 'name_en']) {
    if (f[k] != null) textValue(f, k, empty: true);
  }
  choice(f, 'source', ['custom', 'off']);
  choice(f, 'base_unit', ['g', 'ml']);
  for (final k in ['serving_size', 'grams_per_ml']) {
    if (f[k] != null) positive(f, k);
  }
  if (f['favorite'] != null && f['favorite'] is! bool) fail('invalid_favorite');
  f['favorite'] ??= false;
  final n = object(f['nutrients'], 'nutrients');
  keys(n, nutrients.map((n) => n.id).toSet(), 'nutrients');
  for (final k in n.keys) {
    if (n[k] != null) nonnegative(n, k);
  }
  f['nutrients'] = n;
  final e = f['estimated'] ?? <String>[];
  if (e is! List || e.any((v) => !nutrients.any((n) => n.id == v))) {
    fail('invalid_estimated');
  }
  f['estimated'] = e;
}
