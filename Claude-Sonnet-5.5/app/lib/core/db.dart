import 'dart:async';
import 'dart:convert';

import 'civil.dart';
import 'clock.dart';
import 'ids.dart';
import 'issues.dart';
import 'models.dart';
import 'store.dart';

const String tFoods = 'foods';
const String tEntries = 'food_entries';
const String tWater = 'water_entries';
const String tCaffeine = 'caffeine_entries';
const String tWeights = 'weight_entries';
const String tPeriods = 'periods';
const String tSymptoms = 'symptom_entries';
const String tMeta = 'meta';
const String kSettingsId = 'settings';
const String kGoalsId = 'goals';

/// Ein fachlicher Fehler mit stabilem Code (zum Beispiel `period_overlap`).
final class DomainException implements Exception {
  final String code;
  final String message;
  final Map<String, Object?> details;

  const DomainException(this.code, this.message, [this.details = const {}]);

  @override
  String toString() => 'DomainException($code): $message';
}

/// Sehr kleiner Beobachter, damit der Kern ohne Flutter auskommt.
final class ChangeSignal {
  final List<void Function()> _listeners = [];

  void addListener(void Function() l) => _listeners.add(l);
  void removeListener(void Function() l) => _listeners.remove(l);

  void notify() {
    for (final l in List.of(_listeners)) {
      l();
    }
  }
}

/// Tabelle mit Zeitstempel, indiziert nach ID und Tag.
final class DayTable<T> {
  final LocalDateTime Function(T) atOf;
  final String Function(T) idOf;
  final Map<String, T> byId = {};
  final Map<Day, List<T>> _byDay = {};

  DayTable(this.atOf, this.idOf);

  int _cmp(T a, T b) {
    final c = atOf(a).compareTo(atOf(b));
    return c != 0 ? c : idOf(a).compareTo(idOf(b));
  }

  void put(T v) {
    final old = byId[idOf(v)];
    if (old != null) _removeFromDay(old);
    byId[idOf(v)] = v;
    final list = _byDay.putIfAbsent(atOf(v).day, () => <T>[]);
    var i = list.length;
    while (i > 0 && _cmp(list[i - 1], v) > 0) {
      i--;
    }
    list.insert(i, v);
  }

  void remove(String id) {
    final old = byId.remove(id);
    if (old != null) _removeFromDay(old);
  }

  void _removeFromDay(T old) {
    final d = atOf(old).day;
    final list = _byDay[d];
    if (list == null) return;
    list.removeWhere((e) => idOf(e) == idOf(old));
    if (list.isEmpty) _byDay.remove(d);
  }

  void clear() {
    byId.clear();
    _byDay.clear();
  }

  /// Einträge eines Tages, nach Zeit sortiert. Nicht verändern.
  List<T> on(Day d) => _byDay[d] ?? const [];

  Iterable<T> get all => byId.values;
  int get length => byId.length;
  Iterable<Day> get days => _byDay.keys;
  bool get isEmpty => byId.isEmpty;
}

/// Alle Nutzerdaten im Speicher, mit Indizes, Änderungsoperationen und
/// dauerhafter Ablage über [Persistence]. Alle Schreibzugriffe laufen
/// nacheinander durch eine Warteschlange.
final class Db {
  final Persistence _p;
  final Clock clock;
  final ChangeSignal changes = ChangeSignal();

  final Map<String, Food> _foods = {};
  final DayTable<FoodEntry> entries = DayTable((e) => e.at, (e) => e.id);
  final DayTable<WaterEntry> water = DayTable((e) => e.at, (e) => e.id);
  final DayTable<CaffeineEntry> caffeine = DayTable((e) => e.at, (e) => e.id);
  final DayTable<WeightEntry> weights = DayTable((e) => e.at, (e) => e.id);
  final DayTable<SymptomEntry> symptoms = DayTable((e) => e.at, (e) => e.id);
  final Map<String, PeriodRecord> _periods = {};
  List<PeriodRecord>? _periodsSorted;

  AppSettings _settings = const AppSettings();
  Goals _goals = Goals.none;

  /// Wird bei jeder Änderung erhöht (für Zwischenspeicher).
  int revision = 0;

  Future<void> _queue = Future.value();

  Db._(this._p, this.clock);

  static Future<Db> open(Persistence p, Clock clock) async {
    final db = Db._(p, clock);
    db._loadFrom(p.state);
    return db;
  }

