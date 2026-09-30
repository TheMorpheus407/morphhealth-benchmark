import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphhealth/core/core.dart';
import 'package:morphhealth/ui/health.dart';
import 'package:morphhealth/ui/shared.dart';

/// UI tests use the production validator without file I/O or network traffic.
class _Model extends AppModel {
  _Model()
    : super(
        Store(Directory('.unused-test-store'), List.filled(32, 7)),
        FoodApi(
          baseUrl: 'https://localhost:8788',
          userAgent: 'MorphHealth UI tests',
        ),
      ) {
    selectedDate = DateTime(2026, 9, 17);
  }
  Json data = emptyDocument();
  @override
  Json get doc => data;
  @override
  Future<void> put(String col, Json item) async {
    data = validateDocument({
      ...data,
      col: [...(data[col] as List).where((e) => e['id'] != item['id']), item],
    });
    validatePeriodOverlaps(data['periods'] as List);
    notifyListeners();
  }

  @override
  Future<void> remove(String col, String id) async {
    data = {
      ...data,
      col: (data[col] as List).where((e) => e['id'] != id).toList(),
    };
    notifyListeners();
  }

  @override
  Future<void> settingsPatch(Json patch) async {
    data = {
      ...data,
      'settings': {...settings, ...patch},
    };
    notifyListeners();
  }

  @override
  Future<void> replace(Json document) async {
    data = validateDocument(document);
    notifyListeners();
  }
}

Future<void> _mount(
  WidgetTester tester,
  _Model model,
  Widget page, {
  double scale = 1,
}) async {
  tester.view.reset();
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(411, 914);
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      locale: Locale(model.de ? 'de' : 'en'),
      supportedLocales: const [Locale('de'), Locale('en')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: ThemeData(useMaterial3: true),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(scale)),
        child: child!,
      ),
      home: page,
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> _tap(WidgetTester tester, String text, {bool last = false}) async {
  final found = find.text(text);
  final target = last ? found.last : found.first;
  if (found.evaluate().isEmpty) {
    await tester.scrollUntilVisible(
      found,
      300,
      scrollable: find.byType(Scrollable).first,
    );
  }
  await tester.ensureVisible(target);
  await tester.tap(target);
  await tester.pumpAndSettle();
}

