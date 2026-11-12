library morphhealth.ui.nutrition_page;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:morphhealth/core/model/food.dart';
import 'package:morphhealth/core/model/nutrients.dart';
import 'package:morphhealth/core/repository.dart';
import 'package:morphhealth/l10n/app_localizations.dart';
import 'package:morphhealth/ui/edit_local_food_page.dart';
import 'package:morphhealth/ui/food_search_page.dart';
import 'package:morphhealth/ui/local_foods_page.dart';
import 'package:morphhealth/ui/nutrition_entry_page.dart';

class NutritionPage extends StatefulWidget {
  final HealthRepository repository;
  const NutritionPage({super.key, required this.repository});

  @override
  State<NutritionPage> createState() => _NutritionPageState();
}

class _NutritionPageState extends State<NutritionPage> {
  DateTime _selected = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final entries = widget.repository.nutritionEntriesForDay(_selected)
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    final total = widget.repository.nutritionDaySummary(_selected).total;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          child: Row(
            children: [
              Expanded(
                child: Text('${l.msg('date')}: ${DateFormat.yMMMd(widget.repository.settings.locale).format(_selected)}'),
              ),
              IconButton(icon: const Icon(Icons.calendar_month), onPressed: _pickDate),
              const SizedBox(width: 8),
              FilledButton.icon(
                icon: const Icon(Icons.add),
                label: Text(l.msg('add')),
                onPressed: () => _addEntry(context),
              ),
            ],
          ),
        ),
        Expanded(
          child: entries.isEmpty
              ? Center(child: Text(l.msg('noEntries')))
              : ListView.builder(
                  itemCount: entries.length,
                  itemBuilder: (_, i) {
                    final e = entries[i];
                    return Dismissible(
                      key: ValueKey(e.id),
                      onDismissed: (_) => widget.repository.deleteNutritionEntry(e.id),
                      background: const ColoredBox(color: Colors.red),
                      child: ListTile(
                        title: Text(e.foodName),
                        subtitle: Text(
                          '${e.amountGrams.toStringAsFixed(0)} g · ${e.meal.key} · ${e.energyKcal.toStringAsFixed(0)} ${l.msg('kcal')}',
                        ),
                        trailing: const Icon(Icons.arrow_forward_ios),
                        onTap: () => _editEntry(context, e),
                      ),
                    );
                  },
                ),
        ),
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: _Stat(label: l.msg('kcal'), value: '${(total.energyKcal ?? 0).toStringAsFixed(0)}'),
              ),
              Expanded(child: _Stat(label: l.msg('protein'), value: '${(total.proteinG ?? 0).toStringAsFixed(0)}g')),
              Expanded(child: _Stat(label: l.msg('carbs'), value: '${(total.carbsG ?? 0).toStringAsFixed(0)}g')),
              Expanded(child: _Stat(label: l.msg('fat'), value: '${(total.fatG ?? 0).toStringAsFixed(0)}g')),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(context: context, initialDate: _selected, firstDate: DateTime(2000), lastDate: DateTime(2100), locale: Locale(widget.repository.settings.locale));
    if (picked != null) setState(() => _selected = picked);
  }

  Future<void> _addEntry(BuildContext context) async {
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => NutritionEntryPage(repository: widget.repository, day: _selected),
    ));
    if (saved == true) setState(() {});
  }

  Future<void> _editEntry(BuildContext context, NutritionEntry entry) async {
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => NutritionEntryPage(repository: widget.repository, day: _selected, entry: entry),
    ));
    if (saved == true) setState(() {});
  }
}

extension _IsNotEmpty on NutrientProfile {
  bool get isNotEmpty => !isEmpty;
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat({required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 2),
        Text(value, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold)),
      ],
    );
  }
}