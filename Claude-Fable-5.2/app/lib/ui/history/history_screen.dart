import 'package:flutter/material.dart';
import 'package:morphhealth_core/morphhealth_core.dart';

import '../../l10n/strings.dart';
import '../body/body_screen.dart' show IntensityBadge;
import '../body/editors.dart';
import '../cycle/period_form_screen.dart';
import '../day/day_detail_screen.dart';
import '../nutrition/hydration.dart';
import '../nutrition/intake_screen.dart';
import '../shell.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'trends_tab.dart';

/// The common history: a searchable list of all entries and the trends over
/// seven and 28 days.
class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => HistoryScreenState();
}

class HistoryScreenState extends State<HistoryScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 2, vsync: this);

  /// Shows the entries (0) or the trends (1) tab.
  void showTab(int index) => _tabs.animateTo(index.clamp(0, 1));

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.navHistory),
        actions: const [SettingsButton()],
        bottom: TabBar(
          controller: _tabs,
          tabs: [
            Tab(text: l.tabEntries),
            Tab(text: l.tabTrends),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabs,
        children: const [EntriesTab(), TrendsTab()],
      ),
    );
  }
}

/// The words of the current language that the history search should find.
Map<String, String> historyLabels(L l) => {
  'water': l.water,
  'caffeine': l.caffeine,
  'weight': l.weight,
  'period': l.period,
  'spotting': l.spottingEntry,
  for (final m in Meal.values) 'meal.${m.code}': l.meal(m),
  for (final f in FlowLevel.values) 'flow.${f.code}': l.flow(f),
};

enum _RangePreset { all, last7, last28, custom }

class EntriesTab extends StatefulWidget {
  const EntriesTab({super.key});

  @override
  State<EntriesTab> createState() => _EntriesTabState();
}

