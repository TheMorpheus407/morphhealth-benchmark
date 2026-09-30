import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphhealth/core/food/off_client.dart';
import 'package:morphhealth/core/model/enums.dart';
import 'package:morphhealth/core/service/morphhealth_service.dart';
import 'package:morphhealth/core/util/clock.dart';

import '../support/ui_harness.dart';
import '../support/ui_seed.dart';

void main() {
  setUpAll(loadRealFonts);

  testWidgets('first start shows onboarding and leads to the overview', (
    tester,
  ) async {
    final repo = await pumpMorphHealth(tester, onboardingDone: false);
    expect(find.text('Willkommen bei MorphHealth'), findsOneWidget);
    await tapWithIo(tester, find.text('Los geht’s'));
    expect(find.text('Tagesdetail'), findsOneWidget);
    expect(repo.device.onboardingCompleted, isTrue);
  });

  testWidgets('water quick entry updates the day total and can be undone', (
    tester,
  ) async {
    final repo = await pumpMorphHealth(tester, seed: seedData);
    expect(find.textContaining('500 ml von 2.000 ml'), findsOneWidget);
    await tapWithIo(tester, find.widgetWithText(ActionChip, '250 ml').first);
    expect(find.textContaining('750 ml von 2.000 ml'), findsOneWidget);
    expect(repo.data.waterOn(const SystemClock().today()), hasLength(2));
    await tapWithIo(tester, find.text('Rückgängig'));
    expect(find.textContaining('500 ml von 2.000 ml'), findsOneWidget);
    expect(repo.data.waterOn(const SystemClock().today()), hasLength(1));
    // Let the snack bar finish before the tree is torn down.
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });

  testWidgets('switching the language updates the whole interface', (
    tester,
  ) async {
    final repo = await pumpMorphHealth(tester, seed: seedData);
    expect(find.text('Ernährung'), findsWidgets);
    await withIo(
      tester,
      () => repo.updateSettings(
        repo.data.settings.copyWith(language: AppLanguage.en),
      ),
    );
    expect(find.text('Nutrition'), findsWidgets);
    expect(find.text('Ernährung'), findsNothing);
  });

  testWidgets('hidden overview areas disappear but keep their data', (
    tester,
  ) async {
    final repo = await pumpMorphHealth(tester, seed: seedData);
    expect(find.text('Wasser'), findsWidgets);
    await withIo(
      tester,
      () => repo.updateSettings(
        repo.data.settings.copyWith(overviewAreas: {Area.cycle}),
      ),
    );
    expect(find.text('Wasser'), findsNothing);
    expect(find.textContaining('Periode'), findsWidgets);
    expect(repo.data.weightEntries, isNotEmpty);
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets(
      'a forgotten period end is pointed out and can be entered (text ×$scale)',
      (tester) async {
        final today = const SystemClock().today();
        final repo = await pumpMorphHealth(
          tester,
          textScale: scale,
          seed: (repo) async {
            final s = MorphHealthService(
              repo: repo,
              clock: const SystemClock(),
              defaultFoodApi: FoodApiConfig('https://food.example.test', 'UA'),
            );
            await s.startPeriod(today.addDays(-19));
          },
        );
        await openTab(tester, Icons.water_drop_outlined);
        expect(find.textContaining('seit 20 Tagen offen'), findsOneWidget);
        await tapVisible(tester, find.text('Letzten Tag eintragen'));
        // Without finished periods the editor suggests five days.
        expect(
          tester.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
          isFalse,
        );
        expect(find.text('5 Tage'), findsOneWidget);
        await tapWithIo(tester, find.text('Speichern'));
        expect(repo.data.periods.values.single.end, today.addDays(-15));
        expect(find.textContaining('seit 20 Tagen offen'), findsNothing);
        await tester.pump(const Duration(seconds: 5));
        await tester.pumpAndSettle();
      },
    );
  }

  testWidgets('a food entry can be corrected', (tester) async {
    final repo = await pumpMorphHealth(tester, seed: seedData);
    await openTab(tester, Icons.restaurant_outlined);
    await tapVisible(tester, find.textContaining('250 g').first);
    await tester.enterText(find.byType(TextFormField).first, '100');
    await tester.pumpAndSettle();
    await tapWithIo(tester, find.text('Speichern'));
    final amounts = repo.data.foodEntries.values.map((e) => e.amount).toSet();
    expect(amounts, containsAll([1.5, 100.0]));
    await tester.pump(const Duration(seconds: 5));
    await tester.pumpAndSettle();
  });
}
