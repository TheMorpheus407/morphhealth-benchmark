import '../cycle/forecast.dart';
import '../model/enums.dart';
import 'format.dart';
import 'strings.dart';

class SEn extends S {
  const SEn();

  @override
  AppLanguage get language => AppLanguage.en;

  // ---- General -----------------------------------------------------------
  @override
  String get ok => 'OK';
  @override
  String get cancel => 'Cancel';
  @override
  String get save => 'Save';
  @override
  String get delete => 'Delete';
  @override
  String get edit => 'Edit';
  @override
  String get add => 'Add';
  @override
  String get close => 'Close';
  @override
  String get done => 'Done';
  @override
  String get retry => 'Try again';
  @override
  String get undo => 'Undo';
  @override
  String get next => 'Next';
  @override
  String get back => 'Back';
  @override
  String get search => 'Search';
  @override
  String get clear => 'Clear';
  @override
  String get today => 'Today';
  @override
  String get yesterday => 'Yesterday';
  @override
  String get tomorrow => 'Tomorrow';
  @override
  String get date => 'Date';
  @override
  String get time => 'Time';
  @override
  String get note => 'Note';
  @override
  String get noteOptional => 'Note (optional)';
  @override
  String get optional => 'optional';
  @override
  String get none => 'None';
  @override
  String get more => 'More';
  @override
  String get saved => 'Saved';
  @override
  String get deleted => 'Deleted';
  @override
  String get entryDeleted => 'Entry deleted';
  @override
  String get fieldRequired => 'Please fill in this field';
  @override
  String get invalidNumber => 'Please enter a number';
  @override
  String numberRange(String min, String max) =>
      'Please enter a value between $min and $max';
  @override
  String get previousDay => 'Previous day';
  @override
  String get nextDay => 'Next day';
  @override
  String get previousMonth => 'Previous month';
  @override
  String get nextMonth => 'Next month';
  @override
  String get chooseDate => 'Choose date';
  @override
  String get chooseTime => 'Choose time';
  @override
  String get loading => 'Loading …';
  @override
  String get errorGeneric => 'Something went wrong. Please try again.';
  @override
  String get favorite => 'Favourite';
  @override
  String get addFavorite => 'Add to favourites';
  @override
  String get removeFavorite => 'Remove from favourites';
  @override
  String get deleteConfirmTitle => 'Delete?';
  @override
  String get cannotUndo => 'This cannot be undone.';

  // ---- Navigation / areas ------------------------------------------------
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
  String get historyTitle => 'History';
  @override
  String get settingsTitle => 'Settings';
  @override
  String get dayDetailTitle => 'Day details';
  @override
  String areaName(Area area) => switch (area) {
    Area.nutrition => 'Nutrition',
    Area.cycle => 'Cycle',
    Area.weight => 'Weight',
    Area.symptoms => 'Symptoms',
  };
  @override
  String mealName(Meal meal) => switch (meal) {
    Meal.breakfast => 'Breakfast',
    Meal.lunch => 'Lunch',
    Meal.dinner => 'Dinner',
    Meal.snack => 'Snack',
  };
  @override
  String flowName(Flow flow) => switch (flow) {
    Flow.spotting => 'Spotting',
    Flow.light => 'Light',
    Flow.medium => 'Medium',
    Flow.heavy => 'Heavy',
  };
  @override
  String unitName(AmountUnit unit, {bool plural = false}) => switch (unit) {
    AmountUnit.g => 'g',
    AmountUnit.ml => 'ml',
    AmountUnit.portion => plural ? 'portions' : 'portion',
  };
  @override
  String nutrientName(String key) => switch (key) {
    'energy_kcal' => 'Calories',
    'protein_g' => 'Protein',
    'carbohydrates_g' => 'Carbohydrates',
    'fat_g' => 'Fat',
    'saturated_fat_g' => 'Saturated fat',
    'sugars_g' => 'Sugars',
    'fiber_g' => 'Fibre',
    'salt_g' => 'Salt',
    'sodium_mg' => 'Sodium',
    'caffeine_mg' => 'Caffeine',
    'vitamin_a_ug' => 'Vitamin A',
    'vitamin_c_mg' => 'Vitamin C',
    'vitamin_d_ug' => 'Vitamin D',
    'vitamin_e_mg' => 'Vitamin E',
    'vitamin_k_ug' => 'Vitamin K',
    'vitamin_b1_mg' => 'Vitamin B1 (thiamine)',
    'vitamin_b2_mg' => 'Vitamin B2 (riboflavin)',
    'vitamin_b3_mg' => 'Vitamin B3 (niacin)',
    'vitamin_b5_mg' => 'Vitamin B5 (pantothenic acid)',
    'vitamin_b6_mg' => 'Vitamin B6',
    'vitamin_b7_ug' => 'Vitamin B7 (biotin)',
    'vitamin_b9_ug' => 'Vitamin B9 (folate)',
    'vitamin_b12_ug' => 'Vitamin B12',
    'calcium_mg' => 'Calcium',
    'iron_mg' => 'Iron',
    'magnesium_mg' => 'Magnesium',
    'potassium_mg' => 'Potassium',
    'zinc_mg' => 'Zinc',
    'selenium_ug' => 'Selenium',
    'iodine_ug' => 'Iodine',
    'phosphorus_mg' => 'Phosphorus',
    'water_ml' => 'Water',
    'caffeine_total_mg' => 'Caffeine (total)',
    _ => key,
  };
  @override
  String get groupEnergyMacros => 'Energy & macronutrients';
  @override
  String get groupDetails => 'More details';
  @override
  String get groupVitamins => 'Vitamins';
  @override
  String get groupMinerals => 'Minerals';

