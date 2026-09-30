import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:morphhealth/core/civil.dart';
import 'package:morphhealth/core/clock.dart';
import 'package:morphhealth/core/db.dart';
import 'package:morphhealth/core/models.dart';
import 'package:morphhealth/core/store.dart';

import 'helpers.dart';

void main() {
  test('Verzehreinträge: anlegen, ändern, löschen, nach Tag indiziert', () async {
    final db = await memoryDb();
    final e1 = await db.saveEntry(entryOf(oats(), '2026-09-28T08:00', amount: 60));
    final e2 = await db.saveEntry(entryOf(oats(), '2026-09-28T07:00', amount: 30, id: 'x'));
    expect(db.entries.on(day('2026-09-28')).map((e) => e.id), ['x', e1.id]); // nach Uhrzeit sortiert
    await db.saveEntry(e2.copyWith(at: LocalDateTime.parse('2026-09-29T07:00')));
    expect(db.entries.on(day('2026-09-28')).length, 1);
    expect(db.entries.on(day('2026-09-29')).single.id, 'x');
    await db.deleteEntry('x');
    expect(db.entries.on(day('2026-09-29')), isEmpty);
    expect(db.entries.length, 1);
  });

  test('Ungültige Eingaben werden mit Code abgewiesen', () async {
    final db = await memoryDb();
    await expectLater(
      db.saveEntry(entryOf(oats(), '2026-09-28T08:00', amount: 0)),
      throwsA(isA<DomainException>().having((e) => e.code, 'code', 'invalid_amount')),
    );
    final noServing = oats().copyWith(serving: () => null);
    await expectLater(
      db.saveEntry(entryOf(noServing, '2026-09-28T08:00', amount: 1, unit: AmountUnit.portion)),
      throwsA(isA<DomainException>()),
    );
    await expectLater(
      db.saveSymptom(SymptomEntry(id: 's', name: ' ', intensity: 3, at: LocalDateTime.parse('2026-09-28T08:00'))),
      throwsA(isA<DomainException>()),
    );
    await expectLater(
      db.saveSymptom(SymptomEntry(id: 's', name: 'Kopf', intensity: 11, at: LocalDateTime.parse('2026-09-28T08:00'))),
      throwsA(isA<DomainException>()),
    );
    await expectLater(
      db.saveWater(WaterEntry(id: 'w', at: LocalDateTime.parse('2026-09-28T08:00'), ml: -5)),
      throwsA(isA<DomainException>()),
    );
  });

  test('Eigenes Lebensmittel bearbeiten: Änderung gilt für bestehende Einträge', () async {
    final db = await memoryDb();
    final food = await db.saveFood(Food(id: 'f1', info: oats()));
    await db.saveEntry(entryOf(food.info, '2026-09-28T08:00', amount: 100, foodId: 'f1', id: 'a'));
    await db.saveEntry(
      entryOf(food.info, '2026-09-28T09:00', amount: 2, unit: AmountUnit.portion, foodId: 'f1', id: 'b'),
    );
    final fixed = food.info.copyWith(
      name: 'Haferflocken zart',
      nutrients: food.info.nutrients.with_('energy_kcal', 400),
    );
    await db.saveFood(food.copyWith(info: fixed));
    expect(db.entries.byId['a']!.food.name, 'Haferflocken zart');
    expect(db.entries.byId['a']!.nutrients['energy_kcal'], 400);
    expect(db.entries.byId['b']!.baseAmount, 80);
    // Portionsgröße entfernen: Portionseinträge rechnen in Gramm um.
    await db.saveFood(food.copyWith(info: fixed.copyWith(serving: () => null)));
    final b = db.entries.byId['b']!;
    expect(b.unit, AmountUnit.g);
    expect(b.amount, 80);
  });

  test('Produkt aus Open Food Facts: gleicher Barcode aktualisiert die Bibliothek, Einträge bleiben', () async {
    final db = await memoryDb();
    final info = oats(source: FoodSource.off).copyWith(barcode: () => '4000540000108');
    final f1 = await db.upsertOffFood(info);
    await db.saveEntry(entryOf(info, '2026-09-28T08:00', foodId: f1.id, id: 'a'));
    final f2 = await db.upsertOffFood(info.copyWith(nutrients: info.nutrients.with_('energy_kcal', 500)));
    expect(f2.id, f1.id);
    expect(db.foods.length, 1);
    expect(db.entries.byId['a']!.nutrients['energy_kcal'], 372); // Verlauf bleibt unverändert
  });

  test('Lebensmittel löschen lässt Einträge bestehen; Favoriten und Suche', () async {
    final db = await memoryDb();
    final a = await db.saveFood(Food(id: 'a', info: oats()));
    await db.saveFood(
      Food(
        id: 'b',
        info: oats().copyWith(name: 'Quark'),
        favorite: true,
      ),
    );
    await db.saveEntry(entryOf(a.info, '2026-09-28T08:00', foodId: 'a', id: 'e'));
    expect(db.searchFoods('').first.info.name, 'Quark'); // Favorit zuerst
    expect(db.searchFoods('hafer').single.id, 'a');
    await db.setFavorite('a', true);
    expect(db.food('a')!.favorite, isTrue);
    await db.deleteFood('a');
    expect(db.food('a'), isNull);
    expect(db.entries.byId['e']!.food.name, 'Haferflocken');
    expect(db.recentEntries().single.id, 'e');
  });

  test('Perioden: Überschneidung wird abgewiesen, Tagesmarkierung verlängert oder legt an', () async {
    final db = await memoryDb();
    await db.savePeriod(
      PeriodRecord(id: 'p1', start: day('2026-09-01'), end: day('2026-09-05'), flow: FlowLevel.medium),
    );
    await expectLater(
      db.savePeriod(PeriodRecord(id: 'p2', start: day('2026-09-04'), end: day('2026-09-08'))),
      throwsA(isA<DomainException>().having((e) => e.code, 'code', 'period_overlap')),
    );
    // Tag direkt nach dem Ende: verlängert.
    final ext = await db.markFlowOn(day('2026-09-06'), FlowLevel.light);
    expect(ext.id, 'p1');
    expect(ext.end, day('2026-09-06'));
    expect(ext.flowOn(day('2026-09-06')), FlowLevel.light);
    expect(ext.flowOn(day('2026-09-02')), FlowLevel.medium);
    // Tag mitten in der Periode: nur Tagesstärke.
    final mid = await db.markFlowOn(day('2026-09-03'), FlowLevel.heavy);
    expect(mid.dayFlows[day('2026-09-03')], FlowLevel.heavy);
    // Entfernen der Tagesangabe.
    final removed = await db.markFlowOn(day('2026-09-03'), null);
    expect(removed.dayFlows.containsKey(day('2026-09-03')), isFalse);
    // Ferner Tag: neue Periode.
    final fresh = await db.markFlowOn(day('2026-09-20'), FlowLevel.spotting);
    expect(fresh.id, isNot('p1'));
    expect(db.periods.length, 2);
    expect(db.periodsOn(day('2026-09-20')).single.id, fresh.id);
    // Kein Eintrag zum Entfernen.
    await expectLater(db.markFlowOn(day('2026-09-25'), null), throwsA(isA<DomainException>()));
  });

  test('Offene Periode gilt höchstens 10 Tage als laufend', () async {
    final db = await memoryDb(now: DateTime(2026, 9, 29, 12));
    await db.savePeriod(PeriodRecord(id: 'p', start: day('2026-09-01')));
    expect(db.periodsOn(day('2026-09-05')).length, 1);
    expect(db.periodsOn(day('2026-09-10')).length, 1);
    expect(db.periodsOn(day('2026-09-11')), isEmpty);
  });

  test('Symptomnamen: Gruppierung ohne Groß-/Kleinschreibung, neueste zuerst', () async {
    final db = await memoryDb();
    Future<void> add(String n, String at, int i) =>
        db.saveSymptom(SymptomEntry(id: '$n$at', name: n, intensity: i, at: LocalDateTime.parse(at))).then((_) {});
    await add('Kopfschmerz', '2026-09-01T10:00', 3);
    await add('  kopfschmerz ', '2026-09-03T10:00', 5);
    await add('Müdigkeit', '2026-09-02T10:00', 2);
    final names = db.symptomNames();
    expect(names.map((n) => n.name), ['kopfschmerz', 'Müdigkeit']);
    expect(names.first.count, 2);
  });

  test('Gewicht: Tageswert ist der letzte Eintrag, jüngstes Gewicht bis zu einem Tag', () async {
    final db = await memoryDb();
    Future<void> w(String id, String at, double kg) =>
        db.saveWeight(WeightEntry(id: id, at: LocalDateTime.parse(at), kg: kg)).then((_) {});
    await w('a', '2026-09-27T07:00', 71.0);
    await w('b', '2026-09-28T07:00', 72.0);
    await w('c', '2026-09-28T21:00', 72.6);
    expect(db.weightOn(day('2026-09-28'))!.kg, 72.6);
    expect(db.latestWeightUpTo(day('2026-09-28'))!.id, 'c');
    expect(db.latestWeightUpTo(day('2026-09-27'))!.id, 'a');
    expect(db.latestWeightUpTo(day('2026-09-26')), isNull);
  });

  test('Einstellungen und Ziele werden gespeichert und gemeldet', () async {
    final db = await memoryDb();
    var notified = 0;
    db.changes.addListener(() => notified++);
    await db.saveSettings(db.settings.copyWith(language: 'en', weightUnit: WeightUnit.lb, areas: {Area.nutrition}));
    await db.saveGoals(const Goals(waterMl: 2500, energyKcal: 2000));
    expect(db.settings.language, 'en');
    expect(db.settings.shows(Area.cycle), isFalse);
    expect(db.goals.waterMl, 2500);
    expect(notified, 2);
  });

  test('Dauerhaft: Daten überleben Schließen und Öffnen (verschlüsselter Speicher)', () async {
    final dir = await Directory.systemTemp.createTemp('mh_db_test_');
    addTearDown(() => dir.delete(recursive: true));
    final key = Uint8List.fromList(List.filled(32, 5));
    var store = await EncryptedStore.open(dir, key);
    var db = await Db.open(store, FixedClock(DateTime(2026, 9, 29)));
    await db.saveFood(Food(id: 'f', info: oats(), favorite: true));
    await db.saveEntry(entryOf(oats(), '2026-09-28T08:00', foodId: 'f', id: 'e'));
    await db.saveWater(WaterEntry(id: 'w', at: LocalDateTime.parse('2026-09-28T09:00'), ml: 250));
    await db.savePeriod(
      PeriodRecord(
        id: 'p',
        start: day('2026-09-01'),
        end: day('2026-09-05'),
        flow: FlowLevel.heavy,
        dayFlows: {day('2026-09-02'): FlowLevel.light},
      ),
    );
    await db.saveSettings(const AppSettings(language: 'en'));
    await db.close();

    store = await EncryptedStore.open(dir, key);
    db = await Db.open(store, FixedClock(DateTime(2026, 9, 29)));
    expect(db.food('f')!.favorite, isTrue);
    expect(db.entries.byId['e']!.food.name, 'Haferflocken');
    expect(db.water.on(day('2026-09-28')).single.ml, 250);
    expect(db.periods.single.dayFlows[day('2026-09-02')], FlowLevel.light);
    expect(db.settings.language, 'en');
    await db.close();
  });

  test('Alles löschen setzt Bestand und Einstellungen zurück', () async {
    final db = await memoryDb();
    await db.saveWater(WaterEntry(id: 'w', at: LocalDateTime.parse('2026-09-28T09:00'), ml: 250));
    await db.saveSettings(const AppSettings(language: 'en'));
    await db.wipe();
    expect(db.totalRecords, 0);
    expect(db.settings.language, 'de');
  });
}
