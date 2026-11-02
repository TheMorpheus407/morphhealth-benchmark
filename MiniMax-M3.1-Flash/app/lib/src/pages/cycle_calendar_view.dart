import 'package:flutter/material.dart';
import 'package:morphhealth_core/morphhealth_core.dart';

import '../l10n/app_localizations.dart';
import '../state/app_state.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'day_detail_page.dart';
import 'home_shell.dart';
import 'symptom_entry_sheet.dart';

/// Month calendar with the recorded periods, the predicted window and the
/// symptoms of the selected day.
class CycleCalendarView extends StatefulWidget {
  const CycleCalendarView({super.key});

  @override
  State<CycleCalendarView> createState() => _CycleCalendarViewState();
}

class _CycleCalendarViewState extends State<CycleCalendarView> {
  late DateTime _month;
  String? _selectedDay;

  @override
  void initState() {
    super.initState();
    final DateTime now = DateTime.now();
    _month = DateTime(now.year, now.month);
  }

  void _shiftMonth(int delta) {
    setState(() {
      _month = DateTime(_month.year, _month.month + delta);
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final CycleService cycle = state.cycle;
    final Set<String> periodDays = cycle.periodDays();
    final Set<String> openDays = cycle.openPeriodDays();
    final Set<String> spottingDays = <String>{
      for (final PeriodRecord record in state.repository.periods)
        if (record.spotting) record.startDate,
    };
    final Map<String, List<SymptomEntry>> symptomsByDay =
        <String, List<SymptomEntry>>{};
    for (final SymptomEntry entry in state.symptoms.entries) {
      symptomsByDay.putIfAbsent(entry.date, () => <SymptomEntry>[]).add(entry);
    }

    final CycleForecast current =
        cycle.forecast(DateMath.format(DateTime.now()));
    final String? windowStart = current.predictedWindowStart;
    final String? windowEnd = current.predictedWindowEnd;
    final String today = DateMath.format(DateTime.now());

    final List<String?> grid = _buildGrid(_month);
    final List<String> weekdayNames = _weekdayNames(l10n);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: <Widget>[
        Row(
          children: <Widget>[
            IconButton(
              onPressed: () => _shiftMonth(-1),
              icon: const Icon(Icons.chevron_left),
              tooltip: l10n.t('common.back'),
            ),
            Expanded(
              child: Center(
                child: Text(
                  monthTitle(context, _month.year, _month.month),
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
            IconButton(
              onPressed: () => _shiftMonth(1),
              icon: const Icon(Icons.chevron_right),
              tooltip: l10n.t('common.next'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: <Widget>[
            for (final String name in weekdayNames)
              Expanded(
                child: Center(
                  child: Text(
                    name,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 4),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            childAspectRatio: 0.95,
          ),
          itemCount: grid.length,
          itemBuilder: (BuildContext context, int index) {
            final String? date = grid[index];
            if (date == null) return const SizedBox.shrink();
            final bool isPeriod = periodDays.contains(date);
            final bool isSpotting = spottingDays.contains(date);
            final bool isOpen = openDays.contains(date);
            final bool inWindow = windowStart != null &&
                windowEnd != null &&
                !DateMath.before(date, windowStart) &&
                !DateMath.after(date, windowEnd);
            final List<SymptomEntry> symptoms =
                symptomsByDay[date] ?? const <SymptomEntry>[];
            return _DayCell(
              date: date,
              isPeriod: isPeriod,
              isSpotting: isSpotting,
              isOpen: isOpen,
              inWindow: inWindow,
              isToday: date == today,
              isSelected: date == _selectedDay,
              symptomCount: symptoms.length,
              onTap: () => _select(date, symptoms),
            );
          },
        ),
        const SizedBox(height: 12),
        _Legend(),
        if (_selectedDay != null) ...<Widget>[
          const SizedBox(height: 16),
          _DayPanel(date: _selectedDay!),
        ],
      ],
    );
  }

  void _select(String date, List<SymptomEntry> symptoms) {
    setState(() {
      _selectedDay = date;
    });
  }

  List<String> _weekdayNames(AppLocalizations l10n) {
    final bool german = l10n.strings.isGerman;
    return german
        ? <String>['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So']
        : <String>['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];
  }

  List<String?> _buildGrid(DateTime month) {
    final DateTime first = DateTime(month.year, month.month, 1);
    final int offset = (first.weekday - 1) % 7;
    final int daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final List<String?> cells = <String?>[
      for (int i = 0; i < offset; i++) null,
    ];
    for (int day = 1; day <= daysInMonth; day++) {
      cells.add(DateMath.format(DateTime(month.year, month.month, day)));
    }
    while (cells.length % 7 != 0) {
      cells.add(null);
    }
    return cells;
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.isPeriod,
    required this.isSpotting,
    required this.isOpen,
    required this.inWindow,
    required this.isToday,
    required this.isSelected,
    required this.symptomCount,
    required this.onTap,
  });

  final String date;
  final bool isPeriod;
  final bool isSpotting;
  final bool isOpen;
  final bool inWindow;
  final bool isToday;
  final bool isSelected;
  final int symptomCount;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final int day = DateMath.parse(date).day;

    Color background = Colors.transparent;
    Color foreground = theme.colorScheme.onSurface;
    if (isPeriod) {
      background = theme.colorScheme.primary;
      foreground = theme.colorScheme.onPrimary;
    } else if (inWindow) {
      background = theme.colorScheme.secondaryContainer;
      foreground = theme.colorScheme.onSecondaryContainer;
    } else if (isSpotting) {
      background = theme.colorScheme.surfaceContainerHighest;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.all(2),
        decoration: BoxDecoration(
          color: background,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isToday
                ? theme.colorScheme.primary
                : (isSelected ? theme.colorScheme.secondary : Colors.transparent),
            width: isToday || isSelected ? 1.6 : 1,
          ),
        ),
        child: Stack(
          children: <Widget>[
            Center(
              child: Text(
                '$day',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: foreground,
                  fontWeight:
                      isPeriod || isToday ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            if (isSpotting)
              Positioned(
                top: 3,
                right: 4,
                child: Icon(
                  Icons.water_drop,
                  size: 9,
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            if (symptomCount > 0)
              Positioned(
                bottom: 3,
                child: Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: isPeriod
                        ? theme.colorScheme.onPrimary
                        : theme.colorScheme.tertiary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            if (isOpen)
              Positioned(
                top: 3,
                left: 4,
                child: Icon(
                  Icons.more_horiz,
                  size: 10,
                  color: foreground,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final AppLocalizations l10n = context.l10n;
    Widget item(Color color, String label, {bool outlined = false}) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: outlined ? Colors.transparent : color,
              border: Border.all(color: color, width: 1.4),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 5),
          Text(label, style: theme.textTheme.labelSmall),
        ],
      );
    }

    return Wrap(
      spacing: 14,
      runSpacing: 6,
      children: <Widget>[
        item(theme.colorScheme.primary, l10n.t('cycle.periods')),
        item(
          theme.colorScheme.secondaryContainer,
          l10n.t('cycle.next_window'),
          outlined: true,
        ),
        item(theme.colorScheme.tertiary, l10n.t('cycle.symptom_on_day')),
      ],
    );
  }
}

class _DayPanel extends StatelessWidget {
  const _DayPanel({required this.date});

  final String date;

  @override
  Widget build(BuildContext context) {
    final AppState state = AppScope.of(context);
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    final List<SymptomEntry> symptoms = state.symptoms.entries
        .where((SymptomEntry e) => e.date == date)
        .toList(growable: false);
    final List<PeriodRecord> periods = state.repository.periods
        .where((PeriodRecord p) =>
            p.startDate == date || p.endDate == date)
        .toList(growable: false);

    return SectionCard(
      title: formatDay(context, date, withYear: true),
      trailing: IconButton(
        icon: const Icon(Icons.add),
        tooltip: l10n.t('symptom.add_entry'),
        onPressed: () => SymptomEntrySheet.show(context, initialDate: date),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (periods.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.water_drop_outlined,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    periods.first.spotting
                        ? l10n.t('cycle.spotting')
                        : l10n.t('cycle.periods'),
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          if (symptoms.isEmpty)
            Text(
              l10n.t('common.empty'),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            )
          else
            for (final SymptomEntry symptom in symptoms)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    color: IntensityColors.of(context, symptom.intensity),
                    shape: BoxShape.circle,
                  ),
                ),
                title: Text(symptom.name),
                subtitle: Text('${symptom.intensity}/10'),
                trailing: IconButton(
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  onPressed: () => SymptomEntrySheet.show(context, entry: symptom),
                ),
              ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (BuildContext context) => DayDetailPage(date: date),
                ),
              ),
              icon: const Icon(Icons.open_in_new, size: 18),
              label: Text(l10n.t('overview.day_detail')),
            ),
          ),
        ],
      ),
    );
  }
}
