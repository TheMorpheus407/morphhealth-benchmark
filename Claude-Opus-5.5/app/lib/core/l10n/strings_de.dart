import '../cycle/forecast.dart';
import '../model/enums.dart';
import 'format.dart';
import 'strings.dart';

class SDe extends S {
  const SDe();

  @override
  AppLanguage get language => AppLanguage.de;

  // ---- Allgemein ---------------------------------------------------------
  @override
  String get ok => 'OK';
  @override
  String get cancel => 'Abbrechen';
  @override
  String get save => 'Speichern';
  @override
  String get delete => 'Löschen';
  @override
  String get edit => 'Bearbeiten';
  @override
  String get add => 'Hinzufügen';
  @override
  String get close => 'Schließen';
  @override
  String get done => 'Fertig';
  @override
  String get retry => 'Erneut versuchen';
  @override
  String get undo => 'Rückgängig';
  @override
  String get next => 'Weiter';
  @override
  String get back => 'Zurück';
  @override
  String get search => 'Suchen';
  @override
  String get clear => 'Leeren';
  @override
  String get today => 'Heute';
  @override
  String get yesterday => 'Gestern';
  @override
  String get tomorrow => 'Morgen';
  @override
  String get date => 'Datum';
  @override
  String get time => 'Uhrzeit';
  @override
  String get note => 'Notiz';
  @override
  String get noteOptional => 'Notiz (optional)';
  @override
  String get optional => 'optional';
  @override
  String get none => 'Keine';
  @override
  String get more => 'Mehr';
  @override
  String get saved => 'Gespeichert';
  @override
  String get deleted => 'Gelöscht';
  @override
  String get entryDeleted => 'Eintrag gelöscht';
  @override
  String get fieldRequired => 'Bitte ausfüllen';
  @override
  String get invalidNumber => 'Bitte eine Zahl eingeben';
  @override
  String numberRange(String min, String max) =>
      'Bitte einen Wert zwischen $min und $max eingeben';
  @override
  String get previousDay => 'Vorheriger Tag';
  @override
  String get nextDay => 'Nächster Tag';
  @override
  String get previousMonth => 'Vorheriger Monat';
  @override
  String get nextMonth => 'Nächster Monat';
  @override
  String get chooseDate => 'Datum wählen';
  @override
  String get chooseTime => 'Uhrzeit wählen';
  @override
  String get loading => 'Wird geladen …';
  @override
  String get errorGeneric =>
      'Etwas ist schiefgelaufen. Bitte versuche es noch einmal.';
  @override
  String get favorite => 'Favorit';
  @override
  String get addFavorite => 'Zu Favoriten hinzufügen';
  @override
  String get removeFavorite => 'Aus Favoriten entfernen';
  @override
  String get deleteConfirmTitle => 'Löschen?';
  @override
  String get cannotUndo => 'Das kann nicht rückgängig gemacht werden.';

  // ---- Navigation / Bereiche ---------------------------------------------
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
  String get historyTitle => 'Historie';
  @override
  String get settingsTitle => 'Einstellungen';
  @override
  String get dayDetailTitle => 'Tagesdetail';
  @override
  String areaName(Area area) => switch (area) {
    Area.nutrition => 'Ernährung',
    Area.cycle => 'Zyklus',
    Area.weight => 'Gewicht',
    Area.symptoms => 'Symptome',
  };
  @override
  String mealName(Meal meal) => switch (meal) {
    Meal.breakfast => 'Frühstück',
    Meal.lunch => 'Mittagessen',
    Meal.dinner => 'Abendessen',
    Meal.snack => 'Snack',
  };
  @override
  String flowName(Flow flow) => switch (flow) {
    Flow.spotting => 'Schmierblutung',
    Flow.light => 'Leicht',
    Flow.medium => 'Mittel',
    Flow.heavy => 'Stark',
  };
  @override
  String unitName(AmountUnit unit, {bool plural = false}) => switch (unit) {
    AmountUnit.g => 'g',
    AmountUnit.ml => 'ml',
    AmountUnit.portion => plural ? 'Portionen' : 'Portion',
  };
  @override
  String nutrientName(String key) => switch (key) {
    'energy_kcal' => 'Kalorien',
    'protein_g' => 'Eiweiß (Protein)',
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
    'vitamin_b9_ug' => 'Vitamin B9 (Folat)',
    'vitamin_b12_ug' => 'Vitamin B12',
    'calcium_mg' => 'Kalzium',
    'iron_mg' => 'Eisen',
    'magnesium_mg' => 'Magnesium',
    'potassium_mg' => 'Kalium',
    'zinc_mg' => 'Zink',
    'selenium_ug' => 'Selen',
    'iodine_ug' => 'Jod',
    'phosphorus_mg' => 'Phosphor',
    'water_ml' => 'Wasser',
    'caffeine_total_mg' => 'Koffein (gesamt)',
    _ => key,
  };
  @override
  String get groupEnergyMacros => 'Energie & Makronährstoffe';
  @override
  String get groupDetails => 'Weitere Angaben';
  @override
  String get groupVitamins => 'Vitamine';
  @override
  String get groupMinerals => 'Mineralstoffe';

