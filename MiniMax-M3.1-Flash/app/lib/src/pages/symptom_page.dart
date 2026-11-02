import 'package:flutter/material.dart';
import 'package:morphhealth_core/morphhealth_core.dart';

import '../l10n/app_localizations.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'home_shell.dart';
import 'symptom_entry_sheet.dart';

/// Symptom entries with a per symptom trend.
class SymptomPage extends StatefulWidget {
  const SymptomPage({super.key});

  @override
  State<SymptomPage> createState() => _SymptomPageState();
}

class _SymptomPageState extends State<SymptomPage> {
  String? _selected;
  int _days = 28;

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final List<String> names = state.symptoms.names;
    final String? selected = names.contains(_selected) ? _selected : null;
    final List<SymptomEntry> filtered = selected == null
        ? state.symptoms.entries
        : state.symptoms.byName(selected);
    final String today = DateMath.format(DateTime.now());
    final String from = DateMath.addDays(today, -(_days - 1));
    final List<SymptomEntry> trend = filtered
        .where((SymptomEntry e) => DateMath.inRange(e.date, from, today))
        .toList(growable: false);

    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('symptom.title'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => SymptomEntrySheet.show(context),
        icon: const Icon(Icons.add),
        label: Text(l10n.t('symptom.add_entry')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        children: <Widget>[
          if (names.isNotEmpty)
            SectionCard(
              title: l10n.t('symptom.trend'),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: <Widget>[
                      ChoiceChip(
                        label: Text(l10n.t('symptom.all')),
                        selected: selected == null,
                        onSelected: (bool _) => setState(() => _selected = null),
                      ),
                      for (final String name in names)
                        ChoiceChip(
                          label: Text(name),
                          selected: selected == name,
                          onSelected: (bool value) =>
                              setState(() => _selected = value ? name : null),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: SegmentedSwitch<int>(
                      value: _days,
                      options: const <int, String>{7: '7', 28: '28'},
                      onChanged: (int value) => setState(() => _days = value),
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (trend.isEmpty)
                    EmptyState(message: l10n.t('nutrition.no_trend_data'))
                  else
                    SimpleLineChart(
                      values: <double>[
                        for (final SymptomEntry entry in trend)
                          entry.intensity.toDouble(),
                      ],
                      labels: <String>[
                        formatDay(context, from),
                        formatDay(context, today),
                      ],
                      height: 130,
                      color: theme.colorScheme.tertiary,
                    ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          SectionCard(
            title: l10n.t('symptom.title'),
            child: filtered.isEmpty
                ? EmptyState(message: l10n.t('symptom.empty'))
                : Column(
                    children: <Widget>[
                      for (final SymptomEntry entry in filtered.reversed)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          leading: Container(
                            width: 12,
                            height: 12,
                            decoration: BoxDecoration(
                              color: IntensityColors.of(context, entry.intensity),
                              shape: BoxShape.circle,
                            ),
                          ),
                          title: Text(entry.name),
                          subtitle: Text(
                            <String>[
                              formatDay(context, entry.date, withYear: true),
                              '${entry.intensity}/10',
                              if (entry.note != null) entry.note!,
                            ].join(' · '),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 20),
                            tooltip: l10n.t('common.edit'),
                            onPressed: () => SymptomEntrySheet.show(
                              context,
                              entry: entry,
                            ),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
