import 'package:flutter/material.dart';
import 'package:morphhealth_core/morphhealth_core.dart';

import '../l10n/app_localizations.dart';
import '../state/app_state.dart';

/// Creates or edits an own food with the full nutrient set.
class FoodEditorSheet extends StatefulWidget {
  const FoodEditorSheet({super.key, this.food});

  final FoodItem? food;

  static Future<bool?> show(BuildContext context, {FoodItem? food}) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext context) => FoodEditorSheet(food: food),
    );
  }

  @override
  State<FoodEditorSheet> createState() => _FoodEditorSheetState();
}

class _FoodEditorSheetState extends State<FoodEditorSheet> {
  late final TextEditingController _name;
  late final TextEditingController _brand;
  late final Map<String, TextEditingController> _values;
  late final TextEditingController _serving;
  bool _favorite = false;
  final List<Portion> _portions = <Portion>[];
  bool _showMicros = false;

  @override
  void initState() {
    super.initState();
    final FoodItem? food = widget.food;
    _name = TextEditingController(text: food?.name ?? '');
    _brand = TextEditingController(text: food?.brand ?? '');
    _favorite = food?.isFavorite ?? false;
    _serving = TextEditingController(
      text: food?.servingGrams == null ? '' : _trim(food!.servingGrams!),
    );
    if (food != null) _portions.addAll(food.portions);

    _values = <String, TextEditingController>{};
    for (final NutrientSpec spec in Nutrients.all) {
      final double raw = food?.nutrientsPer100[spec.id] ?? 0;
      final double shown = spec.id == Nutrients.energyKcal
          ? raw
          : spec.toDisplay(raw);
      _values[spec.id] = TextEditingController(
        text: shown == 0 ? '' : _trim(shown),
      );
    }
  }

  static String _trim(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(3).replaceAll(RegExp(r'0+$'), '').replaceAll(
          RegExp(r'\.$'),
          '',
        );
  }