  // ---- Onboarding ---------------------------------------------------------
  @override
  String get welcomeTitle => 'Welcome to MorphHealth';
  @override
  String get welcomeText =>
      'Your personal diary for nutrition, cycle, weight and symptoms. '
      'Everything stays on this device – no account, no ads, no tracking.';
  @override
  String get onboardingLanguage => 'Language';
  @override
  String get onboardingAreas => 'What would you like to see on the overview?';
  @override
  String get onboardingAreasHint =>
      'You can change this at any time. Hidden areas keep their data.';
  @override
  String get onboardingOnline => 'Online food search';
  @override
  String get onboardingOnlineHint =>
      'Search terms and barcodes are sent to the Open Food Facts database. '
      'Your health data never leaves the device.';
  @override
  String get onboardingPrivacy =>
      'Your data is stored encrypted on this device. You can export, back up '
      'or delete it at any time in the settings.';
  @override
  String get getStarted => 'Get started';

  // ---- Overview ----------------------------------------------------------
  @override
  String get customizeOverview => 'Customise overview';
  @override
  String get customizeOverviewHint =>
      'Choose the areas shown on the overview. Hidden areas keep their data.';
  @override
  String get noAreasVisible =>
      'All areas are hidden. Use “Customise overview” to show them again.';
  @override
  String get openDayDetail => 'Day details';
  @override
  String get nutritionToday => 'Nutrition';
  @override
  String kcalOfGoal(String value, String goal) => '$value of $goal kcal';
  @override
  String get noFoodLogged => 'Nothing logged yet';
  @override
  String get latestWeight => 'Latest entry';
  @override
  String get noWeightYet => 'No weight recorded yet';
  @override
  String get noSymptomsOnDay => 'No symptoms recorded for this day';
  @override
  String symptomsCount(int n) => n == 1 ? '1 symptom' : '$n symptoms';

