import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:morphhealth/core/civil.dart';
import 'package:morphhealth/core/clock.dart';
import 'package:morphhealth/core/db.dart';
import 'package:morphhealth/core/models.dart';
import 'package:morphhealth/core/nutrients.dart';
import 'package:morphhealth/core/portable.dart';
import 'package:morphhealth/core/store.dart';

/// Alles, was die Oberfläche speichern kann, muss nach Schließen und Öffnen des verschlüsselten
/// Bestands wieder da sein und sich exportieren, importieren und erneut exportieren lassen.
/// Die Werte stammen aus den Grenzen der Eingabefelder (Randwerte eingeschlossen).
Future<Db> openDb(Directory dir, Uint8List key) async =>
    Db.open(await EncryptedStore.open(dir, key), FixedClock(DateTime(2026, 9, 29, 12)));

void roundtrip(int seed) {
  final rnd = Random(seed);

  String text(int maxLen, {bool allowEmpty = false}) {
    const pool = 'abcXYZ ÄÖÜäöüß-–.,;:!?()€%\n\t"\'\\/é日本🙂0123456789';
    final chars = pool.runes.toList();
    final len = allowEmpty ? rnd.nextInt(maxLen + 1) : 1 + rnd.nextInt(maxLen);
    // Beim Speichern und Laden werden Texte an den Rändern gekürzt; leere Texte gibt es nicht.
    final s = String.fromCharCodes([for (var i = 0; i < len; i++) chars[rnd.nextInt(chars.length)]]).trim();
    return s.isEmpty ? 'x' : s;
  }

  // Randwerte kommen häufiger vor als bei gleichverteilter Ziehung.
  double amount(double min, double max) {
    switch (rnd.nextInt(6)) {
      case 0:
        return min;
      case 1:
        return max;
      default:
        return double.parse((min + rnd.nextDouble() * (max - min)).toStringAsFixed(rnd.nextInt(4)));
    }
  }

  Day randomDay() => Day(2000, 1, 1).addDays(rnd.nextInt(12000));

  LocalDateTime randomAt() {
    final d = randomDay();
    return LocalDateTime.parse(
      '$d'
      'T${rnd.nextInt(24).toString().padLeft(2, '0')}:${rnd.nextInt(60).toString().padLeft(2, '0')}',
    );
  }

  FoodInfo randomInfo({bool withServing = false}) {
    final values = <String, double>{};
    for (final n in nutrientCatalog) {
      if (rnd.nextInt(3) == 0) values[n.key] = amount(0, rnd.nextBool() ? 1000 : 10000000);
    }
    return FoodInfo(
      name: text(200),
      brand: rnd.nextBool() ? null : text(200),
      barcode: rnd.nextBool() ? null : '${100000000 + rnd.nextInt(899999999)}',
      source: FoodSource.values[rnd.nextInt(2)],
      basis: Basis.values[rnd.nextInt(2)],
      serving: withServing || rnd.nextBool() ? Serving(amount(0.001, 100000), rnd.nextBool() ? null : text(100)) : null,
      nutrients: Nutrients.of(values),
      prepared: rnd.nextInt(5) == 0,
    );
  }

  String dump(Db db, {bool portable = false}) => jsonEncode({
    'foods': (db.foods.toList()..sort((a, b) => a.id.compareTo(b.id))).map((f) => f.toJson()).toList(),
    'entries': (db.entries.all.toList()..sort((a, b) => a.id.compareTo(b.id))).map((e) => e.toJson()).toList(),
    'water': (db.water.all.toList()..sort((a, b) => a.id.compareTo(b.id))).map((e) => e.toJson()).toList(),
    'caffeine': (db.caffeine.all.toList()..sort((a, b) => a.id.compareTo(b.id))).map((e) => e.toJson()).toList(),
    'weights': (db.weights.all.toList()..sort((a, b) => a.id.compareTo(b.id))).map((e) => e.toJson()).toList(),
    'symptoms': (db.symptoms.all.toList()..sort((a, b) => a.id.compareTo(b.id))).map((e) => e.toJson()).toList(),
    'periods': db.periods.map((p) => p.toJson()).toList(),
    'settings': db.settings.toJson(portable: portable),
    'goals': db.goals.toJson(),
  });

  test('Zufällige gültige Eingaben überleben Neustart, Export und Import unverändert (Seed $seed)', () async {
    final dir = await Directory.systemTemp.createTemp('mh_roundtrip_');
    addTearDown(() => dir.delete(recursive: true));
    final key = Uint8List.fromList(List.generate(32, (i) => i + 1));
    var db = await openDb(dir, key);
    final counts = <String, int>{};

    // Zuerst kommen die Bibliothek und Einstellungen, danach Einträge, die darauf verweisen.
    final foods = <Food>[];
    for (var i = 0; i < 60; i++) {
      final f = await db.saveFood(Food(id: 'f$i', info: randomInfo(withServing: true), favorite: rnd.nextBool()));
      foods.add(f);
    }
    counts['foods'] = foods.length;

    for (var i = 0; i < 300; i++) {
      final food = foods[rnd.nextInt(foods.length)];
      final unit = food.info.serving != null && rnd.nextBool()
          ? AmountUnit.portion
          : (food.info.basis == Basis.g ? AmountUnit.g : AmountUnit.ml);
      await db.saveEntry(
        FoodEntry(
          id: 'e$i',
          foodId: rnd.nextBool() ? food.id : null,
          food: food.info,
          amount: amount(0.001, 100000),
          unit: unit,
          meal: Meal.values[rnd.nextInt(4)],
          at: randomAt(),
          note: rnd.nextBool() ? null : text(500),
        ),
      );
    }
    counts['entries'] = 300;

    for (var i = 0; i < 100; i++) {
      await db.saveWater(WaterEntry(id: 'w$i', at: randomAt(), ml: amount(0.5, 20000)));
      await db.saveCaffeine(
        CaffeineEntry(id: 'c$i', at: randomAt(), mg: amount(0.1, 5000), label: rnd.nextBool() ? null : text(100)),
      );
      await db.saveWeight(
        WeightEntry(id: 'g$i', at: randomAt(), kg: amount(1, 700), note: rnd.nextBool() ? null : text(500)),
      );
      await db.saveSymptom(
        SymptomEntry(
          id: 's$i',
          name: text(80),
          intensity: rnd.nextInt(11),
          at: randomAt(),
          note: rnd.nextBool() ? null : text(500),
        ),
      );
    }

    // Perioden: offene und geschlossene, kürzeste und längste, mit Tagesangaben.
    var accepted = 0;
    var open = 0;
    for (var i = 0; i < 400 && accepted < 60; i++) {
      final start = randomDay();
      final isOpen = rnd.nextInt(4) == 0;
      final end = isOpen ? null : start.addDays(rnd.nextBool() ? rnd.nextInt(60) : (rnd.nextBool() ? 0 : 59));
      final last = end ?? start.addDays(9);
      final flows = <Day, FlowLevel>{};
      for (var k = 0; k < rnd.nextInt(4); k++) {
        flows[start.addDays(rnd.nextInt(start.daysUntil(last) + 1))] = FlowLevel.values[rnd.nextInt(4)];
      }
      try {
        await db.savePeriod(
          PeriodRecord(
            id: 'p$i',
            start: start,
            end: end,
            flow: rnd.nextBool() ? null : FlowLevel.values[rnd.nextInt(4)],
            dayFlows: flows,
            notes: rnd.nextBool() ? null : text(1000),
          ),
        );
        accepted++;
        if (isOpen) open++;
      } on DomainException catch (e) {
        expect(e.code, 'period_overlap', reason: e.message);
      }
    }
    expect(accepted, greaterThan(20));
    expect(open, greaterThan(0));
    counts['periods'] = accepted;

    await db.saveSettings(
      AppSettings(
        language: 'en',
        weightUnit: WeightUnit.lb,
        areas: {Area.cycle},
        onlineFood: false,
        foodBaseUrl: 'https://example.org',
        cycleForecast: false,
        expectedCycleLength: 60,
        theme: 'dark',
        secureScreen: true,
      ),
    );
    await db.saveGoals(
      const Goals(waterMl: 20000, energyKcal: 20000, proteinG: 2000, carbohydratesG: 3000, fatG: 2000),
    );

    final before = dump(db);
    await db.close();

    // 1. Neustart: der verschlüsselte Bestand öffnet sich und enthält dasselbe.
    db = await openDb(dir, key);
    expect(dump(db), before, reason: 'nach dem Neustart ${counts.toString()}');

    // 2. Export -> Import in einen leeren Bestand -> gleicher Inhalt (der Export lässt nur die
    //    gerätespezifische Serveradresse weg).
    final clock = FixedClock(DateTime(2026, 9, 29, 12));
    final exported = exportPortable(db, clock);
    final parsed = parsePortable(jsonDecode(jsonEncode(exported)));
    expect(parsed.report.warnings, isEmpty, reason: parsed.report.warnings.take(3).join('; '));
    final other = await Db.open(MemoryPersistence(), clock);
    await other.replaceAll(parsed.state);
    expect(dump(other, portable: true), dump(db, portable: true));
    expect(jsonEncode(exportPortable(other, clock)), jsonEncode(exported));
    await db.close();
  });
}

void main() {
  for (final seed in const [2026, 7, 99]) {
    roundtrip(seed);
  }

  test('Offene Periode: Speichern, Neustart und Import bleiben lesbar', () async {
    final dir = await Directory.systemTemp.createTemp('mh_open_period_');
    addTearDown(() => dir.delete(recursive: true));
    final key = Uint8List.fromList(List.filled(32, 9));
    var db = await openDb(dir, key);
    await db.savePeriod(PeriodRecord(id: 'p', start: Day.parse('2026-09-29')));
    await db.markFlowOn(Day.parse('2026-09-29'), FlowLevel.medium);
    await db.close();
    db = await openDb(dir, key);
    expect(db.periods.single.end, isNull);
    expect(db.periods.single.flowOn(Day.parse('2026-09-29')), FlowLevel.medium);
    await db.close();
  });
}
