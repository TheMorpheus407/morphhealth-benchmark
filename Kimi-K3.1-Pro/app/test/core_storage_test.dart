import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphhealth/core/encrypted_store.dart';
import 'package:morphhealth/core/health.dart';
import 'package:morphhealth/core/portable.dart';

import 'core_fixtures.dart';
import 'core_test_io.dart';

void main() {
  late Directory temporary;

  setUp(() => temporary = createAgentTestDirectory('storage_'));
  tearDown(() => deleteAgentTestDirectory(temporary));

  List<int> key([int delta = 0]) =>
      List.generate(32, (index) => (index + delta) & 0xff);

  group('EncryptedFileStore', () {
    test(
      'persistiert AES-GCM ohne Klartextnamen und öffnet denselben Bestand erneut',
      () async {
        final file = File('${temporary.path}/data/state.enc');
        final store = EncryptedFileStore(file, key());
        expect(await store.load(), isNull);
        final state = fullTestState();
        await store.save(state);
        expect(file.existsSync(), isTrue);
        expect(File('${file.path}.tmp').existsSync(), isFalse);
        final raw = file.readAsStringSync();
        final envelope = jsonDecode(raw) as Map<String, dynamic>;
        expect(envelope['format'], EncryptedFileStore.format);
        expect(base64Decode(envelope['nonce_b64'] as String), hasLength(12));
        expect(base64Decode(envelope['mac_b64'] as String), hasLength(16));
        expect(base64Decode(envelope['ciphertext_b64'] as String), isNotEmpty);
        for (final secret in [
          'Testmüsli',
          'Testmarke',
          'Kopfschmerz',
          'Frühstück draußen',
          'Zyklusnotiz',
          'schema_version',
          'nutrients_per_100',
        ]) {
          expect(raw.contains(secret), isFalse, reason: secret);
        }
        final reopened = EncryptedFileStore(file, key());
        expect((await reopened.load())?.toJson(), state.toJson());

        final replacement = fullTestState().copyWith(
          foods: [testFood(id: 'replacement', name: 'Geheimer Ersatzname')],
          intakes: const [],
        );
        await reopened.save(replacement);
        expect(File('${file.path}.tmp').existsSync(), isFalse);
        expect((await store.load())?.toJson(), replacement.toJson());
        expect(
          file.readAsStringSync().contains('Geheimer Ersatzname'),
          isFalse,
        );
      },
    );

    test(
      'falscher Schlüssel und manipulierter Ciphertext werden authentisch abgelehnt',
      () async {
        final file = File('${temporary.path}/state.enc');
        await EncryptedFileStore(file, key()).save(fullTestState());
        await expectLater(
          EncryptedFileStore(file, key(1)).load(),
          throwsA(isA<SecretBoxAuthenticationError>()),
        );
        final envelope =
            jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
        final ciphertext = base64Decode(envelope['ciphertext_b64'] as String);
        ciphertext[ciphertext.length ~/ 2] ^= 1;
        envelope['ciphertext_b64'] = base64Encode(ciphertext);
        file.writeAsStringSync(jsonEncode(envelope), flush: true);
        await expectLater(
          EncryptedFileStore(file, key()).load(),
          throwsA(isA<SecretBoxAuthenticationError>()),
        );
      },
    );

    test('Schlüssellänge, Format und clear werden geprüft', () async {
      expect(
        () => EncryptedFileStore(File('${temporary.path}/x'), key().sublist(1)),
        throwsArgumentError,
      );
      expect(
        () => EncryptedFileStore(File('${temporary.path}/x'), [...key(), 1]),
        throwsArgumentError,
      );
      final file = File('${temporary.path}/state.enc');
      file.writeAsStringSync(jsonEncode({'format': 'other'}));
      await expectLater(
        EncryptedFileStore(file, key()).load(),
        throwsFormatException,
      );
      await EncryptedFileStore(file, key()).save(AppState.initial());
      final temporaryFile = File('${file.path}.tmp');
      temporaryFile.writeAsStringSync('partial');
      await EncryptedFileStore(file, key()).clear();
      expect(file.existsSync(), isFalse);
      expect(temporaryFile.existsSync(), isFalse);
      expect(await EncryptedFileStore(file, key()).load(), isNull);
      expect(randomBytes(16), hasLength(16));
      expect(randomBytes(0), isEmpty);
    });

    test(
      'inDirectory verwendet state.enc und die rohe Schlüsseldatei',
      () async {
        final keyFile = File('${temporary.path}/key.bin');
        keyFile.writeAsBytesSync(key(), flush: true);
        final directory = Directory('${temporary.path}/nested/data');
        final store = await EncryptedFileStore.inDirectory(directory, keyFile);
        expect(store.file.path, '${directory.path}/state.enc');
        expect(directory.existsSync(), isTrue);
        await store.save(AppState.initial());
        expect(store.file.existsSync(), isTrue);
      },
    );
  });

  group('Portable', () {
    test('vollständiger Roundtrip inklusive Formatmetadaten', () {
      final state = fullTestState();
      final exportedAt = DateTime.parse('2026-04-05T12:30:00+02:00');
      final document = createPortableDocument(state, exportedAt);
      expect(document['format'], portableFormat);
      expect(document['app_version'], '1.0.0');
      expect(document['exported_at'], '2026-04-05T10:30:00.000Z');
      final restored = parsePortableDocument(cloneJson(document));
      expect(restored.toJson(), state.toJson());
      expect(
        parsePortableDocument(portableExample()).toJson(),
        AppState.initial().toJson(),
      );
    });

    test(
      'falsches Format, ungültige Metadaten und ungültiger State werden abgelehnt',
      () {
        final valid = createPortableDocument(
          fullTestState(),
          DateTime.utc(2026),
        );
        for (final mutate in [
          (Map<String, dynamic> json) => json['format'] = 'other',
          (Map<String, dynamic> json) => json['app_version'] = '',
          (Map<String, dynamic> json) =>
              json['exported_at'] = '2026-01-01T00:00:00',
          (Map<String, dynamic> json) => json['state'] = null,
          (Map<String, dynamic> json) => json['state']['schema_version'] = 2,
        ]) {
          final document = cloneJson(valid) as Map<String, dynamic>;
          mutate(document);
          expect(() => parsePortableDocument(document), throwsFormatException);
        }
        expect(() => parsePortableDocument(const []), throwsFormatException);
      },
    );
  });

  group('BackupCodec', () {
    test(
      'verschlüsselter Backup-Roundtrip enthält keine Klartextdaten',
      () async {
        final document = createPortableDocument(
          fullTestState(),
          DateTime.utc(2026, 5, 1),
        );
        final envelope = await BackupCodec.encrypt(
          document,
          'richtige Passphrase',
        );
        expect(envelope['format'], backupFormat);
        expect(envelope['cipher'], 'AES-256-GCM');
        final kdf = envelope['kdf'] as Map<String, dynamic>;
        expect(kdf['name'], 'PBKDF2-HMAC-SHA256');
        expect(kdf['iterations'], backupIterations);
        expect(base64Decode(kdf['salt_b64'] as String), hasLength(16));
        expect(base64Decode(envelope['nonce_b64'] as String), hasLength(12));
        expect(base64Decode(envelope['mac_b64'] as String), hasLength(16));
        final raw = jsonEncode(envelope);
        expect(raw.contains('Testmüsli'), isFalse);
        expect(raw.contains('Kopfschmerz'), isFalse);
        expect(raw.contains('richtige Passphrase'), isFalse);
        final decrypted = await BackupCodec.decrypt(
          cloneJson(envelope),
          'richtige Passphrase',
        );
        expect(decrypted, document);
        expect(
          parsePortableDocument(decrypted).toJson(),
          fullTestState().toJson(),
        );
      },
    );

    test(
      'falsche Passphrase und Ciphertext-Manipulation werden abgelehnt',
      () async {
        final document = createPortableDocument(
          fullTestState(),
          DateTime.utc(2026),
        );
        final envelope = await BackupCodec.encrypt(document, 'richtig');
        await expectLater(
          BackupCodec.decrypt(cloneJson(envelope), 'falsch'),
          throwsA(isA<SecretBoxAuthenticationError>()),
        );
        final manipulated = cloneJson(envelope) as Map<String, dynamic>;
        final bytes = base64Decode(manipulated['ciphertext_b64'] as String);
        bytes[0] ^= 0x80;
        manipulated['ciphertext_b64'] = base64Encode(bytes);
        await expectLater(
          BackupCodec.decrypt(manipulated, 'richtig'),
          throwsA(isA<SecretBoxAuthenticationError>()),
        );
      },
    );

    test(
      'ungültige Dokumente und Backup-Metadaten werden vor bzw. ohne Entschlüsselung abgelehnt',
      () async {
        final document = createPortableDocument(
          AppState.initial(),
          DateTime.utc(2026),
        );
        await expectLater(
          BackupCodec.encrypt(document, ''),
          throwsArgumentError,
        );
        await expectLater(
          BackupCodec.encrypt({'format': 'wrong'}, 'pass'),
          throwsFormatException,
        );
        final envelope = await BackupCodec.encrypt(document, 'pass');
        for (final mutate in [
          (Map<String, dynamic> json) => json['format'] = 'wrong',
          (Map<String, dynamic> json) => json['cipher'] = 'AES-CBC',
          (Map<String, dynamic> json) => json['kdf']['name'] = 'other',
          (Map<String, dynamic> json) => json['kdf']['iterations'] = 99999,
          (Map<String, dynamic> json) => json['kdf']['iterations'] = 5000001,
          (Map<String, dynamic> json) =>
              json['kdf']['salt_b64'] = base64Encode(List.filled(15, 1)),
          (Map<String, dynamic> json) =>
              json['nonce_b64'] = base64Encode(List.filled(11, 1)),
          (Map<String, dynamic> json) =>
              json['mac_b64'] = base64Encode(List.filled(15, 1)),
        ]) {
          final candidate = cloneJson(envelope) as Map<String, dynamic>;
          mutate(candidate);
          await expectLater(
            BackupCodec.decrypt(candidate, 'pass'),
            throwsFormatException,
          );
        }
        await expectLater(
          BackupCodec.decrypt(const [], 'pass'),
          throwsFormatException,
        );
      },
    );
  });
}
