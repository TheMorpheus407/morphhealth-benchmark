import 'model.dart';

List<Json> history(
  Json document, {
  String? from,
  String? to,
  String? area,
  String query = '',
  int offset = 0,
  int limit = 100,
  DateTime? now,
}) {
  if (from != null) parseDay(from);
  if (to != null) parseDay(to);
  if (from != null && to != null && from.compareTo(to) > 0) {
    throw const CoreException('invalid_range', 'Start date exceeds end date.');
  }
  if (area != null && !areas.contains(area)) {
    throw const CoreException('invalid_area', 'Unknown history area.');
  }
  if (offset < 0 || limit < 1 || limit > 10000) {
    throw const CoreException(
      'invalid_page',
      'History offset >= 0; limit 1–10000.',
    );
  }
  final today = dateKey(now ?? DateTime.now());
  final q = query.trim().toLowerCase();
  final de = (document['settings'] as Map)['language'] != 'en';
  final rows = <Json>[];
  const mapping = {
    'meals': 'nutrition',
    'drinks': 'nutrition',
    'periods': 'cycle',
    'weights': 'weight',
    'symptoms': 'symptoms',
  };
  for (final c in mapping.keys) {
    if (area != null && mapping[c] != area) continue;
    for (final raw in document[c] as List) {
      final e = raw as Json;
      final at = (e[c == 'periods' ? 'start' : 'at'] as String);
      final date = at.substring(0, 10);
      final last = c == 'periods'
          ? (e['end'] as String? ?? (today.compareTo(date) < 0 ? date : today))
          : date;
      if (from != null && last.compareTo(from) < 0) continue;
      if (to != null && date.compareTo(to) > 0) continue;
      final title = switch (c) {
        'meals' => (e['food'] as Map)['name'] as String,
        'drinks' =>
          e['kind'] == 'water'
              ? (de ? 'Wasser' : 'Water')
              : (de ? 'Koffein' : 'Caffeine'),
        'periods' =>
          e['flow'] == 'spotting' ? 'Spotting' : (de ? 'Periode' : 'Period'),
        'weights' =>
          (document['settings'] as Map)['weightUnit'] == 'lb'
              ? '${((e['kg'] as num) * 2.20462262185).toStringAsFixed(1)} lb'
              : '${e['kg']} kg',
        _ => e['name'] as String,
      };
      final searchable = [
        title,
        e['note'] ?? '',
        date,
        e['meal'] ?? '',
        switch (e['meal']) {
          'breakfast' => 'Frühstück breakfast',
          'lunch' => 'Mittagessen lunch',
          'dinner' => 'Abendessen dinner',
          'snack' => 'Snack',
          _ => '',
        },
        switch (e['flow']) {
          'light' => 'leicht light',
          'medium' => 'mittel medium',
          'heavy' => 'stark heavy',
          'spotting' => 'Schmierblutung spotting',
          _ => '',
        },
        e['flow'] ?? '',
        e['kind'] ?? '',
        if (c == 'meals') (e['food'] as Map)['brand'] ?? '',
        if (c == 'meals') (e['food'] as Map)['barcode'] ?? '',
      ].join(' ').toLowerCase();
      if (q.isNotEmpty && !searchable.contains(q)) continue;
      rows.add({
        'collection': c,
        'item': e,
        'date': date,
        'title': title,
        '_sort': at,
      });
    }
  }
  rows.sort((a, b) {
    final compare = (b['_sort'] as String).compareTo(a['_sort'] as String);
    return compare != 0
        ? compare
        : '${a['collection']}/${a['item']['id']}'.compareTo(
            '${b['collection']}/${b['item']['id']}',
          );
  });
  if (offset >= rows.length) return [];
  return rows
      .skip(offset)
      .take(limit)
      .map((e) => {...e}..remove('_sort'))
      .toList();
}
