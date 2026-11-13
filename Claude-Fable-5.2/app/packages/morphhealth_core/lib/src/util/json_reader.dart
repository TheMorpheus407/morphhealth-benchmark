import 'dates.dart';

/// A problem found while reading a document, with the JSON path it refers to.
class DocumentIssue {
  /// For example `intake[3].food_id`.
  final String path;
  final String message;

  const DocumentIssue(this.path, this.message);

  Map<String, dynamic> toJson() => {'path': path, 'message': message};

  @override
  String toString() => path.isEmpty ? message : '$path: $message';
}

/// Collects errors (which reject a document) and warnings (which do not).
class IssueLog {
  /// Upper bound for stored issues; further ones are only counted.
  final int limit;

  final List<DocumentIssue> errors = [];
  final List<DocumentIssue> warnings = [];
  int errorCount = 0;
  int warningCount = 0;

  IssueLog({this.limit = 100});

  bool get hasErrors => errorCount > 0;

  void error(String path, String message) {
    errorCount++;
    if (errors.length < limit) errors.add(DocumentIssue(path, message));
  }

  void warning(String path, String message) {
    warningCount++;
    if (warnings.length < limit) warnings.add(DocumentIssue(path, message));
  }
}

/// Typed, validating access to one JSON object.
///
/// Every accessor records a readable error in [log] and returns null when the
/// value has the wrong type or range, so that one pass over a document reports
/// all problems instead of stopping at the first one.
class ObjectReader {
  final Map<String, dynamic> map;
  final String path;
  final IssueLog log;
  final Set<String> _read = {};

  ObjectReader(this.map, this.path, this.log);

  String _p(String key) => path.isEmpty ? key : '$path.$key';

  bool has(String key) => map.containsKey(key) && map[key] != null;

  dynamic raw(String key) {
    _read.add(key);
    return map[key];
  }

  String? string(
    String key, {
    bool required = false,
    int maxLength = 500,
    bool allowEmpty = false,
    bool trim = true,
  }) {
    final v = raw(key);
    if (v == null) {
      if (required) log.error(_p(key), 'is required');
      return null;
    }
    if (v is! String) {
      log.error(_p(key), 'must be a string');
      return null;
    }
    final s = trim ? v.trim() : v;
    if (s.isEmpty && !allowEmpty) {
      if (required) log.error(_p(key), 'must not be empty');
      return null;
    }
    if (s.length > maxLength) {
      log.error(_p(key), 'must have at most $maxLength characters');
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
    final v = raw(key);
    if (v == null) {
      if (required) log.error(_p(key), 'is required');
      return null;
    }
    if (v is! num) {
      log.error(_p(key), 'must be a number');
      return null;
    }
    final d = v.toDouble();
    if (d.isNaN || d.isInfinite) {
      log.error(_p(key), 'must be a finite number');
      return null;
    }
    if (min != null && (exclusiveMin ? d <= min : d < min)) {
      log.error(
        _p(key),
        exclusiveMin
            ? 'must be greater than ${_fmt(min)}'
            : 'must be at least ${_fmt(min)}',
      );
      return null;
    }
    if (max != null && d > max) {
      log.error(_p(key), 'must be at most ${_fmt(max)}');
      return null;
    }
    return d;
  }

  int? integer(String key, {bool required = false, int? min, int? max}) {
    final v = raw(key);
    if (v == null) {
      if (required) log.error(_p(key), 'is required');
      return null;
    }
    if (v is! num || v != v.roundToDouble()) {
      log.error(_p(key), 'must be an integer');
      return null;
    }
    final i = v.toInt();
    if (min != null && i < min) {
      log.error(_p(key), 'must be at least $min');
      return null;
    }
    if (max != null && i > max) {
      log.error(_p(key), 'must be at most $max');
      return null;
    }
    return i;
  }

  bool? boolean(String key, {bool required = false}) {
    final v = raw(key);
    if (v == null) {
      if (required) log.error(_p(key), 'is required');
      return null;
    }
    if (v is! bool) {
      log.error(_p(key), 'must be true or false');
      return null;
    }
    return v;
  }

  /// One of [values]; reports the allowed values otherwise.
  String? choice(String key, Iterable<String> values, {bool required = false}) {
    final v = raw(key);
    if (v == null) {
      if (required) log.error(_p(key), 'is required');
      return null;
    }
    if (v is! String || !values.contains(v)) {
      log.error(_p(key), 'must be one of: ${values.join(', ')}');
      return null;
    }
    return v;
  }

  Day? day(String key, {bool required = false}) {
    final v = raw(key);
    if (v == null) {
      if (required) log.error(_p(key), 'is required');
      return null;
    }
    final d = v is String ? Day.tryParse(v) : null;
    if (d == null) {
      log.error(_p(key), 'must be a date as YYYY-MM-DD');
      return null;
    }
    return d;
  }

  LocalDateTime? dateTime(String key, {bool required = false}) {
    final v = raw(key);
    if (v == null) {
      if (required) log.error(_p(key), 'is required');
      return null;
    }
    final p = v is String ? LocalDateTime.tryParseDetailed(v) : null;
    if (p == null) {
      log.error(
        _p(key),
        'must be a local date-time such as 2026-11-09T07:45:00',
      );
      return null;
    }
    if (p.dateOnly) {
      log.warning(_p(key), 'has no time of day; 12:00 is used');
    }
    return p.value;
  }

  List<dynamic>? list(String key, {bool required = false}) {
    final v = raw(key);
    if (v == null) {
      if (required) log.error(_p(key), 'is required');
      return null;
    }
    if (v is! List) {
      log.error(_p(key), 'must be an array');
      return null;
    }
    return v;
  }

  ObjectReader? object(String key, {bool required = false}) {
    final v = raw(key);
    if (v == null) {
      if (required) log.error(_p(key), 'is required');
      return null;
    }
    if (v is! Map) {
      log.error(_p(key), 'must be an object');
      return null;
    }
    return ObjectReader(v.cast<String, dynamic>(), _p(key), log);
  }

  /// Warns about members that no accessor asked for.
  void warnUnknown() {
    for (final k in map.keys) {
      if (!_read.contains(k)) {
        log.warning(_p(k), 'unknown field was ignored');
      }
    }
  }
}

String _fmt(double v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toString();

/// Rounds to six decimal places and removes binary noise such as
/// 12.300000000000001. Integral results stay integral in JSON.
num roundForJson(double v) {
  if (v.isNaN || v.isInfinite) return 0;
  final r = (v * 1e6).roundToDouble() / 1e6;
  if (r == r.truncateToDouble() && r.abs() < 9e15) return r.toInt();
  return r;
}
