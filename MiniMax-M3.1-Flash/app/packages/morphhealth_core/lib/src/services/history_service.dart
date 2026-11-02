import '../models/journal.dart';
import '../models/records.dart';
import '../store/record_store.dart';
import '../store/repository.dart';

/// One entry of the cross area history.
class HistoryItem {
  const HistoryItem({
    required this.area,
    required this.kind,
    required this.id,
    required this.date,
    required this.timestampMs,
    required this.title,
    this.subtitle,
    this.amount,
    this.unit,
  });

  /// Area the entry belongs to: `nutrition`, `cycle`, `weight` or `symptoms`.
  final String area;

  /// Concrete kind, e.g. `journal`, `water`, `caffeine`, `period`, `weight`.
  final String kind;

  final String id;
  final String date;
  final int timestampMs;
  final String title;
  final String? subtitle;
  final double? amount;
  final String? unit;

  /// Identifies the record inside the repository.
  RecordKind get recordKind {
    switch (kind) {
      case 'journal':
        return RecordKind.journalEntry;
      case 'water':
      case 'caffeine':
        return RecordKind.intake;
      case 'period':
        return RecordKind.period;
      case 'weight':
        return RecordKind.weight;
      case 'symptom':
        return RecordKind.symptom;
      default:
        return RecordKind.journalEntry;
    }
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'area': area,
        'kind': kind,
        'id': id,
        'date': date,
        'timestamp_ms': timestampMs,
        'title': title,
        if (subtitle != null) 'subtitle': subtitle,
        if (amount != null) 'amount': amount,
        if (unit != null) 'unit': unit,
      };
}

/// Search across the four product areas.
class HistoryService {
  HistoryService(this._repository);

  final HealthRepository _repository;

  /// Queries the history.
  ///
  /// [from] and [to] limit the calendar days, [areas] limits the product
  /// areas and [text] is matched case insensitively against the name, the
  /// note and the kind of an entry.
  List<HistoryItem> query({
    String? from,
    String? to,
    Set<AppArea>? areas,
    String? text,
  }) {
    final String needle = (text ?? '').trim().toLowerCase();
    final Set<AppArea>? filterAreas =
        areas == null || areas.isEmpty ? null : areas;
    final List<HistoryItem> items = <HistoryItem>[];

    bool accepts(String date, String area, String haystack) {
      if (from != null && DateMath.before(date, from)) return false;
      if (to != null && DateMath.after(date, to)) return false;
      if (filterAreas != null &&
          !filterAreas.contains(AppArea.parse(area))) {
        return false;
      }
      if (needle.isEmpty) return true;
      return haystack.toLowerCase().contains(needle);
    }

    for (final JournalEntry entry in _repository.journalEntries) {
      final String haystack =
          '${entry.foodName} ${entry.brand ?? ''} ${entry.note ?? ''} ${entry.meal.name}';
      if (accepts(entry.date, AppArea.nutrition.name, haystack)) {
        items.add(HistoryItem(
          area: AppArea.nutrition.name,
          kind: 'journal',
          id: entry.id,
          date: entry.date,
          timestampMs: entry.loggedAtMs,
          title: entry.foodName,
          subtitle: entry.note,
          amount: entry.quantity,
          unit: entry.unit.name,
        ));
      }
    }

    for (final IntakeEntry entry in _repository.intakeEntries) {
      final String kind = entry.kind == IntakeKind.water ? 'water' : 'caffeine';
      final String haystack = '${entry.note ?? ''} $kind';
      if (accepts(entry.date, AppArea.nutrition.name, haystack)) {
        items.add(HistoryItem(
          area: AppArea.nutrition.name,
          kind: kind,
          id: entry.id,
          date: entry.date,
          timestampMs: entry.loggedAtMs,
          title: kind == 'water' ? 'Wasser' : 'Koffein',
          subtitle: entry.note,
          amount: entry.amount,
          unit: kind == 'water' ? 'ml' : 'mg',
        ));
      }
    }

    for (final PeriodRecord record in _repository.periods) {
      final String haystack = '${record.note ?? ''} ${record.flow.name}';
      if (accepts(record.startDate, AppArea.cycle.name, haystack)) {
        items.add(HistoryItem(
          area: AppArea.cycle.name,
          kind: 'period',
          id: record.id,
          date: record.startDate,
          timestampMs: record.createdAtMs,
          title: record.spotting ? 'Spotting' : 'Periode',
          subtitle: record.note,
        ));
      }
    }

    for (final WeightEntry entry in _repository.weightEntries) {
      final String haystack = '${entry.note ?? ''} weight';
      if (accepts(entry.date, AppArea.weight.name, haystack)) {
        items.add(HistoryItem(
          area: AppArea.weight.name,
          kind: 'weight',
          id: entry.id,
          date: entry.date,
          timestampMs: entry.loggedAtMs,
          title: '${entry.valueKg.toStringAsFixed(1)} kg',
          subtitle: entry.note,
          amount: entry.valueKg,
          unit: 'kg',
        ));
      }
    }

    for (final SymptomEntry entry in _repository.symptomEntries) {
      final String haystack = '${entry.name} ${entry.note ?? ''} symptom';
      if (accepts(entry.date, AppArea.symptoms.name, haystack)) {
        items.add(HistoryItem(
          area: AppArea.symptoms.name,
          kind: 'symptom',
          id: entry.id,
          date: entry.date,
          timestampMs: entry.occurredAtMs,
          title: entry.name,
          subtitle: entry.note,
          amount: entry.intensity.toDouble(),
          unit: 'intensity',
        ));
      }
    }

    items.sort((HistoryItem a, HistoryItem b) {
      final int byTime = b.timestampMs.compareTo(a.timestampMs);
      if (byTime != 0) return byTime;
      return a.date.compareTo(b.date);
    });
    return items;
  }
}
