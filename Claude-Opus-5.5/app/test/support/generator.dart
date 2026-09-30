import 'dart:math';

import 'package:morphhealth/core/util/local_date.dart';

/// Generates a realistic multi-year portable document (deterministic).
///
/// With the defaults (3.5 years ending 2026-09-22) it contains roughly
/// 10,500 diary entries across all four areas.
Map<String, Object?> generateDataset({
  LocalDate? end,
  int days = 1280,
  int seed = 42,
}) {
  final last = end ?? LocalDate(2026, 9, 22);
  final first = last.addDays(-(days - 1));
  final r = Random(seed);
  String t(int minutes) => TimeOfDayMinutes.format(minutes.clamp(0, 1439));

  final foods = <Map<String, Object?>>[
    for (final f in _foodPool)
      {
        'id': 'food-${f.$1.toLowerCase().replaceAll(RegExp(r'[^a-z]'), '')}',
        'source': 'custom',
        'name': f.$1,
        'basis': f.$2,
        'serving_size': f.$3,
        'serving_label': f.$3 == null ? null : '1 Portion',
        'favorite': r.nextInt(4) == 0,
        'nutrients': f.$4,
      },
  ];

  final foodEntries = <Map<String, Object?>>[];
  final water = <Map<String, Object?>>[];
  final caffeine = <Map<String, Object?>>[];
  final weights = <Map<String, Object?>>[];
  final symptoms = <Map<String, Object?>>[];
  final periods = <Map<String, Object?>>[];
  final cycleDays = <Map<String, Object?>>[];

  var weightKg = 72.0;
  var nextPeriod = first.addDays(3);
  var n = 0;
  String id(String prefix) => '$prefix-${n++}';

  for (var i = 0; i < days; i++) {
    final day = first.addDays(i);
    final date = day.toIso();
    final meals = [
      ('breakfast', 7 * 60 + r.nextInt(120)),
      ('lunch', 12 * 60 + r.nextInt(90)),
      ('dinner', 18 * 60 + r.nextInt(120)),
      if (r.nextBool()) ('snack', 15 * 60 + r.nextInt(120)),
    ];
    for (final (meal, minute) in meals) {
      final food = foods[r.nextInt(foods.length)];
      final hasServing = food['serving_size'] != null && r.nextBool();
      foodEntries.add({
        'id': id('fe'),
        'date': date,
        'time': t(minute),
        'meal': meal,
        'amount': hasServing ? (1 + r.nextInt(2)).toDouble() : (50 + r.nextInt(250)).toDouble(),
        'unit': hasServing ? 'portion' : food['basis'],
        'food': {
          'ref': food['id'],
          for (final k in const ['source', 'name', 'basis', 'serving_size', 'serving_label', 'nutrients'])
            k: food[k],
        },
      });
    }
    for (var w = 0; w < 2 + r.nextInt(3); w++) {
      water.add({'id': id('w'), 'date': date, 'time': t(8 * 60 + w * 180), 'amount_ml': [150, 250, 330, 500][r.nextInt(4)]});
    }
    if (r.nextInt(3) != 0) {
      caffeine.add({'id': id('c'), 'date': date, 'time': t(10 * 60), 'amount_mg': [40, 80, 120][r.nextInt(3)], 'label': 'Kaffee'});
    }
    if (i % 3 == 0) {
      weightKg += (r.nextDouble() - 0.5) * 0.6;
      weights.add({'id': id('kg'), 'date': date, 'time': t(7 * 60), 'value': double.parse(weightKg.toStringAsFixed(1)), 'unit': 'kg'});
    }
    if (r.nextInt(2) == 0) {
      symptoms.add({
        'id': id('s'),
        'date': date,
        'time': t(20 * 60),
        'name': _symptoms[r.nextInt(_symptoms.length)],
        'intensity': r.nextInt(11),
        'note': r.nextInt(5) == 0 ? 'Notiz $i' : null,
      });
    }
    if (day == nextPeriod) {
      final length = 4 + r.nextInt(3);
      final end = day.addDays(length - 1);
      if (end.isAtOrBefore(last)) {
        periods.add({'id': id('p'), 'start': date, 'end': end.toIso()});
        for (var k = 0; k < length; k++) {
          cycleDays.add({
            'id': id('cd'),
            'date': day.addDays(k).toIso(),
            'flow': ['heavy', 'medium', 'medium', 'light', 'light', 'spotting'][k.clamp(0, 5)],
          });
        }
      }
      nextPeriod = day.addDays(26 + r.nextInt(5));
    }
  }

  return {
    'format': 'morphhealth.portable',
    'version': 1,
    'settings': {
      'language': 'de',
      'goals': {'energy_kcal': 2000, 'protein_g': 70, 'water_ml': 2000},
    },
    'foods': foods,
    'food_entries': foodEntries,
    'water_entries': water,
    'caffeine_entries': caffeine,
    'periods': periods,
    'cycle_days': cycleDays,
    'weight_entries': weights,
    'symptom_entries': symptoms,
  };
}

