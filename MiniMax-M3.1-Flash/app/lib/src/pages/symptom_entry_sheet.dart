import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:morphhealth_core/morphhealth_core.dart';

import '../l10n/app_localizations.dart';
import '../state/app_state.dart';

/// Creates or edits a symptom entry.
class SymptomEntrySheet extends StatefulWidget {
  const SymptomEntrySheet({super.key, this.entry, this.initialDate});

  final SymptomEntry? entry;
  final String? initialDate;

  static Future<bool?> show(
    BuildContext context, {
    SymptomEntry? entry,
    String? initialDate,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext context) => SymptomEntrySheet(
        entry: entry,
        initialDate: initialDate,
      ),
    );
  }

  @override
  State<SymptomEntrySheet> createState() => _SymptomEntrySheetState();
}

class _SymptomEntrySheetState extends State<SymptomEntrySheet> {
  late final TextEditingController _name;
  late final TextEditingController _note;
  late int _intensity;
  late DateTime _moment;

  @override
  void initState() {
    super.initState();
    final SymptomEntry? entry = widget.entry;
    _name = TextEditingController(text: entry?.name ?? '');
    _note = TextEditingController(text: entry?.note ?? '');
    _intensity = entry?.intensity ?? 3;
    _moment = entry != null
        ? DateTime.fromMillisecondsSinceEpoch(entry.occurredAtMs)
        : _initialMoment();
  }

  DateTime _initialMoment() {
    final String? date = widget.initialDate;
    if (date == null) return DateTime.now();
    final DateTime parsed = DateMath.parse(date);
    final DateTime now = DateTime.now();
    return DateTime(parsed.year, parsed.month, parsed.day, now.hour, now.minute);
  }

  @override
  void dispose() {
    _name.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
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
                    widget.entry == null
                        ? l10n.t('symptom.add_entry')
                        : l10n.t('symptom.edit_entry'),
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
            TextField(
              controller: _name,
              autofocus: widget.entry == null,
              decoration: InputDecoration(
                labelText: l10n.t('symptom.name'),
                hintText: l10n.t('symptom.name_hint'),
              ),
            ),
            if (state.symptoms.names.isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: <Widget>[
                  for (final String name in state.symptoms.names)
                    ActionChip(
                      label: Text(name),
                      onPressed: () => setState(() => _name.text = name),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            Text(
              '${l10n.t('symptom.intensity')}: '
              '${l10n.t('symptom.intensity_value', <String, String>{'value': '$_intensity'})}',
              style: theme.textTheme.bodyMedium,
            ),
            Slider(
              value: _intensity.toDouble(),
              min: 0,
              max: 10,
              divisions: 10,
              label: '$_intensity',
              onChanged: (double value) =>
                  setState(() => _intensity = value.round()),
            ),
            const SizedBox(height: 6),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickDate(language),
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text(DateFormat.yMd(language).format(_moment)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pickTime(),
                    icon: const Icon(Icons.schedule),
                    label: Text(DateFormat.Hm().format(_moment)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
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
                if (widget.entry != null)
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

  Future<void> _pickDate(String language) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _moment,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      _moment = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _moment.hour,
        _moment.minute,
      );
    });
  }

  Future<void> _pickTime() async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_moment),
    );
    if (picked == null) return;
    setState(() {
      _moment = DateTime(
        _moment.year,
        _moment.month,
        _moment.day,
        picked.hour,
        picked.minute,
      );
    });
  }

  Future<void> _save() async {
    final AppState state = AppScope.of(context);
    final String name = _name.text.trim();
    if (name.isEmpty) return;
    final SymptomEntry? existing = widget.entry;
    final SymptomEntry entry = SymptomEntry(
      id: existing?.id ?? Ids.newId(),
      name: name,
      intensity: _intensity,
      date: DateMath.format(_moment),
      occurredAtMs: _moment.millisecondsSinceEpoch,
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      createdAtMs: existing?.createdAtMs ?? DateTime.now().millisecondsSinceEpoch,
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    await state.upsertSymptom(entry);
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _delete() async {
    final AppState state = AppScope.of(context);
    final SymptomEntry? entry = widget.entry;
    if (entry == null) return;
    await state.deleteSymptom(entry.id);
    if (mounted) Navigator.of(context).pop(true);
  }
}
