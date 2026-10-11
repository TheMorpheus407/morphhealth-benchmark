// Lebensmittel-Screens: Suche (Open Food Facts + Barcode), Favoriten/Eigene,
// Detailansicht, Verzehr-Erfassung und Lebensmittel-Editor.
library;

import 'package:flutter/material.dart';

import '../core/exceptions.dart';
import '../core/parse.dart';
import '../data/repository.dart';
import '../food/off_client.dart';
import '../food/off_mapping.dart';
import '../l10n/app_strings.dart';
import '../model/entries.dart';
import '../model/food.dart';
import '../nutrients/nutrients.dart';
import 'scope.dart';
import 'widgets.dart';

// ------------------------------------------------------------------ Suche

/// Lebensmittelsuche: Open-Food-Facts-Suche, Barcode-Abruf, Favoriten,
/// eigene Lebensmittel und zuletzt verwendete Einträge.
class FoodSearchScreen extends StatefulWidget {
  /// true = Auswahlmodus (Ergebnis wird zurückgegeben statt direkt geloggt).
  final bool pickMode;

  const FoodSearchScreen({super.key, this.pickMode = false});

  @override
  State<FoodSearchScreen> createState() => _FoodSearchScreenState();
}

class _FoodSearchScreenState extends State<FoodSearchScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final TextEditingController _queryController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  List<OffProduct> _results = <OffProduct>[];
  bool _loading = false;
  String? _error;
  int _page = 1;
  int _pageCount = 1;
  String _lastQuery = '';

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _queryController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final AppStrings strings = StringsScope.of(context);
    final OffClient off = MorphScope.offOf(context);
    final String q = _queryController.text.trim();
    if (q.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
      _results = <OffProduct>[];
      _page = 1;
      _lastQuery = q;
    });
    try {
      final String? barcode = OffClient.normalizeBarcode(q);
      if (barcode != null) {
        final OffProduct? product = await off.lookup(barcode);
        if (!mounted) return;
        setState(() {
          _loading = false;
          _results = product == null ? <OffProduct>[] : <OffProduct>[product];
          _pageCount = 1;
          if (product == null) _error = strings.lookupNotFound;
        });
      } else {
        final OffSearchResult result = await off.search(q, page: 1);
        if (!mounted) return;
        setState(() {
          _loading = false;
          _results = result.products;
          _page = result.page;
          _pageCount = result.pageCount;
        });
      }
    } on MorphException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    }
  }

  Future<void> _loadMore() async {
    final OffClient off = MorphScope.offOf(context);
    final int next = _page + 1;
    if (next > _pageCount) return;
    setState(() => _loading = true);
    try {
      final OffSearchResult result =
          await off.search(_lastQuery, page: next);
      if (!mounted) return;
      setState(() {
        _loading = false;
        _results = <OffProduct>[..._results, ...result.products];
        _page = result.page;
        _pageCount = result.pageCount;
      });
    } on MorphException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    }
  }

  void _openProduct(OffProduct product) {
    if (widget.pickMode) {
      Navigator.of(context).pop(product.toFoodItemSnapshot());
      return;
    }
    Navigator.of(context).push(MaterialPageRoute<Widget>(
        builder: (_) => FoodDetailScreen(product: product)));
  }

  void _openFood(FoodItem food) {
    if (widget.pickMode) {
      Navigator.of(context).pop(food);
      return;
    }
    Navigator.of(context).push(MaterialPageRoute<Widget>(
        builder: (_) => FoodDetailScreen(food: food)));
  }

  void _reLog(NutritionEntry entry) {
    if (widget.pickMode) {
      Navigator.of(context).pop(_foodFromEntry(entry));
      return;
    }
    Navigator.of(context).push(MaterialPageRoute<Widget>(
        builder: (_) => EntryEditScreen(reLogFrom: entry)));
  }

  static FoodItem _foodFromEntry(NutritionEntry e) {
    return FoodItem(
      id: e.foodId,
      name: e.foodName,
      source: FoodSource.custom,
      per100: Map<String, double>.of(e.foodPer100),
      serving:
          e.foodServingGrams == null ? null : Serving(grams: e.foodServingGrams),
      createdAt: e.createdAt,
      updatedAt: e.createdAt,
    );
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = StringsScope.of(context);
    final MorphRepository repo = MorphScope.repoOf(context);
    return Scaffold(
      appBar: AppBar(title: Text(strings.foodSearchTitle)),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _queryController,
                    decoration: InputDecoration(
                      labelText: strings.searchHint,
                      prefixIcon: const Icon(Icons.search),
                    ),
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _submit(),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton(
                  onPressed: _loading ? null : _submit,
                  child: Text(strings.search),
                ),
              ],
            ),
          ),
          TabBar(
            controller: _tabs,
            tabs: <Tab>[
              Tab(text: strings.tabSearch),
              Tab(text: strings.tabFavorites),
              Tab(text: strings.tabCustom),
              Tab(text: strings.tabRecent),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: <Widget>[
                _searchTab(strings),
                _foodListTab(strings, repo.favoriteFoods),
                _foodListTab(strings, repo.customFoods),
                _recentTab(strings, repo),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _searchTab(AppStrings strings) {
    if (_loading && _results.isEmpty) {
      return Center(
          child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const CircularProgressIndicator(),
          const SizedBox(height: 8),
          Text(strings.loading),
        ],
      ));
    }
    if (_error != null && _results.isEmpty) {
      return EmptyState(icon: Icons.cloud_off, text: _error!);
    }
    if (_results.isEmpty) {
      return EmptyState(
          icon: Icons.search, text: strings.searchNoResults);
    }
    return ListView.builder(
      controller: _scrollController,
      itemCount: _results.length + (_page < _pageCount ? 1 : 0),
      itemBuilder: (BuildContext context, int i) {
        if (i >= _results.length) {
          return Padding(
            padding: const EdgeInsets.all(12),
            child: FilledButton.tonal(
              onPressed: _loading ? null : _loadMore,
              child: Text(_loading ? strings.loading : strings.search),
            ),
          );
        }
        final OffProduct p = _results[i];
        return ListTile(
          leading: const Icon(Icons.fastfood_outlined),
          title: Text(p.name),
          subtitle: Text(
            '${p.brand ?? ''}${p.brand != null ? ' · ' : ''}'
            '${strings.nutrientAmount('energy_kcal', p.per100['energy_kcal'] ?? 0)} ${strings.per100}',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _openProduct(p),
        );
      },
    );
  }

  Widget _foodListTab(AppStrings strings, List<FoodItem> foods) {
    if (foods.isEmpty) {
      return EmptyState(
          icon: Icons.no_food, text: strings.addFoodFirst);
    }
    return ListView.builder(
      itemCount: foods.length,
      itemBuilder: (BuildContext context, int i) {
        final FoodItem f = foods[i];
        return ListTile(
          leading: Icon(f.isFavorite ? Icons.star : Icons.star_outline),
          title: Text(f.name),
          subtitle: Text(
            '${f.brand ?? ''}${f.barcode != null ? ' · ${f.barcode}' : ''}'
            '${f.brand != null || f.barcode != null ? ' · ' : ''}'
            '${strings.nutrientAmount('energy_kcal', f.per100['energy_kcal'] ?? 0)} ${strings.per100}',
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _openFood(f),
        );
      },
    );
  }

  Widget _recentTab(AppStrings strings, MorphRepository repo) {
    final List<NutritionEntry> recent = List<NutritionEntry>.of(
        repo.nutritionEntries)
      ..sort((NutritionEntry a, NutritionEntry b) =>
          b.date.compareTo(a.date));
    final List<NutritionEntry> top = recent.take(30).toList();
    if (top.isEmpty) {
      return EmptyState(icon: Icons.history, text: strings.diaryEmpty);
    }
    return ListView.builder(
      itemCount: top.length,
      itemBuilder: (BuildContext context, int i) {
        final NutritionEntry e = top[i];
        return ListTile(
          leading: const Icon(Icons.repeat),
          title: Text(e.foodName),
          subtitle: Text(
              '${strings.mealName(e.meal)} · ${strings.formatDateShort(parseDate(e.date) ?? DateTime.now())}'
              ' · ${strings.formatNumber(e.quantity, fractionDigits: e.quantity == e.quantity.roundToDouble() ? 0 : 1)} ${strings.quantityUnitName(e.unit)}'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _reLog(e),
        );
      },
    );
  }
}

// ------------------------------------------------------------------ Detail

/// Detailansicht eines Lebensmittels (OFF-Produkt oder lokaler Eintrag).
class FoodDetailScreen extends StatefulWidget {
  final FoodItem? food;
  final OffProduct? product;

  const FoodDetailScreen({super.key, this.food, this.product});

  @override
  State<FoodDetailScreen> createState() => _FoodDetailScreenState();
}

class _FoodDetailScreenState extends State<FoodDetailScreen> {
  String? _snapshotId;

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = StringsScope.of(context);
    final MorphRepository repo = MorphScope.repoOf(context);
    return ListenableBuilder(
      listenable: MorphScope.listenableOf(context),
      builder: (BuildContext context, Widget? _) {
        // Anzeigedaten auflösen (OFF-Produkt oder lokales Lebensmittel).
        final FoodItem? localFood = widget.food ??
            (_snapshotId != null ? repo.foodById(_snapshotId!) : null);
        final OffProduct? product = widget.product;
        final String name = localFood?.name ?? product?.name ?? '';
        final String? brand = localFood?.brand ?? product?.brand;
        final Map<String, double> per100 =
            localFood?.per100 ?? product?.per100 ?? <String, double>{};
        final Serving? serving = localFood?.serving ?? product?.serving;
        final String? imageUrl = localFood?.imageUrl ?? product?.imageUrl;
        final String? barcode =
            localFood?.barcode ?? product?.barcode;
        final bool isCustom = localFood?.isCustom ?? false;
        final FoodItem? favFood =
            localFood ?? (barcode == null ? null : _findOffFood(repo, barcode));
        final bool isFavorite = favFood?.isFavorite ?? false;

        return Scaffold(
          appBar: AppBar(title: Text(strings.foodDetailTitle)),
          body: ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: <Widget>[
              if (imageUrl != null && imageUrl.isNotEmpty)
                _FoodImage(url: imageUrl),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(name,
                        style: Theme.of(context).textTheme.headlineSmall),
                    if (brand != null && brand.isNotEmpty)
                      Text(brand,
                          style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: <Widget>[
                        Chip(
                            label: Text(isCustom
                                ? strings.sourceCustom
                                : strings.sourceOff)),
                        if (barcode != null) Chip(label: Text(barcode)),
                        if (serving != null && serving.grams != null)
                          Chip(
                              label: Text(
                                  '${strings.perPortion}: ${strings.formatNumber(serving.grams!, fractionDigits: 0)} g'
                                  '${serving.label != null ? ' (${serving.label})' : ''}')),
                      ],
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () => _logFood(repo, localFood, product),
                      icon: const Icon(Icons.add),
                      label: Text(strings.addToDiary),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: <Widget>[
                        OutlinedButton.icon(
                          onPressed: favFood == null
                              ? null
                              : () => _toggleFavorite(repo, favFood, isFavorite),
                          icon: Icon(isFavorite
                              ? Icons.star
                              : Icons.star_outline),
                          label: Text(isFavorite
                              ? strings.favoriteRemove
                              : strings.favoriteAdd),
                        ),
                        if (isCustom && localFood != null)
                          OutlinedButton.icon(
                            onPressed: () => Navigator.of(context).push(
                                MaterialPageRoute<Widget>(
                                    builder: (_) =>
                                        FoodEditScreen(food: localFood))),
                            icon: const Icon(Icons.edit_outlined),
                            label: Text(strings.editFood),
                          ),
                        if (isCustom && localFood != null)
                          OutlinedButton.icon(
                            onPressed: () => _deleteFood(repo, localFood),
                            icon: const Icon(Icons.delete_outline),
                            label: Text(strings.delete),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(strings.nutrientsPer100,
                        style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 4),
                    NutrientTable(values: per100),
                    const SizedBox(height: 12),
                    Text(strings.offAttribution,
                        style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static FoodItem? _findOffFood(MorphRepository repo, String barcode) {
    for (final FoodItem f in repo.foods) {
      if (f.source == FoodSource.off && f.barcode == barcode) return f;
    }
    return null;
  }

  Future<void> _toggleFavorite(
      MorphRepository repo, FoodItem food, bool isFavorite) async {
    await repo.toggleFoodFavorite(food.id, !isFavorite);
  }

  Future<void> _logFood(MorphRepository repo,
      FoodItem? localFood, OffProduct? product) async {
    FoodItem? food = localFood;
    if (food == null && product != null) {
      food = await repo.upsertOffSnapshot(product.toFoodItemSnapshot());
      _snapshotId = food.id;
    }
    if (food == null || !mounted) return;
    await Navigator.of(context).push(MaterialPageRoute<Widget>(
        builder: (_) => EntryEditScreen(food: food)));
  }

  Future<void> _deleteFood(MorphRepository repo, FoodItem food) async {
    final AppStrings strings = StringsScope.of(context);
    if (await confirmDelete(context)) {
      await repo.deleteFood(food.id);
      if (mounted) {
        showInfo(context, strings.foodDeleted);
        Navigator.of(context).pop();
      }
    }
  }
}

/// Produktbild (nur bei verfügbarem Netz; Fehler werden ausgeblendet).
class _FoodImage extends StatelessWidget {
  final String url;
  const _FoodImage({required this.url});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      child: Image.network(
        url,
        height: 160,
        width: double.infinity,
        fit: BoxFit.cover,
        errorBuilder:
            (BuildContext context, Object error, StackTrace? stack) =>
                const SizedBox.shrink(),
      ),
    );
  }
}

// ------------------------------------------------------------------ Verzehr

/// Verzehr erfassen/bearbeiten (Lebensmittel, Menge, Mahlzeit, Datum).
class EntryEditScreen extends StatefulWidget {
  /// Vorausgewähltes Lebensmittel (aus Suche/Detail).
  final FoodItem? food;
  /// Bearbeitung eines bestehenden Eintrags.
  final NutritionEntry? entry;
  /// Erneut erfassen: Werte eines früheren Eintrags übernehmen.
  final NutritionEntry? reLogFrom;
  /// Ziel-Datum (Standard: heute).
  final String? date;

  const EntryEditScreen({
    super.key,
    this.food,
    this.entry,
    this.reLogFrom,
    this.date,
  });

  @override
  State<EntryEditScreen> createState() => _EntryEditScreenState();
}

class _EntryEditScreenState extends State<EntryEditScreen> {
  FoodItem? _food;
  late final TextEditingController _quantityController;
  late final TextEditingController _noteController;
  QuantityUnit _unit = QuantityUnit.g;
  Meal _meal = Meal.breakfast;
  late DateTime _date;
  String? _time;

  NutritionEntry? get _editing => widget.entry;

  @override
  void initState() {
    super.initState();
    final NutritionEntry? source = widget.entry ?? widget.reLogFrom;
    if (widget.food != null) {
      _food = widget.food;
    } else if (source != null) {
      _food = FoodItem(
        id: source.foodId,
        name: source.foodName,
        source: FoodSource.custom,
        per100: Map<String, double>.of(source.foodPer100),
        serving: source.foodServingGrams == null
            ? null
            : Serving(grams: source.foodServingGrams),
        createdAt: source.createdAt,
        updatedAt: source.createdAt,
      );
    }
    _quantityController = TextEditingController(
        text: source == null
            ? ''
            : source.quantity.toStringAsFixed(
                source.quantity == source.quantity.roundToDouble() ? 0 : 2));
    _noteController = TextEditingController(text: source?.note ?? '');
    if (source != null) {
      _unit = source.unit;
      _meal = source.meal;
      _time = source.time;
    }
    final String? dateStr = widget.entry?.date ?? widget.date;
    if (dateStr != null) {
      _date = parseDate(dateStr) ?? DateTime.utc(
          DateTime.now().year, DateTime.now().month, DateTime.now().day);
    } else {
      _date = DateTime.utc(
          DateTime.now().year, DateTime.now().month, DateTime.now().day);
    }
    _quantityController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _quantityController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  double _previewAmount(String key) {
    final FoodItem? f = _food;
    if (f == null) return 0;
    final AppStrings strings = StringsScope.of(context);
    final double q =
        NumberField.parse(strings, _quantityController.text) ?? 0;
    final double grams = switch (_unit) {
      QuantityUnit.g => q,
      QuantityUnit.ml => q,
      QuantityUnit.portion => q * (f.serving?.grams ?? 100),
    };
    return (f.per100[key] ?? 0) * grams / 100;
  }

  Future<void> _pickFood() async {
    final FoodItem? result = await Navigator.of(context)
        .push<FoodItem>(MaterialPageRoute<FoodItem>(
      builder: (_) => const FoodSearchScreen(pickMode: true),
    ));
    if (result != null && mounted) {
      setState(() {
        _food = result;
        if (_unit == QuantityUnit.portion && result.serving?.grams != null) {
          // Portionsgröße des neuen Lebensmittels bleibt erhalten.
        }
      });
    }
  }

  Future<void> _save() async {
    final AppStrings strings = StringsScope.of(context);
    final MorphRepository repo = MorphScope.repoOf(context);
    final FoodItem? food = _food;
    if (food == null) {
      showError(context, strings.selectFoodFirst);
      return;
    }
    final double? quantity =
        NumberField.parse(strings, _quantityController.text);
    if (quantity == null || quantity <= 0) {
      showError(context, strings.invalidNumber);
      return;
    }
    // OFF-Schnappschuss persistieren, damit der Eintrag eine food_id hat.
    FoodItem effective = food;
    if (effective.source == FoodSource.off &&
        repo.foodById(effective.id) == null) {
      effective = await repo.upsertOffSnapshot(effective);
    }
    final String? note = _noteController.text.trim().isEmpty
        ? null
        : _noteController.text.trim();
    final NutritionEntry entry = NutritionEntry(
      id: _editing?.id ?? '',
      foodId: effective.id,
      foodName: effective.name,
      foodPer100: Map<String, double>.of(effective.per100),
      foodServingGrams: effective.serving?.grams,
      date: formatDate(_date),
      time: _time,
      meal: _meal,
      quantity: quantity,
      unit: _unit,
      note: note,
      createdAt: _editing?.createdAt ?? DateTime.now().toUtc(),
    );
    if (_editing == null) {
      await repo.addNutritionEntry(entry);
    } else {
      await repo.updateNutritionEntry(entry);
    }
    if (!mounted) return;
    showInfo(
        context, _editing == null ? strings.entrySaved : strings.entryUpdated);
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final AppStrings strings = StringsScope.of(context);
    final MorphRepository repo = MorphScope.repoOf(context);
    final NutritionEntry? editing = _editing;
    if (editing == null) return;
    if (await confirmDelete(context, message: strings.deleteEntryConfirm)) {
      await repo.deleteNutritionEntry(editing.id);
      if (!mounted) return;
      showInfo(context, strings.entryDeleted);
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = StringsScope.of(context);
    final FoodItem? food = _food;
    return Scaffold(
      appBar: AppBar(
        title: Text(_editing == null
            ? strings.entryNewTitle
            : strings.entryEditTitle),
        actions: <Widget>[
          if (_editing != null)
            IconButton(
              tooltip: strings.a11yDelete,
              icon: const Icon(Icons.delete_outline),
              onPressed: _delete,
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          if (food == null)
            FilledButton.tonalIcon(
              onPressed: _pickFood,
              icon: const Icon(Icons.search),
              label: Text(strings.selectFood),
            )
          else
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.fastfood_outlined),
              title: Text(food.name),
              subtitle: Text(
                  '${food.brand ?? ''}${food.barcode != null ? ' · ${food.barcode}' : ''}'
                  '${food.brand != null || food.barcode != null ? ' · ' : ''}'
                  '${strings.nutrientAmount('energy_kcal', food.per100['energy_kcal'] ?? 0)} ${strings.per100}'),
              trailing: TextButton(
                onPressed: _pickFood,
                child: Text(strings.changeFood),
              ),
            ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(
                flex: 2,
                child: NumberField(
                  controller: _quantityController,
                  label: strings.quantityLabel,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: QuantityUnitPicker(
                  value: _unit,
                  onChanged: (QuantityUnit u) => setState(() => _unit = u),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          MealPicker(
            value: _meal,
            onChanged: (Meal m) => setState(() => _meal = m),
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(
                child: TextButton.icon(
                  onPressed: () async {
                    final DateTime? picked =
                        await pickDate(context, initial: _date);
                    if (picked != null && mounted) {
                      setState(() => _date =
                          DateTime.utc(picked.year, picked.month, picked.day));
                    }
                  },
                  icon: const Icon(Icons.calendar_today),
                  label: Text(strings.formatDateShort(_date)),
                ),
              ),
              Expanded(
                child: TextButton.icon(
                  onPressed: () async {
                    final TimeOfDay? picked = await pickTime(context,
                        initial: TimeOfDay.now());
                    if (picked != null && mounted) {
                      setState(() => _time =
                          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}');
                    }
                  },
                  icon: const Icon(Icons.schedule),
                  label: Text(_time ?? strings.now),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _noteController,
            decoration: InputDecoration(
              labelText: strings.noteLabel,
              hintText: strings.optionalLabel,
            ),
          ),
          const SizedBox(height: 12),
          if (food != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(strings.dayTotal,
                        style: Theme.of(context).textTheme.titleSmall),
                    StatRow(
                        label: strings.nutrientName('energy_kcal'),
                        value: strings.nutrientAmount(
                            'energy_kcal', _previewAmount('energy_kcal'))),
                    StatRow(
                        label: strings.nutrientName('protein_g'),
                        value: strings.nutrientAmount(
                            'protein_g', _previewAmount('protein_g'))),
                    StatRow(
                        label: strings.nutrientName('carbohydrates_g'),
                        value: strings.nutrientAmount('carbohydrates_g',
                            _previewAmount('carbohydrates_g'))),
                    StatRow(
                        label: strings.nutrientName('fat_g'),
                        value: strings.nutrientAmount(
                            'fat_g', _previewAmount('fat_g'))),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save),
            label: Text(strings.save),
          ),
        ],
      ),
    );
  }
}

// ------------------------------------------------------------------ Lebensmittel-Editor

/// Eigenes Lebensmittel anlegen/bearbeiten (alle 31 Nährstoffe pro 100 g).
class FoodEditScreen extends StatefulWidget {
  final FoodItem? food;

  const FoodEditScreen({super.key, this.food});

  @override
  State<FoodEditScreen> createState() => _FoodEditScreenState();
}

class _FoodEditScreenState extends State<FoodEditScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _brandController;
  late final TextEditingController _barcodeController;
  late final TextEditingController _servingGramsController;
  late final TextEditingController _servingLabelController;
  late final Map<String, TextEditingController> _nutrientControllers;
  bool _isFavorite = false;

  @override
  void initState() {
    super.initState();
    final FoodItem? f = widget.food;
    _nameController = TextEditingController(text: f?.name ?? '');
    _brandController = TextEditingController(text: f?.brand ?? '');
    _barcodeController = TextEditingController(text: f?.barcode ?? '');
    _servingGramsController = TextEditingController(
        text: f?.serving?.grams == null ? '' : f!.serving!.grams!.toString());
    _servingLabelController =
        TextEditingController(text: f?.serving?.label ?? '');
    _isFavorite = f?.isFavorite ?? false;
    _nutrientControllers = <String, TextEditingController>{
      for (final NutrientDef d in nutrientDefs)
        d.key: TextEditingController(
            text: f == null
                ? ''
                : (f.per100[d.key] == null || f.per100[d.key] == 0
                    ? ''
                    : f.per100[d.key]!.toString())),
    };
  }

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _barcodeController.dispose();
    _servingGramsController.dispose();
    _servingLabelController.dispose();
    for (final TextEditingController c in _nutrientControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    final AppStrings strings = StringsScope.of(context);
    final MorphRepository repo = MorphScope.repoOf(context);
    final String name = _nameController.text.trim();
    if (name.isEmpty) {
      showError(context, strings.fieldRequired);
      return;
    }
    final Map<String, double> per100 = <String, double>{};
    for (final NutrientDef d in nutrientDefs) {
      final double? v =
          NumberField.parse(strings, _nutrientControllers[d.key]!.text);
      if (v != null && v != 0) per100[d.key] = v;
    }
    final double? servingGrams =
        NumberField.parse(strings, _servingGramsController.text);
    final String? servingLabel = _servingLabelController.text.trim().isEmpty
        ? null
        : _servingLabelController.text.trim();
    final String? barcode =
        _barcodeController.text.trim().isEmpty
            ? null
            : OffClient.normalizeBarcode(_barcodeController.text) ??
                _barcodeController.text.trim();
    final DateTime now = DateTime.now().toUtc();
    final FoodItem food = FoodItem(
      id: widget.food?.id ?? '',
      name: name,
      brand: _brandController.text.trim().isEmpty
          ? null
          : _brandController.text.trim(),
      barcode: barcode,
      source: FoodSource.custom,
      per100: per100,
      serving: servingGrams == null && servingLabel == null
          ? null
          : Serving(grams: servingGrams, label: servingLabel),
      isFavorite: _isFavorite,
      createdAt: widget.food?.createdAt ?? now,
      updatedAt: now,
    );
    if (widget.food == null) {
      await repo.addFood(food);
    } else {
      await repo.updateFood(food);
    }
    if (!mounted) return;
    showInfo(context, strings.foodSaved);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final AppStrings strings = StringsScope.of(context);
    return Scaffold(
      appBar: AppBar(
        title:
            Text(widget.food == null ? strings.newFood : strings.editFood),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          TextField(
            controller: _nameController,
            decoration: InputDecoration(labelText: strings.foodNameLabel),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _brandController,
            decoration: InputDecoration(labelText: strings.brandLabel),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _barcodeController,
            decoration: InputDecoration(labelText: strings.barcodeLabel),
            keyboardType: TextInputType.number,
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(
                child: NumberField(
                  controller: _servingGramsController,
                  label: strings.servingGramsLabel,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _servingLabelController,
                  decoration: InputDecoration(
                      labelText: strings.servingLabelHint),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(strings.favoriteAdd),
            value: _isFavorite,
            onChanged: (bool v) => setState(() => _isFavorite = v),
          ),
          const SizedBox(height: 8),
          Text(strings.nutrientsPer100,
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          _nutrientGroup(strings, strings.mainNutrients, mainNutrients),
          _nutrientGroup(strings, strings.vitamins, vitaminNutrients),
          _nutrientGroup(strings, strings.minerals, mineralNutrients),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: _save,
            icon: const Icon(Icons.save),
            label: Text(strings.save),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _nutrientGroup(
      AppStrings strings, String title, List<NutrientDef> defs) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.only(top: 12, bottom: 4),
          child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        ),
        for (final NutrientDef d in defs)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: NumberField(
              controller: _nutrientControllers[d.key]!,
              label:
                  '${strings.nutrientName(d.key)} (${strings.nutrientUnit(d.key)})',
            ),
          ),
      ],
    );
  }
}
