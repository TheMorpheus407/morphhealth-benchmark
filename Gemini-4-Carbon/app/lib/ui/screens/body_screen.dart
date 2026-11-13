/// Weight and Symptoms screen (P05) with `kg`/`lb` conversion, 7d/28d charts,
/// per-symptom trend filtering, and full edit/delete history.
library;

import 'package:flutter/material.dart';

import '../../core/clock.dart';
import '../../core/models.dart';
import '../app_controller.dart';
import '../sheets/entry_editors.dart';
import '../theme.dart';
import '../widgets/trend_chart.dart';

class BodyScreen extends StatefulWidget {
  final AppController controller;

  const BodyScreen({super.key, required this.controller});

  @override
  State<BodyScreen> createState() => _BodyScreenState();
}

class _BodyScreenState extends State<BodyScreen> {
  int _subTab = 0; // 0 = Weight, 1 = Symptoms
  int _windowDays = 28;
  String? _selectedSymptomName;
  bool _filterListBySelectedSymptom = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final s = c.strings;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text('${s.weightTitle} & ${s.symptomsTitle}'),
        actions: [
          if (_subTab == 0)
            Padding(
              padding: const EdgeInsets.only(right: 12),
              child: SegmentedButton<WeightUnit>(
                segments: const [
                  ButtonSegment(value: WeightUnit.kg, label: Text('kg')),
                  ButtonSegment(value: WeightUnit.lb, label: Text('lb')),
                ],
                selected: {c.preferences.weightUnit},
                onSelectionChanged: (sel) {
                  c.updatePreferences(
                    c.preferences.copyWith(weightUnit: sel.first),
                  );
                },
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_body',
        onPressed: () {
          if (_subTab == 0) {
            showWeightEditorSheet(context, c);
          } else {
            showSymptomEditorSheet(context, c);
          }
        },
        icon: const Icon(Icons.add_rounded),
        label: Text(_subTab == 0 ? s.logWeight : s.logSymptom),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<int>(
                segments: [
                  ButtonSegment(
                    value: 0,
                    icon: const Icon(Icons.monitor_weight_outlined, size: 18),
                    label: Text(s.weightTitle),
                  ),
                  ButtonSegment(
                    value: 1,
                    icon: const Icon(Icons.healing_outlined, size: 18),
                    label: Text(s.symptomsTitle),
                  ),
                ],
                selected: {_subTab},
                onSelectionChanged: (v) => setState(() => _subTab = v.first),
              ),
            ),
          ),
          Expanded(
            child: _subTab == 0
                ? _buildWeightContent(context, c, isDark)
                : _buildSymptomsContent(context, c, isDark),
          ),
        ],
      ),
    );
  }

  Widget _buildWeightContent(
    BuildContext context,
    AppController c,
    bool isDark,
  ) {
    final s = c.strings;
    final unit = c.preferences.weightUnit;
    final weights = c.store.allWeights;
    final series = c.store.weightTrendSeries(
      endDateIso: c.selectedDate,
      days: _windowDays,
      unit: unit,
    );
    final accent =
        isDark ? MhColors.weightAccentDark : MhColors.weightAccentLight;

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 88),
      itemCount: weights.length + 1,
      itemBuilder: (ctx, idx) {
        if (idx == 0) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 10,
                        runSpacing: 8,
                        children: [
                          Text(
                            '${s.tr("Gewichtsverlauf", "Weight trend")} (${unit.jsonKey})',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SegmentedButton<int>(
                            segments: [
                              ButtonSegment(
                                value: 7,
                                label: Text(s.window7Days),
                              ),
                              ButtonSegment(
                                value: 28,
                                label: Text(s.window28Days),
                              ),
                            ],
                            selected: {_windowDays},
                            onSelectionChanged: (v) =>
                                setState(() => _windowDays = v.first),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      MhTrendChart(
                        points: series,
                        unit: unit.jsonKey,
                        title: s.weightTitle,
                        color: accent,
                        style: MhChartStyle.line,
                        decimals: 1,
                        localeCode: c.localeCode,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                '${s.tr("Einträge", "Entries")} (${weights.length})',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              if (weights.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Text(
                      s.tr(
                        'Noch keine Gewichtseinträge erfasst.',
                        'No weight entries recorded yet.',
                      ),
                    ),
                  ),
                ),
            ],
          );
        }

        final w = weights[idx - 1];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Card(
            child: ListTile(
              leading: Icon(Icons.monitor_weight_outlined, color: accent),
              title: Text(
                '${w.valueIn(unit).toStringAsFixed(1)} ${unit.jsonKey}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                w.note != null && w.note!.isNotEmpty
                    ? '${w.date} · ${w.note}'
                    : w.date,
              ),
              trailing: const Icon(Icons.edit_outlined, size: 19),
              onTap: () => showWeightEditorSheet(context, c, existing: w),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSymptomsContent(
    BuildContext context,
    AppController c,
    bool isDark,
  ) {
    final s = c.strings;
    final names = c.store.distinctSymptomNames;
    final activeSym = (_selectedSymptomName != null &&
            names.contains(_selectedSymptomName))
        ? _selectedSymptomName
        : (names.isNotEmpty ? names.first : null);

    final allSyms = c.store.allSymptoms;
    final filteredSyms = (_filterListBySelectedSymptom && activeSym != null)
        ? allSyms
            .where((x) => x.name.toLowerCase() == activeSym.toLowerCase())
            .toList()
        : allSyms;

    final series = activeSym != null
        ? c.store.symptomTrendSeries(
            endDateIso: c.selectedDate,
            days: _windowDays,
            symptomName: activeSym,
          )
        : null;
    final accent =
        isDark ? MhColors.symptomAccentDark : MhColors.symptomAccentLight;

    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 88),
      itemCount: filteredSyms.length + 1,
      itemBuilder: (ctx, idx) {
        if (idx == 0) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 10,
                        runSpacing: 8,
                        children: [
                          Text(
                            s.symptomTrendSelect,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          SegmentedButton<int>(
                            segments: [
                              ButtonSegment(
                                value: 7,
                                label: Text(s.window7Days),
                              ),
                              ButtonSegment(
                                value: 28,
                                label: Text(s.window28Days),
                              ),
                            ],
                            selected: {_windowDays},
                            onSelectionChanged: (v) =>
                                setState(() => _windowDays = v.first),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (names.isEmpty)
                        Text(
                          s.tr(
                            'Erfasse ein Symptom mit Intensität 0–10, um dessen Verlauf auszuwerten.',
                            'Record a symptom with intensity 0–10 to inspect its trend.',
                          ),
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onSurfaceVariant,
                          ),
                        )
                      else ...[
                        DropdownButtonFormField<String>(
                          initialValue: activeSym,
                          isExpanded: true,
                          items: [
                            for (final n in names)
                              DropdownMenuItem(value: n, child: Text(n)),
                          ],
                          onChanged: (v) =>
                              setState(() => _selectedSymptomName = v),
                        ),
                        const SizedBox(height: 12),
                        MhTrendChart(
                          points: series!,
                          unit: '/10',
                          title: activeSym!,
                          color: accent,
                          style: MhChartStyle.line,
                          fixedMinY: 0,
                          fixedMaxY: 10,
                          decimals: 0,
                          localeCode: c.localeCode,
                        ),
                        const SizedBox(height: 6),
                        FilterChip(
                          label: Text(
                            s.tr(
                              'Liste auf „$activeSym“ filtern',
                              'Filter list to "$activeSym"',
                            ),
                          ),
                          selected: _filterListBySelectedSymptom,
                          onSelected: (v) => setState(
                            () => _filterListBySelectedSymptom = v,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                '${s.tr("Einträge", "Entries")} (${filteredSyms.length})',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              if (filteredSyms.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(18),
                    child: Text(
                      s.tr(
                        'Noch keine Symptome erfasst.',
                        'No symptoms recorded yet.',
                      ),
                    ),
                  ),
                ),
            ],
          );
        }

        final sym = filteredSyms[idx - 1];
        return Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Card(
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: accent.withValues(alpha: 0.16),
                child: Text(
                  '${sym.intensity}',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    color: accent,
                  ),
                ),
              ),
              title: Text(
                sym.name,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              subtitle: Text(
                [
                  sym.date,
                  IsoDate.extractTimeHm(sym.recordedAt),
                  '${sym.intensity}/10',
                  if (sym.note != null && sym.note!.isNotEmpty) sym.note!,
                ].join(' · '),
              ),
              trailing: const Icon(Icons.edit_outlined, size: 19),
              onTap: () => showSymptomEditorSheet(context, c, existing: sym),
            ),
          ),
        );
      },
    );
  }
}
