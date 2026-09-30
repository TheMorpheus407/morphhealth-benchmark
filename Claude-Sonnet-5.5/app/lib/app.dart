import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'l10n/gen/app_localizations.dart';
import 'state/app_state.dart';
import 'state/boot.dart';
import 'ui/boot_failure_screen.dart';
import 'ui/home_shell.dart';
import 'ui/theme.dart';

/// Wurzel der App: wartet auf den Start des Datenbestands und zeigt danach die
/// Oberfläche oder den Wiederherstellungsbildschirm.
class MorphHealthApp extends StatefulWidget {
  final Future<BootResult> boot;

  const MorphHealthApp({super.key, required this.boot});

  @override
  State<MorphHealthApp> createState() => _MorphHealthAppState();
}

/// Räumt Meldungen beim Öffnen eines neuen Bildschirms oder Blatts weg, damit
/// sie dessen Bedienelemente nicht verdecken.
class _ClearSnackBars extends NavigatorObserver {
  final GlobalKey<ScaffoldMessengerState> key;

  _ClearSnackBars(this.key);

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    key.currentState?.clearSnackBars();
  }
}

class _MorphHealthAppState extends State<MorphHealthApp> {
  final GlobalKey<ScaffoldMessengerState> _messengerKey = GlobalKey<ScaffoldMessengerState>();
  late final _ClearSnackBars _observer = _ClearSnackBars(_messengerKey);
  AppState? _state;
  BootFailure? _failure;
  bool _lastSecure = false;

  @override
  void initState() {
    super.initState();
    widget.boot.then(_onBoot);
  }

  void _onBoot(BootResult r) {
    if (!mounted) return;
    setState(() {
      switch (r) {
        case BootOk():
          _failure = null;
          _state = AppState(r.core, r.session)..addListener(_syncPlatform);
          _syncPlatform();
        case BootFailure():
          _failure = r;
      }
    });
  }

  /// Übernimmt die Einstellung "Bildschirmaufnahmen sperren" in Android.
  void _syncPlatform() {
    final s = _state;
    if (s == null) return;
    final want = s.settings.secureScreen;
    if (want != _lastSecure) {
      _lastSecure = want;
      s.session.platform.setSecure(want).catchError((Object _) {});
    }
  }

  Future<void> _retry() async {
    setState(() => _failure = null);
    _onBoot(await boot());
  }

  @override
  void dispose() {
    _state?.removeListener(_syncPlatform);
    _state?.dispose();
    super.dispose();
  }

  MaterialApp _app({required Widget home, required Locale locale, ThemeMode mode = ThemeMode.system}) => MaterialApp(
    onGenerateTitle: (c) => AppLocalizations.of(c).appName,
    debugShowCheckedModeBanner: false,
    scaffoldMessengerKey: _messengerKey,
    navigatorObservers: [_observer],
    // Im Querformat liegt die Navigationsleiste des Systems seitlich; der
    // Inhalt bleibt links und rechts davon.
    builder: (context, child) => SafeArea(top: false, bottom: false, child: child ?? const SizedBox.shrink()),
    theme: buildTheme(Brightness.light),
    darkTheme: buildTheme(Brightness.dark),
    themeMode: mode,
    locale: locale,
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  );

  @override
  Widget build(BuildContext context) {
    final state = _state;
    if (state == null) {
      return _app(
        locale: const Locale('de'),
        home: _failure != null
            ? BootFailureScreen(failure: _failure!, onRetry: _retry, onRecovered: _onBoot)
            : const _Splash(),
      );
    }
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) => AppScope(
        state: state,
        child: _app(
          locale: state.locale,
          mode: switch (state.settings.theme) {
            'light' => ThemeMode.light,
            'dark' => ThemeMode.dark,
            _ => ThemeMode.system,
          },
          home: const HomeShell(),
        ),
      ),
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Scaffold(
      body: Center(
        child: Semantics(label: l.bootLoading, child: const CircularProgressIndicator()),
      ),
    );
  }
}
