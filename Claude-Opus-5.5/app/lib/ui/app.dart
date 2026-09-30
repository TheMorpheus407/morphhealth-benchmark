import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import '../core/food/off_client.dart';
import '../core/l10n/strings.dart';
import '../core/model/enums.dart';
import '../core/service/morphhealth_service.dart';
import '../core/service/repository.dart';
import '../core/storage/encrypted_store.dart';
import '../core/util/clock.dart';
import 'controller.dart';
import 'platform/platform_bridge.dart';
import 'screens/home_shell.dart';
import 'screens/onboarding_screen.dart';
import 'theme.dart';

/// Food database settings of this build (`--dart-define`, see build.sh).
const String buildFoodApiBaseUrl = String.fromEnvironment(
  'FOOD_API_BASE_URL',
  defaultValue: defaultFoodApiBaseUrl,
);
const String buildFoodApiUserAgent = String.fromEnvironment(
  'FOOD_API_USER_AGENT',
  defaultValue: defaultFoodApiUserAgent,
);

/// Opens the encrypted store for the app. Separated for tests.
typedef RepositoryOpener = Future<Repository> Function(PlatformBridge platform);

Future<Repository> openAppRepository(PlatformBridge platform) async {
  final dir = Directory('${await platform.dataDirectory()}/morphhealth_store');
  final key = await platform.loadMasterKey();
  return Repository.open(
    directory: dir,
    masterKey: key,
    clock: const SystemClock(),
    encoder: encodeSnapshotInBackground,
    decoder: decodeSnapshotInBackground,
  );
}

class MorphHealthApp extends StatefulWidget {
  const MorphHealthApp({
    super.key,
    this.platform = const PlatformBridge(),
    this.openRepository = openAppRepository,
    this.foodApi,
    this.resetStorage,
  });

  final PlatformBridge platform;
  final RepositoryOpener openRepository;
  final FoodApiConfig? foodApi;

  /// Deletes all local data and the key; defaults to the platform version.
  final Future<void> Function()? resetStorage;

  @override
  State<MorphHealthApp> createState() => _MorphHealthAppState();
}

class _MorphHealthAppState extends State<MorphHealthApp> {
  final _messengerKey = GlobalKey<ScaffoldMessengerState>();
  AppController? _controller;
  Object? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final repo = await widget.openRepository(widget.platform);
      final service = MorphHealthService(
        repo: repo,
        clock: const SystemClock(),
        defaultFoodApi:
            widget.foodApi ?? FoodApiConfig(buildFoodApiBaseUrl, buildFoodApiUserAgent),
      );
      final controller = AppController(
        service: service,
        platform: widget.platform,
        messengerKey: _messengerKey,
        onResetRequested: _reset,
      );
      controller.addListener(_onControllerChanged);
      setState(() {
        _controller = controller;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e;
        _loading = false;
      });
    }
  }

  (AppLanguage, bool)? _rootState;

  /// Rebuilds the root only when language or onboarding state change.
  void _onControllerChanged() {
    final c = _controller;
    if (c == null) return;
    final state = (c.settings.language, c.service.repo.device.onboardingCompleted);
    if (state != _rootState) setState(() => _rootState = state);
  }

  Future<void> _defaultReset() async {
    final dir = Directory('${await widget.platform.dataDirectory()}/morphhealth_store');
    await EncryptedStore.destroyFiles(dir);
    await widget.platform.destroyMasterKey();
  }

  /// Deletes everything (store files and key) and starts again.
  Future<void> _reset() async {
    final controller = _controller;
    setState(() {
      _controller = null;
      _loading = true;
    });
    if (controller != null) {
      controller.removeListener(_onControllerChanged);
      await controller.service.repo.close();
      controller.dispose();
    }
    await (widget.resetStorage ?? _defaultReset)();
    await _load();
  }

  @override
  void dispose() {
    _controller?.removeListener(_onControllerChanged);
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final language = controller?.settings.language ?? AppLanguage.de;
    Widget home;
    if (controller != null) {
      home = controller.service.repo.device.onboardingCompleted
          ? const HomeShell()
          : const OnboardingScreen();
    } else if (_loading) {
      home = const _Splash();
    } else {
      home = _StoreErrorScreen(error: _error!, onRetry: _load, onReset: _reset);
    }
    final app = MaterialApp(
      title: 'MorphHealth',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: _messengerKey,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      locale: Locale(language.json),
      supportedLocales: const [Locale('de'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      home: home,
    );
    if (controller == null) return app;
    return AppScope(controller: controller, child: app);
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Semantics(
          label: 'MorphHealth',
          child: const CircularProgressIndicator(),
        ),
      ),
    );
  }
}

class _StoreErrorScreen extends StatelessWidget {
  const _StoreErrorScreen({
    required this.error,
    required this.onRetry,
    required this.onReset,
  });

  final Object error;
  final VoidCallback onRetry;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode == 'en'
        ? AppLanguage.en
        : AppLanguage.de;
    final s = S.of(lang);
    final code = error is StoreException ? (error as StoreException).code : 'store_io_error';
    return Scaffold(
      appBar: AppBar(title: Text(s.storeErrorTitle)),
      body: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          Icon(Icons.lock_outline, size: 48, color: context.scheme.error),
          const SizedBox(height: 16),
          Text(s.storeErrorText(code), style: context.text.bodyLarge),
          const SizedBox(height: 8),
          Text('$error', style: context.text.bodySmall),
          const SizedBox(height: 24),
          FilledButton(onPressed: onRetry, child: Text(s.retry)),
          const SizedBox(height: 12),
          OutlinedButton(
            onPressed: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: Text(s.resetStore),
                  content: Text(s.deleteAllConfirm),
                  actions: [
                    TextButton(onPressed: () => Navigator.pop(context, false), child: Text(s.cancel)),
                    FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(s.delete)),
                  ],
                ),
              );
              if (confirmed == true) onReset();
            },
            child: Text(s.resetStore),
          ),
        ],
      ),
    );
  }
}
