// Sicherung (Backup): passphrasengeschützte Datei mit dem portablen Dokument.
library;

import 'dart:convert';
import 'dart:io';

import '../core/exceptions.dart';
import '../crypto/crypto.dart';
import '../model/document.dart';

class BackupFile {
  /// Versiegelt ein portables Dokument mit einer Passphrase.
  static Future<List<int>> seal(Map<String, dynamic> portableDocument, String passphrase) async {
    final List<int> plain = utf8.encode(jsonEncode(portableDocument));
    return BackupContainer.seal(plain, passphrase);
  }

  /// Öffnet eine Sicherung und parst das portable Dokument.
  static Future<MorphDocument> openBytes(List<int> blob, String passphrase) async {
    final List<int> plain = await BackupContainer.open(blob, passphrase);
    final Map<String, dynamic> json =
        jsonDecode(utf8.decode(plain)) as Map<String, dynamic>;
    return MorphDocument.fromPortableJson(json);
  }

  static Future<MorphDocument> openFile(File file, String passphrase) async {
    if (!file.existsSync()) {
      throw MorphException('backup.missing', 'Sicherungsdatei nicht gefunden: ${file.path}');
    }
    return openBytes(await file.readAsBytes(), passphrase);
  }
}
