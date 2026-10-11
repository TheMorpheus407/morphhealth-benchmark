// English texts (SPEC P02: entire UI usable in German and English).
library;

import '../model/cycle.dart';
import '../model/entries.dart';
import 'app_strings.dart';

class EnStrings extends AppStringsBase {
  @override
  String get lang => 'en';

  // ------------------------------------------------------------- Common
  @override String get appName => 'MorphHealth';
  @override String get ok => 'OK';
  @override String get cancel => 'Cancel';
  @override String get save => 'Save';
  @override String get delete => 'Delete';
  @override String get edit => 'Edit';
  @override String get close => 'Close';
  @override String get add => 'Add';
  @override String get search => 'Search';
  @override String get retry => 'Try again';
  @override String get loading => 'Loading …';
  @override String get done => 'Done';
  @override String get yes => 'Yes';
  @override String get no => 'No';
  @override String get back => 'Back';
  @override String get today => 'Today';
  @override String get yesterday => 'Yesterday';
  @override String get tomorrow => 'Tomorrow';
  @override String get now => 'Now';
  @override String get dateLabel => 'Date';
  @override String get timeLabel => 'Time';
  @override String get noteLabel => 'Note';
  @override String get optionalLabel => 'optional';
  @override String get confirmDeleteTitle => 'Delete this entry?';
  @override String get confirmDeleteMessage => 'This entry will be permanently deleted.';
  @override String get errorGeneric => 'An error occurred.';
  @override String get fieldRequired => 'Required field';
  @override String get invalidNumber => 'Invalid number';
  @override String get clearLabel => 'Clear';
  @override String get applyLabel => 'Apply';
  @override String get resetLabel => 'Reset';

  // ------------------------------------------------------------- Areas
  @override String get allAreasLabel => 'All areas';
  @override
  String areaName(String areaKey) => switch (areaKey) {
        'nutrition' => 'Nutrition',
        'cycle' => 'Cycle',
        'weight' => 'Weight',
        'symptoms' => 'Symptoms',
        _ => 'Overview',
      };

  // ------------------------------------------------------------- Overview
  @override String get todaySection => 'Today';
  @override String get nutritionCardTitle => 'Nutrition today';
  @override String get waterCardTitle => 'Water today';
  @override String get cycleCardTitle => 'Cycle today';
  @override String get weightCardTitle => 'Weight';
  @override String get symptomsCardTitle => 'Symptoms today';
  @override String get openTrends => 'Open trends';
  @override String get openHistory => 'Search history';
  @override String get openSettings => 'Open settings';
  @override String get openDayDetail => 'Open day details';
  @override String get noDataYet => 'No data yet. Log something — it will show up here.';

