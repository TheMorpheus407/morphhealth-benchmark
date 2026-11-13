/// Personal Period Tracker screen (P04) with transparent personal forecast,
/// interactive month calendar, day-context symptoms & flow, diary-only mode,
/// and recorded period history.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/clock.dart';
import '../../core/cycle_engine.dart';
import '../../core/models.dart';
import '../app_controller.dart';
import '../sheets/entry_editors.dart';
import '../theme.dart';
import 'day_detail_screen.dart';

class CycleScreen extends StatefulWidget {
  final AppController controller;

  const CycleScreen({super.key, required this.controller});

  @override
  State<CycleScreen> createState() => _CycleScreenState();
}

class _CycleScreenState extends State<CycleScreen> {
  late int _viewYear;
  late int _viewMonth;
  late String _focusedDayIso;

  @override
  void initState() {
    super.initState();
    _focusedDayIso = widget.controller.selectedDate;
    final dt = IsoDate.parseUtc(_focusedDayIso);
    _viewYear = dt.year;
    _viewMonth = dt.month;
  }

  void _stepMonth(int delta) {
    setState(() {
      final shifted = DateTime.utc(_viewYear, _viewMonth + delta, 1);
      _viewYear = shifted.year;
      _viewMonth = shifted.month;
      final daysInM = DateTime.utc(_viewYear, _viewMonth + 1, 0).day;
      final curDay = int.parse(_focusedDayIso.substring(8, 10)).clamp(1, daysInM);
      _focusedDayIso = IsoDate.formatUtc(
        DateTime.utc(_viewYear, _viewMonth, curDay),
      );
    });
  }

  void _jumpToToday() {
    final today = widget.controller.todayDate;
    final dt = IsoDate.parseUtc(today);
    setState(() {
      _viewYear = dt.year;
      _viewMonth = dt.month;
      _focusedDayIso = today;
    });
  }

