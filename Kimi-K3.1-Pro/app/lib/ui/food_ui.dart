import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/food_api.dart';
import '../core/nutrition.dart';
import '../core/utils.dart';
import 'controller.dart';
import 'l10n.dart';
import 'nutrition_ui.dart';
import 'widgets.dart';

const _foodSearchPageSize = 20;

String _nutrientGroupTitle(S strings, NutrientGroup group) => switch (group) {
  NutrientGroup.main => strings.t('main_nutrients'),
  NutrientGroup.additional => strings.t('additional_nutrients'),
  NutrientGroup.vitamin => strings.t('vitamins'),
  NutrientGroup.mineral => strings.t('minerals'),
};

Food? _savedFood(AppController controller, Food food) {
  for (final item in controller.state.foods) {
    if (item.id == food.id) return item;
  }
  final barcode = food.barcode;
  if (!food.isCustom && barcode != null) {
    for (final item in controller.state.foods) {
      if (item.source == 'openfoodfacts' && item.barcode == barcode) {
        return item;
      }
    }
  }
  return null;
}

class FoodLibraryPage extends StatefulWidget {
  const FoodLibraryPage({super.key});

  @override
  State<FoodLibraryPage> createState() => _FoodLibraryPageState();
}

enum _LibraryFilter { all, favorites, custom }

class _FoodLibraryPageState extends State<FoodLibraryPage> {
  final _searchController = TextEditingController();
  _LibraryFilter _filter = _LibraryFilter.all;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _toggleFavorite(Food food) async {
    final controller = context.read<AppController>();
    try {
      await controller.repository.saveFood(
        food.copyWith(
          favorite: !food.favorite,
          updatedAt: controller.now.toUtc(),
        ),
      );
    } catch (_) {
      if (mounted) showError(context);
    }
  }

  Future<void> _deleteFood(Food food) async {
    if (!await confirmDeletion(context) || !mounted) return;
    final controller = context.read<AppController>();
    try {
      await controller.repository.deleteFood(food.id);
    } catch (error) {
      if (!mounted) return;
      final isInUse = error is StateError && error.message == 'food_in_use';
      showError(context, isInUse ? l10n(context).t('food_in_use') : null);
    }
  }

