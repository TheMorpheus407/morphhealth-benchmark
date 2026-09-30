import 'package:flutter/material.dart';

import '../../../core/food/off_client.dart';
import '../../../core/l10n/format.dart';
import '../../../core/model/dataset.dart';
import '../../../core/model/entries.dart';
import '../../../core/model/enums.dart';
import '../../../core/model/food.dart';
import '../../../core/model/nutrients.dart';
import '../../../core/util/local_date.dart';
import '../../controller.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/inputs.dart';
import 'custom_food_editor.dart';
import 'intake_cards.dart';
import 'nutrient_list.dart';
import 'nutrition_screen.dart';

/// Log a food (new entry) or correct an existing entry: amount in g, ml or
/// portions, meal, date/time, note, with a live nutrient preview.
class LogFoodScreen extends StatefulWidget {
  const LogFoodScreen.create({
    super.key,
    required FoodProfile this.profile,
    this.foodRef,
    required LocalDate this.date,
    required Meal this.meal,
    this.fetchDetails = false,
    this.initialAmount,
    this.initialUnit,
  }) : entry = null;

  const LogFoodScreen.edit({super.key, required FoodEntry this.entry})
    : profile = null,
      foodRef = null,
      date = null,
      meal = null,
      fetchDetails = false,
      initialAmount = null,
      initialUnit = null;

  final FoodEntry? entry;
  final FoodProfile? profile;
  final String? foodRef;
  final LocalDate? date;
  final Meal? meal;
  final bool fetchDetails;
  final double? initialAmount;
  final AmountUnit? initialUnit;

  @override
  State<LogFoodScreen> createState() => _LogFoodScreenState();
}

class _LogFoodScreenState extends State<LogFoodScreen> {
  final _form = GlobalKey<FormState>();
  late FoodProfile _profile;
  String? _foodRef;
  late final TextEditingController _amount;
  late final TextEditingController _note;
  late AmountUnit _unit;
  late Meal _meal;
  late LocalDate _date;
  int? _time;
  bool _loadingDetails = false;
  bool _saving = false;

  bool get _editing => widget.entry != null;

  @override
  void initState() {
    super.initState();
    final app = context.appRead;
    final entry = widget.entry;
    if (entry != null) {
      _profile = entry.food;
      _foodRef = entry.foodRef;
      _unit = entry.unit;
      _meal = entry.meal;
      _date = entry.date;
      _time = entry.time;
      _amount = TextEditingController(text: app.fmt.input(entry.amount));
      _note = TextEditingController(text: entry.note ?? '');
    } else {
      _profile = widget.profile!;
      _foodRef = widget.foodRef;
      _meal = widget.meal!;
      _date = widget.date!;
      _time = _date == app.today ? app.service.clock.minutesOfDay() : _defaultTime(_meal);
      final unit = widget.initialUnit;
      if (unit != null && widget.initialAmount != null && _profile.supportedUnits.contains(unit)) {
        _unit = unit;
        _amount = TextEditingController(text: app.fmt.input(widget.initialAmount!));
      } else if (_profile.hasServing) {
        _unit = AmountUnit.portion;
        _amount = TextEditingController(text: '1');
      } else {
        _unit = _profile.basis == Basis.g ? AmountUnit.g : AmountUnit.ml;
        _amount = TextEditingController(text: '100');
      }
      _note = TextEditingController();
      if (widget.fetchDetails && _profile.barcode != null && app.settings.onlineFoodSearch) {
        _loadDetails();
      }
    }
  }

  static int _defaultTime(Meal meal) => switch (meal) {
    Meal.breakfast => 8 * 60,
    Meal.lunch => 12 * 60 + 30,
    Meal.dinner => 18 * 60 + 30,
    Meal.snack => 15 * 60 + 30,
  };

