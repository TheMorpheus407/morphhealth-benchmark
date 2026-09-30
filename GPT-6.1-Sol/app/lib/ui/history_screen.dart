import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../core/model.dart';
import '../core/nutrients.dart';
import 'common.dart';
import 'controller.dart';
import 'editors.dart';
import 'overview.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});
  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  bool trends = false;
  final search = TextEditingController();
  Timer? debounce;
  String query = '';
  DateTimeRange? range;
  final areas = <String>{...areaNames};
  @override
  void dispose() {
    debounce?.cancel();
    search.dispose();
    super.dispose();
  }

  Future<void> open(Json item) async {
    final c = AppScope.of(context),
        r = item['record'] as Json,
        t = item['table'] as String;
    c.day(item['date']);
    if (t == 'consumption') {
      await editConsumption(context, r['food'], record: r);
    } else {
      await editRecord(context, t, record: r);
    }
  }

  String title(Json item) {
    final c = AppScope.of(context), r = item['record'] as Json;
    return switch (item['table']) {
      'consumption' => c.foodName(r['food']),
      'drinks' =>
        r['kind'] == 'water'
            ? c.tr('Wasser', 'Water')
            : c.tr('Koffein zusätzlich', 'Additional caffeine'),
      'weights' =>
        '${c.tr('Gewicht', 'Weight')} · ${c.fmt(number(r['kg'])! / (c.pounds ? .45359237 : 1), digits: 2)} ${c.pounds ? 'lb' : 'kg'}',
      'periods' =>
        '${c.tr('Periode', 'Period')} · ${c.strength(r['strength'])}',
      'bleeding' => '${c.tr('Blutung', 'Flow')} · ${c.strength(r['strength'])}',
      _ => r['name'],
    };
  }

  String subtitle(Json item) {
    final c = AppScope.of(context), r = item['record'] as Json;
    var text = c.date(item['date'], short: true);
    if (r['at'] != null) text += ' · ${(r['at'] as String).substring(11, 16)}';
    if (item['table'] == 'consumption') {
      text +=
          ' · ${c.fmt(r['amount'])} ${c.unit(r['unit'])} · ${c.meal(r['meal'])}';
    }
    if (item['table'] == 'drinks') {
      text += ' · ${c.fmt(r['amount'])}${r['kind'] == 'water' ? ' ml' : ' mg'}';
    }
    if (item['table'] == 'symptoms') {
      text += ' · ${r['intensity']} / 10';
    }
    if (item['table'] == 'periods') {
      text +=
          ' – ${r['end'] == null ? c.tr('läuft noch', 'ongoing') : c.date(r['end'], short: true)}';
    }
    if ((r['note'] as String?)?.isNotEmpty == true) text += ' · ${r['note']}';
    return text;
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final items = c.engine.history(
      q: query,
      from: range == null ? null : dateKey(range!.start),
      to: range == null ? null : dateKey(range!.end),
      areas: areas,
    );
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 12),
          child: SizedBox(
            width: double.infinity,
            child: SegmentedButton<bool>(
              segments: [
                ButtonSegment(
                  value: false,
                  label: Text(c.tr('Historie', 'History')),
                  icon: const Icon(Icons.history),
                ),
                ButtonSegment(
                  value: true,
                  label: Text(c.tr('Verläufe', 'Trends')),
                  icon: const Icon(Icons.show_chart),
                ),
              ],
              selected: {trends},
              onSelectionChanged: (v) => setState(() => trends = v.first),
            ),
          ),
        ),
        if (trends) const Expanded(child: TrendsView()),
        if (!trends) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: TextField(
              key: const ValueKey('history-search'),
              controller: search,
              decoration: InputDecoration(
                labelText: c.tr(
                  'Alle Einträge durchsuchen',
                  'Search all entries',
                ),
                prefixIcon: const Icon(Icons.search),
                suffixIcon: search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: c.tr('Leeren', 'Clear'),
                        onPressed: () => setState(() {
                          search.clear();
                          query = '';
                        }),
                        icon: const Icon(Icons.close),
                      ),
              ),
              onChanged: (v) {
                debounce?.cancel();
                debounce = Timer(const Duration(milliseconds: 180), () {
                  if (mounted) setState(() => query = v);
                });
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final a in areaNames)
                  FilterChip(
                    selected: areas.contains(a),
                    label: Text(switch (a) {
                      'nutrition' => c.tr('Ernährung', 'Nutrition'),
                      'cycle' => c.tr('Zyklus', 'Cycle'),
                      'weight' => c.tr('Gewicht', 'Weight'),
                      _ => c.tr('Symptome', 'Symptoms'),
                    }),
                    onSelected: (v) => setState(() {
                      if (v) {
                        areas.add(a);
                      } else {
                        areas.remove(a);
                      }
                    }),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
            child: Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: () async {
                      final r = await showDateRangePicker(
                        context: context,
                        firstDate: DateTime(1900),
                        lastDate: DateTime(2200),
                        initialDateRange: range,
                      );
                      if (r != null) setState(() => range = r);
                    },
                    icon: const Icon(Icons.date_range_outlined),
                    label: Text(
                      range == null
                          ? c.tr('Alle Zeiträume', 'All dates')
                          : '${c.date(dateKey(range!.start), short: true)} – ${c.date(dateKey(range!.end), short: true)}',
                    ),
                  ),
                ),
                if (range != null)
                  IconButton(
                    tooltip: c.tr(
                      'Datumsfilter zurücksetzen',
                      'Reset date filter',
                    ),
                    onPressed: () => setState(() => range = null),
                    icon: const Icon(Icons.close),
                  ),
                Text(
                  items.length.toString(),
                  style: Theme.of(context).textTheme.labelLarge,
                ),
              ],
            ),
          ),
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        c.tr(
                          'Keine passenden Einträge.',
                          'No matching entries.',
                        ),
                      ),
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                    itemCount: items.length,
                    itemBuilder: (ctx, i) {
                      final item = items[i];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Icon(switch (item['area']) {
                            'nutrition' => Icons.restaurant_outlined,
                            'cycle' => Icons.water_drop_outlined,
                            'weight' => Icons.monitor_weight_outlined,
                            _ => Icons.spa_outlined,
                          }),
                          title: Text(title(item)),
                          subtitle: Text(
                            subtitle(item),
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: const Icon(Icons.edit_outlined, size: 18),
                          onTap: () => open(item),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ],
    );
  }
}

