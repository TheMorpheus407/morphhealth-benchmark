// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get appName => 'MorphHealth';

  @override
  String get navOverview => 'Übersicht';

  @override
  String get navNutrition => 'Ernährung';

  @override
  String get navCycle => 'Zyklus';

  @override
  String get navWeight => 'Gewicht';

  @override
  String get navSymptoms => 'Symptome';

  @override
  String get commonSave => 'Speichern';

  @override
  String get commonCancel => 'Abbrechen';

  @override
  String get commonDelete => 'Löschen';

  @override
  String get commonClose => 'Schließen';

  @override
  String get commonRetry => 'Erneut versuchen';

  @override
  String get commonToday => 'Heute';

  @override
  String get bootFailedTitle => 'Der Datenbestand lässt sich nicht öffnen';

  @override
  String get bootLoading => 'MorphHealth wird geöffnet';

  @override
  String get commonOk => 'OK';

  @override
  String get commonEdit => 'Bearbeiten';

  @override
  String get commonAdd => 'Hinzufügen';

  @override
  String get commonBack => 'Zurück';

  @override
  String get commonDone => 'Fertig';

  @override
  String get commonUndo => 'Rückgängig';

  @override
  String get commonMore => 'Mehr';

  @override
  String get commonDate => 'Datum';

  @override
  String get commonTime => 'Uhrzeit';

  @override
  String get commonNote => 'Notiz';

  @override
  String get commonNoteOptional => 'Notiz (optional)';

  @override
  String get commonRequired => 'Bitte ausfüllen';

  @override
  String get commonInvalidNumber => 'Bitte eine gültige Zahl eingeben';

  @override
  String get commonMustBePositive => 'Der Wert muss größer als 0 sein';

  @override
  String get commonNone => 'keine';

  @override
  String get commonAll => 'Alle';

  @override
  String get commonShow => 'Anzeigen';

  @override
  String get commonHide => 'Ausblenden';

  @override
  String get dayPrevious => 'Vorheriger Tag';

  @override
  String get dayNext => 'Nächster Tag';

  @override
  String get dayPick => 'Datum wählen';

  @override
  String commonDeletedItem(String what) {
    return '$what gelöscht';
  }

  @override
  String get commonSaved => 'Gespeichert';

  @override
  String commonError(String message) {
    return 'Das hat nicht geklappt: $message';
  }

  @override
  String get unitG => 'g';

  @override
  String get unitMl => 'ml';

  @override
  String get unitPortion => 'Portion';

  @override
  String get unitKg => 'kg';

  @override
  String get unitLb => 'lb';

  @override
  String get mealBreakfast => 'Frühstück';

  @override
  String get mealLunch => 'Mittagessen';

  @override
  String get mealDinner => 'Abendessen';

  @override
  String get mealSnack => 'Snack';

  @override
  String get flowSpotting => 'Spotting';

  @override
  String get flowLight => 'Leicht';

  @override
  String get flowMedium => 'Mittel';

  @override
  String get flowHeavy => 'Stark';

  @override
  String get flowNone => 'Keine Angabe';

  @override
  String get nutritionTabDiary => 'Tagebuch';

  @override
  String get nutritionTabTrends => 'Verlauf';

  @override
  String get nutritionAddFood => 'Lebensmittel hinzufügen';

  @override
  String get nutritionDaySummary => 'Tagessumme';

  @override
  String nutritionKcalOfGoal(String value, String goal) {
    return '$value von $goal kcal';
  }

  @override
  String nutritionKcalPlain(String value) {
    return '$value kcal';
  }

  @override
  String nutritionKcalLeft(String value) {
    return '$value kcal bis zum Ziel';
  }

  @override
  String nutritionKcalOver(String value) {
    return '$value kcal über dem Ziel';
  }

  @override
  String get nutritionGoalReached => 'Ziel erreicht';

  @override
  String get nutritionAllNutrients => 'Alle Nährwerte';

  @override
  String get nutritionMealEmpty => 'Noch nichts erfasst';

  @override
  String nutritionAddToMeal(String meal) {
    return 'Zu $meal hinzufügen';
  }

  @override
  String get nutritionEntryRelog => 'Erneut erfassen';

  @override
  String nutritionRelogged(String name) {
    return '„$name“ erneut erfasst';
  }

  @override
  String get nutritionEntryDeleted => 'Eintrag gelöscht';

  @override
  String get nutritionDayEmpty => 'An diesem Tag ist noch nichts erfasst.';

  @override
  String nutritionEntrySubtitle(String amount, String kcal) {
    return '$amount · $kcal';
  }

  @override
  String get nutritionNoKcal => 'keine kcal-Angabe';

  @override
  String get nutritionNoData => 'keine Angabe';

  @override
  String nutritionCoverage(String count, String total) {
    return 'nur bei $count von $total Einträgen angegeben';
  }

  @override
  String get nutritionShowDetails => 'Details anzeigen';

  @override
  String get waterTitle => 'Wasser';

  @override
  String waterOfGoal(String value, String goal) {
    return '$value von $goal ml';
  }

  @override
  String waterPlain(String value) {
    return '$value ml';
  }

  @override
  String waterQuickAdd(String amount) {
    return '$amount ml Wasser hinzufügen';
  }

  @override
  String waterAdded(String amount) {
    return '$amount ml Wasser erfasst';
  }

  @override
  String get waterOther => 'Andere Menge';

  @override
  String get waterLogTitle => 'Wasser erfassen';

  @override
  String get waterEditTitle => 'Wassereintrag bearbeiten';

  @override
  String get waterAmountLabel => 'Menge in ml';

  @override
  String waterEntryTitle(String amount) {
    return '$amount ml Wasser';
  }

  @override
  String get waterEntriesToday => 'Einträge dieses Tages';

  @override
  String get caffeineTitle => 'Koffein';

  @override
  String caffeineTotal(String value) {
    return '$value mg gesamt';
  }

  @override
  String caffeineFromFoods(String value) {
    return '$value mg aus Lebensmitteln';
  }

  @override
  String caffeineAdditional(String value) {
    return '$value mg zusätzlich erfasst';
  }

  @override
  String get caffeineLogTitle => 'Koffein erfassen';

  @override
  String get caffeineEditTitle => 'Koffeineintrag bearbeiten';

  @override
  String get caffeineAmountLabel => 'Menge in mg';

  @override
  String get caffeineLabelHint => 'Bezeichnung (optional)';

  @override
  String get caffeinePresetNote => 'Richtwerte zum Anpassen';

  @override
  String get caffeineCoffee => 'Kaffee';

  @override
  String get caffeineEspresso => 'Espresso';

  @override
  String get caffeineTea => 'Schwarztee';

  @override
  String get caffeineGreenTea => 'Grüner Tee';

  @override
  String get caffeineCola => 'Cola';

  @override
  String get caffeineEnergy => 'Energy-Drink';

  @override
  String caffeineEntryTitle(String mg) {
    return '$mg mg Koffein';
  }

  @override
  String caffeineAdded(String mg) {
    return '$mg mg Koffein erfasst';
  }

  @override
  String get pickerSearchHint => 'Lebensmittel suchen';

  @override
  String get pickerBarcodeHint => 'Barcode-Nummer eingeben';

  @override
  String get pickerModeName => 'Name';

  @override
  String get pickerModeBarcode => 'Barcode';

  @override
  String get pickerTabSearch => 'Suche';

  @override
  String get pickerTabRecent => 'Zuletzt';

  @override
  String get pickerTabFavorites => 'Favoriten';

  @override
  String get pickerTabCustom => 'Eigene';

  @override
  String get pickerSearchButton => 'Suchen';

  @override
  String get pickerOnlineHint =>
      'Die Suche nutzt Open Food Facts. Dabei wird nur der Suchbegriff an den Dienst gesendet.';

  @override
  String get pickerOnlineDisabled =>
      'Die Online-Suche ist ausgeschaltet. Du kannst sie in den Einstellungen einschalten.';

  @override
  String pickerNoResults(String query) {
    return 'Keine Treffer für „$query“.';
  }

  @override
  String get pickerBarcodeNotFound => 'Zu dieser Nummer wurde kein Produkt gefunden.';

  @override
  String get pickerBarcodeInvalid => 'Eine Barcode-Nummer hat 8 bis 14 Ziffern.';

  @override
  String get pickerLoadMore => 'Mehr laden';

  @override
  String pickerResultCount(String count) {
    return '$count Treffer';
  }

  @override
  String get pickerErrorOffline => 'Keine Verbindung zum Lebensmitteldienst. Bitte prüfe die Internetverbindung.';

  @override
  String get pickerErrorTimeout => 'Der Lebensmitteldienst antwortet nicht rechtzeitig.';

  @override
  String get pickerErrorTls => 'Die gesicherte Verbindung wurde abgelehnt (Zertifikat).';

  @override
  String get pickerErrorRate => 'Der Dienst ist gerade überlastet. Bitte später erneut versuchen.';

  @override
  String pickerErrorGeneric(String code) {
    return 'Die Anfrage ist fehlgeschlagen ($code).';
  }

  @override
  String get pickerCreateCustom => 'Eigenes Lebensmittel anlegen';

  @override
  String get pickerNoRecent => 'Noch nichts erfasst. Hier erscheinen zuletzt verwendete Lebensmittel.';

  @override
  String get pickerNoFavorites => 'Noch keine Favoriten. Tippe in einem Eintrag auf den Stern.';

  @override
  String get pickerNoCustom => 'Noch keine eigenen Lebensmittel.';

  @override
  String get pickerNoLocalMatches => 'Keine passenden Lebensmittel in dieser Liste.';

  @override
  String foodPer100(String unit) {
    return 'je 100 $unit';
  }

  @override
  String foodKcalPer100(String kcal, String unit) {
    return '$kcal kcal je 100 $unit';
  }

  @override
  String get foodNoNutrition => 'Keine Nährwerte hinterlegt';

  @override
  String get foodSourceOff => 'Open Food Facts';

  @override
  String get foodSourceCustom => 'Eigenes Lebensmittel';

  @override
  String get foodUnnamed => 'Unbenanntes Produkt';

  @override
  String get foodDetailsLoading => 'Produktdetails werden geladen';

  @override
  String get foodDetailsFallback => 'Die Details konnten nicht geladen werden. Es gelten die Werte aus der Suche.';

  @override
  String get foodFavoriteAdded => 'Zu Favoriten hinzugefügt';

  @override
  String get foodFavoriteRemoved => 'Aus Favoriten entfernt';

  @override
  String get foodDeleteLibraryTitle => 'Lebensmittel löschen?';

  @override
  String foodDeleteLibraryMessage(String name) {
    return '„$name“ wird aus deiner Bibliothek entfernt. Bereits erfasste Einträge bleiben erhalten.';
  }

  @override
  String get entryAddTitle => 'Eintrag hinzufügen';

  @override
  String get entryEditTitle => 'Eintrag bearbeiten';

  @override
  String get entryAmount => 'Menge';

  @override
  String get entryUnit => 'Einheit';

  @override
  String get entryServingSize => 'Eine Portion entspricht';

  @override
  String get entryServingRequired => 'Bitte gib die Größe einer Portion an.';

  @override
  String entryServingInfo(String amount, String unit) {
    return '1 Portion = $amount $unit';
  }

  @override
  String get entryPreview => 'Nährwerte für diese Menge';

  @override
  String get entryMeal => 'Mahlzeit';

  @override
  String get entryFavoriteAdd => 'Zu Favoriten hinzufügen';

  @override
  String get entryFavoriteRemove => 'Aus Favoriten entfernen';

  @override
  String get entryDelete => 'Eintrag löschen';

  @override
  String get entryCopyToCustom => 'Als eigenes Lebensmittel kopieren';

  @override
  String get entryDataSource => 'Daten: Open Food Facts (ODbL)';

  @override
  String get entryPreparedNote => 'Die Werte gelten für das zubereitete Produkt.';

  @override
  String get entryIncompleteData => 'Für dieses Produkt fehlen Nährwerte.';

  @override
  String entryAddedToMeal(String name, String meal) {
    return '„$name“ zu $meal hinzugefügt';
  }

  @override
  String get entryUpdated => 'Eintrag aktualisiert';

  @override
  String get customTitleNew => 'Eigenes Lebensmittel';

  @override
  String get customTitleEdit => 'Lebensmittel bearbeiten';

  @override
  String get customName => 'Name';

  @override
  String get customBrand => 'Marke (optional)';

  @override
  String get customBarcode => 'Barcode (optional)';

  @override
  String get customBasis => 'Die Nährwerte beziehen sich auf';

  @override
  String get customPer100g => '100 g';

  @override
  String get customPer100ml => '100 ml';

  @override
  String get customServing => 'Portionsgröße (optional)';

  @override
  String get customServingLabel => 'Bezeichnung (optional)';

  @override
  String customSectionMain(String unit) {
    return 'Hauptnährwerte je 100 $unit';
  }

  @override
  String get customSectionMore => 'Weitere Nährwerte';

  @override
  String get customSectionVitamins => 'Vitamine';

  @override
  String get customSectionMinerals => 'Mineralstoffe';

  @override
  String get customFavorite => 'Als Favorit markieren';

  @override
  String get customNoteEntries => 'Änderungen gelten auch für bereits erfasste Einträge dieses Lebensmittels.';

  @override
  String get customSaltSodium => 'Ist nur Salz oder nur Natrium angegeben, wird das andere berechnet.';

  @override
  String customSaved(String name) {
    return '„$name“ gespeichert';
  }

  @override
  String get nutrientsTitle => 'Nährwerte';

  @override
  String get nutrientsGroupMain => 'Energie und Hauptnährstoffe';

  @override
  String get nutrientsGroupMore => 'Weitere Nährwerte';

  @override
  String get nutrientsGroupVitamins => 'Vitamine';

  @override
  String get nutrientsGroupMinerals => 'Mineralstoffe';

  @override
  String get nutrientsDashHint => 'Ein Strich (–) steht für fehlende Angaben in den erfassten Einträgen.';

  @override
  String get trendsRange7 => '7 Tage';

  @override
  String get trendsRange28 => '28 Tage';

  @override
  String get trendsMetric => 'Anzeigen';

  @override
  String trendsAverage(String value, String days, String total) {
    return 'Durchschnitt: $value ($days von $total Tagen erfasst)';
  }

  @override
  String trendsMinMax(String min, String max) {
    return 'Niedrigster Wert $min, höchster Wert $max';
  }

  @override
  String get trendsNoData => 'Im gewählten Zeitraum sind keine Werte erfasst.';

  @override
  String get trendsGoal => 'Ziel';

  @override
  String get trendsChartHint => 'Balken antippen, um den Wert zu sehen';

  @override
  String get trendsNoDataDay => 'keine Angabe';

  @override
  String trendsSummary(String metric, String range, String avg, String days, String total) {
    return '$metric, $range. Durchschnitt $avg. $days von $total Tagen mit Angaben.';
  }

  @override
  String get historyTitle => 'Historie';

  @override
  String get historySearchHint => 'Suchen (Name, Notiz, Symptom …)';

  @override
  String get historyAreas => 'Bereiche';

  @override
  String get historyPeriod => 'Zeitraum';

  @override
  String get historyPreset7 => 'Letzte 7 Tage';

  @override
  String get historyPreset28 => 'Letzte 28 Tage';

  @override
  String get historyPreset90 => 'Letzte 90 Tage';

  @override
  String get historyPresetAll => 'Gesamter Zeitraum';

  @override
  String get historyCustomRange => 'Zeitraum wählen';

  @override
  String historyCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Einträge',
      one: '1 Eintrag',
      zero: 'Keine Einträge',
    );
    return '$_temp0';
  }

  @override
  String get historyEmpty => 'Keine Einträge gefunden. Passe Suchbegriff oder Filter an.';

  @override
  String get historyClearFilters => 'Filter zurücksetzen';

  @override
  String historyPeriodTitle(String from, String to) {
    return 'Periode $from bis $to';
  }

  @override
  String historyPeriodOpen(String from) {
    return 'Periode ab $from (läuft)';
  }

  @override
  String historySymptomTitle(String name, String intensity) {
    return '$name · $intensity von 10';
  }

  @override
  String historyCaffeineTitle(String mg) {
    return '$mg mg Koffein';
  }

  @override
  String get weightAdd => 'Gewicht erfassen';

  @override
  String get weightEditTitle => 'Gewichtseintrag bearbeiten';

  @override
  String get weightValueLabel => 'Gewicht';

  @override
  String weightLatest(String value, String date) {
    return 'Zuletzt: $value am $date';
  }

  @override
  String weightChange(String delta) {
    return '$delta gegenüber dem vorherigen Eintrag';
  }

  @override
  String get weightNoEntries => 'Noch kein Gewicht erfasst.';

  @override
  String get weightRange90 => '90 Tage';

  @override
  String get weightRangeAll => 'Alles';

  @override
  String weightChartSummary(String range, String first, String last, int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count Einträge', one: '1 Eintrag');
    return 'Gewichtsverlauf, $range. Erster Wert $first, letzter Wert $last, $_temp0.';
  }

  @override
  String weightStats(String min, String max, String delta) {
    return 'Niedrigster Wert $min, höchster Wert $max, Änderung $delta';
  }

  @override
  String get weightChartHint => 'Punkt antippen, um den Wert zu sehen';

  @override
  String get weightEntriesTitle => 'Einträge';

  @override
  String get weightNoteHint => 'Notiz (optional)';

  @override
  String get weightNoRange => 'Im gewählten Zeitraum ist kein Gewicht erfasst.';

  @override
  String get symptomAdd => 'Symptom erfassen';

  @override
  String get symptomEditTitle => 'Symptom bearbeiten';

  @override
  String get symptomNameLabel => 'Name des Symptoms';

  @override
  String get symptomIntensity => 'Intensität';

  @override
  String symptomIntensityValue(String value) {
    return '$value von 10';
  }

  @override
  String get symptomIntensityHint => '0 = kaum spürbar, 10 = sehr stark';

  @override
  String get symptomRecent => 'Zuletzt verwendet';

  @override
  String get symptomTabDay => 'Tag';

  @override
  String get symptomTabHistory => 'Verlauf';

  @override
  String get symptomNoEntries => 'An diesem Tag sind keine Symptome erfasst.';

  @override
  String get symptomPick => 'Symptom wählen';

  @override
  String symptomStats(int count, String avg, String max) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count Einträge', one: '1 Eintrag');
    return '$_temp0, Durchschnitt $avg von 10, Höchstwert $max';
  }

  @override
  String get symptomNoHistory =>
      'Noch keine Symptome erfasst. Sobald du eines erfasst, kannst du hier den Verlauf ansehen.';

  @override
  String symptomChartSummary(String name, String range, int count, String avg) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count Einträge', one: '1 Eintrag');
    return 'Verlauf von $name, $range. $_temp0, Durchschnitt $avg von 10.';
  }

  @override
  String symptomLogged(String name) {
    return '„$name“ erfasst';
  }

  @override
  String symptomEntryTitle(String name, String intensity) {
    return '$name, Intensität $intensity von 10';
  }

  @override
  String get symptomNoInRange => 'Im gewählten Zeitraum ist dieses Symptom nicht erfasst.';

  @override
  String get cycleTabCalendar => 'Kalender';

  @override
  String get cycleTabHistory => 'Historie';

  @override
  String get cycleForecastTitle => 'Einschätzung';

  @override
  String cycleStateAsOf(String date) {
    return 'Stand: $date';
  }

  @override
  String get cycleNoDataTitle => 'Noch keine Perioden erfasst';

  @override
  String get cycleNoDataBody =>
      'Sobald zwei Periodenbeginne vorliegen, schätzt MorphHealth den nächsten Beginn aus deinen eigenen Abständen.';

  @override
  String get cycleInsufficientTitle => 'Für eine Einschätzung fehlen noch Daten';

  @override
  String get cycleInsufficientBody =>
      'Ein Zyklus braucht zwei Periodenbeginne. Trage weitere Perioden ein oder lege in den Einstellungen eine typische Zykluslänge fest.';

  @override
  String cycleInPeriodTitle(String day) {
    return 'Tag $day der Periode';
  }

  @override
  String cyclePredictedIn(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Beginn voraussichtlich in $days Tagen',
      one: 'Beginn voraussichtlich morgen',
      zero: 'Beginn voraussichtlich heute',
    );
    return '$_temp0';
  }

  @override
  String cycleNextStart(String date) {
    return 'Voraussichtlicher Beginn: $date';
  }

  @override
  String cycleWindowLine(String from, String to) {
    return 'Zeitfenster: $from bis $to';
  }

  @override
  String cycleOverdueTitle(int days) {
    String _temp0 = intl.Intl.pluralLogic(days, locale: localeName, other: '$days Tage', one: '1 Tag');
    return 'Der berechnete Beginn liegt $_temp0 zurück';
  }

  @override
  String get cycleOverdueBody => 'Es ist noch keine neue Periode erfasst. Trage den Beginn ein, sobald er eintritt.';

  @override
  String get cycleStaleTitle => 'Der letzte erfasste Beginn liegt lange zurück';

  @override
  String get cycleStaleBody => 'Vermutlich fehlen Einträge, deshalb gibt es keine aktuelle Einschätzung.';

  @override
  String get cycleDisabledTitle => 'Prognose ausgeschaltet';

  @override
  String get cycleDisabledBody =>
      'Der Zyklusbereich arbeitet als reines Tagebuch. Du kannst die Prognose in den Einstellungen einschalten.';

  @override
  String cycleCycleDay(String day) {
    return 'Zyklustag $day';
  }

  @override
  String cycleConfidence(String level) {
    return 'Verlässlichkeit: $level';
  }

  @override
  String get cycleConfHigh => 'hoch';

  @override
  String get cycleConfMedium => 'mittel';

  @override
  String get cycleConfLow => 'niedrig';

  @override
  String get cycleExplainButton => 'Wie kommt die Einschätzung zustande?';

  @override
  String get cycleExplainTitle => 'Erklärung der Einschätzung';

  @override
  String get cycleExplainIntervals => 'Abstände zwischen Periodenbeginnen';

  @override
  String get cycleExplainUsed => 'verwendet';

  @override
  String get cycleExplainTooShort => 'nicht verwendet: unter 15 Tagen';

  @override
  String get cycleExplainTooLong => 'nicht verwendet: über 60 Tagen';

  @override
  String get cycleExplainOlder => 'nicht verwendet: älter als die letzten 6 Zyklen';

  @override
  String get cycleExplainNoIntervals => 'Noch keine Abstände vorhanden.';

  @override
  String cycleIntervalRow(String from, String to, String days) {
    return '$from bis $to: $days Tage';
  }

  @override
  String get cycleStartToday => 'Periode beginnt heute';

  @override
  String cycleStartOnDay(String date) {
    return 'Periode beginnt am $date';
  }

  @override
  String get cycleEndToday => 'Periode endet heute';

  @override
  String cycleEndOnDay(String date) {
    return 'Periode endet am $date';
  }

  @override
  String cycleStartedSnack(String date) {
    return 'Periode ab $date erfasst';
  }

  @override
  String cycleEndedSnack(String date) {
    return 'Ende der Periode am $date erfasst';
  }

  @override
  String get cycleAddPeriod => 'Periode erfassen';

  @override
  String get cycleEditPeriod => 'Periode bearbeiten';

  @override
  String get cycleStart => 'Beginn';

  @override
  String get cycleEnd => 'Ende';

  @override
  String get cycleOngoing => 'Läuft noch (kein Ende erfasst)';

  @override
  String get cycleFlow => 'Blutungsstärke';

  @override
  String get cycleNotes => 'Notizen';

  @override
  String cycleOverlap(String from, String to) {
    return 'Die Periode überschneidet sich mit einer vorhandenen Periode ($from bis $to).';
  }

  @override
  String get cycleEndBeforeStart => 'Das Ende liegt vor dem Beginn.';

  @override
  String get cycleTooLong => 'Eine Periode darf höchstens 60 Tage umfassen.';

  @override
  String get cycleMonthPrev => 'Vorheriger Monat';

  @override
  String get cycleMonthNext => 'Nächster Monat';

  @override
  String get cycleMonthPick => 'Monat wählen';

  @override
  String get cycleLegendPeriod => 'Periode';

  @override
  String get cycleLegendPredicted => 'Voraussichtlich';

  @override
  String get cycleLegendWindow => 'Zeitfenster';

  @override
  String get cycleLegendSymptom => 'Symptome erfasst';

  @override
  String get cycleFlowOnDay => 'Blutungsstärke an diesem Tag';

  @override
  String get cycleFlowRemove => 'Angabe entfernen';

  @override
  String get cycleDaySymptoms => 'Symptome an diesem Tag';

  @override
  String get cycleAddSymptomHere => 'Symptom hinzufügen';

  @override
  String get cycleOpenDayDetail => 'Tagesdetail öffnen';

  @override
  String cycleDayInPeriod(String day) {
    return 'Periode, Tag $day';
  }

  @override
  String get cycleDayNoPeriod => 'Keine Periode an diesem Tag.';

  @override
  String get cycleDayPredicted => 'Voraussichtlicher Periodentag';

  @override
  String get cycleHistoryEmpty => 'Noch keine Perioden erfasst.';

  @override
  String cycleHistoryDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(days, locale: localeName, other: '$days Tage', one: '1 Tag');
    return '$_temp0';
  }

  @override
  String cycleHistoryCycle(String days) {
    return 'Zyklus $days Tage';
  }

  @override
  String get cycleEndMissing => 'Ende fehlt';

  @override
  String get cycleHistoryOngoing => 'läuft';

  @override
  String get cycleStatsTitle => 'Zahlen aus deiner Historie';

  @override
  String cycleStatsAvg(String value) {
    return 'Durchschnittliche Zykluslänge: $value Tage';
  }

  @override
  String cycleStatsPeriod(String value) {
    return 'Durchschnittliche Periodendauer: $value Tage';
  }

  @override
  String cycleStatsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Perioden erfasst',
      one: '1 Periode erfasst',
    );
    return '$_temp0';
  }

  @override
  String get cycleSpottingNote => 'Nur Spotting: zählt nicht als Periodenbeginn für die Einschätzung.';

  @override
  String get cycleDeleteTitle => 'Periode löschen?';

  @override
  String cycleDeleteMessage(String date) {
    return 'Die Periode ab $date wird gelöscht.';
  }

  @override
  String get cycleLegendToday => 'Heute';

  @override
  String get dayDetailTitle => 'Tagesdetail';

  @override
  String get overviewCustomize => 'Bereiche anpassen';

  @override
  String get overviewCustomizeHint =>
      'Ausgeblendete Bereiche bleiben gespeichert und lassen sich jederzeit wieder einblenden.';

  @override
  String get overviewRangeDay => 'Tag';

  @override
  String get overviewOpenDay => 'Tagesdetail';

  @override
  String get overviewNothingVisible =>
      'Alle Bereiche sind ausgeblendet. Wähle unter „Bereiche anpassen“ mindestens einen aus.';

  @override
  String get overviewSettings => 'Einstellungen';

  @override
  String get overviewWeightNone => 'Noch kein Gewicht erfasst';

  @override
  String get overviewSymptomsNone => 'An diesem Tag sind keine Symptome erfasst';

  @override
  String overviewAverageKcal(String value, String days, String total) {
    return 'Durchschnitt $value kcal an $days von $total Tagen';
  }

  @override
  String overviewWaterAverage(String value) {
    return 'Wasser: Durchschnitt $value ml';
  }

  @override
  String overviewCyclePeriods(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Perioden im Zeitraum',
      one: '1 Periode im Zeitraum',
      zero: 'Keine Periode im Zeitraum',
    );
    return '$_temp0';
  }

  @override
  String get overviewTopSymptoms => 'Häufigste Symptome';

  @override
  String overviewSymptomCount(int count, String avg) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count Einträge', one: '1 Eintrag');
    return '$_temp0, Durchschnitt $avg von 10';
  }

  @override
  String overviewWeightRange(String first, String last, String delta) {
    return 'Von $first auf $last ($delta)';
  }

  @override
  String overviewOpenArea(String area) {
    return '$area öffnen';
  }

  @override
  String get overviewNoDataRange => 'Im Zeitraum sind keine Einträge erfasst.';

  @override
  String get settingsTitle => 'Einstellungen';

  @override
  String get settingsLanguage => 'Sprache';

  @override
  String get langGerman => 'Deutsch';

  @override
  String get langEnglish => 'English';

  @override
  String get settingsWeightUnit => 'Gewichtseinheit';

  @override
  String get settingsAreas => 'Bereiche der Übersicht';

  @override
  String get settingsGoals => 'Tagesziele';

  @override
  String get settingsGoalsSubtitle => 'Freiwillig: Wasser, Kalorien, Eiweiß, Kohlenhydrate, Fett';

  @override
  String get goalsHint => 'Alle Ziele sind freiwillig. Leere Felder bedeuten: kein Ziel. Du bestimmst die Werte.';

  @override
  String get goalWater => 'Wasser';

  @override
  String get goalEnergy => 'Kalorien';

  @override
  String get goalSaved => 'Ziele gespeichert';

  @override
  String get settingsCycleSection => 'Zyklus';

  @override
  String get settingsForecast => 'Prognose anzeigen';

  @override
  String get settingsForecastHint => 'Ausgeschaltet arbeitet der Zyklusbereich nur als Tagebuch.';

  @override
  String get settingsExpectedCycle => 'Typische Zykluslänge in Tagen (optional)';

  @override
  String get settingsExpectedCycleHint =>
      'Wird nur verwendet, solange noch kein vollständiger Zyklus erfasst ist. Erlaubt sind 15 bis 60 Tage.';

  @override
  String get settingsOnlineSection => 'Online-Lebensmittelsuche';

  @override
  String get settingsOnlineSwitch => 'Open Food Facts nutzen';

  @override
  String get settingsOnlineHint =>
      'Es wird nur der Suchbegriff beziehungsweise die Barcode-Nummer an den Dienst gesendet. Ohne diese Funktion arbeitet die App vollständig lokal.';

  @override
  String get settingsServer => 'Server der Lebensmittel-API';

  @override
  String get settingsServerHint => 'HTTPS-Ursprung, zum Beispiel https://world.openfoodfacts.org';

  @override
  String get settingsServerInvalid =>
      'Bitte einen HTTPS-Ursprung ohne Pfad angeben, zum Beispiel https://world.openfoodfacts.org.';

  @override
  String get settingsServerReset => 'Standard verwenden';

  @override
  String settingsServerDefault(String url) {
    return 'Standard: $url';
  }

  @override
  String get settingsServerSaved => 'Server gespeichert';

  @override
  String get settingsTheme => 'Darstellung';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Hell';

  @override
  String get themeDark => 'Dunkel';

  @override
  String get settingsPrivacySection => 'Datenschutz';

  @override
  String get settingsSecure => 'Bildschirmaufnahmen sperren';

  @override
  String get settingsSecureHint => 'Sperrt Screenshots und die Vorschau in der App-Übersicht.';

  @override
  String get settingsData => 'Daten und Sicherung';

  @override
  String get settingsDataSubtitle => 'Export, Import, verschlüsselte Sicherung, Löschen';

  @override
  String get settingsAbout => 'Über MorphHealth';

  @override
  String get aboutText =>
      'MorphHealth speichert alle Daten verschlüsselt auf diesem Gerät. Es gibt kein Konto, keine Werbung und keine Telemetrie. Nährwertdaten stammen von Open Food Facts (ODbL).';

  @override
  String get aboutMedical =>
      'MorphHealth dient der persönlichen Dokumentation und Planung. Es ersetzt keine medizinische Beratung und berechnet weder Diagnosen noch Eisprung oder fruchtbare Tage.';

  @override
  String aboutVersion(String version) {
    return 'Version $version';
  }

  @override
  String get aboutLicenses => 'Open-Source-Lizenzen';

  @override
  String get dataTitle => 'Daten und Sicherung';

  @override
  String get dataExportTitle => 'Datenexport (JSON)';

  @override
  String get dataExportHint =>
      'Vollständiger, maschinenlesbarer Export aller Daten. Das Format ist in der README beschrieben. Die Datei ist unverschlüsselt.';

  @override
  String get dataExportButton => 'Exportieren';

  @override
  String get dataExportWarnTitle => 'Unverschlüsselter Export';

  @override
  String get dataExportWarnMessage =>
      'Die Datei enthält alle deine Gesundheitsdaten im Klartext. Speichere sie nur an einem Ort, dem du vertraust.';

  @override
  String dataExportDone(String name) {
    return 'Export gespeichert: $name';
  }

  @override
  String get dataImportTitle => 'Datenimport (JSON)';

  @override
  String get dataImportHint => 'Ersetzt alle vorhandenen Daten durch den Inhalt einer Exportdatei.';

  @override
  String get dataImportButton => 'Datei wählen';

  @override
  String get dataImportPreviewTitle => 'Import prüfen';

  @override
  String dataImportSummary(String count) {
    return 'Die Datei enthält $count Datensätze.';
  }

  @override
  String dataImportWarnings(String count) {
    return '$count Hinweise beim Prüfen';
  }

  @override
  String get dataImportReplaceWarning => 'Alle vorhandenen Daten werden ersetzt.';

  @override
  String get dataImportConfirm => 'Ersetzen';

  @override
  String get dataImportInvalid => 'Die Datei ist ungültig';

  @override
  String get dataImportInvalidJson => 'Die Datei ist kein gültiges JSON.';

  @override
  String dataImportDone(String count) {
    return 'Import abgeschlossen: $count Datensätze';
  }

  @override
  String get dataBackupTitle => 'Verschlüsselte Sicherung';

  @override
  String get dataBackupHint =>
      'Sicherung mit Passphrase (AES-256, Argon2id). Sie lässt sich auf einer frischen Installation wiederherstellen.';

  @override
  String get dataBackupCreate => 'Sicherung erstellen';

  @override
  String get dataPassphrase => 'Passphrase';

  @override
  String get dataPassphraseRepeat => 'Passphrase wiederholen';

  @override
  String get dataPassphraseMismatch => 'Die Passphrasen stimmen nicht überein.';

  @override
  String dataPassphraseShort(String min) {
    return 'Mindestens $min Zeichen.';
  }

  @override
  String get dataBackupWarning =>
      'Ohne die Passphrase lässt sich die Sicherung nicht öffnen. Sie kann nicht zurückgesetzt werden.';

  @override
  String dataBackupDone(String name) {
    return 'Sicherung gespeichert: $name';
  }

  @override
  String get dataRestoreTitle => 'Sicherung wiederherstellen';

  @override
  String get dataRestoreHint => 'Ersetzt alle vorhandenen Daten durch den Inhalt einer Sicherung.';

  @override
  String get dataRestoreButton => 'Sicherung wählen';

  @override
  String get dataRestoreWrong => 'Passphrase falsch oder Datei beschädigt.';

  @override
  String get dataRestoreNotBackup => 'Die Datei ist keine MorphHealth-Sicherung.';

  @override
  String dataRestoreDone(String count) {
    return 'Wiederhergestellt: $count Datensätze';
  }

  @override
  String get dataWorking => 'Bitte einen Moment warten …';

  @override
  String get dataWipeTitle => 'Alle lokalen Daten löschen';

  @override
  String get dataWipeHint =>
      'Löscht alle Einträge, Lebensmittel und Einstellungen auf diesem Gerät und erneuert den Schlüssel.';

  @override
  String get dataWipeButton => 'Alles löschen';

  @override
  String get dataWipeConfirmTitle => 'Wirklich alles löschen?';

  @override
  String get dataWipeConfirmMessage =>
      'Alle Einträge, eigenen Lebensmittel, Favoriten und Einstellungen werden unwiderruflich gelöscht. Exporte und Sicherungen, die du außerhalb der App gespeichert hast, bleiben bestehen.';

  @override
  String get dataWipeDone => 'Alle Daten wurden gelöscht.';

  @override
  String get dataFileTooLarge => 'Die Datei ist zu groß.';

  @override
  String get bootFailedWrongKey =>
      'Der gespeicherte Schlüssel passt nicht zum Datenbestand. Das kommt vor, wenn das Gerät zurückgesetzt oder der Schlüssel gelöscht wurde.';

  @override
  String get bootFailedCorrupt => 'Der Datenbestand ist beschädigt.';

  @override
  String get bootFailedLocked => 'Der Datenbestand wird von einem anderen Prozess verwendet.';

  @override
  String get bootFailedKey => 'Der Gerätehauptschlüssel konnte nicht gelesen werden.';

  @override
  String get bootFailedIo => 'Auf den Speicher konnte nicht zugegriffen werden.';

  @override
  String get bootRestore => 'Aus Sicherung wiederherstellen';

  @override
  String get bootStartFresh => 'Neu beginnen (alle Daten löschen)';

  @override
  String get waterTotalLabel => 'Gesamt';

  @override
  String get unitPortions => 'Portionen';

  @override
  String get errAmountInvalid => 'Die Menge muss größer als 0 sein.';

  @override
  String get errServingNeeded => 'Für Portionen ist eine Portionsgröße nötig.';

  @override
  String get errWeightRange => 'Das Gewicht liegt außerhalb des zulässigen Bereichs (1 bis 700 kg).';

  @override
  String get errSymptomInvalid => 'Ein Symptom braucht einen Namen und eine Intensität von 0 bis 10.';

  @override
  String get errFoodInvalid => 'Ein Lebensmittel braucht einen Namen, und eine Portionsgröße muss größer als 0 sein.';

  @override
  String get errRecordInvalid => 'Diese Angaben lassen sich so nicht speichern (zu lang oder ungültig).';

  @override
  String get errNothingToRemove => 'An diesem Tag ist keine Periode erfasst.';

  @override
  String get errBackupUnsupported =>
      'Diese Sicherung stammt aus einer anderen Version oder verwendet unzulässige Parameter.';

  @override
  String get errBackupCorrupt => 'Der Inhalt der Sicherung ist beschädigt.';

  @override
  String get errPickerBusy => 'Es läuft bereits eine Dateiauswahl.';

  @override
  String get dataRestorePreviewTitle => 'Sicherung prüfen';
}
