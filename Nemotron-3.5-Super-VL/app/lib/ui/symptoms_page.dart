library morphhealth.ui.symptoms_page;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:morphhealth/core/repository.dart';
import 'package:morphhealth/l10n/app_localizations.dart';

class SymptomsPage extends StatefulWidget {
  final HealthRepository repository;
  final DateTime? initialDate;
  const SymptomsPage({super.key, required this.repository, this.initialDate});

  @override
  State<SymptomsPage> createState() => _SymptomsPageState();
}

class _SymptomsPageState extends State<SymptomsPage> {
  String _filterName = '';
  DateTime _selected = DateTime.now();

  @override
  void initState() {
    super.initState();
    if (widget.initialDate != null) _selected = widget.initialDate!;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final entries = widget.repository.symptomEntriesForDay(_selected)
        .where((e) => _filterName.isEmpty || e.name.toLowerCase().contains(_filterName.toLowerCase()))
        .toList()
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));

    return Scaffold(
      appBar: AppBar(title: Text(l.msg('symptom'))),
      body: Column(
        children: [
          ListTile(
            title: Text('${l.msg('date')}: ${DateFormat.yMMMd(widget.repository.settings.locale).format(_selected)}'),
            trailing: IconButton(icon: const Icon(Icons.calendar_month), onPressed: _pickDate),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              decoration: InputDecoration(
                hintText: l.msg('query'),
                isDense: true,
                border: const OutlineInputBorder(),
                prefixIcon: const Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _filterName = v),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: entries.isEmpty
                ? Center(child: Text(l.msg('noEntries')))
                : ListView.builder(
                    itemCount: entries.length,
                    itemBuilder: (_, i) {
                      final e = entries[i];
                      return Dismissible(
                        key: ValueKey(e.id),
                        onDismissed: (_) => widget.repository.deleteSymptomEntry(e.id),
                        background: const ColoredBox(color: Colors.red),
                        child: ListTile(
                          title: Text(e.name),
                          subtitle: Text('Intensität ${e.intensity}/10${e.notes != null ? ' · ${e.notes}' : ''} · ${DateFormat.Hm(widget.repository.settings.locale).format(e.occurredAt)}'),
                          trailing: const Icon(Icons.arrow_forward_ios),
                          onTap: () => _edit(e),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 8),
          SafeArea(
            top: false,
            child: FilledButton.icon(
              icon: const Icon(Icons.add),
              label: Text(l.msg('add')),
              onPressed: () => _edit(null),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(context: context, initialDate: _selected, firstDate: DateTime(2000), lastDate: DateTime(2100), locale: Locale(widget.repository.settings.locale));
    if (picked != null) setState(() => _selected = picked);
  }

  Future<void> _edit(SymptomEntry? entry) async {
    final l = AppLocalizations.of(context)!;
    final controller = TextEditingController(text: entry?.name ?? '');
    final notesController = TextEditingController(text: entry?.notes ?? '');
    int intensity = entry?.intensity ?? 5;
    DateTime when = entry?.occurredAt ?? _selected;
    await showDialog(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setSt) => AlertDialog(
          title: Text(entry == null ? l.msg('add') : l.msg('edit')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: controller, decoration: const InputDecoration(labelText: 'Name')),
              const SizedBox(height: 12),
              Row(children: [
                Text('${l.msg('intensity0to10')}: '),
                Expanded(child: Slider(value: intensity.toDouble(), min: 0, max: 10, divisions: 10, onChanged: (v) => setSt(() => intensity = v.round()))),
                Text('$intensity'),
              ]),
              const SizedBox(height: 12),
              TextField(
                controller: notesController,
                decoration: InputDecoration(labelText: l.msg('notes')),
              ),
              const SizedBox(height: 12),
              ListTile(
                title: Text('${l.msg('date')} / ${l.msg('time')}'),
                subtitle: Text(DateTimeFormatHelper.format(when)),
                trailing: const Icon(Icons.arrow_forward_ios),
                onTap: () async {
                  final date = await showDatePicker(context: context, initialDate: when, firstDate: DateTime(2000), lastDate: DateTime(2100), locale: Locale(widget.repository.settings.locale));
                  if (date == null) return;
                  final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(when));
                  if (time != null) setSt(() => when = DateTime(date.year, date.month, date.day, time.hour, time.minute));
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: Text(l.msg('cancel'))),
            FilledButton(
              onPressed: () {
                if (controller.text.trim().isEmpty) return;
                final e = SymptomEntry(
                  id: entry?.id ?? '',
                  name: controller.text.trim(),
                  intensity: intensity,
                  occurredAt: when,
                  notes: notesController.text.isEmpty ? null : notesController.text,
                );
                if (entry == null) widget.repository.addSymptomEntry(e);
                else widget.repository.updateSymptomEntry(entry.id, e);
                Navigator.pop(context);
                setState(() {});
              },
              child: Text(l.msg('save')),
            ),
          ],
        ),
      ),
    );
  }
}

class DateTimeFormatHelper {
  static String format(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')} ${d.hour}:${d.minute.toString().padLeft(2, '0')}';
}