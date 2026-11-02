import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../state/app_state.dart';
import 'food_search_sheet.dart';
import 'nutrition_day_view.dart';
import 'nutrition_views.dart';

/// The food diary with the day view, the nutrients, the trend and the goals.
class NutritionPage extends StatefulWidget {
  const NutritionPage({super.key});

  @override
  State<NutritionPage> createState() => _NutritionPageState();
}

class _NutritionPageState extends State<NutritionPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final AppLocalizations l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('nutrition.title')),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: <Widget>[
            Tab(text: l10n.t('day.title')),
            Tab(text: l10n.t('nutrition.nutrients')),
            Tab(text: l10n.t('nutrition.trend')),
            Tab(text: l10n.t('nutrition.goals')),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => FoodPickerSheet.show(context),
        icon: const Icon(Icons.add),
        label: Text(l10n.t('nutrition.add_entry')),
      ),
      body: TabBarView(
        controller: _tabs,
        children: <Widget>[
          NutritionDayView(date: state.selectedDate),
          NutritionNutrientsView(date: state.selectedDate),
          const NutritionTrendView(),
          const NutritionGoalsView(),
        ],
      ),
    );
  }
}
