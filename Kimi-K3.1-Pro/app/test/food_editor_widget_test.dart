import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:morphhealth/ui/food_ui.dart';
import 'package:morphhealth/ui/nutrition_ui.dart';

import 'core_fixtures.dart';
import 'widget_test.dart' show pumpApp;

void main() {
  setUpAll(() async {
    await initializeDateFormatting('de');
    await initializeDateFormatting('en');
  });

  testWidgets('All custom food nutrient fields fit the reference device', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    tester.binding.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(
      tester.binding.platformDispatcher.clearTextScaleFactorTestValue,
    );
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await pumpApp(tester);
    await tester.tap(find.text('Ernährung').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lebensmittel'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add-food')));
    await tester.pumpAndSettle();
    for (final entry in [
      (const ValueKey('edit-nutrient-calories'), '250'),
      (const ValueKey('edit-nutrient-protein'), '12'),
    ]) {
      for (
        var attempt = 0;
        attempt < 30 && find.byKey(entry.$1).evaluate().isEmpty;
        attempt++
      ) {
        await tester.drag(find.byType(ListView).last, const Offset(0, -500));
        await tester.pumpAndSettle();
      }
      await tester.ensureVisible(find.byKey(entry.$1));
      await tester.enterText(find.byKey(entry.$1), entry.$2);
      await tester.pumpAndSettle();
    }
    for (
      var attempt = 0;
      attempt < 30 &&
          find.byKey(const ValueKey('save-food')).evaluate().isEmpty;
      attempt++
    ) {
      await tester.drag(find.byType(ListView).last, const Offset(0, -500));
      await tester.pumpAndSettle();
    }
    expect(find.byKey(const ValueKey('save-food')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Food details and intake editor preserve their routes', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    tester.binding.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(
      tester.binding.platformDispatcher.clearTextScaleFactorTestValue,
    );
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final repository = await pumpApp(tester);
    await repository.saveFood(testFood());
    await tester.tap(find.text('Ernährung').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Lebensmittel'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Testmüsli'));
    await tester.pumpAndSettle();
    expect(find.byType(FoodDetailsPage), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Testmüsli'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('add-food-intake')));
    await tester.pumpAndSettle();
    expect(find.byType(IntakeEditPage), findsOneWidget);
    expect(tester.takeException(), isNull);
    for (
      var attempt = 0;
      attempt < 30 &&
          find.byKey(const ValueKey('save-intake')).evaluate().isEmpty;
      attempt++
    ) {
      await tester.drag(find.byType(ListView).last, const Offset(0, -500));
      await tester.pumpAndSettle();
    }
    await tester.tap(find.byKey(const ValueKey('save-intake')));
    await tester.pumpAndSettle();
    expect(find.byType(FoodDetailsPage), findsOneWidget);
    expect(find.byType(BackButton), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.byType(FoodDetailsPage), findsNothing);
  });
}
