import 'package:flutter/material.dart';
import '../core/model.dart';
import '../core/nutrients.dart';
import 'common.dart';
import 'controller.dart';
import 'editors.dart';

Future<void> pickFood(BuildContext context, {String meal = 'snack'}) =>
    Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => FoodPicker(meal: meal)));

class NutritionSummary extends StatelessWidget {
  final Json day;
  const NutritionSummary({super.key, required this.day});
  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context),
        values = day['nutrients'] as Json,
        goals = day['goals'] as Map;
    return Panel(
      color: sage,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            c.tr('Tagesernährung', 'Daily nutrition'),
            style: Theme.of(context).textTheme.labelLarge,
          ),
          const SizedBox(height: 12),
          Text(
            '${c.fmt(values['calories'])} kcal',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          if (goals['calories'] != null)
            Text(
              '${c.tr('Gewähltes Ziel: ', 'Chosen goal: ')}${c.fmt(goals['calories'])} kcal',
            ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 24,
            runSpacing: 14,
            children: [
              for (final n in nutrients.skip(1).take(3))
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      n.name(c.language),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    Text(
                      '${c.fmt(values[n.id])} g',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (goals[n.id] != null)
                      Text(
                        '/ ${c.fmt(goals[n.id])} g',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
            ],
          ),
          if ((day['incomplete_nutrients'] as List).isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Text(
                c.tr(
                  'Einige Angaben fehlen. Summen können unvollständig sein.',
                  'Some values are missing. Totals may be incomplete.',
                ),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          ExpansionTile(
            tilePadding: EdgeInsets.zero,
            title: Text(c.tr('Alle Nährstoffe', 'All nutrients')),
            children: [
              NutrientTable(
                values: values,
                coverage: day['known_food_count'],
                foodCount: day['food_count'],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class WaterPanel extends StatelessWidget {
  final Json day;
  const WaterPanel({super.key, required this.day});
  Future<void> add(BuildContext context, int ml) async {
    final c = AppScope.of(context);
    try {
      final r = {
        'id': newId(),
        'at': atTime(c.selectedDay, TimeOfDay.now()),
        'kind': 'water',
        'amount': ml,
        'note': '',
      };
      await c.upsert('drinks', r);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${c.tr('Wasser erfasst', 'Water logged')} · $ml ml'),
            action: SnackBarAction(
              label: c.tr('Rückgängig', 'Undo'),
              onPressed: () async {
                try {
                  await c.remove('drinks', r['id'] as String);
                } catch (e) {
                  if (context.mounted) await notifyError(context, e);
                }
              },
            ),
          ),
        );
      }
    } catch (e) {
      if (context.mounted) await notifyError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context), goal = day['goals']['water'];
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Heading(
            c.tr('Wasser & Koffein', 'Water & caffeine'),
            subtitle:
                '${c.fmt(day['water_ml'])} ml${goal == null ? '' : ' / ${c.fmt(goal)} ml'}',
          ),
          if (goal != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: LinearProgressIndicator(
                value: (number(day['water_ml'])! / number(goal)!).clamp(0, 1),
                minHeight: 6,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final ml in [150, 250, 500])
                ActionChip(
                  avatar: const Icon(Icons.water_drop_outlined, size: 18),
                  label: Text('+ $ml ml'),
                  onPressed: () => add(context, ml),
                ),
              ActionChip(
                label: Text(c.tr('Andere Menge', 'Other amount')),
                onPressed: () => editRecord(context, 'drinks'),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${c.tr('Koffein gesamt: ', 'Total caffeine: ')}${c.fmt(day['nutrients']['caffeine'])} mg',
                ),
              ),
              TextButton.icon(
                onPressed: () => editRecord(
                  context,
                  'drinks',
                  record: {
                    'id': newId(),
                    'at': atTime(c.selectedDay, TimeOfDay.now()),
                    'kind': 'caffeine',
                    'amount': 0,
                    'note': '',
                  },
                ),
                icon: const Icon(Icons.add),
                label: Text(c.tr('Koffein', 'Caffeine')),
              ),
            ],
          ),
          for (final r in (day['drinks'] as List).cast<Json>())
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                r['kind'] == 'water'
                    ? Icons.water_drop_outlined
                    : Icons.coffee_outlined,
              ),
              title: Text(
                '${r['kind'] == 'water' ? c.tr('Wasser', 'Water') : c.tr('Koffein zusätzlich', 'Additional caffeine')} · ${c.fmt(r['amount'])}${r['kind'] == 'water' ? ' ml' : ' mg'}',
              ),
              subtitle: Text(
                (r['at'] as String).substring(11, 16) +
                    ((r['note'] as String?)?.isNotEmpty == true
                        ? ' · ${r['note']}'
                        : ''),
              ),
              trailing: const Icon(Icons.edit_outlined, size: 18),
              onTap: () => editRecord(context, 'drinks', record: r),
            ),
        ],
      ),
    );
  }
}

