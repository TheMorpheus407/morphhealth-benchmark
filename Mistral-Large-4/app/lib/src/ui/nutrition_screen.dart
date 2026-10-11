// Ernährungstagebuch: Tagesansicht mit Mahlzeiten, Wasser und Koffein.
library;

import 'package:flutter/material.dart';

import '../core/parse.dart';
import '../data/repository.dart';
import '../l10n/app_strings.dart';
import '../model/entries.dart';
import '../nutrition/day.dart';
import 'food_screens.dart';
import 'scope.dart';
import 'widgets.dart';

class NutritionScreen extends StatefulWidget {
  const NutritionScreen({super.key});

  @override
  State<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends State<NutritionScreen> {
  late DateTime _date;

  @override
  void initState() {
    super.initState();
    final DateTime now = DateTime.now();
    _date = DateTime.utc(now.year, now.month, now.day);
  }

  String get _dateStr => formatDate(_date);

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = StringsScope.of(context);
    final MorphRepository repo = MorphScope.repoOf(context);
    return ListenableBuilder(
      listenable: MorphScope.listenableOf(context),
      builder: (BuildContext context, Widget? _) {
        final DayNutrition day = computeDayNutrition(repo.document, _dateStr);
        final List<NutritionEntry> entries =
            repo.nutritionEntriesForDate(_dateStr);
        return ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: <Widget>[
            DayNavHeader(
              date: _date,
              onDateChanged: (DateTime d) => setState(() => _date = d),
            ),
            TodayChip(
              today: DateTime.utc(
                  DateTime.now().year, DateTime.now().month, DateTime.now().day),
              date: _date,
              onSelected: (DateTime d) => setState(() => _date = d),
            ),
            _summaryCard(strings, repo, day),
            _quickActions(strings, repo),
            for (final Meal meal in Meal.values)
              _mealSection(strings, repo, meal, entries),
            _waterSection(strings, repo),
            _caffeineSection(strings, repo),
            _nutrientsExpansion(strings, day),
          ],
        );
      },
    );
  }

  Widget _summaryCard(
      AppStrings strings, MorphRepository repo, DayNutrition day) {
    String goalSuffix(double? percent) =>
        percent == null ? '' : ' · ${strings.percentOfGoal(percent)}';
    return SectionCard(
      title: strings.dayTotal,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          StatRow(
            label: strings.nutrientName('energy_kcal'),
            value:
                '${strings.nutrientAmount('energy_kcal', day.totals['energy_kcal'] ?? 0)}${goalSuffix(day.percentOfGoal('energy_kcal', repo.settings.goals))}',
          ),
          StatRow(
            label: strings.nutrientName('protein_g'),
            value:
                '${strings.nutrientAmount('protein_g', day.totals['protein_g'] ?? 0)}${goalSuffix(day.percentOfGoal('protein_g', repo.settings.goals))}',
          ),
          StatRow(
            label: strings.nutrientName('carbohydrates_g'),
            value:
                '${strings.nutrientAmount('carbohydrates_g', day.totals['carbohydrates_g'] ?? 0)}${goalSuffix(day.percentOfGoal('carbohydrates_g', repo.settings.goals))}',
          ),
          StatRow(
            label: strings.nutrientName('fat_g'),
            value:
                '${strings.nutrientAmount('fat_g', day.totals['fat_g'] ?? 0)}${goalSuffix(day.percentOfGoal('fat_g', repo.settings.goals))}',
          ),
          StatRow(
            label: strings.waterLabel,
            value:
                '${strings.formatMl(day.waterMl)}${goalSuffix(day.waterPercentOfGoal(repo.settings.goals))}',
          ),
          StatRow(
            label: strings.caffeineLabel,
            value: strings.formatMg(day.caffeineTotalMg),
          ),
        ],
      ),
    );
  }

  Widget _quickActions(AppStrings strings, MorphRepository repo) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: <Widget>[
          FilledButton.tonalIcon(
            onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<Widget>(
                    builder: (_) => const FoodSearchScreen())),
            icon: const Icon(Icons.restaurant_outlined),
            label: Text(strings.addEntry),
          ),
          FilledButton.tonalIcon(
            onPressed: () => _addWater(repo),
            icon: const Icon(Icons.water_drop_outlined),
            label: Text(strings.addWater),
          ),
          FilledButton.tonalIcon(
            onPressed: () => _addCaffeine(repo),
            icon: const Icon(Icons.coffee_outlined),
            label: Text(strings.addCaffeine),
          ),
        ],
      ),
    );
  }

  Widget _mealSection(AppStrings strings, MorphRepository repo, Meal meal,
      List<NutritionEntry> entries) {
    final List<NutritionEntry> mealEntries =
        entries.where((NutritionEntry e) => e.meal == meal).toList();
    return SectionCard(
      title: strings.mealName(meal),
      child: mealEntries.isEmpty
          ? Text(strings.diaryEmpty,
              style: Theme.of(context).textTheme.bodySmall)
          : Column(
              children: <Widget>[
                for (final NutritionEntry e in mealEntries)
                  _entryTile(strings, repo, e),
              ],
            ),
    );
  }

  Widget _entryTile(AppStrings strings, MorphRepository repo, NutritionEntry e) {
    final Map<String, double> nutrients = entryNutrients(e);
    final String qty = strings.formatNumber(e.quantity,
        fractionDigits: e.quantity == e.quantity.roundToDouble() ? 0 : 1);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: IconButton(
        tooltip: strings.reLog,
        icon: const Icon(Icons.repeat),
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute<Widget>(
              builder: (_) => EntryEditScreen(reLogFrom: e)),
        ),
      ),
      title: Text(e.foodName),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
              '$qty ${strings.quantityUnitName(e.unit)}'
              '${e.time != null ? ' · ${e.time}' : ''}'
              '${e.note != null && e.note!.isNotEmpty ? ' · ${e.note}' : ''}'),
          Text(
            '${strings.nutrientShort('protein_g')} ${strings.formatNumber(nutrients['protein_g'] ?? 0)} g'
            ' · ${strings.nutrientShort('carbohydrates_g')} ${strings.formatNumber(nutrients['carbohydrates_g'] ?? 0)} g'
            ' · ${strings.nutrientShort('fat_g')} ${strings.formatNumber(nutrients['fat_g'] ?? 0)} g',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
      trailing: Text(
        strings.nutrientAmount('energy_kcal', nutrients['energy_kcal'] ?? 0),
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      onTap: () => Navigator.of(context).push(
        MaterialPageRoute<Widget>(builder: (_) => EntryEditScreen(entry: e)),
      ),
    );
  }

  Widget _waterSection(AppStrings strings, MorphRepository repo) {
    final List<WaterEntry> entries = repo.waterEntriesForDate(_dateStr);
    final double total =
        entries.fold(0.0, (double a, WaterEntry e) => a + e.amountMl);
    return SectionCard(
      title: '${strings.waterLabel} · ${strings.formatMl(total)}',
      trailing: IconButton(
        tooltip: strings.addWater,
        icon: const Icon(Icons.add),
        onPressed: () => _addWater(repo),
      ),
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
                        '${e.time ?? ''}${e.note != null && e.note!.isNotEmpty ? ' · ${e.note}' : ''}'),
                    trailing: IconButton(
                      tooltip: strings.a11yDelete,
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        if (await confirmDelete(context)) {
                          await repo.deleteWaterEntry(e.id);
                        }
                      },
                    ),
                    onTap: () => _editWater(repo, e),
                  ),
              ],
            ),
    );
  }

  Widget _caffeineSection(AppStrings strings, MorphRepository repo) {
    final List<CaffeineEntry> entries = repo.caffeineEntriesForDate(_dateStr);
    final double total =
        entries.fold(0.0, (double a, CaffeineEntry e) => a + e.amountMg);
    return SectionCard(
      title: '${strings.caffeineLabel} · ${strings.formatMg(total)}',
      trailing: IconButton(
        tooltip: strings.addCaffeine,
        icon: const Icon(Icons.add),
        onPressed: () => _addCaffeine(repo),
      ),
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
                        '${e.time ?? ''}${e.note != null && e.note!.isNotEmpty ? ' · ${e.note}' : ''}'),
                    trailing: IconButton(
                      tooltip: strings.a11yDelete,
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        if (await confirmDelete(context)) {
                          await repo.deleteCaffeineEntry(e.id);
                        }
                      },
                    ),
                    onTap: () => _editCaffeine(repo, e),
                  ),
              ],
            ),
    );
  }

  Widget _nutrientsExpansion(AppStrings strings, DayNutrition day) {
    return SectionCard(
      title: strings.allNutrients,
      child: ExpansionTile(
        title: Text(strings.allNutrients),
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: NutrientTable(values: day.totals),
          ),
        ],
      ),
    );
  }

  Future<void> _addWater(MorphRepository repo) async {
    final WaterInput? input = await showWaterDialog(context, date: _dateStr);
    if (input == null || !mounted) return;
    await repo.addWaterEntry(WaterEntry(
      id: '',
      date: _dateStr,
      time: input.time,
      amountMl: input.amountMl,
      note: input.note,
    ));
    if (mounted) showInfo(context, StringsScope.of(context).waterSaved);
  }

  Future<void> _editWater(MorphRepository repo, WaterEntry e) async {
    final WaterInput? input =
        await showWaterDialog(context, date: e.date, initial: e);
    if (input == null || !mounted) return;
    e.amountMl = input.amountMl;
    e.time = input.time;
    e.note = input.note;
    await repo.updateWaterEntry(e);
  }

  Future<void> _addCaffeine(MorphRepository repo) async {
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
    if (mounted) showInfo(context, StringsScope.of(context).caffeineSaved);
  }

  Future<void> _editCaffeine(MorphRepository repo, CaffeineEntry e) async {
    final CaffeineInput? input =
        await showCaffeineDialog(context, date: e.date, initial: e);
    if (input == null || !mounted) return;
    e.amountMg = input.amountMg;
    e.time = input.time;
    e.note = input.note;
    await repo.updateCaffeineEntry(e);
  }
}

