import 'package:flutter/material.dart';
import 'package:morphhealth_core/morphhealth_core.dart';

import '../l10n/app_localizations.dart';
import '../state/app_state.dart';
import '../widgets/common.dart';
import 'food_editor_sheet.dart';
import 'journal_entry_sheet.dart';

/// Lets the user pick a food: search, barcode, own foods, recent entries and
/// favourites.
class FoodPickerSheet extends StatefulWidget {
  const FoodPickerSheet({super.key, this.initialTab = 0});

  final int initialTab;

  static Future<void> show(BuildContext context, {int initialTab = 0}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (BuildContext context) =>
          FoodPickerSheet(initialTab: initialTab),
    );
  }

  @override
  State<FoodPickerSheet> createState() => _FoodPickerSheetState();
}

class _FoodPickerSheetState extends State<FoodPickerSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final TextEditingController _search = TextEditingController();
  final TextEditingController _barcode = TextEditingController();

  List<FoodSearchItem> _results = <FoodSearchItem>[];
  bool _searching = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 5, vsync: this, initialIndex: widget.initialTab);
  }

  @override
  void dispose() {
    _tabs.dispose();
    _search.dispose();
    _barcode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final AppLocalizations l10n = context.l10n;
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom +
            MediaQuery.of(context).padding.bottom,
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.85,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 8, 0),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      l10n.t('nutrition.add_entry'),
                      style: theme.textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                    tooltip: l10n.t('common.close'),
                  ),
                ],
              ),
            ),
            TabBar(
              controller: _tabs,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: <Widget>[
                Tab(text: l10n.t('nutrition.food_search')),
                Tab(text: l10n.t('nutrition.food_scan')),
                Tab(text: l10n.t('nutrition.food_own')),
                Tab(text: l10n.t('nutrition.food_recent')),
                Tab(text: l10n.t('nutrition.food_favorites')),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabs,
                children: <Widget>[
                  _buildSearch(),
                  _buildBarcode(),
                  _buildOwnFoods(),
                  _buildRecent(),
                  _buildFavorites(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearch() {
    final AppLocalizations l10n = context.l10n;
    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _search,
            autofocus: widget.initialTab == 0,
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: l10n.t('nutrition.food_search_hint'),
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searching
                  ? const Padding(
                      padding: EdgeInsets.all(12),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : IconButton(
                      icon: const Icon(Icons.arrow_forward),
                      onPressed: _runSearch,
                      tooltip: l10n.t('common.search'),
                    ),
            ),
            onSubmitted: (String _) => _runSearch(),
          ),
        ),
        if (_message != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              _message!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
        Expanded(
          child: _results.isEmpty
              ? const SizedBox.shrink()
              : ListView.builder(
                  itemCount: _results.length,
                  itemBuilder: (BuildContext context, int index) {
                    final FoodSearchItem item = _results[index];
                    return ListTile(
                      leading: const Icon(Icons.local_grocery_store_outlined),
                      title: Text(item.name),
                      subtitle: Text(
                        <String>[
                          if (item.brand != null) item.brand!,
                          if (item.energyKcalPer100 != null)
                            '${item.energyKcalPer100!.round()} kcal / 100 g',
                          if (item.quantityLabel != null) item.quantityLabel!,
                        ].join(' · '),
                      ),
                      onTap: () => _pickSearchResult(item),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildBarcode() {
    final AppLocalizations l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          TextField(
            controller: _barcode,
            keyboardType: TextInputType.number,
            decoration: InputDecoration(
              hintText: l10n.t('nutrition.food_scan_hint'),
              prefixIcon: const Icon(Icons.qr_code_2),
            ),
            onSubmitted: (String _) => _runLookup(),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _runLookup,
            icon: const Icon(Icons.search),
            label: Text(l10n.t('common.search')),
          ),
        ],
      ),
    );
  }

  Widget _buildOwnFoods() {
    final AppState state = AppScope.of(context);
    final AppLocalizations l10n = context.l10n;
    final List<FoodItem> own = state.repository.foods
        .where((FoodItem f) => f.isCustom)
        .toList(growable: false)
      ..sort((FoodItem a, FoodItem b) => a.name.compareTo(b.name));

    return Column(
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.tonalIcon(
              onPressed: () async {
                await FoodEditorSheet.show(context);
                if (mounted) setState(() {});
              },
              icon: const Icon(Icons.add),
              label: Text(l10n.t('nutrition.food_new')),
            ),
          ),
        ),
        Expanded(
          child: own.isEmpty
              ? EmptyState(message: l10n.t('common.empty'))
              : ListView.builder(
                  itemCount: own.length,
                  itemBuilder: (BuildContext context, int index) {
                    final FoodItem food = own[index];
                    return ListTile(
                      leading: const Icon(Icons.edit_note),
                      title: Text(food.name),
                      subtitle: Text(
                        '${food.nutrientsPer100[Nutrients.energyKcal].round()} kcal / 100 g',
                      ),
                      trailing: IconButton(
                        icon: const Icon(Icons.edit_outlined),
                        tooltip: l10n.t('common.edit'),
                        onPressed: () async {
                          await FoodEditorSheet.show(context, food: food);
                          if (mounted) setState(() {});
                        },
                      ),
                      onTap: () => _logFood(food),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildRecent() {
    final AppState state = AppScope.of(context);
    final AppLocalizations l10n = context.l10n;
    final List<FoodItem> recent = state.nutrition.recentlyLoggedFoods(limit: 30);
    if (recent.isEmpty) {
      return EmptyState(message: l10n.t('common.empty'));
    }
    return ListView.builder(
      itemCount: recent.length,
      itemBuilder: (BuildContext context, int index) {
        final FoodItem food = recent[index];
        return ListTile(
          leading: const Icon(Icons.history),
          title: Text(food.name),
          subtitle: Text(
            '${food.nutrientsPer100[Nutrients.energyKcal].round()} kcal / 100 g',
          ),
          onTap: () => _logFood(food),
        );
      },
    );
  }

  Widget _buildFavorites() {
    final AppState state = AppScope.of(context);
    final AppLocalizations l10n = context.l10n;
    final List<FoodItem> favorites = state.repository.favoriteFoods;
    if (favorites.isEmpty) {
      return EmptyState(message: l10n.t('common.empty'));
    }
    return ListView.builder(
      itemCount: favorites.length,
      itemBuilder: (BuildContext context, int index) {
        final FoodItem food = favorites[index];
        return ListTile(
          leading: const Icon(Icons.star),
          title: Text(food.name),
          subtitle: Text(
            '${food.nutrientsPer100[Nutrients.energyKcal].round()} kcal / 100 g',
          ),
          onTap: () => _logFood(food),
        );
      },
    );
  }

  Future<void> _runSearch() async {
    final String query = _search.text.trim();
    if (query.isEmpty) return;
    setState(() {
      _searching = true;
      _message = null;
    });
    try {
      final FoodSearchResult result = await AppScope.of(context).foodClient
          .search(query, page: 1);
      if (!mounted) return;
      setState(() {
        _results = result.items;
        _searching = false;
        if (result.items.isEmpty) {
          _message = context.l10n.t('nutrition.food_no_results');
        }
      });
    } on Object {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _message = context.l10n.t('nutrition.food_offline');
      });
    }
  }

  Future<void> _runLookup() async {
    final String code = _barcode.text.trim();
    if (code.isEmpty) return;
    setState(() => _searching = true);
    try {
      final FoodLookupResult result =
          await AppScope.of(context).foodClient.lookup(code);
      if (!mounted) return;
      setState(() => _searching = false);
      if (!result.found || result.food == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.t('nutrition.food_not_found'))),
        );
        return;
      }
      await _logFood(result.food!);
    } on Object {
      if (!mounted) return;
      setState(() => _searching = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.t('nutrition.food_offline'))),
      );
    }
  }

  Future<void> _pickSearchResult(FoodSearchItem item) async {
    if (item.code.isEmpty) return;
    setState(() => _searching = true);
    try {
      final FoodLookupResult result =
          await AppScope.of(context).foodClient.lookup(item.code);
      if (!mounted) return;
      setState(() => _searching = false);
      if (!result.found || result.food == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.t('nutrition.food_not_found'))),
        );
        return;
      }
      await _logFood(result.food!);
    } on Object {
      if (!mounted) return;
      setState(() => _searching = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.t('nutrition.food_offline'))),
      );
    }
  }

  Future<void> _logFood(FoodItem food) async {
    final AppState state = AppScope.of(context);
    await state.upsertFood(food);
    if (!mounted) return;
    Navigator.of(context).pop();
    await JournalEntrySheet.show(
      context,
      food: food,
      initialDate: state.selectedDate,
    );
  }
}
