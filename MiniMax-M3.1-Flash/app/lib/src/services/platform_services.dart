import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:morphhealth_core/morphhealth_core.dart';

/// Access to the Android keystore that protects the MorphHealth master key.
class KeyStoreService {
  const KeyStoreService();

  static const MethodChannel _channel =
      MethodChannel('de.themorpheus.morphhealth.local/keystore');

  /// Returns the 32 byte master key, creating it on first use.
  ///
  /// On platforms without the Android keystore (unit tests, desktop runs) a
  /// key file inside the application support directory is used instead.
  Future<List<int>> masterKey(Directory supportDirectory) async {
    if (!kIsWeb && Platform.isAndroid) {
      final String? encoded =
          await _channel.invokeMethod<String>('getOrCreateMasterKey');
      if (encoded == null) {
        throw StateError('The Android keystore did not return a master key.');
      }
      final List<int> bytes = base64Decode(encoded);
      if (bytes.length != 32) {
        throw StateError('The master key must be 32 bytes long.');
      }
      return bytes;
    }
    return _fileKey(supportDirectory);
  }

  /// Removes the keystore entry (only used for a complete reset).
  Future<void> reset() async {
    if (!kIsWeb && Platform.isAndroid) {
      await _channel.invokeMethod<bool>('resetMasterKey');
    }
  }

  Future<List<int>> _fileKey(Directory supportDirectory) async {
    final Directory dir = Directory(p.join(supportDirectory.path, 'keys'));
    await dir.create(recursive: true);
    final File file = File(p.join(dir.path, 'local.key'));
    if (await file.exists()) {
      final List<int> bytes = await file.readAsBytes();
      if (bytes.length == 32) return bytes;
    }
    final List<int> key = Crypto.newMasterKey();
    await file.writeAsBytes(key, flush: true);
    return key;
  }
}

/// Access to the system document picker (Storage Access Framework).
class DocumentService {
  const DocumentService();

  static const MethodChannel _channel =
      MethodChannel('de.themorpheus.morphhealth.local/files');

  /// Asks the user for a target document and returns its URI.
  Future<String?> createDocument({
    required String suggestedName,
    required String mimeType,
  }) async {
    if (kIsWeb || !Platform.isAndroid) return null;
    return _channel.invokeMethod<String>('createDocument', <String, dynamic>{
      'suggestedName': suggestedName,
      'mimeType': mimeType,
    });
  }

  /// Asks the user for a document to read and returns its URI.
  Future<String?> openDocument({String mimeType = '*/*'}) async {
    if (kIsWeb || !Platform.isAndroid) return null;
    return _channel.invokeMethod<String>('openDocument', <String, dynamic>{
      'mimeType': mimeType,
    });
  }

  /// Writes [bytes] into the document behind [uri].
  Future<bool> writeFile(String uri, List<int> bytes) async {
    if (kIsWeb || !Platform.isAndroid) return false;
    final bool? ok = await _channel.invokeMethod<bool>('writeFile', <String, dynamic>{
      'uri': uri,
      'bytes': bytes,
    });
    return ok ?? false;
  }

  /// Reads the document behind [uri].
  Future<List<int>?> readFile(String uri) async {
    if (kIsWeb || !Platform.isAndroid) return null;
    final Uint8List? bytes =
        await _channel.invokeMethod<Uint8List>('readFile', <String, dynamic>{
      'uri': uri,
    });
    return bytes;
  }
}

/// Resolves the directories the app uses.
class AppDirectories {
  const AppDirectories(this.documents, this.support);

  /// Directory that holds the encrypted local store.
  final Directory documents;

  /// Directory for keys and other app internals.
  final Directory support;

  static Future<AppDirectories> resolve() async {
    final Directory docs = await getApplicationDocumentsDirectory();
    final Directory support = await getApplicationSupportDirectory();
    return AppDirectories(
      Directory(p.join(docs.path, 'morphhealth')),
      support,
    );
  }
}
