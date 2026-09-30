import '../util/clock.dart';
import '../util/ids.dart';
import '../util/json_reader.dart';
import '../util/local_date.dart';
import 'entries.dart';
import 'enums.dart';
import 'food.dart';

/// A menstrual period with a start day and (once finished) an end day.
class Period implements Record {
  Period({
    required this.id,
    required this.start,
    this.end,
    this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Period.create({
    required LocalDate start,
    LocalDate? end,
    String? note,
    required DateTime now,
  }) => Period(
    id: newId(),
    start: start,
    end: end,
    note: note,
    createdAt: now,
    updatedAt: now,
  );

  @override
  final String id;
  final LocalDate start;

  /// Last day of the period (inclusive); null while the period is ongoing.
  final LocalDate? end;
  final String? note;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;

  /// Longest accepted length of a finished period in days.
  static const int maxLengthDays = 60;

  bool get isOngoing => end == null;

  /// Length in days (inclusive) for a finished period.
  int? get lengthDays => end == null ? null : start.daysUntil(end!) + 1;

  /// Whether [day] lies in this period. Ongoing periods extend to [today].
  bool contains(LocalDate day, {required LocalDate today}) {
    if (day.isBefore(start)) return false;
    final last = end ?? (today.isBefore(start) ? start : today);
    return day.isAtOrBefore(last);
  }

  /// Last covered day; for an ongoing period this is [today] (at least start).
  LocalDate effectiveEnd(LocalDate today) =>
      end ?? (today.isBefore(start) ? start : today);

  Period copyWith({
    LocalDate? start,
    LocalDate? Function()? end,
    String? Function()? note,
    required DateTime updatedAt,
  }) => Period(
    id: id,
    start: start ?? this.start,
    end: end != null ? end() : this.end,
    note: note != null ? note() : this.note,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );

  @override
  Map<String, Object?> toJson() => {
    'id': id,
    'start': start.toIso(),
    'end': end?.toIso(),
    'note': note,
    'created_at': formatInstant(createdAt),
    'updated_at': formatInstant(updatedAt),
  };

  static Period? fromJson(
    Object? json,
    String path,
    Issues issues,
    DateTime now,
  ) {
    final r = JsonReader.of(json, path, issues);
    if (r == null) return null;
    final before = issues.errors.length;
    r.warnUnknownKeys({'id', 'start', 'end', 'note', 'created_at', 'updated_at'});
    final id = readId(r);
    final start = r.date('start', required: true);
    final end = r.date('end');
    final note = r.string('note', maxLength: 2000);
    final created = r.instant('created_at') ?? now;
    final updated = r.instant('updated_at') ?? created;
    if (start != null && end != null) {
      if (end.isBefore(start)) {
        issues.error('$path.end', 'must not be before start');
      } else if (start.daysUntil(end) + 1 > maxLengthDays) {
        issues.error('$path.end', 'a period may last at most $maxLengthDays days');
      }
    }
    if (issues.errors.length != before) return null;
    return Period(
      id: id,
      start: start!,
      end: end,
      note: note,
      createdAt: created,
      updatedAt: updated,
    );
  }
}

/// Per-day cycle log: bleeding intensity (including spotting) and/or a note.
/// At most one record exists per date.
class CycleDay implements DatedRecord {
  CycleDay({
    required this.id,
    required this.date,
    this.flow,
    this.note,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CycleDay.create({
    required LocalDate date,
    Flow? flow,
    String? note,
    required DateTime now,
  }) => CycleDay(
    id: newId(),
    date: date,
    flow: flow,
    note: note,
    createdAt: now,
    updatedAt: now,
  );

  @override
  final String id;
  @override
  final LocalDate date;
  final Flow? flow;
  final String? note;
  @override
  final DateTime createdAt;
  @override
  final DateTime updatedAt;

  @override
  int? get time => null;

  bool get isEmpty => flow == null && (note == null || note!.isEmpty);

  CycleDay copyWith({
    Flow? Function()? flow,
    String? Function()? note,
    required DateTime updatedAt,
  }) => CycleDay(
    id: id,
    date: date,
    flow: flow != null ? flow() : this.flow,
    note: note != null ? note() : this.note,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );

  @override
  Map<String, Object?> toJson() => {
    'id': id,
    'date': date.toIso(),
    'flow': flow?.json,
    'note': note,
    'created_at': formatInstant(createdAt),
    'updated_at': formatInstant(updatedAt),
  };

  static CycleDay? fromJson(
    Object? json,
    String path,
    Issues issues,
    DateTime now,
  ) {
    final r = JsonReader.of(json, path, issues);
    if (r == null) return null;
    final before = issues.errors.length;
    r.warnUnknownKeys({'id', 'date', 'flow', 'note', 'created_at', 'updated_at'});
    final id = readId(r);
    final date = r.date('date', required: true);
    final flow = r.enumValue('flow', Flow.byJson);
    final note = r.string('note', maxLength: 2000);
    final created = r.instant('created_at') ?? now;
    final updated = r.instant('updated_at') ?? created;
    if (flow == null && note == null && issues.errors.length == before) {
      issues.error(path, 'needs a flow or a note');
    }
    if (issues.errors.length != before) return null;
    return CycleDay(
      id: id,
      date: date!,
      flow: flow,
      note: note,
      createdAt: created,
      updatedAt: updated,
    );
  }
}
