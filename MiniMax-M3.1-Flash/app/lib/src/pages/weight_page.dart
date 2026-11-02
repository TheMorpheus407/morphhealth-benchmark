import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:morphhealth_core/morphhealth_core.dart';

import '../l10n/app_localizations.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import 'home_shell.dart';

/// Weight entries with their trend.
class WeightPage extends StatefulWidget {
  const WeightPage({super.key});

  @override
  State<WeightPage> createState() => _WeightPageState();
}

class _WeightPageState extends State<WeightPage> {
  int _days = 28;

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final List<WeightEntry> entries = state.weight.entries;
    final WeightUnit unit = state.settings.weightUnit;
    final String unitLabel = unit == WeightUnit.lb ? 'lb' : 'kg';
    final String today = DateMath.format(DateTime.now());
    final String from = DateMath.addDays(today, -(_days - 1));

    return Scaffold(
      appBar: AppBar(title: Text(l10n.t('weight.title'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(context),
        icon: const Icon(Icons.add),
        label: Text(l10n.t('weight.add_entry')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
        children: <Widget>[
          SectionCard(
            title: l10n.t('weight.trend'),
            subtitle: l10n.t(
              'nutrition.trend_days',
              <String, String>{'days': '$_days'},
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Align(
                  alignment: Alignment.centerRight,
                  child: SegmentedSwitch<int>(
                    value: _days,
                    options: const <int, String>{7: '7', 28: '28'},
                    onChanged: (int value) => setState(() => _days = value),
                  ),
                ),
                const SizedBox(height: 8),
                SimpleLineChart(
                  values: <double>[
                    for (final WeightEntry entry
                        in state.weight.inRange(from, today))
                      WeightService.toDisplay(entry.valueKg, unit),
                  ],
                  labels: <String>[
                    formatDay(context, from),
                    formatDay(context, today),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    Expanded(
                      child: _stat(
                        context,
                        l10n.t('weight.average'),
                        _value(
                          state.weight.average(from, today),
                          unit,
                        ),
                      ),
                    ),
                    Expanded(
                      child: _stat(
                        context,
                        l10n.t('weight.min_max'),
                        '${_value(state.weight.minimum(from, today), unit)} / '
                        '${_value(state.weight.maximum(from, today), unit)}',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: l10n.t('weight.title'),
            child: entries.isEmpty
                ? EmptyState(message: l10n.t('weight.empty'))
                : Column(
                    children: <Widget>[
                      for (final WeightEntry entry in entries.reversed)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          dense: true,
                          title: Text(
                            '${WeightService.toDisplay(entry.valueKg, unit).toStringAsFixed(1)} $unitLabel',
                            style: theme.textTheme.bodyLarge,
                          ),
                          subtitle: Text(
                            <String>[
                              formatDay(context, entry.date, withYear: true),
                              if (entry.note != null) entry.note!,
                            ].join(' · '),
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 20),
                            tooltip: l10n.t('common.edit'),
                            onPressed: () => _edit(context, entry: entry),
                          ),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  static String _value(double? kilograms, WeightUnit unit) {
    if (kilograms == null) return '–';
    return WeightService.toDisplay(kilograms, unit).toStringAsFixed(1);
  }

  Widget _stat(BuildContext context, String label, String value) {
    final ThemeData theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(value, style: theme.textTheme.titleMedium),
      ],
    );
  }

  Future<void> _edit(BuildContext context, {WeightEntry? entry}) async {
    final AppState state = AppScope.of(context);
    final AppLocalizations l10n = context.l10n;
    final TextEditingController controller = TextEditingController(
      text: entry == null
          ? ''
          : WeightService.toDisplay(
              entry.valueKg,
              state.settings.weightUnit,
            ).toStringAsFixed(1),
    );
    final TextEditingController note =
        TextEditingController(text: entry?.note ?? '');
    final DateTime initial = entry == null
        ? DateTime.now()
        : DateTime.fromMillisecondsSinceEpoch(entry.loggedAtMs);
    DateTime moment = initial;

    final bool? saved = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => StatefulBuilder(
        builder: (BuildContext context, StateSetter setState) {
          return AlertDialog(
            title: Text(
              entry == null
                  ? l10n.t('weight.add_entry')
                  : l10n.t('weight.edit_entry'),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextField(
                  controller: controller,
                  autofocus: true,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: state.settings.weightUnit == WeightUnit.lb
                        ? 'lb'
                        : 'kg',
                  ),
                ),
                const SizedBox(height: 10),
                OutlinedButton.icon(
                  onPressed: () async {
                    final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: moment,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) {
                      setState(() {
                        moment = DateTime(
                          picked.year,
                          picked.month,
                          picked.day,
                          moment.hour,
                          moment.minute,
                        );
                      });
                    }
                  },
                  icon: const Icon(Icons.calendar_today_outlined),
                  label: Text(
                    DateFormat.yMd(
                      Localizations.localeOf(context).toLanguageTag(),
                    ).format(moment),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: note,
                  decoration: InputDecoration(
                    labelText:
                        '${l10n.t('common.note')} (${l10n.t('common.optional')})',
                  ),
                ),
              ],
            ),
            actions: <Widget>[
              if (entry != null)
                TextButton(
                  onPressed: () async {
                    await state.deleteWeight(entry.id);
                    if (context.mounted) Navigator.of(context).pop(false);
                  },
                  child: Text(l10n.t('common.delete')),
                ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.t('common.cancel')),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: Text(l10n.t('common.save')),
              ),
            ],
          );
        },
      ),
    );

    if (saved == true) {
      final double? raw =
          double.tryParse(controller.text.trim().replaceAll(',', '.'));
      if (raw != null && raw > 0) {
        await state.upsertWeight(WeightEntry(
          id: entry?.id ?? Ids.newId(),
          date: DateMath.format(moment),
          valueKg: WeightService.toKilograms(
            raw,
            state.settings.weightUnit,
          ),
          loggedAtMs: moment.millisecondsSinceEpoch,
          note: note.text.trim().isEmpty ? null : note.text.trim(),
          createdAtMs: entry?.createdAtMs ?? DateTime.now().millisecondsSinceEpoch,
          updatedAtMs: DateTime.now().millisecondsSinceEpoch,
        ));
      }
    }
    controller.dispose();
    note.dispose();
  }
}
