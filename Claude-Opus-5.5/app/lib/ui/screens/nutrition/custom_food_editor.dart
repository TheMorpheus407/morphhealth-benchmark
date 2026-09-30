import 'package:flutter/material.dart';

import '../../../core/l10n/format.dart';
import '../../../core/model/enums.dart';
import '../../../core/model/food.dart';
import '../../../core/model/nutrients.dart';
import '../../controller.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/inputs.dart';

/// Create or edit an own food with all nutrients (per 100 g or 100 ml).
/// Returns the saved [Food] when popped.
class CustomFoodEditor extends StatefulWidget {
  const CustomFoodEditor({super.key, this.food, this.initialName, this.initialBarcode});

  final Food? food;
  final String? initialName;
  final String? initialBarcode;

  @override
  State<CustomFoodEditor> createState() => _CustomFoodEditorState();
}

class _CustomFoodEditorState extends State<CustomFoodEditor> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _brand;
  late final TextEditingController _barcode;
  late final TextEditingController _serving;
  late final TextEditingController _servingLabel;
  late final TextEditingController _density;
  late final Map<String, TextEditingController> _nutrients;
  late Basis _basis;
  late bool _favorite;
  bool _saltAuto = false;
  bool _sodiumAuto = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final fmt = context.appRead.fmt;
    final p = widget.food?.profile;
    String num(double? v) => v == null ? '' : fmt.input(v, 4);
    _name = TextEditingController(text: p?.name ?? widget.initialName ?? '');
    _brand = TextEditingController(text: p?.brand ?? '');
    _barcode = TextEditingController(text: p?.barcode ?? widget.initialBarcode ?? '');
    _serving = TextEditingController(text: num(p?.servingSize));
    _servingLabel = TextEditingController(text: p?.servingLabel ?? '');
    _density = TextEditingController(text: num(p?.densityGPerMl));
    _nutrients = {
      for (final n in Nutrients.all) n.key: TextEditingController(text: num(p?.nutrients[n.key])),
    };
    _basis = p?.basis ?? Basis.g;
    _favorite = widget.food?.favorite ?? false;
  }

  @override
  void dispose() {
    for (final c in [_name, _brand, _barcode, _serving, _servingLabel, _density, ..._nutrients.values]) {
      c.dispose();
    }
    super.dispose();
  }

  void _onSaltChanged(String text) {
    _saltAuto = false;
    final salt = Fmt.parseNumber(text);
    final sodium = _nutrients['sodium_mg']!;
    if (sodium.text.trim().isEmpty || _sodiumAuto) {
      sodium.text = salt == null ? '' : context.appRead.fmt.input(salt / Nutrients.saltPerSodium * 1000, 2);
      _sodiumAuto = salt != null;
    }
  }

  void _onSodiumChanged(String text) {
    _sodiumAuto = false;
    final sodium = Fmt.parseNumber(text);
    final salt = _nutrients['salt_g']!;
    if (salt.text.trim().isEmpty || _saltAuto) {
      salt.text = sodium == null ? '' : context.appRead.fmt.input(sodium / 1000 * Nutrients.saltPerSodium, 4);
      _saltAuto = sodium != null;
    }
  }

  FoodProfile _buildProfile() {
    String? text(TextEditingController c) => c.text.trim().isEmpty ? null : c.text.trim();
    final values = <String, double>{};
    for (final n in Nutrients.all) {
      final v = Fmt.parseNumber(_nutrients[n.key]!.text);
      if (v != null) values[n.key] = v;
    }
    final serving = Fmt.parseNumber(_serving.text);
    return FoodProfile(
      source: FoodSource.custom,
      name: _name.text.trim(),
      brand: text(_brand),
      barcode: text(_barcode),
      basis: _basis,
      servingSize: serving,
      servingLabel: serving == null ? null : text(_servingLabel),
      densityGPerMl: Fmt.parseNumber(_density.text),
      nutrients: Nutrients.normalize(values),
    );
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate() || _saving) return;
    final app = context.appRead;
    final s = app.s;
    final profile = _buildProfile();
    final existing = widget.food;
    var updateEntries = false;
    if (existing != null) {
      final used = app.service.entriesUsingFood(existing.id);
      if (used > 0 && !existing.profile.sameNutritionAs(profile)) {
        final answer = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(s.editCustomFood),
            content: Text(s.updateEntriesQuestion(used)),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: Text(s.cancel)),
              TextButton(onPressed: () => Navigator.pop(context, false), child: Text(s.updateEntriesNo)),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: Text(s.updateEntriesYes)),
            ],
          ),
        );
        if (answer == null) return;
        updateEntries = answer;
      }
    }
    setState(() => _saving = true);
    Food? saved;
    final ok = await app.run(() async {
      if (existing == null) {
        saved = await app.service.createCustomFood(profile, favorite: _favorite);
      } else {
        saved = await app.service.saveFood(
          existing.copyWith(profile: profile, favorite: _favorite, updatedAt: app.service.clock.nowUtc()),
          updateEntries: updateEntries,
        );
      }
    });
    if (!mounted) return;
    setState(() => _saving = false);
    if (ok) {
      app.showMessage(s.saved);
      Navigator.of(context).pop(saved);
    }
  }

  Future<void> _delete() async {
    final app = context.appRead;
    final s = app.s;
    final ok = await confirm(
      context,
      title: s.deleteConfirmTitle,
      message: s.deleteFoodQuestion,
      confirmLabel: s.delete,
      destructive: true,
    );
    if (!ok || !mounted) return;
    await app.run(() => app.service.deleteFood(widget.food!.id));
    app.showMessage(s.foodDeleted);
    if (mounted) Navigator.of(context).pop();
  }

  Widget _nutrientField(Nutrient n) {
    final s = context.s;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: NumberField(
        controller: _nutrients[n.key]!,
        label: s.nutrientName(n.key),
        suffix: n.unit,
        min: 0,
        max: n.maxPer100,
        helper: n.key == 'salt_g' ? s.saltSodiumHint : null,
        textInputAction: TextInputAction.next,
        onChanged: switch (n.key) {
          'salt_g' => _onSaltChanged,
          'sodium_mg' => _onSodiumChanged,
          _ => null,
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final s = app.s;
    final groups = [
      (s.groupEnergyMacros, [NutrientGroup.energy, NutrientGroup.macro], true),
      (s.groupDetails, [NutrientGroup.detail], true),
      (s.groupVitamins, [NutrientGroup.vitamin], false),
      (s.groupMinerals, [NutrientGroup.mineral], false),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.food == null ? s.newCustomFood : s.editCustomFood),
        actions: [
          if (widget.food != null)
            IconButton(tooltip: s.delete, icon: const Icon(Icons.delete_outline), onPressed: _delete),
        ],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: pagePadding(context),
          children: [
            TextFormField(
              controller: _name,
              maxLength: 200,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: s.foodName),
              validator: (v) => v == null || v.trim().isEmpty ? s.fieldRequired : null,
            ),
            TextFormField(
              controller: _brand,
              maxLength: 200,
              decoration: InputDecoration(labelText: s.brandOptional),
            ),
            TextFormField(
              controller: _barcode,
              maxLength: 14,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: s.barcodeOptional),
              validator: (v) => v == null || v.trim().isEmpty || RegExp(r'^\d{1,14}$').hasMatch(v.trim())
                  ? null
                  : s.barcodeDigitsOnly,
            ),
            const SizedBox(height: 8),
            Text(s.basisLabel, style: context.text.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<Basis>(
              segments: [
                ButtonSegment(value: Basis.g, label: Text(s.perHundred(Basis.g))),
                ButtonSegment(value: Basis.ml, label: Text(s.perHundred(Basis.ml))),
              ],
              selected: {_basis},
              onSelectionChanged: (v) => setState(() => _basis = v.first),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: NumberField(
                    controller: _serving,
                    label: s.servingSizeOptional,
                    suffix: _basis.json,
                    min: 0,
                    minExclusive: true,
                    max: 100000,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextFormField(
                    controller: _servingLabel,
                    maxLength: 100,
                    decoration: InputDecoration(labelText: s.servingLabelOptional),
                  ),
                ),
              ],
            ),
            NumberField(
              controller: _density,
              label: s.densityOptional,
              suffix: 'g/ml',
              min: 0.05,
              max: 25,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(s.favorite),
              value: _favorite,
              onChanged: (v) => setState(() => _favorite = v),
            ),
            const SizedBox(height: 8),
            Semantics(
              header: true,
              child: Text(s.nutrientsPerHundred(_basis), style: context.text.titleMedium),
            ),
            for (final (title, kinds, expanded) in groups)
              ExpansionTile(
                initiallyExpanded: expanded,
                maintainState: true,
                tilePadding: EdgeInsets.zero,
                title: Text(title, style: context.text.titleSmall?.copyWith(color: context.scheme.primary)),
                children: [
                  for (final n in Nutrients.all.where((n) => kinds.contains(n.group))) _nutrientField(n),
                ],
              ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(s.save),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
