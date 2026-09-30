import 'dart:io';
import 'dart:convert';
import '../app/lib/core/core.dart';

Future<void> main() async {
  final file = File('artifacts/android-large-test.mhbackup.json');
  final doc = await decryptBackup(await file.readAsString(), 'MorphHealth-test-2026');
  if ((doc['meals'] as List).length != 10000) throw StateError('Wrong meal count');
  if ((doc['settings'] as Map)['language'] != 'en') throw StateError('Language lost');
  final result = <String, dynamic>{
    'native_android_backup_bytes': await file.length(),
    'decrypted_meals': (doc['meals'] as List).length,
    'decrypted_drinks': (doc['drinks'] as List).length,
    'language': (doc['settings'] as Map)['language'],
    'portable_without_android_key': true,
  };
  await File('artifacts/android-backup-check.json').writeAsString(const JsonEncoder.withIndent('  ').convert(result));
  stdout.writeln(jsonEncode(result));
}
