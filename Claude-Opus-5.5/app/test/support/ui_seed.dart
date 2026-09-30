import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphhealth/core/cli/describe.dart';
import 'package:morphhealth/core/food/off_client.dart';
import 'package:morphhealth/core/model/entries.dart';
import 'package:morphhealth/core/model/enums.dart';
import 'package:morphhealth/core/model/food.dart';
import 'package:morphhealth/core/model/settings.dart';
import 'package:morphhealth/core/service/morphhealth_service.dart';
import 'package:morphhealth/core/service/repository.dart';
import 'package:morphhealth/core/util/clock.dart';

import 'ui_harness.dart';

/// Realistic data around today: an imported history plus entries today.
Future<void> seedData(Repository repo, {AppLanguage language = AppLanguage.de}) async {
  const clock = SystemClock();
  final today = clock.today();
  final s = MorphHealthService(
    repo: repo,
    clock: clock,
    defaultFoodApi: FoodApiConfig('https://food.example.test', 'UA'),
  );
  final doc = exampleDocument();
  // Regular past periods that end before the seeded current period.
  doc['periods'] = [
    for (var k = 4; k >= 1; k--)
      {
        'start': today.addDays(-2 - 28 * k).toIso(),
        'end': today.addDays(-2 - 28 * k + 4).toIso(),
      },
  ];
  doc['cycle_days'] = <Object>[];
  await s.importDocument(doc);
  await s.updateSettings(s.settings.copyWith(
    language: language,
    goals: const Goals(energyKcal: 2000, proteinG: 70, waterMl: 2000),
  ));
  final food = FoodProfile(
    source: FoodSource.custom,
    name: 'Haferflocken mit sehr langem Namen zur Prüfung des Layouts',
    brand: 'Hausmarke',
    servingSize: 40,
    servingLabel: '1 Portion',
    nutrients: {'energy_kcal': 372, 'protein_g': 13.5, 'carbohydrates_g': 58.7, 'fat_g': 7, 'iron_mg': 4.2},
  );
  await s.addFoodEntry(date: today, time: 7 * 60 + 30, meal: Meal.breakfast, amount: 1.5, unit: AmountUnit.portion, food: food);
  await s.addFoodEntry(date: today, time: 12 * 60, meal: Meal.lunch, amount: 250, unit: AmountUnit.g, food: food);
  await s.addWater(today, 500, time: 9 * 60);
  await s.addCaffeine(today, 80, time: 10 * 60, label: 'Kaffee');
  await s.saveWeight(WeightEntry.create(date: today, time: 7 * 60, value: 68.4, unit: WeightUnit.kg, now: clock.nowUtc()));
  await s.saveWeight(WeightEntry.create(date: today.addDays(-5), time: 7 * 60, value: 68.9, unit: WeightUnit.kg, now: clock.nowUtc()));
  await s.saveSymptom(SymptomEntry.create(date: today, time: 8 * 60, name: 'Kopfschmerzen', intensity: 6, note: 'nach dem Aufstehen', now: clock.nowUtc()));
  await s.startPeriod(today.addDays(-1));
}

Future<void> openTab(WidgetTester tester, IconData icon) async {
  await tester.tap(find.byIcon(icon).last);
  await tester.pumpAndSettle();
}

/// Visits every main screen and the most important sub-pages. [check] is
/// called on each of them.
Future<void> screenTour(WidgetTester tester, Future<void> Function(String screen) check) async {
  await check('overview');

  await openTab(tester, Icons.restaurant_outlined);
  expect(find.textContaining('Haferflocken'), findsWidgets);
  await check('nutrition day');
  await tester.tap(find.byType(Tab).last);
  await tester.pumpAndSettle();
  await check('nutrition trend');
  await tester.tap(find.byType(Tab).first);
  await tester.pumpAndSettle();

  await tapVisible(tester, find.textContaining('Haferflocken').first);
  expect(find.byType(TextFormField), findsWidgets);
  await check('edit entry');
  await goBack(tester);

  await tapVisible(tester, find.byIcon(Icons.add_circle_outline).first);
  await check('food search');
  await goBack(tester);

  await openTab(tester, Icons.water_drop_outlined);
  await check('cycle');
  await tapVisible(tester, find.byIcon(Icons.info_outline).first);
  await check('cycle explanation');
  tester.state<NavigatorState>(find.byType(Navigator).first).pop();
  await tester.pumpAndSettle();

  await openTab(tester, Icons.monitor_weight_outlined);
  await check('weight');
  await openTab(tester, Icons.healing_outlined);
  expect(find.text('Kopfschmerzen'), findsWidgets);
  await check('symptoms');
  await tester.tap(find.byType(Tab).last);
  await tester.pumpAndSettle();
  await check('symptom trend');

  await tester.tap(find.byIcon(Icons.search).first);
  await tester.pumpAndSettle();
  expect(find.byType(FilterChip), findsNWidgets(4));
  await check('history');
  await goBack(tester);

  await tester.tap(find.byIcon(Icons.settings_outlined).first);
  await tester.pumpAndSettle();
  await check('settings');
  await goBack(tester);

  await openTab(tester, Icons.dashboard_outlined);
  await tapVisible(tester, find.byIcon(Icons.today_outlined).first);
  await check('day detail');
  await goBack(tester);
}
