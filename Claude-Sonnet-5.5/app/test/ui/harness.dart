import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:morphhealth/app.dart';
import 'package:morphhealth/core/clock.dart';
import 'package:morphhealth/core/core.dart';
import 'package:morphhealth/core/http.dart';
import 'package:morphhealth/core/store.dart';
import 'package:morphhealth/platform/device_keys.dart';
import 'package:morphhealth/platform/platform_bridge.dart';
import 'package:morphhealth/state/app_state.dart';
import 'package:morphhealth/state/boot.dart';
import 'package:morphhealth/ui/home_shell.dart';

/// Ersatz für den Lebensmitteldienst: ordnet Pfade Antworten zu.
class FakeFoodService implements HttpTransport {
  final Map<String, (int, String)> routes;
  final List<Uri> requests = [];
  bool offline = false;

  FakeFoodService(this.routes);

  @override
  Future<HttpResponse> get(Uri uri, {required Map<String, String> headers, required Duration timeout}) async {
    requests.add(uri);
    if (offline) throw const HttpFailure('offline', 'Keine Verbindung');
    for (final e in routes.entries) {
      if (uri.path.contains(e.key)) {
        return HttpResponse(e.value.$1, const {}, Uint8List.fromList(utf8.encode(e.value.$2)));
      }
    }
    return HttpResponse(404, const {}, Uint8List.fromList(utf8.encode('{"status":"failure"}')));
  }
}

String fixture(String name) => File('test/fixtures/off/$name').readAsStringSync();

/// Standard-Ersatzdienst mit den echten Antworten aus test/fixtures.
FakeFoodService defaultFoodService() => FakeFoodService({
  '/cgi/search.pl': (200, fixture('search_haferflocken.json')),
  '/api/v3.6/product/0000000000000': (404, fixture('lookup_notfound.json')),
  '/api/v3.6/product/4008400402222': (200, fixture('lookup_4008400402222.json')),
  '/api/v3.6/product/4000540000108': (
    200,
    jsonEncode({
      'code': '4000540000108',
      'status': 'success',
      'product': {
        'code': '4000540000108',
        'product_name': 'Vollkorn-Haferflocken',
        'brands': 'Kölln',
        'serving_size': '40 g',
        'serving_quantity': 40,
        'serving_quantity_unit': 'g',
        'nutriments': {'energy-kcal_100g': 361, 'proteins_100g': 14, 'carbohydrates_100g': 56, 'fat_100g': 6.7},
      },
    }),
  ),
});

bool _fontsLoaded = false;

/// Lädt Roboto aus dem Flutter-SDK, damit Textbreiten in Tests denen auf dem
/// Gerät entsprechen (sonst zeichnet der Test alles mit der breiten Ahem-Schrift).
/// Muss in `setUpAll` aufgerufen werden (echte Dateizugriffe laufen nicht in
/// der simulierten Zeit von `testWidgets`).
Future<void> loadRoboto() async {
  if (_fontsLoaded) return;
  _fontsLoaded = true;
  final root = Platform.environment['FLUTTER_ROOT'];
  if (root == null) return;
  final dir = '$root/bin/cache/artifacts/material_fonts';
  final loader = FontLoader('Roboto');
  var any = false;
  for (final f in ['Roboto-Regular', 'Roboto-Medium', 'Roboto-Bold', 'Roboto-Light']) {
    final file = File('$dir/$f.ttf');
    if (file.existsSync()) {
      loader.addFont(file.readAsBytes().then((b) => ByteData.sublistView(b)));
      any = true;
    }
  }
  if (any) await loader.load();
}

/// Startet die App im Speicher (ohne Android) mit angehaltener Uhr
/// (2026-09-29 12:00) und telefonähnlichem Bildschirm.
Future<AppState> launchApp(
  WidgetTester tester, {
  FakeFoodService? food,
  Future<void> Function(MorphCore core)? seed,
  double textScale = 1.0,
}) async {
  await initializeDateFormatting('de');
  await initializeDateFormatting('en');
  tester.view.physicalSize = const Size(1080, 2400);
  tester.view.devicePixelRatio = 2.625;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  final core = await MorphCore.open(
    persistence: MemoryPersistence(),
    clock: FixedClock(DateTime(2026, 9, 29, 12)),
    transport: food ?? defaultFoodService(),
    baseUrlOverride: 'https://localhost:8788',
    userAgentOverride: 'MorphHealth/test',
  );
  if (seed != null) await seed(core);
  final bridge = PlatformBridge();
  final tmp = Directory.systemTemp;
  final session = Session(bridge, tmp, DeviceKeys(bridge, tmp));
  tester.platformDispatcher.textScaleFactorTestValue = textScale;
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await tester.pumpWidget(MorphHealthApp(boot: Future.value(BootOk(core, session))));
  await tester.pumpAndSettle();
  return AppScope.read(tester.element(find.byType(HomeShell)));
}