class TrendsView extends StatefulWidget {
  const TrendsView({super.key});
  @override
  State<TrendsView> createState() => _TrendsViewState();
}

class _TrendsViewState extends State<TrendsView> {
  int days = 7;
  String area = 'nutrition', nutrient = 'calories';
  String? symptom;
  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final names =
        c.data['symptoms'].map((r) => r['name'] as String).toSet().toList()
          ..sort();
    if (!names.contains(symptom)) symptom = names.firstOrNull;
    final dates = List.generate(
      days,
      (i) => addDays(c.selectedDay, i - days + 1),
    );
    final points = <double?>[], labels = <String>[];
    final unit = area == 'nutrition'
        ? (nutrient == 'water' ? 'ml' : nutrientById(nutrient).unit)
        : area == 'weight'
        ? (c.pounds ? 'lb' : 'kg')
        : area == 'symptoms'
        ? '/ 10'
        : '';
    for (final date in dates) {
      double? value;
      String? label;
      if (area == 'nutrition') {
        final d = c.engine.nutritionDay(date);
        value = number(
          nutrient == 'water' ? d['water_ml'] : d['nutrients'][nutrient],
        );
        if (nutrient != 'water' &&
            (d['incomplete_nutrients'] as List).contains(nutrient)) {
          label = '${c.fmt(value, digits: 3)} $unit *';
        }
      }
      if (area == 'weight') {
        final weights = c.engine.on('weights', date);
        if (weights.isNotEmpty) {
          value =
              weights.map((r) => number(r['kg'])!).reduce((a, b) => a + b) /
              weights.length /
              (c.pounds ? .45359237 : 1);
        }
      }
      if (area == 'symptoms') {
        final symptoms = c.engine
            .on('symptoms', date)
            .where((r) => r['name'] == symptom);
        if (symptoms.isNotEmpty) {
          value = symptoms.map((r) => number(r['intensity'])!).reduce(math.max);
        }
      }
      if (area == 'cycle') {
        final bleeding = c.engine.bleedingOn(date);
        if (bleeding != null) {
          value = [
            'none',
            'spotting',
            'light',
            'medium',
            'heavy',
          ].indexOf(bleeding['strength']).toDouble();
          label = c.strength(bleeding['strength']);
        }
      }
      points.add(value);
      labels.add(
        label ??
            (value == null
                ? c.tr('Keine Angabe', 'No value')
                : '${c.fmt(value, digits: 3)} $unit'),
      );
    }
    final heading = area == 'nutrition'
        ? (nutrient == 'water'
              ? c.tr('Wasser', 'Water')
              : nutrientById(nutrient).name(c.language))
        : area == 'weight'
        ? c.tr('Gewicht', 'Weight')
        : area == 'symptoms'
        ? symptom ?? c.tr('Symptom', 'Symptom')
        : c.tr('Blutungsstärke', 'Flow');
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
      children: [
        const DayBar(),
        SegmentedButton<int>(
          segments: [
            ButtonSegment(value: 1, label: Text(c.tr('Tag', 'Day'))),
            ButtonSegment(value: 7, label: Text(c.tr('7 Tage', '7 days'))),
            ButtonSegment(value: 28, label: Text(c.tr('28 Tage', '28 days'))),
          ],
          selected: {days},
          onSelectionChanged: (v) => setState(() => days = v.first),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: area,
          decoration: InputDecoration(labelText: c.tr('Bereich', 'Section')),
          items: areaNames
              .map(
                (a) => DropdownMenuItem(
                  value: a,
                  child: Text(switch (a) {
                    'nutrition' => c.tr('Ernährung', 'Nutrition'),
                    'weight' => c.tr('Gewicht', 'Weight'),
                    'cycle' => c.tr('Zyklus', 'Cycle'),
                    _ => c.tr('Symptome', 'Symptoms'),
                  }),
                ),
              )
              .toList(),
          onChanged: (v) => setState(() => area = v!),
        ),
        const SizedBox(height: 16),
        if (area == 'nutrition')
          DropdownButtonFormField<String>(
            initialValue: nutrient,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: c.tr('Nährstoff oder Wasser', 'Nutrient or water'),
            ),
            items: [
              ...nutrients.map(
                (n) => DropdownMenuItem(
                  value: n.id,
                  child: Text(n.name(c.language)),
                ),
              ),
              DropdownMenuItem(
                value: 'water',
                child: Text(c.tr('Wasser', 'Water')),
              ),
            ],
            onChanged: (v) => setState(() => nutrient = v!),
          ),
        if (area == 'symptoms' && names.isNotEmpty)
          DropdownButtonFormField<String>(
            key: ValueKey(symptom),
            initialValue: symptom,
            isExpanded: true,
            decoration: InputDecoration(
              labelText: c.tr('Symptom wählen', 'Choose symptom'),
            ),
            items: names
                .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                .toList(),
            onChanged: (v) => setState(() => symptom = v),
          ),
        const SizedBox(height: 18),
        Panel(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Heading(heading, subtitle: '${dates.first} – ${dates.last}'),
              if (area == 'symptoms' && names.isEmpty)
                EmptyNote(
                  c.tr(
                    'Erfasse zuerst ein Symptom.',
                    'Record a symptom first.',
                  ),
                ),
              if (points.every((p) => p == null))
                EmptyNote(
                  c.tr(
                    'In diesem Zeitraum fehlen Werte.',
                    'There are no values in this period.',
                  ),
                ),
              if (points.any((p) => p != null)) ...[
                Text(
                  '${c.tr('Spanne: ', 'Range: ')}${c.fmt(points.whereType<double>().reduce(math.min), digits: 3)} – ${c.fmt(points.whereType<double>().reduce(math.max), digits: 3)} $unit',
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 180,
                  width: double.infinity,
                  child: Semantics(
                    label:
                        '$heading. ${dates.asMap().entries.map((e) => '${c.date(e.value, short: true)}: ${labels[e.key]}').join('; ')}',
                    child: CustomPaint(
                      painter: TrendPainter(
                        points,
                        area == 'cycle' ? rose : ink,
                        labelFormat: (value) => c.fmt(value, digits: 3),
                        minimum: area == 'symptoms' || area == 'cycle'
                            ? 0
                            : null,
                        maximum: area == 'symptoms'
                            ? 10
                            : area == 'cycle'
                            ? 4
                            : null,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(c.date(dates.first, short: true)),
                    Text(c.date(dates.last, short: true)),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              Text(
                area == 'weight'
                    ? c.tr(
                        'Tagesmittel bei mehreren Einträgen. Lücken bleiben sichtbar.',
                        'Daily mean when there are multiple entries. Gaps stay visible.',
                      )
                    : area == 'symptoms'
                    ? c.tr(
                        'Höchste aufgezeichnete Intensität je Tag für das gewählte Symptom.',
                        'Highest recorded daily intensity for the selected symptom.',
                      )
                    : area == 'cycle'
                    ? c.tr(
                        '0 keine · 1 Spotting · 2 leicht · 3 mittel · 4 stark. Tagesaufzeichnungen haben Vorrang vor der Periodenstärke.',
                        '0 none · 1 spotting · 2 light · 3 medium · 4 heavy. Daily records override period flow.',
                      )
                    : c.tr(
                        'Summen der bekannten Angaben. * bedeutet unvollständig; fehlende Angaben werden nicht als 0 gerechnet.',
                        'Totals of known values. * means incomplete; missing values are not counted as 0.',
                      ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
        Heading(
          c.tr('Tage im Detail', 'Daily values'),
          subtitle: c.tr(
            'Antippen öffnet das gemeinsame Tagesdetail.',
            'Tap to open the combined day detail.',
          ),
        ),
        for (var i = dates.length - 1; i >= 0; i--)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              title: Text(c.date(dates[i], short: true)),
              subtitle: Text(labels[i]),
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                c.day(dates[i]);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DayDetail()),
                );
              },
            ),
          ),
      ],
    );
  }
}

