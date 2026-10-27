import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/cycle.dart';
import '../core/health.dart';
import '../core/utils.dart';
import 'controller.dart';
import 'l10n.dart';
import 'overview.dart';
import 'widgets.dart';

class CyclePage extends StatefulWidget {
  const CyclePage({super.key});

  @override
  State<CyclePage> createState() => _CyclePageState();
}

class _CyclePageState extends State<CyclePage> {
  late DateTime _visibleMonth;
  late String _lastSelectedDate;

  @override
  void initState() {
    super.initState();
    final selectedDate = context.read<AppController>().selectedDate;
    final selected = parseDate(selectedDate);
    _visibleMonth = DateTime(selected.year, selected.month);
    _lastSelectedDate = selectedDate;
  }

  void _changeMonth(int offset) {
    setState(() {
      _visibleMonth = DateTime(
        _visibleMonth.year,
        _visibleMonth.month + offset,
      );
    });
  }

  void _openDay(String date) {
    context.read<AppController>().selectDate(date);
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => DayDetailPage(date: date)));
  }

  void _openPeriod([Period? existing]) {
    final controller = context.read<AppController>();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PeriodEditPage(
          existing: existing,
          initialDate: existing == null ? controller.selectedDate : null,
        ),
      ),
    );
  }

  Future<void> _setDiaryOnly(bool diaryOnly) async {
    final controller = context.read<AppController>();
    try {
      await controller.repository.updateSettings(
        controller.settings.copyWith(cycleForecastEnabled: !diaryOnly),
      );
    } catch (_) {
      if (mounted) showError(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = l10n(context);
    final controller = context.watch<AppController>();
    if (_lastSelectedDate != controller.selectedDate) {
      _lastSelectedDate = controller.selectedDate;
      final selected = parseDate(controller.selectedDate);
      _visibleMonth = DateTime(selected.year, selected.month);
    }
    final today = instantDateKey(controller.now);
    final forecast = controller.settings.cycleForecastEnabled
        ? forecastCycle(controller.state.periods, today)
        : null;
    final periods = [...controller.state.periods]
      ..sort((a, b) => b.start.compareTo(a.start));

    return Scaffold(
      appBar: AppBar(title: Text(strings.t('cycle'))),
      body: SafeArea(
        child: Scrollbar(
          child: CustomScrollView(
            key: const PageStorageKey<String>('cycle-page-scroll'),
            slivers: [
              SliverToBoxAdapter(
                child: _CalendarCard(
                  month: _visibleMonth,
                  today: today,
                  selectedDate: controller.selectedDate,
                  periods: controller.state.periods,
                  forecast: forecast,
                  onPrevious: () => _changeMonth(-1),
                  onNext: () => _changeMonth(1),
                  onToday: () {
                    final date = parseDate(today);
                    setState(() {
                      _visibleMonth = DateTime(date.year, date.month);
                    });
                  },
                  onDayTap: _openDay,
                ),
              ),
              SliverToBoxAdapter(
                child: AppCard(
                  title: strings.t('cycle_diary'),
                  icon: Icons.menu_book_outlined,
                  trailing: Semantics(
                    label: strings.t('cycle_diary'),
                    child: Switch(
                      key: const ValueKey('cycle-diary-switch'),
                      value: !controller.settings.cycleForecastEnabled,
                      onChanged: _setDiaryOnly,
                    ),
                  ),
                  children: [
                    if (!controller.settings.cycleForecastEnabled)
                      Text(strings.t('forecast_off')),
                  ],
                ),
              ),
              if (forecast != null)
                SliverToBoxAdapter(child: _ForecastCard(forecast: forecast)),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 6),
                  child: Text(
                    strings.t('cycle_history'),
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ),
              if (periods.isEmpty)
                SliverToBoxAdapter(
                  child: EmptyState(
                    text: strings.t('no_entries'),
                    icon: Icons.water_drop_outlined,
                  ),
                )
              else
                SliverList.builder(
                  itemCount: periods.length,
                  itemBuilder: (context, index) {
                    final period = periods[index];
                    return _PeriodHistoryCard(
                      key: ValueKey('period-${period.id}'),
                      period: period,
                      onTap: () => _openPeriod(period),
                    );
                  },
                ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 18, 24, 96),
                  child: Text(
                    strings.t('not_medical'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'cycle-add-period',
        key: const ValueKey('add-period'),
        onPressed: _openPeriod,
        icon: const Icon(Icons.add),
        label: Text(strings.t('add_period')),
      ),
    );
  }
}

class _CalendarCard extends StatelessWidget {
  const _CalendarCard({
    required this.month,
    required this.today,
    required this.selectedDate,
    required this.periods,
    required this.forecast,
    required this.onPrevious,
    required this.onNext,
    required this.onToday,
    required this.onDayTap,
  });

  final DateTime month;
  final String today;
  final String selectedDate;
  final List<Period> periods;
  final CycleForecast? forecast;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onToday;
  final ValueChanged<String> onDayTap;

  @override
  Widget build(BuildContext context) {
    final strings = l10n(context);
    final material = MaterialLocalizations.of(context);
    final firstDay = DateTime(month.year, month.month);
    final leadingDays = firstDay.weekday - DateTime.monday;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final cellCount = ((leadingDays + daysInMonth + 6) ~/ 7) * 7;
    final hasForecast = forecast?.available ?? false;

    return AppCard(
      title: material.formatMonthYear(month),
      icon: Icons.calendar_month_outlined,
      children: [
        Row(
          children: [
            IconButton(
              key: const ValueKey('previous-month'),
              tooltip: material.formatMonthYear(
                DateTime(month.year, month.month - 1),
              ),
              onPressed: onPrevious,
              icon: const Icon(Icons.chevron_left),
            ),
            Expanded(
              child: TextButton.icon(
                key: const ValueKey('current-month'),
                onPressed: onToday,
                icon: const Icon(Icons.today_outlined),
                label: Text(strings.t('today')),
              ),
            ),
            IconButton(
              key: const ValueKey('next-month'),
              tooltip: material.formatMonthYear(
                DateTime(month.year, month.month + 1),
              ),
              onPressed: onNext,
              icon: const Icon(Icons.chevron_right),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            for (var index = 0; index < 7; index++)
              Expanded(
                child: SizedBox(
                  height: 24,
                  child: Center(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        material.narrowWeekdays[(index + 1) % 7],
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        GridView.builder(
          padding: EdgeInsets.zero,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            mainAxisExtent: 60,
          ),
          itemCount: cellCount,
          itemBuilder: (context, index) {
            final day = index - leadingDays + 1;
            if (day < 1 || day > daysInMonth) {
              return const SizedBox.shrink();
            }
            final date = dateKey(DateTime(month.year, month.month, day));
            final actual = periods.any(
              (period) => period.contains(date, today),
            );
            final predictedStart =
                hasForecast && date == forecast!.predictedStart;
            final forecastRange =
                hasForecast &&
                date.compareTo(forecast!.earliestStart!) >= 0 &&
                date.compareTo(forecast!.latestStart!) <= 0;
            return _CalendarDay(
              key: ValueKey('cycle-day-$date'),
              date: date,
              day: day,
              actual: actual,
              predictedStart: predictedStart,
              forecastRange: forecastRange,
              today: date == today,
              selected: date == selectedDate,
              onTap: () => onDayTap(date),
            );
          },
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 14,
          runSpacing: 8,
          children: [
            _CalendarLegend(
              icon: Icons.water_drop,
              label: strings.t('actual_period'),
            ),
            if (hasForecast) ...[
              _CalendarLegend(
                icon: Icons.event_available_outlined,
                label: strings.t('predicted_period'),
              ),
              _CalendarLegend(
                icon: Icons.date_range_outlined,
                label: strings.t('estimated_range'),
              ),
            ],
            _CalendarLegend(
              icon: Icons.today_outlined,
              label: strings.t('today'),
            ),
          ],
        ),
      ],
    );
  }
}

class _CalendarDay extends StatelessWidget {
  const _CalendarDay({
    super.key,
    required this.date,
    required this.day,
    required this.actual,
    required this.predictedStart,
    required this.forecastRange,
    required this.today,
    required this.selected,
    required this.onTap,
  });

  final String date;
  final int day;
  final bool actual;
  final bool predictedStart;
  final bool forecastRange;
  final bool today;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final strings = l10n(context);
    final colors = Theme.of(context).colorScheme;
    final borderColor = selected
        ? colors.primary
        : today
        ? colors.tertiary
        : predictedStart
        ? colors.secondary
        : actual
        ? colors.primary
        : forecastRange
        ? colors.outline
        : colors.outlineVariant;
    final borderWidth = selected
        ? 2.8
        : today || predictedStart || actual
        ? 1.8
        : 1.0;
    final background = actual
        ? colors.secondaryContainer
        : predictedStart
        ? colors.tertiaryContainer
        : forecastRange
        ? colors.surfaceContainerHighest
        : null;
    final semanticLabel = [
      strings.date(date),
      if (actual) strings.t('actual_period'),
      if (predictedStart) strings.t('predicted_period'),
      if (forecastRange) strings.t('estimated_range'),
      if (today) strings.t('today'),
    ].join(', ');

    return Semantics(
      label: semanticLabel,
      hint: strings.t('open_day'),
      button: true,
      selected: selected,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          margin: const EdgeInsets.all(2),
          padding: const EdgeInsets.symmetric(horizontal: 1, vertical: 3),
          decoration: BoxDecoration(
            color: background,
            border: Border.all(color: borderColor, width: borderWidth),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                height: 18,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '$day',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: actual || predictedStart || today || selected
                          ? FontWeight.bold
                          : FontWeight.normal,
                    ),
                  ),
                ),
              ),
              SizedBox(
                height: 14,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (actual)
                      Icon(
                        Icons.water_drop,
                        size: 12,
                        color: colors.onSecondaryContainer,
                      ),
                    if (predictedStart)
                      Icon(
                        Icons.event_available_outlined,
                        size: 12,
                        color: colors.onTertiaryContainer,
                      )
                    else if (forecastRange)
                      Icon(
                        Icons.date_range_outlined,
                        size: 11,
                        color: colors.onSurfaceVariant,
                      ),
                    if (selected)
                      Icon(Icons.check_circle, size: 11, color: colors.primary),
                  ],
                ),
              ),
              SizedBox(
                height: 11,
                child: today
                    ? FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          strings.t('today'),
                          style: Theme.of(context).textTheme.labelSmall,
                        ),
                      )
                    : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CalendarLegend extends StatelessWidget {
  const _CalendarLegend({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 5),
        Flexible(
          child: Text(label, style: Theme.of(context).textTheme.bodySmall),
        ),
      ],
    );
  }
}

class _ForecastCard extends StatelessWidget {
  const _ForecastCard({required this.forecast});

  final CycleForecast forecast;

  String _days(S strings, num value) =>
      strings.t('days', {'count': strings.number(value, decimals: 1)});

  @override
  Widget build(BuildContext context) {
    final strings = l10n(context);
    if (!forecast.available) {
      return AppCard(
        title: strings.t('forecast'),
        icon: Icons.insights_outlined,
        children: [
          EmptyState(
            text: strings.t('no_forecast'),
            icon: Icons.event_note_outlined,
          ),
        ],
      );
    }

    final median = forecast.medianCycleDays!;
    final periodDays = forecast.medianPeriodDays;
    final lowConfidence =
        forecast.confidence == 'low' || forecast.confidence == 'very_low';
    return AppCard(
      title: strings.t('forecast'),
      icon: Icons.insights_outlined,
      subtitle: strings.t('results_count', {'count': forecast.sampleSize}),
      children: [
        _ForecastLine(
          icon: Icons.straighten_outlined,
          label: strings.t('median_cycle'),
          value: _days(strings, median),
        ),
        _ForecastLine(
          icon: Icons.event_available_outlined,
          label: strings.t('estimated_next'),
          value: strings.date(forecast.predictedStart!),
        ),
        _ForecastLine(
          icon: Icons.date_range_outlined,
          label: strings.t('estimated_range'),
          value:
              '${strings.date(forecast.earliestStart!)} – '
              '${strings.date(forecast.latestStart!)}',
        ),
        _ForecastLine(
          icon: Icons.water_drop_outlined,
          label: strings.t('typical_period'),
          value: periodDays == null ? '—' : _days(strings, periodDays),
        ),
        if (lowConfidence)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline,
                  size: 20,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(strings.t('low_confidence'))),
              ],
            ),
          ),
        const Divider(height: 24),
        Text(
          strings.t('forecast_explanation', {
            'values': forecast.cycleLengths.join(', '),
            'median': strings.number(median, decimals: 1),
            'count': forecast.sampleSize,
          }),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _ForecastLine extends StatelessWidget {
  const _ForecastLine({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 21, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.bodySmall),
                Text(value, style: Theme.of(context).textTheme.titleSmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodHistoryCard extends StatelessWidget {
  const _PeriodHistoryCard({
    super.key,
    required this.period,
    required this.onTap,
  });

  final Period period;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final strings = l10n(context);
    return AppCard(
      title: '${strings.t('start')}: ${strings.date(period.start)}',
      subtitle:
          '${strings.t('end')}: '
          '${period.end == null ? strings.t('end_open') : strings.date(period.end!)}',
      icon: period.end == null
          ? Icons.play_circle_outline
          : Icons.water_drop_outlined,
      trailing: const Icon(Icons.edit_outlined),
      onTap: onTap,
      children: [
        Text('${strings.t('flow')}: ${strings.flow(period.flow)}'),
        if (period.end == null) ...[
          const SizedBox(height: 6),
          Text(
            strings.t('current_period'),
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ],
        if (period.notes.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text('${strings.t('notes')}: ${period.notes}'),
        ],
      ],
    );
  }
}

class PeriodEditPage extends StatefulWidget {
  const PeriodEditPage({super.key, this.existing, this.initialDate});

  final Period? existing;
  final String? initialDate;

  @override
  State<PeriodEditPage> createState() => _PeriodEditPageState();
}

class _PeriodEditPageState extends State<PeriodEditPage> {
  static const _flows = ['spotting', 'light', 'medium', 'heavy'];

  late String _start;
  late String _end;
  late bool _ongoing;
  late String _flow;
  late final TextEditingController _notesController;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    final initialDate =
        existing?.start ??
        widget.initialDate ??
        instantDateKey(context.read<AppController>().now);
    _start = dateKey(parseDate(initialDate));
    _end = existing?.end ?? _start;
    _ongoing = existing?.end == null;
    _flow = existing?.flow ?? 'medium';
    _notesController = TextEditingController(text: existing?.notes ?? '');
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  bool get _endBeforeStart => !_ongoing && _end.compareTo(_start) < 0;

  String get _endBeforeStartMessage =>
      Localizations.localeOf(context).languageCode == 'en'
      ? 'The end date cannot be before the start date.'
      : 'Das Enddatum darf nicht vor dem Beginn liegen.';

  bool _overlapsExisting(AppController controller, Period candidate) {
    for (final other in controller.state.periods) {
      if (other.id == candidate.id) continue;
      final separate =
          (candidate.end != null &&
              candidate.end!.compareTo(other.start) < 0) ||
          (other.end != null && other.end!.compareTo(candidate.start) < 0);
      if (!separate) return true;
    }
    return false;
  }

  Future<void> _save() async {
    if (_saving) return;
    final strings = l10n(context);
    if (_endBeforeStart) {
      showError(context, _endBeforeStartMessage);
      return;
    }
    final controller = context.read<AppController>();
    final timestamp = controller.now.toUtc();
    final existing = widget.existing;
    final period = Period(
      id: existing?.id ?? newId(),
      start: _start,
      end: _ongoing ? null : _end,
      flow: _flow,
      notes: _notesController.text.trim(),
      createdAt: existing?.createdAt.toUtc() ?? timestamp,
      updatedAt: timestamp,
    );
    if (_overlapsExisting(controller, period)) {
      showError(context, strings.t('period_overlap'));
      return;
    }

    setState(() => _saving = true);
    try {
      await controller.repository.savePeriod(period);
      if (!mounted) return;
      showMessage(context, strings.t('saved'));
      Navigator.of(context).pop();
    } on FormatException catch (error) {
      if (!mounted) return;
      showError(
        context,
        error.message == 'Periods must not overlap'
            ? strings.t('period_overlap')
            : strings.t('error'),
      );
    } catch (_) {
      if (mounted) showError(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final existing = widget.existing;
    if (existing == null || _saving) return;
    final confirmed = await confirmDeletion(context);
    if (!mounted || !confirmed) return;
    final controller = context.read<AppController>();
    setState(() => _saving = true);
    try {
      await controller.repository.deletePeriod(existing.id);
      if (!mounted) return;
      showMessage(context, l10n(context).t('saved'));
      Navigator.of(context).pop();
    } catch (_) {
      if (mounted) showError(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = l10n(context);
    final existing = widget.existing;
    return Scaffold(
      appBar: AppBar(
        title: Text(strings.t(existing == null ? 'add_period' : 'edit_period')),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            DateField(
              key: const ValueKey('period-start'),
              label: strings.t('start'),
              value: _start,
              onChanged: (value) => setState(() => _start = value),
            ),
            SwitchListTile(
              key: const ValueKey('period-end-open'),
              contentPadding: EdgeInsets.zero,
              secondary: const Icon(Icons.timelapse_outlined),
              title: Text(strings.t('end_open')),
              value: _ongoing,
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _ongoing = value),
            ),
            if (_ongoing)
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.play_circle_outline),
                title: Text(strings.t('current_period')),
              )
            else ...[
              DateField(
                key: const ValueKey('period-end'),
                label: strings.t('end'),
                value: _end,
                onChanged: (value) => setState(() => _end = value),
              ),
              if (_endBeforeStart)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    _endBeforeStartMessage,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
            ],
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              isExpanded: true,
              key: const ValueKey('period-flow'),
              initialValue: _flow,
              decoration: fieldDecoration(strings.t('flow')),
              items: [
                for (final flow in _flows)
                  DropdownMenuItem<String>(
                    value: flow,
                    child: Text(strings.flow(flow)),
                  ),
              ],
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _flow = value ?? _flow),
            ),
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('period-notes'),
              controller: _notesController,
              enabled: !_saving,
              minLines: 3,
              maxLines: 5,
              decoration: fieldDecoration(
                '${strings.t('notes')} (${strings.t('optional')})',
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              key: const ValueKey('save-period'),
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_outlined),
              label: Text(strings.t('save')),
            ),
            if (existing != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                key: const ValueKey('delete-period'),
                onPressed: _saving ? null : _delete,
                style: OutlinedButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
                icon: const Icon(Icons.delete_outline),
                label: Text(strings.t('delete')),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
