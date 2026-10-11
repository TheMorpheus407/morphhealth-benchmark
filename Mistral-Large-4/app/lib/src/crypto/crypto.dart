// Kryptografie: AES-256-GCM-Container für den lokalen Speicher und
// passphrasengeschützte Sicherungen (PBKDF2-HMAC-SHA256).
//
// Reine Dart-Implementierung (package:cryptography), damit derselbe Code in
// der Android-App und im Wartungszugang (AOT-kompiliert) läuft.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../core/exceptions.dart';
import '../core/ids.dart';

/// AES-256-GCM mit 12-Byte-Nonce und 16-Byte-MAC.
class AesGcmCodec {
  static final AesGcm _aes = AesGcm.with256bits();

  /// Verschlüsselt `plaintext` mit einem 32-Byte-Schlüssel.
  /// Rückgabe: nonce (12) || ciphertext || mac (16).
  static Future<List<int>> encrypt(List<int> plaintext, List<int> keyBytes) async {
    _checkKey(keyBytes);
    final SecretKey key = SecretKey(keyBytes);
    final SecretBox box = await _aes.encrypt(plaintext, secretKey: key);
    return <int>[...box.nonce, ...box.cipherText, ...box.mac.bytes];
  }

  /// Entschlüsselt einen Blob aus `encrypt`. Wirft bei Manipulation oder
  /// falschem Schlüssel MorphException('crypto.decrypt_failed').
  static Future<List<int>> decrypt(List<int> blob, List<int> keyBytes) async {
    _checkKey(keyBytes);
    if (blob.length < 12 + 16) {
      throw MorphException('crypto.decrypt_failed', 'Container ist zu kurz.');
    }
    final List<int> nonce = blob.sublist(0, 12);
    final List<int> mac = blob.sublist(blob.length - 16);
    final List<int> cipherText = blob.sublist(12, blob.length - 16);
    final SecretKey key = SecretKey(keyBytes);
    try {
      final List<int> out = await _aes.decrypt(
        SecretBox(cipherText, nonce: nonce, mac: Mac(mac)),
        secretKey: key,
      );
      return out;
    } on SecretBoxAuthenticationError {
      throw MorphException('crypto.decrypt_failed',
          'Entschlüsselung fehlgeschlagen (falscher Schlüssel oder beschädigte Daten).');
    }
  }

  static void _checkKey(List<int> keyBytes) {
    if (keyBytes.length != 32) {
      throw MorphException('crypto.invalid_key', 'Der Schlüssel muss 32 Bytes lang sein.');
    }
  }
}

/// PBKDF2-HMAC-SHA256 zur Passphrase-Ableitung.
class PassphraseKdf {
  /// Iterationen (aktueller OWASP-Richtwert für PBKDF2-HMAC-SHA256).
  static const int defaultIterations = 600000;
  static const int saltBytes = 16;
  static const int keyBytes = 32;

  static Future<List<int>> deriveKey(
    String passphrase, {
    List<int>? salt,
    int iterations = defaultIterations,
  }) async {
    final List<int> saltValue = salt ?? randomBytes(saltBytes);
    final Pbkdf2 pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: iterations,
      bits: keyBytes * 8,
    );
    final SecretKey derived = await pbkdf2.deriveKey(
      secretKey: SecretKey(utf8.encode(passphrase)),
      nonce: saltValue,
    );
    final List<int> bytes = await derived.extractBytes();
    return bytes;
  }
}

/// Versiegelter Container für den lokalen Datenspeicher.
///
/// Aufbau (Bytes):
///   "MHST" | version u16 LE | reserved u16 LE | nonce 12 | ciphertext | mac 16
class StoreContainer {
  static const String magic = 'MHST';
  static const int version = 1;

  static Future<List<int>> seal(List<int> plaintext, List<int> keyBytes) async {
    final List<int> body = await AesGcmCodec.encrypt(plaintext, keyBytes);
    final BytesBuilder b = BytesBuilder();
    b.add(ascii.encode(magic));
    b.add(_u16(version));
    b.add(_u16(0));
    b.add(body); // nonce || ciphertext || mac
    return b.toBytes();
  }

