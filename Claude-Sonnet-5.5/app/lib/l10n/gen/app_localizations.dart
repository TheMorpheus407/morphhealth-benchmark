import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale) : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate = _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates = <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[Locale('de'), Locale('en')];

  /// No description provided for @appName.
  ///
  /// In de, this message translates to:
  /// **'MorphHealth'**
  String get appName;

  /// No description provided for @navOverview.
  ///
  /// In de, this message translates to:
  /// **'Übersicht'**
  String get navOverview;

  /// No description provided for @navNutrition.
  ///
  /// In de, this message translates to:
  /// **'Ernährung'**
  String get navNutrition;

  /// No description provided for @navCycle.
  ///
  /// In de, this message translates to:
  /// **'Zyklus'**
  String get navCycle;

  /// No description provided for @navWeight.
  ///
  /// In de, this message translates to:
  /// **'Gewicht'**
  String get navWeight;

  /// No description provided for @navSymptoms.
  ///
  /// In de, this message translates to:
  /// **'Symptome'**
  String get navSymptoms;

  /// No description provided for @commonSave.
  ///
  /// In de, this message translates to:
  /// **'Speichern'**
  String get commonSave;

  /// No description provided for @commonCancel.
  ///
  /// In de, this message translates to:
  /// **'Abbrechen'**
  String get commonCancel;

  /// No description provided for @commonDelete.
  ///
  /// In de, this message translates to:
  /// **'Löschen'**
  String get commonDelete;

  /// No description provided for @commonClose.
  ///
  /// In de, this message translates to:
  /// **'Schließen'**
  String get commonClose;

  /// No description provided for @commonRetry.
  ///
  /// In de, this message translates to:
  /// **'Erneut versuchen'**
  String get commonRetry;

  /// No description provided for @commonToday.
  ///
  /// In de, this message translates to:
  /// **'Heute'**
  String get commonToday;

  /// No description provided for @bootFailedTitle.
  ///
  /// In de, this message translates to:
  /// **'Der Datenbestand lässt sich nicht öffnen'**
  String get bootFailedTitle;

  /// No description provided for @bootLoading.
  ///
  /// In de, this message translates to:
  /// **'MorphHealth wird geöffnet'**
  String get bootLoading;

  /// No description provided for @commonOk.
  ///
  /// In de, this message translates to:
  /// **'OK'**
  String get commonOk;

  /// No description provided for @commonEdit.
  ///
  /// In de, this message translates to:
  /// **'Bearbeiten'**
  String get commonEdit;

  /// No description provided for @commonAdd.
  ///
  /// In de, this message translates to:
  /// **'Hinzufügen'**
  String get commonAdd;

  /// No description provided for @commonBack.
  ///
  /// In de, this message translates to:
  /// **'Zurück'**
  String get commonBack;

  /// No description provided for @commonDone.
  ///
  /// In de, this message translates to:
  /// **'Fertig'**
  String get commonDone;

  /// No description provided for @commonUndo.
  ///
  /// In de, this message translates to:
  /// **'Rückgängig'**
  String get commonUndo;

  /// No description provided for @commonMore.
  ///
  /// In de, this message translates to:
  /// **'Mehr'**
  String get commonMore;

  /// No description provided for @commonDate.
  ///
  /// In de, this message translates to:
  /// **'Datum'**
  String get commonDate;

  /// No description provided for @commonTime.
  ///
  /// In de, this message translates to:
  /// **'Uhrzeit'**
  String get commonTime;

  /// No description provided for @commonNote.
  ///
  /// In de, this message translates to:
  /// **'Notiz'**
  String get commonNote;

  /// No description provided for @commonNoteOptional.
  ///
  /// In de, this message translates to:
  /// **'Notiz (optional)'**
  String get commonNoteOptional;

  /// No description provided for @commonRequired.
  ///
  /// In de, this message translates to:
  /// **'Bitte ausfüllen'**
  String get commonRequired;

  /// No description provided for @commonInvalidNumber.
  ///
  /// In de, this message translates to:
  /// **'Bitte eine gültige Zahl eingeben'**
  String get commonInvalidNumber;

  /// No description provided for @commonMustBePositive.
  ///
  /// In de, this message translates to:
  /// **'Der Wert muss größer als 0 sein'**
  String get commonMustBePositive;

  /// No description provided for @commonNone.
  ///
  /// In de, this message translates to:
  /// **'keine'**
  String get commonNone;

  /// No description provided for @commonAll.
  ///
  /// In de, this message translates to:
  /// **'Alle'**
  String get commonAll;

  /// No description provided for @commonShow.
  ///
  /// In de, this message translates to:
  /// **'Anzeigen'**
  String get commonShow;

  /// No description provided for @commonHide.
  ///
  /// In de, this message translates to:
  /// **'Ausblenden'**
  String get commonHide;

  /// No description provided for @dayPrevious.
  ///
  /// In de, this message translates to:
  /// **'Vorheriger Tag'**
  String get dayPrevious;

  /// No description provided for @dayNext.
  ///
  /// In de, this message translates to:
  /// **'Nächster Tag'**
  String get dayNext;

  /// No description provided for @dayPick.
  ///
  /// In de, this message translates to:
  /// **'Datum wählen'**
  String get dayPick;

  /// No description provided for @commonDeletedItem.
  ///
  /// In de, this message translates to:
  /// **'{what} gelöscht'**
  String commonDeletedItem(String what);

  /// No description provided for @commonSaved.
  ///
  /// In de, this message translates to:
  /// **'Gespeichert'**
  String get commonSaved;

  /// No description provided for @commonError.
  ///
  /// In de, this message translates to:
  /// **'Das hat nicht geklappt: {message}'**
  String commonError(String message);

  /// No description provided for @unitG.
  ///
  /// In de, this message translates to:
  /// **'g'**
  String get unitG;

  /// No description provided for @unitMl.
  ///
  /// In de, this message translates to:
  /// **'ml'**
  String get unitMl;

  /// No description provided for @unitPortion.
  ///
  /// In de, this message translates to:
  /// **'Portion'**
  String get unitPortion;

  /// No description provided for @unitKg.
  ///
  /// In de, this message translates to:
  /// **'kg'**
  String get unitKg;

  /// No description provided for @unitLb.
  ///
  /// In de, this message translates to:
  /// **'lb'**
  String get unitLb;

  /// No description provided for @mealBreakfast.
  ///
  /// In de, this message translates to:
  /// **'Frühstück'**
  String get mealBreakfast;

  /// No description provided for @mealLunch.
  ///
  /// In de, this message translates to:
  /// **'Mittagessen'**
  String get mealLunch;

  /// No description provided for @mealDinner.
  ///
  /// In de, this message translates to:
  /// **'Abendessen'**
  String get mealDinner;

  /// No description provided for @mealSnack.
  ///
  /// In de, this message translates to:
  /// **'Snack'**
  String get mealSnack;

  /// No description provided for @flowSpotting.
  ///
  /// In de, this message translates to:
  /// **'Spotting'**
  String get flowSpotting;

  /// No description provided for @flowLight.
  ///
  /// In de, this message translates to:
  /// **'Leicht'**
  String get flowLight;

  /// No description provided for @flowMedium.
  ///
  /// In de, this message translates to:
  /// **'Mittel'**
  String get flowMedium;

  /// No description provided for @flowHeavy.
  ///
  /// In de, this message translates to:
  /// **'Stark'**
  String get flowHeavy;

  /// No description provided for @flowNone.
  ///
  /// In de, this message translates to:
  /// **'Keine Angabe'**
  String get flowNone;

  /// No description provided for @nutritionTabDiary.
  ///
  /// In de, this message translates to:
  /// **'Tagebuch'**
  String get nutritionTabDiary;

  /// No description provided for @nutritionTabTrends.
  ///
  /// In de, this message translates to:
  /// **'Verlauf'**
  String get nutritionTabTrends;

  /// No description provided for @nutritionAddFood.
  ///
  /// In de, this message translates to:
  /// **'Lebensmittel hinzufügen'**
  String get nutritionAddFood;

  /// No description provided for @nutritionDaySummary.
  ///
  /// In de, this message translates to:
  /// **'Tagessumme'**
  String get nutritionDaySummary;

  /// No description provided for @nutritionKcalOfGoal.
  ///
  /// In de, this message translates to:
  /// **'{value} von {goal} kcal'**
  String nutritionKcalOfGoal(String value, String goal);

  /// No description provided for @nutritionKcalPlain.
  ///
  /// In de, this message translates to:
  /// **'{value} kcal'**
  String nutritionKcalPlain(String value);

  /// No description provided for @nutritionKcalLeft.
  ///
  /// In de, this message translates to:
  /// **'{value} kcal bis zum Ziel'**
  String nutritionKcalLeft(String value);

  /// No description provided for @nutritionKcalOver.
  ///
  /// In de, this message translates to:
  /// **'{value} kcal über dem Ziel'**
  String nutritionKcalOver(String value);

  /// No description provided for @nutritionGoalReached.
  ///
  /// In de, this message translates to:
  /// **'Ziel erreicht'**
  String get nutritionGoalReached;

  /// No description provided for @nutritionAllNutrients.
  ///
  /// In de, this message translates to:
  /// **'Alle Nährwerte'**
  String get nutritionAllNutrients;

  /// No description provided for @nutritionMealEmpty.
  ///
  /// In de, this message translates to:
  /// **'Noch nichts erfasst'**
  String get nutritionMealEmpty;

  /// No description provided for @nutritionAddToMeal.
  ///
  /// In de, this message translates to:
  /// **'Zu {meal} hinzufügen'**
  String nutritionAddToMeal(String meal);

  /// No description provided for @nutritionEntryRelog.
  ///
  /// In de, this message translates to:
  /// **'Erneut erfassen'**
  String get nutritionEntryRelog;

  /// No description provided for @nutritionRelogged.
  ///
  /// In de, this message translates to:
  /// **'„{name}“ erneut erfasst'**
  String nutritionRelogged(String name);

  /// No description provided for @nutritionEntryDeleted.
  ///
  /// In de, this message translates to:
  /// **'Eintrag gelöscht'**
  String get nutritionEntryDeleted;

  /// No description provided for @nutritionDayEmpty.
  ///
  /// In de, this message translates to:
  /// **'An diesem Tag ist noch nichts erfasst.'**
  String get nutritionDayEmpty;

  /// No description provided for @nutritionEntrySubtitle.
  ///
  /// In de, this message translates to:
  /// **'{amount} · {kcal}'**
  String nutritionEntrySubtitle(String amount, String kcal);

  /// No description provided for @nutritionNoKcal.
  ///
  /// In de, this message translates to:
  /// **'keine kcal-Angabe'**
  String get nutritionNoKcal;

  /// No description provided for @nutritionNoData.
  ///
  /// In de, this message translates to:
  /// **'keine Angabe'**
  String get nutritionNoData;

  /// No description provided for @nutritionCoverage.
  ///
  /// In de, this message translates to:
  /// **'nur bei {count} von {total} Einträgen angegeben'**
  String nutritionCoverage(String count, String total);

  /// No description provided for @nutritionShowDetails.
  ///
  /// In de, this message translates to:
  /// **'Details anzeigen'**
  String get nutritionShowDetails;

  /// No description provided for @waterTitle.
  ///
  /// In de, this message translates to:
  /// **'Wasser'**
  String get waterTitle;

  /// No description provided for @waterOfGoal.
  ///
  /// In de, this message translates to:
  /// **'{value} von {goal} ml'**
  String waterOfGoal(String value, String goal);

  /// No description provided for @waterPlain.
  ///
  /// In de, this message translates to:
  /// **'{value} ml'**
  String waterPlain(String value);

  /// No description provided for @waterQuickAdd.
  ///
  /// In de, this message translates to:
  /// **'{amount} ml Wasser hinzufügen'**
  String waterQuickAdd(String amount);

  /// No description provided for @waterAdded.
  ///
  /// In de, this message translates to:
  /// **'{amount} ml Wasser erfasst'**
  String waterAdded(String amount);

  /// No description provided for @waterOther.
  ///
  /// In de, this message translates to:
  /// **'Andere Menge'**
  String get waterOther;

  /// No description provided for @waterLogTitle.
  ///
  /// In de, this message translates to:
  /// **'Wasser erfassen'**
  String get waterLogTitle;

  /// No description provided for @waterEditTitle.
  ///
  /// In de, this message translates to:
  /// **'Wassereintrag bearbeiten'**
  String get waterEditTitle;

  /// No description provided for @waterAmountLabel.
  ///
  /// In de, this message translates to:
  /// **'Menge in ml'**
  String get waterAmountLabel;

  /// No description provided for @waterEntryTitle.
  ///
  /// In de, this message translates to:
  /// **'{amount} ml Wasser'**
  String waterEntryTitle(String amount);

  /// No description provided for @waterEntriesToday.
  ///
  /// In de, this message translates to:
  /// **'Einträge dieses Tages'**
  String get waterEntriesToday;

  /// No description provided for @caffeineTitle.
  ///
  /// In de, this message translates to:
  /// **'Koffein'**
  String get caffeineTitle;

  /// No description provided for @caffeineTotal.
  ///
  /// In de, this message translates to:
  /// **'{value} mg gesamt'**
  String caffeineTotal(String value);

  /// No description provided for @caffeineFromFoods.
  ///
  /// In de, this message translates to:
  /// **'{value} mg aus Lebensmitteln'**
  String caffeineFromFoods(String value);

  /// No description provided for @caffeineAdditional.
  ///
  /// In de, this message translates to:
  /// **'{value} mg zusätzlich erfasst'**
  String caffeineAdditional(String value);

  /// No description provided for @caffeineLogTitle.
  ///
  /// In de, this message translates to:
  /// **'Koffein erfassen'**
  String get caffeineLogTitle;

  /// No description provided for @caffeineEditTitle.
  ///
  /// In de, this message translates to:
  /// **'Koffeineintrag bearbeiten'**
  String get caffeineEditTitle;

  /// No description provided for @caffeineAmountLabel.
  ///
  /// In de, this message translates to:
  /// **'Menge in mg'**
  String get caffeineAmountLabel;

  /// No description provided for @caffeineLabelHint.
  ///
  /// In de, this message translates to:
  /// **'Bezeichnung (optional)'**
  String get caffeineLabelHint;

  /// No description provided for @caffeinePresetNote.
  ///
  /// In de, this message translates to:
  /// **'Richtwerte zum Anpassen'**
  String get caffeinePresetNote;

  /// No description provided for @caffeineCoffee.
  ///
  /// In de, this message translates to:
  /// **'Kaffee'**
  String get caffeineCoffee;

  /// No description provided for @caffeineEspresso.
  ///
  /// In de, this message translates to:
  /// **'Espresso'**
  String get caffeineEspresso;

  /// No description provided for @caffeineTea.
  ///
  /// In de, this message translates to:
  /// **'Schwarztee'**
  String get caffeineTea;

  /// No description provided for @caffeineGreenTea.
  ///
  /// In de, this message translates to:
  /// **'Grüner Tee'**
  String get caffeineGreenTea;

  /// No description provided for @caffeineCola.
  ///
  /// In de, this message translates to:
  /// **'Cola'**
  String get caffeineCola;

  /// No description provided for @caffeineEnergy.
  ///
  /// In de, this message translates to:
  /// **'Energy-Drink'**
  String get caffeineEnergy;

  /// No description provided for @caffeineEntryTitle.
  ///
  /// In de, this message translates to:
  /// **'{mg} mg Koffein'**
  String caffeineEntryTitle(String mg);

  /// No description provided for @caffeineAdded.
  ///
  /// In de, this message translates to:
  /// **'{mg} mg Koffein erfasst'**
  String caffeineAdded(String mg);

  /// No description provided for @pickerSearchHint.
  ///
  /// In de, this message translates to:
  /// **'Lebensmittel suchen'**
  String get pickerSearchHint;

  /// No description provided for @pickerBarcodeHint.
  ///
  /// In de, this message translates to:
  /// **'Barcode-Nummer eingeben'**
  String get pickerBarcodeHint;

  /// No description provided for @pickerModeName.
  ///
  /// In de, this message translates to:
  /// **'Name'**
  String get pickerModeName;

  /// No description provided for @pickerModeBarcode.
  ///
  /// In de, this message translates to:
  /// **'Barcode'**
  String get pickerModeBarcode;

  /// No description provided for @pickerTabSearch.
  ///
  /// In de, this message translates to:
  /// **'Suche'**
  String get pickerTabSearch;

  /// No description provided for @pickerTabRecent.
  ///
  /// In de, this message translates to:
  /// **'Zuletzt'**
  String get pickerTabRecent;

  /// No description provided for @pickerTabFavorites.
  ///
  /// In de, this message translates to:
  /// **'Favoriten'**
  String get pickerTabFavorites;

  /// No description provided for @pickerTabCustom.
  ///
  /// In de, this message translates to:
  /// **'Eigene'**
  String get pickerTabCustom;

  /// No description provided for @pickerSearchButton.
  ///
  /// In de, this message translates to:
  /// **'Suchen'**
  String get pickerSearchButton;

  /// No description provided for @pickerOnlineHint.
  ///
  /// In de, this message translates to:
  /// **'Die Suche nutzt Open Food Facts. Dabei wird nur der Suchbegriff an den Dienst gesendet.'**
  String get pickerOnlineHint;

  /// No description provided for @pickerOnlineDisabled.
  ///
  /// In de, this message translates to:
  /// **'Die Online-Suche ist ausgeschaltet. Du kannst sie in den Einstellungen einschalten.'**
  String get pickerOnlineDisabled;

  /// No description provided for @pickerNoResults.
  ///
  /// In de, this message translates to:
  /// **'Keine Treffer für „{query}“.'**
  String pickerNoResults(String query);

  /// No description provided for @pickerBarcodeNotFound.
  ///
  /// In de, this message translates to:
  /// **'Zu dieser Nummer wurde kein Produkt gefunden.'**
  String get pickerBarcodeNotFound;

  /// No description provided for @pickerBarcodeInvalid.
  ///
  /// In de, this message translates to:
  /// **'Eine Barcode-Nummer hat 8 bis 14 Ziffern.'**
  String get pickerBarcodeInvalid;

  /// No description provided for @pickerLoadMore.
  ///
  /// In de, this message translates to:
  /// **'Mehr laden'**
  String get pickerLoadMore;

  /// No description provided for @pickerResultCount.
  ///
  /// In de, this message translates to:
  /// **'{count} Treffer'**
  String pickerResultCount(String count);

  /// No description provided for @pickerErrorOffline.
  ///
  /// In de, this message translates to:
  /// **'Keine Verbindung zum Lebensmitteldienst. Bitte prüfe die Internetverbindung.'**
  String get pickerErrorOffline;

  /// No description provided for @pickerErrorTimeout.
  ///
  /// In de, this message translates to:
  /// **'Der Lebensmitteldienst antwortet nicht rechtzeitig.'**
  String get pickerErrorTimeout;

  /// No description provided for @pickerErrorTls.
  ///
  /// In de, this message translates to:
  /// **'Die gesicherte Verbindung wurde abgelehnt (Zertifikat).'**
  String get pickerErrorTls;

  /// No description provided for @pickerErrorRate.
  ///
  /// In de, this message translates to:
  /// **'Der Dienst ist gerade überlastet. Bitte später erneut versuchen.'**
  String get pickerErrorRate;

  /// No description provided for @pickerErrorGeneric.
  ///
  /// In de, this message translates to:
  /// **'Die Anfrage ist fehlgeschlagen ({code}).'**
  String pickerErrorGeneric(String code);

  /// No description provided for @pickerCreateCustom.
  ///
  /// In de, this message translates to:
  /// **'Eigenes Lebensmittel anlegen'**
  String get pickerCreateCustom;

  /// No description provided for @pickerNoRecent.
  ///
  /// In de, this message translates to:
  /// **'Noch nichts erfasst. Hier erscheinen zuletzt verwendete Lebensmittel.'**
  String get pickerNoRecent;

  /// No description provided for @pickerNoFavorites.
  ///
  /// In de, this message translates to:
  /// **'Noch keine Favoriten. Tippe in einem Eintrag auf den Stern.'**
  String get pickerNoFavorites;

  /// No description provided for @pickerNoCustom.
  ///
  /// In de, this message translates to:
  /// **'Noch keine eigenen Lebensmittel.'**
  String get pickerNoCustom;

  /// No description provided for @pickerNoLocalMatches.
  ///
  /// In de, this message translates to:
  /// **'Keine passenden Lebensmittel in dieser Liste.'**
  String get pickerNoLocalMatches;

  /// No description provided for @foodPer100.
  ///
  /// In de, this message translates to:
  /// **'je 100 {unit}'**
  String foodPer100(String unit);

  /// No description provided for @foodKcalPer100.
  ///
  /// In de, this message translates to:
  /// **'{kcal} kcal je 100 {unit}'**
  String foodKcalPer100(String kcal, String unit);

  /// No description provided for @foodNoNutrition.
  ///
  /// In de, this message translates to:
  /// **'Keine Nährwerte hinterlegt'**
  String get foodNoNutrition;

  /// No description provided for @foodSourceOff.
  ///
  /// In de, this message translates to:
  /// **'Open Food Facts'**
  String get foodSourceOff;

  /// No description provided for @foodSourceCustom.
  ///
  /// In de, this message translates to:
  /// **'Eigenes Lebensmittel'**
  String get foodSourceCustom;

  /// No description provided for @foodUnnamed.
  ///
  /// In de, this message translates to:
  /// **'Unbenanntes Produkt'**
  String get foodUnnamed;

  /// No description provided for @foodDetailsLoading.
  ///
  /// In de, this message translates to:
  /// **'Produktdetails werden geladen'**
  String get foodDetailsLoading;

  /// No description provided for @foodDetailsFallback.
  ///
  /// In de, this message translates to:
  /// **'Die Details konnten nicht geladen werden. Es gelten die Werte aus der Suche.'**
  String get foodDetailsFallback;

  /// No description provided for @foodFavoriteAdded.
  ///
  /// In de, this message translates to:
  /// **'Zu Favoriten hinzugefügt'**
  String get foodFavoriteAdded;

  /// No description provided for @foodFavoriteRemoved.
  ///
  /// In de, this message translates to:
  /// **'Aus Favoriten entfernt'**
  String get foodFavoriteRemoved;

  /// No description provided for @foodDeleteLibraryTitle.
  ///
  /// In de, this message translates to:
  /// **'Lebensmittel löschen?'**
  String get foodDeleteLibraryTitle;

  /// No description provided for @foodDeleteLibraryMessage.
  ///
  /// In de, this message translates to:
  /// **'„{name}“ wird aus deiner Bibliothek entfernt. Bereits erfasste Einträge bleiben erhalten.'**
  String foodDeleteLibraryMessage(String name);

  /// No description provided for @entryAddTitle.
  ///
  /// In de, this message translates to:
  /// **'Eintrag hinzufügen'**
  String get entryAddTitle;

  /// No description provided for @entryEditTitle.
  ///
  /// In de, this message translates to:
  /// **'Eintrag bearbeiten'**
  String get entryEditTitle;

  /// No description provided for @entryAmount.
  ///
  /// In de, this message translates to:
  /// **'Menge'**
  String get entryAmount;

  /// No description provided for @entryUnit.
  ///
  /// In de, this message translates to:
  /// **'Einheit'**
  String get entryUnit;

  /// No description provided for @entryServingSize.
  ///
  /// In de, this message translates to:
  /// **'Eine Portion entspricht'**
  String get entryServingSize;

  /// No description provided for @entryServingRequired.
  ///
  /// In de, this message translates to:
  /// **'Bitte gib die Größe einer Portion an.'**
  String get entryServingRequired;

  /// No description provided for @entryServingInfo.
  ///
  /// In de, this message translates to:
  /// **'1 Portion = {amount} {unit}'**
  String entryServingInfo(String amount, String unit);

  /// No description provided for @entryPreview.
  ///
  /// In de, this message translates to:
  /// **'Nährwerte für diese Menge'**
  String get entryPreview;

  /// No description provided for @entryMeal.
  ///
  /// In de, this message translates to:
  /// **'Mahlzeit'**
  String get entryMeal;

  /// No description provided for @entryFavoriteAdd.
  ///
  /// In de, this message translates to:
  /// **'Zu Favoriten hinzufügen'**
  String get entryFavoriteAdd;

  /// No description provided for @entryFavoriteRemove.
  ///
  /// In de, this message translates to:
  /// **'Aus Favoriten entfernen'**
  String get entryFavoriteRemove;

  /// No description provided for @entryDelete.
  ///
  /// In de, this message translates to:
  /// **'Eintrag löschen'**
  String get entryDelete;

  /// No description provided for @entryCopyToCustom.
  ///
  /// In de, this message translates to:
  /// **'Als eigenes Lebensmittel kopieren'**
  String get entryCopyToCustom;

  /// No description provided for @entryDataSource.
  ///
  /// In de, this message translates to:
  /// **'Daten: Open Food Facts (ODbL)'**
  String get entryDataSource;

  /// No description provided for @entryPreparedNote.
  ///
  /// In de, this message translates to:
  /// **'Die Werte gelten für das zubereitete Produkt.'**
  String get entryPreparedNote;

  /// No description provided for @entryIncompleteData.
  ///
  /// In de, this message translates to:
  /// **'Für dieses Produkt fehlen Nährwerte.'**
  String get entryIncompleteData;

  /// No description provided for @entryAddedToMeal.
  ///
  /// In de, this message translates to:
  /// **'„{name}“ zu {meal} hinzugefügt'**
  String entryAddedToMeal(String name, String meal);

  /// No description provided for @entryUpdated.
  ///
  /// In de, this message translates to:
  /// **'Eintrag aktualisiert'**
  String get entryUpdated;

  /// No description provided for @customTitleNew.
  ///
  /// In de, this message translates to:
  /// **'Eigenes Lebensmittel'**
  String get customTitleNew;

  /// No description provided for @customTitleEdit.
  ///
  /// In de, this message translates to:
  /// **'Lebensmittel bearbeiten'**
  String get customTitleEdit;

  /// No description provided for @customName.
  ///
  /// In de, this message translates to:
  /// **'Name'**
  String get customName;

  /// No description provided for @customBrand.
  ///
  /// In de, this message translates to:
  /// **'Marke (optional)'**
  String get customBrand;

  /// No description provided for @customBarcode.
  ///
  /// In de, this message translates to:
  /// **'Barcode (optional)'**
  String get customBarcode;

  /// No description provided for @customBasis.
  ///
  /// In de, this message translates to:
  /// **'Die Nährwerte beziehen sich auf'**
  String get customBasis;

  /// No description provided for @customPer100g.
  ///
  /// In de, this message translates to:
  /// **'100 g'**
  String get customPer100g;

  /// No description provided for @customPer100ml.
  ///
  /// In de, this message translates to:
  /// **'100 ml'**
  String get customPer100ml;

  /// No description provided for @customServing.
  ///
  /// In de, this message translates to:
  /// **'Portionsgröße (optional)'**
  String get customServing;

  /// No description provided for @customServingLabel.
  ///
  /// In de, this message translates to:
  /// **'Bezeichnung (optional)'**
  String get customServingLabel;

  /// No description provided for @customSectionMain.
  ///
  /// In de, this message translates to:
  /// **'Hauptnährwerte je 100 {unit}'**
  String customSectionMain(String unit);

  /// No description provided for @customSectionMore.
  ///
  /// In de, this message translates to:
  /// **'Weitere Nährwerte'**
  String get customSectionMore;

  /// No description provided for @customSectionVitamins.
  ///
  /// In de, this message translates to:
  /// **'Vitamine'**
  String get customSectionVitamins;

  /// No description provided for @customSectionMinerals.
  ///
  /// In de, this message translates to:
  /// **'Mineralstoffe'**
  String get customSectionMinerals;

  /// No description provided for @customFavorite.
  ///
  /// In de, this message translates to:
  /// **'Als Favorit markieren'**
  String get customFavorite;

  /// No description provided for @customNoteEntries.
  ///
  /// In de, this message translates to:
  /// **'Änderungen gelten auch für bereits erfasste Einträge dieses Lebensmittels.'**
  String get customNoteEntries;

  /// No description provided for @customSaltSodium.
  ///
  /// In de, this message translates to:
  /// **'Ist nur Salz oder nur Natrium angegeben, wird das andere berechnet.'**
  String get customSaltSodium;

  /// No description provided for @customSaved.
  ///
  /// In de, this message translates to:
  /// **'„{name}“ gespeichert'**
  String customSaved(String name);

  /// No description provided for @nutrientsTitle.
  ///
  /// In de, this message translates to:
  /// **'Nährwerte'**
  String get nutrientsTitle;

  /// No description provided for @nutrientsGroupMain.
  ///
  /// In de, this message translates to:
  /// **'Energie und Hauptnährstoffe'**
  String get nutrientsGroupMain;

  /// No description provided for @nutrientsGroupMore.
  ///
  /// In de, this message translates to:
  /// **'Weitere Nährwerte'**
  String get nutrientsGroupMore;

  /// No description provided for @nutrientsGroupVitamins.
  ///
  /// In de, this message translates to:
  /// **'Vitamine'**
  String get nutrientsGroupVitamins;

  /// No description provided for @nutrientsGroupMinerals.
  ///
  /// In de, this message translates to:
  /// **'Mineralstoffe'**
  String get nutrientsGroupMinerals;

  /// No description provided for @nutrientsDashHint.
  ///
  /// In de, this message translates to:
  /// **'Ein Strich (–) steht für fehlende Angaben in den erfassten Einträgen.'**
  String get nutrientsDashHint;

  /// No description provided for @trendsRange7.
  ///
  /// In de, this message translates to:
  /// **'7 Tage'**
  String get trendsRange7;

  /// No description provided for @trendsRange28.
  ///
  /// In de, this message translates to:
  /// **'28 Tage'**
  String get trendsRange28;

  /// No description provided for @trendsMetric.
  ///
  /// In de, this message translates to:
  /// **'Anzeigen'**
  String get trendsMetric;

  /// No description provided for @trendsAverage.
  ///
  /// In de, this message translates to:
  /// **'Durchschnitt: {value} ({days} von {total} Tagen erfasst)'**
  String trendsAverage(String value, String days, String total);

  /// No description provided for @trendsMinMax.
  ///
  /// In de, this message translates to:
  /// **'Niedrigster Wert {min}, höchster Wert {max}'**
  String trendsMinMax(String min, String max);

  /// No description provided for @trendsNoData.
  ///
  /// In de, this message translates to:
  /// **'Im gewählten Zeitraum sind keine Werte erfasst.'**
  String get trendsNoData;

  /// No description provided for @trendsGoal.
  ///
  /// In de, this message translates to:
  /// **'Ziel'**
  String get trendsGoal;

  /// No description provided for @trendsChartHint.
  ///
  /// In de, this message translates to:
  /// **'Balken antippen, um den Wert zu sehen'**
  String get trendsChartHint;

  /// No description provided for @trendsNoDataDay.
  ///
  /// In de, this message translates to:
  /// **'keine Angabe'**
  String get trendsNoDataDay;

  /// No description provided for @trendsSummary.
  ///
  /// In de, this message translates to:
  /// **'{metric}, {range}. Durchschnitt {avg}. {days} von {total} Tagen mit Angaben.'**
  String trendsSummary(String metric, String range, String avg, String days, String total);

  /// No description provided for @historyTitle.
  ///
  /// In de, this message translates to:
  /// **'Historie'**
  String get historyTitle;

  /// No description provided for @historySearchHint.
  ///
  /// In de, this message translates to:
  /// **'Suchen (Name, Notiz, Symptom …)'**
  String get historySearchHint;

  /// No description provided for @historyAreas.
  ///
  /// In de, this message translates to:
  /// **'Bereiche'**
  String get historyAreas;

  /// No description provided for @historyPeriod.
  ///
  /// In de, this message translates to:
  /// **'Zeitraum'**
  String get historyPeriod;

  /// No description provided for @historyPreset7.
  ///
  /// In de, this message translates to:
  /// **'Letzte 7 Tage'**
  String get historyPreset7;

  /// No description provided for @historyPreset28.
  ///
  /// In de, this message translates to:
  /// **'Letzte 28 Tage'**
  String get historyPreset28;

  /// No description provided for @historyPreset90.
  ///
  /// In de, this message translates to:
  /// **'Letzte 90 Tage'**
  String get historyPreset90;

  /// No description provided for @historyPresetAll.
  ///
  /// In de, this message translates to:
  /// **'Gesamter Zeitraum'**
  String get historyPresetAll;

  /// No description provided for @historyCustomRange.
  ///
  /// In de, this message translates to:
  /// **'Zeitraum wählen'**
  String get historyCustomRange;

  /// No description provided for @historyCount.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =0{Keine Einträge} =1{1 Eintrag} other{{count} Einträge}}'**
  String historyCount(int count);

  /// No description provided for @historyEmpty.
  ///
  /// In de, this message translates to:
  /// **'Keine Einträge gefunden. Passe Suchbegriff oder Filter an.'**
  String get historyEmpty;

  /// No description provided for @historyClearFilters.
  ///
  /// In de, this message translates to:
  /// **'Filter zurücksetzen'**
  String get historyClearFilters;

  /// No description provided for @historyPeriodTitle.
  ///
  /// In de, this message translates to:
  /// **'Periode {from} bis {to}'**
  String historyPeriodTitle(String from, String to);

  /// No description provided for @historyPeriodOpen.
  ///
  /// In de, this message translates to:
  /// **'Periode ab {from} (läuft)'**
  String historyPeriodOpen(String from);

  /// No description provided for @historySymptomTitle.
  ///
  /// In de, this message translates to:
  /// **'{name} · {intensity} von 10'**
  String historySymptomTitle(String name, String intensity);

  /// No description provided for @historyCaffeineTitle.
  ///
  /// In de, this message translates to:
  /// **'{mg} mg Koffein'**
  String historyCaffeineTitle(String mg);

  /// No description provided for @weightAdd.
  ///
  /// In de, this message translates to:
  /// **'Gewicht erfassen'**
  String get weightAdd;

  /// No description provided for @weightEditTitle.
  ///
  /// In de, this message translates to:
  /// **'Gewichtseintrag bearbeiten'**
  String get weightEditTitle;

  /// No description provided for @weightValueLabel.
  ///
  /// In de, this message translates to:
  /// **'Gewicht'**
  String get weightValueLabel;

  /// No description provided for @weightLatest.
  ///
  /// In de, this message translates to:
  /// **'Zuletzt: {value} am {date}'**
  String weightLatest(String value, String date);

  /// No description provided for @weightChange.
  ///
  /// In de, this message translates to:
  /// **'{delta} gegenüber dem vorherigen Eintrag'**
  String weightChange(String delta);

  /// No description provided for @weightNoEntries.
  ///
  /// In de, this message translates to:
  /// **'Noch kein Gewicht erfasst.'**
  String get weightNoEntries;

  /// No description provided for @weightRange90.
  ///
  /// In de, this message translates to:
  /// **'90 Tage'**
  String get weightRange90;

  /// No description provided for @weightRangeAll.
  ///
  /// In de, this message translates to:
  /// **'Alles'**
  String get weightRangeAll;

  /// No description provided for @weightChartSummary.
  ///
  /// In de, this message translates to:
  /// **'Gewichtsverlauf, {range}. Erster Wert {first}, letzter Wert {last}, {count, plural, =1{1 Eintrag} other{{count} Einträge}}.'**
  String weightChartSummary(String range, String first, String last, int count);

  /// No description provided for @weightStats.
  ///
  /// In de, this message translates to:
  /// **'Niedrigster Wert {min}, höchster Wert {max}, Änderung {delta}'**
  String weightStats(String min, String max, String delta);

  /// No description provided for @weightChartHint.
  ///
  /// In de, this message translates to:
  /// **'Punkt antippen, um den Wert zu sehen'**
  String get weightChartHint;

  /// No description provided for @weightEntriesTitle.
  ///
  /// In de, this message translates to:
  /// **'Einträge'**
  String get weightEntriesTitle;

  /// No description provided for @weightNoteHint.
  ///
  /// In de, this message translates to:
  /// **'Notiz (optional)'**
  String get weightNoteHint;

  /// No description provided for @weightNoRange.
  ///
  /// In de, this message translates to:
  /// **'Im gewählten Zeitraum ist kein Gewicht erfasst.'**
  String get weightNoRange;

  /// No description provided for @symptomAdd.
  ///
  /// In de, this message translates to:
  /// **'Symptom erfassen'**
  String get symptomAdd;

  /// No description provided for @symptomEditTitle.
  ///
  /// In de, this message translates to:
  /// **'Symptom bearbeiten'**
  String get symptomEditTitle;

  /// No description provided for @symptomNameLabel.
  ///
  /// In de, this message translates to:
  /// **'Name des Symptoms'**
  String get symptomNameLabel;

  /// No description provided for @symptomIntensity.
  ///
  /// In de, this message translates to:
  /// **'Intensität'**
  String get symptomIntensity;

  /// No description provided for @symptomIntensityValue.
  ///
  /// In de, this message translates to:
  /// **'{value} von 10'**
  String symptomIntensityValue(String value);

  /// No description provided for @symptomIntensityHint.
  ///
  /// In de, this message translates to:
  /// **'0 = kaum spürbar, 10 = sehr stark'**
  String get symptomIntensityHint;

  /// No description provided for @symptomRecent.
  ///
  /// In de, this message translates to:
  /// **'Zuletzt verwendet'**
  String get symptomRecent;

  /// No description provided for @symptomTabDay.
  ///
  /// In de, this message translates to:
  /// **'Tag'**
  String get symptomTabDay;

  /// No description provided for @symptomTabHistory.
  ///
  /// In de, this message translates to:
  /// **'Verlauf'**
  String get symptomTabHistory;

  /// No description provided for @symptomNoEntries.
  ///
  /// In de, this message translates to:
  /// **'An diesem Tag sind keine Symptome erfasst.'**
  String get symptomNoEntries;

  /// No description provided for @symptomPick.
  ///
  /// In de, this message translates to:
  /// **'Symptom wählen'**
  String get symptomPick;

  /// No description provided for @symptomStats.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =1{1 Eintrag} other{{count} Einträge}}, Durchschnitt {avg} von 10, Höchstwert {max}'**
  String symptomStats(int count, String avg, String max);

  /// No description provided for @symptomNoHistory.
  ///
  /// In de, this message translates to:
  /// **'Noch keine Symptome erfasst. Sobald du eines erfasst, kannst du hier den Verlauf ansehen.'**
  String get symptomNoHistory;

  /// No description provided for @symptomChartSummary.
  ///
  /// In de, this message translates to:
  /// **'Verlauf von {name}, {range}. {count, plural, =1{1 Eintrag} other{{count} Einträge}}, Durchschnitt {avg} von 10.'**
  String symptomChartSummary(String name, String range, int count, String avg);

  /// No description provided for @symptomLogged.
  ///
  /// In de, this message translates to:
  /// **'„{name}“ erfasst'**
  String symptomLogged(String name);

  /// No description provided for @symptomEntryTitle.
  ///
  /// In de, this message translates to:
  /// **'{name}, Intensität {intensity} von 10'**
  String symptomEntryTitle(String name, String intensity);

  /// No description provided for @symptomNoInRange.
  ///
  /// In de, this message translates to:
  /// **'Im gewählten Zeitraum ist dieses Symptom nicht erfasst.'**
  String get symptomNoInRange;

  /// No description provided for @cycleTabCalendar.
  ///
  /// In de, this message translates to:
  /// **'Kalender'**
  String get cycleTabCalendar;

  /// No description provided for @cycleTabHistory.
  ///
  /// In de, this message translates to:
  /// **'Historie'**
  String get cycleTabHistory;

  /// No description provided for @cycleForecastTitle.
  ///
  /// In de, this message translates to:
  /// **'Einschätzung'**
  String get cycleForecastTitle;

  /// No description provided for @cycleStateAsOf.
  ///
  /// In de, this message translates to:
  /// **'Stand: {date}'**
  String cycleStateAsOf(String date);

  /// No description provided for @cycleNoDataTitle.
  ///
  /// In de, this message translates to:
  /// **'Noch keine Perioden erfasst'**
  String get cycleNoDataTitle;

  /// No description provided for @cycleNoDataBody.
  ///
  /// In de, this message translates to:
  /// **'Sobald zwei Periodenbeginne vorliegen, schätzt MorphHealth den nächsten Beginn aus deinen eigenen Abständen.'**
  String get cycleNoDataBody;

  /// No description provided for @cycleInsufficientTitle.
  ///
  /// In de, this message translates to:
  /// **'Für eine Einschätzung fehlen noch Daten'**
  String get cycleInsufficientTitle;

  /// No description provided for @cycleInsufficientBody.
  ///
  /// In de, this message translates to:
  /// **'Ein Zyklus braucht zwei Periodenbeginne. Trage weitere Perioden ein oder lege in den Einstellungen eine typische Zykluslänge fest.'**
  String get cycleInsufficientBody;

  /// No description provided for @cycleInPeriodTitle.
  ///
  /// In de, this message translates to:
  /// **'Tag {day} der Periode'**
  String cycleInPeriodTitle(String day);

  /// No description provided for @cyclePredictedIn.
  ///
  /// In de, this message translates to:
  /// **'{days, plural, =0{Beginn voraussichtlich heute} =1{Beginn voraussichtlich morgen} other{Beginn voraussichtlich in {days} Tagen}}'**
  String cyclePredictedIn(int days);

  /// No description provided for @cycleNextStart.
  ///
  /// In de, this message translates to:
  /// **'Voraussichtlicher Beginn: {date}'**
  String cycleNextStart(String date);

  /// No description provided for @cycleWindowLine.
  ///
  /// In de, this message translates to:
  /// **'Zeitfenster: {from} bis {to}'**
  String cycleWindowLine(String from, String to);

  /// No description provided for @cycleOverdueTitle.
  ///
  /// In de, this message translates to:
  /// **'Der berechnete Beginn liegt {days, plural, =1{1 Tag} other{{days} Tage}} zurück'**
  String cycleOverdueTitle(int days);

  /// No description provided for @cycleOverdueBody.
  ///
  /// In de, this message translates to:
  /// **'Es ist noch keine neue Periode erfasst. Trage den Beginn ein, sobald er eintritt.'**
  String get cycleOverdueBody;

  /// No description provided for @cycleStaleTitle.
  ///
  /// In de, this message translates to:
  /// **'Der letzte erfasste Beginn liegt lange zurück'**
  String get cycleStaleTitle;

  /// No description provided for @cycleStaleBody.
  ///
  /// In de, this message translates to:
  /// **'Vermutlich fehlen Einträge, deshalb gibt es keine aktuelle Einschätzung.'**
  String get cycleStaleBody;

  /// No description provided for @cycleDisabledTitle.
  ///
  /// In de, this message translates to:
  /// **'Prognose ausgeschaltet'**
  String get cycleDisabledTitle;

  /// No description provided for @cycleDisabledBody.
  ///
  /// In de, this message translates to:
  /// **'Der Zyklusbereich arbeitet als reines Tagebuch. Du kannst die Prognose in den Einstellungen einschalten.'**
  String get cycleDisabledBody;

  /// No description provided for @cycleCycleDay.
  ///
  /// In de, this message translates to:
  /// **'Zyklustag {day}'**
  String cycleCycleDay(String day);

  /// No description provided for @cycleConfidence.
  ///
  /// In de, this message translates to:
  /// **'Verlässlichkeit: {level}'**
  String cycleConfidence(String level);

  /// No description provided for @cycleConfHigh.
  ///
  /// In de, this message translates to:
  /// **'hoch'**
  String get cycleConfHigh;

  /// No description provided for @cycleConfMedium.
  ///
  /// In de, this message translates to:
  /// **'mittel'**
  String get cycleConfMedium;

  /// No description provided for @cycleConfLow.
  ///
  /// In de, this message translates to:
  /// **'niedrig'**
  String get cycleConfLow;

  /// No description provided for @cycleExplainButton.
  ///
  /// In de, this message translates to:
  /// **'Wie kommt die Einschätzung zustande?'**
  String get cycleExplainButton;

  /// No description provided for @cycleExplainTitle.
  ///
  /// In de, this message translates to:
  /// **'Erklärung der Einschätzung'**
  String get cycleExplainTitle;

  /// No description provided for @cycleExplainIntervals.
  ///
  /// In de, this message translates to:
  /// **'Abstände zwischen Periodenbeginnen'**
  String get cycleExplainIntervals;

  /// No description provided for @cycleExplainUsed.
  ///
  /// In de, this message translates to:
  /// **'verwendet'**
  String get cycleExplainUsed;

  /// No description provided for @cycleExplainTooShort.
  ///
  /// In de, this message translates to:
  /// **'nicht verwendet: unter 15 Tagen'**
  String get cycleExplainTooShort;

  /// No description provided for @cycleExplainTooLong.
  ///
  /// In de, this message translates to:
  /// **'nicht verwendet: über 60 Tagen'**
  String get cycleExplainTooLong;

  /// No description provided for @cycleExplainOlder.
  ///
  /// In de, this message translates to:
  /// **'nicht verwendet: älter als die letzten 6 Zyklen'**
  String get cycleExplainOlder;

  /// No description provided for @cycleExplainNoIntervals.
  ///
  /// In de, this message translates to:
  /// **'Noch keine Abstände vorhanden.'**
  String get cycleExplainNoIntervals;

  /// No description provided for @cycleIntervalRow.
  ///
  /// In de, this message translates to:
  /// **'{from} bis {to}: {days} Tage'**
  String cycleIntervalRow(String from, String to, String days);

  /// No description provided for @cycleStartToday.
  ///
  /// In de, this message translates to:
  /// **'Periode beginnt heute'**
  String get cycleStartToday;

  /// No description provided for @cycleStartOnDay.
  ///
  /// In de, this message translates to:
  /// **'Periode beginnt am {date}'**
  String cycleStartOnDay(String date);

  /// No description provided for @cycleEndToday.
  ///
  /// In de, this message translates to:
  /// **'Periode endet heute'**
  String get cycleEndToday;

  /// No description provided for @cycleEndOnDay.
  ///
  /// In de, this message translates to:
  /// **'Periode endet am {date}'**
  String cycleEndOnDay(String date);

  /// No description provided for @cycleStartedSnack.
  ///
  /// In de, this message translates to:
  /// **'Periode ab {date} erfasst'**
  String cycleStartedSnack(String date);

  /// No description provided for @cycleEndedSnack.
  ///
  /// In de, this message translates to:
  /// **'Ende der Periode am {date} erfasst'**
  String cycleEndedSnack(String date);

  /// No description provided for @cycleAddPeriod.
  ///
  /// In de, this message translates to:
  /// **'Periode erfassen'**
  String get cycleAddPeriod;

  /// No description provided for @cycleEditPeriod.
  ///
  /// In de, this message translates to:
  /// **'Periode bearbeiten'**
  String get cycleEditPeriod;

  /// No description provided for @cycleStart.
  ///
  /// In de, this message translates to:
  /// **'Beginn'**
  String get cycleStart;

  /// No description provided for @cycleEnd.
  ///
  /// In de, this message translates to:
  /// **'Ende'**
  String get cycleEnd;

  /// No description provided for @cycleOngoing.
  ///
  /// In de, this message translates to:
  /// **'Läuft noch (kein Ende erfasst)'**
  String get cycleOngoing;

  /// No description provided for @cycleFlow.
  ///
  /// In de, this message translates to:
  /// **'Blutungsstärke'**
  String get cycleFlow;

  /// No description provided for @cycleNotes.
  ///
  /// In de, this message translates to:
  /// **'Notizen'**
  String get cycleNotes;

  /// No description provided for @cycleOverlap.
  ///
  /// In de, this message translates to:
  /// **'Die Periode überschneidet sich mit einer vorhandenen Periode ({from} bis {to}).'**
  String cycleOverlap(String from, String to);

  /// No description provided for @cycleEndBeforeStart.
  ///
  /// In de, this message translates to:
  /// **'Das Ende liegt vor dem Beginn.'**
  String get cycleEndBeforeStart;

  /// No description provided for @cycleTooLong.
  ///
  /// In de, this message translates to:
  /// **'Eine Periode darf höchstens 60 Tage umfassen.'**
  String get cycleTooLong;

  /// No description provided for @cycleMonthPrev.
  ///
  /// In de, this message translates to:
  /// **'Vorheriger Monat'**
  String get cycleMonthPrev;

  /// No description provided for @cycleMonthNext.
  ///
  /// In de, this message translates to:
  /// **'Nächster Monat'**
  String get cycleMonthNext;

  /// No description provided for @cycleMonthPick.
  ///
  /// In de, this message translates to:
  /// **'Monat wählen'**
  String get cycleMonthPick;

  /// No description provided for @cycleLegendPeriod.
  ///
  /// In de, this message translates to:
  /// **'Periode'**
  String get cycleLegendPeriod;

  /// No description provided for @cycleLegendPredicted.
  ///
  /// In de, this message translates to:
  /// **'Voraussichtlich'**
  String get cycleLegendPredicted;

  /// No description provided for @cycleLegendWindow.
  ///
  /// In de, this message translates to:
  /// **'Zeitfenster'**
  String get cycleLegendWindow;

  /// No description provided for @cycleLegendSymptom.
  ///
  /// In de, this message translates to:
  /// **'Symptome erfasst'**
  String get cycleLegendSymptom;

  /// No description provided for @cycleFlowOnDay.
  ///
  /// In de, this message translates to:
  /// **'Blutungsstärke an diesem Tag'**
  String get cycleFlowOnDay;

  /// No description provided for @cycleFlowRemove.
  ///
  /// In de, this message translates to:
  /// **'Angabe entfernen'**
  String get cycleFlowRemove;

  /// No description provided for @cycleDaySymptoms.
  ///
  /// In de, this message translates to:
  /// **'Symptome an diesem Tag'**
  String get cycleDaySymptoms;

  /// No description provided for @cycleAddSymptomHere.
  ///
  /// In de, this message translates to:
  /// **'Symptom hinzufügen'**
  String get cycleAddSymptomHere;

  /// No description provided for @cycleOpenDayDetail.
  ///
  /// In de, this message translates to:
  /// **'Tagesdetail öffnen'**
  String get cycleOpenDayDetail;

  /// No description provided for @cycleDayInPeriod.
  ///
  /// In de, this message translates to:
  /// **'Periode, Tag {day}'**
  String cycleDayInPeriod(String day);

  /// No description provided for @cycleDayNoPeriod.
  ///
  /// In de, this message translates to:
  /// **'Keine Periode an diesem Tag.'**
  String get cycleDayNoPeriod;

  /// No description provided for @cycleDayPredicted.
  ///
  /// In de, this message translates to:
  /// **'Voraussichtlicher Periodentag'**
  String get cycleDayPredicted;

  /// No description provided for @cycleHistoryEmpty.
  ///
  /// In de, this message translates to:
  /// **'Noch keine Perioden erfasst.'**
  String get cycleHistoryEmpty;

  /// No description provided for @cycleHistoryDays.
  ///
  /// In de, this message translates to:
  /// **'{days, plural, =1{1 Tag} other{{days} Tage}}'**
  String cycleHistoryDays(int days);

  /// No description provided for @cycleHistoryCycle.
  ///
  /// In de, this message translates to:
  /// **'Zyklus {days} Tage'**
  String cycleHistoryCycle(String days);

  /// No description provided for @cycleEndMissing.
  ///
  /// In de, this message translates to:
  /// **'Ende fehlt'**
  String get cycleEndMissing;

  /// No description provided for @cycleHistoryOngoing.
  ///
  /// In de, this message translates to:
  /// **'läuft'**
  String get cycleHistoryOngoing;

  /// No description provided for @cycleStatsTitle.
  ///
  /// In de, this message translates to:
  /// **'Zahlen aus deiner Historie'**
  String get cycleStatsTitle;

  /// No description provided for @cycleStatsAvg.
  ///
  /// In de, this message translates to:
  /// **'Durchschnittliche Zykluslänge: {value} Tage'**
  String cycleStatsAvg(String value);

  /// No description provided for @cycleStatsPeriod.
  ///
  /// In de, this message translates to:
  /// **'Durchschnittliche Periodendauer: {value} Tage'**
  String cycleStatsPeriod(String value);

  /// No description provided for @cycleStatsCount.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =1{1 Periode erfasst} other{{count} Perioden erfasst}}'**
  String cycleStatsCount(int count);

  /// No description provided for @cycleSpottingNote.
  ///
  /// In de, this message translates to:
  /// **'Nur Spotting: zählt nicht als Periodenbeginn für die Einschätzung.'**
  String get cycleSpottingNote;

  /// No description provided for @cycleDeleteTitle.
  ///
  /// In de, this message translates to:
  /// **'Periode löschen?'**
  String get cycleDeleteTitle;

  /// No description provided for @cycleDeleteMessage.
  ///
  /// In de, this message translates to:
  /// **'Die Periode ab {date} wird gelöscht.'**
  String cycleDeleteMessage(String date);

  /// No description provided for @cycleLegendToday.
  ///
  /// In de, this message translates to:
  /// **'Heute'**
  String get cycleLegendToday;

  /// No description provided for @dayDetailTitle.
  ///
  /// In de, this message translates to:
  /// **'Tagesdetail'**
  String get dayDetailTitle;

  /// No description provided for @overviewCustomize.
  ///
  /// In de, this message translates to:
  /// **'Bereiche anpassen'**
  String get overviewCustomize;

  /// No description provided for @overviewCustomizeHint.
  ///
  /// In de, this message translates to:
  /// **'Ausgeblendete Bereiche bleiben gespeichert und lassen sich jederzeit wieder einblenden.'**
  String get overviewCustomizeHint;

  /// No description provided for @overviewRangeDay.
  ///
  /// In de, this message translates to:
  /// **'Tag'**
  String get overviewRangeDay;

  /// No description provided for @overviewOpenDay.
  ///
  /// In de, this message translates to:
  /// **'Tagesdetail'**
  String get overviewOpenDay;

  /// No description provided for @overviewNothingVisible.
  ///
  /// In de, this message translates to:
  /// **'Alle Bereiche sind ausgeblendet. Wähle unter „Bereiche anpassen“ mindestens einen aus.'**
  String get overviewNothingVisible;

  /// No description provided for @overviewSettings.
  ///
  /// In de, this message translates to:
  /// **'Einstellungen'**
  String get overviewSettings;

  /// No description provided for @overviewWeightNone.
  ///
  /// In de, this message translates to:
  /// **'Noch kein Gewicht erfasst'**
  String get overviewWeightNone;

  /// No description provided for @overviewSymptomsNone.
  ///
  /// In de, this message translates to:
  /// **'An diesem Tag sind keine Symptome erfasst'**
  String get overviewSymptomsNone;

  /// No description provided for @overviewAverageKcal.
  ///
  /// In de, this message translates to:
  /// **'Durchschnitt {value} kcal an {days} von {total} Tagen'**
  String overviewAverageKcal(String value, String days, String total);

  /// No description provided for @overviewWaterAverage.
  ///
  /// In de, this message translates to:
  /// **'Wasser: Durchschnitt {value} ml'**
  String overviewWaterAverage(String value);

  /// No description provided for @overviewCyclePeriods.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =0{Keine Periode im Zeitraum} =1{1 Periode im Zeitraum} other{{count} Perioden im Zeitraum}}'**
  String overviewCyclePeriods(int count);

  /// No description provided for @overviewTopSymptoms.
  ///
  /// In de, this message translates to:
  /// **'Häufigste Symptome'**
  String get overviewTopSymptoms;

  /// No description provided for @overviewSymptomCount.
  ///
  /// In de, this message translates to:
  /// **'{count, plural, =1{1 Eintrag} other{{count} Einträge}}, Durchschnitt {avg} von 10'**
  String overviewSymptomCount(int count, String avg);

  /// No description provided for @overviewWeightRange.
  ///
  /// In de, this message translates to:
  /// **'Von {first} auf {last} ({delta})'**
  String overviewWeightRange(String first, String last, String delta);

  /// No description provided for @overviewOpenArea.
  ///
  /// In de, this message translates to:
  /// **'{area} öffnen'**
  String overviewOpenArea(String area);

  /// No description provided for @overviewNoDataRange.
  ///
  /// In de, this message translates to:
  /// **'Im Zeitraum sind keine Einträge erfasst.'**
  String get overviewNoDataRange;

  /// No description provided for @settingsTitle.
  ///
  /// In de, this message translates to:
  /// **'Einstellungen'**
  String get settingsTitle;

  /// No description provided for @settingsLanguage.
  ///
  /// In de, this message translates to:
  /// **'Sprache'**
  String get settingsLanguage;

  /// No description provided for @langGerman.
  ///
  /// In de, this message translates to:
  /// **'Deutsch'**
  String get langGerman;

  /// No description provided for @langEnglish.
  ///
  /// In de, this message translates to:
  /// **'English'**
  String get langEnglish;

  /// No description provided for @settingsWeightUnit.
  ///
  /// In de, this message translates to:
  /// **'Gewichtseinheit'**
  String get settingsWeightUnit;

  /// No description provided for @settingsAreas.
  ///
  /// In de, this message translates to:
  /// **'Bereiche der Übersicht'**
  String get settingsAreas;

  /// No description provided for @settingsGoals.
  ///
  /// In de, this message translates to:
  /// **'Tagesziele'**
  String get settingsGoals;

  /// No description provided for @settingsGoalsSubtitle.
  ///
  /// In de, this message translates to:
  /// **'Freiwillig: Wasser, Kalorien, Eiweiß, Kohlenhydrate, Fett'**
  String get settingsGoalsSubtitle;

  /// No description provided for @goalsHint.
  ///
  /// In de, this message translates to:
  /// **'Alle Ziele sind freiwillig. Leere Felder bedeuten: kein Ziel. Du bestimmst die Werte.'**
  String get goalsHint;

  /// No description provided for @goalWater.
  ///
  /// In de, this message translates to:
  /// **'Wasser'**
  String get goalWater;

  /// No description provided for @goalEnergy.
  ///
  /// In de, this message translates to:
  /// **'Kalorien'**
  String get goalEnergy;

  /// No description provided for @goalSaved.
  ///
  /// In de, this message translates to:
  /// **'Ziele gespeichert'**
  String get goalSaved;

  /// No description provided for @settingsCycleSection.
  ///
  /// In de, this message translates to:
  /// **'Zyklus'**
  String get settingsCycleSection;

  /// No description provided for @settingsForecast.
  ///
  /// In de, this message translates to:
  /// **'Prognose anzeigen'**
  String get settingsForecast;

  /// No description provided for @settingsForecastHint.
  ///
  /// In de, this message translates to:
  /// **'Ausgeschaltet arbeitet der Zyklusbereich nur als Tagebuch.'**
  String get settingsForecastHint;

  /// No description provided for @settingsExpectedCycle.
  ///
  /// In de, this message translates to:
  /// **'Typische Zykluslänge in Tagen (optional)'**
  String get settingsExpectedCycle;

  /// No description provided for @settingsExpectedCycleHint.
  ///
  /// In de, this message translates to:
  /// **'Wird nur verwendet, solange noch kein vollständiger Zyklus erfasst ist. Erlaubt sind 15 bis 60 Tage.'**
  String get settingsExpectedCycleHint;

  /// No description provided for @settingsOnlineSection.
  ///
  /// In de, this message translates to:
  /// **'Online-Lebensmittelsuche'**
  String get settingsOnlineSection;

  /// No description provided for @settingsOnlineSwitch.
  ///
  /// In de, this message translates to:
  /// **'Open Food Facts nutzen'**
  String get settingsOnlineSwitch;

  /// No description provided for @settingsOnlineHint.
  ///
  /// In de, this message translates to:
  /// **'Es wird nur der Suchbegriff beziehungsweise die Barcode-Nummer an den Dienst gesendet. Ohne diese Funktion arbeitet die App vollständig lokal.'**
  String get settingsOnlineHint;

  /// No description provided for @settingsServer.
  ///
  /// In de, this message translates to:
  /// **'Server der Lebensmittel-API'**
  String get settingsServer;

  /// No description provided for @settingsServerHint.
  ///
  /// In de, this message translates to:
  /// **'HTTPS-Ursprung, zum Beispiel https://world.openfoodfacts.org'**
  String get settingsServerHint;

  /// No description provided for @settingsServerInvalid.
  ///
  /// In de, this message translates to:
  /// **'Bitte einen HTTPS-Ursprung ohne Pfad angeben, zum Beispiel https://world.openfoodfacts.org.'**
  String get settingsServerInvalid;

  /// No description provided for @settingsServerReset.
  ///
  /// In de, this message translates to:
  /// **'Standard verwenden'**
  String get settingsServerReset;

  /// No description provided for @settingsServerDefault.
  ///
  /// In de, this message translates to:
  /// **'Standard: {url}'**
  String settingsServerDefault(String url);

  /// No description provided for @settingsServerSaved.
  ///
  /// In de, this message translates to:
  /// **'Server gespeichert'**
  String get settingsServerSaved;

  /// No description provided for @settingsTheme.
  ///
  /// In de, this message translates to:
  /// **'Darstellung'**
  String get settingsTheme;

  /// No description provided for @themeSystem.
  ///
  /// In de, this message translates to:
  /// **'System'**
  String get themeSystem;

  /// No description provided for @themeLight.
  ///
  /// In de, this message translates to:
  /// **'Hell'**
  String get themeLight;

  /// No description provided for @themeDark.
  ///
  /// In de, this message translates to:
  /// **'Dunkel'**
  String get themeDark;

  /// No description provided for @settingsPrivacySection.
  ///
  /// In de, this message translates to:
  /// **'Datenschutz'**
  String get settingsPrivacySection;

  /// No description provided for @settingsSecure.
  ///
  /// In de, this message translates to:
  /// **'Bildschirmaufnahmen sperren'**
  String get settingsSecure;

  /// No description provided for @settingsSecureHint.
  ///
  /// In de, this message translates to:
  /// **'Sperrt Screenshots und die Vorschau in der App-Übersicht.'**
  String get settingsSecureHint;

  /// No description provided for @settingsData.
  ///
  /// In de, this message translates to:
  /// **'Daten und Sicherung'**
  String get settingsData;

  /// No description provided for @settingsDataSubtitle.
  ///
  /// In de, this message translates to:
  /// **'Export, Import, verschlüsselte Sicherung, Löschen'**
  String get settingsDataSubtitle;

  /// No description provided for @settingsAbout.
  ///
  /// In de, this message translates to:
  /// **'Über MorphHealth'**
  String get settingsAbout;

  /// No description provided for @aboutText.
  ///
  /// In de, this message translates to:
  /// **'MorphHealth speichert alle Daten verschlüsselt auf diesem Gerät. Es gibt kein Konto, keine Werbung und keine Telemetrie. Nährwertdaten stammen von Open Food Facts (ODbL).'**
  String get aboutText;

  /// No description provided for @aboutMedical.
  ///
  /// In de, this message translates to:
  /// **'MorphHealth dient der persönlichen Dokumentation und Planung. Es ersetzt keine medizinische Beratung und berechnet weder Diagnosen noch Eisprung oder fruchtbare Tage.'**
  String get aboutMedical;

  /// No description provided for @aboutVersion.
  ///
  /// In de, this message translates to:
  /// **'Version {version}'**
  String aboutVersion(String version);

  /// No description provided for @aboutLicenses.
  ///
  /// In de, this message translates to:
  /// **'Open-Source-Lizenzen'**
  String get aboutLicenses;

  /// No description provided for @dataTitle.
  ///
  /// In de, this message translates to:
  /// **'Daten und Sicherung'**
  String get dataTitle;

  /// No description provided for @dataExportTitle.
  ///
  /// In de, this message translates to:
  /// **'Datenexport (JSON)'**
  String get dataExportTitle;

  /// No description provided for @dataExportHint.
  ///
  /// In de, this message translates to:
  /// **'Vollständiger, maschinenlesbarer Export aller Daten. Das Format ist in der README beschrieben. Die Datei ist unverschlüsselt.'**
  String get dataExportHint;

  /// No description provided for @dataExportButton.
  ///
  /// In de, this message translates to:
  /// **'Exportieren'**
  String get dataExportButton;

  /// No description provided for @dataExportWarnTitle.
  ///
  /// In de, this message translates to:
  /// **'Unverschlüsselter Export'**
  String get dataExportWarnTitle;

  /// No description provided for @dataExportWarnMessage.
  ///
  /// In de, this message translates to:
  /// **'Die Datei enthält alle deine Gesundheitsdaten im Klartext. Speichere sie nur an einem Ort, dem du vertraust.'**
  String get dataExportWarnMessage;

  /// No description provided for @dataExportDone.
  ///
  /// In de, this message translates to:
  /// **'Export gespeichert: {name}'**
  String dataExportDone(String name);

  /// No description provided for @dataImportTitle.
  ///
  /// In de, this message translates to:
  /// **'Datenimport (JSON)'**
  String get dataImportTitle;

  /// No description provided for @dataImportHint.
  ///
  /// In de, this message translates to:
  /// **'Ersetzt alle vorhandenen Daten durch den Inhalt einer Exportdatei.'**
  String get dataImportHint;

  /// No description provided for @dataImportButton.
  ///
  /// In de, this message translates to:
  /// **'Datei wählen'**
  String get dataImportButton;

  /// No description provided for @dataImportPreviewTitle.
  ///
  /// In de, this message translates to:
  /// **'Import prüfen'**
  String get dataImportPreviewTitle;

  /// No description provided for @dataImportSummary.
  ///
  /// In de, this message translates to:
  /// **'Die Datei enthält {count} Datensätze.'**
  String dataImportSummary(String count);

  /// No description provided for @dataImportWarnings.
  ///
  /// In de, this message translates to:
  /// **'{count} Hinweise beim Prüfen'**
  String dataImportWarnings(String count);

  /// No description provided for @dataImportReplaceWarning.
  ///
  /// In de, this message translates to:
  /// **'Alle vorhandenen Daten werden ersetzt.'**
  String get dataImportReplaceWarning;

  /// No description provided for @dataImportConfirm.
  ///
  /// In de, this message translates to:
  /// **'Ersetzen'**
  String get dataImportConfirm;

  /// No description provided for @dataImportInvalid.
  ///
  /// In de, this message translates to:
  /// **'Die Datei ist ungültig'**
  String get dataImportInvalid;

  /// No description provided for @dataImportInvalidJson.
  ///
  /// In de, this message translates to:
  /// **'Die Datei ist kein gültiges JSON.'**
  String get dataImportInvalidJson;

  /// No description provided for @dataImportDone.
  ///
  /// In de, this message translates to:
  /// **'Import abgeschlossen: {count} Datensätze'**
  String dataImportDone(String count);

  /// No description provided for @dataBackupTitle.
  ///
  /// In de, this message translates to:
  /// **'Verschlüsselte Sicherung'**
  String get dataBackupTitle;

  /// No description provided for @dataBackupHint.
  ///
  /// In de, this message translates to:
  /// **'Sicherung mit Passphrase (AES-256, Argon2id). Sie lässt sich auf einer frischen Installation wiederherstellen.'**
  String get dataBackupHint;

  /// No description provided for @dataBackupCreate.
  ///
  /// In de, this message translates to:
  /// **'Sicherung erstellen'**
  String get dataBackupCreate;

  /// No description provided for @dataPassphrase.
  ///
  /// In de, this message translates to:
  /// **'Passphrase'**
  String get dataPassphrase;

  /// No description provided for @dataPassphraseRepeat.
  ///
  /// In de, this message translates to:
  /// **'Passphrase wiederholen'**
  String get dataPassphraseRepeat;

  /// No description provided for @dataPassphraseMismatch.
  ///
  /// In de, this message translates to:
  /// **'Die Passphrasen stimmen nicht überein.'**
  String get dataPassphraseMismatch;

  /// No description provided for @dataPassphraseShort.
  ///
  /// In de, this message translates to:
  /// **'Mindestens {min} Zeichen.'**
  String dataPassphraseShort(String min);

  /// No description provided for @dataBackupWarning.
  ///
  /// In de, this message translates to:
  /// **'Ohne die Passphrase lässt sich die Sicherung nicht öffnen. Sie kann nicht zurückgesetzt werden.'**
  String get dataBackupWarning;

  /// No description provided for @dataBackupDone.
  ///
  /// In de, this message translates to:
  /// **'Sicherung gespeichert: {name}'**
  String dataBackupDone(String name);

  /// No description provided for @dataRestoreTitle.
  ///
  /// In de, this message translates to:
  /// **'Sicherung wiederherstellen'**
  String get dataRestoreTitle;

  /// No description provided for @dataRestoreHint.
  ///
  /// In de, this message translates to:
  /// **'Ersetzt alle vorhandenen Daten durch den Inhalt einer Sicherung.'**
  String get dataRestoreHint;

  /// No description provided for @dataRestoreButton.
  ///
  /// In de, this message translates to:
  /// **'Sicherung wählen'**
  String get dataRestoreButton;

  /// No description provided for @dataRestoreWrong.
  ///
  /// In de, this message translates to:
  /// **'Passphrase falsch oder Datei beschädigt.'**
  String get dataRestoreWrong;

  /// No description provided for @dataRestoreNotBackup.
  ///
  /// In de, this message translates to:
  /// **'Die Datei ist keine MorphHealth-Sicherung.'**
  String get dataRestoreNotBackup;

  /// No description provided for @dataRestoreDone.
  ///
  /// In de, this message translates to:
  /// **'Wiederhergestellt: {count} Datensätze'**
  String dataRestoreDone(String count);

  /// No description provided for @dataWorking.
  ///
  /// In de, this message translates to:
  /// **'Bitte einen Moment warten …'**
  String get dataWorking;

  /// No description provided for @dataWipeTitle.
  ///
  /// In de, this message translates to:
  /// **'Alle lokalen Daten löschen'**
  String get dataWipeTitle;

  /// No description provided for @dataWipeHint.
  ///
  /// In de, this message translates to:
  /// **'Löscht alle Einträge, Lebensmittel und Einstellungen auf diesem Gerät und erneuert den Schlüssel.'**
  String get dataWipeHint;

  /// No description provided for @dataWipeButton.
  ///
  /// In de, this message translates to:
  /// **'Alles löschen'**
  String get dataWipeButton;

  /// No description provided for @dataWipeConfirmTitle.
  ///
  /// In de, this message translates to:
  /// **'Wirklich alles löschen?'**
  String get dataWipeConfirmTitle;

  /// No description provided for @dataWipeConfirmMessage.
  ///
  /// In de, this message translates to:
  /// **'Alle Einträge, eigenen Lebensmittel, Favoriten und Einstellungen werden unwiderruflich gelöscht. Exporte und Sicherungen, die du außerhalb der App gespeichert hast, bleiben bestehen.'**
  String get dataWipeConfirmMessage;

  /// No description provided for @dataWipeDone.
  ///
  /// In de, this message translates to:
  /// **'Alle Daten wurden gelöscht.'**
  String get dataWipeDone;

  /// No description provided for @dataFileTooLarge.
  ///
  /// In de, this message translates to:
  /// **'Die Datei ist zu groß.'**
  String get dataFileTooLarge;

  /// No description provided for @bootFailedWrongKey.
  ///
  /// In de, this message translates to:
  /// **'Der gespeicherte Schlüssel passt nicht zum Datenbestand. Das kommt vor, wenn das Gerät zurückgesetzt oder der Schlüssel gelöscht wurde.'**
  String get bootFailedWrongKey;

  /// No description provided for @bootFailedCorrupt.
  ///
  /// In de, this message translates to:
  /// **'Der Datenbestand ist beschädigt.'**
  String get bootFailedCorrupt;

  /// No description provided for @bootFailedLocked.
  ///
  /// In de, this message translates to:
  /// **'Der Datenbestand wird von einem anderen Prozess verwendet.'**
  String get bootFailedLocked;

  /// No description provided for @bootFailedKey.
  ///
  /// In de, this message translates to:
  /// **'Der Gerätehauptschlüssel konnte nicht gelesen werden.'**
  String get bootFailedKey;

  /// No description provided for @bootFailedIo.
  ///
  /// In de, this message translates to:
  /// **'Auf den Speicher konnte nicht zugegriffen werden.'**
  String get bootFailedIo;

  /// No description provided for @bootRestore.
  ///
  /// In de, this message translates to:
  /// **'Aus Sicherung wiederherstellen'**
  String get bootRestore;

  /// No description provided for @bootStartFresh.
  ///
  /// In de, this message translates to:
  /// **'Neu beginnen (alle Daten löschen)'**
  String get bootStartFresh;

  /// No description provided for @waterTotalLabel.
  ///
  /// In de, this message translates to:
  /// **'Gesamt'**
  String get waterTotalLabel;

  /// No description provided for @unitPortions.
  ///
  /// In de, this message translates to:
  /// **'Portionen'**
  String get unitPortions;

  /// No description provided for @errAmountInvalid.
  ///
  /// In de, this message translates to:
  /// **'Die Menge muss größer als 0 sein.'**
  String get errAmountInvalid;

  /// No description provided for @errServingNeeded.
  ///
  /// In de, this message translates to:
  /// **'Für Portionen ist eine Portionsgröße nötig.'**
  String get errServingNeeded;

  /// No description provided for @errWeightRange.
  ///
  /// In de, this message translates to:
  /// **'Das Gewicht liegt außerhalb des zulässigen Bereichs (1 bis 700 kg).'**
  String get errWeightRange;

  /// No description provided for @errSymptomInvalid.
  ///
  /// In de, this message translates to:
  /// **'Ein Symptom braucht einen Namen und eine Intensität von 0 bis 10.'**
  String get errSymptomInvalid;

  /// No description provided for @errFoodInvalid.
  ///
  /// In de, this message translates to:
  /// **'Ein Lebensmittel braucht einen Namen, und eine Portionsgröße muss größer als 0 sein.'**
  String get errFoodInvalid;

  /// No description provided for @errRecordInvalid.
  ///
  /// In de, this message translates to:
  /// **'Diese Angaben lassen sich so nicht speichern (zu lang oder ungültig).'**
  String get errRecordInvalid;

  /// No description provided for @errNothingToRemove.
  ///
  /// In de, this message translates to:
  /// **'An diesem Tag ist keine Periode erfasst.'**
  String get errNothingToRemove;

  /// No description provided for @errBackupUnsupported.
  ///
  /// In de, this message translates to:
  /// **'Diese Sicherung stammt aus einer anderen Version oder verwendet unzulässige Parameter.'**
  String get errBackupUnsupported;

  /// No description provided for @errBackupCorrupt.
  ///
  /// In de, this message translates to:
  /// **'Der Inhalt der Sicherung ist beschädigt.'**
  String get errBackupCorrupt;

  /// No description provided for @errPickerBusy.
  ///
  /// In de, this message translates to:
  /// **'Es läuft bereits eine Dateiauswahl.'**
  String get errPickerBusy;

  /// No description provided for @dataRestorePreviewTitle.
  ///
  /// In de, this message translates to:
  /// **'Sicherung prüfen'**
  String get dataRestorePreviewTitle;
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) => <String>['de', 'en'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
