import 'package:flutter/material.dart';

import '../../core/civil.dart';
import '../../core/cycle.dart';
import '../../core/db.dart';
import '../../core/ids.dart';
import '../../core/models.dart';
import '../../state/app_state.dart';
import '../l10n_x.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'explain_screen.dart';

/// Text zu einer Blutungsstärke für Screenreader und Beschriftungen.
String flowLabel(BuildContext context, FlowLevel? f) => context.l10n.flow(f);

/// Inhalt der persönlichen Einschätzung (Überschrift, Zeilen, Erklärung) ohne
/// eigene Karte, damit er in Karten und Abschnitte eingebettet werden kann.
class ForecastBody extends StatelessWidget {
  final Forecast forecast;

  const ForecastBody({super.key, required this.forecast});

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final f = context.fmt;
    final fc = forecast;
    String title;
    String? body;
    final lines = <String>[];
    switch (fc.status) {
      case ForecastStatus.noData:
        title = l.cycleNoDataTitle;
        body = l.cycleNoDataBody;
      case ForecastStatus.insufficientData:
        title = l.cycleInsufficientTitle;
        body = l.cycleInsufficientBody;
      case ForecastStatus.inPeriod:
        title = l.cycleInPeriodTitle('${fc.periodDay}');
      case ForecastStatus.predicted:
        title = l.cyclePredictedIn(fc.daysUntil ?? 0);
      case ForecastStatus.overdue:
        title = l.cycleOverdueTitle(fc.daysOverdue ?? 0);
        body = l.cycleOverdueBody;
      case ForecastStatus.stale:
        title = l.cycleStaleTitle;
        body = l.cycleStaleBody;
      case ForecastStatus.disabled:
        title = l.cycleDisabledTitle;
        body = l.cycleDisabledBody;
    }
    if (fc.predictedStart != null) {
      lines.add(l.cycleNextStart(f.date(fc.predictedStart!)));
      if (fc.earliest != null && fc.latest != null) {
        lines.add(l.cycleWindowLine(f.dayMonth(fc.earliest!), f.date(fc.latest!)));
      }
    }
    if (fc.cycleDay != null && fc.status != ForecastStatus.disabled) lines.add(l.cycleCycleDay('${fc.cycleDay}'));
    final conf = switch (fc.confidence) {
      'high' => l.cycleConfHigh,
      'medium' => l.cycleConfMedium,
      'low' => l.cycleConfLow,
      _ => null,
    };
    if (conf != null && fc.predictedStart != null) lines.add(l.cycleConfidence(conf));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          liveRegion: true,
          child: Text(title, style: context.text.titleLarge?.copyWith(fontWeight: FontWeight.w600)),
        ),
        if (body != null) ...[const SizedBox(height: 4), Text(body, style: context.text.bodyMedium)],
        for (final line in lines)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(line, style: context.text.bodyMedium),
          ),
        if (fc.status != ForecastStatus.disabled) ...[
          const SizedBox(height: 4),
          TextButton.icon(
            onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => ExplainScreen(forecast: fc))),
            icon: const Icon(Icons.help_outline),
            label: Text(l.cycleExplainButton),
          ),
        ],
      ],
    );
  }
}

/// Karte mit der persönlichen Einschätzung für den gewählten Tag.
class ForecastCard extends StatelessWidget {
  final Forecast forecast;

  const ForecastCard({super.key, required this.forecast});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final l = context.l10n;
    final f = context.fmt;
    final color = areaColor(Area.cycle, context.theme.brightness);
    return SectionCard(
      title: l.cycleForecastTitle,
      icon: areaIcon(Area.cycle),
      accent: color,
      trailing: app.selectedDay == app.today
          ? null
          : Text(l.cycleStateAsOf(f.date(app.selectedDay)), style: context.text.labelMedium),
      child: ForecastBody(forecast: forecast),
    );
  }
}

