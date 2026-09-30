import 'clock.dart';
import 'local_date.dart';

/// A single problem found while reading a JSON document, with a JSON path
/// such as `food_entries[3].amount`.
class Issue {
  const Issue(this.path, this.message);

  final String path;
  final String message;

  Map<String, Object?> toJson() => {'path': path, 'message': message};

  @override
  String toString() => path.isEmpty ? message : '$path: $message';
}

/// Collects validation errors and warnings.
class Issues {
  final List<Issue> errors = [];
  final List<Issue> warnings = [];

  bool get hasErrors => errors.isNotEmpty;

  void error(String path, String message) => errors.add(Issue(path, message));
  void warn(String path, String message) => warnings.add(Issue(path, message));
}

/// Thrown when a document or record does not satisfy the data format.
class ValidationException implements Exception {
  ValidationException(this.errors, [this.warnings = const []]);

  final List<Issue> errors;
  final List<Issue> warnings;

  @override
  String toString() {
    final shown = errors.take(10).join('; ');
    final more = errors.length > 10 ? ' (+${errors.length - 10} more)' : '';
    return 'Validation failed: $shown$more';
  }
}

/// Typed, path-aware access to a JSON object that records problems instead of
/// throwing, so that a whole document can be validated in one pass.
class JsonReader {
  JsonReader(this.map, this.path, this.issues);

  /// Returns a reader for [value] or records an error if it is not an object.
  static JsonReader? of(Object? value, String path, Issues issues) {
    if (value is Map<String, Object?>) return JsonReader(value, path, issues);
    if (value is Map) {
      return JsonReader(
        value.map((k, v) => MapEntry(k.toString(), v)),
        path,
        issues,
      );
    }
    issues.error(path, 'expected an object');
    return null;
  }

  final Map<String, Object?> map;
  final String path;
  final Issues issues;

  String _p(String key) => path.isEmpty ? key : '$path.$key';

  bool has(String key) => map.containsKey(key) && map[key] != null;

  void _missing(String key) => issues.error(_p(key), 'is required');

  String? string(
    String key, {
    bool required = false,
    int maxLength = 200,
    bool trim = true,
  }) {
    final v = map[key];
    if (v == null) {
      if (required) _missing(key);
      return null;
    }
    if (v is! String) {
      issues.error(_p(key), 'expected a string');
      return null;
    }
    final s = trim ? v.trim() : v;
    if (s.isEmpty) {
      if (required) issues.error(_p(key), 'must not be empty');
      return null;
    }
    if (s.length > maxLength) {
      issues.error(_p(key), 'is longer than $maxLength characters');
      return null;
    }
    return s;
  }

  double? number(
    String key, {
    bool required = false,
    double? min,
    double? max,
    bool exclusiveMin = false,
  }) {
    final v = map[key];
    if (v == null) {
      if (required) _missing(key);
      return null;
    }
    if (v is! num) {
      issues.error(_p(key), 'expected a number');
      return null;
    }
    final d = v.toDouble();
    if (d.isNaN || d.isInfinite) {
      issues.error(_p(key), 'must be a finite number');
      return null;
    }
    if (min != null && (exclusiveMin ? d <= min : d < min)) {
      issues.error(
        _p(key),
        exclusiveMin ? 'must be greater than $min' : 'must be at least $min',
      );
      return null;
    }
    if (max != null && d > max) {
      issues.error(_p(key), 'must be at most $max');
      return null;
    }
    return d;
  }

  int? integer(String key, {bool required = false, int? min, int? max}) {
    final v = map[key];
    if (v == null) {
      if (required) _missing(key);
      return null;
    }
    if (v is! num || v != v.roundToDouble()) {
      issues.error(_p(key), 'expected an integer');
      return null;
    }
    final i = v.toInt();
    if (min != null && i < min) {
      issues.error(_p(key), 'must be at least $min');
      return null;
    }
    if (max != null && i > max) {
      issues.error(_p(key), 'must be at most $max');
      return null;
    }
    return i;
  }

  bool? boolean(String key, {bool required = false}) {
    final v = map[key];
    if (v == null) {
      if (required) _missing(key);
      return null;
    }
    if (v is! bool) {
      issues.error(_p(key), 'expected true or false');
      return null;
    }
    return v;
  }

  LocalDate? date(String key, {bool required = false}) {
    final s = string(key, required: required, maxLength: 10);
    if (s == null) return null;
    final d = LocalDate.tryParse(s);
    if (d == null) {
      issues.error(_p(key), 'expected a date YYYY-MM-DD');
      return null;
    }
    if (!d.isInSupportedRange) {
      issues.error(_p(key), 'date must be between 1900-01-01 and 2100-12-31');
      return null;
    }
    return d;
  }

  /// Time of day `HH:mm` in minutes since midnight.
  int? time(String key, {bool required = false}) {
    final s = string(key, required: required, maxLength: 5);
    if (s == null) return null;
    final t = TimeOfDayMinutes.tryParse(s);
    if (t == null) {
      issues.error(_p(key), 'expected a time HH:mm');
      return null;
    }
    return t;
  }

  DateTime? instant(String key, {bool required = false}) {
    final v = map[key];
    if (v == null) {
      if (required) _missing(key);
      return null;
    }
    final parsed = tryParseInstant(v);
    if (parsed == null) {
      issues.error(_p(key), 'expected an RFC 3339 timestamp with time zone');
    }
    return parsed;
  }

  T? enumValue<T>(String key, Map<String, T> values, {bool required = false}) {
    final v = map[key];
    if (v == null) {
      if (required) _missing(key);
      return null;
    }
    if (v is! String || !values.containsKey(v)) {
      issues.error(_p(key), 'expected one of ${values.keys.join(', ')}');
      return null;
    }
    return values[v];
  }

  List<Object?>? list(String key, {bool required = false}) {
    final v = map[key];
    if (v == null) {
      if (required) _missing(key);
      return null;
    }
    if (v is! List) {
      issues.error(_p(key), 'expected an array');
      return null;
    }
    return v.cast<Object?>();
  }

  JsonReader? object(String key, {bool required = false}) {
    final v = map[key];
    if (v == null) {
      if (required) _missing(key);
      return null;
    }
    return JsonReader.of(v, _p(key), issues);
  }

  /// Records a warning for every key that is not part of the format.
  void warnUnknownKeys(Set<String> known) {
    for (final key in map.keys) {
      if (!known.contains(key)) {
        issues.warn(_p(key), 'unknown field ignored');
      }
    }
  }
}
