import '../model/cycle_records.dart';
import '../model/dataset.dart';
import '../model/entries.dart';
import '../model/enums.dart';
import '../model/record.dart';
import '../l10n/format.dart';
import '../l10n/strings.dart';
import '../util/local_date.dart';

/// Kind of record shown in the searchable history.
enum HistoryKind {
  food(Area.nutrition, Collection.foodEntries),
  water(Area.nutrition, Collection.waterEntries),
  caffeine(Area.nutrition, Collection.caffeineEntries),
  period(Area.cycle, Collection.periods),
  cycleDay(Area.cycle, Collection.cycleDays),
  weight(Area.weight, Collection.weightEntries),
  symptom(Area.symptoms, Collection.symptomEntries);

  const HistoryKind(this.area, this.collection);
  final Area area;
  final Collection collection;
}

/// One row of the history list.
class HistoryItem {
  HistoryItem({
    required this.kind,
    required this.id,
    required this.date,
    required this.time,
    required this.title,
    required this.subtitle,
    required this.searchText,
  });

  final HistoryKind kind;
  final String id;
  final LocalDate date;
  final int? time;
  final String title;
  final String subtitle;

  /// Lower-case text matched by free-text queries.
  final String searchText;
}

/// A query over the history.
class HistoryQuery {
  const HistoryQuery({this.text = '', this.areas = const {}, this.from, this.to});

  final String text;

  /// Empty = all areas.
  final Set<Area> areas;
  final LocalDate? from;
  final LocalDate? to;
}

/// Flat, pre-rendered index of all diary records for fast filtering.
///
/// The index is rebuilt only when the data set version or the language
/// changes; filtering 10,000+ items takes a few milliseconds.
class HistoryIndex {
  HistoryIndex._(this.version, this.language, this.items);

  final int version;
  final Object language;

  /// All items, newest first.
  final List<HistoryItem> items;

