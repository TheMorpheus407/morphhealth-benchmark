import 'package:flutter_test/flutter_test.dart';
import 'package:morphhealth/core/civil.dart';
import 'package:morphhealth/core/models.dart';
import 'package:morphhealth/core/nutrients.dart';
import 'package:morphhealth/core/nutrition.dart';

import 'helpers.dart';

void main() {
  test('Eintrag: Nährwerte aus Gramm, Millilitern und Portionen', () {
    final food = oats();
    expect(entryOf(food, '2026-09-28T08:00', amount: 50).nutrients['energy_kcal'], closeTo(186, 1e-9));
    expect(entryOf(food, '2026-09-28T08:00', amount: 2, unit: AmountUnit.portion).baseAmount, 80);
    expect(
      entryOf(food, '2026-09-28T08:00', amount: 2, unit: AmountUnit.portion).nutrients['protein_g'],
      closeTo(10.8, 1e-9),
    );
    // Getränk je 100 ml, Menge in ml.
    final juice = FoodInfo(
      name: 'Saft',
      basis: Basis.ml,
      nutrients: Nutrients.of({'energy_kcal': 45, 'vitamin_c_mg': 20}),
    );
    final e = entryOf(juice, '2026-09-28T08:00', amount: 250, unit: AmountUnit.ml);
    expect(e.nutrients['energy_kcal'], closeTo(112.5, 1e-9));
    expect(e.nutrients['vitamin_c_mg'], closeTo(50, 1e-9));
    // Einheit weicht von der Bezugsgröße ab: 1 ml = 1 g.
    expect(entryOf(oats(), '2026-09-28T08:00', amount: 100, unit: AmountUnit.ml).nutrients['energy_kcal'], 372);
    // Keine Angabe bleibt keine Angabe.
    expect(e.nutrients.has('iron_mg'), isFalse);
  });

  test('Tag: Summen, Mahlzeiten, Datenabdeckung, Wasser, Koffein, Ziele', () async {
    final db = await memoryDb();
    await db.saveGoals(const Goals(waterMl: 2000, energyKcal: 2000, proteinG: 100));
    final coffee = FoodInfo(
      name: 'Cola',
      basis: Basis.ml,
      nutrients: Nutrients.of({'energy_kcal': 40, 'caffeine_mg': 10}),
    );
    await db.saveEntry(entryOf(oats(), '2026-09-28T08:00', amount: 100, id: 'a'));
    await db.saveEntry(entryOf(oats(), '2026-09-28T12:00', amount: 50, meal: Meal.lunch, id: 'b'));
    await db.saveEntry(
      entryOf(coffee, '2026-09-28T15:00', amount: 330, unit: AmountUnit.ml, meal: Meal.snack, id: 'c'),
    );
    await db.saveEntry(entryOf(oats(), '2026-09-27T12:00', id: 'other-day'));
    await db.saveWater(WaterEntry(id: 'w1', at: LocalDateTime.parse('2026-09-28T09:00'), ml: 250));
    await db.saveWater(WaterEntry(id: 'w2', at: LocalDateTime.parse('2026-09-28T10:00'), ml: 500));
    await db.saveCaffeine(CaffeineEntry(id: 'k', at: LocalDateTime.parse('2026-09-28T09:30'), mg: 80, label: 'Kaffee'));

    final d = dayNutrition(db, day('2026-09-28'));
    expect(d.entries.map((e) => e.id), ['a', 'b', 'c']);
    expect(d.totals['energy_kcal'], closeTo(372 + 186 + 132, 1e-9));
    expect(d.totals['protein_g'], closeTo(13.5 * 1.5, 1e-9));
    expect(d.foodTotals['caffeine_mg'], closeTo(33, 1e-9));
    expect(d.totals['caffeine_mg'], closeTo(113, 1e-9));
    expect(d.caffeineAdditionalMg, 80);
    expect(d.waterMl, 750);
    expect(d.entriesWithData['energy_kcal'], 3);
    expect(d.entriesWithData['iron_mg'], 2);
    expect(d.entriesWithData['caffeine_mg'], 1);
    final lunch = d.meals.firstWhere((m) => m.meal == Meal.lunch);
    expect(lunch.totals['energy_kcal'], closeTo(186, 1e-9));
    expect(d.meals.firstWhere((m) => m.meal == Meal.dinner).entries, isEmpty);
    final p = d.progress;
    expect(p['water_ml']!.percent, closeTo(37.5, 1e-9));
    expect(p['energy_kcal']!.remaining, closeTo(2000 - 690, 1e-9));
    expect(p.containsKey('fat_g'), isFalse); // kein Ziel gesetzt
    final json = d.toJson();
    expect((json['totals'] as Map)['energy_kcal'], 690.0);
    expect((json['entries'] as List).length, 3);
    expect(dayNutrition(db, day('2026-09-29')).hasAnyData, isFalse);
  });

  test('Nur zusätzliches Koffein ohne Mahlzeit', () async {
    final db = await memoryDb();
    await db.saveCaffeine(CaffeineEntry(id: 'k', at: LocalDateTime.parse('2026-09-28T09:30'), mg: 95));
    final d = dayNutrition(db, day('2026-09-28'));
    expect(d.totals['caffeine_mg'], 95);
    expect(d.entries, isEmpty);
    expect(d.hasAnyData, isTrue);
  });

  test('Verläufe über 7 und 28 Tage', () async {
    final db = await memoryDb();
    for (var i = 0; i < 28; i += 3) {
      final dd = day('2026-09-29').addDays(-i);
      await db.saveEntry(entryOf(oats(), '${dd}T08:00', amount: 100, id: 'e$i'));
      await db.saveWater(WaterEntry(id: 'w$i', at: LocalDateTime.parse('${dd}T09:00'), ml: 300));
    }
    final s7 = nutritionSeries(db, 'energy_kcal', day('2026-09-29'), 7);
    expect(s7.points.length, 7);
    expect(s7.points.last.day, day('2026-09-29'));
    expect(s7.daysWithData, 3); // Tage 0, 3, 6
    expect(s7.average, closeTo(372, 1e-9));
    final s28 = nutritionSeries(db, 'energy_kcal', day('2026-09-29'), 28);
    expect(s28.daysWithData, 10);
    expect(s28.minimum, closeTo(372, 1e-9));
    final water = nutritionSeries(db, kMetricWater, day('2026-09-29'), 7);
    expect(water.unit, 'ml');
    expect(water.maximum, 300);
    // Tage ohne Eintrag sind null, nicht 0.
    expect(s7.points.where((p) => p.value == null).length, 4);
  });

  test('Gewichtsverlauf', () async {
    final db = await memoryDb();
    await db.saveWeight(WeightEntry(id: 'a', at: LocalDateTime.parse('2026-09-27T07:00'), kg: 72));
    await db.saveWeight(WeightEntry(id: 'b', at: LocalDateTime.parse('2026-09-29T07:00'), kg: 71.5));
    final s = weightSeries(db, day('2026-09-29'), 7);
    expect(s.daysWithData, 2);
    expect(s.points.last.value, 71.5);
  });

  test('Einheitenumrechnung kg und lb ist umkehrbar', () {
    expect(kgToLb(70), closeTo(154.323584, 1e-5));
    expect(lbToKg(kgToLb(72.4)), closeTo(72.4, 1e-12));
  });
}
