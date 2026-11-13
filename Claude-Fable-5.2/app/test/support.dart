import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:morphhealth/app.dart';
import 'package:morphhealth/controller.dart';
import 'package:morphhealth/platform/platform_bridge.dart';
import 'package:morphhealth/ui/widgets/common.dart';
import 'package:morphhealth_core/morphhealth_core.dart';
import 'package:morphhealth_core/src/portable/example_document.dart';

/// The moment all widget tests run at: Wednesday, 23 September 2026.
final LocalDateTime testNow = LocalDateTime.parse('2026-09-23T12:40:00+02:00');

/// The example data set of the format description.
AppData exampleData() =>
    AppData.fromDocument(exampleDocument(), IssueLog(), now: testNow)!;

/// Backups without a background isolate and with cheap key derivation.
class FastBackups extends BackupWorker {
  const FastBackups();

  static const _params = Argon2Params(
    memoryKib: 8 * 1024,
    iterations: 1,
    parallelism: 1,
  );

  @override
  Future<Uint8List> seal(
    Map<String, dynamic> document,
    String passphrase,
    LocalDateTime createdAt,
  ) => BackupCodec.seal(
    document,
    passphrase,
    createdAt: createdAt,
    params: _params,
  );

  @override
  Future<Map<String, dynamic>> open(Uint8List bytes, String passphrase) =>
      BackupCodec.open(bytes, passphrase);
}

/// A food service answering from memory; records the requested URLs.
class FakeFoodService implements HttpTransport {
  final List<Uri> requests = [];

  /// Products by barcode, as raw product objects of the service.
  final Map<String, Map<String, dynamic>> products;

  /// If set, every request fails with this error.
  FoodApiException? failure;

  FakeFoodService([Map<String, Map<String, dynamic>>? products])
    : products = products ?? defaultProducts();

  static Map<String, Map<String, dynamic>> defaultProducts() => {
    '4000000000099': {
      'code': '4000000000099',
      'product_name': 'Testmüsli',
      'brands': 'Testmarke',
      'quantity': '500 g',
      'serving_size': '40 g',
      'serving_quantity': 40,
      'serving_quantity_unit': 'g',
      'schema_version': 1004,
      'nutriments': <String, dynamic>{},
      'nutrition': {
        'aggregated_set': {
          'per': '100g',
          'preparation': 'as_sold',
          'nutrients': {
            'energy-kcal': {'value': 380, 'unit': 'kcal'},
            'proteins': {'value': 10, 'unit': 'g'},
            'carbohydrates': {'value': 60, 'unit': 'g'},
            'fat': {'value': 8, 'unit': 'g'},
            'vitamin-c': {'value': 0.03, 'unit': 'g', 'source': 'estimate'},
          },
        },
      },
    },
    for (var i = 1; i <= 25; i++)
      '40000000001${i.toString().padLeft(2, '0')}': {
        'code': '40000000001${i.toString().padLeft(2, '0')}',
        'product_name': 'Testprodukt $i',
        'brands': 'Marke',
        'nutrition_data_per': '100g',
        'nutriments': {'energy-kcal_100g': 100 + i, 'proteins_100g': 5},
      },
  };

  @override
  Future<TransportResponse> get(
    Uri uri, {
    required Map<String, String> headers,
    required Duration timeout,
  }) async {
    requests.add(uri);
    final error = failure;
    if (error != null) throw error;
    TransportResponse json(Object body, [int status = 200]) =>
        TransportResponse(status, const {}, utf8.encode(jsonEncode(body)));
    if (uri.path.startsWith('/api/v3.6/product/')) {
      final code = uri.pathSegments.last.replaceAll('.json', '');
      final product = products[code];
      if (product == null) {
        return json({
          'status': 'failure',
          'result': {'id': 'product_not_found'},
        }, 404);
      }
      return json({'status': 'success', 'code': code, 'product': product});
    }
    final q = (uri.queryParameters['search_terms'] ?? '').toLowerCase();
    final page = int.parse(uri.queryParameters['page'] ?? '1');
    final hits = [
      for (final p in products.values)
        if ('${p['product_name']}'.toLowerCase().contains(q)) p,
    ];
    final start = (page - 1) * 20;
    final slice = hits.skip(start).take(20).toList();
    return json({
      'count': hits.length,
      'page': page,
      'page_count': slice.length,
      'page_size': 20,
      'products': slice,
    });
  }

  @override
  void close() {}
}

class TestApp {
  final AppController controller;
  final FakePlatformBridge platform;
  final FakeFoodService food;
  int restarts = 0;

  TestApp(this.controller, this.platform, this.food);

  HealthRepository get repository => controller.repository;
  AppData get data => controller.data;
}