  // ---- Einführung --------------------------------------------------------
  @override
  String get welcomeTitle => 'Willkommen bei MorphHealth';
  @override
  String get welcomeText =>
      'Dein persönliches Tagebuch für Ernährung, Zyklus, Gewicht und '
      'Symptome. Alles bleibt auf diesem Gerät – ohne Konto, ohne Werbung, '
      'ohne Tracking.';
  @override
  String get onboardingLanguage => 'Sprache';
  @override
  String get onboardingAreas => 'Was möchtest du in der Übersicht sehen?';
  @override
  String get onboardingAreasHint =>
      'Das kannst du jederzeit ändern. Ausgeblendete Bereiche behalten ihre Daten.';
  @override
  String get onboardingOnline => 'Online-Lebensmittelsuche';
  @override
  String get onboardingOnlineHint =>
      'Suchbegriffe und Barcodes werden an die Datenbank Open Food Facts '
      'gesendet. Deine Gesundheitsdaten verlassen das Gerät nie.';
  @override
  String get onboardingPrivacy =>
      'Deine Daten werden verschlüsselt auf diesem Gerät gespeichert. Du '
      'kannst sie jederzeit in den Einstellungen exportieren, sichern oder '
      'löschen.';
  @override
  String get getStarted => 'Los geht’s';

  // ---- Übersicht ---------------------------------------------------------
  @override
  String get customizeOverview => 'Übersicht anpassen';
  @override
  String get customizeOverviewHint =>
      'Wähle, welche Bereiche die Übersicht zeigt. Ausgeblendete Bereiche '
      'behalten ihre Daten.';
  @override
  String get noAreasVisible =>
      'Alle Bereiche sind ausgeblendet. Über „Übersicht anpassen“ kannst du '
      'sie wieder einblenden.';
  @override
  String get openDayDetail => 'Tagesdetail';
  @override
  String get nutritionToday => 'Ernährung';
  @override
  String kcalOfGoal(String value, String goal) => '$value von $goal kcal';
  @override
  String get noFoodLogged => 'Noch nichts erfasst';
  @override
  String get latestWeight => 'Letzter Eintrag';
  @override
  String get noWeightYet => 'Noch kein Gewicht erfasst';
  @override
  String get noSymptomsOnDay => 'Für diesen Tag sind keine Symptome erfasst';
  @override
  String symptomsCount(int n) => n == 1 ? '1 Symptom' : '$n Symptome';

  // ---- Ernährungstagebuch ------------------------------------------------
  @override
  String get addFood => 'Lebensmittel hinzufügen';
  @override
  String addFoodTo(Meal meal) => 'Lebensmittel zu „${mealName(meal)}“ hinzufügen';
  @override
  String get dayTotal => 'Tagessumme';
  @override
  String get goal => 'Ziel';
  @override
  String valueOfGoal(String value, String goal) => '$value von $goal';
  @override
  String get water => 'Wasser';
  @override
  String get waterAddCustom => 'Andere Menge';
  @override
  String get waterAmountMl => 'Wasser (ml)';
  @override
  String waterAdded(String amount) => '$amount Wasser hinzugefügt';
  @override
  String get caffeine => 'Koffein';
  @override
  String get caffeineAdditional => 'Zusätzliches Koffein';
  @override
  String get caffeineFromFoods => 'aus erfassten Lebensmitteln';
  @override
  String get caffeineTotal => 'Gesamt';
  @override
  String get caffeineAddCustom => 'Andere Menge';
  @override
  String get caffeineAmountMg => 'Koffein (mg)';
  @override
  String get caffeineLabelOptional => 'Bezeichnung (optional, z. B. Espresso)';
  @override
  String caffeineAdded(String amount) => '$amount Koffein hinzugefügt';
  @override
  String get allNutrients => 'Alle Nährwerte';
  @override
  String coverage(int known, int total) =>
      'Werte aus $known von $total Einträgen';
  @override
  String get includesEstimates => 'enthält Schätzwerte';
  @override
  String get estimated => 'geschätzt';
  @override
  String get nothingLoggedMeal => 'Nichts erfasst';
  @override
  String get logAgain => 'Erneut erfassen';
  @override
  String loggedAgain(String date) => 'Für $date erneut erfasst';
  @override
  String get logAgainTitle => 'Eintrag erneut erfassen';
  @override
  String get editEntry => 'Eintrag bearbeiten';
  @override
  String get entryNutrients => 'Nährwerte dieses Eintrags';
  @override
  String get dayTab => 'Tag';
  @override
  String get trendTab => 'Verlauf';
  @override
  String get trendMetric => 'Nährwert';
  @override
  String days(int n) => '$n Tage';
  @override
  String get average => 'Durchschnitt';
  @override
  String get averageHint => 'Durchschnitt der Tage mit Einträgen';
  @override
  String daysWithData(int n, int total) => '$n von $total Tagen erfasst';
  @override
  String get minimum => 'Niedrigster Wert';
  @override
  String get maximum => 'Höchster Wert';
  @override
  String get noDataInRange => 'Keine Einträge in diesem Zeitraum.';
  @override
  String get showTable => 'Als Tabelle zeigen';
  @override
  String get showChart => 'Als Diagramm zeigen';
  @override
  String get waterMetric => 'Wasser';
  @override
  String get caffeineTotalMetric => 'Koffein (gesamt)';

