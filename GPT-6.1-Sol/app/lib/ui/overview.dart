import 'package:flutter/material.dart';
import '../core/nutrients.dart';
import 'common.dart';
import 'controller.dart';
import 'cycle_screen.dart';
import 'editors.dart';
import 'food_screens.dart';

class Overview extends StatelessWidget {
  const Overview({super.key});
  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context),
        sections = c.data.settings['sections'] as Map;
    final nutrition = c.engine.nutritionDay(c.selectedDay);
    final weights = c.engine.on('weights', c.selectedDay),
        symptoms = c.engine.on('symptoms', c.selectedDay);
    final latest =
        c.data['weights']
            .where((w) => (w['date'] as String).compareTo(c.selectedDay) <= 0)
            .toList()
          ..sort((a, b) => (b['date'] as String).compareTo(a['date']));
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const DayBar(),
        Heading(
          c.selectedDay == c.engine.clock.today
              ? c.tr('Dein Tag, in deinem Tempo.', 'Your day, at your pace.')
              : c.tr('Ein Blick auf deinen Tag.', 'A look at your day.'),
          subtitle: c.tr(
            'Ein privates Tagebuch für dich.',
            'A private journal for you.',
          ),
        ),
        OutlinedButton.icon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const DayDetail()),
          ),
          icon: const Icon(Icons.view_day_outlined),
          label: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(c.tr('Gemeinsames Tagesdetail', 'Combined day detail')),
          ),
        ),
        const SizedBox(height: 18),
        if (sections['nutrition'] == true) ...[
          NutritionSummary(day: nutrition),
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: FilledButton.icon(
              onPressed: () => pickFood(context),
              icon: const Icon(Icons.add),
              label: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(c.tr('Lebensmittel erfassen', 'Log food')),
              ),
            ),
          ),
          WaterPanel(day: nutrition),
        ],
        if (sections['cycle'] == true) ...[
          ForecastPanel(forecast: c.engine.cycleForecast(c.selectedDay)),
          Padding(
            padding: const EdgeInsets.only(bottom: 18),
            child: OutlinedButton.icon(
              onPressed: () => c.navigate(2),
              icon: const Icon(Icons.calendar_month),
              label: Text(c.tr('Zykluskalender öffnen', 'Open cycle calendar')),
            ),
          ),
        ],
        if (sections['weight'] == true)
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Heading(
                  c.tr('Gewicht', 'Weight'),
                  trailing: IconButton(
                    tooltip: c.tr('Gewicht erfassen', 'Log weight'),
                    onPressed: () => editRecord(context, 'weights'),
                    icon: const Icon(Icons.add),
                  ),
                ),
                if (weights.isEmpty)
                  Text(
                    latest.isEmpty
                        ? c.tr(
                            'Noch kein Gewicht erfasst',
                            'No weight logged yet',
                          )
                        : '${c.tr('Zuletzt: ', 'Latest: ')}${c.fmt(number(latest.first['kg'])! / (c.pounds ? 0.45359237 : 1), digits: 2)} ${c.pounds ? 'lb' : 'kg'} · ${c.date(latest.first['date'], short: true)}',
                  ),
                for (final r in weights) WeightTile(record: r),
                TextButton(
                  onPressed: () => c.navigate(3),
                  child: Text(c.tr('Verlauf ansehen', 'View trend')),
                ),
              ],
            ),
          ),
        if (sections['symptoms'] == true)
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                    c.tr(
                      'Wie geht es dir? Erfasse, was für dich relevant ist.',
                      'How are you feeling? Record what matters to you.',
                    ),
                  ),
                for (final r in symptoms) SymptomTile(record: r),
              ],
            ),
          ),
        if (!sections.values.any((v) => v == true))
          EmptyNote(
            c.tr(
              'Du hast alle Bereiche ausgeblendet. Du kannst sie in den Einstellungen wieder einblenden.',
              'All sections are hidden. You can show them again in settings.',
            ),
          ),
        const SizedBox(height: 20),
        Center(
          child: Text(
            c.tr(
              'Lokal gespeichert · ohne Konto',
              'Stored locally · no account',
            ),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}

class WeightTile extends StatelessWidget {
  final Json record;
  const WeightTile({super.key, required this.record});
  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context), r = record;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.monitor_weight_outlined),
      title: Text(
        '${c.fmt(number(r['kg'])! / (c.pounds ? 0.45359237 : 1), digits: 2)} ${c.pounds ? 'lb' : 'kg'}',
      ),
      subtitle: (r['note'] as String?)?.isNotEmpty == true
          ? Text(r['note'])
          : null,
      trailing: const Icon(Icons.edit_outlined, size: 18),
      onTap: () => editRecord(context, 'weights', record: r),
    );
  }
}

