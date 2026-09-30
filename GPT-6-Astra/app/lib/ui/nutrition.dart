import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/core.dart';
import 'shared.dart';

const _mealKeys = ['breakfast', 'lunch', 'dinner', 'snack'];

String _mealName(AppModel model, String key) => switch (key) {
  'breakfast' => model.tr('Frühstück', 'Breakfast'),
  'lunch' => model.tr('Mittagessen', 'Lunch'),
  'dinner' => model.tr('Abendessen', 'Dinner'),
  _ => model.tr('Snack', 'Snack'),
};

String _unitLabel(AppModel model, String unit) =>
    unit == 'serving' ? model.tr('Portionen', 'Servings') : unit;

List<Json> _items(AppModel model, String collection) =>
    (model.doc[collection] as List).map((e) => Json.from(e as Map)).toList();

Json _object(dynamic value) =>
    value is Map ? Json.from(value) : <String, dynamic>{};

double? _readNumber(String value) =>
    double.tryParse(value.trim().replaceAll(',', '.'));

DateTime _entryTime(AppModel model) {
  final now = DateTime.now();
  final day = model.selectedDate;
  return DateTime(day.year, day.month, day.day, now.hour, now.minute);
}

DateTime _civilTime(String timestamp) =>
    DateTime.parse(timestamp.substring(0, 19));

String _timeText(DateTime date) =>
    '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

String _inputValue(dynamic value) {
  final n = numeric(value);
  if (n == null) return '';
  return n == n.roundToDouble() ? n.toInt().toString() : n.toString();
}

Json _foodTotals(Json food, double amount, String unit) {
  final serving = numeric(food['servingSize']);
  if (amount < 0 ||
      !amount.isFinite ||
      (unit == 'serving' && (serving == null || serving <= 0))) {
    return {for (final nutrient in nutrients) nutrient.key: null};
  }
  return mealTotals({'food': food, 'amount': amount, 'unit': unit});
}

class NutritionPage extends StatelessWidget {
  const NutritionPage({super.key, required this.model});
  final AppModel model;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: model,
    builder: (context, _) {
      final day = dateKey(model.selectedDate);
      final result = nutritionDay(model.doc, day);
      final totals = _object(result['totals']);
      final goals = _object(model.settings['goals']);
      final meals = (result['entries'] as List)
          .map((e) => Json.from(e as Map))
          .toList();
      meals.sort((a, b) => '${a['at']}'.compareTo('${b['at']}'));
      final drinks =
          _items(
              model,
              'drinks',
            ).where((e) => '${e['at']}'.startsWith(day)).toList()
            ..sort((a, b) => '${a['at']}'.compareTo('${b['at']}'));
      return ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 100),
        children: [
          Text(
            model.tr('Dein Ernährungstag', 'Your food diary'),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 6),
          Text(
            model.tr(
              'Was dir heute gut tut.',
              'Make room for what nourishes you.',
            ),
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 18),
          dateBar(context, model),
          const SizedBox(height: 18),
          Panel(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        model.tr('Tagesbilanz', 'Daily nutrition'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _showNutrients(
                        context,
                        model,
                        totals,
                        title: model.tr('Nährstoffe am Tag', 'Daily nutrients'),
                        subtitle: displayDate(model.selectedDate, model.de),
                        knownCounts: _object(result['knownCounts']),
                        entryCount: meals.length,
                        extraCaffeineMg: numeric(result['extraCaffeineMg']),
                      ),
                      icon: const Icon(Icons.list_alt, size: 18),
                      label: Text(model.tr('Alle', 'All')),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '${fmt(numeric(totals['energy']), 0)} kcal',
                  style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (numeric(goals['energy']) != null)
                  _GoalLine(
                    model: model,
                    current: numeric(totals['energy']) ?? 0,
                    goal: numeric(goals['energy'])!,
                    unit: 'kcal',
                  ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 22,
                  runSpacing: 12,
                  children: [
                    for (final key in ['protein', 'carbs', 'fat'])
                      _MacroValue(
                        model: model,
                        nutrientKey: key,
                        value: numeric(totals[key]),
                        goal: numeric(goals[key]),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  model.tr(
                    'Fehlende Angaben bleiben unbekannt. Summen können unvollständig sein.',
                    'Missing values stay unknown. Totals may be incomplete.',
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: () => editMeal(context, model),
            icon: const Icon(Icons.add),
            label: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(model.tr('Lebensmittel erfassen', 'Log food')),
            ),
          ),
          const SizedBox(height: 22),
          SectionTitle(model.tr('Mahlzeiten', 'Meals')),
          if (meals.isEmpty)
            EmptyState(
              icon: Icons.restaurant_outlined,
              title: model.tr(
                'Platz für deinen Tag',
                'A fresh page for your day',
              ),
              message: model.tr(
                'Suche ein Lebensmittel oder lege ein eigenes an.',
                'Find a food or create your own.',
              ),
            ),
          for (final kind in _mealKeys)
            if (meals.any((entry) => entry['meal'] == kind)) ...[
              Padding(
                padding: const EdgeInsets.only(top: 14, bottom: 8),
                child: Text(
                  _mealName(model, kind),
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              Panel(
                child: Column(
                  children: [
                    for (final entry in meals.where((e) => e['meal'] == kind))
                      _MealRow(model: model, entry: entry),
                  ],
                ),
              ),
            ],
          const SizedBox(height: 26),
          SectionTitle(model.tr('Wasser & Koffein', 'Water & caffeine')),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _MetricAction(
                  icon: Icons.water_drop_outlined,
                  content: Text(
                    '${fmt(numeric(result['waterMl']), 0)} ml',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  action: TextButton(
                    onPressed: () => editDrink(context, model),
                    child: Text(model.tr('Eigene Menge', 'Custom amount')),
                  ),
                ),
                if (numeric(goals['water']) != null)
                  _GoalLine(
                    model: model,
                    current: numeric(result['waterMl']) ?? 0,
                    goal: numeric(goals['water'])!,
                    unit: 'ml',
                  ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final amount in [150, 250, 500])
                      ActionChip(
                        avatar: const Icon(Icons.add, size: 18),
                        label: Text('$amount ml'),
                        tooltip: model.tr(
                          '$amount ml Wasser erfassen',
                          'Log $amount ml water',
                        ),
                        onPressed: () => safeAction(context, model, () async {
                          await model.put('drinks', {
                            'id': newId(),
                            'kind': 'water',
                            'amount': amount,
                            'at': _entryTime(model).toIso8601String(),
                            'note': '',
                          });
                        }),
                      ),
                  ],
                ),
                const Divider(height: 30),
                _MetricAction(
                  icon: Icons.coffee_outlined,
                  content: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${fmt(numeric(result['caffeineMg']))} mg',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      Text(
                        model.tr('Erfasstes Koffein', 'Recorded caffeine'),
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                  action: TextButton.icon(
                    onPressed: () =>
                        editDrink(context, model, kind: 'caffeine'),
                    icon: const Icon(Icons.add),
                    label: Text(model.tr('Erfassen', 'Log')),
                  ),
                ),
                const SizedBox(height: 8),
                if ((numeric(_object(result['knownCounts'])['caffeine']) ?? 0) <
                    meals.length)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      model.tr(
                        'Unvollständig: Nicht alle Lebensmittel enthalten eine Koffeinangabe.',
                        'Incomplete: some foods have no caffeine value.',
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                Text(
                  model.tr(
                    'Zusätzlich erfasst: ${fmt(numeric(result['extraCaffeineMg']))} mg. Bekannte Koffeinwerte aus Lebensmitteln sind enthalten.',
                    'Logged separately: ${fmt(numeric(result['extraCaffeineMg']))} mg. Known caffeine values from foods are included.',
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (drinks.isNotEmpty) ...[
            const SizedBox(height: 12),
            Panel(
              child: Column(
                children: [
                  for (final entry in drinks)
                    _DrinkRow(model: model, entry: entry),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          Center(
            child: TextButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) =>
                      FoodPickerPage(model: model, libraryOnly: true),
                ),
              ),
              icon: const Icon(Icons.bookmarks_outlined),
              label: Text(
                model.tr('Meine Lebensmittel verwalten', 'Manage my foods'),
              ),
            ),
          ),
        ],
      );
    },
  );
}

class _MetricAction extends StatelessWidget {
  const _MetricAction({
    required this.icon,
    required this.content,
    required this.action,
  });
  final IconData icon;
  final Widget content;
  final Widget action;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final compact =
          constraints.maxWidth <
          300 * MediaQuery.textScalerOf(context).scale(14) / 14;
      final metric = Row(
        children: [
          Icon(icon),
          const SizedBox(width: 10),
          Expanded(child: content),
          if (!compact) action,
        ],
      );
      return compact
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [metric, const SizedBox(height: 8), action],
            )
          : metric;
    },
  );
}

class _MacroValue extends StatelessWidget {
  const _MacroValue({
    required this.model,
    required this.nutrientKey,
    this.value,
    this.goal,
  });
  final AppModel model;
  final String nutrientKey;
  final double? value;
  final double? goal;
  @override
  Widget build(BuildContext context) {
    final nutrient = nutrients.firstWhere((e) => e.key == nutrientKey);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('${fmt(value)} g', style: Theme.of(context).textTheme.titleLarge),
        Text(
          model.de ? nutrient.de : nutrient.en,
          style: Theme.of(context).textTheme.bodySmall,
        ),
        if (goal != null)
          Text(
            model.tr('Ziel ${fmt(goal)} g', 'Goal ${fmt(goal)} g'),
            style: Theme.of(context).textTheme.labelSmall,
          ),
      ],
    );
  }
}

