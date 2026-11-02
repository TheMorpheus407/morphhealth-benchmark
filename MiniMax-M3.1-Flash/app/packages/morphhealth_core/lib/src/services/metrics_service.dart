import '../models/records.dart';
import '../store/repository.dart';

/// Weight entries and their statistics.
class WeightService {
  WeightService(this._repository);

  final HealthRepository _repository;

  /// All entries, oldest first.
  List<WeightEntry> get entries => _repository.weightEntries;

  /// Entries between two calendar days (inclusive).
  List<WeightEntry> inRange(String from, String to) => entries
      .where((WeightEntry e) => DateMath.inRange(e.date, from, to))
      .toList(growable: false);

  /// The most recent entry.
  WeightEntry? get latest => entries.isEmpty ? null : entries.last;

  /// Difference between the last two entries in kilograms.
  double? get latestChange {
    if (entries.length < 2) return null;
    return entries.last.valueKg - entries[entries.length - 2].valueKg;
  }

  /// Average of the entries in a period.
  double? average(String from, String to) {
    final List<WeightEntry> list = inRange(from, to);
    if (list.isEmpty) return null;
    return list.map((WeightEntry e) => e.valueKg).reduce((double a, double b) => a + b) /
        list.length;
  }

  /// Smallest value in a period.
  double? minimum(String from, String to) {
    final List<WeightEntry> list = inRange(from, to);
    if (list.isEmpty) return null;
    return list.map((WeightEntry e) => e.valueKg).reduce((double a, double b) => a < b ? a : b);
  }

  /// Largest value in a period.
  double? maximum(String from, String to) {
    final List<WeightEntry> list = inRange(from, to);
    if (list.isEmpty) return null;
    return list.map((WeightEntry e) => e.valueKg).reduce((double a, double b) => a > b ? a : b);
  }

  /// Converts kilograms into the display unit.
  static double toDisplay(double kilograms, WeightUnit unit) =>
      unit == WeightUnit.lb ? kilograms * 2.2046226218 : kilograms;

  /// Converts a value given in the display unit back into kilograms.
  static double toKilograms(double value, WeightUnit unit) =>
      unit == WeightUnit.lb ? value / 2.2046226218 : value;
}

/// Symptom entries and the per symptom view.
class SymptomService {
  SymptomService(this._repository);

  final HealthRepository _repository;

  /// All entries, oldest first.
  List<SymptomEntry> get entries => _repository.symptomEntries;

  /// All distinct symptom names, alphabetically.
  List<String> get names {
    final Set<String> unique = <String>{
      for (final SymptomEntry entry in entries) entry.name,
    };
    final List<String> list = unique.toList()..sort();
    return list;
  }

  /// Entries between two calendar days (inclusive).
  List<SymptomEntry> inRange(String from, String to) => entries
      .where((SymptomEntry e) => DateMath.inRange(e.date, from, to))
      .toList(growable: false);

  /// Entries of one symptom.
  List<SymptomEntry> byName(String name) => entries
      .where((SymptomEntry e) => e.name.toLowerCase() == name.toLowerCase())
      .toList(growable: false);

  /// Average intensity of a symptom in a period.
  double? averageIntensity(List<SymptomEntry> list) {
    if (list.isEmpty) return null;
    return list
            .map((SymptomEntry e) => e.intensity)
            .reduce((int a, int b) => a + b) /
        list.length;
  }
}
