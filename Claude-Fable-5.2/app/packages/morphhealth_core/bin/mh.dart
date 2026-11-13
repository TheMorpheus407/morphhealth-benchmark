// Local maintenance access to MorphHealth (JSON Lines on stdin/stdout).
//
//   mh --data-dir ABS --key-file ABS [--now RFC3339]
//      [--food-base-url HTTPS_ORIGIN] [--food-user-agent STRING]
//
// See `{"request_id": 1, "op": "describe"}` and README.md for the protocol.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:morphhealth_core/morphhealth_core.dart';

const String _usage = '''
Usage: mh --data-dir ABS --key-file ABS [--now RFC3339]
          [--food-base-url HTTPS_ORIGIN] [--food-user-agent STRING]

  --data-dir         absolute path of the persistent working data set
  --key-file         absolute path of a file with 32 raw bytes, outside --data-dir
  --now              business clock of this process, e.g. 2026-09-23T08:00:00+02:00
  --food-base-url    HTTPS origin of the food service
  --food-user-agent  User-Agent sent to the food service

Requests are JSON lines on stdin, answers JSON lines on stdout.
Start with: {"request_id": 1, "op": "describe"}''';

class _UsageError implements Exception {
  final String message;
  const _UsageError(this.message);
}

class _Options {
  String? dataDir;
  String? keyFile;
  String? now;
  String? foodBaseUrl;
  String? foodUserAgent;
  bool help = false;
}

_Options _parseArguments(List<String> args) {
  final o = _Options();
  var i = 0;
  String value(String name, String? inline) {
    if (inline != null) return inline;
    if (i + 1 >= args.length) throw _UsageError('$name needs a value');
    i++;
    return args[i];
  }

  for (; i < args.length; i++) {
    final arg = args[i];
    final eq = arg.startsWith('--') ? arg.indexOf('=') : -1;
    final name = eq < 0 ? arg : arg.substring(0, eq);
    final inline = eq < 0 ? null : arg.substring(eq + 1);
    switch (name) {
      case '--data-dir':
        o.dataDir = value(name, inline);
      case '--key-file':
        o.keyFile = value(name, inline);
      case '--now':
        o.now = value(name, inline);
      case '--food-base-url':
        o.foodBaseUrl = value(name, inline);
      case '--food-user-agent':
        o.foodUserAgent = value(name, inline);
      case '--help' || '-h':
        o.help = true;
      default:
        throw _UsageError('unknown option: $arg');
    }
  }
  return o;
}

/// Removes `.` and `..` segments and trailing slashes from an absolute path.
String _normalizePath(String path) {
  final parts = <String>[];
  for (final segment in path.split('/')) {
    if (segment.isEmpty || segment == '.') continue;
    if (segment == '..') {
      if (parts.isNotEmpty) parts.removeLast();
    } else {
      parts.add(segment);
    }
  }
  return '/${parts.join('/')}';
}

String _canonicalPath(String path) {
  try {
    final type = FileSystemEntity.typeSync(path);
    if (type == FileSystemEntityType.directory) {
      return Directory(path).resolveSymbolicLinksSync();
    }
    if (type != FileSystemEntityType.notFound) {
      return File(path).resolveSymbolicLinksSync();
    }
  } on FileSystemException {
    // fall through
  }
  return _normalizePath(path);
}

/// Reads the 32-byte master key. The file is only read, never written.
Uint8List _readKey(String keyFile, String dataDir) {
  final keyPath = _canonicalPath(keyFile);
  final dataPath = _canonicalPath(dataDir);
  if (keyPath == dataPath || keyPath.startsWith('$dataPath/')) {
    throw const MhError(
      'key_file_invalid',
      'The key file lies inside the data directory. Keep it outside.',
    );
  }
  final file = File(keyFile);
  final Uint8List bytes;
  try {
    if (FileSystemEntity.typeSync(keyFile) != FileSystemEntityType.file) {
      throw MhError(
        'key_file_invalid',
        'The key file does not exist or is not a regular file: $keyFile',
      );
    }
    bytes = file.readAsBytesSync();
  } on FileSystemException catch (e) {
    throw MhError(
      'key_file_invalid',
      'The key file cannot be read: ${e.message}',
    );
  }
  if (bytes.length != 32) {
    throw MhError(
      'key_file_invalid',
      'The key file must contain exactly 32 raw bytes; it has '
          '${bytes.length}.',
    );
  }
  return bytes;
}

