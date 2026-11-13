/// Portable JSON export/import codec and self-describing schema documentation
/// for P07 and P10 (`describe`, `portable.export`, `portable.import`).
library;

import 'clock.dart';
import 'models.dart';
import 'nutrients.dart';

class PortableBundle {
  final String exportedAt;
  final UserPreferences preferences;
  final NutritionGoals goals;
  final List<FoodItem> foods;
  final List<FoodDiaryEntry> mealEntries;
  final List<WaterEntry> waterEntries;
  final List<CaffeineEntry> caffeineEntries;
  final List<PeriodEntry> periods;
  final List<WeightEntry> weightEntries;
  final List<SymptomEntry> symptomEntries;

  const PortableBundle({
    required this.exportedAt,
    required this.preferences,
    required this.goals,
    required this.foods,
    required this.mealEntries,
    required this.waterEntries,
    required this.caffeineEntries,
    required this.periods,
    required this.weightEntries,
    required this.symptomEntries,
  });

  int get totalDiaryEntriesCount =>
      mealEntries.length +
      waterEntries.length +
      caffeineEntries.length +
      periods.length +
      weightEntries.length +
      symptomEntries.length;

  Map<String, int> get countsSummary => {
        'foods': foods.length,
        'meal_entries': mealEntries.length,
        'water_entries': waterEntries.length,
        'caffeine_entries': caffeineEntries.length,
        'periods': periods.length,
        'weight_entries': weightEntries.length,
        'symptom_entries': symptomEntries.length,
        'total_diary_entries': totalDiaryEntriesCount,
      };
}

class PortableCodec {
  static const String formatName = 'morphhealth.portable';
  static const int schemaVersion = 1;
  static const String appVersion = '1.0.0';

  static Map<String, dynamic> encode(PortableBundle bundle) {
    return {
      'format': formatName,
      'schema_version': schemaVersion,
      'app_version': appVersion,
      'exported_at': bundle.exportedAt,
      'preferences': bundle.preferences.toJson(),
      'goals': bundle.goals.toJson(),
      'foods': bundle.foods.map((f) => f.toJson()).toList(),
      'meal_entries': bundle.mealEntries.map((e) => e.toJson()).toList(),
      'water_entries': bundle.waterEntries.map((e) => e.toJson()).toList(),
      'caffeine_entries': bundle.caffeineEntries.map((e) => e.toJson()).toList(),
      'periods': bundle.periods.map((e) => e.toJson()).toList(),
      'weight_entries': bundle.weightEntries.map((e) => e.toJson()).toList(),
      'symptom_entries': bundle.symptomEntries.map((e) => e.toJson()).toList(),
    };
  }