class _GoalLine extends StatelessWidget {
  const _GoalLine({
    required this.model,
    required this.current,
    required this.goal,
    required this.unit,
  });
  final AppModel model;
  final double current;
  final double goal;
  final String unit;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        LinearProgressIndicator(
          value: goal > 0 ? (current / goal).clamp(0.0, 1.0) : 0,
          minHeight: 5,
          borderRadius: BorderRadius.circular(8),
          semanticsLabel: model.tr(
            'Freiwilliges Tagesziel',
            'Optional daily goal',
          ),
          semanticsValue: '${fmt(current)} / ${fmt(goal)} $unit',
        ),
        const SizedBox(height: 5),
        Text(
          model.tr(
            'Dein Ziel: ${fmt(goal)} $unit',
            'Your goal: ${fmt(goal)} $unit',
          ),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ),
  );
}

class _MealRow extends StatelessWidget {
  const _MealRow({required this.model, required this.entry});
  final AppModel model;
  final Json entry;
  @override
  Widget build(BuildContext context) {
    final food = _object(entry['food']);
    final totals = _object(entry['totals']);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(
        '${food['name']}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${fmt(numeric(entry['amount']))} ${_unitLabel(model, '${entry['unit']}')} · '
        '${_timeText(_civilTime('${entry['at']}'))}\n'
        '${fmt(numeric(totals['energy']), 0)} kcal · '
        '${model.tr('P', 'P')} ${fmt(numeric(totals['protein']))} · '
        '${model.tr('KH', 'C')} ${fmt(numeric(totals['carbs']))} · '
        '${model.tr('F', 'F')} ${fmt(numeric(totals['fat']))} g',
      ),
      isThreeLine: true,
      onTap: () => editMeal(context, model, entry: entry),
      trailing: PopupMenuButton<String>(
        tooltip: model.tr('Eintrag verwalten', 'Manage entry'),
        onSelected: (value) async {
          if (value == 'edit') await editMeal(context, model, entry: entry);
          if (value == 'repeat' && context.mounted) {
            final copy = Json.from(entry)
              ..remove('id')
              ..remove('totals');
            copy['at'] = _entryTime(model).toIso8601String();
            await editMeal(context, model, entry: copy);
          }
          if (value == 'nutrients' && context.mounted) {
            await _showNutrients(
              context,
              model,
              totals,
              title: '${food['name']}',
              subtitle:
                  '${fmt(numeric(entry['amount']))} ${_unitLabel(model, '${entry['unit']}')}',
            );
          }
          if (value == 'delete' &&
              context.mounted &&
              await confirmDelete(context, model) &&
              context.mounted) {
            await safeAction(
              context,
              model,
              () => model.remove('meals', '${entry['id']}'),
            );
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem(
            value: 'edit',
            child: Text(model.tr('Bearbeiten', 'Edit')),
          ),
          PopupMenuItem(
            value: 'repeat',
            child: Text(model.tr('Erneut erfassen', 'Log again')),
          ),
          PopupMenuItem(
            value: 'nutrients',
            child: Text(model.tr('Alle Nährstoffe', 'All nutrients')),
          ),
          PopupMenuItem(
            value: 'delete',
            child: Text(model.tr('Löschen', 'Delete')),
          ),
        ],
      ),
    );
  }
}

class _DrinkRow extends StatelessWidget {
  const _DrinkRow({required this.model, required this.entry});
  final AppModel model;
  final Json entry;
  @override
  Widget build(BuildContext context) {
    final water = entry['kind'] == 'water';
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(water ? Icons.water_drop_outlined : Icons.coffee_outlined),
      title: Text(
        '${model.tr(water ? 'Wasser' : 'Koffein', water ? 'Water' : 'Caffeine')} · '
        '${fmt(numeric(entry['amount']))} ${water ? 'ml' : 'mg'}',
      ),
      subtitle: Text(
        '${_timeText(_civilTime('${entry['at']}'))}'
        '${entry['note'] == '' ? '' : ' · ${entry['note']}'}',
      ),
      onTap: () => editDrink(context, model, entry: entry),
      trailing: IconButton(
        tooltip: model.tr('Eintrag bearbeiten', 'Edit entry'),
        icon: const Icon(Icons.edit_outlined),
        onPressed: () => editDrink(context, model, entry: entry),
      ),
    );
  }
}