void main() {
  test(
    'concurrent settings changes preserve both edits through the real store',
    () async {
      final directory = await Directory(
        'test',
      ).createTemp('.health-settings-race-');
      final store = Store(directory, List.filled(32, 37));
      final model = AppModel(
        store,
        FoodApi(
          baseUrl: 'https://localhost:8788',
          userAgent: 'MorphHealth UI tests',
        ),
      );
      try {
        await store.open();
        await Future.wait([
          model.settingsPatch({'language': 'en'}),
          model.settingsPatch({'weightUnit': 'lb'}),
        ]);
        expect(model.settings['language'], 'en');
        expect(model.settings['weightUnit'], 'lb');
      } finally {
        model.dispose();
        await store.close();
        await directory.delete(recursive: true);
      }
    },
  );

  testWidgets('weight creation, lb editing and deletion preserve kg', (
    tester,
  ) async {
    final model = _Model();
    await _mount(tester, model, WeightPage(model: model));
    await _tap(tester, 'Gewicht erfassen');
    await tester.enterText(find.byType(TextField).first, '70');
    await _tap(tester, 'Speichern');
    expect((model.doc['weights'] as List).single['kg'], 70);
    await _tap(tester, 'lb');
    expect(model.settings['weightUnit'], 'lb');
    await _tap(tester, '154.32 lb');
    await tester.enterText(find.byType(TextField).first, '176,37');
    await _tap(tester, 'Speichern');
    expect((model.doc['weights'] as List).single['kg'], closeTo(80, .01));
    await _tap(tester, '176.37 lb');
    await _tap(tester, 'Löschen');
    await _tap(tester, 'Löschen', last: true);
    expect(model.doc['weights'], isEmpty);
  });

  testWidgets('symptom CRUD handles 0, free names, notes and a reset', (
    tester,
  ) async {
    final model = _Model();
    await model.settingsPatch({'language': 'en'});
    await _mount(tester, model, SymptomsPage(model: model));
    await _tap(tester, 'Record symptom');
    await tester.enterText(find.byType(TextField).first, 'My observation');
    await tester.enterText(find.byType(TextField).last, 'A quiet morning');
    final slider = tester.widget<Slider>(find.byType(Slider));
    slider.onChanged!(0);
    await tester.pump();
    await _tap(tester, 'Save');
    final entry = (model.doc['symptoms'] as List).single;
    expect(entry['name'], 'My observation');
    expect(entry['intensity'], 0);
    expect(entry['at'], startsWith('2026-09-17T'));
    expect(entry['note'], 'A quiet morning');
    await _tap(tester, 'My observation · 0/10');
    await tester.enterText(find.byType(TextField).first, 'Renamed observation');
    tester.widget<Slider>(find.byType(Slider)).onChanged!(10);
    await tester.pump();
    await _tap(tester, 'Save');
    expect((model.doc['symptoms'] as List).single['intensity'], 10);
    await _tap(tester, 'Renamed observation · 10/10');
    await _tap(tester, 'Delete');
    await _tap(tester, 'Delete', last: true);
    expect(model.doc['symptoms'], isEmpty);
    await model.replace(emptyDocument());
    await tester.pumpAndSettle();
  });

  testWidgets(
    'editing a weight note preserves imported precision across units',
    (tester) async {
      final model = _Model();
      await model.settingsPatch({'weightUnit': 'lb'});
      await model.put('weights', {
        'id': 'precise',
        'at': '2026-09-17T00:30:00+02:00',
        'kg': 70.123456,
        'note': '',
      });
      await _mount(tester, model, WeightPage(model: model));
      await _tap(tester, '${fmt(70.123456 * 2.2046226218, 2)} lb');
      await _tap(tester, 'kg', last: true);
      await tester.enterText(
        find.byType(TextField).last,
        'Nur die Notiz geändert',
      );
      await _tap(tester, 'Speichern');
      final saved = (model.doc['weights'] as List).single;
      expect(saved['kg'], 70.123456);
      expect(saved['at'], '2026-09-17T00:30:00+02:00');
    },
  );

  testWidgets('period CRUD, spotting and overlapping open period validation', (
    tester,
  ) async {
    final model = _Model();
    await _mount(tester, model, Scaffold(body: CyclePage(model: model)));
    await _tap(tester, 'Periode erfassen');
    await tester.enterText(find.byType(TextField), 'Meine Notiz');
    await _tap(tester, 'Speichern');
    var entry = (model.doc['periods'] as List).single;
    expect(entry['flow'], 'medium');
    expect(entry['end'], isNull);
    await _tap(tester, 'Periode erfassen');
    await _tap(tester, 'Speichern');
    expect(find.textContaining('überschneidet'), findsOneWidget);
    await _tap(tester, 'Abbrechen');
    await _tap(tester, '17.09.2026 – offen');
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await _tap(tester, 'Spotting', last: true);
    await _tap(tester, 'Noch nicht beendet');
    await tester.pumpAndSettle();
    await _tap(tester, 'Speichern');
    entry = (model.doc['periods'] as List).single;
    expect(entry['flow'], 'spotting');
    expect(entry['end'], '2026-09-17');
    await _tap(tester, '17.09.2026 – 17.09.2026');
    await _tap(tester, 'Löschen');
    await _tap(tester, 'Löschen', last: true);
    expect(model.doc['periods'], isEmpty);
  });

  testWidgets(
    'calendar reaches prior months and selected-day symptom context',
    (tester) async {
      final model = _Model();
      await model.put('symptoms', {
        'id': 's',
        'name': 'Kopfschmerz',
        'intensity': 3,
        'at': '2026-08-01T09:00:00',
        'note': '',
      });
      await _mount(tester, model, Scaffold(body: CyclePage(model: model)));
      await tester.tap(find.byTooltip('Vorheriger Monat'));
      await tester.pumpAndSettle();
      expect(model.selectedDate, DateTime(2026, 8, 1));
      await _tap(tester, 'Kopfschmerz · 3/10');
      expect(find.text('Symptom bearbeiten'), findsOneWidget);
      await _tap(tester, 'Abbrechen');
      model.selectDate(DateTime(2025, 3, 5));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('März 2025'),
        -300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('März 2025'), findsOneWidget);
    },
  );

  testWidgets('health pages and editors remain usable with large text', (
    tester,
  ) async {
    final model = _Model();
    for (final page in [
      Scaffold(body: CyclePage(model: model)),
      WeightPage(model: model),
      SymptomsPage(model: model),
    ]) {
      await _mount(tester, model, page, scale: 2);
      await _tap(
        tester,
        page is WeightPage
            ? 'Gewicht erfassen'
            : page is SymptomsPage
            ? 'Symptom erfassen'
            : 'Periode erfassen',
      );
      await _tap(tester, 'Abbrechen');
    }
  });

  testWidgets('cycle estimate explains personal history and can be disabled', (
    tester,
  ) async {
    final model = _Model();
    for (final start in ['2026-06-21', '2026-07-20', '2026-08-19']) {
      await model.put('periods', {
        'id': start,
        'start': start,
        'end': dateKey(parseDay(start).add(const Duration(days: 4))),
        'flow': 'medium',
        'note': '',
      });
    }
    await _mount(tester, model, Scaffold(body: CyclePage(model: model)));
    final summary = find.text('Deine persönliche Einschätzung');
    await tester.scrollUntilVisible(
      summary,
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('18.09.2026'), findsOneWidget);
    expect(find.textContaining('Die Mitte deiner 2'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Persönliche Einschätzung'),
      -200,
      scrollable: find.byType(Scrollable).first,
    );
    await _tap(tester, 'Persönliche Einschätzung');
    expect(model.settings['cyclePredictions'], false);
    expect(find.text('Tagebuchmodus'), findsOneWidget);
  });

  testWidgets(
    'imported offset keeps civil date/time and updated symptom choices',
    (tester) async {
      final model = _Model();
      await model.put('symptoms', {
        'id': 'offset',
        'name': 'Beobachtung',
        'intensity': 2,
        'at': '2026-09-17T00:30:00+02:00',
        'note': '',
      });
      await _mount(tester, model, SymptomsPage(model: model));
      await _tap(tester, 'Beobachtung · 2/10');
      expect(find.text('Zeitpunkt: 17.09.2026 · 00:30'), findsOneWidget);
      await tester.enterText(find.byType(TextField).last, 'Neue Notiz');
      await _tap(tester, 'Speichern');
      expect(
        (model.doc['symptoms'] as List).single['at'],
        '2026-09-17T00:30:00+02:00',
      );
      final replacement = emptyDocument();
      replacement['symptoms'] = [
        {
          'id': 'new',
          'name': 'Neu importiert',
          'intensity': 1,
          'at': '2026-09-17T10:00:00',
          'note': '',
        },
      ];
      await model.replace(replacement);
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.text('Symptom für den Verlauf'),
        -300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Neu importiert'), findsWidgets);
      await model.replace(emptyDocument());
      await tester.pumpAndSettle();
    },
  );
}
