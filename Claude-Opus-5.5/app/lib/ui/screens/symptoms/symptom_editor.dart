import 'package:flutter/material.dart';

import '../../../core/model/dataset.dart';
import '../../../core/model/entries.dart';
import '../../../core/util/local_date.dart';
import '../../controller.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/inputs.dart';
import '../nutrition/intake_cards.dart';

/// Opens the symptom editor for a new entry on [date] or for [entry].
Future<void> openSymptomEditor(BuildContext context, {LocalDate? date, SymptomEntry? entry}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => SymptomEditor(date: date, entry: entry)),
  );
}

/// Symptom with a free name, intensity 0–10, date/time and note.
class SymptomEditor extends StatefulWidget {
  const SymptomEditor({super.key, this.date, this.entry});

  final LocalDate? date;
  final SymptomEntry? entry;

  @override
  State<SymptomEditor> createState() => _SymptomEditorState();
}

class _SymptomEditorState extends State<SymptomEditor> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _note;
  late LocalDate _date;
  int? _time;
  late int _intensity;

  @override
  void initState() {
    super.initState();
    final app = context.appRead;
    final e = widget.entry;
    _name = TextEditingController(text: e?.name ?? '');
    _note = TextEditingController(text: e?.note ?? '');
    _date = e?.date ?? widget.date ?? app.today;
    _time = e?.time ?? (_date == app.today ? app.service.clock.minutesOfDay() : null);
    _intensity = e?.intensity ?? 5;
  }

  @override
  void dispose() {
    _name.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final app = context.appRead;
    final note = _note.text.trim().isEmpty ? null : _note.text.trim();
    final name = _name.text.trim().replaceAll(RegExp(r'\s+'), ' ');
    final e = widget.entry;
    final now = app.service.clock.nowUtc();
    final record = e == null
        ? SymptomEntry.create(date: _date, time: _time, name: name, intensity: _intensity, note: note, now: now)
        : e.copyWith(date: _date, time: () => _time, name: name, intensity: _intensity, note: () => note, updatedAt: now);
    final ok = await app.run(() => app.service.saveSymptom(record));
    if (ok && mounted) {
      app.showMessage(app.s.saved);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final s = app.s;
    final known = app.service.knownSymptomNames();
    final suggestions = [
      ...known,
      for (final name in s.symptomSuggestions)
        if (!known.any((k) => k.toLowerCase() == name.toLowerCase())) name,
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.entry == null ? s.addSymptom : s.editSymptom),
        actions: [
          if (widget.entry != null)
            IconButton(
              tooltip: s.delete,
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                final entry = widget.entry!;
                Navigator.of(context).pop();
                await deleteWithUndo(context, Collection.symptomEntries, entry);
              },
            ),
        ],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: pagePadding(context),
          children: [
            TextFormField(
              controller: _name,
              maxLength: SymptomEntry.maxNameLength,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: s.symptomName),
              validator: (v) => v == null || v.trim().isEmpty ? s.fieldRequired : null,
              onChanged: (_) => setState(() {}),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final name in suggestions.take(16))
                  ChoiceChip(
                    label: Text(name),
                    selected: _name.text.trim().toLowerCase() == name.toLowerCase(),
                    onSelected: (_) => setState(() => _name.text = name),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            Semantics(
              header: true,
              child: Text(
                '${s.intensity}: ${s.intensityValue(_intensity)} (${s.intensityWord(_intensity)})',
                style: context.text.titleSmall,
              ),
            ),
            Slider(
              value: _intensity.toDouble(),
              min: 0,
              max: 10,
              divisions: 10,
              label: '$_intensity',
              semanticFormatterCallback: (v) =>
                  '${s.intensityValue(v.round())}, ${s.intensityWord(v.round())}',
              onChanged: (v) => setState(() => _intensity = v.round()),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(s.intensityWord(0), style: context.text.bodySmall),
                Text(s.intensityWord(10), style: context.text.bodySmall),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(child: DateField(date: _date, onChanged: (d) => setState(() => _date = d))),
                const SizedBox(width: 12),
                Expanded(child: TimeField(minutes: _time, onChanged: (t) => setState(() => _time = t))),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _note,
              maxLength: 2000,
              minLines: 2,
              maxLines: 6,
              decoration: InputDecoration(labelText: s.noteOptional),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _save,
              child: Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(s.save)),
            ),
          ],
        ),
      ),
    );
  }
}
