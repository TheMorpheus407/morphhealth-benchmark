import 'package:flutter/material.dart';
import 'package:morphhealth_core/morphhealth_core.dart';

import '../widgets/common.dart';
import 'add_food_screen.dart';
import 'food_form_screen.dart';
import 'nutrient_table.dart';

/// The user's foods: own foods (editable) and products kept from Open Food
/// Facts (viewable, refreshable, removable).
class MyFoodsScreen extends StatefulWidget {
  const MyFoodsScreen({super.key});

  @override
  State<MyFoodsScreen> createState() => _MyFoodsScreenState();
}

class _MyFoodsScreenState extends State<MyFoodsScreen> {
  final _query = TextEditingController();
  String _text = '';

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final fmt = context.fmt;
    final foods = searchLocalFoods(context.app.data, _text, limit: 500);
    return Scaffold(
      appBar: AppBar(title: Text(l.myFoods)),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'foods-add',
        icon: const Icon(Icons.add),
        label: Text(l.foodNew),
        onPressed: () => Navigator.of(
          context,
        ).push<Food>(MaterialPageRoute(builder: (_) => const FoodFormScreen())),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: TextField(
                enableIMEPersonalizedLearning: false,
                controller: _query,
                onChanged: (v) => setState(() => _text = v),
                decoration: InputDecoration(
                  labelText: l.searchFoodHint,
                  prefixIcon: const Icon(Icons.search),
                ),
              ),
            ),
            Expanded(
              child: foods.isEmpty
                  ? SingleChildScrollView(
                      child: EmptyHint(
                        icon: Icons.kitchen_outlined,
                        text: _text.trim().isEmpty
                            ? l.emptyOwn
                            : l.noLocalMatches,
                      ),
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.only(bottom: 168),
                      itemCount: foods.length,
                      itemBuilder: (context, i) {
                        final f = foods[i];
                        final kcal = f.nutrients[Nutrients.energy];
                        return ListTile(
                          leading: Icon(
                            f.favorite
                                ? Icons.star
                                : (f.isCustom ? Icons.edit_note : Icons.public),
                            color: f.favorite
                                ? context.colors.primary
                                : context.colors.onSurfaceVariant,
                          ),
                          title: Text(f.name),
                          subtitle: Text(
                            [
                              if (f.brand != null) f.brand!,
                              f.isCustom ? l.sourceOwn : l.sourceOff,
                              if (kcal != null)
                                l.kcalPer(
                                  fmt.kcalNumber(kcal),
                                  fmt.basis(f.basis),
                                ),
                            ].join(' · '),
                          ),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.of(context).push<void>(
                            MaterialPageRoute(
                              builder: (_) => f.isCustom
                                  ? FoodFormScreen(food: f)
                                  : FoodDetailScreen(foodId: f.id),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Shows a product kept from Open Food Facts with all its nutrient values.
class FoodDetailScreen extends StatelessWidget {
  final String foodId;

  const FoodDetailScreen({super.key, required this.foodId});

  Future<void> _refresh(BuildContext context, Food food) async {
    final l = context.l;
    final app = context.appRead;
    final barcode = food.barcode;
    if (barcode == null) return;
    if (!await ensureOnlineSearch(context) || !context.mounted) return;
    try {
      final lookup = await withProgress(
        context,
        l.loadingProduct,
        () => app.foodClient.lookup(barcode),
      );
      if (!context.mounted) return;
      if (!lookup.found) {
        showSnack(context, l.barcodeNotFound(barcode));
        return;
      }
      await app.repository.adoptProduct(lookup.product!);
      if (context.mounted) showSnack(context, l.refreshed);
    } on Object catch (e) {
      if (context.mounted) showSnack(context, describeError(context, e));
    }
  }

  Future<void> _delete(BuildContext context, Food food) async {
    final l = context.l;
    final repo = context.appRead.repository;
    final sure = await confirm(
      context,
      title: l.deleteFoodConfirm(food.name),
      action: l.delete,
      destructive: true,
    );
    if (!sure || !context.mounted) return;
    FoodDeletion? outcome;
    final ok = await guarded(context, () async {
      outcome = await repo.deleteFood(food.id);
    });
    if (!ok || !context.mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          duration: const Duration(seconds: 6),
          content: Text(
            outcome == FoodDeletion.archived ? l.foodArchived : l.foodDeleted,
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final fmt = context.fmt;
    final app = context.app;
    final food = app.data.food(foodId);
    if (food == null) {
      return Scaffold(appBar: AppBar(), body: const SizedBox.shrink());
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(food.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        actions: [
          IconButton(
            tooltip: food.favorite ? l.favoriteRemove : l.favoriteAdd,
            isSelected: food.favorite,
            icon: const Icon(Icons.star_outline),
            selectedIcon: const Icon(Icons.star),
            onPressed: () => guarded(
              context,
              () => app.repository.setFavorite(food.id, !food.favorite),
            ),
          ),
          IconButton(
            tooltip: l.delete,
            icon: const Icon(Icons.delete_outline),
            onPressed: () => _delete(context, food),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Text(
              [
                if (food.brand != null) food.brand!,
                if (food.packageQuantity != null) food.packageQuantity!,
                if (food.barcode != null) '${l.barcode} ${food.barcode}',
              ].join(' · '),
              style: context.texts.bodyMedium?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(l.sourceOff, style: context.texts.bodySmall),
            if (food.servingSize != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  l.portionEquals(
                    '${fmt.adaptive(food.servingSize!)} ${food.basis.unit}'
                    '${food.servingLabel == null ? '' : ' (${food.servingLabel})'}',
                  ),
                ),
              ),
            if (food.prepared)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(l.preparedHint),
              ),
            const SizedBox(height: 12),
            MhCard(
              title: '${l.allNutrients} ${l.per(fmt.basis(food.basis))}',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (food.nutrients.isEmpty)
                    Text(l.noNutritionData)
                  else
                    NutrientTable(
                      values: food.completedNutrients,
                      estimated: food.estimated,
                    ),
                  if (food.estimated.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        l.estimatedLegend,
                        style: context.texts.bodySmall,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            if (food.barcode != null)
              OutlinedButton.icon(
                icon: const Icon(Icons.refresh),
                label: Text(l.refreshFromOff),
                onPressed: () => _refresh(context, food),
              ),
            const SizedBox(height: 12),
            Text(l.offAttribution, style: context.texts.bodySmall),
          ],
        ),
      ),
    );
  }
}
