import 'package:flutter/material.dart';

import '../../core/db.dart';
import '../../core/ids.dart';
import '../../core/models.dart';
import '../../core/nutrients.dart';
import '../../state/app_state.dart';
import '../format.dart';
import '../l10n_x.dart';
import '../widgets/common.dart';
import '../widgets/fields.dart';

/// Natrium (mg) je g Salz.
const double kSodiumMgPerSaltG = 400;

/// Eigenes Lebensmittel anlegen oder bearbeiten. Liefert das gespeicherte
/// [Food] zurück.
class CustomFoodScreen extends StatefulWidget {
  /// Bestehendes Lebensmittel (Bearbeiten).
  final Food? existing;

  /// Vorlage für ein neues Lebensmittel (zum Beispiel eine Kopie aus Open Food Facts).
  final FoodInfo? initial;

  const CustomFoodScreen({super.key, this.existing, this.initial});

  @override
  State<CustomFoodScreen> createState() => _CustomFoodScreenState();
}

class _CustomFoodScreenState extends State<CustomFoodScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _brand;
  late final TextEditingController _barcode;
  late final TextEditingController _servingAmount;
  late final TextEditingController _servingLabel;
  final Map<String, TextEditingController> _n = {for (final d in nutrientCatalog) d.key: TextEditingController()};
  late Basis _basis;
  late bool _favorite;
  bool _initialized = false;

  /// Der Aufklappzustand bleibt hier erhalten, auch wenn die Liste ihn beim
  /// Wegscrollen verwirft.
  late bool _vitaminsOpen;
  late bool _mineralsOpen;

  FoodInfo? get _seed => widget.existing?.info ?? widget.initial;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final app = AppScope.read(context);
    final f = Fmt(app.lang);
    final s = _seed;
    _name = TextEditingController(text: s == null ? '' : (s.name == s.barcode ? '' : s.name));
    _brand = TextEditingController(text: s?.brand ?? '');
    _barcode = TextEditingController(text: s?.barcode ?? '');
    _servingAmount = TextEditingController(text: s?.serving == null ? '' : f.input(s!.serving!.amount, 3));
    _servingLabel = TextEditingController(text: s?.serving?.label ?? '');
    _basis = s?.basis ?? Basis.g;
    _favorite = widget.existing?.favorite ?? false;
    if (s != null) {
      for (final d in nutrientCatalog) {
        final v = s.nutrients[d.key];
        if (v != null) _n[d.key]!.text = f.input(v, 4);
      }
    }
    _vitaminsOpen = _anyIn(NutrientGroup.vitamin);
    _mineralsOpen = _anyIn(NutrientGroup.mineral);
  }

  @override
  void dispose() {
    for (final c in [_name, _brand, _barcode, _servingAmount, _servingLabel, ..._n.values]) {
      c.dispose();
    }
    super.dispose();
  }

  bool _anyIn(NutrientGroup g) => nutrientsOfGroup(g).any((d) => _n[d.key]!.text.trim().isNotEmpty);

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final app = AppScope.read(context);
    final l = context.l10n;
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final values = <String, double>{};
    for (final d in nutrientCatalog) {
      final v = Fmt.parse(_n[d.key]!.text);
      if (v != null) values[d.key] = v;
    }
    // Salz und Natrium ineinander umrechnen, wenn nur eines angegeben ist.
    if (values.containsKey('salt_g') && !values.containsKey('sodium_mg')) {
      values['sodium_mg'] = values['salt_g']! * kSodiumMgPerSaltG;
    } else if (values.containsKey('sodium_mg') && !values.containsKey('salt_g')) {
      values['salt_g'] = values['sodium_mg']! / kSodiumMgPerSaltG;
    }
    final sa = Fmt.parse(_servingAmount.text);
    final info = FoodInfo(
      name: _name.text.trim(),
      brand: _brand.text.trim().isEmpty ? null : _brand.text.trim(),
      barcode: _barcode.text.trim().isEmpty ? null : _barcode.text.trim(),
      source: FoodSource.custom,
      basis: _basis,
      serving: sa != null && sa > 0
          ? Serving(sa, _servingLabel.text.trim().isEmpty ? null : _servingLabel.text.trim())
          : null,
      nutrients: Nutrients.of(values),
    );
    try {
      final e = widget.existing;
      final food = e == null
          ? Food(id: newId(), info: info, favorite: _favorite, createdAt: app.core.clock.nowLocal())
          : e.copyWith(info: info, favorite: _favorite);
      await app.db.saveFood(food);
      nav.pop(food);
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(content: Text(l.customSaved(info.name))));
    } on DomainException catch (e) {
      if (mounted) showMessage(context, domainErrorText(l, e));
    }
  }

  Future<void> _delete() async {
    final app = AppScope.read(context);
    final l = context.l10n;
    final nav = Navigator.of(context);
    final e = widget.existing!;
    final ok = await confirmDialog(
      context,
      title: l.foodDeleteLibraryTitle,
      message: l.foodDeleteLibraryMessage(e.info.name),
      confirmLabel: l.commonDelete,
      destructive: true,
    );
    if (!ok) return;
    await app.db.deleteFood(e.id);
    nav.pop();
  }

  Widget _field(NutrientDef d) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: NumberField(
      controller: _n[d.key]!,
      label: '${nutrientName(d.key, Localizations.localeOf(context).languageCode)} (${d.unit})',
      max: kMaxNutrientValue,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final editing = widget.existing != null;
    final unit = l.basisUnit(_basis);
    return AppScaffold(
      appBar: AppBar(
        title: Text(editing ? l.customTitleEdit : l.customTitleNew),
        actions: [
          IconButton(
            tooltip: l.customFavorite,
            isSelected: _favorite,
            icon: const Icon(Icons.star_border),
            selectedIcon: Icon(Icons.star, color: context.colors.tertiary),
            onPressed: () => setState(() => _favorite = !_favorite),
          ),
        ],
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            TextFormField(
              controller: _name,
              maxLength: 200,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: l.customName, counterText: ''),
              validator: (v) => (v ?? '').trim().isEmpty ? l.commonRequired : null,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _brand,
              maxLength: 200,
              textCapitalization: TextCapitalization.words,
              decoration: InputDecoration(labelText: l.customBrand, counterText: ''),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _barcode,
              keyboardType: TextInputType.number,
              maxLength: 32,
              decoration: InputDecoration(labelText: l.customBarcode, counterText: ''),
            ),
            const SizedBox(height: 16),
            Text(l.customBasis, style: context.text.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<Basis>(
              showSelectedIcon: false,
              segments: [
                ButtonSegment(value: Basis.g, label: Text(l.customPer100g)),
                ButtonSegment(value: Basis.ml, label: Text(l.customPer100ml)),
              ],
              selected: {_basis},
              onSelectionChanged: (s) => setState(() => _basis = s.first),
            ),
            const SizedBox(height: 16),
            Text(l.customServing, style: context.text.titleSmall),
            const SizedBox(height: 8),
            ControlGroup(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 2,
                    child: NumberField(
                      controller: _servingAmount,
                      label: l.entryAmount,
                      suffix: unit,
                      positive: true,
                      max: 100000,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 3,
                    child: TextFormField(
                      controller: _servingLabel,
                      maxLength: 100,
                      decoration: InputDecoration(labelText: l.customServingLabel, counterText: ''),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Semantics(header: true, child: Text(l.customSectionMain(unit), style: context.text.titleMedium)),
            const SizedBox(height: 12),
            for (final k in [kEnergy, kProtein, kCarbs, kFat]) _field(nutrientByKey[k]!),
            Semantics(header: true, child: Text(l.customSectionMore, style: context.text.titleMedium)),
            const SizedBox(height: 12),
            for (final d in nutrientsOfGroup(NutrientGroup.detail)) _field(d),
            EmptyHint(l.customSaltSodium, icon: Icons.info_outline),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              initiallyExpanded: _vitaminsOpen,
              onExpansionChanged: (v) => setState(() => _vitaminsOpen = v),
              title: Text(l.customSectionVitamins, style: context.text.titleMedium),
              childrenPadding: const EdgeInsets.only(top: 8),
              children: [for (final d in nutrientsOfGroup(NutrientGroup.vitamin)) _field(d)],
            ),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              initiallyExpanded: _mineralsOpen,
              onExpansionChanged: (v) => setState(() => _mineralsOpen = v),
              title: Text(l.customSectionMinerals, style: context.text.titleMedium),
              childrenPadding: const EdgeInsets.only(top: 8),
              children: [for (final d in nutrientsOfGroup(NutrientGroup.mineral)) _field(d)],
            ),
            if (editing) EmptyHint(l.customNoteEntries, icon: Icons.info_outline),
            const SizedBox(height: 16),
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              onPressed: _save,
              icon: const Icon(Icons.check),
              label: Text(l.commonSave),
            ),
            if (editing) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: context.colors.error,
                  minimumSize: const Size.fromHeight(48),
                ),
                onPressed: _delete,
                icon: const Icon(Icons.delete_outline),
                label: Text(l.commonDelete),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
