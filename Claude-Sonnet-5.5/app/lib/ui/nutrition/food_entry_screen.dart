import 'package:flutter/material.dart';

import '../../core/civil.dart';
import '../../core/db.dart';
import '../../core/ids.dart';
import '../../core/models.dart';
import '../../core/nutrients.dart';
import '../../state/app_state.dart';
import '../format.dart';
import '../l10n_x.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/fields.dart';
import 'custom_food_screen.dart';
import 'nutrient_table.dart';
import 'water_caffeine.dart';

/// Eine Portionsbezeichnung wie "40 g" wiederholt nur die Größe und ist kein
/// eigener Hinweis. Nur echte Bezeichnungen ("1 Scheibe") werden angezeigt.
String? _usefulLabel(String? label) {
  if (label == null) return null;
  final t = label.trim();
  if (t.isEmpty || RegExp(r'^\d+([.,]\d+)?\s*(g|ml)$', caseSensitive: false).hasMatch(t)) return null;
  return t;
}

/// Vorbelegung der Mahlzeit nach Tageszeit.
Meal mealForTime(int hour, int minute) {
  final m = hour * 60 + minute;
  if (m < 10 * 60 + 30) return Meal.breakfast;
  if (m < 15 * 60) return Meal.lunch;
  if (m < 17 * 60 + 30) return Meal.snack;
  if (m < 21 * 60 + 30) return Meal.dinner;
  return Meal.snack;
}

/// Erfassen oder Bearbeiten eines Verzehreintrags.
class FoodEntryScreen extends StatefulWidget {
  final FoodInfo food;

  /// Bibliotheks-ID, falls das Lebensmittel schon in der Bibliothek liegt.
  final String? foodId;
  final FoodEntry? existing;
  final Meal? meal;
  final Day? day;
  final double? amount;
  final AmountUnit? unit;

  const FoodEntryScreen({
    super.key,
    required this.food,
    this.foodId,
    this.existing,
    this.meal,
    this.day,
    this.amount,
    this.unit,
  });

  @override
  State<FoodEntryScreen> createState() => _FoodEntryScreenState();
}

class _FoodEntryScreenState extends State<FoodEntryScreen> {
  final _form = GlobalKey<FormState>();
  late FoodInfo _food;
  String? _foodId;
  late final TextEditingController _amount;
  late final TextEditingController _serving;
  late final TextEditingController _note;
  late AmountUnit _unit;
  late Meal _meal;
  late Day _day;
  late TimeOfDay _time;
  late bool _favorite;
  bool _initialized = false;

