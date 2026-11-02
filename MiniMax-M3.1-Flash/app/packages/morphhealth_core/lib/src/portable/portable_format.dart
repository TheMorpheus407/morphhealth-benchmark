import 'dart:convert';

import '../models/food.dart';
import '../models/journal.dart';
import '../models/records.dart';
import '../store/repository.dart';

/// Raised when a portable document cannot be read.
class PortableFormatException implements Exception {
  const PortableFormatException(this.message);

  final String message;

  @override
  String toString() => 'PortableFormatException: $message';
}

/// The documented, machine readable export format of MorphHealth.
///
/// The format is a single JSON object. It contains the complete data set of
/// one installation and is the format that is used for the plain export, for
/// the encrypted backup container and for the import.
abstract final class PortableFormat {
  /// Identifier written into every document.
  static const String formatId = 'morphhealth.portable';

  /// Version of the document format.
  static const int version = 1;

  /// Builds the export document.
  static Map<String, dynamic> exportDocument(
    HealthData data, {
    required DateTime exportedAt,
    String appVersion = '1.0-rc3',
  }) {
    return <String, dynamic>{
      'format': formatId,
      'version': version,
      'exported_at': exportedAt.toUtc().toIso8601String(),
      'app': <String, dynamic>{
        'name': 'MorphHealth',
        'version': appVersion,
      },
      'counts': <String, int>{
        'foods': data.foods.length,
        'journal_entries': data.journalEntries.length,
        'intake_entries': data.intakes.length,
        'periods': data.periods.length,
        'weights': data.weights.length,
        'symptoms': data.symptoms.length,
      },
      'foods': data.foods.values
          .map((FoodItem f) => f.toJson())
          .toList(growable: false),
      'journal_entries': data.journalEntries
          .map((JournalEntry e) => e.toJson())
          .toList(growable: false),
      'intake_entries': data.intakes
          .map((IntakeEntry e) => e.toJson())
          .toList(growable: false),
      'periods': data.periods
          .map((PeriodRecord p) => p.toJson())
          .toList(growable: false),
      'weights': data.weights
          .map((WeightEntry w) => w.toJson())
          .toList(growable: false),
      'symptoms': data.symptoms
          .map((SymptomEntry s) => s.toJson())
          .toList(growable: false),
      'goals': data.goals.toJson(),
      'settings': data.settings.toJson(),
    };
  }

  /// Reads an export document back into a data set.
  static HealthData importDocument(Map<String, dynamic> document) {
    final String? format = document['format'] as String?;
    if (format != formatId) {
      throw PortableFormatException(
        'Unsupported document format: ${format ?? 'missing'}',
      );
    }
    final int docVersion = (document['version'] as num?)?.toInt() ?? 0;
    if (docVersion > version) {
      throw PortableFormatException(
        'Document version $docVersion is newer than supported version $version',
      );
    }

    final Map<String, FoodItem> foods = <String, FoodItem>{};
    for (final dynamic raw in _list(document, 'foods')) {
      final FoodItem food = FoodItem.fromJson(_map(raw));
      foods[food.id] = food;
    }
    final List<JournalEntry> journal = <JournalEntry>[
      for (final dynamic raw in _list(document, 'journal_entries'))
        JournalEntry.fromJson(_map(raw)),
    ];
    final List<IntakeEntry> intakes = <IntakeEntry>[
      for (final dynamic raw in _list(document, 'intake_entries'))
        IntakeEntry.fromJson(_map(raw)),
    ];
    final List<PeriodRecord> periods = <PeriodRecord>[
      for (final dynamic raw in _list(document, 'periods'))
        PeriodRecord.fromJson(_map(raw)),
    ];
    final List<WeightEntry> weights = <WeightEntry>[
      for (final dynamic raw in _list(document, 'weights'))
        WeightEntry.fromJson(_map(raw)),
    ];
    final List<SymptomEntry> symptoms = <SymptomEntry>[
      for (final dynamic raw in _list(document, 'symptoms'))
        SymptomEntry.fromJson(_map(raw)),
    ];

    journal.sort((JournalEntry a, JournalEntry b) =>
        a.date == b.date
            ? a.loggedAtMs.compareTo(b.loggedAtMs)
            : a.date.compareTo(b.date));
    intakes.sort((IntakeEntry a, IntakeEntry b) =>
        a.date == b.date
            ? a.loggedAtMs.compareTo(b.loggedAtMs)
            : a.date.compareTo(b.date));
    weights.sort((WeightEntry a, WeightEntry b) => a.date.compareTo(b.date));
    symptoms.sort((SymptomEntry a, SymptomEntry b) =>
        a.date == b.date
            ? a.occurredAtMs.compareTo(b.occurredAtMs)
            : a.date.compareTo(b.date));
    periods.sort((PeriodRecord a, PeriodRecord b) =>
        a.startDate.compareTo(b.startDate));

    return HealthData(
      foods: foods,
      journalEntries: journal,
      intakes: intakes,
      periods: periods,
      weights: weights,
      symptoms: symptoms,
      goals: Goals.fromJson(_map(document['goals'])),
      settings: AppSettings.fromJson(_map(document['settings'])),
    );
  }

  /// Encodes a document as pretty printed JSON.
  static String encode(Map<String, dynamic> document) =>
      const JsonEncoder.withIndent('  ').convert(document);

  /// Decodes a JSON document.
  static Map<String, dynamic> decode(String text) {
    final dynamic decoded = jsonDecode(text);
    if (decoded is! Map<String, dynamic>) {
      throw const PortableFormatException('Document is not a JSON object');
    }
    return decoded;
  }

  static List<dynamic> _list(Map<String, dynamic> document, String key) =>
      (document[key] as List<dynamic>?) ?? const <dynamic>[];

  static Map<String, dynamic> _map(dynamic value) =>
      value is Map<String, dynamic> ? value : <String, dynamic>{};
}
