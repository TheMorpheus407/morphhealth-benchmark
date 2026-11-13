import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;

import 'package:morphhealth/core/clock.dart';
import 'package:morphhealth/core/crypto_vault.dart';
import 'package:morphhealth/core/models.dart';
import 'package:morphhealth/core/nutrients.dart';
import 'package:morphhealth/core/open_food_facts_client.dart';
import 'package:morphhealth/core/portable_codec.dart';
import 'package:morphhealth/core/store.dart';
import 'package:morphhealth/main.dart';
import 'package:morphhealth/ui/app_controller.dart';
import 'package:morphhealth/ui/platform_bridge.dart';

class _FakePlatformBridge implements PlatformBridge {
  final String dataDir;
  Uint8List key;

  _FakePlatformBridge(this.dataDir, this.key);

  @override
  Future<AppBootstrapCredentials> getAppPathsAndMasterKey() async =>
      AppBootstrapCredentials(dataDir: dataDir, masterKey: key);

  @override
  Future<Uint8List> rotateMasterKey() async {
    key = VaultCrypto.randomBytes(32);
    return key;
  }

  @override
  Future<bool> saveDocument({
    required String fileName,
    required String mimeType,
    required Uint8List bytes,
  }) async =>
      true;

  @override
  Future<PickedDocument?> openDocument() async => null;
}

void main() {
  testWidgets(
      'End-to-end UI workflows: German/English, Overview toggles, Nutrition relog, Cycle forecast, Weight kg/lb, History search',
      (WidgetTester tester) async {
    // Exact reference geometry: 1080x2400 at 420 dpi (scale 2.625 -> 411.4 x 914.3 dp)
    await tester.binding.setSurfaceSize(const Size(412, 915));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    late Directory tempDir;
    late AppController controller;

    await tester.runAsync(() async {
      final base = Directory(
        p.join(Directory.current.path, '.dart_tool', 'test_tmp'),
      );
      if (!base.existsSync()) {
        await base.create(recursive: true);
      }
      tempDir = await base.createTemp('mh_widget_');
      final key = VaultCrypto.randomBytes(32);
      final clock = FixedClock.fromRfc3339('2026-09-23T10:00:00+02:00');
      final store = await MorphHealthStore.open(
        dataDir: tempDir.path,
        masterKey: key,
        clock: clock,
      );
      await store.importPortableDocument(
        PortableCodec.buildExampleDocument(
          referenceNowRfc3339: '2026-09-23T10:00:00+02:00',
        ),
      );
      controller = AppController(
        store: store,
        platformBridge: _FakePlatformBridge(tempDir.path, key),
        foodClient: OpenFoodFactsClient(
          baseUrl: 'https://mock.local',
          userAgent: 'MorphHealthWidgetTest/1.0',
          httpClient: MockClient((_) async => http.Response('{}', 404)),
          clock: clock,
        ),
      );
    });

    await tester.pumpWidget(
      MorphHealthBootstrap(injectedController: controller),
    );
    await tester.pumpAndSettle();

    // 1. Default German navigation & Overview
    expect(find.text('Übersicht'), findsOneWidget);
    expect(find.text('Tagesdetail öffnen'), findsOneWidget);
    expect(find.text('7-/28-Tage-Verläufe'), findsOneWidget);

    // Open Unified Day Detail and 7d/28d Trends from Overview (verifies zero layout overflow & clean Hero transitions)
    await tester.tap(find.text('Tagesdetail öffnen'));
    await tester.pumpAndSettle();
    expect(find.text('Gemeinsames Tagesdetail'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    await tester.tap(find.text('7-/28-Tage-Verläufe'));
    await tester.pumpAndSettle();
    expect(find.text('Verläufe (7 & 28 Tage)'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    // Quick-add +250 ml water from Overview
    expect(controller.store.nutritionForDay('2026-09-23').waterMl, 330);
    await tester.runAsync(() async {
      await controller.quickAddWater(250);
    });
    await tester.pumpAndSettle();
    expect(controller.store.nutritionForDay('2026-09-23').waterMl, 580);

    // Toggle hiding Symptoms module in Overview
    await tester.runAsync(() async {
      await controller.toggleOverviewModule(AppModule.symptoms);
    });
    await tester.pumpAndSettle();
    expect(
      controller.preferences.visibleOverviewModules.contains(AppModule.symptoms),
      isFalse,
    );

    // 2. Navigate to Nutrition Diary and scroll to Breakfast entry
    controller.setNavIndex(1);
    await tester.pumpAndSettle();
    expect(find.text('Ernährungstagebuch'), findsOneWidget);

    await tester.scrollUntilVisible(
      find.text('Zarte Haferflocken Vollkorn'),
      250,
      scrollable: find.descendant(
        of: find.byType(Scaffold).first,
        matching: find.byType(Scrollable),
      ).first,
    );
    expect(find.text('Zarte Haferflocken Vollkorn'), findsWidgets);

    // Re-log meal entry and verify calories double (279 -> 558 kcal)
    await tester.runAsync(() async {
      final firstEntry = controller.store
          .nutritionForDay('2026-09-23')
          .allMealEntries
          .first
          .entry;
      await controller.relogMealEntry(firstEntry);
    });
    await tester.pumpAndSettle();
    expect(
      controller.store
          .nutritionForDay('2026-09-23')
          .combinedNutrients
          .valueOrZero(NutrientKey.caloriesKcal),
      closeTo(558.0, 0.1),
    );

    // 3. Navigate to Cycle Tracker & open personal forecast explanation
    controller.setNavIndex(2);
    await tester.pumpAndSettle();
    expect(find.text('Persönlicher Periodentracker'), findsOneWidget);
    await tester.tap(find.text('Einschätzung erklären'));
    await tester.pumpAndSettle();
    expect(find.text('Persönliche Zykluseinschätzung'), findsOneWidget);
    await tester.tap(find.text('Schließen'));
    await tester.pumpAndSettle();

    // 4. Navigate to Body (Weight & Symptoms) and convert kg -> lb
    controller.setNavIndex(3);
    await tester.pumpAndSettle();
    expect(find.text('66.4 kg'), findsOneWidget);
    await tester.runAsync(() async {
      await controller.updatePreferences(
        controller.preferences.copyWith(weightUnit: WeightUnit.lb),
      );
    });
    await tester.pumpAndSettle();
    expect(find.text('146.4 lb'), findsOneWidget);

    // 5. Navigate to Unified Searchable History
    controller.setNavIndex(4);
    await tester.pumpAndSettle();
    expect(find.textContaining('Unterleibsziehen'), findsOneWidget);

    // 6. Switch UI to English live and verify NavigationBar labels
    await tester.runAsync(() async {
      await controller.updatePreferences(
        controller.preferences.copyWith(localeCode: 'en'),
      );
    });
    await tester.pumpAndSettle();
    final navBar = find.byType(NavigationBar);
    expect(
      find.descendant(of: navBar, matching: find.text('Overview')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: navBar, matching: find.text('Nutrition')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: navBar, matching: find.text('Cycle')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: navBar, matching: find.text('Body')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: navBar, matching: find.text('History')),
      findsOneWidget,
    );

    await tester.runAsync(() async {
      controller.dispose();
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });
  });
}
