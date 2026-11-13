import 'package:flutter/material.dart';
import 'package:morphhealth_core/morphhealth_core.dart';

import '../format.dart';
import '../nutrition/hydration.dart' show defaultEntryTime;
import '../widgets/common.dart';

/// Dialog for a new or existing weight entry.
Future<void> showWeightEditor(
  BuildContext context, {
  WeightEntry? entry,
  Day? day,
}) => showDialog<void>(
  context: context,
  builder: (_) => _WeightDialog(entry: entry, day: day),
);

class _WeightDialog extends StatefulWidget {
  final WeightEntry? entry;
  final Day? day;

  const _WeightDialog({this.entry, this.day});

  @override
  State<_WeightDialog> createState() => _WeightDialogState();
}

class _WeightDialogState extends State<_WeightDialog> {
  final _formKey = GlobalKey<FormState>();
  final _value = TextEditingController();
  final _note = TextEditingController();
  late Day _date;
  late String _unit;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final app = context.appRead;
    final fmt = Fmt.of(context, today: app.today);
    _unit = app.settings.weightUnit;
    final entry = widget.entry;
    _date = entry?.date ?? widget.day ?? app.today;
    if (entry != null) {
      _value.text = fmt.editable(
        Fmt.weightValue(entry.weightKg, _unit),
        decimals: 1,
      );
      _note.text = entry.note ?? '';
    }
  }

  @override
  void dispose() {
    _value.dispose();
    _note.dispose();
    super.dispose();
  }

  String? _validate(String? text) {
    final l = context.l;
    final fmt = context.fmt;
    if (text == null || text.trim().isEmpty) return l.requiredField;
    final v = Fmt.parse(text);
    if (v == null) return l.invalidNumber;
    final kg = Fmt.weightToKg(v, _unit);
    if (kg < WeightEntry.minKg || kg > WeightEntry.maxKg) {
      return l.weightOutOfRange(
        fmt.number(Fmt.weightValue(WeightEntry.minKg, _unit), decimals: 0),
        fmt.number(Fmt.weightValue(WeightEntry.maxKg, _unit), decimals: 0),
      );
    }
    return null;
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final repo = context.appRead.repository;
    final kg = Fmt.weightToKg(Fmt.parse(_value.text)!, _unit);
    final note = _note.text.trim().isEmpty ? null : _note.text.trim();
    final entry = widget.entry;
    final ok = await guarded(
      context,
      () => entry == null
          ? repo.addWeight(_date, kg, note: note)
          : repo.saveWeight(
              entry.copyWith(date: _date, weightKg: kg, note: note),
            ),
    );
    if (ok && mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final entry = widget.entry!;
    final repo = context.appRead.repository;
    final l = context.l;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await guarded(context, () => repo.deleteWeight(entry.id));
    if (!ok || !mounted) return;
    Navigator.of(context).pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l.entryDeleted),
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: l.undo,
            onPressed: () => repo.saveWeight(entry),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final app = context.app;
    final others = app.data
        .weightsOn(_date)
        .where((w) => w.id != widget.entry?.id)
        .isNotEmpty;
    return AlertDialog(
      title: Text(widget.entry == null ? l.addWeight : l.weightEdit),
      scrollable: true,
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              enableIMEPersonalizedLearning: false,
              controller: _value,
              autofocus: widget.entry == null,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: l.weightIn(_unit),
                suffixText: _unit,
              ),
              validator: _validate,
              autovalidateMode: AutovalidateMode.onUserInteraction,
              onFieldSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 12),
            DateField(
              label: l.date,
              value: _date,
              first: DayBar.firstSelectable,
              last: app.today,
              onChanged: (d) => setState(() => _date = d),
            ),
            if (others)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(l.weightExists, style: context.texts.bodySmall),
              ),
            const SizedBox(height: 12),
            TextFormField(
              enableIMEPersonalizedLearning: false,
              controller: _note,
              maxLength: 500,
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: l.noteOptional,
                counterText: '',
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (widget.entry != null)
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: _delete,
            child: Text(l.delete),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.cancel),
        ),
        FilledButton(onPressed: _save, child: Text(l.save)),
      ],
    );
  }
}

/// Opens the form for a new or existing symptom entry.
Future<void> showSymptomEditor(
  BuildContext context, {
  SymptomEntry? entry,
  Day? day,
  String? name,
}) => Navigator.of(context).push<void>(
  MaterialPageRoute(
    fullscreenDialog: true,
    builder: (_) => SymptomScreen(entry: entry, day: day, name: name),
  ),
);

