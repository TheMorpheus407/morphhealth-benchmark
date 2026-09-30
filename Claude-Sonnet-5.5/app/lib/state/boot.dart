import 'dart:io';
import 'dart:typed_data';

import '../core/core.dart';
import '../core/store.dart';
import '../platform/device_keys.dart';
import '../platform/platform_bridge.dart';

/// Ergebnis des Starts: ein geöffneter Kern oder der Grund, warum der
/// Datenbestand nicht geöffnet werden konnte.
sealed class BootResult {
  const BootResult();
}

final class BootOk extends BootResult {
  final MorphCore core;
  final Session session;

  const BootOk(this.core, this.session);
}

final class BootFailure extends BootResult {
  final String message;
  final Session session;

  /// `wrong_key`, `corrupt`, `locked`, `key` (Schlüssel nicht lesbar) oder `io`.
  final String code;

  const BootFailure(this.code, this.message, this.session);
}

/// Gerätebezogene Bausteine, die über die Lebensdauer der App gleich bleiben.
class Session {
  final PlatformBridge platform;
  final Directory dataDir;
  final DeviceKeys keys;

  Session(this.platform, this.dataDir, this.keys);

  /// Öffnet den Datenbestand mit dem Gerätehauptschlüssel.
  Future<MorphCore> openCore(Uint8List key) async {
    final store = await EncryptedStore.open(dataDir, key);
    return MorphCore.open(persistence: store);
  }

  /// Löscht alle lokalen Daten, erneuert den Schlüssel und liefert einen
  /// frischen, leeren Kern.
  Future<MorphCore> wipeAndReopen(MorphCore? current) async {
    await current?.close();
    await EncryptedStore.deleteFiles(dataDir);
    final key = await keys.rotate();
    return openCore(key);
  }
}

Future<BootResult> boot() async {
  final platform = PlatformBridge();
  final files = await platform.filesDir();
  final session = Session(platform, Directory('$files/mh-data'), DeviceKeys(platform, Directory('$files/mh-keys')));
  Uint8List key;
  try {
    key = await session.keys.loadOrCreate();
  } on Object catch (e) {
    return BootFailure('key', '$e', session);
  }
  try {
    return BootOk(await session.openCore(key), session);
  } on StoreException catch (e) {
    return BootFailure(
      switch (e.code) {
        StoreErrorCode.wrongKey => 'wrong_key',
        StoreErrorCode.corrupt => 'corrupt',
        StoreErrorCode.locked => 'locked',
        _ => 'io',
      },
      e.message,
      session,
    );
  } on FileSystemException catch (e) {
    return BootFailure('io', e.message, session);
  }
}
