// Symptombereich: erfassen, Verlauf pro Symptom, Historie.
library;

import 'package:flutter/material.dart';

import '../core/parse.dart';
import '../data/repository.dart';
import '../l10n/app_strings.dart';
import '../model/cycle.dart';
import 'scope.dart';
import 'widgets.dart';

class SymptomsScreen extends StatefulWidget {
  const SymptomsScreen({super.key});

  @override
  State<SymptomsScreen> createState() => _SymptomsScreenState();
}

class _SymptomsScreenState extends State<SymptomsScreen> {
  String? _filter;

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = StringsScope.of(context);
    final MorphRepository repo = MorphScope.repoOf(context);
    return ListenableBuilder(
      listenable: MorphScope.listenableOf(context),
      builder: (BuildContext context, Widget? _) {
        final List<SymptomEntry> all = repo.sortedSymptomEntries;
        final List<String> known = repo.knownSymptomNames();
        final bool filtered = _filter != null;
        final List<SymptomEntry> shown =
            filtered ? repo.symptomEntriesForName(_filter!) : all;
        return ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: <Widget>[
                  FilledButton.tonalIcon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute<Widget>(
                        builder: (_) =>
                            SymptomEditScreen(initialDate: todayString()),
                      ),
                    ),
                    icon: const Icon(Icons.add),
                    label: Text(strings.addSymptom),
                  ),
                  if (known.isNotEmpty)
                    DropdownButton<String?>(
                      value: _filter,
                      hint: Text(strings.selectSymptomHint),
                      items: <DropdownMenuItem<String?>>[
                        DropdownMenuItem<String?>(
                          value: null,
                          child: Text(strings.filterAll),
                        ),
                        for (final String name in known)
                          DropdownMenuItem<String?>(
                            value: name,
                            child: Text(name),
                          ),
                      ],
                      onChanged: (String? v) => setState(() => _filter = v),
                    ),
                ],
              ),
            ),
            if (filtered && shown.isNotEmpty) _historyCard(strings, shown),
            SectionCard(
              title: filtered ? strings.symptomHistory : strings.symptomsTitle,
              child: shown.isEmpty
                  ? EmptyState(
                      icon: Icons.healing_outlined,
                      text: strings.noSymptoms,
                    )
                  : Column(
                      children: <Widget>[
                        for (final SymptomEntry e in shown)
                          _entryTile(context, strings, repo, e),
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _historyCard(AppStrings strings, List<SymptomEntry> shown) {
    final List<SymptomEntry> chronological =
        shown.reversed.toList(); // älteste zuerst
    final List<SymptomEntry> chart = chronological.length > 14
        ? chronological.sublist(chronological.length - 14)
        : chronological;
    final double avg = shown.isEmpty
        ? 0
        : shown.fold(0, (int a, SymptomEntry e) => a + e.intensity) /
            shown.length;
    return SectionCard(
      title: strings.symptomHistory,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          StatRow(
            label: strings.intensityLabel,
            value:
                '${strings.formatNumber(avg, fractionDigits: 1)} / 10 · ${strings.entriesCount(shown.length)}',
          ),
          const SizedBox(height: 8),
          BarChart(
            values: <double>[
              for (final SymptomEntry e in chart) e.intensity.toDouble(),
            ],
            labels: <String>[
              for (final SymptomEntry e in chart)
                strings.formatDateShort(parseDate(e.date)!),
            ],
            unit: '/10',
            height: 140,
          ),
        ],
      ),
    );
  }

  Widget _entryTile(BuildContext context, AppStrings strings,
      MorphRepository repo, SymptomEntry e) {
    final String subtitle = '${strings.formatDateShort(parseDate(e.date)!)}'
        '${e.time != null ? ' · ${e.time}' : ''}'
        ' · ${strings.intensityValue(e.intensity)}'
        '${e.note != null && e.note!.isNotEmpty ? ' · ${e.note}' : ''}';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      leading: const Icon(Icons.healing_outlined, size: 20),
      title: Text(e.name),
      subtitle: Text(subtitle),
      trailing: IconButton(
        tooltip: strings.a11yDelete,
        icon: const Icon(Icons.delete_outline),
        onPressed: () async {
          if (await confirmDelete(context)) {
            await repo.deleteSymptomEntry(e.id);
            if (context.mounted) showInfo(context, strings.symptomDeleted);
          }
        },
      ),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<Widget>(
          builder: (_) => SymptomEditScreen(entry: e),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ Editor

/// Symptom erfassen/bearbeiten (Name mit Vorschlägen, Intensität 0–10).
class SymptomEditScreen extends StatefulWidget {
  final SymptomEntry? entry;
  final String? initialDate;

  const SymptomEditScreen({super.key, this.entry, this.initialDate});

  @override
  State<SymptomEditScreen> createState() => _SymptomEditScreenState();
}

class _SymptomEditScreenState extends State<SymptomEditScreen> {
  TextEditingController? _nameController;
  late final TextEditingController _dateController;
  late final TextEditingController _timeController;
  late final TextEditingController _noteController;
  late DateTime _date;
  TimeOfDay? _time;
  int _intensity = 5;

  @override
  void initState() {
    super.initState();
    final SymptomEntry? init = widget.entry;
    _date = parseDate(init?.date ?? widget.initialDate ?? '') ??
        DateTime.utc(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final DateTime? t = parseTimeOfDay(init?.time);
    _time = t == null ? null : TimeOfDay(hour: t.hour, minute: t.minute);
    _intensity = init?.intensity ?? 5;
    _dateController = TextEditingController();
    _timeController = TextEditingController();
    _noteController = TextEditingController(text: init?.note ?? '');
  }

  @override
  void dispose() {
    _dateController.dispose();
    _timeController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  String get _timeText {
    final TimeOfDay? t = _time;
    if (t == null) return '';
    return '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = StringsScope.of(context);
    final MorphRepository repo = MorphScope.repoOf(context);
    // Anzeigefelder synchron halten (nur Lesen, daher ohne Konflikt).
    final String dateText = strings.formatDateShort(_date);
    if (_dateController.text != dateText) _dateController.text = dateText;
    if (_timeController.text != _timeText) _timeController.text = _timeText;
    return Scaffold(
      appBar: AppBar(
        title: Text(
            widget.entry == null ? strings.addSymptom : strings.editSymptom),
        actions: <Widget>[
          if (widget.entry != null)
            IconButton(
              tooltip: strings.a11yDelete,
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _delete(repo),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Autocomplete<String>(
            initialValue: TextEditingValue(text: widget.entry?.name ?? ''),
            optionsBuilder: (TextEditingValue value) {
              final List<String> options = repo.knownSymptomNames();
              if (value.text.isEmpty) return options;
              final String q = value.text.toLowerCase();
              return options
                  .where((String o) => o.toLowerCase().contains(q))
                  .toList();
            },
            fieldViewBuilder: (BuildContext context,
                TextEditingController controller,
                FocusNode focusNode,
                VoidCallback onFieldSubmitted) {
              _nameController = controller;
              return TextField(
                controller: controller,
                focusNode: focusNode,
                decoration: InputDecoration(
                  labelText: strings.symptomNameLabel,
                  hintText: strings.knownSymptoms,
                ),
                onSubmitted: (_) => onFieldSubmitted(),
              );
            },
            onSelected: (String selection) {
              _nameController?.text = selection;
            },
          ),
          const SizedBox(height: 16),
          Text('${strings.intensityLabel}: ${strings.intensityValue(_intensity)}'),
          Slider(
            value: _intensity.toDouble(),
            min: 0,
            max: 10,
            divisions: 10,
            label: strings.intensityValue(_intensity),
            onChanged: (double v) => setState(() => _intensity = v.round()),
          ),
          Text(strings.intensityHint,
              style: Theme.of(context).textTheme.bodySmall),
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
              final TimeOfDay? picked =
                  await pickTime(context, initial: _time ?? TimeOfDay.now());
              if (picked != null && mounted) {
                setState(() {
                  _time = picked;
                  _timeController.text = _timeText;
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
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: () => _save(repo),
            icon: const Icon(Icons.save_outlined),
            label: Text(strings.save),
          ),
        ],
      ),
    );
  }

  Future<void> _save(MorphRepository repo) async {
    final AppStrings strings = StringsScope.of(context);
    final String name = _nameController?.text.trim() ?? '';
    if (name.isEmpty) {
      showError(context, strings.fieldRequired);
      return;
    }
    final String note = _noteController.text.trim();
    final String date = formatDate(_date);
    final String? time = _time == null ? null : _timeText;
    if (widget.entry == null) {
      await repo.addSymptomEntry(SymptomEntry(
        id: '',
        name: name,
        intensity: _intensity,
        date: date,
        time: time,
        note: note.isEmpty ? null : note,
      ));
    } else {
      final SymptomEntry e = widget.entry!;
      e.name = name;
      e.intensity = _intensity;
      e.date = date;
      e.time = time;
      e.note = note.isEmpty ? null : note;
      await repo.updateSymptomEntry(e);
    }
    if (mounted) {
      showInfo(context, strings.symptomSaved);
      Navigator.of(context).pop();
    }
  }

  Future<void> _delete(MorphRepository repo) async {
    final AppStrings strings = StringsScope.of(context);
    final SymptomEntry? entry = widget.entry;
    if (entry == null) return;
    if (await confirmDelete(context)) {
      await repo.deleteSymptomEntry(entry.id);
      if (mounted) {
        showInfo(context, strings.symptomDeleted);
        Navigator.of(context).pop();
      }
    }
  }
}
