import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphhealth/platform/platform_bridge.dart';
import 'package:morphhealth/ui/cycle/forecast_card.dart';
import 'package:morphhealth/ui/onboarding/welcome_screen.dart';
import 'package:morphhealth/ui/settings/data_screen.dart';
import 'package:morphhealth/ui/settings/settings_screen.dart';
import 'package:morphhealth_core/morphhealth_core.dart';
import 'package:morphhealth_core/src/portable/example_document.dart';

import 'support.dart';

const passphrase = 'richtig langes Geheimnis';

Future<void> openData(WidgetTester tester) async {
  await tapTooltip(tester, 'Einstellungen');
  await tapText(tester, 'Daten');
  expect(find.byType(DataScreen), findsOneWidget);
}

/// The export without the moment it was written.
Map<String, dynamic> content(Map<String, dynamic> document) =>
    Map.of(document)..remove('exported_at');

Map<String, dynamic> currentContent(TestApp app) =>
    content(app.controller.portable.exportDocument());

Uint8List utf8Bytes(String text) => Uint8List.fromList(utf8.encode(text));

/// A backup of the example data. The key derivation pauses with timers, so
/// outside the app's own flows it has to run in real time.
Future<Uint8List> sealedExample(WidgetTester tester) async =>
    (await tester.runAsync(
      () => const FastBackups().seal(exampleDocument(), passphrase, testNow),
    ))!;

