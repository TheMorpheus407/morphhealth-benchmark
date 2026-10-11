// Lokalisierung der MorphHealth-Oberfläche (Deutsch und Englisch).
//
// Reine Dart-Datei ohne Flutter-Abhängigkeit: UI, Widgets und Tests nutzen
// dieselben Texte. Deutsch ist voreingestellt (SPEC P02).
library;

import '../model/cycle.dart';
import '../model/entries.dart';
import '../nutrients/nutrients.dart';
import 'app_strings_de.dart';
import 'app_strings_en.dart';

/// Alle Texte der Benutzeroberfläche.
///
/// Konkrete Ausprägungen: [DeStrings] (deutsch, Standard) und [EnStrings].
abstract class AppStrings {
  /// 'de' oder 'en'.
  String get lang;

  // ------------------------------------------------------------- Allgemein
  String get appName;
  String get ok;
  String get cancel;
  String get save;
  String get delete;
  String get edit;
  String get close;
  String get add;
  String get search;
  String get retry;
  String get loading;
  String get done;
  String get yes;
  String get no;
  String get back;
  String get today;
  String get yesterday;
  String get tomorrow;
  String get now;
  String get dateLabel;
  String get timeLabel;
  String get noteLabel;
  String get optionalLabel;
  String get confirmDeleteTitle;
  String get confirmDeleteMessage;
  String get errorGeneric;
  String get fieldRequired;
  String get invalidNumber;
  String get clearLabel;
  String get applyLabel;
  String get resetLabel;

  // ------------------------------------------------------------- Bereiche
  String get allAreasLabel;
  String areaName(String areaKey);

  // ------------------------------------------------------------- Übersicht
  String get todaySection;
  String get nutritionCardTitle;
  String get waterCardTitle;
  String get cycleCardTitle;
  String get weightCardTitle;
  String get symptomsCardTitle;
  String get openTrends;
  String get openHistory;
  String get openSettings;
  String get openDayDetail;
  String get noDataYet;

  // ------------------------------------------------------------- Ernährung
  String get waterLabel;
  String get caffeineLabel;
  String get addEntry;
  String get addWater;
  String get addCaffeine;
  String get quickWaterTitle;
  String get customAmountLabel;
  String get quantityLabel;
  String get unitLabel;
  String get per100;
  String get perPortion;
  String get dayTotal;
  String get noGoal;
  String get allNutrients;
  String get mainNutrients;
  String get vitamins;
  String get minerals;
  String get noEntriesToday;
  String get diaryEmpty;
  String get addFoodFirst;
  String get entrySaved;
  String get entryUpdated;
  String get entryDeleted;
  String get waterSaved;
  String get caffeineSaved;
  String get foodSearchTitle;
  String get searchHint;
  String get searchByBarcode;
  String get barcodeLabel;
  String get invalidBarcode;
  String get tabSearch;
  String get tabFavorites;
  String get tabCustom;
  String get tabRecent;
  String get searchNoResults;
  String get searchError;
  String get lookupNotFound;
  String get addToDiary;
  String get reLog;
  String get foodDetailTitle;
  String get foodNameLabel;
  String get brandLabel;
  String get servingGramsLabel;
  String get servingLabelHint;
  String get favoriteAdd;
  String get favoriteRemove;
  String get sourceLabel;
  String get sourceOff;
  String get sourceCustom;
  String get offAttribution;
  String get offLicenseFull;
  String get nutrientsPer100;
  String get newFood;
  String get editFood;
  String get foodSaved;
  String get foodDeleted;
  String get entryNewTitle;
  String get entryEditTitle;
  String get mealLabel;
  String get foodLabel;
  String get selectFood;
  String get changeFood;
  String get deleteEntryConfirm;
  String get selectFoodFirst;
  String get goalWaterLabel;
  String get goalEnergyLabel;
  String get goalProteinLabel;
  String get goalCarbsLabel;
  String get goalFatLabel;

