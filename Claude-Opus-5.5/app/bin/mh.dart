// The MorphHealth maintenance process: a JSON-Lines interface to the data and
// functions of the app (see README.md, "Wartungszugang").
//
//   mh --data-dir ABS --key-file ABS [--now RFC3339]
//      [--food-base-url HTTPS_ORIGIN] [--food-user-agent STRING]

import 'dart:convert';
import 'dart:io';

import 'package:morphhealth/core/cli/protocol.dart';
import 'package:morphhealth/core/food/off_client.dart';
import 'package:morphhealth/core/l10n/format.dart';
import 'package:morphhealth/core/service/morphhealth_service.dart';
import 'package:morphhealth/core/service/repository.dart';
import 'package:morphhealth/core/storage/encrypted_store.dart';
import 'package:morphhealth/core/util/clock.dart';

const String _usage = '''
Usage: mh --data-dir ABS --key-file ABS [--now RFC3339]
          [--food-base-url HTTPS_ORIGIN] [--food-user-agent STRING]

Reads JSON requests (one per line) from stdin and writes one JSON response
per request to stdout. Send {"request_id":1,"op":"describe"} for details.
''';

Never _fail(String message) {
  stderr.writeln('mh: $message');
  stderr.write(_usage);
  exit(2);
}

Map<String, String> _parseArgs(List<String> args) {
  const known = {
    '--data-dir',
    '--key-file',
    '--now',
    '--food-base-url',
    '--food-user-agent',
  };
  final result = <String, String>{};
  for (var i = 0; i < args.length; i++) {
    final arg = args[i];
    if (arg == '--help' || arg == '-h') {
      stderr.write(_usage);
      exit(0);
    }
    String name;
    String value;
    final eq = arg.indexOf('=');
    if (arg.startsWith('--') && eq > 0) {
      name = arg.substring(0, eq);
      value = arg.substring(eq + 1);
    } else {
      name = arg;
      if (i + 1 >= args.length) _fail('missing value for $arg');
      value = args[++i];
    }
    if (!known.contains(name)) _fail('unknown option $name');
    if (result.containsKey(name)) _fail('option $name given twice');
    result[name] = value;
  }
  return result;
}

Future<void> main(List<String> arguments) async {
  final args = _parseArgs(arguments);
  final dataDirArg = args['--data-dir'] ?? _fail('--data-dir is required');
  final keyFileArg = args['--key-file'] ?? _fail('--key-file is required');
  if (!dataDirArg.startsWith('/')) _fail('--data-dir must be an absolute path');
  if (!keyFileArg.startsWith('/')) _fail('--key-file must be an absolute path');

  final dataDir = Directory(dataDirArg).absolute;
  final keyFile = File(keyFileArg);
  if (!keyFile.existsSync()) _fail('key file not found: $keyFileArg');
  final keyPath = keyFile.resolveSymbolicLinksSync();
  var dataPath = dataDir.path;
  if (dataDir.existsSync()) dataPath = dataDir.resolveSymbolicLinksSync();
  final normalizedData = dataPath.endsWith('/') ? dataPath : '$dataPath/';
  if (keyPath.startsWith(normalizedData)) {
    _fail('the key file must be stored outside the data directory');
  }
  final key = keyFile.readAsBytesSync();
  if (key.length != 32) {
    _fail('the key file must contain exactly 32 raw bytes (found ${key.length})');
  }
  final mode = keyFile.statSync().mode;
  if (mode & 0x3f != 0) {
    stderr.writeln('mh: warning: key file is readable by other users (chmod 600 recommended)');
  }

  Clock clock;
  String clockSource;
  final now = args['--now'];
  if (now != null) {
    try {
      clock = FixedClock.parseRfc3339(now);
    } on FormatException {
      _fail('--now must be an RFC 3339 timestamp, e.g. 2026-09-23T08:00:00+02:00');
    }
    clockSource = '--now';
  } else {
    clock = const SystemClock();
    clockSource = 'system';
  }

  FoodApiConfig foodApi;
  try {
    foodApi = FoodApiConfig(
      args['--food-base-url'] ?? defaultFoodApiBaseUrl,
      args['--food-user-agent'] ?? defaultFoodApiUserAgent,
    );
  } on ArgumentError {
    _fail('--food-base-url must be an HTTPS origin such as https://world.openfoodfacts.org');
  }

  await initializeFormatting();

  Repository? repo;
  StoreException? storeError;
  try {
    repo = await Repository.open(directory: dataDir, masterKey: key, clock: clock);
    for (final w in repo.openWarnings) {
      stderr.writeln('mh: store warning: $w');
    }
  } on StoreException catch (e) {
    storeError = e;
    stderr.writeln('mh: data store unavailable: ${e.code}: ${e.message}');
  }

  final service = repo == null
      ? null
      : MorphHealthService(repo: repo, clock: clock, defaultFoodApi: foodApi);
  final protocol = MaintenanceProtocol(
    context: ProtocolContext(
      dataDir: dataDir.path,
      clock: clock,
      clockSource: clockSource,
      foodApi: foodApi,
    ),
    service: service,
    storeError: storeError,
  );

  final lines = stdin
      .transform(const Utf8Decoder(allowMalformed: true))
      .transform(const LineSplitter());
  await for (final line in lines) {
    if (line.trim().isEmpty) continue;
    final response = await protocol.handleLine(line);
    stdout.writeln(jsonEncode(response));
    await stdout.flush();
  }

  await repo?.close();
  await stdout.flush();
  exit(0);
}
