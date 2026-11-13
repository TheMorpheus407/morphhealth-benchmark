import 'package:flutter/material.dart';
import 'package:morphhealth_core/morphhealth_core.dart';

import '../format.dart';
import '../widgets/common.dart';
import 'food_form_screen.dart';
import 'nutrient_table.dart';

/// Form for one consumed food: amount, unit, meal, date and time.
///
/// Used for a new entry (with a local [food] or a [product] that was just
/// found in Open Food Facts) and for correcting an existing [entry].
class IntakeScreen extends StatefulWidget {
  final Food? food;
  final CatalogProduct? product;
  final IntakeEntry? entry;

  /// Day of a new entry.
  final Day? day;

  /// Meal of a new entry; derived from the time of day if null.
  final Meal? meal;

  const IntakeScreen({
    super.key,
    this.food,
    this.product,
    this.entry,
    this.day,
    this.meal,
  }) : assert(food != null || product != null);

  /// Opens the form. Returns true if an entry was saved or deleted.
  static Future<bool> open(
    BuildContext context, {
    Food? food,
    CatalogProduct? product,
    IntakeEntry? entry,
    Day? day,
    Meal? meal,
  }) async {
    final result = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => IntakeScreen(
          food: food,
          product: product,
          entry: entry,
          day: day,
          meal: meal,
        ),
      ),
    );
    return result ?? false;
  }

  @override
  State<IntakeScreen> createState() => _IntakeScreenState();
}

