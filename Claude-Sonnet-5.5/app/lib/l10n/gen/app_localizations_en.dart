// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'MorphHealth';

  @override
  String get navOverview => 'Overview';

  @override
  String get navNutrition => 'Nutrition';

  @override
  String get navCycle => 'Cycle';

  @override
  String get navWeight => 'Weight';

  @override
  String get navSymptoms => 'Symptoms';

  @override
  String get commonSave => 'Save';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonClose => 'Close';

  @override
  String get commonRetry => 'Try again';

  @override
  String get commonToday => 'Today';

  @override
  String get bootFailedTitle => 'The data could not be opened';

  @override
  String get bootLoading => 'Opening MorphHealth';

  @override
  String get commonOk => 'OK';

  @override
  String get commonEdit => 'Edit';

  @override
  String get commonAdd => 'Add';

  @override
  String get commonBack => 'Back';

  @override
  String get commonDone => 'Done';

  @override
  String get commonUndo => 'Undo';

  @override
  String get commonMore => 'More';

  @override
  String get commonDate => 'Date';

  @override
  String get commonTime => 'Time';

  @override
  String get commonNote => 'Note';

  @override
  String get commonNoteOptional => 'Note (optional)';

  @override
  String get commonRequired => 'Required';

  @override
  String get commonInvalidNumber => 'Please enter a valid number';

  @override
  String get commonMustBePositive => 'The value must be greater than 0';

  @override
  String get commonNone => 'none';

  @override
  String get commonAll => 'All';

  @override
  String get commonShow => 'Show';

  @override
  String get commonHide => 'Hide';

  @override
  String get dayPrevious => 'Previous day';

  @override
  String get dayNext => 'Next day';

  @override
  String get dayPick => 'Choose date';

  @override
  String commonDeletedItem(String what) {
    return '$what deleted';
  }

  @override
  String get commonSaved => 'Saved';

  @override
  String commonError(String message) {
    return 'That did not work: $message';
  }

  @override
  String get unitG => 'g';

  @override
  String get unitMl => 'ml';

  @override
  String get unitPortion => 'Serving';

  @override
  String get unitKg => 'kg';

  @override
  String get unitLb => 'lb';

  @override
  String get mealBreakfast => 'Breakfast';

  @override
  String get mealLunch => 'Lunch';

  @override
  String get mealDinner => 'Dinner';

  @override
  String get mealSnack => 'Snack';

  @override
  String get flowSpotting => 'Spotting';

  @override
  String get flowLight => 'Light';

  @override
  String get flowMedium => 'Medium';

  @override
  String get flowHeavy => 'Heavy';

  @override
  String get flowNone => 'Not specified';

  @override
  String get nutritionTabDiary => 'Diary';

  @override
  String get nutritionTabTrends => 'Trends';

  @override
  String get nutritionAddFood => 'Add food';

  @override
  String get nutritionDaySummary => 'Day total';

  @override
  String nutritionKcalOfGoal(String value, String goal) {
    return '$value of $goal kcal';
  }

  @override
  String nutritionKcalPlain(String value) {
    return '$value kcal';
  }

  @override
  String nutritionKcalLeft(String value) {
    return '$value kcal to go';
  }

  @override
  String nutritionKcalOver(String value) {
    return '$value kcal above the goal';
  }

  @override
  String get nutritionGoalReached => 'Goal reached';

  @override
  String get nutritionAllNutrients => 'All nutrients';

  @override
  String get nutritionMealEmpty => 'Nothing logged yet';

  @override
  String nutritionAddToMeal(String meal) {
    return 'Add to $meal';
  }

  @override
  String get nutritionEntryRelog => 'Log again';

  @override
  String nutritionRelogged(String name) {
    return 'Logged “$name” again';
  }

  @override
  String get nutritionEntryDeleted => 'Entry deleted';

  @override
  String get nutritionDayEmpty => 'Nothing has been logged on this day.';

  @override
  String nutritionEntrySubtitle(String amount, String kcal) {
    return '$amount · $kcal';
  }

  @override
  String get nutritionNoKcal => 'no kcal data';

  @override
  String get nutritionNoData => 'no data';

  @override
  String nutritionCoverage(String count, String total) {
    return 'given for only $count of $total entries';
  }

  @override
  String get nutritionShowDetails => 'Show details';

  @override
  String get waterTitle => 'Water';

  @override
  String waterOfGoal(String value, String goal) {
    return '$value of $goal ml';
  }

  @override
  String waterPlain(String value) {
    return '$value ml';
  }

  @override
  String waterQuickAdd(String amount) {
    return 'Add $amount ml water';
  }

  @override
  String waterAdded(String amount) {
    return '$amount ml water logged';
  }

  @override
  String get waterOther => 'Other amount';

  @override
  String get waterLogTitle => 'Log water';

  @override
  String get waterEditTitle => 'Edit water entry';

  @override
  String get waterAmountLabel => 'Amount in ml';

  @override
  String waterEntryTitle(String amount) {
    return '$amount ml water';
  }

  @override
  String get waterEntriesToday => 'Entries of this day';

  @override
  String get caffeineTitle => 'Caffeine';

  @override
  String caffeineTotal(String value) {
    return '$value mg total';
  }

  @override
  String caffeineFromFoods(String value) {
    return '$value mg from foods';
  }

  @override
  String caffeineAdditional(String value) {
    return '$value mg logged separately';
  }

  @override
  String get caffeineLogTitle => 'Log caffeine';

  @override
  String get caffeineEditTitle => 'Edit caffeine entry';

  @override
  String get caffeineAmountLabel => 'Amount in mg';

  @override
  String get caffeineLabelHint => 'Label (optional)';

  @override
  String get caffeinePresetNote => 'Typical values, adjust as needed';

  @override
  String get caffeineCoffee => 'Coffee';

  @override
  String get caffeineEspresso => 'Espresso';

  @override
  String get caffeineTea => 'Black tea';

  @override
  String get caffeineGreenTea => 'Green tea';

  @override
  String get caffeineCola => 'Cola';

  @override
  String get caffeineEnergy => 'Energy drink';

  @override
  String caffeineEntryTitle(String mg) {
    return '$mg mg caffeine';
  }

  @override
  String caffeineAdded(String mg) {
    return '$mg mg caffeine logged';
  }

  @override
  String get pickerSearchHint => 'Search foods';

  @override
  String get pickerBarcodeHint => 'Enter barcode number';

  @override
  String get pickerModeName => 'Name';

  @override
  String get pickerModeBarcode => 'Barcode';

  @override
  String get pickerTabSearch => 'Search';

  @override
  String get pickerTabRecent => 'Recent';

  @override
  String get pickerTabFavorites => 'Favorites';

  @override
  String get pickerTabCustom => 'My foods';

  @override
  String get pickerSearchButton => 'Search';

  @override
  String get pickerOnlineHint => 'Search uses Open Food Facts. Only the search term is sent to the service.';

  @override
  String get pickerOnlineDisabled => 'Online search is switched off. You can switch it on in the settings.';

  @override
  String pickerNoResults(String query) {
    return 'No results for “$query”.';
  }

  @override
  String get pickerBarcodeNotFound => 'No product was found for this number.';

  @override
  String get pickerBarcodeInvalid => 'A barcode number has 8 to 14 digits.';

  @override
  String get pickerLoadMore => 'Load more';

  @override
  String pickerResultCount(String count) {
    return '$count results';
  }

  @override
  String get pickerErrorOffline => 'No connection to the food service. Please check your internet connection.';

  @override
  String get pickerErrorTimeout => 'The food service did not answer in time.';

  @override
  String get pickerErrorTls => 'The secure connection was rejected (certificate).';

  @override
  String get pickerErrorRate => 'The service is busy right now. Please try again later.';

  @override
  String pickerErrorGeneric(String code) {
    return 'The request failed ($code).';
  }

  @override
  String get pickerCreateCustom => 'Create custom food';

  @override
  String get pickerNoRecent => 'Nothing logged yet. Recently used foods appear here.';

  @override
  String get pickerNoFavorites => 'No favorites yet. Tap the star in an entry.';

  @override
  String get pickerNoCustom => 'No custom foods yet.';

  @override
  String get pickerNoLocalMatches => 'No matching foods in this list.';

  @override
  String foodPer100(String unit) {
    return 'per 100 $unit';
  }

  @override
  String foodKcalPer100(String kcal, String unit) {
    return '$kcal kcal per 100 $unit';
  }

  @override
  String get foodNoNutrition => 'No nutrition data';

  @override
  String get foodSourceOff => 'Open Food Facts';

  @override
  String get foodSourceCustom => 'Custom food';

  @override
  String get foodUnnamed => 'Unnamed product';

  @override
  String get foodDetailsLoading => 'Loading product details';

  @override
  String get foodDetailsFallback => 'The details could not be loaded. The values from the search are used.';

  @override
  String get foodFavoriteAdded => 'Added to favorites';

  @override
  String get foodFavoriteRemoved => 'Removed from favorites';

  @override
  String get foodDeleteLibraryTitle => 'Delete food?';

  @override
  String foodDeleteLibraryMessage(String name) {
    return '“$name” is removed from your library. Entries you already logged stay as they are.';
  }

  @override
  String get entryAddTitle => 'Add entry';

  @override
  String get entryEditTitle => 'Edit entry';

  @override
  String get entryAmount => 'Amount';

  @override
  String get entryUnit => 'Unit';

  @override
  String get entryServingSize => 'One serving equals';

  @override
  String get entryServingRequired => 'Please enter the size of one serving.';

  @override
  String entryServingInfo(String amount, String unit) {
    return '1 serving = $amount $unit';
  }

  @override
  String get entryPreview => 'Nutrition for this amount';

  @override
  String get entryMeal => 'Meal';

  @override
  String get entryFavoriteAdd => 'Add to favorites';

  @override
  String get entryFavoriteRemove => 'Remove from favorites';

  @override
  String get entryDelete => 'Delete entry';

  @override
  String get entryCopyToCustom => 'Copy as custom food';

  @override
  String get entryDataSource => 'Data: Open Food Facts (ODbL)';

  @override
  String get entryPreparedNote => 'The values refer to the prepared product.';

  @override
  String get entryIncompleteData => 'This product is missing nutrition data.';

  @override
  String entryAddedToMeal(String name, String meal) {
    return 'Added “$name” to $meal';
  }

  @override
  String get entryUpdated => 'Entry updated';

  @override
  String get customTitleNew => 'Custom food';

  @override
  String get customTitleEdit => 'Edit food';

  @override
  String get customName => 'Name';

  @override
  String get customBrand => 'Brand (optional)';

  @override
  String get customBarcode => 'Barcode (optional)';

  @override
  String get customBasis => 'The nutrition values refer to';

  @override
  String get customPer100g => '100 g';

  @override
  String get customPer100ml => '100 ml';

  @override
  String get customServing => 'Serving size (optional)';

  @override
  String get customServingLabel => 'Label (optional)';

  @override
  String customSectionMain(String unit) {
    return 'Main nutrients per 100 $unit';
  }

  @override
  String get customSectionMore => 'More nutrients';

  @override
  String get customSectionVitamins => 'Vitamins';

  @override
  String get customSectionMinerals => 'Minerals';

  @override
  String get customFavorite => 'Mark as favorite';

  @override
  String get customNoteEntries => 'Changes also apply to entries already logged with this food.';

  @override
  String get customSaltSodium => 'If only salt or only sodium is given, the other one is calculated.';

  @override
  String customSaved(String name) {
    return 'Saved “$name”';
  }

  @override
  String get nutrientsTitle => 'Nutrients';

  @override
  String get nutrientsGroupMain => 'Energy and main nutrients';

  @override
  String get nutrientsGroupMore => 'More nutrients';

  @override
  String get nutrientsGroupVitamins => 'Vitamins';

  @override
  String get nutrientsGroupMinerals => 'Minerals';

  @override
  String get nutrientsDashHint => 'A dash (–) stands for missing data in the logged entries.';

  @override
  String get trendsRange7 => '7 days';

  @override
  String get trendsRange28 => '28 days';

  @override
  String get trendsMetric => 'Show';

  @override
  String trendsAverage(String value, String days, String total) {
    return 'Average: $value ($days of $total days logged)';
  }

  @override
  String trendsMinMax(String min, String max) {
    return 'Lowest value $min, highest value $max';
  }

  @override
  String get trendsNoData => 'No values are logged in the selected period.';

  @override
  String get trendsGoal => 'Goal';

  @override
  String get trendsChartHint => 'Tap a bar to see its value';

  @override
  String get trendsNoDataDay => 'no data';

  @override
  String trendsSummary(String metric, String range, String avg, String days, String total) {
    return '$metric, $range. Average $avg. $days of $total days with data.';
  }

  @override
  String get historyTitle => 'History';

  @override
  String get historySearchHint => 'Search (name, note, symptom …)';

  @override
  String get historyAreas => 'Areas';

  @override
  String get historyPeriod => 'Period';

  @override
  String get historyPreset7 => 'Last 7 days';

  @override
  String get historyPreset28 => 'Last 28 days';

  @override
  String get historyPreset90 => 'Last 90 days';

  @override
  String get historyPresetAll => 'All time';

  @override
  String get historyCustomRange => 'Choose range';

  @override
  String historyCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count entries',
      one: '1 entry',
      zero: 'No entries',
    );
    return '$_temp0';
  }

  @override
  String get historyEmpty => 'No entries found. Adjust the search term or filters.';

  @override
  String get historyClearFilters => 'Reset filters';

  @override
  String historyPeriodTitle(String from, String to) {
    return 'Period $from to $to';
  }

  @override
  String historyPeriodOpen(String from) {
    return 'Period from $from (ongoing)';
  }

  @override
  String historySymptomTitle(String name, String intensity) {
    return '$name · $intensity of 10';
  }

  @override
  String historyCaffeineTitle(String mg) {
    return '$mg mg caffeine';
  }

  @override
  String get weightAdd => 'Log weight';

  @override
  String get weightEditTitle => 'Edit weight entry';

  @override
  String get weightValueLabel => 'Weight';

  @override
  String weightLatest(String value, String date) {
    return 'Latest: $value on $date';
  }

  @override
  String weightChange(String delta) {
    return '$delta compared with the previous entry';
  }

  @override
  String get weightNoEntries => 'No weight logged yet.';

  @override
  String get weightRange90 => '90 days';

  @override
  String get weightRangeAll => 'All';

  @override
  String weightChartSummary(String range, String first, String last, int count) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count entries', one: '1 entry');
    return 'Weight trend, $range. First value $first, last value $last, $_temp0.';
  }

  @override
  String weightStats(String min, String max, String delta) {
    return 'Lowest value $min, highest value $max, change $delta';
  }

  @override
  String get weightChartHint => 'Tap a point to see its value';

  @override
  String get weightEntriesTitle => 'Entries';

  @override
  String get weightNoteHint => 'Note (optional)';

  @override
  String get weightNoRange => 'No weight is logged in the selected period.';

  @override
  String get symptomAdd => 'Log symptom';

  @override
  String get symptomEditTitle => 'Edit symptom';

  @override
  String get symptomNameLabel => 'Name of the symptom';

  @override
  String get symptomIntensity => 'Intensity';

  @override
  String symptomIntensityValue(String value) {
    return '$value of 10';
  }

  @override
  String get symptomIntensityHint => '0 = barely noticeable, 10 = very strong';

  @override
  String get symptomRecent => 'Recently used';

  @override
  String get symptomTabDay => 'Day';

  @override
  String get symptomTabHistory => 'Trend';

  @override
  String get symptomNoEntries => 'No symptoms are logged on this day.';

  @override
  String get symptomPick => 'Choose symptom';

  @override
  String symptomStats(int count, String avg, String max) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count entries', one: '1 entry');
    return '$_temp0, average $avg of 10, maximum $max';
  }

  @override
  String get symptomNoHistory => 'No symptoms logged yet. Once you log one, its trend appears here.';

  @override
  String symptomChartSummary(String name, String range, int count, String avg) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count entries', one: '1 entry');
    return 'Trend of $name, $range. $_temp0, average $avg of 10.';
  }

  @override
  String symptomLogged(String name) {
    return 'Logged “$name”';
  }

  @override
  String symptomEntryTitle(String name, String intensity) {
    return '$name, intensity $intensity of 10';
  }

  @override
  String get symptomNoInRange => 'This symptom is not logged in the selected period.';

  @override
  String get cycleTabCalendar => 'Calendar';

  @override
  String get cycleTabHistory => 'History';

  @override
  String get cycleForecastTitle => 'Estimate';

  @override
  String cycleStateAsOf(String date) {
    return 'As of $date';
  }

  @override
  String get cycleNoDataTitle => 'No periods recorded yet';

  @override
  String get cycleNoDataBody =>
      'Once two period starts are recorded, MorphHealth estimates the next start from your own intervals.';

  @override
  String get cycleInsufficientTitle => 'More data is needed for an estimate';

  @override
  String get cycleInsufficientBody =>
      'A cycle needs two period starts. Record more periods or set a typical cycle length in the settings.';

  @override
  String cycleInPeriodTitle(String day) {
    return 'Day $day of your period';
  }

  @override
  String cyclePredictedIn(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Expected to start in $days days',
      one: 'Expected to start tomorrow',
      zero: 'Expected to start today',
    );
    return '$_temp0';
  }

  @override
  String cycleNextStart(String date) {
    return 'Expected start: $date';
  }

  @override
  String cycleWindowLine(String from, String to) {
    return 'Likely window: $from to $to';
  }

  @override
  String cycleOverdueTitle(int days) {
    String _temp0 = intl.Intl.pluralLogic(days, locale: localeName, other: '$days days', one: '1 day');
    return 'The calculated start was $_temp0 ago';
  }

  @override
  String get cycleOverdueBody => 'No new period is recorded yet. Enter the start as soon as it happens.';

  @override
  String get cycleStaleTitle => 'Your last recorded start was a long time ago';

  @override
  String get cycleStaleBody => 'Entries are probably missing, so there is no current estimate.';

  @override
  String get cycleDisabledTitle => 'Forecast switched off';

  @override
  String get cycleDisabledBody =>
      'The cycle area works as a plain diary. You can switch the forecast on in the settings.';

  @override
  String cycleCycleDay(String day) {
    return 'Cycle day $day';
  }

  @override
  String cycleConfidence(String level) {
    return 'Reliability: $level';
  }

  @override
  String get cycleConfHigh => 'high';

  @override
  String get cycleConfMedium => 'medium';

  @override
  String get cycleConfLow => 'low';

  @override
  String get cycleExplainButton => 'How is this estimate made?';

  @override
  String get cycleExplainTitle => 'Explanation of the estimate';

  @override
  String get cycleExplainIntervals => 'Intervals between period starts';

  @override
  String get cycleExplainUsed => 'used';

  @override
  String get cycleExplainTooShort => 'not used: under 15 days';

  @override
  String get cycleExplainTooLong => 'not used: over 60 days';

  @override
  String get cycleExplainOlder => 'not used: older than the last 6 cycles';

  @override
  String get cycleExplainNoIntervals => 'No intervals yet.';

  @override
  String cycleIntervalRow(String from, String to, String days) {
    return '$from to $to: $days days';
  }

  @override
  String get cycleStartToday => 'Period starts today';

  @override
  String cycleStartOnDay(String date) {
    return 'Period starts on $date';
  }

  @override
  String get cycleEndToday => 'Period ends today';

  @override
  String cycleEndOnDay(String date) {
    return 'Period ends on $date';
  }

  @override
  String cycleStartedSnack(String date) {
    return 'Period from $date logged';
  }

  @override
  String cycleEndedSnack(String date) {
    return 'End of period on $date logged';
  }

  @override
  String get cycleAddPeriod => 'Log period';

  @override
  String get cycleEditPeriod => 'Edit period';

  @override
  String get cycleStart => 'Start';

  @override
  String get cycleEnd => 'End';

  @override
  String get cycleOngoing => 'Still ongoing (no end recorded)';

  @override
  String get cycleFlow => 'Flow';

  @override
  String get cycleNotes => 'Notes';

  @override
  String cycleOverlap(String from, String to) {
    return 'The period overlaps an existing period ($from to $to).';
  }

  @override
  String get cycleEndBeforeStart => 'The end is before the start.';

  @override
  String get cycleTooLong => 'A period can span at most 60 days.';

  @override
  String get cycleMonthPrev => 'Previous month';

  @override
  String get cycleMonthNext => 'Next month';

  @override
  String get cycleMonthPick => 'Choose month';

  @override
  String get cycleLegendPeriod => 'Period';

  @override
  String get cycleLegendPredicted => 'Expected';

  @override
  String get cycleLegendWindow => 'Window';

  @override
  String get cycleLegendSymptom => 'Symptoms logged';

  @override
  String get cycleFlowOnDay => 'Flow on this day';

  @override
  String get cycleFlowRemove => 'Remove';

  @override
  String get cycleDaySymptoms => 'Symptoms on this day';

  @override
  String get cycleAddSymptomHere => 'Add symptom';

  @override
  String get cycleOpenDayDetail => 'Open day detail';

  @override
  String cycleDayInPeriod(String day) {
    return 'Period, day $day';
  }

  @override
  String get cycleDayNoPeriod => 'No period on this day.';

  @override
  String get cycleDayPredicted => 'Expected period day';

  @override
  String get cycleHistoryEmpty => 'No periods recorded yet.';

  @override
  String cycleHistoryDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(days, locale: localeName, other: '$days days', one: '1 day');
    return '$_temp0';
  }

  @override
  String cycleHistoryCycle(String days) {
    return 'Cycle $days days';
  }

  @override
  String get cycleEndMissing => 'End missing';

  @override
  String get cycleHistoryOngoing => 'ongoing';

  @override
  String get cycleStatsTitle => 'Numbers from your history';

  @override
  String cycleStatsAvg(String value) {
    return 'Average cycle length: $value days';
  }

  @override
  String cycleStatsPeriod(String value) {
    return 'Average period length: $value days';
  }

  @override
  String cycleStatsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count periods recorded',
      one: '1 period recorded',
    );
    return '$_temp0';
  }

  @override
  String get cycleSpottingNote => 'Spotting only: does not count as a period start for the estimate.';

  @override
  String get cycleDeleteTitle => 'Delete period?';

  @override
  String cycleDeleteMessage(String date) {
    return 'The period from $date will be deleted.';
  }

  @override
  String get cycleLegendToday => 'Today';

  @override
  String get dayDetailTitle => 'Day detail';

  @override
  String get overviewCustomize => 'Customize areas';

  @override
  String get overviewCustomizeHint => 'Hidden areas stay saved and can be shown again at any time.';

  @override
  String get overviewRangeDay => 'Day';

  @override
  String get overviewOpenDay => 'Day detail';

  @override
  String get overviewNothingVisible => 'All areas are hidden. Choose at least one under “Customize areas”.';

  @override
  String get overviewSettings => 'Settings';

  @override
  String get overviewWeightNone => 'No weight logged yet';

  @override
  String get overviewSymptomsNone => 'No symptoms logged on this day';

  @override
  String overviewAverageKcal(String value, String days, String total) {
    return 'Average $value kcal on $days of $total days';
  }

  @override
  String overviewWaterAverage(String value) {
    return 'Water: average $value ml';
  }

  @override
  String overviewCyclePeriods(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count periods in this range',
      one: '1 period in this range',
      zero: 'No period in this range',
    );
    return '$_temp0';
  }

  @override
  String get overviewTopSymptoms => 'Most frequent symptoms';

  @override
  String overviewSymptomCount(int count, String avg) {
    String _temp0 = intl.Intl.pluralLogic(count, locale: localeName, other: '$count entries', one: '1 entry');
    return '$_temp0, average $avg of 10';
  }

  @override
  String overviewWeightRange(String first, String last, String delta) {
    return 'From $first to $last ($delta)';
  }

  @override
  String overviewOpenArea(String area) {
    return 'Open $area';
  }

  @override
  String get overviewNoDataRange => 'No entries are logged in this range.';

  @override
  String get settingsTitle => 'Settings';

  @override
  String get settingsLanguage => 'Language';

  @override
  String get langGerman => 'Deutsch';

  @override
  String get langEnglish => 'English';

  @override
  String get settingsWeightUnit => 'Weight unit';

  @override
  String get settingsAreas => 'Areas in the overview';

  @override
  String get settingsGoals => 'Daily goals';

  @override
  String get settingsGoalsSubtitle => 'Optional: water, calories, protein, carbohydrates, fat';

  @override
  String get goalsHint => 'All goals are optional. An empty field means no goal. You choose the values.';

  @override
  String get goalWater => 'Water';

  @override
  String get goalEnergy => 'Calories';

  @override
  String get goalSaved => 'Goals saved';

  @override
  String get settingsCycleSection => 'Cycle';

  @override
  String get settingsForecast => 'Show forecast';

  @override
  String get settingsForecastHint => 'When switched off, the cycle area works as a diary only.';

  @override
  String get settingsExpectedCycle => 'Typical cycle length in days (optional)';

  @override
  String get settingsExpectedCycleHint => 'Only used until a complete cycle is recorded. Allowed: 15 to 60 days.';

  @override
  String get settingsOnlineSection => 'Online food search';

  @override
  String get settingsOnlineSwitch => 'Use Open Food Facts';

  @override
  String get settingsOnlineHint =>
      'Only the search term or barcode number is sent to the service. Without this feature the app works entirely locally.';

  @override
  String get settingsServer => 'Food API server';

  @override
  String get settingsServerHint => 'HTTPS origin, for example https://world.openfoodfacts.org';

  @override
  String get settingsServerInvalid =>
      'Please enter an HTTPS origin without a path, for example https://world.openfoodfacts.org.';

  @override
  String get settingsServerReset => 'Use default';

  @override
  String settingsServerDefault(String url) {
    return 'Default: $url';
  }

  @override
  String get settingsServerSaved => 'Server saved';

  @override
  String get settingsTheme => 'Appearance';

  @override
  String get themeSystem => 'System';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get settingsPrivacySection => 'Privacy';

  @override
  String get settingsSecure => 'Block screenshots';

  @override
  String get settingsSecureHint => 'Blocks screenshots and the preview in the recent apps list.';

  @override
  String get settingsData => 'Data and backup';

  @override
  String get settingsDataSubtitle => 'Export, import, encrypted backup, delete';

  @override
  String get settingsAbout => 'About MorphHealth';

  @override
  String get aboutText =>
      'MorphHealth stores all data encrypted on this device. There is no account, no advertising and no telemetry. Nutrition data comes from Open Food Facts (ODbL).';

  @override
  String get aboutMedical =>
      'MorphHealth is for personal documentation and planning. It does not replace medical advice and does not calculate diagnoses, ovulation or fertile days.';

  @override
  String aboutVersion(String version) {
    return 'Version $version';
  }

  @override
  String get aboutLicenses => 'Open source licenses';

  @override
  String get dataTitle => 'Data and backup';

  @override
  String get dataExportTitle => 'Data export (JSON)';

  @override
  String get dataExportHint =>
      'Complete, machine-readable export of all data. The format is described in the README. The file is not encrypted.';

  @override
  String get dataExportButton => 'Export';

  @override
  String get dataExportWarnTitle => 'Unencrypted export';

  @override
  String get dataExportWarnMessage =>
      'The file contains all your health data in plain text. Only save it somewhere you trust.';

  @override
  String dataExportDone(String name) {
    return 'Export saved: $name';
  }

  @override
  String get dataImportTitle => 'Data import (JSON)';

  @override
  String get dataImportHint => 'Replaces all existing data with the content of an export file.';

  @override
  String get dataImportButton => 'Choose file';

  @override
  String get dataImportPreviewTitle => 'Check import';

  @override
  String dataImportSummary(String count) {
    return 'The file contains $count records.';
  }

  @override
  String dataImportWarnings(String count) {
    return '$count notes while checking';
  }

  @override
  String get dataImportReplaceWarning => 'All existing data will be replaced.';

  @override
  String get dataImportConfirm => 'Replace';

  @override
  String get dataImportInvalid => 'The file is invalid';

  @override
  String get dataImportInvalidJson => 'The file is not valid JSON.';

  @override
  String dataImportDone(String count) {
    return 'Import complete: $count records';
  }

  @override
  String get dataBackupTitle => 'Encrypted backup';

  @override
  String get dataBackupHint =>
      'Backup protected by a passphrase (AES-256, Argon2id). It can be restored on a fresh installation.';

  @override
  String get dataBackupCreate => 'Create backup';

  @override
  String get dataPassphrase => 'Passphrase';

  @override
  String get dataPassphraseRepeat => 'Repeat passphrase';

  @override
  String get dataPassphraseMismatch => 'The passphrases do not match.';

  @override
  String dataPassphraseShort(String min) {
    return 'At least $min characters.';
  }

  @override
  String get dataBackupWarning => 'The backup cannot be opened without the passphrase. It cannot be reset.';

  @override
  String dataBackupDone(String name) {
    return 'Backup saved: $name';
  }

  @override
  String get dataRestoreTitle => 'Restore backup';

  @override
  String get dataRestoreHint => 'Replaces all existing data with the content of a backup.';

  @override
  String get dataRestoreButton => 'Choose backup';

  @override
  String get dataRestoreWrong => 'Wrong passphrase or damaged file.';

  @override
  String get dataRestoreNotBackup => 'The file is not a MorphHealth backup.';

  @override
  String dataRestoreDone(String count) {
    return 'Restored: $count records';
  }

  @override
  String get dataWorking => 'Please wait a moment …';

  @override
  String get dataWipeTitle => 'Delete all local data';

  @override
  String get dataWipeHint => 'Deletes all entries, foods and settings on this device and renews the key.';

  @override
  String get dataWipeButton => 'Delete everything';

  @override
  String get dataWipeConfirmTitle => 'Really delete everything?';

  @override
  String get dataWipeConfirmMessage =>
      'All entries, custom foods, favorites and settings are deleted permanently. Exports and backups you saved outside the app remain.';

  @override
  String get dataWipeDone => 'All data has been deleted.';

  @override
  String get dataFileTooLarge => 'The file is too large.';

  @override
  String get bootFailedWrongKey =>
      'The stored key does not match the data. This happens when the device was reset or the key was deleted.';

  @override
  String get bootFailedCorrupt => 'The data is damaged.';

  @override
  String get bootFailedLocked => 'The data is in use by another process.';

  @override
  String get bootFailedKey => 'The device master key could not be read.';

  @override
  String get bootFailedIo => 'The storage could not be accessed.';

  @override
  String get bootRestore => 'Restore from backup';

  @override
  String get bootStartFresh => 'Start fresh (delete all data)';

  @override
  String get waterTotalLabel => 'Total';

  @override
  String get unitPortions => 'servings';

  @override
  String get errAmountInvalid => 'The amount must be greater than 0.';

  @override
  String get errServingNeeded => 'Portions need a serving size.';

  @override
  String get errWeightRange => 'The weight is outside the allowed range (1 to 700 kg).';

  @override
  String get errSymptomInvalid => 'A symptom needs a name and an intensity from 0 to 10.';

  @override
  String get errFoodInvalid => 'A food needs a name, and a serving size must be greater than 0.';

  @override
  String get errRecordInvalid => 'These values cannot be saved as entered (too long or invalid).';

  @override
  String get errNothingToRemove => 'No period is recorded on this day.';

  @override
  String get errBackupUnsupported => 'This backup comes from another version or uses invalid parameters.';

  @override
  String get errBackupCorrupt => 'The content of the backup is damaged.';

  @override
  String get errPickerBusy => 'A file picker is already open.';

  @override
  String get dataRestorePreviewTitle => 'Check backup';
}
