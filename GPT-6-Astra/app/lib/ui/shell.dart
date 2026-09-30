import 'package:flutter/material.dart';
import '../core/core.dart';
import 'shared.dart';
import 'nutrition.dart';
import 'health.dart';
import 'settings.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key, required this.model});
  final AppModel model;
  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int index = 0;
  @override
  Widget build(BuildContext context) {
    final m = widget.model;
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.spa_outlined, size: 24),
            SizedBox(width: 10),
            Text(
              'MorphHealth',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                letterSpacing: -.6,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: m.tr('Einstellungen', 'Settings'),
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => SettingsPage(model: m)),
            ),
            icon: const Icon(Icons.tune_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: SafeArea(
        top: false,
        child: IndexedStack(
          index: index,
          children: [
            HomePage(model: m, onNavigate: (i) => setState(() => index = i)),
            NutritionPage(model: m),
            CyclePage(model: m),
            TrendsPage(model: m),
            HistoryPage(model: m),
          ],
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: index,
        onDestinationSelected: (v) => setState(() => index = v),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.space_dashboard_outlined),
            selectedIcon: const Icon(Icons.space_dashboard),
            label: m.tr('Übersicht', 'Overview'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.restaurant_outlined),
            label: m.tr('Ernährung', 'Food'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.calendar_month_outlined),
            label: m.tr('Zyklus', 'Cycle'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.insights_outlined),
            label: m.tr('Verläufe', 'Trends'),
          ),
          NavigationDestination(
            icon: const Icon(Icons.history),
            label: m.tr('Historie', 'History'),
          ),
        ],
      ),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key, required this.model, required this.onNavigate});
  final AppModel model;
  final ValueChanged<int> onNavigate;
  @override
  Widget build(BuildContext context) {
    final m = model;
    final day = dateKey(m.selectedDate);
    final n = nutritionDay(m.doc, day);
    final visible = m.settings['visible'] as Map;
    final records = dayRecords(m, day);
    final weights = records.where((e) => e['collection'] == 'weights').toList();
    final symptoms = records
        .where((e) => e['collection'] == 'symptoms')
        .toList();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        Text(
          m.tr('Dein Tag. Dein Rhythmus.', 'Your day. Your rhythm.'),
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 8),
        Text(
          m.tr(
            'Ein Ort für das, was dir wichtig ist.',
            'A space for what matters to you.',
          ),
          style: const TextStyle(color: Color(0xFF60716A)),
        ),
        const SizedBox(height: 14),
        dateBar(context, m),
        const SizedBox(height: 16),
        Panel(
          color: mint,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.wb_sunny_outlined, size: 20),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      m.tr('DEIN TAGESBLICK', 'YOUR DAILY VIEW'),
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                records.isEmpty
                    ? m.tr('Platz für deinen Alltag', 'Room for your everyday')
                    : m.tr(
                        '${records.length} Einträge für diesen Tag',
                        '${records.length} entries for this day',
                      ),
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                m.tr(
                  'Behalte Ernährung und Wohlbefinden in deinem eigenen Tempo im Blick.',
                  'Keep track of food and wellbeing at your own pace.',
                ),
              ),
              const SizedBox(height: 14),
              FilledButton.tonalIcon(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(builder: (_) => DayPage(model: m)),
                ),
                icon: const Icon(Icons.arrow_forward, size: 18),
                label: Text(
                  m.tr('Gemeinsames Tagesdetail', 'Combined daily detail'),
                ),
              ),
            ],
          ),
        ),
        if (visible['nutrition'] == true) ...[
          SectionTitle(
            m.tr('Ernährung', 'Nutrition'),
            trailing: TextButton(
              onPressed: () => onNavigate(1),
              child: Text(m.tr('Öffnen', 'Open')),
            ),
          ),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      fmt((n['totals'] as Map)['energy'] as num?),
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const Padding(
                      padding: EdgeInsets.only(left: 6, bottom: 5),
                      child: Text('kcal'),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 18,
                  runSpacing: 8,
                  children: [
                    for (final key in ['protein', 'carbs', 'fat'])
                      Text(
                        '${m.de ? nutrients.firstWhere((x) => x.key == key).de : nutrients.firstWhere((x) => x.key == key).en}: ${fmt((n['totals'] as Map)[key] as num?)} g',
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  '${m.tr('Wasser', 'Water')}: ${fmt(n['waterMl'] as num?)} ml · ${m.tr('Koffein', 'Caffeine')}: ${fmt(n['caffeineMg'] as num?)} mg',
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    FilledButton.icon(
                      onPressed: () => editMeal(context, m),
                      icon: const Icon(Icons.add, size: 18),
                      label: Text(m.tr('Essen erfassen', 'Log food')),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => editDrink(context, m),
                      icon: const Icon(Icons.water_drop_outlined, size: 18),
                      label: Text(m.tr('Wasser', 'Water')),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
        if (visible['cycle'] == true) ...[
          SectionTitle(
            m.tr('Zyklus', 'Cycle'),
            trailing: TextButton(
              onPressed: () => onNavigate(2),
              child: Text(m.tr('Öffnen', 'Open')),
            ),
          ),
          Panel(
            color: const Color(0xFFF3E7E0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                cycleSummary(m),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => editPeriod(context, m),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(m.tr('Periode erfassen', 'Log period')),
                ),
              ],
            ),
          ),
        ],
        if (visible['weight'] == true) ...[
          SectionTitle(
            m.tr('Gewicht', 'Weight'),
            trailing: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(builder: (_) => WeightPage(model: m)),
              ),
              child: Text(m.tr('Verlauf', 'History')),
            ),
          ),
          Panel(
            child: Row(
              children: [
                const Icon(Icons.monitor_weight_outlined, size: 28),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(
                    weights.isEmpty
                        ? m.tr(
                            'Heute noch kein Eintrag',
                            'No entry for this day',
                          )
                        : weightLabel(m, weights.first['item'] as Json),
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                IconButton.filledTonal(
                  tooltip: m.tr('Gewicht erfassen', 'Log weight'),
                  onPressed: () => editWeight(context, m),
                  icon: const Icon(Icons.add),
                ),
              ],
            ),
          ),
        ],
        if (visible['symptoms'] == true) ...[
          SectionTitle(
            m.tr('Symptome', 'Symptoms'),
            trailing: TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute<void>(builder: (_) => SymptomsPage(model: m)),
              ),
              child: Text(m.tr('Verlauf', 'History')),
            ),
          ),
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  symptoms.isEmpty
                      ? m.tr('Wie fühlst du dich?', 'How are you feeling?')
                      : symptoms
                            .map((e) => (e['item'] as Json)['name'])
                            .join(' · '),
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => editSymptom(context, m),
                  icon: const Icon(Icons.add, size: 18),
                  label: Text(m.tr('Symptom erfassen', 'Log symptom')),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 24),
        Row(
          children: [
            const Icon(Icons.lock_outline, size: 15, color: Color(0xFF60716A)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                m.tr(
                  'Privat auf deinem Gerät. Ohne Konto.',
                  'Private on your device. No account needed.',
                ),
                style: const TextStyle(fontSize: 12, color: Color(0xFF60716A)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

List<Json> dayRecords(AppModel m, String day) {
  final rows = history(m.doc, from: day, to: day, limit: 10000);
  final ids = rows
      .where((e) => e['collection'] == 'periods')
      .map((e) => (e['item'] as Json)['id'])
      .toSet();
  for (final raw in m.doc['periods'] as List) {
    final p = raw as Json;
    if ((p['start'] as String).compareTo(day) <= 0 &&
        ((p['end'] as String? ?? dateKey(DateTime.now())).compareTo(day) >=
            0) &&
        !ids.contains(p['id'])) {
      rows.add({
        'collection': 'periods',
        'item': p,
        'date': day,
        'title': m.tr('Periode', 'Period'),
      });
    }
  }
  return rows;
}

String weightLabel(AppModel m, Json e) {
  final lb = m.settings['weightUnit'] == 'lb';
  return '${fmt((e['kg'] as num) * (lb ? 2.2046226218 : 1))} ${lb ? 'lb' : 'kg'}';
}

String recordTitle(AppModel m, Json row) {
  final e = row['item'] as Json;
  switch (row['collection']) {
    case 'meals':
      return (e['food'] as Json)['name'] as String;
    case 'drinks':
      return e['kind'] == 'water'
          ? m.tr('Wasser', 'Water')
          : m.tr('Zusätzliches Koffein', 'Additional caffeine');
    case 'periods':
      return m.tr('Periode', 'Period');
    case 'weights':
      return weightLabel(m, e);
    default:
      return e['name'] as String;
  }
}

String recordSubtitle(AppModel m, Json row) {
  final e = row['item'] as Json;
  String info;
  switch (row['collection']) {
    case 'meals':
      final meal = {
        'breakfast': m.tr('Frühstück', 'Breakfast'),
        'lunch': m.tr('Mittagessen', 'Lunch'),
        'dinner': m.tr('Abendessen', 'Dinner'),
        'snack': m.tr('Snack', 'Snack'),
      }[e['meal']];
      info =
          '${fmt(e['amount'] as num)} ${e['unit'] == 'serving' ? m.tr('Portionen', 'servings') : e['unit']} · $meal';
    case 'drinks':
      info = '${fmt(e['amount'] as num)} ${e['kind'] == 'water' ? 'ml' : 'mg'}';
    case 'periods':
      final flow = {
        'spotting': m.tr('Spotting', 'Spotting'),
        'light': m.tr('Leicht', 'Light'),
        'medium': m.tr('Mittel', 'Medium'),
        'heavy': m.tr('Stark', 'Heavy'),
      }[e['flow']];
      info = "${e['start']} – ${e['end'] ?? m.tr('offen', 'ongoing')} · $flow";
    case 'weights':
      info = m.tr('Gewicht', 'Weight');
    default:
      info = '${m.tr('Intensität', 'Intensity')} ${e['intensity']}/10';
  }
  return '$info${(e['note'] as String? ?? '').isNotEmpty ? ' · ${e['note']}' : ''}';
}

IconData recordIcon(String collection) => switch (collection) {
  'meals' => Icons.restaurant_outlined,
  'drinks' => Icons.water_drop_outlined,
  'periods' => Icons.water_drop,
  'weights' => Icons.monitor_weight_outlined,
  _ => Icons.favorite_outline,
};
Future<void> editRecord(BuildContext context, AppModel m, Json row) async {
  FocusManager.instance.primaryFocus?.unfocus();
  final e = row['item'] as Json;
  switch (row['collection']) {
    case 'meals':
      await editMeal(context, m, entry: e);
    case 'drinks':
      await editDrink(context, m, entry: e);
    case 'periods':
      await editPeriod(context, m, entry: e);
    case 'weights':
      await editWeight(context, m, entry: e);
    case 'symptoms':
      await editSymptom(context, m, entry: e);
  }
}

Widget recordTile(
  BuildContext context,
  AppModel m,
  Json row, {
  bool showDate = false,
}) => ListTile(
  contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
  leading: CircleAvatar(
    backgroundColor: mint,
    foregroundColor: ink,
    child: Icon(recordIcon(row['collection'] as String), size: 20),
  ),
  title: Text(recordTitle(m, row)),
  subtitle: Text(
    '${showDate ? '${row['date']} · ' : ''}${recordSubtitle(m, row)}',
  ),
  trailing: const Icon(Icons.chevron_right, size: 20),
  onTap: () => editRecord(context, m, row),
);

class DayPage extends StatelessWidget {
  const DayPage({super.key, required this.model});
  final AppModel model;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: model,
    builder: (context, _) {
      final m = model;
      final rows = dayRecords(m, dateKey(m.selectedDate));
      return Scaffold(
        appBar: AppBar(
          title: Text(m.tr('Dein Tagesdetail', 'Your daily detail')),
        ),
        body: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            dateBar(context, m),
            const SizedBox(height: 16),
            Text(
              m.tr('Alles für diesen Tag', 'Everything for this day'),
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ActionChip(
                  avatar: const Icon(Icons.restaurant, size: 18),
                  label: Text(m.tr('Essen', 'Food')),
                  onPressed: () => editMeal(context, m),
                ),
                ActionChip(
                  avatar: const Icon(Icons.water_drop, size: 18),
                  label: Text(m.tr('Wasser', 'Water')),
                  onPressed: () => editDrink(context, m),
                ),
                ActionChip(
                  label: Text(m.tr('Koffein', 'Caffeine')),
                  onPressed: () => editDrink(context, m, kind: 'caffeine'),
                ),
                ActionChip(
                  label: Text(m.tr('Periode', 'Period')),
                  onPressed: () => editPeriod(context, m),
                ),
                ActionChip(
                  label: Text(m.tr('Gewicht', 'Weight')),
                  onPressed: () => editWeight(context, m),
                ),
                ActionChip(
                  label: Text(m.tr('Symptom', 'Symptom')),
                  onPressed: () => editSymptom(context, m),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (rows.isEmpty)
              EmptyState(
                icon: Icons.event_note_outlined,
                title: m.tr('Noch keine Einträge', 'No entries yet'),
                message: m.tr(
                  'Erfasse etwas über die Schaltflächen oben.',
                  'Add an entry using the buttons above.',
                ),
              )
            else
              Panel(
                child: Column(
                  children: [
                    for (final row in rows) recordTile(context, m, row),
                  ],
                ),
              ),
          ],
        ),
      );
    },
  );
}

class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key, required this.model});
  final AppModel model;
  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  String query = '', area = 'all';
  DateTime? from, to;
  int limit = 60;
  final search = TextEditingController();
  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.model;
    final rows = history(
      m.doc,
      from: from == null ? null : dateKey(from!),
      to: to == null ? null : dateKey(to!),
      area: area == 'all' ? null : area,
      query: query,
      limit: (limit + 1).clamp(1, 10000),
    );
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        Text(
          m.tr('Deine Historie', 'Your history'),
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 8),
        Text(
          m.tr(
            'Einträge wiederfinden und anpassen.',
            'Find and adjust your entries.',
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: search,
          decoration: InputDecoration(
            labelText: m.tr('Alle Einträge durchsuchen', 'Search all entries'),
            prefixIcon: const Icon(Icons.search),
            suffixIcon: query.isEmpty
                ? null
                : IconButton(
                    tooltip: m.tr('Suche leeren', 'Clear search'),
                    onPressed: () {
                      search.clear();
                      setState(() {
                        query = '';
                        limit = 60;
                      });
                    },
                    icon: const Icon(Icons.clear),
                  ),
          ),
          onChanged: (s) => setState(() {
            query = s;
            limit = 60;
          }),
        ),
        const SizedBox(height: 12),
        DropdownButtonFormField<String>(
          initialValue: area,
          decoration: InputDecoration(labelText: m.tr('Bereich', 'Area')),
          items: [
            for (final item in [
              ['all', m.tr('Alle Bereiche', 'All areas')],
              ['nutrition', m.tr('Ernährung', 'Nutrition')],
              ['cycle', m.tr('Zyklus', 'Cycle')],
              ['weight', m.tr('Gewicht', 'Weight')],
              ['symptoms', m.tr('Symptome', 'Symptoms')],
            ])
              DropdownMenuItem(value: item[0], child: Text(item[1])),
          ],
          onChanged: (s) => setState(() {
            area = s!;
            limit = 60;
          }),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            TextButton.icon(
              onPressed: () async {
                final d = await pickDate(context, from ?? m.selectedDate);
                if (d != null) {
                  setState(() {
                    from = d;
                    if (to != null && to!.isBefore(d)) to = d;
                    limit = 60;
                  });
                }
              },
              icon: const Icon(Icons.calendar_today, size: 16),
              label: Text(
                from == null
                    ? m.tr('Von Datum', 'From date')
                    : displayDate(from!, m.de),
              ),
            ),
            TextButton.icon(
              onPressed: () async {
                final d = await pickDate(context, to ?? m.selectedDate);
                if (d != null) {
                  setState(() {
                    to = d;
                    if (from != null && from!.isAfter(d)) from = d;
                    limit = 60;
                  });
                }
              },
              icon: const Icon(Icons.calendar_today, size: 16),
              label: Text(
                to == null
                    ? m.tr('Bis Datum', 'To date')
                    : displayDate(to!, m.de),
              ),
            ),
            if (from != null || to != null)
              IconButton(
                tooltip: m.tr('Datumsfilter entfernen', 'Clear date filter'),
                onPressed: () => setState(() {
                  from = null;
                  to = null;
                  limit = 60;
                }),
                icon: const Icon(Icons.filter_alt_off_outlined),
              ),
          ],
        ),
        const SizedBox(height: 12),
        if (rows.isEmpty)
          EmptyState(
            icon: Icons.search_off,
            title: m.tr('Keine passenden Einträge', 'No matching entries'),
            message: m.tr(
              'Passe die Filter an oder erfasse einen neuen Eintrag.',
              'Adjust the filters or add a new entry.',
            ),
          )
        else ...[
          Text(
            m.tr(
              'Zum Bearbeiten einen Eintrag öffnen.',
              'Open an entry to edit it.',
            ),
            style: const TextStyle(fontSize: 12),
          ),
          const SizedBox(height: 12),
          ...rows
              .take(limit)
              .map((row) => recordTile(context, m, row, showDate: true)),
          if (rows.length > limit)
            OutlinedButton(
              onPressed: () =>
                  setState(() => limit = (limit + 60).clamp(1, 10000)),
              child: Text(m.tr('Weitere Einträge laden', 'Load more entries')),
            ),
        ],
      ],
    );
  }
}