  @override
  void dispose() {
    _name.dispose();
    _brand.dispose();
    _serving.dispose();
    for (final TextEditingController controller in _values.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final bool isNew = widget.food == null;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.9,
      maxChildSize: 0.95,
      minChildSize: 0.5,
      builder: (BuildContext context, ScrollController controller) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom +
                MediaQuery.of(context).padding.bottom,
          ),
          child: Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        isNew
                            ? l10n.t('nutrition.food_new')
                            : l10n.t('nutrition.edit_food'),
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close),
                      tooltip: l10n.t('common.close'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  controller: controller,
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                  children: <Widget>[
                    TextField(
                      controller: _name,
                      decoration:
                          InputDecoration(labelText: l10n.t('common.name')),
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _brand,
                      decoration: InputDecoration(
                        labelText: '${l10n.t('common.name')} (${l10n.t('common.optional')})',
                      ),
                    ),
                    const SizedBox(height: 10),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(l10n.t('common.favorite')),
                      value: _favorite,
                      onChanged: (bool value) =>
                          setState(() => _favorite = value),
                    ),
                    const Divider(height: 24),
                    Text(
                      l10n.t('nutrition.per100g'),
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 10),
                    _numberField(
                      Nutrients.energyKcal,
                      l10n.nutrientLabel(Nutrients.energyKcal),
                      'kcal',
                    ),
                    for (final NutrientSpec spec in Nutrients.macros)
                      _numberField(
                        spec.id,
                        l10n.nutrientLabel(spec.id),
                        spec.unitLabel,
                      ),
                    for (final NutrientSpec spec in Nutrients.extended)
                      _numberField(
                        spec.id,
                        l10n.nutrientLabel(spec.id),
                        spec.unitLabel,
                      ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: () =>
                          setState(() => _showMicros = !_showMicros),
                      icon: Icon(
                        _showMicros ? Icons.expand_less : Icons.expand_more,
                      ),
                      label: Text(l10n.t('nutrition.nutrients_micro')),
                    ),
                    if (_showMicros) ...<Widget>[
                      const SizedBox(height: 10),
                      for (final NutrientSpec spec in <NutrientSpec>[
                        ...Nutrients.vitamins,
                        ...Nutrients.minerals,
                      ])
                        _numberField(
                          spec.id,
                          l10n.nutrientLabel(spec.id),
                          spec.unitLabel,
                        ),
                    ],
                    const Divider(height: 28),
                    Text(
                      l10n.t('nutrition.servings'),
                      style: theme.textTheme.titleSmall,
                    ),
                    const SizedBox(height: 10),
                    TextField(
                      controller: _serving,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: l10n.t('nutrition.serving_amount'),
                      ),
                    ),
                    for (int i = 0; i < _portions.length; i++)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text(_portions[i].label),
                        subtitle: Text('${_trim(_portions[i].amountGrams)} g'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => setState(() => _portions.removeAt(i)),
                        ),
                      ),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: _addPortion,
                        icon: const Icon(Icons.add),
                        label: Text(l10n.t('nutrition.add_serving')),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: <Widget>[
                        if (widget.food != null)
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
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _numberField(String id, String label, String unit) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: TextField(
        controller: _values[id],
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: '$label ($unit)',
          isDense: true,
        ),
      ),
    );
  }

  Future<void> _addPortion() async {
    final TextEditingController label =
        TextEditingController(text: 'Portion ${_portions.length + 1}');
    final TextEditingController amount = TextEditingController(text: '100');
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text(context.l10n.t('nutrition.add_serving')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: label,
              decoration:
                  InputDecoration(labelText: context.l10n.t('nutrition.serving_label')),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: amount,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: context.l10n.t('nutrition.serving_amount'),
              ),
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.t('common.cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(context.l10n.t('common.save')),
          ),
        ],
      ),
    );
    final double grams = double.tryParse(amount.text.replaceAll(',', '.')) ?? 0;
    if (confirmed == true && label.text.trim().isNotEmpty && grams > 0) {
      setState(() {
        _portions.add(Portion(
          label: label.text.trim(),
          amountGrams: grams,
          isDefault: _portions.isEmpty,
        ));
      });
    }
    label.dispose();
    amount.dispose();
  }

  Future<void> _save() async {
    final AppState state = AppScope.of(context);
    final String name = _name.text.trim();
    if (name.isEmpty) return;

    final Map<String, double> values = <String, double>{};
    for (final NutrientSpec spec in Nutrients.all) {
      final double shown =
          double.tryParse(_values[spec.id]!.text.replaceAll(',', '.')) ?? 0;
      if (shown == 0) continue;
      if (spec.id == Nutrients.energyKcal) {
        values[Nutrients.energyKcal] = shown;
        values[Nutrients.energyKj] = shown * 4.184;
      } else {
        final double factor = spec.toDisplay(1.0);
        values[spec.id] = shown / factor;
      }
    }

    final double? serving = double.tryParse(_serving.text.replaceAll(',', '.'));
    final FoodItem? existing = widget.food;
    final FoodItem food = FoodItem(
      id: existing?.id ?? Ids.newId(),
      name: name,
      source: existing?.source ?? FoodSource.custom,
      brand: _brand.text.trim().isEmpty ? null : _brand.text.trim(),
      barcode: existing?.barcode,
      nutrientsPer100: NutrientProfile(values),
      servingGrams: serving,
      servingLabel: serving == null
          ? null
          : '1 Portion (${_trim(serving)} g)',
      portions: List<Portion>.of(_portions),
      imageUrl: existing?.imageUrl,
      isFavorite: _favorite,
      createdAtMs: existing?.createdAtMs ?? DateTime.now().millisecondsSinceEpoch,
      updatedAtMs: DateTime.now().millisecondsSinceEpoch,
      note: existing?.note,
    );
    await state.upsertFood(food);
    if (mounted) Navigator.of(context).pop(true);
  }

  Future<void> _delete() async {
    final AppState state = AppScope.of(context);
    final FoodItem? food = widget.food;
    if (food == null) return;
    await state.deleteFood(food.id);
    if (mounted) Navigator.of(context).pop(true);
  }
}
