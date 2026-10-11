// Gewichtsbereich: erfassen, Verlauf als Liniendiagramm, Historie.
library;

import 'package:flutter/material.dart';

import '../core/parse.dart';
import '../data/repository.dart';
import '../l10n/app_strings.dart';
import '../model/cycle.dart';
import 'scope.dart';
import 'widgets.dart';

/// Umrechnungsfaktor kg → lb (Anzeigeeinheit, kanonisch gespeichert wird kg).
const double kgPerLb = 2.2046226218;

class WeightScreen extends StatelessWidget {
  const WeightScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = StringsScope.of(context);
    final MorphRepository repo = MorphScope.repoOf(context);
    return ListenableBuilder(
      listenable: MorphScope.listenableOf(context),
      builder: (BuildContext context, Widget? _) {
        final List<WeightEntry> entries = repo.sortedWeightEntries;
        final List<WeightEntry> chart = entries.length > 28
            ? entries.sublist(entries.length - 28)
            : entries;
        final String unit = repo.settings.weightUnit;
        final WeightEntry? latest = entries.isEmpty ? null : entries.last;
        return ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: <Widget>[
            SectionCard(
              title: strings.weightTitle,
              trailing: IconButton(
                tooltip: strings.addWeight,
                icon: const Icon(Icons.add),
                onPressed: () => _add(context, repo),
              ),
              child: latest == null
                  ? Text(strings.noWeights)
                  : StatRow(
                      label: strings.latestWeight,
                      value:
                          '${strings.formatWeight(latest.weightKg, unit)} · ${strings.formatDateShort(parseDate(latest.date)!)}',
                    ),
            ),
            if (chart.length >= 2)
              SectionCard(
                title: strings.weightHistory,
                child: LineChart(
                  values: <double>[
                    for (final WeightEntry e in chart)
                      unit == 'lb' ? e.weightKg * kgPerLb : e.weightKg,
                  ],
                  labels: <String>[
                    for (final WeightEntry e in chart)
                      strings.formatDateShort(parseDate(e.date)!),
                  ],
                  unit: unit,
                  height: 180,
                ),
              ),
            SectionCard(
              title: strings.weightHistory,
              child: entries.isEmpty
                  ? EmptyState(
                      icon: Icons.monitor_weight_outlined,
                      text: strings.noWeights,
                    )
                  : Column(
                      children: <Widget>[
                        for (final WeightEntry e in entries.reversed)
                          _entryTile(context, strings, repo, e, unit),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _entryTile(BuildContext context, AppStrings strings,
      MorphRepository repo, WeightEntry e, String unit) {
    final String subtitle = '${strings.formatDateShort(parseDate(e.date)!)}'
        '${e.time != null ? ' · ${e.time}' : ''}'
        '${e.note != null && e.note!.isNotEmpty ? ' · ${e.note}' : ''}';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: const Icon(Icons.monitor_weight_outlined, size: 20),
      title: Text(strings.formatWeight(e.weightKg, unit)),
      subtitle: Text(subtitle),
      trailing: IconButton(
        tooltip: strings.a11yDelete,
        icon: const Icon(Icons.delete_outline),
        onPressed: () async {
          if (await confirmDelete(context)) {
            await repo.deleteWeightEntry(e.id);
            if (context.mounted) showInfo(context, strings.weightDeleted);
          }
        },
      ),
      onTap: () => _edit(context, repo, e),
    );
  }

  Future<void> _add(BuildContext context, MorphRepository repo) async {
    final AppStrings strings = StringsScope.of(context);
    final WeightInput? input =
        await showWeightDialog(context, date: todayString());
    if (input == null || !context.mounted) return;
    await repo.addWeightEntry(WeightEntry(
      id: '',
      date: input.date,
      time: input.time,
      weightKg: input.weightKg,
      note: input.note,
    ));
    if (context.mounted) showInfo(context, strings.weightSaved);
  }

  Future<void> _edit(
      BuildContext context, MorphRepository repo, WeightEntry e) async {
    final AppStrings strings = StringsScope.of(context);
    final WeightInput? input =
        await showWeightDialog(context, date: e.date, initial: e);
    if (input == null || !context.mounted) return;
    e.date = input.date;
    e.time = input.time;
    e.weightKg = input.weightKg;
    e.note = input.note;
    await repo.updateWeightEntry(e);
    if (context.mounted) showInfo(context, strings.weightSaved);
  }
}

// ------------------------------------------------------------------ Dialog

/// Eingabewerte des Gewichtsdialogs (kanonisch in kg).
class WeightInput {
  final double weightKg;
  final String date;
  final String? time;
  final String? note;

  const WeightInput({
    required this.weightKg,
    required this.date,
    this.time,
    this.note,
  });
}

/// Gewichtsdialog: Wert (in der eingestellten Anzeigeeinheit), Datum,
/// Uhrzeit, Notiz. Texte und Einheit werden aus dem aufrufenden Kontext
/// übernommen (Dialog-Routen liegen über den Scopes).
Future<WeightInput?> showWeightDialog(
  BuildContext context, {
  required String date,
  WeightEntry? initial,
}) async {
  final AppStrings strings = StringsScope.of(context);
  final String unit = MorphScope.repoOf(context).settings.weightUnit;
  return showDialog<WeightInput>(
    context: context,
    builder: (BuildContext context) => _WeightDialog(
      strings: strings,
      unit: unit,
      initialDate: initial?.date ?? date,
      initial: initial,
    ),
  );
}

class _WeightDialog extends StatefulWidget {
  final AppStrings strings;
  final String unit;
  final String initialDate;
  final WeightEntry? initial;

  const _WeightDialog({
    required this.strings,
    required this.unit,
    required this.initialDate,
    this.initial,
  });

  @override
  State<_WeightDialog> createState() => _WeightDialogState();
}

class _WeightDialogState extends State<_WeightDialog> {
  late final TextEditingController _weightController;
  late final TextEditingController _dateController;
  late final TextEditingController _timeController;
  late final TextEditingController _noteController;
  late DateTime _date;
  TimeOfDay? _time;

  @override
  void initState() {
    super.initState();
    final WeightEntry? init = widget.initial;
    final double display = init == null
        ? 0
        : (widget.unit == 'lb' ? init.weightKg * kgPerLb : init.weightKg);
    _weightController = TextEditingController(
      text: init == null
          ? ''
          : widget.strings.formatNumber(display, fractionDigits: 1),
    );
    _date = parseDate(widget.initialDate) ??
        DateTime.utc(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    _dateController =
        TextEditingController(text: widget.strings.formatDateShort(_date));
    final DateTime? t = parseTimeOfDay(init?.time);
    _time = t == null ? null : TimeOfDay(hour: t.hour, minute: t.minute);
    _timeController = TextEditingController(text: _formatTime(_time));
    _noteController = TextEditingController(text: init?.note ?? '');
  }

  @override
  void dispose() {
    _weightController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  static String _formatTime(TimeOfDay? t) {
    if (t == null) return '';
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = widget.strings;
    final String unitLabel =
        widget.unit == 'lb' ? strings.weightLbLabel : strings.weightKgLabel;
    return AlertDialog(
      title: Text(
          widget.initial == null ? strings.addWeight : strings.editWeight),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            NumberField(controller: _weightController, label: unitLabel),
            const SizedBox(height: 8),
            TextField(
              readOnly: true,
              controller: _dateController,
              decoration: InputDecoration(
                labelText: strings.dateLabel,
                suffixIcon: const Icon(Icons.calendar_today_outlined),
              ),
              onTap: () async {
                final DateTime? picked = await pickDate(context, initial: _date);
                if (picked != null && mounted) {
                  setState(() {
                    _date = DateTime.utc(picked.year, picked.month, picked.day);
                    _dateController.text = strings.formatDateShort(_date);
                  });
                }
              },
            ),
            const SizedBox(height: 8),
            TextField(
              readOnly: true,
              controller: _timeController,
              decoration: InputDecoration(
                labelText: strings.timeLabel,
                hintText: strings.optionalLabel,
                suffixIcon: _time == null
                    ? const Icon(Icons.schedule_outlined)
                    : IconButton(
                        tooltip: strings.clearLabel,
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(() {
                          _time = null;
                          _timeController.text = '';
                        }),
                      ),
              ),
              onTap: () async {
                final TimeOfDay? picked = await pickTime(context,
                    initial: _time ?? TimeOfDay.now());
                if (picked != null && mounted) {
                  setState(() {
                    _time = picked;
                    _timeController.text = _formatTime(picked);
                  });
                }
              },
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _noteController,
              decoration: InputDecoration(
                labelText: strings.noteLabel,
                hintText: strings.optionalLabel,
              ),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(strings.cancel),
        ),
        FilledButton(
          onPressed: _save,
          child: Text(strings.save),
        ),
      ],
    );
  }

  void _save() {
    final AppStrings strings = widget.strings;
    final double? w = NumberField.parse(strings, _weightController.text);
    if (w == null || w <= 0) {
      showError(context, strings.invalidNumber);
      return;
    }
    final double kg = widget.unit == 'lb' ? w / kgPerLb : w;
    final String note = _noteController.text.trim();
    Navigator.of(context).pop(WeightInput(
      weightKg: kg,
      date: formatDate(_date),
      time: _time == null
          ? null
          : '${_time!.hour.toString().padLeft(2, '0')}:${_time!.minute.toString().padLeft(2, '0')}',
      note: note.isEmpty ? null : note,
    ));
  }
}
