library morphhealth.ui.edit_local_food_page;

import 'package:flutter/material.dart';
import 'package:morphhealth/core/model/food.dart';
import 'package:morphhealth/core/model/nutrients.dart';
import 'package:morphhealth/core/repository.dart';
import 'package:morphhealth/l10n/app_localizations.dart';

class EditLocalFoodPage extends StatefulWidget {
  final HealthRepository repository;
  final LocalFood? food;
  const EditLocalFoodPage({super.key, required this.repository, this.food});

  @override
  State<EditLocalFoodPage> createState() => _EditLocalFoodPageState();
}

class _EditLocalFoodPageState extends State<EditLocalFoodPage> {
  final _name = TextEditingController();
  final _brand = TextEditingController();
  final _serving = TextEditingController();
  final Map<String, TextEditingController> _fields = {};

  NutrientProfile _profile = const NutrientProfile();

  @override
  void initState() {
    super.initState();
    if (widget.food != null) {
      _name.text = widget.food!.name;
      _brand.text = widget.food!.brand ?? '';
      _serving.text = widget.food!.servingSizeGrams != null ? widget.food!.servingSizeGrams!.toStringAsFixed(0) : '';
      _profile = widget.food!.profile;
    }
    _fields['energyKcal'] = _ctrl(_profile.energyKcal);
    _fields['proteinG'] = _ctrl(_profile.proteinG);
    _fields['carbsG'] = _ctrl(_profile.carbsG);
    _fields['fatG'] = _ctrl(_profile.fatG);
    _fields['saturatedFatG'] = _ctrl(_profile.saturatedFatG);
    _fields['sugarG'] = _ctrl(_profile.sugarG);
    _fields['fiberG'] = _ctrl(_profile.fiberG);
    _fields['saltG'] = _ctrl(_profile.saltG);
    _fields['sodiumG'] = _ctrl(_profile.sodiumG);
    _fields['caffeineMg'] = _ctrl(_profile.caffeineMg);
    _fields['vitaminA'] = _ctrl(_profile.vitaminAG);
    _fields['vitaminC'] = _ctrl(_profile.vitaminCG);
    _fields['vitaminD'] = _ctrl(_profile.vitaminDG);
    _fields['vitaminE'] = _ctrl(_profile.vitaminEG);
    _fields['vitaminK'] = _ctrl(_profile.vitaminKG);
    _fields['vitaminB1'] = _ctrl(_profile.vitaminB1G);
    _fields['vitaminB2'] = _ctrl(_profile.vitaminB2G);
    _fields['vitaminB3'] = _ctrl(_profile.vitaminB3G);
    _fields['vitaminB5'] = _ctrl(_profile.vitaminB5G);
    _fields['vitaminB6'] = _ctrl(_profile.vitaminB6G);
    _fields['vitaminB7'] = _ctrl(_profile.vitaminB7G);
    _fields['vitaminB9'] = _ctrl(_profile.vitaminB9G);
    _fields['vitaminB12'] = _ctrl(_profile.vitaminB12G);
    _fields['calcium'] = _ctrl(_profile.calciumMg);
    _fields['iron'] = _ctrl(_profile.ironMg);
    _fields['magnesium'] = _ctrl(_profile.magnesiumMg);
    _fields['potassium'] = _ctrl(_profile.potassiumMg);
    _fields['zinc'] = _ctrl(_profile.zincMg);
    _fields['selenium'] = _ctrl(_profile.seleniumMg);
    _fields['iodine'] = _ctrl(_profile.iodineMg);
    _fields['phosphorus'] = _ctrl(_profile.phosphorusMg);
  }

  TextEditingController _ctrl(double? v) => TextEditingController(text: v != null ? v.toStringAsFixed(2) : '');

  NutrientProfile _readProfile() => NutrientProfile(
        energyKcal: _num('energyKcal'),
        proteinG: _num('proteinG'),
        carbsG: _num('carbsG'),
        fatG: _num('fatG'),
        saturatedFatG: _num('saturatedFatG'),
        sugarG: _num('sugarG'),
        fiberG: _num('fiberG'),
        saltG: _num('saltG'),
        sodiumG: _num('sodiumG'),
        caffeineMg: _num('caffeineMg'),
        vitaminAG: _num('vitaminA'),
        vitaminCG: _num('vitaminC'),
        vitaminDG: _num('vitaminD'),
        vitaminEG: _num('vitaminE'),
        vitaminKG: _num('vitaminK'),
        vitaminB1G: _num('vitaminB1'),
        vitaminB2G: _num('vitaminB2'),
        vitaminB3G: _num('vitaminB3'),
        vitaminB5G: _num('vitaminB5'),
        vitaminB6G: _num('vitaminB6'),
        vitaminB7G: _num('vitaminB7'),
        vitaminB9G: _num('vitaminB9'),
        vitaminB12G: _num('vitaminB12'),
        calciumMg: _num('calcium'),
        ironMg: _num('iron'),
        magnesiumMg: _num('magnesium'),
        potassiumMg: _num('potassium'),
        zincMg: _num('zinc'),
        seleniumMg: _num('selenium'),
        iodineMg: _num('iodine'),
        phosphorusMg: _num('phosphorus'),
      );

