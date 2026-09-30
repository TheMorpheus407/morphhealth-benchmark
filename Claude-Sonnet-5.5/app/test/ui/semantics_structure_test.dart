import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';

import 'accessibility_test.dart' show seedAll;
import 'harness.dart';

/// Flutter hängt in Listeneinträgen mit mehreren nebeneinanderliegenden
/// Bedienelementen das erste Element an den Knoten des Eintrags und meldet die
/// übrigen als dessen Kinder. Das Textfeld oder der Schalter bekommt dann die
/// Fläche der ganzen Zeile (Fokusrahmen von TalkBack, Tippziel automatisierter
/// Bedienung). Dieser Test findet solche Stellen: Ein Textfeld oder Schalter
/// darf keine anders beschrifteten Bedienelemente enthalten.
List<String> nestedControls(WidgetTester tester) {
  bool isControl(SemanticsNode n) {
    final f = n.getSemanticsData().flagsCollection;
    return f.isTextField || f.isButton;
  }

  final found = <String>[];
  final root = tester.binding.renderViews.first.owner!.semanticsOwner!.rootSemanticsNode!;

  void collect(SemanticsNode n, String ownLabel, List<String> out) {
    n.visitChildren((c) {
      final d = c.getSemanticsData();
      final label = d.label.replaceAll('\n', ' / ');
      final interactive = isControl(c) || d.hasAction(SemanticsAction.tap) || d.flagsCollection.isTextField;
      // Gleich beschriftete Kinder gehören zum Aufbau eines Flutter-Widgets
      // (etwa die Segmente eines SegmentedButton), unbeschriftete sind Teil
      // des Elternelements (etwa der Schalter in einer Listenzeile).
      if (interactive && label.isNotEmpty && label != ownLabel) out.add('"$label"');
      collect(c, ownLabel, out);
      return true;
    });
  }

  void walk(SemanticsNode n) {
    if (isControl(n)) {
      final label = n.getSemanticsData().label.replaceAll('\n', ' / ');
      final kids = <String>[];
      collect(n, label, kids);
      if (kids.isNotEmpty) found.add('"$label" ${n.rect} enthält ${kids.join(', ')}');
    }
    n.visitChildren((c) {
      walk(c);
      return true;
    });
  }

  walk(root);
  return found;
}

Future<void> expectClean(WidgetTester tester, String where) async {
  await tester.pumpAndSettle();
  expect(nestedControls(tester), isEmpty, reason: where);
}

