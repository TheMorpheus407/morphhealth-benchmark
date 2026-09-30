import 'dart:convert';
import 'package:flutter/material.dart';
import '../core/model.dart';
import '../core/nutrients.dart';
import 'common.dart';
import 'controller.dart';

Future<void> editRecord(
  BuildContext context,
  String table, {
  Json? record,
  String? day,
}) => Navigator.of(context).push(
  MaterialPageRoute(
    builder: (_) => RecordEditor(
      table: table,
      record: record,
      day: day ?? AppScope.of(context).selectedDay,
    ),
  ),
);
Future<void> editFood(BuildContext context, {Json? food}) => Navigator.of(
  context,
).push(MaterialPageRoute(builder: (_) => FoodEditor(food: food)));
Future<void> editConsumption(
  BuildContext context,
  Json food, {
  Json? record,
  bool repeat = false,
  String meal = 'snack',
}) => Navigator.of(context).push(
  MaterialPageRoute(
    builder: (_) => ConsumptionEditor(
      food: food,
      record: record,
      repeat: repeat,
      initialMeal: meal,
    ),
  ),
);

class RecordEditor extends StatefulWidget {
  final String table, day;
  final Json? record;
  const RecordEditor({
    super.key,
    required this.table,
    required this.day,
    this.record,
  });
  @override
  State<RecordEditor> createState() => _RecordEditorState();
}