  // ------------------------------------------------------------- Zyklus
  String get cycleTitle;
  String get calendarLabel;
  String get addPeriod;
  String get periodStartLabel;
  String get periodEndLabel;
  String get periodOngoing;
  String get flowLabel;
  String get periodNoteLabel;
  String get startPeriodToday;
  String get endPeriodToday;
  String get forecastTitle;
  String get nextPeriodLabel;
  String get expectedStartLabel;
  String get expectedEndLabel;
  String get uncertaintyRangeLabel;
  String get averageCycleLabel;
  String get averagePeriodLabel;
  String get confidenceLabel;
  String get confidenceLow;
  String get confidenceMedium;
  String get confidenceHigh;
  String get explanationTitle;
  String get disclaimer;
  String get cycleHistory;
  String get noPeriods;
  String get periodOpen;
  String get editPeriod;
  String get deletePeriodConfirm;
  String get stateLabel;
  String get stateNoData;
  String get stateInsufficient;
  String get stateBeforeNext;
  String get stateWithinRecorded;
  String get stateWithinPredicted;
  String get stateBetweenPredicted;
  String get legendRecorded;
  String get legendPredicted;
  String get legendToday;
  String get legendSymptom;
  String get legendWeight;
  String get periodSaved;
  String get periodDeleted;

  // ------------------------------------------------------------- Gewicht
  String get weightTitle;
  String get addWeight;
  String get editWeight;
  String get weightLabel;
  String get weightKgLabel;
  String get weightLbLabel;
  String get unitKg;
  String get unitLb;
  String get latestWeight;
  String get noWeights;
  String get weightSaved;
  String get weightDeleted;
  String get weightHistory;

  // ------------------------------------------------------------- Symptome
  String get symptomsTitle;
  String get addSymptom;
  String get editSymptom;
  String get symptomNameLabel;
  String get intensityLabel;
  String get intensityHint;
  String get symptomHistory;
  String get selectSymptomHint;
  String get noSymptoms;
  String get knownSymptoms;
  String get symptomSaved;
  String get symptomDeleted;

  // ------------------------------------------------------------- Tagesdetail
  String get sectionNutrition;
  String get sectionWater;
  String get sectionCaffeine;
  String get sectionWeight;
  String get sectionCycle;
  String get sectionSymptoms;
  String get nothingLogged;
  String get addForDay;

  // ------------------------------------------------------------- Verläufe
  String get trendsTitle;
  String get last7;
  String get last28;
  String get selectMetricLabel;
  String get trendNoData;
  String get averageLabel;
  String get totalLabel;
  String get minLabel;
  String get maxLabel;
  String trendMetricName(String key);

  // ------------------------------------------------------------- Historie
  String get historyTitle;
  String get historySearchHint;
  String get filterAreaLabel;
  String get filterAll;
  String get filterFrom;
  String get filterTo;
  String get noResults;
  String get openEntry;

  // ------------------------------------------------------------- Einstellungen
  String get settingsTitle;
  String get appearanceSection;
  String get languageLabel;
  String get languageSystem;
  String get languageDe;
  String get languageEn;
  String get languageName;
  String get weightUnitLabel;
  String get areasSection;
  String get areasHint;
  String get goalsSection;
  String get goalsHint;
  String get foodApiSection;
  String get foodApiOrigin;
  String get foodApiUserAgent;
  String get foodApiOfflineHint;
  String get dataSection;
  String get exportData;
  String get importData;
  String get backupCreate;
  String get backupRestore;
  String get deleteAll;
  String get aboutSection;
  String get aboutVersion;
  String get aboutPrivacy;
  String get aboutOffline;
  String get storeErrorTitle;
  String get storeErrorMessage;
  String get storeErrorRetry;
  String get storeErrorDelete;

  // ------------------------------------------------------------- Datentransfer
  String get exportTitle;
  String get exportAck;
  String get importTitle;
  String get importConfirm;
  String get importSuccess;
  String get backupCreateTitle;
  String get backupPassphrase;
  String get backupPassphraseRepeat;
  String get backupPassphraseHint;
  String get backupSuccess;
  String get backupRestoreTitle;
  String get backupRestoreConfirm;
  String get backupRestoreSuccess;
  String get deleteAllTitle;
  String get deleteAllConfirm;
  String get deleteAllSuccess;
  String get passphraseRequired;
  String get passphraseMismatch;
  String get passphraseTooShort;
  String get fileSaveCanceled;

