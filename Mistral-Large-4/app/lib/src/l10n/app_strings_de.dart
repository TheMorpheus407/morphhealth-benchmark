// Deutsche Texte (Standardsprache, SPEC P02).
library;

import '../model/cycle.dart';
import '../model/entries.dart';
import 'app_strings.dart';

class DeStrings extends AppStringsBase {
  @override
  String get lang => 'de';

  // ------------------------------------------------------------- Allgemein
  @override String get appName => 'MorphHealth';
  @override String get ok => 'OK';
  @override String get cancel => 'Abbrechen';
  @override String get save => 'Speichern';
  @override String get delete => 'Löschen';
  @override String get edit => 'Bearbeiten';
  @override String get close => 'Schließen';
  @override String get add => 'Hinzufügen';
  @override String get search => 'Suchen';
  @override String get retry => 'Erneut versuchen';
  @override String get loading => 'Wird geladen …';
  @override String get done => 'Fertig';
  @override String get yes => 'Ja';
  @override String get no => 'Nein';
  @override String get back => 'Zurück';
  @override String get today => 'Heute';
  @override String get yesterday => 'Gestern';
  @override String get tomorrow => 'Morgen';
  @override String get now => 'Jetzt';
  @override String get dateLabel => 'Datum';
  @override String get timeLabel => 'Uhrzeit';
  @override String get noteLabel => 'Notiz';
  @override String get optionalLabel => 'optional';
  @override String get confirmDeleteTitle => 'Wirklich löschen?';
  @override String get confirmDeleteMessage => 'Dieser Eintrag wird endgültig gelöscht.';
  @override String get errorGeneric => 'Ein Fehler ist aufgetreten.';
  @override String get fieldRequired => 'Pflichtfeld';
  @override String get invalidNumber => 'Ungültige Zahl';
  @override String get clearLabel => 'Leeren';
  @override String get applyLabel => 'Anwenden';
  @override String get resetLabel => 'Zurücksetzen';

  // ------------------------------------------------------------- Bereiche
  @override String get allAreasLabel => 'Alle Bereiche';
  @override
  String areaName(String areaKey) => switch (areaKey) {
        'nutrition' => 'Ernährung',
        'cycle' => 'Zyklus',
        'weight' => 'Gewicht',
        'symptoms' => 'Symptome',
        _ => 'Übersicht',
      };

  // ------------------------------------------------------------- Übersicht
  @override String get todaySection => 'Heute';
  @override String get nutritionCardTitle => 'Ernährung heute';
  @override String get waterCardTitle => 'Wasser heute';
  @override String get cycleCardTitle => 'Zyklus heute';
  @override String get weightCardTitle => 'Gewicht';
  @override String get symptomsCardTitle => 'Symptome heute';
  @override String get openTrends => 'Verläufe öffnen';
  @override String get openHistory => 'Historie durchsuchen';
  @override String get openSettings => 'Einstellungen öffnen';
  @override String get openDayDetail => 'Tagesdetails öffnen';
  @override String get noDataYet => 'Noch keine Daten. Erfasse etwas — es wird hier angezeigt.';

