import 'dart:convert';

import 'package:cryptography/cryptography.dart';

import 'encrypted_store.dart';
import 'health.dart';
import 'utils.dart';

const portableFormat = 'morphhealth.portable.v1';
const backupFormat = 'morphhealth.encrypted-backup.v1';
const backupIterations = 600000;

Map<String, dynamic> createPortableDocument(
  AppState state,
  DateTime exportedAt,
) => {
  'format': portableFormat,
  'app_version': '1.0.0',
  'exported_at': formatInstant(exportedAt),
  'state': state.toJson(),
};

AppState parsePortableDocument(Object? value) {
  final document = jsonMap(value, 'document');
  if (document['format'] != portableFormat) {
    throw const FormatException(
      'document.format must be morphhealth.portable.v1',
    );
  }
  jsonString(document['app_version'], 'document.app_version');
  parseInstant(document['exported_at'], 'document.exported_at');
  return AppState.fromJson(document['state']);
}

Map<String, dynamic> portableExample() =>
    createPortableDocument(AppState.initial(), DateTime.utc(2026, 1, 1));

class BackupCodec {
  static final _aad = utf8.encode(backupFormat);

  static Future<Map<String, dynamic>> encrypt(
    Map<String, dynamic> document,
    String passphrase,
  ) async {
    if (passphrase.isEmpty) throw ArgumentError('Passphrase must not be empty');
    parsePortableDocument(document);
    final salt = randomBytes(16);
    final nonce = randomBytes(12);
    final key = await _deriveKey(passphrase, salt, backupIterations);
    final box = await AesGcm.with256bits().encrypt(
      utf8.encode(jsonEncode(document)),
      secretKey: key,
      nonce: nonce,
      aad: _aad,
    );
    return {
      'format': backupFormat,
      'kdf': {
        'name': 'PBKDF2-HMAC-SHA256',
        'iterations': backupIterations,
        'salt_b64': base64Encode(salt),
      },
      'cipher': 'AES-256-GCM',
      'nonce_b64': base64Encode(nonce),
      'mac_b64': base64Encode(box.mac.bytes),
      'ciphertext_b64': base64Encode(box.cipherText),
    };
  }

  static Future<Map<String, dynamic>> decrypt(
    Object? value,
    String passphrase,
  ) async {
    final envelope = jsonMap(value, 'backup');
    if (envelope['format'] != backupFormat ||
        envelope['cipher'] != 'AES-256-GCM') {
      throw const FormatException('Unsupported backup format');
    }
    final kdf = jsonMap(envelope['kdf'], 'backup.kdf');
    if (kdf['name'] != 'PBKDF2-HMAC-SHA256')
      throw const FormatException('Unsupported backup KDF');
    final iterations = jsonInt(
      kdf['iterations'],
      'backup.kdf.iterations',
      min: 100000,
      max: 5000000,
    );
    final salt = base64Decode(
      jsonString(kdf['salt_b64'], 'backup.kdf.salt_b64'),
    );
    final nonce = base64Decode(
      jsonString(envelope['nonce_b64'], 'backup.nonce_b64'),
    );
    final mac = base64Decode(jsonString(envelope['mac_b64'], 'backup.mac_b64'));
    final ciphertext = base64Decode(
      jsonString(envelope['ciphertext_b64'], 'backup.ciphertext_b64'),
    );
    if (salt.length != 16 || nonce.length != 12 || mac.length != 16) {
      throw const FormatException('Invalid backup cryptographic field lengths');
    }
    final key = await _deriveKey(passphrase, salt, iterations);
    final clearText = await AesGcm.with256bits().decrypt(
      SecretBox(ciphertext, nonce: nonce, mac: Mac(mac)),
      secretKey: key,
      aad: _aad,
    );
    final document = jsonMap(jsonDecode(utf8.decode(clearText)), 'document');
    parsePortableDocument(document);
    return document;
  }

  static Future<SecretKey> _deriveKey(
    String passphrase,
    List<int> salt,
    int iterations,
  ) {
    final kdf = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iterations,
      bits: 256,
    );
    return kdf.deriveKey(
      secretKey: SecretKey(utf8.encode(passphrase)),
      nonce: salt,
    );
  }
}