  // ------------------------------------------------------------- Nutrition
  @override String get waterLabel => 'Water';
  @override String get caffeineLabel => 'Caffeine';
  @override String get addEntry => 'Log food';
  @override String get addWater => 'Add water';
  @override String get addCaffeine => 'Add caffeine';
  @override String get quickWaterTitle => 'Quick log';
  @override String get customAmountLabel => 'Custom amount';
  @override String get quantityLabel => 'Amount';
  @override String get unitLabel => 'Unit';
  @override String get per100 => 'per 100 g';
  @override String get perPortion => 'per serving';
  @override String get dayTotal => 'Daily total';
  @override String get noGoal => 'No goal';
  @override String get allNutrients => 'All nutrients';
  @override String get mainNutrients => 'Main nutrients';
  @override String get vitamins => 'Vitamins';
  @override String get minerals => 'Minerals';
  @override String get noEntriesToday => 'No entries on this day yet.';
  @override String get diaryEmpty => 'Nothing logged on this day yet.';
  @override String get addFoodFirst => 'Create a custom food or search Open Food Facts.';
  @override String get entrySaved => 'Entry saved.';
  @override String get entryUpdated => 'Entry updated.';
  @override String get entryDeleted => 'Entry deleted.';
  @override String get waterSaved => 'Water logged.';
  @override String get caffeineSaved => 'Caffeine logged.';
  @override String get foodSearchTitle => 'Search food';
  @override String get searchHint => 'Enter a name or barcode';
  @override String get searchByBarcode => 'Look up barcode';
  @override String get barcodeLabel => 'Barcode number';
  @override String get invalidBarcode => 'Please enter a valid barcode (6–14 digits).';
  @override String get tabSearch => 'Search';
  @override String get tabFavorites => 'Favorites';
  @override String get tabCustom => 'Custom';
  @override String get tabRecent => 'Recent';
  @override String get searchNoResults => 'No results found.';
  @override String get searchError => 'Search failed. Check your internet connection.';
  @override String get lookupNotFound => 'Product not found.';
  @override String get addToDiary => 'Add to diary';
  @override String get reLog => 'Log again';
  @override String get foodDetailTitle => 'Food';
  @override String get foodNameLabel => 'Name';
  @override String get brandLabel => 'Brand';
  @override String get servingGramsLabel => 'Serving size (g)';
  @override String get servingLabelHint => 'Label, e.g. "1 slice"';
  @override String get favoriteAdd => 'Add to favorites';
  @override String get favoriteRemove => 'Remove from favorites';
  @override String get sourceLabel => 'Source';
  @override String get sourceOff => 'Open Food Facts';
  @override String get sourceCustom => 'Custom food';
  @override String get offAttribution => 'Product data: Open Food Facts (ODbL)';
  @override String get offLicenseFull => 'Product data from Open Food Facts (openfoodfacts.org), license: Open Database License (ODbL) 1.0.';
  @override String get nutrientsPer100 => 'Nutrients per 100 g';
  @override String get newFood => 'New food';
  @override String get editFood => 'Edit food';
  @override String get foodSaved => 'Food saved.';
  @override String get foodDeleted => 'Food deleted.';
  @override String get entryNewTitle => 'Log food';
  @override String get entryEditTitle => 'Edit entry';
  @override String get mealLabel => 'Meal';
  @override String get foodLabel => 'Food';
  @override String get selectFood => 'Select a food';
  @override String get changeFood => 'Change food';
  @override String get deleteEntryConfirm => 'Delete this entry?';
  @override String get selectFoodFirst => 'Please select a food first.';
  @override String get goalWaterLabel => 'Water goal';
  @override String get goalEnergyLabel => 'Calorie goal';
  @override String get goalProteinLabel => 'Protein goal';
  @override String get goalCarbsLabel => 'Carbohydrate goal';
  @override String get goalFatLabel => 'Fat goal';

  // ------------------------------------------------------------- Cycle
  @override String get cycleTitle => 'Cycle';
  @override String get calendarLabel => 'Calendar';
  @override String get addPeriod => 'Log period';
  @override String get periodStartLabel => 'Start';
  @override String get periodEndLabel => 'End';
  @override String get periodOngoing => 'ongoing';
  @override String get flowLabel => 'Flow strength';
  @override String get periodNoteLabel => 'Period note';
  @override String get startPeriodToday => 'Period started today';
  @override String get endPeriodToday => 'Period ended today';
  @override String get forecastTitle => 'Personal estimate';
  @override String get nextPeriodLabel => 'Next period';
  @override String get expectedStartLabel => 'Expected start';
  @override String get expectedEndLabel => 'Expected end';
  @override String get uncertaintyRangeLabel => 'Uncertain range';
  @override String get averageCycleLabel => 'Avg. cycle length';
  @override String get averagePeriodLabel => 'Avg. bleeding duration';
  @override String get confidenceLabel => 'Consistency';
  @override String get confidenceLow => 'low';
  @override String get confidenceMedium => 'medium';
  @override String get confidenceHigh => 'high';
  @override String get explanationTitle => 'How this estimate is made';
  @override String get disclaimer => 'This is a personal estimate based on your own records, not a medical prediction, diagnosis or treatment recommendation.';
  @override String get cycleHistory => 'History';
  @override String get noPeriods => 'No periods logged yet. Log your first period.';
  @override String get periodOpen => 'open';
  @override String get editPeriod => 'Edit period';
  @override String get deletePeriodConfirm => 'Delete this period?';
  @override String get stateLabel => 'Status';
  @override String get stateNoData => 'No data';
  @override String get stateInsufficient => 'Little data';
  @override String get stateBeforeNext => 'Before the next period';
  @override String get stateWithinRecorded => 'Within a logged period';
  @override String get stateWithinPredicted => 'Within a predicted period';
  @override String get stateBetweenPredicted => 'Between periods';
  @override String get legendRecorded => 'Logged';
  @override String get legendPredicted => 'Forecast';
  @override String get legendToday => 'Today';
  @override String get legendSymptom => 'Symptom';
  @override String get legendWeight => 'Weight';
  @override String get periodSaved => 'Period saved.';
  @override String get periodDeleted => 'Period deleted.';

