import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:morphhealth_core/morphhealth_core.dart';

import '../widgets/common.dart';
import 'food_form_screen.dart';
import 'hydration.dart';
import 'intake_screen.dart';

/// Asks for the user's consent to send search texts and barcodes to Open
/// Food Facts, unless it has been given. Returns true if the lookup may run.
Future<bool> ensureOnlineSearch(BuildContext context) async {
  final app = context.appRead;
  if (app.onlineSearchEnabled) return true;
  final l = context.l;
  final ok = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(l.onlineConsentTitle),
      content: SingleChildScrollView(child: Text(l.onlineConsentBody)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l.onlineNotNow),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(l.onlineEnable),
        ),
      ],
    ),
  );
  if (ok != true) {
    // "Not now" is remembered as a decision, so the app does not keep asking
    // on its own; the search button offers the choice again.
    if (app.settings.onlineFoodSearch == OnlineFoodSearch.ask) {
      await app.updateSettings(
        (s) => s.copyWith(onlineFoodSearch: OnlineFoodSearch.disabled),
      );
    }
    return false;
  }
  await app.updateSettings(
    (s) => s.copyWith(onlineFoodSearch: OnlineFoodSearch.enabled),
  );
  return true;
}

/// Choosing a food to log: recent foods, favorites, own foods, a search in
/// the local foods and in Open Food Facts, and barcode entry.
class AddFoodScreen extends StatefulWidget {
  final Day day;
  final Meal? meal;

  const AddFoodScreen({super.key, required this.day, this.meal});

  static Future<void> open(
    BuildContext context, {
    required Day day,
    Meal? meal,
  }) => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => AddFoodScreen(day: day, meal: meal),
    ),
  );

  @override
  State<AddFoodScreen> createState() => _AddFoodScreenState();
}

enum _ListTab { recent, favorites, own }

class _AddFoodScreenState extends State<AddFoodScreen> {
  final _query = TextEditingController();
  final _focus = FocusNode();
  String _text = '';
  _ListTab _tab = _ListTab.recent;

  // Online search state.
  String? _onlineQuery;
  List<CatalogProduct> _results = const [];
  int _total = 0;
  int _page = 0;
  bool _hasMore = false;
  bool _loading = false;
  bool _loadingMore = false;
  String? _errorCode;
  int _request = 0;

  @override
  void dispose() {
    _query.dispose();
    _focus.dispose();
    super.dispose();
  }

  String get _normalized => _text.trim().replaceAll(RegExp(r'\s+'), ' ');

  bool get _looksLikeBarcode =>
      RegExp(r'^[0-9][0-9 \-]{5,16}[0-9]$').hasMatch(_text.trim()) &&
      RegExp(
        r'^[0-9]{7,14}$',
      ).hasMatch(_text.replaceAll(RegExp(r'[\s\-]'), ''));

  Future<void> _openLocal(Food food) async {
    final saved = await IntakeScreen.open(
      context,
      food: food,
      day: widget.day,
      meal: widget.meal,
    );
    if (saved && mounted) Navigator.of(context).pop();
  }

  Future<void> _openProduct(CatalogProduct listed) async {
    final app = context.appRead;
    final code = normalizeBarcode(listed.barcode) ?? listed.barcode;
    final kept = app.data.foodByBarcode(code, source: FoodSource.openFoodFacts);
    if (kept != null && !kept.archived) {
      return _openLocal(kept);
    }
    // The product endpoint has the complete, current data of one product;
    // if it cannot be reached the search result itself is used.
    var product = listed;
    try {
      final lookup = await withProgress(
        context,
        context.l.loadingProduct,
        () => app.foodClient.lookup(listed.barcode),
      );
      if (lookup.found) product = lookup.product!;
    } on FoodApiException {
      // Keep the search result.
    }
    if (!mounted) return;
    final saved = await IntakeScreen.open(
      context,
      product: product,
      day: widget.day,
      meal: widget.meal,
    );
    if (saved && mounted) Navigator.of(context).pop();
  }