  static PortableBundle decodeAndValidate(Map<String, dynamic> doc) {
    if (doc['format'] != formatName) {
      throw FormatValidationException(
        'Unsupported portable document format "${doc['format']}". Expected "$formatName".',
      );
    }
    if (doc['schema_version'] != schemaVersion) {
      throw FormatValidationException(
        'Unsupported portable schema_version "${doc['schema_version']}". Expected $schemaVersion.',
      );
    }
    final exportedAtRaw =
        (doc['exported_at'] as String?) ?? '2026-01-01T00:00:00Z';
    Rfc3339.parseStrict(exportedAtRaw);

    final prefsObj = doc['preferences'];
    if (prefsObj != null && prefsObj is! Map<String, dynamic>) {
      throw const FormatValidationException('"preferences" must be a JSON object.');
    }
    final goalsObj = doc['goals'];
    if (goalsObj != null && goalsObj is! Map<String, dynamic>) {
      throw const FormatValidationException('"goals" must be a JSON object.');
    }

    final prefs = UserPreferences.fromJson(prefsObj as Map<String, dynamic>?);
    final goals = NutritionGoals.fromJson(goalsObj as Map<String, dynamic>?);

    List<T> parseList<T>(
      String field,
      T Function(Map<String, dynamic>) parser,
      String Function(T) idOf,
    ) {
      final raw = doc[field];
      if (raw == null) return <T>[];
      if (raw is! List) {
        throw FormatValidationException('"$field" must be a JSON array.');
      }
      final seenIds = <String>{};
      final out = <T>[];
      for (var i = 0; i < raw.length; i++) {
        final item = raw[i];
        if (item is! Map<String, dynamic>) {
          throw FormatValidationException('"$field[$i]" must be a JSON object.');
        }
        final parsed = parser(item);
        final id = idOf(parsed);
        if (!seenIds.add(id)) {
          throw FormatValidationException(
            'Duplicate id "$id" found in "$field".',
          );
        }
        out.add(parsed);
      }
      return out;
    }

    final foods = parseList('foods', FoodItem.fromJson, (x) => x.id);
    final mealEntries =
        parseList('meal_entries', FoodDiaryEntry.fromJson, (x) => x.id);
    final waterEntries =
        parseList('water_entries', WaterEntry.fromJson, (x) => x.id);
    final caffeineEntries =
        parseList('caffeine_entries', CaffeineEntry.fromJson, (x) => x.id);
    final periods = parseList('periods', PeriodEntry.fromJson, (x) => x.id);
    final weightEntries =
        parseList('weight_entries', WeightEntry.fromJson, (x) => x.id);
    final symptomEntries =
        parseList('symptom_entries', SymptomEntry.fromJson, (x) => x.id);

    // Ensure every meal entry has a corresponding catalog FoodItem (synthesize from snapshot if absent)
    final foodMap = {for (final f in foods) f.id: f};
    for (final entry in mealEntries) {
      if (!foodMap.containsKey(entry.foodId)) {
        foodMap[entry.foodId] = FoodItem(
          id: entry.foodId,
          source: entry.foodId.startsWith('off:')
              ? FoodSource.openFoodFacts
              : FoodSource.custom,
          barcode: entry.foodId.startsWith('off:')
              ? entry.foodId.substring(4)
              : null,
          name: entry.foodNameSnapshot,
          brand: entry.brandSnapshot,
          servingQuantity: entry.servingQuantitySnapshot,
          nutrientsPer100: entry.nutrientsPer100Snapshot,
          createdAt: entry.recordedAt,
          updatedAt: entry.recordedAt,
        );
      }
    }

    return PortableBundle(
      exportedAt: exportedAtRaw,
      preferences: prefs,
      goals: goals,
      foods: foodMap.values.toList(),
      mealEntries: mealEntries,
      waterEntries: waterEntries,
      caffeineEntries: caffeineEntries,
      periods: periods,
      weightEntries: weightEntries,
      symptomEntries: symptomEntries,
    );
  }