/// "Periode beginnt" beziehungsweise "Periode endet" für den gewählten Tag.
class PeriodQuickActions extends StatelessWidget {
  const PeriodQuickActions({super.key});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final l = context.l10n;
    final f = context.fmt;
    final day = app.selectedDay;
    final isToday = day == app.today;
    final open = app.db.periods
        .where((p) => p.isOpen && !p.start.isAfter(day) && day.daysUntil(p.start).abs() < 60)
        .toList();
    final canEnd =
        open.isNotEmpty && !open.last.start.isAfter(day) && open.last.start.daysUntil(day) < PeriodRecord.maxDays;
    final startLabel = isToday ? l.cycleStartToday : l.cycleStartOnDay(f.date(day));
    final endLabel = isToday ? l.cycleEndToday : l.cycleEndOnDay(f.date(day));
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        FilledButton.tonalIcon(
          onPressed: () => startPeriodOn(context, app, day),
          icon: const Icon(Icons.play_arrow),
          label: Text(startLabel),
        ),
        if (canEnd)
          OutlinedButton.icon(
            onPressed: () => endPeriodOn(context, app, open.last, day),
            icon: const Icon(Icons.stop),
            label: Text(endLabel),
          ),
      ],
    );
  }
}

Future<void> startPeriodOn(BuildContext context, AppState app, Day day) async {
  final l = context.l10n;
  final f = context.fmt;
  final messenger = context;
  try {
    final p = PeriodRecord(id: newId(), start: day);
    await app.db.savePeriod(p);
    if (messenger.mounted) showUndo(messenger, l.cycleStartedSnack(f.date(day)), () => app.db.deletePeriod(p.id));
  } on DomainException catch (e) {
    if (messenger.mounted) showMessage(messenger, periodErrorText(messenger, e));
  }
}

Future<void> endPeriodOn(BuildContext context, AppState app, PeriodRecord p, Day day) async {
  final l = context.l10n;
  final f = context.fmt;
  final messenger = context;
  try {
    await app.db.savePeriod(p.copyWith(end: () => day));
    if (messenger.mounted) showUndo(messenger, l.cycleEndedSnack(f.date(day)), () => app.db.savePeriod(p));
  } on DomainException catch (e) {
    if (messenger.mounted) showMessage(messenger, periodErrorText(messenger, e));
  }
}

/// Verständliche Meldung zu Fehlern beim Speichern einer Periode.
String periodErrorText(BuildContext context, DomainException e) {
  final l = context.l10n;
  final f = context.fmt;
  switch (e.code) {
    case 'period_overlap':
      final from = Day.tryParse(e.details['other_start'] as String?);
      final to = Day.tryParse(e.details['other_end'] as String?);
      return l.cycleOverlap(from == null ? '' : f.date(from), to == null ? l.cycleHistoryOngoing : f.date(to));
    case 'invalid_period':
      return e.message.contains('Beginn') ? l.cycleEndBeforeStart : l.cycleTooLong;
    default:
      return domainErrorText(l, e);
  }
}

/// Blatt zum Erfassen oder Bearbeiten einer Periode.
Future<void> showPeriodSheet(BuildContext context, {PeriodRecord? existing, Day? start}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (c) => _PeriodSheet(existing: existing, start: start, parent: context),
  );
}

class _PeriodSheet extends StatefulWidget {
  final PeriodRecord? existing;
  final Day? start;
  final BuildContext parent;

  const _PeriodSheet({required this.existing, required this.start, required this.parent});

  @override
  State<_PeriodSheet> createState() => _PeriodSheetState();
}

class _PeriodSheetState extends State<_PeriodSheet> {
  late Day _start;
  Day? _end;
  bool _ongoing = false;
  FlowLevel? _flow;
  late final TextEditingController _notes;
  String? _error;

