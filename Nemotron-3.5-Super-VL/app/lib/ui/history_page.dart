library morphhealth.ui.history_page;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:morphhealth/core/repository.dart';
import 'package:morphhealth/l10n/app_localizations.dart';
import 'package:morphhealth/ui/caffeine_entry_page.dart';
import 'package:morphhealth/ui/cycle_page.dart';
import 'package:morphhealth/ui/nutrition_entry_page.dart';
import 'package:morphhealth/ui/symptoms_page.dart';
import 'package:morphhealth/ui/water_entry_page.dart';
import 'package:morphhealth/ui/weight_entry_page.dart';

class HistoryPage extends StatefulWidget {
  final HealthRepository repository;
  const HistoryPage({super.key, required this.repository});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  DateTime? _from;
  DateTime? _to;
  String? _area;
  String _query = '';

  IconData _icon(String area) {
    switch (area) {
      case 'nutrition':
        return Icons.restaurant_menu;
      case 'water':
        return Icons.local_drink;
      case 'caffeine':
        return Icons.coffee;
      case 'cycle':
        return Icons.calendar_today;
      case 'symptom':
        return Icons.psychology;
      default:
        return Icons.monitor_weight;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final items = widget.repository.history(
      from: _from,
      to: _to,
      area: _area,
      query: _query.isEmpty ? null : _query,
    );

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(l.msg('from')),
                      subtitle: Text(_from == null ? '-' : DateFormat.yMMMd(widget.repository.settings.locale).format(_from!)),
                      trailing: const Icon(Icons.arrow_forward_ios),
                      onTap: _pickFrom,
                    ),
                  ),
                  Expanded(
                    child: ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(l.msg('to')),
                      subtitle: Text(_to == null ? '-' : DateFormat.yMMMd(widget.repository.settings.locale).format(_to!)),
                      trailing: const Icon(Icons.arrow_forward_ios),
                      onTap: _pickTo,
                    ),
                  ),
                ],
              ),
              DropdownButtonFormField<String>(
                value: _area,
                decoration: const InputDecoration(labelText: 'Bereich', isDense: true, border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: null, child: Text('Alle')),
                  DropdownMenuItem(value: 'nutrition', child: Text('Ernährung')),
                  DropdownMenuItem(value: 'water', child: Text('Wasser')),
                  DropdownMenuItem(value: 'caffeine', child: Text('Koffein')),
                  DropdownMenuItem(value: 'cycle', child: Text('Zyklus')),
                  DropdownMenuItem(value: 'symptom', child: Text('Symptome')),
                  DropdownMenuItem(value: 'weight', child: Text('Gewicht')),
                ],
                onChanged: (v) => setState(() => _area = v),
              ),
              const SizedBox(height: 8),
              TextField(
                decoration: InputDecoration(
                  labelText: l.msg('query'),
                  isDense: true,
                  border: const OutlineInputBorder(),
                  prefixIcon: const Icon(Icons.search),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ],
          ),
        ),
        Expanded(
          child: items.isEmpty
              ? Center(child: Text(l.msg('noEntries')))
              : ListView.builder(
                  itemCount: items.length,
                  itemBuilder: (_, i) {
                    final item = items[i];
                    return ListTile(
                      leading: Icon(_icon(item.area), size: 20),
                      title: Text(item.title),
                      subtitle: Text('${item.subtitle} · ${DateFormat.yMMMd(widget.repository.settings.locale).format(item.when)} ${DateFormat.Hm(widget.repository.settings.locale).format(item.when)}'),
                      trailing: const Icon(Icons.arrow_forward_ios),
                      onTap: () => _open(context, item),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Future<void> _pickFrom() async {
    final picked = await showDatePicker(context: context, initialDate: _from ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100), locale: Locale(widget.repository.settings.locale));
    if (picked != null) setState(() => _from = picked);
  }

  Future<void> _pickTo() async {
    final picked = await showDatePicker(context: context, initialDate: _to ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100), locale: Locale(widget.repository.settings.locale));
    if (picked != null) setState(() => _to = picked);
  }

  Future<void> _open(BuildContext context, HistoryItem item) async {
    final repository = widget.repository;
    bool? saved;
    switch (item.area) {
      case 'nutrition':
        saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
          builder: (_) => NutritionEntryPage(repository: repository, day: item.when, entry: item.entry),
        ));
        break;
      case 'water':
        saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
          builder: (_) => WaterEntryPage(repository: repository, day: item.when, entry: item.entry),
        ));
        break;
      case 'caffeine':
        saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
          builder: (_) => CaffeineEntryPage(repository: repository, day: item.when, entry: item.entry),
        ));
        break;
      case 'weight':
        saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
          builder: (_) => WeightEntryPage(repository: repository, day: item.when, entry: item.entry),
        ));
        break;
      case 'cycle':
        await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => CyclePage(repository: repository, initialDate: item.when),
        ));
        break;
      case 'symptom':
        await Navigator.of(context).push(MaterialPageRoute(
          builder: (_) => SymptomsPage(repository: repository, initialDate: item.when),
        ));
        break;
    }
    if (saved == true) setState(() {});
  }
}