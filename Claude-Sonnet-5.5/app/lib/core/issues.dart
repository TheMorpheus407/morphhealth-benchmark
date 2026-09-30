import 'package:characters/characters.dart';

import 'civil.dart';

/// Ein Fund beim Prüfen eines Dokuments: Pfad im Dokument plus Klartext.
final class Issue {
  final String path;
  final String message;

  const Issue(this.path, this.message);

  Map<String, Object?> toJson() => {'path': path, 'message': message};

  @override
  String toString() => '$path: $message';
}

/// Sammelt Fehler und Warnungen, statt beim ersten Fehler abzubrechen.
final class Issues {
  static const int maxKept = 200;

  final List<Issue> errors = [];
  final List<Issue> warnings = [];
  int droppedErrors = 0;
  int droppedWarnings = 0;

  void error(String path, String message) {
    if (errors.length < maxKept) {
      errors.add(Issue(path, message));
    } else {
      droppedErrors++;
    }
  }

  void warn(String path, String message) {
    if (warnings.length < maxKept) {
      warnings.add(Issue(path, message));
    } else {
      droppedWarnings++;
    }
  }

  bool get hasErrors => errors.isNotEmpty || droppedErrors > 0;
}

/// Wird geworfen, wenn ein Dokument ungültig ist.
final class ValidationException implements Exception {
  final String message;
  final List<Issue> issues;

  ValidationException(this.message, this.issues);

  @override
  String toString() =>
      'ValidationException: $message${issues.isEmpty ? '' : ' (${issues.take(3).join('; ')}${issues.length > 3 ? ' …' : ''})'}';
}

/// Lesezugriff auf ein JSON-Objekt mit Typprüfung, Wertebereichen und Pfaden
/// in Fehlermeldungen (`$.food_entries[3].amount`). Fehler werden gesammelt.
final class Obj {
  final Map<String, dynamic> map;
  final String path;
  final Issues issues;
  final Set<String> _seen = {};

  Obj(this.map, this.path, this.issues);

  static Obj? from(Object? node, String path, Issues issues, {bool required = true}) {
    if (node == null) {
      if (required) issues.error(path, 'Objekt erwartet, nichts gefunden');
      return null;
    }
    if (node is Map) {
      return Obj(node.map((k, v) => MapEntry(k.toString(), v)), path, issues);
    }
    issues.error(path, 'Objekt erwartet');
    return null;
  }

  String at(String key) => '$path.$key';

  bool has(String key) => map[key] != null;

  Object? raw(String key) {
    _seen.add(key);
    return map[key];
  }

  String? string(String key, {bool required = false, int min = 0, int max = 500, bool trim = true}) {
    _seen.add(key);
    final v = map[key];
    if (v == null) {
      if (required) issues.error(at(key), 'Pflichtfeld fehlt');
      return null;
    }
    if (v is! String) {
      issues.error(at(key), 'Text erwartet');
      return null;
    }
    final s = trim ? v.trim() : v;
    if (s.length < min || (required && s.isEmpty)) {
      issues.error(at(key), min > 1 ? 'mindestens $min Zeichen erwartet' : 'darf nicht leer sein');
      return null;
    }
    // Die Eingabefelder begrenzen in Zeichen (Graphemen); UTF-16-Einheiten zählen mehr (Emoji).
    if (s.length > max && s.characters.length > max) {
      issues.error(at(key), 'höchstens $max Zeichen erlaubt');
      return null;
    }
    return s.isEmpty ? null : s;
  }

  double? number(String key, {bool required = false, double? min, double? max, bool minExclusive = false}) {
    _seen.add(key);
    final v = map[key];
    if (v == null) {
      if (required) issues.error(at(key), 'Pflichtfeld fehlt');
      return null;
    }
    double? d;
    if (v is num) {
      d = v.toDouble();
    } else if (v is String) {
      d = double.tryParse(v.trim().replaceAll(',', '.'));
    }
    if (d == null || d.isNaN || d.isInfinite) {
      issues.error(at(key), 'Zahl erwartet');
      return null;
    }
    if (min != null && (minExclusive ? d <= min : d < min)) {
      issues.error(at(key), minExclusive ? 'muss größer als $min sein' : 'muss mindestens $min sein');
      return null;
    }
    if (max != null && d > max) {
      issues.error(at(key), 'darf höchstens $max sein');
      return null;
    }
    return d;
  }

