import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/health.dart';
import '../core/nutrition.dart';
import '../core/utils.dart';
import 'charts.dart' hide fieldDecoration;
import 'controller.dart';
import 'food_ui.dart';
import 'l10n.dart';
import 'widgets.dart';

class NutritionPage extends StatelessWidget {
  const NutritionPage({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = l10n(context);
    final controller = context.watch<AppController>();
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: Text(strings.t('nutrition')),
          bottom: TabBar(
            tabs: [
              Tab(
                icon: const Icon(Icons.today_outlined),
                text: strings.t('day'),
              ),
              Tab(
                icon: const Icon(Icons.restaurant_outlined),
                text: strings.t('foods'),
              ),
              Tab(
                icon: const Icon(Icons.show_chart),
                text: strings.t('trends'),
              ),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            const NutritionDayView(),
            const FoodLibraryPage(),
            ListView(
              children: [NutrientTrends(endDate: controller.selectedDate)],
            ),
          ],
        ),
      ),
    );
  }
}

class NutritionDayView extends StatelessWidget {
  const NutritionDayView({super.key});

  DateTime _atSelectedTime(AppController controller) {
    final selected = parseDate(controller.selectedDate);
    final now = controller.now.toLocal();
    return DateTime(
      selected.year,
      selected.month,
      selected.day,
      now.hour,
      now.minute,
    );
  }

