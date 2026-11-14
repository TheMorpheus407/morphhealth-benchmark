import "dart:convert";
import "dart:io";
import "dart:typed_data";
import "crypto.dart";
import "models.dart";

class Store {
  final String dataDir;
  final Uint8List key;
  late Map<String, dynamic> doc;
  Store(this.dataDir, this.key);
  File get _file => File("$dataDir/data.enc.json");
  Directory get _dir => Directory(dataDir);

  void load() {
    _dir.createSync(recursive: true);
    if (!_file.existsSync()) { doc = emptyDoc(); save(); return; }
    final outer = jsonDecode(_file.readAsStringSync()) as Map<String, dynamic>;
    if (outer["format"] != "morphhealth-encrypted") throw const FormatException("bad encrypted store format");
    final plain = CryptoBox.decryptWithKey(key, outer["nonce"] as String, outer["data"] as String);
    final d = jsonDecode(plain);
    if (!isValidDoc(d)) throw const FormatException("invalid morphhealth document");
    doc = d as Map<String, dynamic>;
  }
  void save() {
    _dir.createSync(recursive: true);
    final e = CryptoBox.encryptWithKey(key, jsonEncode(doc));
    _file.writeAsStringSync(jsonEncode({"format": "morphhealth-encrypted", "cipher": "AES-256-GCM", "nonce": e["nonce"], "data": e["data"]}));
  }
  // Portable export = the plaintext document (machine readable). Import replaces fully.
  Map<String, dynamic> exportDoc() => jsonDecode(jsonEncode(doc)) as Map<String, dynamic>;
  void importDoc(dynamic d) {
    if (!isValidDoc(d)) throw const FormatException("invalid morphhealth document for import");
    doc = d as Map<String, dynamic>;
    save();
  }
  void wipe() { doc = emptyDoc(); save(); }
  List<Map<String, dynamic>> get foods => (doc["foods"] as List).cast<Map<String, dynamic>>();
  List<Map<String, dynamic>> get entries => (doc["entries"] as List).cast<Map<String, dynamic>>();
  Map<String, dynamic> get settings => doc["settings"] as Map<String, dynamic>;
}
