library morphhealth.ui.caffeine_entry_page;

import 'package:flutter/material.dart';
import 'package:morphhealth/core/repository.dart';
import 'package:morphhealth/l10n/app_localizations.dart';

class CaffeineEntryPage extends StatefulWidget {
  final HealthRepository repository;
  final DateTime day;
  final CaffeineEntry? entry;
  const CaffeineEntryPage({super.key, required this.repository, required this.day, this.entry});

  @override
  State<CaffeineEntryPage> createState() => _CaffeineEntryPageState();
}

class _CaffeineEntryPageState extends State<CaffeineEntryPage> {
  final _amount = TextEditingController();
  DateTime _occurredAt = DateTime.now();

  @override
  void initState() {
    super.initState();
    _occurredAt = widget.entry?.occurredAt ?? widget.day;
    _amount.text = (widget.entry?.amountMg ?? 100).toStringAsFixed(0);
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
            title: Text(l.msg('amount')),
            subtitle: Text(l.msg('mg')),
            trailing: SizedBox(
              width: 120,
              child: TextField(
                controller: _amount,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
              ),
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            title: Text('${l.msg('date')} / ${l.msg('time')}'),
            subtitle: Text('${_occurredAt.day}.${_occurredAt.month} ${_occurredAt.hour}:${_occurredAt.minute.toString().padLeft(2, '0')}'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () async {
              final date = await showDatePicker(context: context, initialDate: _occurredAt, firstDate: DateTime(2000), lastDate: DateTime(2100), locale: Locale(widget.repository.settings.locale));
              if (date == null) return;
              final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_occurredAt));
              if (time != null) setState(() => _occurredAt = DateTime(date.year, date.month, date.day, time.hour, time.minute));
            },
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: _save, child: Text(widget.entry == null ? l.msg('add') : l.msg('save'))),
        ],
      ),
    );
  }

  void _save() {
    final amount = double.tryParse(_amount.text) ?? 0;
    if (amount <= 0) return;
    final entry = CaffeineEntry(id: widget.entry?.id ?? '', amountMg: amount, occurredAt: _occurredAt);
    if (widget.entry == null) {
      widget.repository.addCaffeineEntry(entry);
    } else {
      widget.repository.updateCaffeineEntry(widget.entry!.id, entry);
    }
    Navigator.of(context).pop(true);
  }
}