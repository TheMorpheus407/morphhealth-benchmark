import 'package:flutter/material.dart';

import '../../../core/model/cycle_records.dart';
import '../../../core/util/local_date.dart';
import '../../controller.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/inputs.dart';

/// Opens the editor for a new past period or an existing one. With
/// [closing], an ongoing period is opened with a suggested last day.
Future<void> openPeriodEditor(
  BuildContext context, {
  Period? period,
  LocalDate? start,
  bool closing = false,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) =>
          PeriodEditor(period: period, start: start, closing: closing),
    ),
  );
}

/// Start, end (or ongoing) and note of a period.
class PeriodEditor extends StatefulWidget {
  const PeriodEditor({
    super.key,
    this.period,
    this.start,
    this.closing = false,
  });

  final Period? period;
  final LocalDate? start;
  final bool closing;

  @override
  State<PeriodEditor> createState() => _PeriodEditorState();
}

class _PeriodEditorState extends State<PeriodEditor> {
  late LocalDate _start;
  LocalDate? _end;
  late bool _ongoing;
  late final TextEditingController _note;
  String? _error;
  bool _endTouched = false;

  @override
  void initState() {
    super.initState();
    final app = context.appRead;
    final p = widget.period;
    _start = p?.start ?? widget.start ?? app.today;
    _end = p?.end ?? (p == null ? _start.addDays(4) : null);
    if (_end != null && _end!.isAfter(app.today)) _end = app.today;
    _ongoing = p != null && p.end == null;
    if (_ongoing && widget.closing) {
      // Suggest the typical length of the user's periods (else five days).
      final typical =
          app.service.cycleForecast(app.today).medianPeriodLength ?? 5;
      _ongoing = false;
      _end = _clampEnd(_start.addDays(typical - 1), app.today);
    }
    _note = TextEditingController(text: p?.note ?? '');
  }

  /// Latest possible last day: today, and at most the maximum period length.
  LocalDate _endLimit(LocalDate today) {
    final byLength = _start.addDays(Period.maxLengthDays - 1);
    final limit = byLength.isAfter(today) ? today : byLength;
    return limit.isBefore(_start) ? _start : limit;
  }

  LocalDate _clampEnd(LocalDate end, LocalDate today) {
    final limit = _endLimit(today);
    return end.isAfter(limit) ? limit : end;
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final app = context.appRead;
    final note = _note.text.trim().isEmpty ? null : _note.text.trim();
    final end = _ongoing ? null : (_end ?? _start);
    final now = app.service.clock.nowUtc();
    final p = widget.period;
    final record = p == null
        ? Period.create(start: _start, end: end, note: note, now: now)
        : p.copyWith(
            start: _start,
            end: () => end,
            note: () => note,
            updatedAt: now,
          );
    try {
      await app.service.savePeriod(record);
    } catch (e) {
      setState(() => _error = app.errorMessage(e));
      return;
    }
    app.showMessage(app.s.saved);
    if (mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final app = context.appRead;
    final s = app.s;
    final ok = await confirm(
      context,
      title: s.deleteConfirmTitle,
      message: s.deletePeriodQuestion,
      confirmLabel: s.delete,
      destructive: true,
    );
    if (!ok || !mounted) return;
    await app.run(() => app.service.deletePeriod(widget.period!));
    app.showMessage(s.deleted);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final s = app.s;
    final length = _ongoing ? null : (_start.daysUntil(_end ?? _start) + 1);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.period == null ? s.newPeriod : s.editPeriod),
        actions: [
          if (widget.period != null)
            IconButton(
              tooltip: s.delete,
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
        ],
      ),
      body: ListView(
        padding: pagePadding(context, top: 16),
        children: [
          DateField(
            label: s.periodStart,
            date: _start,
            last: app.today,
            onChanged: (d) => setState(() {
              _start = d;
              _error = null;
              if (widget.period == null && !_endTouched) {
                // A new period keeps a typical length of five days.
                final suggested = d.addDays(4);
                _end = suggested.isAfter(app.today) ? app.today : suggested;
              }
              if (_end != null && _end!.isBefore(d)) _end = d;
            }),
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(s.periodOngoing),
            value: _ongoing,
            onChanged: (v) => setState(() {
              _ongoing = v;
              _error = null;
              _end ??= _start;
            }),
          ),
          if (!_ongoing) ...[
            const SizedBox(height: 8),
            DateField(
              label: s.periodEnd,
              date: _end ?? _start,
              first: _start,
              last: _endLimit(app.today),
              onChanged: (d) => setState(() {
                _end = d;
                _endTouched = true;
                _error = null;
              }),
            ),
            if (length != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  s.periodLengthDays(length),
                  style: context.text.bodySmall,
                ),
              ),
          ],
          const SizedBox(height: 16),
          TextField(
            controller: _note,
            maxLength: 2000,
            minLines: 2,
            maxLines: 6,
            decoration: InputDecoration(labelText: s.noteOptional),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Semantics(
                liveRegion: true,
                child: Text(
                  _error!,
                  style: TextStyle(color: context.scheme.error),
                ),
              ),
            ),
          FilledButton(
            onPressed: _save,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(s.save),
            ),
          ),
        ],
      ),
    );
  }
}