/// Wechselt in einen Bereich über die Navigation.
Future<void> openTab(WidgetTester tester, String label) async {
  await tester.tap(find.descendant(of: find.byType(NavigationBar), matching: find.text(label)));
  await tester.pumpAndSettle();
}

/// Wartet auf Netzwerk-Futures des Ersatzdienstes und Animationen.
Future<void> settle(WidgetTester tester) async {
  await tester.pumpAndSettle(const Duration(milliseconds: 100));
}

/// Die vertikal scrollende Liste des aktuellen Bildschirms (nicht ein waagerechter
/// Seitenwechsler, eine Tab-Leiste, das Innere eines Textfelds oder die Seite eines
/// TabBarView, die neben dem Bildschirm liegt).
Finder verticalScrollable() => find.byElementPredicate((e) {
  final w = e.widget;
  if (w is! Scrollable || w.axis != Axis.vertical) return false;
  var insideTextField = false;
  e.visitAncestorElements((a) {
    if (a.widget is EditableText) {
      insideTextField = true;
      return false;
    }
    return true;
  });
  if (insideTextField) return false;
  final box = e.renderObject;
  if (box is! RenderBox || !box.attached || !box.hasSize) return false;
  final view = WidgetsBinding.instance.platformDispatcher.views.first;
  final screen = Offset.zero & (view.physicalSize / view.devicePixelRatio);
  return (box.localToGlobal(Offset.zero) & box.size).overlaps(screen);
}).last;

/// Bringt [finder] in die obere Hälfte der senkrechten Liste des Bildschirms (weg von
/// Schwebeknöpfen und Meldungen am unteren Rand). Baut das Ziel bei Bedarf zuerst auf,
/// indem die Liste seitenweise durchlaufen wird. Bewegt ausschließlich die nächste
/// senkrechte Liste (nicht wie `ensureVisible` auch den waagerechten Seitenwechsler eines
/// TabBarView) und springt statt zu wischen, damit kein Dehnungseffekt am Listenrand die
/// Lagemessung verfälscht. Der Sprung wiederholt sich nach der gemessenen Lage, weil sich
/// noch nicht gebaute Einträge beim Aufbauen verschieben.
Future<void> scrollTo(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    final position = tester.state<ScrollableState>(verticalScrollable()).position;
    final step = position.viewportDimension * 0.8;
    position.jumpTo(position.minScrollExtent);
    await tester.pump();
    while (finder.evaluate().isEmpty && position.pixels < position.maxScrollExtent) {
      position.jumpTo((position.pixels + step).clamp(position.minScrollExtent, position.maxScrollExtent));
      await tester.pump();
    }
  }
  if (finder.evaluate().isEmpty) throw StateError('Nicht gefunden: $finder');
  final scrollable = Scrollable.maybeOf(finder.evaluate().first);
  if (scrollable == null || scrollable.widget.axis != Axis.vertical) return;
  final position = scrollable.position;
  final list = scrollable.context.findRenderObject()! as RenderBox;
  for (var attempt = 0; attempt < 20; attempt++) {
    final area = list.localToGlobal(Offset.zero) & list.size;
    final centerY = tester.getCenter(finder.first).dy;
    if (centerY >= area.top && centerY <= area.top + area.height / 2) return;
    final wanted = position.pixels + centerY - area.top - 60;
    position.jumpTo(wanted.clamp(position.minScrollExtent, position.maxScrollExtent));
    await tester.pump();
  }
}

/// Trägt [text] in das Textfeld mit der Beschriftung [label] ein (scrollt bei Bedarf).
Future<void> enterByLabel(WidgetTester tester, String label, String text) async {
  final field = find.ancestor(of: find.text(label), matching: find.byType(TextField));
  await scrollTo(tester, field);
  await tester.enterText(field.first, text);
  await tester.pump();
}

/// Scrollt zu [finder] und tippt darauf.
Future<void> tapScrolled(WidgetTester tester, Finder finder) async {
  await scrollTo(tester, finder);
  await tester.tap(finder.first);
  await tester.pumpAndSettle();
}

/// Schließt das oberste Blatt (oder den obersten Bildschirm) wie die Zurück-Geste des Systems.
Future<void> popTop(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
}
