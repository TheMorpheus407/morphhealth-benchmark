// Tagesdetail: alle Erfassungen eines Tages auf einen Blick, mit
// Schnellzugriff auf die Editoren der einzelnen Bereiche.
library;

import 'package:flutter/material.dart';

import '../core/parse.dart';
import '../cycle/forecast.dart';
import '../data/repository.dart';
import '../l10n/app_strings.dart';
import '../model/cycle.dart';
import '../model/entries.dart';
import '../model/food.dart';
import '../nutrition/day.dart';
import 'cycle_screen.dart';
import 'food_screens.dart';
import 'nutrition_screen.dart';
import 'scope.dart';
import 'symptoms_screen.dart';
import 'weight_screen.dart';
import 'widgets.dart';

class DayDetailScreen extends StatefulWidget {
  final String date; // YYYY-MM-DD

  const DayDetailScreen({super.key, required this.date});

  @override
  State<DayDetailScreen> createState() => _DayDetailScreenState();
}

class _DayDetailScreenState extends State<DayDetailScreen> {
  late DateTime _date;

  @override
  void initState() {
    super.initState();
    _date = parseDate(widget.date) ??
        DateTime.utc(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  }

  String get _dateStr => formatDate(_date);

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = StringsScope.of(context);
    final MorphRepository repo = MorphScope.repoOf(context);
    return Scaffold(
      appBar: AppBar(title: Text(strings.formatDateLong(_date))),
      body: ListenableBuilder(
        listenable: MorphScope.listenableOf(context),
        builder: (BuildContext context, Widget? _) {
          final DayNutrition day = computeDayNutrition(repo.document, _dateStr);
          final List<NutritionEntry> entries =
              repo.nutritionEntriesForDate(_dateStr);
          final List<WaterEntry> water = repo.waterEntriesForDate(_dateStr);
          final List<CaffeineEntry> caffeine =
              repo.caffeineEntriesForDate(_dateStr);
          final WeightEntry? weight = repo.weightEntryOn(_dateStr);
          final PeriodRecord? period =
              repo.periodOn(_dateStr, today: todayString());
          final List<SymptomEntry> symptoms =
              repo.symptomEntriesForDate(_dateStr);
          final CycleForecast forecast =
              computeCycleForecast(repo.document, _dateStr);
          final bool empty = day.entryCount == 0 &&
              water.isEmpty &&
              caffeine.isEmpty &&
              weight == null &&
              period == null &&
              symptoms.isEmpty;
          final DateTime now = DateTime.now();
          return ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: <Widget>[
              DayNavHeader(
                date: _date,
                onDateChanged: (DateTime d) => setState(() => _date = d),
              ),
              TodayChip(
                today: DateTime.utc(now.year, now.month, now.day),
                date: _date,
                onSelected: (DateTime d) => setState(() => _date = d),
              ),
              _quickActions(strings, repo),
              if (empty)
                SectionCard(
                  title: strings.addForDay,
                  child: EmptyState(
                    icon: Icons.article_outlined,
                    text: strings.nothingLogged,
                  ),
                ),
              _nutritionSection(strings, repo, day, entries),
              _waterSection(strings, repo, water),
              _caffeineSection(strings, repo, caffeine),
              _weightSection(strings, repo, weight),
              _cycleSection(strings, repo, period, forecast),
              _symptomsSection(strings, repo, symptoms),
            ],
          );
        },
      ),
    );
  }

  // ------------------------------------------------------------ Aktionen

  Widget _quickActions(AppStrings strings, MorphRepository repo) {
    return SectionCard(
      title: strings.addForDay,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: <Widget>[
          FilledButton.tonalIcon(
            onPressed: () => _pickFood(strings, repo),
            icon: const Icon(Icons.restaurant_outlined),
            label: Text(strings.addEntry),
          ),
          FilledButton.tonalIcon(
            onPressed: () => _addWater(strings, repo),
            icon: const Icon(Icons.water_drop_outlined),
            label: Text(strings.addWater),
          ),
          FilledButton.tonalIcon(
            onPressed: () => _addCaffeine(strings, repo),
            icon: const Icon(Icons.coffee_outlined),
            label: Text(strings.addCaffeine),
          ),
          FilledButton.tonalIcon(
            onPressed: () => _addWeight(strings, repo),
            icon: const Icon(Icons.monitor_weight_outlined),
            label: Text(strings.addWeight),
          ),
          FilledButton.tonalIcon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<Widget>(
                builder: (_) => SymptomEditScreen(initialDate: _dateStr),
              ),
            ),
            icon: const Icon(Icons.healing_outlined),
            label: Text(strings.addSymptom),
          ),
          FilledButton.tonalIcon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<Widget>(
                builder: (_) => PeriodEditScreen(initialDate: _dateStr),
              ),
            ),
            icon: const Icon(Icons.calendar_month_outlined),
            label: Text(strings.addPeriod),
          ),
        ],
      ),
    );
  }

  Future<void> _pickFood(AppStrings strings, MorphRepository repo) async {
    final FoodItem? food = await Navigator.of(context).push<FoodItem>(
      MaterialPageRoute<FoodItem>(
        builder: (_) => const FoodSearchScreen(pickMode: true),
      ),
    );
    if (food == null || !mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute<Widget>(
        builder: (_) => EntryEditScreen(food: food, date: _dateStr),
      ),
    );
  }

  Future<void> _addWater(AppStrings strings, MorphRepository repo) async {
    final WaterInput? input = await showWaterDialog(context, date: _dateStr);
    if (input == null || !mounted) return;
    await repo.addWaterEntry(WaterEntry(
      id: '',
      date: _dateStr,
      time: input.time,
      amountMl: input.amountMl,
      note: input.note,
    ));
    if (mounted) showInfo(context, strings.waterSaved);
  }

  Future<void> _addCaffeine(AppStrings strings, MorphRepository repo) async {
    final CaffeineInput? input =
        await showCaffeineDialog(context, date: _dateStr);
    if (input == null || !mounted) return;
    await repo.addCaffeineEntry(CaffeineEntry(
      id: '',
      date: _dateStr,
      time: input.time,
      amountMg: input.amountMg,
      note: input.note,
    ));
    if (mounted) showInfo(context, strings.caffeineSaved);
  }

  Future<void> _addWeight(AppStrings strings, MorphRepository repo) async {
    final WeightInput? input =
        await showWeightDialog(context, date: _dateStr);
    if (input == null || !mounted) return;
    await repo.addWeightEntry(WeightEntry(
      id: '',
      date: input.date,
      time: input.time,
      weightKg: input.weightKg,
      note: input.note,
    ));
    if (mounted) showInfo(context, strings.weightSaved);
  }

  // ------------------------------------------------------------ Abschnitte

  Widget _nutritionSection(AppStrings strings, MorphRepository repo,
      DayNutrition day, List<NutritionEntry> entries) {
    return SectionCard(
      title:
          '${strings.sectionNutrition} · ${strings.nutrientAmount('energy_kcal', day.totals['energy_kcal'] ?? 0)}',
      child: entries.isEmpty
          ? Text(strings.noEntriesToday,
              style: Theme.of(context).textTheme.bodySmall)
          : Column(
              children: <Widget>[
                for (final NutritionEntry e in entries)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: const Icon(Icons.restaurant_outlined, size: 20),
                    title: Text(e.foodName),
                    subtitle: Text(
                      '${strings.formatNumber(e.quantity, fractionDigits: e.quantity == e.quantity.roundToDouble() ? 0 : 1)} ${strings.quantityUnitName(e.unit)}'
                      '${e.time != null ? ' · ${e.time}' : ''}'
                      '${e.note != null && e.note!.isNotEmpty ? ' · ${e.note}' : ''}',
                    ),
                    trailing: Text(
                      strings.nutrientAmount(
                          'energy_kcal', entryNutrients(e)['energy_kcal'] ?? 0),
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<Widget>(
                        builder: (_) => EntryEditScreen(entry: e),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _waterSection(
      AppStrings strings, MorphRepository repo, List<WaterEntry> entries) {
    final double total =
        entries.fold(0.0, (double a, WaterEntry e) => a + e.amountMl);
    return SectionCard(
      title: '${strings.sectionWater} · ${strings.formatMl(total)}',
      child: entries.isEmpty
          ? Text(strings.noEntriesToday,
              style: Theme.of(context).textTheme.bodySmall)
          : Column(
              children: <Widget>[
                for (final WaterEntry e in entries)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: const Icon(Icons.water_drop_outlined, size: 20),
                    title: Text(strings.formatMl(e.amountMl)),
                    subtitle: Text(
                      '${e.time ?? ''}${e.note != null && e.note!.isNotEmpty ? ' · ${e.note}' : ''}',
                    ),
                    onTap: () => _editWater(strings, repo, e),
                  ),
              ],
            ),
    );
  }

  Widget _caffeineSection(AppStrings strings, MorphRepository repo,
      List<CaffeineEntry> entries) {
    final double total =
        entries.fold(0.0, (double a, CaffeineEntry e) => a + e.amountMg);
    return SectionCard(
      title: '${strings.sectionCaffeine} · ${strings.formatMg(total)}',
      child: entries.isEmpty
          ? Text(strings.noEntriesToday,
              style: Theme.of(context).textTheme.bodySmall)
          : Column(
              children: <Widget>[
                for (final CaffeineEntry e in entries)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: const Icon(Icons.coffee_outlined, size: 20),
                    title: Text(strings.formatMg(e.amountMg)),
                    subtitle: Text(
                      '${e.time ?? ''}${e.note != null && e.note!.isNotEmpty ? ' · ${e.note}' : ''}',
                    ),
                    onTap: () => _editCaffeine(strings, repo, e),
                  ),
              ],
            ),
    );
  }

  Future<void> _editWater(
      AppStrings strings, MorphRepository repo, WaterEntry e) async {
    final WaterInput? input =
        await showWaterDialog(context, date: e.date, initial: e);
    if (input == null || !mounted) return;
    e.amountMl = input.amountMl;
    e.time = input.time;
    e.note = input.note;
    await repo.updateWaterEntry(e);
  }

  Future<void> _editCaffeine(
      AppStrings strings, MorphRepository repo, CaffeineEntry e) async {
    final CaffeineInput? input =
        await showCaffeineDialog(context, date: e.date, initial: e);
    if (input == null || !mounted) return;
    e.amountMg = input.amountMg;
    e.time = input.time;
    e.note = input.note;
    await repo.updateCaffeineEntry(e);
  }

  Widget _weightSection(
      AppStrings strings, MorphRepository repo, WeightEntry? weight) {
    final String unit = repo.settings.weightUnit;
    return SectionCard(
      title: strings.sectionWeight,
      child: weight == null
          ? Text(strings.noEntriesToday,
              style: Theme.of(context).textTheme.bodySmall)
          : ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: const Icon(Icons.monitor_weight_outlined, size: 20),
              title: Text(strings.formatWeight(weight.weightKg, unit)),
              subtitle: Text(
                '${weight.time ?? ''}${weight.note != null && weight.note!.isNotEmpty ? ' · ${weight.note}' : ''}',
              ),
              onTap: () => _editWeight(strings, repo, weight),
            ),
    );
  }

  Future<void> _editWeight(
      AppStrings strings, MorphRepository repo, WeightEntry e) async {
    final WeightInput? input =
        await showWeightDialog(context, date: e.date, initial: e);
    if (input == null || !mounted) return;
    e.date = input.date;
    e.time = input.time;
    e.weightKg = input.weightKg;
    e.note = input.note;
    await repo.updateWeightEntry(e);
    if (mounted) showInfo(context, strings.weightSaved);
  }

  Widget _cycleSection(AppStrings strings, MorphRepository repo,
      PeriodRecord? period, CycleForecast forecast) {
    final List<Widget> rows = <Widget>[];
    if (period != null) {
      rows.add(StatRow(
        label: strings.flowLabel,
        value:
            '${strings.flowName(period.flowOn(_dateStr))} · ${period.start} – ${period.end ?? strings.periodOngoing}',
      ));
    } else if (forecast.currentCycleDay != null) {
      rows.add(StatRow(
        label: strings.cycleDayLabel(forecast.currentCycleDay!),
        value: forecast.lastPeriodStart ?? '',
      ));
    }
    if (forecast.nextPeriodStartEstimate != null) {
      rows.add(StatRow(
        label: strings.nextPeriodLabel,
        value: strings.formatDateShort(
            parseDate(forecast.nextPeriodStartEstimate!)!),
      ));
    }
    if (rows.isEmpty) {
      rows.add(Text(strings.noPeriods,
          style: Theme.of(context).textTheme.bodySmall));
    }
    return SectionCard(
      title: strings.sectionCycle,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          ...rows,
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: <Widget>[
              if (period != null && period.isOngoing)
                FilledButton.tonalIcon(
                  onPressed: () => _endPeriod(strings, repo, period),
                  icon: const Icon(Icons.stop_circle_outlined),
                  label: Text(strings.endPeriodToday),
                )
              else
                FilledButton.tonalIcon(
                  onPressed: () => _startPeriod(strings, repo),
                  icon: const Icon(Icons.play_circle_outline),
                  label: Text(strings.startPeriodToday),
                ),
              if (period != null)
                FilledButton.tonalIcon(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<Widget>(
                      builder: (_) => PeriodEditScreen(period: period),
                    ),
                  ),
                  icon: const Icon(Icons.edit_outlined),
                  label: Text(strings.editPeriod),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _startPeriod(AppStrings strings, MorphRepository repo) async {
    await repo.addPeriod(PeriodRecord(
      id: '',
      start: _dateStr,
      end: null,
      flow: FlowLevel.medium,
    ));
    if (mounted) showInfo(context, strings.periodSaved);
  }

  Future<void> _endPeriod(
      AppStrings strings, MorphRepository repo, PeriodRecord ongoing) async {
    ongoing.end = _dateStr;
    await repo.updatePeriod(ongoing);
    if (mounted) showInfo(context, strings.periodSaved);
  }

  Widget _symptomsSection(
      AppStrings strings, MorphRepository repo, List<SymptomEntry> entries) {
    return SectionCard(
      title: strings.sectionSymptoms,
      child: entries.isEmpty
          ? Text(strings.noEntriesToday,
              style: Theme.of(context).textTheme.bodySmall)
          : Column(
              children: <Widget>[
                for (final SymptomEntry e in entries)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: const Icon(Icons.healing_outlined, size: 20),
                    title: Text(e.name),
                    subtitle: Text(
                      '${strings.intensityValue(e.intensity)}'
                      '${e.time != null ? ' · ${e.time}' : ''}'
                      '${e.note != null && e.note!.isNotEmpty ? ' · ${e.note}' : ''}',
                    ),
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<Widget>(
                        builder: (_) => SymptomEditScreen(entry: e),
                      ),
                    ),
                  ),
              ],
            ),
    );
  }
}
