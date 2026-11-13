import '../model/app_data.dart';
import '../model/entries.dart';
import '../model/food.dart';
import '../model/settings.dart';
import '../util/dates.dart';

/// The kinds of entries that appear in the common history.
enum HistoryKind {
  intake(Area.nutrition),
  water(Area.nutrition),
  caffeine(Area.nutrition),
  weight(Area.weight),
  symptom(Area.symptoms),
  period(Area.cycle),
  cycleDay(Area.cycle);

  final Area area;
  const HistoryKind(this.area);
}

/// One entry of any area, prepared for listing and searching.
class HistoryItem {
  final HistoryKind kind;

  /// Id of the record; for [HistoryKind.cycleDay] the date as `YYYY-MM-DD`.
  final String id;

  /// The day the entry is listed under (for a period: its first day).
  final Day day;

  /// Last day the entry covers; differs from [day] only for periods.
  final Day lastDay;

  /// Orders entries by wall-clock time.
  final int sortKey;

  /// The underlying record: [IntakeEntry], [WaterEntry], [CaffeineEntry],
  /// [WeightEntry], [SymptomEntry], [Period] or [CycleDay].
  final Object record;

  /// The food of an [IntakeEntry].
  final Food? food;

  /// Lower-case, accent-free text that the free-text filter matches against.
  final String searchText;

  const HistoryItem({
    required this.kind,
    required this.id,
    required this.day,
    required this.lastDay,
    required this.sortKey,
    required this.record,
    this.food,
    required this.searchText,
  });

  Area get area => kind.area;
}

/// Lower case without accents and umlauts, so that "muesli", "Müsli" and
/// "MUSLI" find each other.
///
/// The umlaut spellings "ae", "oe" and "ue" are reduced to the plain vowel
/// as well. Both the stored text and the query go through this function, so
/// a word always finds itself; the price is that "bauer" and "baur" count as
/// the same, which is acceptable for a search aid.
String foldForSearch(String input) {
  final lower = input.toLowerCase();
  final b = StringBuffer();
  for (final rune in lower.runes) {
    final mapped = _folds[rune];
    if (mapped != null) {
      b.write(mapped);
    } else {
      b.writeCharCode(rune);
    }
  }
  final folded = b.toString();
  if (!folded.contains('e')) return folded;
  return folded
      .replaceAll('ae', 'a')
      .replaceAll('oe', 'o')
      .replaceAll('ue', 'u');
}

const Map<int, String> _folds = {
  0xE4: 'a', 0xF6: 'o', 0xFC: 'u', 0xDF: 'ss', // ä ö ü ß
  0xE0: 'a', 0xE1: 'a', 0xE2: 'a', 0xE3: 'a', 0xE5: 'a',
  0xE7: 'c',
  0xE8: 'e', 0xE9: 'e', 0xEA: 'e', 0xEB: 'e',
  0xEC: 'i', 0xED: 'i', 0xEE: 'i', 0xEF: 'i',
  0xF1: 'n',
  0xF2: 'o', 0xF3: 'o', 0xF4: 'o', 0xF5: 'o', 0xF8: 'o',
  0xF9: 'u', 0xFA: 'u', 0xFB: 'u',
  0xFD: 'y', 0xFF: 'y',
};

/// Splits a query into folded terms.
List<String> searchTerms(String query) => [
  for (final t in foldForSearch(query).split(RegExp(r'\s+')))
    if (t.isNotEmpty) t,
];

/// All entries of the four areas in one list, newest first, with filters for
/// date range, area and free text.
///
/// Building the index touches every entry once; searching is a single pass
/// over prepared strings. With 10,000 entries both take a few milliseconds.
class HistoryIndex {
  /// Newest first.
  final List<HistoryItem> items;

  /// [AppData.revision] this index was built from.
  final int revision;

  HistoryIndex._(this.items, this.revision);

