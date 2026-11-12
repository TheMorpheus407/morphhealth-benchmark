library morphhealth.core.storage.encrypted_store;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:encrypt/encrypt.dart' as enc;

/// Verschlüsselter, dateibasierter Speicher für den gesamten Datenbestand.
///
/// Format pro Datei (JSON-Umschlag):
///   {"iv": base64(16 Byte), "data": base64(ciphertext AES-256-CBC),
///    "mac": base64(HMAC-SHA256 über iv||data)}
///
/// Der Schlüssel ist 32 Rohbyte (AES-256). Er wird vom Aufrufer bereitgestellt:
/// Flutter-App aus dem sicheren Schlüsselspeicher, `mh`-CLI aus --key-file.
class EncryptedStore {
  EncryptedStore(this.key) : assert(key.length == 32);

  final Uint8List key;

  /// Klartext-UTF8-JSON verschlüsseln und unter [path] ablegen.
  Future<void> writePlaintext(String path, String plaintext) async {
    final iv = enc.IV.fromSecureRandom(16);
    final encrypter = enc.Encrypter(enc.AES(enc.Key(key), mode: enc.AESMode.cbc));
    final encrypted = encrypter.encrypt(plaintext, iv: iv);
    final mac = _mac(key, iv.bytes, encrypted.bytes);
    final envelope = <String, dynamic>{
      'iv': base64Url.encode(iv.bytes),
      'data': base64Url.encode(encrypted.bytes),
      'mac': base64Url.encode(mac),
    };
    final file = File(path);
    await file.create(recursive: true);
    await file.writeAsString(jsonEncode(envelope), flush: true);
  }

  /// Datei entschlüsseln und Klartext zurückgeben. Wirft bei fehlgeschlagener
  /// Integritätsprüfung oder falschem Schlüssel eine [EncryptedStoreError].
  Future<String> readPlaintext(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      return '';
    }
    final envelope = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
    final ivBytes = base64Url.decode(envelope['iv'] as String);
    final dataBytes = base64Url.decode(envelope['data'] as String);
    final mac = base64Url.decode(envelope['mac'] as String);
    if (!_macEqual(_mac(key, ivBytes, dataBytes), mac)) {
      throw const EncryptedStoreError('Integritätsprüfung fehlgeschlagen');
    }
    final iv = enc.IV(ivBytes);
    final encrypter = enc.Encrypter(enc.AES(enc.Key(key), mode: enc.AESMode.cbc));
    try {
      return encrypter.decrypt64(base64Url.encode(dataBytes), iv: iv);
    } on Exception {
      throw const EncryptedStoreError('Entschlüsselung fehlgeschlagen');
    }
  }

  /// Datei löschen, falls vorhanden.
  Future<void> delete(String path) async {
    final file = File(path);
    if (await file.exists()) await file.delete();
  }

  static Uint8List _mac(Uint8List key, Uint8List iv, Uint8List data) {
    final hmac = Hmac(sha256, key);
    return Uint8List.fromList(hmac.convert([...iv, ...data]).bytes);
  }

  static bool _macEqual(Uint8List a, Uint8List b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}

class EncryptedStoreError implements Exception {
  const EncryptedStoreError(this.message);
  final String message;
  @override
  String toString() => 'EncryptedStoreError: $message';
}