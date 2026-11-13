import 'package:flutter/material.dart';
import 'package:morphhealth_core/morphhealth_core.dart';

import '../body/body_screen.dart' show SymptomTile;
import '../body/editors.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'month_calendar.dart';
import 'period_form_screen.dart';

/// Starts a period on [day].
///
/// For today and the last few days the period is recorded as running, which
/// takes one tap. For older days the form opens with a suggested last day.
Future<void> startPeriodOn(BuildContext context, Day day) async {
  final app = context.appRead;
  final l = context.l;
  final typical = app.forecast.typicalPeriodLengthDays;
  final suggestedEnd = day.addDays(typical - 1);
  if (suggestedEnd < app.today) {
    await Navigator.of(context).push<void>(
      MaterialPageRoute(
        builder: (_) =>
            PeriodFormScreen(initialStart: day, initialEnd: suggestedEnd),
      ),
    );
    return;
  }
  Period? created;
  final ok = await guarded(context, () async {
    created = await app.repository.startPeriod(day);
  });
  if (ok && context.mounted) {
    showSnack(
      context,
      l.periodStarted,
      onUndo: () => app.repository.deletePeriod(created!.id),
    );
  }
}

/// Records [day] as the last day of [period].
Future<void> endPeriodOn(BuildContext context, Period period, Day day) async {
  final repo = context.appRead.repository;
  final l = context.l;
  final ok = await guarded(
    context,
    () => repo.savePeriod(period.copyWith(end: day)),
  );
  if (ok && context.mounted) {
    showSnack(context, l.periodEnded, onUndo: () => repo.savePeriod(period));
  }
}

/// Everything about the cycle on one day: period and bleeding strength,
/// spotting, note and symptoms, each with its actions.
class CycleDayPanel extends StatelessWidget {
  final Day day;

  /// Shows the symptoms of the day (the cycle calendar does, the common day
  /// detail has its own symptom section).
  final bool withSymptoms;

  const CycleDayPanel({super.key, required this.day, this.withSymptoms = true});

