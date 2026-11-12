library morphhealth.ui.app;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:morphhealth/core/repository.dart';
import 'package:morphhealth/l10n/app_localizations.dart';
import 'package:morphhealth/ui/home_page.dart';

class MorphHealthApp extends StatefulWidget {
  final HealthRepository repository;
  final Locale initialLocale;
  const MorphHealthApp({
    super.key,
    required this.repository,
    required this.initialLocale,
  });

  @override
  State<MorphHealthApp> createState() => _MorphHealthAppState();
}

class _MorphHealthAppState extends State<MorphHealthApp> {
  late Locale _locale;

  @override
  void initState() {
    super.initState();
    _locale = widget.initialLocale;
  }

  void setLocale(Locale locale) {
    setState(() => _locale = locale);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MorphHealth',
      debugShowCheckedModeBanner: false,
      theme: _theme(),
      locale: _locale,
      supportedLocales: const [Locale('de'), Locale('en')],
      localizationsDelegates: [
        const AppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: HomePage(
        repository: widget.repository,
        onLocaleChange: setLocale,
      ),
    );
  }

  ThemeData _theme() {
    const seed = Color(0xFF2E6F6E);
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(seedColor: seed, brightness: Brightness.light),
    );
  }
}