  // ------------------------------------------------------------- Ernährung
  @override String get waterLabel => 'Wasser';
  @override String get caffeineLabel => 'Koffein';
  @override String get addEntry => 'Verzehr hinzufügen';
  @override String get addWater => 'Wasser hinzufügen';
  @override String get addCaffeine => 'Koffein hinzufügen';
  @override String get quickWaterTitle => 'Schnellerfassung';
  @override String get customAmountLabel => 'Eigene Menge';
  @override String get quantityLabel => 'Menge';
  @override String get unitLabel => 'Einheit';
  @override String get per100 => 'pro 100 g';
  @override String get perPortion => 'pro Portion';
  @override String get dayTotal => 'Tagessumme';
  @override String get noGoal => 'Kein Ziel';
  @override String get allNutrients => 'Alle Nährstoffe';
  @override String get mainNutrients => 'Hauptnährstoffe';
  @override String get vitamins => 'Vitamine';
  @override String get minerals => 'Mineralstoffe';
  @override String get noEntriesToday => 'Noch keine Einträge an diesem Tag.';
  @override String get diaryEmpty => 'An diesem Tag ist noch nichts eingetragen.';
  @override String get addFoodFirst => 'Lege ein eigenes Lebensmittel an oder suche in Open Food Facts.';
  @override String get entrySaved => 'Verzehr gespeichert.';
  @override String get entryUpdated => 'Verzehr aktualisiert.';
  @override String get entryDeleted => 'Verzehr gelöscht.';
  @override String get waterSaved => 'Wasser erfasst.';
  @override String get caffeineSaved => 'Koffein erfasst.';
  @override String get foodSearchTitle => 'Lebensmittel suchen';
  @override String get searchHint => 'Name oder Barcode eingeben';
  @override String get searchByBarcode => 'Barcode suchen';
  @override String get barcodeLabel => 'Barcode-Nummer';
  @override String get invalidBarcode => 'Bitte eine gültige Barcode-Nummer eingeben (6–14 Ziffern).';
  @override String get tabSearch => 'Suche';
  @override String get tabFavorites => 'Favoriten';
  @override String get tabCustom => 'Eigene';
  @override String get tabRecent => 'Zuletzt';
  @override String get searchNoResults => 'Keine Treffer gefunden.';
  @override String get searchError => 'Suche fehlgeschlagen. Prüfe die Internetverbindung.';
  @override String get lookupNotFound => 'Produkt nicht gefunden.';
  @override String get addToDiary => 'Zum Tagebuch';
  @override String get reLog => 'Erneut erfassen';
  @override String get foodDetailTitle => 'Lebensmittel';
  @override String get foodNameLabel => 'Name';
  @override String get brandLabel => 'Marke';
  @override String get servingGramsLabel => 'Portionsgröße (g)';
  @override String get servingLabelHint => 'Bezeichnung, z. B. „1 Scheibe“';
  @override String get favoriteAdd => 'Zu Favoriten hinzufügen';
  @override String get favoriteRemove => 'Aus Favoriten entfernen';
  @override String get sourceLabel => 'Quelle';
  @override String get sourceOff => 'Open Food Facts';
  @override String get sourceCustom => 'Eigenes Lebensmittel';
  @override String get offAttribution => 'Produktdaten: Open Food Facts (ODbL)';
  @override String get offLicenseFull => 'Produktdaten von Open Food Facts (openfoodfacts.org), Lizenz: Open Database License (ODbL) 1.0.';
  @override String get nutrientsPer100 => 'Nährwerte pro 100 g';
  @override String get newFood => 'Neues Lebensmittel';
  @override String get editFood => 'Lebensmittel bearbeiten';
  @override String get foodSaved => 'Lebensmittel gespeichert.';
  @override String get foodDeleted => 'Lebensmittel gelöscht.';
  @override String get entryNewTitle => 'Verzehr erfassen';
  @override String get entryEditTitle => 'Verzehr bearbeiten';
  @override String get mealLabel => 'Mahlzeit';
  @override String get foodLabel => 'Lebensmittel';
  @override String get selectFood => 'Lebensmittel auswählen';
  @override String get changeFood => 'Lebensmittel ändern';
  @override String get deleteEntryConfirm => 'Diesen Eintrag löschen?';
  @override String get selectFoodFirst => 'Bitte zuerst ein Lebensmittel auswählen.';
  @override String get goalWaterLabel => 'Wasserziel';
  @override String get goalEnergyLabel => 'Kalorienziel';
  @override String get goalProteinLabel => 'Proteinziel';
  @override String get goalCarbsLabel => 'Kohlenhydratziel';
  @override String get goalFatLabel => 'Fettziel';

