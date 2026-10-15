import 'package:flutter/material.dart';
import '../app_state.dart';
import '../modals/entry_modals.dart';
import '../widgets/charts.dart';

class WeightSymptomsTab extends StatelessWidget {
  final MorphHealthController ctrl;

  const WeightSymptomsTab({super.key, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final s = ctrl.s;
    final unit = ctrl.settings.weightUnit;
    final weights = ctrl.repository.allWeightEntries;
    final symptoms = ctrl.repository.allSymptomEntries;
    final distinctSymptomNames = ctrl.repository.distinctSymptomNames;

    final weightSeries = ctrl.repository
        .getWeightSeries(
          endDate: ctrl.selectedDate,
          days: ctrl.selectedTrendDays,
        )
        .map((w) => TrendPoint(date: w.date, value: w.valueInUnit(unit)))
        .toList();

    final currentSymptom =
        (ctrl.selectedSymptomForTrend != null &&
                distinctSymptomNames.contains(ctrl.selectedSymptomForTrend))
            ? ctrl.selectedSymptomForTrend
            : (distinctSymptomNames.isNotEmpty
                ? distinctSymptomNames.first
                : null);

    final symptomSeries = currentSymptom != null
        ? ctrl.repository
            .getSymptomSeries(
              symptomName: currentSymptom,
              endDate: ctrl.selectedDate,
              days: ctrl.selectedTrendDays,
            )
            .map((e) => TrendPoint(date: e.date, value: e.intensity.toDouble()))
            .toList()
        : const <TrendPoint>[];

    return ListView(
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 80),
      children: [
        // Top Action Bar
        Wrap(
          spacing: 8,
          runSpacing: 8,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            FilledButton.icon(
              icon: const Icon(Icons.monitor_weight_outlined, size: 18),
              label: Text(s.logWeight),
              onPressed: () => showWeightEntryDialog(context, ctrl),
            ),
            FilledButton.tonalIcon(
              icon: const Icon(Icons.healing_outlined, size: 18),
              label: Text(s.logSymptom),
              onPressed: () => showSymptomEntryDialog(context, ctrl),
            ),
            SegmentedButton<int>(
              segments: [
                ButtonSegment(value: 7, label: Text(s.days7)),
                ButtonSegment(value: 28, label: Text(s.days28)),
              ],
              selected: {ctrl.selectedTrendDays},
              onSelectionChanged: (sel) => ctrl.setTrendDays(sel.first),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // 1. Weight Section (P05)
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
                        '${s.domainWeight} (${weights.length})',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'kg', label: Text('kg')),
                        ButtonSegment(value: 'lb', label: Text('lb')),
                      ],
                      selected: {unit},
                      onSelectionChanged: (sel) =>
                          ctrl.setWeightUnit(sel.first),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TrendSeriesChart(
                  points: weightSeries,
                  unit: unit,
                  color: Colors.indigo.shade500,
                  decimals: 1,
                  connectLine: true,
                  emptyLabel: s.t(
                    'Keine Gewichtseinträge im gewählten Zeitraum',
                    'No weight entries in selected period',
                  ),
                ),
                const Divider(height: 20),
                if (weights.isEmpty)
                  Text(
                    s.t(
                      'Noch keine Gewichtseinträge vorhanden.',
                      'No weight entries recorded yet.',
                    ),
                  )
                else
                  for (final w in weights.take(15))
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: const Icon(Icons.monitor_weight_outlined),
                      title: Text(
                        '${w.valueInUnit(unit).toStringAsFixed(1)} $unit '
                        '(${unit == 'kg' ? '${w.weightLb.toStringAsFixed(1)} lb' : '${w.weightKg.toStringAsFixed(1)} kg'})',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        '${w.date}${w.notes != null ? ' · ${w.notes}' : ''}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: s.edit,
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            onPressed: () => showWeightEntryDialog(
                              context,
                              ctrl,
                              existing: w,
                            ),
                          ),
                          IconButton(
                            tooltip: s.delete,
                            icon: const Icon(Icons.delete_outline, size: 18),
                            onPressed: () => ctrl.deleteWeightEntry(w.id),
                          ),
                        ],
                      ),
                    ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),

        // 2. Symptoms Section (P05: frei wählbarer Name, Intensität 0 bis 10, Verlauf nach gewähltem Symptom)
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
                        '${s.domainSymptoms} (${symptoms.length})',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                      ),
                    ),
                    if (distinctSymptomNames.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: DropdownButton<String>(
                          value: currentSymptom,
                          isDense: true,
                          isExpanded: true,
                          items: [
                            for (final name in distinctSymptomNames)
                              DropdownMenuItem(
                                value: name,
                                child: Text(
                                  name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: (v) => ctrl.setSelectedSymptomForTrend(v),
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                TrendSeriesChart(
                  points: symptomSeries,
                  unit: '/ 10',
                  color: Colors.deepPurple.shade400,
                  decimals: 0,
                  connectLine: true,
                  emptyLabel: s.t(
                    'Keine Einträge für dieses Symptom im Zeitraum',
                    'No entries for this symptom in period',
                  ),
                ),
                const Divider(height: 20),
                if (symptoms.isEmpty)
                  Text(
                    s.t(
                      'Noch keine Symptome erfasst. Tippe auf „Symptom erfassen“, um beliebige Symptome mit Intensität 0–10 zu protokollieren.',
                      'No symptoms recorded yet. Tap "Log Symptom" to record any symptom with intensity 0–10.',
                    ),
                  )
                else
                  for (final sym in symptoms.take(20))
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      leading: CircleAvatar(
                        radius: 15,
                        backgroundColor:
                            Colors.deepPurple.withValues(alpha: 0.14),
                        child: Text(
                          '${sym.intensity}',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      title: Text(
                        sym.name,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        '${sym.date} · ${s.t('Intensität', 'Intensity')} ${sym.intensity}/10'
                        '${sym.notes != null ? ' · ${sym.notes}' : ''}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: s.edit,
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            onPressed: () => showSymptomEntryDialog(
                              context,
                              ctrl,
                              existing: sym,
                            ),
                          ),
                          IconButton(
                            tooltip: s.delete,
                            icon: const Icon(Icons.delete_outline, size: 18),
                            onPressed: () => ctrl.deleteSymptomEntry(sym.id),
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