Future<void> _showNutrients(
  BuildContext context,
  AppModel model,
  Json values, {
  required String title,
  String? subtitle,
  Json? knownCounts,
  int? entryCount,
  double? extraCaffeineMg,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (context) => SafeArea(
    child: DraggableScrollableSheet(
      expand: false,
      initialChildSize: .78,
      minChildSize: .35,
      maxChildSize: .94,
      builder: (context, scroll) => ListView(
        controller: scroll,
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 30),
        children: [
          Text(title, style: Theme.of(context).textTheme.headlineSmall),
          if (subtitle != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(subtitle),
            ),
          const SizedBox(height: 16),
          Text(
            model.tr(
              '— bedeutet unbekannt. Bekannte Werte werden addiert; fehlende Angaben sind keine Null.',
              '— means unknown. Known values are added; missing values are not zero.',
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          _NutrientTable(
            model: model,
            values: values,
            knownCounts: knownCounts,
            entryCount: entryCount,
            extraCaffeineMg: extraCaffeineMg,
          ),
        ],
      ),
    ),
  ),
);

class _NutrientTable extends StatelessWidget {
  const _NutrientTable({
    required this.model,
    required this.values,
    this.knownCounts,
    this.entryCount,
    this.extraCaffeineMg,
  });
  final AppModel model;
  final Json values;
  final Json? knownCounts;
  final int? entryCount;
  final double? extraCaffeineMg;
  @override
  Widget build(BuildContext context) => Column(
    children: [
      for (final nutrient in nutrients)
        Column(
          key: ValueKey('nutrient-${nutrient.key}'),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 11),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(model.de ? nutrient.de : nutrient.en),
                        if (nutrient.key == 'caffeine' &&
                            extraCaffeineMg != null)
                          Text(
                            model.tr(
                              'Zusätzlich erfasst: ${fmt(extraCaffeineMg)} mg',
                              'Logged separately: ${fmt(extraCaffeineMg)} mg',
                            ),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        if (knownCounts != null &&
                            entryCount != null &&
                            entryCount! > 0 &&
                            (numeric(knownCounts![nutrient.key]) ?? 0) <
                                entryCount!)
                          Text(
                            model.tr(
                              '${knownCounts![nutrient.key] ?? 0} von $entryCount Lebensmitteln bekannt',
                              'Known for ${knownCounts![nutrient.key] ?? 0} of $entryCount foods',
                            ),
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    '${fmt(numeric(values[nutrient.key]), nutrient.key == 'energy' ? 0 : 2)} ${nutrient.unit}',
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
          ],
        ),
    ],
  );
}

Future<void> editMeal(
  BuildContext context,
  AppModel model, {
  Json? entry,
  Json? food,
}) async {
  final selected =
      food ??
      (entry == null ? null : _object(entry['food'])) ??
      await Navigator.of(context).push<Json>(
        MaterialPageRoute(builder: (_) => FoodPickerPage(model: model)),
      );
  if (selected == null || !context.mounted) return;
  await Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => _MealEditor(model: model, entry: entry, food: selected),
    ),
  );
}

class _MealEditor extends StatefulWidget {
  const _MealEditor({required this.model, required this.food, this.entry});
  final AppModel model;
  final Json food;
  final Json? entry;
  @override
  State<_MealEditor> createState() => _MealEditorState();
}

class _MealEditorState extends State<_MealEditor> {
  final _form = GlobalKey<FormState>();
  late Json _food;
  late TextEditingController _amount;
  late TextEditingController _serving;
  late TextEditingController _note;
  late DateTime _at;
  late String _meal;
  late String _unit;
  bool _saving = false;
  bool _timestampChanged = false;
  AppModel get model => widget.model;
  bool get existing => widget.entry?['id'] != null;