  double? _num(String key) {
    final text = _fields[key]!.text.trim();
    if (text.isEmpty) return null;
    return double.tryParse(text);
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(widget.food == null ? l.msg('newLocalFood') : l.msg('editLocalFood'))),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Name', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: _brand, decoration: const InputDecoration(labelText: 'Marke', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: _serving, decoration: const InputDecoration(labelText: 'Portionsgröße (g)', border: OutlineInputBorder()), keyboardType: TextInputType.number),
            const SizedBox(height: 20),
            Text('Makronährstoffe (pro 100 g)', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            _grid([
              _Field('energyKcal', l.msg('kcal'), 'kcal'),
              _Field('proteinG', l.msg('protein'), 'g'),
              _Field('carbsG', l.msg('carbs'), 'g'),
              _Field('fatG', l.msg('fat'), 'g'),
              _Field('saturatedFatG', 'gesättigte Fettsäuren', 'g'),
              _Field('sugarG', 'Zucker', 'g'),
              _Field('fiberG', 'Ballaststoffe', 'g'),
              _Field('saltG', 'Salz', 'g'),
              _Field('sodiumG', 'Natrium', 'g'),
              _Field('caffeineMg', l.msg('caffeine'), 'mg'),
            ], _fields),
            const SizedBox(height: 20),
            Text(l.msg('micronutrients'), style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            _grid([
              _Field('vitaminA', 'Vitamin A', 'µg'),
              _Field('vitaminC', 'Vitamin C', 'µg'),
              _Field('vitaminD', 'Vitamin D', 'µg'),
              _Field('vitaminE', 'Vitamin E', 'µg'),
              _Field('vitaminK', 'Vitamin K', 'µg'),
              _Field('vitaminB1', 'Vitamin B1', 'µg'),
              _Field('vitaminB2', 'Vitamin B2', 'µg'),
              _Field('vitaminB3', 'Vitamin B3', 'µg'),
              _Field('vitaminB5', 'Vitamin B5', 'µg'),
              _Field('vitaminB6', 'Vitamin B6', 'µg'),
              _Field('vitaminB7', 'Vitamin B7', 'µg'),
              _Field('vitaminB9', 'Vitamin B9', 'µg'),
              _Field('vitaminB12', 'Vitamin B12', 'µg'),
              _Field('calcium', 'Kalzium', 'mg'),
              _Field('iron', 'Eisen', 'mg'),
              _Field('magnesium', 'Magnesium', 'mg'),
              _Field('potassium', 'Kalium', 'mg'),
              _Field('zinc', 'Zink', 'mg'),
              _Field('selenium', 'Selen', 'mg'),
              _Field('iodine', 'Jod', 'mg'),
              _Field('phosphorus', 'Phosphor', 'mg'),
            ], _fields),
            const SizedBox(height: 24),
            FilledButton(onPressed: _save, child: Text(l.msg('save'))),
          ],
        ),
      ),
    );
  }

  Widget _grid(List<_Field> fields, Map<String, TextEditingController> controllers) {
    final children = <Widget>[];
    for (var i = 0; i < fields.length; i += 2) {
      children.add(Row(
        children: [
          Expanded(child: fields[i].build(context, controllers)),
          if (i + 1 < fields.length) ...[const SizedBox(width: 8), Expanded(child: fields[i + 1].build(context, controllers))],
        ],
      ));
      children.add(const SizedBox(height: 8));
    }
    return Column(children: children);
  }

  void _save() {
    if (_name.text.trim().isEmpty) return;
    final serving = double.tryParse(_serving.text.trim());
    final food = LocalFood(
      id: widget.food?.id ?? '',
      name: _name.text.trim(),
      brand: _brand.text.trim().isEmpty ? null : _brand.text.trim(),
      profile: _readProfile(),
      servingSizeGrams: serving,
    );
    if (widget.food == null) {
      widget.repository.addLocalFood(food);
    } else {
      widget.repository.updateLocalFood(widget.food!.id, food);
    }
    Navigator.of(context).pop(true);
  }
}

class _Field {
  final String key;
  final String label;
  final String unit;
  _Field(this.key, this.label, this.unit);

  Widget build(BuildContext context, Map<String, TextEditingController> fields) =>
      TextField(
        controller: fields[key],
        decoration: InputDecoration(
          labelText: '$label ($unit)',
          isDense: true,
          border: const OutlineInputBorder(),
        ),
        keyboardType: TextInputType.numberWithOptions(decimal: true),
      );
}