// Läuft nur, wenn der in ENVIRONMENT.json genannte Endpunkt erreichbar ist.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:morphhealth/core/food_api.dart';
import 'package:morphhealth/core/http.dart';

Map<String, Object?> readEnvironment() {
  final f = File('../ENVIRONMENT.json');
  if (!f.existsSync()) return {};
  return (jsonDecode(f.readAsStringSync()) as Map).cast<String, Object?>();
}

void main() {
  final env = readEnvironment();
  final base = Platform.environment['MH_FOOD_BASE_URL'] ?? (env['food_api_base_url'] as String?) ?? '';
  final ua =
      Platform.environment['MH_FOOD_USER_AGENT'] ?? (env['food_api_user_agent'] as String?) ?? 'MorphHealth/test';

  late bool reachable;
  setUpAll(() async {
    reachable = false;
    if (base.isEmpty) return;
    try {
      final u = Uri.parse(base);
      final s = await Socket.connect(u.host, u.port, timeout: const Duration(seconds: 2));
      await s.close();
      reachable = true;
    } on Object {
      reachable = false;
    }
  });

  FoodApi api() => FoodApi(baseUrl: base, userAgent: ua, transport: IoHttpTransport());

  test('Live: Produktabruf per Barcode (TLS mit Systemzertifikaten)', () async {
    if (!reachable) return markTestSkipped('Endpunkt nicht erreichbar');
    final r = await api().lookup('4008400402222');
    expect(r.food.name, 'Nutella');
    expect(r.food.nutrients['energy_kcal'], 539);
  });

  test('Live: Suche nach Namen', () async {
    if (!reachable) return markTestSkipped('Endpunkt nicht erreichbar');
    final page = await api().search('haferflocken');
    expect(page.items, isNotEmpty);
    expect(page.total, greaterThan(20));
    final p2 = await api().search('haferflocken', page: 2);
    expect(p2.page, 2);
    expect(p2.items.first.barcode, isNot(page.items.first.barcode));
  });

  test('Live: unbekannter Barcode ergibt not_found', () async {
    if (!reachable) return markTestSkipped('Endpunkt nicht erreichbar');
    await expectLater(
      api().lookup('0000000000000'),
      throwsA(isA<FoodApiException>().having((e) => e.code, 'code', 'not_found')),
    );
  });

  test('Live: falsches Zertifikat wird abgelehnt (kein Umgehen der Prüfung)', () async {
    if (!reachable) return markTestSkipped('Endpunkt nicht erreichbar');
    // Ein leerer Kontext ohne Vertrauensanker darf die Verbindung nicht aufbauen.
    final strict = IoHttpTransport(context: SecurityContext(withTrustedRoots: false));
    final a = FoodApi(baseUrl: base, userAgent: ua, transport: strict);
    await expectLater(a.lookup('4008400402222'), throwsA(isA<FoodApiException>().having((e) => e.code, 'code', 'tls')));
  });
}
