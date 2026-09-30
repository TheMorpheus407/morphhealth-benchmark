import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:morphhealth/application.dart';
import 'package:morphhealth/core/engine.dart';
import 'package:morphhealth/core/food_api.dart';
import 'package:morphhealth/core/model.dart';
import 'package:morphhealth/core/storage.dart';
import 'package:morphhealth/ui/controller.dart';
import 'package:morphhealth/ui/common.dart';
import 'package:morphhealth/ui/editors.dart';
import 'package:morphhealth/ui/food_screens.dart';

class MemoryVault extends VaultStore {
  MemoryVault(super.directory, super.key);
  @override
  Future<void> write(HealthData data) async {}
}

void main() {
  late Directory dir;
  late AppController c;
  setUp(() async {
    await initializeDateFormatting('de');
    await initializeDateFormatting('en');
    dir = await Directory('.dart_tool').createTemp('mh-ui-');
    c = AppController(
      HealthEngine(
        MemoryVault(dir, List.filled(32, 9)),
        HealthData.empty(),
        clock: BusinessClock(DateTime(2026, 9, 20, 12)),
      ),
      FoodApi('https://localhost:8788', 'MorphHealth UI tests'),
    );
  });
  tearDown(() async {
    await dir.delete(recursive: true);
  });
  Future<void> start(WidgetTester t) async {
    t.view.physicalSize = const Size(412, 916);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(MorphHealthApp(controller: c));
    await t.pumpAndSettle();
  }

  Future<void> io(WidgetTester t) async {
    await t.pumpAndSettle();
  }

  testWidgets(
    'German/English navigation and overview visibility are immediately applied',
    (t) async {
      await start(t);
      expect(find.text('Dein Tag, in deinem Tempo.'), findsOneWidget);
      await t.tap(find.text('Optionen'));
      await t.pumpAndSettle();
      expect(find.text('Dein MorphHealth'), findsOneWidget);
      await t.runAsync(
        () => c.change((d) {
          d.settings['language'] = 'en';
          d.settings['sections']['cycle'] = false;
        }),
      );
      await t.pumpAndSettle();
      expect(find.text('Your MorphHealth'), findsOneWidget);
      await t.tap(find.text('Overview'));
      await t.pumpAndSettle();
      expect(find.text('Your day, at your pace.'), findsOneWidget);
      expect(find.text('Your personal estimate'), findsNothing);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'custom food can be created and entered with all micronutrient fields',
    (t) async {
      await start(t);
      final context = t.element(find.byType(AppShell));
      editFood(context);
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const ValueKey('food-name')), 'My oats');
      await t.enterText(find.byKey(const ValueKey('food-calories')), '370');
      await t.enterText(find.byKey(const ValueKey('food-protein')), '13');
      final scroll = find
          .descendant(
            of: find.byType(FoodEditor),
            matching: find.byType(Scrollable),
          )
          .first;
      await t.scrollUntilVisible(
        find.text('Alle Vitamine und Mineralstoffe'),
        300,
        scrollable: scroll,
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Alle Vitamine und Mineralstoffe'));
      await t.pumpAndSettle();
      await t.scrollUntilVisible(
        find.byKey(const ValueKey('food-vitamin_b7')),
        300,
        scrollable: scroll,
      );
      await t.enterText(find.byKey(const ValueKey('food-vitamin_b7')), '8,5');
      await t.scrollUntilVisible(
        find.text('Speichern'),
        300,
        scrollable: scroll,
      );
      await t.pumpAndSettle();
      await t.runAsync(() async {
        await t.tap(find.text('Speichern'));
        await c.whenIdle();
      });
      await io(t);
      expect(c.data['foods'].single['nutrients']['vitamin_b7'], 8.5);
      editConsumption(t.element(find.byType(AppShell)), c.data['foods'].single);
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const ValueKey('consumption-amount')), '50');
      await t.scrollUntilVisible(
        find.text('Speichern'),
        300,
        scrollable: find
            .descendant(
              of: find.byType(FormFrame),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await t.pumpAndSettle();
      await t.runAsync(() async {
        await t.tap(find.text('Speichern'));
        await c.whenIdle();
      });
      await io(t);
      expect(c.data['consumption'].length, 1);
      expect(c.engine.nutritionDay('2026-09-20')['nutrients']['calories'], 185);
      expect(
        c.engine.nutritionDay('2026-09-20')['nutrients']['vitamin_b7'],
        4.25,
      );
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'symptom editor supports zero intensity, edit and history search',
    (t) async {
      await start(t);
      editRecord(t.element(find.byType(AppShell)), 'symptoms');
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const ValueKey('symptom-name')), 'Headache');
      await t.scrollUntilVisible(
        find.text('Speichern'),
        200,
        scrollable: find
            .descendant(
              of: find.byType(FormFrame),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await t.pumpAndSettle();
      await t.runAsync(() async {
        await t.tap(find.text('Speichern'));
        await c.whenIdle();
      });
      await io(t);
      expect(c.data['symptoms'].single['intensity'], 0);
      await t.tap(find.text('Historie'));
      await t.pumpAndSettle();
      await t.enterText(
        find.byKey(const ValueKey('history-search')),
        'Headache',
      );
      await t.pump(const Duration(milliseconds: 250));
      await t.pumpAndSettle();
      expect(find.widgetWithText(ListTile, 'Headache'), findsOneWidget);
      await t.tap(find.widgetWithText(ListTile, 'Headache'));
      await t.pumpAndSettle();
      await t.enterText(find.byKey(const ValueKey('symptom-name')), 'Migraine');
      await t.scrollUntilVisible(
        find.text('Speichern'),
        200,
        scrollable: find
            .descendant(
              of: find.byType(FormFrame),
              matching: find.byType(Scrollable),
            )
            .first,
      );
      await t.pumpAndSettle();
      await t.runAsync(() async {
        await t.tap(find.text('Speichern'));
        await c.whenIdle();
      });
      await io(t);
      expect(c.data['symptoms'].single['name'], 'Migraine');
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'offline food picker starts with local foods and explicit online opt-in',
    (t) async {
      await start(t);
      pickFood(t.element(find.byType(AppShell)));
      await t.pumpAndSettle();
      expect(find.text('Lokal'), findsOneWidget);
      await t.tap(find.text('Online suchen'));
      await t.pumpAndSettle();
      expect(find.text('Online-Suche aktivieren'), findsOneWidget);
      expect(c.data.settings['online_enabled'], false);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('main screens remain usable at enlarged Android font size', (
    t,
  ) async {
    await start(t);
    t.platformDispatcher.textScaleFactorTestValue = 1.7;
    addTearDown(t.platformDispatcher.clearTextScaleFactorTestValue);
    await t.pumpAndSettle();
    for (final label in [
      'Zyklus',
      'Historie',
      'Optionen',
      'Ernährung',
      'Übersicht',
    ]) {
      await t.tap(find.text(label).last);
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
    }
  });
}