  int? integer(String key, {bool required = false, int? min, int? max}) {
    _seen.add(key);
    final v = map[key];
    if (v == null) {
      if (required) issues.error(at(key), 'Pflichtfeld fehlt');
      return null;
    }
    int? n;
    if (v is int) {
      n = v;
    } else if (v is double && v == v.roundToDouble()) {
      n = v.toInt();
    } else if (v is String) {
      n = int.tryParse(v.trim());
    }
    if (n == null) {
      issues.error(at(key), 'ganze Zahl erwartet');
      return null;
    }
    if (min != null && n < min) {
      issues.error(at(key), 'muss mindestens $min sein');
      return null;
    }
    if (max != null && n > max) {
      issues.error(at(key), 'darf höchstens $max sein');
      return null;
    }
    return n;
  }

  bool? boolean(String key, {bool? def}) {
    _seen.add(key);
    final v = map[key];
    if (v == null) return def;
    if (v is bool) return v;
    issues.error(at(key), 'true oder false erwartet');
    return def;
  }

  Day? day(String key, {bool required = false}) {
    _seen.add(key);
    final v = map[key];
    if (v == null) {
      if (required) issues.error(at(key), 'Pflichtfeld fehlt');
      return null;
    }
    if (v is String) {
      // Auch ein voller Zeitstempel ist als Tag verwendbar.
      final direct = Day.tryParse(v);
      if (direct != null) return direct;
      final t = LocalDateTime.tryParse(v);
      if (t != null) return t.day;
    }
    issues.error(at(key), 'Datum erwartet als YYYY-MM-DD');
    return null;
  }

  LocalDateTime? dateTime(String key, {bool required = false}) {
    _seen.add(key);
    final v = map[key];
    if (v == null) {
      if (required) issues.error(at(key), 'Pflichtfeld fehlt');
      return null;
    }
    if (v is String) {
      final t = LocalDateTime.tryParse(v);
      if (t != null) return t;
    }
    issues.error(at(key), 'Zeitpunkt erwartet als YYYY-MM-DDTHH:MM[:SS]');
    return null;
  }

  T? choice<T>(String key, List<T> values, String Function(T) nameOf, {bool required = false, T? def}) {
    _seen.add(key);
    final v = map[key];
    if (v == null) {
      if (required) issues.error(at(key), 'Pflichtfeld fehlt');
      return def;
    }
    if (v is String) {
      final lower = v.trim().toLowerCase();
      for (final c in values) {
        if (nameOf(c) == lower) return c;
      }
    }
    issues.error(at(key), 'erlaubt sind: ${values.map(nameOf).join(', ')}');
    return def;
  }

  Obj? object(String key, {bool required = false}) {
    _seen.add(key);
    final v = map[key];
    if (v == null) {
      if (required) issues.error(at(key), 'Pflichtfeld fehlt');
      return null;
    }
    return Obj.from(v, at(key), issues);
  }

  /// Liste von Objekten. Elemente, die keine Objekte sind, werden als Fehler
  /// gemeldet und übersprungen.
  List<Obj>? objects(String key, {bool required = false}) {
    _seen.add(key);
    final v = map[key];
    if (v == null) {
      if (required) issues.error(at(key), 'Pflichtfeld fehlt');
      return null;
    }
    if (v is! List) {
      issues.error(at(key), 'Liste erwartet');
      return null;
    }
    final out = <Obj>[];
    for (var i = 0; i < v.length; i++) {
      final o = Obj.from(v[i], '${at(key)}[$i]', issues);
      if (o != null) out.add(o);
    }
    return out;
  }

  /// Meldet Felder, die dieser Leser nie angefasst hat, als Warnung.
  void finish() {
    for (final k in map.keys) {
      if (!_seen.contains(k)) issues.warn(at(k), 'unbekanntes Feld ignoriert');
    }
  }
}