  // ---- Nutrition diary ---------------------------------------------------
  @override
  String get addFood => 'Add food';
  @override
  String addFoodTo(Meal meal) => 'Add food to ${mealName(meal).toLowerCase()}';
  @override
  String get dayTotal => 'Day total';
  @override
  String get goal => 'Goal';
  @override
  String valueOfGoal(String value, String goal) => '$value of $goal';
  @override
  String get water => 'Water';
  @override
  String get waterAddCustom => 'Other amount';
  @override
  String get waterAmountMl => 'Water (ml)';
  @override
  String waterAdded(String amount) => '$amount water added';
  @override
  String get caffeine => 'Caffeine';
  @override
  String get caffeineAdditional => 'Additional caffeine';
  @override
  String get caffeineFromFoods => 'from logged foods';
  @override
  String get caffeineTotal => 'Total';
  @override
  String get caffeineAddCustom => 'Other amount';
  @override
  String get caffeineAmountMg => 'Caffeine (mg)';
  @override
  String get caffeineLabelOptional => 'Label (optional, e.g. espresso)';
  @override
  String caffeineAdded(String amount) => '$amount caffeine added';
  @override
  String get allNutrients => 'All nutrients';
  @override
  String coverage(int known, int total) =>
      'values from $known of $total entries';
  @override
  String get includesEstimates => 'includes estimates';
  @override
  String get estimated => 'estimated';
  @override
  String get nothingLoggedMeal => 'Nothing logged';
  @override
  String get logAgain => 'Log again';
  @override
  String loggedAgain(String date) => 'Logged again for $date';
  @override
  String get logAgainTitle => 'Log this entry again';
  @override
  String get editEntry => 'Edit entry';
  @override
  String get entryNutrients => 'Nutrients of this entry';
  @override
  String get dayTab => 'Day';
  @override
  String get trendTab => 'Trends';
  @override
  String get trendMetric => 'Nutrient';
  @override
  String days(int n) => '$n days';
  @override
  String get average => 'Average';
  @override
  String get averageHint => 'average of days with entries';
  @override
  String daysWithData(int n, int total) => '$n of $total days logged';
  @override
  String get minimum => 'Lowest';
  @override
  String get maximum => 'Highest';
  @override
  String get noDataInRange => 'No entries in this period.';
  @override
  String get showTable => 'Show as table';
  @override
  String get showChart => 'Show as chart';
  @override
  String get waterMetric => 'Water';
  @override
  String get caffeineTotalMetric => 'Caffeine (total)';

  // ---- Food search & library ---------------------------------------------
  @override
  String get foodSearchHint => 'Food name or barcode number';
  @override
  String get tabSearch => 'Search';
  @override
  String get tabFavorites => 'Favourites';
  @override
  String get tabRecent => 'Recent';
  @override
  String get tabMyFoods => 'My foods';
  @override
  String get searchOnline => 'Search Open Food Facts';
  @override
  String get loadMore => 'Load more';
  @override
  String get noResults => 'No results.';
  @override
  String get noFavorites =>
      'No favourites yet. Tap the star on a food to add it.';
  @override
  String get noRecent => 'Foods you log will appear here.';
  @override
  String get noCustomFoods => 'You have not created any foods yet.';
  @override
  String get localResults => 'On this device';
  @override
  String get onlineResults => 'Open Food Facts';
  @override
  String get onlineDisabled =>
      'Online search is switched off. You can switch it on in the settings.';
  @override
  String get searching => 'Searching …';
  @override
  String get barcodeNotFound => 'No product found for this barcode.';
  @override
  String get barcodeCheckDigitWarning =>
      'The check digit does not match – please check the number.';
  @override
  String lookupBarcode(String code) => 'Look up barcode $code';
  @override
  String get createCustomFood => 'Create your own food';
  @override
  String get offAttribution =>
      'Product data: Open Food Facts, available under the Open Database '
      'Licence (ODbL).';
  @override
  String perHundred(Basis basis) => 'per 100 ${basis.json}';
  @override
  String get perPortion => 'per portion';
  @override
  String get noNutritionData => 'No nutrition data';
  @override
  String get foodDetails => 'Food details';
  @override
  String get customFood => 'Own food';
  @override
  String get onlineFood => 'Open Food Facts';
  @override
  String resultCount(int n) => n == 1 ? '1 result' : '$n results';
  @override
  String foodApiError(String code) => switch (code) {
    'network_error' =>
      'No connection to the food database. Check your internet connection.',
    'network_timeout' => 'The food database did not respond in time.',
    'tls_error' => 'The secure connection to the food database failed.',
    'rate_limited' => 'Too many requests. Please wait a moment.',
    'online_disabled' => onlineDisabled,
    _ => 'The food database could not be reached ($code).',
  };
  @override
  String get amount => 'Amount';
  @override
  String get unit => 'Unit';
  @override
  String get meal => 'Meal';
  @override
  String get addToDiary => 'Add to diary';
  @override
  String get nutrientsForAmount => 'Nutrients for this amount';
  @override
  String get assumedDensity =>
      'Converted between g and ml assuming 1 g = 1 ml.';
  @override
  String portionDescription(String? label, String size, Basis basis) =>
      label == null ? '1 portion = $size ${basis.json}' : '1 portion ($label) = $size ${basis.json}';
  @override
  String addedToDiary(String name) => '$name added';