  static Future<List<int>> open(List<int> blob, List<int> keyBytes) async {
    if (blob.length < 8 || ascii.decode(blob.sublist(0, 4)) != magic) {
      throw MorphException('store.invalid_format', 'Kein MorphHealth-Speichercontainer.');
    }
    final int version = _readU16(blob, 4);
    if (version != StoreContainer.version) {
      throw MorphException('store.unsupported_version', 'Speicherversion $version wird nicht unterstützt.');
    }
    return AesGcmCodec.decrypt(blob.sublist(8), keyBytes);
  }

  static List<int> _u16(int v) => <int>[v & 0xff, (v >> 8) & 0xff];

  static int _readU16(List<int> b, int offset) => b[offset] | (b[offset + 1] << 8);
}

/// Versiegelter Container für passphrasengeschützte Sicherungen.
///
/// Aufbau (Bytes):
///   "MHBK" | version u16 LE | kdfId u8 | iterations u32 LE |
///   salt 16 | nonce 12 | ciphertext | mac 16
class BackupContainer {
  static const String magic = 'MHBK';
  static const int version = 1;
  static const int kdfPbkdf2Sha256 = 1;

  /// Versiegelt ein Klartext-Dokument mit einer Passphrase.
  static Future<List<int>> seal(
    List<int> plaintext,
    String passphrase, {
    List<int>? salt,
    int iterations = PassphraseKdf.defaultIterations,
  }) async {
    final List<int> saltBytes = salt ?? randomBytes(PassphraseKdf.saltBytes);
    final List<int> key = await PassphraseKdf.deriveKey(passphrase,
        salt: saltBytes, iterations: iterations);
    final List<int> body = await AesGcmCodec.encrypt(plaintext, key);
    final BytesBuilder b = BytesBuilder();
    b.add(ascii.encode(magic));
    b.add(_u16(version));
    b.add(<int>[kdfPbkdf2Sha256]);
    b.add(_u32(iterations));
    b.add(saltBytes);
    b.add(body);
    return b.toBytes();
  }

  /// Öffnet einen Sicherungscontainer. Wirft MorphException('backup.wrong_passphrase')
  /// bei falscher Passphrase oder beschädigten Daten.
  static Future<List<int>> open(List<int> blob, String passphrase) async {
    const int headerLen = 4 + 2 + 1 + 4 + 16; // magic+version+kdfId+iterations+salt
    if (blob.length < headerLen + 12 + 16 || ascii.decode(blob.sublist(0, 4)) != magic) {
      throw MorphException('backup.invalid_format', 'Kein MorphHealth-Sicherungscontainer.');
    }
    final int version = _readU16(blob, 4);
    if (version != BackupContainer.version) {
      throw MorphException('backup.unsupported_version', 'Sicherungsversion $version wird nicht unterstützt.');
    }
    final int kdfId = blob[6];
    final int iterations = _readU32(blob, 7);
    if (kdfId != kdfPbkdf2Sha256) {
      throw MorphException('backup.unsupported_kdf', 'Unbekanntes KDF-Verfahren $kdfId.');
    }
    final List<int> salt = blob.sublist(11, 11 + 16);
    final List<int> key = await PassphraseKdf.deriveKey(passphrase,
        salt: salt, iterations: iterations);
    try {
      return await AesGcmCodec.decrypt(blob.sublist(headerLen), key);
    } on MorphException catch (e) {
      if (e.code == 'crypto.decrypt_failed') {
        throw MorphException('backup.wrong_passphrase',
            'Passphrase falsch oder Sicherung beschädigt.');
      }
      rethrow;
    }
  }

  static List<int> _u16(int v) => <int>[v & 0xff, (v >> 8) & 0xff];

  static List<int> _u32(int v) => <int>[
        v & 0xff,
        (v >> 8) & 0xff,
        (v >> 16) & 0xff,
        (v >> 24) & 0xff,
      ];

  static int _readU16(List<int> b, int offset) => b[offset] | (b[offset + 1] << 8);

  static int _readU32(List<int> b, int offset) =>
      b[offset] | (b[offset + 1] << 8) | (b[offset + 2] << 16) | (b[offset + 3] << 24);
}
