import 'dart:io';
import 'dart:typed_data';

import '../core/ids.dart';
import 'platform_bridge.dart';

/// Hauptschlüssel der lokalen Datenbank auf dem Gerät. Die 32 Byte entstehen
/// zufällig und liegen nur umhüllt (AES-256-GCM mit einem nicht exportierbaren
/// Android-Keystore-Schlüssel) im privaten Dateiordner, getrennt vom
/// Datenverzeichnis.
class DeviceKeys {
  final PlatformBridge platform;
  final Directory dir;

  DeviceKeys(this.platform, this.dir);

  File get _file => File('${dir.path}/master.wrapped');

  /// Der vorhandene Schlüssel oder ein neuer, wenn noch keiner existiert.
  Future<Uint8List> loadOrCreate() async {
    if (await _file.exists()) {
      final blob = await _file.readAsBytes();
      return platform.keyUnwrap(blob);
    }
    return _create();
  }

  Future<Uint8List> _create() async {
    final key = Uint8List.fromList(randomBytes(32));
    final blob = await platform.keyWrap(key);
    await dir.create(recursive: true);
    final tmp = File('${_file.path}.tmp');
    await tmp.writeAsBytes(blob, flush: true);
    await tmp.rename(_file.path);
    return key;
  }

  /// Verwirft den alten Schlüssel und erzeugt einen neuen (nach "Alles löschen").
  Future<Uint8List> rotate() async {
    if (await _file.exists()) await _file.delete();
    await platform.keyDelete();
    return _create();
  }
}