  // ------------------------------------------------------------- Zyklus
  @override String get cycleTitle => 'Zyklus';
  @override String get calendarLabel => 'Kalender';
  @override String get addPeriod => 'Periode erfassen';
  @override String get periodStartLabel => 'Beginn';
  @override String get periodEndLabel => 'Ende';
  @override String get periodOngoing => 'läuft noch';
  @override String get flowLabel => 'Blutungsstärke';
  @override String get periodNoteLabel => 'Notiz zur Periode';
  @override String get startPeriodToday => 'Periode heute begonnen';
  @override String get endPeriodToday => 'Periode heute beendet';
  @override String get forecastTitle => 'Persönliche Einschätzung';
  @override String get nextPeriodLabel => 'Nächste Periode';
  @override String get expectedStartLabel => 'Voraussichtlicher Beginn';
  @override String get expectedEndLabel => 'Voraussichtliches Ende';
  @override String get uncertaintyRangeLabel => 'Unsicherer Bereich';
  @override String get averageCycleLabel => 'Ø Zykluslänge';
  @override String get averagePeriodLabel => 'Ø Blutungsdauer';
  @override String get confidenceLabel => 'Übereinstimmung';
  @override String get confidenceLow => 'niedrig';
  @override String get confidenceMedium => 'mittel';
  @override String get confidenceHigh => 'hoch';
  @override String get explanationTitle => 'So kommt die Einschätzung zustande';
  @override String get disclaimer => 'Dies ist eine persönliche Schätzung aus deinen eigenen Aufzeichnungen und keine medizinische Vorhersage, Diagnose oder Behandlungsempfehlung.';
  @override String get cycleHistory => 'Verlauf';
  @override String get noPeriods => 'Noch keine Perioden erfasst. Trage deine erste Periode ein.';
  @override String get periodOpen => 'offen';
  @override String get editPeriod => 'Periode bearbeiten';
  @override String get deletePeriodConfirm => 'Diese Periode löschen?';
  @override String get stateLabel => 'Status';
  @override String get stateNoData => 'Keine Daten';
  @override String get stateInsufficient => 'Wenig Daten';
  @override String get stateBeforeNext => 'Vor der nächsten Periode';
  @override String get stateWithinRecorded => 'In aufgezeichneter Periode';
  @override String get stateWithinPredicted => 'In vorhergesagter Periode';
  @override String get stateBetweenPredicted => 'Zwischen den Perioden';
  @override String get legendRecorded => 'Erfasst';
  @override String get legendPredicted => 'Prognose';
  @override String get legendToday => 'Heute';
  @override String get legendSymptom => 'Symptom';
  @override String get legendWeight => 'Gewicht';
  @override String get periodSaved => 'Periode gespeichert.';
  @override String get periodDeleted => 'Periode gelöscht.';

  // ------------------------------------------------------------- Gewicht
  @override String get weightTitle => 'Gewicht';
  @override String get addWeight => 'Gewicht erfassen';
  @override String get editWeight => 'Gewicht bearbeiten';
  @override String get weightLabel => 'Gewicht';
  @override String get weightKgLabel => 'Gewicht (kg)';
  @override String get weightLbLabel => 'Gewicht (lb)';
  @override String get unitKg => 'kg';
  @override String get unitLb => 'lb';
  @override String get latestWeight => 'Zuletzt erfasst';
  @override String get noWeights => 'Noch keine Gewichtseinträge.';
  @override String get weightSaved => 'Gewicht gespeichert.';
  @override String get weightDeleted => 'Gewicht gelöscht.';
  @override String get weightHistory => 'Verlauf';

  // ------------------------------------------------------------- Symptome
  @override String get symptomsTitle => 'Symptome';
  @override String get addSymptom => 'Symptom erfassen';
  @override String get editSymptom => 'Symptom bearbeiten';
  @override String get symptomNameLabel => 'Symptom';
  @override String get intensityLabel => 'Intensität';
  @override String get intensityHint => '0 = nicht vorhanden, 10 = sehr stark';
  @override String get symptomHistory => 'Verlauf dieses Symptoms';
  @override String get selectSymptomHint => 'Symptom auswählen';
  @override String get noSymptoms => 'Noch keine Symptome erfasst.';
  @override String get knownSymptoms => 'Bekannte Symptome';
  @override String get symptomSaved => 'Symptom gespeichert.';
  @override String get symptomDeleted => 'Symptom gelöscht.';