/// Eingabewerte des Wasserdialogs.
class WaterInput {
  final double amountMl;
  final String? time;
  final String? note;
  const WaterInput({required this.amountMl, this.time, this.note});
}

/// Eingabewerte des Koffeindialogs.
class CaffeineInput {
  final double amountMg;
  final String? time;
  final String? note;
  const CaffeineInput({required this.amountMg, this.time, this.note});
}

/// Wasserdialog mit Schnellerfassung und eigener Menge.
Future<WaterInput?> showWaterDialog(
  BuildContext context, {
  required String date,
  WaterEntry? initial,
}) async {
  final AppStrings strings = StringsScope.of(context);
  return showDialog<WaterInput>(
    context: context,
    builder: (BuildContext context) => _AmountDialog<WaterInput>(
      strings: strings,
      title: strings.addWater,
      quickAmounts: const <double>[200, 250, 330, 500],
      initialAmount: initial?.amountMl,
      format: strings.formatMl,
      toInput: (double amount, String? time, String? note) =>
          WaterInput(amountMl: amount, time: time, note: note),
    ),
  );
}

/// Koffeindialog mit Schnellerfassung und eigener Menge.
Future<CaffeineInput?> showCaffeineDialog(
  BuildContext context, {
  required String date,
  CaffeineEntry? initial,
}) async {
  final AppStrings strings = StringsScope.of(context);
  return showDialog<CaffeineInput>(
    context: context,
    builder: (BuildContext context) => _AmountDialog<CaffeineInput>(
      strings: strings,
      title: strings.addCaffeine,
      quickAmounts: const <double>[40, 80, 120],
      initialAmount: initial?.amountMg,
      format: strings.formatMg,
      toInput: (double amount, String? time, String? note) =>
          CaffeineInput(amountMg: amount, time: time, note: note),
    ),
  );
}

