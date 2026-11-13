import 'package:flutter/material.dart';
import 'package:morphhealth_core/morphhealth_core.dart';

import '../day/day_detail_screen.dart';
import '../shell.dart';
import '../widgets/common.dart';
import 'cycle_day_panel.dart';
import 'cycle_history_screen.dart';
import 'forecast_card.dart';
import 'month_calendar.dart';

/// The period tracker: assessment, month calendar and the selected day.
class CycleScreen extends StatefulWidget {
  const CycleScreen({super.key});

  @override
  State<CycleScreen> createState() => _CycleScreenState();
}

class _CycleScreenState extends State<CycleScreen> {
  /// First month that can be shown.
  static final Day _origin = Day(2000, 1, 1);

  /// Months after the current one that can be shown.
  static const int _monthsAhead = 12;

  Day? _selected;
  PageController? _pages;
  int _page = 0;

  static int _indexOf(Day day) =>
      (day.year - _origin.year) * 12 + day.month - 1;

  static Day _monthAt(int index) => _origin.addMonths(index);

  @override
  void dispose() {
    _pages?.dispose();
    super.dispose();
  }

  final _panelKey = GlobalKey();

  /// Selects [day] and brings its details, which lie below the calendar,
  /// into view.
  void _select(Day day) {
    setState(() => _selected = day);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final panel = _panelKey.currentContext;
      if (panel == null || !mounted) return;
      Scrollable.ensureVisible(
        panel,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : const Duration(milliseconds: 250),
        curve: Curves.easeOut,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
    });
  }

  void _showMonthOf(Day day) {
    final index = _indexOf(day);
    if (_pages?.hasClients ?? false) {
      _pages!.animateToPage(
        index,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final fmt = context.fmt;
    final app = context.app;
    final today = app.today;
    final selected = _selected ?? today;
    if (_pages == null) {
      _page = _indexOf(selected);
      _pages = PageController(initialPage: _page);
    }
    final lastIndex = _indexOf(today) + _monthsAhead;
    final month = _monthAt(_page);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    void go(int delta) {
      final target = (_page + delta).clamp(0, lastIndex);
      if (reduceMotion) {
        _pages!.jumpToPage(target);
      } else {
        _pages!.animateToPage(
          target,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(l.navCycle),
        actions: [
          IconButton(
            tooltip: l.cycleHistory,
            icon: const Icon(Icons.format_list_bulleted),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const CycleHistoryScreen(),
              ),
            ),
          ),
          const SettingsButton(),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
          children: [
            ForecastCard(title: fmt.dayHeadline(today)),
            const PatternsCard(),
            const SizedBox(height: 12),
            PlainCard(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        IconButton(
                          tooltip: l.previousMonth,
                          onPressed: _page > 0 ? () => go(-1) : null,
                          icon: const Icon(Icons.chevron_left),
                        ),
                        Expanded(
                          child: Semantics(
                            header: true,
                            container: true,
                            liveRegion: true,
                            child: Text(
                              fmt.month(month),
                              textAlign: TextAlign.center,
                              style: context.texts.titleMedium,
                            ),
                          ),
                        ),
                        if (_page != _indexOf(today) || selected != today)
                          IconButton(
                            tooltip: l.goToToday,
                            icon: const Icon(Icons.today_outlined),
                            onPressed: () {
                              setState(() => _selected = today);
                              _showMonthOf(today);
                            },
                          ),
                        IconButton(
                          tooltip: l.nextMonth,
                          onPressed: _page < lastIndex ? () => go(1) : null,
                          icon: const Icon(Icons.chevron_right),
                        ),
                      ],
                    ),
                    SizedBox(
                      height: MonthCalendar.height,
                      child: PageView.builder(
                        controller: _pages,
                        itemCount: lastIndex + 1,
                        onPageChanged: (i) => setState(() => _page = i),
                        itemBuilder: (context, i) => MonthCalendar(
                          month: _monthAt(i),
                          selected: selected,
                          onSelect: _select,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                      child: Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: CalendarLegend(
                          withEstimates: app.settings.cyclePredictions,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            MhCard(
              key: _panelKey,
              title: fmt.dayLong(selected),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CycleDayPanel(day: selected),
                  if (selected <= today)
                    Align(
                      alignment: AlignmentDirectional.centerStart,
                      child: TextButton.icon(
                        icon: const Icon(Icons.view_day_outlined),
                        label: Text(l.openDayDetail),
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => DayDetailScreen(day: selected),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