  Future<void> _quickLog(RecentFood recent) async {
    final repo = context.appRead.repository;
    final l = context.l;
    final last = recent.lastEntry;
    final at = defaultEntryTime(context, widget.day);
    IntakeEntry? created;
    final ok = await guarded(context, () async {
      created = await repo.logIntake(
        foodId: recent.food.id,
        amount: last.amount,
        unit: last.unit,
        portionSize: last.portionSize,
        at: at,
        meal:
            widget.meal ??
            (widget.day == context.appRead.today
                ? Meal.suggestFor(at)
                : last.meal),
      );
    });
    if (ok && mounted) {
      showSnack(
        context,
        l.entryRepeated(recent.food.name),
        onUndo: () => repo.deleteIntake(created!.id),
      );
    }
  }

  Future<void> _createOwn({String? barcode}) async {
    final food = await Navigator.of(context).push<Food>(
      MaterialPageRoute(
        builder: (_) => FoodFormScreen(
          initialName: barcode == null && !_looksLikeBarcode
              ? _normalized
              : null,
          initialBarcode: barcode,
        ),
      ),
    );
    if (food != null && mounted) await _openLocal(food);
  }

  // ------------------------------------------------------------- online

  Future<void> _searchOnline() async {
    final q = _normalized;
    if (q.length < 2) {
      showSnack(context, context.l.onlineSearchMinChars);
      return;
    }
    if (!await ensureOnlineSearch(context) || !mounted) return;
    _focus.unfocus();
    final request = ++_request;
    setState(() {
      _onlineQuery = q;
      _results = const [];
      _total = 0;
      _page = 0;
      _hasMore = false;
      _errorCode = null;
      _loading = true;
    });
    await _loadPage(q, 1, request);
  }

  Future<void> _loadMore() async {
    final q = _onlineQuery;
    if (q == null || _loadingMore || !_hasMore) return;
    final request = ++_request;
    setState(() {
      _loadingMore = true;
      _errorCode = null;
    });
    await _loadPage(q, _page + 1, request);
  }

  Future<void> _loadPage(String q, int page, int request) async {
    final client = context.appRead.foodClient;
    try {
      final result = await client.search(q, page: page);
      if (!mounted || request != _request) return;
      setState(() {
        final seen = {for (final p in _results) p.barcode};
        _results = [
          ..._results,
          for (final p in result.products)
            if (seen.add(p.barcode)) p,
        ];
        _total = result.totalCount;
        _page = result.page;
        _hasMore = result.hasMore && result.products.isNotEmpty;
        _loading = false;
        _loadingMore = false;
      });
    } on FoodApiException catch (e) {
      if (!mounted || request != _request) return;
      setState(() {
        _errorCode = e.code;
        _loading = false;
        _loadingMore = false;
      });
    }
  }

  Future<void> _barcodeDialog() async {
    final code = await showDialog<String>(
      context: context,
      builder: (_) => const _BarcodeDialog(),
    );
    if (code != null && mounted) await _lookupBarcode(code);
  }

