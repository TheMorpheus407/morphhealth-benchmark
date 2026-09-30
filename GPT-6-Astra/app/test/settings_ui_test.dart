import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphhealth/core/core.dart';
import 'package:morphhealth/ui/settings.dart';
import 'package:morphhealth/ui/shared.dart';

Future<AppModel> _model(WidgetTester tester, String language) async {
  late Store store;
  late Directory dir;
  await tester.runAsync(() async {
    final parent = Directory(
      '${Directory.current.path}/.dart_tool/ui-test-data',
    );
    await parent.create(recursive: true);
    dir = await parent.createTemp('settings-');
    store = Store(dir, List.generate(32, (index) => index));
    await store.open();
    await store.updateSettings({'language': language});
  });
  final model = AppModel(
    store,
    FoodApi(baseUrl: 'https://localhost:8788', userAgent: 'MorphHealth/tests'),
  );
  addTearDown(() async {
    model.dispose();
    await tester.runAsync(() async {
      await store.close();
      await dir.delete(recursive: true);
    });
  });
  return model;
}

Widget _host(AppModel model) => MaterialApp(
  locale: Locale(model.de ? 'de' : 'en'),
  supportedLocales: const [Locale('de'), Locale('en')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates,
  theme: ThemeData(useMaterial3: true),
  home: SettingsPage(model: model),
);

void main() {
  for (final language in ['de', 'en']) {
    testWidgets(
      'file processing stays visible after scrolling and picker cancellation ($language)',
      (tester) async {
        tester.view.physicalSize = const Size(600, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final semantics = tester.ensureSemantics();
        try {
          final model = await _model(tester, language);
          final saveRequested = Completer<void>();
          final saveResult = Completer<bool?>();
          Map<dynamic, dynamic>? arguments;
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(documents, (MethodCall call) async {
                expect(call.method, 'save');
                arguments = call.arguments as Map;
                saveRequested.complete();
                return saveResult.future;
              });
          addTearDown(() {
            if (!saveResult.isCompleted) saveResult.complete(null);
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
                .setMockMethodCallHandler(documents, null);
          });
          await tester.pumpWidget(_host(model));
          await tester.pumpAndSettle();
          final action = language == 'de'
              ? 'Verschlüsselte Sicherung erstellen'
              : 'Full JSON export';
          await tester.scrollUntilVisible(
            find.text(action),
            400,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.pumpAndSettle();
          final scrollPosition = tester
              .state<ScrollableState>(find.byType(Scrollable).first)
              .position;
          final initialOffset = scrollPosition.pixels;
          expect(initialOffset, greaterThan(700));
          await tester.runAsync(() async => tester.tap(find.text(action)));
          await tester.pumpAndSettle();
          if (language == 'de') {
            await tester.enterText(
              find.byType(TextFormField).at(0),
              'Eine lange Testpassphrase',
            );
            await tester.enterText(
              find.byType(TextFormField).at(1),
              'Eine lange Testpassphrase',
            );
            tester.testTextInput.hide();
            await tester.runAsync(() async => tester.tap(find.text('Weiter')));
          } else {
            await tester.runAsync(
              () async => tester.tap(find.text('Export plain text')),
            );
          }
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
          final status = language == 'de'
              ? 'Datei wird verarbeitet …'
              : 'Processing file …';
          expect(find.text(status), findsOneWidget);
          expect(find.byType(CircularProgressIndicator), findsOneWidget);
          expect(find.byType(LinearProgressIndicator), findsNothing);
          final statusRect = tester.getRect(find.text(status));
          expect((statusRect.center.dy - 450).abs(), lessThan(160));
          expect(
            scrollPosition.pixels,
            initialOffset,
            reason:
                'Busy state must not insert list children or shift the viewport',
          );
          expect(
            tester.getSemantics(find.byKey(const ValueKey('file-processing'))),
            matchesSemantics(label: status, isLiveRegion: true),
          );
          expect(
            find.byType(AlertDialog),
            findsNothing,
            reason:
                'Passphrase / confirmation dialog finishes its reverse transition safely',
          );
          expect(tester.takeException(), isNull);
          final deadline = DateTime.now().add(const Duration(seconds: 60));
          while (!saveRequested.isCompleted &&
              DateTime.now().isBefore(deadline)) {
            await tester.runAsync(
              () async =>
                  Future<void>.delayed(const Duration(milliseconds: 50)),
            );
            await tester.pump(const Duration(milliseconds: 16));
          }
          expect(saveRequested.isCompleted, isTrue);
          final payload = jsonDecode(arguments!['content'] as String) as Map;
          expect(
            payload['format'],
            language == 'de' ? 'morphhealth-encrypted' : 'morphhealth',
          );
          await tester.runAsync(() async {
            saveResult.complete(null); // Android document picker Back / Cancel.
            await Future<void>.delayed(const Duration(milliseconds: 20));
          });
          await tester.pumpAndSettle();
          expect(find.text(status), findsNothing);
          expect(find.byType(CircularProgressIndicator), findsNothing);
          expect(scrollPosition.pixels, initialOffset);
          expect(
            tester
                .widget<AbsorbPointer>(find.byType(AbsorbPointer).first)
                .absorbing,
            isFalse,
          );
          expect(
            find.text(language == 'de' ? 'Datei gespeichert.' : 'File saved.'),
            findsNothing,
          );
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      },
    );
  }
}
