import 'package:flutter/material.dart';
import 'package:morphhealth_core/morphhealth_core.dart';

import '../l10n/app_localizations.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import 'home_shell.dart';

/// Shows every tracked nutrient of the selected day.
class NutritionNutrientsView extends StatelessWidget {
  const NutritionNutrientsView({required this.date, super.key});

  final String date;

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final DayNutrition day = state.nutrition.day(date);

    final List<NutrientSpec> energy = Nutrients.all
        .where((NutrientSpec s) => s.group == NutrientGroup.energy)
        .toList(growable: false);
    final List<NutrientSpec> macros = Nutrients.macros;
    final List<NutrientSpec> extended = Nutrients.extended;
    final List<NutrientSpec> vitamins = Nutrients.vitamins;
    final List<NutrientSpec> minerals = Nutrients.minerals;

    Widget group(String title, List<NutrientSpec> specs) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 14, 4, 6),
            child: Text(
              title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          for (final NutrientSpec spec in specs)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      l10n.nutrientLabel(spec.id),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  Text(
                    _format(spec.toDisplay(day.totals[spec.id])),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(
                    width: 54,
                    child: Text(
                      spec.unitLabel,
                      textAlign: TextAlign.right,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      children: <Widget>[
        SectionCard(
          title: l10n.t('nutrition.nutrients'),
          subtitle: formatDay(context, date, withYear: true),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              group(l10n.t('common.total'), energy),
              group(l10n.t('nutrition.nutrients'), macros),
              group(l10n.t('nutrition.nutrients_micro'), extended),
              group(l10n.t('nutrition.nutrients_micro'), vitamins),
              group(l10n.t('nutrition.nutrients_micro'), minerals),
            ],
          ),
        ),
      ],
    );
  }

  static String _format(double value) {
    if (value == 0) return '0';
    if (value.abs() < 0.01) return value.toStringAsFixed(3);
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(1);
  }
}

/// Shows the development of one nutrient over 7 or 28 days.
class NutritionTrendView extends StatefulWidget {
  const NutritionTrendView({super.key});

  @override
  State<NutritionTrendView> createState() => _NutritionTrendViewState();
}

class _NutritionTrendViewState extends State<NutritionTrendView> {
  String _nutrient = Nutrients.energyKcal;
  int _days = 7;

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final String today = DateMath.format(DateTime.now());
    final String from = DateMath.addDays(today, -(_days - 1));
    final List<DayNutrition> data = state.nutrition.days(from, today);
    final List<double> values = <double>[
      for (final DayNutrition day in data)
        day.totals[_nutrient] * _factor(_nutrient),
    ];

    final List<NutrientSpec> options = <NutrientSpec>[
      Nutrients.specOf(Nutrients.energyKcal)!,
      ...Nutrients.macros,
      ...Nutrients.extended,
      ...Nutrients.vitamins,
      ...Nutrients.minerals,
    ];

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      children: <Widget>[
        SectionCard(
          title: l10n.t('nutrition.trend'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _nutrient,
                      isExpanded: true,
                      decoration: InputDecoration(
                        labelText: l10n.t('nutrition.trend_select'),
                      ),
                      items: <DropdownMenuItem<String>>[
                        for (final NutrientSpec spec in options)
                          DropdownMenuItem<String>(
                            value: spec.id,
                            child: Text(
                              l10n.nutrientLabel(spec.id),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (String? value) {
                        if (value == null) return;
                        setState(() => _nutrient = value);
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  SegmentedSwitch<int>(
                    value: _days,
                    options: const <int, String>{7: '7', 28: '28'},
                    onChanged: (int value) => setState(() => _days = value),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              if (values.every((double v) => v == 0))
                EmptyState(message: l10n.t('nutrition.no_trend_data'))
              else
                SimpleLineChart(
                  values: values,
                  labels: <String>[
                    formatDay(context, from),
                    formatDay(context, today),
                  ],
                ),
              const SizedBox(height: 10),
              Text(
                l10n.t(
                  'nutrition.trend_days',
                  <String, String>{'days': '$_days'},
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SectionCard(
          title: l10n.t('common.total'),
          child: Column(
            children: <Widget>[
              for (int i = data.length - 1; i >= 0; i--)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          formatDay(context, data[i].date),
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                      Text(
                        _format(values[i]),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      SizedBox(
                        width: 48,
                        child: Text(
                          Nutrients.specOf(_nutrient)!.unitLabel,
                          textAlign: TextAlign.right,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  static double _factor(String nutrientId) {
    if (nutrientId == Nutrients.energyKcal) return 1;
    final NutrientSpec spec = Nutrients.specOf(nutrientId)!;
    return spec.toDisplay(1.0);
  }

  static String _format(double value) {
    if (value == 0) return '0';
    if (value.abs() < 0.01) return value.toStringAsFixed(3);
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(1);
  }
}

/// Daily goals the user defines for water, calories and the macros.
class NutritionGoalsView extends StatefulWidget {
  const NutritionGoalsView({super.key});

  @override
  State<NutritionGoalsView> createState() => _NutritionGoalsViewState();
}

class _NutritionGoalsViewState extends State<NutritionGoalsView> {
  final Map<String, TextEditingController> _controllers =
      <String, TextEditingController>{};
  bool _initialised = false;

  @override
  void dispose() {
    for (final TextEditingController controller in _controllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _init(Goals goals) {
    if (_initialised) return;
    _initialised = true;
    _controllers[Nutrients.energyKcal] = _controller(goals.caloriesKcal);
    _controllers[Nutrients.protein] = _controller(goals.proteinG);
    _controllers[Nutrients.carbohydrates] = _controller(goals.carbohydratesG);
    _controllers[Nutrients.fat] = _controller(goals.fatG);
    _controllers['water'] = _controller(goals.waterMl);
  }

  TextEditingController _controller(double? value) => TextEditingController(
        text: value == null ? '' : _trim(value),
      );

  static String _trim(double value) {
    if (value == value.roundToDouble()) return value.toInt().toString();
    return value.toStringAsFixed(1);
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final AppLocalizations l10n = context.l10n;
    _init(state.goals);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      children: <Widget>[
        SectionCard(
          title: l10n.t('nutrition.goals'),
          subtitle: l10n.t('nutrition.goals_hint'),
          child: Column(
            children: <Widget>[
              _field(Nutrients.energyKcal, l10n.t('nutrition.goal_calories')),
              _field(Nutrients.protein, l10n.t('nutrition.goal_protein')),
              _field(
                Nutrients.carbohydrates,
                l10n.t('nutrition.goal_carbs'),
              ),
              _field(Nutrients.fat, l10n.t('nutrition.goal_fat')),
              _field('water', l10n.t('nutrition.goal_water')),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.check),
                  label: Text(l10n.t('common.save')),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _field(String id, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: _controllers[id],
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(labelText: label, isDense: true),
      ),
    );
  }

  Future<void> _save() async {
    final AppState state = AppScope.of(context);
    double? read(String id) => double.tryParse(
          (_controllers[id]?.text ?? '').replaceAll(',', '.'),
        );
    await state.setGoals(Goals(
      waterMl: read('water'),
      caloriesKcal: read(Nutrients.energyKcal),
      proteinG: read(Nutrients.protein),
      carbohydratesG: read(Nutrients.carbohydrates),
      fatG: read(Nutrients.fat),
    ));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.t('common.saved'))),
    );
  }
}
