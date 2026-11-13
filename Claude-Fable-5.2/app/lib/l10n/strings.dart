import 'package:flutter/widgets.dart';
import 'package:morphhealth_core/morphhealth_core.dart';

/// All texts of the user interface in German and English.
///
/// Both languages stand next to each other in every member, so a text cannot
/// exist in one language only. German is the default language of the app.
class L {
  /// `de` or `en`.
  final String languageCode;

  const L(this.languageCode);

  bool get _de => languageCode != 'en';

  static L of(BuildContext context) => Localizations.of<L>(context, L)!;

  static const LocalizationsDelegate<L> delegate = _Delegate();

  String _n(int n, String deOne, String deMany, String enOne, String enMany) =>
      _de ? (n == 1 ? deOne : deMany) : (n == 1 ? enOne : enMany);

  /// [n] with the thousands separator of the language: 10.734 / 10,734.
  String _count(int n) {
    final digits = n.abs().toString();
    final b = StringBuffer(n < 0 ? '-' : '');
    for (var i = 0; i < digits.length; i++) {
      if (i > 0 && (digits.length - i) % 3 == 0) b.write(_de ? '.' : ',');
      b.write(digits[i]);
    }
    return b.toString();
  }

  // ------------------------------------------------------------- general

  String get appName => 'MorphHealth';
  String get save => _de ? 'Speichern' : 'Save';
  String get cancel => _de ? 'Abbrechen' : 'Cancel';
  String get delete => _de ? 'Löschen' : 'Delete';
  String get edit => _de ? 'Bearbeiten' : 'Edit';
  String get add => _de ? 'Hinzufügen' : 'Add';
  String get close => _de ? 'Schließen' : 'Close';
  String get ok => 'OK';
  String get undo => _de ? 'Rückgängig' : 'Undo';
  String get retry => _de ? 'Erneut versuchen' : 'Try again';
  String get back => _de ? 'Zurück' : 'Back';
  String get today => _de ? 'Heute' : 'Today';
  String get yesterday => _de ? 'Gestern' : 'Yesterday';
  String get tomorrow => _de ? 'Morgen' : 'Tomorrow';
  String get previousDay => _de ? 'Vorheriger Tag' : 'Previous day';
  String get nextDay => _de ? 'Nächster Tag' : 'Next day';
  String get pickDate => _de ? 'Datum wählen' : 'Choose date';
  String get date => _de ? 'Datum' : 'Date';
  String get time => _de ? 'Uhrzeit' : 'Time';
  String get note => _de ? 'Notiz' : 'Note';
  String get noteOptional => _de ? 'Notiz (optional)' : 'Note (optional)';
  String get entryDeleted => _de ? 'Eintrag gelöscht' : 'Entry deleted';
  String get saved => _de ? 'Gespeichert' : 'Saved';
  String get invalidNumber =>
      _de ? 'Bitte eine Zahl eingeben' : 'Please enter a number';
  String get requiredField => _de ? 'Bitte ausfüllen' : 'Please fill in';
  String get mustBePositive =>
      _de ? 'Muss größer als 0 sein' : 'Must be greater than 0';
  String valueTooLarge(String max) => _de ? 'Höchstens $max' : 'At most $max';
  String errorGeneric(String detail) =>
      _de ? 'Das hat nicht geklappt: $detail' : 'That did not work: $detail';
  String get saveFailed => _de
      ? 'Die Änderung konnte nicht gespeichert werden.'
      : 'The change could not be saved.';
  String get moreActions => _de ? 'Weitere Aktionen' : 'More actions';
  String get goToToday => _de ? 'Zu heute springen' : 'Go to today';

  // ---------------------------------------------------------- navigation

  String get navOverview => _de ? 'Übersicht' : 'Overview';
  String get navNutrition => _de ? 'Ernährung' : 'Nutrition';
  String get navCycle => _de ? 'Zyklus' : 'Cycle';
  String get navBody => _de ? 'Körper' : 'Body';
  String get navHistory => _de ? 'Verlauf' : 'History';
  String get settings => _de ? 'Einstellungen' : 'Settings';

  String area(Area a) => switch (a) {
    Area.nutrition => _de ? 'Ernährung' : 'Nutrition',
    Area.cycle => _de ? 'Zyklus' : 'Cycle',
    Area.weight => _de ? 'Gewicht' : 'Weight',
    Area.symptoms => _de ? 'Symptome' : 'Symptoms',
  };

  String meal(Meal m) => switch (m) {
    Meal.breakfast => _de ? 'Frühstück' : 'Breakfast',
    Meal.lunch => _de ? 'Mittagessen' : 'Lunch',
    Meal.dinner => _de ? 'Abendessen' : 'Dinner',
    Meal.snack => 'Snack',
  };

  String flow(FlowLevel f) => switch (f) {
    FlowLevel.spotting => _de ? 'Schmierblutung' : 'Spotting',
    FlowLevel.light => _de ? 'Leicht' : 'Light',
    FlowLevel.medium => _de ? 'Mittel' : 'Medium',
    FlowLevel.heavy => _de ? 'Stark' : 'Heavy',
  };

  String get flowNone => _de ? 'Keine Angabe' : 'Not specified';

  String unit(AmountUnit u) => switch (u) {
    AmountUnit.g => 'g',
    AmountUnit.ml => 'ml',
    AmountUnit.portion => _de ? 'Portion' : 'Serving',
  };

  String portions(String count, bool one) => _de
      ? '$count ${one ? 'Portion' : 'Portionen'}'
      : '$count ${one ? 'serving' : 'servings'}';

  String nutrient(Nutrient n) => n.label(languageCode);

  String nutrientGroup(NutrientGroup g) => switch (g) {
    NutrientGroup.energy || NutrientGroup.macro =>
      _de ? 'Kalorien und Makronährstoffe' : 'Calories and macronutrients',
    NutrientGroup.detail => _de ? 'Weitere Nährwerte' : 'Further nutrients',
    NutrientGroup.vitamin => _de ? 'Vitamine' : 'Vitamins',
    NutrientGroup.mineral => _de ? 'Mineralstoffe' : 'Minerals',
  };

  String metric(NutritionMetric m) {
    final n = m.nutrient;
    if (n != null) return nutrient(n);
    return m.key == NutritionMetric.water.key
        ? water
        : (_de ? 'Koffein gesamt' : 'Caffeine, total');
  }

  // ------------------------------------------------------------ overview