  Future<void> _pickMonthViaDateDialog(BuildContext context) async {
    final dt = IsoDate.parseUtc(_focusedDayIso);
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(dt.year, dt.month, dt.day),
      firstDate: DateTime(1990, 1, 1),
      lastDate: DateTime(2100, 12, 31),
      locale: Locale(widget.controller.localeCode),
    );
    if (picked != null) {
      setState(() {
        _viewYear = picked.year;
        _viewMonth = picked.month;
        _focusedDayIso = IsoDate.fromLocalDateTime(picked);
      });
    }
  }

  void _showForecastExplanationSheet(
    BuildContext context,
    CycleForecastResult fc,
  ) {
    final s = widget.controller.strings;
    final stats = fc.statistics;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            4,
            20,
            MediaQuery.viewPaddingOf(ctx).bottom + 28,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                s.tr(
                  'Persönliche Zykluseinschätzung',
                  'Personal Cycle Assessment',
                ),
                style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
              ),
              const SizedBox(height: 12),
              Text(
                fc.explanation(widget.controller.localeCode),
                style: const TextStyle(fontSize: 14.5, height: 1.45),
              ),
              if (stats.cyclesUsedCount > 0) ...[
                const Divider(height: 24),
                Text(
                  s.tr('Statistische Kennzahlen deiner Daten:', 'Metrics from your recorded history:'),
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                Text(
                  '• ${s.tr("Erfasste Perioden", "Recorded periods")}: ${stats.recordedPeriodsCount}',
                ),
                Text(
                  '• ${s.tr("Ausgewertete Zyklen", "Evaluated cycles")}: ${stats.cyclesUsedCount} (${stats.cycleLengthsDays.join(", ")} ${s.tr("Tage", "days")})',
                ),
                Text(
                  '• ${s.tr("Spanne", "Range")}: ${stats.minCycleDays}–${stats.maxCycleDays} ${s.tr("Tage", "days")}',
                ),
                if (stats.stdDevDays != null)
                  Text(
                    '• ${s.tr("Persönliche Streuung", "Personal variability")}: ±${stats.stdDevDays!.toStringAsFixed(1)} ${s.tr("Tage", "days")}',
                  ),
                if (fc.expectedPeriodDurationDays != null)
                  Text(
                    '• ${s.tr("Typische Blutungsdauer", "Typical bleeding duration")}: ${fc.expectedPeriodDurationDays} ${s.tr("Tage", "days")}',
                  ),
              ],
              const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: () => Navigator.pop(ctx),
                  child: Text(s.close),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = widget.controller;
    final s = c.strings;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent =
        isDark ? MhColors.cycleAccentDark : MhColors.cycleAccentLight;

    final forecast = c.store.cycleForecastOn(c.todayDate);
    final allPeriods = c.store.allPeriods;
    final dayPeriods = c.store.periodsCoveringDate(_focusedDayIso);
    final daySymptoms = c.store.symptomsForDay(_focusedDayIso);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          s.cycleTrackerTitle,
          style: const TextStyle(fontSize: 17.5),
        ),
        actions: [
          FilterChip(
            label: Text(s.diaryOnlyLabel),
            selected: c.preferences.cycleDiaryOnlyMode,
            onSelected: (v) => c.updatePreferences(
              c.preferences.copyWith(cycleDiaryOnlyMode: v),
            ),
          ),
          const SizedBox(width: 12),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab_cycle',
        onPressed: () => showPeriodEditorSheet(
          context,
          c,
          initialStartDate: _focusedDayIso,
        ),
        icon: const Icon(Icons.add_rounded),
        label: Text(s.logPeriodOrSpotting),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 88),
        children: [
          // 1. Personal Forecast / Diary Banner
          _ForecastSummaryCard(
            controller: c,
            forecast: forecast,
            accent: accent,
            onExplain: () => _showForecastExplanationSheet(context, forecast),
          ),
          const SizedBox(height: 12),

          // 2. Interactive Month Calendar
          _MonthCalendarCard(
            controller: c,
            year: _viewYear,
            month: _viewMonth,
            focusedDayIso: _focusedDayIso,
            forecast: forecast,
            accent: accent,
            onStepMonth: _stepMonth,
            onJumpToday: _jumpToToday,
            onPickMonth: () => _pickMonthViaDateDialog(context),
            onSelectDay: (iso) => setState(() => _focusedDayIso = iso),
          ),
          const SizedBox(height: 12),

          // 3. Focused Day Context (Period + Daily Flow + Symptoms right in context!)
          _FocusedDayContextCard(
            controller: c,
            dateIso: _focusedDayIso,
            periodsOnDay: dayPeriods,
            symptomsOnDay: daySymptoms,
            accent: accent,
          ),
          const SizedBox(height: 14),

          // 4. Period History List
          Text(
            s.periodHistory,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          if (allPeriods.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Text(
                  s.tr(
                    'Noch keine Perioden oder Spotting-Einträge protokolliert.',
                    'No periods or spotting entries recorded yet.',
                  ),
                ),
              ),
            )
          else
            for (var i = 0; i < allPeriods.length; i++) ...[
              _PeriodHistoryTile(
                entry: allPeriods[i],
                // Next chronological period is at i-1 because allPeriods is sorted newest-first
                nextPeriodStart:
                    (i > 0 && allPeriods[i].countsAsPeriod && allPeriods[i - 1].countsAsPeriod)
                        ? allPeriods[i - 1].startDate
                        : null,
                controller: c,
                accent: accent,
              ),
              const SizedBox(height: 8),
            ],
        ],
      ),
    );
  }
}

class _ForecastSummaryCard extends StatelessWidget {
  final AppController controller;
  final CycleForecastResult forecast;
  final Color accent;
  final VoidCallback onExplain;

  const _ForecastSummaryCard({
    required this.controller,
    required this.forecast,
    required this.accent,
    required this.onExplain,
  });