  Future<void> _lookupBarcode(String input) async {
    final l = context.l;
    final app = context.appRead;
    final digits = input.replaceAll(RegExp(r'[\s\-]'), '');
    final normalized = normalizeBarcode(digits);
    if (normalized == null || !RegExp(r'^[0-9]{7,14}$').hasMatch(digits)) {
      showSnack(context, l.barcodeInvalid);
      return;
    }
    // A product that is already kept needs no connection.
    final kept = app.data.foodByBarcode(normalized);
    if (kept != null && !kept.archived) return _openLocal(kept);

    if (!await ensureOnlineSearch(context) || !mounted) return;
    final FoodLookup lookup;
    try {
      lookup = await withProgress(
        context,
        l.loadingProduct,
        () => app.foodClient.lookup(digits),
      );
    } on FoodApiException catch (e) {
      if (mounted) showSnack(context, l.foodError(e.code));
      return;
    }
    if (!mounted) return;
    if (lookup.found) {
      final saved = await IntakeScreen.open(
        context,
        product: lookup.product,
        day: widget.day,
        meal: widget.meal,
      );
      if (saved && mounted) Navigator.of(context).pop();
      return;
    }
    final create = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.barcode),
        content: SingleChildScrollView(
          child: Text(
            [
              lookup.reason == 'other_product_type'
                  ? l.barcodeOtherType
                  : l.barcodeNotFound(digits),
              if (!hasValidGtinCheckDigit(digits) &&
                  const [8, 12, 13, 14].contains(digits.length))
                l.barcodeCheckDigit,
            ].join('\n\n'),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l.close),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l.createOwnWithBarcode),
          ),
        ],
      ),
    );
    if (create == true && mounted) await _createOwn(barcode: digits);
  }

  // ---------------------------------------------------------------- UI

  String _foodSubtitle(Food f) {
    final l = context.l;
    final fmt = context.fmt;
    final kcal = f.nutrients[Nutrients.energy];
    return [
      if (f.brand != null) f.brand!,
      kcal == null
          ? l.noNutritionData
          : l.kcalPer(fmt.kcalNumber(kcal), fmt.basis(f.basis)),
    ].join(' · ');
  }

  Widget _foodTile(Food f, {RecentFood? recent}) {
    final l = context.l;
    final fmt = context.fmt;
    final amount = recent == null
        ? null
        : fmt.intakeAmount(recent.lastEntry, f);
    return ListTile(
      leading: Icon(
        f.favorite ? Icons.star : (f.isCustom ? Icons.edit_note : Icons.public),
        color: f.favorite
            ? context.colors.primary
            : context.colors.onSurfaceVariant,
      ),
      title: Text(f.name),
      subtitle: Text(
        amount == null ? _foodSubtitle(f) : '$amount · ${_foodSubtitle(f)}',
      ),
      trailing: recent == null
          ? null
          : IconButton(
              tooltip: l.logAgainSemantics(f.name, amount!),
              icon: const Icon(Icons.add_circle_outline),
              onPressed: () => _quickLog(recent),
            ),
      onTap: () => _openLocal(f),
    );
  }

  Widget _productTile(CatalogProduct p) {
    final l = context.l;
    final fmt = context.fmt;
    final kcal = p.nutrients[Nutrients.energy];
    return ListTile(
      leading: Icon(Icons.public, color: context.colors.onSurfaceVariant),
      title: Text(p.hasName ? p.name : l.noNameProduct),
      subtitle: Text(
        [
          if (p.brand != null) p.brand!,
          if (p.quantity != null) p.quantity!,
          kcal == null
              ? l.noNutritionData
              : l.kcalPer(fmt.kcalNumber(kcal), fmt.basis(p.basis)),
        ].join(' · '),
      ),
      onTap: () => _openProduct(p),
    );
  }

  List<Widget> _browseLists() {
    final l = context.l;
    final data = context.app.data;
    final List<Widget> tiles;
    final String empty;
    switch (_tab) {
      case _ListTab.recent:
        tiles = [
          for (final r in recentFoods(data, limit: 40))
            _foodTile(r.food, recent: r),
        ];
        empty = l.emptyRecent;
      case _ListTab.favorites:
        tiles = [
          for (final f in searchLocalFoods(data, '', favoritesOnly: true))
            _foodTile(f),
        ];
        empty = l.emptyFavorites;
      case _ListTab.own:
        tiles = [
          for (final f in searchLocalFoods(data, '', customOnly: true))
            _foodTile(f),
        ];
        empty = l.emptyOwn;
    }
    return [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
        child: SizedBox(
          width: double.infinity,
          child: SegmentedButton<_ListTab>(
            showSelectedIcon: false,
            segments: [
              ButtonSegment(value: _ListTab.recent, label: Text(l.tabRecent)),
              ButtonSegment(
                value: _ListTab.favorites,
                label: Text(l.tabFavorites),
              ),
              ButtonSegment(value: _ListTab.own, label: Text(l.tabOwn)),
            ],
            selected: {_tab},
            onSelectionChanged: (s) => setState(() => _tab = s.first),
          ),
        ),
      ),
      if (tiles.isEmpty)
        EmptyHint(icon: Icons.restaurant_outlined, text: empty)
      else
        ...tiles,
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: OutlinedButton.icon(
          icon: const Icon(Icons.add),
          label: Text(l.newOwnFood),
          onPressed: _createOwn,
        ),
      ),
    ];
  }

  List<Widget> _searchLists() {
    final l = context.l;
    final app = context.app;
    final local = searchLocalFoods(app.data, _text);
    final q = _normalized;
    final showResults = _onlineQuery == q;
    return [
      SectionTitle(
        l.sectionLocal,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      ),
      if (local.isEmpty)
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
          child: Text(
            l.noLocalMatches,
            style: context.texts.bodyMedium?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
        )
      else
        for (final f in local) _foodTile(f),
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: TextButton.icon(
            icon: const Icon(Icons.add),
            label: Text(l.newOwnFood),
            onPressed: _createOwn,
          ),
        ),
      ),
      const Divider(),
      SectionTitle(
        l.sectionOnline,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        trailing: showResults && !_loading && _errorCode == null
            ? Text(l.hits(_total), style: context.texts.bodySmall)
            : null,
      ),
      if (_looksLikeBarcode)
        ListTile(
          leading: const Icon(Icons.qr_code_2),
          title: Text('${l.barcode} ${_text.trim()}'),
          subtitle: Text(l.lookUp),
          onTap: () => _lookupBarcode(_text),
        ),
      if (!showResults) ...[
        if (app.settings.onlineFoodSearch == OnlineFoodSearch.disabled)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Text(
              l.onlineDisabledInfo,
              style: context.texts.bodyMedium?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: FilledButton.tonalIcon(
            icon: const Icon(Icons.search),
            label: Text(l.searchOnlineFor(q), textAlign: TextAlign.center),
            onPressed: _searchOnline,
          ),
        ),
      ] else if (_loading)
        Padding(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: Column(
              children: [
                const CircularProgressIndicator(),
                const SizedBox(height: 12),
                Text(l.searching),
              ],
            ),
          ),
        )
      else ...[
        for (final p in _results) _productTile(p),
        if (_errorCode != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l.foodError(_errorCode!),
                  style: TextStyle(color: context.colors.error),
                ),
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  icon: const Icon(Icons.refresh),
                  label: Text(l.retry),
                  onPressed: _results.isEmpty ? _searchOnline : _loadMore,
                ),
              ],
            ),
          )
        else if (_results.isEmpty)
          EmptyHint(icon: Icons.search_off, text: l.noOnlineResults)
        else if (_hasMore)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: _loadingMore
                ? const Center(child: CircularProgressIndicator())
                : OutlinedButton(onPressed: _loadMore, child: Text(l.loadMore)),
          ),
      ],
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
        child: Text(l.offAttribution, style: context.texts.bodySmall),
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final fmt = context.fmt;
    final meal = widget.meal;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l.addFood),
            Text(
              meal == null
                  ? fmt.dayRelative(widget.day)
                  : '${l.meal(meal)} · ${fmt.dayRelative(widget.day)}',
              style: context.texts.bodySmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: l.enterBarcode,
            icon: const Icon(Icons.qr_code_2),
            onPressed: _barcodeDialog,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: TextField(
                enableIMEPersonalizedLearning: false,
                controller: _query,
                focusNode: _focus,
                textInputAction: TextInputAction.search,
                onChanged: (v) => setState(() => _text = v),
                onSubmitted: (_) =>
                    _looksLikeBarcode ? _lookupBarcode(_text) : _searchOnline(),
                decoration: InputDecoration(
                  labelText: l.searchFoodHint,
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _text.isEmpty
                      ? null
                      : IconButton(
                          tooltip: l.clearSearch,
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _query.clear();
                            setState(() => _text = '');
                          },
                        ),
                ),
              ),
            ),
            Expanded(
              child: ListView(
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.only(bottom: 24),
                children: _text.trim().isEmpty
                    ? _browseLists()
                    : _searchLists(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BarcodeDialog extends StatefulWidget {
  const _BarcodeDialog();

  @override
  State<_BarcodeDialog> createState() => _BarcodeDialogState();
}

class _BarcodeDialogState extends State<_BarcodeDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final digits = _controller.text.replaceAll(RegExp(r'[\s\-]'), '');
    if (!RegExp(r'^[0-9]{7,14}$').hasMatch(digits)) {
      setState(() => _error = context.l.barcodeInvalid);
      return;
    }
    Navigator.of(context).pop(digits);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    return AlertDialog(
      title: Text(l.enterBarcode),
      content: TextField(
        enableIMEPersonalizedLearning: false,
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        inputFormatters: [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9 \-]')),
          LengthLimitingTextInputFormatter(20),
        ],
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          labelText: l.barcode,
          helperText: l.barcodeHelper,
          errorText: _error,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l.lookUp)),
      ],
    );
  }
}