int diaryEntryCount(Map<String, Object?> doc) => [
  'food_entries',
  'water_entries',
  'caffeine_entries',
  'periods',
  'cycle_days',
  'weight_entries',
  'symptom_entries',
].fold(0, (s, k) => s + (doc[k] as List).length);

const List<String> _symptoms = [
  'Kopfschmerzen',
  'Unterleibskrämpfe',
  'Müdigkeit',
  'Blähungen',
  'Rückenschmerzen',
  'Stimmungsschwankungen',
];

const List<(String, String, int?, Map<String, num>)> _foodPool = [
  ('Haferflocken', 'g', 40, {'energy_kcal': 372, 'protein_g': 13.5, 'carbohydrates_g': 58.7, 'fat_g': 7, 'fiber_g': 10, 'iron_mg': 4.2, 'magnesium_mg': 130}),
  ('Vollmilch', 'ml', 250, {'energy_kcal': 64, 'protein_g': 3.3, 'carbohydrates_g': 4.8, 'fat_g': 3.5, 'calcium_mg': 120, 'vitamin_b12_ug': 0.4, 'iodine_ug': 15}),
  ('Vollkornbrot', 'g', 50, {'energy_kcal': 214, 'protein_g': 7, 'carbohydrates_g': 38.8, 'fat_g': 1.2, 'fiber_g': 8, 'salt_g': 1.1}),
  ('Apfel', 'g', 150, {'energy_kcal': 52, 'carbohydrates_g': 11.4, 'sugars_g': 10.3, 'fiber_g': 2.4, 'vitamin_c_mg': 12, 'potassium_mg': 119}),
  ('Banane', 'g', 120, {'energy_kcal': 93, 'carbohydrates_g': 20, 'potassium_mg': 367, 'vitamin_b6_mg': 0.36, 'magnesium_mg': 30}),
  ('Linsensuppe', 'g', 350, {'energy_kcal': 68, 'protein_g': 4.3, 'carbohydrates_g': 9.4, 'fat_g': 1.1, 'iron_mg': 1.5}),
  ('Spaghetti gekocht', 'g', null, {'energy_kcal': 158, 'protein_g': 5.8, 'carbohydrates_g': 30.9, 'fat_g': 0.9}),
  ('Tomatensauce', 'g', 125, {'energy_kcal': 45, 'carbohydrates_g': 6.5, 'sugars_g': 5, 'salt_g': 0.9, 'vitamin_c_mg': 9}),
  ('Lachs', 'g', 125, {'energy_kcal': 208, 'protein_g': 20, 'fat_g': 13, 'vitamin_d_ug': 16, 'selenium_ug': 30, 'vitamin_b12_ug': 3}),
  ('Brokkoli', 'g', 200, {'energy_kcal': 34, 'protein_g': 2.8, 'vitamin_c_mg': 89, 'vitamin_k_ug': 101, 'vitamin_b9_ug': 63, 'calcium_mg': 47}),
  ('Reis gekocht', 'g', null, {'energy_kcal': 130, 'protein_g': 2.7, 'carbohydrates_g': 28}),
  ('Joghurt natur', 'g', 150, {'energy_kcal': 61, 'protein_g': 3.5, 'fat_g': 3.3, 'calcium_mg': 121, 'vitamin_b2_mg': 0.14}),
  ('Espresso', 'ml', 30, {'energy_kcal': 9, 'caffeine_mg': 212}),
  ('Orangensaft', 'ml', 200, {'energy_kcal': 45, 'carbohydrates_g': 10.4, 'sugars_g': 8.4, 'vitamin_c_mg': 50, 'potassium_mg': 200}),
  ('Käse Gouda', 'g', 30, {'energy_kcal': 356, 'protein_g': 25, 'fat_g': 27, 'saturated_fat_g': 17, 'salt_g': 2, 'calcium_mg': 700, 'phosphorus_mg': 546, 'zinc_mg': 3.9}),
  ('Nüsse gemischt', 'g', 25, {'energy_kcal': 607, 'protein_g': 20, 'fat_g': 54, 'magnesium_mg': 250, 'vitamin_e_mg': 11, 'vitamin_b1_mg': 0.5, 'vitamin_b3_mg': 4.1, 'vitamin_b5_mg': 1.1, 'vitamin_b7_ug': 30}),
];