  String get overviewCustomize =>
      _de ? 'Übersicht anpassen' : 'Customize overview';
  String get overviewCustomizeHint => _de
      ? 'Wähle, welche Bereiche auf der Übersicht erscheinen. Die Bereiche '
            'selbst bleiben über die Leiste unten erreichbar.'
      : 'Choose which areas appear on the overview. The areas themselves '
            'stay available in the bar below.';
  String get overviewAllHidden =>
      _de ? 'Alle Bereiche sind ausgeblendet.' : 'All areas are hidden.';
  String get openDayDetail => _de ? 'Tagesdetail öffnen' : 'Open day detail';
  String get nothingLoggedYet =>
      _de ? 'Noch nichts erfasst' : 'Nothing recorded yet';
  String get logFood => _de ? 'Lebensmittel erfassen' : 'Log food';
  String ofGoal(String actual, String goal, String unit) =>
      _de ? '$actual von $goal $unit' : '$actual of $goal $unit';
  String get goal => _de ? 'Ziel' : 'Goal';
  String get noWeightYet =>
      _de ? 'Noch kein Gewicht eingetragen' : 'No weight recorded yet';
  String get addWeight => _de ? 'Gewicht eintragen' : 'Record weight';
  String get noSymptomsToday =>
      _de ? 'Heute keine Symptome eingetragen' : 'No symptoms recorded today';
  String get addSymptom => _de ? 'Symptom eintragen' : 'Record symptom';
  String sinceEntry(String change, String date) =>
      _de ? '$change seit $date' : '$change since $date';
  String openArea(String name) => _de ? '$name öffnen' : 'Open $name';

  // -------------------------------------------------- water and caffeine

  String get water => _de ? 'Wasser' : 'Water';
  String get caffeine => _de ? 'Koffein' : 'Caffeine';
  String get waterAndCaffeine =>
      _de ? 'Wasser und Koffein' : 'Water and caffeine';
  String addWaterSemantics(String amount) =>
      _de ? '$amount Wasser erfassen' : 'Record $amount of water';
  String waterAdded(String amount) =>
      _de ? '$amount Wasser erfasst' : '$amount of water recorded';
  String get otherAmount => _de ? 'Andere Menge' : 'Other amount';
  String get amountMl => _de ? 'Menge in ml' : 'Amount in ml';
  String get amountMg => _de ? 'Menge in mg' : 'Amount in mg';
  String get waterEntry => _de ? 'Wasser erfassen' : 'Record water';
  String get waterEdit => _de ? 'Wassereintrag bearbeiten' : 'Edit water entry';
  String get caffeineEntry => _de ? 'Koffein erfassen' : 'Record caffeine';
  String get caffeineEdit =>
      _de ? 'Koffeineintrag bearbeiten' : 'Edit caffeine entry';
  String get caffeineLabel =>
      _de ? 'Bezeichnung (optional)' : 'Description (optional)';
  String get caffeineLabelHint => _de ? 'z. B. Espresso' : 'e.g. espresso';
  String caffeineAdded(String amount) =>
      _de ? '$amount Koffein erfasst' : '$amount of caffeine recorded';
  String addCaffeineSemantics(String label, String amount) => _de
      ? '$label mit $amount Koffein erfassen'
      : 'Record $label with $amount of caffeine';
  String get caffeineFromFood => _de ? 'aus Lebensmitteln' : 'from foods';
  String get caffeineAdditional =>
      _de ? 'zusätzlich erfasst' : 'recorded separately';
  String get espresso => 'Espresso';
  String get coffee => _de ? 'Kaffee' : 'Coffee';
  String get tea => _de ? 'Tee' : 'Tea';
  String get energyDrink => 'Energydrink';
  String entriesCount(int n) => _n(
    n,
    '1 Eintrag',
    '${_count(n)} Einträge',
    '1 entry',
    '${_count(n)} entries',
  );
  String get showEntries => _de ? 'Einträge anzeigen' : 'Show entries';

  // ----------------------------------------------------------- nutrition

