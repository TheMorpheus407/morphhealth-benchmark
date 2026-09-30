import 'package:flutter/material.dart';

import '../../core/civil.dart';
import '../../core/history.dart';
import '../../core/models.dart';
import '../../core/nutrients.dart';
import '../../state/app_state.dart';
import '../cycle/cycle_widgets.dart';
import '../l10n_x.dart';
import '../nutrition/food_entry_screen.dart';
import '../nutrition/water_caffeine.dart';
import '../symptoms/symptom_screen.dart';
import '../theme.dart';
import '../weight/weight_screen.dart';
import '../widgets/common.dart';

/// Durchsuchbare Historie über die vier Bereiche mit Filtern für Datumsbereich,
/// Bereich und Freitext. Einträge lassen sich von hier öffnen und bearbeiten.
class HistoryScreen extends StatefulWidget {
  final Set<Area>? initialAreas;
  final String? initialText;

  const HistoryScreen({super.key, this.initialAreas, this.initialText});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final _text = TextEditingController();
  late Set<Area> _areas;
  Day? _from;
  Day? _to;
  int _preset = 0; // 0 alles, 7, 28, 90, -1 eigener Bereich

  List<HistoryItem> _all = const [];
  int _allRevision = -1;
  List<HistoryItem> _filtered = const [];
  String _filterKey = '';
  List<Object> _rows = const [];

  @override
  void initState() {
    super.initState();
    _areas = {...?widget.initialAreas};
    _text.text = widget.initialText ?? '';
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  void _setPreset(int days, Day today) {
    setState(() {
      _preset = days;
      if (days == 0) {
        _from = null;
        _to = null;
      } else {
        _from = today.addDays(-(days - 1));
        _to = today;
      }
    });
  }

  Future<void> _pickRange(Day today) async {
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: today.addDays(366).toDateTime(),
      initialDateRange: _from != null && _to != null
          ? DateTimeRange(start: _from!.toDateTime(), end: _to!.toDateTime())
          : null,
      helpText: context.l10n.historyCustomRange,
    );
    if (r != null) {
      setState(() {
        _preset = -1;
        _from = Day.fromDateTime(r.start);
        _to = Day.fromDateTime(r.end);
      });
    }
  }

  bool get _hasFilter => _text.text.trim().isNotEmpty || _areas.isNotEmpty || _from != null || _to != null;

  void _reset() => setState(() {
    _text.clear();
    _areas = {};
    _from = null;
    _to = null;
    _preset = 0;
  });

