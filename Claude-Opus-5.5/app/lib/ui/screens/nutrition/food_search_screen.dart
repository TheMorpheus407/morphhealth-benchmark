import 'package:flutter/material.dart';

import '../../../core/food/off_client.dart';
import '../../../core/food/off_parser.dart';
import '../../../core/model/enums.dart';
import '../../../core/model/food.dart';
import '../../../core/service/morphhealth_service.dart';
import '../../../core/util/local_date.dart';
import '../../controller.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import 'custom_food_editor.dart';
import 'log_food_screen.dart';

/// Find a food by name or barcode (on this device and in Open Food Facts),
/// or pick one from favorites, recent foods or own foods.
class FoodSearchScreen extends StatefulWidget {
  const FoodSearchScreen({super.key, required this.date, required this.meal});

  final LocalDate date;
  final Meal meal;

  @override
  State<FoodSearchScreen> createState() => _FoodSearchScreenState();
}

class _FoodSearchScreenState extends State<FoodSearchScreen> {
  final _query = TextEditingController();
  String _text = '';

  // Online name search state.
  String? _onlineQuery;
  final List<OnlineFood> _online = [];
  OffSearchPage? _lastPage;
  bool _loading = false;
  String? _errorCode;

  // Barcode lookup state.
  FoodLookupResult? _lookup;