  String addToMeal(String meal) => _de ? 'Zu $meal hinzufügen' : 'Add to $meal';
  String get mealEmpty => _de ? 'Nichts erfasst' : 'Nothing recorded';
  String get repeatEntry => _de ? 'Erneut erfassen' : 'Log again';
  String entryRepeated(String name) =>
      _de ? '$name erneut erfasst' : '$name logged again';
  String entryAdded(String name) => _de ? '$name erfasst' : '$name logged';
  String get allNutrients => _de ? 'Alle Nährwerte' : 'All nutrients';
  String get dayNutrientsTitle =>
      _de ? 'Nährwerte des Tages' : 'Nutrients of the day';
  String coverage(int known, int total) => _de
      ? 'Angabe in $known von $total Einträgen'
      : 'stated in $known of $total entries';
  String get coverageNone => _de ? 'keine Angabe' : 'not stated';
  String get containsEstimates =>
      _de ? 'enthält Schätzwerte' : 'includes estimates';
  String get dayNutrientsHint => _de
      ? 'Nicht jedes Lebensmittel nennt alle Nährwerte. Die Summen zählen nur, '
            'was angegeben ist; daneben steht, wie viele Einträge beitragen.'
      : 'Not every food states every nutrient. The totals count only what is '
            'stated; next to them you see how many entries contribute.';
  String get goals => _de ? 'Tagesziele' : 'Daily goals';
  String get goalsIntro => _de
      ? 'Ziele sind freiwillig. Ein leeres Feld bedeutet: kein Ziel.'
      : 'Goals are optional. An empty field means: no goal.';
  String goalFor(String what, String unit) =>
      _de ? '$what in $unit' : '$what in $unit';
  String get myFoods => _de ? 'Meine Lebensmittel' : 'My foods';
  String get newOwnFood =>
      _de ? 'Eigenes Lebensmittel anlegen' : 'Create own food';
  String get addFood => _de ? 'Lebensmittel hinzufügen' : 'Add food';
  String get searchFoodHint => _de ? 'Lebensmittel suchen' : 'Search foods';
  String get enterBarcode => _de ? 'Barcode eingeben' : 'Enter barcode';
  String get barcode => 'Barcode';
  String get barcodeHelper => _de
      ? 'Die Ziffern unter dem Strichcode, 7 bis 14 Stellen'
      : 'The digits below the bar code, 7 to 14 digits';
  String get barcodeInvalid => _de
      ? 'Ein Barcode besteht aus 7 bis 14 Ziffern.'
      : 'A barcode consists of 7 to 14 digits.';
  String get barcodeCheckDigit => _de
      ? 'Die Prüfziffer passt nicht. Bitte auf Tippfehler prüfen.'
      : 'The check digit does not match. Please check for typos.';
  String barcodeNotFound(String code) => _de
      ? 'Zu $code ist in Open Food Facts kein Lebensmittel hinterlegt.'
      : 'Open Food Facts has no food for $code.';
  String get barcodeOtherType => _de
      ? 'Dieser Code gehört zu einem Produkt, das kein Lebensmittel ist.'
      : 'This code belongs to a product that is not a food.';
  String get createOwnWithBarcode =>
      _de ? 'Als eigenes Lebensmittel anlegen' : 'Create as own food';
  String get lookUp => _de ? 'Nachschlagen' : 'Look up';
  String get tabRecent => _de ? 'Zuletzt' : 'Recent';
  String get tabFavorites => _de ? 'Favoriten' : 'Favorites';
  String get tabOwn => _de ? 'Eigene' : 'Own';
  String get emptyRecent => _de
      ? 'Noch nichts erfasst. Suche ein Lebensmittel oder lege ein eigenes an.'
      : 'Nothing logged yet. Search for a food or create your own.';
  String get emptyFavorites => _de
      ? 'Noch keine Favoriten. Der Stern beim Erfassen merkt ein Lebensmittel '
            'vor.'
      : 'No favorites yet. The star in the entry form marks a food.';
  String get emptyOwn =>
      _de ? 'Noch keine eigenen Lebensmittel.' : 'No own foods yet.';
  String get sectionLocal => _de ? 'Meine Lebensmittel' : 'My foods';
  String get sectionOnline => 'Open Food Facts';
  String get noLocalMatches =>
      _de ? 'Kein Treffer in deinen Lebensmitteln' : 'No match in your foods';
  String searchOnlineFor(String q) => _de
      ? '„$q“ in Open Food Facts suchen'
      : 'Search Open Food Facts for “$q”';
  String get onlineConsentTitle => _de
      ? 'Online-Suche in Open Food Facts'
      : 'Online search in Open Food Facts';
  String get onlineConsentBody => _de
      ? 'Für eine Suche werden nur der Suchbegriff oder der Barcode an Open '
            'Food Facts gesendet. Dein Tagebuch verlässt das Gerät nicht. Die '
            'Suche lässt sich jederzeit in den Einstellungen ausschalten.'
      : 'A search sends only the search text or the barcode to Open Food '
            'Facts. Your diary never leaves the device. You can switch the '
            'search off in the settings at any time.';
  String get onlineEnable =>
      _de ? 'Online-Suche einschalten' : 'Switch on online search';
  String get onlineNotNow => _de ? 'Nicht jetzt' : 'Not now';
  String get onlineDisabledInfo => _de
      ? 'Die Online-Suche ist ausgeschaltet. Gesucht wird nur in deinen '
            'eigenen Lebensmitteln.'
      : 'Online search is switched off. Only your own foods are searched.';
  String get onlineSearchMinChars => _de
      ? 'Für die Online-Suche mindestens zwei Zeichen eingeben.'
      : 'Enter at least two characters for the online search.';
  String hits(int n) => _n(
    n,
    '1 Treffer',
    '${_count(n)} Treffer',
    '1 result',
    '${_count(n)} results',
  );
  String get loadMore => _de ? 'Weitere Treffer laden' : 'Load more results';
  String get noOnlineResults =>
      _de ? 'Kein Treffer in Open Food Facts' : 'No result in Open Food Facts';
  String get searching => _de ? 'Suche läuft …' : 'Searching …';
  String get loadingProduct =>
      _de ? 'Produkt wird geladen …' : 'Loading product …';
  String kcalPer(String kcal, String basis) =>
      _de ? '$kcal kcal je $basis' : '$kcal kcal per $basis';
  String get noNutritionData =>
      _de ? 'keine Nährwerte hinterlegt' : 'no nutrition facts available';
  String get offAttribution => _de
      ? 'Lebensmitteldaten: Open Food Facts, Open Database License'
      : 'Food data: Open Food Facts, Open Database License';
  String logAgainSemantics(String name, String amount) =>
      _de ? '$name, $amount, erneut erfassen' : 'Log $name, $amount, again';
  String foodError(String code) => switch (code) {
    'network' =>
      _de
          ? 'Open Food Facts ist nicht erreichbar. Besteht eine '
                'Internetverbindung?'
          : 'Open Food Facts cannot be reached. Is there an internet '
                'connection?',
    'timeout' =>
      _de
          ? 'Open Food Facts hat nicht rechtzeitig geantwortet.'
          : 'Open Food Facts did not answer in time.',
    'tls' =>
      _de
          ? 'Die sichere Verbindung zu Open Food Facts kam nicht zustande.'
          : 'The secure connection to Open Food Facts could not be set up.',
    'rate_limited' =>
      _de
          ? 'Zu viele Anfragen in kurzer Zeit. Bitte einen Moment warten.'
          : 'Too many requests in a short time. Please wait a moment.',
    'server_error' =>
      _de
          ? 'Open Food Facts ist gerade nicht verfügbar.'
          : 'Open Food Facts is not available right now.',
    _ =>
      _de
          ? 'Die Antwort von Open Food Facts war nicht lesbar.'
          : 'The answer of Open Food Facts could not be read.',
  };

  // intake form
  String get amount => _de ? 'Menge' : 'Amount';
  String get unitLabel => _de ? 'Einheit' : 'Unit';
  String get mealLabel => _de ? 'Mahlzeit' : 'Meal';
  String portionSizeIn(String unit) =>
      _de ? 'Größe einer Portion in $unit' : 'Size of one serving in $unit';
  String portionEquals(String size) =>
      _de ? '1 Portion = $size' : '1 serving = $size';
  String get nutrientsOfAmount =>
      _de ? 'Nährwerte dieser Menge' : 'Nutrients of this amount';
  String per(String basis) => _de ? 'je $basis' : 'per $basis';
  String get estimatedLegend => _de
      ? '≈ Schätzwert von Open Food Facts'
      : '≈ estimate by Open Food Facts';
  String get preparedHint => _de
      ? 'Die Werte gelten für das zubereitete Produkt.'
      : 'The values describe the prepared product.';
  String conversionHint(String density) => _de
      ? 'Umrechnung zwischen g und ml mit $density g je ml'
      : 'Converted between g and ml with $density g per ml';
  String get favoriteAdd => _de ? 'Als Favorit merken' : 'Mark as favorite';
  String get favoriteRemove =>
      _de ? 'Aus Favoriten entfernen' : 'Remove from favorites';
  String get deleteEntry => _de ? 'Eintrag löschen' : 'Delete entry';
  String get editFood => _de ? 'Lebensmittel bearbeiten' : 'Edit food';
  String get foodDetails => _de ? 'Lebensmittel ansehen' : 'View food';
  String get unknownFood => _de ? 'Unbekanntes Lebensmittel' : 'Unknown food';
  String get noNameProduct => _de ? 'Produkt ohne Namen' : 'Unnamed product';
  String get sourceOff => _de ? 'aus Open Food Facts' : 'from Open Food Facts';
  String get sourceOwn => _de ? 'eigenes Lebensmittel' : 'own food';
  String get refreshFromOff => _de
      ? 'Aus Open Food Facts aktualisieren'
      : 'Refresh from Open Food Facts';
  String get refreshed => _de ? 'Aktualisiert' : 'Refreshed';

