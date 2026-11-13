// Opens a MorphHealth backup on the host and prints what it contains.
//
//   dart run tool/open_backup.dart FILE.mhbackup [--json]
//
// The passphrase is read from the environment variable MH_PASSPHRASE or, if
// that is not set, from the first line of stdin. With --json the decrypted
// export document is written to stdout; otherwise only a summary is printed.
//
// The tool exists to check, independently of the app, that a backup can be
// decrypted with nothing but the documented format and the passphrase.
import 'dart:convert';
import 'dart:io';

import 'package:morphhealth_core/morphhealth_core.dart';

Future<void> main(List<String> args) async {
  final files = args.where((a) => !a.startsWith('--')).toList();
  if (files.length != 1) {
    stderr.writeln('Usage: open_backup.dart FILE.mhbackup [--json]');
    exit(64);
  }
  final bytes = File(files.single).readAsBytesSync();
  final passphrase =
      Platform.environment['MH_PASSPHRASE'] ??
      stdin.readLineSync(encoding: utf8) ??
      '';
  try {
    final header = BackupCodec.readHeader(bytes);
    final document = await BackupCodec.open(bytes, passphrase);
    if (args.contains('--json')) {
      stdout.writeln(const JsonEncoder.withIndent(' ').convert(document));
      return;
    }
    final log = IssueLog();
    final data = AppData.fromDocument(
      document,
      log,
      now: const SystemClock().now(),
    );
    stdout.writeln('created_at: ${header.createdAt}');
    stdout.writeln('app_version: ${header.appVersion}');
    stdout.writeln(
      'kdf: argon2id m=${header.kdf.memoryKib} KiB '
      't=${header.kdf.iterations} p=${header.kdf.parallelism}',
    );
    if (data == null) {
      stdout.writeln('document errors: ${log.errors}');
      exit(1);
    }
    stdout.writeln('counts: ${data.counts}');
  } on BackupException catch (e) {
    stderr.writeln('${e.code}: ${e.message}');
    exit(1);
  }
}