  // -- Laden ----------------------------------------------------------------

  void _loadFrom(State s) {
    final issues = Issues();
    _clearAll();
    for (final e in (s[tFoods] ?? const <String, Map<String, Object?>>{}).entries) {
      final f = Food.read(Obj(e.value, '\$.foods.${e.key}', issues));
      if (f != null) _foods[f.id] = f;
    }
    for (final e in (s[tEntries] ?? const <String, Map<String, Object?>>{}).entries) {
      final v = FoodEntry.read(Obj(e.value, '\$.food_entries.${e.key}', issues));
      if (v != null) entries.put(v);
    }
    for (final e in (s[tWater] ?? const <String, Map<String, Object?>>{}).entries) {
      final v = WaterEntry.read(Obj(e.value, '\$.water_entries.${e.key}', issues));
      if (v != null) water.put(v);
    }
    for (final e in (s[tCaffeine] ?? const <String, Map<String, Object?>>{}).entries) {
      final v = CaffeineEntry.read(Obj(e.value, '\$.caffeine_entries.${e.key}', issues));
      if (v != null) caffeine.put(v);
    }
    for (final e in (s[tWeights] ?? const <String, Map<String, Object?>>{}).entries) {
      final v = WeightEntry.read(Obj(e.value, '\$.weight_entries.${e.key}', issues));
      if (v != null) weights.put(v);
    }
    for (final e in (s[tSymptoms] ?? const <String, Map<String, Object?>>{}).entries) {
      final v = SymptomEntry.read(Obj(e.value, '\$.symptom_entries.${e.key}', issues));
      if (v != null) symptoms.put(v);
    }
    for (final e in (s[tPeriods] ?? const <String, Map<String, Object?>>{}).entries) {
      final v = PeriodRecord.read(Obj(e.value, '\$.periods.${e.key}', issues));
      if (v != null) _periods[v.id] = v;
    }
    final meta = s[tMeta] ?? const <String, Map<String, Object?>>{};
    if (meta[kSettingsId] != null) {
      _settings = AppSettings.read(Obj(meta[kSettingsId]!, '\$.settings', issues));
    }
    if (meta[kGoalsId] != null) {
      _goals = Goals.read(Obj(meta[kGoalsId]!, '\$.goals', issues));
    }
    _periodsSorted = null;
    if (issues.hasErrors) {
      throw StoreException(StoreErrorCode.corrupt, 'Gespeicherte Daten sind ungültig: ${issues.errors.first}');
    }
    revision++;
  }

  void _clearAll() {
    _foods.clear();
    entries.clear();
    water.clear();
    caffeine.clear();
    weights.clear();
    symptoms.clear();
    _periods.clear();
    _periodsSorted = null;
    _settings = const AppSettings();
    _goals = Goals.none;
  }

  // -- Zugriff --------------------------------------------------------------

  AppSettings get settings => _settings;
  Goals get goals => _goals;

  Iterable<Food> get foods => _foods.values;
  Food? food(String id) => _foods[id];

  /// Alle Perioden, nach Beginn sortiert.
  List<PeriodRecord> get periods => _periodsSorted ??= (_periods.values.toList()
    ..sort((a, b) {
      final c = a.start.compareTo(b.start);
      return c != 0 ? c : a.id.compareTo(b.id);
    }));

  PeriodRecord? period(String id) => _periods[id];

  int get totalRecords =>
      _foods.length +
      entries.length +
      water.length +
      caffeine.length +
      weights.length +
      symptoms.length +
      _periods.length;

  /// Anzahl der Tagebucheinträge (ohne Bibliothek).
  int get diaryEntryCount =>
      entries.length + water.length + caffeine.length + weights.length + symptoms.length + _periods.length;

  // -- Schreiben ------------------------------------------------------------

  Future<T> _tx<T>(Future<T> Function() action) {
    final next = _queue.then((_) => action());
    _queue = next.then<void>((_) {}, onError: (_) {});
    return next;
  }

  void _changed() {
    revision++;
    changes.notify();
  }