  // food form
  String get foodNew => _de ? 'Eigenes Lebensmittel' : 'Own food';
  String get foodName => _de ? 'Name' : 'Name';
  String get brand => _de ? 'Marke (optional)' : 'Brand (optional)';
  String get barcodeOptional =>
      _de ? 'Barcode (optional)' : 'Barcode (optional)';
  String get basisTitle => _de ? 'Nährwerte gelten je' : 'Nutrients are per';
  String get servingSizeOptional =>
      _de ? 'Portionsgröße (optional)' : 'Serving size (optional)';
  String get servingLabelOptional => _de
      ? 'Bezeichnung der Portion (optional)'
      : 'Serving description (optional)';
  String get servingLabelHint => _de ? 'z. B. 1 Scheibe' : 'e.g. 1 slice';
  String get densityOptional =>
      _de ? 'Dichte in g je ml (optional)' : 'Density in g per ml (optional)';
  String get densityHelper => _de
      ? 'Nur nötig, wenn du zwischen Gramm und Millilitern umrechnen willst.'
      : 'Only needed to convert between grams and millilitres.';
  String get emptyMeansUnknown => _de
      ? 'Leere Felder gelten als unbekannt. Für null bitte 0 eintragen.'
      : 'Empty fields count as unknown. Enter 0 for zero.';
  String get advanced => _de ? 'Erweitert' : 'Advanced';
  String deleteFoodConfirm(String name) =>
      _de ? '„$name“ löschen?' : 'Delete “$name”?';
  String get foodDeleted => _de ? 'Lebensmittel gelöscht' : 'Food deleted';
  String get foodArchived => _de
      ? 'Das Lebensmittel steht in Tagebucheinträgen. Es wurde aus den Listen '
            'entfernt; die Einträge bleiben vollständig erhalten.'
      : 'The food is used in diary entries. It was removed from the lists; '
            'the entries stay complete.';
  String get saltSodiumHint => _de
      ? 'Salz und Natrium werden auseinander berechnet, wenn nur eines '
            'angegeben ist.'
      : 'Salt and sodium are derived from each other if only one is given.';

  // --------------------------------------------------------------- cycle

  String cycleDay(int n) => _de ? 'Zyklustag $n' : 'Cycle day $n';
  String periodDay(int n) => _de ? 'Periode, Tag $n' : 'Period, day $n';
  String get period => _de ? 'Periode' : 'Period';
  String nextPeriodAround(String date) => _de
      ? 'Nächste Periode voraussichtlich um den $date'
      : 'Next period expected around $date';
  String window(String from, String to) =>
      _de ? 'Zeitfenster $from bis $to' : 'Window $from to $to';
  String inDays(int n) => n == 0
      ? (_de ? 'heute' : 'today')
      : n == 1
      ? (_de ? 'morgen' : 'tomorrow')
      : (_de ? 'in $n Tagen' : 'in $n days');
  String get periodDue => _de
      ? 'Die Periode wird in diesen Tagen erwartet'
      : 'Your period is expected around now';
  String periodLate(int n) => _de
      ? 'Das Zeitfenster ist seit ${_n(n, '1 Tag', '$n Tagen', '', '')} vorbei'
      : 'The window ended ${_n(n, '', '', '1 day', '$n days')} ago';
  String get periodLateHint => _de
      ? 'Zyklen können sich verschieben. Trage den ersten Tag ein, sobald '
            'die Periode beginnt.'
      : 'Cycles can shift. Enter the first day when your period starts.';
  String get forecastStale => _de
      ? 'Für eine Einschätzung fehlen aktuelle Einträge.'
      : 'Recent entries are missing for an estimate.';
  String lastPeriodStarted(String date) => _de
      ? 'Letzte erfasste Periode: ab $date'
      : 'Last recorded period: from $date';
  String get noPeriodYet =>
      _de ? 'Noch keine Periode erfasst' : 'No period recorded yet';
  String get needTwoPeriods => _de
      ? 'Eine Einschätzung ist ab zwei erfassten Perioden möglich.'
      : 'An estimate is possible from two recorded periods.';
  String get periodStartsToday =>
      _de ? 'Periode beginnt heute' : 'Period starts today';
  String get periodEndsToday =>
      _de ? 'Periode endet heute' : 'Period ends today';
  String expectedUntil(String date) =>
      _de ? 'voraussichtlich bis $date' : 'expected until $date';
  String get diaryMode => _de
      ? 'Tagebuchmodus: Es wird nichts vorausberechnet.'
      : 'Diary mode: nothing is calculated ahead.';
  String get howCalculated =>
      _de ? 'Wie kommt das zustande?' : 'How is this worked out?';
  String get explanationTitle =>
      _de ? 'So entsteht die Einschätzung' : 'How the estimate is made';
  String get reliability => _de ? 'Verlässlichkeit' : 'Reliability';
  String confidence(Confidence c) => switch (c) {
    Confidence.low => _de ? 'gering' : 'low',
    Confidence.medium => _de ? 'mittel' : 'medium',
    Confidence.high => _de ? 'hoch' : 'high',
  };
  String get endMissingHint => _de
      ? 'Für die letzte Periode ist kein Ende eingetragen.'
      : 'The last period has no end recorded.';
  String get cyclesUsedTitle =>
      _de ? 'Berücksichtigte Zyklen' : 'Cycles considered';
  String cycleLength(int n) => _de ? '$n Tage' : '$n days';
  String get cycleNotUsed => _de ? 'nicht berücksichtigt' : 'not used';
  String get turnOffEstimates => _de
      ? 'Einschätzung in den Einstellungen ausschalten'
      : 'Switch estimates off in the settings';
  String get patternsTitle =>
      _de ? 'Wiederkehrende Muster' : 'Recurring patterns';
  String pattern(
    String symptom,
    int withIt,
    int total,
    PatternPhase phase,
    int offset,
  ) {
    final String where;
    if (phase == PatternPhase.beforePeriod) {
      final d = -offset;
      where = _de
          ? 'vor Beginn der Periode, meist ${_n(d, '1 Tag', '$d Tage', '', '')} vorher'
          : 'before your period starts, usually ${_n(d, '', '', '1 day', '$d days')} before';
    } else {
      where = _de
          ? 'in den ersten Tagen der Periode, meist an Tag ${offset + 1}'
          : 'in the first days of your period, usually on day ${offset + 1}';
    }
    return _de
        ? '$symptom: in $withIt von $total Zyklen $where'
        : '$symptom: in $withIt of $total cycles $where';
  }

  String get patternsHint => _de
      ? 'Beschreibt nur, was du eingetragen hast. Keine Aussage über Ursachen.'
      : 'Describes only what you recorded. No statement about causes.';

  // calendar
  String get previousMonth => _de ? 'Vorheriger Monat' : 'Previous month';
  String get nextMonth => _de ? 'Nächster Monat' : 'Next month';
  String get legendPeriod => _de ? 'Periode' : 'Period';
  String get legendExpected => _de ? 'Erwartete Periode' : 'Expected period';
  String get legendWindow => _de ? 'Möglicher Beginn' : 'Possible start';
  String get legendSymptom => _de ? 'Symptom' : 'Symptom';
  String get legendSpotting => _de ? 'Schmierblutung' : 'Spotting';
  String get legend => _de ? 'Legende' : 'Legend';
  String get semPeriodDay => _de ? 'Periode' : 'period';
  String get semExpected => _de ? 'Periode erwartet' : 'period expected';
  String get semWindow =>
      _de ? 'möglicher Beginn der Periode' : 'possible start of period';
  String get semSymptoms => _de ? 'Symptome eingetragen' : 'symptoms recorded';
  String get semSpotting => _de ? 'Schmierblutung' : 'spotting';
  String get semNote => _de ? 'Notiz vorhanden' : 'has a note';
  String get semToday => _de ? 'heute' : 'today';
  String get semSelected => _de ? 'ausgewählt' : 'selected';

