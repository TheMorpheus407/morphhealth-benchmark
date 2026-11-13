import 'package:flutter/material.dart';
import 'package:morphhealth_core/morphhealth_core.dart';

import '../widgets/common.dart';

/// Form for recording or correcting a period: first day, last day (or still
/// running), bleeding strength per day and a note.
class PeriodFormScreen extends StatefulWidget {
  /// The period to edit; null records a new one.
  final Period? period;
  final Day? initialStart;
  final Day? initialEnd;

  const PeriodFormScreen({
    super.key,
    this.period,
    this.initialStart,
    this.initialEnd,
  });

  @override
  State<PeriodFormScreen> createState() => _PeriodFormScreenState();
}

class _PeriodFormScreenState extends State<PeriodFormScreen> {
  final _note = TextEditingController();
  late Day _start;
  Day? _end;
  late bool _running;
  late Map<Day, FlowLevel> _flow;
  String? _error;
  bool _initialized = false;
  bool _saving = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final app = context.appRead;
    final p = widget.period;
    if (p != null) {
      _start = p.start;
      _end = p.end;
      _running = p.end == null;
      _flow = Map.of(p.flow);
      _note.text = p.note ?? '';
    } else {
      _start = widget.initialStart ?? app.today;
      _end = widget.initialEnd;
      _running = _end == null;
      _flow = {};
    }
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  /// The days whose bleeding strength can be set.
  List<Day> get _days {
    final today = context.appRead.today;
    var last = _end ?? today;
    final limit = _start.addDays(Period.maxLengthDays - 1);
    if (last > limit) last = limit;
    if (_running) {
      final open = _start.addDays(Period.openPeriodDays - 1);
      if (last > open) last = open;
    }
    return [for (var d = _start; d <= last; d = d.addDays(1)) d];
  }

  Future<void> _save() async {
    if (_saving) return;
    final l = context.l;
    final fmt = context.fmt;
    final app = context.appRead;
    final end = _running ? null : _end;
    if (_start > app.today || (end != null && end > app.today)) {
      setState(() => _error = l.periodInFuture);
      return;
    }
    if (!_running && end == null) {
      setState(() => _error = l.requiredField);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final now = app.now;
    final existing = widget.period;
    final note = _note.text.trim().isEmpty ? null : _note.text.trim();
    final valid = {for (final d in _days) d};
    final period = Period(
      id: existing?.id ?? app.repository.createId(),
      start: _start,
      end: end,
      flow: {
        for (final e in _flow.entries)
          if (valid.contains(e.key)) e.key: e.value,
      },
      note: note,
      createdAt: existing?.createdAt ?? now,
      updatedAt: now,
    );
    try {
      await app.repository.savePeriod(period);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(l.saved)));
    } on ValidationException catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = l.validation(e, fmt.date);
        });
      }
    } on Object catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showSnack(context, describeError(context, e));
      }
    }
  }

  Future<void> _delete() async {
    final period = widget.period!;
    final l = context.l;
    final repo = context.appRead.repository;
    final sure = await confirm(
      context,
      title: l.deletePeriodConfirm,
      action: l.delete,
      destructive: true,
    );
    if (!sure || !mounted) return;
    final ok = await guarded(context, () => repo.deletePeriod(period.id));
    if (!ok || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l.periodDeleted),
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: l.undo,
            onPressed: () => repo.savePeriod(period),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final fmt = context.fmt;
    final today = context.app.today;
    final days = _days;
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.period == null ? l.periodNew : l.editPeriod),
        actions: [
          if (widget.period != null)
            IconButton(
              tooltip: l.delete,
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
          Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: TextButton(
              onPressed: _saving ? null : _save,
              child: Text(l.save),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            DateField(
              label: l.periodFirstDay,
              value: _start,
              first: DayBar.firstSelectable,
              last: today,
              onChanged: (d) => setState(() {
                _start = d;
                if (_end != null && _end! < d) _end = d;
                _error = null;
              }),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l.periodStillRunning),
              value: _running,
              onChanged: (v) => setState(() {
                _running = v;
                if (!v && _end == null) {
                  final typical =
                      context.appRead.forecast.typicalPeriodLengthDays;
                  final suggested = _start.addDays(typical - 1);
                  _end = suggested > today ? today : suggested;
                }
                _error = null;
              }),
            ),
            if (!_running)
              DateField(
                label: l.periodLastDay,
                value: _end,
                first: _start,
                last: today,
                onChanged: (d) => setState(() {
                  _end = d;
                  _error = null;
                }),
              ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Semantics(
                  container: true,
                  liveRegion: true,
                  child: Text(
                    _error!,
                    style: TextStyle(color: context.colors.error),
                  ),
                ),
              ),
            SectionTitle(
              l.flowPerDay,
              padding: const EdgeInsets.fromLTRB(0, 20, 0, 8),
            ),
            for (final d in days)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: ChoiceField<FlowLevel?>(
                  key: ValueKey('flow-$d'),
                  label: fmt.day(d),
                  value: _flow[d],
                  options: [
                    (null, l.flowNone),
                    for (final f in FlowLevel.values) (f, l.flow(f)),
                  ],
                  onChanged: (level) => setState(() {
                    if (level == null) {
                      _flow.remove(d);
                    } else {
                      _flow[d] = level;
                    }
                  }),
                ),
              ),
            const SizedBox(height: 4),
            TextField(
              enableIMEPersonalizedLearning: false,
              controller: _note,
              maxLength: 500,
              maxLines: null,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: l.noteOptional,
                counterText: '',
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(l.save),
            ),
          ],
        ),
      ),
    );
  }
}