  /// Erzeugt die Schreiboperation für einen Datensatz. Der Datensatz muss sich mit denselben
  /// Regeln wieder lesen lassen, die beim Öffnen des Bestands gelten: Was sich hier speichern
  /// lässt, macht den Bestand nie unlesbar, und eine Verletzung zeigt sich sofort statt erst
  /// beim nächsten Start.
  static Op _put(String table, String id, Map<String, Object?> json) {
    final stored = (jsonDecode(jsonEncode(json)) as Map).cast<String, dynamic>();
    final issues = Issues();
    final o = Obj(stored, '\$.$table.$id', issues);
    switch (table) {
      case tFoods:
        Food.read(o);
      case tEntries:
        FoodEntry.read(o);
      case tWater:
        WaterEntry.read(o);
      case tCaffeine:
        CaffeineEntry.read(o);
      case tWeights:
        WeightEntry.read(o);
      case tSymptoms:
        SymptomEntry.read(o);
      case tPeriods:
        PeriodRecord.read(o);
      case tMeta:
        id == kSettingsId ? AppSettings.read(o) : Goals.read(o);
    }
    if (issues.hasErrors) throw DomainException('invalid_record', issues.errors.first.toString());
    return Op.put(table, id, json);
  }

  /// Einstellungen speichern.
  Future<void> saveSettings(AppSettings s) => _tx(() async {
    await _p.commit([_put(tMeta, kSettingsId, s.toJson())]);
    _settings = s;
    _changed();
  });

  Future<void> saveGoals(Goals g) => _tx(() async {
    await _p.commit([_put(tMeta, kGoalsId, g.toJson())]);
    _goals = g;
    _changed();
  });

  // Lebensmittel -------------------------------------------------------------

  /// Legt ein Lebensmittel an oder aktualisiert es. Bei eigenen Lebensmitteln
  /// gelten Änderungen auch für bestehende Einträge dieses Lebensmittels.
  Future<Food> saveFood(Food f) => _tx(() async {
    _validateInfo(f.info);
    final ops = <Op>[_put(tFoods, f.id, f.toJson())];
    final changedEntries = <FoodEntry>[];
    final existing = _foods[f.id];
    if (existing != null && f.info.source == FoodSource.custom && existing.info != f.info) {
      for (final e in entries.all) {
        if (e.foodId != f.id) continue;
        final n = _reconcile(e, f.info);
        changedEntries.add(n);
        ops.add(_put(tEntries, n.id, n.toJson()));
      }
    }
    await _p.commit(ops);
    _foods[f.id] = f;
    for (final e in changedEntries) {
      entries.put(e);
    }
    _changed();
    return f;
  });

  /// Übernimmt ein Produkt aus Open Food Facts in die Bibliothek (oder
  /// aktualisiert das vorhandene mit gleichem Barcode).
  Future<Food> upsertOffFood(FoodInfo info) => _tx(() async {
    _validateInfo(info);
    Food? existing;
    if (info.barcode != null) {
      for (final f in _foods.values) {
        if (f.info.source == FoodSource.off && f.info.barcode == info.barcode) {
          existing = f;
          break;
        }
      }
    }
    final food = existing != null
        ? existing.copyWith(info: info)
        : Food(id: newId(), info: info, createdAt: clock.nowLocal());
    if (existing != null && existing.info == info) return existing;
    await _p.commit([_put(tFoods, food.id, food.toJson())]);
    _foods[food.id] = food;
    _changed();
    return food;
  });

  Future<void> setFavorite(String foodId, bool favorite) => _tx(() async {
    final f = _foods[foodId];
    if (f == null || f.favorite == favorite) return;
    final n = f.copyWith(favorite: favorite);
    await _p.commit([_put(tFoods, n.id, n.toJson())]);
    _foods[n.id] = n;
    _changed();
  });

  /// Löscht ein Lebensmittel aus der Bibliothek. Bestehende Einträge behalten
  /// ihre Angaben.
  Future<void> deleteFood(String foodId) => _tx(() async {
    if (!_foods.containsKey(foodId)) return;
    await _p.commit([Op.delete(tFoods, foodId)]);
    _foods.remove(foodId);
    _changed();
  });

  void _validateInfo(FoodInfo info) {
    if (info.name.trim().isEmpty) {
      throw const DomainException('invalid_food', 'Ein Lebensmittel braucht einen Namen');
    }
    final s = info.serving;
    if (s != null && !(s.amount > 0)) {
      throw const DomainException('invalid_food', 'Die Portionsgröße muss größer als 0 sein');
    }
  }

  /// Überträgt geänderte Lebensmittelangaben in einen Eintrag. Wird die
  /// Portionsgröße entfernt, rechnet der Eintrag in die Bezugseinheit um.
  FoodEntry _reconcile(FoodEntry e, FoodInfo info) {
    if (e.unit == AmountUnit.portion && info.serving == null) {
      final base = e.baseAmount;
      return e.copyWith(
        food: info,
        amount: base > 0 ? base : e.amount,
        unit: info.basis == Basis.ml ? AmountUnit.ml : AmountUnit.g,
      );
    }
    return e.copyWith(food: info);
  }