  @override
  Widget build(BuildContext context) {
    final s = controller.strings;
    final cs = Theme.of(context).colorScheme;

    String title;
    String subtitle;
    if (forecast.diaryOnlyMode) {
      title = s.tr(
        'Tagebuch-Modus aktiv',
        'Diary-only mode active',
      );
      subtitle = forecast.currentCycleDay != null
          ? '${s.tr("Aktueller Zyklustag", "Current cycle day")}: ${forecast.currentCycleDay}'
          : s.tr(
              'Kalender und Historie dienen rein der eigenen Dokumentation.',
              'Calendar and history are used purely as a personal diary.',
            );
    } else if (forecast.isPeriodActiveOnDate) {
      title = s.tr('Aktuelle Periode / Blutung', 'Active period / bleeding');
      subtitle = forecast.currentCycleDay != null
          ? '${s.tr("Zyklustag", "Cycle day")} ${forecast.currentCycleDay} · ${forecast.activeFlowIntensity?.label(controller.localeCode) ?? ""}'
          : '';
    } else if (forecast.predictedNextStart != null) {
      final days = forecast.daysUntilExpectedStart ?? 0;
      title = days > 0
          ? s.tr(
              'Nächste Periode voraussichtlich um ${forecast.predictedNextStart} (in $days Tagen)',
              'Next period expected around ${forecast.predictedNextStart} (in $days days)',
            )
          : (days == 0
              ? s.tr(
                  'Voraussichtlicher Beginn um heute (${forecast.predictedNextStart})',
                  'Expected start around today (${forecast.predictedNextStart})',
                )
              : s.tr(
                  '${days.abs()} Tage nach üblichem Richtwert (${forecast.predictedNextStart})',
                  '${days.abs()} days past typical estimate (${forecast.predictedNextStart})',
                ));
      subtitle =
          '${s.tr("Planungsfenster", "Planning window")}: ${forecast.predictedWindowStart} – ${forecast.predictedWindowEnd} · ${s.tr("Übliche Zykluslänge", "Typical cycle")}: ${forecast.expectedCycleLengthDays} ${s.tr("Tage", "days")}';
    } else {
      title = forecast.status == 'awaiting_second_period'
          ? '${s.tr("Zyklustag", "Cycle day")} ${forecast.currentCycleDay}'
          : s.tr('Persönliche Zyklusplanung', 'Personal cycle planning');
      subtitle = forecast.explanation(controller.localeCode);
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_graph_rounded, color: accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            if (subtitle.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: TextStyle(color: cs.onSurfaceVariant, height: 1.35),
              ),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onExplain,
                icon: const Icon(Icons.info_outline_rounded, size: 18),
                label: Text(s.explainForecast),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthCalendarCard extends StatelessWidget {
  final AppController controller;
  final int year;
  final int month;
  final String focusedDayIso;
  final CycleForecastResult forecast;
  final Color accent;
  final void Function(int) onStepMonth;
  final VoidCallback onJumpToday;
  final VoidCallback onPickMonth;
  final void Function(String) onSelectDay;

  const _MonthCalendarCard({
    required this.controller,
    required this.year,
    required this.month,
    required this.focusedDayIso,
    required this.forecast,
    required this.accent,
    required this.onStepMonth,
    required this.onJumpToday,
    required this.onPickMonth,
    required this.onSelectDay,
  });

  @override
  Widget build(BuildContext context) {
    final s = controller.strings;
    final cs = Theme.of(context).colorScheme;
    final monthTitle = DateFormat(
      'MMMM yyyy',
      controller.localeCode == 'en' ? 'en_US' : 'de_DE',
    ).format(DateTime(year, month, 1));

    final weekdays = controller.localeCode == 'en'
        ? const ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun']
        : const ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So'];

    final firstOfMonth = DateTime.utc(year, month, 1);
    final leadingBlanks = firstOfMonth.weekday - 1; // Monday = 0
    final daysInMonth = DateTime.utc(year, month + 1, 0).day;
    final totalCells = ((leadingBlanks + daysInMonth + 6) ~/ 7) * 7;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  tooltip: s.tr('Vorheriger Monat', 'Previous month'),
                  onPressed: () => onStepMonth(-1),
                  icon: const Icon(Icons.chevron_left_rounded),
                ),
                Expanded(
                  child: InkWell(
                    borderRadius: BorderRadius.circular(8),
                    onTap: onPickMonth,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        monthTitle,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ),
                TextButton(
                  onPressed: onJumpToday,
                  child: Text(s.today),
                ),
                IconButton(
                  tooltip: s.tr('Nächster Monat', 'Next month'),
                  onPressed: () => onStepMonth(1),
                  icon: const Icon(Icons.chevron_right_rounded),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                for (final wd in weekdays)
                  Expanded(
                    child: Center(
                      child: Text(
                        wd,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: totalCells,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
                childAspectRatio: 1.0,
              ),
              itemBuilder: (ctx, index) {
                final dayNum = index - leadingBlanks + 1;
                if (dayNum < 1 || dayNum > daysInMonth) {
                  return const SizedBox.shrink();
                }
                final dateIso = IsoDate.formatUtc(
                  DateTime.utc(year, month, dayNum),
                );
                final periods = controller.store.periodsCoveringDate(dateIso);
                final hasPeriod = periods.any((p) => p.countsAsPeriod);
                final hasSpottingOnly =
                    !hasPeriod && periods.any((p) => !p.countsAsPeriod);
                final inPredPeriod = forecast.isDateInPredictedPeriod(dateIso);
                final inPredWindow = forecast.isDateInPredictedWindow(dateIso);
                final symptomsCount =
                    controller.store.symptomsForDay(dateIso).length;
                final isSelected = dateIso == focusedDayIso;
                final isToday = dateIso == controller.todayDate;

                Color? bg;
                Border? border;
                Color textColor = cs.onSurface;

                if (hasPeriod) {
                  bg = accent.withValues(alpha: 0.85);
                  textColor = Colors.white;
                } else if (hasSpottingOnly) {
                  bg = accent.withValues(alpha: 0.24);
                } else if (inPredPeriod) {
                  bg = accent.withValues(alpha: 0.14);
                  border = Border.all(
                    color: accent.withValues(alpha: 0.7),
                    width: 1.3,
                  );
                } else if (inPredWindow) {
                  bg = accent.withValues(alpha: 0.06);
                }

                if (isSelected) {
                  border = Border.all(color: cs.primary, width: 2.3);
                } else if (isToday && border == null) {
                  border = Border.all(color: cs.outline, width: 1.2);
                }

                return Semantics(
                  label:
                      '$dateIso${hasPeriod ? ", ${s.tr("Periode", "Period")}" : ""}${hasSpottingOnly ? ", Spotting" : ""}${symptomsCount > 0 ? ", $symptomsCount ${s.symptomsTitle}" : ""}',
                  selected: isSelected,
                  button: true,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => onSelectDay(dateIso),
                    child: Container(
                      decoration: BoxDecoration(
                        color: bg,
                        borderRadius: BorderRadius.circular(10),
                        border: border,
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Text(
                            '$dayNum',
                            style: TextStyle(
                              fontWeight: (isSelected || isToday || hasPeriod)
                                  ? FontWeight.w700
                                  : FontWeight.w500,
                              color: textColor,
                            ),
                          ),
                          if (symptomsCount > 0)
                            Positioned(
                              bottom: 4,
                              child: Container(
                                width: 6,
                                height: 6,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: hasPeriod
                                      ? Colors.white
                                      : MhColors.symptomAccentLight,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 10),
            // Compact accessible legend
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                _LegendItem(
                  color: accent.withValues(alpha: 0.85),
                  label: s.tr('Periode', 'Period'),
                ),
                _LegendItem(
                  color: accent.withValues(alpha: 0.24),
                  label: 'Spotting',
                ),
                if (!forecast.diaryOnlyMode)
                  _LegendItem(
                    color: accent.withValues(alpha: 0.14),
                    outlined: true,
                    borderColor: accent,
                    label: s.tr('Geplant / Fenster', 'Planned / window'),
                  ),
                _LegendItem(
                  color: MhColors.symptomAccentLight,
                  isDot: true,
                  label: s.symptomsTitle,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;
  final bool outlined;
  final Color? borderColor;
  final bool isDot;

  const _LegendItem({
    required this.color,
    required this.label,
    this.outlined = false,
    this.borderColor,
    this.isDot = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: isDot ? 8 : 12,
          height: isDot ? 8 : 12,
          decoration: BoxDecoration(
            color: color,
            shape: isDot ? BoxShape.circle : BoxShape.rectangle,
            borderRadius: isDot ? null : BorderRadius.circular(3),
            border: outlined && borderColor != null
                ? Border.all(color: borderColor!)
                : null,
          ),
        ),
        const SizedBox(width: 5),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}

class _FocusedDayContextCard extends StatelessWidget {
  final AppController controller;
  final String dateIso;
  final List<PeriodEntry> periodsOnDay;
  final List<SymptomEntry> symptomsOnDay;
  final Color accent;

  const _FocusedDayContextCard({
    required this.controller,
    required this.dateIso,
    required this.periodsOnDay,
    required this.symptomsOnDay,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final s = controller.strings;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${s.tr("Gewählter Tag", "Selected day")}: $dateIso',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: () => openDayDetailScreen(
                    context,
                    controller,
                    dateIso: dateIso,
                  ),
                  child: Text(s.openDayDetail),
                ),
              ],
            ),
            if (periodsOnDay.isNotEmpty) ...[
              for (final pe in periodsOnDay)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: Icon(Icons.water_drop_rounded, color: accent),
                  title: Text(
                    '${pe.countsAsPeriod ? s.tr("Periode", "Period") : "Spotting"} · ${pe.intensityForDate(dateIso).label(controller.localeCode)}',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: pe.note != null ? Text(pe.note!) : null,
                  trailing: const Icon(Icons.edit_outlined, size: 18),
                  onTap: () => showPeriodEditorSheet(
                    context,
                    controller,
                    existing: pe,
                  ),
                ),
            ],
            const Divider(height: 18),
            Row(
              children: [
                Expanded(
                  child: Text(
                    '${s.symptomsTitle} (${symptomsOnDay.length})',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => showSymptomEditorSheet(
                    context,
                    controller,
                    initialDate: dateIso,
                  ),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(s.logSymptom),
                ),
              ],
            ),
            if (symptomsOnDay.isEmpty)
              Text(
                s.tr(
                  'Keine Symptome an diesem Tag erfasst.',
                  'No symptoms recorded on this day.',
                ),
                style: TextStyle(
                  fontSize: 13,
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              )
            else
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final sym in symptomsOnDay)
                    InputChip(
                      label: Text('${sym.name} (${sym.intensity}/10)'),
                      onPressed: () => showSymptomEditorSheet(
                        context,
                        controller,
                        existing: sym,
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _PeriodHistoryTile extends StatelessWidget {
  final PeriodEntry entry;
  final String? nextPeriodStart;
  final AppController controller;
  final Color accent;

  const _PeriodHistoryTile({
    required this.entry,
    required this.nextPeriodStart,
    required this.controller,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final s = controller.strings;
    final dur = entry.completedDurationDays;
    final cycleLen = nextPeriodStart != null
        ? IsoDate.daysBetween(entry.startDate, nextPeriodStart!)
        : null;

    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: accent.withValues(alpha: 0.16),
          child: Icon(
            entry.countsAsPeriod
                ? Icons.calendar_today_rounded
                : Icons.grain_rounded,
            color: accent,
            size: 18,
          ),
        ),
        title: Text(
          entry.endDate != null
              ? '${entry.startDate} – ${entry.endDate}'
              : '${entry.startDate} (${s.tr("laufend", "ongoing")})',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          [
            entry.countsAsPeriod ? s.tr('Periode', 'Period') : 'Spotting',
            entry.intensity.label(controller.localeCode),
            if (dur != null) '$dur ${s.tr("Tage Blutung", "d bleeding")}',
            if (cycleLen != null && cycleLen > 0)
              '${s.tr("Zyklus", "Cycle")}: $cycleLen ${s.tr("Tage", "d")}',
            if (entry.note != null && entry.note!.isNotEmpty) entry.note!,
          ].join(' · '),
        ),
        trailing: const Icon(Icons.edit_outlined, size: 19),
        onTap: () => showPeriodEditorSheet(
          context,
          controller,
          existing: entry,
        ),
      ),
    );
  }
}