  // ------------------------------------------------------------- Weight
  @override String get weightTitle => 'Weight';
  @override String get addWeight => 'Log weight';
  @override String get editWeight => 'Edit weight';
  @override String get weightLabel => 'Weight';
  @override String get weightKgLabel => 'Weight (kg)';
  @override String get weightLbLabel => 'Weight (lb)';
  @override String get unitKg => 'kg';
  @override String get unitLb => 'lb';
  @override String get latestWeight => 'Latest entry';
  @override String get noWeights => 'No weight entries yet.';
  @override String get weightSaved => 'Weight saved.';
  @override String get weightDeleted => 'Weight deleted.';
  @override String get weightHistory => 'History';

  // ------------------------------------------------------------- Symptoms
  @override String get symptomsTitle => 'Symptoms';
  @override String get addSymptom => 'Log symptom';
  @override String get editSymptom => 'Edit symptom';
  @override String get symptomNameLabel => 'Symptom';
  @override String get intensityLabel => 'Intensity';
  @override String get intensityHint => '0 = none, 10 = very strong';
  @override String get symptomHistory => 'History of this symptom';
  @override String get selectSymptomHint => 'Select a symptom';
  @override String get noSymptoms => 'No symptoms logged yet.';
  @override String get knownSymptoms => 'Known symptoms';
  @override String get symptomSaved => 'Symptom saved.';
  @override String get symptomDeleted => 'Symptom deleted.';

  // ------------------------------------------------------------- Day detail
  @override String get sectionNutrition => 'Nutrition';
  @override String get sectionWater => 'Water';
  @override String get sectionCaffeine => 'Caffeine';
  @override String get sectionWeight => 'Weight';
  @override String get sectionCycle => 'Period';
  @override String get sectionSymptoms => 'Symptoms';
  @override String get nothingLogged => 'Nothing logged on this day.';
  @override String get addForDay => 'Log for this day';

  // ------------------------------------------------------------- Trends
  @override String get trendsTitle => 'Trends';
  @override String get last7 => '7 days';
  @override String get last28 => '28 days';
  @override String get selectMetricLabel => 'Show';
  @override String get trendNoData => 'No data in this period.';
  @override String get averageLabel => 'Avg';
  @override String get totalLabel => 'Total';
  @override String get minLabel => 'Min';
  @override String get maxLabel => 'Max';
  @override
  String trendMetricName(String key) => switch (key) {
        'energy_kcal' => 'Calories',
        'protein_g' => 'Protein',
        'carbohydrates_g' => 'Carbohydrates',
        'fat_g' => 'Fat',
        'water' => 'Water',
        'caffeine' => 'Caffeine',
        'weight' => 'Weight',
        _ => nutrientName(key),
      };

  // ------------------------------------------------------------- History
  @override String get historyTitle => 'History';
  @override String get historySearchHint => 'Free text — e.g. food, symptom, note';
  @override String get filterAreaLabel => 'Area';
  @override String get filterAll => 'All';
  @override String get filterFrom => 'From';
  @override String get filterTo => 'To';
  @override String get noResults => 'No entries found.';
  @override String get openEntry => 'Open';

