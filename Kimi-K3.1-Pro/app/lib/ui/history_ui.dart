import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/health.dart';
import '../core/history.dart';
import '../core/nutrition.dart';
import '../core/utils.dart';
import 'controller.dart';
import 'cycle_ui.dart';
import 'l10n.dart';
import 'nutrition_ui.dart';
import 'tracking_ui.dart';
import 'widgets.dart';

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  final query = TextEditingController();
  String area = 'all';
  String? from;
  String? to;

  @override
  void dispose() {
    query.dispose();
    super.dispose();
  }

  Future<void> pickDate(bool start) async {
    final initial = parseDate(
      start
          ? from ?? to ?? dateKey(DateTime.now())
          : to ?? from ?? dateKey(DateTime.now()),
    );
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() {
        if (start) {
          from = dateKey(picked);
        } else {
          to = dateKey(picked);
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = l10n(context);
    final state = context.watch<AppController>().state;
    final records = searchHistory(
      state,
      query: query.text,
      area: area,
      from: from,
      to: to,
    );
    return Scaffold(
      appBar: AppBar(title: Text(strings.t('history'))),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              key: const ValueKey('history-search'),
              controller: query,
              onChanged: (_) => setState(() {}),
              decoration: fieldDecoration(strings.t('free_text')).copyWith(
                prefixIcon: const Icon(Icons.search),
                suffixIcon: query.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: strings.t('clear_filters'),
                        onPressed: () => setState(query.clear),
                        icon: const Icon(Icons.clear),
                      ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: area,
                  decoration: fieldDecoration(strings.t('area')),
                  items: [
                    for (final item in [
                      'all',
                      'nutrition',
                      'cycle',
                      'weight',
                      'symptoms',
                    ])
                      DropdownMenuItem(
                        value: item,
                        child: Text(strings.t(item)),
                      ),
                  ],
                  onChanged: (value) => setState(() => area = value ?? 'all'),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => pickDate(true),
                        icon: const Icon(Icons.event),
                        label: Text(
                          from == null
                              ? strings.t('from')
                              : strings.date(from!),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => pickDate(false),
                        icon: const Icon(Icons.event),
                        label: Text(
                          to == null ? strings.t('to') : strings.date(to!),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ],
                ),
                Wrap(
                  alignment: WrapAlignment.spaceBetween,
                  children: [
                    Text(strings.t('results_count', {'count': records.length})),
                    TextButton(
                      onPressed: () => setState(() {
                        query.clear();
                        area = 'all';
                        from = null;
                        to = null;
                      }),
                      child: Text(strings.t('clear_filters')),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: records.isEmpty
                ? EmptyState(text: strings.t('no_results'))
                : ListView.separated(
                    itemCount: records.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final record = records[index];
                      return ListTile(
                        key: ValueKey('history-${record.kind}-${record.id}'),
                        leading: Icon(switch (record.area) {
                          'nutrition' => Icons.restaurant_outlined,
                          'cycle' => Icons.water_drop_outlined,
                          'weight' => Icons.monitor_weight_outlined,
                          _ => Icons.favorite_outline,
                        }),
                        title: Text(_title(record, strings)),
                        subtitle: Text(
                          '${strings.date(record.date)} · ${strings.t(record.area)}\n'
                          '${_detail(record, strings)}',
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: const Icon(Icons.edit_outlined),
                        onTap: () => _open(record),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  String _title(HistoryRecord record, S strings) {
    if (record.kind == 'water') return strings.t('water');
    if (record.kind == 'caffeine') return strings.t('caffeine');
    if (record.kind == 'period') return strings.t('period');
    if (record.kind == 'weight') return strings.t('weight');
    return record.title;
  }

  String _detail(HistoryRecord record, S strings) {
    final value = record.value;
    return switch (value) {
      IntakeEntry() =>
        '${strings.amount(value.amount, value.unit == 'portion' ? strings.t('portions') : value.unit)}'
            '${value.notes.isEmpty ? '' : ' · ${value.notes}'}',
      Period() =>
        '${strings.date(value.start)} – ${value.end == null ? strings.t('end_open') : strings.date(value.end!)} · '
            '${strings.flow(value.flow)}${value.notes.isEmpty ? '' : ' · ${value.notes}'}',
      WeightEntry() => strings.amount(value.kg, 'kg'),
      SymptomEntry() => strings.t('intensity_value', {
        'value': value.intensity,
      }),
      _ => '',
    };
  }

  void _open(HistoryRecord record) {
    final value = record.value;
    final page = switch (value) {
      IntakeEntry() =>
        value.kind == IntakeKind.food
            ? IntakeEditPage(existing: value)
            : SimpleIntakeEditPage(existing: value),
      Period() => PeriodEditPage(existing: value),
      WeightEntry() => WeightEditPage(existing: value),
      SymptomEntry() => SymptomEditPage(existing: value),
      _ => throw StateError('Unknown history record'),
    };
    Navigator.push(context, MaterialPageRoute<void>(builder: (_) => page));
  }
}
