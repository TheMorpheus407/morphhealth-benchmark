import 'package:flutter/material.dart';

import '../../core/civil.dart';
import '../../core/db.dart';
import '../../core/ids.dart';
import '../../core/models.dart';
import '../../core/nutrients.dart' show roundTo;
import '../../state/app_state.dart';
import '../history/history_screen.dart';
import '../l10n_x.dart';
import '../nutrition/water_caffeine.dart' show defaultTimeFor;
import '../theme.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import '../widgets/fields.dart';

/// Bereich "Symptome": Einträge des gewählten Tages und Verlauf je Symptom.
class SymptomScreen extends StatelessWidget {
  const SymptomScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(l.navSymptoms),
          actions: [
            IconButton(
              tooltip: l.historyTitle,
              icon: const Icon(Icons.search),
              onPressed: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: (_) => const HistoryScreen(initialAreas: {Area.symptoms}))),
            ),
          ],
          bottom: TabBar(
            tabs: [
              Tab(text: l.symptomTabDay),
              Tab(text: l.symptomTabHistory),
            ],
          ),
        ),
        body: const TabBarView(children: [_SymptomDayTab(), _SymptomTrendTab()]),
      ),
    );
  }
}

/// Zeile für einen Symptomeintrag.
class SymptomTile extends StatelessWidget {
  final SymptomEntry entry;
  final bool showDate;

  const SymptomTile({super.key, required this.entry, this.showDate = false});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final f = context.fmt;
    final color = areaColor(Area.symptoms, context.theme.brightness);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.16),
        child: Text(
          '${entry.intensity}',
          style: TextStyle(color: color, fontWeight: FontWeight.w700),
        ),
      ),
      title: Semantics(
        label: l.symptomEntryTitle(entry.name, '${entry.intensity}'),
        excludeSemantics: true,
        child: Text(entry.name),
      ),
      subtitle: Text(
        [showDate ? f.dateTime(entry.at) : f.time(entry.at), if (entry.note != null) entry.note!].join(' · '),
      ),
      trailing: const Icon(Icons.edit_outlined, size: 18),
      onTap: () => showSymptomSheet(context, day: entry.day, existing: entry),
    );
  }
}

class _SymptomDayTab extends StatelessWidget {
  const _SymptomDayTab();

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final l = context.l10n;
    final color = areaColor(Area.symptoms, context.theme.brightness);
    final day = app.selectedDay;
    final entries = app.db.symptoms.on(day);
    final recent = app.db.symptomNames().take(8).toList();
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showSymptomSheet(context, day: day),
        icon: const Icon(Icons.add),
        label: Text(l.symptomAdd),
      ),
      body: ListView(
        key: const PageStorageKey('symptoms-day'),
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 96),
        children: [
          DayNavigator(day: day, today: app.today, onChanged: app.selectDay),
          const SizedBox(height: 8),
          if (recent.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.only(left: 4, bottom: 6),
              child: Text(l.symptomRecent, style: context.text.titleSmall),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final n in recent)
                  ActionChip(
                    avatar: Icon(Icons.add, size: 18, color: color),
                    label: Text(n.name),
                    onPressed: () => showSymptomSheet(context, day: day, presetName: n.name),
                  ),
              ],
            ),
            const SizedBox(height: 12),
          ],
          SectionCard(
            title: l.navSymptoms,
            icon: areaIcon(Area.symptoms),
            accent: color,
            child: entries.isEmpty
                ? EmptyHint(l.symptomNoEntries, icon: Icons.healing_outlined)
                : Column(children: [for (final e in entries) SymptomTile(entry: e)]),
          ),
        ],
      ),
    );
  }
}

class _SymptomTrendTab extends StatefulWidget {
  const _SymptomTrendTab();

  @override
  State<_SymptomTrendTab> createState() => _SymptomTrendTabState();
}

class _SymptomTrendTabState extends State<_SymptomTrendTab> {
  String? _key;
  int _days = 28; // 0 = alles

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final l = context.l10n;
    final f = context.fmt;
    final color = areaColor(Area.symptoms, context.theme.brightness);
    final names = app.db.symptomNames();
    if (names.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [EmptyHint(l.symptomNoHistory, icon: Icons.healing_outlined)],
      );
    }
    final key = names.any((n) => symptomKey(n.name) == _key) ? _key! : symptomKey(names.first.name);
    final selectedName = names.firstWhere((n) => symptomKey(n.name) == key).name;
    final today = app.today;
    final all = app.db.symptoms.all.where((s) => s.key == key).toList()..sort((a, b) => a.at.compareTo(b.at));
    final Day start = _days > 0 ? today.addDays(-(_days - 1)) : (all.isEmpty ? today : all.first.day);
    final inRange = [
      for (final s in all)
        if (!s.day.isBefore(start) && !s.day.isAfter(today)) s,
    ];
    // Tageswert: höchste Intensität des Tages.
    final perDay = <Day, int>{};
    for (final s in inRange) {
      final cur = perDay[s.day];
      if (cur == null || s.intensity > cur) perDay[s.day] = s.intensity;
    }
    final points = [
      for (final e in (perDay.entries.toList()..sort((a, b) => a.key.compareTo(b.key))))
        LinePoint(e.key, e.value.toDouble()),
    ];
    final avg = inRange.isEmpty ? 0.0 : inRange.fold<double>(0, (a, b) => a + b.intensity) / inRange.length;
    final maxI = inRange.isEmpty ? 0 : inRange.map((e) => e.intensity).reduce((a, b) => a > b ? a : b);
    final rangeText = switch (_days) {
      7 => l.trendsRange7,
      28 => l.trendsRange28,
      90 => l.weightRange90,
      _ => l.weightRangeAll,
    };
    return ListView(
      key: const PageStorageKey('symptoms-trend'),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
      children: [
        DropdownMenu<String>(
          key: ValueKey(key),
          width: double.infinity,
          label: Text(l.symptomPick),
          initialSelection: key,
          dropdownMenuEntries: [
            for (final n in names) DropdownMenuEntry(value: symptomKey(n.name), label: '${n.name} (${n.count})'),
          ],
          onSelected: (v) {
            if (v != null) setState(() => _key = v);
          },
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
          title: '$selectedName · $rangeText',
          icon: Icons.show_chart,
          accent: color,
          child: inRange.isEmpty
              ? EmptyHint(l.symptomNoInRange, icon: Icons.info_outline)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LineChart(
                      points: points,
                      start: start,
                      end: today,
                      color: color,
                      yMin: 0,
                      yMax: 10,
                      valueLabel: (v) => f.n(v, 0),
                      dayLabel: (d) => f.dateWithWeekday(d),
                      axisLabel: (d) => f.dayMonth(d),
                      hint: l.weightChartHint,
                      summary: l.symptomChartSummary(selectedName, rangeText, inRange.length, f.n(roundTo(avg, 1), 1)),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      l.symptomStats(inRange.length, f.n(roundTo(avg, 1), 1), '$maxI'),
                      style: context.text.bodyMedium,
                    ),
                  ],
                ),
        ),
        const SizedBox(height: 12),
        if (inRange.isNotEmpty)
          SectionCard(
            title: l.weightEntriesTitle,
            icon: Icons.list,
            accent: color,
            child: Column(children: [for (final s in inRange.reversed) SymptomTile(entry: s, showDate: true)]),
          ),
      ],
    );
  }
}