  // ------------------------------------------------------------- Accessibility
  String get a11yBack;
  String get a11yMenu;
  String get a11yAdd;
  String get a11yEdit;
  String get a11yDelete;
  String get a11ySearch;
  String get a11yFavorite;
  String get a11yIncrement;
  String get a11yDecrement;
  String get a11yCalendar;
  String get a11yClose;

  // ------------------------------------------------------------- Namen (sprachspezifisch)
  String mealName(Meal meal);
  String flowName(FlowLevel flow);
  String quantityUnitName(QuantityUnit unit);
  String weekdayName(int weekday); // 1 = Montag .. 7 = Sonntag
  String weekdayShort(int weekday);
  String monthName(int month); // 1..12
  String monthShort(int month);
  String nutrientName(String key);
  String nutrientShort(String key);

  // ------------------------------------------------------------- Formatierung
  // Implementierungen (sprachabhängig) liegen in [AppStringsBase].
  String formatNumber(double value, {int fractionDigits = 1});
  String formatInteger(num value);
  String formatPercent(double percent);
  String formatMl(double ml);
  String formatMg(double mg);
  String formatWeight(double weightKg, String unit);
  String nutrientUnit(String key);
  int nutrientFractionDigits(String key);
  String nutrientAmount(String key, double value);
  String formatDateShort(DateTime d);
  String formatDateLong(DateTime d);
  String daysCount(int n);
  String entriesCount(int n);
  String resultsCount(int n);
  String cycleDayLabel(int day);
  String intensityValue(int intensity);
  String imported(String area, int count);
  String savedAt(String path);
  String percentOfGoal(double percent);
}

/// Gemeinsame Implementierungen (Formatierung, Einheiten, Daten).
///
/// Sprachspezifische Namen (Nährstoffe, Mahlzeiten, Wochentage …) bleiben
/// in den konkreten Klassen [DeStrings] bzw. [EnStrings].
abstract class AppStringsBase extends AppStrings {
  // ------------------------------------------------------------- Zahlen
  /// Formatiert eine Zahl lokalisiert (de: 1.234,5 — en: 1,234.5).
  /// Führende/abschließende Dezimalnullen werden entfernt.
  @override
  String formatNumber(double value, {int fractionDigits = 1}) {
    double v = value.isFinite ? value : 0;
    final bool negative = v < 0;
    v = v.abs();
    final int p = _pow10(fractionDigits);
    final int scaled = (v * p).round();
    final int intDigits = scaled ~/ p;
    String frac = fractionDigits == 0
        ? ''
        : (scaled % p).toString().padLeft(fractionDigits, '0');
    while (frac.endsWith('0')) {
      frac = frac.substring(0, frac.length - 1);
    }
    final String grouped = _groupThousands(intDigits.toString());
    final String dec = lang == 'de' ? ',' : '.';
    final String out = frac.isEmpty ? grouped : '$grouped$dec$frac';
    return negative ? '-$out' : out;
  }

  @override
  String formatInteger(num value) => formatNumber(value.toDouble(), fractionDigits: 0);

  @override
  String formatPercent(double percent) =>
      '${formatNumber(percent, fractionDigits: 0)} %';

  @override
  String formatMl(double ml) => '${formatNumber(ml, fractionDigits: 0)} ml';

  @override
  String formatMg(double mg) => '${formatNumber(mg, fractionDigits: 0)} mg';

  /// Gewicht in der eingestellten Anzeigeeinheit (kg kanonisch gespeichert).
  @override
  String formatWeight(double weightKg, String unit) {
    if (unit == 'lb') {
      return '${formatNumber(weightKg * 2.2046226218, fractionDigits: 1)} lb';
    }
    return '${formatNumber(weightKg, fractionDigits: 1)} kg';
  }

