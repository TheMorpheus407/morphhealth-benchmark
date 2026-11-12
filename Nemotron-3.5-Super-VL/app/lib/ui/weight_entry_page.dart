library morphhealth.ui.weight_entry_page;

import 'package:flutter/material.dart';
import 'package:morphhealth/core/repository.dart';
import 'package:morphhealth/l10n/app_localizations.dart';

class WeightEntryPage extends StatefulWidget {
  final HealthRepository repository;
  final DateTime day;
  final WeightEntry? entry;
  const WeightEntryPage({super.key, required this.repository, required this.day, this.entry});

  @override
  State<WeightEntryPage> createState() => _WeightEntryPageState();
}

class _WeightEntryPageState extends State<WeightEntryPage> {
  final _value = TextEditingController();
  DateTime _date = DateTime.now();
  WeightUnit _unit = WeightUnit.kg;

  @override
  void initState() {
    super.initState();
    _date = widget.entry?.date ?? widget.day;
    _unit = widget.entry?.unit ?? WeightUnit.kg;
    _value.text = (widget.entry?.value ?? 0).toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(widget.entry == null ? l.msg('add') : l.msg('edit'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            title: Text(l.msg('value')),
            subtitle: Text(_unit == WeightUnit.kg ? l.msg('kg') : l.msg('lb')),
            trailing: SizedBox(
              width: 120,
              child: TextField(
                controller: _value,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
              ),
            ),
          ),
          ListTile(
            title: Text(_unit == WeightUnit.kg ? l.msg('kg') : l.msg('lb')),
            trailing: DropdownButton<WeightUnit>(
              value: _unit,
              items: const [
                DropdownMenuItem(value: WeightUnit.kg, child: Text('kg')),
                DropdownMenuItem(value: WeightUnit.lb, child: Text('lb')),
              ],
              onChanged: (u) => setState(() => _unit = u!),
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            title: Text(l.msg('date')),
            subtitle: Text(DateFormatHelper.format(_date)),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () async {
              final picked = await showDatePicker(context: context, initialDate: _date, firstDate: DateTime(2000), lastDate: DateTime(2100), locale: Locale(widget.repository.settings.locale));
              if (picked != null) setState(() => _date = picked);
            },
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: _save, child: Text(widget.entry == null ? l.msg('add') : l.msg('save'))),
        ],
      ),
    );
  }

  void _save() {
    final value = double.tryParse(_value.text) ?? 0;
    if (value <= 0) return;
    final entry = WeightEntry(id: widget.entry?.id ?? '', date: _date, value: value, unit: _unit);
    if (widget.entry == null) {
      widget.repository.addWeightEntry(entry);
    } else {
      widget.repository.updateWeightEntry(widget.entry!.id, entry);
    }
    Navigator.of(context).pop(true);
  }
}

class DateFormatHelper {
  static String format(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}