import 'model.dart';

/// Nutrition of an entry uses the immutable food snapshot at time of logging.
Json mealTotals(Json entry) {
  final food = entry['food'] as Map;
  final ns = food['nutrients'] as Map;
  var quantity = (entry['amount'] as num).toDouble();
  if (entry['unit'] == 'serving') {
    quantity *= (food['servingSize'] as num).toDouble();
  }
  final factor = quantity / 100;
  return {
    for (final n in nutrients)
      n.key: numeric(ns[n.key]) == null ? null : numeric(ns[n.key])! * factor,
  };
}

Json nutritionDay(Json document, String date) {
  parseDay(date);
  final entries = <Json>[];
  final totals = <String, dynamic>{for (final n in nutrients) n.key: null};
  final counts = <String, dynamic>{for (final n in nutrients) n.key: 0};
  for (final raw in document['meals'] as List) {
    final item = raw as Json;
    if (!(item['at'] as String).startsWith(date)) continue;
    final values = mealTotals(item);
    entries.add({...item, 'totals': values});
    for (final n in nutrients) {
      final value = numeric(values[n.key]);
      if (value != null) {
        totals[n.key] = (numeric(totals[n.key]) ?? 0) + value;
        counts[n.key] = (counts[n.key] as int) + 1;
      }
    }
  }
  entries.sort((a, b) => (a['at'] as String).compareTo(b['at'] as String));
  var water = 0.0;
  var caffeine = 0.0;
  var caffeineEntries = 0;
  final drinks = <Json>[];
  for (final raw in document['drinks'] as List) {
    final d = raw as Json;
    if (!(d['at'] as String).startsWith(date)) continue;
    drinks.add(d);
    if (d['kind'] == 'water') {
      water += (d['amount'] as num).toDouble();
    } else {
      caffeine += (d['amount'] as num).toDouble();
      caffeineEntries++;
    }
  }
  if (caffeineEntries > 0) {
    totals['caffeine'] = (numeric(totals['caffeine']) ?? 0) + caffeine;
  }
  return {
    'date': date,
    'entries': entries,
    'drinks': drinks,
    'totals': totals,
    'waterMl': water,
    'extraCaffeineMg': caffeine,
    'caffeineMg': totals['caffeine'],
    'knownCounts': counts,
    'extraCaffeineEntryCount': caffeineEntries,
    'entryCount': entries.length,
    'completeness': {
      for (final n in nutrients)
        n.key: entries.isEmpty ? null : counts[n.key] == entries.length,
    },
  };
}
