import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/civil.dart';
import '../../core/food_api.dart';
import '../../core/models.dart';
import '../../core/nutrients.dart';
import '../../l10n/gen/app_localizations.dart';
import '../../state/app_state.dart';
import '../l10n_x.dart';
import '../widgets/common.dart';
import 'custom_food_screen.dart';
import 'food_entry_screen.dart';

/// Text zu einem Fehler des Lebensmitteldienstes.
String foodErrorText(AppLocalizations l, FoodApiException e) => switch (e.code) {
  'offline' => l.pickerErrorOffline,
  'timeout' => l.pickerErrorTimeout,
  'tls' => l.pickerErrorTls,
  'rate_limited' => l.pickerErrorRate,
  'disabled' => l.pickerOnlineDisabled,
  'not_found' => l.pickerBarcodeNotFound,
  'invalid_barcode' => l.pickerBarcodeInvalid,
  _ => l.pickerErrorGeneric(e.code),
};

enum _Mode { name, barcode }

/// Lebensmittel auswählen: Online-Suche (Name oder Barcode), zuletzt
/// verwendete, Favoriten und eigene Lebensmittel.
class FoodPickerScreen extends StatefulWidget {
  final Meal? meal;
  final Day? day;

  const FoodPickerScreen({super.key, this.meal, this.day});

  @override
  State<FoodPickerScreen> createState() => _FoodPickerScreenState();
}

