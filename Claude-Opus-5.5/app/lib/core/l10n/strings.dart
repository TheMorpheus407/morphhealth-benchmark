import '../cycle/forecast.dart';
import '../model/enums.dart';
import 'format.dart';
import 'strings_de.dart';
import 'strings_en.dart';

/// All user-facing texts of MorphHealth. German is the default language;
/// every text must exist in both languages (enforced by the compiler).
abstract class S {
  const S();

  static S of(AppLanguage language) =>
      language == AppLanguage.de ? const SDe() : const SEn();

  AppLanguage get language;

  // ---- General -----------------------------------------------------------
  String get appName => 'MorphHealth';
  String get ok;
  String get cancel;
  String get save;
  String get delete;
  String get edit;
  String get add;
  String get close;
  String get done;
  String get retry;
  String get undo;
  String get next;
  String get back;
  String get search;
  String get clear;
  String get today;
  String get yesterday;
  String get tomorrow;
  String get date;
  String get time;
  String get note;
  String get noteOptional;
  String get optional;
  String get none;
  String get more;
  String get saved;
  String get deleted;
  String get entryDeleted;
  String get fieldRequired;
  String get invalidNumber;
  String numberRange(String min, String max);
  String get previousDay;
  String get nextDay;
  String get previousMonth;
  String get nextMonth;
  String get chooseDate;
  String get chooseTime;
  String get loading;
  String get errorGeneric;
  String get favorite;
  String get addFavorite;
  String get removeFavorite;
  String get deleteConfirmTitle;
  String get cannotUndo;

  // ---- Navigation / areas ------------------------------------------------
  String get navOverview;
  String get navNutrition;
  String get navCycle;
  String get navWeight;
  String get navSymptoms;
  String get historyTitle;
  String get settingsTitle;
  String get dayDetailTitle;
  String areaName(Area area);
  String mealName(Meal meal);
  String flowName(Flow flow);
  String unitName(AmountUnit unit, {bool plural = false});
  String nutrientName(String key);
  String get groupEnergyMacros;
  String get groupDetails;
  String get groupVitamins;
  String get groupMinerals;

  // ---- Onboarding ---------------------------------------------------------
  String get welcomeTitle;
  String get welcomeText;
  String get onboardingLanguage;
  String get onboardingAreas;
  String get onboardingAreasHint;
  String get onboardingOnline;
  String get onboardingOnlineHint;
  String get onboardingPrivacy;
  String get getStarted;

  // ---- Overview ----------------------------------------------------------
  String get customizeOverview;
  String get customizeOverviewHint;
  String get noAreasVisible;
  String get openDayDetail;
  String get nutritionToday;
  String kcalOfGoal(String value, String goal);
  String get noFoodLogged;
  String get latestWeight;
  String get noWeightYet;
  String get noSymptomsOnDay;
  String symptomsCount(int n);

  // ---- Nutrition diary ---------------------------------------------------
  String get addFood;
  String addFoodTo(Meal meal);
  String get dayTotal;
  String get goal;
  String valueOfGoal(String value, String goal);
  String get water;
  String get waterAddCustom;
  String get waterAmountMl;
  String waterAdded(String amount);
  String get caffeine;
  String get caffeineAdditional;
  String get caffeineFromFoods;
  String get caffeineTotal;
  String get caffeineAddCustom;
  String get caffeineAmountMg;
  String get caffeineLabelOptional;
  String caffeineAdded(String amount);
  String get allNutrients;
  String coverage(int known, int total);
  String get includesEstimates;
  String get estimated;
  String get nothingLoggedMeal;
  String get logAgain;
  String loggedAgain(String date);
  String get logAgainTitle;
  String get editEntry;
  String get entryNutrients;
  String get dayTab;
  String get trendTab;
  String get trendMetric;
  String days(int n);
  String get average;
  String get averageHint;
  String daysWithData(int n, int total);
  String get minimum;
  String get maximum;
  String get noDataInRange;
  String get showTable;
  String get showChart;
  String get waterMetric;
  String get caffeineTotalMetric;