  static HistoryIndex build(Dataset data, S s, Fmt fmt, LocalDate today) {
    final items = <HistoryItem>[];
    String timeText(int? t) => t == null ? '' : fmt.time(t);

    for (final e in data.foodEntries.values) {
      final amount = e.unit == AmountUnit.portion
          ? '${fmt.number(e.amount, 2)} ${s.unitName(AmountUnit.portion, plural: e.amount != 1)}'
          : '${fmt.number(e.amount, 1)} ${e.unit.json}';
      final kcal = e.nutrient('energy_kcal');
      final subtitle = [
        s.mealName(e.meal),
        amount,
        if (kcal != null) '${fmt.integer(kcal)} kcal',
        if (e.time != null) timeText(e.time),
      ].join(' · ');
      items.add(
        HistoryItem(
          kind: HistoryKind.food,
          id: e.id,
          date: e.date,
          time: e.time,
          title: e.food.brand == null ? e.food.name : '${e.food.name} (${e.food.brand})',
          subtitle: subtitle,
          searchText: [
            e.food.name,
            e.food.brand ?? '',
            e.food.barcode ?? '',
            s.mealName(e.meal),
            s.kindFood,
            e.note ?? '',
          ].join(' ').toLowerCase(),
        ),
      );
    }
    for (final w in data.waterEntries.values) {
      items.add(
        HistoryItem(
          kind: HistoryKind.water,
          id: w.id,
          date: w.date,
          time: w.time,
          title: s.kindWater,
          subtitle: [
            '${fmt.integer(w.amountMl)} ml',
            if (w.time != null) timeText(w.time),
          ].join(' · '),
          searchText: '${s.kindWater} ${s.water}'.toLowerCase(),
        ),
      );
    }
    for (final c in data.caffeineEntries.values) {
      items.add(
        HistoryItem(
          kind: HistoryKind.caffeine,
          id: c.id,
          date: c.date,
          time: c.time,
          title: c.label == null ? s.kindCaffeine : '${s.kindCaffeine}: ${c.label}',
          subtitle: [
            '${fmt.integer(c.amountMg)} mg',
            if (c.time != null) timeText(c.time),
          ].join(' · '),
          searchText: '${s.kindCaffeine} ${c.label ?? ''}'.toLowerCase(),
        ),
      );
    }
    for (final p in data.periods.values) {
      final end = p.end;
      final range = end == null
          ? '${fmt.medium(p.start)} – ${s.periodStillOngoing}'
          : '${fmt.medium(p.start)} – ${fmt.medium(end)}';
      final length = p.lengthDays ?? (p.start.daysUntil(today) + 1);
      items.add(
        HistoryItem(
          kind: HistoryKind.period,
          id: p.id,
          date: p.start,
          time: null,
          title: s.kindPeriod,
          subtitle: '$range · ${s.periodLengthDays(length < 1 ? 1 : length)}',
          searchText: '${s.kindPeriod} ${p.note ?? ''}'.toLowerCase(),
        ),
      );
    }
    for (final d in data.cycleDays.values) {
      final flow = d.flow == null ? null : s.flowName(d.flow!);
      items.add(
        HistoryItem(
          kind: HistoryKind.cycleDay,
          id: d.id,
          date: d.date,
          time: null,
          title: flow == null ? s.kindCycleDay : '${s.flow}: $flow',
          subtitle: d.note ?? '',
          searchText: '${s.kindCycleDay} ${s.flow} ${flow ?? ''} ${d.note ?? ''}'
              .toLowerCase(),
        ),
      );
    }
    for (final w in data.weightEntries.values) {
      final unit = data.settings.weightUnit;
      items.add(
        HistoryItem(
          kind: HistoryKind.weight,
          id: w.id,
          date: w.date,
          time: w.time,
          title: s.kindWeight,
          subtitle: [
            '${fmt.fixed(w.valueIn(unit), 1)} ${unit.json}',
            if (w.time != null) timeText(w.time),
            if (w.note != null) w.note!,
          ].join(' · '),
          searchText: '${s.kindWeight} ${w.note ?? ''}'.toLowerCase(),
        ),
      );
    }
    for (final e in data.symptomEntries.values) {
      items.add(
        HistoryItem(
          kind: HistoryKind.symptom,
          id: e.id,
          date: e.date,
          time: e.time,
          title: e.name,
          subtitle: [
            '${s.intensity} ${s.intensityValue(e.intensity)}',
            if (e.time != null) timeText(e.time),
            if (e.note != null) e.note!,
          ].join(' · '),
          searchText: '${e.name} ${s.kindSymptom} ${e.note ?? ''}'.toLowerCase(),
        ),
      );
    }
    items.sort((a, b) {
      final d = b.date.compareTo(a.date);
      if (d != 0) return d;
      return (b.time ?? -1).compareTo(a.time ?? -1);
    });
    return HistoryIndex._(data.version, s.language, items);
  }

  List<HistoryItem> filter(HistoryQuery q) {
    final tokens = q.text
        .toLowerCase()
        .split(RegExp(r'\s+'))
        .where((t) => t.isNotEmpty)
        .toList();
    final fromDay = q.from?.epochDay;
    final toDay = q.to?.epochDay;
    return [
      for (final item in items)
        if ((q.areas.isEmpty || q.areas.contains(item.kind.area)) &&
            (fromDay == null || item.date.epochDay >= fromDay) &&
            (toDay == null || item.date.epochDay <= toDay) &&
            tokens.every(item.searchText.contains))
          item,
    ];
  }
}

/// Convenience lookups used by the UI when opening a history item.
extension HistoryLookup on Dataset {
  DatedRecord? datedRecord(HistoryKind kind, String id) => switch (kind) {
    HistoryKind.food => foodEntries[id],
    HistoryKind.water => waterEntries[id],
    HistoryKind.caffeine => caffeineEntries[id],
    HistoryKind.cycleDay => cycleDays[id],
    HistoryKind.weight => weightEntries[id],
    HistoryKind.symptom => symptomEntries[id],
    HistoryKind.period => null,
  };

  Period? periodById(String id) => periods[id];
}
