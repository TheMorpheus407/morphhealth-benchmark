import 'dart:convert';

import 'package:morphhealth_core/morphhealth_core.dart';
import 'package:morphhealth_core/src/portable/example_document.dart';
import 'package:test/test.dart';

final _now = LocalDateTime.parse('2026-09-23T20:00:00+02:00');

// Small parameters keep the tests fast; the format stores them in the file.
const _fast = Argon2Params(memoryKib: 8 * 1024, iterations: 1, parallelism: 1);

Matcher _fails(String code) =>
    throwsA(isA<BackupException>().having((e) => e.code, 'code', code));

void main() {
  final document = exampleDocument();

  test(
    'a backup restores the complete document on a fresh installation',
    () async {
      final bytes = await BackupCodec.seal(
        document,
        'korrekt Pferd Batterie',
        createdAt: _now,
        params: _fast,
      );
      final restored = await BackupCodec.open(bytes, 'korrekt Pferd Batterie');
      expect(jsonEncode(restored), jsonEncode(document));

      // Fresh repository, as after a new installation.
      final repo = await HealthRepository.open(
        MemoryDataStore(),
        clock: FixedClock(_now),
      );
      final report = await PortableService(repo).importDocument(restored);
      expect(report.counts['intake'], 7);
      expect(repo.data.settings.onlineFoodSearch, OnlineFoodSearch.enabled);
      expect(repo.data.goals.energyKcal, 2100);
      expect(repo.data.food('food-haferflocken')!.favorite, isTrue);
    },
  );

  test('the file reveals no health data', () async {
    final bytes = await BackupCodec.seal(
      document,
      'korrekt Pferd Batterie',
      createdAt: _now,
      params: _fast,
    );
    final text = utf8.decode(bytes);
    final envelope = jsonDecode(text) as Map<String, dynamic>;
    expect(envelope.keys, [
      'format', 'version', 'created_at', 'app_version', 'kdf', 'cipher',
      'compression', 'data', //
    ]);
    expect(envelope['format'], 'morphhealth-backup');
    expect(envelope['cipher'], 'xchacha20-poly1305');
    expect((envelope['kdf'] as Map)['algorithm'], 'argon2id');
    for (final secret in [
      'Haferflocken',
      'Kopfschmerzen',
      'period',
      'intake',
      'weight_kg',
    ]) {
      expect(text.contains(secret), isFalse, reason: secret);
      expect(
        latin1
            .decode(base64.decode(envelope['data'] as String))
            .contains(secret),
        isFalse,
        reason: secret,
      );
    }
  });

  test('every backup uses a fresh salt and nonce', () async {
    final a = await BackupCodec.seal(
      document,
      'korrekt Pferd Batterie',
      createdAt: _now,
      params: _fast,
    );
    final b = await BackupCodec.seal(
      document,
      'korrekt Pferd Batterie',
      createdAt: _now,
      params: _fast,
    );
    final ea = jsonDecode(utf8.decode(a)) as Map<String, dynamic>;
    final eb = jsonDecode(utf8.decode(b)) as Map<String, dynamic>;
    expect((ea['kdf'] as Map)['salt'], isNot((eb['kdf'] as Map)['salt']));
    expect(ea['data'], isNot(eb['data']));
  });

  test('a wrong passphrase is refused', () async {
    final bytes = await BackupCodec.seal(
      document,
      'korrekt Pferd Batterie',
      createdAt: _now,
      params: _fast,
    );
    await expectLater(
      BackupCodec.open(bytes, 'korrekt Pferd Batteriee'),
      _fails('wrong_passphrase'),
    );
    await expectLater(BackupCodec.open(bytes, ''), _fails('wrong_passphrase'));
  });

  test('changing any part of the file makes it unreadable', () async {
    final bytes = await BackupCodec.seal(
      document,
      'korrekt Pferd Batterie',
      createdAt: _now,
      params: _fast,
    );
    Future<void> tampered(
      void Function(Map<String, dynamic> e) change,
      String code,
    ) async {
      final envelope = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
      change(envelope);
      await expectLater(
        BackupCodec.open(
          utf8.encode(jsonEncode(envelope)),
          'korrekt Pferd Batterie',
        ),
        _fails(code),
      );
    }

    await tampered(
      (e) => e['created_at'] = '2020-01-01T00:00:00',
      'wrong_passphrase',
    );
    await tampered((e) => e['app_version'] = '9.9.9', 'wrong_passphrase');
    await tampered((e) {
      final data = base64.decode(e['data'] as String);
      data[data.length ~/ 2] ^= 1;
      e['data'] = base64.encode(data);
    }, 'wrong_passphrase');
    await tampered(
      (e) => (e['kdf'] as Map)['iterations'] = 2,
      'wrong_passphrase',
    );
    await tampered((e) => e['version'] = 2, 'unsupported');
    await tampered((e) => e['cipher'] = 'aes-256-gcm', 'unsupported');
    await tampered(
      (e) => (e['kdf'] as Map)['memory_kib'] = 1 << 30,
      'unsupported',
    );
    await tampered((e) => e['format'] = 'something', 'not_a_backup');
    await tampered((e) => e.remove('data'), 'not_a_backup');
  });

  test('other files are recognized as "not a backup"', () async {
    await expectLater(
      BackupCodec.open(utf8.encode('Hallo'), 'korrekt Pferd Batterie'),
      _fails('not_a_backup'),
    );
    await expectLater(
      BackupCodec.open(
        utf8.encode(jsonEncode(document)),
        'korrekt Pferd Batterie',
      ),
      _fails('not_a_backup'),
    );
    await expectLater(
      BackupCodec.open(const [0xff, 0xfe, 0x00], 'x' * 12),
      _fails('not_a_backup'),
    );
  });

  test('short passphrases are refused', () async {
    await expectLater(
      BackupCodec.seal(document, 'kurz', createdAt: _now, params: _fast),
      _fails('weak_passphrase'),
    );
    expect(() => BackupCodec.checkPassphrase('12345678'), returnsNormally);
  });

  test('the header can be read without the passphrase', () async {
    final bytes = await BackupCodec.seal(
      document,
      'korrekt Pferd Batterie',
      createdAt: _now,
      params: _fast,
    );
    final header = BackupCodec.readHeader(bytes);
    expect(header.version, 1);
    expect(header.createdAt, _now);
    expect(header.appVersion, morphHealthVersion);
    expect(header.kdf.memoryKib, _fast.memoryKib);
  });

  test('default parameters work end to end', () async {
    final bytes = await BackupCodec.seal(
      {'format': 'morphhealth-export', 'version': 1},
      'ein langer Satz',
      createdAt: _now,
    );
    final header = BackupCodec.readHeader(bytes);
    expect(header.kdf.memoryKib, 65536);
    expect(header.kdf.iterations, 3);
    expect(header.kdf.parallelism, 4);
    expect(await BackupCodec.open(bytes, 'ein langer Satz'), {
      'format': 'morphhealth-export',
      'version': 1,
    });
  });

  test('file names', () {
    expect(
      BackupCodec.suggestedFileName(Day(2026, 11, 9)),
      'morphhealth-2026-11-09.mhbackup',
    );
  });
}