  Future<void> _editNote(BuildContext context, CycleDay? current) async {
    final l = context.l;
    final controller = TextEditingController(text: current?.note ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.dayNote),
        content: TextField(
          enableIMEPersonalizedLearning: false,
          controller: controller,
          autofocus: true,
          maxLength: 500,
          maxLines: 4,
          minLines: 2,
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(labelText: l.note, counterText: ''),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: Text(l.save),
          ),
        ],
      ),
    );
    if (result == null || !context.mounted) return;
    await guarded(
      context,
      () => context.appRead.repository.saveCycleDay(
        day,
        spotting: current?.spotting ?? false,
        note: result,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final fmt = context.fmt;
    final app = context.app;
    final repo = app.repository;
    final today = app.today;
    final info = CycleDayInfo.of(app, day);
    final colors = MhColors.of(context);
    final period = info.period;
    final cycleDay = app.data.cycleDay(day);
    final forecast = app.forecast;

    // The cycle day of a past day or of today, counted from the last period
    // that started on or before it.
    int? cycleDayNumber;
    if (day <= today) {
      for (final p in app.data.periodsSorted.reversed) {
        if (p.start <= day) {
          final n = day.daysSince(p.start) + 1;
          if (n <= CycleForecast.maxPlausibleLength) cycleDayNumber = n;
          break;
        }
      }
    }

    final children = <Widget>[];

    if (day > today) {
      if (info.expected) {
        children.add(
          _InfoLine(
            icon: Icons.event_outlined,
            color: colors.period,
            text: l.expectedPeriodDay,
          ),
        );
      } else if (info.possibleStart) {
        children.add(
          _InfoLine(
            icon: Icons.event_outlined,
            color: colors.period,
            text: l.possibleStartDay,
          ),
        );
      }
      children.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            l.futureDayHint,
            style: context.texts.bodyMedium?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        ),
      );
    } else {
      if (period != null) {
        final last = app.data.periodLastDay(period, today);
        final dayNumber = day.daysSince(period.start) + 1;
        children.add(
          _InfoLine(
            icon: Icons.water_drop,
            color: colors.period,
            text: l.periodDay(dayNumber),
            detail:
                '${fmt.range(period.start, last)}'
                '${period.end == null ? ', ${l.periodRunning}' : ''}',
          ),
        );
        children.add(
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Text(l.flowTitle, style: context.texts.labelLarge),
          ),
        );
        children.add(
          Semantics(
            label: l.flowOfDay(fmt.dateMonthLong(day)),
            container: true,
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final level in FlowLevel.values)
                  ChoiceChip(
                    label: Text(l.flow(level)),
                    selected: info.flow == level,
                    onSelected: (on) => guarded(
                      context,
                      () => repo.setFlow(period.id, day, on ? level : null),
                    ),
                  ),
              ],
            ),
          ),
        );
        children.add(const SizedBox(height: 8));
        children.add(
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              if (period.end == null || day < period.end!)
                FilledButton.tonal(
                  onPressed: () => endPeriodOn(context, period, day),
                  child: Text(l.periodEndedThisDay),
                ),
              OutlinedButton.icon(
                icon: const Icon(Icons.edit_outlined),
                label: Text(l.editPeriod),
                onPressed: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => PeriodFormScreen(period: period),
                  ),
                ),
              ),
            ],
          ),
        );
      } else {
        if (info.possibleStart && forecast.hasEstimate) {
          children.add(
            _InfoLine(
              icon: Icons.event_outlined,
              color: colors.period,
              text: l.possibleStartDay,
            ),
          );
        }
        children.add(
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: FilledButton.tonalIcon(
                icon: const Icon(Icons.water_drop_outlined),
                label: Text(l.periodBeganThisDay),
                onPressed: () => startPeriodOn(context, day),
              ),
            ),
          ),
        );
        children.add(
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l.spottingThisDay),
            value: cycleDay?.spotting ?? false,
            onChanged: (v) => guarded(
              context,
              () => repo.saveCycleDay(day, spotting: v, note: cycleDay?.note),
            ),
          ),
        );
      }

      final note = cycleDay?.note;
      children.add(
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.sticky_note_2_outlined),
          title: Text(note == null || note.isEmpty ? l.dayNote : note),
          subtitle: note == null || note.isEmpty ? null : Text(l.dayNote),
          trailing: const Icon(Icons.edit_outlined),
          onTap: () => _editNote(context, cycleDay),
        ),
      );

      if (withSymptoms) {
        final symptoms = app.data.symptomsOn(day);
        children.add(
          SectionTitle(
            l.symptomsThisDay,
            padding: const EdgeInsets.fromLTRB(0, 12, 0, 0),
          ),
        );
        if (symptoms.isEmpty) {
          children.add(
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Text(
                l.noSymptomsThisDay,
                style: context.texts.bodyMedium?.copyWith(
                  color: context.colors.onSurfaceVariant,
                ),
              ),
            ),
          );
        } else {
          for (final s in symptoms) {
            children.add(SymptomTile(entry: s, showDate: false));
          }
        }
        children.add(
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              icon: const Icon(Icons.add),
              label: Text(l.addSymptom),
              onPressed: () => showSymptomEditor(context, day: day),
            ),
          ),
        );
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (cycleDayNumber != null)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              l.cycleDay(cycleDayNumber),
              style: context.texts.bodyMedium?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ),
        ...children,
      ],
    );
  }
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;
  final String? detail;

  const _InfoLine({
    required this.icon,
    required this.color,
    required this.text,
    this.detail,
  });

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ExcludeSemantics(child: Icon(icon, color: color, size: 20)),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(text, style: context.texts.bodyLarge),
              if (detail != null)
                Text(
                  detail!,
                  style: context.texts.bodyMedium?.copyWith(
                    color: context.colors.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ),
      ],
    ),
  );
}
