import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'package:cryptography/cryptography.dart';
import 'model.dart';
import 'nutrients.dart';

const backupIterations = 600000;
List<int> randomBytes(int count) {
  final random = Random.secure();
  return List.generate(count, (_) => random.nextInt(256));
}

class Envelope {
  static Future<Json> seal(List<int> clear, List<int> key, {Json? kdf}) async {
    final header = {
      'format': kdf == null ? 'morphhealth-vault' : 'morphhealth-backup',
      'version': 1,
      'cipher': 'AES-256-GCM',
      'kdf': kdf,
    };
    final box = await AesGcm.with256bits().encrypt(
      clear,
      secretKey: SecretKey(key),
      nonce: randomBytes(12),
      aad: utf8.encode(jsonEncode(header)),
    );
    return {
      ...header,
      'nonce': base64Encode(box.nonce),
      'ciphertext': base64Encode(box.cipherText),
      'tag': base64Encode(box.mac.bytes),
    };
  }

  static Future<List<int>> open(
    Json envelope,
    List<int> key, {
    required bool backup,
  }) async {
    final expected = backup ? 'morphhealth-backup' : 'morphhealth-vault';
    if (envelope['format'] != expected ||
        envelope['version'] != 1 ||
        envelope['cipher'] != 'AES-256-GCM') {
      throw const FormatException('unsupported_encryption_format');
    }
    final header = {
      for (final k in ['format', 'version', 'cipher', 'kdf']) k: envelope[k],
    };
    final nonce = base64Decode(envelope['nonce']),
        tag = base64Decode(envelope['tag']);
    if (nonce.length != 12 || tag.length != 16) {
      throw const FormatException('invalid_envelope');
    }
    final box = SecretBox(
      base64Decode(envelope['ciphertext']),
      nonce: nonce,
      mac: Mac(tag),
    );
    try {
      return await AesGcm.with256bits().decrypt(
        box,
        secretKey: SecretKey(key),
        aad: utf8.encode(jsonEncode(header)),
      );
    } on SecretBoxAuthenticationError {
      throw const FormatException('authentication_failed');
    }
  }
}

class VaultStore {
  final Directory directory;
  final List<int> key;
  VaultStore(this.directory, this.key) {
    if (key.length != 32) throw const FormatException('key_must_be_32_bytes');
  }
  File get file => File('${directory.path}/health.mhv');
  Future<HealthData> read() async {
    if (!await file.exists()) return HealthData.empty();
    final path = file.path, secret = key;
    final document = await Isolate.run(() async {
      final envelope = object(
        jsonDecode(await File(path).readAsString()),
        'vault',
      );
      return jsonDecode(
        utf8.decode(await Envelope.open(envelope, secret, backup: false)),
      );
    });
    return HealthData.import(document);
  }

  Future<void> write(HealthData data) async {
    await directory.create(recursive: true);
    final document = data.export(DateTime.now()),
        secret = key,
        path = file.path;
    await Isolate.run(() async {
      final encoded = jsonEncode(
        await Envelope.seal(utf8.encode(jsonEncode(document)), secret),
      );
      final temp = File('$path.tmp');
      await temp.writeAsString(encoded, flush: true);
      if (Platform.isLinux) await Process.run('chmod', ['600', temp.path]);
      await temp.rename(path);
    });
  }
}

Future<Json> createBackup(Json document, String passphrase) async {
  if (passphrase.runes.length < 10) {
    throw const FormatException('passphrase_too_short');
  }
  return Isolate.run(() async {
    final salt = randomBytes(16);
    final kdf = {
      'name': 'PBKDF2-HMAC-SHA256',
      'iterations': backupIterations,
      'salt': base64Encode(salt),
    };
    final key = await Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: backupIterations,
      bits: 256,
    ).deriveKey(secretKey: SecretKey(utf8.encode(passphrase)), nonce: salt);
    return Envelope.seal(
      utf8.encode(jsonEncode(document)),
      await key.extractBytes(),
      kdf: kdf,
    );
  });
}

Future<HealthData> restoreBackup(Json envelope, String passphrase) async {
  final document = await Isolate.run(() async {
    if (envelope['format'] != 'morphhealth-backup') {
      throw const FormatException('unsupported_encryption_format');
    }
    final kdf = object(envelope['kdf'], 'kdf');
    if (kdf['name'] != 'PBKDF2-HMAC-SHA256' ||
        kdf['iterations'] != backupIterations) {
      throw const FormatException('unsupported_kdf');
    }
    final salt = base64Decode(kdf['salt']);
    if (salt.length != 16) throw const FormatException('invalid_salt');
    final key = await Pbkdf2(
      macAlgorithm: Hmac.sha256(),
      iterations: backupIterations,
      bits: 256,
    ).deriveKey(secretKey: SecretKey(utf8.encode(passphrase)), nonce: salt);
    return jsonDecode(
      utf8.decode(
        await Envelope.open(envelope, await key.extractBytes(), backup: true),
      ),
    );
  });
  return HealthData.import(document);
}