  // ------------------------------------------------------------- Tagesdetail
  @override String get sectionNutrition => 'Ernährung';
  @override String get sectionWater => 'Wasser';
  @override String get sectionCaffeine => 'Koffein';
  @override String get sectionWeight => 'Gewicht';
  @override String get sectionCycle => 'Periode';
  @override String get sectionSymptoms => 'Symptome';
  @override String get nothingLogged => 'An diesem Tag wurde nichts erfasst.';
  @override String get addForDay => 'Für diesen Tag erfassen';

  // ------------------------------------------------------------- Verläufe
  @override String get trendsTitle => 'Verläufe';
  @override String get last7 => '7 Tage';
  @override String get last28 => '28 Tage';
  @override String get selectMetricLabel => 'Anzeigen';
  @override String get trendNoData => 'Keine Daten im Zeitraum.';
  @override String get averageLabel => 'Ø';
  @override String get totalLabel => 'Summe';
  @override String get minLabel => 'Min';
  @override String get maxLabel => 'Max';
  @override
  String trendMetricName(String key) => switch (key) {
        'energy_kcal' => 'Kalorien',
        'protein_g' => 'Protein',
        'carbohydrates_g' => 'Kohlenhydrate',
        'fat_g' => 'Fett',
        'water' => 'Wasser',
        'caffeine' => 'Koffein',
        'weight' => 'Gewicht',
        _ => nutrientName(key),
      };

  // ------------------------------------------------------------- Historie
  @override String get historyTitle => 'Historie';
  @override String get historySearchHint => 'Freitext — z. B. Lebensmittel, Symptom, Notiz';
  @override String get filterAreaLabel => 'Bereich';
  @override String get filterAll => 'Alle';
  @override String get filterFrom => 'Von';
  @override String get filterTo => 'Bis';
  @override String get noResults => 'Keine Einträge gefunden.';
  @override String get openEntry => 'Öffnen';

  // ------------------------------------------------------------- Einstellungen
  @override String get settingsTitle => 'Einstellungen';
  @override String get appearanceSection => 'Darstellung';
  @override String get languageLabel => 'Sprache';
  @override String get languageSystem => 'Systemeinstellung';
  @override String get languageDe => 'Deutsch';
  @override String get languageEn => 'Englisch';
  @override String get languageName => 'Deutsch';
  @override String get weightUnitLabel => 'Gewichtseinheit';
  @override String get areasSection => 'Sichtbare Bereiche';
  @override String get areasHint => 'Mindestens ein Bereich muss sichtbar sein.';
  @override String get goalsSection => 'Tagesziele (freiwillig)';
  @override String get goalsHint => 'Leer lassen bedeutet: kein Ziel.';
  @override String get foodApiSection => 'Lebensmittel-Suche (Open Food Facts)';
  @override String get foodApiOrigin => 'Server';
  @override String get foodApiUserAgent => 'User-Agent';
  @override String get foodApiOfflineHint => 'Die Suche benötigt eine Internetverbindung.';
  @override String get dataSection => 'Daten';
  @override String get exportData => 'Exportieren (Klartext-JSON)';
  @override String get importData => 'Importieren (JSON)';
  @override String get backupCreate => 'Sicherung erstellen (verschlüsselt)';
  @override String get backupRestore => 'Sicherung wiederherstellen';
  @override String get deleteAll => 'Alle Daten löschen';
  @override String get aboutSection => 'Über MorphHealth';
  @override String get aboutVersion => 'Version';
  @override String get aboutPrivacy => 'Alle Daten bleiben verschlüsselt auf diesem Gerät. Kein Konto, keine Telemetrie, keine Werbung.';
  @override String get aboutOffline => 'Alle Funktionen außer der Lebensmittelsuche funktionieren ohne Internetverbindung.';
  @override String get storeErrorTitle => 'Datenbestand nicht lesbar';
  @override String get storeErrorMessage => 'Die gespeicherten Daten konnten nicht entschlüsselt werden (falscher Schlüssel oder beschädigte Datei).';
  @override String get storeErrorRetry => 'Erneut versuchen';
  @override String get storeErrorDelete => 'Daten löschen und neu beginnen';