  /// Generates a complete, valid, import-ready example document for `describe`.
  static Map<String, dynamic> buildExampleDocument({
    String referenceNowRfc3339 = '2026-09-23T09:00:00+02:00',
  }) {
    const oatmealNutrients = NutrientProfile({
      NutrientKey.caloriesKcal: 372,
      NutrientKey.proteinG: 13.5,
      NutrientKey.carbsG: 58.7,
      NutrientKey.fatG: 7.0,
      NutrientKey.saturatedFatG: 1.3,
      NutrientKey.sugarG: 0.7,
      NutrientKey.fiberG: 10.0,
      NutrientKey.saltG: 0.02,
      NutrientKey.sodiumMg: 8.0,
      NutrientKey.vitaminB1Mg: 0.59,
      NutrientKey.vitaminB5Mg: 1.3,
      NutrientKey.vitaminB6Mg: 0.12,
      NutrientKey.vitaminB7Ug: 20.0,
      NutrientKey.vitaminB9Ug: 56.0,
      NutrientKey.calciumMg: 54.0,
      NutrientKey.ironMg: 4.3,
      NutrientKey.magnesiumMg: 139.0,
      NutrientKey.potassiumMg: 397.0,
      NutrientKey.zincMg: 3.9,
      NutrientKey.seleniumUg: 9.7,
      NutrientKey.phosphorusMg: 430.0,
    });

    final bundle = PortableBundle(
      exportedAt: referenceNowRfc3339,
      preferences: const UserPreferences(
        localeCode: 'de',
        weightUnit: WeightUnit.kg,
      ),
      goals: const NutritionGoals(
        waterMl: 2200,
        caloriesKcal: 2100,
        proteinG: 90,
        carbsG: 240,
        fatG: 70,
      ),
      foods: const [
        FoodItem(
          id: 'custom_oatmeal_01',
          source: FoodSource.custom,
          name: 'Zarte Haferflocken Vollkorn',
          nameDe: 'Zarte Haferflocken Vollkorn',
          nameEn: 'Rolled Wholegrain Oats',
          brand: 'Eigenes Lebensmittel',
          nutritionBasis: '100g',
          servingQuantity: 50,
          servingLabel: '1 Schale (50 g)',
          nutrientsPer100: oatmealNutrients,
          isFavorite: true,
          createdAt: '2026-09-01T08:00:00+02:00',
          updatedAt: '2026-09-01T08:00:00+02:00',
        ),
      ],
      mealEntries: const [
        FoodDiaryEntry(
          id: 'meal_sample_01',
          date: '2026-09-23',
          recordedAt: '2026-09-23T08:15:00+02:00',
          mealType: MealType.breakfast,
          foodId: 'custom_oatmeal_01',
          foodNameSnapshot: 'Zarte Haferflocken Vollkorn',
          brandSnapshot: 'Eigenes Lebensmittel',
          amount: 1.5,
          unit: AmountUnit.portion,
          servingQuantitySnapshot: 50,
          nutrientsPer100Snapshot: oatmealNutrients,
          note: 'Mit warmem Wasser und Zimt',
        ),
      ],
      waterEntries: const [
        WaterEntry(
          id: 'water_sample_01',
          date: '2026-09-23',
          recordedAt: '2026-09-23T08:20:00+02:00',
          amountMl: 330,
          note: 'Morgens ein Glas Wasser',
        ),
      ],
      caffeineEntries: const [
        CaffeineEntry(
          id: 'caff_sample_01',
          date: '2026-09-23',
          recordedAt: '2026-09-23T08:30:00+02:00',
          amountMg: 65,
          sourceLabel: 'Espresso',
        ),
      ],
      periods: const [
        PeriodEntry(
          id: 'period_sample_01',
          startDate: '2026-07-30',
          endDate: '2026-08-03',
          intensity: FlowIntensity.medium,
          dailyFlows: {
            '2026-07-30': FlowIntensity.light,
            '2026-07-31': FlowIntensity.heavy,
            '2026-08-03': FlowIntensity.spotting,
          },
        ),
        PeriodEntry(
          id: 'period_sample_02',
          startDate: '2026-08-27',
          endDate: '2026-08-31',
          intensity: FlowIntensity.medium,
          note: 'Regulärer Verlauf',
        ),
      ],
      weightEntries: [
        WeightEntry.fromInput(
          id: 'weight_sample_01',
          date: '2026-09-23',
          recordedAt: '2026-09-23T07:45:00+02:00',
          value: 66.4,
          unit: WeightUnit.kg,
        ),
      ],
      symptomEntries: const [
        SymptomEntry(
          id: 'sym_sample_01',
          date: '2026-09-23',
          recordedAt: '2026-09-23T18:00:00+02:00',
          name: 'Unterleibsziehen',
          intensity: 3,
          note: 'Abends leicht spürbar',
        ),
      ],
    );
    return encode(bundle);
  }