class TrendsPage extends StatefulWidget {
  const TrendsPage({super.key, required this.model});
  final AppModel model;
  @override
  State<TrendsPage> createState() => _TrendsPageState();
}

class _TrendsPageState extends State<TrendsPage> {
  int days = 7;
  String metric = 'energy';
  String? symptom;
  @override
  Widget build(BuildContext context) {
    final m = widget.model;
    final names =
        (m.doc['symptoms'] as List)
            .map((s) => s['name'] as String)
            .toSet()
            .toList()
          ..sort();
    if (!names.contains(symptom)) symptom = names.isEmpty ? null : names.first;
    final options = <String, String>{
      for (final n in nutrients) n.key: '${m.de ? n.de : n.en} (${n.unit})',
      'water': m.tr('Wasser (ml)', 'Water (ml)'),
      'weight': m.tr('Gewicht', 'Weight'),
      'symptoms': m.tr('Symptomintensität', 'Symptom intensity'),
      'cycle': m.tr('Blutungsstärke', 'Bleeding flow'),
    };
    final dates = List.generate(
      days,
      (i) => DateTime(
        m.selectedDate.year,
        m.selectedDate.month,
        m.selectedDate.day - days + 1 + i,
      ),
    );
    final values = <double?>[];
    for (final d in dates) {
      final key = dateKey(d);
      if (metric == 'weight') {
        final ws =
            (m.doc['weights'] as List)
                .where((e) => (e['at'] as String).startsWith(key))
                .toList()
              ..sort(
                (a, b) => (a['at'] as String).compareTo(b['at'] as String),
              );
        values.add(
          ws.isEmpty
              ? null
              : (ws.last['kg'] as num).toDouble() *
                    (m.settings['weightUnit'] == 'lb' ? 2.2046226218 : 1),
        );
      } else if (metric == 'symptoms') {
        final ss = (m.doc['symptoms'] as List)
            .where(
              (e) =>
                  e['name'] == symptom && (e['at'] as String).startsWith(key),
            )
            .toList();
        values.add(
          ss.isEmpty
              ? null
              : ss
                    .map((e) => (e['intensity'] as num).toDouble())
                    .reduce((a, b) => a > b ? a : b),
        );
      } else if (metric == 'cycle') {
        final ps = (m.doc['periods'] as List)
            .where(
              (e) =>
                  (e['start'] as String).compareTo(key) <= 0 &&
                  ((e['end'] as String? ?? dateKey(DateTime.now())).compareTo(
                        key,
                      ) >=
                      0),
            )
            .toList();
        values.add(
          ps.isEmpty
              ? null
              : const {
                  'spotting': 1.0,
                  'light': 2.0,
                  'medium': 3.0,
                  'heavy': 4.0,
                }[ps.last['flow']],
        );
      } else {
        final n = nutritionDay(m.doc, key);
        values.add(
          metric == 'water'
              ? (n['waterMl'] as num).toDouble()
              : ((n['totals'] as Map)[metric] as num?)?.toDouble(),
        );
      }
    }
    final unit = metric == 'water'
        ? 'ml'
        : metric == 'weight'
        ? m.settings['weightUnit'] as String
        : metric == 'symptoms'
        ? '/10'
        : metric == 'cycle'
        ? '/4'
        : nutrients.firstWhere((n) => n.key == metric).unit;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      children: [
        Text(
          m.tr('Muster entdecken', 'Discover patterns'),
          style: Theme.of(context).textTheme.headlineLarge,
        ),
        const SizedBox(height: 8),
        Text(
          m.tr('Deine Aufzeichnungen im Verlauf.', 'Your records over time.'),
        ),
        const SizedBox(height: 16),
        dateBar(context, m),
        const SizedBox(height: 12),
        SegmentedButton<int>(
          segments: [
            ButtonSegment(value: 7, label: Text(m.tr('7 Tage', '7 days'))),
            ButtonSegment(value: 28, label: Text(m.tr('28 Tage', '28 days'))),
          ],
          selected: {days},
          onSelectionChanged: (v) => setState(() => days = v.first),
        ),
        const SizedBox(height: 20),
        DropdownButtonFormField<String>(
          initialValue: metric,
          isExpanded: true,
          decoration: InputDecoration(
            labelText: m.tr('Angezeigter Wert', 'Displayed metric'),
          ),
          items: options.entries
              .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
              .toList(),
          onChanged: (v) => setState(() => metric = v!),
        ),
        if (metric == 'symptoms') ...[
          const SizedBox(height: 12),
          if (names.isEmpty)
            Text(m.tr('Erfasse zuerst ein Symptom.', 'Log a symptom first.'))
          else
            DropdownButtonFormField<String>(
              key: ValueKey(symptom),
              initialValue: symptom,
              isExpanded: true,
              decoration: InputDecoration(
                labelText: m.tr('Symptom', 'Symptom'),
              ),
              items: names
                  .map((n) => DropdownMenuItem(value: n, child: Text(n)))
                  .toList(),
              onChanged: (v) => setState(() => symptom = v),
            ),
        ],
        const SizedBox(height: 20),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                options[metric]!,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              TrendPlot(
                values: values,
                labels: dates.map((d) => displayDate(d, m.de)).toList(),
                unit: unit,
                model: m,
              ),
              const SizedBox(height: 8),
              Text(
                metric == 'symptoms'
                    ? m.tr(
                        'Je Tag wird die höchste erfasste Intensität angezeigt.',
                        'Shows the highest recorded intensity per day.',
                      )
                    : metric == 'weight'
                    ? m.tr(
                        'Je Tag wird der letzte Eintrag angezeigt.',
                        'Shows the last entry per day.',
                      )
                    : metric == 'cycle'
                    ? m.tr(
                        '1 Spotting · 2 leicht · 3 mittel · 4 stark. Lücken bedeuten: keine Aufzeichnung.',
                        '1 spotting · 2 light · 3 medium · 4 heavy. Gaps mean no record.',
                      )
                    : m.tr(
                        'Summen bekannter Werte. Fehlende Nährwerte sind unbekannt und keine Nullwerte.',
                        'Sums of known values. Missing nutrients are unknown, not zero.',
                      ),
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        OutlinedButton.icon(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute<void>(builder: (_) => DayPage(model: m)),
          ),
          icon: const Icon(Icons.event_note_outlined),
          label: Text(m.tr('Ausgewählten Tag öffnen', 'Open selected day')),
        ),
      ],
    );
  }
}