void main() {
  setUpAll(loadRoboto);

  Future<void> back(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Zurück'));
    await tester.pumpAndSettle();
  }

  Future<void> dismissSheet(WidgetTester tester) => popTop(tester);

  testWidgets('Übersicht, Tagesdetail und Historie', (tester) async {
    final handle = tester.ensureSemantics();
    await launchApp(tester, seed: seedAll);
    await expectClean(tester, 'Übersicht');
    await tester.tap(find.text('7 Tage'));
    await expectClean(tester, 'Übersicht 7 Tage');
    await tester.tap(find.text('28 Tage'));
    await expectClean(tester, 'Übersicht 28 Tage');
    await tester.tap(find.byTooltip('Bereiche anpassen'));
    await expectClean(tester, 'Bereiche anpassen');
    await dismissSheet(tester);
    await tester.tap(find.text('Tagesdetail'));
    await expectClean(tester, 'Tagesdetail');
    await back(tester);
    await tester.tap(find.byTooltip('Historie'));
    await expectClean(tester, 'Historie');
    handle.dispose();
  });

  testWidgets('Ernährung: Tagebuch, Verlauf, Blätter und Eintragsformulare', (tester) async {
    final handle = tester.ensureSemantics();
    await launchApp(tester, seed: seedAll);
    await openTab(tester, 'Ernährung');
    await expectClean(tester, 'Tagebuch');
    await tester.tap(find.text('Andere Menge'));
    await expectClean(tester, 'Wasser-Blatt');
    await dismissSheet(tester);
    await tester.tap(find.text('Verlauf'));
    await expectClean(tester, 'Ernährungsverlauf');
    await tester.tap(find.text('Tagebuch'));
    await tester.pumpAndSettle();
    await tapScrolled(tester, find.textContaining('Haferflocken mit sehr langem Namen').first);
    await expectClean(tester, 'Eintrag bearbeiten');
    await tapScrolled(tester, find.text('Alle Nährwerte'));
    await expectClean(tester, 'Eintrag bearbeiten mit allen Nährwerten');
    await back(tester);
    await tester.tap(find.text('Lebensmittel hinzufügen'));
    await expectClean(tester, 'Lebensmittelauswahl');
    await tester.tap(find.text('Barcode').first);
    await expectClean(tester, 'Barcode-Suche');
    await tester.tap(find.text('Eigene'));
    await expectClean(tester, 'Eigene Lebensmittel');
    await tester.tap(find.text('Eigenes Lebensmittel anlegen'));
    await expectClean(tester, 'Eigenes Lebensmittel');
    handle.dispose();
  });

  testWidgets('Ernährung: Nährwerttabelle des Tages', (tester) async {
    final handle = tester.ensureSemantics();
    await launchApp(tester, seed: seedAll);
    await openTab(tester, 'Ernährung');
    await tester.tap(find.text('Alle Nährwerte'));
    await expectClean(tester, 'Nährwerttabelle des Tages');
    handle.dispose();
  });

  testWidgets('Neuer Eintrag aus einem Suchtreffer', (tester) async {
    final handle = tester.ensureSemantics();
    await launchApp(tester, seed: seedAll);
    await openTab(tester, 'Ernährung');
    await tester.tap(find.text('Lebensmittel hinzufügen'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Barcode').first);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).first, '4008400402222');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await settle(tester);
    await tester.tap(find.text('Nutella'));
    await expectClean(tester, 'Neuer Eintrag');
    handle.dispose();
  });

  testWidgets('Zyklus: Kalender, Blatt und Erklärung', (tester) async {
    final handle = tester.ensureSemantics();
    await launchApp(tester, seed: seedAll);
    await openTab(tester, 'Zyklus');
    await expectClean(tester, 'Zyklus');
    await tester.tap(find.text('Periode erfassen'));
    await expectClean(tester, 'Periode-Blatt');
    await dismissSheet(tester);
    await tester.tap(find.text('Wie kommt die Einschätzung zustande?'));
    await expectClean(tester, 'Erklärung');
    handle.dispose();
  });

  testWidgets('Gewicht und Symptome', (tester) async {
    final handle = tester.ensureSemantics();
    await launchApp(tester, seed: seedAll);
    await openTab(tester, 'Gewicht');
    await expectClean(tester, 'Gewicht');
    await tester.tap(find.text('Gewicht erfassen'));
    await expectClean(tester, 'Gewicht-Blatt');
    await dismissSheet(tester);
    await openTab(tester, 'Symptome');
    await expectClean(tester, 'Symptome');
    await tester.tap(find.text('Symptom erfassen'));
    await expectClean(tester, 'Symptom-Blatt');
    handle.dispose();
  });

  testWidgets('Einstellungen, Tagesziele und Daten', (tester) async {
    final handle = tester.ensureSemantics();
    await launchApp(tester, seed: seedAll);
    await tester.tap(find.byTooltip('Einstellungen'));
    await expectClean(tester, 'Einstellungen');
    await scrollTo(tester, find.text('Server der Lebensmittel-API'));
    await expectClean(tester, 'Einstellungen (Server)');
    await tapScrolled(tester, find.widgetWithText(ListTile, 'Daten und Sicherung'));
    await expectClean(tester, 'Daten und Sicherung');
    handle.dispose();
  });

  testWidgets('Tagesziele', (tester) async {
    final handle = tester.ensureSemantics();
    await launchApp(tester, seed: seedAll);
    await tester.tap(find.byTooltip('Einstellungen'));
    await tester.pumpAndSettle();
    await tapScrolled(tester, find.widgetWithText(ListTile, 'Tagesziele'));
    await expectClean(tester, 'Tagesziele');
    handle.dispose();
  });
}
