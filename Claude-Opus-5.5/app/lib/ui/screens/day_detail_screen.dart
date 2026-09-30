import 'package:flutter/material.dart';

import '../../core/model/enums.dart';
import '../../core/util/local_date.dart';
import '../controller.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/date_nav.dart';
import 'cycle/cycle_day_sheet.dart';
import 'nutrition/intake_cards.dart';
import 'nutrition/nutrition_screen.dart';
import 'symptoms/symptom_editor.dart';
import 'symptoms/symptoms_screen.dart';
import 'weight/weight_screen.dart';

/// Everything recorded on one day: nutrition, water/caffeine, weight,
/// period records and symptoms (independent of the overview settings).
class DayDetailScreen extends StatefulWidget {
  const DayDetailScreen({super.key, required this.date});

  final LocalDate date;

  @override
  State<DayDetailScreen> createState() => _DayDetailScreenState();
}

class _DayDetailScreenState extends State<DayDetailScreen> {
  late LocalDate _date = widget.date;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final s = app.s;
    final fmt = app.fmt;
    final data = app.data;
    final day = app.service.nutritionDay(_date);
    final period = data.periodOn(_date, app.today);
    final inPeriod = period != null && !_date.isAfter(app.today);
    final cycleDay = data.cycleDayOn(_date);
    final weights = data.weightsOn(_date);
    final symptoms = data.symptomsOn(_date);
    final empty = !data.hasDataOn(_date) && !inPeriod;

    return Scaffold(
      appBar: AppBar(title: Text(s.dayDetailTitle)),
      body: ListView(
        padding: pagePadding(context, horizontal: 12, top: 4),
        children: [
          DateNavigator(date: _date, onChanged: (d) => setState(() => _date = d)),
          if (empty) EmptyHint(s.nothingLoggedOnDay, icon: Icons.event_available_outlined),
          const SizedBox(height: 4),
          NutritionSummaryCard(day: day, title: s.areaName(Area.nutrition)),
          const SizedBox(height: 12),
          for (final meal in Meal.values)
            if (day.entriesFor(meal).isNotEmpty) ...[
              MealCard(day: day, meal: meal),
              const SizedBox(height: 12),
            ],
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => openFoodSearch(context, _date, null),
              icon: const Icon(Icons.add),
              label: Text(s.addFood),
            ),
          ),
          WaterCard(date: _date),
          const SizedBox(height: 12),
          CaffeineCard(date: _date),
          const SizedBox(height: 12),
          SectionCard(
            title: s.cycleOnDay,
            icon: Icons.water_drop_outlined,
            iconColor: context.colors.cycle,
            onTap: () => showCycleDaySheet(context, _date),
            trailing: const Icon(Icons.chevron_right),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(inPeriod ? s.dayInPeriod(period.start.daysUntil(_date) + 1) : s.notInPeriod),
                if (inPeriod)
                  Text(
                    period.end == null
                        ? '${fmt.medium(period.start)} – ${s.periodStillOngoing}'
                        : '${fmt.medium(period.start)} – ${fmt.medium(period.end!)}',
                    style: context.text.bodySmall,
                  ),
                if (cycleDay?.flow != null) Text('${s.flow}: ${s.flowName(cycleDay!.flow!)}'),
                if (cycleDay?.note != null) Text('${s.note}: ${cycleDay!.note}'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: s.weight,
            icon: Icons.monitor_weight_outlined,
            iconColor: context.colors.weight,
            trailing: IconButton(
              tooltip: s.addWeight,
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () => openWeightEditor(context, date: _date),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (weights.isEmpty) EmptyHint(s.noWeightYet),
                for (final w in weights) WeightTile(entry: w),
              ],
            ),
          ),
          const SizedBox(height: 12),
          SectionCard(
            title: s.navSymptoms,
            icon: Icons.healing_outlined,
            iconColor: context.colors.symptoms,
            trailing: IconButton(
              tooltip: s.addSymptom,
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () => openSymptomEditor(context, date: _date),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (symptoms.isEmpty) EmptyHint(s.noSymptomsOnDay),
                for (final e in symptoms) SymptomTile(entry: e),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