  // ---- Food search & library ---------------------------------------------
  String get foodSearchHint;
  String get tabSearch;
  String get tabFavorites;
  String get tabRecent;
  String get tabMyFoods;
  String get searchOnline;
  String get loadMore;
  String get noResults;
  String get noFavorites;
  String get noRecent;
  String get noCustomFoods;
  String get localResults;
  String get onlineResults;
  String get onlineDisabled;
  String get searching;
  String get barcodeNotFound;
  String get barcodeCheckDigitWarning;
  String lookupBarcode(String code);
  String get createCustomFood;
  String get offAttribution;
  String perHundred(Basis basis);
  String get perPortion;
  String get noNutritionData;
  String get foodDetails;
  String get customFood;
  String get onlineFood;
  String resultCount(int n);
  String foodApiError(String code);
  String get amount;
  String get unit;
  String get meal;
  String get addToDiary;
  String get nutrientsForAmount;
  String get assumedDensity;
  String portionDescription(String? label, String size, Basis basis);
  String addedToDiary(String name);

  // ---- Custom food editor ------------------------------------------------
  String get newCustomFood;
  String get editCustomFood;
  String get foodName;
  String get brandOptional;
  String get barcodeOptional;
  String get barcodeDigitsOnly;
  String get basisLabel;
  String get servingSizeOptional;
  String get servingLabelOptional;
  String get densityOptional;
  String nutrientsPerHundred(Basis basis);
  String get saltSodiumHint;
  String updateEntriesQuestion(int n);
  String get updateEntriesYes;
  String get updateEntriesNo;
  String get deleteFoodQuestion;
  String get foodDeleted;
  String valueTooLarge(String max);
  String get portionNeedsServing;

  // ---- Cycle -------------------------------------------------------------
  String get periodStartToday;
  String get periodEndToday;
  String get addPastPeriod;
  String get editPeriod;
  String get newPeriod;
  String get periodStart;
  String get periodEnd;
  String get periodOngoing;
  String get periodStillOngoing;
  String get deletePeriodQuestion;
  String get periodOverlap;
  String get periodEndBeforeStart;
  String periodTooLong(int max);
  String get periodStartInFuture;
  String get onlyLatestOngoing;
  String get flow;
  String get noFlow;
  String get legendPeriod;
  String get legendPredicted;
  String get legendWindow;
  String get legendSpotting;
  String get legendSymptoms;
  String get legendToday;
  String get calendar;
  String get periodHistory;
  String get noPeriodsYet;
  String cycleLengthDays(int n);
  String periodLengthDays(int n);
  String get averageCycle;
  String get averagePeriod;
  String get cycleLengthsChart;
  String get startPeriodHere;
  String get endPeriodHere;
  String get symptomsOfDay;
  String get cycleDayNote;
  String dayInPeriod(int day);
  String periodStarted(String date);
  String periodEnded(String date);
  String get whyThisEstimate;
  String get explanationTitle;
  String get disclaimer;
  String confidenceName(ForecastConfidence c);
  String get predictionsOff;
  String longOngoingPeriodHint(int days);
  String get enterLastDay;
  String get flowOutsidePeriodQuestion;
  String get startPeriodOnDay;
  String extendPeriodToDay(String date);
  String get onlySaveBleeding;
  String get saveNote;
  String get cycleStats;
  String cyclesRecorded(int n);

  /// One-line status for cards and the cycle screen header.
  String cycleHeadline(CycleForecast f, Fmt fmt);

  /// A secondary line (e.g. expected date and window).
  String? cycleSubline(CycleForecast f, Fmt fmt);

  /// Paragraphs explaining how the estimate was derived.
  List<String> cycleExplanation(CycleForecast f, Fmt fmt);

