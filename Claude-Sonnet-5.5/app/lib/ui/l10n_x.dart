import 'package:flutter/material.dart';

import '../core/db.dart' show DomainException;
import '../core/models.dart';
import '../l10n/gen/app_localizations.dart';
import 'format.dart';

/// Kurzwege für Übersetzungen und Formatierung.
extension BuildContextX on BuildContext {
  AppLocalizations get l10n => AppLocalizations.of(this);

  ThemeData get theme => Theme.of(this);

  ColorScheme get colors => Theme.of(this).colorScheme;

  TextTheme get text => Theme.of(this).textTheme;

  /// Formatierung in der Sprache der App.
  Fmt get fmt => Fmt(Localizations.localeOf(this).languageCode);
}

extension AppLocalizationsX on AppLocalizations {
  String meal(Meal m) => switch (m) {
    Meal.breakfast => mealBreakfast,
    Meal.lunch => mealLunch,
    Meal.dinner => mealDinner,
    Meal.snack => mealSnack,
  };

  String flow(FlowLevel? f) => switch (f) {
    FlowLevel.spotting => flowSpotting,
    FlowLevel.light => flowLight,
    FlowLevel.medium => flowMedium,
    FlowLevel.heavy => flowHeavy,
    null => flowNone,
  };

  String unit(AmountUnit u) => switch (u) {
    AmountUnit.g => unitG,
    AmountUnit.ml => unitMl,
    AmountUnit.portion => unitPortion,
  };

  String basisUnit(Basis b) => b == Basis.ml ? unitMl : unitG;

  /// Einheit mit Singular oder Plural (`1 Portion`, `2 Portionen`).
  String unitFor(AmountUnit u, double amount) =>
      u == AmountUnit.portion ? (amount == 1 ? unitPortion : unitPortions) : unit(u);

  String area(Area a) => switch (a) {
    Area.nutrition => navNutrition,
    Area.cycle => navCycle,
    Area.weight => navWeight,
    Area.symptoms => navSymptoms,
  };
}

/// Meldung zu einem fachlichen Fehler in der Sprache der App. Die Meldungen des Kerns sind
/// Klartext für Protokolle und den Wartungszugang; die Oberfläche übersetzt sie nach Code.
String domainErrorText(AppLocalizations l, DomainException e) {
  switch (e.code) {
    case 'invalid_amount':
      return e.message.contains('Portion') ? l.errServingNeeded : l.errAmountInvalid;
    case 'invalid_weight':
      return l.errWeightRange;
    case 'invalid_symptom':
      return l.errSymptomInvalid;
    case 'invalid_food':
      return l.errFoodInvalid;
    case 'invalid_record':
      return l.errRecordInvalid;
    case 'nothing_to_remove':
      return l.errNothingToRemove;
    default:
      return l.commonError(e.message);
  }
}