  // ------------------------------------------------------------- Settings
  @override String get settingsTitle => 'Settings';
  @override String get appearanceSection => 'Appearance';
  @override String get languageLabel => 'Language';
  @override String get languageSystem => 'System default';
  @override String get languageDe => 'German';
  @override String get languageEn => 'English';
  @override String get languageName => 'English';
  @override String get weightUnitLabel => 'Weight unit';
  @override String get areasSection => 'Visible areas';
  @override String get areasHint => 'At least one area must be visible.';
  @override String get goalsSection => 'Daily goals (optional)';
  @override String get goalsHint => 'Leave empty for no goal.';
  @override String get foodApiSection => 'Food search (Open Food Facts)';
  @override String get foodApiOrigin => 'Server';
  @override String get foodApiUserAgent => 'User agent';
  @override String get foodApiOfflineHint => 'Search requires an internet connection.';
  @override String get dataSection => 'Data';
  @override String get exportData => 'Export (plaintext JSON)';
  @override String get importData => 'Import (JSON)';
  @override String get backupCreate => 'Create backup (encrypted)';
  @override String get backupRestore => 'Restore backup';
  @override String get deleteAll => 'Delete all data';
  @override String get aboutSection => 'About MorphHealth';
  @override String get aboutVersion => 'Version';
  @override String get aboutPrivacy => 'All data stays encrypted on this device. No account, no telemetry, no ads.';
  @override String get aboutOffline => 'Everything except food search works without an internet connection.';
  @override String get storeErrorTitle => 'Data store not readable';
  @override String get storeErrorMessage => 'The stored data could not be decrypted (wrong key or damaged file).';
  @override String get storeErrorRetry => 'Try again';
  @override String get storeErrorDelete => 'Delete data and start fresh';

  // ------------------------------------------------------------- Data transfer
  @override String get exportTitle => 'Export data';
  @override String get exportAck => 'I understand: the export contains all health data in plaintext.';
  @override String get importTitle => 'Import data';
  @override String get importConfirm => 'The import replaces the entire current data set.';
  @override String get importSuccess => 'Import complete.';
  @override String get backupCreateTitle => 'Create backup';
  @override String get backupPassphrase => 'Passphrase';
  @override String get backupPassphraseRepeat => 'Repeat passphrase';
  @override String get backupPassphraseHint => 'At least 8 characters. Without the passphrase the backup cannot be restored.';
  @override String get backupSuccess => 'Backup created.';
  @override String get backupRestoreTitle => 'Restore backup';
  @override String get backupRestoreConfirm => 'Restoring replaces the current data set.';
  @override String get backupRestoreSuccess => 'Backup restored.';
  @override String get deleteAllTitle => 'Delete all data';
  @override String get deleteAllConfirm => 'Really delete ALL local data? This cannot be undone.';
  @override String get deleteAllSuccess => 'All data has been deleted.';
  @override String get passphraseRequired => 'Please enter a passphrase.';
  @override String get passphraseMismatch => 'The passphrases do not match.';
  @override String get passphraseTooShort => 'The passphrase must be at least 8 characters long.';
  @override String get fileSaveCanceled => 'Canceled.';

  // ------------------------------------------------------------- Accessibility
  @override String get a11yBack => 'Back';
  @override String get a11yMenu => 'Menu';
  @override String get a11yAdd => 'Add';
  @override String get a11yEdit => 'Edit';
  @override String get a11yDelete => 'Delete';
  @override String get a11ySearch => 'Search';
  @override String get a11yFavorite => 'Toggle favorite';
  @override String get a11yIncrement => 'Increase value';
  @override String get a11yDecrement => 'Decrease value';
  @override String get a11yCalendar => 'Calendar';
  @override String get a11yClose => 'Close';

  // ------------------------------------------------------------- Names
  @override
  String mealName(Meal meal) => switch (meal) {
        Meal.breakfast => 'Breakfast',
        Meal.lunch => 'Lunch',
        Meal.dinner => 'Dinner',
        Meal.snack => 'Snack',
      };

  @override
  String flowName(FlowLevel flow) => switch (flow) {
        FlowLevel.spotting => 'Spotting',
        FlowLevel.light => 'Light',
        FlowLevel.medium => 'Medium',
        FlowLevel.heavy => 'Heavy',
      };

  @override
  String quantityUnitName(QuantityUnit unit) => switch (unit) {
        QuantityUnit.g => 'Grams',
        QuantityUnit.ml => 'Milliliters',
        QuantityUnit.portion => 'Serving',
      };

