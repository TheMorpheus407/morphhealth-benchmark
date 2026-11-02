import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import 'cycle_calendar_view.dart';
import 'cycle_views.dart';
import 'period_editor_sheet.dart';

/// The period tracker: calendar, history and the personal assessment.
class CyclePage extends StatefulWidget {
  const CyclePage({super.key});

  @override
  State<CyclePage> createState() => _CyclePageState();
}

class _CyclePageState extends State<CyclePage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('cycle.title')),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: <Widget>[
            Tab(text: l10n.t('cycle.title')),
            Tab(text: l10n.t('cycle.history')),
            Tab(text: l10n.t('cycle.forecast')),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => PeriodEditorSheet.show(context),
        icon: const Icon(Icons.add),
        label: Text(l10n.t('cycle.add_period')),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const <Widget>[
          CycleCalendarView(),
          CycleHistoryView(),
          CycleForecastView(),
        ],
      ),
    );
  }
}
