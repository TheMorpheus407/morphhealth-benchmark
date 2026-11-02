import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphhealth/morphhealth.dart';
import 'package:morphhealth_core/morphhealth_core.dart';

/// Builds an [AppState] that works on a temporary directory, without any
/// platform plugin.
Future<AppState> buildState(Directory temp) async {
  final HealthRepository repository = await HealthRepository.open(
    directory: Directory('${temp.path}/data'),
    masterKey: Crypto.newMasterKey(),
  );
  await repository.load();

  final FoodItem food = FoodItem(
    id: 'f1',
    name: 'Haferflocken',
    source: FoodSource.custom,
    nutrientsPer100: const NutrientProfile(<String, double>{
      Nutrients.energyKcal: 400,
      Nutrients.protein: 12,
      Nutrients.carbohydrates: 60,
      Nutrients.fat: 8,
    }),
  );
  await repository.upsertFood(food);

  final String today = DateMath.format(DateTime.now());
  await repository.upsertJournalEntry(JournalEntry(
    id: 'e1',
    foodId: food.id,
    foodName: food.name,
    quantity: 50,
    unit: QuantityUnit.gram,
    meal: MealSlot.breakfast,
    date: today,
    loggedAtMs: DateTime.now().millisecondsSinceEpoch,
    nutrientsPer100Snapshot: food.nutrientsPer100.values,
  ));
  await repository.upsertIntake(IntakeEntry(
    id: 'i1',
    kind: IntakeKind.water,
    amount: 500,
    date: today,
    loggedAtMs: DateTime.now().millisecondsSinceEpoch,
  ));
  await repository.upsertPeriod(PeriodRecord(
    id: 'p1',
    startDate: DateMath.addDays(today, -30),
    endDate: DateMath.addDays(today, -26),
  ));
  await repository.upsertPeriod(PeriodRecord(
    id: 'p2',
    startDate: DateMath.addDays(today, -1),
    endDate: DateMath.addDays(today, 2),
  ));
  await repository.upsertWeight(WeightEntry(
    id: 'w1',
    date: today,
    valueKg: 70,
    loggedAtMs: DateTime.now().millisecondsSinceEpoch,
  ));
  await repository.upsertSymptom(SymptomEntry(
    id: 's1',
    name: 'Kopfschmerzen',
    intensity: 4,
    date: today,
    occurredAtMs: DateTime.now().millisecondsSinceEpoch,
  ));
  await repository.setGoals(const Goals(waterMl: 2000, caloriesKcal: 2000));

  final AppSettings settings = repository.settings;
  return AppState(
    repository: repository,
    directories: AppDirectories(
      Directory('${temp.path}/data'),
      Directory('${temp.path}/support'),
    ),
    foodClient: FoodApiClient(
      baseUrl: kFoodApiBaseUrl,
      userAgent: kFoodApiUserAgent,
    ),
    strings: settings.languageCode == 'en' ? Strings.en : Strings.de,
  );
}

void main() {
  late Directory temp;
  late AppState state;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('morphhealth_app_test');
    state = await buildState(temp);
  });

  tearDown(() async {
    state.dispose();
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  Widget wrap() => MorphHealthApp(state: state);

  testWidgets('the overview shows the four areas', (WidgetTester tester) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    expect(find.text('MorphHealth'), findsOneWidget);
    expect(find.text('Ernährung'), findsWidgets);
    expect(find.text('Zyklus'), findsWidgets);
    expect(find.text('Gewicht'), findsWidgets);

    await tester.scrollUntilVisible(
      find.text('Symptome'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Symptome'), findsWidgets);
  });

  testWidgets('the nutrition tab shows the day total', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ernährung').last);
    await tester.pumpAndSettle();

    expect(find.text('Ernährungstagebuch'), findsWidgets);
    // 50 g * 400 kcal / 100 g = 200 kcal
    expect(find.textContaining('200', findRichText: true), findsWidgets);
    // 500 ml of water
    expect(find.textContaining('500', findRichText: true), findsWidgets);

    await tester.drag(find.byType(ListView).first, const Offset(0, -400));
    await tester.pumpAndSettle();
    expect(find.textContaining('200 kcal'), findsWidgets);
  });

  testWidgets('the cycle tab explains the personal assessment', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Zyklus').last);
    await tester.pumpAndSettle();
    expect(find.text('Periodentracker'), findsWidgets);

    await tester.tap(find.textContaining('Einschätzung').first);
    await tester.pumpAndSettle();
    expect(find.text('Persönliche Einschätzung'), findsWidgets);
    // The assessment explains itself with the recorded history.
    expect(find.textContaining('Zyklustag'), findsWidgets);
  });

  testWidgets('the settings page switches the language', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Einstellungen').last);
    await tester.pumpAndSettle();
    expect(find.text('Sprache'), findsWidgets);

    await tester.tap(find.text('English').first);
    await tester.pumpAndSettle();

    expect(find.text('Language'), findsWidgets);
    expect(find.text('Settings'), findsWidgets);
  });

  testWidgets('the food picker opens and lists the sources', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ernährung').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Eintrag hinzufügen').last);
    await tester.pumpAndSettle();

    expect(find.text('Lebensmittel suchen'), findsWidgets);
    expect(find.text('Barcode eingeben'), findsWidgets);
    expect(find.text('Eigene Lebensmittel'), findsWidgets);
    expect(find.text('Zuletzt erfasst'), findsWidgets);
    expect(find.text('Favoriten'), findsWidgets);
  });

  testWidgets('the history page finds entries by free text', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(wrap());
    await tester.pumpAndSettle();

    await tester.tap(find.text('Verlauf').last);
    await tester.pumpAndSettle();
    expect(find.text('Historie'), findsWidgets);

    await tester.enterText(
      find.byType(TextField).first,
      'Kopfschmerzen',
    );
    await tester.pumpAndSettle();

    expect(find.text('Kopfschmerzen'), findsWidgets);
  });
}
