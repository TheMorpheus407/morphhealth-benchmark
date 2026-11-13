/// Bilingual UI localization (German default `de`, English `en`).
library;

class MhStrings {
  final String localeCode;

  const MhStrings(this.localeCode);

  bool get isEn => localeCode == 'en';

  String tr(String de, String en) => isEn ? en : de;

  // Navigation
  String get navOverview => tr('Übersicht', 'Overview');
  String get navNutrition => tr('Ernährung', 'Nutrition');
  String get navCycle => tr('Zyklus', 'Cycle');
  String get navBody => tr('Werte', 'Body');
  String get navHistory => tr('Historie', 'History');

  // Common actions
  String get today => tr('Heute', 'Today');
  String get save => tr('Speichern', 'Save');
  String get cancel => tr('Abbrechen', 'Cancel');
  String get delete => tr('Löschen', 'Delete');
  String get edit => tr('Bearbeiten', 'Edit');
  String get close => tr('Schließen', 'Close');
  String get add => tr('Hinzufügen', 'Add');
  String get optionalNote => tr('Notiz (optional)', 'Note (optional)');
  String get date => tr('Datum', 'Date');
  String get time => tr('Uhrzeit', 'Time');
  String get settingsTitle => tr('Einstellungen & Daten', 'Settings & Data');
  String get previousDay => tr('Vorheriger Tag', 'Previous day');
  String get nextDay => tr('Nächster Tag', 'Next day');
  String get pickDate => tr('Datum wählen', 'Select date');

  // Overview & Day Detail & Trends
  String get customizeAreas => tr('Bereiche ein-/ausblenden', 'Show/hide areas');
  String get dayDetailTitle => tr('Gemeinsames Tagesdetail', 'Unified Day Detail');
  String get openDayDetail => tr('Tagesdetail öffnen', 'Open day detail');
  String get trendsTitle => tr('Verläufe (7 & 28 Tage)', 'Trends (7 & 28 days)');
  String get openTrends => tr('7-/28-Tage-Verläufe', '7/28-day trends');
  String get window7Days => tr('7 Tage', '7 days');
  String get window28Days => tr('28 Tage', '28 days');
  String get allModulesHidden => tr(
        'Alle vier Bereiche sind aktuell in der Übersicht ausgeblendet. Über „Bereiche ein-/ausblenden“ kannst du deine gewünschte Auswahl aktivieren.',
        'All four areas are currently hidden on the overview. Use "Show/hide areas" to enable the sections you want.',
      );

  // Nutrition
  String get nutritionDiary => tr('Ernährungstagebuch', 'Nutrition Diary');
  String get addFood => tr('Lebensmittel erfassen', 'Log food');
  String get waterAndCaffeine => tr('Wasser & Koffein', 'Water & Caffeine');
  String get water => tr('Wasser', 'Water');
  String get caffeine => tr('Koffein', 'Caffeine');
  String get customAmount => tr('Eigene Menge', 'Custom amount');
  String get logWater => tr('Wasser erfassen', 'Log water');
  String get logCaffeine => tr('Koffein erfassen', 'Log caffeine');
  String get relogEntry => tr('Erneut erfassen', 'Log again');
  String get reloggedNotice => tr(
        'Eintrag zum gewählten Tag hinzugefügt.',
        'Entry added to the selected day.',
      );
  String get allNutrientsAndMicros => tr(
        'Erweiterte Nährwerte & alle 21 Mikronährstoffe',
        'Extended nutrients & all 21 micronutrients',
      );
  String get macrosSection => tr('Makronährstoffe', 'Macronutrients');
  String get extendedSection => tr('Weitere Nährwerte', 'Extended nutrients');
  String get vitaminsSection => tr('Vitamine (13)', 'Vitamins (13)');
  String get mineralsSection => tr('Mineralstoffe & Spurenelemente (8)', 'Minerals (8)');
  String get goalsButton => tr('Tagesziele', 'Daily goals');
  String get voluntaryGoalsInfo => tr(
        'Freiwillige Orientierungswerte. Leere Felder deaktivieren das jeweilige Ziel.',
        'Voluntary personal targets. Leave any field empty to disable that goal.',
      );
  String get tabOffSearch => tr('Open Food Facts', 'Open Food Facts');
  String get tabRecent => tr('Erneut', 'Recent');
  String get tabFavorites => tr('Favoriten', 'Favorites');
  String get tabCustomFoods => tr('Eigene', 'Custom');
  String get createCustomFood => tr('Eigenes Lebensmittel anlegen', 'Create custom food');
  String get editCustomFood => tr('Eigenes Lebensmittel bearbeiten', 'Edit custom food');
  String get searchByNameHint => tr('Lebensmittelname suchen…', 'Search food by name…');
  String get barcodeHint => tr('Barcode-Nummer eingeben…', 'Enter barcode number…');
  String get lookupBarcodeBtn => tr('Barcode abrufen', 'Lookup barcode');
  String get onlineSearchDisabledMsg => tr(
        'Die Online-Lebensmittelsuche ist in den Datenschutzeinstellungen deaktiviert. Eigene Lebensmittel und Favoriten stehen weiterhin lokal bereit.',
        'Online food search is disabled in privacy settings. Custom foods and favorites remain available locally.',
      );

