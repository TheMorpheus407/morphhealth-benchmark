import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:morphhealth/app.dart';
import 'package:morphhealth/controller.dart';
import 'package:morphhealth/l10n/strings.dart';
import 'package:morphhealth/ui/theme.dart';
import 'package:morphhealth/ui/widgets/charts.dart';
import 'package:morphhealth_core/morphhealth_core.dart';

import 'support.dart';

void main() {
  test('bar chart axes end at round numbers', () {
    expect(niceUpperBound(1190), 1200);
    expect(niceUpperBound(2080), 2500);
    expect(niceUpperBound(596), 600);
    expect(niceUpperBound(1000), 1000);
    expect(niceUpperBound(9.1), 10);
    expect(niceUpperBound(87), 100);
    expect(niceUpperBound(0.043), closeTo(0.05, 1e-12));
    expect(niceUpperBound(0), 1);
    expect(niceUpperBound(double.nan), 1);
    for (final v in [0.3, 7.0, 11.0, 149.9, 4321.0, 99999.0]) {
      final bound = niceUpperBound(v);
      expect(bound, greaterThanOrEqualTo(v * 0.999999), reason: '$v');
      expect(bound, lessThanOrEqualTo(v * 1.34), reason: '$v');
    }
  });

  testWidgets('charts draw every shape of data without errors', (tester) async {
    final app = await pumpApp(tester);
    final first = Day(2026, 9, 1);
    List<DayValue> series(List<double?> values) => [
      for (var i = 0; i < values.length; i++)
        DayValue(first.addDays(i), values[i]),
    ];
    final cases = <String, List<double?>>{
      'nothing': List.filled(7, null),
      'one value': [null, null, 3, null, null, null, null],
      'zeros': List.filled(7, 0),
      'equal values': List.filled(28, 68.0),
      'gaps': [1, null, 2, null, null, 9, null],
      'large': [for (var i = 0; i < 90; i++) 1000.0 * i],
      'tiny': [0.001, 0.002, 0.0005, null, 0.0001, 0.003, 0.002],
      'one day': [5],
    };
    for (final kind in DayChartKind.values) {
      for (final c in cases.entries) {
        await tester.pumpWidget(
          AppScope(
            controller: app.controller,
            child: MaterialApp(
              theme: buildTheme(Brightness.light),
              locale: const Locale('de'),
              supportedLocales: const [Locale('de')],
              localizationsDelegates: appLocalizationsDelegates,
              home: Scaffold(
                body: Builder(
                  builder: (context) => DayChart(
                    values: series(c.value),
                    kind: kind,
                    color: Colors.teal,
                    goal: kind == DayChartKind.bars ? 4 : null,
                    goalLabel: L.of(context).goal,
                    formatValue: (v) => '$v',
                    formatAxis: (v) => v.toStringAsFixed(1),
                    semanticsLabel: c.key,
                    emptyText: 'leer',
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull, reason: '$kind ${c.key}');
        expect(find.bySemanticsLabel(c.key), findsOneWidget);
        // Tapping anywhere in the chart never fails either.
        await tester.tapAt(tester.getCenter(find.byType(DayChart)));
        await tester.pump();
        expect(tester.takeException(), isNull, reason: 'tap $kind ${c.key}');
      }
    }
    expect(find.text('leer'), findsNothing, reason: 'the last case has data');
  });
}
