// App-Wurzel: MaterialApp mit Theme, Lokalisierung und Scopes; behandelt den
// Fall eines nicht lesbaren Datenbestands (Wiederherstellungsbildschirm).
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/exceptions.dart';
import '../data/repository.dart';
import '../food/off_client.dart';
import '../l10n/app_strings.dart';
import 'bootstrap.dart';
import 'home_shell.dart';
import 'scope.dart';

const Color _seedColor = Color(0xFF1F6F5C); // ruhiges Teal

ThemeData _lightTheme() => ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _seedColor,
        brightness: Brightness.light,
      ),
    );

ThemeData _darkTheme() => ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _seedColor,
        brightness: Brightness.dark,
      ),
    );

const List<Locale> _supportedLocales = <Locale>[Locale('de'), Locale('en')];

const List<LocalizationsDelegate<dynamic>> _delegates =
    <LocalizationsDelegate<dynamic>>[
  GlobalMaterialLocalizations.delegate,
  GlobalWidgetsLocalizations.delegate,
  GlobalCupertinoLocalizations.delegate,
];

/// Wurzel-Widget der App.
class MorphHealthApp extends StatefulWidget {
  final Bootstrap bootstrap;
  const MorphHealthApp({super.key, required this.bootstrap});

  @override
  State<MorphHealthApp> createState() => _MorphHealthAppState();
}

class _MorphHealthAppState extends State<MorphHealthApp>
    with WidgetsBindingObserver {
  late Bootstrap _bootstrap;
  RepoListenable? _listenable;
  OffClient? _off;
  String? _lastLang;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _bootstrap = widget.bootstrap;
    WidgetsBinding.instance.addObserver(this);
    _attach();
  }

  void _attach() {
    final MorphRepository? repo = _bootstrap.repository;
    if (repo == null) return;
    _listenable ??= RepoListenable(repo);
    _off ??= OffClient(_bootstrap.offConfig);
    repo.addListener(_onRepoChanged);
    _lastLang = repo.settings.language;
  }

  void _onRepoChanged() {
    final MorphRepository? repo = _bootstrap.repository;
    if (repo == null) return;
    final String? lang = repo.settings.language;
    if (lang != _lastLang) {
      // Sprachwechsel: komplettes MaterialApp neu bauen (Locale + Texte).
      _lastLang = lang;
      if (mounted) setState(() {});
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      // Verzögerte Schreibzugriffe sofort persistieren, wenn die App pausiert.
      _bootstrap.repository?.persistNow();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    final MorphRepository? repo = _bootstrap.repository;
    if (repo != null) {
      repo.removeListener(_onRepoChanged);
      unawaited(repo.dispose());
    }
    _listenable?.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    if (_busy) return;
    setState(() => _busy = true);
    final Bootstrap next = await bootstrapApp();
    if (!mounted) return;
    _swapBootstrap(next);
  }

  Future<void> _deleteAndReload() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final Directory? dataDir = _bootstrap.dataDir;
      if (dataDir != null && await dataDir.exists()) {
        await dataDir.delete(recursive: true);
      }
    } catch (_) {
      // Löschfehler werden vom erneuten Bootstrap gemeldet.
    }
    final Bootstrap next = await bootstrapApp();
    if (!mounted) return;
    _swapBootstrap(next);
  }

  /// Tauscht den Bootstrap aus und hängt die Listener an das neue Repository.
  void _swapBootstrap(Bootstrap next) {
    final MorphRepository? oldRepo = _bootstrap.repository;
    if (oldRepo != null && oldRepo != next.repository) {
      oldRepo.removeListener(_onRepoChanged);
      unawaited(oldRepo.dispose());
    }
    _listenable?.dispose();
    _listenable = null;
    _off = null;
    setState(() {
      _bootstrap = next;
      _busy = false;
    });
    _attach();
  }

  String _resolveLang(MorphRepository repo) {
    final String? setting = repo.settings.language;
    if (setting != null) return normalizeLanguage(setting);
    final String sys =
        WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    return normalizeLanguage(sys);
  }

  @override
  Widget build(BuildContext context) {
    final MorphRepository? repo = _bootstrap.repository;
    if (repo == null || _listenable == null || _off == null) {
      final AppStrings strings = stringsFor(null);
      // Scopes oberhalb von MaterialApp: auch per Navigator.push geöffnete
      // Routen und Dialoge müssen StringsScope/MorphScope erreichen können.
      return StringsScope(
        strings: strings,
        child: MaterialApp(
          title: 'MorphHealth',
          locale: const Locale('de'),
          supportedLocales: _supportedLocales,
          localizationsDelegates: _delegates,
          theme: _lightTheme(),
          darkTheme: _darkTheme(),
          home: StoreErrorScreen(
            error: _bootstrap.error,
            busy: _busy,
            onRetry: _reload,
            onDeleteAndRetry: _deleteAndReload,
          ),
        ),
      );
    }
    final String lang = _resolveLang(repo);
    return MorphScope(
      repo: repo,
      listenable: _listenable!,
      off: _off!,
      appInfo: _bootstrap.appInfo,
      child: StringsScope(
        strings: stringsFor(lang),
        child: MaterialApp(
          title: 'MorphHealth',
          locale: Locale(lang),
          supportedLocales: _supportedLocales,
          localizationsDelegates: _delegates,
          theme: _lightTheme(),
          darkTheme: _darkTheme(),
          home: const HomeShell(),
        ),
      ),
    );
  }
}

/// Bildschirm bei nicht lesbarem Datenbestand (z. B. beschädigte Datei).
class StoreErrorScreen extends StatelessWidget {
  final MorphException? error;
  final bool busy;
  final Future<void> Function() onRetry;
  final Future<void> Function() onDeleteAndRetry;

  const StoreErrorScreen({
    super.key,
    required this.error,
    required this.busy,
    required this.onRetry,
    required this.onDeleteAndRetry,
  });

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = StringsScope.of(context);
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Icon(Icons.lock_outline, size: 56, color: theme.colorScheme.error),
              const SizedBox(height: 16),
              Text(strings.storeErrorTitle,
                  style: theme.textTheme.headlineSmall,
                  textAlign: TextAlign.center),
              const SizedBox(height: 8),
              Text(
                '${strings.storeErrorMessage}\n${error?.message ?? ''}',
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: busy ? null : () => unawaited(onRetry()),
                icon: const Icon(Icons.refresh),
                label: Text(strings.storeErrorRetry),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: busy ? null : () => unawaited(_confirmDelete(context)),
                icon: const Icon(Icons.delete_forever),
                label: Text(strings.storeErrorDelete),
              ),
              if (busy) ...<Widget>[
                const SizedBox(height: 16),
                const LinearProgressIndicator(),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final AppStrings strings = StringsScope.of(context);
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(strings.deleteAllTitle),
        content: Text(strings.deleteAllConfirm),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(strings.delete),
          ),
        ],
      ),
    );
    if (ok == true && context.mounted) {
      await onDeleteAndRetry();
    }
  }
}