Future<void> enterDialogText(WidgetTester tester, String text) async {
  await tester.enterText(
    find.descendant(
      of: find.byType(AlertDialog),
      matching: find.byType(TextField),
    ),
    text,
  );
  await tester.tap(find.widgetWithText(FilledButton, 'Speichern'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('export and import: complete copy, checked and confirmed', (
    tester,
  ) async {
    final app = await pumpApp(tester, data: exampleData());
    final before = currentContent(app);
    await openData(tester);
    expect(find.text('Verzehreinträge: 7'), findsOneWidget);
    expect(find.text('Perioden: 8'), findsOneWidget);

    // The export warns about plain text; declining writes nothing.
    await tapText(tester, 'Daten exportieren');
    expect(find.text('Unverschlüsselter Export'), findsOneWidget);
    expect(find.textContaining('im Klartext'), findsOneWidget);
    await tapText(tester, 'Abbrechen');
    expect(app.platform.savedDocuments, isEmpty);

    await tapText(tester, 'Daten exportieren');
    await tapText(tester, 'Unverschlüsselt exportieren');
    final name = app.platform.savedDocuments.keys.single;
    expect(name, 'morphhealth-export-2026-09-23.json');
    expect(find.text('Gespeichert: $name'), findsOneWidget);
    final bytes = app.platform.savedDocuments[name]!;
    final document = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    expect(
      (document['format'], document['version']),
      ('morphhealth-export', 1),
    );
    expect(content(document), before);

    // Change the data, then bring the export back.
    await app.repository.deletePeriod('period-2026-09-16');
    await app.repository.addWater(500);
    await app.repository.updateSettings(
      app.data.settings.copyWith(weightUnit: 'lb'),
    );
    await tester.pumpAndSettle();
    expect(find.text('Perioden: 7'), findsOneWidget);

    app.platform.nextOpen = PickedDocument(name, bytes);
    await tapText(tester, 'Daten importieren');
    expect(find.text('Import prüfen'), findsOneWidget);
    expect(find.text(name), findsOneWidget);
    expect(find.text('Perioden: 8'), findsOneWidget, reason: 'in the file');
    expect(find.text('Wassereinträge: 6'), findsWidgets, reason: 'stored now');
    expect(find.textContaining('ersetzt alle Daten'), findsOneWidget);
    await tapText(tester, 'Abbrechen');
    expect(app.data.periodCount, 7, reason: 'cancelled: nothing changed');

    await tapText(tester, 'Daten importieren');
    await tapText(tester, 'Alles ersetzen');
    expect(find.text('Import abgeschlossen: 36 Einträge'), findsOneWidget);
    expect(currentContent(app), before);
    expect(find.text('Perioden: 8'), findsOneWidget);
  });

  testWidgets('a file that does not fit is refused and changes nothing', (
    tester,
  ) async {
    final app = await pumpApp(tester, data: exampleData());
    final before = currentContent(app);
    await openData(tester);

    final example = exampleDocument();
    final broken = jsonDecode(jsonEncode(example)) as Map<String, dynamic>;
    ((broken['weights'] as List).first as Map)['weight_kg'] = -5;
    final files = <String, String>{
      'no JSON': 'das ist kein JSON',
      'another format': '{"format":"etwas-anderes","version":1}',
      'a newer version': jsonEncode({...example, 'version': 99}),
      'one invalid entry': jsonEncode(broken),
      'a list': '[1,2,3]',
    };
    for (final file in files.entries) {
      app.platform.nextOpen = PickedDocument(
        'datei.json',
        utf8Bytes(file.value),
      );
      await tapText(tester, 'Daten importieren');
      expect(
        find.text('Die Datei kann nicht importiert werden'),
        findsOneWidget,
        reason: file.key,
      );
      expect(
        find.textContaining('Es wurde nichts geändert.'),
        findsOneWidget,
        reason: file.key,
      );
      await tapText(tester, 'Schließen');
      expect(currentContent(app), before, reason: file.key);
    }

    // Picking nothing is no error.
    app.platform.nextOpen = null;
    await tapText(tester, 'Daten importieren');
    expect(find.byType(AlertDialog), findsNothing);
  });

  testWidgets('encrypted backup: passphrase rules, restore, wrong passphrase', (
    tester,
  ) async {
    final app = await pumpApp(tester, data: exampleData());
    final before = currentContent(app);
    await openData(tester);

    await tapText(tester, 'Verschlüsselte Sicherung erstellen');
    final first = find.widgetWithText(TextFormField, 'Passphrase');
    final second = find.widgetWithText(TextFormField, 'Passphrase wiederholen');
    await tester.enterText(first, 'kurz');
    await tester.enterText(second, 'kurz');
    await tapText(tester, 'Sicherung erstellen');
    expect(find.text('Mindestens 8 Zeichen'), findsOneWidget);
    await tester.enterText(first, passphrase);
    await tester.enterText(second, 'etwas anderes Langes');
    await tapText(tester, 'Sicherung erstellen');
    expect(
      find.text('Die beiden Eingaben stimmen nicht überein'),
      findsOneWidget,
    );
    expect(app.platform.savedDocuments, isEmpty);
    await tester.enterText(second, passphrase);
    await tapText(tester, 'Sicherung erstellen');

    final name = app.platform.savedDocuments.keys.single;
    expect(name, 'morphhealth-2026-09-23.mhbackup');
    expect(find.text('Gespeichert: $name'), findsOneWidget);
    final bytes = app.platform.savedDocuments[name]!;
    final text = latin1.decode(bytes);
    for (final secret in [
      'Haferflocken',
      'Kopfschmerzen',
      'period',
      passphrase,
    ]) {
      expect(text, isNot(contains(secret)));
    }
    expect(BackupCodec.readHeader(bytes).createdAt!.day, testNow.day);

    // Lose everything, then restore.
    await app.repository.replaceAll(AppData());
    await tester.pumpAndSettle();
    expect(find.text('Perioden: 0'), findsOneWidget);

    app.platform.nextOpen = PickedDocument(name, bytes);
    await tapText(tester, 'Sicherung wiederherstellen');
    final field = find.widgetWithText(TextFormField, 'Passphrase');
    await tester.enterText(field, 'falsches Geheimnis');
    await tapText(tester, 'Sicherung öffnen');
    expect(
      find.text('Die Passphrase passt nicht zu dieser Sicherung.'),
      findsOneWidget,
    );
    expect(app.data.periodCount, 0);

    await tester.enterText(field, passphrase);
    await tapText(tester, 'Sicherung öffnen');
    expect(find.text('Sicherung vom 23. Sept. 2026'), findsOneWidget);
    expect(find.text('Perioden: 8'), findsOneWidget);
    await tapText(tester, 'Alles ersetzen');
    expect(find.text('Die Sicherung wurde wiederhergestellt.'), findsOneWidget);
    expect(currentContent(app), before);
  });

  testWidgets('a damaged or foreign backup file is refused', (tester) async {
    final app = await pumpApp(tester, data: exampleData());
    final before = currentContent(app);
    final sealed = await sealedExample(tester);
    await openData(tester);

    app.platform.nextOpen = PickedDocument(
      'notiz.txt',
      utf8Bytes('keine Sicherung'),
    );
    await tapText(tester, 'Sicherung wiederherstellen');
    expect(
      find.text('Die Datei ist keine MorphHealth-Sicherung.'),
      findsOneWidget,
    );

    // One changed byte in the encrypted part.
    final damaged = Uint8List.fromList(sealed);
    final envelope = jsonDecode(utf8.decode(damaged)) as Map<String, dynamic>;
    final cipher = envelope['data'] as String;
    envelope['data'] = '${cipher[0] == 'A' ? 'B' : 'A'}${cipher.substring(1)}';
    app.platform.nextOpen = PickedDocument(
      'x.mhbackup',
      utf8Bytes(jsonEncode(envelope)),
    );
    await tapText(tester, 'Sicherung wiederherstellen');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Passphrase'),
      passphrase,
    );
    await tapText(tester, 'Sicherung öffnen');
    // A changed file cannot be told from a wrong passphrase.
    expect(
      find.text('Die Passphrase passt nicht zu dieser Sicherung.'),
      findsOneWidget,
    );
    await tapText(tester, 'Abbrechen');
    expect(currentContent(app), before);
  });

  testWidgets('delete everything: explicit confirmation, key destroyed', (
    tester,
  ) async {
    final app = await pumpApp(tester, data: exampleData());
    await openData(tester);

    await tapText(tester, 'Alle Daten löschen');
    expect(find.text('Wirklich alles löschen?'), findsOneWidget);
    expect(find.textContaining('nicht rückgängig'), findsOneWidget);
    final delete = find.widgetWithText(FilledButton, 'Alles löschen');
    expect(
      tester.widget<FilledButton>(delete).onPressed,
      isNull,
      reason: 'only after ticking the box',
    );
    await tapText(tester, 'Abbrechen');
    expect(app.data.periodCount, 8);
    expect(app.platform.keyResets, 0);

    await tapText(tester, 'Alle Daten löschen');
    await tester.tap(find.byType(Checkbox));
    await tester.pumpAndSettle();
    await tester.tap(delete);
    await tester.pumpAndSettle();
    expect(app.data.isEmpty, isTrue);
    expect(app.controller.local.onboardingDone, isFalse);
    expect(app.platform.keyResets, 1);
    expect(app.restarts, 1);
  });

  testWidgets('settings: language, appearance, unit, areas', (tester) async {
    final app = await pumpApp(tester, data: exampleData());
    await tapTooltip(tester, 'Einstellungen');
    Brightness brightness() =>
        Theme.of(tester.element(find.byType(SettingsScreen))).brightness;

    await tester.tap(find.text('English'));
    await tester.pumpAndSettle();
    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Weight unit'), findsOneWidget);
    expect(app.controller.settings.language, 'en');
    await tester.tap(find.text('Deutsch'));
    await tester.pumpAndSettle();
    expect(find.text('Einstellungen'), findsOneWidget);

    await tester.tap(find.text('Dunkel'));
    await tester.pumpAndSettle();
    expect(brightness(), Brightness.dark);
    await tester.tap(find.text('Hell'));
    await tester.pumpAndSettle();
    expect(brightness(), Brightness.light);
    expect(app.controller.settings.theme, 'light');

    await tester.tap(find.text('Pfund (lb)'));
    await tester.pumpAndSettle();
    expect(app.controller.settings.weightUnit, 'lb');

    // Hide the cycle on the overview.
    await reveal(tester, find.widgetWithText(SwitchListTile, 'Zyklus'));
    await tester.tap(find.widgetWithText(SwitchListTile, 'Zyklus'));
    await tester.pumpAndSettle();
    expect(app.controller.settings.overviewSections, {
      Area.nutrition,
      Area.weight,
      Area.symptoms,
    });
    await goBack(tester);
    expect(find.byType(ForecastCard), findsNothing);
    expect(find.text('149,9 lb'), findsWidgets);
  });

  testWidgets('settings: nutrition and cycle options are validated', (
    tester,
  ) async {
    final app = await pumpApp(tester, data: exampleData());
    await tapTooltip(tester, 'Einstellungen');

    await tapText(tester, 'Schnellmengen für Wasser');
    await enterDialogText(tester, 'viel');
    expect(
      find.text(
        'Bitte ein bis sechs ganze Zahlen zwischen 10 und 5000 eingeben',
      ),
      findsOneWidget,
    );
    await enterDialogText(tester, '200, 400 750');
    expect(app.controller.settings.waterQuickAmountsMl, [200, 400, 750]);
    expect(find.text('200 ml, 400 ml, 750 ml'), findsOneWidget);

    await tapText(tester, 'Online-Suche in Open Food Facts');
    expect(app.controller.settings.onlineFoodSearch, OnlineFoodSearch.disabled);

    await tapText(tester, 'Adresse des Lebensmitteldienstes');
    await enterDialogText(tester, 'http://unverschluesselt.example');
    expect(
      find.textContaining('Bitte eine Adresse wie https://'),
      findsOneWidget,
    );
    await enterDialogText(tester, 'https://spiegel.example/');
    expect(app.controller.foodBaseUrl, 'https://spiegel.example');
    expect(find.text('https://spiegel.example'), findsOneWidget);
    await tapText(tester, 'Adresse des Lebensmitteldienstes');
    await enterDialogText(tester, '');
    expect(app.controller.foodBaseUrl, 'https://food.example');
    expect(find.text('Voreinstellung: https://food.example'), findsOneWidget);

    await tapText(tester, 'Übliche Zykluslänge in Tagen');
    await enterDialogText(tester, '5');
    expect(find.textContaining('Bitte eine ganze Zahl von'), findsOneWidget);
    await enterDialogText(tester, '30');
    expect(app.controller.settings.typicalCycleLengthDays, 30);
    expect(find.text('30 Tage'), findsOneWidget);

    await tapText(tester, 'Nächste Periode einschätzen');
    expect(app.controller.settings.cyclePredictions, isFalse);
    expect(app.controller.forecast.status, ForecastStatus.disabled);
  });

  testWidgets('the overview shows only the chosen areas', (tester) async {
    final app = await pumpApp(tester, data: exampleData());
    expect(find.byType(ForecastCard), findsOneWidget);
    await tapText(tester, 'Übersicht anpassen');
    for (final area in ['Ernährung', 'Zyklus', 'Gewicht', 'Symptome']) {
      await tester.tap(find.widgetWithText(SwitchListTile, area));
      await tester.pumpAndSettle();
    }
    expect(app.controller.settings.overviewSections, isEmpty);
    await tester.tapAt(const Offset(200, 40));
    await tester.pumpAndSettle();
    expect(find.text('Alle Bereiche sind ausgeblendet.'), findsOneWidget);
    expect(find.byType(ForecastCard), findsNothing);
    expect(find.text('Lebensmittel erfassen'), findsNothing);

    // The areas themselves stay reachable and complete.
    await openTab(tester, 'Zyklus');
    expect(
      find.text('Nächste Periode voraussichtlich um den 14. Oktober'),
      findsOneWidget,
    );
  });

  testWidgets('a backup is restored from the welcome screen', (tester) async {
    final sealed = await sealedExample(tester);
    final app = await pumpApp(tester, onboarded: false);
    expect(find.byType(WelcomeScreen), findsOneWidget);

    app.platform.nextOpen = PickedDocument('morphhealth.mhbackup', sealed);
    await tapText(tester, 'Sicherung wiederherstellen');
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Passphrase'),
      passphrase,
    );
    await tapText(tester, 'Sicherung öffnen');
    await tapText(tester, 'Alles ersetzen');
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(app.data.periodCount, 8);
    expect(app.controller.local.onboardingDone, isTrue);
  });
}