/// Starts the app on a phone-sized surface with in-memory data.
Future<TestApp> pumpApp(
  WidgetTester tester, {
  AppData? data,
  bool onboarded = true,
  Size size = const Size(411, 914),
  double textScale = 1.0,

  /// Height of a system navigation bar drawn over the lower edge of the
  /// app, as on Android 15, where apps extend behind the system bars.
  double systemBarBottom = 0,
  Settings Function(Settings s)? settings,
}) async {
  await initializeDateFormatting();
  var counter = 0;
  final repository = await HealthRepository.open(
    MemoryDataStore(),
    clock: FixedClock(testNow),
    idFactory: () => 'test-${++counter}',
  );
  if (data != null) await repository.replaceAll(data);
  if (settings != null) {
    await repository.updateSettings(settings(repository.data.settings));
  }
  if (onboarded) {
    await repository.updateLocal(const LocalState(onboardingDone: true));
  }
  final platform = FakePlatformBridge();
  final food = FakeFoodService();
  late final TestApp app;
  final controller = AppController(
    repository: repository,
    platform: platform,
    restart: () async => app.restarts++,
    watchClock: false,
    backups: const FastBackups(),
    config: const AppConfig(
      defaultFoodBaseUrl: 'https://food.example',
      foodUserAgent: 'MorphHealth/test',
    ),
    foodClientFactory: (origin, userAgent, languages) => FoodApiClient(
      origin: origin,
      userAgent: userAgent,
      transport: food,
      languages: languages,
      sleep: (_) async {},
    ),
  );
  app = TestApp(controller, platform, food);
  addTearDown(controller.dispose);

  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  if (systemBarBottom > 0) {
    final bars = FakeViewPadding(top: 24, bottom: systemBarBottom);
    tester.view.padding = bars;
    tester.view.viewPadding = bars;
  }
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

  await tester.pumpWidget(MorphHealthApp(controller: controller));
  await tester.pumpAndSettle();
  return app;
}

/// Scrolls the main list of the current screen until [finder] is visible.
/// Lists build their children lazily, so a widget further down does not
/// exist before it is scrolled to.
Future<void> reveal(WidgetTester tester, Finder finder, {int index = 0}) async {
  if (finder.evaluate().length <= index) {
    // The main list of a screen is its first vertical scrollable (text
    // fields and chip rows contain scrollables of their own).
    final lists = find.byWidgetPredicate(
      (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
    );
    // Look further down first, then go back up to the top.
    for (final step in const [-300.0, 300.0]) {
      for (var i = 0; i < 60 && finder.evaluate().length <= index; i++) {
        if (lists.evaluate().isEmpty) break;
        await tester.drag(lists.first, Offset(0, step));
        await tester.pump();
      }
    }
    await tester.pumpAndSettle();
    expect(
      finder.evaluate().length,
      greaterThan(index),
      reason:
          'not found after scrolling: ${finder.describeMatch(Plurality.one)}\n'
          'on screen: ${visibleTexts(tester)}',
    );
  }
  // Centred, so that neither the action button nor a message at the bottom
  // covers the target.
  await Scrollable.ensureVisible(
    tester.element(finder.at(index)),
    alignment: 0.5,
  );
  await tester.pumpAndSettle();
}

/// Taps the widget with [text] after scrolling it into view.
Future<void> tapText(WidgetTester tester, String text, {int index = 0}) async {
  final finder = find.text(text);
  await reveal(tester, finder, index: index);
  await tester.tap(finder.at(index));
  await tester.pumpAndSettle();
}

Future<void> tapTooltip(
  WidgetTester tester,
  String tooltip, {
  int index = 0,
}) async {
  final finder = find.byTooltip(tooltip);
  await reveal(tester, finder, index: index);
  await tester.tap(finder.at(index));
  await tester.pumpAndSettle();
}

/// Taps the chip labelled [text].
Future<void> tapChip(WidgetTester tester, String text, {int index = 0}) async {
  final finder = find.widgetWithText(ActionChip, text);
  await reveal(tester, finder, index: index);
  await tester.tap(finder.at(index));
  await tester.pumpAndSettle();
}

/// Taps the choice chip labelled [text].
Future<void> tapChoice(
  WidgetTester tester,
  String text, {
  int index = 0,
}) async {
  final finder = find.widgetWithText(ChoiceChip, text);
  await reveal(tester, finder, index: index);
  await tester.tap(finder.at(index));
  await tester.pumpAndSettle();
}

/// Chooses [option] in the choice field named [label].
Future<void> choose(WidgetTester tester, String label, String option) async {
  final field = find.byWidgetPredicate(
    (w) => w is ChoiceField && w.label == label,
  );
  await reveal(tester, field);
  await tester.tap(field.first);
  await tester.pumpAndSettle();
  final entry = find.widgetWithText(ListTile, option);
  await tester.scrollUntilVisible(
    entry,
    200,
    scrollable: find
        .descendant(
          of: find.byType(BottomSheet),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  await tester.tap(entry);
  await tester.pumpAndSettle();
}

/// Leaves the current screen through the back or close button of its app bar.
Future<void> goBack(WidgetTester tester) async {
  final back = find.byType(BackButton);
  await tester.tap(
    back.evaluate().isNotEmpty ? back.last : find.byTooltip('Schließen').last,
  );
  await tester.pumpAndSettle();
}

/// All texts currently on screen, for diagnosing a failing test.
String visibleTexts(WidgetTester tester) => tester
    .widgetList<Text>(find.byType(Text))
    .map((t) => t.data ?? t.textSpan?.toPlainText() ?? '')
    .where((s) => s.isNotEmpty)
    .join(' | ');

/// Opens one of the five main tabs by its label in the navigation bar.
Future<void> openTab(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(of: find.byType(NavigationBar), matching: find.text(label)),
  );
  await tester.pumpAndSettle();
}