class FoodDiary extends StatelessWidget {
  const FoodDiary({super.key});
  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context), day = c.engine.nutritionDay(c.selectedDay);
    final entries = (day['entries'] as List).cast<Json>();
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const DayBar(),
        NutritionSummary(day: day),
        FilledButton.icon(
          onPressed: () => pickFood(context),
          icon: const Icon(Icons.add),
          label: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Text(c.tr('Lebensmittel erfassen', 'Log food')),
          ),
        ),
        const SizedBox(height: 18),
        WaterPanel(day: day),
        for (final meal in ['breakfast', 'lunch', 'dinner', 'snack'])
          Panel(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Heading(
                  c.meal(meal),
                  trailing: IconButton(
                    tooltip: c.tr('Lebensmittel hinzufügen', 'Add food'),
                    onPressed: () => pickFood(context, meal: meal),
                    icon: const Icon(Icons.add),
                  ),
                ),
                if (!entries.any((e) => e['meal'] == meal))
                  Text(
                    c.tr('Noch kein Eintrag', 'No entries yet'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                for (final e in entries.where((e) => e['meal'] == meal))
                  FoodEntryTile(entry: e),
              ],
            ),
          ),
        const SizedBox(height: 32),
      ],
    );
  }
}

class FoodEntryTile extends StatelessWidget {
  final Json entry;
  const FoodEntryTile({super.key, required this.entry});
  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context), food = entry['food'] as Json;
    final values =
        entry['nutrients'] ??
        scaledNutrients(food, number(entry['amount'])!, entry['unit']);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            onTap: () => editConsumption(context, food, record: entry),
            title: Text(
              c.foodName(food),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              '${c.fmt(entry['amount'])} ${c.unit(entry['unit'])} · ${(entry['at'] as String).substring(11, 16)}',
            ),
            trailing: PopupMenuButton<String>(
              tooltip: c.tr('Eintragsaktionen', 'Entry actions'),
              onSelected: (action) {
                if (action == 'repeat') {
                  editConsumption(context, food, record: entry, repeat: true);
                }
                if (action == 'edit') {
                  editConsumption(context, food, record: entry);
                }
                if (action == 'delete') {
                  deleteRecord(context, 'consumption', entry['id']);
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'repeat',
                  child: Text(c.tr('Erneut erfassen', 'Log again')),
                ),
                PopupMenuItem(
                  value: 'edit',
                  child: Text(c.tr('Bearbeiten', 'Edit')),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Text(c.tr('Löschen', 'Delete')),
                ),
              ],
            ),
          ),
          Text(
            '${c.fmt(values['calories'])} kcal · ${c.tr('Protein ', 'Protein ')}${c.fmt(values['protein'])} g · ${c.tr('KH ', 'Carbs ')}${c.fmt(values['carbs'])} g · ${c.tr('Fett ', 'Fat ')}${c.fmt(values['fat'])} g',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class FoodPicker extends StatefulWidget {
  final String meal;
  const FoodPicker({super.key, this.meal = 'snack'});
  @override
  State<FoodPicker> createState() => _FoodPickerState();
}

class _FoodPickerState extends State<FoodPicker> {
  final query = TextEditingController();
  bool online = false, barcode = false, busy = false;
  String filter = 'all';
  Json? result;
  String? error;
  int page = 1, generation = 0;
  String lastQuery = '';
  @override
  void dispose() {
    generation++;
    query.dispose();
    super.dispose();
  }

  Future<void> search({int requestedPage = 1}) async {
    final c = AppScope.of(context), q = query.text.trim();
    if (q.isEmpty) {
      setState(
        () => error = c.tr(
          'Gib einen Namen oder Barcode ein.',
          'Enter a name or barcode.',
        ),
      );
      return;
    }
    final g = ++generation;
    setState(() {
      busy = true;
      error = null;
      result = null;
    });
    try {
      final r = barcode
          ? await c.api.lookup(q)
          : await c.api.search(q, requestedPage);
      if (mounted && g == generation) {
        setState(() {
          result = r;
          busy = false;
          page = requestedPage;
          lastQuery = q;
        });
      }
    } catch (e) {
      if (mounted && g == generation) {
        setState(() {
          busy = false;
          error = c.error(e);
        });
      }
    }
  }

  Future<void> favourite(Json food) async {
    final c = AppScope.of(context),
        existing = c.data['foods']
            .where((f) => f['id'] == food['id'])
            .firstOrNull;
    try {
      await c.upsert('foods', {
        ...food,
        'favorite': !(existing?['favorite'] ?? false),
      });
    } catch (e) {
      if (mounted) await notifyError(context, e);
    }
  }

  Widget tile(Json food) {
    final c = AppScope.of(context),
        saved = c.data['foods'].where((f) => f['id'] == food['id']).firstOrNull;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        leading: CircleAvatar(
          backgroundColor: sage,
          child: Icon(
            food['source'] == 'custom'
                ? Icons.edit_note
                : Icons.restaurant_outlined,
            color: ink,
          ),
        ),
        title: Text(
          c.foodName(food),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          "${food['brand'] ?? c.tr('Eigener Eintrag', 'Custom food')} · ${c.fmt(food['nutrients']['calories'])} kcal / 100 ${food['base_unit']}",
        ),
        trailing: IconButton(
          tooltip: c.tr('Favorit umschalten', 'Toggle favourite'),
          icon: Icon(
            saved?['favorite'] == true ? Icons.star : Icons.star_outline,
          ),
          onPressed: () => favourite(food),
        ),
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => FoodDetail(food: saved ?? food, meal: widget.meal),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    final recentIds = c.data['consumption'].reversed
        .map((r) => r['food_id'])
        .toSet()
        .take(40)
        .toSet();
    final local = c.data['foods'].where((f) {
      if (filter == 'favorite' && f['favorite'] != true) return false;
      if (filter == 'custom' && f['source'] != 'custom') return false;
      if (filter == 'recent' && !recentIds.contains(f['id'])) return false;
      final searchable =
          "${c.foodName(f)} ${f['brand'] ?? ''} ${f['barcode'] ?? ''}"
              .toLowerCase();
      return searchable.contains(query.text.toLowerCase().trim());
    }).toList();
    if (filter == 'recent') {
      local.sort(
        (a, b) => recentIds
            .toList()
            .indexOf(a['id'])
            .compareTo(recentIds.toList().indexOf(b['id'])),
      );
    }
    final products = result == null
        ? <Json>[]
        : barcode
        ? (result!['found'] == true ? [result!['product'] as Json] : [])
        : (result!['products'] as List).cast<Json>();
    final enabled = c.data.settings['online_enabled'] == true;
    return Scaffold(
      appBar: AppBar(title: Text(c.tr('Lebensmittel', 'Foods'))),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => editFood(context),
        icon: const Icon(Icons.add),
        label: Text(c.tr('Eigenes Lebensmittel', 'Custom food')),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            SegmentedButton<bool>(
              segments: [
                ButtonSegment(
                  value: false,
                  label: Text(c.tr('Lokal', 'Local')),
                  icon: const Icon(Icons.inventory_2_outlined),
                ),
                ButtonSegment(
                  value: true,
                  label: Text(c.tr('Online suchen', 'Search online')),
                  icon: const Icon(Icons.search),
                ),
              ],
              selected: {online},
              onSelectionChanged: (v) => setState(() {
                online = v.first;
                error = null;
                result = null;
                generation++;
                busy = false;
              }),
            ),
            const SizedBox(height: 18),
            if (online && !enabled)
              Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      c.tr('Open Food Facts', 'Open Food Facts'),
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      c.tr(
                        'Für die Online-Suche werden nur Suchtext oder Barcode an Open Food Facts gesendet. Dein Tagebuch bleibt auf diesem Gerät. Du kannst die Verbindung in den Einstellungen ausschalten.',
                        'Online search sends only your query or barcode to Open Food Facts. Your journal stays on this device. You can turn the connection off in settings.',
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: () async {
                        try {
                          await c.change(
                            (d) => d.settings['online_enabled'] = true,
                          );
                        } catch (e) {
                          if (context.mounted) await notifyError(context, e);
                        }
                      },
                      child: Text(
                        c.tr('Online-Suche aktivieren', 'Enable online search'),
                      ),
                    ),
                  ],
                ),
              ),
            if (!online || enabled) ...[
              if (online)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: SegmentedButton<bool>(
                    segments: [
                      ButtonSegment(
                        value: false,
                        label: Text(c.tr('Name', 'Name')),
                      ),
                      ButtonSegment(
                        value: true,
                        label: Text(c.tr('Barcode-Nummer', 'Barcode number')),
                      ),
                    ],
                    selected: {barcode},
                    onSelectionChanged: (v) => setState(() {
                      barcode = v.first;
                      result = null;
                      error = null;
                    }),
                  ),
                ),
              TextField(
                key: const ValueKey('food-search'),
                controller: query,
                decoration: InputDecoration(
                  labelText: online && barcode
                      ? c.tr('Barcode eingeben', 'Enter barcode')
                      : c.tr('Lebensmittel suchen', 'Search foods'),
                  prefixIcon: Icon(
                    online && barcode ? Icons.numbers : Icons.search,
                  ),
                  suffixIcon: query.text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: c.tr('Leeren', 'Clear'),
                          onPressed: () => setState(() {
                            query.clear();
                            result = null;
                          }),
                          icon: const Icon(Icons.close),
                        ),
                ),
                keyboardType: online && barcode
                    ? TextInputType.number
                    : TextInputType.text,
                textInputAction: TextInputAction.search,
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) {
                  if (online && !busy) search();
                },
              ),
              const SizedBox(height: 12),
              if (online)
                FilledButton(
                  onPressed: busy ? null : () => search(),
                  child: Text(c.tr('Suchen', 'Search')),
                ),
              if (!online)
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final f in ['all', 'favorite', 'recent', 'custom'])
                      ChoiceChip(
                        label: Text(switch (f) {
                          'favorite' => c.tr('Favoriten', 'Favourites'),
                          'recent' => c.tr('Zuletzt verwendet', 'Recent'),
                          'custom' => c.tr('Eigene', 'Custom'),
                          _ => c.tr('Alle', 'All'),
                        }),
                        selected: filter == f,
                        onSelected: (_) => setState(() => filter = f),
                      ),
                  ],
                ),
              const SizedBox(height: 16),
              if (busy)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
              if (error != null)
                Text(
                  error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              if (online && result != null && products.isEmpty)
                EmptyNote(
                  c.tr(
                    'Kein Lebensmittel gefunden. Du kannst es selbst anlegen.',
                    'No food found. You can create a custom food.',
                  ),
                ),
              if (!online && local.isEmpty)
                EmptyNote(
                  c.tr(
                    'Hier erscheinen deine eigenen Lebensmittel, Favoriten und erfassten Produkte. Lege ein Lebensmittel an oder suche online.',
                    'Your custom foods, favourites and logged products appear here. Create a food or search online.',
                  ),
                ),
              for (final f in online ? products : local) tile(f),
              if (online && result != null && !barcode)
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    TextButton(
                      onPressed: page > 1 && !busy
                          ? () => search(requestedPage: page - 1)
                          : null,
                      child: Text(c.tr('Zurück', 'Previous')),
                    ),
                    Text(c.tr('Seite ', 'Page ') + page.toString()),
                    TextButton(
                      onPressed: result!['has_more'] == true && !busy
                          ? () => search(requestedPage: page + 1)
                          : null,
                      child: Text(c.tr('Weiter', 'Next')),
                    ),
                  ],
                ),
            ],
            if (online)
              Padding(
                padding: const EdgeInsets.only(top: 18),
                child: Text(
                  c.tr(
                    'Lebensmitteldaten: Open Food Facts · ODbL 1.0. Angaben können fehlen oder fehlerhaft sein.',
                    'Food data: Open Food Facts · ODbL 1.0. Values may be missing or incorrect.',
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }
}

class FoodDetail extends StatelessWidget {
  final Json food;
  final String meal;
  const FoodDetail({super.key, required this.food, this.meal = 'snack'});
  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context),
        f =
            c.data['foods'].where((v) => v['id'] == food['id']).firstOrNull ??
            food;
    return Scaffold(
      appBar: AppBar(
        title: Text(c.tr('Lebensmittel', 'Food')),
        actions: [
          IconButton(
            tooltip: c.tr('Favorit umschalten', 'Toggle favourite'),
            icon: Icon(f['favorite'] == true ? Icons.star : Icons.star_outline),
            onPressed: () async {
              try {
                await c.upsert('foods', {
                  ...f,
                  'favorite': f['favorite'] != true,
                });
              } catch (e) {
                if (context.mounted) await notifyError(context, e);
              }
            },
          ),
          if (f['source'] == 'custom')
            IconButton(
              tooltip: c.tr('Bearbeiten', 'Edit'),
              onPressed: () async {
                final existed = c.data['foods'].any((v) => v['id'] == f['id']);
                await editFood(context, food: f);
                if (context.mounted &&
                    existed &&
                    !c.data['foods'].any((v) => v['id'] == f['id'])) {
                  Navigator.pop(context);
                }
              },
              icon: const Icon(Icons.edit_outlined),
            ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Heading(c.foodName(f), subtitle: f['brand']),
            FilledButton.icon(
              onPressed: () => editConsumption(context, f, meal: meal),
              icon: const Icon(Icons.add),
              label: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Text(c.tr('Im Tagebuch erfassen', 'Add to diary')),
              ),
            ),
            const SizedBox(height: 20),
            Panel(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    c.tr('Je 100 ', 'Per 100 ') + f['base_unit'],
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (f['serving_size'] != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: Text(
                        "${c.tr('Eine Portion: ', 'One serving: ')}${c.fmt(f['serving_size'])} ${f['base_unit']}",
                      ),
                    ),
                  NutrientTable(values: f['nutrients']),
                ],
              ),
            ),
            if (f['source'] == 'off')
              Text(
                c.tr(
                      'Quelle: Open Food Facts · ODbL 1.0 · Barcode ',
                      'Source: Open Food Facts · ODbL 1.0 · Barcode ',
                    ) +
                    (f['barcode'] ?? ''),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            if ((f['estimated'] as List?)?.isNotEmpty == true)
              Text(
                c.tr(
                      'Geschätzt oder eingeschränkt angegeben: ',
                      'Estimated or qualified values: ',
                    ) +
                    (f['estimated'] as List)
                        .map((id) => nutrientById(id).name(c.language))
                        .join(', '),
              ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
