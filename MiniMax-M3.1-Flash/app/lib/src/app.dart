import 'package:flutter/material.dart';

import 'l10n/app_localizations.dart';
import 'pages/home_shell.dart';
import 'state/app_state.dart';
import 'theme/app_theme.dart';

/// Root widget of MorphHealth.
class MorphHealthApp extends StatelessWidget {
  const MorphHealthApp({required this.state, super.key});

  final AppState state;

  @override
  Widget build(BuildContext context) {
    // AppScope sits above MaterialApp on purpose: routes that are pushed on
    // the navigator (dialogs, bottom sheets, detail pages) are built inside
    // the navigator and therefore need the scope as an ancestor as well.
    return AppScope(
      state: state,
      child: ValueListenableBuilder<Locale>(
        valueListenable: state.locale,
        builder: (BuildContext context, Locale locale, Widget? child) {
          return MaterialApp(
            title: 'MorphHealth',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            themeMode: ThemeMode.system,
            locale: locale,
            supportedLocales: AppLocalizations.supportedLocales,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            home: const HomeShell(),
          );
        },
      ),
    );
  }
}
