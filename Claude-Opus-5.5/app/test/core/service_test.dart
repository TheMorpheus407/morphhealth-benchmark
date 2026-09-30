import 'package:flutter_test/flutter_test.dart';
import 'package:morphhealth/core/l10n/format.dart';
import 'package:morphhealth/core/model/dataset.dart';
import 'package:morphhealth/core/model/entries.dart';
import 'package:morphhealth/core/model/enums.dart';
import 'package:morphhealth/core/model/food.dart';
import 'package:morphhealth/core/model/settings.dart';
import 'package:morphhealth/core/history/history.dart';
import 'package:morphhealth/core/nutrition/nutrition.dart';
import 'package:morphhealth/core/service/morphhealth_service.dart';
import 'package:morphhealth/core/util/local_date.dart';

import '../support/helpers.dart';

FoodProfile yogurt() => FoodProfile(
  source: FoodSource.custom,
  name: 'Joghurt',
  basis: Basis.g,
  servingSize: 150,
  servingLabel: '1 Becher',
  nutrients: {
    'energy_kcal': 60,
    'protein_g': 4,
    'calcium_mg': 120,
    'vitamin_b12_ug': 0.4,
  },
);

void main() {
  setUpAll(initializeFormatting);
  final day = LocalDate(2026, 9, 23);

  group('nutrition', () {
    test('computes entries in g, ml and portions with totals and coverage', () async {
      final (s, repo, _) = await openService();
      final food = await s.createCustomFood(yogurt());
      await s.addFoodEntry(date: day, time: 480, meal: Meal.breakfast, amount: 1.5, unit: AmountUnit.portion, food: food.profile, foodRef: food.id);
      await s.addFoodEntry(date: day, time: 900, meal: Meal.snack, amount: 100, unit: AmountUnit.ml, food: food.profile);
      await s.addFoodEntry(
        date: day,
        time: 1200,
        meal: Meal.dinner,
        amount: 50,
        unit: AmountUnit.g,
        food: FoodProfile(source: FoodSource.custom, name: 'Brot', nutrients: {'energy_kcal': 250, 'protein_g': 9, 'caffeine_mg': 0}),
      );
      await s.addWater(day, 250, time: 600);
      await s.addWater(day, 500, time: 700);
      await s.addCaffeine(day, 80, label: 'Kaffee');

      final n = s.nutritionDay(day);
      expect(n.entries.map((e) => e.meal), [Meal.breakfast, Meal.dinner, Meal.snack]);
      // 225 g + 100 ml (density 1) yogurt, 50 g bread
      expect(n.totals['energy_kcal'], closeTo(60 * 3.25 + 125, 1e-9));
      expect(n.totals['protein_g'], closeTo(4 * 3.25 + 4.5, 1e-9));
      expect(n.totals['calcium_mg'], closeTo(390, 1e-9));
      expect(n.totals.knownCount['calcium_mg'], 2);
      expect(n.totals.isComplete('calcium_mg'), isFalse);
      expect(n.totals['vitamin_c_mg'], isNull);
      expect(n.waterMl, 750);
      expect(n.caffeineTotalMg, 80);
      final json = n.toJson();
      expect((json['totals'] as Map)['energy_kcal'], 320.0);
      expect((json['water'] as Map)['total_ml'], 750.0);
      expect((json['meals'] as Map)['snack'], isA<Map>());
    });

    test('trend series averages only days with entries', () async {
      final (s, repo, _) = await openService();
      await s.addFoodEntry(date: day, time: 480, meal: Meal.lunch, amount: 100, unit: AmountUnit.g, food: yogurt());
      await s.addFoodEntry(date: day.addDays(-2), time: 480, meal: Meal.lunch, amount: 200, unit: AmountUnit.g, food: yogurt());
      final series = s.nutritionTrend('energy_kcal', day, 7);
      expect(series.values, [null, null, null, null, 120.0, null, 60.0]);
      expect(series.average, 90);
      expect(series.daysWithData, 2);
      final water = s.nutritionTrend(TrendMetric.water, day, 28);
      expect(water.days, hasLength(28));
      expect(water.daysWithData, 0);
    });

    test('log again copies an entry to another day', () async {
      final (s, repo, _) = await openService();
      final e = await s.addFoodEntry(date: day, time: 480, meal: Meal.lunch, amount: 100, unit: AmountUnit.g, food: yogurt());
      final copy = await s.relogEntry(e, date: day.addDays(1), time: 600);
      expect(copy.id, isNot(e.id));
      expect(copy.amount, 100);
      expect(s.data.foodEntries, hasLength(2));
    });

    test('editing a custom food can update the entries that use it', () async {
      final (s, repo, _) = await openService();
      final food = await s.createCustomFood(yogurt());
      await s.addFoodEntry(date: day, time: 480, meal: Meal.lunch, amount: 1, unit: AmountUnit.portion, food: food.profile, foodRef: food.id);
      await s.addFoodEntry(date: day, time: 480, meal: Meal.lunch, amount: 100, unit: AmountUnit.g, food: food.profile, foodRef: food.id);
      expect(s.entriesUsingFood(food.id), 2);

      final changed = food.copyWith(
        profile: food.profile.copyWith(nutrients: {'energy_kcal': 80}),
        updatedAt: DateTime.utc(2026, 9, 24),
      );
      await s.saveFood(changed, updateEntries: false);
      expect(s.nutritionDay(day).totals['energy_kcal'], closeTo(150, 1e-9));
      await s.saveFood(
        changed.copyWith(profile: changed.profile.copyWith(servingSize: () => null)),
        updateEntries: true,
      );
      final totals = s.nutritionDay(day).totals;
      expect(totals['energy_kcal'], closeTo(80 * 2.5, 1e-9),
          reason: 'portion entry keeps its 150 g when the portion is removed');
      expect(s.data.foodEntries.values.every((e) => e.unit == AmountUnit.g), isTrue);
    });

    test('favorites save online products and remove them again', () async {
      final (s, repo, _) = await openService();
      final product = FoodProfile(source: FoodSource.openFoodFacts, name: 'Nutella', barcode: '3017620425035', nutrients: {'energy_kcal': 539});
      final saved = await s.setFavorite(product, true);
      expect(saved!.favorite, isTrue);
      expect(s.favoriteFoods().single.profile.name, 'Nutella');
      expect(s.searchLocalFoods('nute').single.isFavorite, isTrue);
      await s.setFavorite(product, false);
      expect(s.data.foods, isEmpty);
      final custom = await s.createCustomFood(yogurt(), favorite: true);
      await s.setFavorite(custom.profile, false, foodRef: custom.id);
      expect(s.data.foods[custom.id]!.favorite, isFalse, reason: 'custom foods stay');
    });

    test('recent foods are distinct and newest first', () async {
      final (s, repo, _) = await openService();
      await s.addFoodEntry(date: day.addDays(-3), time: 480, meal: Meal.lunch, amount: 100, unit: AmountUnit.g, food: yogurt());
      await s.addFoodEntry(date: day.addDays(-1), time: 480, meal: Meal.lunch, amount: 100, unit: AmountUnit.g, food: FoodProfile(source: FoodSource.custom, name: 'Apfel'));
      await s.addFoodEntry(date: day, time: 480, meal: Meal.lunch, amount: 150, unit: AmountUnit.g, food: yogurt());
      final recent = s.recentFoods();
      expect(recent.map((r) => r.profile.name), ['Joghurt', 'Apfel']);
      expect(recent.first.lastEntry!.amount, 150);
    });
  });

  group('cycle', () {
    test('start and end periods, with validation', () async {
      final (s, repo, _) = await openService();
      final first = await s.startPeriod(LocalDate(2026, 8, 26));
      await s.endPeriod(first, LocalDate(2026, 8, 30));
      expect(() => s.startPeriod(LocalDate(2026, 8, 28)), throwsA(isA<DomainException>()));
      expect(() => s.startPeriod(LocalDate(2026, 9, 30)), throwsA(isA<DomainException>()),
          reason: 'future start');
      final second = await s.startPeriod(LocalDate(2026, 9, 22));
      expect(second.isOngoing, isTrue);
      expect(
        () => s.savePeriod(first.copyWith(end: () => LocalDate(2026, 9, 25), updatedAt: DateTime.utc(2026))),
        throwsA(isA<DomainException>()),
      );
      final forecast = s.cycleForecast(day);
      expect(forecast.currentPeriodDay, 2);
      expect(forecast.cycles.single.length, 27);
    });

    test('starting a new period closes a forgotten ongoing one', () async {
      final (s, repo, _) = await openService();
      await s.startPeriod(LocalDate(2026, 8, 20));
      await s.startPeriod(LocalDate(2026, 9, 18));
      final periods = s.data.periodsSorted;
      expect(periods.first.end, LocalDate(2026, 9, 17));
      expect(periods.last.isOngoing, isTrue);
    });

    test('deleting a period removes its bleeding intensities but keeps notes', () async {
      final (s, repo, _) = await openService();
      final p = await s.startPeriod(LocalDate(2026, 9, 1), end: LocalDate(2026, 9, 4));
      await s.setCycleDay(LocalDate(2026, 9, 1), flow: Flow.heavy);
      await s.setCycleDay(LocalDate(2026, 9, 2), flow: Flow.medium, note: 'Wärmflasche');
      await s.setCycleDay(LocalDate(2026, 9, 12), flow: Flow.spotting);
      await s.deletePeriod(p);
      expect(s.data.periods, isEmpty);
      expect(s.data.cycleDayOn(LocalDate(2026, 9, 1)), isNull);
      expect(s.data.cycleDayOn(LocalDate(2026, 9, 2))!.flow, isNull);
      expect(s.data.cycleDayOn(LocalDate(2026, 9, 2))!.note, 'Wärmflasche');
      expect(s.data.cycleDayOn(LocalDate(2026, 9, 12))!.flow, Flow.spotting);
      await s.setCycleDay(LocalDate(2026, 9, 12));
      expect(s.data.cycleDayOn(LocalDate(2026, 9, 12)), isNull);
    });
  });

  group('symptoms, weight and history', () {
    test('symptom names group case-insensitively; series per symptom', () async {
      final (s, repo, _) = await openService();
      await s.saveSymptom(SymptomEntry.create(date: day, time: 600, name: 'Kopfschmerzen', intensity: 4, now: DateTime.utc(2026)));
      await s.saveSymptom(SymptomEntry.create(date: day, time: 900, name: 'kopfschmerzen ', intensity: 7, now: DateTime.utc(2026)));
      await s.saveSymptom(SymptomEntry.create(date: day.addDays(-1), time: 900, name: 'Übelkeit', intensity: 2, now: DateTime.utc(2026)));
      expect(s.knownSymptomNames().first.toLowerCase().trim(), 'kopfschmerzen');
      final series = s.symptomSeries('Kopfschmerzen', day, 7);
      expect(series.values.last, 7);
      expect(series.entries, hasLength(2));
      expect(series.averageIntensity, 5.5);
      expect(() => s.saveSymptom(SymptomEntry.create(date: day, time: 1, name: 'x', intensity: 11, now: DateTime.utc(2026))),
          throwsA(isA<DomainException>()));
    });

    test('weight in kg and lb', () async {
      final (s, repo, _) = await openService();
      await s.saveWeight(WeightEntry.create(date: day, time: 420, value: 150, unit: WeightUnit.lb, now: DateTime.utc(2026)));
      final w = s.data.weightEntries.values.single;
      expect(w.kg, closeTo(68.0389, 1e-4));
      expect(w.valueIn(WeightUnit.lb), 150);
      expect(() => s.saveWeight(WeightEntry.create(date: day, time: 1, value: 0.5, unit: WeightUnit.kg, now: DateTime.utc(2026))),
          throwsA(isA<DomainException>()));
    });

    test('history filters by area, date range and text', () async {
      final (s, repo, _) = await openService();
      await s.addFoodEntry(date: day, time: 480, meal: Meal.breakfast, amount: 100, unit: AmountUnit.g, food: yogurt());
      await s.addWater(day.addDays(-10), 300);
      await s.saveSymptom(SymptomEntry.create(date: day.addDays(-3), time: 600, name: 'Rückenschmerzen', intensity: 5, note: 'nach dem Joggen', now: DateTime.utc(2026)));
      await s.startPeriod(LocalDate(2026, 9, 1), end: LocalDate(2026, 9, 5));
      final index = s.historyIndex();
      expect(index.items, hasLength(4));
      expect(index.filter(const HistoryQuery(text: 'jogh')).single.kind, HistoryKind.food);
      expect(index.filter(const HistoryQuery(text: 'joggen')).single.kind, HistoryKind.symptom);
      expect(index.filter(const HistoryQuery(areas: {Area.cycle})).single.kind, HistoryKind.period);
      expect(index.filter(HistoryQuery(from: day.addDays(-5), to: day)), hasLength(2));
      expect(index.filter(const HistoryQuery(text: 'frühstück joghurt')), hasLength(1));
      expect(identical(s.historyIndex(), index), isTrue, reason: 'cached until data changes');
      await s.updateSettings(s.settings.copyWith(language: AppLanguage.en));
      expect(s.historyIndex().filter(const HistoryQuery(text: 'breakfast')), hasLength(1));
    });

    test('settings persist', () async {
      final (s, repo, dir) = await openService();
      await s.updateSettings(s.settings.copyWith(
        weightUnit: WeightUnit.lb,
        overviewAreas: {Area.cycle},
        goals: const Goals(energyKcal: 1800, waterMl: 2000),
      ));
      await repo.close();
      final (s2, repo2, _) = await openService(dir: dir);
      expect(s2.settings.weightUnit, WeightUnit.lb);
      expect(s2.settings.overviewAreas, {Area.cycle});
      expect(s2.settings.goals.energyKcal, 1800);
      await repo2.close();
    });
  });

  test('undo restores a deleted record', () async {
    final (s, repo, _) = await openService();
    final e = await s.addFoodEntry(date: day, time: 480, meal: Meal.lunch, amount: 100, unit: AmountUnit.g, food: yogurt());
    await s.deleteRecord(Collection.foodEntries, e.id);
    expect(s.data.foodEntries, isEmpty);
    await s.restoreRecord(Collection.foodEntries, e);
    expect(s.data.foodEntries[e.id]!.amount, 100);
  });
}