class TrendPainter extends CustomPainter {
  final List<double?> points;
  final Color color;
  final double? minimum, maximum;
  final String Function(double)? labelFormat;
  TrendPainter(
    this.points,
    this.color, {
    this.minimum,
    this.maximum,
    this.labelFormat,
  });
  @override
  void paint(Canvas canvas, Size size) {
    final values = points.whereType<double>().toList();
    if (values.isEmpty) return;
    var min = minimum ?? values.reduce(math.min),
        max = maximum ?? values.reduce(math.max);
    if (max == min) {
      final padding = math.max(1.0, max.abs() * .05);
      min = math.max(0, min - padding);
      max += padding;
    }
    final span = max - min;
    const left = 44.0, top = 12.0, bottom = 12.0;
    final width = size.width - left - 8, height = size.height - top - bottom;
    final grid = Paint()
      ..color = const Color(0xffd8e2db)
      ..strokeWidth = 1;
    final line = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    for (var i = 0; i < 3; i++) {
      final y = top + height * i / 2;
      canvas.drawLine(Offset(left, y), Offset(size.width - 8, y), grid);
      final number = max - (span * i / 2);
      final label = TextPainter(
        text: TextSpan(
          text:
              labelFormat?.call(number) ??
              number.toStringAsFixed(number.abs() < 10 ? 1 : 0),
          style: const TextStyle(color: ink, fontSize: 11),
        ),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: 40);
      label.paint(canvas, Offset(0, y - label.height / 2));
    }
    Offset? last;
    for (var i = 0; i < points.length; i++) {
      if (points[i] == null) {
        last = null;
        continue;
      }
      final p = Offset(
        left +
            (points.length == 1 ? width / 2 : width * i / (points.length - 1)),
        top + height - (points[i]! - min) / span * height,
      );
      if (last != null) canvas.drawLine(last, p, line);
      canvas.drawCircle(p, 3.5, Paint()..color = color);
      last = p;
    }
  }

  @override
  bool shouldRepaint(covariant TrendPainter old) => true;
}