  Future<void> _quickWater(BuildContext context) async {
    final controller = context.read<AppController>();
    final strings = l10n(context);
    Future<void> add(double amount) async {
      try {
        await controller.repository.addWater(
          amount,
          at: _atSelectedTime(controller),
        );
      } catch (_) {
        if (context.mounted) showError(context);
      }
    }

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(
                  strings.t('water_quick'),
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              for (final amount in [150.0, 250.0, 330.0, 500.0])
                ListTile(
                  key: ValueKey('water-${amount.round()}'),
                  leading: const Icon(Icons.water_drop_outlined),
                  title: Text('${strings.number(amount, decimals: 0)} ml'),
                  onTap: () {
                    Navigator.pop(sheetContext);
                    add(amount);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.edit_outlined),
                title: Text(strings.t('amount')),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _amountDialog(context, IntakeKind.water);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _amountDialog(BuildContext context, IntakeKind kind) async {
    final controller = context.read<AppController>();
    final strings = l10n(context);
    final input = TextEditingController();
    final form = GlobalKey<FormState>();
    final amount = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        scrollable: true,
        title: Text(
          strings.t(kind == IntakeKind.water ? 'add_water' : 'add_caffeine'),
        ),
        content: Form(
          key: form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (kind == IntakeKind.caffeine) Text(strings.t('caffeine_help')),
              TextFormField(
                key: const ValueKey('quick-amount'),
                controller: input,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: fieldDecoration(
                  strings.t('amount'),
                  suffix: kind == IntakeKind.water ? 'ml' : 'mg',
                ),
                validator: (value) {
                  final parsed = parseAmount(value ?? '');
                  if (parsed == null) return strings.t('invalid_number');
                  if (parsed <= 0) return strings.t('positive_number');
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(strings.t('cancel')),
          ),
          FilledButton(
            key: const ValueKey('quick-save'),
            onPressed: () {
              if (form.currentState!.validate()) {
                Navigator.pop(context, parseAmount(input.text));
              }
            },
            child: Text(strings.t('save')),
          ),
        ],
      ),
    );
    if (amount == null) return;
    try {
      if (kind == IntakeKind.water) {
        await controller.repository.addWater(
          amount,
          at: _atSelectedTime(controller),
        );
      } else {
        await controller.repository.addCaffeine(
          amount,
          at: _atSelectedTime(controller),
        );
      }
    } catch (_) {
      if (context.mounted) showError(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = l10n(context);
    final controller = context.watch<AppController>();
    final day = controller.repository.nutritionDay(controller.selectedDate);
    final foods = day.entries
        .where((entry) => entry.kind == IntakeKind.food)
        .toList();
    final simple = day.entries
        .where((entry) => entry.kind != IntakeKind.food)
        .toList();
    return ListView(
      key: const ValueKey('nutrition-day'),
      padding: const EdgeInsets.only(bottom: 32),
      children: [
        DateSelector(
          date: controller.selectedDate,
          onChanged: controller.selectDate,
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                key: const ValueKey('add-food-entry'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => const FoodSearchPage(),
                  ),
                ),
                icon: const Icon(Icons.add),
                label: Text(strings.t('add_intake')),
              ),
              OutlinedButton.icon(
                key: const ValueKey('quick-water'),
                onPressed: () => _quickWater(context),
                icon: const Icon(Icons.water_drop_outlined),
                label: Text(strings.t('water')),
              ),
              OutlinedButton.icon(
                key: const ValueKey('quick-caffeine'),
                onPressed: () => _amountDialog(context, IntakeKind.caffeine),
                icon: const Icon(Icons.coffee_outlined),
                label: Text(strings.t('caffeine')),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        _DailyTotals(
          day: day,
          onGoals: () => Navigator.push(
            context,
            MaterialPageRoute<void>(builder: (_) => const GoalsPage()),
          ),
        ),
        if (simple.isNotEmpty)
          AppCard(
            title: '${strings.t('water')} / ${strings.t('caffeine')}',
            icon: Icons.local_drink_outlined,
            children: [for (final entry in simple) IntakeTile(entry: entry)],
          ),
        for (final meal in ['breakfast', 'lunch', 'dinner', 'snack'])
          if (foods.any((entry) => entry.meal == meal))
            AppCard(
              title: strings.meal(meal),
              icon: Icons.restaurant_outlined,
              children: [
                for (final entry in foods.where((entry) => entry.meal == meal))
                  IntakeTile(entry: entry),
              ],
            ),
        if (day.entries.isEmpty) EmptyState(text: strings.t('no_entries')),
      ],
    );
  }
}

class _DailyTotals extends StatelessWidget {
  const _DailyTotals({required this.day, required this.onGoals});
  final NutritionDay day;
  final VoidCallback onGoals;

  @override
  Widget build(BuildContext context) {
    final strings = l10n(context);
    final settings = context.watch<AppController>().settings;
    return AppCard(
      title: strings.t('daily_total'),
      icon: Icons.insights_outlined,
      trailing: IconButton(
        tooltip: strings.t('goals'),
        onPressed: onGoals,
        icon: const Icon(Icons.flag_outlined),
      ),
      children: [
        for (final nutrient in [
          Nutrient.calories,
          Nutrient.protein,
          Nutrient.carbs,
          Nutrient.fat,
        ])
          _TotalRow(
            nutrient: nutrient,
            value: day.total(nutrient),
            goal: settings.goals.forNutrient(nutrient),
          ),
        _TotalRow(
          label: strings.t('water'),
          value: day.waterMl,
          unit: 'ml',
          goal: settings.goals.waterMl,
        ),
        _TotalRow(
          label: strings.t('caffeine'),
          value: day.total(Nutrient.caffeine),
          unit: 'mg',
        ),
        if (day.foodEntryCount > 0 &&
            Nutrient.values.any(
              (nutrient) =>
                  day.knownFoodEntries[nutrient.id]! < day.foodEntryCount,
            ))
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Text(
              strings.t('incomplete_nutrients'),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ),
        _NutrientGroupTotals(day: day, group: NutrientGroup.additional),
        _NutrientGroupTotals(day: day, group: NutrientGroup.vitamin),
        _NutrientGroupTotals(day: day, group: NutrientGroup.mineral),
      ],
    );
  }
}

class _NutrientGroupTotals extends StatelessWidget {
  const _NutrientGroupTotals({required this.day, required this.group});
  final NutritionDay day;
  final NutrientGroup group;

  @override
  Widget build(BuildContext context) {
    final strings = l10n(context);
    final title = switch (group) {
      NutrientGroup.additional => 'additional_nutrients',
      NutrientGroup.vitamin => 'vitamins',
      NutrientGroup.mineral => 'minerals',
      NutrientGroup.main => 'main_nutrients',
    };
    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      childrenPadding: EdgeInsets.zero,
      title: Text(strings.t(title)),
      children: [
        for (final nutrient in Nutrient.values.where(
          (item) => item.group == group,
        ))
          _TotalRow(nutrient: nutrient, value: day.total(nutrient)),
      ],
    );
  }
}

class _TotalRow extends StatelessWidget {
  const _TotalRow({
    this.nutrient,
    this.label,
    this.unit,
    required this.value,
    this.goal,
  });

  final Nutrient? nutrient;
  final String? label;
  final String? unit;
  final double value;
  final double? goal;

  @override
  Widget build(BuildContext context) {
    final strings = l10n(context);
    final resolvedLabel = label ?? strings.nutrient(nutrient!);
    final resolvedUnit = unit ?? nutrient!.unit;
    final progress = goal != null && goal! > 0
        ? (value / goal!).clamp(0.0, 1.0)
        : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: Text(resolvedLabel)),
              Text(
                '${strings.amount(value, resolvedUnit)}'
                '${goal == null ? '' : ' / ${strings.amount(goal!, resolvedUnit)}'}',
              ),
            ],
          ),
          if (progress != null) ...[
            const SizedBox(height: 5),
            LinearProgressIndicator(value: progress, minHeight: 5),
          ],
        ],
      ),
    );
  }
}

