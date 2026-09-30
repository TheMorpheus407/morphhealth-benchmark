import 'package:flutter/services.dart';

/// Ein über die System-Dokumentenauswahl gewähltes Dokument.
final class PickedDocument {
  final String name;
  final Uint8List bytes;

  const PickedDocument(this.name, this.bytes);
}

/// Fehler der Android-Brücke (Auswahl abgebrochen ist kein Fehler).
final class PlatformFailure implements Exception {
  final String code;
  final String message;

  const PlatformFailure(this.code, this.message);

  @override
  String toString() => 'PlatformFailure($code): $message';
}

/// Dünne Hülle um den MethodChannel zur Android-Seite (MainActivity.kt).
class PlatformBridge {
  static const MethodChannel _ch = MethodChannel('de.themorpheus.morphhealth/platform');

  Future<T?> _call<T>(String method, [Object? args]) async {
    try {
      return await _ch.invokeMethod<T>(method, args);
    } on PlatformException catch (e) {
      throw PlatformFailure(e.code, e.message ?? e.code);
    }
  }

  /// Privater Dateiordner der App.
  Future<String> filesDir() async => (await _call<String>('filesDir'))!;

  /// Umhüllt [plain] mit dem nicht exportierbaren Keystore-Schlüssel.
  Future<Uint8List> keyWrap(Uint8List plain) async => (await _call<Uint8List>('keyWrap', plain))!;

  Future<Uint8List> keyUnwrap(Uint8List blob) async => (await _call<Uint8List>('keyUnwrap', blob))!;

  Future<void> keyDelete() => _call<void>('keyDelete');

  /// Sperrt Bildschirmaufnahmen und die Vorschau in der App-Übersicht.
  Future<void> setSecure(bool on) => _call<void>('setSecure', on);

  /// Öffnet "Speichern unter" des Systems. Liefert den Dateinamen oder null,
  /// wenn abgebrochen wurde.
  Future<String?> saveDocument({required String name, required String mime, required Uint8List bytes}) =>
      _call<String>('saveDocument', {'name': name, 'mime': mime, 'bytes': bytes});

  /// Öffnet die System-Dateiauswahl. Null bei Abbruch.
  Future<PickedDocument?> openDocument() async {
    final r = await _call<Map<Object?, Object?>>('openDocument');
    if (r == null) return null;
    return PickedDocument(r['name'] as String? ?? '', r['bytes'] as Uint8List);
  }
}
