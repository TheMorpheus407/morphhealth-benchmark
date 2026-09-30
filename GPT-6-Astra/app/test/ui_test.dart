import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphhealth/core/core.dart';
import 'package:morphhealth/main.dart';
import 'package:morphhealth/ui/shared.dart';
import 'package:morphhealth/ui/settings.dart';
import 'package:morphhealth/ui/shell.dart';

void main() {
  test('Small known nutrient amounts never display as a known zero', () {
    expect(fmt(null), '—');
    expect(fmt(0), '0');
    expect(fmt(0.001, 2), '0.001');
    expect(fmt(0.00000001, 2), '1.00e-8');
    expect(fmt(1.25, 2), '1.25');
  });
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory dir;
  late Store store;
  late AppModel model;
  setUp(() async {
    final base = Directory('build/ui-test');
    await base.create(recursive: true);
    dir = await base.createTemp('root-');
    store = Store(dir, List.generate(32, (i) => i));
    await store.open();
    model = AppModel(
      store,
      FoodApi(baseUrl: 'https://localhost:8788', userAgent: 'MorphHealth test'),
    );
    model.selectDate(DateTime(2026, 9, 26));
  });
  tearDown(() async {
    model.dispose();
    await store.close();
    await dir.delete(recursive: true);
  });
  testWidgets('German default navigation, shared day and English switch', (
    t,
  ) async {
    await t.pumpWidget(MorphHealth(model: model));
    await t.pumpAndSettle();
    expect(find.text('Dein Tag. Dein Rhythmus.'), findsOneWidget);
    await t.tap(find.text('Gemeinsames Tagesdetail'));
    await t.pumpAndSettle();
    expect(find.text('Alles für diesen Tag'), findsOneWidget);
    await t.tap(find.byType(BackButton));
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('Einstellungen'));
    await t.pumpAndSettle();
    expect(find.byType(SettingsPage), findsOneWidget);
    await t.runAsync(() => model.settingsPatch({'language': 'en'}));
    await t.pumpAndSettle();
    expect(find.text('Settings'), findsOneWidget);
    await t.tap(find.byType(BackButton));
    await t.pumpAndSettle();
    expect(find.text('Your day. Your rhythm.'), findsOneWidget);
    await t.tap(find.text('Trends'));
    await t.pumpAndSettle();
    expect(find.text('Discover patterns'), findsOneWidget);
    expect(t.takeException(), isNull);
  });
  testWidgets('History filters find note text and open actual edit form', (
    t,
  ) async {
    await t.runAsync(
      () => store.put('symptoms', {
        'id': 's',
        'at': '2026-09-26T10:00:00',
        'name': 'Kopf',
        'intensity': 4,
        'note': 'after a walk',
      }),
    );
    await t.runAsync(
      () => store.put('drinks', {
        'id': 'd',
        'at': '2026-09-25T10:00:00',
        'kind': 'water',
        'amount': 250,
        'note': '',
      }),
    );
    await t.pumpWidget(MorphHealth(model: model));
    await t.pumpAndSettle();
    await t.tap(find.text('Historie'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField).first, 'walk');
    await t.pumpAndSettle();
    expect(find.text('Kopf'), findsOneWidget);
    expect(find.text('Wasser'), findsNothing);
    await t.tap(find.text('Kopf'));
    await t.pumpAndSettle();
    expect(find.textContaining('bearbeiten'), findsWidgets);
    expect(t.takeException(), isNull);
  });
  testWidgets('Root screens remain accessible at large text and narrow width', (
    t,
  ) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(390, 844),
            textScaler: TextScaler.linear(1.6),
          ),
          child: Scaffold(
            body: HomePage(model: model, onNavigate: (_) {}),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
    await t.pumpWidget(
      MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(390, 844),
            textScaler: TextScaler.linear(1.6),
          ),
          child: Scaffold(body: TrendsPage(model: model)),
        ),
      ),
    );
    await t.pumpAndSettle();
  });
}