  @override
  void initState() {
    super.initState();
    _food = Json.from(widget.food);
    _unit = '${widget.entry?['unit'] ?? _food['basis'] ?? 'g'}';
    _amount = TextEditingController(
      text: _inputValue(
        widget.entry?['amount'] ?? (_unit == 'serving' ? 1 : 100),
      ),
    );
    _serving = TextEditingController(text: _inputValue(_food['servingSize']));
    _note = TextEditingController(text: '${widget.entry?['note'] ?? ''}');
    _at = widget.entry == null
        ? _entryTime(model)
        : _civilTime('${widget.entry!['at']}');
    _meal =
        '${widget.entry?['meal'] ?? (_at.hour < 11
                ? 'breakfast'
                : _at.hour < 15
                ? 'lunch'
                : _at.hour < 21
                ? 'dinner'
                : 'snack')}';
    _amount.addListener(_refresh);
    _serving.addListener(_refresh);
  }

  void _refresh() => setState(() {});
  @override
  void dispose() {
    _amount.dispose();
    _serving.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    final snapshot = Json.from(_food);
    if (_unit == 'serving') {
      snapshot['servingSize'] = _readNumber(_serving.text);
    }
    await safeAction(context, model, () async {
      await model.put('meals', {
        'id': widget.entry?['id'] ?? newId(),
        'food': snapshot,
        'amount': _readNumber(_amount.text),
        'unit': _unit,
        'at': !_timestampChanged && widget.entry != null
            ? widget.entry!['at']
            : _at.toIso8601String(),
        'meal': _meal,
        'note': _note.text.trim(),
      });
      if (mounted) Navigator.pop(context);
    });
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) {
    final basis = '${_food['basis'] ?? 'g'}';
    final previewFood = Json.from(_food)
      ..['servingSize'] = _readNumber(_serving.text);
    final totals = _foodTotals(
      previewFood,
      _readNumber(_amount.text) ?? 0,
      _unit,
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(
          existing
              ? model.tr('Eintrag bearbeiten', 'Edit entry')
              : model.tr('Lebensmittel erfassen', 'Log food'),
        ),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
          children: [
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${_food['name']}',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  if ('${_food['brand'] ?? ''}'.isNotEmpty)
                    Text('${_food['brand']}'),
                  const SizedBox(height: 8),
                  Text(
                    model.tr(
                      'Nährwerte beziehen sich auf 100 $basis.',
                      'Nutrition is based on 100 $basis.',
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () async {
                      final replacement = await Navigator.of(context)
                          .push<Json>(
                            MaterialPageRoute(
                              builder: (_) => FoodPickerPage(model: model),
                            ),
                          );
                      if (replacement == null || !mounted) return;
                      setState(() {
                        _food = Json.from(replacement);
                        _unit = '${_food['basis']}';
                        _serving.text = _inputValue(_food['servingSize']);
                      });
                    },
                    icon: const Icon(Icons.swap_horiz),
                    label: Text(model.tr('Lebensmittel ändern', 'Change food')),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            LayoutBuilder(
              builder: (context, constraints) {
                final stacked =
                    constraints.maxWidth < 300 ||
                    MediaQuery.textScalerOf(context).scale(14) > 19;
                final width = stacked
                    ? constraints.maxWidth
                    : (constraints.maxWidth - 12) / 2;
                return Wrap(
                  spacing: 12,
                  runSpacing: 16,
                  children: [
                    SizedBox(
                      width: width,
                      child: _NumberInput(
                        controller: _amount,
                        label: model.tr('Menge', 'Amount'),
                        model: model,
                        required: true,
                        positive: true,
                      ),
                    ),
                    SizedBox(
                      width: width,
                      child: DropdownButtonFormField<String>(
                        key: ValueKey('unit-$basis-$_unit'),
                        initialValue: _unit,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: model.tr('Einheit', 'Unit'),
                        ),
                        items: [basis, 'serving']
                            .map(
                              (unit) => DropdownMenuItem(
                                value: unit,
                                child: Text(_unitLabel(model, unit)),
                              ),
                            )
                            .toList(),
                        onChanged: (value) => setState(() => _unit = value!),
                      ),
                    ),
                  ],
                );
              },
            ),
            if (_unit == 'serving') ...[
              const SizedBox(height: 16),
              _NumberInput(
                controller: _serving,
                label: model.tr(
                  'Eine Portion entspricht',
                  'One serving equals',
                ),
                unit: basis,
                model: model,
                required: true,
                positive: true,
              ),
            ],
            const SizedBox(height: 10),
            Text(
              model.tr(
                'Gramm und Milliliter werden nicht ohne Dichte umgerechnet. Eine Portion nutzt die angegebene Basis $basis.',
                'Grams and millilitres are not converted without density. A serving uses the stated $basis basis.',
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 20),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _meal,
              decoration: InputDecoration(
                labelText: model.tr('Mahlzeit', 'Meal'),
              ),
              items: _mealKeys
                  .map(
                    (key) => DropdownMenuItem(
                      value: key,
                      child: Text(_mealName(model, key)),
                    ),
                  )
                  .toList(),
              onChanged: (value) => setState(() => _meal = value!),
            ),
            const SizedBox(height: 16),
            _DateTimeButton(
              model: model,
              at: _at,
              onChanged: (value) => setState(() {
                _at = value;
                _timestampChanged = true;
              }),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _note,
              maxLines: 3,
              maxLength: 2000,
              decoration: InputDecoration(
                labelText: model.tr('Notiz (optional)', 'Note (optional)'),
              ),
            ),
            const SizedBox(height: 18),
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${fmt(numeric(totals['energy']), 0)} kcal',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 20,
                    runSpacing: 12,
                    children: [
                      for (final key in ['protein', 'carbs', 'fat'])
                        _MacroValue(
                          model: model,
                          nutrientKey: key,
                          value: numeric(totals[key]),
                        ),
                    ],
                  ),
                  TextButton(
                    onPressed: () => _showNutrients(
                      context,
                      model,
                      totals,
                      title: model.tr(
                        'Nährstoffe für diese Menge',
                        'Nutrients for this amount',
                      ),
                    ),
                    child: Text(
                      model.tr('Alle Nährstoffe ansehen', 'View all nutrients'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(model.tr('Speichern', 'Save')),
              ),
            ),
            if (existing) ...[
              const SizedBox(height: 8),
              TextButton.icon(
                onPressed: _saving
                    ? null
                    : () async {
                        if (!await confirmDelete(context, model) ||
                            !context.mounted) {
                          return;
                        }
                        await safeAction(context, model, () async {
                          await model.remove('meals', '${widget.entry!['id']}');
                          if (context.mounted) Navigator.pop(context);
                        });
                      },
                icon: const Icon(Icons.delete_outline),
                label: Text(model.tr('Eintrag löschen', 'Delete entry')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

Future<void> editDrink(
  BuildContext context,
  AppModel model, {
  Json? entry,
  String kind = 'water',
}) => Navigator.of(context).push<void>(
  MaterialPageRoute(
    builder: (_) => _DrinkEditor(model: model, entry: entry, kind: kind),
  ),
);

class _DrinkEditor extends StatefulWidget {
  const _DrinkEditor({required this.model, this.entry, required this.kind});
  final AppModel model;
  final Json? entry;
  final String kind;
  @override
  State<_DrinkEditor> createState() => _DrinkEditorState();
}

class _DrinkEditorState extends State<_DrinkEditor> {
  final _form = GlobalKey<FormState>();
  late TextEditingController _amount;
  late TextEditingController _note;
  late DateTime _at;
  late String _kind;
  bool _saving = false;
  bool _timestampChanged = false;
  AppModel get model => widget.model;
  @override
  void initState() {
    super.initState();
    _kind = '${widget.entry?['kind'] ?? widget.kind}';
    _amount = TextEditingController(
      text: _inputValue(
        widget.entry?['amount'] ?? (_kind == 'water' ? 250 : null),
      ),
    );
    _note = TextEditingController(text: '${widget.entry?['note'] ?? ''}');
    _at = widget.entry == null
        ? _entryTime(model)
        : _civilTime('${widget.entry!['at']}');
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    await safeAction(context, model, () async {
      await model.put('drinks', {
        'id': widget.entry?['id'] ?? newId(),
        'kind': _kind,
        'amount': _readNumber(_amount.text),
        'at': !_timestampChanged && widget.entry != null
            ? widget.entry!['at']
            : _at.toIso8601String(),
        'note': _note.text.trim(),
      });
      if (mounted) Navigator.pop(context);
    });
    if (mounted) setState(() => _saving = false);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(model.tr('Wasser & Koffein', 'Water & caffeine')),
    ),
    body: Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          SegmentedButton<String>(
            direction:
                MediaQuery.textScalerOf(context).scale(14) > 19 ||
                    MediaQuery.sizeOf(context).width < 360
                ? Axis.vertical
                : Axis.horizontal,
            segments: [
              ButtonSegment(
                value: 'water',
                label: Text(model.tr('Wasser', 'Water')),
                icon: const Icon(Icons.water_drop_outlined),
              ),
              ButtonSegment(
                value: 'caffeine',
                label: Text(model.tr('Koffein', 'Caffeine')),
                icon: const Icon(Icons.coffee_outlined),
              ),
            ],
            selected: {_kind},
            onSelectionChanged: (values) =>
                setState(() => _kind = values.first),
          ),
          const SizedBox(height: 24),
          _NumberInput(
            controller: _amount,
            label: model.tr('Menge', 'Amount'),
            unit: _kind == 'water' ? 'ml' : 'mg',
            model: model,
            required: true,
            positive: true,
          ),
          const SizedBox(height: 16),
          _DateTimeButton(
            model: model,
            at: _at,
            onChanged: (value) => setState(() {
              _at = value;
              _timestampChanged = true;
            }),
          ),
          const SizedBox(height: 16),
          TextFormField(
            controller: _note,
            maxLines: 3,
            maxLength: 2000,
            decoration: InputDecoration(
              labelText: model.tr('Notiz (optional)', 'Note (optional)'),
            ),
          ),
          if (_kind == 'caffeine')
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                model.tr(
                  'Erfasse hier nur zusätzliches Koffein. Koffein aus protokollierten Lebensmitteln wird bereits mitgezählt.',
                  'Log only additional caffeine here. Caffeine from logged foods is already included.',
                ),
              ),
            ),
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.check),
            label: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(model.tr('Speichern', 'Save')),
            ),
          ),
          if (widget.entry != null)
            TextButton.icon(
              onPressed: _saving
                  ? null
                  : () async {
                      if (!await confirmDelete(context, model) ||
                          !context.mounted) {
                        return;
                      }
                      await safeAction(context, model, () async {
                        await model.remove('drinks', '${widget.entry!['id']}');
                        if (context.mounted) Navigator.pop(context);
                      });
                    },
              icon: const Icon(Icons.delete_outline),
              label: Text(model.tr('Eintrag löschen', 'Delete entry')),
            ),
        ],
      ),
    ),
  );
}