  Future<void> _loadDetails() async {
    setState(() => _loadingDetails = true);
    try {
      final food = await context.appRead.service.fetchProduct(_profile.barcode!);
      if (food != null && mounted && food.profile.nutrients.isNotEmpty) {
        setState(() {
          _profile = food.profile;
          if (!_profile.supportedUnits.contains(_unit)) {
            _unit = _profile.basis == Basis.g ? AmountUnit.g : AmountUnit.ml;
          }
        });
      }
    } on FoodApiException {
      // Keep the data from the search result.
    } finally {
      if (mounted) setState(() => _loadingDetails = false);
    }
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  double? get _amountValue => Fmt.parseNumber(_amount.text);

  double? get _quantity {
    final a = _amountValue;
    if (a == null || a <= 0) return null;
    return _profile.quantityInBasis(a, _unit);
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate() || _saving) return;
    final app = context.appRead;
    final amount = _amountValue!;
    final note = _note.text.trim().isEmpty ? null : _note.text.trim();
    setState(() => _saving = true);
    final ok = await app.run(() async {
      final entry = widget.entry;
      if (entry == null) {
        await app.service.addFoodEntry(
          date: _date,
          time: _time,
          meal: _meal,
          amount: amount,
          unit: _unit,
          food: _profile,
          foodRef: _foodRef,
          note: note,
        );
        app.showMessage(app.s.addedToDiary(_profile.name));
      } else {
        await app.service.updateFoodEntry(entry.copyWith(
          date: _date,
          time: () => _time,
          meal: _meal,
          amount: amount,
          unit: _unit,
          food: _profile,
          note: () => note,
          updatedAt: app.service.clock.nowUtc(),
        ));
        app.showMessage(app.s.saved);
      }
    });
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final s = app.s;
    final fmt = app.fmt;
    final library = app.service.libraryFoodFor(_profile, foodRef: _foodRef);
    final isFavorite = library?.favorite ?? false;
    final quantity = _quantity;
    final maxAmount = _unit == AmountUnit.portion ? FoodEntry.maxPortions : FoodEntry.maxAmountGramOrMl;
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing ? s.editEntry : s.addFood),
        actions: [
          IconButton(
            tooltip: isFavorite ? s.removeFavorite : s.addFavorite,
            icon: Icon(isFavorite ? Icons.star : Icons.star_outline),
            onPressed: () => app.run(() => app.service.setFavorite(_profile, !isFavorite, foodRef: _foodRef)),
          ),
          if (library != null && library.isCustom)
            IconButton(
              tooltip: s.editCustomFood,
              icon: const Icon(Icons.edit_note),
              onPressed: () async {
                final updated = await Navigator.of(context).push<Food>(
                  MaterialPageRoute(builder: (_) => CustomFoodEditor(food: library)),
                );
                if (updated != null && mounted) setState(() => _profile = updated.profile);
              },
            ),
          if (_editing)
            PopupMenuButton<String>(
              tooltip: s.more,
              onSelected: (action) async {
                final entry = widget.entry!;
                if (action == 'again') {
                  await relogWithDialog(context, entry);
                } else if (action == 'delete') {
                  Navigator.of(context).pop();
                  await deleteWithUndo(context, Collection.foodEntries, entry);
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'again', child: Text(s.logAgain)),
                PopupMenuItem(value: 'delete', child: Text(s.delete)),
              ],
            ),
        ],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: pagePadding(context),
          children: [
            _Header(profile: _profile, loading: _loadingDetails),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: NumberField(
                    controller: _amount,
                    label: s.amount,
                    min: 0,
                    minExclusive: true,
                    max: maxAmount,
                    required: true,
                    onChanged: (_) => setState(() {}),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<AmountUnit>(
                    initialValue: _unit,
                    isExpanded: true,
                    decoration: InputDecoration(labelText: s.unit),
                    items: [
                      for (final u in _profile.supportedUnits)
                        DropdownMenuItem(value: u, child: Text(s.unitName(u, plural: true))),
                    ],
                    onChanged: (u) => setState(() => _unit = u ?? _unit),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            _QuickAmounts(
              profile: _profile,
              onSelected: (amount, unit) => setState(() {
                _amount.text = fmt.input(amount);
                _unit = unit;
              }),
            ),
            if (_profile.hasServing)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  s.portionDescription(_profile.servingLabel, fmt.number(_profile.servingSize!, 1), _profile.basis),
                  style: context.text.bodySmall,
                ),
              ),
            if (_profile.usesAssumedDensity(_unit))
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(s.assumedDensity, style: context.text.bodySmall),
              ),
            const SizedBox(height: 16),
            DropdownButtonFormField<Meal>(
              initialValue: _meal,
              isExpanded: true,
              decoration: InputDecoration(labelText: s.meal, prefixIcon: Icon(mealIcon(_meal))),
              items: [
                for (final m in Meal.values) DropdownMenuItem(value: m, child: Text(s.mealName(m))),
              ],
              onChanged: (m) => setState(() => _meal = m ?? _meal),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(child: DateField(date: _date, onChanged: (d) => setState(() => _date = d))),
                const SizedBox(width: 12),
                Expanded(child: TimeField(minutes: _time, onChanged: (t) => setState(() => _time = t))),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _note,
              maxLength: 2000,
              minLines: 1,
              maxLines: 4,
              decoration: InputDecoration(labelText: s.noteOptional),
            ),
            const SizedBox(height: 8),
            SectionCard(
              title: s.nutrientsForAmount,
              icon: Icons.analytics_outlined,
              iconColor: context.colors.nutrition,
              child: quantity == null
                  ? EmptyHint(s.invalidNumber)
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          macroLine(context, (k) => _profile.valueFor(k, quantity)),
                          style: context.text.titleSmall,
                        ),
                        if (_profile.nutrients.isEmpty) EmptyHint(s.noNutritionData),
                        Theme(
                          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                          child: ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            title: Text(s.allNutrients),
                            children: [
                              NutrientList(
                                valueOf: (n) => _profile.valueFor(n.key, quantity),
                                isEstimated: (n) => _profile.estimatedNutrients.contains(n.key),
                                singleFood: true,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                '${s.perHundred(_profile.basis)}: '
                                '${macroLine(context, (k) => _profile.nutrients[k])}',
                                style: context.text.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: Icon(_editing ? Icons.check : Icons.add),
              label: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(_editing ? s.save : s.addToDiary),
              ),
            ),
            if (_profile.source == FoodSource.openFoodFacts)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(s.offAttribution, style: context.text.bodySmall),
              ),
          ],
        ),
      ),
    );
  }
}

