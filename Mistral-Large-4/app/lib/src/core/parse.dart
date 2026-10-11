/// Hilfsfunktionen für JSON-Dokumente und Datumswerte.
///
/// Datumsangaben werden überall als `YYYY-MM-DD` (lokaler Kalendertag)
/// gespeichert. Berechnungen erfolgen in UTC, damit keine
/// Zeitzonen-/DST-Verschiebungen entstehen.
library;

/// Parst `YYYY-MM-DD` als UTC-Datum. Liefert null bei ungültigem Format.
DateTime? parseDate(String? value) {
  if (value == null || value.isEmpty) return null;
  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
  if (m == null) return null;
  final y = int.parse(m.group(1)!);
  final mo = int.parse(m.group(2)!);
  final d = int.parse(m.group(3)!);
  final dt = DateTime.utc(y, mo, d);
  if (dt.year != y || dt.month != mo || dt.day != d) return null;
  return dt;
}

/// Formatiert ein Datum als `YYYY-MM-DD`.
///
/// Es werden die Felder des übergebenen Werts verwendet (kein Zeitzonen-
/// shift): Kanonische Daten sind `DateTime.utc(y, m, d)`, lokale Eingaben
/// (z. B. aus Date-Pickern) behalten ihre lokalen Felder.
String formatDate(DateTime dt) {
  return '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}

/// Parst `HH:MM` (24h). Liefert null bei ungültigem Format.
DateTime? parseTimeOfDay(String? value) {
  if (value == null || value.isEmpty) return null;
  final m = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(value);
  if (m == null) return null;
  final h = int.parse(m.group(1)!);
  final mi = int.parse(m.group(2)!);
  if (h > 23 || mi > 59) return null;
  return DateTime.utc(2000, 1, 1, h, mi);
}

/// Formatiert eine Uhrzeit als `HH:MM` (lokale Felder des Werts).
String formatTimeOfDay(DateTime dt) {
  return '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
}

/// Heute als `YYYY-MM-DD` (lokal).
String todayString([DateTime? now]) {
  final n = now ?? DateTime.now();
  return formatDate(DateTime.utc(n.year, n.month, n.day));
}

/// Anzahl Tage zwischen zwei `YYYY-MM-DD`-Angaben (b - a).
int dateDiffDays(String a, String b) {
  final da = parseDate(a);
  final db = parseDate(b);
  if (da == null || db == null) {
    throw ArgumentError('Ungültiges Datum: $a / $b');
  }
  return db.difference(da).inDays;
}

String? getString(Map<String, dynamic>? map, String key) {
  final v = map?[key];
  if (v is String) return v;
  if (v is num) return v.toString();
  return null;
}

double? getDouble(Map<String, dynamic>? map, String key) {
  final v = map?[key];
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v.replaceAll(',', '.'));
  return null;
}

int? getInt(Map<String, dynamic>? map, String key) {
  final v = map?[key];
  if (v is int) return v;
  if (v is num) return v.toInt();
  if (v is String) return int.tryParse(v);
  return null;
}

bool? getBool(Map<String, dynamic>? map, String key) {
  final v = map?[key];
  if (v is bool) return v;
  return null;
}

List<dynamic>? getList(Map<String, dynamic>? map, String key) {
  final v = map?[key];
  if (v is List) return v;
  return null;
}

Map<String, dynamic>? getMap(Map<String, dynamic>? map, String key) {
  final v = map?[key];
  if (v is Map<String, dynamic>) return v;
  if (v is Map) return v.cast<String, dynamic>();
  return null;
}
