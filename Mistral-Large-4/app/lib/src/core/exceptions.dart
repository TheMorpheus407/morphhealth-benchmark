/// Fachliche Fehler mit stabilem Code (für UI und JSON-Lines-CLI).
class MorphException implements Exception {
  final String code;
  final String message;
  MorphException(this.code, this.message);
  @override
  String toString() => 'MorphException($code): $message';
}
