import 'package:flutter/material.dart';
import '../../core/models.dart';
import '../../core/nutrients.dart';
import '../app_state.dart';

Future<void> showAddFoodCatalogSheet(
  BuildContext context,
  MorphHealthController ctrl, {
  String? initialMeal,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => _FoodCatalogSheet(
      ctrl: ctrl,
      initialMeal: initialMeal ?? MealType.breakfast,
    ),
  );
}

class _FoodCatalogSheet extends StatefulWidget {
  final MorphHealthController ctrl;
  final String initialMeal;

  const _FoodCatalogSheet({
    required this.ctrl,
    required this.initialMeal,
  });

  @override
  State<_FoodCatalogSheet> createState() => _FoodCatalogSheetState();
}

class _FoodCatalogSheetState extends State<_FoodCatalogSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _barcodeCtrl = TextEditingController();
  final TextEditingController _localFilterCtrl = TextEditingController();

  bool _isSearching = false;
  String? _searchError;
  List<FoodItem> _searchResults = [];
  int _currentPage = 1;
  int _totalCount = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    _barcodeCtrl.dispose();
    _localFilterCtrl.dispose();
    super.dispose();
  }

  Future<void> _runOffSearch({int page = 1}) async {
    final q = _searchCtrl.text.trim();
    if (q.isEmpty) return;
    if (!widget.ctrl.settings.onlineFoodSearchEnabled) {
      setState(() {
        _searchError = widget.ctrl.s.t(
          'Online-Lebensmittelsuche ist in den Einstellungen deaktiviert.',
          'Online food search is disabled in Settings.',
        );
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _searchError = null;
    });

    try {
      final res = await widget.ctrl.offClient.search(query: q, page: page);
      if (!mounted) return;
      setState(() {
        _currentPage = res.page;
        _totalCount = res.totalCount;
        _searchResults = res.products
            .map(
              (p) => p.copyWith(
                isFavorite: widget.ctrl.repository
                    .isFoodFavorite(p.id, barcode: p.barcode),
              ),
            )
            .toList();
        _isSearching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSearching = false;
        _searchError = e.toString();
      });
    }
  }

  Future<void> _runBarcodeLookup() async {
    final code = _barcodeCtrl.text.trim();
    if (code.isEmpty) return;
    if (!widget.ctrl.settings.onlineFoodSearchEnabled) {
      setState(() {
        _searchError = widget.ctrl.s.t(
          'Online-Lebensmittelsuche ist in den Einstellungen deaktiviert.',
          'Online food search is disabled in Settings.',
        );
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _searchError = null;
    });

    try {
      final item = await widget.ctrl.offClient.lookupBarcode(code);
      if (!mounted) return;
      final enriched = item.copyWith(
        isFavorite: widget.ctrl.repository
            .isFoodFavorite(item.id, barcode: item.barcode),
      );
      setState(() {
        _isSearching = false;
        _searchResults = [enriched];
        _totalCount = 1;
        _currentPage = 1;
      });
      await showFoodEntryEditorSheet(
        context,
        widget.ctrl,
        food: enriched,
        initialMeal: widget.initialMeal,
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSearching = false;
        _searchError = e.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.ctrl.s;
    return ListenableBuilder(
      listenable: widget.ctrl,
      builder: (context, _) {
        return Scaffold(
          appBar: AppBar(
            title: Text(s.addFood),
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).pop(),
            ),
            bottom: TabBar(
              controller: _tabController,
              isScrollable: true,
              tabs: [
                Tab(
                  icon: const Icon(Icons.public, size: 18),
                  text: s.offSearch,
                ),
                Tab(
                  icon: const Icon(Icons.history, size: 18),
                  text: s.recentEntries,
                ),
                Tab(
                  icon: const Icon(Icons.star_outline, size: 18),
                  text: s.favorites,
                ),
                Tab(
                  icon: const Icon(Icons.restaurant_menu, size: 18),
                  text: s.customFood,
                ),
              ],
            ),
          ),
          body: TabBarView(
            controller: _tabController,
            children: [
              _buildOffTab(context),
              _buildRecentTab(context),
              _buildFavoritesTab(context),
              _buildCustomFoodsTab(context),
            ],
          ),
        );
      },
    );
  }

  Widget _buildOffTab(BuildContext context) {
    final s = widget.ctrl.s;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _searchCtrl,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _runOffSearch(page: 1),
                  decoration: InputDecoration(
                    labelText: s.searchFoodHint,
                    prefixIcon: const Icon(Icons.search),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _isSearching ? null : () => _runOffSearch(page: 1),
                child: Text(s.search),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _barcodeCtrl,
                  keyboardType: TextInputType.number,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _runBarcodeLookup(),
                  decoration: InputDecoration(
                    labelText: s.enterBarcode,
                    prefixIcon: const Icon(Icons.qr_code),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: _isSearching ? null : _runBarcodeLookup,
                child: Text(s.barcodeLookup),
              ),
            ],
          ),
        ),
        if (_isSearching) const LinearProgressIndicator(),
        if (_searchError != null)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              _searchError!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        Expanded(
          child: _searchResults.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      s.t(
                        'Suche nach einem Lebensmittelnamen (z. B. „Haferflocken“, „Milch“, „Apfel“) oder gib eine Barcode-Nummer ein, um Produktdaten aus Open Food Facts abzurufen.',
                        'Search by food name (e.g. "Oats", "Milk", "Apple") or enter a barcode number to fetch product data from Open Food Facts.',
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 4,
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            s.t(
                              '$_totalCount Treffer (Seite $_currentPage)',
                              '$_totalCount results (Page $_currentPage)',
                            ),
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          Row(
                            children: [
                              if (_currentPage > 1)
                                TextButton(
                                  onPressed: _isSearching
                                      ? null
                                      : () => _runOffSearch(
                                            page: _currentPage - 1,
                                          ),
                                  child: Text(s.t('Zurück', 'Prev')),
                                ),
                              if (_searchResults.length >= 20)
                                TextButton(
                                  onPressed: _isSearching
                                      ? null
                                      : () => _runOffSearch(
                                            page: _currentPage + 1,
                                          ),
                                  child: Text(s.t('Weiter', 'Next')),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.separated(
                        itemCount: _searchResults.length,
                        separatorBuilder: (_, _) => const Divider(height: 1),
                        itemBuilder: (ctx, i) {
                          final item = _searchResults[i];
                          final isFav = widget.ctrl.repository
                              .isFoodFavorite(item.id, barcode: item.barcode);
                          final n = item.nutrientsPer100g;
                          return ListTile(
                            title: Text(item.displayName(widget.ctrl.lang)),
                            subtitle: Text(
                              '${item.brand != null ? '${item.brand} · ' : ''}'
                              '100 ${item.defaultUnit}: ${n.caloriesKcal.round()} kcal · '
                              'P ${n.proteinG.toStringAsFixed(1)}g · '
                              'KH ${n.carbohydratesG.toStringAsFixed(1)}g · '
                              'F ${n.fatG.toStringAsFixed(1)}g',
                            ),
                            trailing: IconButton(
                              tooltip: s.favorites,
                              icon: Icon(
                                isFav ? Icons.star : Icons.star_border,
                                color: isFav ? Colors.amber.shade700 : null,
                              ),
                              onPressed: () {
                                widget.ctrl.toggleFavoriteFood(item);
                              },
                            ),
                            onTap: () async {
                              await showFoodEntryEditorSheet(
                                context,
                                widget.ctrl,
                                food: item,
                                initialMeal: widget.initialMeal,
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
        ),
      ],
    );
  }

  Widget _buildRecentTab(BuildContext context) {
    final s = widget.ctrl.s;
    final recents = widget.ctrl.repository.getRecentFoodEntries(limit: 30);
    if (recents.isEmpty) {
      return Center(
        child: Text(
          s.t(
            'Noch keine protokollierten Verzehreinträge vorhanden.',
            'No logged food entries yet.',
          ),
        ),
      );
    }
    return ListView.separated(
      itemCount: recents.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (ctx, i) {
        final entry = recents[i];
        final kcal = entry.nutrients.caloriesKcal.round();
        return ListTile(
          title: Text(entry.food.displayName(widget.ctrl.lang)),
          subtitle: Text(
            '${entry.amount.toStringAsFixed(entry.amount == entry.amount.roundToDouble() ? 0 : 1)} '
            '${FoodUnit.label(entry.unit, widget.ctrl.lang)} · '
            '${MealType.label(entry.meal, widget.ctrl.lang)} · $kcal kcal',
          ),
          trailing: FilledButton.tonalIcon(
            icon: const Icon(Icons.replay, size: 18),
            label: Text(s.logAgain),
            onPressed: () async {
              await widget.ctrl.relogFoodEntry(
                entry,
                targetDate: widget.ctrl.selectedDate,
                targetMeal: widget.initialMeal,
              );
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      s.t(
                        '„${entry.food.displayName(widget.ctrl.lang)}“ erneut erfasst.',
                        'Logged "${entry.food.displayName(widget.ctrl.lang)}" again.',
                      ),
                    ),
                  ),
                );
                Navigator.of(context).pop();
              }
            },
          ),
          onTap: () async {
            await showFoodEntryEditorSheet(
              context,
              widget.ctrl,
              food: entry.food,
              initialMeal: widget.initialMeal,
              initialAmount: entry.amount,
              initialUnit: entry.unit,
            );
          },
        );
      },
    );
  }

  Widget _buildFavoritesTab(BuildContext context) {
    final s = widget.ctrl.s;
    final favs = widget.ctrl.repository.favoriteFoods;
    if (favs.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            s.t(
              'Markiere Lebensmittel mit dem Stern-Symbol als Favoriten, um sie hier schnell auszuwählen.',
              'Star foods to save them as favorites for quick access here.',
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView.separated(
      itemCount: favs.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (ctx, i) {
        final item = favs[i];
        final n = item.nutrientsPer100g;
        return ListTile(
          leading: Icon(Icons.star, color: Colors.amber.shade700),
          title: Text(item.displayName(widget.ctrl.lang)),
          subtitle: Text(
            '100 ${item.defaultUnit}: ${n.caloriesKcal.round()} kcal · '
            'P ${n.proteinG.toStringAsFixed(1)}g · '
            'KH ${n.carbohydratesG.toStringAsFixed(1)}g · '
            'F ${n.fatG.toStringAsFixed(1)}g',
          ),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => widget.ctrl.toggleFavoriteFood(item),
          ),
          onTap: () async {
            await showFoodEntryEditorSheet(
              context,
              widget.ctrl,
              food: item,
              initialMeal: widget.initialMeal,
            );
          },
        );
      },
    );
  }

  Widget _buildCustomFoodsTab(BuildContext context) {
    final s = widget.ctrl.s;
    final customs = widget.ctrl.repository.customFoods;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: const Icon(Icons.add),
              label: Text(s.createCustomFood),
              onPressed: () async {
                await showCustomFoodEditorSheet(context, widget.ctrl);
              },
            ),
          ),
        ),
        Expanded(
          child: customs.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      s.t(
                        'Noch keine eigenen Lebensmittel angelegt. Du kannst eigene Lebensmittel inklusive aller Makro- und Mikronährstoffe erstellen und jederzeit bearbeiten.',
                        'No custom foods created yet. You can create custom foods with all macro- and micronutrients and edit them anytime.',
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.separated(
                  itemCount: customs.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (ctx, i) {
                    final item = customs[i];
                    final n = item.nutrientsPer100g;
                    return ListTile(
                      title: Text(item.displayName(widget.ctrl.lang)),
                      subtitle: Text(
                        '${item.brand != null ? '${item.brand} · ' : ''}'
                        '100 ${item.defaultUnit}: ${n.caloriesKcal.round()} kcal · '
                        '1 Portion = ${item.servingQuantityG.toStringAsFixed(0)}${item.defaultUnit}',
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: s.edit,
                            icon: const Icon(Icons.edit_outlined),
                            onPressed: () async {
                              await showCustomFoodEditorSheet(
                                context,
                                widget.ctrl,
                                existing: item,
                              );
                            },
                          ),
                          IconButton(
                            tooltip: s.delete,
                            icon: const Icon(Icons.delete_outline),
                            onPressed: () =>
                                widget.ctrl.deleteCustomFood(item.id),
                          ),
                        ],
                      ),
                      onTap: () async {
                        await showFoodEntryEditorSheet(
                          context,
                          widget.ctrl,
                          food: item,
                          initialMeal: widget.initialMeal,
                        );
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}

Future<void> showFoodEntryEditorSheet(
  BuildContext context,
  MorphHealthController ctrl, {
  FoodItem? food,
  FoodDiaryEntry? existingEntry,
  String? initialMeal,
  double? initialAmount,
  String? initialUnit,
}) async {
  final targetFood = existingEntry?.food ?? food!;
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => _FoodEntryEditorSheet(
      ctrl: ctrl,
      food: targetFood,
      existingEntry: existingEntry,
      initialMeal: existingEntry?.meal ?? initialMeal ?? MealType.breakfast,
      initialAmount: existingEntry?.amount ?? initialAmount ?? 100.0,
      initialUnit:
          existingEntry?.unit ?? initialUnit ?? targetFood.defaultUnit,
    ),
  );
}

class _FoodEntryEditorSheet extends StatefulWidget {
  final MorphHealthController ctrl;
  final FoodItem food;
  final FoodDiaryEntry? existingEntry;
  final String initialMeal;
  final double initialAmount;
  final String initialUnit;

  const _FoodEntryEditorSheet({
    required this.ctrl,
    required this.food,
    this.existingEntry,
    required this.initialMeal,
    required this.initialAmount,
    required this.initialUnit,
  });

  @override
  State<_FoodEntryEditorSheet> createState() => _FoodEntryEditorSheetState();
}

class _FoodEntryEditorSheetState extends State<_FoodEntryEditorSheet> {
  late TextEditingController _amountCtrl;
  late TextEditingController _servingWeightCtrl;
  late TextEditingController _dateCtrl;
  late TextEditingController _timeCtrl;
  late TextEditingController _notesCtrl;
  late String _unit;
  late String _meal;
  bool _showAllNutrients = false;

  @override
  void initState() {
    super.initState();
    _unit = FoodUnit.normalize(widget.initialUnit);
    _meal = MealType.normalize(widget.initialMeal);
    _amountCtrl = TextEditingController(
      text: widget.initialAmount == widget.initialAmount.roundToDouble()
          ? widget.initialAmount.toInt().toString()
          : widget.initialAmount.toString(),
    );
    final srv =
        widget.existingEntry?.servingQuantityG ?? widget.food.servingQuantityG;
    _servingWeightCtrl = TextEditingController(
      text: srv.toStringAsFixed(srv == srv.roundToDouble() ? 0 : 1),
    );
    _dateCtrl = TextEditingController(
      text: widget.existingEntry?.date ?? widget.ctrl.selectedDate,
    );
    final ts = widget.existingEntry?.timestamp ?? widget.ctrl.repository.nowIso;
    final hhmm = ts.length >= 16 ? ts.substring(11, 16) : '12:00';
    _timeCtrl = TextEditingController(text: hhmm);
    _notesCtrl =
        TextEditingController(text: widget.existingEntry?.notes ?? '');
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _servingWeightCtrl.dispose();
    _dateCtrl.dispose();
    _timeCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  double get _parsedAmount {
    final v =
        double.tryParse(_amountCtrl.text.trim().replaceAll(',', '.')) ?? 0.0;
    return v > 0 ? v : 0.0;
  }

  double get _parsedServingWeight {
    final v =
        double.tryParse(_servingWeightCtrl.text.trim().replaceAll(',', '.')) ??
            widget.food.servingQuantityG;
    return v > 0 ? v : 100.0;
  }

  NutrientProfile get _previewNutrients => widget.food.nutrientsForQuantity(
        _parsedAmount,
        _unit,
        customServingQuantityG: _parsedServingWeight,
      );

  Future<void> _save() async {
    final amount = _parsedAmount;
    if (amount <= 0) return;
    final date = _dateCtrl.text.trim();
    final time = _timeCtrl.text.trim();
    final ts = '${date}T${time.length == 5 ? time : '12:00'}:00Z';

    final entry = FoodDiaryEntry(
      id: widget.existingEntry?.id ?? widget.ctrl.repository.generateId('fe'),
      date: date,
      timestamp: ts,
      meal: _meal,
      food: widget.food,
      amount: amount,
      unit: _unit,
      servingQuantityG: _parsedServingWeight,
      notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
    );

    await widget.ctrl.saveFoodEntry(entry);
    if (mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.ctrl.s;
    final lang = widget.ctrl.lang;
    final n = _previewNutrients;
    final isFav = widget.ctrl.repository
        .isFoodFavorite(widget.food.id, barcode: widget.food.barcode);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.food.displayName(lang)),
        actions: [
          IconButton(
            tooltip: s.favorites,
            icon: Icon(
              isFav ? Icons.star : Icons.star_border,
              color: isFav ? Colors.amber.shade700 : null,
            ),
            onPressed: () {
              widget.ctrl.toggleFavoriteFood(widget.food);
              setState(() {});
            },
          ),
          if (widget.existingEntry != null)
            IconButton(
              tooltip: s.delete,
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                await widget.ctrl.deleteFoodEntry(widget.existingEntry!.id);
                if (context.mounted) Navigator.of(context).pop();
              },
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (widget.food.brand != null || widget.food.barcode != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(
                [
                  if (widget.food.brand != null) widget.food.brand!,
                  if (widget.food.barcode != null)
                    'Barcode: ${widget.food.barcode}',
                ].join(' · '),
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),

          // Amount & Unit row (g, ml, portion)
          Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _amountCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: s.t('Menge', 'Amount'),
                    border: const OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 3,
                child: SegmentedButton<String>(
                  segments: [
                    const ButtonSegment(
                      value: FoodUnit.gram,
                      label: Text('g'),
                    ),
                    const ButtonSegment(
                      value: FoodUnit.milliliter,
                      label: Text('ml'),
                    ),
                    ButtonSegment(
                      value: FoodUnit.portion,
                      label: Text(s.t('Portion', 'Portion')),
                    ),
                  ],
                  selected: {_unit},
                  onSelectionChanged: (sel) {
                    setState(() {
                      final nextUnit = sel.first;
                      if (nextUnit == FoodUnit.portion &&
                          _unit != FoodUnit.portion &&
                          _parsedAmount >= 25) {
                        _amountCtrl.text = '1';
                      } else if (nextUnit != FoodUnit.portion &&
                          _unit == FoodUnit.portion &&
                          _parsedAmount <= 5) {
                        _amountCtrl.text =
                            _parsedServingWeight.toStringAsFixed(0);
                      }
                      _unit = nextUnit;
                    });
                  },
                ),
              ),
            ],
          ),

          if (_unit == FoodUnit.portion) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _servingWeightCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                labelText: s.t(
                  'Gewicht/Volumen pro 1 Portion (${widget.food.defaultUnit})',
                  'Weight/Volume per 1 Portion (${widget.food.defaultUnit})',
                ),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],

          const SizedBox(height: 12),
          // Meal selection
          DropdownButtonFormField<String>(
            initialValue: _meal,
            decoration: InputDecoration(
              labelText: s.t('Mahlzeit', 'Meal'),
              border: const OutlineInputBorder(),
            ),
            items: [
              for (final m in MealType.all)
                DropdownMenuItem(
                  value: m,
                  child: Text(MealType.label(m, lang)),
                ),
            ],
            onChanged: (v) {
              if (v != null) setState(() => _meal = v);
            },
          ),

          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _dateCtrl,
                  decoration: InputDecoration(
                    labelText: '${s.date} (YYYY-MM-DD)',
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _timeCtrl,
                  decoration: InputDecoration(
                    labelText: '${s.time} (HH:MM)',
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),
          TextField(
            controller: _notesCtrl,
            decoration: InputDecoration(
              labelText: s.notes,
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),

          const SizedBox(height: 16),
          // Main Macros Summary Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.t(
                      'Nährwerte für gewählte Menge',
                      'Nutrients for selected amount',
                    ),
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _MacroPill(
                        label: s.t('Kalorien', 'Calories'),
                        value: '${n.caloriesKcal.round()} kcal',
                      ),
                      _MacroPill(
                        label: 'Protein',
                        value: '${n.proteinG.toStringAsFixed(1)} g',
                      ),
                      _MacroPill(
                        label: s.t('Kohlenhydrate', 'Carbs'),
                        value: '${n.carbohydratesG.toStringAsFixed(1)} g',
                      ),
                      _MacroPill(
                        label: s.t('Fett', 'Fat'),
                        value: '${n.fatG.toStringAsFixed(1)} g',
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      icon: Icon(
                        _showAllNutrients
                            ? Icons.expand_less
                            : Icons.expand_more,
                      ),
                      label: Text(
                        _showAllNutrients
                            ? s.t(
                                'Mikronährstoffe ausblenden',
                                'Hide Micronutrients',
                              )
                            : s.t(
                                'Alle 31 Nährstoffe & Mikronährstoffe anzeigen',
                                'Show All 31 Nutrients & Micronutrients',
                              ),
                      ),
                      onPressed: () =>
                          setState(() => _showAllNutrients = !_showAllNutrients),
                    ),
                  ),
                  if (_showAllNutrients) ...[
                    const Divider(),
                    _NutrientCategoryTable(
                      title: s.extendedNutrients,
                      metas: NutrientCatalog.byCategory(
                        NutrientCategory.extended,
                      ),
                      profile: n,
                      lang: lang,
                    ),
                    const SizedBox(height: 8),
                    _NutrientCategoryTable(
                      title: s.vitamins,
                      metas:
                          NutrientCatalog.byCategory(NutrientCategory.vitamin),
                      profile: n,
                      lang: lang,
                    ),
                    const SizedBox(height: 8),
                    _NutrientCategoryTable(
                      title: s.minerals,
                      metas:
                          NutrientCatalog.byCategory(NutrientCategory.mineral),
                      profile: n,
                      lang: lang,
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            icon: const Icon(Icons.check),
            label: Text(s.save),
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}

class _MacroPill extends StatelessWidget {
  final String label;
  final String value;

  const _MacroPill({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class _NutrientCategoryTable extends StatelessWidget {
  final String title;
  final List<NutrientMeta> metas;
  final NutrientProfile profile;
  final String lang;

  const _NutrientCategoryTable({
    required this.title,
    required this.metas,
    required this.profile,
    required this.lang,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 4),
        for (final m in metas)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(m.label(lang), style: const TextStyle(fontSize: 13)),
                Text(
                  '${profile[m.key].toStringAsFixed(m.decimals)} ${m.unit}',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

Future<FoodItem?> showCustomFoodEditorSheet(
  BuildContext context,
  MorphHealthController ctrl, {
  FoodItem? existing,
}) async {
  return showModalBottomSheet<FoodItem>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => _CustomFoodEditorSheet(ctrl: ctrl, existing: existing),
  );
}

class _CustomFoodEditorSheet extends StatefulWidget {
  final MorphHealthController ctrl;
  final FoodItem? existing;

  const _CustomFoodEditorSheet({
    required this.ctrl,
    this.existing,
  });

  @override
  State<_CustomFoodEditorSheet> createState() => _CustomFoodEditorSheetState();
}

class _CustomFoodEditorSheetState extends State<_CustomFoodEditorSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _brandCtrl;
  late final TextEditingController _barcodeCtrl;
  late final TextEditingController _servingQtyCtrl;
  late String _defaultUnit;
  late bool _isFavorite;
  final Map<String, TextEditingController> _nutrientCtrls = {};

  @override
  void initState() {
    super.initState();
    final ex = widget.existing;
    _nameCtrl = TextEditingController(text: ex?.name ?? '');
    _brandCtrl = TextEditingController(text: ex?.brand ?? '');
    _barcodeCtrl = TextEditingController(text: ex?.barcode ?? '');
    _servingQtyCtrl = TextEditingController(
      text: (ex?.servingQuantityG ?? 100.0).toStringAsFixed(0),
    );
    _defaultUnit = ex?.defaultUnit ?? FoodUnit.gram;
    _isFavorite = ex?.isFavorite ?? false;

    for (final m in NutrientCatalog.all) {
      final v = ex?.nutrientsPer100g[m.key] ?? 0.0;
      _nutrientCtrls[m.key] = TextEditingController(
        text: v > 0 ? v.toString() : '0',
      );
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _brandCtrl.dispose();
    _barcodeCtrl.dispose();
    _servingQtyCtrl.dispose();
    for (final c in _nutrientCtrls.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) return;

    final map = <String, double>{};
    for (final m in NutrientCatalog.all) {
      final raw = _nutrientCtrls[m.key]?.text.trim().replaceAll(',', '.') ?? '0';
      map[m.key] = double.tryParse(raw) ?? 0.0;
    }

    final srv = double.tryParse(
          _servingQtyCtrl.text.trim().replaceAll(',', '.'),
        ) ??
        100.0;

    final item = FoodItem(
      id: widget.existing?.id ?? widget.ctrl.repository.generateId('custom'),
      barcode: _barcodeCtrl.text.trim().isEmpty
          ? null
          : _barcodeCtrl.text.trim(),
      name: name,
      nameDe: name,
      nameEn: name,
      brand: _brandCtrl.text.trim().isEmpty ? null : _brandCtrl.text.trim(),
      isCustom: true,
      isFavorite: _isFavorite,
      defaultUnit: _defaultUnit,
      servingSizeLabel: '${srv.toStringAsFixed(0)} $_defaultUnit',
      servingQuantityG: srv > 0 ? srv : 100.0,
      nutrientsPer100g: NutrientProfile(map),
      updatedAt: widget.ctrl.repository.nowIso,
    );

    final saved = await widget.ctrl.saveCustomFood(item);
    if (mounted) {
      Navigator.of(context).pop(saved);
    }
  }

  Widget _buildNutrientInputs(List<NutrientMeta> metas, String lang) {
    return Column(
      children: [
        for (int i = 0; i < metas.length; i += 2)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _nutrientCtrls[metas[i].key],
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText:
                          '${metas[i].label(lang)} (${metas[i].unit})',
                      border: const OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                if (i + 1 < metas.length)
                  Expanded(
                    child: TextField(
                      controller: _nutrientCtrls[metas[i + 1].key],
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText:
                            '${metas[i + 1].label(lang)} (${metas[i + 1].unit})',
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  )
                else
                  const Expanded(child: SizedBox.shrink()),
              ],
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.ctrl.s;
    final lang = widget.ctrl.lang;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.existing == null ? s.createCustomFood : s.editCustomFood,
        ),
        actions: [
          IconButton(
            icon: Icon(
              _isFavorite ? Icons.star : Icons.star_border,
              color: _isFavorite ? Colors.amber.shade700 : null,
            ),
            onPressed: () => setState(() => _isFavorite = !_isFavorite),
          ),
          TextButton(
            onPressed: _save,
            child: Text(s.save),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _nameCtrl,
            decoration: InputDecoration(
              labelText: s.t('Bezeichnung *', 'Food Name *'),
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _brandCtrl,
                  decoration: InputDecoration(
                    labelText: s.t('Marke (optional)', 'Brand (optional)'),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _barcodeCtrl,
                  decoration: InputDecoration(
                    labelText: 'Barcode (optional)',
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _defaultUnit,
                  decoration: InputDecoration(
                    labelText: s.t('Bezugseinheit (pro 100)', 'Base Unit (per 100)'),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                  items: const [
                    DropdownMenuItem(value: FoodUnit.gram, child: Text('100 g')),
                    DropdownMenuItem(
                      value: FoodUnit.milliliter,
                      child: Text('100 ml'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _defaultUnit = v);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextField(
                  controller: _servingQtyCtrl,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText:
                        s.t('1 Portion in $_defaultUnit', '1 Portion in $_defaultUnit'),
                    border: const OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            '${s.mainMacros} (pro 100 $_defaultUnit)',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 10),
          _buildNutrientInputs(
            NutrientCatalog.byCategory(NutrientCategory.macro),
            lang,
          ),
          const SizedBox(height: 12),
          Text(
            '${s.extendedNutrients} (pro 100 $_defaultUnit)',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 10),
          _buildNutrientInputs(
            NutrientCatalog.byCategory(NutrientCategory.extended),
            lang,
          ),
          const SizedBox(height: 12),
          Text(
            '${s.vitamins} (pro 100 $_defaultUnit)',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 10),
          _buildNutrientInputs(
            NutrientCatalog.byCategory(NutrientCategory.vitamin),
            lang,
          ),
          const SizedBox(height: 12),
          Text(
            '${s.minerals} (pro 100 $_defaultUnit)',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 10),
          _buildNutrientInputs(
            NutrientCatalog.byCategory(NutrientCategory.mineral),
            lang,
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            icon: const Icon(Icons.save),
            label: Text(s.save),
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}

Future<void> showGoalsDialog(
  BuildContext context,
  MorphHealthController ctrl,
) async {
  final s = ctrl.s;
  final g = ctrl.settings.goals;
  final waterCtrl =
      TextEditingController(text: g.waterMl?.round().toString() ?? '');
  final kcalCtrl =
      TextEditingController(text: g.caloriesKcal?.round().toString() ?? '');
  final protCtrl =
      TextEditingController(text: g.proteinG?.round().toString() ?? '');
  final carbCtrl =
      TextEditingController(text: g.carbohydratesG?.round().toString() ?? '');
  final fatCtrl =
      TextEditingController(text: g.fatG?.round().toString() ?? '');

  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(s.dailyGoals),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              s.t(
                'Alle Ziele sind freiwillig. Lass ein Feld leer, wenn du kein Ziel setzen möchtest.',
                'All goals are voluntary. Leave any field empty if you prefer no goal.',
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: waterCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: '${s.water} (ml)',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: kcalCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: '${s.t('Kalorien', 'Calories')} (kcal)',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: protCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Protein (g)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: carbCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: '${s.t('Kohlenhydrate', 'Carbohydrates')} (g)',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: fatCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: '${s.t('Fett', 'Fat')} (g)',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(s.cancel),
        ),
        FilledButton(
          onPressed: () async {
            double? parseOpt(String t) {
              final d = double.tryParse(t.trim().replaceAll(',', '.'));
              return (d != null && d > 0) ? d : null;
            }

            final nextGoals = NutritionGoals(
              waterMl: parseOpt(waterCtrl.text),
              caloriesKcal: parseOpt(kcalCtrl.text),
              proteinG: parseOpt(protCtrl.text),
              carbohydratesG: parseOpt(carbCtrl.text),
              fatG: parseOpt(fatCtrl.text),
            );
            await ctrl.updateSettings(ctrl.settings.copyWith(goals: nextGoals));
            if (ctx.mounted) Navigator.of(ctx).pop();
          },
          child: Text(s.save),
        ),
      ],
    ),
  );
}

Future<void> showWaterEntryDialog(
  BuildContext context,
  MorphHealthController ctrl, {
  WaterEntry? existing,
}) async {
  final s = ctrl.s;
  final mlCtrl = TextEditingController(
    text: (existing?.amountMl ?? 250).round().toString(),
  );
  final dateCtrl = TextEditingController(
    text: existing?.date ?? ctrl.selectedDate,
  );
  final notesCtrl = TextEditingController(text: existing?.notes ?? '');

  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(
        existing == null
            ? s.t('Wasser erfassen', 'Log Water')
            : s.t('Wassereintrag bearbeiten', 'Edit Water Entry'),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: mlCtrl,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Menge / Amount (ml)',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: dateCtrl,
            decoration: InputDecoration(
              labelText: '${s.date} (YYYY-MM-DD)',
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: notesCtrl,
            decoration: InputDecoration(
              labelText: s.notes,
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        if (existing != null)
          TextButton(
            onPressed: () async {
              await ctrl.deleteWaterEntry(existing.id);
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: Text(s.delete),
          ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(s.cancel),
        ),
        FilledButton(
          onPressed: () async {
            final ml = double.tryParse(mlCtrl.text.trim()) ?? 0.0;
            if (ml <= 0) return;
            final date = dateCtrl.text.trim();
            final entry = WaterEntry(
              id: existing?.id ?? ctrl.repository.generateId('we'),
              date: date,
              timestamp: existing?.timestamp ?? '${date}T12:00:00Z',
              amountMl: ml,
              notes:
                  notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
            );
            await ctrl.saveWaterEntry(entry);
            if (ctx.mounted) Navigator.of(ctx).pop();
          },
          child: Text(s.save),
        ),
      ],
    ),
  );
}

Future<void> showCaffeineEntryDialog(
  BuildContext context,
  MorphHealthController ctrl, {
  CaffeineEntry? existing,
}) async {
  final s = ctrl.s;
  final mgCtrl = TextEditingController(
    text: (existing?.amountMg ?? 80).round().toString(),
  );
  final nameCtrl = TextEditingController(
    text: existing?.beverageName ?? 'Kaffee',
  );
  final dateCtrl = TextEditingController(
    text: existing?.date ?? ctrl.selectedDate,
  );
  final notesCtrl = TextEditingController(text: existing?.notes ?? '');

  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(
        existing == null
            ? s.t('Koffein erfassen', 'Log Caffeine')
            : s.t('Koffeineintrag bearbeiten', 'Edit Caffeine Entry'),
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                ActionChip(
                  label: const Text('Espresso (60 mg)'),
                  onPressed: () {
                    nameCtrl.text = 'Espresso';
                    mgCtrl.text = '60';
                  },
                ),
                ActionChip(
                  label: Text(s.t('Filterkaffee (100 mg)', 'Coffee (100 mg)')),
                  onPressed: () {
                    nameCtrl.text = s.t('Filterkaffee', 'Filter Coffee');
                    mgCtrl.text = '100';
                  },
                ),
                ActionChip(
                  label: Text(s.t('Tee (40 mg)', 'Tea (40 mg)')),
                  onPressed: () {
                    nameCtrl.text = s.t('Grüner/Schwarzer Tee', 'Tea');
                    mgCtrl.text = '40';
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextField(
              controller: nameCtrl,
              decoration: InputDecoration(
                labelText: s.t('Getränk / Quelle', 'Beverage / Source'),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: mgCtrl,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: '${s.caffeine} (mg)',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: dateCtrl,
              decoration: InputDecoration(
                labelText: '${s.date} (YYYY-MM-DD)',
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: notesCtrl,
              decoration: InputDecoration(
                labelText: s.notes,
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (existing != null)
          TextButton(
            onPressed: () async {
              await ctrl.deleteCaffeineEntry(existing.id);
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: Text(s.delete),
          ),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(s.cancel),
        ),
        FilledButton(
          onPressed: () async {
            final mg = double.tryParse(mgCtrl.text.trim()) ?? 0.0;
            if (mg <= 0) return;
            final date = dateCtrl.text.trim();
            final entry = CaffeineEntry(
              id: existing?.id ?? ctrl.repository.generateId('ce'),
              date: date,
              timestamp: existing?.timestamp ?? '${date}T09:00:00Z',
              amountMg: mg,
              beverageName: nameCtrl.text.trim().isEmpty
                  ? 'Koffein'
                  : nameCtrl.text.trim(),
              notes:
                  notesCtrl.text.trim().isEmpty ? null : notesCtrl.text.trim(),
            );
            await ctrl.saveCaffeineEntry(entry);
            if (ctx.mounted) Navigator.of(ctx).pop();
          },
          child: Text(s.save),
        ),
      ],
    ),
  );
}

Future<void> showPeriodEntryDialog(
  BuildContext context,
  MorphHealthController ctrl, {
  PeriodEntry? existing,
  String? defaultStartDate,
}) async {
  final s = ctrl.s;
  final lang = ctrl.lang;
  final startCtrl = TextEditingController(
    text: existing?.startDate ?? defaultStartDate ?? ctrl.selectedDate,
  );
  final endCtrl = TextEditingController(
    text: existing?.endDate ?? '',
  );
  final notesCtrl = TextEditingController(text: existing?.notes ?? '');
  String selectedIntensity = existing?.intensity ?? BleedingIntensity.medium;

  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: Text(existing == null ? s.logPeriod : s.editPeriod),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                controller: startCtrl,
                decoration: InputDecoration(
                  labelText: s.t('Beginn (YYYY-MM-DD)', 'Start Date (YYYY-MM-DD)'),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: endCtrl,
                      decoration: InputDecoration(
                        labelText:
                            s.t('Ende (YYYY-MM-DD, optional)', 'End Date (YYYY-MM-DD, optional)'),
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  TextButton(
                    onPressed: () {
                      final startDt =
                          DateTime.tryParse('${startCtrl.text.trim()}T00:00:00Z');
                      if (startDt != null) {
                        final endDt = startDt.add(const Duration(days: 4));
                        final y = endDt.year.toString().padLeft(4, '0');
                        final m = endDt.month.toString().padLeft(2, '0');
                        final d = endDt.day.toString().padLeft(2, '0');
                        setDialogState(() {
                          endCtrl.text = '$y-$m-$d';
                        });
                      }
                    },
                    child: Text(s.t('+4 Tage', '+4 Days')),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: selectedIntensity,
                decoration: InputDecoration(
                  labelText: s.t('Blutungsstärke', 'Bleeding Intensity'),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
                items: [
                  for (final b in BleedingIntensity.all)
                    DropdownMenuItem(
                      value: b,
                      child: Text(BleedingIntensity.label(b, lang)),
                    ),
                ],
                onChanged: (v) {
                  if (v != null) {
                    setDialogState(() => selectedIntensity = v);
                  }
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: notesCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: s.notes,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          if (existing != null)
            TextButton(
              onPressed: () async {
                await ctrl.deletePeriodEntry(existing.id);
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              child: Text(s.delete),
            ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(s.cancel),
          ),
          FilledButton(
            onPressed: () async {
              final start = startCtrl.text.trim();
              if (start.length < 10) return;
              final rawEnd = endCtrl.text.trim();
              final end = rawEnd.length >= 10 ? rawEnd.substring(0, 10) : null;
              if (end != null && end.compareTo(start) < 0) return;

              final entry = PeriodEntry(
                id: existing?.id ?? ctrl.repository.generateId('pe'),
                startDate: start.substring(0, 10),
                endDate: end,
                intensity: selectedIntensity,
                dailyFlow: existing?.dailyFlow ?? const {},
                notes: notesCtrl.text.trim().isEmpty
                    ? null
                    : notesCtrl.text.trim(),
              );
              await ctrl.savePeriodEntry(entry);
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: Text(s.save),
          ),
        ],
      ),
    ),
  );
}

Future<void> showWeightEntryDialog(
  BuildContext context,
  MorphHealthController ctrl, {
  WeightEntry? existing,
}) async {
  final s = ctrl.s;
  String unit = existing?.inputUnit ?? ctrl.settings.weightUnit;
  final initialVal = existing != null
      ? existing.valueInUnit(unit)
      : (ctrl.latestWeight?.valueInUnit(unit) ?? (unit == 'lb' ? 145.0 : 65.0));

  final valCtrl = TextEditingController(
    text: initialVal.toStringAsFixed(1),
  );
  final dateCtrl = TextEditingController(
    text: existing?.date ?? ctrl.selectedDate,
  );
  final notesCtrl = TextEditingController(text: existing?.notes ?? '');

  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: Text(existing == null ? s.logWeight : s.editWeight),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: valCtrl,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: '${s.domainWeight} ($unit)',
                        border: const OutlineInputBorder(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SegmentedButton<String>(
                    segments: const [
                      ButtonSegment(value: 'kg', label: Text('kg')),
                      ButtonSegment(value: 'lb', label: Text('lb')),
                    ],
                    selected: {unit},
                    onSelectionChanged: (sel) {
                      final nextUnit = sel.first;
                      if (nextUnit != unit) {
                        final cur = double.tryParse(
                          valCtrl.text.trim().replaceAll(',', '.'),
                        );
                        if (cur != null && cur > 0) {
                          final kg = WeightEntry.toKg(cur, unit);
                          final converted = nextUnit == 'lb'
                              ? kg * WeightEntry.kgToLbFactor
                              : kg;
                          valCtrl.text = converted.toStringAsFixed(1);
                        }
                        setDialogState(() => unit = nextUnit);
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: dateCtrl,
                decoration: InputDecoration(
                  labelText: '${s.date} (YYYY-MM-DD)',
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: notesCtrl,
                decoration: InputDecoration(
                  labelText: s.notes,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          if (existing != null)
            TextButton(
              onPressed: () async {
                await ctrl.deleteWeightEntry(existing.id);
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              child: Text(s.delete),
            ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(s.cancel),
          ),
          FilledButton(
            onPressed: () async {
              final raw = double.tryParse(
                valCtrl.text.trim().replaceAll(',', '.'),
              );
              if (raw == null || raw <= 0) return;
              final date = dateCtrl.text.trim().substring(0, 10);
              final entry = WeightEntry(
                id: existing?.id ?? ctrl.repository.generateId('wt'),
                date: date,
                timestamp: existing?.timestamp ?? '${date}T07:30:00Z',
                weightKg: WeightEntry.toKg(raw, unit),
                inputUnit: unit,
                notes: notesCtrl.text.trim().isEmpty
                    ? null
                    : notesCtrl.text.trim(),
              );
              await ctrl.saveWeightEntry(entry);
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: Text(s.save),
          ),
        ],
      ),
    ),
  );
}

Future<void> showSymptomEntryDialog(
  BuildContext context,
  MorphHealthController ctrl, {
  SymptomEntry? existing,
  String? defaultDate,
}) async {
  final s = ctrl.s;
  final nameCtrl = TextEditingController(text: existing?.name ?? '');
  final dateCtrl = TextEditingController(
    text: existing?.date ?? defaultDate ?? ctrl.selectedDate,
  );
  final timeCtrl = TextEditingController(
    text: (existing?.timestamp != null && existing!.timestamp.length >= 16)
        ? existing.timestamp.substring(11, 16)
        : '12:00',
  );
  final notesCtrl = TextEditingController(text: existing?.notes ?? '');
  int intensity = existing?.intensity ?? 4;

  final suggestions = ctrl.lang == 'en'
      ? const [
          'Headache',
          'Cramps',
          'Fatigue',
          'Bloating',
          'Back pain',
          'Mood swings',
          'Nausea',
          'Breast tenderness',
        ]
      : const [
          'Kopfschmerzen',
          'Unterleibskrämpfe',
          'Müdigkeit',
          'Blähbauch',
          'Rückenschmerzen',
          'Stimmungsschwankungen',
          'Übelkeit',
          'Brustspannen',
        ];

  await showDialog<void>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        title: Text(existing == null ? s.logSymptom : s.editSymptom),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final sug in suggestions)
                    ActionChip(
                      label: Text(sug, style: const TextStyle(fontSize: 12)),
                      onPressed: () {
                        setDialogState(() => nameCtrl.text = sug);
                      },
                    ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: nameCtrl,
                decoration: InputDecoration(
                  labelText: s.t(
                    'Symptomname (frei wählbar)',
                    'Symptom Name (free text)',
                  ),
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    s.symptomIntensity,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    '$intensity / 10',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ],
              ),
              Slider(
                value: intensity.toDouble(),
                min: 0,
                max: 10,
                divisions: 10,
                label: '$intensity',
                onChanged: (v) {
                  setDialogState(() => intensity = v.round());
                },
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: dateCtrl,
                      decoration: InputDecoration(
                        labelText: '${s.date} (YYYY-MM-DD)',
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: timeCtrl,
                      decoration: InputDecoration(
                        labelText: '${s.time} (HH:MM)',
                        border: const OutlineInputBorder(),
                        isDense: true,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: notesCtrl,
                decoration: InputDecoration(
                  labelText: s.notes,
                  border: const OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
          ),
        ),
        actions: [
          if (existing != null)
            TextButton(
              onPressed: () async {
                await ctrl.deleteSymptomEntry(existing.id);
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              child: Text(s.delete),
            ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(s.cancel),
          ),
          FilledButton(
            onPressed: () async {
              final name = nameCtrl.text.trim();
              if (name.isEmpty) return;
              final date = dateCtrl.text.trim().substring(0, 10);
              final time = timeCtrl.text.trim();
              final ts = '${date}T${time.length == 5 ? time : '12:00'}:00Z';

              final entry = SymptomEntry(
                id: existing?.id ?? ctrl.repository.generateId('sy'),
                date: date,
                timestamp: ts,
                name: name,
                intensity: intensity,
                notes: notesCtrl.text.trim().isEmpty
                    ? null
                    : notesCtrl.text.trim(),
              );
              await ctrl.saveSymptomEntry(entry);
              if (ctx.mounted) Navigator.of(ctx).pop();
            },
            child: Text(s.save),
          ),
        ],
      ),
    ),
  );
}