  // ---- Custom food editor ------------------------------------------------
  @override
  String get newCustomFood => 'New food';
  @override
  String get editCustomFood => 'Edit food';
  @override
  String get foodName => 'Name';
  @override
  String get brandOptional => 'Brand (optional)';
  @override
  String get barcodeOptional => 'Barcode (optional)';
  @override
  String get barcodeDigitsOnly => 'Digits only, please';
  @override
  String get basisLabel => 'Nutrition values refer to';
  @override
  String get servingSizeOptional => 'Portion size (optional)';
  @override
  String get servingLabelOptional => 'Portion name (optional, e.g. 1 slice)';
  @override
  String get densityOptional => 'Density in g/ml (optional)';
  @override
  String nutrientsPerHundred(Basis basis) =>
      'Nutrition values per 100 ${basis.json}';
  @override
  String get saltSodiumHint =>
      'If you enter only salt or only sodium, the other value is calculated '
      '(salt = sodium × 2.5).';
  @override
  String updateEntriesQuestion(int n) => n == 1
      ? '1 diary entry uses this food. Update it with the new values as well?'
      : '$n diary entries use this food. Update them with the new values as well?';
  @override
  String get updateEntriesYes => 'Update entries';
  @override
  String get updateEntriesNo => 'Only the food';
  @override
  String get deleteFoodQuestion =>
      'Delete this food? Diary entries that use it are kept.';
  @override
  String get foodDeleted => 'Food deleted';
  @override
  String valueTooLarge(String max) => 'At most $max';
  @override
  String get portionNeedsServing => 'Enter a portion size first.';

  // ---- Cycle -------------------------------------------------------------
  @override
  String get periodStartToday => 'Period started today';
  @override
  String get periodEndToday => 'Period ended today';
  @override
  String get addPastPeriod => 'Add a period';
  @override
  String get editPeriod => 'Edit period';
  @override
  String get newPeriod => 'New period';
  @override
  String get periodStart => 'First day';
  @override
  String get periodEnd => 'Last day';
  @override
  String get periodOngoing => 'Still ongoing';
  @override
  String get periodStillOngoing => 'ongoing';
  @override
  String get deletePeriodQuestion =>
      'Delete this period? Bleeding entries of these days are deleted too.';
  @override
  String get periodOverlap => 'This period overlaps with another period.';
  @override
  String get periodEndBeforeStart =>
      'The last day must not be before the first day.';
  @override
  String periodTooLong(int max) => 'A period can last at most $max days.';
  @override
  String get periodStartInFuture => 'The first day cannot be in the future.';
  @override
  String get onlyLatestOngoing =>
      'Only the most recent period can be ongoing. Please enter a last day.';
  @override
  String get flow => 'Bleeding';
  @override
  String get noFlow => 'None';
  @override
  String get legendPeriod => 'Period';
  @override
  String get legendPredicted => 'Estimated period';
  @override
  String get legendWindow => 'Likely start';
  @override
  String get legendSpotting => 'Spotting';
  @override
  String get legendSymptoms => 'Symptoms';
  @override
  String get legendToday => 'Today';
  @override
  String get calendar => 'Calendar';
  @override
  String get periodHistory => 'Periods';
  @override
  String get noPeriodsYet => 'No periods recorded yet.';
  @override
  String cycleLengthDays(int n) => 'cycle $n days';
  @override
  String periodLengthDays(int n) => n == 1 ? '1 day' : '$n days';
  @override
  String get averageCycle => 'Typical cycle';
  @override
  String get averagePeriod => 'Typical period';
  @override
  String get cycleLengthsChart => 'Cycle lengths';
  @override
  String get startPeriodHere => 'Period started on this day';
  @override
  String get endPeriodHere => 'Period ended on this day';
  @override
  String get symptomsOfDay => 'Symptoms';
  @override
  String get cycleDayNote => 'Note for this day';
  @override
  String dayInPeriod(int day) => 'Period day $day';
  @override
  String periodStarted(String date) => 'Period started on $date';
  @override
  String periodEnded(String date) => 'Period ended on $date';
  @override
  String get whyThisEstimate => 'How is this estimated?';
  @override
  String get explanationTitle => 'Your personal estimate';
  @override
  String get disclaimer =>
      'This estimate is for personal planning only. It is not a diagnosis, '
      'does not calculate ovulation and is not suitable for contraception.';
  @override
  String confidenceName(ForecastConfidence c) => switch (c) {
    ForecastConfidence.low => 'rough',
    ForecastConfidence.medium => 'moderate',
    ForecastConfidence.high => 'good',
  };
  @override
  String get predictionsOff =>
      'Diary mode: estimates are switched off.';
  @override
  String longOngoingPeriodHint(int days) =>
      'This period has been open for $days days. If it is already over, '
      'please enter the last day.';
  @override
  String get enterLastDay => 'Enter last day';
  @override
  String get flowOutsidePeriodQuestion =>
      'This day is not part of a recorded period. How would you like to save '
      'the bleeding?';
  @override
  String get startPeriodOnDay => 'Start a period on this day';
  @override
  String extendPeriodToDay(String date) => 'Extend the period to $date';
  @override
  String get onlySaveBleeding => 'Only save the bleeding';
  @override
  String get saveNote => 'Save note';
  @override
  String get cycleStats => 'Summary';
  @override
  String cyclesRecorded(int n) => n == 1 ? '1 recorded cycle' : '$n recorded cycles';