  // day panel
  String get periodBeganThisDay =>
      _de ? 'Periode begann an diesem Tag' : 'Period started on this day';
  String get periodEndedThisDay =>
      _de ? 'Periode endete an diesem Tag' : 'Period ended on this day';
  String get editPeriod => _de ? 'Periode bearbeiten' : 'Edit period';
  String get flowTitle => _de ? 'Blutungsstärke' : 'Bleeding strength';
  String flowOfDay(String day) =>
      _de ? 'Blutungsstärke am $day' : 'Bleeding strength on $day';
  String get spottingThisDay =>
      _de ? 'Schmierblutung an diesem Tag' : 'Spotting on this day';
  String get dayNote => _de ? 'Notiz zum Tag' : 'Note for the day';
  String get symptomsThisDay =>
      _de ? 'Symptome an diesem Tag' : 'Symptoms on this day';
  String get noSymptomsThisDay =>
      _de ? 'Keine Symptome eingetragen' : 'No symptoms recorded';
  String get futureDayHint => _de
      ? 'Für kommende Tage lässt sich noch nichts eintragen.'
      : 'Nothing can be recorded for days to come.';
  String get periodRunning => _de ? 'läuft noch' : 'still running';
  String get expectedPeriodDay => _de
      ? 'Für diesen Tag wird die Periode erwartet.'
      : 'Your period is expected on this day.';
  String get possibleStartDay => _de
      ? 'An diesem Tag könnte die Periode beginnen.'
      : 'Your period could start on this day.';
  String get periodStarted => _de ? 'Periode eingetragen' : 'Period recorded';
  String get periodEnded => _de ? 'Ende eingetragen' : 'End recorded';

  // period form and history
  String get periodNew => _de ? 'Periode eintragen' : 'Record period';
  String get periodFirstDay => _de ? 'Erster Tag' : 'First day';
  String get periodLastDay => _de ? 'Letzter Tag' : 'Last day';
  String get periodStillRunning =>
      _de ? 'Die Periode läuft noch' : 'The period is still running';
  String get flowPerDay =>
      _de ? 'Blutungsstärke je Tag' : 'Bleeding strength per day';
  String get deletePeriodConfirm =>
      _de ? 'Diese Periode löschen?' : 'Delete this period?';
  String get periodDeleted => _de ? 'Periode gelöscht' : 'Period deleted';
  String periodOverlap(String date) => _de
      ? 'Der Zeitraum überschneidet sich mit der Periode ab $date.'
      : 'The dates overlap the period that starts on $date.';
  String get periodEndBeforeStart => _de
      ? 'Der letzte Tag liegt vor dem ersten Tag.'
      : 'The last day is before the first day.';
  String periodTooLong(int n) => _de
      ? 'Eine Periode kann höchstens $n Tage umfassen.'
      : 'A period can cover at most $n days.';
  String get periodInFuture =>
      _de ? 'Der Tag liegt in der Zukunft.' : 'The day lies in the future.';
  String get cycleHistory => _de ? 'Periodenverlauf' : 'Period history';
  String daysCount(int n) => _n(n, '1 Tag', '$n Tage', '1 day', '$n days');
  String cycleOf(int n) => _de ? 'Zyklus $n Tage' : 'Cycle $n days';
  String get endNotRecorded =>
      _de ? 'Ende nicht eingetragen' : 'End not recorded';
  String get typicalCycle => _de ? 'Typischer Zyklus' : 'Typical cycle';
  String get typicalPeriod => _de ? 'Typische Periode' : 'Typical period';
  String cycleRange(int a, int b) => _de ? '$a bis $b Tage' : '$a to $b days';
  String get noPeriods => _de
      ? 'Noch keine Perioden erfasst. Tippe im Kalender auf den ersten Tag '
            'deiner Periode.'
      : 'No periods recorded yet. Tap the first day of your period in the '
            'calendar.';

  // ---------------------------------------------------------------- body

  String get weight => _de ? 'Gewicht' : 'Weight';
  String weightIn(String unit) => _de ? 'Gewicht in $unit' : 'Weight in $unit';
  String get weightEdit => _de ? 'Gewicht bearbeiten' : 'Edit weight';
  String get weightExists => _de
      ? 'Für diesen Tag gibt es bereits einen Eintrag. Ein weiterer Wert '
            'wird zusätzlich gespeichert.'
      : 'This day already has an entry. Another value is stored in addition.';
  String weightOutOfRange(String min, String max) => _de
      ? 'Bitte einen Wert zwischen $min und $max eingeben'
      : 'Please enter a value between $min and $max';
  String get noWeights => _de
      ? 'Noch keine Gewichtseinträge. Der erste Eintrag beginnt den Verlauf.'
      : 'No weight entries yet. The first entry starts the history.';
  String get range7 => _de ? '7 Tage' : '7 days';
  String get range28 => _de ? '28 Tage' : '28 days';
  String get range90 => _de ? '90 Tage' : '90 days';
  String get rangeAll => _de ? 'Alles' : 'All';
  String get rangeLabel => _de ? 'Zeitraum' : 'Range';
  String get symptoms => _de ? 'Symptome' : 'Symptoms';
  String get symptom => _de ? 'Symptom' : 'Symptom';
  String get symptomEdit => _de ? 'Symptom bearbeiten' : 'Edit symptom';
  String get symptomNameHint => _de ? 'z. B. Kopfschmerzen' : 'e.g. headache';
  String get intensity => _de ? 'Stärke' : 'Intensity';
  String intensityOf(int n) => _de ? 'Stärke $n von 10' : 'Intensity $n of 10';
  String get intensityScale => _de
      ? '0 = nicht spürbar, 10 = stärkste Ausprägung'
      : '0 = not noticeable, 10 = strongest';
  String get less => _de ? 'Schwächer' : 'Less';
  String get moreIntense => _de ? 'Stärker' : 'More';
  String get allSymptoms => _de ? 'Alle Symptome' : 'All symptoms';
  String get noSymptoms =>
      _de ? 'Noch keine Symptome eingetragen.' : 'No symptoms recorded yet.';
  String get strongestPerDay =>
      _de ? 'Stärkster Wert je Tag' : 'Strongest value per day';
  List<String> get symptomSuggestions => _de
      ? const [
          'Kopfschmerzen', 'Krämpfe', 'Müdigkeit', 'Rückenschmerzen',
          'Übelkeit', 'Stimmungstief', 'Blähungen', 'Schlafprobleme', //
        ]
      : const [
          'Headache', 'Cramps', 'Fatigue', 'Back pain', 'Nausea', 'Low mood',
          'Bloating', 'Sleep problems', //
        ];

  // ---------------------------------------------------------- day detail

  String get dayDetail => _de ? 'Tagesdetail' : 'Day detail';
  String get nothingThisDay => _de
      ? 'Für diesen Tag ist nichts eingetragen.'
      : 'Nothing is recorded for this day.';
  String get noPeriodThisDay =>
      _de ? 'Keine Periode eingetragen' : 'No period recorded';
  String get openInCalendar =>
      _de ? 'Im Zykluskalender öffnen' : 'Open in cycle calendar';

