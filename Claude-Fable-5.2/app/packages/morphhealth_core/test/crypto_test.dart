import 'dart:convert';
import 'dart:typed_data';

import 'package:cryptography/cryptography.dart';
import 'package:cryptography/dart.dart';
import 'package:morphhealth_core/morphhealth_core.dart';
import 'package:test/test.dart';

void main() {
  group('published test vectors', () {
    test('XChaCha20-Poly1305 (draft-irtf-cfrg-xchacha-03, A.3.1)', () {
      const cipher = DartXchacha20.poly1305Aead();
      final key = hexDecode(
        '808182838485868788898a8b8c8d8e8f909192939495969798999a9b9c9d9e9f',
      );
      final nonce = hexDecode(
        '404142434445464748494a4b4c4d4e4f5051525354555657',
      );
      final aad = hexDecode('50515253c0c1c2c3c4c5c6c7');
      final plaintext = utf8.encode(
        "Ladies and Gentlemen of the class of '99: If I could offer you "
        'only one tip for the future, sunscreen would be it.',
      );
      final box = cipher.encryptSync(
        plaintext,
        secretKey: SecretKeyData(key),
        nonce: nonce,
        aad: aad,
      );
      expect(
        hexEncode(box.cipherText),
        'bd6d179d3e83d43b9576579493c0e939572a1700252bfaccbed2902c21396cbb'
        '731c7f1b0b4aa6440bf3a82f4eda7e39ae64c6708c54c216cb96b72e1213b452'
        '2f8c9ba40db5d945b11b69b982c1bb9e3f3fac2bc369488f76b2383565d3fff9'
        '21f9664c97637da9768812f615c68b13b52e',
      );
      expect(hexEncode(box.mac.bytes), 'c0875924c1c7987947deafd8780acf49');

      // The same vector through the wrapper used by store and backup.
      final sealed = Uint8List.fromList([
        ...nonce,
        ...box.cipherText,
        ...box.mac.bytes,
      ]);
      expect(Aead.open(key, sealed, aad: aad), plaintext);
    });

    test('HKDF-SHA-256 (RFC 5869, test case 1)', () async {
      final hkdf = DartHkdf(hmac: Hmac.sha256(), outputLength: 42);
      final out = await hkdf.deriveKey(
        secretKey: SecretKey(List<int>.filled(22, 0x0b)),
        nonce: hexDecode('000102030405060708090a0b0c'),
        info: hexDecode('f0f1f2f3f4f5f6f7f8f9'),
      );
      expect(
        hexEncode(out.bytes),
        '3cb25f25faacd57a90434f64d0362f2a2d2d0a90cf1a5a4c5db02d56ecc4c5bf'
        '34007208d5b887185865',
      );
    });

    test('Argon2id (RFC 9106, section 5.3)', () async {
      const algorithm = DartArgon2id(
        parallelism: 4,
        memory: 32,
        iterations: 3,
        hashLength: 32,
        maxIsolates: 0,
      );
      final key = await algorithm.deriveKey(
        secretKey: SecretKey(List<int>.filled(32, 1)),
        nonce: List<int>.filled(16, 2),
        optionalSecret: List<int>.filled(8, 3),
        associatedData: List<int>.filled(12, 4),
      );
      expect(
        hexEncode(await key.extractBytes()),
        '0d640df58d78766c08c037a34a8b53c9d01ef0452d75b65eb52520e96b01e659',
      );
    });
  });

  group('Aead', () {
    final key = Uint8List.fromList(List<int>.generate(32, (i) => i));
    final aad = utf8.encode('context');

    test('round trip with fresh nonces', () {
      final message = utf8.encode('Kopfschmerzen, Stärke 4');
      final a = Aead.seal(key, message, aad: aad);
      final b = Aead.seal(key, message, aad: aad);
      expect(a.length, message.length + Aead.overhead);
      expect(a, isNot(b), reason: 'nonces must differ');
      expect(Aead.open(key, a, aad: aad), message);
      expect(Aead.open(key, b, aad: aad), message);
    });

    test('detects every kind of modification', () {
      final sealed = Aead.seal(key, utf8.encode('geheim'), aad: aad);
      for (final index in [0, 23, 24, sealed.length - 17, sealed.length - 1]) {
        final copy = Uint8List.fromList(sealed)..[index] ^= 0x01;
        expect(
          () => Aead.open(key, copy, aad: aad),
          throwsA(isA<AuthenticationFailure>()),
          reason: 'byte $index',
        );
      }
      expect(
        () => Aead.open(key, sealed, aad: utf8.encode('other')),
        throwsA(isA<AuthenticationFailure>()),
      );
      final otherKey = Uint8List.fromList(key)..[0] ^= 1;
      expect(
        () => Aead.open(otherKey, sealed, aad: aad),
        throwsA(isA<AuthenticationFailure>()),
      );
      expect(
        () => Aead.open(key, Uint8List.sublistView(sealed, 0, 10), aad: aad),
        throwsA(isA<AuthenticationFailure>()),
      );
    });

    test('refuses keys of the wrong length', () {
      expect(
        () => Aead.seal(Uint8List(31), const [1], aad: const []),
        throwsArgumentError,
      );
    });
  });

  test('hkdfSha256 separates purposes', () async {
    final master = List<int>.filled(32, 7);
    final a = await hkdfSha256(master, info: 'morphhealth/store/v1');
    final b = await hkdfSha256(master, info: 'morphhealth/other/v1');
    expect(a.length, 32);
    expect(a, isNot(b));
    expect(a, await hkdfSha256(master, info: 'morphhealth/store/v1'));
  });

  test(
    'argon2id derives stable keys that depend on salt and passphrase',
    () async {
      const params = Argon2Params(
        memoryKib: 8 * 1024,
        iterations: 1,
        parallelism: 1,
      );
      final salt = List<int>.filled(16, 9);
      final a = await argon2id(utf8.encode('richtig'), salt, params: params);
      expect(a, await argon2id(utf8.encode('richtig'), salt, params: params));
      expect(
        a,
        isNot(await argon2id(utf8.encode('falsch'), salt, params: params)),
      );
      expect(
        a,
        isNot(
          await argon2id(
            utf8.encode('richtig'),
            List<int>.filled(16, 8),
            params: params,
          ),
        ),
      );
    },
  );

  test('default Argon2id parameters follow RFC 9106 (second option)', () {
    expect(Argon2Params.standard.memoryKib, 64 * 1024);
    expect(Argon2Params.standard.iterations, 3);
    expect(Argon2Params.standard.parallelism, 4);
    expect(Argon2Params.standard.isAcceptable, isTrue);
    expect(
      const Argon2Params(
        memoryKib: 1 << 30,
        iterations: 3,
        parallelism: 4,
      ).isAcceptable,
      isFalse,
    );
  });
}
