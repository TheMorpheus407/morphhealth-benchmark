import '../model/app_data.dart';
import '../model/entries.dart';
import '../model/food.dart';
import '../nutrition/nutrition_day.dart';
import '../util/dates.dart';
import 'history.dart';

/// Summary of a daily series for labels and screen readers.
class SeriesStats {
  /// Days that have a value.
  final int count;
  final double? min;
  final Day? minDay;
  final double? max;
  final Day? maxDay;
  final double? mean;

  /// The earliest value and its day.
  final double? first;
  final Day? firstDay;

  /// The latest value and its day.
  final double? last;
  final Day? lastDay;

  const SeriesStats({
    required this.count,
    this.min,
    this.minDay,
    this.max,
    this.maxDay,
    this.mean,
    this.first,
    this.firstDay,
    this.last,
    this.lastDay,
  });

  /// Last value minus first value, if there are at least two.
  double? get change =>
      count >= 2 && first != null && last != null ? last! - first! : null;

  factory SeriesStats.of(List<DayValue> series) {
    var count = 0;
    var sum = 0.0;
    double? min, max, first, last;
    Day? minDay, maxDay, firstDay, lastDay;
    for (final p in series) {
      final v = p.value;
      if (v == null) continue;
      count++;
      sum += v;
      first ??= v;
      firstDay ??= p.day;
      last = v;
      lastDay = p.day;
      if (min == null || v < min) {
        min = v;
        minDay = p.day;
      }
      if (max == null || v > max) {
        max = v;
        maxDay = p.day;
      }
    }
    return SeriesStats(
      count: count,
      min: min,
      minDay: minDay,
      max: max,
      maxDay: maxDay,
      mean: count == 0 ? null : sum / count,
      first: first,
      firstDay: firstDay,
      last: last,
      lastDay: lastDay,
    );
  }
}

/// Weight in kilograms per day from [from] to [to]; the mean if a day has
/// several values, null if it has none.
List<DayValue> weightSeries(AppData data, Day from, Day to) => [
  for (var d = from; d <= to; d = d.addDays(1)) DayValue(d, data.weightKgOn(d)),
];

/// Strongest intensity per day of the symptom with [nameKey] (see
/// [SymptomEntry.nameKey]); null on days without an entry.
List<DayValue> symptomSeries(AppData data, String nameKey, Day from, Day to) {
  final out = <DayValue>[];
  for (var d = from; d <= to; d = d.addDays(1)) {
    int? strongest;
    for (final s in data.symptomsOn(d)) {
      if (s.nameKey != nameKey) continue;
      if (strongest == null || s.intensity > strongest) strongest = s.intensity;
    }
    out.add(DayValue(d, strongest?.toDouble()));
  }
  return out;
}

/// A symptom name the user has used.
class SymptomName {
  final String key;

  /// The spelling of the most recent entry.
  final String display;
  final int count;
  final LocalDateTime lastUsed;

  const SymptomName(this.key, this.display, this.count, this.lastUsed);
}

/// All symptom names in use, most recently used first.
List<SymptomName> symptomNames(AppData data) {
  final byKey = <String, SymptomName>{};
  for (final s in data.symptoms) {
    final old = byKey[s.nameKey];
    if (old == null) {
      byKey[s.nameKey] = SymptomName(s.nameKey, s.name, 1, s.at);
    } else {
      final newer = s.at.compareTo(old.lastUsed) > 0;
      byKey[s.nameKey] = SymptomName(
        s.nameKey,
        newer ? s.name : old.display,
        old.count + 1,
        newer ? s.at : old.lastUsed,
      );
    }
  }
  return byKey.values.toList()..sort((a, b) {
    final c = b.lastUsed.compareTo(a.lastUsed);
    return c != 0 ? c : a.key.compareTo(b.key);
  });
}

/// A food together with the user's most recent entry of it.
class RecentFood {
  final Food food;
  final IntakeEntry lastEntry;
  final int uses;

  const RecentFood(this.food, this.lastEntry, this.uses);
}

/// Foods the user logged, most recently used first. Each carries its latest
/// entry, so that it can be logged again with the same amount in one step.
List<RecentFood> recentFoods(AppData data, {int limit = 30}) {
  final latest = <String, IntakeEntry>{};
  final uses = <String, int>{};
  for (final e in data.intake) {
    uses[e.foodId] = (uses[e.foodId] ?? 0) + 1;
    final old = latest[e.foodId];
    if (old == null || e.at.compareTo(old.at) > 0) latest[e.foodId] = e;
  }
  final out = <RecentFood>[];
  for (final entry in latest.entries) {
    final food = data.food(entry.key);
    if (food == null || food.archived) continue;
    out.add(RecentFood(food, entry.value, uses[entry.key]!));
  }
  out.sort((a, b) {
    final c = b.lastEntry.at.compareTo(a.lastEntry.at);
    return c != 0 ? c : a.food.id.compareTo(b.food.id);
  });
  return out.length > limit ? out.sublist(0, limit) : out;
}

/// Local foods (own foods and kept products) whose name, brand or barcode
/// contains every word of [query]. Favorites first, then by name. Archived
/// foods are left out.
List<Food> searchLocalFoods(
  AppData data,
  String query, {
  int limit = 100,
  bool customOnly = false,
  bool favoritesOnly = false,
}) {
  final terms = searchTerms(query);
  final out = <Food>[];
  for (final f in data.foods) {
    if (f.archived) continue;
    if (customOnly && !f.isCustom) continue;
    if (favoritesOnly && !f.favorite) continue;
    if (terms.isNotEmpty) {
      final text = foldForSearch(
        '${f.name} ${f.brand ?? ''} ${f.barcode ?? ''}',
      );
      if (!terms.every(text.contains)) continue;
    }
    out.add(f);
  }
  out.sort((a, b) {
    if (a.favorite != b.favorite) return a.favorite ? -1 : 1;
    final c = foldForSearch(a.name).compareTo(foldForSearch(b.name));
    return c != 0 ? c : a.id.compareTo(b.id);
  });
  return out.length > limit ? out.sublist(0, limit) : out;
}
