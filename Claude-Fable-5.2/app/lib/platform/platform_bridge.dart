import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// A document the user picked with the system file dialog.
class PickedDocument {
  final String name;
  final Uint8List bytes;

  const PickedDocument(this.name, this.bytes);
}

/// The master key of the local data cannot be provided by the device.
class KeyUnavailableException implements Exception {
  final String message;

  const KeyUnavailableException(this.message);

  @override
  String toString() => 'KeyUnavailableException: $message';
}

/// A file could not be saved or opened.
class DocumentException implements Exception {
  /// `write_failed`, `read_failed`, `too_large`, `no_file_picker` or `busy`.
  final String code;
  final String message;

  const DocumentException(this.code, this.message);

  @override
  String toString() => 'DocumentException($code): $message';
}

/// The few services MorphHealth needs from the platform.
abstract class PlatformBridge {
  /// Private directory of the encrypted data store.
  Future<String> dataDirectory();

  /// The 32-byte master key of the data store; created on first use and kept
  /// wrapped by a key of the Android Keystore.
  Future<Uint8List> loadOrCreateMasterKey();

  /// Destroys the master key. Everything encrypted with it becomes unreadable.
  Future<void> resetMasterKey();

  /// Lets the user choose where to save [bytes]. Returns the name of the
  /// written document, or null if the user cancelled.
  Future<String?> saveDocument({
    required String name,
    required String mimeType,
    required Uint8List bytes,
  });

  /// Lets the user pick a document. Returns null if the user cancelled.
  Future<PickedDocument?> openDocument();
}

/// [PlatformBridge] backed by the Android activity (see MainActivity.kt).
class MethodChannelPlatformBridge implements PlatformBridge {
  static const MethodChannel _channel = MethodChannel(
    'de.themorpheus.morphhealth.local/platform',
  );

  const MethodChannelPlatformBridge();

  @override
  Future<String> dataDirectory() async =>
      (await _channel.invokeMethod<String>('dataDirectory'))!;

  @override
  Future<Uint8List> loadOrCreateMasterKey() async {
    try {
      final key = await _channel.invokeMethod<Uint8List>(
        'loadOrCreateMasterKey',
      );
      if (key == null || key.length != 32) {
        throw const KeyUnavailableException('The device returned no key.');
      }
      return key;
    } on PlatformException catch (e) {
      throw KeyUnavailableException(e.message ?? e.code);
    }
  }

  @override
  Future<void> resetMasterKey() async {
    try {
      await _channel.invokeMethod<void>('resetMasterKey');
    } on PlatformException catch (e) {
      throw KeyUnavailableException(e.message ?? e.code);
    }
  }

  @override
  Future<String?> saveDocument({
    required String name,
    required String mimeType,
    required Uint8List bytes,
  }) async {
    try {
      return await _channel.invokeMethod<String>('saveDocument', {
        'name': name,
        'mimeType': mimeType,
        'bytes': bytes,
      });
    } on PlatformException catch (e) {
      throw DocumentException(e.code, e.message ?? e.code);
    }
  }

  @override
  Future<PickedDocument?> openDocument() async {
    try {
      final result = await _channel.invokeMapMethod<String, Object?>(
        'openDocument',
      );
      if (result == null) return null;
      return PickedDocument(
        result['name'] as String? ?? '',
        result['bytes'] as Uint8List? ?? Uint8List(0),
      );
    } on PlatformException catch (e) {
      throw DocumentException(e.code, e.message ?? e.code);
    }
  }
}

/// In-memory [PlatformBridge] for widget tests.
@visibleForTesting
class FakePlatformBridge implements PlatformBridge {
  Uint8List key = Uint8List.fromList(List<int>.generate(32, (i) => i));
  final Map<String, Uint8List> savedDocuments = {};

  /// What the next [openDocument] returns; null means "cancelled".
  PickedDocument? nextOpen;

  /// If true, [saveDocument] behaves as if the user cancelled.
  bool cancelSave = false;
  int keyResets = 0;

  @override
  Future<String> dataDirectory() async => '/nonexistent/morphhealth-test';

  @override
  Future<Uint8List> loadOrCreateMasterKey() async => key;

  @override
  Future<void> resetMasterKey() async {
    keyResets++;
    key = Uint8List.fromList(List<int>.generate(32, (i) => 255 - i));
  }

  @override
  Future<String?> saveDocument({
    required String name,
    required String mimeType,
    required Uint8List bytes,
  }) async {
    if (cancelSave) return null;
    savedDocuments[name] = bytes;
    return name;
  }

  @override
  Future<PickedDocument?> openDocument() async => nextOpen;
}
