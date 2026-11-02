import 'package:flutter/material.dart';
import 'package:morphhealth_core/morphhealth_core.dart';

import '../l10n/app_localizations.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import 'day_detail_page.dart';
import 'home_shell.dart';
import 'journal_entry_sheet.dart';
import 'period_editor_sheet.dart';
import 'symptom_entry_sheet.dart';

/// Searchable history across the four areas.
class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final TextEditingController _search = TextEditingController();
  final Set<AppArea> _areas = <AppArea>{};
  DateTime? _from;
  DateTime? _to;
  bool _filtering = false;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);

    final List<HistoryItem> items = state.history.query(
      from: _from == null ? null : DateMath.format(_from!),
      to: _to == null ? null : DateMath.format(_to!),
      areas: _areas,
      text: _search.text,
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(l10n.t('history.title')),
        actions: <Widget>[
          IconButton(
            onPressed: _toggleFilters,
            icon: Icon(_filtering ? Icons.filter_alt : Icons.filter_alt_outlined),
            tooltip: l10n.t('history.filter_range'),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: TextField(
              controller: _search,
              onChanged: (String _) => setState(() {}),
              decoration: InputDecoration(
                hintText: l10n.t('history.search_hint'),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(_search.clear),
                      ),
              ),
            ),
          ),
          if (_filtering)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: <Widget>[
                      for (final AppArea area in AppArea.values)
                        FilterChip(
                          label: Text(l10n.t('area.${area.name}')),
                          selected: _areas.contains(area),
                          onSelected: (bool selected) => setState(() {
                            if (selected) {
                              _areas.add(area);
                            } else {
                              _areas.remove(area);
                            }
                          }),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pickFrom(),
                          icon: const Icon(Icons.calendar_today_outlined),
                          label: Text(
                            _from == null
                                ? '${l10n.t('common.from')}: ${l10n.t('common.none')}'
                                : '${l10n.t('common.from')}: '
                                    '${formatDay(context, DateMath.format(_from!), withYear: true)}',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () => _pickTo(),
                          icon: const Icon(Icons.event_available_outlined),
                          label: Text(
                            _to == null
                                ? '${l10n.t('common.to')}: ${l10n.t('common.none')}'
                                : '${l10n.t('common.to')}: '
                                    '${formatDay(context, DateMath.format(_to!), withYear: true)}',
                          ),
                        ),
                      ),
                    ],
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => setState(() {
                        _from = null;
                        _to = null;
                        _areas.clear();
                      }),
                      child: Text(l10n.t('common.reset')),
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                l10n.t(
                  'history.results',
                  <String, String>{'count': '${items.length}'},
                ),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? EmptyState(
                    message: l10n.t('history.empty'),
                    icon: Icons.search_off,
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                    itemCount: items.length,
                    itemBuilder: (BuildContext context, int index) {
                      final HistoryItem item = items[index];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 6),
                        child: ListTile(
                          leading: Icon(_iconFor(item.kind)),
                          title: Text(item.title),
                          subtitle: Text(
                            <String>[
                              l10n.t('area.${item.area}'),
                              formatDay(context, item.date, withYear: true),
                              if (item.subtitle != null) item.subtitle!,
                            ].join(' · '),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => _open(context, item),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  static IconData _iconFor(String kind) {
    switch (kind) {
      case 'journal':
        return Icons.restaurant_outlined;
      case 'water':
        return Icons.water_drop_outlined;
      case 'caffeine':
        return Icons.coffee_outlined;
      case 'period':
        return Icons.water_drop;
      case 'weight':
        return Icons.monitor_weight_outlined;
      case 'symptom':
        return Icons.healing_outlined;
      default:
        return Icons.circle_outlined;
    }
  }

  void _toggleFilters() {
    setState(() => _filtering = !_filtering);
  }

  Future<void> _pickFrom() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _from ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _from = picked);
  }

  Future<void> _pickTo() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _to ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) setState(() => _to = picked);
  }

  Future<void> _open(BuildContext context, HistoryItem item) async {
    final AppState state = AppScope.of(context);
    switch (item.kind) {
      case 'journal':
        final FoodItem? food = state.repository.foodById(item.id);
        if (food == null) {
          _openDay(context, item.date);
          return;
        }
        final JournalEntry? entry = state.repository.journalEntryById(item.id);
        await JournalEntrySheet.show(
          context,
          food: food,
          entry: entry,
          initialDate: item.date,
        );
      case 'water':
      case 'caffeine':
        final IntakeEntry? entry = state.repository.intakeEntryById(item.id);
        if (entry == null) return;
        await state.deleteIntake(entry.id);
      case 'period':
        final PeriodRecord? record = state.repository.periodById(item.id);
        if (record == null) return;
        await PeriodEditorSheet.show(context, record: record);
      case 'weight':
        final WeightEntry? entry = state.repository.weightEntryById(item.id);
        if (entry == null) return;
        _openDay(context, item.date);
      case 'symptom':
        final SymptomEntry? entry = state.repository.symptomEntryById(item.id);
        if (entry == null) return;
        await SymptomEntrySheet.show(context, entry: entry);
    }
    if (mounted) setState(() {});
  }

  void _openDay(BuildContext context, String date) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => DayDetailPage(date: date),
      ),
    );
  }
}
