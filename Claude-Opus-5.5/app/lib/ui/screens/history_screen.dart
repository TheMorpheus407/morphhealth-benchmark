import 'package:flutter/material.dart';

import '../../core/history/history.dart';
import '../../core/model/enums.dart';
import '../../core/util/local_date.dart';
import '../controller.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'cycle/cycle_day_sheet.dart';
import 'cycle/period_editor.dart';
import 'nutrition/intake_cards.dart';
import 'nutrition/log_food_screen.dart';
import 'symptoms/symptom_editor.dart';
import 'weight/weight_screen.dart';

/// Searchable history across all four areas with area, date range and
/// free-text filters. Entries open in their editors.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _text = TextEditingController();
  final Set<Area> _areas = {};
  LocalDate? _from;
  LocalDate? _to;

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  Future<void> _pickRange() async {
    final app = context.appRead;
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100, 12, 31),
      initialDateRange: _from == null
          ? null
          : DateTimeRange(start: _from!.toDateTime(), end: _to!.toDateTime()),
      currentDate: app.today.toDateTime(),
    );
    if (range != null) {
      setState(() {
        _from = LocalDate.fromDateTime(range.start);
        _to = LocalDate.fromDateTime(range.end);
      });
    }
  }

  Future<void> _open(HistoryItem item) async {
    final app = context.appRead;
    final data = app.data;
    switch (item.kind) {
      case HistoryKind.food:
        final e = data.foodEntries[item.id];
        if (e != null) {
          await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => LogFoodScreen.edit(entry: e)));
        }
      case HistoryKind.water:
        final e = data.waterEntries[item.id];
        if (e != null) await editWater(context, e);
      case HistoryKind.caffeine:
        final e = data.caffeineEntries[item.id];
        if (e != null) await editCaffeine(context, e);
      case HistoryKind.period:
        final p = data.periods[item.id];
        if (p != null) await openPeriodEditor(context, period: p);
      case HistoryKind.cycleDay:
        await showCycleDaySheet(context, item.date);
      case HistoryKind.weight:
        final e = data.weightEntries[item.id];
        if (e != null) await openWeightEditor(context, entry: e);
      case HistoryKind.symptom:
        final e = data.symptomEntries[item.id];
        if (e != null) await openSymptomEditor(context, entry: e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final s = app.s;
    final fmt = app.fmt;
    final results = app.service.historyIndex().filter(
      HistoryQuery(text: _text.text, areas: _areas, from: _from, to: _to),
    );
    // Flatten into date headers and items for a lazy list.
    final rows = <Object>[];
    LocalDate? current;
    for (final item in results) {
      if (item.date != current) {
        current = item.date;
        rows.add(item.date);
      }
      rows.add(item);
    }
    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _text,
          autofocus: false,
          textInputAction: TextInputAction.search,
          decoration: InputDecoration(
            hintText: s.historySearchHint,
            border: InputBorder.none,
            prefixIcon: const Icon(Icons.search),
            suffixIcon: _text.text.isEmpty
                ? null
                : IconButton(
                    tooltip: s.clear,
                    icon: const Icon(Icons.clear),
                    onPressed: () => setState(_text.clear),
                  ),
          ),
          onChanged: (_) => setState(() {}),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Row(
              children: [
                for (final area in Area.values)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      avatar: Icon(areaIcon(area), size: 18, color: context.colors.area(area)),
                      label: Text(s.areaName(area)),
                      selected: _areas.contains(area),
                      onSelected: (on) => setState(() => on ? _areas.add(area) : _areas.remove(area)),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickRange,
                    icon: const Icon(Icons.date_range),
                    label: Text(
                      _from == null ? s.anyDate : '${fmt.medium(_from!)} – ${fmt.medium(_to!)}',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                if (_from != null)
                  IconButton(
                    tooltip: s.clear,
                    icon: const Icon(Icons.close),
                    onPressed: () => setState(() {
                      _from = null;
                      _to = null;
                    }),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Semantics(
              liveRegion: true,
              child: Text(s.historyResults(results.length), style: context.text.labelLarge),
            ),
          ),
          Expanded(
            child: results.isEmpty
                ? ListView(
                    padding: const EdgeInsets.all(16),
                    children: [EmptyHint(s.noHistoryResults, icon: Icons.search_off)],
                  )
                : ListView.builder(
                    itemCount: rows.length,
                    itemBuilder: (context, i) {
                      final row = rows[i];
                      if (row is LocalDate) {
                        return ListHeader(fmt.full(row));
                      }
                      final item = row as HistoryItem;
                      return ListTile(
                        leading: ExcludeSemantics(
                          child: Icon(areaIcon(item.kind.area), color: context.colors.area(item.kind.area)),
                        ),
                        title: Text(item.title),
                        subtitle: item.subtitle.isEmpty ? null : Text(item.subtitle),
                        onTap: () => _open(item),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
