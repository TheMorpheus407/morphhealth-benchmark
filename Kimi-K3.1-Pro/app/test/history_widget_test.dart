import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:morphhealth/ui/nutrition_ui.dart';

import 'core_fixtures.dart';
import 'widget_test.dart' show pumpApp;

void main() {
  setUpAll(() async {
    await initializeDateFormatting('de');
    await initializeDateFormatting('en');
  });

  testWidgets('History result opens and edits the productive intake', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    tester.binding.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(
      tester.binding.platformDispatcher.clearTextScaleFactorTestValue,
    );
    final repository = await pumpApp(tester);
    await repository.saveFood(testFood());
    await repository.saveIntake(testFoodIntake());
    await tester.tap(find.text('Historie'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('history-search')),
      'Testmüsli',
    );
    await tester.pumpAndSettle();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    final result = find.widgetWithText(ListTile, 'Testmüsli');
    expect(result, findsOneWidget);
    await tester.tap(result);
    await tester.pumpAndSettle();
    expect(find.byType(IntakeEditPage), findsOneWidget);
    await tester.enterText(find.byKey(const ValueKey('intake-amount')), '150');
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
    expect(repository.state.intakes.single.amount, 150);
    expect(tester.takeException(), isNull);
  });
}
