import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:morphhealth/main.dart' as app;
import 'package:morphhealth/ui/app.dart';
import 'package:morphhealth/ui/controller.dart';
import 'package:provider/provider.dart';

Future<void> settle(WidgetTester tester) async {
  await tester.pumpAndSettle(const Duration(milliseconds: 200));
}

Future<void> makeVisible(WidgetTester tester, Finder finder) async {
  for (var attempt = 0; attempt < 30 && finder.evaluate().isEmpty; attempt++) {
    await tester.drag(find.byType(ListView).last, const Offset(0, -500));
    await settle(tester);
  }
  expect(finder, findsWidgets);
  await tester.ensureVisible(finder.first);
  await settle(tester);
}

Future<void> tap(WidgetTester tester, Finder finder) async {
  await makeVisible(tester, finder);
  await tester.tap(finder.first);
  await settle(tester);
}

Future<void> enter(WidgetTester tester, Finder finder, String value) async {
  await makeVisible(tester, finder);
  await tester.enterText(finder.first, value);
  await settle(tester);
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('complete Android diary and live food flow', (tester) async {
    await app.main();
    await settle(tester);
    expect(find.byType(MainShell), findsOneWidget);
    final element = tester.element(find.byType(MainShell));
    final controller = element.read<AppController>();
    await controller.repository.wipe();
    await settle(tester);

    await tester.tap(find.text('Ernährung').last);
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('quick-water')));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('water-250')));
    await settle(tester);
    expect(controller.state.intakes.single.amount, 250);

    await tester.tap(find.text('Lebensmittel'));
    await settle(tester);
    await tap(tester, find.byKey(const ValueKey('add-food')));
    await enter(tester, find.byKey(const ValueKey('food-name')), 'Testhafer');
    await enter(
      tester,
      find.byKey(const ValueKey('edit-nutrient-calories')),
      '250',
    );
    await enter(
      tester,
      find.byKey(const ValueKey('edit-nutrient-protein')),
      '12',
    );
    await tap(tester, find.byKey(const ValueKey('save-food')));
    expect(controller.state.foods.single.name, 'Testhafer');
    expect(controller.state.foods.single.nutrients['vitamin_b12'], isNull);

    await tap(tester, find.text('Testhafer'));
    await tap(tester, find.byKey(const ValueKey('add-food-intake')));
    await tap(tester, find.byKey(const ValueKey('save-intake')));
    expect(controller.state.intakes, hasLength(2));
    await tester.tap(find.byType(BackButton));
    await settle(tester);

    await tester.tap(find.text('Tag'));
    await settle(tester);
    await tap(tester, find.byKey(const ValueKey('add-food-entry')));
    await enter(
      tester,
      find.byKey(const ValueKey('food-search-query')),
      'apfel',
    );
    await tap(tester, find.byKey(const ValueKey('food-search-submit')));
    expect(find.textContaining('Einträge'), findsWidgets);
    await enter(
      tester,
      find.byKey(const ValueKey('food-barcode')),
      '4000405002377',
    );
    await tap(tester, find.byKey(const ValueKey('food-barcode-submit')));
    const productName = 'Vegane Pommersche Apfel und Zwieben';
    expect(find.text(productName), findsWidgets);
    await tap(tester, find.text(productName));
    await tap(tester, find.byKey(const ValueKey('add-food-intake')));
    await tap(tester, find.byKey(const ValueKey('save-intake')));
    expect(controller.state.foods, hasLength(2));
    expect(controller.state.intakes, hasLength(3));
    await tester.tap(find.byType(BackButton));
    await settle(tester);
    await tester.tap(find.byType(BackButton));
    await settle(tester);

    await tester.tap(find.text('Übersicht').last);
    await settle(tester);
    await tap(tester, find.byTooltip('Gewichtsverlauf'));
    await tap(tester, find.text('Gewicht erfassen'));
    await enter(tester, find.byType(TextFormField).first, '72,5');
    await tap(tester, find.text('Speichern'));
    expect(controller.state.weights.single.kg, 72.5);
    await tester.tap(find.byType(BackButton));
    await settle(tester);

    await tap(tester, find.byTooltip('Symptomverlauf'));
    await tap(tester, find.text('Symptom erfassen'));
    await enter(tester, find.byType(TextFormField).first, 'Testkopfschmerz');
    await tap(tester, find.text('Speichern'));
    expect(controller.state.symptoms.single.name, 'Testkopfschmerz');
    await tester.tap(find.byType(BackButton));
    await settle(tester);

    await tester.tap(find.text('Zyklus').last);
    await settle(tester);
    await tester.pump(const Duration(seconds: 5));
    await settle(tester);
    await tap(tester, find.byKey(const ValueKey('add-period')));
    await tap(tester, find.byKey(const ValueKey('save-period')));
    expect(controller.state.periods, hasLength(1));
    expect(controller.state.periods.single.end, isNull);

    await tester.tap(find.text('Historie'));
    await settle(tester);
    await enter(
      tester,
      find.byKey(const ValueKey('history-search')),
      'Testhafer',
    );
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump(const Duration(seconds: 5));
    await settle(tester);
    final historyResult = find.widgetWithText(ListTile, 'Testhafer');
    expect(historyResult, findsOneWidget);
    await tap(tester, historyResult);
    await enter(tester, find.byKey(const ValueKey('intake-amount')), '150');
    await tap(tester, find.byKey(const ValueKey('save-intake')));
    expect(
      controller.state.intakes
          .firstWhere((entry) => entry.foodName == 'Testhafer')
          .amount,
      150,
    );

    await tester.tap(find.text('Zyklus'));
    await settle(tester);
    await tap(
      tester,
      find.byKey(ValueKey('cycle-day-${controller.selectedDate}')),
    );
    expect(find.text('Testhafer'), findsWidgets);
    await makeVisible(tester, find.text('Testkopfschmerz'));
    expect(find.text('Testkopfschmerz'), findsOneWidget);
  });
}
