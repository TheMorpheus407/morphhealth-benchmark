import 'package:flutter/material.dart';

import '../../core/models.dart';
import '../../core/nutrients.dart';
import '../../state/app_state.dart';
import '../format.dart';
import '../l10n_x.dart';
import '../widgets/common.dart';
import '../widgets/fields.dart';

/// Freiwillige Tagesziele für Wasser, Kalorien und die drei Makronährstoffe.
class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  final _form = GlobalKey<FormState>();
  final _water = TextEditingController();
  final _energy = TextEditingController();
  final _protein = TextEditingController();
  final _carbs = TextEditingController();
  final _fat = TextEditingController();
  bool _init = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_init) return;
    _init = true;
    final app = AppScope.read(context);
    final f = Fmt(app.lang);
    final g = app.db.goals;
    String s(double? v) => v == null ? '' : f.input(v, 1);
    _water.text = s(g.waterMl);
    _energy.text = s(g.energyKcal);
    _protein.text = s(g.proteinG);
    _carbs.text = s(g.carbohydratesG);
    _fat.text = s(g.fatG);
  }

  @override
  void dispose() {
    for (final c in [_water, _energy, _protein, _carbs, _fat]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final app = AppScope.read(context);
    final l = context.l10n;
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    double? p(TextEditingController c) {
      final v = Fmt.parse(c.text);
      return v == null || v <= 0 ? null : v;
    }

    await app.db.saveGoals(
      Goals(
        waterMl: p(_water),
        energyKcal: p(_energy),
        proteinG: p(_protein),
        carbohydratesG: p(_carbs),
        fatG: p(_fat),
      ),
    );
    nav.pop();
    messenger.showSnackBar(SnackBar(content: Text(l.goalSaved)));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final lang = Localizations.localeOf(context).languageCode;
    return AppScaffold(
      appBar: AppBar(title: Text(l.settingsGoals)),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            EmptyHint(l.goalsHint, icon: Icons.info_outline),
            const SizedBox(height: 12),
            NumberField(controller: _water, label: l.goalWater, suffix: 'ml', max: 20000),
            const SizedBox(height: 16),
            NumberField(controller: _energy, label: l.goalEnergy, suffix: 'kcal', max: 20000),
            const SizedBox(height: 16),
            NumberField(controller: _protein, label: nutrientName(kProtein, lang), suffix: 'g', max: 2000),
            const SizedBox(height: 16),
            NumberField(controller: _carbs, label: nutrientName(kCarbs, lang), suffix: 'g', max: 3000),
            const SizedBox(height: 16),
            NumberField(controller: _fat, label: nutrientName(kFat, lang), suffix: 'g', max: 2000),
            const SizedBox(height: 24),
            FilledButton.icon(
              style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
              onPressed: _save,
              icon: const Icon(Icons.check),
              label: Text(l.commonSave),
            ),
          ],
        ),
      ),
    );
  }
}
