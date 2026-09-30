import '../util/local_date.dart';

/// Common shape of all stored records.
abstract class Record {
  String get id;
  DateTime get createdAt;
  DateTime get updatedAt;
  Map<String, Object?> toJson();
}

/// A record that belongs to a calendar day, optionally at a wall-clock time.
abstract class DatedRecord implements Record {
  LocalDate get date;

  /// Minutes since midnight, or null if no time was recorded.
  int? get time;
}

/// Orders dated records by date, then time (records without time first),
/// then creation instant.
int compareDated(DatedRecord a, DatedRecord b) {
  final byDate = a.date.compareTo(b.date);
  if (byDate != 0) return byDate;
  final at = a.time ?? -1;
  final bt = b.time ?? -1;
  if (at != bt) return at.compareTo(bt);
  return a.createdAt.compareTo(b.createdAt);
}
