import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'controller.dart';
import 'l10n/strings.dart';
import 'ui/onboarding/welcome_screen.dart';
import 'ui/shell.dart';
import 'ui/theme.dart';

/// English-speaking countries for which date and number formats exist; other
/// devices set to English get British formats (day first, week starts Monday).
const Set<String> _englishRegions = {
  'GB', 'US', 'AU', 'CA', 'IE', 'IN', 'NZ', 'SG', 'ZA', //
};

/// The locale for the language chosen in the app.
Locale localeFor(String language, Locale device) {
  if (language != 'en') return const Locale('de');
  final country = device.countryCode;
  if (device.languageCode == 'en' &&
      country != null &&
      _englishRegions.contains(country)) {
    return Locale('en', country);
  }
  return const Locale('en', 'GB');
}

const List<LocalizationsDelegate<Object>> appLocalizationsDelegates = [
  L.delegate,
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

/// The running app with data: theme, language and the first screen.
class MorphHealthApp extends StatelessWidget {
  final AppController controller;

  const MorphHealthApp({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return AppScope(
      controller: controller,
      child: ListenableBuilder(
        listenable: controller,
        builder: (context, _) {
          final settings = controller.settings;
          final locale = localeFor(
            settings.language,
            WidgetsBinding.instance.platformDispatcher.locale,
          );
          return MaterialApp(
            title: 'MorphHealth',
            debugShowCheckedModeBanner: false,
            theme: buildTheme(Brightness.light),
            darkTheme: buildTheme(Brightness.dark),
            themeMode: switch (settings.theme) {
              'light' => ThemeMode.light,
              'dark' => ThemeMode.dark,
              _ => ThemeMode.system,
            },
            locale: locale,
            supportedLocales: [
              const Locale('de'),
              if (locale.languageCode == 'en')
                locale
              else
                const Locale('en', 'GB'),
            ],
            localizationsDelegates: appLocalizationsDelegates,
            home: const _Home(),
          );
        },
      ),
    );
  }
}

/// The first screen: the welcome page until it has been completed, then the
/// app itself. Depends on the controller, so it switches by itself.
class _Home extends StatelessWidget {
  const _Home();

  @override
  Widget build(BuildContext context) =>
      AppScope.of(context).local.onboardingDone
      ? const AppShell()
      : const WelcomeScreen();
}
