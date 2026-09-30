import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'crypto.dart';
import 'ids.dart';

/// Fehler beim Erstellen oder Öffnen einer Sicherung.
final class BackupException implements Exception {
  /// `wrong_passphrase`, `not_a_backup`, `unsupported`, `corrupt` oder `weak_passphrase`.
  final String code;
  final String message;

  const BackupException(this.code, this.message);

  @override
  String toString() => 'BackupException($code): $message';
}

const List<int> _magic = [0x4D, 0x48, 0x42, 0x31]; // "MHB1"
const int _kdfArgon2id = 2;
const int _headerLength = 4 + 1 + 4 + 4 + 1 + 16;

/// Dateiendung und Medientyp verschlüsselter Sicherungen.
const String kBackupExtension = 'mhbackup';
const String kBackupMime = 'application/octet-stream';

/// Mindestlänge der Passphrase.
const int kMinPassphraseLength = 8;

/// Verschlüsselte Sicherung eines Exportdokuments.
///
/// Aufbau (alle Zahlen Big Endian):
/// `"MHB1" | kdf u8 (2 = Argon2id) | speicher_kib u32 | durchläufe u32 |
/// lanes u8 | salt 16 | nonce 12 | ciphertext | tag 16`.
/// Der Klartext ist gzip-komprimiertes JSON (das Export-Dokument), verschlüsselt
/// mit AES-256-GCM; der Schlüssel entsteht aus der Passphrase mit Argon2id.
/// Der Kopf (bis einschließlich Salt) ist als zusätzliche Daten authentifiziert.
Future<Uint8List> createBackup(
  Map<String, Object?> document,
  String passphrase, {
  Argon2Params params = Argon2Params.standard,
}) async {
  if (passphrase.length < kMinPassphraseLength) {
    throw const BackupException('weak_passphrase', 'Die Passphrase braucht mindestens $kMinPassphraseLength Zeichen');
  }
  final salt = Uint8List.fromList(randomBytes(16));
  final key = await argon2idKey(passphrase, salt, params);
  final header = BytesBuilder(copy: false)
    ..add(_magic)
    ..addByte(_kdfArgon2id)
    ..add(_u32(params.memoryKiB))
    ..add(_u32(params.iterations))
    ..addByte(params.parallelism)
    ..add(salt);
  final headerBytes = header.toBytes();
  final plain = Uint8List.fromList(gzip.encode(utf8.encode(jsonEncode(document))));
  final sealed = await aeadSeal(key, plain, headerBytes);
  return Uint8List.fromList([...headerBytes, ...sealed]);
}

/// Öffnet eine Sicherung und liefert das Exportdokument.
Future<Map<String, Object?>> openBackup(Uint8List bytes, String passphrase) async {
  if (bytes.length < _headerLength + aeadNonceLength + aeadTagLength || !_hasMagic(bytes)) {
    throw const BackupException('not_a_backup', 'Die Datei ist keine MorphHealth-Sicherung');
  }
  final kdf = bytes[4];
  if (kdf != _kdfArgon2id) {
    throw BackupException('unsupported', 'Unbekanntes Ableitungsverfahren ($kdf)');
  }
  final view = ByteData.sublistView(bytes);
  final params = Argon2Params(
    memoryKiB: view.getUint32(5, Endian.big),
    iterations: view.getUint32(9, Endian.big),
    parallelism: bytes[13],
  );
  if (!params.withinLimits) {
    throw const BackupException('unsupported', 'Die Ableitungsparameter der Sicherung sind unzulässig');
  }
  final salt = Uint8List.sublistView(bytes, 14, 30);
  final key = await argon2idKey(passphrase, Uint8List.fromList(salt), params);
  final Uint8List plain;
  try {
    plain = await aeadOpen(
      key,
      Uint8List.sublistView(bytes, _headerLength),
      Uint8List.sublistView(bytes, 0, _headerLength),
    );
  } on CryptoFailure {
    throw const BackupException('wrong_passphrase', 'Passphrase falsch oder Sicherung beschädigt');
  }
  try {
    final doc = jsonDecode(utf8.decode(gzip.decode(plain)));
    if (doc is! Map) throw const FormatException('kein Objekt');
    return doc.cast<String, Object?>();
  } on Object {
    throw const BackupException('corrupt', 'Der Inhalt der Sicherung ist beschädigt');
  }
}

bool _hasMagic(Uint8List b) {
  for (var i = 0; i < _magic.length; i++) {
    if (b[i] != _magic[i]) return false;
  }
  return true;
}

Uint8List _u32(int v) {
  final d = ByteData(4)..setUint32(0, v, Endian.big);
  return d.buffer.asUint8List();
}
