import 'package:flutter/material.dart';

import '../../core/civil.dart';
import '../../core/db.dart';
import '../../core/ids.dart';
import '../../core/models.dart';
import '../../core/nutrients.dart' show roundTo;
import '../../state/app_state.dart';
import '../format.dart';
import '../history/history_screen.dart';
import '../l10n_x.dart';
import '../nutrition/water_caffeine.dart' show defaultTimeFor;
import '../theme.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import '../widgets/fields.dart';

/// Gewicht in der gewählten Einheit als Text, z. B. `72,4 kg`.
String formatWeight(BuildContext context, AppState app, double kg, {int decimals = 1}) {
  final f = context.fmt;
  return app.settings.weightUnit == WeightUnit.lb ? '${f.n(kgToLb(kg), decimals)} lb' : '${f.n(kg, decimals)} kg';
}

/// Differenz mit Vorzeichen in der gewählten Einheit, z. B. `−0,4 kg`.
String formatWeightDelta(BuildContext context, AppState app, double deltaKg) {
  final f = context.fmt;
  final lb = app.settings.weightUnit == WeightUnit.lb;
  final v = lb ? kgToLb(deltaKg) : deltaKg;
  final r = roundTo(v, 1);
  final s = f.n(r.abs(), 1);
  final sign = r > 0 ? '+' : (r < 0 ? '−' : '±');
  return '$sign$s ${lb ? 'lb' : 'kg'}';
}

class WeightScreen extends StatefulWidget {
  const WeightScreen({super.key});

  @override
  State<WeightScreen> createState() => _WeightScreenState();
}

class _WeightScreenState extends State<WeightScreen> {
  int _days = 28; // 0 = alles

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final l = context.l10n;
    final f = context.fmt;
    final color = areaColor(Area.weight, context.theme.brightness);
    final all = app.db.weights.all.toList()..sort((a, b) => b.at.compareTo(a.at));
    final today = app.today;
    final latest = all.isEmpty ? null : all.first;
    final previous = all.length > 1 ? all[1] : null;

    // Verlauf: Tageswerte (letzter Eintrag des Tages) im gewählten Zeitraum.
    Day? start;
    if (_days > 0) {
      start = today.addDays(-(_days - 1));
    } else if (all.isNotEmpty) {
      start = all.last.day;
    }
    final byDay = <Day, WeightEntry>{};
    for (final w in all.reversed) {
      byDay[w.day] = w; // später überschreibt früher: letzter Eintrag des Tages
    }
    final points = <LinePoint>[
      for (final e in (byDay.entries.toList()..sort((a, b) => a.key.compareTo(b.key))))
        if (start != null && !e.key.isBefore(start) && !e.key.isAfter(today)) LinePoint(e.key, e.value.kg),
    ];
    final chartStart = start ?? today;
    final rangeText = switch (_days) {
      7 => l.trendsRange7,
      28 => l.trendsRange28,
      90 => l.weightRange90,
      _ => l.weightRangeAll,
    };
    double toUnit(double kg) => app.settings.weightUnit == WeightUnit.lb ? kgToLb(kg) : kg;

    return Scaffold(
      appBar: AppBar(
        title: Text(l.navWeight),
        actions: [
          IconButton(
            tooltip: l.historyTitle,
            icon: const Icon(Icons.search),
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const HistoryScreen(initialAreas: {Area.weight}))),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showWeightSheet(context, day: app.selectedDay),
        icon: const Icon(Icons.add),
        label: Text(l.weightAdd),
      ),
      body: CustomScrollView(
        key: const PageStorageKey('weight'),
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            sliver: SliverList.list(
              children: [
                SectionCard(
                  title: l.navWeight,
                  icon: areaIcon(Area.weight),
                  accent: color,
                  child: latest == null
                      ? EmptyHint(l.weightNoEntries, icon: Icons.monitor_weight_outlined)
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              formatWeight(context, app, latest.kg),
                              style: context.text.headlineMedium?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            Text(
                              l.weightLatest(formatWeight(context, app, latest.kg), f.date(latest.day)),
                              style: context.text.bodyMedium,
                            ),
                            if (previous != null)
                              Text(
                                l.weightChange(formatWeightDelta(context, app, latest.kg - previous.kg)),
                                style: context.text.bodyMedium,
                              ),
                          ],
                        ),
                ),
                const SizedBox(height: 12),
                SegmentedButton<int>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(value: 7, label: Text(l.trendsRange7)),
                    ButtonSegment(value: 28, label: Text(l.trendsRange28)),
                    ButtonSegment(value: 90, label: Text(l.weightRange90)),
                    ButtonSegment(value: 0, label: Text(l.weightRangeAll)),
                  ],
                  selected: {_days},
                  onSelectionChanged: (s) => setState(() => _days = s.first),
                ),
                const SizedBox(height: 12),
                SectionCard(
                  title: '${l.navWeight} · $rangeText',
                  icon: Icons.show_chart,
                  accent: color,
                  child: points.isEmpty
                      ? EmptyHint(l.weightNoRange, icon: Icons.info_outline)
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            LineChart(
                              points: [for (final p in points) LinePoint(p.day, toUnit(p.value))],
                              start: chartStart,
                              end: today,
                              color: color,
                              valueLabel: (v) => f.n(v, 1),
                              dayLabel: (d) => f.dateWithWeekday(d),
                              axisLabel: (d) => f.dayMonth(d),
                              hint: l.weightChartHint,
                              summary: l.weightChartSummary(
                                rangeText,
                                formatWeight(context, app, points.first.value),
                                formatWeight(context, app, points.last.value),
                                points.length,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Builder(
                              builder: (context) {
                                final vals = points.map((p) => p.value);
                                final lo = vals.reduce((a, b) => a < b ? a : b);
                                final hi = vals.reduce((a, b) => a > b ? a : b);
                                return Text(
                                  l.weightStats(
                                    formatWeight(context, app, lo),
                                    formatWeight(context, app, hi),
                                    formatWeightDelta(context, app, points.last.value - points.first.value),
                                  ),
                                  style: context.text.bodyMedium,
                                );
                              },
                            ),
                          ],
                        ),
                ),
                const SizedBox(height: 16),
                if (all.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 4),
                    child: Semantics(header: true, child: Text(l.weightEntriesTitle, style: context.text.titleMedium)),
                  ),
              ],
            ),
          ),
          SliverList.builder(
            itemCount: all.length,
            itemBuilder: (c, i) {
              final w = all[i];
              final prev = i + 1 < all.length ? all[i + 1] : null;
              return ListTile(
                title: Text(formatWeight(context, app, w.kg), style: context.text.titleMedium),
                subtitle: Text([f.dateTime(w.at), if (w.note != null) w.note!].join(' · ')),
                trailing: prev == null
                    ? const Icon(Icons.edit_outlined, size: 18)
                    : Text(formatWeightDelta(context, app, w.kg - prev.kg), style: context.text.bodyMedium),
                onTap: () => showWeightSheet(context, day: w.day, existing: w),
              );
            },
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 96)),
        ],
      ),
    );
  }
}

