import 'dart:convert';
import 'dart:io';
import 'package:morphhealth/core/contract.dart';
import 'package:morphhealth/core/engine.dart';
import 'package:morphhealth/core/food_api.dart';
import 'package:morphhealth/core/model.dart';
import 'package:morphhealth/core/nutrients.dart';
import 'package:morphhealth/core/storage.dart';

Future<void> main(List<String> args) async {
  RandomAccessFile? lock;
  try {
    final options = <String, String>{};
    const allowed = [
      '--data-dir',
      '--key-file',
      '--now',
      '--food-base-url',
      '--food-user-agent',
    ];
    for (var i = 0; i < args.length; i += 2) {
      if (!allowed.contains(args[i]) ||
          i + 1 >= args.length ||
          options.containsKey(args[i])) {
        throw const FormatException(
          'Usage: mh --data-dir ABS --key-file ABS [--now RFC3339] [--food-base-url HTTPS_ORIGIN] [--food-user-agent STRING]',
        );
      }
      options[args[i]] = args[i + 1];
    }
    final directory = options['--data-dir'], keyPath = options['--key-file'];
    if (directory == null ||
        keyPath == null ||
        !directory.startsWith('/') ||
        !keyPath.startsWith('/')) {
      throw const FormatException(
        'data-dir and key-file must be absolute paths',
      );
    }
    await Directory(directory).create(recursive: true);
    final canonical = await Directory(directory).resolveSymbolicLinks();
    final canonicalKey = await File(keyPath).resolveSymbolicLinks();
    if (canonicalKey == canonical || canonicalKey.startsWith('$canonical/')) {
      throw const FormatException('key-file must be outside data-dir');
    }
    final key = await File(canonicalKey).readAsBytes();
    if (key.length != 32) {
      throw const FormatException('key-file must contain 32 raw bytes');
    }
    lock = await File('$canonical/.lock').open(mode: FileMode.append);
    await lock.lock(FileLock.exclusive);
    DateTime? fixed;
    final now = options['--now'];
    if (now != null) {
      if (!RegExp(
            r'^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})$',
          ).hasMatch(now) ||
          DateTime.tryParse(now) == null) {
        throw const FormatException('--now requires RFC3339');
      }
      final wall = now.replaceFirst(RegExp(r'(Z|[+-]\d{2}:\d{2})$'), '');
      fixed = DateTime.parse(wall);
      atValue({'at': wall});
    }
    final engine = await HealthEngine.open(
      VaultStore(Directory(canonical), key),
      clock: BusinessClock(fixed),
    );
    final api = FoodApi(
      options['--food-base-url'] ??
          Platform.environment['MH_FOOD_BASE_URL'] ??
          'https://world.openfoodfacts.org',
      options['--food-user-agent'] ??
          Platform.environment['MH_FOOD_USER_AGENT'] ??
          'MorphHealth/1.0 (local maintenance)',
    );
    await for (final line
        in stdin.transform(utf8.decoder).transform(const LineSplitter())) {
      dynamic requestId;
      Json response;
      try {
        final request = object(jsonDecode(line), 'request');
        requestId = request['request_id'];
        if (!request.containsKey('request_id') ||
            (requestId is! String && requestId is! num && requestId != null)) {
          throw const FormatException('invalid_request_id');
        }
        dynamic result;
        switch (request['op']) {
          case 'describe':
            result = describeContract();
          case 'portable.export':
            if (request['ack_plaintext'] != true) {
              throw const FormatException('ack_plaintext_required');
            }
            result = engine.export();
          case 'portable.import':
            if (request['confirm_replace'] != true) {
              throw const FormatException('confirm_replace_required');
            }
            await engine.replace(request['document']);
            result = {
              'replaced': true,
              'counts': {for (final t in tableNames) t: engine.data[t].length},
            };
          case 'nutrition.day':
            textValue(request, 'date');
            result = engine.nutritionDay(request['date']);
          case 'cycle.forecast':
            textValue(request, 'on');
            result = engine.cycleForecast(request['on']);
          case 'food.search':
            textValue(request, 'q');
            if (request['page'] is! int || request['page'] < 1) {
              throw const FormatException('invalid_page');
            }
            result = await api.search(request['q'], request['page']);
          case 'food.lookup':
            textValue(request, 'barcode');
            result = await api.lookup(request['barcode']);
          default:
            throw const FormatException('unknown_op');
        }
        response = {'request_id': requestId, 'ok': true, 'data': result};
      } catch (e) {
        final code = e is FormatException
            ? e.message
            : e is FoodApiError
            ? e.code
            : 'operation_failed';
        response = {
          'request_id': requestId,
          'ok': false,
          'error': {'code': code, 'message': code},
        };
      }
      stdout.writeln(jsonEncode(response));
      await stdout.flush();
    }
  } catch (e) {
    stderr.writeln(
      e is FormatException
          ? e.message
          : 'MorphHealth could not open the data store: $e',
    );
    exitCode = 2;
  } finally {
    if (lock != null) {
      await lock.unlock();
      await lock.close();
    }
  }
}
