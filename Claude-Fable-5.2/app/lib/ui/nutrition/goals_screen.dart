import 'package:flutter/material.dart';
import 'package:morphhealth_core/morphhealth_core.dart';

import '../format.dart';
import '../widgets/common.dart';

/// The voluntary daily goals for water, calories and the macronutrients.
class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _water = TextEditingController();
  final _energy = TextEditingController();
  final _protein = TextEditingController();
  final _carbs = TextEditingController();
  final _fat = TextEditingController();
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final app = context.appRead;
    final fmt = Fmt.of(context, today: app.today);
    final g = app.goals;
    void set(TextEditingController c, double? v) {
      if (v != null) c.text = fmt.editable(v);
    }

    set(_water, g.waterMl);
    set(_energy, g.energyKcal);
    set(_protein, g.proteinG);
    set(_carbs, g.carbohydratesG);
    set(_fat, g.fatG);
  }

  @override
  void dispose() {
    for (final c in [_water, _energy, _protein, _carbs, _fat]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final goals = Goals(
      waterMl: Fmt.parse(_water.text),
      energyKcal: Fmt.parse(_energy.text),
      proteinG: Fmt.parse(_protein.text),
      carbohydratesG: Fmt.parse(_carbs.text),
      fatG: Fmt.parse(_fat.text),
    );
    final l = context.l;
    final ok = await guarded(
      context,
      () => context.appRead.repository.updateGoals(goals),
    );
    if (ok && mounted) {
      Navigator.of(context).pop();
      showSnack(context, l.saved);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    Widget field(
      TextEditingController c,
      String what,
      String unit,
      double max,
    ) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: NumberField(
        controller: c,
        label: l.goalFor(what, unit),
        unit: unit,
        allowZero: false,
        max: max,
        textInputAction: TextInputAction.next,
      ),
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(l.goals),
        actions: [
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: TextButton(onPressed: _save, child: Text(l.save)),
          ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              Text(l.goalsIntro, style: context.texts.bodyMedium),
              const SizedBox(height: 16),
              field(_water, l.water, 'ml', 20000),
              field(_energy, l.nutrient(Nutrients.energy), 'kcal', 20000),
              field(_protein, l.nutrient(Nutrients.protein), 'g', 2000),
              field(_carbs, l.nutrient(Nutrients.carbohydrates), 'g', 5000),
              field(_fat, l.nutrient(Nutrients.fat), 'g', 2000),
              const SizedBox(height: 8),
              FilledButton(onPressed: _save, child: Text(l.save)),
            ],
          ),
        ),
      ),
    );
  }
}
