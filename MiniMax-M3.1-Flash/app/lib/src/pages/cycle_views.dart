import 'package:flutter/material.dart';
import 'package:morphhealth_core/morphhealth_core.dart';

import '../l10n/app_localizations.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import 'home_shell.dart';
import 'period_editor_sheet.dart';

/// The list of all recorded periods.
class CycleHistoryView extends StatelessWidget {
  const CycleHistoryView({super.key});

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final List<PeriodRecord> periods = state.repository.periods.reversed.toList();

    if (periods.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
        children: <Widget>[
          EmptyState(
            message: l10n.t('cycle.empty'),
            icon: Icons.water_drop_outlined,
          ),
        ],
      );
    }

    final List<int> lengths = state.cycle.observedCycleLengths();

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: <Widget>[
        if (lengths.isNotEmpty)
          SectionCard(
            title: l10n.t('cycle.history'),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  '${l10n.t('cycle.avg_cycle')}: '
                  '${(lengths.reduce((int a, int b) => a + b) / lengths.length).toStringAsFixed(1)}',
                ),
                Text(
                  '${l10n.t('cycle.cycle_range')}: '
                  '${lengths.reduce((int a, int b) => a < b ? a : b)} – '
                  '${lengths.reduce((int a, int b) => a > b ? a : b)}',
                ),
              ],
            ),
          ),
        const SizedBox(height: 12),
        for (final PeriodRecord record in periods)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SectionCard(
              onTap: () => PeriodEditorSheet.show(context, record: record),
              child: Row(
                children: <Widget>[
                  Icon(
                    record.spotting
                        ? Icons.water_drop_outlined
                        : Icons.water_drop,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          record.spotting
                              ? l10n.t('cycle.spotting')
                              : l10n.t('cycle.periods'),
                          style: theme.textTheme.titleSmall,
                        ),
                        Text(
                          record.endDate == null
                              ? '${formatDay(context, record.startDate, withYear: true)} –'
                              : '${formatDay(context, record.startDate, withYear: true)} – '
                                  '${formatDay(context, record.endDate!, withYear: true)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        if (record.note != null)
                          Text(
                            record.note!,
                            style: theme.textTheme.bodySmall,
                          ),
                      ],
                    ),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Text(
                        l10n.t('cycle.strength.${record.flow.name}'),
                        style: theme.textTheme.bodySmall,
                      ),
                      if (record.lengthDays != null)
                        Text(
                          '${record.lengthDays} Tage',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

/// The personal assessment of the cycle, derived from the own history.
class CycleForecastView extends StatelessWidget {
  const CycleForecastView({super.key});

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final String today = state.selectedDate;
    final CycleForecast forecast = state.cycle.forecast(today);
    final int? daysUntil = forecast.daysUntilPredictedStart;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: <Widget>[
        SectionCard(
          title: l10n.t('cycle.forecast'),
          subtitle: l10n.t('cycle.forecast_hint'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (!forecast.hasData)
                EmptyState(message: l10n.t('cycle.before_first'))
              else ...<Widget>[
                if (forecast.cycleDay != null)
                  Text(
                    l10n.t(
                      'cycle.cycle_day',
                      <String, String>{'day': '${forecast.cycleDay}'},
                    ),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                const SizedBox(height: 12),
                _row(
                  context,
                  l10n.t('cycle.avg_cycle'),
                  forecast.averageCycleLength == null
                      ? '–'
                      : forecast.averageCycleLength!.toStringAsFixed(1),
                ),
                _row(
                  context,
                  l10n.t('cycle.avg_period'),
                  forecast.averagePeriodLength == null
                      ? '–'
                      : forecast.averagePeriodLength!.toStringAsFixed(1),
                ),
                _row(
                  context,
                  l10n.t('cycle.cycle_range'),
                  forecast.minCycleLength == null
                      ? '–'
                      : '${forecast.minCycleLength} – ${forecast.maxCycleLength}',
                ),
                _row(
                  context,
                  l10n.t('cycle.next_start'),
                  forecast.predictedNextStart == null
                      ? '–'
                      : formatDay(
                          context,
                          forecast.predictedNextStart!,
                          withYear: true,
                        ),
                ),
                if (forecast.predictedWindowStart != null &&
                    forecast.predictedWindowEnd != null)
                  _row(
                    context,
                    l10n.t('cycle.next_window'),
                    '${formatDay(context, forecast.predictedWindowStart!)} – '
                    '${formatDay(context, forecast.predictedWindowEnd!)}',
                  ),
                if (daysUntil != null && daysUntil >= 0)
                  _row(
                    context,
                    l10n.t(
                      'cycle.days_until',
                      <String, String>{'days': '$daysUntil'},
                    ),
                    '$daysUntil',
                  ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: l10n.t('cycle.forecast'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              for (final String line in forecast.explanation)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Padding(
                        padding: const EdgeInsets.only(top: 6, right: 8),
                        child: Container(
                          width: 5,
                          height: 5,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      Expanded(
                        child: Text(line, style: theme.textTheme.bodyMedium),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _row(BuildContext context, String label, String? raw) {
    final String value = raw ?? '–';
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(label, style: theme.textTheme.bodyMedium),
          ),
          Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
