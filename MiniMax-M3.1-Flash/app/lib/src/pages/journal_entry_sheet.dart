import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:morphhealth_core/morphhealth_core.dart';

import '../l10n/app_localizations.dart';
import '../state/app_state.dart';

/// Adds or edits a journal entry for a food.
class JournalEntrySheet extends StatefulWidget {
  const JournalEntrySheet({
    required this.food,
    super.key,
    this.entry,
    this.template,
    this.initialDate,
  });

  final FoodItem food;

  /// The entry that is edited. When it is set, the entry keeps its identity.
  final JournalEntry? entry;

  /// A previous entry whose values are offered as a template for a new
  /// entry ("log again").
  final JournalEntry? template;

  final String? initialDate;

  static Future<bool?> show(
    BuildContext context, {
    required FoodItem food,
    JournalEntry? entry,
    JournalEntry? template,
    String? initialDate,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext context) => JournalEntrySheet(
        food: food,
        entry: entry,
        template: template,
        initialDate: initialDate,
      ),
    );
  }

  @override
  State<JournalEntrySheet> createState() => _JournalEntrySheetState();
}

class _JournalEntrySheetState extends State<JournalEntrySheet> {
  late final TextEditingController _quantity;
  late QuantityUnit _unit;
  late MealSlot _meal;
  late String _portionLabel;
  late DateTime _moment;
  late final TextEditingController _note;

  @override
  void initState() {
    super.initState();
    final JournalEntry? entry = widget.entry;
    final JournalEntry? seed = entry ?? widget.template;
    final FoodItem food = widget.food;
    _quantity = TextEditingController(
      text: seed != null
          ? _trim(seed.quantity)
          : (food.servingGrams != null ? _trim(food.servingGrams!) : '100'),
    );
    _unit = seed?.unit ?? QuantityUnit.gram;
    _meal = seed?.meal ?? _suggestMeal();
    final List<String> labels = food.portions
        .map((Portion p) => p.label)
        .toList(growable: false);
    _portionLabel = seed?.portionLabel ??
        (labels.isNotEmpty
            ? labels.first
            : (food.servingLabel ?? '1 Portion'));
    _moment = entry != null
        ? DateTime.fromMillisecondsSinceEpoch(entry.loggedAtMs)
        : _initialMoment();
    _note = TextEditingController(text: seed?.note ?? '');
  }

  DateTime _initialMoment() {
    final String? date = widget.initialDate;
    final DateTime now = DateTime.now();
    if (date == null) return now;
    final DateTime parsed = DateMath.parse(date);
    return DateTime(
      parsed.year,
      parsed.month,
      parsed.day,
      now.hour,
      now.minute,
    );
  }

  MealSlot _suggestMeal() {
    final int hour = DateTime.now().hour;
    if (hour < 10) return MealSlot.breakfast;
    if (hour < 15) return MealSlot.lunch;
    if (hour < 19) return MealSlot.dinner;
    return MealSlot.snack;
  }

  static String _trim(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(1);
  }

