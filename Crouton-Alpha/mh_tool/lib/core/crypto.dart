import "dart:convert";
import "dart:math";
import "dart:typed_data";
import "package:pointycastle/export.dart";

class CryptoBox {
  static Uint8List randomBytes(int n) {
    final r = Random.secure();
    return Uint8List.fromList(List.generate(n, (_) => r.nextInt(256)));
  }
  static String b64(List<int> b) => base64Encode(b);
  static List<int> unb64(String s) => base64Decode(s);

  static Map<String, dynamic> encryptWithKey(Uint8List key, String plaintext) {
    if (key.length != 32) throw ArgumentError("key must be 32 bytes");
    final nonce = randomBytes(12);
    final cipher = GCMBlockCipher(AESEngine());
    cipher.init(true, AEADParameters(KeyParameter(key), 128, nonce, Uint8List(0)));
    final plain = Uint8List.fromList(utf8.encode(plaintext));
    final out = Uint8List(cipher.getOutputSize(plain.length));
    var len = cipher.processBytes(plain, 0, plain.length, out, 0);
    len += cipher.doFinal(out, len);
    return {"nonce": b64(nonce), "data": b64(out.sublist(0, len))};
  }

  static String decryptWithKey(Uint8List key, String nonceB64, String dataB64) {
    if (key.length != 32) throw ArgumentError("key must be 32 bytes");
    final nonce = Uint8List.fromList(unb64(nonceB64));
    final data = Uint8List.fromList(unb64(dataB64));
    final cipher = GCMBlockCipher(AESEngine());
    cipher.init(false, AEADParameters(KeyParameter(key), 128, nonce, Uint8List(0)));
    final out = Uint8List(cipher.getOutputSize(data.length));
    var len = cipher.processBytes(data, 0, data.length, out, 0);
    try { len += cipher.doFinal(out, len); } catch (e) { throw const FormatException("decryption/authentication failed"); }
    return utf8.decode(out.sublist(0, len));
  }

  static Uint8List derivePassphraseKey(String passphrase, Uint8List salt) {
    final deriv = PBKDF2KeyDerivator(HMac(SHA256Digest(), 64));
    deriv.init(Pbkdf2Parameters(salt, 200000, 256));
    final out = deriv.process(Uint8List.fromList(utf8.encode(passphrase)));
    if (out.length == 32) return out;
    return Uint8List.sublistView(out, 0, 32);
  }

  static Map<String, dynamic> encryptPassphrase(String passphrase, String plaintext) {
    final salt = randomBytes(16);
    final key = derivePassphraseKey(passphrase, salt);
    final e = encryptWithKey(key, plaintext);
    return {"format": "morphhealth-backup", "version": 1, "cipher": "AES-256-GCM",
      "kdf": "PBKDF2-HMAC-SHA256", "iterations": 200000, "salt": b64(salt),
      "nonce": e["nonce"], "data": e["data"]};
  }

  static String decryptPassphrase(String passphrase, Map<String, dynamic> doc) {
    if (doc["format"] != "morphhealth-backup") throw const FormatException("not a morphhealth-backup");
    final salt = Uint8List.fromList(unb64(doc["salt"] as String));
    final key = derivePassphraseKey(passphrase, salt);
    return decryptWithKey(key, doc["nonce"] as String, doc["data"] as String);
  }
}