  static Map<String, dynamic> buildProtocolDescription({
    required String nowRfc3339,
    required String foodBaseUrl,
    required String foodUserAgent,
  }) {
    return {
      'application': 'MorphHealth',
      'version': appVersion,
      'clock_now': nowRfc3339,
      'food_api': {
        'base_url': foodBaseUrl,
        'user_agent': foodUserAgent,
        'endpoints': {
          'lookup': 'GET {base}/api/v3.6/product/{barcode}.json',
          'search':
              'GET {base}/cgi/search.pl?search_terms={q}&search_simple=1&action=process&json=1&page={p}&page_size=20',
        },
      },
      'storage_encryption': {
        'master_key': '32 raw bytes from --key-file (located outside --data-dir)',
        'kdf': 'HKDF-SHA256 (RFC 5869) with 16-byte random per-vault salt',
        'aead': 'ChaCha20-Poly1305 (RFC 8439, 96-bit nonce, 128-bit MAC)',
        'files_in_data_dir': {
          'vault.mhv1': 'AEAD-encrypted gzip snapshot with authenticated MHVAULT1 header',
          'vault.wal.mhv1': 'AEAD-encrypted append-only mutation frames bound to epoch & monotonic sequence',
        },
        'encrypted_backup_format': {
          'format': 'morphhealth.encrypted-backup',
          'schema_version': 1,
          'kdf': 'Argon2id (RFC 9106, 32 MiB, p=2, t=3)',
          'aead': 'ChaCha20-Poly1305 over gzip-compressed morphhealth.portable JSON',
        },
      },
      'portable_format': {
        'format': formatName,
        'schema_version': schemaVersion,
        'top_level_fields': {
          'format': 'Fixed string "morphhealth.portable"',
          'schema_version': 'Integer 1',
          'app_version': 'Application version string',
          'exported_at': 'RFC3339 timestamp',
          'preferences':
              'Object {locale_code: "de"|"en", weight_unit: "kg"|"lb", visible_overview_modules: ["nutrition","cycle","weight","symptoms"], cycle_diary_only_mode: bool, online_food_enabled: bool, water_quick_amounts_ml: int[]}',
          'goals':
              'Object {water_ml, calories_kcal, protein_g, carbs_g, fat_g} (each number > 0 or null)',
          'foods': 'Array of FoodItem objects (custom and cached Open Food Facts items)',
          'meal_entries':
              'Array of FoodDiaryEntry objects (meal_type in breakfast|lunch|dinner|snack; unit in g|ml|portion)',
          'water_entries': 'Array of WaterEntry objects (amount_ml > 0)',
          'caffeine_entries': 'Array of CaffeineEntry objects (amount_mg > 0)',
          'periods':
              'Array of PeriodEntry objects (start_date, optional end_date, intensity in spotting|light|medium|heavy, daily_flows map, counts_as_period bool, note)',
          'weight_entries':
              'Array of WeightEntry objects (weight_kg, input_unit in kg|lb, input_value)',
          'symptom_entries':
              'Array of SymptomEntry objects (name, intensity integer 0..10, date, recorded_at, note)',
        },
        'nutrients_supported': [
          for (final k in NutrientKey.values)
            {
              'key': k.jsonKey,
              'unit': k.unit,
              'category': k.category.name,
              'label_de': k.labelDe,
              'label_en': k.labelEn,
            },
        ],
      },
      'operations': {
        'describe': {
          'input': <String, String>{},
          'output':
              'Full specification of formats, nutrients, operations, and example_portable_document.',
        },
        'portable.export': {
          'input': {'ack_plaintext': 'boolean (must be true)'},
          'output':
              'Complete portable document (format = "morphhealth.portable") representing the working dataset.',
          'errors': ['ACK_REQUIRED'],
        },
        'portable.import': {
          'input': {
            'document': 'Object conforming to morphhealth.portable v1',
            'confirm_replace': 'boolean (must be true)',
          },
          'output':
              'Object {replaced: true, imported_at: RFC3339, counts: {foods, meal_entries, water_entries, caffeine_entries, periods, weight_entries, symptom_entries, total_diary_entries}}.',
          'errors': ['CONFIRMATION_REQUIRED', 'INVALID_DOCUMENT'],
        },
        'nutrition.day': {
          'input': {'date': 'String YYYY-MM-DD'},
          'output':
              'Daily nutrition report {date, water_ml, caffeine_from_foods_mg, caffeine_direct_mg, total_caffeine_mg, nutrients (all 31 keys), goals, meals (breakfast/lunch/dinner/snack), meal_entries, water_entries, caffeine_entries}.',
          'errors': ['INVALID_ARGUMENT'],
        },
        'cycle.forecast': {
          'input': {'on': 'String YYYY-MM-DD'},
          'output':
              'Personal cycle evaluation {on, status, confidence, diary_only_mode, is_period_active_on_date, current_cycle_day, last_period_start, predicted_next_start, predicted_next_end, predicted_window_start, predicted_window_end, days_until_expected_start, expected_cycle_length_days, expected_period_duration_days, variability_days, statistics, explanation: {de, en}}.',
          'errors': ['INVALID_ARGUMENT'],
        },
        'food.search': {
          'input': {
            'q': 'Non-empty search query string',
            'page': 'Positive integer >= 1 (default 1)',
          },
          'output':
              'Paginated search results {query, page, page_size: 20, total_count, page_count, items: FoodItem[]}.',
          'errors': ['INVALID_ARGUMENT', 'NETWORK_ERROR', 'TIMEOUT', 'UPSTREAM_HTTP_ERROR'],
        },
        'food.lookup': {
          'input': {'barcode': 'Barcode string (4-32 chars)'},
          'output': 'Object {barcode, item: FoodItem}.',
          'errors': [
            'INVALID_ARGUMENT',
            'PRODUCT_NOT_FOUND',
            'NETWORK_ERROR',
            'TIMEOUT',
            'UPSTREAM_HTTP_ERROR',
          ],
        },
      },
      'example_portable_document': buildExampleDocument(
        referenceNowRfc3339: nowRfc3339,
      ),
    };
  }
}