class _DateTimeButton extends StatelessWidget {
  const _DateTimeButton({
    required this.model,
    required this.at,
    required this.onChanged,
  });
  final AppModel model;
  final DateTime at;
  final ValueChanged<DateTime> onChanged;
  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: () async {
      final selected = await pickTimestamp(context, at);
      if (selected != null) onChanged(selected);
    },
    icon: const Icon(Icons.event_outlined),
    label: Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Text('${displayDate(at, model.de)} · ${_timeText(at)}'),
    ),
  );
}

class _NumberInput extends StatelessWidget {
  const _NumberInput({
    required this.controller,
    required this.label,
    required this.model,
    this.unit,
    this.required = false,
    this.positive = false,
  });
  final TextEditingController controller;
  final String label;
  final String? unit;
  final AppModel model;
  final bool required;
  final bool positive;
  @override
  Widget build(BuildContext context) => TextFormField(
    controller: controller,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(labelText: label, suffixText: unit),
    validator: (value) {
      if ((value ?? '').trim().isEmpty) {
        return required
            ? model.tr('Bitte eine Menge eingeben.', 'Enter an amount.')
            : null;
      }
      final parsed = _readNumber(value!);
      if (parsed == null ||
          !parsed.isFinite ||
          parsed < 0 ||
          (positive && parsed == 0)) {
        return model.tr(
          positive ? 'Zahl größer als 0 eingeben.' : 'Zahl ab 0 eingeben.',
          positive ? 'Enter a number above 0.' : 'Enter a number of 0 or more.',
        );
      }
      return null;
    },
  );
}

class FoodPickerPage extends StatefulWidget {
  const FoodPickerPage({
    super.key,
    required this.model,
    this.libraryOnly = false,
  });
  final AppModel model;
  final bool libraryOnly;
  @override
  State<FoodPickerPage> createState() => _FoodPickerPageState();
}

class _FoodPickerPageState extends State<FoodPickerPage> {
  final _query = TextEditingController();
  String _tab = 'local';
  String _localFilter = 'all';
  int _localLimit = 40;
  String _submittedQuery = '';
  int _page = 0;
  int _count = 0;
  int _request = 0;
  bool _loading = false;
  bool _searched = false;
  bool _hasMore = false;
  String? _error;
  List<Json> _results = [];
  AppModel get model => widget.model;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _changeTab(String tab) {
    setState(() {
      _tab = tab;
      _request++;
      _query.clear();
      _results = [];
      _searched = false;
      _loading = false;
      _error = null;
      _page = 0;
      _count = 0;
      _hasMore = false;
    });
  }

  Future<void> _search({bool more = false}) async {
    if (model.settings['onlineFood'] != true || _loading) return;
    final q = more ? _submittedQuery : _query.text.trim();
    if (q.isEmpty) {
      setState(
        () => _error = model.tr(
          'Bitte einen Suchbegriff eingeben.',
          'Enter a search term.',
        ),
      );
      return;
    }
    if (_tab == 'barcode' && !RegExp(r'^\d{4,24}$').hasMatch(q)) {
      setState(
        () => _error = model.tr(
          'Bitte 4 bis 24 Barcode-Ziffern eingeben.',
          'Enter 4 to 24 barcode digits.',
        ),
      );
      return;
    }
    FocusScope.of(context).unfocus();
    final request = ++_request;
    final page = more ? _page + 1 : 1;
    setState(() {
      _loading = true;
      _error = null;
      _searched = true;
      if (!more) {
        _results = [];
        _count = 0;
        _page = 0;
        _hasMore = false;
      }
      _submittedQuery = q;
    });
    try {
      if (_tab == 'barcode') {
        final product = await model.api.lookup(q);
        if (!mounted || request != _request) return;
        setState(() {
          _results = product == null ? [] : [product];
          _count = _results.length;
          _page = 1;
          _hasMore = false;
        });
      } else {
        final response = await model.api.search(q, page: page);
        if (!mounted || request != _request) return;
        final products = (response['products'] as List)
            .map((e) => Json.from(e as Map))
            .toList();
        setState(() {
          final existingIds = _results.map((e) => '${e['id']}').toSet();
          _results = [
            ..._results,
            ...products.where((p) => !existingIds.contains('${p['id']}')),
          ];
          _count = (numeric(response['count']) ?? _results.length).toInt();
          _page = page;
          _hasMore =
              products.isNotEmpty &&
              page * (numeric(response['pageSize']) ?? 20) < _count;
        });
      }
    } catch (error) {
      if (!mounted || request != _request) return;
      setState(
        () => _error = switch (error is CoreException ? error.code : '') {
          'food_rate_limited' => model.tr(
            'Der Dienst erhält gerade zu viele Anfragen. Versuche es in einer Minute erneut.',
            'The service is receiving too many requests. Try again in a minute.',
          ),
          'food_tls' => model.tr(
            'Die sichere Verbindung konnte nicht geprüft werden. Versuche es später erneut.',
            'The secure connection could not be verified. Try again later.',
          ),
          'food_timeout' => model.tr(
            'Der Dienst hat nicht rechtzeitig geantwortet. Versuche es erneut.',
            'The service did not respond in time. Try again.',
          ),
          'food_invalid_response' => model.tr(
            'Der Dienst hat keine gültigen Lebensmitteldaten geliefert. Versuche es später erneut.',
            'The service did not return valid food data. Try again later.',
          ),
          'invalid_query' => model.tr(
            'Bitte einen Suchbegriff mit höchstens 200 Zeichen eingeben.',
            'Enter a search term of up to 200 characters.',
          ),
          _ => model.tr(
            'Der Abruf ist fehlgeschlagen. Prüfe die Internetverbindung und versuche es erneut.',
            'The request failed. Check your internet connection and try again.',
          ),
        },
      );
    } finally {
      if (mounted && request == _request) setState(() => _loading = false);
    }
  }

  List<Json> _localFoods() {
    final stored = _items(model, 'foods');
    final storedIds = stored.map((food) => food['id']).toSet();
    final recents = _items(model, 'meals')
      ..sort((a, b) => '${b['at']}'.compareTo('${a['at']}'));
    final recentFoods = <String, Json>{};
    for (final entry in recents) {
      final food = _object(entry['food']);
      recentFoods.putIfAbsent('${food['id']}', () => food);
    }
    final all = <String, Json>{
      for (final food in stored) '${food['id']}': food,
    };
    for (final entry in recentFoods.entries) {
      all.putIfAbsent(entry.key, () => entry.value);
    }
    final q = _query.text.trim().toLowerCase();
    Iterable<Json> filtered = _localFilter == 'recent'
        ? recentFoods.keys.map((key) => all[key]!)
        : all.values;
    if (_localFilter == 'favorite') {
      filtered = filtered.where((food) => food['favorite'] == true);
    }
    if (_localFilter == 'custom') {
      filtered = filtered.where(
        (food) => food['source'] == 'custom' && storedIds.contains(food['id']),
      );
    }
    final result = filtered
        .where(
          (food) =>
              '${food['name']} ${food['brand'] ?? ''} ${food['barcode'] ?? ''}'
                  .toLowerCase()
                  .contains(q),
        )
        .toList();
    if (_localFilter != 'recent') {
      result.sort(
        (a, b) => '${a['name']}'.toLowerCase().compareTo(
          '${b['name']}'.toLowerCase(),
        ),
      );
    }
    return result;
  }