  // ---- Lebensmittelsuche & eigene Lebensmittel ---------------------------
  @override
  String get foodSearchHint => 'Name oder Barcode-Nummer';
  @override
  String get tabSearch => 'Suche';
  @override
  String get tabFavorites => 'Favoriten';
  @override
  String get tabRecent => 'Zuletzt';
  @override
  String get tabMyFoods => 'Eigene';
  @override
  String get searchOnline => 'In Open Food Facts suchen';
  @override
  String get loadMore => 'Weitere laden';
  @override
  String get noResults => 'Keine Treffer.';
  @override
  String get noFavorites =>
      'Noch keine Favoriten. Tippe bei einem Lebensmittel auf den Stern.';
  @override
  String get noRecent => 'Erfasste Lebensmittel erscheinen hier.';
  @override
  String get noCustomFoods => 'Du hast noch keine eigenen Lebensmittel angelegt.';
  @override
  String get localResults => 'Auf diesem Gerät';
  @override
  String get onlineResults => 'Open Food Facts';
  @override
  String get onlineDisabled =>
      'Die Online-Suche ist ausgeschaltet. Du kannst sie in den '
      'Einstellungen einschalten.';
  @override
  String get searching => 'Suche läuft …';
  @override
  String get barcodeNotFound => 'Zu diesem Barcode wurde kein Produkt gefunden.';
  @override
  String get barcodeCheckDigitWarning =>
      'Die Prüfziffer passt nicht – bitte die Nummer kontrollieren.';
  @override
  String lookupBarcode(String code) => 'Barcode $code nachschlagen';
  @override
  String get createCustomFood => 'Eigenes Lebensmittel anlegen';
  @override
  String get offAttribution =>
      'Produktdaten: Open Food Facts, verfügbar unter der Open Database '
      'License (ODbL).';
  @override
  String perHundred(Basis basis) => 'pro 100 ${basis.json}';
  @override
  String get perPortion => 'pro Portion';
  @override
  String get noNutritionData => 'Keine Nährwertangaben';
  @override
  String get foodDetails => 'Lebensmittel';
  @override
  String get customFood => 'Eigenes Lebensmittel';
  @override
  String get onlineFood => 'Open Food Facts';
  @override
  String resultCount(int n) => n == 1 ? '1 Treffer' : '$n Treffer';
  @override
  String foodApiError(String code) => switch (code) {
    'network_error' =>
      'Keine Verbindung zur Lebensmitteldatenbank. Bitte prüfe deine '
          'Internetverbindung.',
    'network_timeout' => 'Die Lebensmitteldatenbank hat nicht rechtzeitig geantwortet.',
    'tls_error' => 'Die sichere Verbindung zur Lebensmitteldatenbank ist fehlgeschlagen.',
    'rate_limited' => 'Zu viele Anfragen. Bitte warte einen Moment.',
    'online_disabled' => onlineDisabled,
    _ => 'Die Lebensmitteldatenbank ist nicht erreichbar ($code).',
  };
  @override
  String get amount => 'Menge';
  @override
  String get unit => 'Einheit';
  @override
  String get meal => 'Mahlzeit';
  @override
  String get addToDiary => 'Zum Tagebuch hinzufügen';
  @override
  String get nutrientsForAmount => 'Nährwerte für diese Menge';
  @override
  String get assumedDensity =>
      'Umrechnung zwischen g und ml mit der Annahme 1 g = 1 ml.';
  @override
  String portionDescription(String? label, String size, Basis basis) =>
      label == null
      ? '1 Portion = $size ${basis.json}'
      : '1 Portion ($label) = $size ${basis.json}';
  @override
  String addedToDiary(String name) => '$name hinzugefügt';

  // ---- Eigenes Lebensmittel ----------------------------------------------
  @override
  String get newCustomFood => 'Neues Lebensmittel';
  @override
  String get editCustomFood => 'Lebensmittel bearbeiten';
  @override
  String get foodName => 'Name';
  @override
  String get brandOptional => 'Marke (optional)';
  @override
  String get barcodeOptional => 'Barcode (optional)';
  @override
  String get barcodeDigitsOnly => 'Bitte nur Ziffern';
  @override
  String get basisLabel => 'Nährwerte beziehen sich auf';
  @override
  String get servingSizeOptional => 'Portionsgröße (optional)';
  @override
  String get servingLabelOptional =>
      'Portionsbezeichnung (optional, z. B. 1 Scheibe)';
  @override
  String get densityOptional => 'Dichte in g/ml (optional)';
  @override
  String nutrientsPerHundred(Basis basis) => 'Nährwerte pro 100 ${basis.json}';
  @override
  String get saltSodiumHint =>
      'Wenn du nur Salz oder nur Natrium einträgst, wird der andere Wert '
      'berechnet (Salz = Natrium × 2,5).';
  @override
  String updateEntriesQuestion(int n) => n == 1
      ? '1 Tagebucheintrag verwendet dieses Lebensmittel. Soll er ebenfalls '
            'die neuen Werte erhalten?'
      : '$n Tagebucheinträge verwenden dieses Lebensmittel. Sollen sie '
            'ebenfalls die neuen Werte erhalten?';
  @override
  String get updateEntriesYes => 'Einträge aktualisieren';
  @override
  String get updateEntriesNo => 'Nur Lebensmittel';
  @override
  String get deleteFoodQuestion =>
      'Dieses Lebensmittel löschen? Tagebucheinträge damit bleiben erhalten.';
  @override
  String get foodDeleted => 'Lebensmittel gelöscht';
  @override
  String valueTooLarge(String max) => 'Höchstens $max';
  @override
  String get portionNeedsServing => 'Bitte zuerst eine Portionsgröße angeben.';

