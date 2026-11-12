library morphhealth.ui.local_foods_page;

import 'package:flutter/material.dart';
import 'package:morphhealth/core/model/food.dart';
import 'package:morphhealth/core/model/nutrients.dart';
import 'package:morphhealth/core/repository.dart';
import 'package:morphhealth/l10n/app_localizations.dart';
import 'package:morphhealth/ui/edit_local_food_page.dart';

class LocalFoodsPage extends StatefulWidget {
  final HealthRepository repository;
  const LocalFoodsPage({super.key, required this.repository});

  @override
  State<LocalFoodsPage> createState() => _LocalFoodsPageState();
}

class _LocalFoodsPageState extends State<LocalFoodsPage> {
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final foods = widget.repository.localFoods..sort((a, b) => a.name.compareTo(b.name));
    return Scaffold(
      appBar: AppBar(title: Text(l.msg('localFoods'))),
      body: foods.isEmpty
          ? Center(child: Text(l.msg('noEntries')))
          : ListView.builder(
              itemCount: foods.length,
              itemBuilder: (_, i) {
                final f = foods[i];
                return Dismissible(
                  key: ValueKey(f.id),
                  onDismissed: (_) => widget.repository.deleteLocalFood(f.id),
                  background: const ColoredBox(color: Colors.red),
                  child: ListTile(
                    title: Text(f.name),
                    subtitle: Text(f.brand ?? ''),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () => _edit(context, f),
                  ),
                );
              },
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _edit(context, null),
        child: const Icon(Icons.add),
      ),
    );
  }

  Future<void> _edit(BuildContext context, LocalFood? food) async {
    final saved = await Navigator.of(context).push<bool>(MaterialPageRoute(
      builder: (_) => EditLocalFoodPage(repository: widget.repository, food: food),
    ));
    if (saved == true) setState(() {});
  }
}