class IntakeTile extends StatelessWidget {
  const IntakeTile({super.key, required this.entry});
  final IntakeEntry entry;

  @override
  Widget build(BuildContext context) {
    final strings = l10n(context);
    final controller = context.read<AppController>();
    final title = switch (entry.kind) {
      IntakeKind.food => entry.foodName,
      IntakeKind.water => strings.t('water'),
      IntakeKind.caffeine => strings.t('caffeine'),
    };
    final unit = entry.unit == 'portion' ? strings.t('portions') : entry.unit;
    final calories = entry.amountOf(Nutrient.calories);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: Text(
        '${strings.time(entry.occurredAt)} · ${strings.amount(entry.amount, unit)}'
        '${entry.kind == IntakeKind.food ? ' · ${strings.meal(entry.meal)}' : ''}'
        '${calories == null ? '' : ' · ${strings.amount(calories, 'kcal')}'}'
        '${entry.notes.isEmpty ? '' : '\n${entry.notes}'}',
      ),
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => entry.kind == IntakeKind.food
              ? IntakeEditPage(existing: entry)
              : SimpleIntakeEditPage(existing: entry),
        ),
      ),
      trailing: PopupMenuButton<String>(
        onSelected: (action) async {
          if (action == 'repeat') {
            try {
              await controller.repository.repeatIntake(entry.id);
            } catch (_) {
              if (context.mounted) showError(context);
            }
          } else if (action == 'delete' && await confirmDeletion(context)) {
            try {
              await controller.repository.deleteIntake(entry.id);
            } catch (_) {
              if (context.mounted) showError(context);
            }
          } else if (action == 'edit') {
            if (!context.mounted) return;
            Navigator.push(
              context,
              MaterialPageRoute<void>(
                builder: (_) => entry.kind == IntakeKind.food
                    ? IntakeEditPage(existing: entry)
                    : SimpleIntakeEditPage(existing: entry),
              ),
            );
          }
        },
        itemBuilder: (context) => [
          PopupMenuItem(value: 'repeat', child: Text(strings.t('repeat'))),
          PopupMenuItem(value: 'edit', child: Text(strings.t('edit'))),
          PopupMenuItem(value: 'delete', child: Text(strings.t('delete'))),
        ],
      ),
    );
  }
}

class IntakeEditPage extends StatefulWidget {
  const IntakeEditPage({super.key, this.food, this.existing});
  final Food? food;
  final IntakeEntry? existing;

  @override
  State<IntakeEditPage> createState() => _IntakeEditPageState();
}

