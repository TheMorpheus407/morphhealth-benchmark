/// Unified searchable History screen (P06) across Nutrition, Cycle, Weight,
/// and Symptoms — optimized for 10,000+ diary entries with virtualized rendering.
library;

import 'package:flutter/material.dart';

import '../../core/clock.dart';
import '../../core/models.dart';
import '../../core/store.dart';
import '../app_controller.dart';
import '../sheets/entry_editors.dart';
import '../sheets/food_sheets.dart';
import '../theme.dart';

class HistoryScreen extends StatefulWidget {
  final AppController controller;

  const HistoryScreen({super.key, required this.controller});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final TextEditingController _queryCtrl = TextEditingController();
  AppModule? _selectedModule;
  String _rangePreset = 'all'; // 'all', '7d', '28d', '90d', 'custom'
  String? _customStartIso;
  String? _customEndIso;

  @override
  void dispose() {
    _queryCtrl.dispose();
    super.dispose();
  }

  (String?, String?) _effectiveDateBounds(String todayIso) {
    switch (_rangePreset) {
      case '7d':
        return (IsoDate.addDays(todayIso, -6), todayIso);
      case '28d':
        return (IsoDate.addDays(todayIso, -27), todayIso);
      case '90d':
        return (IsoDate.addDays(todayIso, -89), todayIso);
      case 'custom':
        return (_customStartIso, _customEndIso);
      default:
        return (null, null);
    }
  }