  bool get _isBarcode => Gtin.looksLikeBarcode(_text);

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    setState(() {
      _text = value.trim();
      if (_onlineQuery != null && _onlineQuery != _text) {
        _onlineQuery = null;
        _online.clear();
        _lastPage = null;
        _errorCode = null;
      }
      _lookup = null;
    });
  }

  Future<void> _submit() async {
    if (_text.isEmpty) return;
    if (_isBarcode) {
      await _lookupBarcode();
    } else {
      await _searchOnline(reset: true);
    }
  }

  Future<void> _searchOnline({required bool reset}) async {
    final app = context.appRead;
    if (!app.settings.onlineFoodSearch) {
      setState(() => _errorCode = 'online_disabled');
      return;
    }
    final query = _text;
    final page = reset ? 1 : (_lastPage?.page ?? 0) + 1;
    setState(() {
      _loading = true;
      _errorCode = null;
      if (reset) {
        _online.clear();
        _lastPage = null;
      }
      _onlineQuery = query;
    });
    try {
      final result = await app.service.searchOnline(query, page);
      if (!mounted || _onlineQuery != query) return;
      setState(() {
        _lastPage = result;
        _online.addAll(result.items);
      });
    } on FoodApiException catch (e) {
      if (mounted) setState(() => _errorCode = e.code);
    } on DomainException catch (e) {
      if (mounted) setState(() => _errorCode = e.code);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _lookupBarcode() async {
    final app = context.appRead;
    setState(() {
      _loading = true;
      _errorCode = null;
      _lookup = null;
    });
    try {
      final result = await app.service.lookupBarcode(_text);
      if (!mounted) return;
      setState(() {
        _lookup = result;
        _errorCode = result.onlineError?.code ??
            (!result.onlineEnabled && result.local.isEmpty ? 'online_disabled' : null);
      });
    } on DomainException catch (e) {
      if (mounted) setState(() => _errorCode = e.code);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  /// Opens the logging screen; returns to the diary once an entry was added.
  Future<void> _open(
    FoodProfile profile, {
    String? foodRef,
    bool fetchDetails = false,
    double? amount,
    AmountUnit? unit,
  }) async {
    final added = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => LogFoodScreen.create(
          profile: profile,
          foodRef: foodRef,
          date: widget.date,
          meal: widget.meal,
          fetchDetails: fetchDetails,
          initialAmount: amount,
          initialUnit: unit,
        ),
      ),
    );
    if (added == true && mounted) Navigator.of(context).pop();
  }

  Future<void> _createCustom() async {
    final food = await Navigator.of(context).push<Food>(
      MaterialPageRoute(
        builder: (_) => CustomFoodEditor(
          initialName: _isBarcode ? null : (_text.isEmpty ? null : _text),
          initialBarcode: _isBarcode ? Gtin.sanitize(_text) : null,
        ),
      ),
    );
    if (food != null && mounted) _open(food.profile, foodRef: food.id);
  }

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final s = app.s;
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(s.addFood),
              Text(
                '${s.mealName(widget.meal)} · ${app.fmt.weekdayDayMonth(widget.date)}',
                style: context.text.bodySmall,
              ),
            ],
          ),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(124),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: TextField(
                    controller: _query,
                    autofocus: true,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: s.foodSearchHint,
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: _text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: s.clear,
                              icon: const Icon(Icons.clear),
                              onPressed: () {
                                _query.clear();
                                _onChanged('');
                              },
                            ),
                    ),
                    onChanged: _onChanged,
                    onSubmitted: (_) => _submit(),
                  ),
                ),
                TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  tabs: [
                    Tab(text: s.tabSearch),
                    Tab(text: s.tabFavorites),
                    Tab(text: s.tabRecent),
                    Tab(text: s.tabMyFoods),
                  ],
                ),
              ],
            ),
          ),
        ),
        body: TabBarView(
          children: [
            _searchTab(context),
            _favoritesTab(context),
            _recentTab(context),
            _customTab(context),
          ],
        ),
      ),
    );
  }

  Widget _searchTab(BuildContext context) {
    final app = context.app;
    final s = app.s;
    final children = <Widget>[];
    if (_text.isEmpty) {
      children.add(EmptyHint(s.foodSearchHint, icon: Icons.search));
    } else if (_isBarcode) {
      final code = Gtin.sanitize(_text)!;
      children.add(
        Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.icon(
            onPressed: _loading ? null : _lookupBarcode,
            icon: const Icon(Icons.qr_code_2),
            label: Text(s.lookupBarcode(code)),
          ),
        ),
      );
      if (Gtin.hasValidCheckDigit(code) == false) {
        children.add(Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: EmptyHint(s.barcodeCheckDigitWarning, icon: Icons.info_outline),
        ));
      }
      final lookup = _lookup;
      if (lookup != null) {
        for (final hit in lookup.local) {
          children.add(_FoodTile(
            profile: hit.profile,
            isFavorite: hit.isFavorite,
            onTap: () => _open(hit.profile, foodRef: hit.food?.id),
          ));
        }
        if (lookup.online != null) {
          children.add(_FoodTile(
            profile: lookup.online!.profile,
            quantityLabel: lookup.online!.quantityLabel,
            onTap: () => _open(lookup.online!.profile),
          ));
        } else if (lookup.onlineEnabled && lookup.onlineError == null && lookup.local.isEmpty) {
          children.add(Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: EmptyHint(s.barcodeNotFound, icon: Icons.search_off),
          ));
        }
      }
    } else {
      final local = app.service.searchLocalFoods(_text);
      if (local.isNotEmpty) {
        children.add(ListHeader(s.localResults));
        for (final hit in local) {
          children.add(_FoodTile(
            profile: hit.profile,
            isFavorite: hit.isFavorite,
            onTap: () => _open(
              hit.profile,
              foodRef: hit.food?.id ?? hit.lastEntry?.foodRef,
              amount: hit.lastEntry?.amount,
              unit: hit.lastEntry?.unit,
            ),
          ));
        }
      }
      children.add(ListHeader(
        s.onlineResults,
        trailing: _lastPage == null ? null : Text(s.resultCount(_lastPage!.count), style: context.text.bodySmall),
      ));
      if (_onlineQuery == null && !_loading) {
        children.add(Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: FilledButton.tonalIcon(
            onPressed: () => _searchOnline(reset: true),
            icon: const Icon(Icons.travel_explore),
            label: Text(s.searchOnline),
          ),
        ));
      }
      for (final food in _online) {
        children.add(_FoodTile(
          profile: food.profile,
          quantityLabel: food.quantityLabel,
          onTap: () => _open(food.profile, fetchDetails: true),
        ));
      }
      if (_lastPage != null && _online.isEmpty && !_loading) {
        children.add(Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: EmptyHint(s.noResults),
        ));
      }
      if (_lastPage != null && _lastPage!.hasMore && !_loading) {
        children.add(Padding(
          padding: const EdgeInsets.all(16),
          child: OutlinedButton(onPressed: () => _searchOnline(reset: false), child: Text(s.loadMore)),
        ));
      }
    }
    if (_loading) {
      children.add(Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Semantics(label: s.searching, child: const CircularProgressIndicator()),
        ),
      ));
    }
    if (_errorCode != null) {
      children.add(Padding(
        padding: const EdgeInsets.all(16),
        child: Card(
          semanticContainer: false,
          color: context.scheme.errorContainer,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(s.foodApiError(_errorCode!), style: TextStyle(color: context.scheme.onErrorContainer)),
                if (_errorCode != 'online_disabled')
                  TextButton(onPressed: _submit, child: Text(s.retry)),
              ],
            ),
          ),
        ),
      ));
    }
    children.add(Padding(
      padding: const EdgeInsets.all(16),
      child: OutlinedButton.icon(
        onPressed: _createCustom,
        icon: const Icon(Icons.add),
        label: Text(s.createCustomFood),
      ),
    ));
    if (app.settings.onlineFoodSearch) {
      children.add(Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        child: Text(s.offAttribution, style: context.text.bodySmall?.copyWith(color: context.scheme.onSurfaceVariant)),
      ));
    }
    return ListView(children: children);
  }

  Widget _favoritesTab(BuildContext context) {
    final app = context.app;
    final foods = app.service.favoriteFoods();
    if (foods.isEmpty) {
      return ListView(padding: const EdgeInsets.all(16), children: [EmptyHint(app.s.noFavorites, icon: Icons.star_outline)]);
    }
    return ListView(
      children: [
        for (final f in foods)
          _FoodTile(profile: f.profile, isFavorite: true, onTap: () => _open(f.profile, foodRef: f.id)),
      ],
    );
  }

  Widget _recentTab(BuildContext context) {
    final app = context.app;
    final recent = app.service.recentFoods(limit: 60);
    if (recent.isEmpty) {
      return ListView(padding: const EdgeInsets.all(16), children: [EmptyHint(app.s.noRecent, icon: Icons.history)]);
    }
    return ListView(
      children: [
        for (final r in recent)
          _FoodTile(
            profile: r.profile,
            isFavorite: r.isFavorite,
            subtitleExtra: r.lastEntry == null ? null : app.fmt.dayMonth(r.lastEntry!.date),
            onTap: () => _open(
              r.profile,
              foodRef: r.food?.id ?? r.lastEntry?.foodRef,
              amount: r.lastEntry?.amount,
              unit: r.lastEntry?.unit,
            ),
          ),
      ],
    );
  }

  Widget _customTab(BuildContext context) {
    final app = context.app;
    final s = app.s;
    final foods = app.service.customFoods();
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton.tonalIcon(
            onPressed: _createCustom,
            icon: const Icon(Icons.add),
            label: Text(s.createCustomFood),
          ),
        ),
        if (foods.isEmpty) Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: EmptyHint(s.noCustomFoods)),
        for (final f in foods)
          _FoodTile(
            profile: f.profile,
            isFavorite: f.favorite,
            onTap: () => _open(f.profile, foodRef: f.id),
            trailing: IconButton(
              tooltip: s.editCustomFood,
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute<Food>(builder: (_) => CustomFoodEditor(food: f)),
              ),
            ),
          ),
      ],
    );
  }
}