  // ------------------------------------------------------------- Datentransfer
  @override String get exportTitle => 'Daten exportieren';
  @override String get exportAck => 'Ich verstehe: Der Export enthält alle Gesundheitsdaten im Klartext.';
  @override String get importTitle => 'Daten importieren';
  @override String get importConfirm => 'Der Import ersetzt den gesamten aktuellen Datenbestand.';
  @override String get importSuccess => 'Import abgeschlossen.';
  @override String get backupCreateTitle => 'Sicherung erstellen';
  @override String get backupPassphrase => 'Passphrase';
  @override String get backupPassphraseRepeat => 'Passphrase wiederholen';
  @override String get backupPassphraseHint => 'Mindestens 8 Zeichen. Ohne Passphrase ist die Sicherung nicht wiederherstellbar.';
  @override String get backupSuccess => 'Sicherung erstellt.';
  @override String get backupRestoreTitle => 'Sicherung wiederherstellen';
  @override String get backupRestoreConfirm => 'Die Wiederherstellung ersetzt den aktuellen Datenbestand.';
  @override String get backupRestoreSuccess => 'Sicherung wiederhergestellt.';
  @override String get deleteAllTitle => 'Alle Daten löschen';
  @override String get deleteAllConfirm => 'Wirklich ALLE lokalen Daten löschen? Dies kann nicht rückgängig gemacht werden.';
  @override String get deleteAllSuccess => 'Alle Daten wurden gelöscht.';
  @override String get passphraseRequired => 'Bitte eine Passphrase eingeben.';
  @override String get passphraseMismatch => 'Die Passphrasen stimmen nicht überein.';
  @override String get passphraseTooShort => 'Die Passphrase muss mindestens 8 Zeichen haben.';
  @override String get fileSaveCanceled => 'Abgebrochen.';

  // ------------------------------------------------------------- Accessibility
  @override String get a11yBack => 'Zurück';
  @override String get a11yMenu => 'Menü';
  @override String get a11yAdd => 'Hinzufügen';
  @override String get a11yEdit => 'Bearbeiten';
  @override String get a11yDelete => 'Löschen';
  @override String get a11ySearch => 'Suchen';
  @override String get a11yFavorite => 'Favorit umschalten';
  @override String get a11yIncrement => 'Wert erhöhen';
  @override String get a11yDecrement => 'Wert verringern';
  @override String get a11yCalendar => 'Kalender';
  @override String get a11yClose => 'Schließen';

  // ------------------------------------------------------------- Namen
  @override
  String mealName(Meal meal) => switch (meal) {
        Meal.breakfast => 'Frühstück',
        Meal.lunch => 'Mittagessen',
        Meal.dinner => 'Abendessen',
        Meal.snack => 'Snack',
      };

  @override
  String flowName(FlowLevel flow) => switch (flow) {
        FlowLevel.spotting => 'Spotting',
        FlowLevel.light => 'leicht',
        FlowLevel.medium => 'mittel',
        FlowLevel.heavy => 'stark',
      };

  @override
  String quantityUnitName(QuantityUnit unit) => switch (unit) {
        QuantityUnit.g => 'Gramm',
        QuantityUnit.ml => 'Milliliter',
        QuantityUnit.portion => 'Portion',
      };

  @override
  String weekdayName(int weekday) => switch (weekday) {
        1 => 'Montag',
        2 => 'Dienstag',
        3 => 'Mittwoch',
        4 => 'Donnerstag',
        5 => 'Freitag',
        6 => 'Samstag',
        7 => 'Sonntag',
        _ => '',
      };

  @override
  String weekdayShort(int weekday) => switch (weekday) {
        1 => 'Mo',
        2 => 'Di',
        3 => 'Mi',
        4 => 'Do',
        5 => 'Fr',
        6 => 'Sa',
        7 => 'So',
        _ => '',
      };

  @override
  String monthName(int month) => switch (month) {
        1 => 'Januar',
        2 => 'Februar',
        3 => 'März',
        4 => 'April',
        5 => 'Mai',
        6 => 'Juni',
        7 => 'Juli',
        8 => 'August',
        9 => 'September',
        10 => 'Oktober',
        11 => 'November',
        12 => 'Dezember',
        _ => '',
      };

