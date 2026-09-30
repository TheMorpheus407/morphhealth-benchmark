import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphhealth/core/food/off_client.dart';
import 'package:morphhealth/core/l10n/format.dart';
import 'package:morphhealth/core/service/repository.dart';
import 'package:morphhealth/core/storage/encrypted_store.dart';
import 'package:morphhealth/core/util/clock.dart';
import 'package:morphhealth/ui/app.dart';

import 'helpers.dart';

bool _fontsLoaded = false;

/// Loads the real Roboto and Material Icons fonts from the Flutter SDK so
/// that layout tests use realistic text metrics (the default test font is
/// much wider).
Future<void> loadRealFonts() async {
  if (_fontsLoaded) return;
  final candidates = <String>[
    if (Platform.environment['FLUTTER_ROOT'] != null)
      '${Platform.environment['FLUTTER_ROOT']}/bin/cache/artifacts/material_fonts',
  ];
  // flutter_tester lives in <sdk>/bin/cache/artifacts/engine/<platform>/.
  var dir = File(Platform.resolvedExecutable).parent;
  for (var i = 0; i < 6; i++) {
    candidates.add('${dir.path}/material_fonts');
    candidates.add('${dir.path}/bin/cache/artifacts/material_fonts');
    dir = dir.parent;
  }
  final fontsDir = candidates.map(Directory.new).firstWhere(
    (d) => File('${d.path}/Roboto-Regular.ttf').existsSync(),
    orElse: () => Directory(''),
  );
  if (fontsDir.path.isEmpty) return;
  Future<void> load(String family, List<String> files) async {
    final loader = FontLoader(family);
    for (final f in files) {
      final bytes = File('${fontsDir.path}/$f').readAsBytesSync();
      loader.addFont(Future.value(ByteData.sublistView(bytes)));
    }
    await loader.load();
  }

  await load('Roboto', ['Roboto-Regular.ttf', 'Roboto-Medium.ttf', 'Roboto-Bold.ttf']);
  await load('MaterialIcons', ['MaterialIcons-Regular.otf']);
  _fontsLoaded = true;
}

/// Reference device: 1080 × 2400 px at 420 dpi (411 × 914 dp).
void useReferenceDevice(WidgetTester tester) {
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.reset);
}

/// Opens a fresh repository (optionally seeded) and pumps the app with it.
Future<Repository> pumpMorphHealth(
  WidgetTester tester, {
  Future<void> Function(Repository repo)? seed,
  bool onboardingDone = true,
  double textScale = 1.0,
  bool realFonts = true,
}) async {
  if (realFonts) await loadRealFonts();
  await initializeFormatting();
  useReferenceDevice(tester);
  final repo = (await tester.runAsync(() async {
    final dir = await createTempDir('ui');
    final repo = await Repository.open(
      directory: dir,
      masterKey: testKey(),
      clock: const SystemClock(),
    );
    if (seed != null) await seed(repo);
    if (onboardingDone) {
      await repo.updateDevice(const DeviceState(onboardingCompleted: true));
    }
    return repo;
  }))!;
  // The repository is intentionally not closed here: its write queue lives
  // in the fake-async test zone, and the temporary store is discarded with
  // the test process anyway.
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(
    MorphHealthApp(
      openRepository: (_) async => repo,
      foodApi: FoodApiConfig('https://food.example.test', 'MorphHealthTest/1.0'),
      resetStorage: () async {},
    ),
  );
  await tester.pumpAndSettle();
  return repo;
}

/// Runs a direct store operation (real file I/O) and lets the UI settle.
Future<void> withIo(WidgetTester tester, Future<void> Function() action) async {
  await tester.runAsync(action);
  await settleIo(tester);
}

/// Taps [finder] and waits until the store write triggered by the tap has
/// completed (file I/O needs real time; the test clock is fake).
Future<void> tapWithIo(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(finder, 300, scrollable: find.byType(Scrollable).first);
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await settleIo(tester);
}

Future<void> settleIo(WidgetTester tester) async {
  for (var i = 0; i < 8; i++) {
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 15)));
    await tester.pump(const Duration(milliseconds: 50));
  }
  await tester.pumpAndSettle();
}

/// Taps the app bar back button (tooltip "Zurück" / "Back").
Future<void> goBack(WidgetTester tester) async {
  await tester.tap(find.byType(BackButtonIcon).last);
  await tester.pumpAndSettle();
}

/// Scrolls [finder] into view and taps it.
Future<void> tapVisible(WidgetTester tester, Finder finder) async {
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
  await tester.tap(finder);
  await tester.pumpAndSettle();
}
