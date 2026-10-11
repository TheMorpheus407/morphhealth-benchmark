// Beispieldokument für `describe` (zum Import geeignet).
library;

import '../model/document.dart';

/// Ein kleines, vollständiges portables Dokument als Import-Beispiel.
Map<String, dynamic> examplePortableDocument() {
  return <String, dynamic>{
    'format': portableFormat,
    'format_version': portableFormatVersion,
    'generator': <String, dynamic>{
      'app': 'MorphHealth',
      'version': '1.0.0+1',
      'exported_at': '2026-09-23T12:00:00.000Z',
    },
    'data': <String, dynamic>{
      'settings': <String, dynamic>{
        'language': 'de',
        'weight_unit': 'kg',
        'visible_areas': <String>['nutrition', 'cycle', 'weight', 'symptoms'],
        'goals': <String, dynamic>{'water_ml': 2000, 'energy_kcal': 2000},
      },
      'foods': <dynamic>[
        <String, dynamic>{
          'id': '00000000-0000-4000-8000-000000000001',
          'name': 'Beispiel: Haferflocken',
          'brand': 'MorphHealth Beispiel',
          'source': 'custom',
          'per100': <String, dynamic>{
            'energy_kcal': 372,
            'protein_g': 13.5,
            'carbohydrates_g': 58.7,
            'fat_g': 7,
            'fiber_g': 10,
            'calcium_mg': 54,
            'iron_mg': 4.3,
          },
          'serving': <String, dynamic>{'grams': 40, 'label': '1 Portion'},
          'is_favorite': true,
          'created_at': '2026-09-20T08:00:00.000Z',
          'updated_at': '2026-09-20T08:00:00.000Z',
        },
      ],
      'nutrition_entries': <dynamic>[
        <String, dynamic>{
          'id': '00000000-0000-4000-8000-000000000002',
          'food_id': '00000000-0000-4000-8000-000000000001',
          'food_name': 'Beispiel: Haferflocken',
          'food_per100': <String, dynamic>{'energy_kcal': 372, 'protein_g': 13.5},
          'food_serving_grams': 40,
          'date': '2026-09-23',
          'time': '07:30',
          'meal': 'breakfast',
          'quantity': 1.5,
          'unit': 'portion',
          'created_at': '2026-09-23T07:31:00.000Z',
        },
      ],
      'water_entries': <dynamic>[
        <String, dynamic>{
          'id': '00000000-0000-4000-8000-000000000003',
          'date': '2026-09-23',
          'time': '08:00',
          'amount_ml': 500,
        },
      ],
      'caffeine_entries': <dynamic>[
        <String, dynamic>{
          'id': '00000000-0000-4000-8000-000000000004',
          'date': '2026-09-23',
          'time': '09:15',
          'amount_mg': 80,
          'note': 'Tasse Kaffee',
        },
      ],
      'periods': <dynamic>[
        <String, dynamic>{
          'id': '00000000-0000-4000-8000-000000000005',
          'start': '2026-08-28',
          'end': '2026-09-01',
          'flow': 'medium',
          'flow_by_day': <String, dynamic>{'2026-08-28': 2, '2026-08-29': 3},
          'note': 'Beispielperiode',
        },
      ],
      'weight_entries': <dynamic>[
        <String, dynamic>{
          'id': '00000000-0000-4000-8000-000000000006',
          'date': '2026-09-23',
          'time': '07:00',
          'weight_kg': 72.5,
        },
      ],
      'symptom_entries': <dynamic>[
        <String, dynamic>{
          'id': '00000000-0000-4000-8000-000000000007',
          'name': 'Kopfschmerzen',
          'intensity': 4,
          'date': '2026-09-23',
          'time': '14:00',
          'note': 'leichte Intensität',
        },
      ],
    },
  };
}
