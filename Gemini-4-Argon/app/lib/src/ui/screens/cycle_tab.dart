import 'package:flutter/material.dart';
import '../../core/models.dart';
import '../app_state.dart';
import '../modals/entry_modals.dart';
import '../widgets/charts.dart';

class CycleTab extends StatelessWidget {
  final MorphHealthController ctrl;

  const CycleTab({super.key, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final s = ctrl.s;
    final lang = ctrl.lang;
    final periods = ctrl.repository.allPeriodEntries;
    final forecast = ctrl.currentCycleForecast;
    final showPredictions = ctrl.settings.cyclePredictionsEnabled;
    final dayPeriods = ctrl.selectedDayPeriods;
    final daySymptoms = ctrl.selectedDaySymptoms;

    final symptomDates = <String>{
      for (final sym in ctrl.repository.allSymptomEntries) sym.date,
    };

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 80),
      children: [
        // Top Action Bar
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            FilledButton.icon(
              icon: const Icon(Icons.add),
              label: Text(s.logPeriod),
              onPressed: () => showPeriodEntryDialog(context, ctrl),
            ),
            OutlinedButton.icon(
              icon: const Icon(Icons.healing_outlined),
              label: Text(s.logSymptom),
              onPressed: () => showSymptomEntryDialog(
                context,
                ctrl,
                defaultDate: ctrl.selectedDate,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Personal Cycle Assessment & Explanation Card (P04)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        s.cycleAssessment,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          s.t('Prognose', 'Forecast'),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        Switch(
                          value: showPredictions,
                          onChanged: (v) => ctrl.updateSettings(
                            ctrl.settings.copyWith(cyclePredictionsEnabled: v),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                if (!showPredictions)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      s.t(
                        'Tagebuch-Modus aktiv: Prognosen sind ausgeblendet. Deine erfassten Perioden und Symptome stehen im Kalender und in der Historie bereit.',
                        'Diary-only mode active: Forecasts are hidden. Your logged periods and symptoms remain available in the calendar and history.',
                      ),
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  )
                else ...[
                  const SizedBox(height: 8),
                  if (forecast.hasSufficientData) ...[
                    Wrap(
                      spacing: 10,
                      runSpacing: 8,
                      children: [
                        _CycleMetricChip(
                          label: s.t('Zyklustag', 'Cycle Day'),
                          value: '${forecast.currentCycleDay ?? '-'}',
                        ),
                        _CycleMetricChip(
                          label: s.t('Nächste Periode ca.', 'Expected Start'),
                          value: forecast.expectedStartDate ?? '-',
                        ),
                        _CycleMetricChip(
                          label: s.t('Planungsfenster', 'Planning Window'),
                          value:
                              '${forecast.windowStartDate ?? '-'} .. ${forecast.windowEndDate ?? '-'}',
                        ),
                        if (forecast.weightedCycleLengthDays != null)
                          _CycleMetricChip(
                            label: s.t('Ø Zykluslänge', 'Avg Cycle Length'),
                            value:
                                '${forecast.weightedCycleLengthDays} ${s.t('Tage', 'd')}',
                          ),
                        if (forecast.averagePeriodDurationDays != null)
                          _CycleMetricChip(
                            label: s.t('Ø Blutungsdauer', 'Avg Duration'),
                            value:
                                '${forecast.averagePeriodDurationDays} ${s.t('Tage', 'd')}',
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context)
                          .colorScheme
                          .surfaceContainerHighest
                          .withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.info_outline, size: 18),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                s.cycleExplanationTitle,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          forecast.explanation(lang),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Interactive Monthly Calendar Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: CycleMonthCalendar(
              selectedDate: ctrl.selectedDate,
              onSelectDate: (ymd) => ctrl.setSelectedDate(ymd),
              periods: periods,
              forecast: forecast,
              showPredictions: showPredictions,
              datesWithSymptoms: symptomDates,
              lang: lang,
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Selected Day Context (Tageskontext inklusive Blutung/Spotting und Symptome - P04)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.t(
                    'Tageskontext (${ctrl.selectedDate})',
                    'Selected Day Context (${ctrl.selectedDate})',
                  ),
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 10),
                if (dayPeriods.isEmpty)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          s.t(
                            'Keine Blutung an diesem Tag protokolliert.',
                            'No bleeding logged on this day.',
                          ),
                        ),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.water_drop_outlined, size: 18),
                        label: Text(s.logPeriod),
                        onPressed: () => showPeriodEntryDialog(
                          context,
                          ctrl,
                          defaultStartDate: ctrl.selectedDate,
                        ),
                      ),
                    ],
                  )
                else
                  for (final p in dayPeriods)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.favorite,
                        color: Colors.pink.shade500,
                      ),
                      title: Text(
                        '${s.t('Periode', 'Period')}: ${p.startDate}'
                        '${p.endDate != null ? ' – ${p.endDate}' : ''}',
                      ),
                      subtitle: Text(
                        '${BleedingIntensity.label(p.intensityForDate(ctrl.selectedDate) ?? p.intensity, lang)}'
                        '${p.notes != null ? ' · ${p.notes}' : ''}',
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        onPressed: () => showPeriodEntryDialog(
                          context,
                          ctrl,
                          existing: p,
                        ),
                      ),
                    ),
                const Divider(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        '${s.domainSymptoms} (${daySymptoms.length})',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(s.logSymptom),
                      onPressed: () => showSymptomEntryDialog(
                        context,
                        ctrl,
                        defaultDate: ctrl.selectedDate,
                      ),
                    ),
                  ],
                ),
                if (daySymptoms.isEmpty)
                  Text(
                    s.t(
                      'Keine Symptome für ${ctrl.selectedDate} erfasst.',
                      'No symptoms logged for ${ctrl.selectedDate}.',
                    ),
                    style: Theme.of(context).textTheme.bodySmall,
                  )
                else
                  for (final sym in daySymptoms)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: CircleAvatar(
                        radius: 14,
                        backgroundColor:
                            Colors.deepPurple.withValues(alpha: 0.15),
                        child: Text(
                          '${sym.intensity}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(sym.name),
                      subtitle: sym.notes != null ? Text(sym.notes!) : null,
                      trailing: IconButton(
                        icon: const Icon(Icons.edit_outlined, size: 18),
                        onPressed: () => showSymptomEntryDialog(
                          context,
                          ctrl,
                          existing: sym,
                        ),
                      ),
                    ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // Period History Card
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${s.periodHistory} (${periods.length})',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
                const SizedBox(height: 8),
                if (periods.isEmpty)
                  Text(
                    s.t(
                      'Noch keine Perioden erfasst. Tippe oben auf „Periode erfassen“, um vergangene oder aktuelle Perioden hinzuzufügen.',
                      'No periods logged yet. Tap "Log Period" above to record past or current periods.',
                    ),
                  )
                else
                  for (final p in periods)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(
                        Icons.calendar_month,
                        color: Colors.pink.shade400,
                      ),
                      title: Text(
                        '${p.startDate}${p.endDate != null ? ' – ${p.endDate}' : ''}',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        '${BleedingIntensity.label(p.intensity, lang)} · '
                        '${p.durationDays} ${s.t('Tage', 'days')}'
                        '${p.notes != null ? ' · ${p.notes}' : ''}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: s.edit,
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () => showPeriodEntryDialog(
                              context,
                              ctrl,
                              existing: p,
                            ),
                          ),
                          IconButton(
                            tooltip: s.delete,
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () => ctrl.deletePeriodEntry(p.id),
                          ),
                        ],
                      ),
                    ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CycleMetricChip extends StatelessWidget {
  final String label;
  final String value;

  const _CycleMetricChip({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.pink.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall,
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}
