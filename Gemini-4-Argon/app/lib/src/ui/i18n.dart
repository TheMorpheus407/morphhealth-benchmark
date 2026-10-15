class AppStrings {
  final String lang;

  const AppStrings(this.lang);

  bool get isEn => lang == 'en';

  String t(String de, String en) => isEn ? en : de;

  // Navigation
  String get navOverview => t('Übersicht', 'Overview');
  String get navNutrition => t('Ernährung', 'Nutrition');
  String get navCycle => t('Zyklus', 'Cycle');
  String get navWeightSymptoms => t('Gewicht & Symptome', 'Weight & Symptoms');
  String get navHistorySettings => t('Historie & Daten', 'History & Data');

  // Common
  String get today => t('Heute', 'Today');
  String get save => t('Speichern', 'Save');
  String get cancel => t('Abbrechen', 'Cancel');
  String get delete => t('Löschen', 'Delete');
  String get edit => t('Bearbeiten', 'Edit');
  String get close => t('Schließen', 'Close');
  String get notes => t('Notiz (optional)', 'Note (optional)');
  String get date => t('Datum', 'Date');
  String get time => t('Uhrzeit', 'Time');
  String get days7 => t('7 Tage', '7 Days');
  String get days28 => t('28 Tage', '28 Days');
  String get allTime => t('Gesamt', 'All');
  String get search => t('Suchen', 'Search');

  // Domains
  String get domainAll => t('Alle Bereiche', 'All Areas');
  String get domainNutrition => t('Ernährung', 'Nutrition');
  String get domainCycle => t('Zyklus', 'Cycle');
  String get domainWeight => t('Gewicht', 'Weight');
  String get domainSymptoms => t('Symptome', 'Symptoms');

  // Nutrition
  String get addFood => t('Lebensmittel erfassen', 'Log Food');
  String get customFood => t('Eigenes Lebensmittel', 'Custom Food');
  String get createCustomFood =>
      t('Eigenes Lebensmittel anlegen', 'Create Custom Food');
  String get editCustomFood =>
      t('Eigenes Lebensmittel bearbeiten', 'Edit Custom Food');
  String get favorites => t('Favoriten', 'Favorites');
  String get recentEntries => t('Zuletzt erfasst', 'Recent');
  String get offSearch => t('Open Food Facts', 'Open Food Facts');
  String get barcodeLookup => t('Barcode-Abruf', 'Barcode Lookup');
  String get enterBarcode =>
      t('Barcode-Nummer eingeben (z. B. 5411188112709)', 'Enter barcode number (e.g. 5411188112709)');
  String get searchFoodHint =>
      t('Lebensmittelname suchen (z. B. Haferflocken)', 'Search food name (e.g. Oats)');
  String get logAgain => t('Erneut erfassen', 'Log again');
  String get waterAndCaffeine => t('Wasser & Koffein', 'Water & Caffeine');
  String get water => t('Wasser', 'Water');
  String get caffeine => t('Koffein', 'Caffeine');
  String get dailyGoals => t('Freiwillige Tagesziele', 'Voluntary Daily Goals');
  String get micronutrients => t('Mikronährstoffe & Details', 'Micronutrients & Details');
  String get vitamins => t('Vitamine (13)', 'Vitamins (13)');
  String get minerals => t('Mineralstoffe (8)', 'Minerals (8)');
  String get extendedNutrients =>
      t('Weitere Nährwertangaben', 'Additional Nutrients');
  String get mainMacros => t('Hauptnährwerte', 'Main Macronutrients');
  String get nutrientTrend => t('Nährstoffverlauf', 'Nutrient Trend');

  // Cycle
  String get periodTracker =>
      t('Persönlicher Periodentracker', 'Personal Period Tracker');
  String get logPeriod => t('Periode erfassen', 'Log Period');
  String get editPeriod => t('Periode bearbeiten', 'Edit Period');
  String get cycleAssessment =>
      t('Persönliche Zykluseinschätzung', 'Personal Cycle Assessment');
  String get cycleExplanationTitle =>
      t('Erklärung der Einschätzung', 'Assessment Explanation');
  String get diaryOnlyMode =>
      t('Nur als Tagebuch verwenden (Prognose ausblenden)', 'Use as diary only (hide forecast)');
  String get periodHistory => t('Periodenhistorie', 'Period History');

  // Weight & Symptoms
  String get logWeight => t('Gewicht erfassen', 'Log Weight');
  String get editWeight => t('Gewicht bearbeiten', 'Edit Weight');
  String get logSymptom => t('Symptom erfassen', 'Log Symptom');
  String get editSymptom => t('Symptom bearbeiten', 'Edit Symptom');
  String get symptomIntensity => t('Intensität (0–10)', 'Intensity (0–10)');
  String get symptomTrend => t('Symptomverlauf', 'Symptom Trend');

  // History & Settings
  String get searchableHistory =>
      t('Durchsuchbare Historie', 'Searchable History');
  String get settingsAndData =>
      t('Einstellungen, Sicherung & Portabilität', 'Settings, Backup & Portability');
  String get encryptedBackup =>
      t('Verschlüsselte Sicherung (.mhb)', 'Encrypted Backup (.mhb)');
  String get portableExportImport =>
      t('Maschinenlesbarer Export & Import (JSON)', 'Machine-Readable Export & Import (JSON)');
  String get deleteAllData =>
      t('Gesamten lokalen Datenbestand löschen', 'Delete All Local Data');
}