  // ------------------------------------------------------------- history

  String get tabEntries => _de ? 'Einträge' : 'Entries';
  String get tabTrends => _de ? 'Verläufe' : 'Trends';
  String get historySearchHint =>
      _de ? 'Einträge durchsuchen' : 'Search entries';
  String get clearSearch => _de ? 'Suche leeren' : 'Clear search';
  String get filterAllTime => _de ? 'Gesamter Zeitraum' : 'All time';
  String get filterLast7 => _de ? 'Letzte 7 Tage' : 'Last 7 days';
  String get filterLast28 => _de ? 'Letzte 28 Tage' : 'Last 28 days';
  String get filterCustomRange => _de ? 'Zeitraum wählen …' : 'Choose range …';
  String get filterPeriod => _de ? 'Zeitraum' : 'Date range';
  String get filterAreas => _de ? 'Bereiche' : 'Areas';
  String get noEntriesFound =>
      _de ? 'Keine Einträge gefunden.' : 'No entries found.';
  String get historyEmpty => _de
      ? 'Hier erscheinen alle Einträge aus Ernährung, Zyklus, Gewicht und '
            'Symptomen.'
      : 'All entries from nutrition, cycle, weight and symptoms appear here.';
  String get resetFilters => _de ? 'Filter zurücksetzen' : 'Reset filters';
  String get previousRange => _de ? 'Früherer Zeitraum' : 'Earlier range';
  String get nextRange => _de ? 'Späterer Zeitraum' : 'Later range';
  String get trendNoData =>
      _de ? 'Keine Einträge in diesem Zeitraum' : 'No entries in this range';
  String get average => _de ? 'Durchschnitt' : 'Average';
  String get lowest => _de ? 'Niedrigster Wert' : 'Lowest';
  String get highest => _de ? 'Höchster Wert' : 'Highest';
  String get valuesAsList => _de ? 'Werte als Liste' : 'Values as a list';
  String get quantity => _de ? 'Größe' : 'Quantity';
  String get periodDays => _de ? 'Periodentage' : 'Period days';
  String chartSummary(
    String title,
    String range,
    String avg,
    String min,
    String max,
    int days,
  ) => days == 1
      ? (_de
            ? '$title, $range: 1 Tag mit einem Wert, $avg.'
            : '$title, $range: 1 day with a value, $avg.')
      : (_de
            ? '$title, $range: $days Tage mit Werten. Durchschnitt $avg, '
                  'niedrigster Wert $min, höchster Wert $max.'
            : '$title, $range: $days days with values. Average $avg, lowest '
                  '$min, highest $max.');
  String chartEmpty(String title, String range) =>
      _de ? '$title, $range: keine Einträge.' : '$title, $range: no entries.';
  String periodDaysSummary(int n) => _de
      ? '${_n(n, '1 Periodentag', '$n Periodentage', '', '')} im Zeitraum'
      : '${_n(n, '', '', '1 period day', '$n period days')} in this range';
  String get spottingEntry => _de ? 'Schmierblutung' : 'Spotting';
  String get cycleNote => _de ? 'Notiz im Zyklus' : 'Cycle note';

  // ------------------------------------------------------------ settings

  String get language => _de ? 'Sprache' : 'Language';
  String get appearance => _de ? 'Darstellung' : 'Appearance';
  String get themeSystem => _de ? 'Wie das System' : 'Follow system';
  String get themeLight => _de ? 'Hell' : 'Light';
  String get themeDark => _de ? 'Dunkel' : 'Dark';
  String get overviewAreas =>
      _de ? 'Bereiche auf der Übersicht' : 'Areas on the overview';
  String get weightUnit => _de ? 'Gewichtseinheit' : 'Weight unit';
  String get kilograms => _de ? 'Kilogramm (kg)' : 'Kilograms (kg)';
  String get pounds => _de ? 'Pfund (lb)' : 'Pounds (lb)';
  String get waterQuickAmounts =>
      _de ? 'Schnellmengen für Wasser' : 'Quick amounts for water';
  String get waterQuickAmountsHelper => _de
      ? 'Bis zu sechs Mengen in ml, durch Komma getrennt'
      : 'Up to six amounts in ml, separated by commas';
  String get waterQuickAmountsInvalid => _de
      ? 'Bitte ein bis sechs ganze Zahlen zwischen 10 und 5000 eingeben'
      : 'Please enter one to six whole numbers between 10 and 5000';
  String get onlineSearch => _de
      ? 'Online-Suche in Open Food Facts'
      : 'Online search in Open Food Facts';
  String get onlineSearchOn => _de
      ? 'Suchbegriffe und Barcodes werden an Open Food Facts gesendet.'
      : 'Search texts and barcodes are sent to Open Food Facts.';
  String get onlineSearchOff => _de
      ? 'Aus: Es wird nichts ins Internet gesendet.'
      : 'Off: nothing is sent to the internet.';
  String get foodServer =>
      _de ? 'Adresse des Lebensmitteldienstes' : 'Address of the food service';
  String foodServerDefault(String url) =>
      _de ? 'Voreinstellung: $url' : 'Default: $url';
  String get foodServerHelper => _de
      ? 'Leer lassen für die Voreinstellung. Nur https.'
      : 'Leave empty for the default. https only.';
  String get foodServerInvalid => _de
      ? 'Bitte eine Adresse wie https://world.openfoodfacts.org eingeben'
      : 'Please enter an address like https://world.openfoodfacts.org';
  String get cyclePredictions =>
      _de ? 'Nächste Periode einschätzen' : 'Estimate the next period';
  String get cyclePredictionsOn => _de
      ? 'Aus deinen Einträgen wird die nächste Periode eingeschätzt.'
      : 'The next period is estimated from your entries.';
  String get cyclePredictionsOff => _de
      ? 'Aus: Der Periodentracker arbeitet nur als Tagebuch.'
      : 'Off: the period tracker works as a diary only.';
  String get typicalCycleLength =>
      _de ? 'Übliche Zykluslänge in Tagen' : 'Usual cycle length in days';
  String get typicalCycleHelper => _de
      ? 'Optional. Zählt nur, solange weniger als drei eigene Zyklen erfasst '
            'sind.'
      : 'Optional. Counts only while fewer than three own cycles are '
            'recorded.';
  String typicalCycleInvalid(int min, int max) => _de
      ? 'Bitte eine ganze Zahl von $min bis $max eingeben'
      : 'Please enter a whole number from $min to $max';
  String get notSet => _de ? 'nicht angegeben' : 'not set';
  String get dataTitle => _de ? 'Daten' : 'Data';
  String get dataSubtitle => _de
      ? 'Export, Import, Sicherung, Löschen'
      : 'Export, import, backup, delete';
  String get about => _de ? 'Über MorphHealth' : 'About MorphHealth';
  String get sectionGeneral => _de ? 'Allgemein' : 'General';

  // ---------------------------------------------------------------- data