/// Form for a symptom: free name, intensity 0–10, date, time and note.
class SymptomScreen extends StatefulWidget {
  final SymptomEntry? entry;
  final Day? day;
  final String? name;

  const SymptomScreen({super.key, this.entry, this.day, this.name});

  @override
  State<SymptomScreen> createState() => _SymptomScreenState();
}

class _SymptomScreenState extends State<SymptomScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _note = TextEditingController();
  int _intensity = 5;
  late LocalDateTime _at;
  bool _initialized = false;
  bool _saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final app = context.appRead;
    final entry = widget.entry;
    if (entry != null) {
      _name.text = entry.name;
      _note.text = entry.note ?? '';
      _intensity = entry.intensity;
      _at = entry.at;
    } else {
      _name.text = widget.name ?? '';
      _at = defaultEntryTime(context, widget.day ?? app.today);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final repo = context.appRead.repository;
    final l = context.l;
    final note = _note.text.trim().isEmpty ? null : _note.text.trim();
    final entry = widget.entry;
    final ok = await guarded(
      context,
      () => entry == null
          ? repo.addSymptom(_name.text, _intensity, at: _at, note: note)
          : repo.saveSymptom(
              entry.copyWith(
                name: _name.text.trim(),
                intensity: _intensity,
                at: _at,
                note: note,
              ),
            ),
    );
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l.saved)));
    }
  }

  Future<void> _delete() async {
    final entry = widget.entry!;
    final repo = context.appRead.repository;
    final l = context.l;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await guarded(context, () => repo.deleteSymptom(entry.id));
    if (!ok || !mounted) return;
    Navigator.of(context).pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l.entryDeleted),
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: l.undo,
            onPressed: () => repo.saveSymptom(entry),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final app = context.app;
    final used = [for (final n in app.usedSymptoms.take(10)) n.display];
    final usedKeys = {for (final n in used) SymptomEntry.normalizeName(n)};
    final suggestions = [
      ...used,
      for (final s in l.symptomSuggestions)
        if (!usedKeys.contains(SymptomEntry.normalizeName(s))) s,
    ].take(12).toList();

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: l.close,
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(widget.entry == null ? l.addSymptom : l.symptomEdit),
        actions: [
          if (widget.entry != null)
            IconButton(
              tooltip: l.delete,
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: TextButton(
              onPressed: _saving ? null : _save,
              child: Text(l.save),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              TextFormField(
                enableIMEPersonalizedLearning: false,
                controller: _name,
                autofocus: widget.entry == null && _name.text.isEmpty,
                maxLength: 80,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: l.symptom,
                  hintText: l.symptomNameHint,
                  counterText: '',
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? l.requiredField : null,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final s in suggestions)
                    ActionChip(
                      label: Text(s),
                      onPressed: () => setState(() {
                        _name.text = s;
                        _name.selection = TextSelection.collapsed(
                          offset: s.length,
                        );
                      }),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Text(l.intensity, style: context.texts.labelLarge),
              IntensityPicker(
                value: _intensity,
                onChanged: (v) => setState(() => _intensity = v),
              ),
              Text(l.intensityScale, style: context.texts.bodySmall),
              const SizedBox(height: 20),
              DateTimeFields(
                value: _at,
                onChanged: (v) => setState(() => _at = v),
              ),
              const SizedBox(height: 12),
              TextFormField(
                enableIMEPersonalizedLearning: false,
                controller: _note,
                maxLength: 500,
                maxLines: null,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: l.noteOptional,
                  counterText: '',
                ),
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: _saving ? null : _save,
                child: Text(l.save),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Chooses an intensity from 0 to 10 with a slider and two step buttons.
class IntensityPicker extends StatelessWidget {
  final int value;
  final ValueChanged<int> onChanged;

  const IntensityPicker({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    return Row(
      children: [
        IconButton(
          tooltip: l.less,
          onPressed: value > 0 ? () => onChanged(value - 1) : null,
          icon: const Icon(Icons.remove_circle_outline),
        ),
        Expanded(
          child: Slider(
            value: value.toDouble(),
            min: 0,
            max: 10,
            divisions: 10,
            label: '$value',
            semanticFormatterCallback: (v) => l.intensityOf(v.round()),
            onChanged: (v) => onChanged(v.round()),
          ),
        ),
        IconButton(
          tooltip: l.moreIntense,
          onPressed: value < 10 ? () => onChanged(value + 1) : null,
          icon: const Icon(Icons.add_circle_outline),
        ),
        SizedBox(
          width: 44,
          child: ExcludeSemantics(
            child: Text(
              '$value',
              textAlign: TextAlign.center,
              style: context.texts.headlineSmall,
            ),
          ),
        ),
      ],
    );
  }
}
