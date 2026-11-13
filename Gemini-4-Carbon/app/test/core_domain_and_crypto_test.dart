import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;

import 'package:morphhealth/core/clock.dart';
import 'package:morphhealth/core/crypto_vault.dart';
import 'package:morphhealth/core/cycle_engine.dart';
import 'package:morphhealth/core/mh_rpc_handler.dart';
import 'package:morphhealth/core/models.dart';
import 'package:morphhealth/core/nutrients.dart';
import 'package:morphhealth/core/open_food_facts_client.dart';
import 'package:morphhealth/core/portable_codec.dart';
import 'package:morphhealth/core/store.dart';

void main() {
  late Directory testRoot;

  setUp(() async {
    final base = Directory(p.join(Directory.current.path, '.dart_tool', 'test_tmp'));
    if (!base.existsSync()) {
      await base.create(recursive: true);
    }
    testRoot = await base.createTemp('mh_unit_');
  });

  tearDown(() async {
    if (testRoot.existsSync()) {
      await testRoot.delete(recursive: true);
    }
  });

  test('Supports all 31 required nutrients across g, ml, and portion', () {
    expect(NutrientKey.values.length, 31);
    expect(NutrientKey.byCategory(NutrientCategory.macro).length, 4);
    expect(NutrientKey.byCategory(NutrientCategory.extended).length, 6);
    expect(NutrientKey.byCategory(NutrientCategory.vitamin).length, 13);
    expect(NutrientKey.byCategory(NutrientCategory.mineral).length, 8);

    final fullProfile = NutrientProfile({
      for (var i = 0; i < NutrientKey.values.length; i++)
        NutrientKey.values[i]: (i + 1) * 2.0,
    });

    final food = FoodItem(
      id: 'custom_full',
      source: FoodSource.custom,
      name: 'Vollständiges Testlebensmittel',
      servingQuantity: 40.0,
      nutrientsPer100: fullProfile,
      createdAt: '2026-09-23T08:00:00Z',
      updatedAt: '2026-09-23T08:00:00Z',
    );

    // 2.5 portions * 40g = 100g -> exact 1.0x profile
    final scaledPortion = food.computeNutrientsFor(2.5, AmountUnit.portion);
    for (final k in NutrientKey.values) {
      expect(scaledPortion.valueOrZero(k), closeTo(fullProfile.valueOrZero(k), 1e-6));
    }

    // 50 ml -> 0.5x profile
    final scaledMl = food.computeNutrientsFor(50, AmountUnit.ml);
    expect(
      scaledMl.valueOrZero(NutrientKey.vitaminB12Ug),
      closeTo(fullProfile.valueOrZero(NutrientKey.vitaminB12Ug) * 0.5, 1e-6),
    );
  });

  test('OpenFoodFactsClient parses v3.6 lookup and search.pl contract identically', () async {
    String? capturedUserAgent;
    final mockHttp = MockClient((request) async {
      capturedUserAgent = request.headers['User-Agent'];
      if (request.url.path == '/api/v3.6/product/5411188112709.json') {
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'status': 'success',
              'product': {
                'code': '5411188112709',
                'product_name_de': 'Geröstete Mandel Ohne Zucker',
                'brands': 'Alpro',
                'serving_size': '1 portion (200 ml)',
                'serving_quantity': 200.0,
                'serving_quantity_unit': 'ml',
                'nutriments': <String, dynamic>{},
                'nutrition': {
                  'aggregated_set': {
                    'per': '100g',
                    'nutrients': {
                      'energy-kcal': {
                        'source': 'packaging',
                        'source_per': '100ml',
                        'unit': 'kcal',
                        'value': 14,
                      },
                      'proteins': {
                        'source': 'packaging',
                        'unit': 'g',
                        'value': 0.5,
                      },
                      'calcium': {
                        'source': 'packaging',
                        'unit': 'g',
                        'value': 0.12,
                      },
                      'vitamin-b12': {
                        'source': 'packaging',
                        'unit': 'g',
                        'value': 3.8e-7,
                      },
                      'iron': {
                        'source': 'estimate',
                        'modifier': '~',
                        'unit': 'g',
                        'value': 0.0001,
                      },
                    },
                  },
                },
              },
            }),
          ),
          200,
        );
      }
      if (request.url.path == '/api/v3.6/product/99999999.json') {
        return http.Response('{"status":"failure"}', 404);
      }
      if (request.url.path == '/cgi/search.pl') {
        expect(request.url.queryParameters['search_terms'], 'red bull');
        expect(request.url.queryParameters['page'], '2');
        expect(request.url.queryParameters['page_size'], '20');
        return http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'count': 25,
              'page': 2,
              'products': [
                {
                  'code': '9002490100070',
                  'product_name_de': 'Red Bull Energy Drink',
                  'brands': 'Red Bull',
                  'serving_size': '250 ml',
                  'nutriments': {
                    'energy-kcal_100g': 46,
                    'carbohydrates_100g': 11,
                    'caffeine_100g': 0.032,
                    'vitamin-pp_100g': 0.008,
                    'pantothenic-acid_100g': 0.002,
                  },
                },
              ],
            }),
          ),
          200,
        );
      }
      return http.Response('Not found', 404);
    });

    final client = OpenFoodFactsClient(
      baseUrl: 'https://mock-off.local',
      userAgent: 'MorphHealthTest/1.0',
      httpClient: mockHttp,
    );

    final lookedUp = await client.lookupBarcode('5411188112709');
    expect(capturedUserAgent, 'MorphHealthTest/1.0');
    expect(lookedUp.name, 'Geröstete Mandel Ohne Zucker');
    expect(lookedUp.nutritionBasis, '100ml');
    expect(lookedUp.servingQuantity, 200.0);
    expect(lookedUp.nutrientsPer100[NutrientKey.caloriesKcal], 14.0);
    expect(lookedUp.nutrientsPer100[NutrientKey.calciumMg], closeTo(120.0, 1e-6));
    expect(lookedUp.nutrientsPer100[NutrientKey.vitaminB12Ug], closeTo(0.38, 1e-6));
    // Estimated ingredient guess was excluded
    expect(lookedUp.nutrientsPer100.containsKey(NutrientKey.ironMg), isFalse);

    await expectLater(
      () => client.lookupBarcode('99999999'),
      throwsA(isA<FoodNotFoundException>()),
    );

    final searchRes = await client.searchProducts(query: 'red bull', page: 2);
    expect(searchRes.totalCount, 25);
    expect(searchRes.pageCount, 2);
    expect(searchRes.items.single.nutrientsPer100[NutrientKey.caffeineMg], closeTo(32.0, 1e-6));
    expect(searchRes.items.single.nutrientsPer100[NutrientKey.vitaminB3Mg], closeTo(8.0, 1e-6));
    expect(searchRes.items.single.nutrientsPer100[NutrientKey.vitaminB5Mg], closeTo(2.0, 1e-6));
  });

  test('CycleForecastEngine evaluates personal history, DST, spotting, and outliers', () {
    // 0 periods
    final empty = CycleForecastEngine.evaluate(
      allPeriods: const [],
      onDate: '2026-10-26',
    );
    expect(empty.status, 'no_history');
    expect(empty.predictedNextStart, isNull);

    // 1 period -> does NOT invent generic 28-day prediction
    final single = CycleForecastEngine.evaluate(
      allPeriods: const [
        PeriodEntry(
          id: 'p1',
          startDate: '2026-10-01',
          endDate: '2026-10-05',
          intensity: FlowIntensity.medium,
        ),
      ],
      onDate: '2026-10-15',
    );
    expect(single.status, 'awaiting_second_period');
    expect(single.currentCycleDay, 15);
    expect(single.predictedNextStart, isNull);

    // Multi-cycle history across October DST + 1 outlier gap (120 days) + standalone spotting
    final periods = [
      const PeriodEntry(
        id: 'p0_gap',
        startDate: '2026-02-01',
        endDate: '2026-02-05',
        intensity: FlowIntensity.medium,
      ),
      const PeriodEntry(
        id: 'p1',
        startDate: '2026-06-01', // 120d gap -> excluded as outlier
        endDate: '2026-06-05',
        intensity: FlowIntensity.medium,
      ),
      const PeriodEntry(
        id: 'p2',
        startDate: '2026-06-30', // 29d
        endDate: '2026-07-04',
        intensity: FlowIntensity.heavy,
      ),
      const PeriodEntry(
        id: 'spot_mid',
        startDate: '2026-07-15', // standalone spotting -> ignored as cycle start
        endDate: '2026-07-15',
        intensity: FlowIntensity.spotting,
        countsAsPeriod: false,
      ),
      const PeriodEntry(
        id: 'p3',
        startDate: '2026-07-29', // 29d
        endDate: '2026-08-02',
        intensity: FlowIntensity.medium,
      ),
      const PeriodEntry(
        id: 'p4',
        startDate: '2026-08-28', // 30d
        endDate: '2026-09-01',
        intensity: FlowIntensity.medium,
      ),
      const PeriodEntry(
        id: 'p5',
        startDate: '2026-09-26', // 29d
        endDate: '2026-09-30',
        intensity: FlowIntensity.light,
      ),
    ];

    final fc = CycleForecastEngine.evaluate(
      allPeriods: periods,
      onDate: '2026-10-20',
    );
    expect(fc.status, 'personal_forecast');
    expect(fc.confidence, 'high');
    expect(fc.statistics.excludedOutliersCount, 1);
    expect(fc.statistics.standaloneSpottingCount, 1);
    expect(fc.statistics.cyclesUsedCount, 4);
    expect(fc.expectedCycleLengthDays, 29);
    expect(fc.predictedNextStart, '2026-10-25'); // across Europe/Berlin DST date!

    // Diary-only mode hides forecast fields in serialized output
    final diaryOnly = CycleForecastEngine.evaluate(
      allPeriods: periods,
      onDate: '2026-10-20',
      diaryOnlyMode: true,
    );
    expect(diaryOnly.toJson()['predicted_next_start'], isNull);
  });

  test('Encrypted vault, WAL replay, tamper detection, and Argon2id backup restore', () async {
    final dataDir = p.join(testRoot.path, 'vault');
    final keyA = VaultCrypto.randomBytes(32);
    final keyB = VaultCrypto.randomBytes(32);
    final clock = FixedClock.fromRfc3339('2026-09-23T12:00:00+02:00');

    final store1 = await MorphHealthStore.open(
      dataDir: dataDir,
      masterKey: keyA,
      clock: clock,
    );
    await store1.upsertWaterEntry(
      const WaterEntry(
        id: 'w1',
        date: '2026-09-23',
        recordedAt: '2026-09-23T09:00:00+02:00',
        amountMl: 450,
      ),
    );
    await store1.upsertSymptomEntry(
      const SymptomEntry(
        id: 's1',
        date: '2026-09-23',
        recordedAt: '2026-09-23T10:00:00+02:00',
        name: 'Kopfschmerzen',
        intensity: 6,
      ),
    );

    // Reopen from disk (replays encrypted WAL)
    final store2 = await MorphHealthStore.open(
      dataDir: dataDir,
      masterKey: keyA,
      clock: clock,
    );
    expect(store2.nutritionForDay('2026-09-23').waterMl, 450);
    expect(store2.symptomsForDay('2026-09-23').single.intensity, 6);

    // Wrong master key fails authentication
    await expectLater(
      () => MorphHealthStore.open(dataDir: dataDir, masterKey: keyB),
      throwsA(isA<VaultSecurityException>()),
    );

    // Argon2id encrypted backup -> restore onto fresh store
    final backupText = await EncryptedBackupCodec.createEncryptedBackup(
      passphrase: 'correct-horse-battery-staple',
      portableDocument: store2.exportPortableDocument(),
      createdAtRfc3339: clock.nowRfc3339(),
      memoryKiB: 4096, // fast test memory parameter
      iterations: 2,
    );

    await expectLater(
      () => EncryptedBackupCodec.decryptEncryptedBackup(
        passphrase: 'wrong-passphrase',
        backupJsonText: backupText,
      ),
      throwsA(isA<VaultSecurityException>()),
    );

    final decryptedDoc = await EncryptedBackupCodec.decryptEncryptedBackup(
      passphrase: 'correct-horse-battery-staple',
      backupJsonText: backupText,
    );

    final freshDir = p.join(testRoot.path, 'fresh_install');
    final freshStore = await MorphHealthStore.open(
      dataDir: freshDir,
      masterKey: keyB,
      clock: clock,
    );
    await freshStore.importPortableDocument(decryptedDoc);
    expect(freshStore.nutritionForDay('2026-09-23').waterMl, 450);
    expect(freshStore.symptomsForDay('2026-09-23').single.name, 'Kopfschmerzen');
  });

  test('MhRpcHandler enforces guards and handles 10,000 multi-year diary entries smoothly', () async {
    final dataDir = p.join(testRoot.path, 'perf_vault');
    final masterKey = VaultCrypto.randomBytes(32);
    final clock = FixedClock.fromRfc3339('2026-09-23T15:00:00+02:00');

    final store = await MorphHealthStore.open(
      dataDir: dataDir,
      masterKey: masterKey,
      clock: clock,
    );
    final foodClient = OpenFoodFactsClient(
      baseUrl: 'https://mock.local',
      userAgent: 'MorphHealthTest/1.0',
      httpClient: MockClient((_) async => http.Response('{}', 404)),
    );
    final rpc = MhRpcHandler(store: store, foodClient: foodClient, clock: clock);

    // Guardrail checks
    final noAck = await rpc.handleRawJsonLine(
      jsonEncode({'request_id': 1, 'op': 'portable.export'}),
    );
    expect(noAck['ok'], isFalse);
    expect(noAck['error']['code'], 'ACK_REQUIRED');

    final noConfirm = await rpc.handleRawJsonLine(
      jsonEncode({
        'request_id': 2,
        'op': 'portable.import',
        'document': PortableCodec.buildExampleDocument(),
      }),
    );
    expect(noConfirm['ok'], isFalse);
    expect(noConfirm['error']['code'], 'CONFIRMATION_REQUIRED');

    // Generate 10,000 realistic diary entries across ~1,500 days (~4+ years)
    const sampleFood = FoodItem(
      id: 'custom_perf_oats',
      source: FoodSource.custom,
      name: 'Vollkorn Haferflocken',
      servingQuantity: 60,
      nutrientsPer100: NutrientProfile({
        NutrientKey.caloriesKcal: 370,
        NutrientKey.proteinG: 13.0,
        NutrientKey.carbsG: 59.0,
        NutrientKey.fatG: 7.0,
        NutrientKey.ironMg: 4.2,
        NutrientKey.magnesiumMg: 135.0,
      }),
      createdAt: '2022-01-01T08:00:00Z',
      updatedAt: '2022-01-01T08:00:00Z',
    );

    final meals = <FoodDiaryEntry>[];
    final waters = <WaterEntry>[];
    final caffeines = <CaffeineEntry>[];
    final weights = <WeightEntry>[];
    final symptoms = <SymptomEntry>[];
    final periods = <PeriodEntry>[];

    const baseDate = '2022-08-01';
    // 5,000 meals + 2,500 waters + 1,000 caffeines + 700 weights + 750 symptoms + 50 periods = 10,000 entries
    for (var i = 0; i < 5000; i++) {
      final d = IsoDate.addDays(baseDate, i ~/ 4);
      meals.add(
        FoodDiaryEntry(
          id: 'm_$i',
          date: d,
          recordedAt: '${d}T08:30:00Z',
          mealType: MealType.values[i % 4],
          foodId: sampleFood.id,
          foodNameSnapshot: sampleFood.name,
          amount: 80,
          unit: AmountUnit.g,
          nutrientsPer100Snapshot: sampleFood.nutrientsPer100,
        ),
      );
    }
    for (var i = 0; i < 2500; i++) {
      final d = IsoDate.addDays(baseDate, i ~/ 2);
      waters.add(
        WaterEntry(
          id: 'w_$i',
          date: d,
          recordedAt: '${d}T11:00:00Z',
          amountMl: 300,
        ),
      );
    }
    for (var i = 0; i < 1000; i++) {
      final d = IsoDate.addDays(baseDate, i);
      caffeines.add(
        CaffeineEntry(
          id: 'c_$i',
          date: d,
          recordedAt: '${d}T09:00:00Z',
          amountMg: 75,
          sourceLabel: 'Espresso',
        ),
      );
    }
    for (var i = 0; i < 700; i++) {
      final d = IsoDate.addDays(baseDate, i * 2);
      weights.add(
        WeightEntry.fromInput(
          id: 'wt_$i',
          date: d,
          recordedAt: '${d}T07:30:00Z',
          value: 65.0 + (i % 10) * 0.2,
          unit: WeightUnit.kg,
        ),
      );
    }
    for (var i = 0; i < 750; i++) {
      final d = IsoDate.addDays(baseDate, i * 2);
      symptoms.add(
        SymptomEntry(
          id: 's_$i',
          date: d,
          recordedAt: '${d}T19:00:00Z',
          name: i.isEven ? 'Müdigkeit' : 'Unterleibsziehen',
          intensity: (i % 8) + 1,
        ),
      );
    }
    for (var i = 0; i < 50; i++) {
      final start = IsoDate.addDays(baseDate, i * 29);
      periods.add(
        PeriodEntry(
          id: 'p_$i',
          startDate: start,
          endDate: IsoDate.addDays(start, 4),
          intensity: FlowIntensity.medium,
        ),
      );
    }

    final bundle10k = PortableBundle(
      exportedAt: clock.nowRfc3339(),
      preferences: const UserPreferences(),
      goals: const NutritionGoals(caloriesKcal: 2000, waterMl: 2000),
      foods: const [sampleFood],
      mealEntries: meals,
      waterEntries: waters,
      caffeineEntries: caffeines,
      periods: periods,
      weightEntries: weights,
      symptomEntries: symptoms,
    );
    expect(bundle10k.totalDiaryEntriesCount, 10000);

    final swImport = Stopwatch()..start();
    final importRes = await store.importPortableDocument(
      PortableCodec.encode(bundle10k),
    );
    swImport.stop();
    expect(importRes['counts']['total_diary_entries'], 10000);
    expect(swImport.elapsedMilliseconds, lessThan(2000));

    // Cold reload of 10,000 encrypted entries
    final swLoad = Stopwatch()..start();
    final reloaded = await MorphHealthStore.open(
      dataDir: dataDir,
      masterKey: masterKey,
      clock: clock,
    );
    swLoad.stop();
    expect(reloaded.totalDiaryEntriesCount, 10000);
    expect(swLoad.elapsedMilliseconds, lessThan(1500));

    // Query & search latency on 10,000 entries
    final swQueries = Stopwatch()..start();
    final sampleDay = IsoDate.addDays(baseDate, 400);
    final daySummary = reloaded.nutritionForDay(sampleDay);
    final trend28 = reloaded.nutrientTrendSeries(
      endDateIso: sampleDay,
      days: 28,
      metricKey: NutrientKey.caloriesKcal.jsonKey,
    );
    final historyAll = reloaded.searchHistory();
    final historyFiltered = reloaded.searchHistory(
      query: 'unterleibsziehen',
      moduleFilter: AppModule.symptoms,
    );
    swQueries.stop();

    expect(daySummary.allMealEntries.length, 4);
    expect(trend28.length, 28);
    expect(historyAll.length, 10000);
    expect(historyFiltered.length, 375);
    expect(swQueries.elapsedMilliseconds, lessThan(500));

    foodClient.close();
  });
}