class _IntakeEditPageState extends State<IntakeEditPage> {
  final form = GlobalKey<FormState>();
  late final TextEditingController amount;
  late final TextEditingController notes;
  late DateTime timestamp;
  late String meal;
  late String unit;
  bool saving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    amount = TextEditingController(
      text: existing == null ? '100' : existing.amount.toString(),
    );
    notes = TextEditingController(text: existing?.notes ?? '');
    if (existing != null) {
      timestamp = existing.occurredAt;
    } else {
      final controller = context.read<AppController>();
      final selected = parseDate(controller.selectedDate);
      final current = controller.now.toLocal();
      timestamp = DateTime(
        selected.year,
        selected.month,
        selected.day,
        current.hour,
        current.minute,
      );
    }
    meal = existing?.meal ?? 'breakfast';
    unit = existing?.unit ?? widget.food?.measure ?? 'g';
  }

  @override
  void dispose() {
    amount.dispose();
    notes.dispose();
    super.dispose();
  }

  Map<String, double> get nutrients =>
      widget.food?.nutrients ?? widget.existing!.nutrients;
  double? get portionSize =>
      widget.food?.portionSize ?? widget.existing?.portionSize;

  Future<void> save() async {
    if (!form.currentState!.validate() || saving) return;
    final controller = context.read<AppController>();
    setState(() => saving = true);
    try {
      final parsed = parseAmount(amount.text)!;
      final existing = widget.existing;
      if (existing != null) {
        await controller.repository.saveIntake(
          IntakeEntry(
            id: existing.id,
            kind: existing.kind,
            occurredAt: timestamp.toUtc(),
            meal: meal,
            foodId: existing.foodId,
            foodName: existing.foodName,
            brand: existing.brand,
            amount: parsed,
            unit: unit,
            portionSize: portionSize,
            nutrients: existing.nutrients,
            notes: notes.text.trim(),
            createdAt: existing.createdAt,
            updatedAt: controller.now,
          ),
        );
      } else {
        final food = await controller.importFood(widget.food!);
        await controller.repository.saveIntake(
          IntakeEntry(
            id: newId(),
            kind: IntakeKind.food,
            occurredAt: timestamp.toUtc(),
            meal: meal,
            foodId: food.id,
            foodName: food.name,
            brand: food.brand,
            amount: parsed,
            unit: unit,
            portionSize: food.portionSize,
            nutrients: food.nutrients,
            notes: notes.text.trim(),
            createdAt: controller.now,
            updatedAt: controller.now,
          ),
        );
      }
      if (!mounted) return;
      Navigator.pop(context);
    } catch (_) {
      if (!mounted) return;
      showError(context);
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = l10n(context);
    final existing = widget.existing;
    final title = existing?.foodName ?? widget.food?.name ?? '';
    final measure =
        widget.food?.measure ?? (existing?.unit == 'ml' ? 'ml' : 'g');
    final units = <String>[measure, if (portionSize != null) 'portion'];
    if (!units.contains(unit)) unit = measure;
    final factor = unit == 'portion'
        ? (parseAmount(amount.text) ?? 0) * (portionSize ?? 0) / 100
        : (parseAmount(amount.text) ?? 0) / 100;
    return Scaffold(
      appBar: AppBar(
        title: Text(strings.t(existing == null ? 'add_intake' : 'edit_intake')),
      ),
      body: Form(
        key: form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(title, style: Theme.of(context).textTheme.headlineSmall),
            if ((existing?.brand ?? widget.food?.brand ?? '').isNotEmpty)
              Text(existing?.brand ?? widget.food!.brand),
            const SizedBox(height: 16),
            DateTimeFields(
              value: timestamp,
              onChanged: (value) => setState(() => timestamp = value),
            ),
            const SizedBox(height: 12),
            TextFormField(
              key: const ValueKey('intake-amount'),
              controller: amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: fieldDecoration(strings.t('amount')),
              onChanged: (_) => setState(() {}),
              validator: (value) {
                final parsed = parseAmount(value ?? '');
                if (parsed == null) return strings.t('invalid_number');
                if (parsed <= 0) return strings.t('positive_number');
                return null;
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: unit,
              decoration: fieldDecoration(strings.t('unit')),
              items: [
                for (final item in units)
                  DropdownMenuItem(
                    value: item,
                    child: Text(switch (item) {
                      'g' => strings.t('grams'),
                      'ml' => strings.t('milliliters'),
                      _ => strings.t('portions'),
                    }),
                  ),
              ],
              onChanged: (value) => setState(() => unit = value ?? unit),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: meal,
              decoration: fieldDecoration(strings.t('meal')),
              items: [
                for (final item in ['breakfast', 'lunch', 'dinner', 'snack'])
                  DropdownMenuItem(
                    value: item,
                    child: Text(strings.meal(item)),
                  ),
              ],
              onChanged: (value) => setState(() => meal = value ?? meal),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: notes,
              maxLines: 3,
              decoration: fieldDecoration(
                '${strings.t('notes')} (${strings.t('optional')})',
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '${strings.nutrient(Nutrient.calories)}: '
              '${nutrients[Nutrient.calories.id] == null ? strings.t('unknown_nutrient') : strings.amount(nutrients[Nutrient.calories.id]! * factor, 'kcal')}\n'
              '${strings.nutrient(Nutrient.protein)}: '
              '${nutrients[Nutrient.protein.id] == null ? '–' : strings.amount(nutrients[Nutrient.protein.id]! * factor, 'g')} · '
              '${strings.nutrient(Nutrient.carbs)}: '
              '${nutrients[Nutrient.carbs.id] == null ? '–' : strings.amount(nutrients[Nutrient.carbs.id]! * factor, 'g')} · '
              '${strings.nutrient(Nutrient.fat)}: '
              '${nutrients[Nutrient.fat.id] == null ? '–' : strings.amount(nutrients[Nutrient.fat.id]! * factor, 'g')}',
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              key: const ValueKey('save-intake'),
              onPressed: saving ? null : save,
              icon: const Icon(Icons.check),
              label: Text(strings.t('save')),
            ),
            if (existing != null)
              TextButton.icon(
                onPressed: () async {
                  if (!await confirmDeletion(context) || !context.mounted)
                    return;
                  try {
                    await context.read<AppController>().repository.deleteIntake(
                      existing.id,
                    );
                    if (!context.mounted) return;
                    Navigator.pop(context);
                  } catch (_) {
                    if (!context.mounted) return;
                    showError(context);
                  }
                },
                icon: const Icon(Icons.delete_outline),
                label: Text(strings.t('delete')),
              ),
          ],
        ),
      ),
    );
  }
}

