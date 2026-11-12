library morphhealth.ui.food_search_page;

import 'package:flutter/material.dart';
import 'package:morphhealth/core/model/food.dart';
import 'package:morphhealth/core/repository.dart';
import 'package:morphhealth/l10n/app_localizations.dart';

class FoodPickerPage extends StatefulWidget {
  final HealthRepository repository;
  const FoodPickerPage({super.key, required this.repository});

  @override
  State<FoodPickerPage> createState() => _FoodPickerPageState();
}

class _FoodPickerPageState extends State<FoodPickerPage> {
  final _query = TextEditingController();
  final _barcode = TextEditingController();
  final List<OffProduct> _results = [];
  bool _searching = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l.msg('food'))),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          ListTile(
            title: const Text('Barcode'),
            subtitle: Text(l.msg('barcode')),
            trailing: SizedBox(
              width: 160,
              child: TextField(
                controller: _barcode,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(isDense: true, border: OutlineInputBorder()),
                onSubmitted: (_) => _lookupBarcode(),
              ),
            ),
            onTap: _lookupBarcode,
          ),
          const SizedBox(height: 12),
          ListTile(
            title: Text(l.msg('search')),
            trailing: SizedBox(
              width: 200,
              child: TextField(
                controller: _query,
                decoration: const InputDecoration(isDense: true, border: OutlineInputBorder(), hintText: 'z. B. Haferflocken'),
                onSubmitted: (_) => _search(),
              ),
            ),
            onTap: _search,
          ),
          if (_searching) const LinearProgressIndicator(),
          if (_results.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(l.msg('openFoodFacts'), style: Theme.of(context).textTheme.titleSmall),
            ..._results.map((p) => _ProductTile(product: p, onTap: () => Navigator.pop(context, <String, dynamic>{'food': p}))),
          ],
          const SizedBox(height: 20),
          Text(l.msg('localFoods'), style: Theme.of(context).textTheme.titleSmall),
          ...widget.repository.localFoods.map((f) => ListTile(
            title: Text(f.name),
            subtitle: f.brand != null ? Text(f.brand!) : null,
            onTap: () => Navigator.pop(context, <String, dynamic>{'food': f}),
          )),
          if (widget.repository.localFoods.isEmpty)
            Padding(
              padding: const EdgeInsets.all(8),
              child: Text(l.msg('noEntries'), style: Theme.of(context).textTheme.bodySmall),
            ),
        ],
      ),
    );
  }

  Future<void> _search() async {
    if (_query.text.trim().isEmpty) return;
    setState(() => _searching = true);
    try {
      final result = await widget.repository.foodClient!.search(_query.text.trim());
      setState(() {
        _results.clear();
        _results.addAll(result.products);
        _searching = false;
      });
    } on Exception {
      setState(() => _searching = false);
    }
  }

  Future<void> _lookupBarcode() async {
    if (_barcode.text.trim().isEmpty) return;
    setState(() => _searching = true);
    try {
      final product = await widget.repository.foodClient!.lookup(_barcode.text.trim());
      setState(() => _searching = false);
      if (product == null) {
        _show(context, 'Nicht gefunden', 'Kein Produkt für diesen Barcode.');
      } else {
        widget.repository.cacheProduct(product);
        Navigator.pop(context, <String, dynamic>{'food': product});
      }
    } on Exception {
      setState(() => _searching = false);
      _show(context, l10nOf(context).msg('error'), 'Suche fehlgeschlagen');
    }
  }

  void _show(BuildContext context, String title, String message) {
    showDialog(context: context, builder: (_) => AlertDialog(title: Text(title), content: Text(message), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))]));
  }

  AppLocalizations l10nOf(BuildContext c) => AppLocalizations.of(c)!;
}

class _ProductTile extends StatelessWidget {
  final OffProduct product;
  final VoidCallback onTap;
  const _ProductTile({required this.product, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: Text(product.name),
      subtitle: Text('${product.brand ?? '-'} · ${product.id}'),
      trailing: const Icon(Icons.arrow_forward_ios),
      onTap: onTap,
    );
  }
}