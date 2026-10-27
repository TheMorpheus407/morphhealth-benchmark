import 'health.dart';
import 'nutrition.dart';
import 'utils.dart';

class HistoryRecord {
  const HistoryRecord({
    required this.area,
    required this.kind,
    required this.id,
    required this.date,
    required this.sortTime,
    required this.title,
    required this.searchText,
    required this.value,
  });

  final String area;
  final String kind;
  final String id;
  final String date;
  final DateTime sortTime;
  final String title;
  final String searchText;
  final Object value;
}

List<HistoryRecord> searchHistory(
  AppState state, {
  String query = '',
  String area = 'all',
  String? from,
  String? to,
}) {
  if (from != null) parseDate(from, 'from');
  if (to != null) parseDate(to, 'to');
  final records = <HistoryRecord>[
    for (final entry in state.intakes)
      HistoryRecord(
        area: 'nutrition',
        kind: entry.kind.name,
        id: entry.id,
        date: instantDateKey(entry.occurredAt),
        sortTime: entry.occurredAt,
        title: entry.kind == IntakeKind.food ? entry.foodName : entry.kind.name,
        searchText:
            '${entry.foodName} ${entry.brand} ${entry.meal} ${entry.notes} ${entry.kind.name} wasser koffein',
        value: entry,
      ),
    for (final period in state.periods)
      HistoryRecord(
        area: 'cycle',
        kind: 'period',
        id: period.id,
        date: period.start,
        sortTime: parseDate(period.start),
        title: 'period',
        searchText: 'period periode ${period.flow} ${period.notes}',
        value: period,
      ),
    for (final weight in state.weights)
      HistoryRecord(
        area: 'weight',
        kind: 'weight',
        id: weight.id,
        date: weight.date,
        sortTime: parseDate(weight.date),
        title: 'weight',
        searchText: 'weight gewicht ${weight.kg} ${weight.notes}',
        value: weight,
      ),
    for (final symptom in state.symptoms)
      HistoryRecord(
        area: 'symptoms',
        kind: 'symptom',
        id: symptom.id,
        date: instantDateKey(symptom.occurredAt),
        sortTime: symptom.occurredAt,
        title: symptom.name,
        searchText: '${symptom.name} ${symptom.intensity} ${symptom.notes}',
        value: symptom,
      ),
  ];
  final normalized = normalizeSearch(query);
  return records.where((record) {
    if (area != 'all' && record.area != area) return false;
    if (from != null && record.date.compareTo(from) < 0) return false;
    if (to != null && record.date.compareTo(to) > 0) return false;
    return normalized.isEmpty ||
        normalizeSearch(record.searchText).contains(normalized);
  }).toList()..sort((a, b) {
    final byTime = b.sortTime.compareTo(a.sortTime);
    return byTime != 0 ? byTime : b.id.compareTo(a.id);
  });
}
