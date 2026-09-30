import 'package:flutter/material.dart';

import '../../../core/util/local_date.dart';
import '../../controller.dart';
import '../../widgets/common.dart';
import 'nutrient_list.dart';

/// All nutrients of one day, with data coverage and estimate markers.
class DayNutrientsScreen extends StatelessWidget {
  const DayNutrientsScreen({super.key, required this.date});

  final LocalDate date;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final s = app.s;
    final day = app.service.nutritionDay(date);
    final total = day.entries.length;
    return Scaffold(
      appBar: AppBar(title: Text('${s.allNutrients} · ${app.fmt.weekdayDayMonth(date)}')),
      body: ListView(
        padding: pagePadding(context),
        children: [
          if (total == 0) EmptyHint(s.noFoodLogged, icon: Icons.restaurant_outlined),
          NutrientList(
            valueOf: (n) => day.totals[n.key],
            isEstimated: (n) => day.totals.estimated.contains(n.key),
            coverageOf: (n) {
              final known = day.totals.knownCount[n.key] ?? 0;
              if (total == 0 || known == total || known == 0) return null;
              return s.coverage(known, total);
            },
            extraCaffeineMg: day.caffeineAdditionalMg,
          ),
        ],
      ),
    );
  }
}
