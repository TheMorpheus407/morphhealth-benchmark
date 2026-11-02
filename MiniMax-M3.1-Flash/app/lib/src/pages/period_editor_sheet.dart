import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:morphhealth_core/morphhealth_core.dart';

import '../l10n/app_localizations.dart';
import '../state/app_state.dart';

/// Creates or edits a period record.
class PeriodEditorSheet extends StatefulWidget {
  const PeriodEditorSheet({super.key, this.record});

  final PeriodRecord? record;

  static Future<bool?> show(BuildContext context, {PeriodRecord? record}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext context) => PeriodEditorSheet(record: record),
    );
  }

  @override
  State<PeriodEditorSheet> createState() => _PeriodEditorSheetState();
}

class _PeriodEditorSheetState extends State<PeriodEditorSheet> {
  late DateTime _start;
  DateTime? _end;
  late FlowStrength _flow;
  bool _spotting = false;
  late final TextEditingController _note;

  @override
  void initState() {
    super.initState();
    final PeriodRecord? record = widget.record;
    _start = record != null
        ? DateMath.parse(record.startDate)
        : DateTime.now();
    _end = record?.endDate == null ? null : DateMath.parse(record!.endDate!);
    _flow = record?.flow ?? FlowStrength.medium;
    _spotting = record?.spotting ?? false;
    _note = TextEditingController(text: record?.note ?? '');
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final String language = Localizations.localeOf(context).languageCode;

    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 12,
        bottom: MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).padding.bottom +
            20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    widget.record == null
                        ? l10n.t('cycle.add_period')
                        : l10n.t('cycle.edit_period'),
                    style: theme.textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                  tooltip: l10n.t('common.close'),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _dateRow(
              context,
              label: l10n.t('cycle.start_date'),
              date: _start,
              onPick: (DateTime value) => setState(() {
                _start = value;
                if (_end != null &&
                    DateMath.before(
                      DateMath.format(_end!),
                      DateMath.format(_start),
                    )) {
                  _end = _start;
                }
              }),
              language: language,
            ),
            const SizedBox(height: 10),
            _dateRow(
              context,
              label: l10n.t('cycle.end_date'),
              date: _end,
              hint: l10n.t('cycle.end_date_hint'),
              onPick: (DateTime value) => setState(() => _end = value),
              language: language,
              onClear: () => setState(() => _end = null),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<FlowStrength>(
              initialValue: _flow,
              decoration:
                  InputDecoration(labelText: l10n.t('cycle.strength')),
              items: <DropdownMenuItem<FlowStrength>>[
                for (final FlowStrength flow in FlowStrength.values)
                  DropdownMenuItem<FlowStrength>(
                    value: flow,
                    child: Text(l10n.t('cycle.strength.${flow.name}')),
                  ),
              ],
              onChanged: (FlowStrength? value) {
                if (value == null) return;
                setState(() => _flow = value);
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l10n.t('cycle.spotting')),
              subtitle: Text(l10n.t('cycle.spotting_hint')),
              value: _spotting,
              onChanged: (bool value) => setState(() => _spotting = value),
            ),
            TextField(
              controller: _note,
              maxLines: 2,
              decoration: InputDecoration(
                labelText:
                    '${l10n.t('common.note')} (${l10n.t('common.optional')})',
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: <Widget>[
                if (widget.record != null)
                  IconButton(
                    onPressed: _delete,
                    icon: const Icon(Icons.delete_outline),
                    tooltip: l10n.t('common.delete'),
                  ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.check),
                  label: Text(l10n.t('common.save')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _dateRow(
    BuildContext context, {
    required String label,
    required DateTime? date,
    required ValueChanged<DateTime> onPick,
    required String language,
    String? hint,
    VoidCallback? onClear,
  }) {
    final AppLocalizations l10n = context.l10n;
    return Row(
      children: <Widget>[
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () async {
              final DateTime? picked = await showDatePicker(
                context: context,
                initialDate: date ?? DateTime.now(),
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );
              if (picked != null) onPick(picked);
            },
            icon: const Icon(Icons.calendar_today_outlined),
            label: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                date == null
                    ? (hint ?? l10n.t('common.none'))
                    : DateFormat.yMd(language).format(date),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        ),
        if (onClear != null)
          IconButton(
            onPressed: onClear,
            icon: const Icon(Icons.clear),
            tooltip: l10n.t('common.reset'),
          ),
      ],
    );
  }

  Future<void> _save() async {
    final AppState state = AppScope.of(context);
    final PeriodRecord? existing = widget.record;
    final PeriodRecord record = PeriodRecord(
      id: existing?.id ?? Ids.newId(),
      startDate: DateMath.format(_start),
      endDate: _end == null ? null : DateMath.format(_end!),
      flow: _flow,
      spotting: _spotting,
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      createdAtMs: existing?.createdAtMs ?? DateTime.now().millisecondsSinceEpoch,
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    await state.upsertPeriod(record);
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _delete() async {
    final AppState state = AppScope.of(context);
    final PeriodRecord? record = widget.record;
    if (record == null) return;
    await state.deletePeriod(record.id);
    if (mounted) Navigator.of(context).pop(true);
  }
}