class _FoodPickerScreenState extends State<FoodPickerScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabs = TabController(length: 4, vsync: this);
  final _query = TextEditingController();
  final _focus = FocusNode();
  _Mode _mode = _Mode.name;

  bool _loading = false;
  String? _error;
  bool _searched = false;
  String _lastQuery = '';
  int _total = 0;
  int _page = 0;
  bool _hasMore = false;
  final List<FoodInfo> _results = [];
  FoodInfo? _barcodeHit;
  int _requestId = 0;

  @override
  void dispose() {
    _tabs.dispose();
    _query.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    _focus.unfocus();
    _tabs.animateTo(0);
    if (_mode == _Mode.barcode) {
      await _lookupBarcode();
    } else {
      await _search();
    }
  }

  Future<void> _search({bool more = false}) async {
    final app = AppScope.read(context);
    final q = more ? _lastQuery : _query.text.trim();
    if (q.isEmpty) return;
    final id = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
      _searched = true;
      if (!more) {
        _results.clear();
        _lastQuery = q;
        _page = 0;
        _total = 0;
        _hasMore = false;
      }
    });
    final l = context.l10n;
    try {
      final page = await app.core.foodSearch(q, page: _page + 1);
      if (!mounted || id != _requestId) return;
      setState(() {
        _results.addAll(page.items);
        _page = page.page;
        _total = page.total;
        _hasMore = page.hasMore;
        _loading = false;
      });
    } on FoodApiException catch (e) {
      if (!mounted || id != _requestId) return;
      setState(() {
        _error = foodErrorText(l, e);
        _loading = false;
      });
    }
  }

  Future<void> _lookupBarcode() async {
    final app = AppScope.read(context);
    final code = _query.text.trim();
    if (code.isEmpty) return;
    final id = ++_requestId;
    setState(() {
      _loading = true;
      _error = null;
      _searched = true;
      _barcodeHit = null;
    });
    final l = context.l10n;
    try {
      final r = await app.core.foodLookup(code);
      if (!mounted || id != _requestId) return;
      setState(() {
        _barcodeHit = r.food;
        _loading = false;
      });
    } on FoodApiException catch (e) {
      if (!mounted || id != _requestId) return;
      setState(() {
        _error = foodErrorText(l, e);
        _loading = false;
      });
    }
  }

  /// Öffnet den Eintragsbildschirm. Bei Produkten aus der Suche werden vorher
  /// die Produktdetails per Barcode geladen (bei Fehlern gelten die
  /// Suchwerte).
  Future<void> _open(
    FoodInfo info, {
    String? foodId,
    double? amount,
    AmountUnit? unit,
    Meal? meal,
    bool fetchDetails = false,
  }) async {
    final app = AppScope.read(context);
    final l = context.l10n;
    var detail = info;
    if (fetchDetails && info.source == FoodSource.off && info.barcode != null && app.settings.onlineFood) {
      final nav = Navigator.of(context, rootNavigator: true);
      unawaited(
        showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (c) => PopScope(
            canPop: false,
            child: AlertDialog(
              content: Row(
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(width: 20),
                  Expanded(child: Text(l.foodDetailsLoading)),
                ],
              ),
            ),
          ),
        ),
      );
      var failed = false;
      try {
        detail = (await app.core.foodLookup(info.barcode!)).food;
      } on FoodApiException {
        failed = true;
      }
      nav.pop();
      if (!mounted) return;
      if (failed) showMessage(context, l.foodDetailsFallback);
    }
    final added = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => FoodEntryScreen(
          food: detail,
          foodId: foodId,
          meal: meal ?? widget.meal,
          day: widget.day,
          amount: amount,
          unit: unit,
        ),
      ),
    );
    if (added == true && mounted) Navigator.of(context).pop(true);
  }

  Future<void> _createCustom() async {
    final food = await Navigator.of(context).push<Food>(MaterialPageRoute(builder: (_) => const CustomFoodScreen()));
    if (food != null && mounted) await _open(food.info, foodId: food.id);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AppScaffold(
      appBar: AppBar(
        title: Text(l.nutritionAddFood),
        bottom: TabBar(
          controller: _tabs,
          isScrollable: true,
          tabAlignment: TabAlignment.start,
          tabs: [
            Tab(text: l.pickerTabSearch),
            Tab(text: l.pickerTabRecent),
            Tab(text: l.pickerTabFavorites),
            Tab(text: l.pickerTabCustom),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Column(
              children: [
                SegmentedButton<_Mode>(
                  showSelectedIcon: false,
                  segments: [
                    ButtonSegment(value: _Mode.name, icon: const Icon(Icons.search), label: Text(l.pickerModeName)),
                    ButtonSegment(
                      value: _Mode.barcode,
                      icon: const Icon(Icons.pin_outlined),
                      label: Text(l.pickerModeBarcode),
                    ),
                  ],
                  selected: {_mode},
                  onSelectionChanged: (s) => setState(() {
                    _mode = s.first;
                    _error = null;
                    _searched = false;
                    _barcodeHit = null;
                    _query.clear();
                  }),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _query,
                  focusNode: _focus,
                  keyboardType: _mode == _Mode.barcode ? TextInputType.number : TextInputType.text,
                  textInputAction: TextInputAction.search,
                  onSubmitted: (_) => _submit(),
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: _mode == _Mode.barcode ? l.pickerBarcodeHint : l.pickerSearchHint,
                    prefixIcon: Icon(_mode == _Mode.barcode ? Icons.pin_outlined : Icons.search),
                    suffixIcon: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_query.text.isNotEmpty)
                          IconButton(
                            tooltip: l.commonDelete,
                            icon: const Icon(Icons.clear),
                            onPressed: () => setState(_query.clear),
                          ),
                        IconButton(
                          tooltip: l.pickerSearchButton,
                          icon: const Icon(Icons.arrow_forward),
                          onPressed: _submit,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabs,
              children: [
                _buildSearchTab(context),
                _buildRecentTab(context),
                _buildLibraryTab(context, favorites: true),
                _buildLibraryTab(context, favorites: false),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // -- Tab "Suche" ----------------------------------------------------------

  Widget _buildSearchTab(BuildContext context) {
    final l = context.l10n;
    final app = AppScope.of(context);
    if (!app.settings.onlineFood) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [EmptyHint(l.pickerOnlineDisabled, icon: Icons.cloud_off)],
      );
    }
    if (!_searched) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          EmptyHint(l.pickerOnlineHint, icon: Icons.info_outline),
          const SizedBox(height: 8),
          OutlinedButton.icon(onPressed: _createCustom, icon: const Icon(Icons.add), label: Text(l.pickerCreateCustom)),
        ],
      );
    }
    if (_loading && _results.isEmpty && _barcodeHit == null) {
      return Center(
        child: Semantics(label: l.pickerSearchButton, child: const CircularProgressIndicator()),
      );
    }
    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          EmptyHint(_error!, icon: Icons.error_outline),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(onPressed: _submit, icon: const Icon(Icons.refresh), label: Text(l.commonRetry)),
          ),
        ],
      );
    }
    if (_mode == _Mode.barcode) {
      final hit = _barcodeHit;
      if (hit == null) return const SizedBox.shrink();
      return ListView(padding: const EdgeInsets.only(top: 8), children: [_foodTile(context, hit, online: true)]);
    }
    if (_results.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          EmptyHint(l.pickerNoResults(_lastQuery), icon: Icons.search_off),
          const SizedBox(height: 8),
          OutlinedButton.icon(onPressed: _createCustom, icon: const Icon(Icons.add), label: Text(l.pickerCreateCustom)),
        ],
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 24),
      itemCount: _results.length + 2,
      itemBuilder: (c, i) {
        if (i == 0) {
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Semantics(
              liveRegion: true,
              child: Text(l.pickerResultCount(context.fmt.n(_total.toDouble())), style: context.text.labelLarge),
            ),
          );
        }
        if (i == _results.length + 1) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: _hasMore
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      onPressed: _loading ? null : () => _search(more: true),
                      icon: _loading
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                          : const Icon(Icons.expand_more),
                      label: Text(l.pickerLoadMore),
                    ),
                  )
                : const SizedBox.shrink(),
          );
        }
        return _foodTile(c, _results[i - 1], online: true);
      },
    );
  }

  Widget _foodTile(BuildContext context, FoodInfo info, {bool online = false, String? foodId, Widget? trailing}) {
    final l = context.l10n;
    final f = context.fmt;
    final n = info.nutrients;
    final name = info.name == info.barcode ? l.foodUnnamed : info.name;
    final sub = [
      if (info.brand != null) info.brand!,
      n.has(kEnergy) ? l.foodKcalPer100(f.n(n.get0(kEnergy)), l.basisUnit(info.basis)) : l.foodNoNutrition,
    ].join(' · ');
    return ListTile(
      title: Text(name, maxLines: 2, overflow: TextOverflow.ellipsis),
      subtitle: Text(sub, maxLines: 2, overflow: TextOverflow.ellipsis),
      trailing: trailing ?? const Icon(Icons.chevron_right),
      onTap: () => _open(info, foodId: foodId, fetchDetails: online),
    );
  }

  // -- Tab "Zuletzt" --------------------------------------------------------

  Widget _buildRecentTab(BuildContext context) {
    final l = context.l10n;
    final f = context.fmt;
    final app = AppScope.of(context);
    final q = _query.text.trim().toLowerCase();
    final recent = [
      for (final e in app.db.recentEntries(limit: 60))
        if (q.isEmpty || e.food.name.toLowerCase().contains(q) || (e.food.brand?.toLowerCase().contains(q) ?? false)) e,
    ];
    if (recent.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [EmptyHint(q.isEmpty ? l.pickerNoRecent : l.pickerNoLocalMatches, icon: Icons.history)],
      );
    }
    return ListView.builder(
      itemCount: recent.length,
      itemBuilder: (c, i) {
        final e = recent[i];
        final amount = '${f.nTrim(e.amount, 2)} ${l.unitFor(e.unit, e.amount)}';
        final kcal = e.nutrients.has(kEnergy) ? f.kcal(e.nutrients.get0(kEnergy)) : l.nutritionNoKcal;
        return ListTile(
          leading: const Icon(Icons.history),
          title: Text(e.food.name, maxLines: 2, overflow: TextOverflow.ellipsis),
          subtitle: Text('$amount · $kcal'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => _open(e.food, foodId: e.foodId, amount: e.amount, unit: e.unit),
        );
      },
    );
  }

  // -- Tabs "Favoriten" und "Eigene" -------------------------------------------

  Widget _buildLibraryTab(BuildContext context, {required bool favorites}) {
    final l = context.l10n;
    final app = AppScope.of(context);
    final q = _query.text.trim();
    final all = app.db.searchFoods(q, limit: 500);
    final foods = [
      for (final fd in all)
        if (favorites ? fd.favorite : fd.info.source == FoodSource.custom) fd,
    ];
    final header = favorites
        ? const SizedBox.shrink()
        : Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.tonalIcon(
                onPressed: _createCustom,
                icon: const Icon(Icons.add),
                label: Text(l.pickerCreateCustom),
              ),
            ),
          );
    if (foods.isEmpty) {
      final empty = q.isNotEmpty ? l.pickerNoLocalMatches : (favorites ? l.pickerNoFavorites : l.pickerNoCustom);
      return ListView(
        padding: const EdgeInsets.only(top: 4),
        children: [
          header,
          Padding(
            padding: const EdgeInsets.all(16),
            child: EmptyHint(empty, icon: favorites ? Icons.star_border : Icons.edit_note),
          ),
        ],
      );
    }
    return ListView.builder(
      itemCount: foods.length + 1,
      itemBuilder: (c, i) {
        if (i == 0) return header;
        final fd = foods[i - 1];
        return _foodTile(
          c,
          fd.info,
          foodId: fd.id,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: fd.favorite ? l.entryFavoriteRemove : l.entryFavoriteAdd,
                isSelected: fd.favorite,
                icon: const Icon(Icons.star_border),
                selectedIcon: Icon(Icons.star, color: context.colors.tertiary),
                onPressed: () => app.db.setFavorite(fd.id, !fd.favorite),
              ),
              if (fd.info.source == FoodSource.custom)
                IconButton(
                  tooltip: l.commonEdit,
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: () =>
                      Navigator.of(context).push(MaterialPageRoute(builder: (_) => CustomFoodScreen(existing: fd))),
                ),
            ],
          ),
        );
      },
    );
  }
}