class _EntriesTabState extends State<EntriesTab>
    with AutomaticKeepAliveClientMixin {
  final _query = TextEditingController();
  String _text = '';
  Set<Area> _areas = Area.values.toSet();
  _RangePreset _preset = _RangePreset.all;
  Day? _from;
  Day? _to;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  bool get _filtered =>
      _text.trim().isNotEmpty ||
      _areas.length != Area.values.length ||
      _preset != _RangePreset.all;

  void _reset() {
    _query.clear();
    setState(() {
      _text = '';
      _areas = Area.values.toSet();
      _preset = _RangePreset.all;
      _from = null;
      _to = null;
    });
  }

  Future<void> _chooseRange(_RangePreset preset) async {
    final today = context.appRead.today;
    switch (preset) {
      case _RangePreset.all:
        setState(() {
          _preset = preset;
          _from = null;
          _to = null;
        });
      case _RangePreset.last7:
        setState(() {
          _preset = preset;
          _from = today.addDays(-6);
          _to = today;
        });
      case _RangePreset.last28:
        setState(() {
          _preset = preset;
          _from = today.addDays(-27);
          _to = today;
        });
      case _RangePreset.custom:
        final picked = await showDateRangePicker(
          context: context,
          firstDate: DayBar.firstSelectable.toDateTime(),
          lastDate: today.toDateTime(),
          initialDateRange: _from != null && _to != null
              ? DateTimeRange(
                  start: _from!.toDateTime(),
                  end: _to!.toDateTime(),
                )
              : null,
        );
        if (picked != null && mounted) {
          setState(() {
            _preset = preset;
            _from = Day.fromDateTime(picked.start);
            _to = Day.fromDateTime(picked.end);
          });
        }
    }
  }

  Future<void> _pickRange() async {
    final l = context.l;
    final preset = await showModalBottomSheet<_RangePreset>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final option in [
              (_RangePreset.all, l.filterAllTime),
              (_RangePreset.last7, l.filterLast7),
              (_RangePreset.last28, l.filterLast28),
              (_RangePreset.custom, l.filterCustomRange),
            ])
              ListTile(
                title: Text(option.$2),
                selected: option.$1 == _preset,
                trailing: option.$1 == _preset ? const Icon(Icons.check) : null,
                onTap: () => Navigator.of(context).pop(option.$1),
              ),
          ],
        ),
      ),
    );
    if (preset != null && mounted) await _chooseRange(preset);
  }

  String _rangeLabel() {
    final l = context.l;
    final fmt = context.fmt;
    return switch (_preset) {
      _RangePreset.all => l.filterAllTime,
      _RangePreset.last7 => l.filterLast7,
      _RangePreset.last28 => l.filterLast28,
      _RangePreset.custom => fmt.range(_from!, _to!),
    };
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final l = context.l;
    final fmt = context.fmt;
    final app = context.app;
    final index = app.history(historyLabels(l), l.languageCode);
    final items = index.search(
      from: _from,
      to: _to,
      areas: _areas.length == Area.values.length ? null : _areas,
      text: _text,
    );

    // Flat list of rows: a heading per day followed by its entries.
    final rows = <Object>[];
    Day? current;
    for (final item in items) {
      if (item.day != current) {
        current = item.day;
        rows.add(item.day);
      }
      rows.add(item);
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: TextField(
            enableIMEPersonalizedLearning: false,
            controller: _query,
            textInputAction: TextInputAction.search,
            onChanged: (v) => setState(() => _text = v),
            decoration: InputDecoration(
              labelText: l.historySearchHint,
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _text.isEmpty
                  ? null
                  : IconButton(
                      tooltip: l.clearSearch,
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _query.clear();
                        setState(() => _text = '');
                      },
                    ),
            ),
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Row(
            children: [
              ActionChip(
                avatar: const Icon(Icons.date_range, size: 18),
                label: Text(
                  _rangeLabel(),
                  semanticsLabel: '${l.filterPeriod}: ${_rangeLabel()}',
                ),
                backgroundColor: _preset == _RangePreset.all
                    ? null
                    : context.colors.secondaryContainer,
                onPressed: _pickRange,
              ),
              const SizedBox(width: 8),
              for (final area in Area.values) ...[
                FilterChip(
                  label: Text(l.area(area)),
                  selected: _areas.contains(area),
                  onSelected: (on) => setState(() {
                    _areas = {
                      for (final a in Area.values)
                        if (a == area ? on : _areas.contains(a)) a,
                    };
                  }),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
          child: Row(
            children: [
              Expanded(
                child: Semantics(
                  container: true,
                  liveRegion: true,
                  child: Text(
                    l.entriesCount(items.length),
                    style: context.texts.bodySmall,
                  ),
                ),
              ),
              if (_filtered)
                TextButton(onPressed: _reset, child: Text(l.resetFilters))
              else
                const SizedBox(height: 48),
            ],
          ),
        ),
        Expanded(
          child: rows.isEmpty
              ? SingleChildScrollView(
                  child: EmptyHint(
                    icon: Icons.manage_search,
                    text: index.items.isEmpty
                        ? l.historyEmpty
                        : l.noEntriesFound,
                  ),
                )
              : ListView.builder(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.only(bottom: 24),
                  itemCount: rows.length,
                  itemBuilder: (context, i) {
                    final row = rows[i];
                    if (row is Day) {
                      return Padding(
                        padding: const EdgeInsets.fromLTRB(16, 14, 16, 2),
                        child: Semantics(
                          header: true,
                          child: Text(
                            row.year == app.today.year
                                ? fmt.dayLongNoYear(row)
                                : fmt.dayLong(row),
                            style: context.texts.labelLarge?.copyWith(
                              color: context.colors.onSurfaceVariant,
                            ),
                          ),
                        ),
                      );
                    }
                    return HistoryTile(item: row as HistoryItem);
                  },
                ),
        ),
      ],
    );
  }
}

/// One entry of the common history; tapping opens it for editing.
class HistoryTile extends StatelessWidget {
  final HistoryItem item;

  const HistoryTile({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final fmt = context.fmt;
    final app = context.app;
    final colors = MhColors.of(context);
    final record = item.record;

    switch (record) {
      case final IntakeEntry e:
        final food = item.food;
        final n = IntakeNutrition.of(e, food);
        final kcal = n.nutrients[Nutrients.energy];
        return ListTile(
          leading: Icon(Icons.restaurant_outlined, color: colors.nutrition),
          title: Text(food?.name ?? l.unknownFood),
          subtitle: Text(
            [
              l.meal(e.meal),
              fmt.intakeAmount(e, food),
              if (kcal != null) fmt.kcal(kcal),
              fmt.time(e.at),
            ].join(' · '),
          ),
          onTap: food == null
              ? null
              : () => IntakeScreen.open(context, food: food, entry: e),
        );
      case final WaterEntry e:
        return ListTile(
          leading: Icon(Icons.water_drop_outlined, color: colors.water),
          title: Text('${l.water}, ${fmt.ml(e.amountMl)}'),
          subtitle: Text(fmt.time(e.at)),
          onTap: () => showWaterEditor(context, day: e.day, entry: e),
        );
      case final CaffeineEntry e:
        return ListTile(
          leading: Icon(Icons.coffee_outlined, color: colors.caffeine),
          title: Text('${e.label ?? l.caffeine}, ${fmt.mg(e.amountMg)}'),
          subtitle: Text('${l.caffeine} · ${fmt.time(e.at)}'),
          onTap: () => showCaffeineEditor(context, day: e.day, entry: e),
        );
      case final WeightEntry e:
        return ListTile(
          leading: Icon(Icons.monitor_weight_outlined, color: colors.weight),
          title: Text(fmt.weight(e.weightKg, app.settings.weightUnit)),
          subtitle: Text(e.note == null ? l.weight : '${l.weight} · ${e.note}'),
          onTap: () => showWeightEditor(context, entry: e),
        );
      case final SymptomEntry e:
        return ListTile(
          leading: IntensityBadge(value: e.intensity),
          title: Text(e.name),
          subtitle: Text(
            [
              l.intensityOf(e.intensity),
              fmt.time(e.at),
              if (e.note != null) e.note!,
            ].join(' · '),
          ),
          onTap: () => showSymptomEditor(context, entry: e),
        );
      case final Period p:
        final end = p.end;
        return ListTile(
          leading: Icon(Icons.water_drop, color: colors.period),
          title: Text(
            end == null
                ? '${l.period}, ${p.isRunning(app.today) ? l.periodRunning : l.endNotRecorded}'
                : '${l.period}, ${fmt.range(p.start, end)}',
          ),
          subtitle: Text(
            [
              if (p.lengthDays != null) l.daysCount(p.lengthDays!),
              if (p.note != null) p.note!,
            ].join(' · '),
          ),
          onTap: () => Navigator.of(context).push<void>(
            MaterialPageRoute(builder: (_) => PeriodFormScreen(period: p)),
          ),
        );
      case final CycleDay d:
        return ListTile(
          leading: Icon(Icons.sticky_note_2_outlined, color: colors.period),
          title: Text(d.spotting ? l.spottingEntry : l.cycleNote),
          subtitle: d.note == null ? null : Text(d.note!),
          onTap: () => Navigator.of(context).push<void>(
            MaterialPageRoute(builder: (_) => DayDetailScreen(day: d.date)),
          ),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
