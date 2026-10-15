import 'dart:convert';
import 'dart:io';
import 'package:morphhealth/src/core/crypto_vault.dart';
import 'package:morphhealth/src/core/mh_protocol.dart';
import 'package:morphhealth/src/core/off_client.dart';
import 'package:morphhealth/src/core/repository.dart';

DateTime _parseRfc3339WallClock(String raw) {
  final trimmed = raw.trim();
  final parsedInstant = DateTime.tryParse(trimmed);
  if (parsedInstant == null) {
    throw FormatException('Invalid --now RFC3339 timestamp: $raw');
  }
  // Extract wall-clock YYYY-MM-DDTHH:MM:SS from the RFC3339 string so that
  // local dates with timezone offsets (e.g. 2026-10-15T00:39:34+02:00) preserve
  // their calendar date (2026-10-15).
  final match = RegExp(
    r'^(\d{4})-(\d{2})-(\d{2})[Tt ](\d{2}):(\d{2}):(\d{2})',
  ).firstMatch(trimmed);
  if (match != null) {
    return DateTime.utc(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
      int.parse(match.group(4)!),
      int.parse(match.group(5)!),
      int.parse(match.group(6)!),
    );
  }
  return parsedInstant.toUtc();
}

Future<void> main(List<String> args) async {
  String? dataDir;
  String? keyFile;
  String? nowStr;
  String? foodBaseUrl;
  String? foodUserAgent;

  for (int i = 0; i < args.length; i++) {
    final arg = args[i];
    String? nextVal() {
      if (i + 1 < args.length) {
        i++;
        return args[i];
      }
      return null;
    }

    if (arg == '--data-dir') {
      dataDir = nextVal();
    } else if (arg.startsWith('--data-dir=')) {
      dataDir = arg.substring('--data-dir='.length);
    } else if (arg == '--key-file') {
      keyFile = nextVal();
    } else if (arg.startsWith('--key-file=')) {
      keyFile = arg.substring('--key-file='.length);
    } else if (arg == '--now') {
      nowStr = nextVal();
    } else if (arg.startsWith('--now=')) {
      nowStr = arg.substring('--now='.length);
    } else if (arg == '--food-base-url') {
      foodBaseUrl = nextVal();
    } else if (arg.startsWith('--food-base-url=')) {
      foodBaseUrl = arg.substring('--food-base-url='.length);
    } else if (arg == '--food-user-agent') {
      foodUserAgent = nextVal();
    } else if (arg.startsWith('--food-user-agent=')) {
      foodUserAgent = arg.substring('--food-user-agent='.length);
    } else {
      stderr.writeln('Unknown argument: $arg');
      exit(2);
    }
  }

  if (dataDir == null || dataDir.trim().isEmpty) {
    stderr.writeln('Missing required argument: --data-dir ABS');
    exit(2);
  }
  if (keyFile == null || keyFile.trim().isEmpty) {
    stderr.writeln('Missing required argument: --key-file ABS');
    exit(2);
  }

  if (!PathCheck.isAbsolute(dataDir) || !PathCheck.isAbsolute(keyFile)) {
    stderr.writeln('--data-dir and --key-file must be absolute paths.');
    exit(2);
  }

  DateTime Function() clock = DateTime.now;
  if (nowStr != null && nowStr.trim().isNotEmpty) {
    try {
      final fixedNow = _parseRfc3339WallClock(nowStr);
      clock = () => fixedNow;
    } catch (e) {
      stderr.writeln(e.toString());
      exit(2);
    }
  }

  final defaults = OpenFoodFactsClient.loadDefaultConfig();
  final effectiveBaseUrl =
      (foodBaseUrl != null && foodBaseUrl.trim().isNotEmpty)
          ? foodBaseUrl.trim()
          : defaults.baseUrl;
  final effectiveUserAgent =
      (foodUserAgent != null && foodUserAgent.trim().isNotEmpty)
          ? foodUserAgent.trim()
          : defaults.userAgent;

  final repo = MorphHealthRepository(
    dataDirPath: dataDir,
    keyFilePath: keyFile,
    clock: clock,
  );

  try {
    await repo.initialize(createKeyIfMissing: true);
  } on VaultCryptoException catch (e) {
    stderr.writeln('Vault initialization failed (${e.code}): ${e.message}');
    exit(1);
  } catch (e) {
    stderr.writeln('Initialization error: $e');
    exit(1);
  }

  final offClient = OpenFoodFactsClient(
    baseUrl: effectiveBaseUrl,
    userAgent: effectiveUserAgent,
    nowIsoProvider: () => repo.nowIso,
  );

  final handler = MhProtocolHandler(
    repository: repo,
    offClient: offClient,
  );

  try {
    final lines = stdin
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    await for (final rawLine in lines) {
      final line = rawLine.trim();
      if (line.isEmpty) continue;

      Map<String, dynamic> response;
      try {
        final decoded = jsonDecode(line);
        if (decoded is! Map) {
          response = {
            'request_id': null,
            'ok': false,
            'error': {
              'code': 'invalid_request',
              'message': 'Request line must be a JSON object.',
            },
          };
        } else {
          response = await handler.handleRequest(
            Map<String, dynamic>.from(decoded),
          );
        }
      } catch (e) {
        response = {
          'request_id': null,
          'ok': false,
          'error': {
            'code': 'invalid_json',
            'message': 'Malformed JSON line: $e',
          },
        };
      }

      stdout.writeln(jsonEncode(response));
      await stdout.flush();
    }
  } finally {
    offClient.close();
  }
}

class PathCheck {
  static bool isAbsolute(String p) {
    return p.startsWith('/') || RegExp(r'^[a-zA-Z]:[\\/]').hasMatch(p);
  }
}
