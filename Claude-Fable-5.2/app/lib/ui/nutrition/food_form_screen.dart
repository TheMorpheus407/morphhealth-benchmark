import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:morphhealth_core/morphhealth_core.dart';

import '../format.dart';
import '../widgets/common.dart';

/// Form for creating or editing an own food, including all micronutrients.
///
/// Pops with the saved [Food], or with null if nothing was saved.
class FoodFormScreen extends StatefulWidget {
  /// The food to edit; null creates a new one.
  final Food? food;

  /// Prefilled values for a new food.
  final String? initialName;
  final String? initialBarcode;

  const FoodFormScreen({
    super.key,
    this.food,
    this.initialName,
    this.initialBarcode,
  });

  @override
  State<FoodFormScreen> createState() => _FoodFormScreenState();
}

class _FoodFormScreenState extends State<FoodFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _brand = TextEditingController();
  final _barcode = TextEditingController();
  final _servingSize = TextEditingController();
  final _servingLabel = TextEditingController();
  final _density = TextEditingController();
  final _note = TextEditingController();
  final Map<Nutrient, TextEditingController> _nutrients = {
    for (final n in Nutrients.all) n: TextEditingController(),
  };
  FoodBasis _basis = FoodBasis.per100g;
  bool _initialized = false;
  bool _saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final fmt = Fmt.of(context, today: context.appRead.today);
    final food = widget.food;
    if (food == null) {
      _name.text = widget.initialName ?? '';
      _barcode.text = widget.initialBarcode ?? '';
      return;
    }
    _name.text = food.name;
    _brand.text = food.brand ?? '';
    _barcode.text = food.barcode ?? '';
    _basis = food.basis;
    if (food.servingSize != null) {
      _servingSize.text = fmt.editable(food.servingSize!);
    }
    _servingLabel.text = food.servingLabel ?? '';
    if (food.densityGPerMl != null) {
      _density.text = fmt.editable(food.densityGPerMl!, decimals: 3);
    }
    _note.text = food.note ?? '';
    for (final n in Nutrients.all) {
      final v = food.nutrients[n];
      if (v != null) _nutrients[n]!.text = fmt.editable(v, decimals: 4);
    }
  }

  @override
  void dispose() {
    for (final c in [
      _name, _brand, _barcode, _servingSize, _servingLabel, _density, _note,
      ..._nutrients.values, //
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _text(TextEditingController c) {
    final t = c.text.trim();
    return t.isEmpty ? null : t;
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final app = context.appRead;
    final now = app.now;
    final values = NutrientValues();
    for (final n in Nutrients.all) {
      final v = Fmt.parse(_nutrients[n]!.text);
      if (v != null) values[n] = v;
    }
    final existing = widget.food;
    final food = Food(
      id: existing?.id ?? app.repository.createId(),
      source: FoodSource.custom,
      name: _name.text.trim(),
      brand: _text(_brand),
      barcode: _text(_barcode),
      basis: _basis,
      servingSize: Fmt.parse(_servingSize.text),
      servingLabel: _text(_servingLabel),
      densityGPerMl: Fmt.parse(_density.text),
      nutrients: values,
      favorite: existing?.favorite ?? false,
      note: _text(_note),
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    Food? saved;
    final ok = await guarded(context, () async {
      saved = await app.repository.saveFood(food);
    });
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) Navigator.of(context).pop(saved);
  }

  Future<void> _delete() async {
    final food = widget.food;
    if (food == null) return;
    final l = context.l;
    final repo = context.appRead.repository;
    final sure = await confirm(
      context,
      title: l.deleteFoodConfirm(food.name),
      action: l.delete,
      destructive: true,
    );
    if (!sure || !mounted) return;
    FoodDeletion? outcome;
    final ok = await guarded(context, () async {
      outcome = await repo.deleteFood(food.id);
    });
    if (!ok || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 6),
          content: Text(
            outcome == FoodDeletion.archived ? l.foodArchived : l.foodDeleted,
          ),
        ),
      );
  }

  Widget _nutrientField(Nutrient n) {
    final l = context.l;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: NumberField(
        controller: _nutrients[n]!,
        label: l.nutrient(n),
        unit: n.unit,
        max: n == Nutrients.energy ? 1000 : null,
        textInputAction: TextInputAction.next,
      ),
    );
  }

  Widget _group(NutrientGroup group, {String? footer}) {
    final l = context.l;
    return PlainCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          maintainState: true,
          title: Text(l.nutrientGroup(group)),
          childrenPadding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          children: [
            for (final n in Nutrients.inGroup(group)) _nutrientField(n),
            if (footer != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(footer, style: context.texts.bodySmall),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final fmt = context.fmt;
    final unit = _basis.unit;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.food == null ? l.foodNew : l.editFood),
        actions: [
          if (widget.food != null)
            IconButton(
              tooltip: l.delete,
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
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
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              TextFormField(
                enableIMEPersonalizedLearning: false,
                controller: _name,
                autofocus: widget.food == null && _name.text.isEmpty,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                maxLength: 200,
                decoration: InputDecoration(
                  labelText: l.foodName,
                  counterText: '',
                ),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? l.requiredField : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                enableIMEPersonalizedLearning: false,
                controller: _brand,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                maxLength: 200,
                decoration: InputDecoration(
                  labelText: l.brand,
                  counterText: '',
                ),
              ),
              const SizedBox(height: 16),
              Text(l.basisTitle, style: context.texts.labelLarge),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<FoodBasis>(
                  showSelectedIcon: false,
                  segments: [
                    for (final b in FoodBasis.values)
                      ButtonSegment(value: b, label: Text(fmt.basis(b))),
                  ],
                  selected: {_basis},
                  onSelectionChanged: (s) => setState(() => _basis = s.first),
                ),
              ),
              const SizedBox(height: 16),
              NumberField(
                controller: _servingSize,
                label: l.servingSizeOptional,
                unit: unit,
                allowZero: false,
                max: 100000,
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 12),
              TextFormField(
                enableIMEPersonalizedLearning: false,
                controller: _servingLabel,
                textInputAction: TextInputAction.next,
                maxLength: 100,
                decoration: InputDecoration(
                  labelText: l.servingLabelOptional,
                  hintText: l.servingLabelHint,
                  counterText: '',
                ),
              ),
              SectionTitle(
                '${l.nutrientGroup(NutrientGroup.macro)} ${l.per(fmt.basis(_basis))}',
                padding: const EdgeInsets.fromLTRB(0, 20, 0, 4),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  l.emptyMeansUnknown,
                  style: context.texts.bodySmall,
                ),
              ),
              for (final n in Nutrients.main) _nutrientField(n),
              _group(NutrientGroup.detail, footer: l.saltSodiumHint),
              _group(NutrientGroup.vitamin),
              _group(NutrientGroup.mineral),
              PlainCard(
                margin: const EdgeInsets.only(bottom: 12),
                child: Theme(
                  data: Theme.of(
                    context,
                  ).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    maintainState: true,
                    title: Text(l.advanced),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                    children: [
                      TextFormField(
                        enableIMEPersonalizedLearning: false,
                        controller: _barcode,
                        keyboardType: TextInputType.number,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(14),
                        ],
                        decoration: InputDecoration(
                          labelText: l.barcodeOptional,
                        ),
                      ),
                      const SizedBox(height: 12),
                      NumberField(
                        controller: _density,
                        label: l.densityOptional,
                        helper: l.densityHelper,
                        allowZero: false,
                        max: 25,
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
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
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
