import 'package:flutter_test/flutter_test.dart';
import 'package:morphhealth/core/cycle/forecast.dart';
import 'package:morphhealth/core/cycle/forecast_json.dart';
import 'package:morphhealth/core/l10n/format.dart';
import 'package:morphhealth/core/l10n/strings.dart';
import 'package:morphhealth/core/model/cycle_records.dart';
import 'package:morphhealth/core/model/enums.dart';
import 'package:morphhealth/core/util/local_date.dart';

LocalDate d(String iso) => LocalDate.parse(iso);

Period p(String start, [String? end]) => Period.create(
  start: d(start),
  end: end == null ? null : d(end),
  now: DateTime.utc(2026),
);

void main() {
  const f = CycleForecaster();
  setUpAll(initializeFormatting);

  test('no data', () {
    final r = f.forecast([], d('2026-09-23'));
    expect(r.status, CycleStatus.noData);
    expect(r.hasEstimate, isFalse);
  });

  test('a single period gives no personal estimate', () {
    final r = f.forecast([p('2026-09-01', '2026-09-05')], d('2026-09-23'));
    expect(r.status, CycleStatus.insufficientData);
    expect(r.cycleDay, 23);
    expect(r.hasEstimate, isFalse);
    expect(r.medianPeriodLength, 5);
  });

  test('regular cycles: median, window and high confidence', () {
    final periods = [
      p('2026-05-08', '2026-05-12'),
      p('2026-06-05', '2026-06-09'),
      p('2026-07-03', '2026-07-07'),
      p('2026-07-31', '2026-08-04'),
      p('2026-08-29', '2026-09-02'),
    ];
    final r = f.forecast(periods, d('2026-09-10'));
    expect(r.cycles.map((c) => c.length), [28, 28, 28, 29]);
    expect(r.medianCycleLength, 28);
    expect(r.expectedStart, d('2026-09-26'));
    expect(r.windowHalfWidth, 1);
    expect(r.windowStart, d('2026-09-25'));
    expect(r.windowEnd, d('2026-09-27'));
    expect(r.confidence, ForecastConfidence.high);
    expect(r.status, CycleStatus.beforeWindow);
    expect(r.daysUntilExpected, 16);
    expect(r.medianPeriodLength, 5);
    expect(r.upcoming.first.start, d('2026-09-26'));
    expect(r.upcoming.first.end, d('2026-09-30'));
    expect(r.upcoming, hasLength(3));
    expect(r.isPredictedPeriodDay(d('2026-09-28')), isTrue);
  });

  test('only uses history up to the viewing day', () {
    final periods = [
      p('2026-06-05', '2026-06-09'),
      p('2026-07-03', '2026-07-07'),
      p('2026-07-31', '2026-08-04'),
    ];
    final r = f.forecast(periods, d('2026-07-10'));
    expect(r.periodsConsidered, 2);
    expect(r.cycles.single.length, 28);
    expect(r.expectedStart, d('2026-07-31'));
    expect(r.windowHalfWidth, 3, reason: 'single cycle → ± 3 days');
    expect(r.confidence, ForecastConfidence.low);
  });

  test('in period, window and after window states', () {
    final periods = [
      p('2026-07-03', '2026-07-07'),
      p('2026-07-31', '2026-08-04'),
      p('2026-08-28', '2026-09-01'),
      p('2026-09-25'),
    ];
    final inPeriod = f.forecast(periods, d('2026-09-27'));
    expect(inPeriod.status, CycleStatus.inPeriod);
    expect(inPeriod.currentPeriodDay, 3);
    expect(inPeriod.expectedCurrentEnd, d('2026-09-29'));
    expect(inPeriod.expectedStart, d('2026-10-23'));

    final older = periods.sublist(0, 3);
    expect(f.forecast(older, d('2026-09-25')).status, CycleStatus.inWindow);
    final late = f.forecast(older, d('2026-10-01'));
    expect(late.status, CycleStatus.afterWindow);
    expect(late.daysAfterWindow, 5);
    expect(late.upcoming.first.start.isAfter(d('2026-10-01')), isTrue,
        reason: 'no estimated period is drawn into the past');
  });

  test('an ongoing period ending after the viewing day counts as ongoing', () {
    final periods = [p('2026-08-01', '2026-08-05'), p('2026-08-29', '2026-09-03')];
    final r = f.forecast(periods, d('2026-08-31'));
    expect(r.status, CycleStatus.inPeriod);
    expect(r.currentPeriodDay, 3);
    expect(r.periodLengths, [5], reason: 'the current period is not finished yet');
  });

  test('implausible cycles are excluded and explained', () {
    final periods = [
      p('2026-01-02', '2026-01-06'),
      p('2026-04-10', '2026-04-14'), // 98 days: missing entry
      p('2026-05-08', '2026-05-12'),
      p('2026-05-18', '2026-05-19'), // 10 days: spotting logged as period
      p('2026-06-05', '2026-06-09'),
      p('2026-07-03', '2026-07-07'),
    ];
    final r = f.forecast(periods, d('2026-07-20'));
    expect(r.excluded.map((e) => e.reason),
        [ExclusionReason.tooLong, ExclusionReason.tooShort]);
    expect(r.cycles.map((c) => c.length), [28, 18, 28]);
    expect(r.medianCycleLength, 28);
    final text = S.of(AppLanguage.de).cycleExplanation(r, Fmt(AppLanguage.de)).join(' ');
    expect(text, contains('Nicht berücksichtigt'));
    expect(text, contains('98 Tagen'));
  });

  test('irregular cycles lower the confidence and widen the window', () {
    final periods = [
      p('2026-01-01', '2026-01-05'),
      p('2026-01-24', '2026-01-28'), // 23
      p('2026-03-01', '2026-03-05'), // 36
      p('2026-03-27', '2026-03-31'), // 26
      p('2026-05-05', '2026-05-09'), // 39
    ];
    final r = f.forecast(periods, d('2026-05-20'));
    expect(r.confidence, ForecastConfidence.low);
    expect(r.windowHalfWidth, greaterThanOrEqualTo(7));
  });

  test('diary mode shows facts without estimates', () {
    final periods = [p('2026-08-01', '2026-08-05'), p('2026-08-29', '2026-09-02')];
    final r = f.forecast(periods, d('2026-09-10'), predictionsEnabled: false);
    expect(r.status, CycleStatus.diaryOnly);
    expect(r.hasEstimate, isFalse);
    expect(r.cycleDay, 13);
    final json = forecastToJson(r, S.of(AppLanguage.en), Fmt(AppLanguage.en));
    expect(json['next_period'], isNull);
    expect(json['predictions_enabled'], false);
  });

  test('JSON contains explanation texts in both languages', () {
    final periods = [p('2026-07-03', '2026-07-07'), p('2026-07-31', '2026-08-04'), p('2026-08-29', '2026-09-02')];
    final r = f.forecast(periods, d('2026-09-23'));
    for (final lang in AppLanguage.values) {
      final json = forecastToJson(r, S.of(lang), Fmt(lang));
      expect((json['explanation'] as List).length, greaterThanOrEqualTo(4));
      expect((json['summary'] as Map)['headline'], isNotEmpty);
    }
    final json = forecastToJson(r, S.of(AppLanguage.en), Fmt(AppLanguage.en));
    expect((json['next_period'] as Map)['expected_start'], '2026-09-27');
    expect(json['status'], 'before_window');
  });
}