class SimpleIntakeEditPage extends StatefulWidget {
  const SimpleIntakeEditPage({super.key, required this.existing});
  final IntakeEntry existing;

  @override
  State<SimpleIntakeEditPage> createState() => _SimpleIntakeEditPageState();
}

class _SimpleIntakeEditPageState extends State<SimpleIntakeEditPage> {
  final form = GlobalKey<FormState>();
  late final TextEditingController amount;
  late final TextEditingController notes;
  late DateTime timestamp;

  @override
  void initState() {
    super.initState();
    amount = TextEditingController(text: widget.existing.amount.toString());
    notes = TextEditingController(text: widget.existing.notes);
    timestamp = widget.existing.occurredAt;
  }

  @override
  void dispose() {
    amount.dispose();
    notes.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final strings = l10n(context);
    final entry = widget.existing;
    final title = strings.t(
      entry.kind == IntakeKind.water ? 'water' : 'caffeine',
    );
    return Scaffold(
      appBar: AppBar(title: Text('${strings.t('edit')}: $title')),
      body: Form(
        key: form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DateTimeFields(
              value: timestamp,
              onChanged: (value) => setState(() => timestamp = value),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: amount,
              decoration: fieldDecoration(
                strings.t('amount'),
                suffix: entry.unit,
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: (value) {
                final parsed = parseAmount(value ?? '');
                if (parsed == null) return strings.t('invalid_number');
                if (parsed <= 0) return strings.t('positive_number');
                return null;
              },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: notes,
              maxLines: 3,
              decoration: fieldDecoration(strings.t('notes')),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: () async {
                if (!form.currentState!.validate()) return;
                try {
                  await context.read<AppController>().repository.saveIntake(
                    IntakeEntry(
                      id: entry.id,
                      kind: entry.kind,
                      occurredAt: timestamp.toUtc(),
                      meal: entry.meal,
                      amount: parseAmount(amount.text)!,
                      unit: entry.unit,
                      nutrients: entry.nutrients,
                      notes: notes.text.trim(),
                      createdAt: entry.createdAt,
                      updatedAt: context.read<AppController>().now,
                    ),
                  );
                  if (!context.mounted) return;
                  Navigator.pop(context);
                } catch (_) {
                  if (!context.mounted) return;
                  showError(context);
                }
              },
              child: Text(strings.t('save')),
            ),
            TextButton(
              onPressed: () async {
                if (!await confirmDeletion(context) || !context.mounted) return;
                await context.read<AppController>().repository.deleteIntake(
                  entry.id,
                );
                if (!context.mounted) return;
                Navigator.pop(context);
              },
              child: Text(strings.t('delete')),
            ),
          ],
        ),
      ),
    );
  }
}