  String get storageInfo => _de
      ? 'Alle Einträge liegen verschlüsselt auf diesem Gerät. Es gibt kein '
            'Konto und keinen Server; Android-Sicherungen sind für diese App '
            'ausgeschaltet.'
      : 'All entries are stored encrypted on this device. There is no '
            'account and no server; Android backups are switched off for this '
            'app.';
  String get exportData => _de ? 'Daten exportieren' : 'Export data';
  String get exportSubtitle => _de
      ? 'Vollständige, lesbare Kopie als JSON-Datei'
      : 'Complete, readable copy as a JSON file';
  String get exportWarnTitle =>
      _de ? 'Unverschlüsselter Export' : 'Unencrypted export';
  String get exportWarnBody => _de
      ? 'Die Datei enthält alle deine Gesundheitsdaten im Klartext. Jede App '
            'und jede Person mit Zugriff auf die Datei kann sie lesen. Für eine '
            'geschützte Kopie eignet sich die verschlüsselte Sicherung.'
      : 'The file contains all your health data in plain text. Any app and '
            'any person with access to the file can read it. For a protected '
            'copy use the encrypted backup.';
  String get exportConfirm =>
      _de ? 'Unverschlüsselt exportieren' : 'Export unencrypted';
  String fileSaved(String name) => _de ? 'Gespeichert: $name' : 'Saved: $name';
  String get importData => _de ? 'Daten importieren' : 'Import data';
  String get importSubtitle => _de
      ? 'JSON-Datei im MorphHealth-Format einlesen'
      : 'Read a JSON file in the MorphHealth format';
  String get importCheckTitle => _de ? 'Import prüfen' : 'Check import';
  String get importReplaces => _de
      ? 'Der Import ersetzt alle Daten, die jetzt auf diesem Gerät liegen.'
      : 'The import replaces all data that are on this device now.';
  String get fileContains => _de ? 'Die Datei enthält:' : 'The file contains:';
  String get currentlyStored =>
      _de ? 'Derzeit gespeichert:' : 'Currently stored:';
  String get replaceAll => _de ? 'Alles ersetzen' : 'Replace everything';
  String importDone(int n) => _de
      ? 'Import abgeschlossen: ${entriesCount(n)}'
      : 'Import finished: ${entriesCount(n)}';
  String get importRejectedTitle => _de
      ? 'Die Datei kann nicht importiert werden'
      : 'The file cannot be imported';
  String importProblems(int n) => _n(
    n,
    '1 Problem gefunden. Es wurde nichts geändert.',
    '$n Probleme gefunden. Es wurde nichts geändert.',
    '1 problem found. Nothing was changed.',
    '$n problems found. Nothing was changed.',
  );
  String importWarnings(int n) =>
      _n(n, '1 Hinweis', '$n Hinweise', '1 note', '$n notes');
  String get backupCreate =>
      _de ? 'Verschlüsselte Sicherung erstellen' : 'Create encrypted backup';
  String get backupCreateSubtitle => _de
      ? 'Datei mit Passphrase, geeignet für den Umzug auf ein neues Gerät'
      : 'File protected by a passphrase, suitable for moving to a new device';
  String get backupRestore =>
      _de ? 'Sicherung wiederherstellen' : 'Restore backup';
  String get backupRestoreSubtitle => _de
      ? 'Ersetzt alle Daten durch den Stand einer Sicherung'
      : 'Replaces all data by the content of a backup';
  String get passphrase => 'Passphrase';
  String get passphraseRepeat =>
      _de ? 'Passphrase wiederholen' : 'Repeat passphrase';
  String passphraseTooShort(int n) =>
      _de ? 'Mindestens $n Zeichen' : 'At least $n characters';
  String get passphraseMismatch => _de
      ? 'Die beiden Eingaben stimmen nicht überein'
      : 'The two entries do not match';
  String get passphraseHint => _de
      ? 'Die Passphrase wird nirgends gespeichert. Ohne sie lässt sich die '
            'Sicherung nicht mehr öffnen. Ein langer Satz ist sicherer als ein '
            'kurzes, kompliziertes Wort.'
      : 'The passphrase is not stored anywhere. Without it the backup cannot '
            'be opened. A long sentence is safer than a short, complicated '
            'word.';
  String get showPassphrase => _de ? 'Passphrase anzeigen' : 'Show passphrase';
  String get hidePassphrase => _de ? 'Passphrase verbergen' : 'Hide passphrase';
  String get backupWorking =>
      _de ? 'Sicherung wird verschlüsselt …' : 'Encrypting backup …';
  String get restoreWorking =>
      _de ? 'Sicherung wird entschlüsselt …' : 'Decrypting backup …';
  String get createBackup => _de ? 'Sicherung erstellen' : 'Create backup';
  String get openBackup => _de ? 'Sicherung öffnen' : 'Open backup';
  String backupFrom(String date) =>
      _de ? 'Sicherung vom $date' : 'Backup of $date';
  String backupError(String code) => switch (code) {
    'wrong_passphrase' =>
      _de
          ? 'Die Passphrase passt nicht zu dieser Sicherung.'
          : 'The passphrase does not open this backup.',
    'not_a_backup' =>
      _de
          ? 'Die Datei ist keine MorphHealth-Sicherung.'
          : 'The file is not a MorphHealth backup.',
    'unsupported' =>
      _de
          ? 'Die Sicherung stammt aus einer neueren Version von MorphHealth.'
          : 'The backup was written by a newer version of MorphHealth.',
    'weak_passphrase' => passphraseTooShort(BackupCodec.minPassphraseLength),
    _ => _de ? 'Die Sicherung ist beschädigt.' : 'The backup is damaged.',
  };
  String get restoreDone => _de
      ? 'Die Sicherung wurde wiederhergestellt.'
      : 'The backup has been restored.';
  String get wipe => _de ? 'Alle Daten löschen' : 'Delete all data';
  String get wipeSubtitle => _de
      ? 'Entfernt alle Einträge, Lebensmittel und Einstellungen von diesem '
            'Gerät'
      : 'Removes all entries, foods and settings from this device';
  String get wipeConfirmTitle =>
      _de ? 'Wirklich alles löschen?' : 'Really delete everything?';
  String get wipeConfirmBody => _de
      ? 'Alle Einträge, Lebensmittel und Einstellungen werden von diesem '
            'Gerät gelöscht. Das lässt sich nicht rückgängig machen. Bereits '
            'gespeicherte Exporte und Sicherungen bleiben erhalten.'
      : 'All entries, foods and settings are deleted from this device. This '
            'cannot be undone. Exports and backups you already saved are kept.';
  String get wipeConfirmCheck => _de
      ? 'Ich möchte alle Daten endgültig löschen'
      : 'I want to delete all data for good';
  String get wipeConfirmAction => _de ? 'Alles löschen' : 'Delete everything';
  String get wipeDone =>
      _de ? 'Alle Daten wurden gelöscht.' : 'All data have been deleted.';
  String get documentError => _de
      ? 'Die Datei konnte nicht gelesen oder geschrieben werden.'
      : 'The file could not be read or written.';
  String countLine(String key, int n) {
    final label = switch (key) {
      'foods' => _de ? 'Lebensmittel' : 'Foods',
      'intake' => _de ? 'Verzehreinträge' : 'Food entries',
      'water' => _de ? 'Wassereinträge' : 'Water entries',
      'caffeine' => _de ? 'Koffeineinträge' : 'Caffeine entries',
      'weights' => _de ? 'Gewichtseinträge' : 'Weight entries',
      'symptoms' => _de ? 'Symptomeinträge' : 'Symptom entries',
      'periods' => _de ? 'Perioden' : 'Periods',
      _ => _de ? 'Zyklusnotizen' : 'Cycle notes',
    };
    return '$label: ${_count(n)}';
  }