  /// Berechnet gefilterte Liste und Zeilen neu, wenn sich Daten oder Filter geändert haben.
  void _refresh(AppState app) {
    if (_allRevision != app.db.revision) {
      _all = buildHistory(app.db);
      _allRevision = app.db.revision;
      _filterKey = '';
    }
    final key =
        '${_text.text}|${(_areas.map((a) => a.index).toList()..sort()).join(',')}|$_from|$_to|${app.settings.areas.length}|$_allRevision';
    if (key == _filterKey) return;
    _filterKey = key;
    _filtered = filterHistory(
      _all,
      HistoryQuery(from: _from, to: _to, areas: _areas.isEmpty ? null : _areas, text: _text.text),
      visible: app.settings.areas,
    );
    final rows = <Object>[];
    Day? last;
    for (final it in _filtered) {
      if (it.day != last) {
        rows.add(it.day);
        last = it.day;
      }
      rows.add(it);
    }
    _rows = rows;
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final l = context.l10n;
    final f = context.fmt;
    _refresh(app);
    final visible = Area.values.where(app.settings.shows).toList();
    final today = app.today;
    String rangeLabel() => _from != null && _to != null ? '${f.date(_from!)} – ${f.date(_to!)}' : l.historyCustomRange;
    return AppScaffold(
      appBar: AppBar(title: Text(l.historyTitle)),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              controller: _text,
              textInputAction: TextInputAction.search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: l.historySearchHint,
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _text.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: l.commonDelete,
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(_text.clear),
                      ),
              ),
            ),
          ),
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              children: [
                for (final p in [
                  (0, l.historyPresetAll),
                  (7, l.historyPreset7),
                  (28, l.historyPreset28),
                  (90, l.historyPreset90),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(p.$2),
                      selected: _preset == p.$1,
                      onSelected: (_) => _setPreset(p.$1, today),
                    ),
                  ),
                ChoiceChip(
                  avatar: const Icon(Icons.date_range, size: 18),
                  label: Text(_preset == -1 ? rangeLabel() : l.historyCustomRange),
                  selected: _preset == -1,
                  onSelected: (_) => _pickRange(today),
                ),
              ],
            ),
          ),
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              children: [
                for (final a in visible)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: FilterChip(
                      avatar: Icon(areaIcon(a), size: 18),
                      label: Text(l.area(a)),
                      selected: _areas.contains(a),
                      onSelected: (v) => setState(() => v ? _areas.add(a) : _areas.remove(a)),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    liveRegion: true,
                    child: Text(l.historyCount(_filtered.length), style: context.text.labelLarge),
                  ),
                ),
                if (_hasFilter) TextButton(onPressed: _reset, child: Text(l.historyClearFilters)),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _rows.isEmpty
                ? ListView(
                    padding: const EdgeInsets.all(16),
                    children: [EmptyHint(l.historyEmpty, icon: Icons.search_off)],
                  )
                : ListView.builder(
                    itemCount: _rows.length,
                    itemBuilder: (c, i) {
                      final r = _rows[i];
                      if (r is Day) {
                        return Padding(
                          padding: const EdgeInsets.fromLTRB(16, 14, 16, 4),
                          child: Semantics(
                            header: true,
                            child: Text(
                              f.dateLong(r),
                              style: context.text.titleSmall?.copyWith(color: c.colors.primary),
                            ),
                          ),
                        );
                      }
                      return _HistoryTile(item: r as HistoryItem, app: app);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  final HistoryItem item;
  final AppState app;

  const _HistoryTile({required this.item, required this.app});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final f = context.fmt;
    final color = areaColor(item.area, context.theme.brightness);
    final src = item.source;
    String title;
    String subtitle;
    IconData icon;
    VoidCallback onTap;
    switch (src) {
      case FoodEntry e:
        icon = Icons.restaurant_outlined;
        title = e.food.name == e.food.barcode ? l.foodUnnamed : e.food.name;
        final kcal = e.nutrients.has(kEnergy) ? f.kcal(e.nutrients.get0(kEnergy)) : l.nutritionNoKcal;
        subtitle = [
          f.time(e.at),
          '${f.nTrim(e.amount, 2)} ${l.unitFor(e.unit, e.amount)}',
          l.meal(e.meal),
          kcal,
        ].join(' · ');
        onTap = () => Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => FoodEntryScreen(food: e.food, foodId: e.foodId, existing: e),
          ),
        );
      case WaterEntry w:
        icon = Icons.water_drop_outlined;
        title = l.waterEntryTitle(f.n(w.ml));
        subtitle = f.time(w.at);
        onTap = () => showWaterSheet(context, day: w.day, existing: w);
      case CaffeineEntry c:
        icon = Icons.coffee_outlined;
        title = c.label == null ? l.historyCaffeineTitle(f.n(c.mg)) : '${c.label} · ${f.n(c.mg)} mg';
        subtitle = f.time(c.at);
        onTap = () => showCaffeineSheet(context, day: c.day, existing: c);
      case WeightEntry w:
        icon = Icons.monitor_weight_outlined;
        title = formatWeight(context, app, w.kg);
        subtitle = [f.time(w.at), if (w.note != null) w.note!].join(' · ');
        onTap = () => showWeightSheet(context, day: w.day, existing: w);
      case PeriodRecord p:
        icon = Icons.water_drop_outlined;
        title = p.end == null
            ? l.historyPeriodOpen(f.date(p.start))
            : l.historyPeriodTitle(f.date(p.start), f.date(p.end!));
        subtitle = [if (p.flow != null) l.flow(p.flow), if (p.notes != null) p.notes!].join(' · ');
        onTap = () => showPeriodSheet(context, existing: p);
      case SymptomEntry s:
        icon = Icons.healing_outlined;
        title = l.historySymptomTitle(s.name, '${s.intensity}');
        subtitle = [f.time(s.at), if (s.note != null) s.note!].join(' · ');
        onTap = () => showSymptomSheet(context, day: s.day, existing: s);
      default:
        icon = Icons.help_outline;
        title = '';
        subtitle = '';
        onTap = () {};
    }
    return ListTile(
      leading: Icon(icon, color: color),
      title: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: subtitle.isEmpty ? null : Text(subtitle, maxLines: 2, overflow: TextOverflow.ellipsis),
      onTap: onTap,
    );
  }
}