  // ---- Zyklus ------------------------------------------------------------
  @override
  String get periodStartToday => 'Periode hat heute begonnen';
  @override
  String get periodEndToday => 'Periode heute beendet';
  @override
  String get addPastPeriod => 'Periode nachtragen';
  @override
  String get editPeriod => 'Periode bearbeiten';
  @override
  String get newPeriod => 'Neue Periode';
  @override
  String get periodStart => 'Erster Tag';
  @override
  String get periodEnd => 'Letzter Tag';
  @override
  String get periodOngoing => 'Dauert noch an';
  @override
  String get periodStillOngoing => 'läuft';
  @override
  String get deletePeriodQuestion =>
      'Diese Periode löschen? Die Blutungseinträge dieser Tage werden ebenfalls '
      'gelöscht.';
  @override
  String get periodOverlap => 'Diese Periode überschneidet sich mit einer anderen.';
  @override
  String get periodEndBeforeStart =>
      'Der letzte Tag darf nicht vor dem ersten Tag liegen.';
  @override
  String periodTooLong(int max) => 'Eine Periode kann höchstens $max Tage dauern.';
  @override
  String get periodStartInFuture => 'Der erste Tag darf nicht in der Zukunft liegen.';
  @override
  String get onlyLatestOngoing =>
      'Nur die jüngste Periode kann noch andauern. Bitte einen letzten Tag angeben.';
  @override
  String get flow => 'Blutung';
  @override
  String get noFlow => 'Keine';
  @override
  String get legendPeriod => 'Periode';
  @override
  String get legendPredicted => 'Erwartete Periode';
  @override
  String get legendWindow => 'Wahrscheinlicher Beginn';
  @override
  String get legendSpotting => 'Schmierblutung';
  @override
  String get legendSymptoms => 'Symptome';
  @override
  String get legendToday => 'Heute';
  @override
  String get calendar => 'Kalender';
  @override
  String get periodHistory => 'Perioden';
  @override
  String get noPeriodsYet => 'Noch keine Perioden erfasst.';
  @override
  String cycleLengthDays(int n) => 'Zyklus $n Tage';
  @override
  String periodLengthDays(int n) => n == 1 ? '1 Tag' : '$n Tage';
  @override
  String get averageCycle => 'Typischer Zyklus';
  @override
  String get averagePeriod => 'Typische Periode';
  @override
  String get cycleLengthsChart => 'Zykluslängen';
  @override
  String get startPeriodHere => 'Periode begann an diesem Tag';
  @override
  String get endPeriodHere => 'Periode endete an diesem Tag';
  @override
  String get symptomsOfDay => 'Symptome';
  @override
  String get cycleDayNote => 'Notiz zu diesem Tag';
  @override
  String dayInPeriod(int day) => 'Periodentag $day';
  @override
  String periodStarted(String date) => 'Periodenbeginn am $date erfasst';
  @override
  String periodEnded(String date) => 'Periodenende am $date erfasst';
  @override
  String get whyThisEstimate => 'Wie entsteht diese Einschätzung?';
  @override
  String get explanationTitle => 'Deine persönliche Einschätzung';
  @override
  String get disclaimer =>
      'Diese Einschätzung dient nur deiner persönlichen Planung. Sie ist '
      'keine Diagnose, berechnet keinen Eisprung und ist nicht zur Verhütung '
      'geeignet.';
  @override
  String confidenceName(ForecastConfidence c) => switch (c) {
    ForecastConfidence.low => 'grob',
    ForecastConfidence.medium => 'mittel',
    ForecastConfidence.high => 'gut',
  };
  @override
  String get predictionsOff => 'Tagebuchmodus: Einschätzungen sind ausgeschaltet.';
  @override
  String longOngoingPeriodHint(int days) =>
      'Diese Periode ist seit $days Tagen offen. Falls sie schon vorbei ist, '
      'trage bitte den letzten Tag ein.';
  @override
  String get enterLastDay => 'Letzten Tag eintragen';
  @override
  String get flowOutsidePeriodQuestion =>
      'Dieser Tag gehört zu keiner erfassten Periode. Wie möchtest du die '
      'Blutung speichern?';
  @override
  String get startPeriodOnDay => 'Periode an diesem Tag beginnen';
  @override
  String extendPeriodToDay(String date) => 'Periode bis $date verlängern';
  @override
  String get onlySaveBleeding => 'Nur die Blutung speichern';
  @override
  String get saveNote => 'Notiz speichern';
  @override
  String get cycleStats => 'Auswertung';
  @override
  String cyclesRecorded(int n) => n == 1 ? '1 erfasster Zyklus' : '$n erfasste Zyklen';