  Future<void> _select(Json food) async {
    final selected = await Navigator.of(context).push<Json>(
      MaterialPageRoute(
        builder: (_) => _FoodDetailsPage(model: model, food: food),
      ),
    );
    if (selected == null || !mounted) return;
    if (widget.libraryOnly) {
      await editMeal(context, model, food: selected);
    } else {
      Navigator.pop(context, selected);
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: model,
    builder: (context, _) {
      final online = model.settings['onlineFood'] == true;
      final local = _tab == 'local';
      final products = local ? _localFoods() : _results;
      return Scaffold(
        appBar: AppBar(
          title: Text(
            widget.libraryOnly
                ? model.tr('Meine Lebensmittel', 'My foods')
                : model.tr('Lebensmittel wählen', 'Choose a food'),
          ),
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            SegmentedButton<String>(
              direction:
                  MediaQuery.textScalerOf(context).scale(14) > 19 ||
                      MediaQuery.sizeOf(context).width < 360
                  ? Axis.vertical
                  : Axis.horizontal,
              segments: [
                ButtonSegment(
                  value: 'local',
                  label: Text(model.tr('Meine', 'Mine')),
                  icon: const Icon(Icons.bookmarks_outlined),
                ),
                ButtonSegment(
                  value: 'search',
                  label: Text(model.tr('Suche', 'Search')),
                  icon: const Icon(Icons.search),
                ),
                const ButtonSegment(
                  value: 'barcode',
                  label: Text('Barcode'),
                  icon: Icon(Icons.numbers),
                ),
              ],
              selected: {_tab},
              onSelectionChanged: (values) => _changeTab(values.first),
            ),
            const SizedBox(height: 18),
            if (!local && !online) ...[
              Panel(
                color: Theme.of(context).colorScheme.secondaryContainer,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.public_outlined, size: 32),
                    const SizedBox(height: 14),
                    Text(
                      model.tr(
                        'Online-Suche freigeben',
                        'Enable online search',
                      ),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      model.tr(
                        'Suchbegriffe und eingegebene Barcodes werden an den konfigurierten Open-Food-Facts-Dienst gesendet. Dein Tagebuch bleibt auf diesem Gerät. Du kannst die Verbindung jederzeit in den Einstellungen deaktivieren.',
                        'Search terms and entered barcodes are sent to the configured Open Food Facts service. Your diary stays on this device. You can disable the connection in Settings at any time.',
                      ),
                    ),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: () => safeAction(
                        context,
                        model,
                        () => model.settingsPatch({'onlineFood': true}),
                      ),
                      icon: const Icon(Icons.public),
                      label: Text(
                        model.tr(
                          'Online-Suche aktivieren',
                          'Enable online search',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () => editFood(context, model),
                icon: const Icon(Icons.add),
                label: Text(
                  model.tr(
                    'Eigenes Lebensmittel anlegen',
                    'Create a custom food',
                  ),
                ),
              ),
            ] else ...[
              TextField(
                controller: _query,
                keyboardType: _tab == 'barcode'
                    ? TextInputType.number
                    : TextInputType.text,
                inputFormatters: _tab == 'barcode'
                    ? [FilteringTextInputFormatter.digitsOnly]
                    : null,
                textInputAction: TextInputAction.search,
                decoration: InputDecoration(
                  labelText: _tab == 'barcode'
                      ? model.tr('Barcode-Nummer', 'Barcode number')
                      : model.tr('Name oder Marke', 'Name or brand'),
                  prefixIcon: Icon(
                    _tab == 'barcode' ? Icons.numbers : Icons.search,
                  ),
                  suffixIcon: _query.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: model.tr('Suchfeld leeren', 'Clear search'),
                          onPressed: () => setState(() => _query.clear()),
                          icon: const Icon(Icons.close),
                        ),
                ),
                onChanged: (_) => setState(() => _localLimit = 40),
                onSubmitted: (_) {
                  if (!local) _search();
                },
              ),
              const SizedBox(height: 14),
              if (local) ...[
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final option in [
                      ('all', model.tr('Alle', 'All')),
                      ('favorite', model.tr('Favoriten', 'Favourites')),
                      ('recent', model.tr('Zuletzt erfasst', 'Recent')),
                      ('custom', model.tr('Eigene', 'Custom')),
                    ])
                      ChoiceChip(
                        label: Text(option.$2),
                        selected: _localFilter == option.$1,
                        onSelected: (_) => setState(() {
                          _localFilter = option.$1;
                          _localLimit = 40;
                        }),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: () => editFood(context, model),
                  icon: const Icon(Icons.add),
                  label: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      model.tr(
                        'Eigenes Lebensmittel anlegen',
                        'Create a custom food',
                      ),
                    ),
                  ),
                ),
              ] else ...[
                FilledButton.icon(
                  onPressed: _loading ? null : _search,
                  icon: const Icon(Icons.search),
                  label: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Text(
                      _tab == 'barcode'
                          ? model.tr('Barcode abrufen', 'Look up barcode')
                          : model.tr(
                              'Open Food Facts durchsuchen',
                              'Search Open Food Facts',
                            ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  model.tr(
                    'Daten: Open Food Facts · ODbL. Angaben können fehlen oder ungenau sein; mit der Verpackung abgleichen.',
                    'Data: Open Food Facts · ODbL. Values may be missing or inaccurate; check the packaging.',
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
              const SizedBox(height: 22),
              if (_error != null) ...[
                Panel(
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(_error!),
                      TextButton.icon(
                        onPressed: _loading
                            ? null
                            : () =>
                                  _search(more: _page > 0 && _tab != 'barcode'),
                        icon: const Icon(Icons.refresh),
                        label: Text(model.tr('Erneut versuchen', 'Try again')),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],
              if (_loading && products.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(36),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (products.isEmpty && !_loading && _error == null)
                EmptyState(
                  icon: local ? Icons.kitchen_outlined : Icons.search,
                  title: local
                      ? model.tr('Noch nichts gefunden', 'No foods found')
                      : _searched
                      ? model.tr('Kein Treffer', 'No results')
                      : model.tr(
                          'Was möchtest du erfassen?',
                          'What would you like to log?',
                        ),
                  message: local
                      ? model.tr(
                          'Eigene Lebensmittel, Favoriten und zuletzt erfasste Lebensmittel findest du hier.',
                          'Your custom foods, favourites and recently logged foods appear here.',
                        )
                      : _searched
                      ? model.tr(
                          'Versuche einen anderen Suchbegriff oder lege das Lebensmittel selbst an.',
                          'Try another search term or create the food yourself.',
                        )
                      : _tab == 'barcode'
                      ? model.tr(
                          'Gib die Nummer unter dem Barcode ein. Eine Kamera ist nicht nötig.',
                          'Enter the number beneath the barcode. No camera is needed.',
                        )
                      : model.tr(
                          'Suche nach einem Namen oder einer Marke.',
                          'Search by food name or brand.',
                        ),
                  action: _searched && !local
                      ? TextButton.icon(
                          onPressed: () => editFood(context, model),
                          icon: const Icon(Icons.add),
                          label: Text(
                            model.tr('Eigenes Lebensmittel', 'Custom food'),
                          ),
                        )
                      : null,
                ),
              if (products.isNotEmpty) ...[
                SectionTitle(
                  local
                      ? model.tr(
                          '${products.length} Lebensmittel',
                          '${products.length} foods',
                        )
                      : model.tr(
                          '${products.length} von $_count Ergebnissen',
                          '${products.length} of $_count results',
                        ),
                ),
                const SizedBox(height: 8),
                for (final food
                    in (local ? products.take(_localLimit) : products))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Panel(
                      child: _FoodRow(
                        model: model,
                        food: food,
                        onTap: () => _select(food),
                      ),
                    ),
                  ),
              ],
              if (local && products.length > _localLimit)
                OutlinedButton.icon(
                  onPressed: () => setState(() => _localLimit += 40),
                  icon: const Icon(Icons.expand_more),
                  label: Text(
                    model.tr(
                      'Weitere Lebensmittel anzeigen',
                      'Show more foods',
                    ),
                  ),
                ),
              if (!local && _hasMore)
                Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: OutlinedButton.icon(
                    onPressed: _loading ? null : () => _search(more: true),
                    icon: _loading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.expand_more),
                    label: Text(
                      model.tr('Weitere Ergebnisse laden', 'Load more results'),
                    ),
                  ),
                ),
            ],
          ],
        ),
      );
    },
  );
}

class _FoodRow extends StatelessWidget {
  const _FoodRow({
    required this.model,
    required this.food,
    required this.onTap,
  });
  final AppModel model;
  final Json food;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final values = _object(food['nutrients']);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: Icon(
          food['source'] == 'custom'
              ? Icons.edit_note
              : Icons.restaurant_outlined,
        ),
      ),
      title: Text(
        '${food['name']}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        '${food['brand'] == null || food['brand'] == '' ? '' : '${food['brand']} · '}'
        '${fmt(numeric(values['energy']), 0)} kcal / 100 ${food['basis']}',
      ),
      trailing: Icon(
        food['favorite'] == true ? Icons.star : Icons.chevron_right,
        color: food['favorite'] == true
            ? Theme.of(context).colorScheme.primary
            : null,
      ),
      onTap: onTap,
    );
  }
}

