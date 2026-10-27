import 'dart:math';

final _random = Random.secure();

String newId() => List.generate(
  16,
  (_) => _random.nextInt(256),
).map((value) => value.toRadixString(16).padLeft(2, '0')).join();

String dateKey(DateTime value) =>
    '${value.year.toString().padLeft(4, '0')}-'
    '${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

String instantDateKey(DateTime value) => dateKey(value.toLocal());

DateTime parseDate(String value, [String path = 'date']) {
  if (!RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) {
    throw FormatException('$path must be YYYY-MM-DD');
  }
  final parsed = DateTime.tryParse(value);
  if (parsed == null || dateKey(parsed) != value) {
    throw FormatException('$path is not a valid calendar date');
  }
  return parsed;
}

DateTime addDays(DateTime value, int days) =>
    DateTime(value.year, value.month, value.day + days);

String formatInstant(DateTime value) => value.toUtc().toIso8601String();

DateTime parseInstant(Object? value, String path) {
  if (value is! String) throw FormatException('$path must be RFC3339 text');
  final parsed = DateTime.tryParse(value);
  if (parsed == null || !RegExp(r'(?:Z|[+-]\d{2}:\d{2})$').hasMatch(value)) {
    throw FormatException('$path must include a timezone');
  }
  return parsed.toUtc();
}

Map<String, dynamic> jsonMap(Object? value, String path) {
  if (value is! Map) throw FormatException('$path must be an object');
  return value.map((key, value) {
    if (key is! String) throw FormatException('$path has a non-text key');
    return MapEntry(key, value);
  });
}

List<dynamic> jsonList(Object? value, String path) {
  if (value is! List) throw FormatException('$path must be an array');
  return value;
}

String jsonString(Object? value, String path, {bool allowEmpty = false}) {
  if (value is! String || (!allowEmpty && value.trim().isEmpty)) {
    throw FormatException(
      '$path must be ${allowEmpty ? 'text' : 'non-empty text'}',
    );
  }
  return value;
}

String? jsonOptionalString(Object? value, String path) {
  if (value == null) return null;
  return jsonString(value, path, allowEmpty: true);
}

double jsonDouble(Object? value, String path, {double? min, double? max}) {
  if (value is! num || !value.isFinite) {
    throw FormatException('$path must be a finite number');
  }
  final result = value.toDouble();
  if ((min != null && result < min) || (max != null && result > max)) {
    throw FormatException('$path is outside its allowed range');
  }
  return result;
}

double? jsonOptionalDouble(Object? value, String path, {double? min}) {
  if (value == null) return null;
  return jsonDouble(value, path, min: min);
}

int jsonInt(Object? value, String path, {int? min, int? max}) {
  if (value is! int ||
      (min != null && value < min) ||
      (max != null && value > max)) {
    throw FormatException('$path is not an allowed integer');
  }
  return value;
}

bool jsonBool(Object? value, String path) {
  if (value is! bool) throw FormatException('$path must be boolean');
  return value;
}

Map<String, double> jsonNumberMap(Object? value, String path) {
  final map = jsonMap(value, path);
  return map.map(
    (key, value) => MapEntry(key, jsonDouble(value, '$path.$key', min: 0)),
  );
}

String normalizeSearch(String value) => value
    .toLowerCase()
    .replaceAll('ä', 'ae')
    .replaceAll('ö', 'oe')
    .replaceAll('ü', 'ue')
    .replaceAll('ß', 'ss')
    .trim();