  @override
  String monthShort(int month) => switch (month) {
        1 => 'Jan',
        2 => 'Feb',
        3 => 'Mär',
        4 => 'Apr',
        5 => 'Mai',
        6 => 'Jun',
        7 => 'Jul',
        8 => 'Aug',
        9 => 'Sep',
        10 => 'Okt',
        11 => 'Nov',
        12 => 'Dez',
        _ => '',
      };

  @override
  String nutrientName(String key) => switch (key) {
        'energy_kcal' => 'Kalorien',
        'protein_g' => 'Protein',
        'carbohydrates_g' => 'Kohlenhydrate',
        'fat_g' => 'Fett',
        'saturated_fat_g' => 'Gesättigte Fettsäuren',
        'sugars_g' => 'Zucker',
        'fiber_g' => 'Ballaststoffe',
        'salt_g' => 'Salz',
        'sodium_mg' => 'Natrium',
        'caffeine_mg' => 'Koffein',
        'vitamin_a_ug' => 'Vitamin A',
        'vitamin_c_mg' => 'Vitamin C',
        'vitamin_d_ug' => 'Vitamin D',
        'vitamin_e_mg' => 'Vitamin E',
        'vitamin_k_ug' => 'Vitamin K',
        'vitamin_b1_mg' => 'Vitamin B1 (Thiamin)',
        'vitamin_b2_mg' => 'Vitamin B2 (Riboflavin)',
        'vitamin_b3_mg' => 'Vitamin B3 (Niacin)',
        'vitamin_b5_mg' => 'Vitamin B5 (Pantothensäure)',
        'vitamin_b6_mg' => 'Vitamin B6',
        'vitamin_b7_ug' => 'Vitamin B7 (Biotin)',
        'vitamin_b9_ug' => 'Vitamin B9 (Folsäure)',
        'vitamin_b12_ug' => 'Vitamin B12',
        'calcium_mg' => 'Kalzium',
        'iron_mg' => 'Eisen',
        'magnesium_mg' => 'Magnesium',
        'potassium_mg' => 'Kalium',
        'zinc_mg' => 'Zink',
        'selenium_ug' => 'Selen',
        'iodine_ug' => 'Jod',
        'phosphorus_mg' => 'Phosphor',
        _ => key,
      };

  @override
  String nutrientShort(String key) => switch (key) {
        'energy_kcal' => 'kcal',
        'protein_g' => 'Protein',
        'carbohydrates_g' => 'Kohlenhydr.',
        'fat_g' => 'Fett',
        'saturated_fat_g' => 'ges. FS',
        'sugars_g' => 'Zucker',
        'fiber_g' => 'Ballastst.',
        'salt_g' => 'Salz',
        'sodium_mg' => 'Natrium',
        'caffeine_mg' => 'Koffein',
        'vitamin_a_ug' => 'Vit. A',
        'vitamin_c_mg' => 'Vit. C',
        'vitamin_d_ug' => 'Vit. D',
        'vitamin_e_mg' => 'Vit. E',
        'vitamin_k_ug' => 'Vit. K',
        'vitamin_b1_mg' => 'Vit. B1',
        'vitamin_b2_mg' => 'Vit. B2',
        'vitamin_b3_mg' => 'Vit. B3',
        'vitamin_b5_mg' => 'Vit. B5',
        'vitamin_b6_mg' => 'Vit. B6',
        'vitamin_b7_ug' => 'Vit. B7',
        'vitamin_b9_ug' => 'Vit. B9',
        'vitamin_b12_ug' => 'Vit. B12',
        'calcium_mg' => 'Kalzium',
        'iron_mg' => 'Eisen',
        'magnesium_mg' => 'Magnesium',
        'potassium_mg' => 'Kalium',
        'zinc_mg' => 'Zink',
        'selenium_ug' => 'Selen',
        'iodine_ug' => 'Jod',
        'phosphorus_mg' => 'Phosphor',
        _ => key,
      };
}
