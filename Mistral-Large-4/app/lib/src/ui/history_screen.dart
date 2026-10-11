// Globale Historie: durchsucht Ernährung, Zyklus, Gewicht und Symptome
// (Freitext, Bereich, Datumsbereich).
library;

import 'package:flutter/material.dart';

import '../core/parse.dart';
import '../data/repository.dart';
import '../l10n/app_strings.dart';
import '../model/cycle.dart';
import '../model/entries.dart';
import '../model/settings.dart';
import 'cycle_screen.dart';
import 'food_screens.dart';
import 'nutrition_screen.dart';
import 'scope.dart';
import 'symptoms_screen.dart';
import 'weight_screen.dart';
import 'widgets.dart';

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  final TextEditingController _queryController = TextEditingController();
  String? _area;
  DateTime? _from;
  DateTime? _to;

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = StringsScope.of(context);
    final MorphRepository repo = MorphScope.repoOf(context);
    return Scaffold(
      appBar: AppBar(title: Text(strings.historyTitle)),
      body: ListenableBuilder(
        listenable: MorphScope.listenableOf(context),
        builder: (BuildContext context, Widget? _) {
          final List<HistoryHit> hits = repo.searchHistory(
            from: _from == null ? null : formatDate(_from!),
            to: _to == null ? null : formatDate(_to!),
            area: _area,
            query: _queryController.text,
          );
          return Column(
            children: <Widget>[
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Column(
                  children: <Widget>[
                    TextField(
                      controller: _queryController,
                      decoration: InputDecoration(
                        hintText: strings.historySearchHint,
                        prefixIcon: const Icon(Icons.search),
                        suffixIcon: _queryController.text.isEmpty
                            ? null
                            : IconButton(
                                tooltip: strings.clearLabel,
                                icon: const Icon(Icons.clear),
                                onPressed: () => setState(
                                    () => _queryController.clear()),
                              ),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: <Widget>[
                        Expanded(
                          child: DropdownButtonFormField<String?>(
                            initialValue: _area,
                            decoration: InputDecoration(
                                labelText: strings.filterAreaLabel),
                            items: <DropdownMenuItem<String?>>[
                              DropdownMenuItem<String?>(
                                value: null,
                                child: Text(strings.filterAll),
                              ),
                              for (final String area in areaKeys)
                                DropdownMenuItem<String?>(
                                  value: area,
                                  child: Text(strings.areaName(area)),
                                ),
                            ],
                            onChanged: (String? v) =>
                                setState(() => _area = v),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: _dateFilter(strings, true)),
                        const SizedBox(width: 8),
                        Expanded(child: _dateFilter(strings, false)),
                      ],
                    ),
                  ],
                ),
              ),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    strings.resultsCount(hits.length),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
              ),
              Expanded(
                child: hits.isEmpty
                    ? EmptyState(
                        icon: Icons.search_off,
                        text: strings.noResults,
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(bottom: 24),
                        itemCount: hits.length,
                        itemBuilder: (BuildContext context, int i) =>
                            _hitTile(strings, repo, hits[i]),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _dateFilter(AppStrings strings, bool isFrom) {
    final DateTime? value = isFrom ? _from : _to;
    return TextField(
      readOnly: true,
      controller: TextEditingController(
        text: value == null
            ? ''
            : strings.formatDateShort(value),
      ),
      decoration: InputDecoration(
        labelText: isFrom ? strings.filterFrom : strings.filterTo,
        suffixIcon: value == null
            ? const Icon(Icons.calendar_today_outlined)
            : IconButton(
                tooltip: strings.clearLabel,
                icon: const Icon(Icons.clear),
                onPressed: () => setState(() {
                  if (isFrom) {
                    _from = null;
                  } else {
                    _to = null;
                  }
                }),
              ),
      ),
      onTap: () async {
        final DateTime now = DateTime.now();
        final DateTime? picked = await pickDate(
          context,
          initial: value ?? DateTime.utc(now.year, now.month, now.day),
        );
        if (picked != null) {
          setState(() {
            if (isFrom) {
              _from = DateTime.utc(picked.year, picked.month, picked.day);
            } else {
              _to = DateTime.utc(picked.year, picked.month, picked.day);
            }
          });
        }
      },
    );
  }

  Widget _hitTile(AppStrings strings, MorphRepository repo, HistoryHit hit) {
    return ListTile(
      leading: Icon(_areaIcon(hit.area)),
      title: Text(_title(strings, hit)),
      subtitle: Text(
        '${strings.formatDateShort(parseDate(hit.date) ?? DateTime.now())}'
        '${hit.time != null ? ' · ${hit.time}' : ''}'
        ' · ${strings.areaName(hit.area)}'
        ' · ${_subtitle(strings, repo, hit)}',
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => _open(strings, repo, hit),
    );
  }

  static IconData _areaIcon(String area) {
    switch (area) {
      case 'nutrition':
        return Icons.restaurant_outlined;
      case 'cycle':
        return Icons.calendar_month_outlined;
      case 'weight':
        return Icons.monitor_weight_outlined;
      case 'symptoms':
        return Icons.healing_outlined;
      default:
        return Icons.article_outlined;
    }
  }

  static String _title(AppStrings strings, HistoryHit hit) {
    switch (hit.kind) {
      case 'water_entry':
        return strings.waterLabel;
      case 'caffeine_entry':
        return strings.caffeineLabel;
      case 'period':
        return strings.sectionCycle;
      case 'weight_entry':
        return strings.weightLabel;
      default:
        return hit.title;
    }
  }

  static String _subtitle(
      AppStrings strings, MorphRepository repo, HistoryHit hit) {
    switch (hit.kind) {
      case 'nutrition_entry':
        final NutritionEntry? e = repo.nutritionEntryById(hit.id);
        if (e == null) return hit.subtitle;
        final String qty = strings.formatNumber(e.quantity,
            fractionDigits: e.quantity == e.quantity.roundToDouble() ? 0 : 1);
        return '${strings.mealName(e.meal)} · $qty ${strings.quantityUnitName(e.unit)}';
      case 'water_entry':
        final WaterEntry? e = _waterById(repo, hit.id);
        return e == null ? hit.subtitle : strings.formatMl(e.amountMl);
      case 'caffeine_entry':
        final CaffeineEntry? e = _caffeineById(repo, hit.id);
        return e == null ? hit.subtitle : strings.formatMg(e.amountMg);
      case 'period':
        final PeriodRecord? p = repo.periodById(hit.id);
        if (p == null) return hit.subtitle;
        return p.end == null
            ? '${strings.periodStartLabel}: ${p.start} (${strings.periodOngoing})'
            : '${p.start} – ${p.end}';
      case 'weight_entry':
        final WeightEntry? e = repo.weightEntryById(hit.id);
        return e == null
            ? hit.subtitle
            : strings.formatWeight(e.weightKg, repo.settings.weightUnit);
      case 'symptom_entry':
        final SymptomEntry? e = repo.symptomEntryById(hit.id);
        return e == null ? hit.subtitle : strings.intensityValue(e.intensity);
      default:
        return hit.subtitle;
    }
  }

  static WaterEntry? _waterById(MorphRepository repo, String id) {
    for (final WaterEntry e in repo.waterEntries) {
      if (e.id == id) return e;
    }
    return null;
  }

  static CaffeineEntry? _caffeineById(MorphRepository repo, String id) {
    for (final CaffeineEntry e in repo.caffeineEntries) {
      if (e.id == id) return e;
    }
    return null;
  }

  // ------------------------------------------------------------- Öffnen

  Future<void> _open(
      AppStrings strings, MorphRepository repo, HistoryHit hit) async {
    switch (hit.kind) {
      case 'nutrition_entry':
        final NutritionEntry? e = repo.nutritionEntryById(hit.id);
        if (e != null && mounted) {
          await Navigator.of(context).push(MaterialPageRoute<Widget>(
            builder: (_) => EntryEditScreen(entry: e),
          ));
        }
        return;
      case 'water_entry':
        final WaterEntry? w = _waterById(repo, hit.id);
        if (w == null || !mounted) return;
        final WaterInput? input =
            await showWaterDialog(context, date: w.date, initial: w);
        if (input == null || !mounted) return;
        w.amountMl = input.amountMl;
        w.time = input.time;
        w.note = input.note;
        await repo.updateWaterEntry(w);
        return;
      case 'caffeine_entry':
        final CaffeineEntry? c = _caffeineById(repo, hit.id);
        if (c == null || !mounted) return;
        final CaffeineInput? input =
            await showCaffeineDialog(context, date: c.date, initial: c);
        if (input == null || !mounted) return;
        c.amountMg = input.amountMg;
        c.time = input.time;
        c.note = input.note;
        await repo.updateCaffeineEntry(c);
        return;
      case 'period':
        final PeriodRecord? p = repo.periodById(hit.id);
        if (p != null && mounted) {
          await Navigator.of(context).push(MaterialPageRoute<Widget>(
            builder: (_) => PeriodEditScreen(period: p),
          ));
        }
        return;
      case 'weight_entry':
        final WeightEntry? we = repo.weightEntryById(hit.id);
        if (we == null || !mounted) return;
        final WeightInput? input =
            await showWeightDialog(context, date: we.date, initial: we);
        if (input == null || !mounted) return;
        we.date = input.date;
        we.time = input.time;
        we.weightKg = input.weightKg;
        we.note = input.note;
        await repo.updateWeightEntry(we);
        if (mounted) showInfo(context, strings.weightSaved);
        return;
      case 'symptom_entry':
        final SymptomEntry? s = repo.symptomEntryById(hit.id);
        if (s != null && mounted) {
          await Navigator.of(context).push(MaterialPageRoute<Widget>(
            builder: (_) => SymptomEditScreen(entry: s),
          ));
        }
        return;
    }
  }
}
