import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

import 'health.dart';
import 'repository.dart';
import 'utils.dart';

class EncryptedFileStore implements StateStore {
  EncryptedFileStore(this.file, List<int> keyBytes)
    : _keyBytes = List.unmodifiable(keyBytes) {
    if (keyBytes.length != 32)
      throw ArgumentError('The database key must contain 32 bytes');
  }

  static const format = 'morphhealth.encrypted-state.v1';
  static final _aad = utf8.encode(format);
  final File file;
  final List<int> _keyBytes;
  final _cipher = AesGcm.with256bits();

  static Future<EncryptedFileStore> inDirectory(
    Directory directory,
    File keyFile,
  ) async {
    await directory.create(recursive: true);
    final key = await keyFile.readAsBytes();
    return EncryptedFileStore(File('${directory.path}/state.enc'), key);
  }

  @override
  Future<AppState?> load() async {
    if (!await file.exists()) return null;
    final envelope = jsonMap(
      jsonDecode(await file.readAsString()),
      'encrypted_state',
    );
    if (envelope['format'] != format)
      throw const FormatException('Unknown encrypted state format');
    final nonce = base64Decode(jsonString(envelope['nonce_b64'], 'nonce_b64'));
    final ciphertext = base64Decode(
      jsonString(envelope['ciphertext_b64'], 'ciphertext_b64'),
    );
    final mac = base64Decode(jsonString(envelope['mac_b64'], 'mac_b64'));
    final clearText = await _cipher.decrypt(
      SecretBox(ciphertext, nonce: nonce, mac: Mac(mac)),
      secretKey: SecretKey(_keyBytes),
      aad: _aad,
    );
    return AppState.fromJson(jsonDecode(utf8.decode(clearText)));
  }

  @override
  Future<void> save(AppState state) async {
    await file.parent.create(recursive: true);
    final box = await _cipher.encrypt(
      utf8.encode(jsonEncode(state.toJson())),
      secretKey: SecretKey(_keyBytes),
      aad: _aad,
    );
    final envelope = jsonEncode({
      'format': format,
      'nonce_b64': base64Encode(box.nonce),
      'ciphertext_b64': base64Encode(box.cipherText),
      'mac_b64': base64Encode(box.mac.bytes),
    });
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(envelope, flush: true);
    await temporary.rename(file.path);
  }

  @override
  Future<void> clear() async {
    if (await file.exists()) await file.delete();
    final temporary = File('${file.path}.tmp');
    if (await temporary.exists()) await temporary.delete();
  }
}

List<int> randomBytes(int length) {
  final random = Random.secure();
  return List.generate(length, (_) => random.nextInt(256));
}