class SymptomTile extends StatelessWidget {
  final Json record;
  const SymptomTile({super.key, required this.record});
  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context), r = record;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(r['name']),
      subtitle: Text(
        '${c.tr('Intensität ', 'Intensity ')}${r['intensity']} / 10 · ${(r['at'] as String).substring(11, 16)}${(r['note'] as String?)?.isNotEmpty == true ? ' · ${r['note']}' : ''}',
      ),
      trailing: const Icon(Icons.edit_outlined, size: 18),
      onTap: () => editRecord(context, 'symptoms', record: r),
    );
  }
}

class DayDetail extends StatelessWidget {
  const DayDetail({super.key});
  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context),
        day = c.engine.nutritionDay(c.selectedDay),
        p = c.engine.periodOn(c.selectedDay),
        b = c.engine.bleedingOn(c.selectedDay);
    final explicit = c.engine.on('bleeding', c.selectedDay).firstOrNull;
    final weights = c.engine.on('weights', c.selectedDay),
        symptoms = c.engine.on('symptoms', c.selectedDay);
    return Scaffold(
      appBar: AppBar(title: Text(c.tr('Tagesdetail', 'Day detail'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const DayBar(),
            NutritionSummary(day: day),
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Heading(
                    c.tr('Lebensmittel', 'Foods'),
                    trailing: IconButton(
                      tooltip: c.tr('Lebensmittel erfassen', 'Log food'),
                      onPressed: () => pickFood(context),
                      icon: const Icon(Icons.add),
                    ),
                  ),
                  if ((day['entries'] as List).isEmpty)
                    Text(c.tr('Noch kein Eintrag', 'No entries yet')),
                  for (final r in (day['entries'] as List).cast<Json>())
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.meal(r['meal']),
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                        FoodEntryTile(entry: r),
                      ],
                    ),
                ],
              ),
            ),
            WaterPanel(day: day),
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Heading(c.tr('Periode & Blutung', 'Period & flow')),
                  if (p != null)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        '${c.date(p['start'], short: true)} – ${p['end'] == null ? c.tr('läuft noch', 'ongoing') : c.date(p['end'], short: true)}',
                      ),
                      subtitle: Text(c.strength(p['strength'])),
                      trailing: const Icon(Icons.edit_outlined, size: 18),
                      onTap: () => editRecord(context, 'periods', record: p),
                    ),
                  if (b == null) Text(c.tr('Keine Aufzeichnung', 'No record')),
                  if (b != null)
                    Text(
                      c.strength(b['strength']) +
                          ((b['note'] as String?)?.isNotEmpty == true
                              ? ' · ${b['note']}'
                              : ''),
                    ),
                  Wrap(
                    spacing: 8,
                    children: [
                      TextButton(
                        onPressed: () =>
                            editRecord(context, 'bleeding', record: explicit),
                        child: Text(c.tr('Blutung erfassen', 'Record flow')),
                      ),
                      TextButton(
                        onPressed: () =>
                            editRecord(context, 'periods', record: p),
                        child: Text(c.tr('Periode erfassen', 'Record period')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Heading(
                    c.tr('Gewicht', 'Weight'),
                    trailing: IconButton(
                      tooltip: c.tr('Gewicht erfassen', 'Log weight'),
                      onPressed: () => editRecord(context, 'weights'),
                      icon: const Icon(Icons.add),
                    ),
                  ),
                  if (weights.isEmpty)
                    Text(c.tr('Noch kein Eintrag', 'No entries yet')),
                  for (final r in weights) WeightTile(record: r),
                ],
              ),
            ),
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Heading(
                    c.tr('Symptome', 'Symptoms'),
                    trailing: IconButton(
                      tooltip: c.tr('Symptom erfassen', 'Record symptom'),
                      onPressed: () => editRecord(context, 'symptoms'),
                      icon: const Icon(Icons.add),
                    ),
                  ),
                  if (symptoms.isEmpty)
                    Text(c.tr('Noch kein Eintrag', 'No entries yet')),
                  for (final r in symptoms) SymptomTile(record: r),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