  void _openDetails(Food food) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => FoodDetailsPage(food: food)),
    );
  }

  void _openEditor([Food? food]) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => FoodEditPage(existing: food)),
    );
  }

  Widget _filterChip(S strings, _LibraryFilter filter, String label) {
    return ChoiceChip(
      label: Text(label),
      selected: _filter == filter,
      onSelected: (selected) {
        if (selected) setState(() => _filter = filter);
      },
    );
  }

  Widget _foodCard(BuildContext context, Food food) {
    final strings = l10n(context);
    final subtitle = <String>[
      if (food.brand.trim().isNotEmpty) food.brand,
      strings.t(food.isCustom ? 'source_custom' : 'source_off'),
      if (food.barcode != null) '${strings.t('barcode')}: ${food.barcode}',
    ].join('\n');
    return AppCard(
      title: food.name,
      subtitle: subtitle,
      icon: food.isCustom ? Icons.restaurant_menu : Icons.cloud_outlined,
      onTap: () => _openDetails(food),
      trailing: IconButton(
        tooltip: strings.t(food.favorite ? 'favorite_remove' : 'favorite_add'),
        onPressed: () => _toggleFavorite(food),
        icon: Icon(food.favorite ? Icons.favorite : Icons.favorite_border),
      ),
      children: [
        _MainNutrients(food: food),
        if (food.isCustom)
          OverflowBar(
            alignment: MainAxisAlignment.end,
            children: [
              TextButton.icon(
                onPressed: () => _openEditor(food),
                icon: const Icon(Icons.edit_outlined),
                label: Text(strings.t('edit')),
              ),
              TextButton.icon(
                onPressed: () => _deleteFood(food),
                icon: const Icon(Icons.delete_outline),
                label: Text(strings.t('delete')),
              ),
            ],
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = l10n(context);
    final controller = context.watch<AppController>();
    final query = normalizeSearch(_searchController.text);
    final foods =
        controller.state.foods.where((food) {
          if (_filter == _LibraryFilter.favorites && !food.favorite) {
            return false;
          }
          if (_filter == _LibraryFilter.custom && !food.isCustom) return false;
          if (query.isEmpty) return true;
          return normalizeSearch(
            '${food.name}\n${food.brand}\n${food.barcode ?? ''}',
          ).contains(query);
        }).toList()..sort(
          (a, b) => normalizeSearch(a.name).compareTo(normalizeSearch(b.name)),
        );

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                key: const ValueKey('food-library-search'),
                controller: _searchController,
                decoration: fieldDecoration(strings.t('search')).copyWith(
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: query.isEmpty
                      ? null
                      : IconButton(
                          tooltip: strings.t('cancel'),
                          onPressed: () {
                            _searchController.clear();
                            setState(() {});
                          },
                          icon: const Icon(Icons.clear),
                        ),
                ),
                onChanged: (_) => setState(() {}),
              ),
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  _filterChip(strings, _LibraryFilter.all, strings.t('all')),
                  const SizedBox(width: 8),
                  _filterChip(
                    strings,
                    _LibraryFilter.favorites,
                    strings.t('favorites'),
                  ),
                  const SizedBox(width: 8),
                  _filterChip(
                    strings,
                    _LibraryFilter.custom,
                    strings.t('own_foods'),
                  ),
                ],
              ),
            ),
            AppCard(
              title: strings.t('search_online'),
              subtitle: strings.t('source_off'),
              icon: Icons.travel_explore,
              trailing: const Icon(Icons.chevron_right),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute<void>(
                    builder: (_) => const FoodSearchPage(),
                  ),
                );
              },
            ),
            if (foods.isEmpty)
              EmptyState(
                text: strings.t(
                  controller.state.foods.isEmpty ? 'no_foods' : 'no_results',
                ),
                icon: Icons.restaurant_menu_outlined,
              )
            else
              for (final food in foods) _foodCard(context, food),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'food-library-add',
        key: const ValueKey('add-food'),
        tooltip: strings.t('add_food'),
        onPressed: _openEditor,
        icon: const Icon(Icons.add),
        label: Text(strings.t('add_food')),
      ),
    );
  }
}

enum _FoodRequest { none, search, lookup }

class FoodSearchPage extends StatefulWidget {
  const FoodSearchPage({super.key});

  @override
  State<FoodSearchPage> createState() => _FoodSearchPageState();
}

class _FoodSearchPageState extends State<FoodSearchPage> {
  final _queryController = TextEditingController();
  final _barcodeController = TextEditingController();
  final _queryFormKey = GlobalKey<FormState>();
  final _barcodeFormKey = GlobalKey<FormState>();

  FoodSearchResult? _searchResult;
  FoodLookupResult? _lookupResult;
  _FoodRequest _lastRequest = _FoodRequest.none;
  String _activeQuery = '';
  String _activeBarcode = '';
  int _activePage = 1;
  int _requestSerial = 0;
  bool _loading = false;
  bool _hasSearched = false;
  Object? _error;

  @override
  void dispose() {
    _requestSerial++;
    _queryController.dispose();
    _barcodeController.dispose();
    super.dispose();
  }

  bool get _onlineEnabled =>
      context.read<AppController>().settings.onlineEnabled;

  void _submitSearch() {
    if (!_onlineEnabled || _loading) return;
    if (_queryFormKey.currentState?.validate() != true) return;
    _search(_queryController.text, 1);
  }