class _RecordEditorState extends State<RecordEditor> {
  final _form = GlobalKey<FormState>();
  late String day, end, strength, unit;
  late bool ongoing;
  late TimeOfDay time;
  late TextEditingController name, amount, note;
  double intensity = 0;
  bool busy = false;
  String? error;
  bool initialized = false;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (initialized) return;
    initialized = true;
    final c = AppScope.of(context), r = widget.record;
    day =
        r?['date'] ??
        r?['start'] ??
        (r?['at'] as String?)?.substring(0, 10) ??
        widget.day;
    end = r?['end'] ?? day;
    ongoing = widget.table == 'periods' && (r == null || r['end'] == null);
    time = parseTime(r?['at']);
    strength = r?['strength'] ?? 'medium';
    unit = c.pounds ? 'lb' : 'kg';
    final value = widget.table == 'weights'
        ? (number(r?['kg']) == null
              ? null
              : number(r?['kg'])! / (c.pounds ? 0.45359237 : 1))
        : number(r?['amount']);
    amount = TextEditingController(text: value == null ? '' : c.input(value));
    name = TextEditingController(text: r?['name'] ?? '');
    note = TextEditingController(text: r?['note'] ?? '');
    intensity = number(r?['intensity']) ?? 0;
  }

  @override
  void dispose() {
    name.dispose();
    amount.dispose();
    note.dispose();
    super.dispose();
  }

  Future<void> save() async {
    if (!_form.currentState!.validate()) return;
    final c = AppScope.of(context), t = widget.table;
    setState(() {
      busy = true;
      error = null;
    });
    final r = <String, dynamic>{
      'id': widget.record?['id'] ?? newId(),
      'note': note.text.trim(),
    };
    if (t == 'weights') {
      r.addAll({
        'date': day,
        'kg': number(amount.text)! * (unit == 'lb' ? 0.45359237 : 1),
      });
    }
    if (t == 'symptoms') {
      r.addAll({
        'at': atTime(day, time),
        'name': name.text.trim(),
        'intensity': intensity.round(),
      });
    }
    if (t == 'periods') {
      r.addAll({
        'start': day,
        'end': ongoing ? null : end,
        'strength': strength,
      });
    }
    if (t == 'bleeding') {
      r.addAll({'date': day, 'strength': strength});
    }
    if (t == 'drinks') {
      r.addAll({
        'at': atTime(day, time),
        'kind': widget.record?['kind'] ?? 'water',
        'amount': number(amount.text)!,
      });
    }
    try {
      await c.upsert(t, r);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          error = c.error(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context), t = widget.table;
    final water = widget.record?['kind'] != 'caffeine';
    final title = switch (t) {
      'weights' => c.tr('Gewicht', 'Weight'),
      'symptoms' => c.tr('Symptom', 'Symptom'),
      'periods' => c.tr('Periode', 'Period'),
      'bleeding' => c.tr('Blutung am Tag', 'Daily bleeding'),
      _ => water ? c.tr('Wasser', 'Water') : c.tr('Koffein', 'Caffeine'),
    };
    return FormFrame(
      title: title,
      busy: busy,
      save: save,
      error: error,
      delete:
          widget.record == null ||
              !c.data[t].any((r) => r['id'] == widget.record!['id'])
          ? null
          : () async {
              final before = c.data[t].length;
              await deleteRecord(context, t, widget.record!['id']);
              if (context.mounted && c.data[t].length < before) {
                Navigator.pop(context);
              }
            },
      children: [
        Form(
          key: _form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DateField(
                label: t == 'periods'
                    ? c.tr('Beginn', 'Start')
                    : c.tr('Datum', 'Date'),
                value: day,
                onChanged: (v) => setState(() => day = v),
              ),
              if (t == 'symptoms' || t == 'drinks')
                TimeField(
                  value: time,
                  onChanged: (v) => setState(() => time = v),
                ),
              if (t == 'periods') ...[
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(c.tr('Periode läuft noch', 'Period is ongoing')),
                  value: ongoing,
                  onChanged: (v) => setState(() => ongoing = v),
                ),
                if (!ongoing)
                  DateField(
                    label: c.tr('Ende (einschließlich)', 'End (inclusive)'),
                    value: end,
                    onChanged: (v) => setState(() => end = v),
                  ),
              ],
              if (t == 'periods' || t == 'bleeding')
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: DropdownButtonFormField<String>(
                    initialValue: strength,
                    decoration: InputDecoration(
                      labelText: c.tr('Blutungsstärke', 'Flow'),
                    ),
                    items:
                        [
                              if (t == 'bleeding') 'none',
                              'spotting',
                              'light',
                              'medium',
                              'heavy',
                            ]
                            .map(
                              (s) => DropdownMenuItem(
                                value: s,
                                child: Text(c.strength(s)),
                              ),
                            )
                            .toList(),
                    onChanged: (v) => setState(() => strength = v!),
                  ),
                ),
              if (t == 'weights' || t == 'drinks') ...[
                TextFormField(
                  key: const ValueKey('amount-input'),
                  controller: amount,
                  decoration: InputDecoration(
                    labelText: c.tr('Menge', 'Amount'),
                    suffixText: t == 'weights'
                        ? unit
                        : water
                        ? 'ml'
                        : 'mg',
                  ),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  validator: (v) => numericValidation(v, c),
                ),
                const SizedBox(height: 16),
                if (t == 'weights')
                  DropdownButtonFormField<String>(
                    initialValue: unit,
                    decoration: InputDecoration(
                      labelText: c.tr('Einheit', 'Unit'),
                    ),
                    items: ['kg', 'lb']
                        .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                        .toList(),
                    onChanged: (v) {
                      final old = number(amount.text);
                      if (old != null) {
                        amount.text = c.fmt(
                          old * (v == 'lb' ? 1 / .45359237 : .45359237),
                          digits: 2,
                        );
                      }
                      setState(() => unit = v!);
                    },
                  ),
              ],
              if (t == 'symptoms') ...[
                TextFormField(
                  key: const ValueKey('symptom-name'),
                  controller: name,
                  maxLength: 200,
                  decoration: InputDecoration(
                    labelText: c.tr('Name des Symptoms', 'Symptom name'),
                  ),
                  validator: (v) => requiredValidation(v, c),
                ),
                Wrap(
                  spacing: 8,
                  children: c.data['symptoms']
                      .map((s) => s['name'] as String)
                      .toSet()
                      .take(8)
                      .map(
                        (n) => ActionChip(
                          label: Text(n),
                          onPressed: () => setState(() => name.text = n),
                        ),
                      )
                      .toList(),
                ),
                const SizedBox(height: 14),
                Text(
                  '${c.tr('Intensität', 'Intensity')} · ${intensity.round()} / 10',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                Slider(
                  value: intensity,
                  min: 0,
                  max: 10,
                  divisions: 10,
                  label: intensity.round().toString(),
                  onChanged: (v) => setState(() => intensity = v),
                ),
              ],
              const SizedBox(height: 18),
              TextFormField(
                controller: note,
                maxLength: 10000,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: c.tr('Notiz (optional)', 'Note (optional)'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class FoodEditor extends StatefulWidget {
  final Json? food;
  const FoodEditor({super.key, this.food});
  @override
  State<FoodEditor> createState() => _FoodEditorState();
}

class _FoodEditorState extends State<FoodEditor> {
  final form = GlobalKey<FormState>();
  late TextEditingController name, brand, serving, density;
  final values = <String, TextEditingController>{};
  String base = 'g';
  bool busy = false, initialized = false, favorite = false;
  String? error;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (initialized) return;
    initialized = true;
    final c = AppScope.of(context), f = widget.food;
    name = TextEditingController(text: f?['name'] ?? '');
    brand = TextEditingController(text: f?['brand'] ?? '');
    serving = TextEditingController(
      text: number(f?['serving_size']) == null
          ? ''
          : c.input(f!['serving_size']),
    );
    density = TextEditingController(
      text: number(f?['grams_per_ml']) == null
          ? ''
          : c.input(f!['grams_per_ml']),
    );
    base = f?['base_unit'] ?? 'g';
    favorite = f?['favorite'] ?? false;
    for (final n in nutrients) {
      values[n.id] = TextEditingController(
        text: number(f?['nutrients']?[n.id]) == null
            ? ''
            : c.input(f!['nutrients'][n.id]),
      );
    }
  }

  @override
  void dispose() {
    name.dispose();
    brand.dispose();
    serving.dispose();
    density.dispose();
    for (final v in values.values) {
      v.dispose();
    }
    super.dispose();
  }

  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    final c = AppScope.of(context);
    setState(() {
      busy = true;
      error = null;
    });
    final f = <String, dynamic>{
      'id': widget.food?['id'] ?? newId(),
      'name': name.text.trim(),
      'name_en': widget.food?['name_en'],
      'barcode': widget.food?['barcode'],
      'brand': brand.text.trim(),
      'source': 'custom',
      'base_unit': base,
      'serving_size': number(serving.text.trim()),
      'grams_per_ml': number(density.text.trim()),
      'favorite': favorite,
      'nutrients': {
        for (final n in nutrients) n.id: number(values[n.id]!.text.trim()),
      },
      'estimated': <String>[],
    };
    try {
      await c.upsert('foods', f);
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          error = c.error(e);
        });
      }
    }
  }

  Widget numeric(String id, String title, {String? unit}) {
    final c = AppScope.of(context);
    final controller = id == 'serving'
        ? serving
        : id == 'density'
        ? density
        : values[id]!;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: TextFormField(
        key: ValueKey('food-$id'),
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: title, suffixText: unit),
        validator: (v) => numericValidation(
          v,
          c,
          optional: true,
          zero: id != 'serving' && id != 'density',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    return FormFrame(
      title: c.tr('Eigenes Lebensmittel', 'Custom food'),
      busy: busy,
      save: save,
      error: error,
      delete: widget.food == null
          ? null
          : () async {
              final before = c.data['foods'].length;
              await deleteRecord(context, 'foods', widget.food!['id']);
              if (context.mounted && c.data['foods'].length < before) {
                Navigator.pop(context);
              }
            },
      children: [
        Form(
          key: form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                key: const ValueKey('food-name'),
                controller: name,
                maxLength: 1000,
                decoration: InputDecoration(labelText: c.tr('Name', 'Name')),
                validator: (v) => requiredValidation(v, c),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: brand,
                decoration: InputDecoration(
                  labelText: c.tr('Marke (optional)', 'Brand (optional)'),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: base,
                decoration: InputDecoration(
                  labelText: c.tr('Nährwerte pro', 'Nutrition per'),
                ),
                items: ['g', 'ml']
                    .map(
                      (u) => DropdownMenuItem(value: u, child: Text('100 $u')),
                    )
                    .toList(),
                onChanged: (v) => setState(() => base = v!),
              ),
              const SizedBox(height: 18),
              numeric(
                'serving',
                c.tr(
                  'Größe einer Portion (optional)',
                  'Serving size (optional)',
                ),
                unit: base,
              ),
              numeric(
                'density',
                c.tr(
                  'Dichte (optional, für g ↔ ml)',
                  'Density (optional, for g ↔ ml)',
                ),
                unit: 'g/ml',
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(c.tr('Favorit', 'Favourite')),
                value: favorite,
                onChanged: (v) => setState(() => favorite = v),
              ),
              const SizedBox(height: 16),
              Text(
                c.tr('Nährwerte je 100 ', 'Nutrients per 100 ') + base,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  c.tr(
                    'Leere Felder bleiben unbekannt. Trage 0 ein, wenn ein Wert tatsächlich null ist.',
                    'Empty fields stay unknown. Enter 0 when a value is actually zero.',
                  ),
                ),
              ),
              for (final n in nutrients.take(10))
                numeric(n.id, n.name(c.language), unit: n.unit),
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(
                  c.tr(
                    'Alle Vitamine und Mineralstoffe',
                    'All vitamins and minerals',
                  ),
                ),
                children: [
                  for (final n in nutrients.skip(10))
                    numeric(n.id, n.name(c.language), unit: n.unit),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class ConsumptionEditor extends StatefulWidget {
  final Json food;
  final Json? record;
  final bool repeat;
  final String initialMeal;
  const ConsumptionEditor({
    super.key,
    required this.food,
    this.record,
    this.repeat = false,
    this.initialMeal = 'snack',
  });
  @override
  State<ConsumptionEditor> createState() => _ConsumptionEditorState();
}

class _ConsumptionEditorState extends State<ConsumptionEditor> {
  final form = GlobalKey<FormState>();
  late Json food;
  late TextEditingController amount, note, serving, density;
  late String day, unit, meal;
  late TimeOfDay time;
  bool initialized = false, busy = false;
  String? error;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (initialized) return;
    initialized = true;
    final c = AppScope.of(context), r = widget.record;
    food = jsonDecode(jsonEncode(widget.food));
    day = widget.repeat
        ? c.selectedDay
        : (r?['at'] as String?)?.substring(0, 10) ?? c.selectedDay;
    time = widget.repeat ? TimeOfDay.now() : parseTime(r?['at']);
    unit = r?['unit'] ?? food['base_unit'];
    meal = r?['meal'] ?? widget.initialMeal;
    amount = TextEditingController(text: c.input(r?['amount'] ?? 100));
    note = TextEditingController(text: widget.repeat ? '' : r?['note'] ?? '');
    serving = TextEditingController(
      text: number(food['serving_size']) == null
          ? ''
          : c.input(food['serving_size']),
    );
    density = TextEditingController(
      text: number(food['grams_per_ml']) == null
          ? ''
          : c.input(food['grams_per_ml']),
    );
    amount.addListener(() => setState(() {}));
    serving.addListener(() => setState(() {}));
    density.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    amount.dispose();
    note.dispose();
    serving.dispose();
    density.dispose();
    super.dispose();
  }

  Json workingFood() => {
    ...food,
    'serving_size': number(serving.text.trim()),
    'grams_per_ml': number(density.text.trim()),
  };
  Future<void> save() async {
    if (!form.currentState!.validate()) return;
    final c = AppScope.of(context), f = workingFood();
    setState(() {
      busy = true;
      error = null;
    });
    final r = <String, dynamic>{
      'id': widget.repeat ? newId() : widget.record?['id'] ?? newId(),
      'food_id': f['id'],
      'food': f,
      'at': atTime(day, time),
      'amount': number(amount.text)!,
      'unit': unit,
      'meal': meal,
      'note': note.text.trim(),
    };
    try {
      await c.change((d) {
        final i = d['consumption'].indexWhere((v) => v['id'] == r['id']);
        if (i < 0) {
          d['consumption'].add(r);
        } else {
          d['consumption'][i] = r;
        }
        if (!d['foods'].any((v) => v['id'] == f['id'])) d['foods'].add(f);
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(() {
          busy = false;
          error = c.error(e);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    Json? preview;
    try {
      if (number(amount.text) != null && number(amount.text)! > 0) {
        preview = scaledNutrients(workingFood(), number(amount.text)!, unit);
      }
    } catch (_) {}
    return FormFrame(
      title: widget.repeat
          ? c.tr('Erneut erfassen', 'Log again')
          : c.tr('Verzehr', 'Food entry'),
      busy: busy,
      save: save,
      error: error,
      delete: widget.record == null || widget.repeat
          ? null
          : () async {
              final before = c.data['consumption'].length;
              await deleteRecord(context, 'consumption', widget.record!['id']);
              if (context.mounted && c.data['consumption'].length < before) {
                Navigator.pop(context);
              }
            },
      children: [
        Heading(
          c.foodName(food),
          subtitle:
              food['brand'] ??
              (food['source'] == 'off'
                  ? 'Open Food Facts'
                  : c.tr('Eigenes Lebensmittel', 'Custom food')),
        ),
        Form(
          key: form,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              DateField(
                label: c.tr('Datum', 'Date'),
                value: day,
                onChanged: (v) => setState(() => day = v),
              ),
              TimeField(
                value: time,
                onChanged: (v) => setState(() => time = v),
              ),
              TextFormField(
                key: const ValueKey('consumption-amount'),
                controller: amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(labelText: c.tr('Menge', 'Amount')),
                validator: (v) => numericValidation(v, c),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: unit,
                decoration: InputDecoration(labelText: c.tr('Einheit', 'Unit')),
                items: ['g', 'ml', 'portion']
                    .map(
                      (u) => DropdownMenuItem(value: u, child: Text(c.unit(u))),
                    )
                    .toList(),
                onChanged: (v) => setState(() => unit = v!),
              ),
              const SizedBox(height: 16),
              if (unit == 'portion') ...[
                TextFormField(
                  controller: serving,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: c.tr(
                      'Eine Portion entspricht',
                      'One serving equals',
                    ),
                    suffixText: food['base_unit'],
                  ),
                  validator: (v) => numericValidation(v, c),
                ),
                const SizedBox(height: 16),
              ],
              if (unit != 'portion' && unit != food['base_unit']) ...[
                TextFormField(
                  controller: density,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: c.tr(
                      'Dichte für die Umrechnung',
                      'Density for conversion',
                    ),
                    suffixText: 'g/ml',
                  ),
                  validator: (v) => numericValidation(v, c),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  child: Text(
                    c.tr(
                          'Die Nährwerte sind pro 100 ',
                          'Nutrition is per 100 ',
                        ) +
                        food['base_unit'] +
                        c.tr(
                          ' angegeben. Die Dichte bestimmst du selbst.',
                          '; supply the density yourself.',
                        ),
                  ),
                ),
              ],
              DropdownButtonFormField<String>(
                initialValue: meal,
                decoration: InputDecoration(
                  labelText: c.tr('Mahlzeit', 'Meal'),
                ),
                items: ['breakfast', 'lunch', 'dinner', 'snack']
                    .map(
                      (m) => DropdownMenuItem(value: m, child: Text(c.meal(m))),
                    )
                    .toList(),
                onChanged: (v) => setState(() => meal = v!),
              ),
              const SizedBox(height: 16),
              if (preview != null)
                Panel(
                  color: sage,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${c.fmt(preview['calories'])} kcal',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${c.tr('Protein', 'Protein')} ${c.fmt(preview['protein'])} g · ${c.tr('Kohlenhydrate', 'Carbs')} ${c.fmt(preview['carbs'])} g · ${c.tr('Fett', 'Fat')} ${c.fmt(preview['fat'])} g',
                      ),
                      ExpansionTile(
                        tilePadding: EdgeInsets.zero,
                        title: Text(
                          c.tr(
                            'Alle Nährwerte für diese Menge',
                            'All nutrients for this amount',
                          ),
                        ),
                        children: [NutrientTable(values: preview)],
                      ),
                    ],
                  ),
                ),
              if ((food['estimated'] as List?)?.isNotEmpty == true)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: Text(
                    c.tr(
                      'Open Food Facts enthält auch geschätzte oder mit Vergleichszeichen angegebene Werte.',
                      'Open Food Facts includes estimated or qualified values.',
                    ),
                  ),
                ),
              TextFormField(
                controller: note,
                maxLines: 2,
                maxLength: 10000,
                decoration: InputDecoration(
                  labelText: c.tr('Notiz (optional)', 'Note (optional)'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