  @override
  String cycleHeadline(CycleForecast f, Fmt fmt) {
    if (f.currentPeriodDay != null) return 'Period · day ${f.currentPeriodDay}';
    switch (f.status) {
      case CycleStatus.noData:
        return 'No period recorded yet';
      case CycleStatus.beforeWindow:
        final d = f.daysUntilExpected!;
        return d == 1 ? 'Next period in about 1 day' : 'Next period in about $d days';
      case CycleStatus.inWindow:
        return 'Next period expected any day now';
      case CycleStatus.afterWindow:
        final d = f.daysAfterWindow!;
        return d == 1
            ? '1 day past the estimated window'
            : '$d days past the estimated window';
      case CycleStatus.insufficientData:
      case CycleStatus.diaryOnly:
      case CycleStatus.inPeriod:
        return f.cycleDay == null ? 'No period recorded yet' : 'Cycle day ${f.cycleDay}';
    }
  }

  @override
  String? cycleSubline(CycleForecast f, Fmt fmt) {
    String window() =>
        '${fmt.dayMonth(f.windowStart!)} – ${fmt.dayMonth(f.windowEnd!)}';
    switch (f.status) {
      case CycleStatus.noData:
        return 'Record the start of a period to see your cycle here.';
      case CycleStatus.diaryOnly:
        return predictionsOff;
      case CycleStatus.insufficientData:
        return 'A personal estimate is possible once a second period start is recorded.';
      case CycleStatus.inPeriod:
        final parts = <String>[];
        if (f.expectedCurrentEnd != null) {
          parts.add('usually until about ${fmt.dayMonth(f.expectedCurrentEnd!)}');
        }
        if (f.expectedStart != null) {
          parts.add('next start around ${fmt.dayMonth(f.expectedStart!)}');
        }
        return parts.isEmpty ? null : _capitalize(parts.join(' · '));
      case CycleStatus.beforeWindow:
        return 'Around ${fmt.dayMonth(f.expectedStart!)} · likely ${window()} · cycle day ${f.cycleDay}';
      case CycleStatus.inWindow:
        return 'Likely ${window()} · cycle day ${f.cycleDay}';
      case CycleStatus.afterWindow:
        return 'Estimated around ${fmt.dayMonth(f.expectedStart!)} (${window()}) · cycle day ${f.cycleDay}';
    }
  }