  Future<void> _search(String query, int page) async {
    if (!_onlineEnabled) return;
    final normalized = query.trim();
    if (normalized.isEmpty || page < 1) return;
    final serial = ++_requestSerial;
    final api = context.read<AppController>().foodApi;
    setState(() {
      _loading = true;
      _hasSearched = true;
      _error = null;
      _searchResult = null;
      _lookupResult = null;
      _lastRequest = _FoodRequest.search;
      _activeQuery = normalized;
      _activePage = page;
    });
    try {
      final result = await api.search(normalized, page);
      if (!mounted || serial != _requestSerial) return;
      setState(() {
        _searchResult = result;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || serial != _requestSerial) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  void _submitLookup() {
    if (!_onlineEnabled || _loading) return;
    if (_barcodeFormKey.currentState?.validate() != true) return;
    _lookup(_barcodeController.text);
  }

  Future<void> _lookup(String barcode) async {
    if (!_onlineEnabled) return;
    final normalized = barcode.trim();
    final serial = ++_requestSerial;
    final api = context.read<AppController>().foodApi;
    setState(() {
      _loading = true;
      _hasSearched = true;
      _error = null;
      _searchResult = null;
      _lookupResult = null;
      _lastRequest = _FoodRequest.lookup;
      _activeBarcode = normalized;
    });
    try {
      final result = await api.lookup(normalized);
      if (!mounted || serial != _requestSerial) return;
      setState(() {
        _lookupResult = result;
        _loading = false;
      });
    } catch (error) {
      if (!mounted || serial != _requestSerial) return;
      setState(() {
        _error = error;
        _loading = false;
      });
    }
  }

  void _retry() {
    if (_loading) return;
    switch (_lastRequest) {
      case _FoodRequest.search:
        _search(_activeQuery, _activePage);
      case _FoodRequest.lookup:
        _lookup(_activeBarcode);
      case _FoodRequest.none:
        break;
    }
  }

  Widget _controls(S strings, bool enabled) {
    return AppCard(
      title: strings.t('online'),
      subtitle: strings.t('online_subtitle'),
      icon: Icons.travel_explore,
      children: [
        Form(
          key: _queryFormKey,
          child: TextFormField(
            key: const ValueKey('food-search-query'),
            controller: _queryController,
            enabled: enabled,
            decoration: fieldDecoration(strings.t('search')),
            textInputAction: TextInputAction.search,
            onFieldSubmitted: enabled ? (_) => _submitSearch() : null,
            validator: (value) => value == null || value.trim().isEmpty
                ? strings.t('required')
                : null,
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            key: const ValueKey('food-search-submit'),
            onPressed: enabled && !_loading ? _submitSearch : null,
            icon: const Icon(Icons.search),
            label: Text(strings.t('search')),
          ),
        ),
        const Divider(height: 32),
        Form(
          key: _barcodeFormKey,
          child: TextFormField(
            key: const ValueKey('food-barcode'),
            controller: _barcodeController,
            enabled: enabled,
            decoration: fieldDecoration(strings.t('barcode')),
            keyboardType: TextInputType.number,
            textInputAction: TextInputAction.search,
            onFieldSubmitted: enabled ? (_) => _submitLookup() : null,
            validator: (value) {
              final normalized = value?.trim() ?? '';
              if (normalized.isEmpty) return strings.t('required');
              if (!RegExp(r'^\d{8,14}$').hasMatch(normalized)) {
                return strings.t('invalid_number');
              }
              return null;
            },
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.icon(
            key: const ValueKey('food-barcode-submit'),
            onPressed: enabled && !_loading ? _submitLookup : null,
            icon: const Icon(Icons.qr_code),
            label: Text(strings.t('lookup_barcode')),
          ),
        ),
      ],
    );
  }

  Widget _resultCard(Food food) {
    final strings = l10n(context);
    final subtitle = <String>[
      if (food.brand.trim().isNotEmpty) food.brand,
      if (food.barcode != null) '${strings.t('barcode')}: ${food.barcode}',
    ].join('\n');
    return AppCard(
      title: food.name,
      subtitle: subtitle.isEmpty ? strings.t('source_off') : subtitle,
      icon: Icons.restaurant_outlined,
      trailing: const Icon(Icons.chevron_right),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => FoodDetailsPage(food: food)),
        );
      },
      children: [_MainNutrients(food: food)],
    );
  }

  List<Widget> _results(S strings) {
    if (_loading) {
      return [
        Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Column(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 16),
                Text(strings.t('working')),
              ],
            ),
          ),
        ),
      ];
    }
    if (_error != null) {
      return [
        AppCard(
          title: strings.t('error'),
          icon: Icons.error_outline,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                key: const ValueKey('food-search-retry'),
                onPressed: _retry,
                icon: const Icon(Icons.refresh),
                label: Text(strings.t('retry')),
              ),
            ),
          ],
        ),
      ];
    }

    final search = _searchResult;
    final lookup = _lookupResult;
    final foods = <Food>[
      if (lookup?.food != null) lookup!.food!,
      if (search != null) ...search.foods,
    ];
    if (_hasSearched && foods.isEmpty) {
      return [EmptyState(text: strings.t('no_results'))];
    }

    final total = search?.total ?? foods.length;
    final page = search?.page ?? 1;
    final pageCount = total == 0
        ? 1
        : (total + _foodSearchPageSize - 1) ~/ _foodSearchPageSize;
    final hasPrevious = search != null && page > 1;
    final hasNext = search != null && page < pageCount;
    return [
      if (_hasSearched)
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
          child: Text(
            strings.t('results_count', {'count': total}),
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
      for (final food in foods) _resultCard(food),
      if (hasPrevious || hasNext)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                key: const ValueKey('food-search-previous'),
                onPressed: hasPrevious
                    ? () => _search(_activeQuery, page - 1)
                    : null,
                icon: const Icon(Icons.navigate_before),
              ),
              Text('$page / $pageCount'),
              IconButton(
                key: const ValueKey('food-search-next'),
                onPressed: hasNext
                    ? () => _search(_activeQuery, page + 1)
                    : null,
                icon: const Icon(Icons.navigate_next),
              ),
            ],
          ),
        ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final strings = l10n(context);
    final onlineEnabled = context.watch<AppController>().settings.onlineEnabled;
    return Scaffold(
      appBar: AppBar(title: Text(strings.t('online'))),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 24),
          children: [
            _controls(strings, onlineEnabled),
            if (!onlineEnabled)
              EmptyState(
                text: strings.t('online_disabled'),
                icon: Icons.cloud_off_outlined,
              )
            else
              ..._results(strings),
            AppCard(
              title: strings.t('source_off'),
              subtitle: strings.t('off_attribution'),
              icon: Icons.public,
            ),
          ],
        ),
      ),
    );
  }
}

