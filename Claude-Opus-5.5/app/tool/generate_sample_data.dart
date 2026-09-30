// Writes a realistic multi-year MorphHealth export (≈ 10,500 diary entries)
// for performance checks: dart run tool/generate_sample_data.dart OUT.json [END]
//
// END (YYYY-MM-DD) is the last day with data (default: yesterday).

import 'dart:convert';
import 'dart:io';

import 'package:morphhealth/core/util/local_date.dart';

import '../test/support/generator.dart';

void main(List<String> args) {
  if (args.isEmpty) {
    stderr.writeln('usage: dart run tool/generate_sample_data.dart OUT.json [END]');
    exit(2);
  }
  final end = args.length > 1
      ? LocalDate.parse(args[1])
      : LocalDate.fromDateTime(DateTime.now()).addDays(-1);
  final doc = generateDataset(end: end);
  File(args[0]).writeAsStringSync(const JsonEncoder.withIndent(' ').convert(doc));
  stderr.writeln('wrote ${args[0]}: ${diaryEntryCount(doc)} diary entries until $end');
}