  static int _pow10(int n) {
    int r = 1;
    for (int i = 0; i < n; i++) {
      r *= 10;
    }
    return r;
  }

  String _groupThousands(String digits) {
    final String sep = lang == 'de' ? '.' : ',';
    final StringBuffer b = StringBuffer();
    for (int i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) b.write(sep);
      b.write(digits[i]);
    }
    return b.toString();
  }

  // ------------------------------------------------------------- Nährstoffe
  @override
  String nutrientUnit(String key) {
    final NutrientDef? def = nutrientByKey(key);
    if (def == null) return '';
    return switch (def.unit) {
      NutrientUnit.kcal => 'kcal',
      NutrientUnit.g => 'g',
      NutrientUnit.mg => 'mg',
      NutrientUnit.ug => 'µg',
    };
  }

  @override
  int nutrientFractionDigits(String key) {
    final NutrientDef? def = nutrientByKey(key);
    if (def == null) return 1;
    return switch (def.unit) {
      NutrientUnit.kcal => 0,
      NutrientUnit.g => 1,
      NutrientUnit.mg => 1,
      NutrientUnit.ug => 1,
    };
  }

  /// Wert mit kanonischer Einheit, z. B. „372 kcal“, „13,5 g“.
  @override
  String nutrientAmount(String key, double value) {
    final String number = formatNumber(value, fractionDigits: nutrientFractionDigits(key));
    final String unit = nutrientUnit(key);
    return unit.isEmpty ? number : '$number $unit';
  }

  // ------------------------------------------------------------- Datum/Uhrzeit
  @override
  String formatDateShort(DateTime d) {
    final String dd = d.day.toString().padLeft(2, '0');
    final String mm = d.month.toString().padLeft(2, '0');
    if (lang == 'de') return '$dd.$mm.${d.year}';
    return '${d.year}-$mm-$dd';
  }

  @override
  String formatDateLong(DateTime d) {
    if (lang == 'de') {
      return '${weekdayName(d.weekday)}, ${d.day}. ${monthName(d.month)} ${d.year}';
    }
    return '${weekdayName(d.weekday)}, ${monthName(d.month)} ${d.day}, ${d.year}';
  }

  // ------------------------------------------------------------- Mengenangaben (Texte)
  @override
  String daysCount(int n) => lang == 'de'
      ? (n == 1 ? '1 Tag' : '$n Tage')
      : (n == 1 ? '1 day' : '$n days');

  @override
  String entriesCount(int n) => lang == 'de'
      ? (n == 1 ? '1 Eintrag' : '$n Einträge')
      : (n == 1 ? '1 entry' : '$n entries');

  @override
  String resultsCount(int n) => lang == 'de'
      ? (n == 1 ? '1 Treffer' : '$n Treffer')
      : (n == 1 ? '1 result' : '$n results');

  @override
  String cycleDayLabel(int day) =>
      lang == 'de' ? 'Zyklustag $day' : 'Cycle day $day';

  @override
  String intensityValue(int intensity) =>
      lang == 'de' ? 'Intensität $intensity/10' : 'Intensity $intensity/10';

  @override
  String imported(String area, int count) => '$area: $count';

  @override
  String savedAt(String path) =>
      lang == 'de' ? 'Gespeichert unter: $path' : 'Saved to: $path';

  @override
  String percentOfGoal(double percent) => lang == 'de'
      ? '${formatNumber(percent, fractionDigits: 0)} % vom Ziel'
      : '${formatNumber(percent, fractionDigits: 0)} % of goal';
}

/// Normalisiert eine Sprachangabe auf 'de' | 'en' (Deutsch ist Standard).
String normalizeLanguage(String? lang) => lang == 'en' ? 'en' : 'de';

/// Liefert die Texte zur Sprache (null/unbekannt ⇒ Deutsch).
AppStrings stringsFor(String? lang) =>
    normalizeLanguage(lang) == 'en' ? EnStrings() : DeStrings();
