// Lokaler Wartungszugang (JSON Lines). Ruft dieselben Funktionen auf wie die
// Android-App: lib/core ist reines Dart und wird von beiden gemeinsam genutzt.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:morphhealth/core/clock.dart';
import 'package:morphhealth/core/core.dart';
import 'package:morphhealth/core/protocol.dart';
import 'package:morphhealth/core/store.dart';

const String usage =
    'Aufruf: mh --data-dir ABS --key-file ABS [--now RFC3339] '
    '[--food-base-url HTTPS_ORIGIN] [--food-user-agent STRING]\n'
    'Liest JSON-Zeilen von stdin und schreibt je eine Antwortzeile auf stdout. '
    'Die Operation describe beschreibt alles Weitere.';

void fail(String message, {int code = 2}) {
  stderr.add(utf8.encode('mh: $message\n'));
  exit(code);
}

Future<void> writeLine(Map<String, Object?> response) async {
  stdout.add(utf8.encode('${jsonEncode(response)}\n'));
  await stdout.flush();
}

Future<void> main(List<String> args) async {
  String? dataDir;
  String? keyFile;
  String? now;
  String? baseUrl;
  String? userAgent;
  for (var i = 0; i < args.length; i++) {
    final a = args[i];
    String value(String name) {
      final eq = a.indexOf('=');
      if (eq > 0) return a.substring(eq + 1);
      if (i + 1 >= args.length) fail('Option $name braucht einen Wert\n$usage');
      return args[++i];
    }

    if (a == '--help' || a == '-h') {
      stdout.add(utf8.encode('$usage\n'));
      return;
    }
    final name = a.contains('=') ? a.substring(0, a.indexOf('=')) : a;
    switch (name) {
      case '--data-dir':
        dataDir = value(name);
      case '--key-file':
        keyFile = value(name);
      case '--now':
        now = value(name);
      case '--food-base-url':
        baseUrl = value(name);
      case '--food-user-agent':
        userAgent = value(name);
      default:
        fail('Unbekannte Option: $a\n$usage');
    }
  }
  if (dataDir == null || keyFile == null) fail('--data-dir und --key-file sind Pflicht\n$usage');

  Clock clock = SystemClock();
  if (now != null) {
    try {
      clock = FixedClock.parse(now);
    } on FormatException catch (e) {
      fail('--now: ${e.message}');
    }
  }

  // Datenbestand öffnen. Scheitert das, beantwortet der Prozess trotzdem alle
  // Anfragen (describe funktioniert, der Rest meldet den Grund).
  Protocol protocol;
  MorphCore? core;
  try {
    final keyBytes = await File(keyFile!).readAsBytes();
    if (keyBytes.length != 32) {
      throw StoreException(
        StoreErrorCode.wrongKey,
        'Die Schlüsseldatei muss genau 32 rohe Byte enthalten (gefunden: ${keyBytes.length})',
      );
    }
    final store = await EncryptedStore.open(
      Directory(dataDir!),
      Uint8List.fromList(keyBytes),
      onWarning: (m) => stderr.add(utf8.encode('mh: $m\n')),
    );
    core = await MorphCore.open(
      persistence: store,
      clock: clock,
      baseUrlOverride: baseUrl,
      userAgentOverride: userAgent,
    );
    protocol = Protocol(core: core);
  } on StoreException catch (e) {
    stderr.add(utf8.encode('mh: ${e.message}\n'));
    protocol = Protocol(startupError: e);
  } on FileSystemException catch (e) {
    final err = StoreException(
      StoreErrorCode.io,
      'Datei nicht lesbar: ${e.path ?? ''} (${e.osError?.message ?? e.message})',
    );
    stderr.add(utf8.encode('mh: ${err.message}\n'));
    protocol = Protocol(startupError: err);
  }

  final lines = stdin.transform(utf8.decoder).transform(const LineSplitter());
  await for (final line in lines) {
    if (line.trim().isEmpty) continue;
    Map<String, Object?> response;
    try {
      response = await protocol.handle(jsonDecode(line));
    } on FormatException catch (e) {
      response = Protocol.invalidJson('Die Zeile ist kein gültiges JSON: ${e.message}');
    }
    await writeLine(response);
  }
  await core?.close();
}