  bool get _editing => widget.existing != null;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final app = AppScope.read(context);
    final f = Fmt(app.lang);
    final e = widget.existing;
    _food = widget.food;
    _foodId = widget.foodId ?? e?.foodId;
    _favorite = _foodId != null && (app.db.food(_foodId!)?.favorite ?? false);
    final base = _food.basis == Basis.ml ? AmountUnit.ml : AmountUnit.g;
    if (e != null) {
      _unit = e.unit;
      _amount = TextEditingController(text: f.input(e.amount, 3));
      _meal = e.meal;
      _day = e.day;
      _time = TimeOfDay(hour: e.at.hour, minute: e.at.minute);
      _note = TextEditingController(text: e.note ?? '');
    } else {
      _unit = widget.unit ?? (_food.serving != null ? AmountUnit.portion : base);
      final def = _unit == AmountUnit.portion ? 1.0 : 100.0;
      _amount = TextEditingController(text: f.input(widget.amount ?? def, 3));
      _day = widget.day ?? app.selectedDay;
      final at = defaultTimeFor(app, _day);
      _time = TimeOfDay(hour: at.hour, minute: at.minute);
      _meal = widget.meal ?? mealForTime(at.hour, at.minute);
      _note = TextEditingController();
    }
    _serving = TextEditingController(text: _food.serving == null ? '' : f.input(_food.serving!.amount, 3));
  }

  @override
  void dispose() {
    _amount.dispose();
    _serving.dispose();
    _note.dispose();
    super.dispose();
  }

  Basis get _basis => _food.basis;
  AmountUnit get _baseUnit => _basis == Basis.ml ? AmountUnit.ml : AmountUnit.g;

  /// Größe einer Portion (in g/ml): vom Lebensmittel oder aus dem Eingabefeld.
  double? get _servingAmount {
    if (_food.serving != null) return _food.serving!.amount;
    final v = Fmt.parse(_serving.text);
    return v != null && v > 0 ? v : null;
  }

  Nutrients get _preview {
    final a = Fmt.parse(_amount.text);
    if (a == null || a <= 0) return Nutrients.none;
    final base = _unit == AmountUnit.portion ? (_servingAmount == null ? 0.0 : a * _servingAmount!) : a;
    return _food.nutrients.scaled(base / 100);
  }

  Future<void> _toggleFavorite() async {
    final app = AppScope.read(context);
    final l = context.l10n;
    setState(() => _favorite = !_favorite);
    if (_foodId != null && app.db.food(_foodId!) != null) {
      await app.db.setFavorite(_foodId!, _favorite);
      if (mounted) showMessage(context, _favorite ? l.foodFavoriteAdded : l.foodFavoriteRemoved);
    }
  }

  Future<void> _copyAsCustom() async {
    final copy = await Navigator.of(context).push<Food>(
      MaterialPageRoute(
        builder: (_) => CustomFoodScreen(initial: _food.copyWith(source: FoodSource.custom)),
      ),
    );
    if (copy != null && mounted) {
      setState(() {
        _food = copy.info;
        _foodId = copy.id;
        _favorite = copy.favorite;
      });
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final app = AppScope.read(context);
    final l = context.l10n;
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final amount = Fmt.parse(_amount.text)!;
    var info = _food;
    if (_unit == AmountUnit.portion && info.serving == null) {
      info = info.copyWith(serving: () => Serving(_servingAmount!));
    }
    final at = LocalDateTime(_day, _time.hour, _time.minute);
    final note = _note.text.trim().isEmpty ? null : _note.text.trim();
    try {
      var foodId = _foodId;
      if (!_editing && info.source == FoodSource.off) {
        final lib = await app.db.upsertOffFood(info);
        foodId = lib.id;
        if (_favorite != lib.favorite) await app.db.setFavorite(lib.id, _favorite);
      } else if (foodId != null && app.db.food(foodId) != null && _food.serving == null && info.serving != null) {
        // Die selbst festgelegte Portionsgröße für das nächste Mal merken.
        final lib = app.db.food(foodId)!;
        await app.db.saveFood(lib.copyWith(info: lib.info.copyWith(serving: () => info.serving)));
      }
      final e = widget.existing;
      final entry = e == null
          ? FoodEntry(
              id: newId(),
              foodId: foodId,
              food: info,
              amount: amount,
              unit: _unit,
              meal: _meal,
              at: at,
              note: note,
            )
          : e.copyWith(
              foodId: () => foodId,
              food: info,
              amount: amount,
              unit: _unit,
              meal: _meal,
              at: at,
              note: () => note,
            );
      await app.db.saveEntry(entry);
      nav.pop(true);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Text(e == null ? l.entryAddedToMeal(info.name, l.meal(_meal)) : l.entryUpdated),
          action: e == null ? SnackBarAction(label: l.commonUndo, onPressed: () => app.db.deleteEntry(entry.id)) : null,
        ),
      );
    } on DomainException catch (e) {
      if (mounted) showMessage(context, domainErrorText(l, e));
    }
  }

  Future<void> _delete() async {
    final app = AppScope.read(context);
    final l = context.l10n;
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final e = widget.existing!;
    await app.db.deleteEntry(e.id);
    nav.pop(true);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(l.nutritionEntryDeleted),
        action: SnackBarAction(label: l.commonUndo, onPressed: () => app.db.saveEntry(e)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final f = context.fmt;
    final color = areaColor(Area.nutrition, context.theme.brightness);
    final preview = _preview;
    final needsServing = _unit == AmountUnit.portion && _food.serving == null;
    final incomplete = !_food.nutrients.has(kEnergy);
    return AppScaffold(
      appBar: AppBar(
        title: Text(_editing ? l.entryEditTitle : l.entryAddTitle),
        actions: [
          if (_foodId != null || _food.source == FoodSource.off)
            IconButton(
              tooltip: _favorite ? l.entryFavoriteRemove : l.entryFavoriteAdd,
              isSelected: _favorite,
              icon: const Icon(Icons.star_border),
              selectedIcon: Icon(Icons.star, color: context.colors.tertiary),
              onPressed: _toggleFavorite,
            ),
          if (_food.source == FoodSource.off)
            PopupMenuButton<String>(
              tooltip: l.commonMore,
              onSelected: (v) {
                if (v == 'copy') _copyAsCustom();
              },
              itemBuilder: (c) => [PopupMenuItem(value: 'copy', child: Text(l.entryCopyToCustom))],
            ),
        ],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          children: [
            _Header(food: _food, color: color),
            const SizedBox(height: 16),
            ControlGroup(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: NumberField(
                      controller: _amount,
                      label: l.entryAmount,
                      required: true,
                      positive: true,
                      max: 100000,
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: SegmentedButton<AmountUnit>(
                        showSelectedIcon: false,
                        segments: [
                          ButtonSegment(value: _baseUnit, label: Text(l.unit(_baseUnit))),
                          ButtonSegment(value: AmountUnit.portion, label: Text(l.unitPortion)),
                        ],
                        selected: {_unit == AmountUnit.portion ? AmountUnit.portion : _baseUnit},
                        onSelectionChanged: (s) => setState(() {
                          final next = s.first;
                          if (next == _unit) return;
                          // Menge sinnvoll mitnehmen: 1 Portion <-> Portionsgröße.
                          final a = Fmt.parse(_amount.text);
                          final sv = _servingAmount;
                          if (a != null && sv != null) {
                            if (next == AmountUnit.portion) {
                              _amount.text = f.input(a / sv, 3);
                            } else {
                              _amount.text = f.input(a * sv, 3);
                            }
                          } else if (next == AmountUnit.portion) {
                            _amount.text = '1';
                          }
                          _unit = next;
                        }),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            if (_unit == AmountUnit.portion && _food.serving != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  '${_usefulLabel(_food.serving!.label) == null ? '' : '${_usefulLabel(_food.serving!.label)} · '}${l.entryServingInfo(f.nTrim(_food.serving!.amount, 3), l.basisUnit(_basis))}',
                  style: context.text.bodySmall,
                ),
              ),
            if (needsServing) ...[
              const SizedBox(height: 12),
              NumberField(
                controller: _serving,
                label: l.entryServingSize,
                suffix: l.basisUnit(_basis),
                required: true,
                positive: true,
                max: 100000,
                onChanged: (_) => setState(() {}),
              ),
            ],
            const SizedBox(height: 16),
            Text(l.entryMeal, style: context.text.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
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
            DateTimeRow(
              day: _day,
              time: _time,
              onDay: (d) => setState(() => _day = d),
              onTime: (t) => setState(() => _time = t),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _note,
              maxLength: 500,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: l.commonNoteOptional, counterText: ''),
            ),
            const SizedBox(height: 12),
            SectionCard(
              title: l.entryPreview,
              icon: Icons.local_fire_department_outlined,
              accent: color,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    preview.has(kEnergy) ? f.kcal(preview.get0(kEnergy)) : l.nutritionNoKcal,
                    style: context.text.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 4),
                  Wrap(
                    spacing: 16,
                    children: [
                      for (final k in [kProtein, kCarbs, kFat])
                        Text(
                          '${nutrientName(k, f.lang)} ${preview.has(k) ? f.nutrient(preview.get0(k), nutrientByKey[k]!) : '–'}',
                          style: context.text.bodyMedium,
                        ),
                    ],
                  ),
                  if (incomplete) ...[
                    const SizedBox(height: 8),
                    EmptyHint(l.entryIncompleteData, icon: Icons.info_outline),
                  ],
                  if (_food.prepared) EmptyHint(l.entryPreparedNote, icon: Icons.info_outline),
                  ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: Text(l.nutritionAllNutrients),
                    children: [NutrientTable(values: preview, onlyPresent: true)],
                  ),
                  if (_food.source == FoodSource.off)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(l.entryDataSource, style: context.text.bodySmall),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              onPressed: _save,
              icon: const Icon(Icons.check),
              label: Text(_editing ? l.commonSave : l.commonAdd),
            ),
            if (_editing) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: context.colors.error,
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: _delete,
                icon: const Icon(Icons.delete_outline),
                label: Text(l.entryDelete),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  final FoodInfo food;
  final Color color;

  const _Header({required this.food, required this.color});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final f = context.fmt;
    final n = food.nutrients;
    final name = food.name == food.barcode ? l.foodUnnamed : food.name;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(header: true, child: Text(name, style: context.text.headlineSmall)),
        if (food.brand != null)
          Text(food.brand!, style: context.text.bodyLarge?.copyWith(color: context.colors.onSurfaceVariant)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            Chip(
              avatar: Icon(food.source == FoodSource.off ? Icons.public : Icons.edit_note, size: 18, color: color),
              label: Text(food.source == FoodSource.off ? l.foodSourceOff : l.foodSourceCustom),
            ),
            if (food.barcode != null && food.barcode != food.name)
              Chip(avatar: const Icon(Icons.qr_code_2, size: 18), label: Text(food.barcode!)),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          n.has(kEnergy)
              ? '${l.foodKcalPer100(f.n(n.get0(kEnergy)), l.basisUnit(food.basis))} · '
                    '${nutrientName(kProtein, f.lang)} ${n.has(kProtein) ? f.nutrient(n.get0(kProtein), nutrientByKey[kProtein]!) : '–'} · '
                    '${nutrientName(kCarbs, f.lang)} ${n.has(kCarbs) ? f.nutrient(n.get0(kCarbs), nutrientByKey[kCarbs]!) : '–'} · '
                    '${nutrientName(kFat, f.lang)} ${n.has(kFat) ? f.nutrient(n.get0(kFat), nutrientByKey[kFat]!) : '–'}'
              : l.foodNoNutrition,
          style: context.text.bodyMedium,
        ),
      ],
    );
  }
}