Map<String, dynamic> _readEnvironmentFile() {
  final path = Platform.environment['MH_ENVIRONMENT_FILE'];
  if (path == null || path.isEmpty) return const {};
  try {
    final file = File(path);
    if (!file.existsSync()) return const {};
    final decoded = jsonDecode(file.readAsStringSync());
    return decoded is Map<String, dynamic> ? decoded : const {};
  } on Object catch (e) {
    stderr.writeln('mh: cannot read $path: $e');
    return const {};
  }
}

Never _fail(String message) {
  stderr.writeln('mh: $message');
  stderr.writeln(_usage);
  exit(64);
}

Future<void> main(List<String> args) async {
  final _Options options;
  try {
    options = _parseArguments(args);
  } on _UsageError catch (e) {
    _fail(e.message);
  }
  if (options.help) {
    stderr.writeln(_usage);
    exit(0);
  }
  final dataDir = options.dataDir;
  final keyFile = options.keyFile;
  if (dataDir == null) _fail('--data-dir is required');
  if (keyFile == null) _fail('--key-file is required');
  if (!dataDir.startsWith('/')) _fail('--data-dir must be an absolute path');
  if (!keyFile.startsWith('/')) _fail('--key-file must be an absolute path');

  Clock clock = const SystemClock();
  final nowText = options.now;
  if (nowText != null) {
    final parsed = LocalDateTime.tryParseDetailed(nowText);
    if (parsed == null || parsed.dateOnly) {
      _fail(
        '--now must be an RFC 3339 date-time such as '
        '2026-09-23T08:00:00+02:00',
      );
    }
    clock = FixedClock(parsed.value);
  }

  final environment = _readEnvironmentFile();
  final envBase = environment['food_api_base_url'];
  final envAgent = environment['food_api_user_agent'];
  final baseUrl =
      options.foodBaseUrl ??
      (envBase is String && envBase.isNotEmpty
          ? envBase
          : FoodApiClient.productionOrigin);
  final userAgent =
      options.foodUserAgent ??
      (envAgent is String && envAgent.isNotEmpty
          ? envAgent
          : 'MorphHealth/$morphHealthVersion');
  if (userAgent.trim().isEmpty) _fail('--food-user-agent must not be empty');
  final Uri origin;
  try {
    origin = FoodApiClient.parseOrigin(baseUrl);
  } on FoodApiException catch (e) {
    _fail('--food-base-url: ${e.message}');
  }

  final service = MhService(
    clock: clock,
    clockIsFixed: nowText != null,
    foodBaseUrl: origin.toString(),
    foodUserAgent: userAgent,
    foodClient: (languages) => FoodApiClient(
      origin: origin,
      userAgent: userAgent,
      transport: IoHttpTransport(),
      languages: languages,
    ),
    openRepository: () {
      final key = _readKey(keyFile, dataDir);
      return HealthRepository.open(
        EncryptedFileStore(Directory(_normalizePath(dataDir)), key),
        clock: clock,
      );
    },
  );

  final lines = stdin
      .transform(const Utf8Decoder(allowMalformed: true))
      .transform(const LineSplitter());
  try {
    await for (final line in lines) {
      final response = await service.handleLine(line);
      if (response == null) continue;
      stdout.writeln(jsonEncode(response));
      await stdout.flush();
    }
    await stdout.flush();
  } on IOException {
    // The reader went away; there is nobody left to answer.
  }
  exit(0);
}