class _FoodDetailsPage extends StatefulWidget {
  const _FoodDetailsPage({required this.model, required this.food});
  final AppModel model;
  final Json food;
  @override
  State<_FoodDetailsPage> createState() => _FoodDetailsPageState();
}

class _FoodDetailsPageState extends State<_FoodDetailsPage> {
  late Json _food;
  AppModel get model => widget.model;
  @override
  void initState() {
    super.initState();
    _food = Json.from(widget.food);
    _refreshStored();
  }

  void _refreshStored() {
    for (final food in _items(model, 'foods')) {
      if (food['id'] == _food['id']) _food = food;
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(model.tr('Lebensmittel', 'Food')),
      actions: [
        IconButton(
          tooltip: _food['favorite'] == true
              ? model.tr('Favorit entfernen', 'Remove favourite')
              : model.tr('Als Favorit speichern', 'Save favourite'),
          icon: Icon(
            _food['favorite'] == true ? Icons.star : Icons.star_border,
          ),
          onPressed: () => safeAction(context, model, () async {
            final updated = Json.from(_food)
              ..['favorite'] = _food['favorite'] != true;
            await model.put('foods', updated);
            if (mounted) setState(() => _food = updated);
          }),
        ),
      ],
    ),
    bottomNavigationBar: SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
        child: FilledButton.icon(
          onPressed: () => Navigator.pop(context, _food),
          icon: const Icon(Icons.add),
          label: Padding(
            padding: const EdgeInsets.all(13),
            child: Text(
              model.tr('Dieses Lebensmittel verwenden', 'Use this food'),
            ),
          ),
        ),
      ),
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 30),
      children: [
        Text(
          '${_food['name']}',
          style: Theme.of(context).textTheme.headlineMedium,
        ),
        if ('${_food['brand'] ?? ''}'.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('${_food['brand']}'),
          ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            Chip(
              label: Text(
                _food['source'] == 'custom'
                    ? model.tr('Eigenes Lebensmittel', 'Custom food')
                    : 'Open Food Facts',
              ),
            ),
            Chip(
              label: Text(
                model.tr(
                  'Je 100 ${_food['basis']}',
                  'Per 100 ${_food['basis']}',
                ),
              ),
            ),
          ],
        ),
        if ('${_food['barcode'] ?? ''}'.isNotEmpty)
          Text('Barcode: ${_food['barcode']}'),
        if (numeric(_food['servingSize']) != null)
          Text(
            model.tr(
              'Eine Portion: ${fmt(numeric(_food['servingSize']))} ${_food['basis']}',
              'One serving: ${fmt(numeric(_food['servingSize']))} ${_food['basis']}',
            ),
          ),
        if (_food['source'] == 'custom') ...[
          const SizedBox(height: 14),
          OutlinedButton.icon(
            onPressed: () async {
              await editFood(context, model, food: _food);
              if (mounted) setState(_refreshStored);
            },
            icon: const Icon(Icons.edit_outlined),
            label: Text(model.tr('Lebensmittel bearbeiten', 'Edit food')),
          ),
        ],
        const SizedBox(height: 16),
        Text(
          model.tr(
            '— bedeutet unbekannt. Alle Angaben je 100 ${_food['basis']}.',
            '— means unknown. All values per 100 ${_food['basis']}.',
          ),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 12),
        _NutrientTable(model: model, values: _object(_food['nutrients'])),
        if (_food['source'] == 'off')
          Padding(
            padding: const EdgeInsets.only(top: 18),
            child: Text(
              model.tr(
                'Datenquelle: Open Food Facts, Open Database License (ODbL). Bitte die Verpackung prüfen; Angaben können unvollständig sein.',
                'Source: Open Food Facts, Open Database License (ODbL). Check the packaging; values may be incomplete.',
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        if (_food['source'] == 'custom')
          Padding(
            padding: const EdgeInsets.only(top: 18),
            child: TextButton.icon(
              onPressed: () async {
                if (!await confirmDelete(context, model) || !context.mounted) {
                  return;
                }
                await safeAction(context, model, () async {
                  await model.remove('foods', '${_food['id']}');
                  if (context.mounted) Navigator.pop(context);
                });
              },
              icon: const Icon(Icons.delete_outline),
              label: Text(
                model.tr('Eigenes Lebensmittel löschen', 'Delete custom food'),
              ),
            ),
          ),
      ],
    ),
  );
}

