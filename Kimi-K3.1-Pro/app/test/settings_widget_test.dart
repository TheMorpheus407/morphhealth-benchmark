import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'widget_test.dart' show pumpApp;

void main() {
  setUpAll(() async {
    await initializeDateFormatting('de');
    await initializeDateFormatting('en');
  });

  Future<void> configure(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.625;
    tester.binding.platformDispatcher.textScaleFactorTestValue = 2.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    addTearDown(
      tester.binding.platformDispatcher.clearTextScaleFactorTestValue,
    );
    await pumpApp(tester);
    await tester.tap(find.text('Einstellungen'));
    await tester.pumpAndSettle();
  }

  Future<void> reveal(WidgetTester tester, Finder finder) async {
    for (
      var attempt = 0;
      attempt < 30 && finder.evaluate().isEmpty;
      attempt++
    ) {
      await tester.drag(find.byType(ListView).last, const Offset(0, -500));
      await tester.pumpAndSettle();
    }
    expect(finder, findsWidgets);
    await tester.ensureVisible(finder.first);
    await tester.pumpAndSettle();
  }

  testWidgets('Backup passphrase dialog remains usable at 200 percent text', (
    tester,
  ) async {
    await configure(tester);
    await reveal(tester, find.byKey(const ValueKey('create-backup')));
    await tester.tap(find.byKey(const ValueKey('create-backup')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('backup-passphrase')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('backup-passphrase-repeat')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Wipe confirmation dialog remains usable at 200 percent text', (
    tester,
  ) async {
    await configure(tester);
    await reveal(tester, find.text('Alle lokalen Daten löschen'));
    await tester.tap(find.text('Alle lokalen Daten löschen'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('wipe-confirmation')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
