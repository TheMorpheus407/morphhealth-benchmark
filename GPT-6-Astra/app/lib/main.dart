import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'core/core.dart';
import 'ui/shared.dart';
import 'ui/shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    const vault = FlutterSecureStorage(
      aOptions: AndroidOptions(resetOnError: false),
    );
    final dir = await getApplicationSupportDirectory();
    final saved = await vault.read(key: 'morphhealth-data-key');
    // Never silently replace an existing vault's lost key.
    if (saved == null &&
        await Directory('${dir.path}/vault').exists() &&
        !await Directory('${dir.path}/vault').list().isEmpty) {
      throw StateError(
        'Der Geräteschlüssel fehlt. Vorhandene Daten wurden nicht verändert. / Device key missing. Existing data was preserved.',
      );
    }
    final bytes = saved == null
        ? List<int>.generate(32, (_) => Random.secure().nextInt(256))
        : base64Decode(saved);
    if (saved == null) {
      await vault.write(
        key: 'morphhealth-data-key',
        value: base64Encode(bytes),
      );
    }
    final store = Store(Directory('${dir.path}/vault'), bytes);
    await store.open();
    final api = FoodApi(
      baseUrl: const String.fromEnvironment(
        'FOOD_API_BASE_URL',
        defaultValue: 'https://world.openfoodfacts.org',
      ),
      userAgent: const String.fromEnvironment(
        'FOOD_API_USER_AGENT',
        defaultValue: 'MorphHealth/1.0 (Android)',
      ),
    );
    runApp(MorphHealth(model: AppModel(store, api)));
  } catch (e) {
    runApp(
      MaterialApp(
        home: Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.lock_outline, size: 48),
                  const SizedBox(height: 24),
                  const Text('MorphHealth', style: TextStyle(fontSize: 30)),
                  const SizedBox(height: 16),
                  const Text(
                    'Der lokale Datenspeicher konnte nicht geöffnet werden. Die vorhandenen Daten bleiben erhalten. Starte die App erneut.\n\nThe local vault could not be opened. Existing data is preserved. Please restart the app.',
                  ),
                  const SizedBox(height: 20),
                  SelectableText(e.toString()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MorphHealth extends StatelessWidget {
  const MorphHealth({super.key, required this.model});
  final AppModel model;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: model,
    builder: (context, _) => MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'MorphHealth',
      locale: Locale(model.de ? 'de' : 'en'),
      supportedLocales: const [Locale('de'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: ink,
          brightness: Brightness.light,
        ).copyWith(primary: ink, secondary: terracotta, surface: cream),
        scaffoldBackgroundColor: cream,
        appBarTheme: const AppBarTheme(
          backgroundColor: cream,
          foregroundColor: ink,
          centerTitle: false,
          scrolledUnderElevation: 0,
        ),
        textTheme: const TextTheme(
          headlineLarge: TextStyle(
            fontSize: 34,
            fontWeight: FontWeight.w600,
            letterSpacing: -1.2,
            color: ink,
          ),
          headlineMedium: TextStyle(
            fontSize: 28,
            fontWeight: FontWeight.w600,
            letterSpacing: -.7,
            color: ink,
          ),
          headlineSmall: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w500,
            color: ink,
          ),
          titleLarge: TextStyle(
            fontSize: 21,
            fontWeight: FontWeight.w600,
            color: ink,
          ),
          titleMedium: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: ink,
          ),
          bodyLarge: TextStyle(fontSize: 16, color: ink),
          bodyMedium: TextStyle(fontSize: 14, height: 1.45, color: ink),
        ),
        inputDecorationTheme: InputDecorationTheme(
          filled: true,
          fillColor: Colors.white,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFD8E0D8)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: Color(0xFFD8E0D8)),
          ),
        ),
        navigationBarTheme: NavigationBarThemeData(
          backgroundColor: cream,
          indicatorColor: mint,
          labelTextStyle: WidgetStateProperty.all(
            const TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            minimumSize: const Size(48, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
        ),
        outlinedButtonTheme: OutlinedButtonThemeData(
          style: OutlinedButton.styleFrom(minimumSize: const Size(48, 48)),
        ),
        chipTheme: ChipThemeData(
          side: BorderSide.none,
          backgroundColor: mint,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      home: AppShell(model: model),
    ),
  );
}