  // Verzehreinträge ------------------------------------------------------------

  void _validateEntry(FoodEntry e) {
    if (!(e.amount > 0)) throw const DomainException('invalid_amount', 'Die Menge muss größer als 0 sein');
    if (e.unit == AmountUnit.portion && (e.food.serving == null || !(e.food.serving!.amount > 0))) {
      throw const DomainException('invalid_amount', 'Für Portionen ist eine Portionsgröße nötig');
    }
    _validateInfo(e.food);
  }

  Future<FoodEntry> saveEntry(FoodEntry e) => _tx(() async {
    _validateEntry(e);
    await _p.commit([_put(tEntries, e.id, e.toJson())]);
    entries.put(e);
    _changed();
    return e;
  });

  Future<void> deleteEntry(String id) => _tx(() async {
    if (!entries.byId.containsKey(id)) return;
    await _p.commit([Op.delete(tEntries, id)]);
    entries.remove(id);
    _changed();
  });

  // Wasser und Koffein ---------------------------------------------------------

  Future<WaterEntry> saveWater(WaterEntry w) => _tx(() async {
    if (!(w.ml > 0)) throw const DomainException('invalid_amount', 'Die Menge muss größer als 0 sein');
    await _p.commit([_put(tWater, w.id, w.toJson())]);
    water.put(w);
    _changed();
    return w;
  });

  Future<void> deleteWater(String id) => _tx(() async {
    if (!water.byId.containsKey(id)) return;
    await _p.commit([Op.delete(tWater, id)]);
    water.remove(id);
    _changed();
  });

  Future<CaffeineEntry> saveCaffeine(CaffeineEntry c) => _tx(() async {
    if (!(c.mg > 0)) throw const DomainException('invalid_amount', 'Die Menge muss größer als 0 sein');
    await _p.commit([_put(tCaffeine, c.id, c.toJson())]);
    caffeine.put(c);
    _changed();
    return c;
  });

  Future<void> deleteCaffeine(String id) => _tx(() async {
    if (!caffeine.byId.containsKey(id)) return;
    await _p.commit([Op.delete(tCaffeine, id)]);
    caffeine.remove(id);
    _changed();
  });

  // Gewicht --------------------------------------------------------------------

  Future<WeightEntry> saveWeight(WeightEntry w) => _tx(() async {
    if (!(w.kg >= 1 && w.kg <= 700)) {
      throw const DomainException('invalid_weight', 'Das Gewicht liegt außerhalb des zulässigen Bereichs');
    }
    await _p.commit([_put(tWeights, w.id, w.toJson())]);
    weights.put(w);
    _changed();
    return w;
  });

  Future<void> deleteWeight(String id) => _tx(() async {
    if (!weights.byId.containsKey(id)) return;
    await _p.commit([Op.delete(tWeights, id)]);
    weights.remove(id);
    _changed();
  });

  // Symptome -------------------------------------------------------------------

  Future<SymptomEntry> saveSymptom(SymptomEntry s) => _tx(() async {
    if (s.name.trim().isEmpty) throw const DomainException('invalid_symptom', 'Ein Symptom braucht einen Namen');
    if (s.intensity < 0 || s.intensity > 10) {
      throw const DomainException('invalid_symptom', 'Die Intensität liegt zwischen 0 und 10');
    }
    final n = s.copyWith(name: s.name.trim().replaceAll(RegExp(r'\s+'), ' '));
    await _p.commit([_put(tSymptoms, n.id, n.toJson())]);
    symptoms.put(n);
    _changed();
    return n;
  });

  Future<void> deleteSymptom(String id) => _tx(() async {
    if (!symptoms.byId.containsKey(id)) return;
    await _p.commit([Op.delete(tSymptoms, id)]);
    symptoms.remove(id);
    _changed();
  });

  // Perioden -------------------------------------------------------------------

  /// Speichert eine Periode. Überschneidungen mit anderen Perioden werden
  /// abgewiesen (`period_overlap`).
  Future<PeriodRecord> savePeriod(PeriodRecord p) => _tx(() async {
    _validatePeriod(p);
    await _p.commit([_put(tPeriods, p.id, p.toJson())]);
    _periods[p.id] = p;
    _periodsSorted = null;
    _changed();
    return p;
  });

