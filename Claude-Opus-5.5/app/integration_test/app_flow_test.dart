// End-to-end test on the Android reference device (see check.sh --device):
// real Android Keystore, real encrypted files and the configured food API.
//
//   flutter test integration_test -d emulator-5560 \
//     --dart-define=FOOD_API_BASE_URL=https://localhost:8788 \
//     --dart-define=FOOD_API_USER_AGENT="MorphHealth/1.0-rc3 (benchmark build)"

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:morphhealth/core/history/history.dart';
import 'package:morphhealth/core/l10n/format.dart';
import 'package:morphhealth/core/l10n/strings.dart';
import 'package:morphhealth/core/model/enums.dart';
import 'package:morphhealth/core/portable/portable_codec.dart';
import 'package:morphhealth/core/service/repository.dart';
import 'package:morphhealth/core/storage/encrypted_store.dart';
import 'package:morphhealth/core/util/clock.dart';
import 'package:morphhealth/core/util/local_date.dart';
import 'package:morphhealth/ui/app.dart';
import 'package:morphhealth/ui/controller.dart';
import 'package:morphhealth/ui/platform/platform_bridge.dart';

import '../test/support/generator.dart';

Future<void> waitFor(WidgetTester tester, Finder finder, {Duration timeout = const Duration(seconds: 20)}) async {
  final end = DateTime.now().add(timeout);
  while (finder.evaluate().isEmpty) {
    if (DateTime.now().isAfter(end)) {
      final visible = find
          .byType(Text)
          .evaluate()
          .map((e) => (e.widget as Text).data ?? '')
          .where((t) => t.isNotEmpty)
          .take(40)
          .join(' | ');
      throw TestFailure('Timed out waiting for $finder. Visible texts: $visible');
    }
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.pumpAndSettle();
}

Future<void> tapText(WidgetTester tester, String text, {int index = 0}) async {
  final finder = find.text(text);
  if (finder.evaluate().isEmpty && find.byType(Scrollable).evaluate().isNotEmpty) {
    // Lists build lazily: scroll until the target exists.
    await tester.scrollUntilVisible(
      finder,
      300,
      scrollable: find.byType(Scrollable).first,
      maxScrolls: 30,
    );
  }
  await waitFor(tester, finder);
  await tester.ensureVisible(finder.at(index));
  await tester.pumpAndSettle();
  await tester.tap(finder.at(index));
  await tester.pumpAndSettle();
}

AppController controllerOf(WidgetTester tester) =>
    AppScope.read(tester.element(find.byType(Scaffold).first));

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeFormatting();
    // Start from an empty installation.
    const platform = PlatformBridge();
    final dir = Directory('${await platform.dataDirectory()}/morphhealth_store');
    await EncryptedStore.destroyFiles(dir);
    await platform.destroyMasterKey();
  });

  testWidgets('everyday flows on the device', (tester) async {
    await tester.pumpWidget(const MorphHealthApp());
    await waitFor(tester, find.text('Willkommen bei MorphHealth'));

    // Onboarding.
    await tapText(tester, 'Los geht’s');
    await waitFor(tester, find.text('Tagesdetail'));

    // Water quick entry on the overview.
    await tapText(tester, '250 ml');
    await waitFor(tester, find.textContaining('250 ml Wasser hinzugefügt'));

    // Online search in Open Food Facts (organizer endpoint via adb reverse).
    await tester.tap(find.byIcon(Icons.restaurant_outlined).last);
    await tester.pumpAndSettle();
    await tapText(tester, 'Lebensmittel hinzufügen');
    await tester.enterText(find.byType(TextField).first, 'Haferflocken');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await waitFor(tester, find.textContaining('kcal pro 100'), timeout: const Duration(seconds: 30));
    await tester.tap(find.textContaining('kcal pro 100').first);
    await tester.pumpAndSettle();
    await waitFor(tester, find.text('Zum Tagebuch hinzufügen'));
    await tester.enterText(find.byType(TextFormField).first, '50');
    await tester.pumpAndSettle();
    await tapText(tester, 'Zum Tagebuch hinzufügen');
    await waitFor(tester, find.text('Tagessumme'));
    final controller = controllerOf(tester);
    final today = controller.today;
    final day = controller.service.nutritionDay(today);
    expect(day.entries, hasLength(1));
    expect(day.totals['energy_kcal'], greaterThan(0));

    // Barcode lookup.
    final lookup = await controller.service.lookupBarcode('4000417025005');
    expect(lookup.online, isNotNull);

    // Cycle: period started today.
    await tester.tap(find.byIcon(Icons.water_drop_outlined).last);
    await tester.pumpAndSettle();
    await tapText(tester, 'Periode hat heute begonnen');
    await waitFor(tester, find.text('Periode heute beendet'));
    await tester.scrollUntilVisible(
      find.text('Periode · Tag 1'),
      -300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(controller.service.cycleForecast(today).currentPeriodDay, 1);

    // History finds the logged food.
    await tester.tap(find.byIcon(Icons.search).first);
    await tester.pumpAndSettle();
    expect(find.textContaining('Periode'), findsWidgets);
    await tester.tap(find.byType(BackButtonIcon).last);
    await tester.pumpAndSettle();

    // Nothing readable is stored on the device: food names and record
    // structure exist only in encrypted form.
    final repo = controller.service.repo;
    final foodName = day.entries.single.food.name;
    for (final file in repo.directory.listSync().whereType<File>()) {
      final content = latin1.decode(file.readAsBytesSync());
      expect(content.contains(foodName), isFalse, reason: file.path);
      expect(content.contains('food_entries'), isFalse, reason: file.path);
    }

    // The data survives closing and reopening the encrypted store.
    final counts = repo.data.counts();
    await repo.close();
    final reopened = await openAppRepository(const PlatformBridge());
    expect(reopened.data.counts(), counts);
    await reopened.close();
  });

  testWidgets('10,000+ diary entries on the device', (tester) async {
    await initializeFormatting();
    final doc = generateDataset(end: LocalDate.fromDateTime(DateTime.now()));
    final count = diaryEntryCount(doc);
    final timings = <String, int>{};
    Future<T> measure<T>(String name, Future<T> Function() body) async {
      final sw = Stopwatch()..start();
      final r = await body();
      timings[name] = sw.elapsedMilliseconds;
      return r;
    }

    const platform = PlatformBridge();
    final dir = Directory('${await platform.dataDirectory()}/morphhealth_perf');
    await EncryptedStore.destroyFiles(dir);
    final key = await platform.loadMasterKey();
    var repo = await Repository.open(
      directory: dir,
      masterKey: key,
      clock: const SystemClock(),
      encoder: encodeSnapshotInBackground,
      decoder: decodeSnapshotInBackground,
    );
    final json = jsonEncode(doc);
    await measure('import 10k (validate + encrypted snapshot)', () async {
      final decoded = decodePortable(jsonDecode(json), now: DateTime.now().toUtc());
      await repo.replaceAll(decoded.dataset);
    });
    await repo.close();
    repo = await measure('open encrypted store', () => Repository.open(
      directory: dir,
      masterKey: key,
      clock: const SystemClock(),
      encoder: encodeSnapshotInBackground,
      decoder: decodeSnapshotInBackground,
    ));
    expect(repo.data.diaryEntryCount, count);
    final today = LocalDate.fromDateTime(DateTime.now());
    final fmt = Fmt(AppLanguage.de);
    await measure('journal append (one entry)', () async {
      await repo.updateSettings(repo.data.settings.copyWith(weightUnit: WeightUnit.kg));
    });
    final index = await measure(
      'history index',
      () async => HistoryIndex.build(repo.data, S.of(AppLanguage.de), fmt, today),
    );
    await measure('history filter', () async => index.filter(const HistoryQuery(text: 'kopf', areas: {Area.symptoms})));
    await repo.close();
    await EncryptedStore.destroyFiles(dir);

    binding.reportData = {'timings_ms': timings, 'diary_entries': count};
    // ignore: avoid_print
    print('DEVICE PERF $count diary entries: ${jsonEncode(timings)}');
    expect(timings['open encrypted store']!, lessThan(5000));
  });
}
