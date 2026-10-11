// Persistenz: verschlüsselter lokaler Datenbestand + Schlüsseldatiei.
//
// Dateiformat siehe SECURITY.md. Die Schlüsseldatiei enthält 32 rohe Bytes
// und liegt außerhalb des Datenverzeichnisses (App: app-privater Speicher;
// CLI: --key-file). Schreibzugriffe sind atomar (tmp + rename).
library;

import 'dart:convert';
import 'dart:io';

import '../core/clock.dart';
import '../core/exceptions.dart';
import '../core/ids.dart';
import '../crypto/crypto.dart';
import '../model/document.dart';

/// Dateiname des Speichers innerhalb des Datenverzeichnisses.
const String storeFileName = 'morphhealth.store';

class EncryptedStore {
  final Directory dataDir;
  final List<int> keyBytes;
  final AppInfo appInfo;

  EncryptedStore({required this.dataDir, required this.keyBytes, this.appInfo = const AppInfo()});

  File get storeFile => File('${dataDir.path}/$storeFileName');

  bool get exists => storeFile.existsSync();

  /// Lädt das Dokument. Legt bei Bedarf (erstes Starten) ein neues,
  /// leeres Dokument an und speichert es.
  Future<MorphDocument> load({Clock? clock}) async {
    if (!storeFile.existsSync()) {
      final MorphDocument doc = MorphDocument.empty();
      await save(doc, clock: clock);
      return doc;
    }
    try {
      final List<int> blob = await storeFile.readAsBytes();
      final List<int> plain = await StoreContainer.open(blob, keyBytes);
      final Map<String, dynamic> json =
          jsonDecode(utf8.decode(plain)) as Map<String, dynamic>;
      return MorphDocument.fromDataJson(json);
    } on MorphException {
      rethrow;
    } catch (e) {
      throw MorphException('store.unreadable',
          'Der Datenbestand kann nicht gelesen werden: $e');
    }
  }

  /// Speichert das Dokument atomar (tmp-Datei + rename).
  Future<void> save(MorphDocument doc, {Clock? clock}) async {
    await dataDir.create(recursive: true);
    final Map<String, dynamic> json = doc.toDataJson();
    final List<int> plain = utf8.encode(jsonEncode(json));
    final List<int> blob = await StoreContainer.seal(plain, keyBytes);
    final File tmp = File('${storeFile.path}.tmp');
    await tmp.writeAsBytes(blob, flush: true);
    await tmp.rename(storeFile.path);
  }

  /// Löscht den gesamten lokalen Datenbestand (ohne Schlüsseldatiei).
  Future<void> deleteAll() async {
    if (await dataDir.exists()) {
      await dataDir.delete(recursive: true);
    }
  }
}

/// Verwaltung der Schlüsseldatiei (32 rohe Bytes, außerhalb des Datenverzeichnisses).
class KeyFile {
  final File file;
  const KeyFile(this.file);

  /// Lädt den Schlüssel; legt ihn bei Bedarf neu an (nur App-Verhalten).
  ///
  /// Beim CLI muss die Datei existieren und exakt 32 Bytes enthalten —
  /// siehe [loadStrict].
  static Future<List<int>> loadOrCreate(File file) async {
    if (file.existsSync()) {
      return loadStrict(file);
    }
    final List<int> key = randomBytes(32);
    await file.parent.create(recursive: true);
    await file.writeAsBytes(key, flush: true);
    try {
      await Process.run('chmod', <String>['600', file.path]);
    } catch (_) {
      // Berechtigungen sind best effort (funktioniert nicht überall).
    }
    return key;
  }

  /// Lädt den Schlüssel und verlangt exakt 32 Bytes.
  static Future<List<int>> loadStrict(File file) async {
    if (!file.existsSync()) {
      throw MorphException('keyfile.missing',
          'Schlüsseldatiei nicht gefunden: ${file.path}');
    }
    final List<int> bytes = await file.readAsBytes();
    if (bytes.length != 32) {
      throw MorphException('keyfile.invalid_length',
          'Die Schlüsseldatiei muss 32 rohe Bytes enthalten (${bytes.length} gefunden): ${file.path}');
    }
    return bytes;
  }
}
