// Tests für data/repository.dart (CRUD, Suche, Listener, Import/Export).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:morphhealth/src/data/repository.dart';
import 'package:morphhealth/src/model/cycle.dart';
import 'package:morphhealth/src/model/document.dart';
import 'package:morphhealth/src/model/entries.dart';
import 'package:morphhealth/src/model/food.dart';
import 'package:morphhealth/src/model/settings.dart';

import 'helpers.dart';

void main() {
  group('Lebenszyklus und Persistenz', () {
    test('load() liefert ein leeres Dokument', () async {
      final MorphRepository repo = await makeRepo();
      expect(repo.isLoaded, isTrue);
      expect(repo.document.foods, isEmpty);
      await repo.dispose();
    });

    test('persistNow speichert über das Backend', () async {
      final MemoryStoreBackend backend = MemoryStoreBackend();
      final MorphRepository repo = await makeRepo(backend: backend);
      expect(backend.saveCount, 0);
      await repo.addFood(makeFood());
      await repo.persistNow();
      expect(backend.saveCount, 1);
      await repo.dispose();
    });

    test('Listener werden bei Änderungen benachrichtigt', () async {
      final MorphRepository repo = await makeRepo();
      int calls = 0;
      void listener() => calls++;
      repo.addListener(listener);
      await repo.addFood(makeFood());
      expect(calls, 1);
      repo.removeListener(listener);
      await repo.addFood(makeFood(id: 'f2'));
      expect(calls, 1);
      await repo.dispose();
    });

    test('dispose persistiert offene Änderungen', () async {
      final MemoryStoreBackend backend = MemoryStoreBackend();
      final MorphRepository repo = await makeRepo(backend: backend);
      await repo.addWaterEntry(makeWaterEntry());
      await repo.dispose();
      expect(backend.saveCount, greaterThan(0));
      final MorphRepository neu = await makeRepo(backend: backend);
      expect(neu.waterEntries.length, 1);
      await neu.dispose();
    });
  });

  group('Lebensmittel', () {
    test('add/update/delete/toggleFavorite', () async {
      final MorphRepository repo = await makeRepo();
      final FoodItem f = await repo.addFood(makeFood(name: 'Apfel'));
      expect(repo.foods.length, 1);
      expect(repo.foodById(f.id), isNotNull);
      f.name = 'Apfel (neu)';
      await repo.updateFood(f);
      expect(repo.foodById(f.id)!.name, 'Apfel (neu)');
      // updatedAt wurde vom festen Datum gesetzt.
      expect(repo.foodById(f.id)!.updatedAt, DateTime.utc(2026, 9, 23, 12));
      await repo.toggleFoodFavorite(f.id, true);
      expect(repo.favoriteFoods.length, 1);
      expect(repo.customFoods.length, 1);
      await repo.deleteFood(f.id);
      expect(repo.foods, isEmpty);
      expect(repo.foodById(f.id), isNull);
      await repo.dispose();
    });

    test('upsertOffSnapshot legt an und aktualisiert bei gleicher Barcode', () async {
      final MorphRepository repo = await makeRepo();
      final FoodItem snap = makeFood(
        id: '',
        name: 'OFF-Produkt',
        source: FoodSource.off,
        barcode: '3017620422003',
      );
      final FoodItem a = await repo.upsertOffSnapshot(snap);
      expect(a.id, isNotEmpty);
      await repo.toggleFoodFavorite(a.id, true);
      // Erneuter Snapshot: gleiche ID, Favorit bleibt, Name aktualisiert.
      final FoodItem b = await repo.upsertOffSnapshot(makeFood(
        id: '',
        name: 'OFF-Produkt v2',
        source: FoodSource.off,
        barcode: '3017620422003',
      ));
      expect(b.id, a.id);
      expect(b.name, 'OFF-Produkt v2');
      expect(b.isFavorite, isTrue);
      expect(repo.foods.length, 1);
      // Anderer Barcode → neues Lebensmittel.
      await repo.upsertOffSnapshot(makeFood(
          id: '', source: FoodSource.off, barcode: '4006381333931'));
      expect(repo.foods.length, 2);
      await repo.dispose();
    });
  });

  group('Ernährungseinträge', () {
    test('CRUD + zeitliche Sortierung pro Tag', () async {
      final MorphRepository repo = await makeRepo();
      final NutritionEntry e = await repo.addNutritionEntry(makeNutritionEntry(
          id: 'x', time: '18:00', meal: Meal.dinner));
      expect(e.id, isNot('x')); // ID wird vergeben
      expect(e.createdAt, DateTime.utc(2026, 9, 23, 12));
      await repo.addNutritionEntry(makeNutritionEntry(
          id: 'y', time: '07:30', meal: Meal.breakfast));
      await repo.addNutritionEntry(makeNutritionEntry(
          id: 'z', date: '2026-09-22', time: '07:30'));
      final List<NutritionEntry> tag =
          repo.nutritionEntriesForDate('2026-09-23');
      expect(tag.length, 2);
      expect(tag[0].meal, Meal.breakfast); // 07:30 vor 18:00
      expect(tag[1].meal, Meal.dinner);
      // Update + Delete
      e.meal = Meal.snack;
      await repo.updateNutritionEntry(e);
      expect(repo.nutritionEntryById(e.id)!.meal, Meal.snack);
      await repo.deleteNutritionEntry(e.id);
      expect(repo.nutritionEntriesForDate('2026-09-23').length, 1);
      await repo.dispose();
    });

    test('Wasser- und Koffein-CRUD', () async {
      final MorphRepository repo = await makeRepo();
      final WaterEntry w = await repo.addWaterEntry(makeWaterEntry());
      final CaffeineEntry c = await repo.addCaffeineEntry(makeCaffeineEntry());
      expect(repo.waterEntriesForDate('2026-09-23').length, 1);
      expect(repo.caffeineEntriesForDate('2026-09-23').length, 1);
      w.amountMl = 750;
      await repo.updateWaterEntry(w);
      expect(repo.waterEntries.single.amountMl, 750);
      await repo.deleteWaterEntry(w.id);
      await repo.deleteCaffeineEntry(c.id);
      expect(repo.waterEntries, isEmpty);
      expect(repo.caffeineEntries, isEmpty);
      await repo.dispose();
    });

    test('knownFoodNames sammelt Namen aus Einträgen und Lebensmitteln', () async {
      final MorphRepository repo = await makeRepo();
      await repo.addFood(makeFood(name: 'Banane'));
      await repo.addNutritionEntry(makeNutritionEntry(foodName: 'apfel'));
      await repo.addNutritionEntry(
          makeNutritionEntry(id: 'e2', foodName: 'Apfel'));
      await repo.addNutritionEntry(
          makeNutritionEntry(id: 'e3', foodName: '   ')); // wird ignoriert
      // Sortierung case-insensitive; bei Gleichheit bleibt die Einfügereihenfolge.
      expect(repo.knownFoodNames(), <String>['apfel', 'Apfel', 'Banane']);
      await repo.dispose();
    });
  });

  group('Zyklus', () {
    test('CRUD + sortierte Perioden + periodOn', () async {
      final MorphRepository repo = await makeRepo();
      final PeriodRecord p1 =
          await repo.addPeriod(makePeriod(id: 'x', start: '2026-09-10', end: '2026-09-14'));
      final PeriodRecord p2 =
          await repo.addPeriod(makePeriod(id: 'y', start: '2026-08-01', end: '2026-08-05'));
      expect(repo.sortedPeriods.map((PeriodRecord p) => p.start).toList(),
          <String>['2026-08-01', '2026-09-10']);
      expect(repo.periodOn('2026-09-12')!.id, p1.id);
      expect(repo.periodOn('2026-09-15'), isNull);
      // Laufende Periode deckt bis heute.
      final PeriodRecord laufend =
          await repo.addPeriod(makePeriod(id: 'z', start: '2026-09-20', end: null));
      expect(repo.periodOn('2026-09-23')!.id, laufend.id);
      // Mit früherem Stichtag endet die laufende Periode am 21.09.
      expect(repo.periodOn('2026-09-23', today: '2026-09-21'), isNull);
      expect(repo.periodOn('2026-09-21', today: '2026-09-21')!.id, laufend.id);
      p1.end = '2026-09-16';
      await repo.updatePeriod(p1);
      expect(repo.periodOn('2026-09-15')!.id, p1.id);
      await repo.deletePeriod(p2.id);
      expect(repo.periods.length, 2);
      await repo.dispose();
    });
  });

  group('Gewicht', () {
    test('CRUD + Sortierung + latestWeightEntry', () async {
      final MorphRepository repo = await makeRepo();
      // addWeightEntry vergibt frische IDs (wie die anderen add*-Methoden).
      final WeightEntry a = await repo.addWeightEntry(
          makeWeightEntry(id: 'a', date: '2026-09-20', weightKg: 73));
      final WeightEntry b = await repo.addWeightEntry(
          makeWeightEntry(id: 'b', date: '2026-09-23', weightKg: 72.5));
      final WeightEntry c = await repo.addWeightEntry(
          makeWeightEntry(id: 'c', date: '2026-09-22', weightKg: 72.8));
      expect(repo.sortedWeightEntries.map((WeightEntry e) => e.date).toList(),
          <String>['2026-09-20', '2026-09-22', '2026-09-23']);
      expect(repo.weightEntryOn('2026-09-22')!.id, c.id);
      expect(repo.weightEntryOn('2026-09-21'), isNull);
      expect(repo.latestWeightEntry()!.id, b.id);
      expect(repo.latestWeightEntry(before: '2026-09-21')!.id, a.id);
      expect(repo.latestWeightEntry(before: '2026-09-19'), isNull);
      b.weightKg = 72.4;
      await repo.updateWeightEntry(b);
      expect(repo.weightEntryById(b.id)!.weightKg, 72.4);
      await repo.deleteWeightEntry(a.id);
      expect(repo.weightEntries.length, 2);
      await repo.dispose();
    });
  });

  group('Symptome', () {
    test('CRUD + Namenssuche + bekannten Namen', () async {
      final MorphRepository repo = await makeRepo();
      // addSymptomEntry vergibt frische IDs.
      final SymptomEntry a = await repo.addSymptomEntry(makeSymptomEntry(
          id: 'a', name: 'Kopfschmerzen', date: '2026-09-20', intensity: 3));
      final SymptomEntry b = await repo.addSymptomEntry(makeSymptomEntry(
          id: 'b', name: ' kopfschmerzen ', date: '2026-09-22', intensity: 7));
      await repo.addSymptomEntry(makeSymptomEntry(
          id: 'c', name: 'Müdigkeit', date: '2026-09-22', intensity: 5));
      // Sortierung case-insensitive; bei Gleichheit bleibt die Reihenfolge.
      expect(repo.knownSymptomNames(),
          <String>['Kopfschmerzen', 'kopfschmerzen', 'Müdigkeit']);
      final List<SymptomEntry> ks =
          repo.symptomEntriesForName('Kopfschmerzen');
      expect(ks.length, 2);
      // Neueste zuerst.
      expect(ks[0].id, b.id);
      expect(repo.symptomEntriesForDate('2026-09-22').length, 2);
      b.intensity = 9;
      await repo.updateSymptomEntry(b);
      expect(repo.symptomEntryById(b.id)!.intensity, 9);
      await repo.deleteSymptomEntry(a.id);
      expect(repo.symptomEntries.length, 2);
      await repo.dispose();
    });
  });

  group('Einstellungen', () {
    test('updateSettings ändert Werte und benachrichtigt', () async {
      final MorphRepository repo = await makeRepo();
      int calls = 0;
      repo.addListener(() => calls++);
      await repo.updateSettings((AppSettings s) {
        s.language = 'en';
        s.weightUnit = 'lb';
        s.visibleAreas = <String>['nutrition'];
        return s;
      });
      expect(repo.settings.language, 'en');
      expect(repo.settings.weightUnit, 'lb');
      expect(repo.settings.visibleAreas, <String>['nutrition']);
      expect(calls, 1);
      await repo.dispose();
    });
  });

  group('Globale Historie-Suche', () {
    /// Seed-Datensatz: Repository + die vom Repository vergebenen IDs
    /// (add*-Methoden vergeben frische UUIDs).
    Future<({MorphRepository repo, Map<String, String> ids})> seeded() async {
      final MorphRepository repo = await makeRepo();
      final Map<String, String> ids = <String, String>{};
      ids['e1'] = (await repo.addNutritionEntry(makeNutritionEntry(
          foodName: 'Haferflocken',
          date: '2026-09-20',
          time: '07:30',
          note: 'mit Milch'))).id;
      ids['e2'] = (await repo.addNutritionEntry(makeNutritionEntry(
          foodName: 'Apfel', date: '2026-09-22', time: '12:00'))).id;
      ids['w1'] = (await repo.addWaterEntry(
          makeWaterEntry(date: '2026-09-21', amountMl: 500))).id;
      ids['c1'] = (await repo.addCaffeineEntry(
          makeCaffeineEntry(date: '2026-09-21', amountMg: 80))).id;
      ids['p1'] = (await repo.addPeriod(makePeriod(
          start: '2026-09-01', end: '2026-09-05', note: 'August-Zyklus'))).id;
      ids['g1'] = (await repo.addWeightEntry(makeWeightEntry(
          date: '2026-09-22', weightKg: 72.5, note: 'morgens'))).id;
      ids['s1'] = (await repo.addSymptomEntry(makeSymptomEntry(
          name: 'Kopfschmerzen', date: '2026-09-23', intensity: 4))).id;
      return (repo: repo, ids: ids);
    }

    test('findet Einträge über alle Bereiche, neueste zuerst', () async {
      final (:repo, :ids) = await seeded();
      final List<HistoryHit> hits = repo.searchHistory();
      expect(hits.length, 7);
      expect(hits.first.date, '2026-09-23');
      expect(hits.first.id, ids['s1']);
      expect(hits.last.date, '2026-09-01');
      expect(hits.last.id, ids['p1']);
      expect(hits.map((HistoryHit h) => h.kind).toSet(), <String>{
        'nutrition_entry', 'water_entry', 'caffeine_entry',
        'period', 'weight_entry', 'symptom_entry',
      });
      await repo.dispose();
    });

    test('Bereichsfilter', () async {
      final (:repo, :ids) = await seeded();
      // e1, e2 (nutrition_entry) + w1 (water_entry) + c1 (caffeine_entry).
      final List<HistoryHit> nurErnaehrung =
          repo.searchHistory(area: 'nutrition');
      expect(nurErnaehrung.length, 4);
      expect(nurErnaehrung.every((HistoryHit h) => h.area == 'nutrition'),
          isTrue);
      expect(repo.searchHistory(area: 'cycle').single.id, ids['p1']);
      expect(repo.searchHistory(area: 'weight').single.id, ids['g1']);
      expect(repo.searchHistory(area: 'symptoms').single.id, ids['s1']);
      await repo.dispose();
    });

    test('Freitextfilter ist case-insensitive (Titel + Notiz)', () async {
      final (:repo, :ids) = await seeded();
      expect(repo.searchHistory(query: 'HAFER').length, 1);
      expect(repo.searchHistory(query: 'milch').single.id, ids['e1']); // Notiz
      expect(repo.searchHistory(query: 'kopfschmerzen').single.kind,
          'symptom_entry');
      expect(repo.searchHistory(query: 'morgens').single.kind, 'weight_entry');
      expect(repo.searchHistory(query: 'wasser').single.kind, 'water_entry');
      expect(repo.searchHistory(query: 'kaffee'), isEmpty);
      await repo.dispose();
    });

    test('Datumsbereich filtert inklusive Grenzen', () async {
      final (:repo, :ids) = await seeded();
      final List<HistoryHit> fenster =
          repo.searchHistory(from: '2026-09-21', to: '2026-09-22');
      expect(fenster.map((HistoryHit h) => h.id).toSet(),
          <String>{ids['e2']!, ids['w1']!, ids['c1']!, ids['g1']!});
      expect(repo.searchHistory(from: '2026-09-23').single.id, ids['s1']);
      expect(repo.searchHistory(to: '2026-09-01').single.id, ids['p1']);
      await repo.dispose();
    });

    test('Kombination aus Bereich, Zeitraum und Text', () async {
      final (:repo, :ids) = await seeded();
      final List<HistoryHit> hits = repo.searchHistory(
          area: 'nutrition', from: '2026-09-21', query: 'apfel');
      expect(hits.single.id, ids['e2']);
      await repo.dispose();
    });
  });

  group('Dokument ersetzen / löschen / exportieren', () {
    test('replaceDocument übernimmt ein Dokument und liefert Bericht', () async {
      final MorphRepository repo = await makeRepo();
      await repo.addFood(makeFood(id: 'alt'));
      final MorphDocument neu = MorphDocument(
        foods: <FoodItem>[makeFood(id: 'f1'), makeFood(id: 'f2')],
        waterEntries: <WaterEntry>[makeWaterEntry()],
      );
      final Map<String, int> report = await repo.replaceDocument(neu);
      expect(report['foods'], 2);
      expect(report['water_entries'], 1);
      expect(repo.foods.length, 2);
      expect(repo.waterEntries.length, 1);
      await repo.dispose();
    });

    test('exportPortable liefert das dokumentierte Format', () async {
      final MorphRepository repo = await makeRepo();
      await repo.addFood(makeFood(id: 'f1'));
      final Map<String, dynamic> portable = repo.exportPortable();
      expect(portable['format'], 'morphhealth.portable');
      expect(portable['format_version'], 1);
      expect(portable['generator']['app'], 'MorphHealth');
      expect(portable['generator']['version'], '1.0.0+1');
      // Muss als Import funktionieren.
      final MorphDocument back = MorphDocument.fromPortableJson(portable);
      expect(back.foods.single.id, 'f1');
      await repo.dispose();
    });

    test('deleteAllData leert Dokument und Backend', () async {
      final MemoryStoreBackend backend = MemoryStoreBackend();
      final MorphRepository repo = await makeRepo(backend: backend);
      await repo.addFood(makeFood());
      await repo.deleteAllData();
      expect(repo.document.foods, isEmpty);
      expect(backend.deleteAllCalled, isTrue);
      // Nach Persistierung ist auch das Backend leer.
      final MorphRepository neu = await makeRepo(backend: backend);
      expect(neu.foods, isEmpty);
      await neu.dispose();
    });
  });
}