class _IntakeScreenState extends State<IntakeScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _portionSize = TextEditingController();
  final _note = TextEditingController();
  late Food _food;
  late AmountUnit _unit;
  late Meal _meal;
  late LocalDateTime _at;
  late bool _favorite;
  bool _initialized = false;
  bool _saving = false;
  bool _showAll = false;

  bool get _isStored => widget.product == null;

  static const Map<Meal, (int, int)> _mealTimes = {
    Meal.breakfast: (8, 0),
    Meal.lunch: (12, 30),
    Meal.dinner: (19, 0),
    Meal.snack: (15, 30),
  };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final app = context.appRead;
    final fmt = Fmt.of(context, today: app.today);
    final now = app.now;
    _food = widget.food ?? widget.product!.toFood(id: 'preview', now: now);
    _favorite = _food.favorite;

    final entry = widget.entry;
    if (entry != null) {
      _unit = entry.unit;
      _amount.text = fmt.editable(entry.amount);
      _meal = entry.meal;
      _at = entry.at;
      _note.text = entry.note ?? '';
      final size = entry.portionSize ?? _food.servingSize;
      if (size != null) _portionSize.text = fmt.editable(size);
      return;
    }

    // A new entry starts with the amount of the last entry of this food,
    // otherwise with one portion or 100 g / 100 ml.
    IntakeEntry? last;
    if (_isStored) {
      for (final e in app.data.intake) {
        if (e.foodId == _food.id &&
            (last == null || e.at.compareTo(last.at) > 0)) {
          last = e;
        }
      }
    }
    if (last != null) {
      _unit = last.unit;
      _amount.text = fmt.editable(last.amount);
      final size = last.portionSize ?? _food.servingSize;
      if (size != null) _portionSize.text = fmt.editable(size);
    } else if (_food.servingSize != null) {
      _unit = AmountUnit.portion;
      _amount.text = '1';
      _portionSize.text = fmt.editable(_food.servingSize!);
    } else {
      _unit = _food.basis == FoodBasis.per100g ? AmountUnit.g : AmountUnit.ml;
      _amount.text = '100';
    }

    final day = widget.day ?? app.today;
    if (day == app.today) {
      _at = LocalDateTime(day, now.hour, now.minute, 0, now.offsetMinutes);
      _meal = widget.meal ?? Meal.suggestFor(_at);
    } else {
      _meal = widget.meal ?? Meal.lunch;
      final t = _mealTimes[_meal]!;
      _at = LocalDateTime(day, t.$1, t.$2);
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _portionSize.dispose();
    _note.dispose();
    super.dispose();
  }

  double? get _amountValue {
    final v = Fmt.parse(_amount.text);
    return v != null && v > 0 ? v : null;
  }

  double? get _portionValue {
    final v = Fmt.parse(_portionSize.text);
    return v != null && v > 0 ? v : null;
  }

  /// The quantity in the basis unit for the current input, if complete.
  double? get _quantity {
    final amount = _amountValue;
    if (amount == null) return null;
    final probe = IntakeEntry(
      id: 'probe',
      foodId: _food.id,
      at: _at,
      meal: _meal,
      amount: amount,
      unit: _unit,
      portionSize: _unit == AmountUnit.portion ? _portionValue : null,
      createdAt: _at,
      updatedAt: _at,
    );
    if (_unit == AmountUnit.portion && _portionValue == null) return null;
    return probe.basisQuantity(_food);
  }

  Future<void> _save() async {
    if (_saving || !_formKey.currentState!.validate()) return;
    final amount = _amountValue;
    if (amount == null) return;
    setState(() => _saving = true);
    final app = context.appRead;
    final l = context.l;
    final repo = app.repository;
    final note = _note.text.trim().isEmpty ? null : _note.text.trim();
    final ok = await guarded(context, () async {
      var food = _food;
      if (!_isStored) {
        food = await repo.adoptProduct(widget.product!);
      }
      if (food.favorite != _favorite) {
        await repo.setFavorite(food.id, _favorite);
      }
      final portionSize = _unit == AmountUnit.portion ? _portionValue : null;
      final entry = widget.entry;
      if (entry == null) {
        await repo.logIntake(
          foodId: food.id,
          amount: amount,
          unit: _unit,
          at: _at,
          meal: _meal,
          portionSize: portionSize,
          note: note,
        );
      } else {
        await repo.saveIntake(
          entry.copyWith(
            amount: amount,
            unit: _unit,
            at: _at,
            meal: _meal,
            portionSize: portionSize,
            note: note,
          ),
        );
      }
    });
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop(true);
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              widget.entry == null ? l.entryAdded(_food.name) : l.saved,
            ),
          ),
        );
    }
  }

  Future<void> _delete() async {
    final entry = widget.entry;
    if (entry == null) return;
    final repo = context.appRead.repository;
    final l = context.l;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await guarded(context, () => repo.deleteIntake(entry.id));
    if (!ok || !mounted) return;
    Navigator.of(context).pop(true);
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l.entryDeleted),
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: l.undo,
            onPressed: () => repo.saveIntake(entry),
          ),
        ),
      );
  }

  Future<void> _toggleFavorite() async {
    setState(() => _favorite = !_favorite);
    // For a stored food the star takes effect at once.
    if (_isStored) {
      await guarded(
        context,
        () => context.appRead.repository.setFavorite(_food.id, _favorite),
      );
    }
  }

  /// The serving description of the food, unless it only repeats the size
  /// ("40 g", "40.0g").
  static String? _servingHint(Food food) {
    final label = food.servingLabel;
    if (label == null) return null;
    final plain = RegExp(
      r'^\s*\d+(?:[.,]\d+)?\s*(?:g|gr|gram|gramm|grams|ml)?\s*$',
      caseSensitive: false,
    );
    return plain.hasMatch(label) ? null : label;
  }

  Future<void> _editFood() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(builder: (_) => FoodFormScreen(food: _food)),
    );
    if (!mounted) return;
    final updated = context.appRead.data.food(_food.id);
    if (updated != null) setState(() => _food = updated);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final fmt = context.fmt;
    final food = _food;
    final basisUnit = food.basis.unit;
    final quantity = _quantity;
    final preview = quantity == null ? null : nutrientsOf(food, quantity);
    final crossUnit =
        (_unit == AmountUnit.g && food.basis == FoodBasis.per100ml) ||
        (_unit == AmountUnit.ml && food.basis == FoodBasis.per100g);

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          tooltip: l.close,
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.of(context).pop(false),
        ),
        title: Text(food.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: _favorite ? l.favoriteRemove : l.favoriteAdd,
            isSelected: _favorite,
            icon: const Icon(Icons.star_outline),
            selectedIcon: const Icon(Icons.star),
            onPressed: _toggleFavorite,
          ),
          if (_isStored && food.isCustom)
            IconButton(
              tooltip: l.editFood,
              icon: const Icon(Icons.edit_outlined),
              onPressed: _editFood,
            ),
          if (widget.entry != null)
            IconButton(
              tooltip: l.deleteEntry,
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
          // Reachable while the keyboard covers the lower part of the form.
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
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              Text(
                [
                  if (food.brand != null) food.brand!,
                  if (food.packageQuantity != null) food.packageQuantity!,
                  food.isCustom ? l.sourceOwn : l.sourceOff,
                ].join(' · '),
                style: context.texts.bodyMedium?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
              if (food.prepared)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(l.preparedHint, style: context.texts.bodySmall),
                ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: NumberField(
                      controller: _amount,
                      label: l.amount,
                      unit: _unit == AmountUnit.portion ? null : l.unit(_unit),
                      required: true,
                      allowZero: false,
                      max: 100000,
                      autofocus: widget.entry == null,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Semantics(
                label: l.unitLabel,
                container: true,
                child: SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<AmountUnit>(
                    showSelectedIcon: false,
                    segments: [
                      for (final u in AmountUnit.values)
                        ButtonSegment(value: u, label: Text(l.unit(u))),
                    ],
                    selected: {_unit},
                    onSelectionChanged: (s) => setState(() {
                      _unit = s.first;
                      if (_unit == AmountUnit.portion &&
                          _portionSize.text.isEmpty &&
                          food.servingSize != null) {
                        _portionSize.text = fmt.editable(food.servingSize!);
                      }
                    }),
                  ),
                ),
              ),
              if (_unit == AmountUnit.portion) ...[
                const SizedBox(height: 12),
                NumberField(
                  controller: _portionSize,
                  label: l.portionSizeIn(basisUnit),
                  unit: basisUnit,
                  helper: _servingHint(food),
                  required: true,
                  allowZero: false,
                  max: 100000,
                  onChanged: (_) => setState(() {}),
                ),
              ],
              if (crossUnit)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    l.conversionHint(fmt.number(food.density, decimals: 2)),
                    style: context.texts.bodySmall?.copyWith(
                      color: context.colors.onSurfaceVariant,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              // Directly below the amount, so that it stays visible while
              // the keyboard is open.
              MhCard(
                title: quantity == null
                    ? l.nutrientsOfAmount
                    : '${l.nutrientsOfAmount} '
                          '(${fmt.adaptive(quantity)} $basisUnit)',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!food.nutrients.isEmpty)
                      MainNutrientRow(
                        values: preview ?? NutrientValues(),
                        estimated: food.estimated,
                      )
                    else
                      Text(l.noNutritionData),
                    if (!food.nutrients.isEmpty) ...[
                      const SizedBox(height: 4),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: TextButton.icon(
                          onPressed: () => setState(() => _showAll = !_showAll),
                          icon: Icon(
                            _showAll ? Icons.expand_less : Icons.expand_more,
                          ),
                          label: Text(l.allNutrients),
                        ),
                      ),
                      if (_showAll) ...[
                        NutrientTable(
                          values: preview ?? NutrientValues(),
                          estimated: food.estimated,
                        ),
                        if (food.estimated.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              l.estimatedLegend,
                              style: context.texts.bodySmall,
                            ),
                          ),
                      ],
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(l.mealLabel, style: context.texts.labelLarge),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  for (final m in Meal.values)
                    ChoiceChip(
                      label: Text(l.meal(m)),
                      selected: _meal == m,
                      onSelected: (_) => setState(() => _meal = m),
                    ),
                ],
              ),
              const SizedBox(height: 16),
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