class FoodDetailsPage extends StatefulWidget {
  const FoodDetailsPage({super.key, required Food food}) : _food = food;

  final Food _food;

  @override
  State<FoodDetailsPage> createState() => _FoodDetailsPageState();
}

class _FoodDetailsPageState extends State<FoodDetailsPage> {
  bool _busy = false;

  Future<Food> _ensureSaved(AppController controller, Food food) async {
    return _savedFood(controller, food) ?? controller.importFood(food);
  }

  Future<void> _toggleFavorite(Food food) async {
    final controller = context.read<AppController>();
    setState(() => _busy = true);
    try {
      final saved = await _ensureSaved(controller, food);
      await controller.repository.saveFood(
        saved.copyWith(
          favorite: !saved.favorite,
          updatedAt: controller.now.toUtc(),
        ),
      );
    } catch (_) {
      if (mounted) showError(context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addIntake(Food food) async {
    final controller = context.read<AppController>();
    setState(() => _busy = true);
    try {
      final saved = await _ensureSaved(controller, food);
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => IntakeEditPage(food: saved)),
      );
    } catch (_) {
      if (mounted) showError(context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _infoLine(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 16),
          Flexible(child: Text(value, textAlign: TextAlign.end)),
        ],
      ),
    );
  }

  Widget _nutrientGroup(S strings, Food food, NutrientGroup group) {
    final nutrients = Nutrient.values.where((item) => item.group == group);
    return AppCard(
      title: _nutrientGroupTitle(strings, group),
      subtitle: strings.t('per_100', {'unit': food.measure}),
      children: [
        for (final nutrient in nutrients)
          Padding(
            key: ValueKey('food-nutrient-${nutrient.id}'),
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(flex: 3, child: Text(strings.nutrient(nutrient))),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: Text(
                    food.nutrients[nutrient.id] == null
                        ? strings.t('unknown_nutrient')
                        : strings.amount(
                            food.nutrients[nutrient.id]!,
                            nutrient.unit,
                          ),
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = l10n(context);
    final controller = context.watch<AppController>();
    final food = _savedFood(controller, widget._food) ?? widget._food;
    final subtitle = <String>[
      if (food.brand.trim().isNotEmpty) food.brand,
      strings.t(food.isCustom ? 'source_custom' : 'source_off'),
    ].join('\n');
    return Scaffold(
      appBar: AppBar(
        title: Text(food.name),
        actions: [
          IconButton(
            tooltip: strings.t(
              food.favorite ? 'favorite_remove' : 'favorite_add',
            ),
            onPressed: _busy ? null : () => _toggleFavorite(food),
            icon: Icon(food.favorite ? Icons.favorite : Icons.favorite_border),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(top: 8, bottom: 96),
          children: [
            AppCard(
              title: food.name,
              subtitle: subtitle,
              icon: food.isCustom
                  ? Icons.restaurant_menu_outlined
                  : Icons.cloud_outlined,
              children: [
                if (food.barcode != null)
                  _infoLine(strings.t('barcode'), food.barcode!),
                _infoLine(
                  strings.t('unit'),
                  '${strings.t(food.measure == 'g' ? 'grams' : 'milliliters')} (${food.measure})',
                ),
                _infoLine(
                  strings.t('portion_size'),
                  food.portionSize == null
                      ? strings.t('unknown_nutrient')
                      : strings.amount(food.portionSize!, food.measure),
                ),
              ],
            ),
            for (final group in NutrientGroup.values)
              _nutrientGroup(strings, food, group),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'food-details-add-${food.id}',
        key: const ValueKey('add-food-intake'),
        tooltip: strings.t('add_intake'),
        onPressed: _busy ? null : () => _addIntake(food),
        icon: const Icon(Icons.add),
        label: Text(strings.t('add_intake')),
      ),
    );
  }
}

class FoodEditPage extends StatefulWidget {
  const FoodEditPage({super.key, Food? existing}) : _existing = existing;

  final Food? _existing;

  @override
  State<FoodEditPage> createState() => _FoodEditPageState();
}

class _FoodEditPageState extends State<FoodEditPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _brandController;
  late final TextEditingController _portionController;
  late final Map<Nutrient, TextEditingController> _nutrientControllers;
  late String _measure;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    final existing = widget._existing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _brandController = TextEditingController(text: existing?.brand ?? '');
    _portionController = TextEditingController(
      text: existing?.portionSize?.toString() ?? '',
    );
    _measure = existing?.measure ?? 'g';
    _nutrientControllers = {
      for (final nutrient in Nutrient.values)
        nutrient: TextEditingController(
          text: existing?.nutrients[nutrient.id]?.toString() ?? '',
        ),
    };
  }

  @override
  void dispose() {
    _nameController.dispose();
    _brandController.dispose();
    _portionController.dispose();
    for (final controller in _nutrientControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _validateOptionalNumber(String? value, {bool positive = false}) {
    final strings = l10n(context);
    final normalized = value?.trim() ?? '';
    if (normalized.isEmpty) return null;
    final parsed = parseAmount(normalized);
    if (parsed == null || !parsed.isFinite || parsed < 0) {
      return strings.t('invalid_number');
    }
    if (positive && parsed == 0) return strings.t('positive_number');
    return null;
  }

  Future<void> _save() async {
    if (_saving || _formKey.currentState?.validate() != true) return;
    FocusScope.of(context).unfocus();
    final controller = context.read<AppController>();
    setState(() => _saving = true);
    try {
      final timestamp = controller.now.toUtc();
      final existing = widget._existing;
      final nutrients = <String, double>{};
      for (final nutrient in Nutrient.values) {
        final raw = _nutrientControllers[nutrient]!.text;
        if (raw.trim().isEmpty) continue;
        final value = parseAmount(raw);
        if (value != null) nutrients[nutrient.id] = value;
      }
      final portionText = _portionController.text.trim();
      await controller.repository.saveFood(
        Food(
          id: existing?.id ?? newId(),
          name: _nameController.text.trim(),
          brand: _brandController.text.trim(),
          source: 'custom',
          measure: _measure,
          portionSize: portionText.isEmpty ? null : parseAmount(portionText),
          nutrients: nutrients,
          favorite: existing?.favorite ?? false,
          barcode: existing?.barcode,
          createdAt: existing?.createdAt ?? timestamp,
          updatedAt: timestamp,
        ),
      );
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) showError(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Widget _nutrientGroup(S strings, NutrientGroup group) {
    final nutrients = Nutrient.values.where((item) => item.group == group);
    return AppCard(
      title: _nutrientGroupTitle(strings, group),
      subtitle: strings.t('per_100', {'unit': _measure}),
      children: [
        for (final nutrient in nutrients)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TextFormField(
              key: ValueKey('edit-nutrient-${nutrient.id}'),
              controller: _nutrientControllers[nutrient],
              decoration: fieldDecoration(
                strings.nutrient(nutrient),
                suffix: nutrient.unit,
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              validator: _validateOptionalNumber,
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final strings = l10n(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          strings.t(widget._existing == null ? 'custom_food' : 'edit_food'),
        ),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.only(top: 8, bottom: 24),
            children: [
              AppCard(
                title: strings.t('custom_food'),
                subtitle: strings.t('nutrient_input_help'),
                icon: Icons.restaurant_menu_outlined,
                children: [
                  TextFormField(
                    key: const ValueKey('food-name'),
                    controller: _nameController,
                    decoration: fieldDecoration(strings.t('name')),
                    textCapitalization: TextCapitalization.sentences,
                    validator: (value) => value == null || value.trim().isEmpty
                        ? strings.t('required')
                        : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const ValueKey('food-brand'),
                    controller: _brandController,
                    decoration: fieldDecoration(
                      '${strings.t('brand')} (${strings.t('optional')})',
                    ),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    isExpanded: true,
                    key: const ValueKey('food-measure'),
                    initialValue: _measure,
                    decoration: fieldDecoration(strings.t('unit')),
                    items: [
                      DropdownMenuItem(
                        value: 'g',
                        child: Text('${strings.t('grams')} (g)'),
                      ),
                      DropdownMenuItem(
                        value: 'ml',
                        child: Text('${strings.t('milliliters')} (ml)'),
                      ),
                    ],
                    onChanged: (value) {
                      if (value != null) setState(() => _measure = value);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const ValueKey('food-portion-size'),
                    controller: _portionController,
                    decoration: fieldDecoration(
                      '${strings.t('portion_size')} (${strings.t('optional')})',
                      suffix: _measure,
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (value) =>
                        _validateOptionalNumber(value, positive: true),
                  ),
                ],
              ),
              for (final group in NutrientGroup.values)
                _nutrientGroup(strings, group),
              Padding(
                padding: const EdgeInsets.all(16),
                child: FilledButton.icon(
                  key: const ValueKey('save-food'),
                  onPressed: _saving ? null : _save,
                  icon: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.save_outlined),
                  label: Text(strings.t(_saving ? 'working' : 'save')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MainNutrients extends StatelessWidget {
  const _MainNutrients({required this.food});

  final Food food;

  @override
  Widget build(BuildContext context) {
    final strings = l10n(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          strings.t('per_100', {'unit': food.measure}),
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
          runSpacing: 8,
          children: [
            for (final nutrient in Nutrient.values.where(
              (item) => item.group == NutrientGroup.main,
            ))
              Text(
                '${strings.nutrient(nutrient)}: '
                '${food.nutrients[nutrient.id] == null ? strings.t('unknown_nutrient') : strings.amount(food.nutrients[nutrient.id]!, nutrient.unit)}',
              ),
          ],
        ),
      ],
    );
  }
}