  @override
  void dispose() {
    _quantity.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final FoodItem food = widget.food;
    final List<String> portions = food.portions
        .map((Portion p) => p.label)
        .toList(growable: false);
    final double? portionGrams = _portionGrams(food);

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
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        food.name,
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      if (food.brand != null)
                        Text(
                          food.brand!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
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
            Row(
              children: <Widget>[
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _quantity,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: l10n.t('nutrition.quantity'),
                    ),
                    onChanged: (String _) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<QuantityUnit>(
                    initialValue: _unit,
                    decoration: InputDecoration(labelText: l10n.t('common.unit')),
                    items: <DropdownMenuItem<QuantityUnit>>[
                      DropdownMenuItem<QuantityUnit>(
                        value: QuantityUnit.gram,
                        child: Text(l10n.t('nutrition.unit.g')),
                      ),
                      DropdownMenuItem<QuantityUnit>(
                        value: QuantityUnit.milliliter,
                        child: Text(l10n.t('nutrition.unit.ml')),
                      ),
                      DropdownMenuItem<QuantityUnit>(
                        value: QuantityUnit.portion,
                        child: Text(l10n.t('nutrition.unit.portion')),
                      ),
                    ],
                    onChanged: (QuantityUnit? value) {
                      if (value == null) return;
                      setState(() => _unit = value);
                    },
                  ),
                ),
              ],
            ),
            if (_unit == QuantityUnit.portion && portions.isNotEmpty) ...<Widget>[
              const SizedBox(height: 10),
              DropdownButtonFormField<String>(
                initialValue: portions.contains(_portionLabel)
                    ? _portionLabel
                    : portions.first,
                decoration:
                    InputDecoration(labelText: l10n.t('nutrition.serving')),
                items: <DropdownMenuItem<String>>[
                  for (final String label in portions)
                    DropdownMenuItem<String>(value: label, child: Text(label)),
                ],
                onChanged: (String? value) {
                  if (value == null) return;
                  setState(() => _portionLabel = value);
                },
              ),
            ],
            const SizedBox(height: 10),
            DropdownButtonFormField<MealSlot>(
              initialValue: _meal,
              decoration: InputDecoration(labelText: l10n.t('nutrition.select_meal')),
              items: <DropdownMenuItem<MealSlot>>[
                for (final MealSlot meal in MealSlot.values)
                  DropdownMenuItem<MealSlot>(
                    value: meal,
                    child: Text(l10n.t('meal.${meal.name}')),
                  ),
              ],
              onChanged: (MealSlot? value) {
                if (value == null) return;
                setState(() => _meal = value);
              },
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickDate,
                    icon: const Icon(Icons.calendar_today_outlined),
                    label: Text(
                      DateFormat.yMd(
                        Localizations.localeOf(context).toLanguageTag(),
                      ).format(_moment),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickTime,
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
                labelText: '${l10n.t('common.note')} (${l10n.t('common.optional')})',
              ),
            ),
            const SizedBox(height: 10),
            _Preview(food: food, grams: _currentQuantity(food, portionGrams)),
            const SizedBox(height: 14),
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
            SizedBox(height: state.busy ? 4 : 0),
          ],
        ),
      ),
    );
  }

  double _currentQuantity(FoodItem food, double? portionGrams) {
    final double quantity = double.tryParse(_quantity.text.replaceAll(',', '.')) ?? 0;
    switch (_unit) {
      case QuantityUnit.gram:
        return quantity;
      case QuantityUnit.milliliter:
        return quantity;
      case QuantityUnit.portion:
        return quantity * (portionGrams ?? 100);
    }
  }

  double? _portionGrams(FoodItem food) {
    for (final Portion portion in food.portions) {
      if (portion.label == _portionLabel) return portion.amountGrams;
    }
    return food.servingGrams;
  }

  Future<void> _pickDate() async {
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
    final FoodItem food = widget.food;
    final double quantity =
        double.tryParse(_quantity.text.replaceAll(',', '.')) ?? 0;
    if (quantity <= 0) return;

    final JournalEntry? existing = widget.entry;
    final JournalEntry entry = JournalEntry(
      id: existing?.id ?? Ids.newId(),
      foodId: food.id,
      foodName: food.name,
      brand: food.brand,
      quantity: quantity,
      unit: _unit,
      meal: _meal,
      date: DateMath.format(_moment),
      loggedAtMs: _moment.millisecondsSinceEpoch,
      portionLabel:
          _unit == QuantityUnit.portion ? _portionLabel : null,
      portionGrams:
          _unit == QuantityUnit.portion ? _portionGrams(food) : null,
      note: _note.text.trim().isEmpty ? null : _note.text.trim(),
      nutrientsPer100Snapshot: food.nutrientsPer100.values,
      createdAtMs: existing?.createdAtMs ?? DateTime.now().millisecondsSinceEpoch,
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
    );
    await state.upsertJournalEntry(entry);
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _delete() async {
    final AppState state = AppScope.of(context);
    final JournalEntry? entry = widget.entry;
    if (entry == null) return;
    await state.deleteJournalEntry(entry.id);
    if (mounted) Navigator.of(context).pop(true);
  }
}

class _Preview extends StatelessWidget {
  const _Preview({required this.food, required this.grams});

  final FoodItem food;
  final double grams;

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final double factor = grams / 100.0;
    final double kcal = food.nutrientsPer100[Nutrients.energyKcal] * factor;
    final double protein = food.nutrientsPer100[Nutrients.protein] * factor;
    final double carbs = food.nutrientsPer100[Nutrients.carbohydrates] * factor;
    final double fat = food.nutrientsPer100[Nutrients.fat] * factor;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: <Widget>[
          _value(context, '${kcal.round()}', 'kcal'),
          _value(context, protein.toStringAsFixed(1), 'g ${l10n.nutrientLabel(Nutrients.protein)}'),
          _value(context, carbs.toStringAsFixed(1), 'g ${l10n.nutrientLabel(Nutrients.carbohydrates)}'),
          _value(context, fat.toStringAsFixed(1), 'g ${l10n.nutrientLabel(Nutrients.fat)}'),
        ],
      ),
    );
  }

  Widget _value(BuildContext context, String value, String unit) {
    final ThemeData theme = Theme.of(context);
    return Column(
      children: <Widget>[
        Text(
          value,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          unit,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