  @override
  String cycleHeadline(CycleForecast f, Fmt fmt) {
    if (f.currentPeriodDay != null) {
      return 'Periode · Tag ${f.currentPeriodDay}';
    }
    switch (f.status) {
      case CycleStatus.noData:
        return 'Noch keine Periode erfasst';
      case CycleStatus.beforeWindow:
        final d = f.daysUntilExpected!;
        return d == 1
            ? 'Nächste Periode in etwa 1 Tag'
            : 'Nächste Periode in etwa $d Tagen';
      case CycleStatus.inWindow:
        return 'Nächste Periode kann jetzt beginnen';
      case CycleStatus.afterWindow:
        final d = f.daysAfterWindow!;
        return d == 1
            ? '1 Tag nach dem erwarteten Zeitraum'
            : '$d Tage nach dem erwarteten Zeitraum';
      case CycleStatus.insufficientData:
      case CycleStatus.diaryOnly:
      case CycleStatus.inPeriod:
        return f.cycleDay == null
            ? 'Noch keine Periode erfasst'
            : 'Zyklustag ${f.cycleDay}';
    }
  }

  @override
  String? cycleSubline(CycleForecast f, Fmt fmt) {
    String window() =>
        '${fmt.dayMonth(f.windowStart!)} – ${fmt.dayMonth(f.windowEnd!)}';
    switch (f.status) {
      case CycleStatus.noData:
        return 'Erfasse den Beginn einer Periode, um deinen Zyklus hier zu sehen.';
      case CycleStatus.diaryOnly:
        return predictionsOff;
      case CycleStatus.insufficientData:
        return 'Eine persönliche Einschätzung ist möglich, sobald ein zweiter '
            'Periodenbeginn erfasst ist.';
      case CycleStatus.inPeriod:
        final parts = <String>[];
        if (f.expectedCurrentEnd != null) {
          parts.add('meist bis etwa ${fmt.dayMonth(f.expectedCurrentEnd!)}');
        }
        if (f.expectedStart != null) {
          parts.add('nächster Beginn um den ${fmt.dayMonth(f.expectedStart!)}');
        }
        if (parts.isEmpty) return null;
        final s = parts.join(' · ');
        return s[0].toUpperCase() + s.substring(1);
      case CycleStatus.beforeWindow:
        return 'Um den ${fmt.dayMonth(f.expectedStart!)} · wahrscheinlich '
            '${window()} · Zyklustag ${f.cycleDay}';
      case CycleStatus.inWindow:
        return 'Wahrscheinlich ${window()} · Zyklustag ${f.cycleDay}';
      case CycleStatus.afterWindow:
        return 'Erwartet um den ${fmt.dayMonth(f.expectedStart!)} '
            '(${window()}) · Zyklustag ${f.cycleDay}';
    }
  }

