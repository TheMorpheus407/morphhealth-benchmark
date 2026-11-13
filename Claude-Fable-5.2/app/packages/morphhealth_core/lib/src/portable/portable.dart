import 'dart:convert';

import '../model/app_data.dart';
import '../store/repository.dart';
import '../util/dates.dart';
import '../util/json_reader.dart';
import '../version.dart';

/// A document was not taken over because it has errors. Nothing was changed.
class ImportRejected implements Exception {
  final List<DocumentIssue> errors;

  /// Total number of errors; [errors] holds at most the first hundred.
  final int errorCount;
  final List<DocumentIssue> warnings;

  const ImportRejected(this.errors, this.errorCount, this.warnings);

  Map<String, dynamic> toJson() => {
    'error_count': errorCount,
    'errors': [for (final e in errors) e.toJson()],
    'warnings': [for (final w in warnings) w.toJson()],
  };

  @override
  String toString() => 'ImportRejected: ${errors.take(3).join('; ')}';
}

/// The result of checking a document without taking it over.
class ImportPreview {
  /// The data the document would produce.
  final AppData data;
  final List<DocumentIssue> warnings;
  final int warningCount;

  /// `exported_at` of the document, if it carries a readable one.
  final LocalDateTime? exportedAt;

  const ImportPreview(
    this.data,
    this.warnings,
    this.warningCount,
    this.exportedAt,
  );
}

/// What an import did.
class ImportReport {
  /// Records per collection after the import.
  final Map<String, int> counts;

  /// Records per collection that were replaced.
  final Map<String, int> previousCounts;
  final List<DocumentIssue> warnings;
  final int warningCount;
  final LocalDateTime importedAt;

  const ImportReport({
    required this.counts,
    required this.previousCounts,
    required this.warnings,
    required this.warningCount,
    required this.importedAt,
  });

  Map<String, dynamic> toJson() => {
    'replaced': true,
    'imported_at': importedAt.toIso(),
    'counts': counts,
    'entries_total': counts.entries
        .where((e) => e.key != 'foods')
        .fold<int>(0, (a, e) => a + e.value),
    'previous_counts': previousCounts,
    'warning_count': warningCount,
    'warnings': [for (final w in warnings) w.toJson()],
  };
}

/// Complete export and import of the user's data in the documented,
/// machine-readable format `morphhealth-export` (see README).
class PortableService {
  /// Largest document that is read, in bytes.
  static const int maxDocumentBytes = 128 * 1024 * 1024;

  final HealthRepository repository;

  const PortableService(this.repository);

  /// The complete data set as a JSON-compatible document.
  Map<String, dynamic> exportDocument() => repository.data.toDocument(
    exportedAt: repository.now,
    appVersion: morphHealthVersion,
  );

  /// The export as UTF-8 JSON text.
  List<int> exportBytes({bool pretty = true}) => utf8.encode(
    pretty
        ? const JsonEncoder.withIndent(' ').convert(exportDocument())
        : jsonEncode(exportDocument()),
  );

  /// Suggested file name, for example `morphhealth-export-2026-11-09.json`.
  String suggestedFileName() => 'morphhealth-export-${repository.today}.json';

  /// Decodes the bytes of an export file. Throws [ImportRejected] if they are
  /// not JSON.
  static Object? decodeBytes(List<int> bytes) {
    if (bytes.length > maxDocumentBytes) {
      throw const ImportRejected(
        [DocumentIssue('', 'the file is too large')],
        1,
        [],
      );
    }
    var start = 0;
    if (bytes.length >= 3 &&
        bytes[0] == 0xEF &&
        bytes[1] == 0xBB &&
        bytes[2] == 0xBF) {
      start = 3;
    }
    try {
      return jsonDecode(utf8.decode(start == 0 ? bytes : bytes.sublist(start)));
    } on FormatException catch (e) {
      throw ImportRejected(
        [DocumentIssue('', 'the file is not valid JSON: ${e.message}')],
        1,
        const [],
      );
    }
  }

  /// Checks [document] completely. Throws [ImportRejected] on any error.
  ImportPreview preview(Object? document) {
    final log = IssueLog();
    final data = AppData.fromDocument(document, log, now: repository.now);
    if (data == null) {
      throw ImportRejected(log.errors, log.errorCount, log.warnings);
    }
    LocalDateTime? exportedAt;
    if (document is Map && document['exported_at'] is String) {
      exportedAt = LocalDateTime.tryParse(document['exported_at'] as String);
    }
    return ImportPreview(data, log.warnings, log.warningCount, exportedAt);
  }

  /// Replaces the whole data set by [document].
  ///
  /// The document is checked first; if it has errors, [ImportRejected] is
  /// thrown and the existing data stay untouched.
  Future<ImportReport> importDocument(Object? document) =>
      apply(preview(document));

  /// Takes over a checked document.
  Future<ImportReport> apply(ImportPreview preview) async {
    final previous = repository.data.counts;
    await repository.replaceAll(preview.data);
    return ImportReport(
      counts: repository.data.counts,
      previousCounts: previous,
      warnings: preview.warnings,
      warningCount: preview.warningCount,
      importedAt: repository.now,
    );
  }
}
