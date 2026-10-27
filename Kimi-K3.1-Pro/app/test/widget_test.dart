import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:morphhealth/core/food_api.dart';
import 'package:morphhealth/core/health.dart';
import 'package:morphhealth/core/nutrition.dart';
import 'package:morphhealth/core/repository.dart';
import 'package:morphhealth/main.dart';

class MemoryStore implements StateStore {
  AppState? value;

  @override
  Future<AppState?> load() async => value;

  @override
  Future<void> save(AppState state) async => value = state;

  @override
  Future<void> clear() async => value = null;
}

Future<HealthRepository> pumpApp(WidgetTester tester) async {
  final repository = await HealthRepository.open(MemoryStore());
  final api = FoodApi(
    'https://food.invalid',
    'MorphHealth widget test',
    client: MockClient(
      (request) async => http.Response('{"products":[]}', 200),
    ),
  );
  await tester.pumpWidget(MorphHealthApp(repository: repository, foodApi: api));
  await tester.pumpAndSettle();
  return repository;
}

void main() {
  setUpAll(() async {
    await initializeDateFormatting('de');
    await initializeDateFormatting('en');
  });

  testWidgets('German overview and all main areas are available', (
    tester,
  ) async {
    await pumpApp(tester);
    expect(find.text('Übersicht'), findsWidgets);
    expect(find.text('Ernährung'), findsWidgets);
    expect(find.text('Zyklus'), findsWidgets);
    expect(find.text('Historie'), findsOneWidget);
    expect(find.text('Einstellungen'), findsOneWidget);
    expect(find.text('Gewicht'), findsWidgets);
    await tester.scrollUntilVisible(find.text('Symptome'), 250);
    expect(find.text('Symptome'), findsWidgets);
  });

  testWidgets('Quick water uses the productive repository', (tester) async {
    final repository = await pumpApp(tester);
    await tester.tap(find.text('Ernährung').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('quick-water')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('water-250')));
    await tester.pumpAndSettle();
    expect(repository.state.intakes, hasLength(1));
    expect(repository.state.intakes.single.kind, IntakeKind.water);
    expect(repository.state.intakes.single.amount, 250);
    expect(
      repository
          .nutritionDay(
            repository.state.intakes.single.occurredAt
                .toLocal()
                .toString()
                .substring(0, 10),
          )
          .waterMl,
      250,
    );
  });

  testWidgets('Language can be switched to English and persists', (
    tester,
  ) async {
    final repository = await pumpApp(tester);
    await tester.tap(find.text('Einstellungen'));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Englisch').last);
    await tester.pumpAndSettle();
    expect(repository.state.settings.language, 'en');
    expect(find.text('Language'), findsOneWidget);
    expect(find.text('Open Food Facts search'), findsWidgets);
  });
}
