import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/model.dart';
import '../core/nutrients.dart';
import 'common.dart';
import 'controller.dart';
import 'editors.dart';

class ForecastPanel extends StatelessWidget {
  final Json forecast;
  const ForecastPanel({super.key, required this.forecast});
  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context), f = forecast;
    final sufficient = f['predicted_start'] != null;
    final enabled = f['enabled'] == true;
    return Panel(
      color: const Color(0xfff5e7eb),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            c.tr('Deine persönliche Einschätzung', 'Your personal estimate'),
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 12),
          Text(
            !enabled
                ? c.tr('Tagebuchmodus', 'Journal mode')
                : !sufficient
                ? c.tr('Historie aufbauen', 'Building your history')
                : c.date(f['predicted_start'], short: true),
            style: Theme.of(context).textTheme.headlineMedium,
          ),
          const SizedBox(height: 8),
          Text(
            !enabled
                ? c.tr(
                    'Du dokumentierst deinen Verlauf ohne Vorhersage.',
                    'You are recording your history without predictions',
                  )
                : !sufficient
                ? c.tr(
                    'Für eine persönliche Einschätzung sind mindestens zwei Periodenbeginne nötig.',
                    'At least two recorded period starts are needed for a personal estimate.',
                  )
                : '${c.tr('Planungsfenster: ', 'Planning window: ')}${c.date(f['window_start'], short: true)} – ${c.date(f['window_end'], short: true)}',
          ),
          if (f['status'] == 'past_window')
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                c.tr(
                  'Das geschätzte Fenster ist vergangen. Die Einschätzung wartet auf einen neuen aufgezeichneten Beginn.',
                  'The estimated window has passed. The estimate waits for a new recorded start.',
                ),
              ),
            ),
          if (f['cycle_day'] != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                c.tr('Tag ', 'Day ') +
                    f['cycle_day'].toString() +
                    c.tr(' seit dem letzten Beginn', ' since the last start'),
              ),
            ),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(
              c.tr('Wie entsteht die Einschätzung?', 'How is this estimated?'),
            ),
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.tr(
                        'Wir verwenden den Median deiner letzten bis zu sechs aufgezeichneten Abstände zwischen Periodenbeginnen. Zukünftige Einträge und reine Spotting-Perioden zählen nicht mit.',
                        'We use the median of your last six or fewer recorded intervals between period starts. Future entries and spotting-only periods are excluded.',
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (f['sample_count'] > 0) ...[
                      Text(
                        c.tr('Ausgewertete Abstände: ', 'Intervals used: ') +
                            (f['intervals_days'] as List).join(', ') +
                            c.tr(' Tage', ' days'),
                      ),
                      Text(
                        c.tr('Median: ', 'Median: ') +
                            c.fmt(f['median_cycle_days']) +
                            c.tr(' Tage', ' days'),
                      ),
                      Text(
                        '${c.tr('Beobachtete Spanne: ', 'Observed range: ')}${f['observed_min_days']}–${f['observed_max_days']}${c.tr(' Tage', ' days')}',
                      ),
                    ],
                    if (f['median_bleeding_days'] != null)
                      Text(
                        c.tr(
                              'Mittlere Blutungsdauer (Median): ',
                              'Median bleeding duration: ',
                            ) +
                            f['median_bleeding_days'].toString() +
                            c.tr(' Tage', ' days'),
                      ),
                    const SizedBox(height: 12),
                    Text(
                      c.tr(
                        'Das Fenster reicht beidseits um mindestens zwei Tage oder das 1,5-Fache der mittleren absoluten Abweichung vom Median. Es ist ein Planungskorridor ohne garantierte Wahrscheinlichkeit.',
                        'The window extends by at least two days on each side, or 1.5 times the median absolute deviation. It is a planning range without a guaranteed probability.',
                      ),
                    ),
                    if (f['variability'] == 'limited_history')
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          c.tr(
                            'Die Datenbasis ist noch klein; diese Einschätzung ist vorläufig.',
                            'There is little history yet; this estimate is tentative.',
                          ),
                        ),
                      ),
                    if (f['variability'] == 'variable')
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          c.tr(
                            'Deine aufgezeichneten Abstände variieren deutlich. Das Fenster kann diese Unterschiede nicht vollständig abbilden.',
                            'Your recorded intervals vary considerably. The window may not capture all of these differences.',
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    Text(
                      c.tr(
                        'Für persönliche Dokumentation und Planung. Keine Eisprungberechnung oder Verhütungsmethode.',
                        'For personal recording and planning. No ovulation calculation or contraceptive method.',
                      ),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 14),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class CycleScreen extends StatefulWidget {
  const CycleScreen({super.key});
  @override
  State<CycleScreen> createState() => _CycleScreenState();
}

class _CycleScreenState extends State<CycleScreen> {
  late DateTime month;
  String? lastDay;
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final c = AppScope.of(context);
    if (lastDay != c.selectedDay) {
      final d = parseDay(c.selectedDay);
      month = DateTime(d.year, d.month);
      lastDay = c.selectedDay;
    }
  }

  Widget calendar(Json f) {
    final c = AppScope.of(context);
    final first = DateTime(month.year, month.month);
    final offset = first.weekday - 1;
    final count = DateTime(month.year, month.month + 1, 0).day;
    final weeks = ((count + offset) / 7).ceil();
    return Panel(
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: c.tr('Voriger Monat', 'Previous month'),
                onPressed: () => setState(
                  () => month = DateTime(month.year, month.month - 1),
                ),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: Text(
                  DateFormat.yMMMM(c.language).format(month),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              IconButton(
                tooltip: c.tr('Nächster Monat', 'Next month'),
                onPressed: () => setState(
                  () => month = DateTime(month.year, month.month + 1),
                ),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: List.generate(
              7,
              (i) => Expanded(
                child: Text(
                  DateFormat.E(c.language).format(DateTime(2026, 9, 21 + i)),
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          for (var week = 0; week < weeks; week++)
            Row(
              children: List.generate(7, (weekday) {
                final day = week * 7 + weekday - offset + 1;
                if (day < 1 || day > count) {
                  return const Expanded(child: SizedBox(height: 58));
                }
                final date = dateKey(DateTime(month.year, month.month, day));
                final bleed = c.engine.bleedingOn(date),
                    symptoms = c.engine.on('symptoms', date);
                final recorded = bleed != null && bleed['strength'] != 'none';
                final predicted =
                    f['window_start'] != null &&
                    date.compareTo(f['window_start']) >= 0 &&
                    date.compareTo(f['window_end']) <= 0;
                final selected = date == c.selectedDay;
                final label =
                    c.date(date) +
                    (recorded ? ' · ${c.strength(bleed['strength'])}' : '') +
                    (symptoms.isEmpty
                        ? ''
                        : c.tr(' · Symptome', ' · symptoms')) +
                    (predicted
                        ? c.tr(' · Planungsfenster', ' · planning window')
                        : '');
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Semantics(
                      label: label,
                      button: true,
                      selected: selected,
                      excludeSemantics: true,
                      child: Tooltip(
                        message: label,
                        child: InkWell(
                          key: ValueKey('calendar-$date'),
                          borderRadius: BorderRadius.circular(12),
                          onTap: () => c.day(date),
                          child: Container(
                            height: 54,
                            decoration: BoxDecoration(
                              color: selected
                                  ? ink
                                  : recorded
                                  ? const Color(0xfff1d4de)
                                  : null,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: predicted
                                    ? rose
                                    : selected
                                    ? ink
                                    : Colors.transparent,
                                width: predicted ? 2 : 1,
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  '$day',
                                  style: TextStyle(
                                    color: selected ? Colors.white : ink,
                                    fontWeight: selected
                                        ? FontWeight.w700
                                        : FontWeight.normal,
                                  ),
                                ),
                                if (recorded || symptoms.isNotEmpty)
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      if (recorded)
                                        Icon(
                                          bleed['strength'] == 'spotting'
                                              ? Icons.more_horiz
                                              : Icons.water_drop,
                                          size: 11,
                                          color: selected ? Colors.white : rose,
                                        ),
                                      if (symptoms.isNotEmpty)
                                        Icon(
                                          Icons.circle,
                                          size: 6,
                                          color: selected ? Colors.white : ink,
                                        ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 14,
            runSpacing: 8,
            children: [
              legend(
                c.tr('Aufgezeichnet', 'Recorded'),
                const Color(0xfff1d4de),
              ),
              legend(
                c.tr('Planungsfenster', 'Planning window'),
                Colors.transparent,
                border: rose,
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.circle, size: 7),
                  const SizedBox(width: 5),
                  Text(
                    c.tr('Symptome', 'Symptoms'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget legend(String text, Color color, {Color? border}) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 12,
        height: 12,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
          border: border == null ? null : Border.all(color: border),
        ),
      ),
      const SizedBox(width: 5),
      Text(text, style: Theme.of(context).textTheme.bodySmall),
    ],
  );
  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context), f = c.engine.cycleForecast(c.selectedDay);
    final bleeding = c.engine.bleedingOn(c.selectedDay),
        explicit = c.engine.on('bleeding', c.selectedDay).firstOrNull;
    final period = c.engine.periodOn(c.selectedDay),
        symptoms = c.engine.on('symptoms', c.selectedDay);
    final periods = [...c.data['periods']]
      ..sort((a, b) => (b['start'] as String).compareTo(a['start']));
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const DayBar(),
        ForecastPanel(forecast: f),
        calendar(f),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Heading(
                c.tr('Gewählter Tag', 'Selected day'),
                subtitle: c.date(c.selectedDay),
              ),
              Text(
                bleeding == null
                    ? c.tr(
                        'Keine Blutung aufgezeichnet',
                        'No bleeding recorded',
                      )
                    : c.strength(bleeding['strength']),
              ),
              if ((bleeding?['note'] as String?)?.isNotEmpty == true)
                Text(bleeding!['note']),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  OutlinedButton.icon(
                    onPressed: () =>
                        editRecord(context, 'bleeding', record: explicit),
                    icon: const Icon(Icons.water_drop_outlined),
                    label: Text(c.tr('Blutung erfassen', 'Record flow')),
                  ),
                  OutlinedButton.icon(
                    onPressed: () =>
                        editRecord(context, 'periods', record: period),
                    icon: const Icon(Icons.edit_calendar_outlined),
                    label: Text(
                      period == null
                          ? c.tr('Periode erfassen', 'Record period')
                          : c.tr('Periode bearbeiten', 'Edit period'),
                    ),
                  ),
                ],
              ),
              const Divider(height: 28),
              Heading(
                c.tr('Symptome', 'Symptoms'),
                trailing: IconButton(
                  tooltip: c.tr('Symptom erfassen', 'Record symptom'),
                  onPressed: () => editRecord(context, 'symptoms'),
                  icon: const Icon(Icons.add),
                ),
              ),
              if (symptoms.isEmpty)
                Text(
                  c.tr('Noch kein Symptom erfasst', 'No symptoms logged yet'),
                ),
              for (final r in symptoms)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(r['name']),
                  subtitle: Text(
                    '${c.tr('Intensität ', 'Intensity ')}${r['intensity']} / 10',
                  ),
                  trailing: const Icon(Icons.edit_outlined, size: 18),
                  onTap: () => editRecord(context, 'symptoms', record: r),
                ),
            ],
          ),
        ),
        Heading(
          c.tr('Periodenverlauf', 'Period history'),
          trailing: TextButton.icon(
            onPressed: () => editRecord(context, 'periods'),
            icon: const Icon(Icons.add),
            label: Text(c.tr('Erfassen', 'Add')),
          ),
        ),
        if (periods.isEmpty)
          EmptyNote(
            c.tr(
              'Erfasse auch vergangene Perioden, um deine persönliche Historie aufzubauen.',
              'Record past periods too to build your personal history.',
            ),
          ),
        for (final p in periods)
          Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              leading: const Icon(Icons.water_drop_outlined, color: rose),
              title: Text(
                '${c.date(p['start'], short: true)} – ${p['end'] == null ? c.tr('läuft noch', 'ongoing') : c.date(p['end'], short: true)}',
              ),
              subtitle: Text(
                c.strength(p['strength']) +
                    ((p['note'] as String?)?.isNotEmpty == true
                        ? ' · ${p['note']}'
                        : ''),
              ),
              trailing: const Icon(Icons.edit_outlined, size: 18),
              onTap: () => editRecord(context, 'periods', record: p),
            ),
          ),
        const SizedBox(height: 32),
      ],
    );
  }
}