  @override
  void initState() {
    super.initState();
    final app = AppScope.read(widget.parent);
    final e = widget.existing;
    _start = e?.start ?? widget.start ?? app.selectedDay;
    _end = e?.end;
    _ongoing = e == null ? false : e.end == null;
    _flow = e?.flow ?? (e == null ? FlowLevel.medium : null);
    _notes = TextEditingController(text: e?.notes ?? '');
    if (e == null) {
      // Neue Periode: Vorschlag Ende = Beginn + 4 Tage (fünf Tage), aber höchstens heute.
      final guess = _start.addDays(4);
      _end = guess.isAfter(app.today) ? (_start.isAfter(app.today) ? _start : app.today) : guess;
    }
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final app = AppScope.read(widget.parent);
    final nav = Navigator.of(context);
    final messenger = widget.parent;
    final l = context.l10n;
    final notes = _notes.text.trim().isEmpty ? null : _notes.text.trim();
    final end = _ongoing ? null : _end;
    if (end != null && end.isBefore(_start)) {
      setState(() => _error = l.cycleEndBeforeStart);
      return;
    }
    try {
      final e = widget.existing;
      // Tagesangaben, die außerhalb der neuen Spanne liegen, entfallen.
      Map<Day, FlowLevel> dayFlows = e?.dayFlows ?? const {};
      final last = end ?? _start.addDays(PeriodRecord.maxDays - 1);
      dayFlows = {
        for (final d in dayFlows.entries)
          if (!d.key.isBefore(_start) && !d.key.isAfter(last) && d.value != _flow) d.key: d.value,
      };
      final p = e == null
          ? PeriodRecord(id: newId(), start: _start, end: end, flow: _flow, notes: notes)
          : e.copyWith(start: _start, end: () => end, flow: () => _flow, dayFlows: dayFlows, notes: () => notes);
      await app.db.savePeriod(p);
      nav.pop();
      if (messenger.mounted) showMessage(messenger, l.commonSaved);
    } on DomainException catch (ex) {
      if (mounted) setState(() => _error = periodErrorText(context, ex));
    }
  }

  Future<void> _delete() async {
    final app = AppScope.read(widget.parent);
    final l = context.l10n;
    final f = context.fmt;
    final nav = Navigator.of(context);
    final messenger = widget.parent;
    final e = widget.existing!;
    final ok = await confirmDialog(
      context,
      title: l.cycleDeleteTitle,
      message: l.cycleDeleteMessage(f.date(e.start)),
      confirmLabel: l.commonDelete,
      destructive: true,
    );
    if (!ok) return;
    await app.db.deletePeriod(e.id);
    nav.pop();
    if (messenger.mounted) showUndo(messenger, l.commonDeletedItem(l.cycleLegendPeriod), () => app.db.savePeriod(e));
  }

  @override
  Widget build(BuildContext context) {
    final app = AppScope.read(widget.parent);
    final l = context.l10n;
    final f = context.fmt;
    final editing = widget.existing != null;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + sheetBottomInset(context)),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(editing ? l.cycleEditPeriod : l.cycleAddPeriod, style: context.text.titleLarge),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52), alignment: Alignment.centerLeft),
              icon: const Icon(Icons.event),
              label: Text('${l.cycleStart}: ${f.dateWithWeekday(_start)}'),
              onPressed: () async {
                final d = await pickDay(context, _start, last: app.today.addDays(366));
                if (d != null) {
                  setState(() {
                    _start = d;
                    _error = null;
                    if (_end != null && _end!.isBefore(d)) _end = d;
                  });
                }
              },
            ),
            const SizedBox(height: 8),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l.cycleOngoing),
              value: _ongoing,
              onChanged: (v) => setState(() {
                _ongoing = v;
                _error = null;
                _end ??= _start;
              }),
            ),
            if (!_ongoing)
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52), alignment: Alignment.centerLeft),
                icon: const Icon(Icons.event_available),
                label: Text('${l.cycleEnd}: ${f.dateWithWeekday(_end ?? _start)}'),
                onPressed: () async {
                  final d = await pickDay(
                    context,
                    _end ?? _start,
                    first: _start,
                    last: _start.addDays(PeriodRecord.maxDays - 1),
                  );
                  if (d != null) {
                    setState(() {
                      _end = d;
                      _error = null;
                    });
                  }
                },
              ),
            const SizedBox(height: 16),
            Text(l.cycleFlow, style: context.text.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final v in [null, ...FlowLevel.values])
                  ChoiceChip(
                    label: Text(l.flow(v)),
                    selected: _flow == v,
                    onSelected: (_) => setState(() => _flow = v),
                  ),
              ],
            ),
            if (_flow == FlowLevel.spotting) ...[
              const SizedBox(height: 8),
              EmptyHint(l.cycleSpottingNote, icon: Icons.info_outline),
            ],
            const SizedBox(height: 16),
            TextFormField(
              controller: _notes,
              maxLength: 1000,
              minLines: 1,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: l.cycleNotes, counterText: ''),
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Semantics(
                  liveRegion: true,
                  child: Text(_error!, style: TextStyle(color: context.colors.error)),
                ),
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
    );
  }
}
