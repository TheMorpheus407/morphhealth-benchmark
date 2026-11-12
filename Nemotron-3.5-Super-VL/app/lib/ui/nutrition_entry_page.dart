library morphhealth.ui.nutrition_entry_page;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:morphhealth/core/model/food.dart';
import 'package:morphhealth/core/model/nutrients.dart';
import 'package:morphhealth/core/repository.dart';
import 'package:morphhealth/l10n/app_localizations.dart';
import 'package:morphhealth/ui/food_search_page.dart';
import 'package:morphhealth/ui/local_foods_page.dart';

class NutritionEntryPage extends StatefulWidget {
  final HealthRepository repository;
  final DateTime day;
  final NutritionEntry? entry;
  const NutritionEntryPage({super.key, required this.repository, required this.day, this.entry});

  @override
  State<NutritionEntryPage> createState() => _NutritionEntryPageState();
}

class _NutritionEntryPageState extends State<NutritionEntryPage> {
  Food? _food;
  String _amountGrams = '';
  String _amountMl = '';
  String _servings = '1';
  Meal _meal = Meal.snack;
  DateTime _occurredAt = DateTime.now();
  bool _isMl = false;
  bool _isServings = false;

  @override
  void initState() {
    super.initState();
    _occurredAt = widget.entry?.occurredAt ?? widget.day;
    _meal = widget.entry?.meal ?? Meal.snack;
    if (widget.entry != null) {
      _food = _findFood(widget.entry!.foodId);
      _amountGrams = widget.entry!.amountGrams.toStringAsFixed(0);
      _amountMl = widget.entry!.amountMilliliters.toStringAsFixed(0);
      _servings = widget.entry!.servingCount.toStringAsFixed(0);
      _isMl = widget.entry!.amountMilliliters > 0;
      _isServings = widget.entry!.amountGrams == 0 && widget.entry!.amountMilliliters == 0;
    }
  }

  Food? _findFood(String id) {
    final local = widget.repository.localFoods.firstWhereOrNull((f) => f.id == id);
    if (local != null) return local;
    return widget.repository.findCachedProduct(id);
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
            title: Text(l.msg('food')),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () => _pickFood(context),
            subtitle: Text(_food == null ? l.msg('noEntries') : _food!.name),
          ),
          const Divider(),
          ListTile(
            title: Text(_food == null ? '' : _food!.name),
            subtitle: _food == null
                ? null
                : Text('${l.msg('brand')}: ${_food!.brand ?? '-'}   ·   ${l.msg('per100g')}'),
          ),
          if (_food != null) ...[
            const SizedBox(height: 12),
            Text(l.msg('amount'), style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _AmountChoice(
                    label: l.msg('grams'),
                    value: _amountGrams,
                    selected: !_isMl && !_isServings,
                    onChanged: (v) {
                      setState(() { _amountGrams = v; _isMl = false; _isServings = false; });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _AmountChoice(
                    label: l.msg('milliliters'),
                    value: _amountMl,
                    selected: _isMl,
                    onChanged: (v) {
                      setState(() { _amountMl = v; _isMl = true; _isServings = false; });
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _AmountChoice(
                    label: l.msg('servings'),
                    value: _servings,
                    selected: _isServings,
                    onChanged: (v) {
                      setState(() { _servings = v; _isMl = false; _isServings = true; });
                    },
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          ListTile(
            title: Text(l.msg('meal')),
            trailing: DropdownButton<Meal>(
              value: _meal,
              items: Meal.values.map((m) => DropdownMenuItem(value: m, child: Text(l.msg(m.key)))).toList(),
              onChanged: (m) => setState(() => _meal = m!),
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            title: Text('${l.msg('date')} / ${l.msg('time')}'),
            subtitle: Text('${DateFormat.yMMMd().format(_occurredAt)} ${DateFormat.Hm().format(_occurredAt)}'),
            trailing: const Icon(Icons.arrow_forward_ios),
            onTap: () async {
              final date = await showDatePicker(context: context, initialDate: _occurredAt, firstDate: DateTime(2000), lastDate: DateTime(2100), locale: Locale(widget.repository.settings.locale));
              if (date == null) return;
              final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(_occurredAt));
              if (time != null) setState(() => _occurredAt = DateTime(date.year, date.month, date.day, time.hour, time.minute));
            },
          ),
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _save,
            child: Text(widget.entry == null ? l.msg('add') : l.msg('save')),
          ),
        ],
      ),
    );
  }

  Future<void> _pickFood(BuildContext context) async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(MaterialPageRoute(
      builder: (_) => FoodPickerPage(repository: widget.repository),
    ));
    if (result == null) return;
    setState(() {
      _food = result['food'] as Food;
      _amountGrams = '';
      _amountMl = '';
      _servings = '1';
      _isMl = false;
      _isServings = false;
    });
  }

  void _save() {
    if (_food == null) {
      _show(context, l10nOf(context).msg('error'), 'Bitte Lebensmittel wählen');
      return;
    }
    final grams = double.tryParse(_amountGrams) ?? 0;
    final ml = double.tryParse(_amountMl) ?? 0;
    final servings = double.tryParse(_servings) ?? 0;
    if (grams <= 0 && ml <= 0 && servings <= 0) {
      _show(context, l10nOf(context).msg('error'), 'Menge eingeben');
      return;
    }
    final servingSize = _food!.servingSizeGrams ?? 100;
    final entry = NutritionEntry(
      id: widget.entry?.id ?? '',
      foodSource: _food!.source,
      foodId: _food!.id,
      foodName: _food!.name,
      profilePer100g: _food!.profile,
      amountGrams: _isServings ? 0 : grams,
      amountMilliliters: _isMl ? ml : 0,
      servingCount: _isServings ? servings : 0,
      occurredAt: _occurredAt,
      meal: _meal,
    );
    if (widget.entry == null) {
      widget.repository.addNutritionEntry(entry);
    } else {
      widget.repository.updateNutritionEntry(widget.entry!.id, entry);
    }
    Navigator.of(context).pop(true);
  }

  void _show(BuildContext context, String title, String message) {
    showDialog(context: context, builder: (_) => AlertDialog(title: Text(title), content: Text(message), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))]));
  }

  AppLocalizations l10nOf(BuildContext c) => AppLocalizations.of(c)!;
}

class _AmountChoice extends StatelessWidget {
  final String label;
  final String value;
  final bool selected;
  final ValueChanged<String> onChanged;
  const _AmountChoice({required this.label, required this.value, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(children: [
          Radio<bool>(
            value: true,
            groupValue: selected,
            onChanged: (_) {},
          ),
          Text(label),
        ]),
        SizedBox(
          width: 70,
          child: TextField(
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(border: const OutlineInputBorder(), isDense: true, contentPadding: const EdgeInsets.all(8)),
            controller: TextEditingController(text: value),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}

extension _FirstWhereOrNull<T> on Iterable<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    for (final element in this) {
      if (test(element)) return element;
    }
    return null;
  }
}