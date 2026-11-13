import 'package:flutter/material.dart';
import 'package:morphhealth_core/morphhealth_core.dart';

import '../settings/settings_screen.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'cycle_day_panel.dart';

/// The personal cycle assessment for today in a few lines, with the main
/// action (period starts or ends today) and the way to its explanation.
class ForecastCard extends StatelessWidget {
  /// Opens the cycle area when the card is used on the overview.
  final VoidCallback? onOpen;

  /// Title of the card; "Zyklus" by default.
  final String? title;

  const ForecastCard({super.key, this.onOpen, this.title});

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final fmt = context.fmt;
    final app = context.app;
    final f = app.forecast;
    final colors = MhColors.of(context);
    final today = app.today;
    final last = f.lastPeriod;

    final lines = <Widget>[];
    void headline(String text) =>
        lines.add(Text(text, style: context.texts.titleMedium));
    void body(String text) => lines.add(
      Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(text, style: context.texts.bodyMedium),
      ),
    );
    void quiet(String text) => lines.add(
      Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Text(
          text,
          style: context.texts.bodyMedium?.copyWith(
            color: context.colors.onSurfaceVariant,
          ),
        ),
      ),
    );

    if (f.inPeriod) {
      final end = f.currentPeriodExpectedEnd;
      headline(l.periodDay(f.periodDay!));
      if (last?.end != null) {
        body(fmt.range(last!.start, last.end!));
      } else if (end != null && f.predictionsEnabled) {
        body(l.expectedUntil(fmt.dateMonthLong(end)));
      }
    }

    switch (f.status) {
      case ForecastStatus.disabled:
        if (!f.inPeriod) {
          headline(
            f.cycleDay == null ? l.noPeriodYet : l.cycleDay(f.cycleDay!),
          );
        }
        quiet(l.diaryMode);
      case ForecastStatus.noData:
        headline(l.noPeriodYet);
        quiet(l.needTwoPeriods);
      case ForecastStatus.insufficientData:
        if (!f.inPeriod) headline(l.cycleDay(f.cycleDay!));
        quiet(l.needTwoPeriods);
      case ForecastStatus.upcoming:
      case ForecastStatus.due:
        final n = f.next!;
        if (f.status == ForecastStatus.due) {
          headline(l.periodDue);
        } else if (f.inPeriod) {
          body(l.nextPeriodAround(fmt.dateMonthLong(n.expectedStart)));
        } else {
          headline(l.nextPeriodAround(fmt.dateMonthLong(n.expectedStart)));
        }
        body(
          '${l.window(fmt.dateShort(n.earliestStart), fmt.dateShort(n.latestStart))}'
          '${f.status == ForecastStatus.upcoming ? ' · ${l.inDays(f.daysUntilExpectedStart!)}' : ''}',
        );
        if (!f.inPeriod) quiet(l.cycleDay(f.cycleDay!));
      case ForecastStatus.late:
        headline(l.periodLate(f.daysLate));
        body(l.periodLateHint);
        quiet(l.cycleDay(f.cycleDay!));
      case ForecastStatus.stale:
        headline(l.forecastStale);
        if (last != null) quiet(l.lastPeriodStarted(fmt.date(last.start)));
    }
    if (f.lastPeriodEndMissing) quiet(l.endMissingHint);

    final canExplain =
        f.predictionsEnabled && f.status != ForecastStatus.noData;
    final runningPeriod = f.inPeriod && last != null && last.end == null
        ? last
        : null;

    return MhCard(
      title: title ?? l.navCycle,
      icon: Icons.calendar_month_outlined,
      iconColor: colors.period,
      onOpen: onOpen,
      openLabel: onOpen == null ? null : l.openArea(l.navCycle),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...lines,
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (runningPeriod != null)
                FilledButton.tonal(
                  onPressed: () => endPeriodOn(context, runningPeriod, today),
                  child: Text(l.periodEndsToday),
                )
              else if (!f.inPeriod)
                FilledButton.tonal(
                  onPressed: () => startPeriodOn(context, today),
                  child: Text(l.periodStartsToday),
                ),
              if (canExplain)
                TextButton(
                  onPressed: () => showForecastExplanation(context),
                  child: Text(l.howCalculated),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Shows how the current assessment was derived from the recorded history.
Future<void> showForecastExplanation(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      // The sheet ends above the system navigation bar, so that its last
      // lines and the button below them stay reachable.
      builder: (context) => SafeArea(
        top: false,
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.85,
          maxChildSize: 0.95,
          builder: (context, scroll) => _Explanation(scrollController: scroll),
        ),
      ),
    );

class _Explanation extends StatelessWidget {
  final ScrollController scrollController;

  const _Explanation({required this.scrollController});

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final fmt = context.fmt;
    final app = context.app;
    final f = app.forecast;
    final colors = MhColors.of(context);
    final paragraphs = f.explain(l.languageCode);
    final longest = f.cycles.isEmpty
        ? 1
        : f.cycles.map((c) => c.lengthDays).reduce((a, b) => a > b ? a : b);

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        Semantics(
          header: true,
          child: Text(l.explanationTitle, style: context.texts.titleLarge),
        ),
        const SizedBox(height: 12),
        for (final p in paragraphs)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(p, style: context.texts.bodyLarge),
          ),
        if (f.cycles.isNotEmpty) ...[
          SectionTitle(
            l.cyclesUsedTitle,
            padding: const EdgeInsets.fromLTRB(0, 8, 0, 8),
          ),
          for (final c in f.cycles.reversed)
            Semantics(
              label:
                  '${fmt.range(c.start, c.nextStart.addDays(-1))}: '
                  '${l.cycleLength(c.lengthDays)}'
                  '${c.used ? '' : ', ${l.cycleNotUsed}'}',
              excludeSemantics: true,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                      width: 118,
                      child: Text(
                        fmt.dateCompact(c.start),
                        style: context.texts.bodySmall,
                      ),
                    ),
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, box) => Align(
                          alignment: AlignmentDirectional.centerStart,
                          child: Container(
                            height: 14,
                            width: box.maxWidth * c.lengthDays / longest,
                            decoration: BoxDecoration(
                              color: c.used ? colors.period : null,
                              border: c.used
                                  ? null
                                  : Border.all(color: context.colors.outline),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    SizedBox(
                      width: 64,
                      child: Text(
                        l.cycleLength(c.lengthDays),
                        textAlign: TextAlign.end,
                        style: context.texts.bodySmall?.copyWith(
                          decoration: c.used
                              ? null
                              : TextDecoration.lineThrough,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
        ],
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: context.colors.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            CycleForecast.disclaimer(l.languageCode),
            style: context.texts.bodyMedium,
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
              );
            },
            child: Text(l.turnOffEstimates),
          ),
        ),
      ],
    );
  }
}

/// Symptoms that keep appearing around period starts.
class PatternsCard extends StatelessWidget {
  const PatternsCard({super.key});

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final patterns = context.app.patterns;
    if (patterns.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: MhCard(
        title: l.patternsTitle,
        icon: Icons.repeat,
        iconColor: MhColors.of(context).symptom,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final p in patterns.take(5))
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text(
                  l.pattern(
                    p.name,
                    p.cyclesWith,
                    p.cyclesTotal,
                    p.phase,
                    p.typicalOffsetDays,
                  ),
                  style: context.texts.bodyMedium,
                ),
              ),
            Text(
              l.patternsHint,
              style: context.texts.bodySmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