/// One-tap amounts: common portion multiples and gram/millilitre values.
class _QuickAmounts extends StatelessWidget {
  const _QuickAmounts({required this.profile, required this.onSelected});

  final FoodProfile profile;
  final void Function(double amount, AmountUnit unit) onSelected;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final fmt = context.fmt;
    final basisUnit = profile.basis == Basis.g ? AmountUnit.g : AmountUnit.ml;
    final options = <(double, AmountUnit)>[
      if (profile.hasServing) ...[
        (0.5, AmountUnit.portion),
        (1, AmountUnit.portion),
        (2, AmountUnit.portion),
      ],
      for (final v in const [50.0, 100.0, 150.0, 200.0, 250.0]) (v, basisUnit),
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      children: [
        for (final (amount, unit) in options)
          ActionChip(
            label: Text(
              unit == AmountUnit.portion
                  ? '${fmt.number(amount, 1)} ${s.unitName(unit, plural: amount != 1)}'
                  : '${fmt.integer(amount)} ${unit.json}',
            ),
            onPressed: () => onSelected(amount, unit),
          ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.profile, required this.loading});

  final FoodProfile profile;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final fmt = context.fmt;
    final kcal = profile.nutrients[Nutrients.energy.key];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(header: true, child: Text(profile.name, style: context.text.headlineSmall)),
        const SizedBox(height: 4),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (profile.brand != null) Text(profile.brand!, style: context.text.bodyMedium),
            TagChip(profile.source == FoodSource.custom ? s.customFood : s.onlineFood),
            if (profile.barcode != null) Text('EAN ${profile.barcode}', style: context.text.bodySmall),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          kcal == null
              ? s.noNutritionData
              : '${fmt.integer(kcal)} kcal ${s.perHundred(profile.basis)}',
          style: context.text.bodyMedium,
        ),
        if (loading) ...[
          const SizedBox(height: 8),
          Semantics(label: s.loading, child: const LinearProgressIndicator()),
        ],
      ],
    );
  }
}