  /// Semantic label of a calendar day.
  String calendarDayLabel({
    required String date,
    required bool isToday,
    required bool inPeriod,
    Flow? flow,
    required bool predicted,
    required bool inWindow,
    required int symptoms,
    required bool hasNote,
  });

  // ---- Weight ------------------------------------------------------------
  String get addWeight;
  String get editWeight;
  String get weight;
  String get weightUnit;
  String get deleteWeightQuestion;
  String changeSince(String change, String date);
  String get range7;
  String get range28;
  String get range90;
  String get range365;
  String get rangeAll;
  String get weightEntries;
  String weightOutOfRange(String min, String max);

  // ---- Symptoms ----------------------------------------------------------
  String get addSymptom;
  String get editSymptom;
  String get symptomName;
  String get intensity;
  String intensityValue(int i);
  String intensityWord(int i);
  String get deleteSymptomQuestion;
  String get noSymptomsYet;
  String get symptomEntriesTab;
  String get symptomTrendTab;
  String get chooseSymptom;
  String occurrences(int n);
  String get averageIntensity;
  String get maxIntensity;
  List<String> get symptomSuggestions;

  // ---- History -----------------------------------------------------------
  String get historySearchHint;
  String get allAreas;
  String get dateRange;
  String get anyDate;
  String historyResults(int n);
  String get noHistoryResults;
  String get kindFood;
  String get kindWater;
  String get kindCaffeine;
  String get kindPeriod;
  String get kindCycleDay;
  String get kindWeight;
  String get kindSymptom;

  // ---- Day detail --------------------------------------------------------
  String get nothingLoggedOnDay;
  String get cycleOnDay;
  String get notInPeriod;

  // ---- Settings ----------------------------------------------------------
  String get languageLabel;
  String get languageName;
  String get units;
  String get dailyGoals;
  String get goalsHint;
  String get goalEnergy;
  String get goalProtein;
  String get goalCarbs;
  String get goalFat;
  String get goalWater;
  String get overviewAreas;
  String get quickAmounts;
  String get waterQuickAmounts;
  String get caffeineQuickAmounts;
  String get quickAmountsHint;
  String get cycleSettings;
  String get predictionsSwitch;
  String get predictionsHint;
  String get onlineSection;
  String get onlineSwitch;
  String get onlineHint;
  String get serverOrigin;
  String get serverOriginHint;
  String get serverOriginInvalid;
  String get resetToDefault;
  String get dataSection;
  String get exportData;
  String get exportDataHint;
  String get exportWarningTitle;
  String get exportWarning;
  String get exportAck;
  String get exportDone;
  String get importData;
  String get importDataHint;
  String get importConfirm;
  String importDone(int entries);
  String importFailed(String reason);
  String get createBackup;
  String get createBackupHint;
  String get passphrase;
  String get passphraseRepeat;
  String get passphraseHint;
  String get passphraseTooShort;
  String get passphraseMismatch;
  String get backupWorking;
  String get backupDone;
  String get restoreBackup;
  String get restoreBackupHint;
  String get restoreConfirm;
  String get restoreWrongPassphrase;
  String get restoreInvalidFile;
  String restoreDone(int entries);
  String get deleteAllData;
  String get deleteAllDataHint;
  String get deleteAllConfirm;
  String get deleteAllTypeWord;
  String get deleteAllWord;
  String get deleteAllDone;
  String get about;
  String get version;
  String get privacyTitle;
  String get privacyText;
  String get licenses;
  String get storageInfo;
  String dataCounts(int diaryEntries, int foods);
  String get cancelled;
  String get fileSaveFailed;
  String get fileOpenFailed;
  String get storeErrorTitle;
  String storeErrorText(String code);
  String get resetStore;
  String get showPassphrase;
  String get hidePassphrase;
  String get userAgent;
  String get noGoal;
  String get medicalNoteTitle;
}
