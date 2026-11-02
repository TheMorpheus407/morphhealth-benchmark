import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';

import '../store/crypto.dart';

/// Raised when a backup container cannot be opened.
class BackupException implements Exception {
  const BackupException(this.message);

  final String message;

  @override
  String toString() => 'BackupException: $message';
}

/// Passphrase protected backup container.
///
/// Layout (all integers big endian):
/// ```
/// offset  size  content
/// 0       8     magic "MHBACKUP"
/// 8       1     container version (1)
/// 9       1     key derivation id (1 = Argon2id)
/// 10      4     Argon2id memory in KiB
/// 14      4     Argon2id iterations
/// 18      1     Argon2id parallelism
/// 19      1     salt length (16)
/// 20      16    salt
/// 36      1     nonce length (12)
/// 37      12    nonce
/// 49      4     ciphertext length
/// 53      1     authentication tag length (16)
/// 54      16    GCM authentication tag
/// 70      n     AES-256-GCM ciphertext of the portable JSON document
/// ```
/// The bytes 0..48 (magic, parameters, salt and nonce) are used as
/// additional authenticated data, so the parameters cannot be tampered with.
abstract final class BackupContainer {
  static const List<int> magic = <int>[
    0x4d, 0x48, 0x42, 0x41, 0x43, 0x4b, 0x55, 0x50, // MHBACKUP
  ];
  static const int version = 1;
  static const int kdfArgon2id = 1;
  static const int aadLength = 49;
  static const int headerLength = 70;

  /// Encrypts a portable document with a passphrase.
  static Future<List<int>> seal(
    Map<String, dynamic> document,
    String passphrase, {
    int memory = Crypto.argon2MemoryKib,
    int iterations = Crypto.argon2Iterations,
    int parallelism = Crypto.argon2Parallelism,
  }) async {
    final List<int> salt = Crypto.randomBytes(16);
    final List<int> nonce = Crypto.randomBytes(12);

    final List<int> clear = utf8.encode(jsonEncode(document));
    final SecretKey key = await Crypto.derivePassphraseKey(
      passphrase,
      salt,
      memory: memory,
      iterations: iterations,
      parallelism: parallelism,
    );
    final EncryptedPayload payload = await Crypto.encrypt(
      clear,
      key: key,
      nonce: nonce,
      aad: _headerFor(salt, nonce, memory, iterations, parallelism, 0, 0)
          .sublist(0, aadLength),
    );

    final Uint8List header = _headerFor(
      salt,
      nonce,
      memory,
      iterations,
      parallelism,
      payload.cipherText.length,
      payload.mac.length,
    );
    header.setRange(54, 54 + payload.mac.length, payload.mac);
    final Uint8List out = Uint8List(headerLength + payload.cipherText.length);
    out.setRange(0, headerLength, header);
    out.setRange(headerLength, out.length, payload.cipherText);
    return out;
  }

  static Uint8List _headerFor(
    List<int> salt,
    List<int> nonce,
    int memory,
    int iterations,
    int parallelism,
    int cipherLength,
    int macLength,
  ) {
    final Uint8List header = Uint8List(headerLength);
    header.setRange(0, magic.length, magic);
    header[8] = version;
    header[9] = kdfArgon2id;
    ByteData.sublistView(header).setUint32(10, memory, Endian.big);
    ByteData.sublistView(header).setUint32(14, iterations, Endian.big);
    header[18] = parallelism;
    header[19] = salt.length;
    header.setRange(20, 20 + salt.length, salt);
    header[36] = nonce.length;
    header.setRange(37, 37 + nonce.length, nonce);
    ByteData.sublistView(header).setUint32(49, cipherLength, Endian.big);
    header[53] = macLength;
    return header;
  }

  /// Opens a backup container and returns the portable document.
  static Future<Map<String, dynamic>> open(
    List<int> bytes,
    String passphrase,
  ) async {
    if (bytes.length < headerLength) {
      throw const BackupException('File is too short to be a backup');
    }
    final Uint8List data = Uint8List.fromList(bytes);
    for (int i = 0; i < magic.length; i++) {
      if (data[i] != magic[i]) {
        throw const BackupException('Not a MorphHealth backup file');
      }
    }
    final int containerVersion = data[8];
    if (containerVersion != version) {
      throw BackupException('Unsupported backup version: $containerVersion');
    }
    final int kdf = data[9];
    if (kdf != kdfArgon2id) {
      throw BackupException('Unsupported key derivation: $kdf');
    }
    final ByteData view = ByteData.sublistView(data);
    final int memory = view.getUint32(10, Endian.big);
    final int iterations = view.getUint32(14, Endian.big);
    final int parallelism = data[18];
    final int saltLength = data[19];
    if (saltLength != 16) {
      throw const BackupException('Invalid salt');
    }
    final List<int> salt = data.sublist(20, 36);
    final int nonceLength = data[36];
    if (nonceLength != 12) {
      throw const BackupException('Invalid nonce');
    }
    final List<int> nonce = data.sublist(37, 49);
    final int cipherLength = view.getUint32(49, Endian.big);
    final int macLength = data[53];
    if (macLength != 16) {
      throw const BackupException('Invalid authentication tag');
    }
    if (headerLength + cipherLength > data.length) {
      throw const BackupException('Truncated backup file');
    }
    final List<int> cipherText =
        data.sublist(headerLength, headerLength + cipherLength);
    final List<int> mac = data.sublist(54, 70);

    final SecretKey key = await Crypto.derivePassphraseKey(
      passphrase,
      salt,
      memory: memory,
      iterations: iterations,
      parallelism: parallelism,
    );
    final List<int> clear;
    try {
      clear = await Crypto.decrypt(
        EncryptedPayload(
          nonce: nonce,
          cipherText: cipherText,
          mac: mac,
        ),
        key: key,
        aad: data.sublist(0, aadLength),
      );
    } on Object {
      throw const BackupException('Wrong passphrase or damaged file');
    }
    final dynamic decoded = jsonDecode(utf8.decode(clear));
    if (decoded is! Map<String, dynamic>) {
      throw const BackupException('Backup does not contain a valid document');
    }
    return decoded;
  }
}
