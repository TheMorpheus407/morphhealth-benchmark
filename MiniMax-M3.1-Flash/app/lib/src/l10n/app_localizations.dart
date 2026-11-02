import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:morphhealth_core/morphhealth_core.dart';

/// Localized strings of the app.
///
/// The catalogue itself lives in the shared core package, so that the `mh`
/// CLI and the app always use the same wording.
@immutable
class AppLocalizations {
  const AppLocalizations(this.strings);

  final Strings strings;

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ];

  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
  ];

  /// Translates [key]; [params] fills `{placeholder}` slots.
  String t(String key, [Map<String, String> params = const <String, String>{}]) =>
      strings.t(key, params);

  /// Localized name of a tracked nutrient.
  String nutrientLabel(String id) {
    final NutrientSpec? spec = Nutrients.specOf(id);
    return spec?.label(strings.languageCode) ?? id;
  }

  /// Localized unit of a tracked nutrient.
  String nutrientUnit(String id) => Nutrients.specOf(id)?.unitLabel ?? '';

  /// The catalogue for the given language.
  static AppLocalizations of(Locale locale) => AppLocalizations(
        locale.languageCode == 'en' ? Strings.en : Strings.de,
      );
}

class _AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      locale.languageCode == 'de' || locale.languageCode == 'en';

  @override
  Future<AppLocalizations> load(Locale locale) async =>
      AppLocalizations.of(locale);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

/// Convenience access to the localized strings.
extension AppLocalizationsX on BuildContext {
  AppLocalizations get l10n =>
      Localizations.of<AppLocalizations>(this, AppLocalizations) ??
      const AppLocalizations(Strings.de);
}
