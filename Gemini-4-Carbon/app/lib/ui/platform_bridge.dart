/// Platform bridge to `MainActivity.kt` for Android Keystore master key wrapping
/// and Storage Access Framework (`com.android.documentsui`) document picking.
library;

import 'package:flutter/services.dart';

class PickedDocument {
  final String name;
  final Uint8List bytes;
  final String? uri;

  const PickedDocument({
    required this.name,
    required this.bytes,
    this.uri,
  });
}

class AppBootstrapCredentials {
  final String dataDir;
  final Uint8List masterKey;

  const AppBootstrapCredentials({
    required this.dataDir,
    required this.masterKey,
  });
}

abstract class PlatformBridge {
  Future<AppBootstrapCredentials> getAppPathsAndMasterKey();
  Future<Uint8List> rotateMasterKey();
  Future<bool> saveDocument({
    required String fileName,
    required String mimeType,
    required Uint8List bytes,
  });
  Future<PickedDocument?> openDocument();
}

class AndroidMethodChannelBridge implements PlatformBridge {
  static const MethodChannel _channel = MethodChannel(
    'de.themorpheus.morphhealth.local/platform',
  );

  const AndroidMethodChannelBridge();

  @override
  Future<AppBootstrapCredentials> getAppPathsAndMasterKey() async {
    final map = await _channel.invokeMapMethod<String, dynamic>(
      'getAppPathsAndMasterKey',
    );
    if (map == null) {
      throw StateError('Null response from getAppPathsAndMasterKey.');
    }
    final dataDir = map['dataDir'] as String;
    final key = map['masterKey'] as Uint8List;
    return AppBootstrapCredentials(dataDir: dataDir, masterKey: key);
  }

  @override
  Future<Uint8List> rotateMasterKey() async {
    final map = await _channel.invokeMapMethod<String, dynamic>(
      'rotateMasterKey',
    );
    if (map == null || map['masterKey'] is! Uint8List) {
      throw StateError('Failed to rotate Android Keystore master key.');
    }
    return map['masterKey'] as Uint8List;
  }

  @override
  Future<bool> saveDocument({
    required String fileName,
    required String mimeType,
    required Uint8List bytes,
  }) async {
    final map = await _channel.invokeMapMethod<String, dynamic>(
      'saveDocument',
      {
        'fileName': fileName,
        'mimeType': mimeType,
        'bytes': bytes,
      },
    );
    return map?['saved'] == true;
  }

  @override
  Future<PickedDocument?> openDocument() async {
    final map = await _channel.invokeMapMethod<String, dynamic>('openDocument');
    if (map == null || map['picked'] != true) return null;
    final bytes = map['bytes'] as Uint8List?;
    if (bytes == null) return null;
    return PickedDocument(
      name: (map['name'] as String?) ?? 'document',
      bytes: bytes,
      uri: map['uri'] as String?,
    );
  }
}
