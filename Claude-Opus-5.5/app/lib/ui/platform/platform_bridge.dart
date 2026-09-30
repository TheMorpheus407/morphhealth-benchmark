import 'dart:isolate';

import 'package:flutter/services.dart';

import '../../core/storage/encrypted_store.dart';

/// Access to the Android side (see MainActivity.kt / KeyVault.kt).
class PlatformBridge {
  const PlatformBridge();

  static const MethodChannel _channel = MethodChannel(
    'de.themorpheus.morphhealth/platform',
  );

  /// The app's private files directory.
  Future<String> dataDirectory() async =>
      (await _channel.invokeMethod<String>('dataDirectory'))!;

  /// The 32-byte master key, created on first use and kept wrapped by a
  /// non-exportable Android Keystore key.
  Future<Uint8List> loadMasterKey() async =>
      (await _channel.invokeMethod<Uint8List>('loadMasterKey'))!;

  /// Deletes the wrapped master key and its Keystore wrapping key.
  Future<void> destroyMasterKey() => _channel.invokeMethod('destroyMasterKey');

  /// Lets the user choose where to save [bytes]. Returns false if cancelled.
  Future<bool> createDocument({
    required String name,
    required String mimeType,
    required Uint8List bytes,
  }) async {
    final result = await _channel.invokeMethod<bool>('createDocument', {
      'name': name,
      'mimeType': mimeType,
      'bytes': bytes,
    });
    return result ?? false;
  }

  /// Lets the user pick a document; returns its bytes or null if cancelled.
  Future<Uint8List?> openDocument(List<String> mimeTypes) =>
      _channel.invokeMethod<Uint8List>('openDocument', {'mimeTypes': mimeTypes});
}

/// Encodes store snapshots in a background isolate so large data sets never
/// block the UI thread.
Future<Uint8List> encodeSnapshotInBackground(
  SnapshotJob job,
  StoreContents contents,
) => Isolate.run(() => job.encode(contents));

/// Decrypts and parses the snapshot in a background isolate.
Future<SnapshotData> decodeSnapshotInBackground(
  Uint8List bytes,
  List<int> masterKey,
  DateTime now,
) => Isolate.run(() => EncryptedStore.decodeSnapshot(bytes, masterKey, now: now));