class GoalsPage extends StatefulWidget {
  const GoalsPage({super.key});

  @override
  State<GoalsPage> createState() => _GoalsPageState();
}

class _GoalsPageState extends State<GoalsPage> {
  final form = GlobalKey<FormState>();
  late final Map<String, TextEditingController> controllers;

  @override
  void initState() {
    super.initState();
    final goals = context.read<AppController>().settings.goals;
    controllers = {
      'water_ml': TextEditingController(text: goals.waterMl?.toString() ?? ''),
      'calories': TextEditingController(text: goals.calories?.toString() ?? ''),
      'protein': TextEditingController(text: goals.protein?.toString() ?? ''),
      'carbs': TextEditingController(text: goals.carbs?.toString() ?? ''),
      'fat': TextEditingController(text: goals.fat?.toString() ?? ''),
    };
  }

  @override
  void dispose() {
    for (final controller in controllers.values) controller.dispose();
    super.dispose();
  }

  double? value(String key) => parseAmount(controllers[key]!.text);

  @override
  Widget build(BuildContext context) {
    final strings = l10n(context);
    final labels = {
      'water_ml': 'goal_water',
      'calories': 'goal_calories',
      'protein': 'goal_protein',
      'carbs': 'goal_carbs',
      'fat': 'goal_fat',
    };
    return Scaffold(
      appBar: AppBar(title: Text(strings.t('goals'))),
      body: Form(
        key: form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(strings.t('goals_help')),
            const SizedBox(height: 16),
            for (final entry in labels.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: TextFormField(
                  controller: controllers[entry.key],
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: fieldDecoration(strings.t(entry.value)),
                  validator: (text) {
                    if (text == null || text.trim().isEmpty) return null;
                    final parsed = parseAmount(text);
                    if (parsed == null) return strings.t('invalid_number');
                    if (parsed <= 0) return strings.t('positive_number');
                    return null;
                  },
                ),
              ),
            FilledButton(
              onPressed: () async {
                if (!form.currentState!.validate()) return;
                final controller = context.read<AppController>();
                try {
                  await controller.repository.updateSettings(
                    controller.settings.copyWith(
                      goals: Goals(
                        waterMl: value('water_ml'),
                        calories: value('calories'),
                        protein: value('protein'),
                        carbs: value('carbs'),
                        fat: value('fat'),
                      ),
                    ),
                  );
                  if (!context.mounted) return;
                  Navigator.pop(context);
                } catch (_) {
                  if (!context.mounted) return;
                  showError(context);
                }
              },
              child: Text(strings.t('save')),
            ),
          ],
        ),
      ),
    );
  }
}
