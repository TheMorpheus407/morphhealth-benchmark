// Widget-Smoke-Tests: App-Shell rendert mit In-Memory-Repository (kein
// Datei-/Plugin-Zugriff nötig) und zeigt Overview + alle vier Bereiche.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphhealth/src/core/exceptions.dart';
import 'package:morphhealth/src/data/repository.dart';
import 'package:morphhealth/src/food/off_client.dart';
import 'package:morphhealth/src/model/document.dart';
import 'package:morphhealth/src/ui/app.dart';
import 'package:morphhealth/src/ui/bootstrap.dart';

import 'helpers.dart';

/// Baut die App mit einem geladenen In-Memory-Repository.
Future<Bootstrap> makeBootstrap({MorphRepository? repo}) async {
  final MorphRepository r = repo ?? await makeRepo();
  return Bootstrap(
    repository: r,
    offConfig: const OffConfig(
        baseUrl: 'https://foodapi.example', userAgent: 'MorphHealth/1.0 (test)'),
    appInfo: const AppInfo(name: 'MorphHealth', version: '1.0.0+1'),
  );
}

void main() {
  testWidgets('Home-Shell rendert Übersicht und alle vier Bereiche',
      (WidgetTester tester) async {
    // Ohne gesetzte Spracheinstellung folgt die App der System-Locale
    // (im Test standardmäßig en) — hier bewusst Deutsch.
    tester.platformDispatcher.localeTestValue = const Locale('de');
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);
    // Großzügige Testfläche: Die Lazy-Listen der Bereichsansichten bauen so
    // ihre kompletten Inhalte (inkl. Leerzustände) ohne Scrollen auf.
    tester.view.physicalSize = const Size(800, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final Bootstrap bootstrap = await makeBootstrap();
    await tester.pumpWidget(MorphHealthApp(bootstrap: bootstrap));
    await tester.pumpAndSettle();

    // App-Bar zeigt den App-Namen, Übersicht die heutige Sektion.
    expect(find.text('MorphHealth'), findsWidgets);
    expect(find.text('Heute'), findsOneWidget);
    // Karten der sichtbaren Bereiche.
    expect(find.text('Ernährung heute'), findsOneWidget);
    expect(find.text('Zyklus heute'), findsOneWidget);
    expect(find.text('Symptome heute'), findsOneWidget);

    // Bottom-Navigation: Übersicht + 4 Bereiche.
    expect(find.text('Übersicht'), findsOneWidget);
    expect(find.text('Ernährung'), findsWidgets);
    expect(find.text('Zyklus'), findsWidgets);
    expect(find.text('Gewicht'), findsWidgets);
    expect(find.text('Symptome'), findsWidgets);

    // Bereich wechseln: Ernährung zeigt je Mahlzeit den leeren-Tag-Hinweis
    // (Frühstück, Mittagessen, Abendessen, Snack).
    await tester.tap(find.text('Ernährung').last);
    await tester.pumpAndSettle();
    expect(find.text('An diesem Tag ist noch nichts eingetragen.'),
        findsNWidgets(4));

    // Zyklus-Bereich: Monatskalender + Leerzustand (Prognose-Karte und
    // Historie zeigen denselben Hinweis).
    await tester.tap(find.text('Zyklus').last);
    await tester.pumpAndSettle();
    expect(find.byType(GridView), findsOneWidget);
    expect(
        find.text(
            'Noch keine Perioden erfasst. Trage deine erste Periode ein.'),
        findsNWidgets(2));

    // Gewicht-Bereich: Leerzustand in aktueller Wert + Historie.
    await tester.tap(find.text('Gewicht').last);
    await tester.pumpAndSettle();
    expect(find.text('Noch keine Gewichtseinträge.'), findsNWidgets(2));

    // Symptome-Bereich.
    await tester.tap(find.text('Symptome').last);
    await tester.pumpAndSettle();
    expect(find.text('Noch keine Symptome erfasst.'), findsOneWidget);

    // Aufräumen: Widget-Baum abbauen (disposet Repository + Timer).
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('sichtbare Bereiche ausblendbar (nur Ernährung)',
      (WidgetTester tester) async {
    tester.platformDispatcher.localeTestValue = const Locale('de');
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);
    final MorphRepository repo = await makeRepo();
    await repo.updateSettings((s) {
      s.visibleAreas = <String>['nutrition'];
      return s;
    });
    final Bootstrap bootstrap = await makeBootstrap(repo: repo);
    await tester.pumpWidget(MorphHealthApp(bootstrap: bootstrap));
    await tester.pumpAndSettle();

    expect(find.text('Ernährung heute'), findsOneWidget);
    expect(find.text('Zyklus heute'), findsNothing);
    expect(find.text('Symptome heute'), findsNothing);
    // Navigation: Übersicht + Ernährung.
    expect(find.text('Übersicht'), findsOneWidget);
    expect(find.text('Ernährung'), findsWidgets);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('Fehlerbildschirm bei nicht lesbarem Datenbestand',
      (WidgetTester tester) async {
    tester.platformDispatcher.localeTestValue = const Locale('de');
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);
    final Bootstrap bootstrap = Bootstrap(
      repository: null,
      offConfig: const OffConfig(
          baseUrl: 'https://foodapi.example', userAgent: 'MorphHealth/1.0 (test)'),
      appInfo: const AppInfo(name: 'MorphHealth', version: '1.0.0+1'),
      error: MorphException('store.unreadable', 'Testfehler'),
    );
    await tester.pumpWidget(MorphHealthApp(bootstrap: bootstrap));
    await tester.pumpAndSettle();

    expect(find.text('Datenbestand nicht lesbar'), findsOneWidget);
    expect(find.text('Erneut versuchen'), findsOneWidget);
    expect(find.textContaining('Testfehler'), findsOneWidget);
  });

  // Regression: Per Navigator.push geöffnete Routen müssen StringsScope und
  // MorphScope oberhalb von MaterialApp erreichen (früher Null-Check-Fehler).
  testWidgets('per Navigator.push geöffnete Lebensmittel-Suche erreichbar',
      (WidgetTester tester) async {
    tester.platformDispatcher.localeTestValue = const Locale('de');
    addTearDown(tester.platformDispatcher.clearLocaleTestValue);
    tester.view.physicalSize = const Size(800, 3200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final Bootstrap bootstrap = await makeBootstrap();
    await tester.pumpWidget(MorphHealthApp(bootstrap: bootstrap));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ernährung').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Verzehr hinzufügen'));
    await tester.pumpAndSettle();

    // Die gepushte Route baut ohne Scope-Fehler und zeigt ihren Titel.
    expect(find.text('Lebensmittel suchen'), findsOneWidget);
    expect(find.text('Name oder Barcode eingeben'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}