Future<void> showWeightSheet(BuildContext context, {required Day day, WeightEntry? existing}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (c) => _WeightSheet(day: day, existing: existing, parent: context),
  );
}

class _WeightSheet extends StatefulWidget {
  final Day day;
  final WeightEntry? existing;
  final BuildContext parent;

  const _WeightSheet({required this.day, required this.existing, required this.parent});

  @override
  State<_WeightSheet> createState() => _WeightSheetState();
}

class _WeightSheetState extends State<_WeightSheet> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _value;
  late final TextEditingController _note;
  late Day _day;
  late TimeOfDay _time;

  @override
  void initState() {
    super.initState();
    final app = AppScope.read(widget.parent);
    final e = widget.existing;
    final at = e?.at ?? defaultTimeFor(app, widget.day);
    final lb = app.settings.weightUnit == WeightUnit.lb;
    String initial = '';
    if (e != null) {
      initial = Fmt(app.lang).input(roundTo(lb ? kgToLb(e.kg) : e.kg, 2), 2);
    } else {
      final last = app.db.latestWeightUpTo(at.day) ?? app.db.latestWeightUpTo(app.today);
      if (last != null) initial = Fmt(app.lang).input(roundTo(lb ? kgToLb(last.kg) : last.kg, 1), 1);
    }
    _value = TextEditingController(text: initial);
    _note = TextEditingController(text: e?.note ?? '');
    _day = at.day;
    _time = TimeOfDay(hour: at.hour, minute: at.minute);
  }

  @override
  void dispose() {
    _value.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final app = AppScope.read(widget.parent);
    final l = context.l10n;
    final nav = Navigator.of(context);
    final messenger = widget.parent;
    final lb = app.settings.weightUnit == WeightUnit.lb;
    final raw = Fmt.parse(_value.text)!;
    final kg = roundTo(lb ? lbToKg(raw) : raw, 4);
    final note = _note.text.trim().isEmpty ? null : _note.text.trim();
    final at = LocalDateTime(_day, _time.hour, _time.minute);
    try {
      final e = widget.existing;
      final saved = e == null
          ? WeightEntry(id: newId(), at: at, kg: kg, note: note)
          : e.copyWith(at: at, kg: kg, note: () => note);
      await app.db.saveWeight(saved);
      nav.pop();
      if (messenger.mounted) {
        showMessage(messenger, l.commonSaved);
      }
    } on DomainException catch (e) {
      if (mounted) showMessage(context, domainErrorText(l, e));
    }
  }

  Future<void> _delete() async {
    final app = AppScope.read(widget.parent);
    final l = context.l10n;
    final nav = Navigator.of(context);
    final messenger = widget.parent;
    final e = widget.existing!;
    await app.db.deleteWeight(e.id);
    nav.pop();
    if (messenger.mounted) showUndo(messenger, l.commonDeletedItem(l.navWeight), () => app.db.saveWeight(e));
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.read(widget.parent);
    final l = context.l10n;
    final editing = widget.existing != null;
    final unit = app.settings.weightUnit == WeightUnit.lb ? 'lb' : 'kg';
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + sheetBottomInset(context)),
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(editing ? l.weightEditTitle : l.weightAdd, style: context.text.titleLarge),
              const SizedBox(height: 16),
              NumberField(
                controller: _value,
                label: l.weightValueLabel,
                suffix: unit,
                required: true,
                positive: true,
                max: unit == 'lb' ? 1500 : 700,
                autofocus: !editing,
              ),
              const SizedBox(height: 12),
              DateTimeRow(
                day: _day,
                time: _time,
                onDay: (d) => setState(() => _day = d),
                onTime: (t) => setState(() => _time = t),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _note,
                maxLength: 500,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(labelText: l.weightNoteHint, counterText: ''),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  if (editing)
                    TextButton.icon(
                      onPressed: _delete,
                      icon: const Icon(Icons.delete_outline),
                      label: Text(l.commonDelete),
                    ),
                  const Spacer(),
                  TextButton(onPressed: () => Navigator.pop(context), child: Text(l.commonCancel)),
                  const SizedBox(width: 8),
                  FilledButton(onPressed: _save, child: Text(l.commonSave)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