  @override
  String weekdayName(int weekday) => switch (weekday) {
        1 => 'Monday',
        2 => 'Tuesday',
        3 => 'Wednesday',
        4 => 'Thursday',
        5 => 'Friday',
        6 => 'Saturday',
        7 => 'Sunday',
        _ => '',
      };

  @override
  String weekdayShort(int weekday) => switch (weekday) {
        1 => 'Mon',
        2 => 'Tue',
        3 => 'Wed',
        4 => 'Thu',
        5 => 'Fri',
        6 => 'Sat',
        7 => 'Sun',
        _ => '',
      };

  @override
  String monthName(int month) => switch (month) {
        1 => 'January',
        2 => 'February',
        3 => 'March',
        4 => 'April',
        5 => 'May',
        6 => 'June',
        7 => 'July',
        8 => 'August',
        9 => 'September',
        10 => 'October',
        11 => 'November',
        12 => 'December',
        _ => '',
      };

  @override
  String monthShort(int month) => switch (month) {
        1 => 'Jan',
        2 => 'Feb',
        3 => 'Mar',
        4 => 'Apr',
        5 => 'May',
        6 => 'Jun',
        7 => 'Jul',
        8 => 'Aug',
        9 => 'Sep',
        10 => 'Oct',
        11 => 'Nov',
        12 => 'Dec',
        _ => '',
      };

  @override
  String nutrientName(String key) => switch (key) {
        'energy_kcal' => 'Calories',
        'protein_g' => 'Protein',
        'carbohydrates_g' => 'Carbohydrates',
        'fat_g' => 'Fat',
        'saturated_fat_g' => 'Saturated fat',
        'sugars_g' => 'Sugars',
        'fiber_g' => 'Fiber',
        'salt_g' => 'Salt',
        'sodium_mg' => 'Sodium',
        'caffeine_mg' => 'Caffeine',
        'vitamin_a_ug' => 'Vitamin A',
        'vitamin_c_mg' => 'Vitamin C',
        'vitamin_d_ug' => 'Vitamin D',
        'vitamin_e_mg' => 'Vitamin E',
        'vitamin_k_ug' => 'Vitamin K',
        'vitamin_b1_mg' => 'Vitamin B1 (Thiamine)',
        'vitamin_b2_mg' => 'Vitamin B2 (Riboflavin)',
        'vitamin_b3_mg' => 'Vitamin B3 (Niacin)',
        'vitamin_b5_mg' => 'Vitamin B5 (Pantothenic acid)',
        'vitamin_b6_mg' => 'Vitamin B6',
        'vitamin_b7_ug' => 'Vitamin B7 (Biotin)',
        'vitamin_b9_ug' => 'Vitamin B9 (Folate)',
        'vitamin_b12_ug' => 'Vitamin B12',
        'calcium_mg' => 'Calcium',
        'iron_mg' => 'Iron',
        'magnesium_mg' => 'Magnesium',
        'potassium_mg' => 'Potassium',
        'zinc_mg' => 'Zinc',
        'selenium_ug' => 'Selenium',
        'iodine_ug' => 'Iodine',
        'phosphorus_mg' => 'Phosphorus',
        _ => key,
      };

  @override
  String nutrientShort(String key) => switch (key) {
        'energy_kcal' => 'kcal',
        'protein_g' => 'Protein',
        'carbohydrates_g' => 'Carbs',
        'fat_g' => 'Fat',
        'saturated_fat_g' => 'Sat. fat',
        'sugars_g' => 'Sugars',
        'fiber_g' => 'Fiber',
        'salt_g' => 'Salt',
        'sodium_mg' => 'Sodium',
        'caffeine_mg' => 'Caffeine',
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
        'calcium_mg' => 'Calcium',
        'iron_mg' => 'Iron',
        'magnesium_mg' => 'Magnesium',
        'potassium_mg' => 'Potassium',
        'zinc_mg' => 'Zinc',
        'selenium_ug' => 'Selenium',
        'iodine_ug' => 'Iodine',
        'phosphorus_mg' => 'Phosphorus',
        _ => key,
      };
}