  // --------------------------------------------------------------- about

  String version(String v) => _de ? 'Version $v' : 'Version $v';
  String get aboutPurpose => _de
      ? 'MorphHealth ist ein persönliches Tagebuch für Ernährung, Zyklus, '
            'Gewicht und Symptome. Die App dient der eigenen Dokumentation und '
            'Planung. Sie stellt keine Diagnosen, berechnet keinen Eisprung und '
            'ist weder Verhütungsmittel noch Ersatz für ärztlichen Rat.'
      : 'MorphHealth is a personal diary for nutrition, cycle, weight and '
            'symptoms. It serves your own records and planning. It makes no '
            'diagnoses, calculates no ovulation and is neither a contraceptive '
            'nor a substitute for medical advice.';
  String get privacyTitle => _de ? 'Deine Daten' : 'Your data';
  List<String> get privacyPoints => _de
      ? const [
          'Kein Konto, keine Werbung, keine Nutzungsmessung.',
          'Alle Einträge liegen verschlüsselt auf diesem Gerät; den Schlüssel '
              'verwahrt der Schlüsselspeicher von Android.',
          'Ins Internet geht nur die Lebensmittelsuche, und nur wenn du sie '
              'einschaltest: Suchbegriff oder Barcode an Open Food Facts.',
          'Export und verschlüsselte Sicherung gehören dir und lassen sich '
              'jederzeit erstellen.',
        ]
      : const [
          'No account, no advertising, no usage tracking.',
          'All entries are stored encrypted on this device; the key is kept '
              'by the Android Keystore.',
          'Only the food search uses the internet, and only if you switch it '
              'on: search text or barcode to Open Food Facts.',
          'Export and encrypted backup are yours and can be made at any time.',
        ];
  String get offTitle => 'Open Food Facts';
  String get offNotice => _de
      ? 'Lebensmitteldaten stammen aus Open Food Facts und stehen unter der '
            'Open Database License (ODbL). Die Angaben werden von Freiwilligen '
            'gepflegt und können unvollständig oder fehlerhaft sein.'
      : 'Food data come from Open Food Facts and are available under the '
            'Open Database License (ODbL). They are maintained by volunteers '
            'and may be incomplete or wrong.';
  String get licenses => _de
      ? 'Lizenzen der verwendeten Bibliotheken'
      : 'Licenses of the libraries used';

  // ------------------------------------------------------------- welcome

  String get welcomeTitle =>
      _de ? 'Willkommen bei MorphHealth' : 'Welcome to MorphHealth';
  String get welcomeBody => _de
      ? 'Ein ruhiges Tagebuch für Ernährung, Zyklus, Gewicht und Symptome. '
            'Ohne Konto, verschlüsselt auf deinem Gerät.'
      : 'A calm diary for nutrition, cycle, weight and symptoms. No account, '
            'encrypted on your device.';
  String get welcomeAreas => _de
      ? 'Was soll auf deiner Übersicht erscheinen?'
      : 'What should appear on your overview?';
  String get welcomeChangeLater => _de
      ? 'Alles lässt sich später in den Einstellungen ändern.'
      : 'Everything can be changed later in the settings.';
  String get welcomeStart => _de ? 'Loslegen' : 'Get started';

  // ------------------------------------------------------------- startup

  String get startupOpening =>
      _de ? 'Daten werden geöffnet …' : 'Opening your data …';
  String get startupProblemTitle => _de
      ? 'Die gespeicherten Daten lassen sich nicht öffnen'
      : 'The stored data cannot be opened';
  String startupProblemBody(String code) => switch (code) {
    'key' || 'wrong_key' =>
      _de
          ? 'Der Schlüssel dieses Geräts passt nicht mehr zu den '
                'gespeicherten Daten. Das kann nach dem Zurücksetzen der '
                'Gerätesicherheit vorkommen. Mit einer verschlüsselten '
                'Sicherung lassen sich die Daten nach dem Zurücksetzen '
                'wiederherstellen.'
          : 'The key of this device no longer matches the stored data. '
                'This can happen after the device security was reset. With an '
                'encrypted backup the data can be restored after resetting.',
    'unsupported' =>
      _de
          ? 'Die Daten wurden mit einer neueren Version von MorphHealth '
                'gespeichert. Bitte die App aktualisieren.'
          : 'The data were stored by a newer version of MorphHealth. '
                'Please update the app.',
    _ =>
      _de
          ? 'Die Dateien sind beschädigt oder nicht lesbar.'
          : 'The files are damaged or cannot be read.',
  };
  String get startupReset =>
      _de ? 'Lokale Daten zurücksetzen' : 'Reset local data';
  String get startupResetConfirm => _de
      ? 'Alle Daten auf diesem Gerät werden gelöscht, damit die App neu '
            'starten kann. Das lässt sich nicht rückgängig machen.'
      : 'All data on this device are deleted so that the app can start '
            'again. This cannot be undone.';
  String get journalDamaged => _de
      ? 'Ein Teil der zuletzt gespeicherten Änderungen war nicht lesbar und '
            'wurde verworfen.'
      : 'Some of the most recently stored changes could not be read and '
            'were dropped.';

  /// Message for a change the data layer refused.
  String validation(ValidationException e, String Function(Day) formatDay) =>
      switch (e.code) {
        'period_overlap' => periodOverlap(
          e.details['other_start'] is Day
              ? formatDay(e.details['other_start'] as Day)
              : '',
        ),
        'period_end_before_start' => periodEndBeforeStart,
        'period_too_long' => periodTooLong(Period.maxLengthDays),
        'amount_invalid' => mustBePositive,
        'name_required' => requiredField,
        'portion_size_missing' =>
          _de
              ? 'Bitte die Größe einer Portion angeben.'
              : 'Please state the size of one serving.',
        'weight_invalid' =>
          _de
              ? 'Das Gewicht liegt außerhalb des möglichen Bereichs.'
              : 'The weight is outside the possible range.',
        _ => errorGeneric(e.message),
      };
}

class _Delegate extends LocalizationsDelegate<L> {
  const _Delegate();

  @override
  bool isSupported(Locale locale) =>
      locale.languageCode == 'de' || locale.languageCode == 'en';

  @override
  Future<L> load(Locale locale) async =>
      L(locale.languageCode == 'en' ? 'en' : 'de');

  @override
  bool shouldReload(_Delegate old) => false;
}