class _FoodTile extends StatelessWidget {
  const _FoodTile({
    required this.profile,
    required this.onTap,
    this.isFavorite = false,
    this.quantityLabel,
    this.subtitleExtra,
    this.trailing,
  });

  final FoodProfile profile;
  final VoidCallback onTap;
  final bool isFavorite;
  final String? quantityLabel;
  final String? subtitleExtra;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final fmt = context.fmt;
    final kcal = profile.nutrients['energy_kcal'];
    final parts = [
      ?profile.brand,
      ?quantityLabel,
      kcal == null ? s.noNutritionData : '${fmt.integer(kcal)} kcal ${s.perHundred(profile.basis)}',
      ?subtitleExtra,
    ];
    return ListTile(
      leading: ExcludeSemantics(
        child: Icon(
          profile.source == FoodSource.custom ? Icons.edit_note : Icons.inventory_2_outlined,
          color: context.colors.nutrition,
        ),
      ),
      title: Row(
        children: [
          Flexible(child: Text(profile.name)),
          if (isFavorite) ...[
            const SizedBox(width: 6),
            Icon(Icons.star, size: 16, color: context.scheme.tertiary, semanticLabel: s.favorite),
          ],
        ],
      ),
      subtitle: Text(parts.join(' · ')),
      onTap: onTap,
      trailing: trailing,
    );
  }
}