  Future<void> _pickCustomDateRange(BuildContext context) async {
    final today = IsoDate.parseUtc(widget.controller.todayDate);
    final initEnd = _customEndIso != null
        ? IsoDate.parseUtc(_customEndIso!)
        : today;
    final initStart = _customStartIso != null
        ? IsoDate.parseUtc(_customStartIso!)
        : DateTime.utc(initEnd.year, initEnd.month, initEnd.day - 27);

    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(1990, 1, 1),
      lastDate: DateTime(2100, 12, 31),
      initialDateRange: DateTimeRange(
        start: DateTime(initStart.year, initStart.month, initStart.day),
        end: DateTime(initEnd.year, initEnd.month, initEnd.day),
      ),
      locale: Locale(widget.controller.localeCode),
    );
    if (picked != null) {
      setState(() {
        _rangePreset = 'custom';
        _customStartIso = IsoDate.fromLocalDateTime(picked.start);
        _customEndIso = IsoDate.fromLocalDateTime(picked.end);
      });
    }
  }

  Future<void> _openItemEditor(
    BuildContext context,
    UnifiedHistoryItem item,
  ) async {
    final c = widget.controller;
    switch (item.kind) {
      case HistoryRecordKind.meal:
        final entry = item.record as FoodDiaryEntry;
        await showLogFoodEntrySheet(
          context,
          c,
          food: c.store.foodsById[entry.foodId],
          existingEntry: entry,
        );
      case HistoryRecordKind.water:
        await showWaterEditorSheet(
          context,
          c,
          existing: item.record as WaterEntry,
        );
      case HistoryRecordKind.caffeine:
        await showCaffeineEditorSheet(
          context,
          c,
          existing: item.record as CaffeineEntry,
        );
      case HistoryRecordKind.period:
        await showPeriodEditorSheet(
          context,
          c,
          existing: item.record as PeriodEntry,
        );
      case HistoryRecordKind.weight:
        await showWeightEditorSheet(
          context,
          c,
          existing: item.record as WeightEntry,
        );
      case HistoryRecordKind.symptom:
        await showSymptomEditorSheet(
          context,
          c,
          existing: item.record as SymptomEntry,
        );
    }
  }

  IconData _iconForKind(HistoryRecordKind kind) {
    switch (kind) {
      case HistoryRecordKind.meal:
        return Icons.restaurant_rounded;
      case HistoryRecordKind.water:
        return Icons.water_drop_outlined;
      case HistoryRecordKind.caffeine:
        return Icons.coffee_outlined;
      case HistoryRecordKind.period:
        return Icons.calendar_month_rounded;
      case HistoryRecordKind.weight:
        return Icons.monitor_weight_outlined;
      case HistoryRecordKind.symptom:
        return Icons.healing_outlined;
    }
  }

  Color _colorForModule(AppModule mod, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    switch (mod) {
      case AppModule.nutrition:
        return Theme.of(context).colorScheme.primary;
      case AppModule.cycle:
        return isDark ? MhColors.cycleAccentDark : MhColors.cycleAccentLight;
      case AppModule.weight:
        return isDark ? MhColors.weightAccentDark : MhColors.weightAccentLight;
      case AppModule.symptoms:
        return isDark
            ? MhColors.symptomAccentDark
            : MhColors.symptomAccentLight;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final s = c.strings;
    final bounds = _effectiveDateBounds(c.todayDate);

    final items = c.store.searchHistory(
      query: _queryCtrl.text,
      moduleFilter: _selectedModule,
      startDateIso: bounds.$1,
      endDateIso: bounds.$2,
      locale: c.localeCode,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(s.navHistory),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                '${items.length} ${s.tr("Einträge", "entries")}',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
            child: TextField(
              controller: _queryCtrl,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: s.historySearchHint,
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: _queryCtrl.text.isNotEmpty
                    ? IconButton(
                        tooltip: s.tr('Suche leeren', 'Clear search'),
                        onPressed: () {
                          _queryCtrl.clear();
                          setState(() {});
                        },
                        icon: const Icon(Icons.clear_rounded),
                      )
                    : null,
              ),
            ),
          ),
          // Area filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                ChoiceChip(
                  label: Text(s.allAreas),
                  selected: _selectedModule == null,
                  onSelected: (_) => setState(() => _selectedModule = null),
                ),
                const SizedBox(width: 6),
                for (final mod in AppModule.values) ...[
                  ChoiceChip(
                    label: Text(mod.label(c.localeCode)),
                    selected: _selectedModule == mod,
                    onSelected: (_) => setState(() => _selectedModule = mod),
                  ),
                  const SizedBox(width: 6),
                ],
              ],
            ),
          ),
          const SizedBox(height: 6),
          // Date range filter chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                ChoiceChip(
                  label: Text(s.allDates),
                  selected: _rangePreset == 'all',
                  onSelected: (_) => setState(() => _rangePreset = 'all'),
                ),
                const SizedBox(width: 6),
                ChoiceChip(
                  label: Text(s.window7Days),
                  selected: _rangePreset == '7d',
                  onSelected: (_) => setState(() => _rangePreset = '7d'),
                ),
                const SizedBox(width: 6),
                ChoiceChip(
                  label: Text(s.window28Days),
                  selected: _rangePreset == '28d',
                  onSelected: (_) => setState(() => _rangePreset = '28d'),
                ),
                const SizedBox(width: 6),
                ChoiceChip(
                  label: Text(s.tr('90 Tage', '90 days')),
                  selected: _rangePreset == '90d',
                  onSelected: (_) => setState(() => _rangePreset = '90d'),
                ),
                const SizedBox(width: 6),
                ActionChip(
                  avatar: const Icon(Icons.date_range_rounded, size: 16),
                  label: Text(
                    _rangePreset == 'custom' && _customStartIso != null
                        ? '$_customStartIso – $_customEndIso'
                        : s.customRange,
                  ),
                  onPressed: () => _pickCustomDateRange(context),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        s.tr(
                          'Keine passenden Einträge für die gewählten Filter.',
                          'No matching entries for the active filters.',
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: items.length,
                    itemBuilder: (ctx, index) {
                      final item = items[index];
                      final color = _colorForModule(item.module, ctx);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Card(
                          child: ListTile(
                            leading: CircleAvatar(
                              backgroundColor: color.withValues(alpha: 0.14),
                              child: Icon(
                                _iconForKind(item.kind),
                                color: color,
                                size: 19,
                              ),
                            ),
                            title: Text(
                              item.title,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            subtitle: Text('${item.date} · ${item.subtitle}'),
                            trailing: const Icon(
                              Icons.edit_outlined,
                              size: 18,
                            ),
                            onTap: () => _openItemEditor(ctx, item),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