  @override
  List<String> cycleExplanation(CycleForecast f, Fmt fmt) {
    final out = <String>[];
    if (!f.predictionsEnabled) {
      out.add(
        'Estimates are switched off (diary mode). Your entries are still '
        'saved and shown. You can switch estimates on in the settings.',
      );
      return out;
    }
    out.add(
      'MorphHealth only uses your own entries up to ${fmt.medium(f.on)}. It '
      'looks at the number of days between the first days of your recorded '
      'periods (the cycle length).',
    );
    if (f.status == CycleStatus.noData) {
      out.add('There are no recorded periods up to this day yet.');
      out.add(disclaimer);
      return out;
    }
    if (f.cycles.isEmpty) {
      out.add(
        f.periodsConsidered == 1
            ? 'So far one period is recorded (from ${fmt.medium(f.lastPeriodStart!)}). '
                  'As soon as the next period start is recorded, the first cycle '
                  'length is known and a personal estimate becomes possible.'
            : 'There are ${f.periodsConsidered} recorded periods, but no usable '
                  'cycle length yet.',
      );
      _excluded(f, fmt, out);
      out.add(disclaimer);
      return out;
    }
    final lengths = f.cycles.map((c) => c.length).join(', ');
    final n = f.cycles.length;
    out.add(
      n == 1
          ? 'Used: your most recent cycle (from ${fmt.medium(f.cycles.first.start)}), '
                'which lasted $lengths days.'
          : 'Used: your last $n cycles (starting ${fmt.medium(f.cycles.first.start)} '
                'to ${fmt.medium(f.cycles.last.start)}) with lengths of $lengths days.',
    );
    if (n > 1) {
      out.add(
        'The median is ${f.medianCycleLength} days (average '
        '${fmt.number(f.meanCycleLength!, 1)}). Your cycles vary by a standard '
        'deviation of ${fmt.number(f.sdCycleLength!, 1)} days, so the window is '
        '± ${f.windowHalfWidth} days.',
      );
    } else {
      out.add(
        'With only one cycle the variation is unknown, so the window is '
        '± ${f.windowHalfWidth} days.',
      );
    }
    out.add(
      'Your last period started on ${fmt.medium(f.lastPeriodStart!)}. Adding '
      '${f.medianCycleLength} days gives ${fmt.medium(f.expectedStart!)} as the '
      'estimated start; it is likely between ${fmt.medium(f.windowStart!)} and '
      '${fmt.medium(f.windowEnd!)}.',
    );
    if (f.medianPeriodLength != null) {
      final k = f.periodLengths.length;
      final days = '${f.medianPeriodLength} ${f.medianPeriodLength == 1 ? 'day' : 'days'}';
      out.add(
        k == 1
            ? 'Your last finished period lasted $days.'
            : 'Your last $k finished periods lasted a median of $days.',
      );
    }
    _excluded(f, fmt, out);
    out.add(
      'Reliability: ${confidenceName(f.confidence!)} – ${switch (f.confidence!) {
        ForecastConfidence.high => 'based on several cycles with little variation.',
        ForecastConfidence.medium => 'your cycles vary somewhat.',
        ForecastConfidence.low => n == 1 ? 'based on a single cycle.' : 'your cycles vary a lot or there are only few of them.',
      }}',
    );
    out.add(disclaimer);
    return out;
  }

  void _excluded(CycleForecast f, Fmt fmt, List<String> out) {
    for (final e in f.excluded) {
      final why = e.reason == ExclusionReason.tooLong
          ? 'unusually long – perhaps a period was not recorded'
          : 'unusually short – perhaps spotting or one period was recorded as two';
      out.add(
        'Not used: a cycle of ${e.sample.length} days (from '
        '${fmt.medium(e.sample.start)}), because it is $why.',
      );
    }
  }

  static String _capitalize(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

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
    if (isToday) parts.add('today');
    if (inPeriod) parts.add('period');
    if (flow != null) parts.add(flowName(flow).toLowerCase());
    if (predicted) parts.add('estimated period');
    if (inWindow) parts.add('likely start of next period');
    if (symptoms > 0) parts.add(symptomsCount(symptoms));
    if (hasNote) parts.add('note');
    return parts.join(', ');
  }

  // ---- Weight ------------------------------------------------------------
  @override
  String get addWeight => 'Add weight';
  @override
  String get editWeight => 'Edit weight';
  @override
  String get weight => 'Weight';
  @override
  String get weightUnit => 'Weight unit';
  @override
  String get deleteWeightQuestion => 'Delete this weight entry?';
  @override
  String changeSince(String change, String date) => '$change since $date';
  @override
  String get range7 => '7 days';
  @override
  String get range28 => '28 days';
  @override
  String get range90 => '90 days';
  @override
  String get range365 => '1 year';
  @override
  String get rangeAll => 'All';
  @override
  String get weightEntries => 'Entries';
  @override
  String weightOutOfRange(String min, String max) =>
      'Please enter a weight between $min and $max';

  // ---- Symptoms ----------------------------------------------------------
  @override
  String get addSymptom => 'Add symptom';
  @override
  String get editSymptom => 'Edit symptom';
  @override
  String get symptomName => 'Symptom';
  @override
  String get intensity => 'Intensity';
  @override
  String intensityValue(int i) => '$i of 10';
  @override
  String intensityWord(int i) {
    if (i == 0) return 'none';
    if (i <= 3) return 'mild';
    if (i <= 6) return 'moderate';
    if (i <= 9) return 'strong';
    return 'very strong';
  }

  @override
  String get deleteSymptomQuestion => 'Delete this symptom entry?';
  @override
  String get noSymptomsYet => 'No symptoms recorded yet.';
  @override
  String get symptomEntriesTab => 'Entries';
  @override
  String get symptomTrendTab => 'Trend';
  @override
  String get chooseSymptom => 'Symptom';
  @override
  String occurrences(int n) => n == 1 ? '1 entry' : '$n entries';
  @override
  String get averageIntensity => 'Average intensity';
  @override
  String get maxIntensity => 'Highest intensity';
  @override
  List<String> get symptomSuggestions => const [
    'Headache',
    'Cramps',
    'Bloating',
    'Tiredness',
    'Nausea',
    'Back pain',
    'Mood swings',
    'Breast tenderness',
    'Skin blemishes',
    'Cravings',
    'Trouble sleeping',
    'Joint pain',
  ];

  // ---- History -----------------------------------------------------------
  @override
  String get historySearchHint => 'Search entries';
  @override
  String get allAreas => 'All areas';
  @override
  String get dateRange => 'Period of time';
  @override
  String get anyDate => 'Any date';
  @override
  String historyResults(int n) => n == 1 ? '1 entry' : '$n entries';
  @override
  String get noHistoryResults => 'No matching entries.';
  @override
  String get kindFood => 'Food';
  @override
  String get kindWater => 'Water';
  @override
  String get kindCaffeine => 'Caffeine';
  @override
  String get kindPeriod => 'Period';
  @override
  String get kindCycleDay => 'Cycle day';
  @override
  String get kindWeight => 'Weight';
  @override
  String get kindSymptom => 'Symptom';

  // ---- Day detail --------------------------------------------------------
  @override
  String get nothingLoggedOnDay => 'Nothing has been recorded for this day.';
  @override
  String get cycleOnDay => 'Cycle';
  @override
  String get notInPeriod => 'No period recorded on this day';

  // ---- Settings ----------------------------------------------------------
  @override
  String get languageLabel => 'Language';
  @override
  String get languageName => 'English';
  @override
  String get units => 'Units';
  @override
  String get dailyGoals => 'Daily goals';
  @override
  String get goalsHint =>
      'Goals are optional and entirely up to you. Leave a field empty for no goal.';
  @override
  String get goalEnergy => 'Calories (kcal)';
  @override
  String get goalProtein => 'Protein (g)';
  @override
  String get goalCarbs => 'Carbohydrates (g)';
  @override
  String get goalFat => 'Fat (g)';
  @override
  String get goalWater => 'Water (ml)';
  @override
  String get overviewAreas => 'Areas on the overview';
  @override
  String get quickAmounts => 'Quick entry';
  @override
  String get waterQuickAmounts => 'Water buttons (ml)';
  @override
  String get caffeineQuickAmounts => 'Caffeine buttons (mg)';
  @override
  String get quickAmountsHint => 'Up to 6 values, separated by commas or spaces';
  @override
  String get cycleSettings => 'Cycle';
  @override
  String get predictionsSwitch => 'Show personal estimates';
  @override
  String get predictionsHint =>
      'When switched off, the cycle tracker works as a pure diary.';
  @override
  String get onlineSection => 'Online food search';
  @override
  String get onlineSwitch => 'Allow online food search';
  @override
  String get onlineHint =>
      'Only search terms and barcodes are sent to the food database. '
      'Your diary never leaves the device.';
  @override
  String get serverOrigin => 'Food database server';
  @override
  String get serverOriginHint => 'HTTPS address of an Open Food Facts compatible server';
  @override
  String get serverOriginInvalid => 'Please enter an address starting with https://';
  @override
  String get resetToDefault => 'Reset to default';
  @override
  String get dataSection => 'Data & backup';
  @override
  String get exportData => 'Export data (JSON)';
  @override
  String get exportDataHint => 'Complete, machine-readable, unencrypted';
  @override
  String get exportWarningTitle => 'Unencrypted export';
  @override
  String get exportWarning =>
      'The export file contains all your health data in readable form. Store '
      'it carefully and only share it with people you trust.';
  @override
  String get exportAck => 'I understand';
  @override
  String get exportDone => 'Export saved';
  @override
  String get importData => 'Import data (JSON)';
  @override
  String get importDataHint => 'Replaces all data on this device';
  @override
  String get importConfirm =>
      'Importing replaces ALL data currently on this device with the content '
      'of the file.';
  @override
  String importDone(int entries) =>
      'Import complete: $entries diary entries.';
  @override
  String importFailed(String reason) => 'Import failed: $reason';
  @override
  String get createBackup => 'Create encrypted backup';
  @override
  String get createBackupHint => 'Protected by a passphrase, for a new device';
  @override
  String get passphrase => 'Passphrase';
  @override
  String get passphraseRepeat => 'Repeat passphrase';
  @override
  String get passphraseHint =>
      'At least 10 characters. Without the passphrase the backup cannot be '
      'restored – nobody can recover it.';
  @override
  String get passphraseTooShort => 'At least 10 characters, please';
  @override
  String get passphraseMismatch => 'The passphrases do not match';
  @override
  String get backupWorking => 'Encrypting …';
  @override
  String get backupDone => 'Backup saved';
  @override
  String get restoreBackup => 'Restore backup';
  @override
  String get restoreBackupHint => 'Replaces all data on this device';
  @override
  String get restoreConfirm =>
      'Restoring replaces ALL data currently on this device with the backup.';
  @override
  String get restoreWrongPassphrase =>
      'Wrong passphrase, or the file is damaged.';
  @override
  String get restoreInvalidFile => 'This is not a MorphHealth backup file.';
  @override
  String restoreDone(int entries) =>
      'Backup restored: $entries diary entries.';
  @override
  String get deleteAllData => 'Delete all data';
  @override
  String get deleteAllDataHint => 'Removes every entry and setting from this device';
  @override
  String get deleteAllConfirm =>
      'All diary entries, foods and settings will be deleted from this device '
      'and the encryption key will be destroyed.';
  @override
  String get deleteAllTypeWord => 'To confirm, type DELETE:';
  @override
  String get deleteAllWord => 'DELETE';
  @override
  String get deleteAllDone => 'All data deleted';
  @override
  String get about => 'About MorphHealth';
  @override
  String get version => 'Version';
  @override
  String get privacyTitle => 'Privacy';
  @override
  String get privacyText =>
      'MorphHealth works without an account, advertising, analytics or AI '
      'services. Your entries are stored only on this device, encrypted with '
      'a key protected by the Android Keystore. Only the online food search '
      'contacts the internet, and only with your search terms or barcodes.';
  @override
  String get licenses => 'Open-source licences';
  @override
  String get storageInfo => 'Stored on this device';
  @override
  String dataCounts(int diaryEntries, int foods) =>
      '$diaryEntries diary entries · $foods foods';
  @override
  String get cancelled => 'Cancelled';
  @override
  String get fileSaveFailed => 'The file could not be saved.';
  @override
  String get fileOpenFailed => 'The file could not be read.';
  @override
  String get storeErrorTitle => 'Your data could not be opened';
  @override
  String storeErrorText(String code) => switch (code) {
    'store_wrong_key' =>
      'The encryption key does not match the stored data. This can happen '
          'after restoring the app from a device backup.',
    'store_corrupted' => 'The stored data is damaged.',
    'store_unsupported' =>
      'The data was created by a newer version of MorphHealth.',
    _ => 'The storage could not be accessed ($code).',
  };
  @override
  String get resetStore => 'Start over with empty data';
  @override
  String get showPassphrase => 'Show passphrase';
  @override
  String get hidePassphrase => 'Hide passphrase';
  @override
  String get userAgent => 'User agent';
  @override
  String get noGoal => 'No goal';
  @override
  String get medicalNoteTitle => 'Note';
}
