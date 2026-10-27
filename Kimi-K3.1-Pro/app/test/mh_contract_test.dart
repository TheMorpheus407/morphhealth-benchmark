import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:morphhealth/core/health.dart';
import 'package:morphhealth/core/nutrition.dart';
import 'package:morphhealth/core/portable.dart';

import 'core_fixtures.dart';
import 'core_test_io.dart';

void main() {
  test(
    'echter mh JSON-Lines-Vertrag, atomarer Import und native Persistenz',
    () async {
      final temporary = createAgentTestDirectory('mh_contract_');
      addTearDown(() => deleteAgentTestDirectory(temporary));
      final keyFile = File('${temporary.path}/key.bin');
      keyFile.writeAsBytesSync(
        List.generate(32, (index) => index),
        flush: true,
      );
      final dataDirectory = Directory('${temporary.path}/data');
      final arguments = <String>[
        '--data-dir',
        dataDirectory.absolute.path,
        '--key-file',
        keyFile.absolute.path,
        '--now',
        '2026-01-20T00:00:00Z',
        '--food-base-url',
        'https://localhost:8788',
        '--food-user-agent',
        'MorphHealth contract tests',
      ];
      MhClient? client;
      MhClient? restarted;
      try {
        client = await MhClient.start(arguments);
        await client.writeWithoutResponse('   ');

        final described = await client.request({
          'request_id': 'describe',
          'op': 'describe',
        });
        expectSuccess(described, 'describe');
        final description = described['data'] as Map<String, dynamic>;
        expect(description['protocol'], contains('version 1'));
        expect(
          (description['operations'] as Map<String, dynamic>).keys,
          containsAll([
            'describe',
            'portable.export',
            'portable.import',
            'nutrition.day',
            'cycle.forecast',
            'food.search',
            'food.lookup',
          ]),
        );
        expect(
          (description['formats'] as Map<String, dynamic>)['nutrient_units'],
          hasLength(31),
        );
        parsePortableDocument(description['portable_import_example']);

        final missingAck = await client.request({
          'request_id': 'ack',
          'op': 'portable.export',
        });
        expectError(missingAck, 'ack', 'invalid_request');
        final initialExport = await client.request({
          'request_id': 'initial-export',
          'op': 'portable.export',
          'ack_plaintext': true,
        });
        expectSuccess(initialExport, 'initial-export');
        final initialDocument = initialExport['data'] as Map<String, dynamic>;
        expect(initialDocument['exported_at'], '2026-01-20T00:00:00.000Z');
        expect(
          (initialDocument['state'] as Map<String, dynamic>)['foods'],
          isEmpty,
        );

        final initialNutrition = await client.request({
          'request_id': 'empty-day',
          'op': 'nutrition.day',
          'date': '2026-01-15',
        });
        expectSuccess(initialNutrition, 'empty-day');
        expect(
          (initialNutrition['data'] as Map<String, dynamic>)['totals'],
          hasLength(31),
        );
        expect(
          (initialNutrition['data']
              as Map<String, dynamic>)['food_entry_count'],
          0,
        );
        final initialCycle = await client.request({
          'request_id': 'empty-cycle',
          'op': 'cycle.forecast',
          'on': '2026-01-20',
        });
        expectSuccess(initialCycle, 'empty-cycle');
        expect(
          (initialCycle['data'] as Map<String, dynamic>)['available'],
          isFalse,
        );
        expect(
          (initialCycle['data']
              as Map<String, dynamic>)['forecast_enabled_in_app'],
          isTrue,
        );

        expectError(
          await client.request({
            'request_id': 'unknown',
            'op': 'not.an.operation',
          }),
          'unknown',
          'invalid_request',
        );
        expectError(await client.raw('not-json'), null, 'invalid_request');
        expectError(
          await client.request({'op': 'describe'}),
          null,
          'invalid_request',
        );

        final importedState = fullTestState().copyWith(
          periods: [
            testPeriod(),
            testPeriod(id: 'period-2', start: '2026-01-29', end: '2026-02-02'),
          ],
        );
        final document = createPortableDocument(
          importedState,
          DateTime.utc(2026, 1, 20),
        );
        expectError(
          await client.request({
            'request_id': 'unconfirmed',
            'op': 'portable.import',
            'document': document,
          }),
          'unconfirmed',
          'invalid_request',
        );
        final invalidDocument = createPortableDocument(
          testState(intakes: [testFoodIntake(id: 'dangling')]),
          DateTime.utc(2026, 1, 20),
        );
        expectError(
          await client.request({
            'request_id': 'invalid-import',
            'op': 'portable.import',
            'document': invalidDocument,
            'confirm_replace': true,
          }),
          'invalid-import',
          'invalid_request',
        );
        final afterRejected = await client.request({
          'request_id': 'after-rejected',
          'op': 'portable.export',
          'ack_plaintext': true,
        });
        expect(
          (afterRejected['data'] as Map<String, dynamic>)['state'],
          AppState.initial().toJson(),
        );

        final imported = await client.request({
          'request_id': 'import',
          'op': 'portable.import',
          'document': document,
          'confirm_replace': true,
        });
        expectSuccess(imported, 'import');
        expect(imported['data'], {
          'replaced': true,
          'counts': {
            'foods': 1,
            'intakes': 3,
            'periods': 2,
            'weights': 1,
            'symptoms': 1,
          },
        });
        final nutrition = await client.request({
          'request_id': 'day',
          'op': 'nutrition.day',
          'date': '2026-01-15',
        });
        expectSuccess(nutrition, 'day');
        final day = nutrition['data'] as Map<String, dynamic>;
        expect(day['water_ml'], 250);
        expect(day['food_entry_count'], 1);
        expect((day['totals'] as Map<String, dynamic>)['calories'], 200);
        expect((day['totals'] as Map<String, dynamic>)['caffeine'], 95);
        expect(
          (day['known_food_entries_per_nutrient']
              as Map<String, dynamic>)['caffeine'],
          1,
        );
        expect((day['goals'] as Map<String, dynamic>)['water_ml'], 2000);
        expect(day['entries'], hasLength(3));
        expect(
          (day['nutrient_units'] as Map<String, dynamic>).keys.toSet(),
          Nutrient.values.map((item) => item.id).toSet(),
        );

        final cycle = await client.request({
          'request_id': 'cycle',
          'op': 'cycle.forecast',
          'on': '2026-02-15',
        });
        expectSuccess(cycle, 'cycle');
        final forecast = cycle['data'] as Map<String, dynamic>;
        expect(forecast['available'], isTrue);
        expect(forecast['sample_size'], 1);
        expect(forecast['cycle_lengths_days'], [28]);
        expect(forecast['predicted_start'], '2026-02-26');
        expect(forecast['forecast_enabled_in_app'], isFalse);
        expectError(
          await client.request({
            'request_id': 'offline',
            'op': 'food.search',
            'q': 'Müsli',
            'page': 1,
          }),
          'offline',
          'online_disabled',
        );

        final exported = await client.request({
          'request_id': 'export',
          'op': 'portable.export',
          'ack_plaintext': true,
        });
        expect(
          (exported['data'] as Map<String, dynamic>)['state'],
          importedState.toJson(),
        );
        final encryptedFile = File('${dataDirectory.path}/state.enc');
        expect(encryptedFile.existsSync(), isTrue);
        final encryptedText = encryptedFile.readAsStringSync();
        expect(encryptedText.contains('Testmüsli'), isFalse);
        expect(encryptedText.contains('Kopfschmerz'), isFalse);
        expect(jsonDecode(encryptedText), isA<Map<String, dynamic>>());
        await client.finish();

        restarted = await MhClient.start(arguments);
        final persisted = await restarted.request({
          'request_id': 'persisted',
          'op': 'portable.export',
          'ack_plaintext': true,
        });
        expectSuccess(persisted, 'persisted');
        expect(
          (persisted['data'] as Map<String, dynamic>)['state'],
          importedState.toJson(),
        );
        await restarted.finish();
      } finally {
        await client?.stop();
        await restarted?.stop();
      }
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test(
    'mh lehnt ungültige absolute Pfade und fehlende Schlüssel ohne stdout aus',
    () async {
      final temporary = createAgentTestDirectory('mh_args_');
      addTearDown(() => deleteAgentTestDirectory(temporary));
      final root = projectRoot();
      final environment = <String, String>{
        'PUB_CACHE': '$root/.pub-cache',
        'TMPDIR': '$root/.tmp',
      };
      final invalidPath = await Process.run(
        '$root/mh',
        ['--data-dir', 'relative', '--key-file', '${temporary.path}/key.bin'],
        workingDirectory: root,
        environment: environment,
      );
      expect(invalidPath.exitCode, 64);
      expect(invalidPath.stdout, isEmpty);
      expect(invalidPath.stderr, contains('Usage: mh'));
      final missingKey = await Process.run(
        '$root/mh',
        [
          '--data-dir',
          '${temporary.path}/data',
          '--key-file',
          '${temporary.path}/missing.bin',
        ],
        workingDirectory: root,
        environment: environment,
      );
      expect(missingKey.exitCode, 1);
      expect(missingKey.stdout, isEmpty);
      expect(missingKey.stderr, contains('cannot open local data'));
    },
  );
}

void expectSuccess(Map<String, dynamic> response, Object? requestId) {
  expect(response.keys.toSet(), {'request_id', 'ok', 'data'});
  expect(response['request_id'], requestId);
  expect(response['ok'], isTrue);
  expect(response['data'], isNotNull);
}

void expectError(
  Map<String, dynamic> response,
  Object? requestId,
  String code,
) {
  expect(response.keys.toSet(), {'request_id', 'ok', 'error'});
  expect(response['request_id'], requestId);
  expect(response['ok'], isFalse);
  final error = response['error'] as Map<String, dynamic>;
  expect(error.keys.toSet(), {'code', 'message'});
  expect(error['code'], code);
  expect(error['message'], isNotEmpty);
}

class MhClient {
  MhClient._(this.process)
    : output = StreamIterator(
        process.stdout.transform(utf8.decoder).transform(const LineSplitter()),
      ) {
    process.stderr
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(stderrLines.add);
  }

  static Future<MhClient> start(List<String> arguments) async {
    final root = projectRoot();
    final process = await Process.start(
      '$root/mh',
      arguments,
      workingDirectory: root,
      environment: {'PUB_CACHE': '$root/.pub-cache', 'TMPDIR': '$root/.tmp'},
    );
    return MhClient._(process);
  }

  final Process process;
  final StreamIterator<String> output;
  final List<String> stderrLines = [];
  bool finished = false;

  Future<void> writeWithoutResponse(String line) async {
    process.stdin.writeln(line);
    await process.stdin.flush();
  }

  Future<Map<String, dynamic>> request(Map<String, dynamic> request) =>
      raw(jsonEncode(request));

  Future<Map<String, dynamic>> raw(String line) async {
    if (finished) throw StateError('mh client is already closed');
    await writeWithoutResponse(line);
    final hasLine = await output.moveNext().timeout(
      const Duration(seconds: 30),
    );
    if (!hasLine) {
      throw StateError(
        'mh closed stdout before answering; stderr: ${stderrLines.join('\n')}',
      );
    }
    final decoded = jsonDecode(output.current);
    if (decoded is! Map<String, dynamic>) {
      throw StateError('mh stdout was not a JSON object: ${output.current}');
    }
    return decoded;
  }

  Future<void> finish() async {
    if (finished) return;
    await process.stdin.close();
    final hasExtraLine = await output.moveNext().timeout(
      const Duration(seconds: 30),
    );
    expect(hasExtraLine, isFalse, reason: hasExtraLine ? output.current : null);
    expect(
      await process.exitCode.timeout(const Duration(seconds: 30)),
      0,
      reason: stderrLines.join('\n'),
    );
    finished = true;
  }

  Future<void> stop() async {
    if (finished) return;
    process.kill();
    await process.exitCode;
    finished = true;
  }
}
