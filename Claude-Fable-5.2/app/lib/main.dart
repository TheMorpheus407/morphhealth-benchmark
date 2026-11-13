import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:morphhealth_core/morphhealth_core.dart';

import 'app.dart';
import 'controller.dart';
import 'l10n/strings.dart';
import 'platform/platform_bridge.dart';
import 'ui/theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting();
  runApp(const MorphHealthRoot(platform: MethodChannelPlatformBridge()));
}

/// Opens the encrypted data store and then shows the app.
///
/// While the store is being opened a neutral start screen is shown. If the
/// store cannot be opened (for example because the device no longer has the
/// key), the user gets an explanation and the choice to reset the local data.
class MorphHealthRoot extends StatefulWidget {
  final PlatformBridge platform;

  const MorphHealthRoot({super.key, required this.platform});

  @override
  State<MorphHealthRoot> createState() => _MorphHealthRootState();
}

class _MorphHealthRootState extends State<MorphHealthRoot> {
  AppController? _controller;
  String? _errorCode;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _open();
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  Future<void> _open({bool afterWipe = false}) async {
    final old = _controller;
    setState(() {
      _controller = null;
      _errorCode = null;
    });
    // The old screens are still mounted during this frame.
    if (old != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
    }
    try {
      final directory = Directory(await widget.platform.dataDirectory());
      final key = await widget.platform.loadOrCreateMasterKey();
      final repository = await HealthRepository.open(
        EncryptedFileStore(directory, key),
      );
      if (!mounted) return;
      setState(() {
        _generation++;
        _controller = AppController(
          repository: repository,
          platform: widget.platform,
          restart: () => _open(afterWipe: true),
          afterWipe: afterWipe,
        );
      });
    } on KeyUnavailableException {
      if (mounted) setState(() => _errorCode = 'key');
    } on StoreException catch (e) {
      if (mounted) setState(() => _errorCode = e.code);
    } on FileSystemException {
      if (mounted) setState(() => _errorCode = 'io');
    }
  }

  /// Removes the unreadable store and its key, then starts fresh.
  Future<void> _reset() async {
    try {
      final directory = Directory(await widget.platform.dataDirectory());
      await EncryptedFileStore(directory, List<int>.filled(32, 0)).wipe();
      await widget.platform.resetMasterKey();
    } on Object {
      // Opening again reports what is still wrong.
    }
    await _open(afterWipe: true);
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    if (controller != null) {
      return MorphHealthApp(key: ValueKey(_generation), controller: controller);
    }
    final device = WidgetsBinding.instance.platformDispatcher.locale;
    return MaterialApp(
      title: 'MorphHealth',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      // Before the settings are readable: German, or English on a device set
      // to English.
      locale: device.languageCode == 'en'
          ? const Locale('en', 'GB')
          : const Locale('de'),
      supportedLocales: const [Locale('de'), Locale('en', 'GB')],
      localizationsDelegates: appLocalizationsDelegates,
      home: _errorCode == null
          ? const _OpeningScreen()
          : _ProblemScreen(code: _errorCode!, onRetry: _open, onReset: _reset),
    );
  }
}

class _OpeningScreen extends StatelessWidget {
  const _OpeningScreen();

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 20),
            Text(l.startupOpening),
          ],
        ),
      ),
    );
  }
}

class _ProblemScreen extends StatelessWidget {
  final String code;
  final Future<void> Function() onRetry;
  final Future<void> Function() onReset;

  const _ProblemScreen({
    required this.code,
    required this.onRetry,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context) {
    final l = L.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(
                    Icons.lock_outline,
                    size: 48,
                    color: theme.colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  Semantics(
                    header: true,
                    child: Text(
                      l.startupProblemTitle,
                      style: theme.textTheme.headlineSmall,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    l.startupProblemBody(code),
                    style: theme.textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 24),
                  FilledButton(onPressed: onRetry, child: Text(l.retry)),
                  const SizedBox(height: 8),
                  if (code != 'unsupported')
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.colorScheme.error,
                      ),
                      onPressed: () async {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (context) => AlertDialog(
                            title: Text(l.startupReset),
                            content: Text(l.startupResetConfirm),
                            actions: [
                              TextButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(false),
                                child: Text(l.cancel),
                              ),
                              FilledButton(
                                onPressed: () =>
                                    Navigator.of(context).pop(true),
                                child: Text(l.wipeConfirmAction),
                              ),
                            ],
                          ),
                        );
                        if (ok == true) await onReset();
                      },
                      child: Text(l.startupReset),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
