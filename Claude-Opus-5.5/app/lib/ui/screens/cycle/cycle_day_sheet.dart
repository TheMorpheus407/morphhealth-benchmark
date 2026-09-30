import 'package:flutter/material.dart' hide Flow;

import '../../../core/model/enums.dart';
import '../../../core/util/local_date.dart';
import '../../controller.dart';
import '../../theme.dart';
import '../day_detail_screen.dart';
import '../symptoms/symptom_editor.dart';
import 'period_editor.dart';

/// Shows the cycle context of one day as a bottom sheet.
Future<void> showCycleDaySheet(BuildContext context, LocalDate date) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (context, scroll) => CycleDaySheet(date: date, controller: scroll),
    ),
  );
}

/// Bleeding intensity (incl. spotting), note, period start/end and the
/// symptoms of one day.
class CycleDaySheet extends StatefulWidget {
  const CycleDaySheet({super.key, required this.date, this.controller});

  final LocalDate date;
  final ScrollController? controller;

  @override
  State<CycleDaySheet> createState() => _CycleDaySheetState();
}

class _CycleDaySheetState extends State<CycleDaySheet> {
  late final TextEditingController _note;

  @override
  void initState() {
    super.initState();
    _note = TextEditingController(text: context.appRead.data.cycleDayOn(widget.date)?.note ?? '');
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  LocalDate get _day => widget.date;

  Future<void> _setFlow(Flow? flow) async {
    final app = context.appRead;
    final s = app.s;
    final service = app.service;
    final inPeriod = app.data.periodOn(_day, app.today) != null;
    final note = app.data.cycleDayOn(_day)?.note;
    if (flow != null && flow != Flow.spotting && !inPeriod && !_day.isAfter(app.today)) {
      final previous = service.periodEndingBefore(_day);
      final choice = await showDialog<String>(
        context: context,
        builder: (context) => SimpleDialog(
          title: Text(s.flow),
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(s.flowOutsidePeriodQuestion),
            ),
            const SizedBox(height: 8),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, 'start'),
              child: Text(s.startPeriodOnDay),
            ),
            if (previous != null)
              SimpleDialogOption(
                onPressed: () => Navigator.pop(context, 'extend'),
                child: Text(s.extendPeriodToDay(app.fmt.dayMonth(_day))),
              ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, 'only'),
              child: Text(s.onlySaveBleeding),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context),
              child: Text(s.cancel),
            ),
          ],
        ),
      );
      if (choice == null) return;
      final ok = await app.run(() async {
        if (choice == 'start') {
          await _startPeriodHere();
        } else if (choice == 'extend') {
          await service.savePeriod(previous!.copyWith(end: () => _day, updatedAt: service.clock.nowUtc()));
        }
        await service.setCycleDay(_day, flow: flow, note: note);
      });
      if (!ok) return;
      return;
    }
    await app.run(() => service.setCycleDay(_day, flow: flow, note: note));
  }

  /// Starts a period on this day. If no later period exists it stays open
  /// (ongoing); otherwise it covers this day and can be extended.
  Future<void> _startPeriodHere() async {
    final app = context.appRead;
    final laterExists = app.data.periods.values.any((p) => p.start.isAfter(_day));
    await app.service.startPeriod(_day, end: laterExists ? _day : null);
    app.showMessage(app.s.periodStarted(app.fmt.dayMonth(_day)));
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final s = app.s;
    final fmt = app.fmt;
    final period = app.data.periodOn(_day, app.today);
    final inPeriod = period != null && !_day.isAfter(app.today);
    final cycleDay = app.data.cycleDayOn(_day);
    final symptoms = app.data.symptomsOn(_day);
    final future = _day.isAfter(app.today);
    return ListView(
      controller: widget.controller,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
      children: [
        Semantics(header: true, child: Text(fmt.full(_day), style: context.text.titleLarge)),
        const SizedBox(height: 4),
        Text(
          inPeriod ? s.dayInPeriod(period.start.daysUntil(_day) + 1) : s.notInPeriod,
          style: context.text.bodyMedium?.copyWith(color: context.scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 16),
        Text(s.flow, style: context.text.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: Text(s.noFlow),
              selected: cycleDay?.flow == null,
              onSelected: future ? null : (_) => _setFlow(null),
            ),
            for (final f in Flow.values)
              ChoiceChip(
                avatar: Icon(
                  f == Flow.spotting ? Icons.water_drop_outlined : Icons.water_drop,
                  size: 18,
                  color: context.colors.period,
                ),
                label: Text(s.flowName(f)),
                selected: cycleDay?.flow == f,
                onSelected: future ? null : (_) => _setFlow(f),
              ),
          ],
        ),
        const SizedBox(height: 16),
        if (!future)
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (!inPeriod)
                OutlinedButton.icon(
                  onPressed: () => app.run(_startPeriodHere),
                  icon: const Icon(Icons.play_arrow_outlined),
                  label: Text(s.startPeriodHere),
                ),
              if (inPeriod && (period.end == null || period.end != _day))
                OutlinedButton.icon(
                  onPressed: () => app.run(() async {
                    await app.service.endPeriod(period, _day);
                    app.showMessage(s.periodEnded(fmt.dayMonth(_day)));
                  }),
                  icon: const Icon(Icons.stop_outlined),
                  label: Text(s.endPeriodHere),
                ),
              if (period != null)
                TextButton.icon(
                  onPressed: () => openPeriodEditor(context, period: period),
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(s.editPeriod),
                ),
            ],
          ),
        const SizedBox(height: 16),
        TextField(
          controller: _note,
          maxLength: 2000,
          minLines: 1,
          maxLines: 4,
          decoration: InputDecoration(
            labelText: s.cycleDayNote,
            suffixIcon: IconButton(
              tooltip: s.saveNote,
              icon: const Icon(Icons.check),
              onPressed: () => app.run(() async {
                await app.service.setCycleDay(_day, flow: cycleDay?.flow, note: _note.text);
                app.showMessage(s.saved);
              }),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: Semantics(header: true, child: Text(s.symptomsOfDay, style: context.text.titleSmall))),
            TextButton.icon(
              onPressed: () => openSymptomEditor(context, date: _day),
              icon: const Icon(Icons.add),
              label: Text(s.addSymptom),
            ),
          ],
        ),
        if (symptoms.isEmpty)
          Text(s.noSymptomsOnDay, style: context.text.bodyMedium?.copyWith(color: context.scheme.onSurfaceVariant)),
        for (final e in symptoms)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: ExcludeSemantics(child: Icon(Icons.healing_outlined, color: context.colors.symptoms)),
            title: Text(e.name),
            subtitle: Text([
              '${s.intensity} ${s.intensityValue(e.intensity)}',
              if (e.time != null) fmt.time(e.time!),
              if (e.note != null) e.note!,
            ].join(' · ')),
            onTap: () => openSymptomEditor(context, entry: e),
          ),
        const SizedBox(height: 16),
        FilledButton.tonalIcon(
          onPressed: () {
            Navigator.of(context).pop();
            Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => DayDetailScreen(date: _day)));
          },
          icon: const Icon(Icons.today_outlined),
          label: Text(s.openDayDetail),
        ),
      ],
    );
  }
}