/// Allgemeiner Mengendialog (Schnellbeträge + eigener Wert + Notiz).
///
/// Die Texte werden aus dem aufrufenden Kontext übergeben: Dialog-Routen
/// liegen auf dem Root-Navigator und damit über den Scopes.
class _AmountDialog<T> extends StatefulWidget {
  final AppStrings strings;
  final String title;
  final List<double> quickAmounts;
  final double? initialAmount;
  final String Function(double) format;
  final T Function(double amount, String? time, String? note) toInput;

  const _AmountDialog({
    required this.strings,
    required this.title,
    required this.quickAmounts,
    required this.initialAmount,
    required this.format,
    required this.toInput,
  });

  @override
  State<_AmountDialog<T>> createState() => _AmountDialogState<T>();
}

class _AmountDialogState<T> extends State<_AmountDialog<T>> {
  late final TextEditingController _amountController;
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController(
        text: widget.initialAmount == null
            ? ''
            : widget.initialAmount!.toStringAsFixed(0));
    _noteController = TextEditingController();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = widget.strings;
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(strings.quickWaterTitle,
                style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 4),
            AmountChips(
              amounts: widget.quickAmounts,
              format: widget.format,
              onSelected: (double a) {
                setState(() {
                  _amountController.text = a.toStringAsFixed(0);
                });
              },
            ),
            const SizedBox(height: 8),
            NumberField(
              controller: _amountController,
              label: strings.customAmountLabel,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _noteController,
              decoration: InputDecoration(
                  labelText: strings.noteLabel,
                  hintText: strings.optionalLabel),
            ),
          ],
        ),
      ),
      actions: <Widget>[
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(strings.cancel),
        ),
        FilledButton(
          onPressed: () {
            final double? amount =
                NumberField.parse(strings, _amountController.text);
            if (amount == null || amount <= 0) {
              showError(context, strings.invalidNumber);
              return;
            }
            final String? note = _noteController.text.trim().isEmpty
                ? null
                : _noteController.text.trim();
            Navigator.of(context).pop(widget.toInput(
                amount, formatTimeOfDay(DateTime.now()), note));
          },
          child: Text(strings.save),
        ),
      ],
    );
  }
}
