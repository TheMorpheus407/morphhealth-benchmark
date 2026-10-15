import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:morphhealth/main.dart';
import 'package:morphhealth/src/core/crypto_vault.dart';
import 'package:morphhealth/src/core/cycle_engine.dart';
import 'package:morphhealth/src/core/mh_protocol.dart';
import 'package:morphhealth/src/core/models.dart';
import 'package:morphhealth/src/core/nutrients.dart';
import 'package:morphhealth/src/core/off_client.dart';
import 'package:morphhealth/src/core/repository.dart';
import 'package:morphhealth/src/ui/app_state.dart';

void main() {
  group('NutrientCatalog & Open Food Facts Parsing', () {
    test('Supports all 31 required macro, extended, vitamin, and mineral nutrients', () {
      expect(NutrientCatalog.all.length, 31);
      expect(
        NutrientCatalog.byCategory(NutrientCategory.macro).length,
        4,
      );
      expect(
        NutrientCatalog.byCategory(NutrientCategory.extended).length,
        6,
      );
      expect(
        NutrientCatalog.byCategory(NutrientCategory.vitamin).length,
        13,
      );
      expect(
        NutrientCatalog.byCategory(NutrientCategory.mineral).length,
        8,
      );
    });

    test('Parses Open Food Facts v3.6 nutrition.aggregated_set and v1/v2 nutriments', () {
      final v3Product = {
        'code': '20003166',
        'product_name_de': 'Haferflocken',
        'brands': 'Crownfield',
        'serving_quantity': 50,
        'nutrition': {
          'aggregated_set': {
            'per': '100g',
            'nutrients': {
              'energy-kcal': {'value': 372, 'unit': 'kcal'},
              'proteins': {'value': 13.5, 'unit': 'g'},
              'carbohydrates': {'value': 58.7, 'unit': 'g'},
              'fat': {'value': 7.0, 'unit': 'g'},
              'saturated-fat': {'value': 1.3, 'unit': 'g'},
              'sugars': {'value': 0.7, 'unit': 'g'},
              'fiber': {'value': 10.0, 'unit': 'g'},
              'salt': {'value': 0.02, 'unit': 'g'},
              'sodium': {'value': 0.008, 'unit': 'g'},
              'iron': {'value': 0.0043, 'unit': 'g'},
              'magnesium': {'value': 0.13, 'unit': 'g'},
              'phosphorus': {'value': 0.43, 'unit': 'g'},
              'vitamin-b1': {'value': 0.0006, 'unit': 'g'},
              'biotin': {'value': 0.00002, 'unit': 'g'},
            },
          },
        },
      };

      final item = FoodItem.fromOpenFoodFactsProduct(v3Product);
      expect(item.name, 'Haferflocken');
      expect(item.servingQuantityG, 50.0);
      expect(item.nutrientsPer100g.caloriesKcal, closeTo(372.0, 0.01));
      expect(item.nutrientsPer100g.proteinG, closeTo(13.5, 0.01));
      expect(item.nutrientsPer100g.sodiumMg, closeTo(8.0, 0.01));
      expect(item.nutrientsPer100g['iron_mg'], closeTo(4.3, 0.01));
      expect(item.nutrientsPer100g['magnesium_mg'], closeTo(130.0, 0.01));
      expect(item.nutrientsPer100g['phosphorus_mg'], closeTo(430.0, 0.01));
      expect(item.nutrientsPer100g['vitamin_b1_mg'], closeTo(0.6, 0.01));
      expect(item.nutrientsPer100g['vitamin_b7_ug'], closeTo(20.0, 0.01));

      // Portion scaling (2 portions of 50g = 100g)
      final twoPortions = item.nutrientsForQuantity(2.0, FoodUnit.portion);
      expect(twoPortions.caloriesKcal, closeTo(372.0, 0.01));
    });
  });

  group('CycleForecastEngine', () {
    test('Evaluates multi-cycle history and filters >90d unlogged outlier gaps', () {
      final periods = [
        const PeriodEntry(
          id: 'p1',
          startDate: '2026-01-01',
          endDate: '2026-01-05',
          intensity: BleedingIntensity.medium,
        ),
        // >90d gap (e.g. paused logging) until July
        const PeriodEntry(
          id: 'p2',
          startDate: '2026-07-10',
          endDate: '2026-07-14',
          intensity: BleedingIntensity.medium,
        ),
        const PeriodEntry(
          id: 'p3',
          startDate: '2026-08-07',
          endDate: '2026-08-11',
          intensity: BleedingIntensity.light,
        ),
        const PeriodEntry(
          id: 'p4',
          startDate: '2026-09-05',
          endDate: '2026-09-09',
          intensity: BleedingIntensity.heavy,
        ),
        const PeriodEntry(
          id: 'p5',
          startDate: '2026-10-03',
          endDate: '2026-10-07',
          intensity: BleedingIntensity.spotting,
        ),
      ];

      final res = CycleForecastEngine.evaluate(
        periods: periods,
        onDate: '2026-10-15',
      );
      expect(res.hasSufficientData, isTrue);
      expect(res.hasPersonalCycleIntervals, isTrue);
      expect(res.skippedOutlierGapsCount, 1);
      expect(res.completedCyclesCount, 3);
      expect(res.cycleLengthsHistoryDays, [28, 29, 28]);
      expect(res.expectedStartDate, '2026-10-31');
      expect(res.explanationDe, contains('28, 29, 28'));
      expect(res.explanationEn, contains('28, 29, 28'));
    });
  });

  group('CryptoVault & Encrypted Backups', () {
    test('Encrypts and decrypts MHV1 vault and PBKDF2 backups; rejects tampering', () async {
      final key = CryptoVault.generateRandomBytes(32);
      final payload = {'hello': 'morphhealth', 'count': 42};
      final encrypted = await CryptoVault.encryptVaultPayload(payload, key);
      expect(encrypted.sublist(0, 4), [0x4D, 0x48, 0x56, 0x31]);

      final decrypted = await CryptoVault.decryptVaultPayload(encrypted, key);
      expect(decrypted['hello'], 'morphhealth');
      expect(decrypted['count'], 42);

      // Tamper with a byte
      final tampered = Uint8List.fromList(encrypted);
      tampered[tampered.length - 1] ^= 0xFF;
      expect(
        () => CryptoVault.decryptVaultPayload(tampered, key),
        throwsA(isA<VaultCryptoException>()),
      );

      // Encrypted backup roundtrip
      final backup = await CryptoVault.createEncryptedBackup(
        portableDocument: payload,
        passphrase: 'correct-horse-battery-staple',
        createdAtIso: '2026-10-15T10:00:00Z',
      );
      final restored = await CryptoVault.decryptEncryptedBackup(
        backupEnvelope: backup,
        passphrase: 'correct-horse-battery-staple',
      );
      expect(restored['hello'], 'morphhealth');

      expect(
        () => CryptoVault.decryptEncryptedBackup(
          backupEnvelope: backup,
          passphrase: 'wrong-password',
        ),
        throwsA(isA<VaultCryptoException>()),
      );
    });
  });

  group('Repository, mh Protocol & 10,000-Entry Performance', () {
    test('Handles all 7 mh ops and 10,000 diary entries rapidly', () async {
      final tmp = Directory.systemTemp.createTempSync('mh_test_');
      try {
        final dataDir = '${tmp.path}/data';
        final keyFile = '${tmp.path}/master.key';
        File(keyFile).writeAsBytesSync(CryptoVault.generateRandomBytes(32));

        final repo = MorphHealthRepository(
          dataDirPath: dataDir,
          keyFilePath: keyFile,
          clock: () => DateTime.utc(2026, 10, 15, 10, 0),
        );
        await repo.initialize();

        final mockHttp = MockClient((req) async {
          if (req.url.path.contains('/cgi/search.pl')) {
            return http.Response(
              jsonEncode({
                'count': 1,
                'page': 1,
                'page_size': 20,
                'products': [
                  {
                    'code': '12345678',
                    'product_name_de': 'Test Apfel',
                    'nutriments': {
                      'energy-kcal_100g': 52,
                      'carbohydrates_100g': 14,
                      'vitamin-c_100g': 0.0046,
                    },
                  },
                ],
              }),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }
          if (req.url.path.contains('/api/v3.6/product/12345678.json')) {
            return http.Response(
              jsonEncode({
                'status': 'success',
                'code': '12345678',
                'product': {
                  'code': '12345678',
                  'product_name_de': 'Test Apfel',
                  'nutrition': {
                    'aggregated_set': {
                      'per': '100g',
                      'nutrients': {
                        'energy-kcal': {'value': 52, 'unit': 'kcal'},
                        'vitamin-c': {'value': 0.0046, 'unit': 'g'},
                      },
                    },
                  },
                },
              }),
              200,
              headers: {'content-type': 'application/json; charset=utf-8'},
            );
          }
          return http.Response('Not found', 404);
        });

        final off = OpenFoodFactsClient(
          baseUrl: 'https://localhost:8788',
          userAgent: 'TestAgent/1.0',
          httpClient: mockHttp,
        );
        final handler = MhProtocolHandler(repository: repo, offClient: off);

        final desc = await handler.handleRequest({
          'request_id': 'r1',
          'op': 'describe',
        });
        expect(desc['ok'], isTrue);
        final sampleDoc =
            desc['data']['example_document'] as Map<String, dynamic>;

        final imp = await handler.handleRequest({
          'request_id': 'r2',
          'op': 'portable.import',
          'document': sampleDoc,
          'confirm_replace': true,
        });
        expect(imp['ok'], isTrue);

        final day = await handler.handleRequest({
          'request_id': 'r3',
          'op': 'nutrition.day',
          'date': '2026-10-15',
        });
        expect(day['ok'], isTrue);
        expect(day['data']['calories_kcal'], closeTo(279.0, 0.1));
        expect(day['data']['water_ml'], closeTo(800.0, 0.1));

        final cyc = await handler.handleRequest({
          'request_id': 'r4',
          'op': 'cycle.forecast',
          'on': '2026-10-15',
        });
        expect(cyc['ok'], isTrue);
        expect(cyc['data']['expected_start_date'], '2026-10-31');

        final srch = await handler.handleRequest({
          'request_id': 'r5',
          'op': 'food.search',
          'q': 'Apfel',
          'page': 1,
        });
        expect(srch['ok'], isTrue);
        expect((srch['data']['products'] as List).first['name'], 'Test Apfel');

        final lkp = await handler.handleRequest({
          'request_id': 'r6',
          'op': 'food.lookup',
          'barcode': '12345678',
        });
        expect(lkp['ok'], isTrue);
        expect(
          lkp['data']['nutrients_per_100g']['vitamin_c_mg'],
          closeTo(4.6, 0.01),
        );

        final exp = await handler.handleRequest({
          'request_id': 'r7',
          'op': 'portable.export',
          'ack_plaintext': true,
        });
        expect(exp['ok'], isTrue);

        // Now verify 10,000-entry bulk generation & query speed
        final sw = Stopwatch()..start();
        await repo.generateBulkDataset(targetTotalEntries: 10000);
        expect(repo.totalDiaryEntryCount, 10000);

        final historyAll = repo.searchHistory();
        expect(historyAll.length, 10000);

        final historyFiltered = repo.searchHistory(
          domain: 'symptoms',
          query: 'Kopfschmerzen',
        );
        expect(historyFiltered.isNotEmpty, isTrue);
        sw.stop();
        expect(sw.elapsedMilliseconds, lessThan(5000));
      } finally {
        tmp.deleteSync(recursive: true);
      }
    });
  });

  group('MorphHealthApp Widget Test', () {
    testWidgets('Renders German default UI, switches language, and navigates tabs', (tester) async {
      await tester.binding.setSurfaceSize(const Size(412, 915));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final tmp = Directory.systemTemp.createTempSync('mh_widget_');
      addTearDown(() => tmp.deleteSync(recursive: true));

      final ctrl = MorphHealthController();
      await tester.runAsync(() async {
        await ctrl.init(
          overrideDataDir: '${tmp.path}/data',
          overrideKeyFile: '${tmp.path}/master.key',
          clock: () => DateTime.utc(2026, 10, 15, 10, 0),
        );
        await ctrl.loadSampleDataset();
      });

      await tester.pumpWidget(MorphHealthApp(controller: ctrl));
      await tester.pumpAndSettle();

      // Verify German default UI
      expect(find.text('MorphHealth'), findsOneWidget);
      expect(find.text('Übersicht'), findsWidgets);
      expect(find.text('Ernährung'), findsWidgets);
      expect(find.text('Zyklus'), findsWidgets);

      // Switch to English via top language chip
      await tester.runAsync(() async {
        await ctrl.setLanguage('en');
      });
      await tester.pumpAndSettle();
      expect(find.text('Overview'), findsWidgets);
      expect(find.text('Nutrition'), findsWidgets);

      // Switch back to German
      await tester.runAsync(() async {
        await ctrl.setLanguage('de');
      });
      await tester.pumpAndSettle();

      // Navigate to Nutrition tab
      await tester.tap(find.byIcon(Icons.restaurant_outlined));
      await tester.pumpAndSettle();
      expect(find.text('Wasser & Koffein'), findsOneWidget);

      // Navigate to Cycle tab
      await tester.tap(find.byIcon(Icons.favorite_outline));
      await tester.pumpAndSettle();
      expect(find.text('Persönliche Zykluseinschätzung'), findsOneWidget);

      // Navigate to Weight & Symptoms tab
      await tester.tap(find.byIcon(Icons.monitor_weight_outlined).last);
      await tester.pumpAndSettle();
      expect(find.textContaining('64.5 kg'), findsWidgets);

      // Navigate to History & Data tab
      await tester.tap(find.byIcon(Icons.history_outlined));
      await tester.pumpAndSettle();
      expect(find.text('Durchsuchbare Historie'), findsOneWidget);
    });
  });
}
