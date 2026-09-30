import 'civil.dart';
import 'db.dart';
import 'models.dart';

enum HistoryKind { foodEntry, water, caffeine, weight, period, symptom }

/// Ein Eintrag der bereichsübergreifenden Historie.
final class HistoryItem {
  final HistoryKind kind;
  final Area area;
  final String id;

  /// Zeitpunkt (bei Perioden: Beginn um 00:00).
  final LocalDateTime at;

  /// Letzter Tag bei Perioden.
  final Day? endDay;

  /// Der zugrunde liegende Datensatz (`FoodEntry`, `WaterEntry`, ...).
  final Object source;

  /// Kleingeschriebener Suchtext (Namen, Notizen, Bereichswörter in Deutsch
  /// und Englisch).
  final String text;

  const HistoryItem(this.kind, this.area, this.id, this.at, this.endDay, this.source, this.text);

  Day get day => at.day;
}

/// Filter der Historie. Alles ist optional; ein leerer Filter zeigt alles.
final class HistoryQuery {
  final Day? from;
  final Day? to;

  /// Nur diese Bereiche; null = alle.
  final Set<Area>? areas;

  /// Freitext: Jedes Wort muss vorkommen (Groß-/Kleinschreibung egal).
  final String text;

  const HistoryQuery({this.from, this.to, this.areas, this.text = ''});

  bool get isEmpty => from == null && to == null && areas == null && text.trim().isEmpty;
}

const Map<Meal, String> _mealWords = {
  Meal.breakfast: 'frühstück fruehstueck breakfast',
  Meal.lunch: 'mittagessen lunch',
  Meal.dinner: 'abendessen dinner',
  Meal.snack: 'snack zwischenmahlzeit',
};

const Map<FlowLevel, String> _flowWords = {
  FlowLevel.spotting: 'spotting schmierblutung',
  FlowLevel.light: 'leicht light',
  FlowLevel.medium: 'mittel medium',
  FlowLevel.heavy: 'stark heavy',
};

String _fmt(double v) => v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

/// Alle Einträge der vier Bereiche, neueste zuerst.
List<HistoryItem> buildHistory(Db db) {
  final out = <HistoryItem>[];
  for (final e in db.entries.all) {
    out.add(
      HistoryItem(
        HistoryKind.foodEntry,
        Area.nutrition,
        e.id,
        e.at,
        null,
        e,
        '${e.food.name} ${e.food.brand ?? ''} ${e.food.barcode ?? ''} ${e.note ?? ''} ${_mealWords[e.meal]} ernährung nutrition ${_fmt(e.amount)}'
            .toLowerCase(),
      ),
    );
  }
  for (final w in db.water.all) {
    out.add(HistoryItem(HistoryKind.water, Area.nutrition, w.id, w.at, null, w, 'wasser water trinken ${_fmt(w.ml)}'));
  }
  for (final c in db.caffeine.all) {
    out.add(
      HistoryItem(
        HistoryKind.caffeine,
        Area.nutrition,
        c.id,
        c.at,
        null,
        c,
        'koffein caffeine ${c.label ?? ''} ${_fmt(c.mg)}'.toLowerCase(),
      ),
    );
  }
  for (final w in db.weights.all) {
    out.add(
      HistoryItem(
        HistoryKind.weight,
        Area.weight,
        w.id,
        w.at,
        null,
        w,
        'gewicht weight ${w.note ?? ''} ${_fmt(w.kg)}'.toLowerCase(),
      ),
    );
  }
  for (final p in db.periods) {
    final flows = <FlowLevel>{?p.flow, ...p.dayFlows.values};
    out.add(
      HistoryItem(
        HistoryKind.period,
        Area.cycle,
        p.id,
        LocalDateTime(p.start),
        p.end,
        p,
        'periode period zyklus cycle blutung ${p.notes ?? ''} ${flows.map((f) => _flowWords[f]).join(' ')}'
            .toLowerCase(),
      ),
    );
  }
  for (final s in db.symptoms.all) {
    out.add(
      HistoryItem(
        HistoryKind.symptom,
        Area.symptoms,
        s.id,
        s.at,
        null,
        s,
        'symptom ${s.name} ${s.note ?? ''} ${s.intensity}'.toLowerCase(),
      ),
    );
  }
  out.sort((a, b) {
    final c = b.at.compareTo(a.at);
    return c != 0 ? c : a.id.compareTo(b.id);
  });
  return out;
}

/// Wendet Datumsbereich, Bereiche und Freitext an. [visible] blendet nicht
/// eingeblendete Bereiche aus.
List<HistoryItem> filterHistory(List<HistoryItem> all, HistoryQuery q, {Set<Area>? visible}) {
  final words = q.text.toLowerCase().split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();
  bool ok(HistoryItem it) {
    if (visible != null && !visible.contains(it.area)) return false;
    if (q.areas != null && !q.areas!.contains(it.area)) return false;
    final first = it.day;
    final last = it.endDay ?? it.day;
    if (q.from != null && last.isBefore(q.from!)) return false;
    if (q.to != null && first.isAfter(q.to!)) return false;
    for (final w in words) {
      if (!it.text.contains(w)) return false;
    }
    return true;
  }

  return [
    for (final it in all)
      if (ok(it)) it,
  ];
}