Future<void> showSymptomSheet(BuildContext context, {required Day day, SymptomEntry? existing, String? presetName}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (c) => _SymptomSheet(day: day, existing: existing, presetName: presetName, parent: context),
  );
}

class _SymptomSheet extends StatefulWidget {
  final Day day;
  final SymptomEntry? existing;
  final String? presetName;
  final BuildContext parent;

  const _SymptomSheet({required this.day, required this.existing, required this.presetName, required this.parent});

  @override
  State<_SymptomSheet> createState() => _SymptomSheetState();
}

class _SymptomSheetState extends State<_SymptomSheet> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _note;
  late double _intensity;
  late Day _day;
  late TimeOfDay _time;

  @override
  void initState() {
    super.initState();
    final app = AppScope.read(widget.parent);
    final e = widget.existing;
    final at = e?.at ?? defaultTimeFor(app, widget.day);
    _name = TextEditingController(text: e?.name ?? widget.presetName ?? '');
    _note = TextEditingController(text: e?.note ?? '');
    _intensity = (e?.intensity ?? 3).toDouble();
    _day = at.day;
    _time = TimeOfDay(hour: at.hour, minute: at.minute);
  }

  @override
  void dispose() {
    _name.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final app = AppScope.read(widget.parent);
    final l = context.l10n;
    final nav = Navigator.of(context);
    final messenger = widget.parent;
    final at = LocalDateTime(_day, _time.hour, _time.minute);
    final note = _note.text.trim().isEmpty ? null : _note.text.trim();
    try {
      final e = widget.existing;
      final entry = e == null
          ? SymptomEntry(id: newId(), name: _name.text, intensity: _intensity.round(), at: at, note: note)
          : e.copyWith(name: _name.text, intensity: _intensity.round(), at: at, note: () => note);
      final saved = await app.db.saveSymptom(entry);
      nav.pop();
      if (messenger.mounted) {
        if (e == null) {
          showUndo(messenger, l.symptomLogged(saved.name), () => app.db.deleteSymptom(saved.id));
        } else {
          showMessage(messenger, l.commonSaved);
        }
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
    await app.db.deleteSymptom(e.id);
    nav.pop();
    if (messenger.mounted) showUndo(messenger, l.commonDeletedItem(e.name), () => app.db.saveSymptom(e));
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.read(widget.parent);
    final l = context.l10n;
    final editing = widget.existing != null;
    final typed = symptomKey(_name.text);
    final suggestions = [
      for (final n in app.db.symptomNames())
        if (typed.isEmpty || symptomKey(n.name).contains(typed)) n,
    ].take(8).toList();
    final color = areaColor(Area.symptoms, context.theme.brightness);
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + sheetBottomInset(context)),
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(editing ? l.symptomEditTitle : l.symptomAdd, style: context.text.titleLarge),
              const SizedBox(height: 16),
              TextFormField(
                controller: _name,
                autofocus: !editing && widget.presetName == null,
                maxLength: 80,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(labelText: l.symptomNameLabel, counterText: ''),
                validator: (v) => (v ?? '').trim().isEmpty ? l.commonRequired : null,
              ),
              if (suggestions.isNotEmpty &&
                  !(suggestions.length == 1 && symptomKey(suggestions.first.name) == typed)) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final n in suggestions)
                      ActionChip(label: Text(n.name), onPressed: () => setState(() => _name.text = n.name)),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(child: Text(l.symptomIntensity, style: context.text.titleSmall)),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      l.symptomIntensityValue('${_intensity.round()}'),
                      style: context.text.titleMedium?.copyWith(color: color),
                    ),
                  ),
                ],
              ),
              Slider(
                value: _intensity,
                min: 0,
                max: 10,
                divisions: 10,
                semanticFormatterCallback: (v) => l.symptomIntensityValue('${v.round()}'),
                onChanged: (v) => setState(() => _intensity = v),
              ),
              Text(l.symptomIntensityHint, style: context.text.bodySmall),
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
                decoration: InputDecoration(labelText: l.commonNoteOptional, counterText: ''),
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