  /// [labels] supplies words in the user's language that should also be
  /// findable, for example `{'water': 'Wasser', 'meal.breakfast':
  /// 'Frühstück'}`. Keys: `water`, `caffeine`, `weight`, `period`,
  /// `spotting`, `meal.<code>` and `flow.<code>`.
  factory HistoryIndex.build(
    AppData data, {
    Map<String, String> labels = const {},
  }) {
    String label(String key) => labels[key] ?? key;
    final items = <HistoryItem>[];

    for (final e in data.intake) {
      final food = data.food(e.foodId);
      items.add(
        HistoryItem(
          kind: HistoryKind.intake,
          id: e.id,
          day: e.day,
          lastDay: e.day,
          sortKey: e.at.sortKey,
          record: e,
          food: food,
          searchText: foldForSearch(
            [
              food?.name ?? '',
              food?.brand ?? '',
              food?.barcode ?? '',
              label('meal.${e.meal.code}'),
              e.note ?? '',
            ].join(' '),
          ),
        ),
      );
    }
    for (final e in data.water) {
      items.add(
        HistoryItem(
          kind: HistoryKind.water,
          id: e.id,
          day: e.day,
          lastDay: e.day,
          sortKey: e.at.sortKey,
          record: e,
          searchText: foldForSearch(label('water')),
        ),
      );
    }
    for (final e in data.caffeine) {
      items.add(
        HistoryItem(
          kind: HistoryKind.caffeine,
          id: e.id,
          day: e.day,
          lastDay: e.day,
          sortKey: e.at.sortKey,
          record: e,
          searchText: foldForSearch('${label('caffeine')} ${e.label ?? ''}'),
        ),
      );
    }
    for (final e in data.weights) {
      items.add(
        HistoryItem(
          kind: HistoryKind.weight,
          id: e.id,
          day: e.date,
          lastDay: e.date,
          sortKey: e.date.epochDay * 86400,
          record: e,
          searchText: foldForSearch('${label('weight')} ${e.note ?? ''}'),
        ),
      );
    }
    for (final e in data.symptoms) {
      items.add(
        HistoryItem(
          kind: HistoryKind.symptom,
          id: e.id,
          day: e.day,
          lastDay: e.day,
          sortKey: e.at.sortKey,
          record: e,
          searchText: foldForSearch('${e.name} ${e.note ?? ''}'),
        ),
      );
    }
    for (final p in data.periods) {
      final flows = {for (final f in p.flow.values) label('flow.${f.code}')};
      items.add(
        HistoryItem(
          kind: HistoryKind.period,
          id: p.id,
          day: p.start,
          lastDay: p.end ?? p.start,
          sortKey: p.start.epochDay * 86400,
          record: p,
          searchText: foldForSearch(
            '${label('period')} ${flows.join(' ')} ${p.note ?? ''}',
          ),
        ),
      );
    }
    for (final d in data.cycleDays) {
      items.add(
        HistoryItem(
          kind: HistoryKind.cycleDay,
          id: d.date.toString(),
          day: d.date,
          lastDay: d.date,
          sortKey: d.date.epochDay * 86400,
          record: d,
          searchText: foldForSearch(
            '${d.spotting ? label('spotting') : ''} ${d.note ?? ''}',
          ),
        ),
      );
    }
    items.sort((a, b) {
      final c = b.sortKey.compareTo(a.sortKey);
      if (c != 0) return c;
      final k = a.kind.index.compareTo(b.kind.index);
      return k != 0 ? k : a.id.compareTo(b.id);
    });
    return HistoryIndex._(items, data.revision);
  }

  /// Entries from [from] to [to] (both inclusive, both optional) in [areas]
  /// (null: all) whose text contains every word of [text].
  List<HistoryItem> search({
    Day? from,
    Day? to,
    Set<Area>? areas,
    String text = '',
  }) {
    final terms = searchTerms(text);
    if (from == null &&
        to == null &&
        (areas == null || areas.length == Area.values.length) &&
        terms.isEmpty) {
      return items;
    }
    final out = <HistoryItem>[];
    for (final item in items) {
      if (to != null && item.day > to) continue;
      if (from != null && item.lastDay < from) continue;
      if (areas != null && !areas.contains(item.area)) continue;
      var match = true;
      for (final t in terms) {
        if (!item.searchText.contains(t)) {
          match = false;
          break;
        }
      }
      if (match) out.add(item);
    }
    return out;
  }
}