  // Cycle
  String get cycleTrackerTitle => tr('Persönlicher Periodentracker', 'Personal Period Tracker');
  String get logPeriodOrSpotting => tr('Periode / Spotting erfassen', 'Log period / spotting');
  String get diaryOnlyLabel => tr('Nur als Tagebuch', 'Diary only');
  String get explainForecast => tr('Einschätzung erklären', 'Explain estimate');
  String get periodHistory => tr('Aufgezeichnete Historie', 'Recorded history');
  String get ongoingPeriod => tr('Laufend (Ende offen)', 'Ongoing (open end)');
  String get standaloneSpottingLabel => tr(
        'Einzelnes Spotting / Zwischenblutung (startet keinen neuen Zyklus)',
        'Standalone spotting (does not start a new cycle)',
      );

  // Weight & Symptoms
  String get weightTitle => tr('Gewicht', 'Weight');
  String get symptomsTitle => tr('Symptome', 'Symptoms');
  String get logWeight => tr('Gewicht eintragen', 'Log weight');
  String get logSymptom => tr('Symptom erfassen', 'Log symptom');
  String get symptomNameLabel => tr('Symptombezeichnung', 'Symptom name');
  String get intensityLabel => tr('Intensität (0–10)', 'Intensity (0–10)');
  String get symptomTrendSelect => tr('Symptomverlauf wählen', 'Select symptom trend');

  // History
  String get historySearchHint => tr(
        'Lebensmittel, Symptom, Notiz oder Wert suchen…',
        'Search food, symptom, note, or value…',
      );
  String get allAreas => tr('Alle Bereiche', 'All areas');
  String get allDates => tr('Gesamter Zeitraum', 'All dates');
  String get customRange => tr('Zeitraum wählen', 'Custom range');

  // Portability & Security
  String get portabilitySection => tr(
        'Datensicherung, Export & Löschung',
        'Backup, Export & Data Wipe',
      );
  String get createEncryptedBackup => tr(
        'Verschlüsselte Sicherung erstellen',
        'Create encrypted backup',
      );
  String get restoreEncryptedBackup => tr(
        'Verschlüsselte Sicherung wiederherstellen',
        'Restore encrypted backup',
      );
  String get exportPlainJson => tr(
        'Portabler Datenexport (JSON)',
        'Portable data export (JSON)',
      );
  String get importPlainJson => tr(
        'Portabler Datenimport (JSON)',
        'Portable data import (JSON)',
      );
  String get wipeAllData => tr(
        'Gesamten lokalen Datenbestand löschen',
        'Delete all local data',
      );
}
