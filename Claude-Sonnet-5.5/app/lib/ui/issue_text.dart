/// Übersetzt die Meldungen der Dokumentprüfung für die englische Oberfläche. Der Kern liefert
/// sie als deutschen Klartext (Protokoll des Wartungszugangs); die App zeigt sie in ihrer Sprache.
String issueMessage(String lang, String message) {
  if (lang != 'en') return message;
  for (final (pattern, build) in _rules) {
    final m = pattern.firstMatch(message);
    if (m != null) return build(m);
  }
  return message;
}

final List<(RegExp, String Function(RegExpMatch))> _rules = [
  (
    RegExp(r'^Pflichtfeld fehlt \(oder food_id verweist auf kein Lebensmittel\)$'),
    (_) => 'required field missing (or food_id does not refer to a food)',
  ),
  (RegExp(r'^Pflichtfeld fehlt$'), (_) => 'required field missing'),
  (RegExp(r'^Portion setzt food\.serving voraus$'), (_) => 'unit portion requires food.serving'),
  (RegExp(r'^Schlüssel muss ein Datum YYYY-MM-DD sein$'), (_) => 'key must be a date YYYY-MM-DD'),
  (RegExp(r'^Ende liegt vor dem Beginn$'), (_) => 'the end is before the start'),
  (RegExp(r'^Eine Periode darf höchstens (\d+) Tage umfassen$'), (m) => 'a period can span at most ${m[1]} days'),
  (RegExp(r'^Tag (\S+) liegt außerhalb der Periode$'), (m) => 'day ${m[1]} lies outside the period'),
  (RegExp(r'^fehlt, erwartet (".*")$'), (m) => 'missing, expected ${m[1]}'),
  (RegExp(r'^erwartet (".*"), gefunden (".*")$'), (m) => 'expected ${m[1]}, found ${m[2]}'),
  (
    RegExp(r'^Version (\S+) ist neuer als diese App versteht \((\S+)\)$'),
    (m) => 'version ${m[1]} is newer than this app understands (${m[2]})',
  ),
  (RegExp(r'^ID (".*") kommt in (\S+) mehrfach vor$'), (m) => 'ID ${m[1]} occurs more than once in ${m[2]}'),
  (
    RegExp(r'^Perioden ab (\S+) und ab (\S+) überschneiden sich$'),
    (m) => 'periods from ${m[1]} and from ${m[2]} overlap',
  ),
  (RegExp(r'^Objekt erwartet, nichts gefunden$'), (_) => 'object expected, nothing found'),
  (RegExp(r'^Objekt erwartet$'), (_) => 'object expected'),
  (RegExp(r'^Text erwartet$'), (_) => 'text expected'),
  (RegExp(r'^mindestens (\d+) Zeichen erwartet$'), (m) => 'at least ${m[1]} characters expected'),
  (RegExp(r'^darf nicht leer sein$'), (_) => 'must not be empty'),
  (RegExp(r'^höchstens (\d+) Zeichen erlaubt$'), (m) => 'at most ${m[1]} characters allowed'),
  (RegExp(r'^Zahl erwartet$'), (_) => 'number expected'),
  (RegExp(r'^muss größer als (\S+) sein$'), (m) => 'must be greater than ${m[1]}'),
  (RegExp(r'^muss mindestens (\S+) sein$'), (m) => 'must be at least ${m[1]}'),
  (RegExp(r'^darf höchstens (\S+) sein$'), (m) => 'must be at most ${m[1]}'),
  (RegExp(r'^ganze Zahl erwartet$'), (_) => 'integer expected'),
  (RegExp(r'^true oder false erwartet$'), (_) => 'true or false expected'),
  (RegExp(r'^Datum erwartet als YYYY-MM-DD$'), (_) => 'date expected as YYYY-MM-DD'),
  (RegExp(r'^Zeitpunkt erwartet als (\S+)$'), (m) => 'timestamp expected as ${m[1]}'),
  (RegExp(r'^erlaubt sind: (.*)$'), (m) => 'allowed values: ${m[1]}'),
  (RegExp(r'^Liste erwartet$'), (_) => 'list expected'),
  (RegExp(r'^unbekanntes Feld ignoriert$'), (_) => 'unknown field ignored'),
];