Future<void> editFood(BuildContext context, AppModel model, {Json? food}) =>
    Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) => _FoodEditor(model: model, food: food),
      ),
    );

class _FoodEditor extends StatefulWidget {
  const _FoodEditor({required this.model, this.food});
  final AppModel model;
  final Json? food;
  @override
  State<_FoodEditor> createState() => _FoodEditorState();
}

class _FoodEditorState extends State<_FoodEditor> {
  final _form = GlobalKey<FormState>();
  late TextEditingController _name;
  late TextEditingController _brand;
  late TextEditingController _barcode;
  late TextEditingController _serving;
  final Map<String, TextEditingController> _nutrients = {};
  late String _basis;
  late bool _favorite;
  bool _saving = false;
  AppModel get model => widget.model;
  @override
  void initState() {
    super.initState();
    final food = widget.food ?? <String, dynamic>{};
    _name = TextEditingController(text: '${food['name'] ?? ''}');
    _brand = TextEditingController(text: '${food['brand'] ?? ''}');
    _barcode = TextEditingController(text: '${food['barcode'] ?? ''}');
    _serving = TextEditingController(text: _inputValue(food['servingSize']));
    _basis = '${food['basis'] ?? 'g'}';
    _favorite = food['favorite'] == true;
    final values = _object(food['nutrients']);
    for (final nutrient in nutrients) {
      _nutrients[nutrient.key] = TextEditingController(
        text: _inputValue(values[nutrient.key]),
      );
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _brand.dispose();
    _barcode.dispose();
    _serving.dispose();
    for (final controller in _nutrients.values) {
      controller.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    await safeAction(context, model, () async {
      await model.put('foods', {
        'id': widget.food?['id'] ?? newId(),
        'name': _name.text.trim(),
        'brand': _brand.text.trim(),
        'barcode': _barcode.text.trim(),
        'source': 'custom',
        'basis': _basis,
        'servingSize': _readNumber(_serving.text),
        'favorite': _favorite,
        'nutrients': {
          for (final nutrient in nutrients)
            nutrient.key: _readNumber(_nutrients[nutrient.key]!.text),
        },
      });
      if (mounted) Navigator.pop(context);
    });
    if (mounted) setState(() => _saving = false);
  }

  Widget _group(String title, List<Nutrient> group, {bool open = false}) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 14),
        child: Panel(
          child: ExpansionTile(
            tilePadding: EdgeInsets.zero,
            childrenPadding: const EdgeInsets.only(top: 12, bottom: 8),
            initiallyExpanded: open,
            maintainState: true,
            title: Text(title, style: Theme.of(context).textTheme.titleMedium),
            subtitle: Text(
              model.tr('Angaben je 100 $_basis', 'Values per 100 $_basis'),
            ),
            children: [
              for (final nutrient in group)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _NumberInput(
                    controller: _nutrients[nutrient.key]!,
                    label: model.de ? nutrient.de : nutrient.en,
                    model: model,
                    unit: nutrient.unit,
                  ),
                ),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.food == null
            ? model.tr('Eigenes Lebensmittel', 'Custom food')
            : model.tr('Lebensmittel bearbeiten', 'Edit food'),
      ),
    ),
    body: Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
        children: [
          Text(
            model.tr('Deine Angaben, deine Basis.', 'Your food, your values.'),
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            model.tr(
              'Übertrage Nährwerte von der Verpackung. Unbekannte Werte lässt du leer; 0 bedeutet ausdrücklich null.',
              'Copy nutrition values from the packaging. Leave unknown values empty; 0 explicitly means zero.',
            ),
          ),
          const SizedBox(height: 22),
          TextFormField(
            controller: _name,
            maxLength: 200,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(labelText: model.tr('Name', 'Name')),
            validator: (value) => (value ?? '').trim().isEmpty
                ? model.tr('Bitte einen Namen eingeben.', 'Enter a name.')
                : null,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _brand,
            maxLength: 200,
            decoration: InputDecoration(
              labelText: model.tr('Marke (optional)', 'Brand (optional)'),
            ),
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _barcode,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            maxLength: 24,
            decoration: InputDecoration(
              labelText: model.tr('Barcode (optional)', 'Barcode (optional)'),
            ),
            validator: (value) =>
                value != null &&
                    value.isNotEmpty &&
                    !RegExp(r'^\d{4,24}$').hasMatch(value)
                ? model.tr(
                    '4 bis 24 Ziffern eingeben.',
                    'Enter 4 to 24 digits.',
                  )
                : null,
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            isExpanded: true,
            initialValue: _basis,
            decoration: InputDecoration(
              labelText: model.tr('Nährwertbasis', 'Nutrition basis'),
            ),
            items: [
              DropdownMenuItem(
                value: 'g',
                child: Text(model.tr('Je 100 Gramm', 'Per 100 grams')),
              ),
              DropdownMenuItem(
                value: 'ml',
                child: Text(
                  model.tr('Je 100 Milliliter', 'Per 100 millilitres'),
                ),
              ),
            ],
            onChanged: (value) => setState(() => _basis = value!),
          ),
          const SizedBox(height: 16),
          _NumberInput(
            controller: _serving,
            label: model.tr(
              'Portionsgröße (optional)',
              'Serving size (optional)',
            ),
            model: model,
            unit: _basis,
            positive: true,
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(model.tr('Als Favorit speichern', 'Save as favourite')),
            value: _favorite,
            onChanged: (value) => setState(() => _favorite = value),
          ),
          if (widget.food != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Text(
                model.tr(
                  'Bereits erfasste Mahlzeiten behalten ihre ursprünglichen Nährwerte.',
                  'Previously logged meals keep their original nutrition values.',
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          const SizedBox(height: 18),
          _group(
            model.tr('Energie & Hauptnährstoffe', 'Energy & main nutrients'),
            nutrients
                .where(
                  (n) =>
                      !n.key.startsWith('vitamin') &&
                      ![
                        'calcium',
                        'iron',
                        'magnesium',
                        'potassium',
                        'zinc',
                        'selenium',
                        'iodine',
                        'phosphorus',
                      ].contains(n.key),
                )
                .toList(),
            open: true,
          ),
          _group(
            model.tr('Vitamine', 'Vitamins'),
            nutrients.where((n) => n.key.startsWith('vitamin')).toList(),
          ),
          _group(
            model.tr(
              'Mineralstoffe & Spurenelemente',
              'Minerals & trace elements',
            ),
            nutrients
                .where(
                  (n) => [
                    'calcium',
                    'iron',
                    'magnesium',
                    'potassium',
                    'zinc',
                    'selenium',
                    'iodine',
                    'phosphorus',
                  ].contains(n.key),
                )
                .toList(),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _saving ? null : _save,
            icon: const Icon(Icons.check),
            label: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(model.tr('Lebensmittel speichern', 'Save food')),
            ),
          ),
        ],
      ),
    ),
  );
}