  Future<void> deletePeriod(String id) => _tx(() async {
    if (!_periods.containsKey(id)) return;
    await _p.commit([Op.delete(tPeriods, id)]);
    _periods.remove(id);
    _periodsSorted = null;
    _changed();
  });

  void _validatePeriod(PeriodRecord p) {
    final today = clock.today();
    if (p.end != null && p.end!.isBefore(p.start)) {
      throw const DomainException('invalid_period', 'Das Ende liegt vor dem Beginn');
    }
    final asOf = today.isAfter(p.start) ? today : p.start;
    if (p.start.daysUntil(p.lastDay(asOf)) + 1 > PeriodRecord.maxDays) {
      throw const DomainException(
        'invalid_period',
        'Eine Periode darf höchstens ${PeriodRecord.maxDays} Tage umfassen',
      );
    }
    for (final q in _periods.values) {
      if (q.id == p.id) continue;
      final qLast = q.lastDay(asOf.isAfter(q.start) ? asOf : q.start);
      final pLast = p.lastDay(asOf);
      final overlap = !p.start.isAfter(qLast) && !q.start.isAfter(pLast);
      if (overlap) {
        throw DomainException('period_overlap', 'Die Periode überschneidet sich mit einer vorhandenen Periode', {
          'other_id': q.id,
          'other_start': q.start.toString(),
          'other_end': q.end?.toString(),
        });
      }
    }
  }

  /// Markiert den Tag [d] mit der Blutungsstärke [flow] (null = Angabe für den
  /// Tag entfernen). Liegt der Tag in keiner Periode, wird er an eine
  /// unmittelbar angrenzende Periode angehängt oder als neue Periode angelegt.
  Future<PeriodRecord> markFlowOn(Day d, FlowLevel? flow) => _tx(() async {
    final today = clock.today();
    final asOf = today.isAfter(d) ? today : d;
    PeriodRecord? cover;
    PeriodRecord? before;
    PeriodRecord? after;
    for (final q in _periods.values) {
      if (q.coversDay(d, asOf)) cover = q;
      final ql = q.lastDay(asOf);
      if (ql.addDays(1) == d) before = q;
      if (q.start.addDays(-1) == d) after = q;
    }
    PeriodRecord next;
    if (cover != null) {
      final m = Map<Day, FlowLevel>.of(cover.dayFlows);
      if (flow == null) {
        m.remove(d);
      } else if (flow == cover.flow) {
        m.remove(d);
      } else {
        m[d] = flow;
      }
      next = cover.copyWith(dayFlows: m);
    } else if (flow == null) {
      throw const DomainException('nothing_to_remove', 'An diesem Tag ist keine Periode erfasst');
    } else if (before != null) {
      final m = Map<Day, FlowLevel>.of(before.dayFlows);
      if (flow != before.flow) m[d] = flow;
      next = before.copyWith(end: () => d, dayFlows: m);
    } else if (after != null) {
      final m = Map<Day, FlowLevel>.of(after.dayFlows);
      if (flow != after.flow) m[d] = flow;
      next = after.copyWith(start: d, dayFlows: m);
    } else {
      next = PeriodRecord(id: newId(), start: d, end: d, flow: flow);
    }
    _validatePeriod(next);
    await _p.commit([_put(tPeriods, next.id, next.toJson())]);
    _periods[next.id] = next;
    _periodsSorted = null;
    _changed();
    return next;
  });

  // Ersetzen des gesamten Bestands ----------------------------------------------

  /// Ersetzt alle Daten (Import, Wiederherstellung, Löschen).
  Future<void> replaceAll(State newState) => _tx(() async {
    await _p.replaceAll(newState);
    _loadFrom(_p.state);
    _changed();
  });

  /// Löscht alle Nutzerdaten und Einstellungen.
  Future<void> wipe() => replaceAll({});

  // -- Abfragen ---------------------------------------------------------------

  /// Perioden, die den Tag [d] abdecken.
  List<PeriodRecord> periodsOn(Day d) {
    final asOf = clock.today().isAfter(d) ? clock.today() : d;
    return [
      for (final p in periods)
        if (p.coversDay(d, asOf)) p,
    ];
  }