  @override
  List<String> cycleExplanation(CycleForecast f, Fmt fmt) {
    final out = <String>[];
    if (!f.predictionsEnabled) {
      out.add(
        'Einschätzungen sind ausgeschaltet (Tagebuchmodus). Deine Einträge '
        'werden weiterhin gespeichert und angezeigt. In den Einstellungen '
        'kannst du Einschätzungen wieder einschalten.',
      );
      return out;
    }
    out.add(
      'MorphHealth verwendet nur deine eigenen Einträge bis zum '
      '${fmt.medium(f.on)}. Betrachtet wird die Anzahl der Tage zwischen den '
      'ersten Tagen deiner erfassten Perioden (die Zykluslänge).',
    );
    if (f.status == CycleStatus.noData) {
      out.add('Bis zu diesem Tag ist noch keine Periode erfasst.');
      out.add(disclaimer);
      return out;
    }
    if (f.cycles.isEmpty) {
      out.add(
        f.periodsConsidered == 1
            ? 'Bisher ist eine Periode erfasst (ab ${fmt.medium(f.lastPeriodStart!)}). '
                  'Sobald der nächste Periodenbeginn erfasst ist, ist die erste '
                  'Zykluslänge bekannt und eine persönliche Einschätzung möglich.'
            : 'Es sind ${f.periodsConsidered} Perioden erfasst, aber noch keine '
                  'verwertbare Zykluslänge.',
      );
      _excluded(f, fmt, out);
      out.add(disclaimer);
      return out;
    }
    final lengths = f.cycles.map((c) => c.length).join(', ');
    final n = f.cycles.length;
    out.add(
      n == 1
          ? 'Grundlage: dein letzter Zyklus (ab ${fmt.medium(f.cycles.first.start)}) '
                'mit $lengths Tagen.'
          : 'Grundlage: deine letzten $n Zyklen (Beginn '
                '${fmt.medium(f.cycles.first.start)} bis '
                '${fmt.medium(f.cycles.last.start)}) mit $lengths Tagen.',
    );
    if (n > 1) {
      out.add(
        'Der Median liegt bei ${f.medianCycleLength} Tagen (Mittelwert '
        '${fmt.number(f.meanCycleLength!, 1)}). Deine Zyklen schwanken mit '
        'einer Standardabweichung von ${fmt.number(f.sdCycleLength!, 1)} Tagen, '
        'daher umfasst der Zeitraum ± ${f.windowHalfWidth} '
        '${f.windowHalfWidth == 1 ? 'Tag' : 'Tage'}.',
      );
    } else {
      out.add(
        'Bei nur einem Zyklus ist die Schwankung unbekannt, daher umfasst der '
        'Zeitraum ± ${f.windowHalfWidth} Tage.',
      );
    }
    out.add(
      'Deine letzte Periode begann am ${fmt.medium(f.lastPeriodStart!)}. Plus '
      '${f.medianCycleLength} Tage ergibt den ${fmt.medium(f.expectedStart!)} '
      'als erwarteten Beginn; wahrscheinlich liegt er zwischen dem '
      '${fmt.medium(f.windowStart!)} und dem ${fmt.medium(f.windowEnd!)}.',
    );
    if (f.medianPeriodLength != null) {
      final k = f.periodLengths.length;
      final days = '${f.medianPeriodLength} ${f.medianPeriodLength == 1 ? 'Tag' : 'Tage'}';
      out.add(
        k == 1
            ? 'Deine letzte abgeschlossene Periode dauerte $days.'
            : 'Deine letzten $k abgeschlossenen Perioden dauerten im Median $days.',
      );
    }
    _excluded(f, fmt, out);
    out.add(
      'Verlässlichkeit: ${confidenceName(f.confidence!)} – ${switch (f.confidence!) {
        ForecastConfidence.high => 'mehrere Zyklen mit geringer Schwankung.',
        ForecastConfidence.medium => 'deine Zyklen schwanken etwas.',
        ForecastConfidence.low => n == 1 ? 'nur ein Zyklus als Grundlage.' : 'deine Zyklen schwanken stark oder es sind nur wenige.',
      }}',
    );
    out.add(disclaimer);
    return out;
  }

  void _excluded(CycleForecast f, Fmt fmt, List<String> out) {
    for (final e in f.excluded) {
      final why = e.reason == ExclusionReason.tooLong
          ? 'ungewöhnlich lang ist – vielleicht fehlt ein Periodeneintrag'
          : 'ungewöhnlich kurz ist – vielleicht wurde eine Schmierblutung oder '
                'eine Periode doppelt erfasst';
      out.add(
        'Nicht berücksichtigt: ein Zyklus mit ${e.sample.length} Tagen (ab '
        '${fmt.medium(e.sample.start)}), weil er $why.',
      );
    }
  }

  @override
  String calendarDayLabel({
    required String date,
    required bool isToday,
    required bool inPeriod,
    Flow? flow,
    required bool predicted,
    required bool inWindow,
    required int symptoms,
    required bool hasNote,
  }) {
    final parts = <String>[date];
    if (isToday) parts.add('heute');
    if (inPeriod) parts.add('Periode');
    if (flow != null) parts.add(flowName(flow));
    if (predicted) parts.add('erwartete Periode');
    if (inWindow) parts.add('wahrscheinlicher Beginn der nächsten Periode');
    if (symptoms > 0) parts.add(symptomsCount(symptoms));
    if (hasNote) parts.add('Notiz');
    return parts.join(', ');
  }

  // ---- Gewicht -----------------------------------------------------------
  @override
  String get addWeight => 'Gewicht erfassen';
  @override
  String get editWeight => 'Gewicht bearbeiten';
  @override
  String get weight => 'Gewicht';
  @override
  String get weightUnit => 'Gewichtseinheit';
  @override
  String get deleteWeightQuestion => 'Diesen Gewichtseintrag löschen?';
  @override
  String changeSince(String change, String date) => '$change seit $date';
  @override
  String get range7 => '7 Tage';
  @override
  String get range28 => '28 Tage';
  @override
  String get range90 => '90 Tage';
  @override
  String get range365 => '1 Jahr';
  @override
  String get rangeAll => 'Alle';
  @override
  String get weightEntries => 'Einträge';
  @override
  String weightOutOfRange(String min, String max) =>
      'Bitte ein Gewicht zwischen $min und $max eingeben';

  // ---- Symptome ----------------------------------------------------------
  @override
  String get addSymptom => 'Symptom erfassen';
  @override
  String get editSymptom => 'Symptom bearbeiten';
  @override
  String get symptomName => 'Symptom';
  @override
  String get intensity => 'Intensität';
  @override
  String intensityValue(int i) => '$i von 10';
  @override
  String intensityWord(int i) {
    if (i == 0) return 'keine';
    if (i <= 3) return 'leicht';
    if (i <= 6) return 'mittel';
    if (i <= 9) return 'stark';
    return 'sehr stark';
  }

  @override
  String get deleteSymptomQuestion => 'Diesen Symptomeintrag löschen?';
  @override
  String get noSymptomsYet => 'Noch keine Symptome erfasst.';
  @override
  String get symptomEntriesTab => 'Einträge';
  @override
  String get symptomTrendTab => 'Verlauf';
  @override
  String get chooseSymptom => 'Symptom';
  @override
  String occurrences(int n) => n == 1 ? '1 Eintrag' : '$n Einträge';
  @override
  String get averageIntensity => 'Mittlere Intensität';
  @override
  String get maxIntensity => 'Höchste Intensität';
  @override
  List<String> get symptomSuggestions => const [
    'Kopfschmerzen',
    'Unterleibskrämpfe',
    'Blähungen',
    'Müdigkeit',
    'Übelkeit',
    'Rückenschmerzen',
    'Stimmungsschwankungen',
    'Brustspannen',
    'Hautunreinheiten',
    'Heißhunger',
    'Schlafprobleme',
    'Gelenkschmerzen',
  ];

  // ---- Historie ----------------------------------------------------------
  @override
  String get historySearchHint => 'Einträge durchsuchen';
  @override
  String get allAreas => 'Alle Bereiche';
  @override
  String get dateRange => 'Zeitraum';
  @override
  String get anyDate => 'Gesamter Zeitraum';
  @override
  String historyResults(int n) => n == 1 ? '1 Eintrag' : '$n Einträge';
  @override
  String get noHistoryResults => 'Keine passenden Einträge.';
  @override
  String get kindFood => 'Lebensmittel';
  @override
  String get kindWater => 'Wasser';
  @override
  String get kindCaffeine => 'Koffein';
  @override
  String get kindPeriod => 'Periode';
  @override
  String get kindCycleDay => 'Zyklustag';
  @override
  String get kindWeight => 'Gewicht';
  @override
  String get kindSymptom => 'Symptom';

  // ---- Tagesdetail -------------------------------------------------------
  @override
  String get nothingLoggedOnDay => 'Für diesen Tag ist noch nichts erfasst.';
  @override
  String get cycleOnDay => 'Zyklus';
  @override
  String get notInPeriod => 'An diesem Tag ist keine Periode erfasst';

  // ---- Einstellungen -----------------------------------------------------
  @override
  String get languageLabel => 'Sprache';
  @override
  String get languageName => 'Deutsch';
  @override
  String get units => 'Einheiten';
  @override
  String get dailyGoals => 'Tagesziele';
  @override
  String get goalsHint =>
      'Ziele sind freiwillig und ganz dir überlassen. Leeres Feld = kein Ziel.';
  @override
  String get goalEnergy => 'Kalorien (kcal)';
  @override
  String get goalProtein => 'Eiweiß (g)';
  @override
  String get goalCarbs => 'Kohlenhydrate (g)';
  @override
  String get goalFat => 'Fett (g)';
  @override
  String get goalWater => 'Wasser (ml)';
  @override
  String get overviewAreas => 'Bereiche in der Übersicht';
  @override
  String get quickAmounts => 'Schnellerfassung';
  @override
  String get waterQuickAmounts => 'Wasser-Schaltflächen (ml)';
  @override
  String get caffeineQuickAmounts => 'Koffein-Schaltflächen (mg)';
  @override
  String get quickAmountsHint => 'Bis zu 6 Werte, getrennt durch Komma oder Leerzeichen';
  @override
  String get cycleSettings => 'Zyklus';
  @override
  String get predictionsSwitch => 'Persönliche Einschätzungen zeigen';
  @override
  String get predictionsHint =>
      'Ausgeschaltet arbeitet der Periodentracker als reines Tagebuch.';
  @override
  String get onlineSection => 'Online-Lebensmittelsuche';
  @override
  String get onlineSwitch => 'Online-Lebensmittelsuche erlauben';
  @override
  String get onlineHint =>
      'An die Lebensmitteldatenbank gehen nur Suchbegriffe und Barcodes. '
      'Dein Tagebuch verlässt das Gerät nie.';
  @override
  String get serverOrigin => 'Server der Lebensmitteldatenbank';
  @override
  String get serverOriginHint =>
      'HTTPS-Adresse eines Open-Food-Facts-kompatiblen Servers';
  @override
  String get serverOriginInvalid =>
      'Bitte eine Adresse eingeben, die mit https:// beginnt';
  @override
  String get resetToDefault => 'Standard wiederherstellen';
  @override
  String get dataSection => 'Daten & Sicherung';
  @override
  String get exportData => 'Daten exportieren (JSON)';
  @override
  String get exportDataHint => 'Vollständig, maschinenlesbar, unverschlüsselt';
  @override
  String get exportWarningTitle => 'Unverschlüsselter Export';
  @override
  String get exportWarning =>
      'Die Exportdatei enthält alle deine Gesundheitsdaten in lesbarer Form. '
      'Bewahre sie sorgfältig auf und gib sie nur an Menschen weiter, denen '
      'du vertraust.';
  @override
  String get exportAck => 'Verstanden';
  @override
  String get exportDone => 'Export gespeichert';
  @override
  String get importData => 'Daten importieren (JSON)';
  @override
  String get importDataHint => 'Ersetzt alle Daten auf diesem Gerät';
  @override
  String get importConfirm =>
      'Der Import ersetzt ALLE Daten auf diesem Gerät durch den Inhalt der Datei.';
  @override
  String importDone(int entries) =>
      'Import abgeschlossen: $entries Tagebucheinträge.';
  @override
  String importFailed(String reason) => 'Import fehlgeschlagen: $reason';
  @override
  String get createBackup => 'Verschlüsselte Sicherung erstellen';
  @override
  String get createBackupHint => 'Mit Passphrase geschützt, für ein neues Gerät';
  @override
  String get passphrase => 'Passphrase';
  @override
  String get passphraseRepeat => 'Passphrase wiederholen';
  @override
  String get passphraseHint =>
      'Mindestens 10 Zeichen. Ohne die Passphrase lässt sich die Sicherung '
      'nicht wiederherstellen – niemand kann sie zurückholen.';
  @override
  String get passphraseTooShort => 'Bitte mindestens 10 Zeichen';
  @override
  String get passphraseMismatch => 'Die Passphrasen stimmen nicht überein';
  @override
  String get backupWorking => 'Wird verschlüsselt …';
  @override
  String get backupDone => 'Sicherung gespeichert';
  @override
  String get restoreBackup => 'Sicherung wiederherstellen';
  @override
  String get restoreBackupHint => 'Ersetzt alle Daten auf diesem Gerät';
  @override
  String get restoreConfirm =>
      'Die Wiederherstellung ersetzt ALLE Daten auf diesem Gerät durch die '
      'Sicherung.';
  @override
  String get restoreWrongPassphrase =>
      'Falsche Passphrase oder die Datei ist beschädigt.';
  @override
  String get restoreInvalidFile => 'Das ist keine MorphHealth-Sicherungsdatei.';
  @override
  String restoreDone(int entries) =>
      'Sicherung wiederhergestellt: $entries Tagebucheinträge.';
  @override
  String get deleteAllData => 'Alle Daten löschen';
  @override
  String get deleteAllDataHint =>
      'Entfernt alle Einträge und Einstellungen von diesem Gerät';
  @override
  String get deleteAllConfirm =>
      'Alle Tagebucheinträge, Lebensmittel und Einstellungen werden von '
      'diesem Gerät gelöscht und der Schlüssel wird vernichtet.';
  @override
  String get deleteAllTypeWord => 'Zur Bestätigung LÖSCHEN eintippen:';
  @override
  String get deleteAllWord => 'LÖSCHEN';
  @override
  String get deleteAllDone => 'Alle Daten gelöscht';
  @override
  String get about => 'Über MorphHealth';
  @override
  String get version => 'Version';
  @override
  String get privacyTitle => 'Datenschutz';
  @override
  String get privacyText =>
      'MorphHealth funktioniert ohne Konto, Werbung, Analyse- oder KI-Dienste. '
      'Deine Einträge liegen nur auf diesem Gerät, verschlüsselt mit einem '
      'Schlüssel, den der Android-Keystore schützt. Nur die '
      'Online-Lebensmittelsuche nutzt das Internet – und zwar nur mit deinen '
      'Suchbegriffen oder Barcodes.';
  @override
  String get licenses => 'Open-Source-Lizenzen';
  @override
  String get storageInfo => 'Auf diesem Gerät gespeichert';
  @override
  String dataCounts(int diaryEntries, int foods) =>
      '$diaryEntries Tagebucheinträge · $foods Lebensmittel';
  @override
  String get cancelled => 'Abgebrochen';
  @override
  String get fileSaveFailed => 'Die Datei konnte nicht gespeichert werden.';
  @override
  String get fileOpenFailed => 'Die Datei konnte nicht gelesen werden.';
  @override
  String get storeErrorTitle => 'Deine Daten konnten nicht geöffnet werden';
  @override
  String storeErrorText(String code) => switch (code) {
    'store_wrong_key' =>
      'Der Schlüssel passt nicht zu den gespeicherten Daten. Das kann nach '
          'der Wiederherstellung der App aus einer Gerätesicherung passieren.',
    'store_corrupted' => 'Die gespeicherten Daten sind beschädigt.',
    'store_unsupported' =>
      'Die Daten stammen von einer neueren MorphHealth-Version.',
    _ => 'Auf den Speicher konnte nicht zugegriffen werden ($code).',
  };
  @override
  String get resetStore => 'Mit leeren Daten neu beginnen';
  @override
  String get showPassphrase => 'Passphrase anzeigen';
  @override
  String get hidePassphrase => 'Passphrase verbergen';
  @override
  String get userAgent => 'User-Agent';
  @override
  String get noGoal => 'Kein Ziel';
  @override
  String get medicalNoteTitle => 'Hinweis';
}