  /// Die ersten und letzten Tage mit Daten (für Kalender und Verlauf).
  (Day, Day)? get dataRange {
    Day? lo;
    Day? hi;
    void see(Iterable<Day> days) {
      for (final d in days) {
        if (lo == null || d.isBefore(lo!)) lo = d;
        if (hi == null || d.isAfter(hi!)) hi = d;
      }
    }

    see(entries.days);
    see(water.days);
    see(caffeine.days);
    see(weights.days);
    see(symptoms.days);
    see(periods.map((p) => p.start));
    see(periods.where((p) => p.end != null).map((p) => p.end!));
    return lo == null ? null : (lo!, hi!);
  }

  /// Bibliothek durchsuchen (Name, Marke, Barcode).
  List<Food> searchFoods(String query, {int limit = 50}) {
    final q = query.trim().toLowerCase();
    final recency = _recencyByFood();
    final hits = <Food>[
      for (final f in _foods.values)
        if (q.isEmpty ||
            f.info.name.toLowerCase().contains(q) ||
            (f.info.brand?.toLowerCase().contains(q) ?? false) ||
            (f.info.barcode?.contains(q) ?? false))
          f,
    ];
    hits.sort((a, b) {
      if (a.favorite != b.favorite) return a.favorite ? -1 : 1;
      final ra = recency[a.id];
      final rb = recency[b.id];
      if (ra != null && rb != null && ra != rb) return rb.compareTo(ra);
      if ((ra == null) != (rb == null)) return ra == null ? 1 : -1;
      return a.info.name.toLowerCase().compareTo(b.info.name.toLowerCase());
    });
    return hits.length > limit ? hits.sublist(0, limit) : hits;
  }

  Map<String, LocalDateTime> _recencyByFood() {
    final out = <String, LocalDateTime>{};
    for (final e in entries.all) {
      final id = e.foodId;
      if (id == null) continue;
      final cur = out[id];
      if (cur == null || e.at.compareTo(cur) > 0) out[id] = e.at;
    }
    return out;
  }

  /// Zuletzt verzehrte Lebensmittel als Verzehreinträge (je Lebensmittel der
  /// jüngste), neueste zuerst.
  List<FoodEntry> recentEntries({int limit = 20}) {
    final latest = <String, FoodEntry>{};
    for (final e in entries.all) {
      final key = e.foodId ?? '${e.food.name}|${e.food.brand}|${e.food.barcode}';
      final cur = latest[key];
      if (cur == null || e.at.compareTo(cur.at) > 0) latest[key] = e;
    }
    final list = latest.values.toList()..sort((a, b) => b.at.compareTo(a.at));
    return list.length > limit ? list.sublist(0, limit) : list;
  }

  /// Bisher verwendete Symptomnamen (neueste Verwendung zuerst) mit Häufigkeit.
  List<SymptomName> symptomNames() {
    final byKey = <String, SymptomName>{};
    for (final s in symptoms.all) {
      final cur = byKey[s.key];
      if (cur == null) {
        byKey[s.key] = SymptomName(s.name, 1, s.at);
      } else {
        byKey[s.key] = SymptomName(
          s.at.compareTo(cur.lastAt) > 0 ? s.name : cur.name,
          cur.count + 1,
          s.at.compareTo(cur.lastAt) > 0 ? s.at : cur.lastAt,
        );
      }
    }
    final list = byKey.values.toList()..sort((a, b) => b.lastAt.compareTo(a.lastAt));
    return list;
  }

  /// Der Wert des Gewichts an einem Tag: der letzte Eintrag des Tages.
  WeightEntry? weightOn(Day d) {
    final l = weights.on(d);
    return l.isEmpty ? null : l.last;
  }

  /// Das jüngste Gewicht bis einschließlich [d].
  WeightEntry? latestWeightUpTo(Day d) {
    WeightEntry? best;
    for (final w in weights.all) {
      if (w.day.isAfter(d)) continue;
      if (best == null || w.at.compareTo(best.at) > 0) best = w;
    }
    return best;
  }

  /// Nährstoff-Schlüssel, für die es Daten gibt (nur für Anzeigen).
  Set<String> get usedNutrientKeys {
    final out = <String>{};
    for (final e in entries.all) {
      out.addAll(e.food.nutrients.keys);
    }
    return out;
  }

  Future<void> close() => _p.close();
}

/// Ein Symptomname mit Häufigkeit und letzter Verwendung.
final class SymptomName {
  final String name;
  final int count;
  final LocalDateTime lastAt;

  const SymptomName(this.name, this.count, this.lastAt);
}
