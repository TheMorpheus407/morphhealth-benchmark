/// Food search, Open Food Facts barcode lookup, favorites, re-logging,
/// custom food editor (all 31 nutrients), and meal entry editor.
library;

import 'package:flutter/material.dart';

import '../../core/clock.dart';
import '../../core/models.dart';
import '../../core/nutrients.dart';
import '../../core/open_food_facts_client.dart';
import '../app_controller.dart';
import '../l10n.dart';

// ---------------------------------------------------------------------------
// Custom Food Editor (all 31 nutrients)
// ---------------------------------------------------------------------------

Future<FoodItem?> showCustomFoodEditorSheet(
  BuildContext context,
  AppController controller, {
  FoodItem? existing,
}) async {
  final s = controller.strings;
  final nameCtrl = TextEditingController(text: existing?.name ?? '');
  final brandCtrl = TextEditingController(text: existing?.brand ?? '');
  final barcodeCtrl = TextEditingController(text: existing?.barcode ?? '');
  final servingQtyCtrl = TextEditingController(
    text: (existing?.servingQuantity ?? 100.0).toStringAsFixed(
      (existing?.servingQuantity ?? 100.0) ==
              (existing?.servingQuantity ?? 100.0).roundToDouble()
          ? 0
          : 1,
    ),
  );
  final servingLabelCtrl =
      TextEditingController(text: existing?.servingLabel ?? '');
  var basis = existing?.nutritionBasis ?? '100g';
  var isFavorite = existing?.isFavorite ?? false;

  final nutrientCtrls = <NutrientKey, TextEditingController>{
    for (final k in NutrientKey.values)
      k: TextEditingController(
        text: existing?.nutrientsPer100[k] != null
            ? existing!.nutrientsPer100[k]!.toString()
            : '',
      ),
  };

  String? errorMsg;

  return showModalBottomSheet<FoodItem>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setModalState) {
          Widget buildNutrientGrid(List<NutrientKey> keys) {
            return Column(
              children: [
                for (var i = 0; i < keys.length; i += 2)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: nutrientCtrls[keys[i]],
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: InputDecoration(
                              labelText: keys[i].label(controller.localeCode),
                              suffixText: keys[i].unit,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        if (i + 1 < keys.length)
                          Expanded(
                            child: TextField(
                              controller: nutrientCtrls[keys[i + 1]],
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                decimal: true,
                              ),
                              decoration: InputDecoration(
                                labelText:
                                    keys[i + 1].label(controller.localeCode),
                                suffixText: keys[i + 1].unit,
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

          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.9,
            maxChildSize: 0.96,
            minChildSize: 0.6,
            builder: (ctx, scrollCtrl) {
              return Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  bottom: MediaQuery.viewInsetsOf(ctx).bottom +
                      MediaQuery.viewPaddingOf(ctx).bottom +
                      16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            existing == null
                                ? s.createCustomFood
                                : s.editCustomFood,
                            style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                        ),
                        IconButton(
                          tooltip: s.tr('Favorit', 'Favorite'),
                          onPressed: () =>
                              setModalState(() => isFavorite = !isFavorite),
                          icon: Icon(
                            isFavorite
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            color: isFavorite ? Colors.amber.shade700 : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Expanded(
                      child: ListView(
                        controller: scrollCtrl,
                        children: [
                          TextField(
                            controller: nameCtrl,
                            decoration: InputDecoration(
                              labelText: s.tr('Name *', 'Name *'),
                            ),
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: brandCtrl,
                                  decoration: InputDecoration(
                                    labelText: s.tr(
                                      'Marke / Herkunft',
                                      'Brand / origin',
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  controller: barcodeCtrl,
                                  decoration: const InputDecoration(
                                    labelText: 'Barcode',
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Wrap(
                            crossAxisAlignment: WrapCrossAlignment.center,
                            spacing: 12,
                            runSpacing: 8,
                            children: [
                              Text(
                                s.tr('Nährwertbasis:', 'Basis:'),
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              SegmentedButton<String>(
                                segments: const [
                                  ButtonSegment(
                                    value: '100g',
                                    label: Text('100 g'),
                                  ),
                                  ButtonSegment(
                                    value: '100ml',
                                    label: Text('100 ml'),
                                  ),
                                ],
                                selected: {basis},
                                onSelectionChanged: (v) =>
                                    setModalState(() => basis = v.first),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: TextField(
                                  controller: servingQtyCtrl,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                  decoration: InputDecoration(
                                    labelText: s.tr(
                                      'Portionsgröße',
                                      'Portion size',
                                    ),
                                    suffixText: basis == '100ml' ? 'ml' : 'g',
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: TextField(
                                  controller: servingLabelCtrl,
                                  decoration: InputDecoration(
                                    labelText: s.tr(
                                      'Portionshinweis (z. B. 1 Scheibe)',
                                      'Portion label (e.g. 1 slice)',
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 18),
                          Text(
                            '${s.macrosSection} (${s.tr("pro", "per")} $basis)',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                            ),
                          ),
                          const SizedBox(height: 8),
                          buildNutrientGrid(
                            NutrientKey.byCategory(NutrientCategory.macro),
                          ),
                          ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            initiallyExpanded: true,
                            title: Text(
                              s.extendedSection,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            children: [
                              const SizedBox(height: 4),
                              buildNutrientGrid(
                                NutrientKey.byCategory(
                                  NutrientCategory.extended,
                                ),
                              ),
                            ],
                          ),
                          ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            title: Text(
                              s.vitaminsSection,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            children: [
                              const SizedBox(height: 4),
                              buildNutrientGrid(
                                NutrientKey.byCategory(
                                  NutrientCategory.vitamin,
                                ),
                              ),
                            ],
                          ),
                          ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            title: Text(
                              s.mineralsSection,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            children: [
                              const SizedBox(height: 4),
                              buildNutrientGrid(
                                NutrientKey.byCategory(
                                  NutrientCategory.mineral,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (errorMsg != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          errorMsg!,
                          style: TextStyle(
                            color: Theme.of(ctx).colorScheme.error,
                          ),
                        ),
                      ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        if (existing != null && existing.isCustom) ...[
                          TextButton.icon(
                            onPressed: () async {
                              await controller.deleteCustomFood(existing.id);
                              if (ctx.mounted) Navigator.pop(ctx);
                            },
                            icon: Icon(
                              Icons.delete_outline_rounded,
                              color: Theme.of(ctx).colorScheme.error,
                            ),
                            label: Text(
                              s.delete,
                              style: TextStyle(
                                color: Theme.of(ctx).colorScheme.error,
                              ),
                            ),
                          ),
                          const Spacer(),
                        ] else
                          const Spacer(),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text(s.cancel),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: () async {
                            final name = nameCtrl.text.trim();
                            if (name.isEmpty) {
                              setModalState(
                                () => errorMsg = s.tr(
                                  'Bitte gib einen Namen ein.',
                                  'Please enter a food name.',
                                ),
                              );
                              return;
                            }
                            final sq = double.tryParse(
                              servingQtyCtrl.text.trim().replaceAll(',', '.'),
                            );
                            if (sq == null || sq <= 0) {
                              setModalState(
                                () => errorMsg = s.tr(
                                  'Portionsgröße muss größer als 0 sein.',
                                  'Portion size must be greater than 0.',
                                ),
                              );
                              return;
                            }
                            final parsedMap = <NutrientKey, double>{};
                            for (final e in nutrientCtrls.entries) {
                              final raw =
                                  e.value.text.trim().replaceAll(',', '.');
                              if (raw.isEmpty) continue;
                              final v = double.tryParse(raw);
                              if (v == null || v < 0 || !v.isFinite) {
                                setModalState(
                                  () => errorMsg = s.tr(
                                    'Ungültiger Zahlenwert bei ${e.key.labelDe}.',
                                    'Invalid number for ${e.key.labelEn}.',
                                  ),
                                );
                                return;
                              }
                              parsedMap[e.key] = v;
                            }

                            final nowStr = controller.store.clock.nowRfc3339();
                            final item = FoodItem(
                              id: existing?.id ?? generateEntityId('custom'),
                              source: FoodSource.custom,
                              barcode: barcodeCtrl.text.trim().isEmpty
                                  ? null
                                  : barcodeCtrl.text.trim(),
                              name: name,
                              nameDe: name,
                              nameEn: name,
                              brand: brandCtrl.text.trim().isEmpty
                                  ? null
                                  : brandCtrl.text.trim(),
                              nutritionBasis: basis,
                              servingQuantity: sq,
                              servingLabel: servingLabelCtrl.text.trim().isEmpty
                                  ? null
                                  : servingLabelCtrl.text.trim(),
                              nutrientsPer100: NutrientProfile(parsedMap),
                              isFavorite: isFavorite,
                              createdAt: existing?.createdAt ?? nowStr,
                              updatedAt: nowStr,
                            );
                            final saved = await controller.saveCustomFood(item);
                            if (ctx.mounted) Navigator.pop(ctx, saved);
                          },
                          child: Text(s.save),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    },
  );
}

// ---------------------------------------------------------------------------
// Meal Entry Logger & Editor (supports g, ml, portion + full 31-nutrient view)
// ---------------------------------------------------------------------------

Future<bool> showLogFoodEntrySheet(
  BuildContext context,
  AppController controller, {
  FoodItem? food,
  FoodDiaryEntry? existingEntry,
  MealType initialMealType = MealType.breakfast,
  String? initialDate,
}) async {
  assert(food != null || existingEntry != null);
  final s = controller.strings;

  FoodItem activeFood;
  if (food != null) {
    activeFood = food;
  } else {
    final entryRef = existingEntry!;
    activeFood = controller.store.foodsById[entryRef.foodId] ??
        FoodItem(
          id: entryRef.foodId,
          source: entryRef.foodId.startsWith('off:')
              ? FoodSource.openFoodFacts
              : FoodSource.custom,
          name: entryRef.foodNameSnapshot,
          brand: entryRef.brandSnapshot,
          servingQuantity: entryRef.servingQuantitySnapshot,
          nutrientsPer100: entryRef.nutrientsPer100Snapshot,
          createdAt: entryRef.recordedAt,
          updatedAt: entryRef.recordedAt,
        );
  }

  // Sync favorite status if already in local catalog
  final catalogMatch = controller.store.foodsById[activeFood.id];
  if (catalogMatch != null) {
    activeFood = activeFood.copyWith(isFavorite: catalogMatch.isFavorite);
  }

  var dateIso = existingEntry?.date ?? initialDate ?? controller.selectedDate;
  var hm = existingEntry != null
      ? IsoDate.extractTimeHm(existingEntry.recordedAt)
      : IsoDate.extractTimeHm(controller.defaultTimestampForSelectedDate());
  var mealType = existingEntry?.mealType ?? initialMealType;
  var unit = existingEntry?.unit ??
      (activeFood.nutritionBasis == '100ml' ? AmountUnit.ml : AmountUnit.g);
  final amountCtrl = TextEditingController(
    text: existingEntry != null
        ? _cleanNumber(existingEntry.amount)
        : (unit == AmountUnit.portion ? '1' : '100'),
  );
  final noteCtrl = TextEditingController(text: existingEntry?.note ?? '');
  String? errorMsg;
  var logged = false;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setModalState) {
          final parsedAmount =
              double.tryParse(amountCtrl.text.trim().replaceAll(',', '.')) ??
                  0.0;
          final validAmt = parsedAmount > 0 ? parsedAmount : 0.0;
          final previewNutrients = activeFood.computeNutrientsFor(validAmt, unit);
          final eqGrams = activeFood.computeGramsOrMlEquivalent(validAmt, unit);

          return DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.85,
            maxChildSize: 0.95,
            minChildSize: 0.55,
            builder: (ctx, scrollCtrl) {
              return Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  bottom: MediaQuery.viewInsetsOf(ctx).bottom +
                      MediaQuery.viewPaddingOf(ctx).bottom +
                      16,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                activeFood.localizedName(controller.localeCode),
                                style: Theme.of(ctx)
                                    .textTheme
                                    .titleLarge
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              if (activeFood.brand != null &&
                                  activeFood.brand!.isNotEmpty)
                                Text(
                                  activeFood.brand!,
                                  style: TextStyle(
                                    color: Theme.of(ctx)
                                        .colorScheme
                                        .onSurfaceVariant,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        if (activeFood.isCustom)
                          IconButton(
                            tooltip: s.editCustomFood,
                            onPressed: () async {
                              final edited = await showCustomFoodEditorSheet(
                                ctx,
                                controller,
                                existing: activeFood,
                              );
                              if (edited != null) {
                                setModalState(() => activeFood = edited);
                              }
                            },
                            icon: const Icon(Icons.edit_outlined),
                          ),
                        IconButton(
                          tooltip: s.tr('Als Favorit merken', 'Toggle favorite'),
                          onPressed: () async {
                            final toggled =
                                await controller.toggleFavoriteFood(activeFood);
                            setModalState(() => activeFood = toggled);
                          },
                          icon: Icon(
                            activeFood.isFavorite
                                ? Icons.star_rounded
                                : Icons.star_border_rounded,
                            color: activeFood.isFavorite
                                ? Colors.amber.shade700
                                : null,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Expanded(
                      child: ListView(
                        controller: scrollCtrl,
                        children: [
                          // Live Macro Summary Box
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Theme.of(ctx)
                                  .colorScheme
                                  .primaryContainer
                                  .withValues(alpha: 0.45),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _MiniMacroStat(
                                  label: 'kcal',
                                  value: previewNutrients
                                      .valueOrZero(NutrientKey.caloriesKcal)
                                      .round()
                                      .toString(),
                                ),
                                _MiniMacroStat(
                                  label: 'Protein',
                                  value:
                                      '${previewNutrients.valueOrZero(NutrientKey.proteinG).toStringAsFixed(1)} g',
                                ),
                                _MiniMacroStat(
                                  label: s.tr('KH', 'Carbs'),
                                  value:
                                      '${previewNutrients.valueOrZero(NutrientKey.carbsG).toStringAsFixed(1)} g',
                                ),
                                _MiniMacroStat(
                                  label: s.tr('Fett', 'Fat'),
                                  value:
                                      '${previewNutrients.valueOrZero(NutrientKey.fatG).toStringAsFixed(1)} g',
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                flex: 4,
                                child: TextField(
                                  controller: amountCtrl,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                    decimal: true,
                                  ),
                                  onChanged: (_) => setModalState(() {}),
                                  decoration: InputDecoration(
                                    labelText: s.tr('Menge', 'Amount'),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                flex: 6,
                                child: SegmentedButton<AmountUnit>(
                                  segments: [
                                    const ButtonSegment(
                                      value: AmountUnit.g,
                                      label: Text('g'),
                                    ),
                                    const ButtonSegment(
                                      value: AmountUnit.ml,
                                      label: Text('ml'),
                                    ),
                                    ButtonSegment(
                                      value: AmountUnit.portion,
                                      label: Text(
                                        s.tr('Portion', 'Portion'),
                                      ),
                                    ),
                                  ],
                                  selected: {unit},
                                  onSelectionChanged: (sel) {
                                    final nextUnit = sel.first;
                                    setModalState(() {
                                      if (unit != nextUnit) {
                                        if (nextUnit == AmountUnit.portion) {
                                          amountCtrl.text = '1';
                                        } else if (unit == AmountUnit.portion) {
                                          amountCtrl.text = _cleanNumber(
                                            activeFood.servingQuantity,
                                          );
                                        }
                                        unit = nextUnit;
                                      }
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                          Padding(
                            padding: const EdgeInsets.only(top: 6, left: 4),
                            child: Text(
                              unit == AmountUnit.portion
                                  ? '${s.tr("1 Portion", "1 portion")} = ${_cleanNumber(activeFood.servingQuantity)} ${activeFood.nutritionBasis == "100ml" ? "ml" : "g"}${activeFood.servingLabel != null ? " (${activeFood.servingLabel})" : ""} · ${s.tr("entspricht", "equals")} ${_cleanNumber(eqGrams)} ${activeFood.nutritionBasis == "100ml" ? "ml" : "g"}'
                                  : '${s.tr("Nährwerte pro", "Values per")} ${activeFood.nutritionBasis}',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: Theme.of(ctx)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            s.tr('Mahlzeit', 'Meal'),
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final mt in MealType.values)
                                ChoiceChip(
                                  label: Text(mt.label(controller.localeCode)),
                                  selected: mealType == mt,
                                  onSelected: (_) =>
                                      setModalState(() => mealType = mt),
                                ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: [
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () async {
                                    final dt = IsoDate.parseUtc(dateIso);
                                    final picked = await showDatePicker(
                                      context: ctx,
                                      initialDate: DateTime(
                                        dt.year,
                                        dt.month,
                                        dt.day,
                                      ),
                                      firstDate: DateTime(1990, 1, 1),
                                      lastDate: DateTime(2100, 12, 31),
                                      locale: Locale(controller.localeCode),
                                    );
                                    if (picked != null) {
                                      setModalState(
                                        () => dateIso =
                                            IsoDate.fromLocalDateTime(picked),
                                      );
                                    }
                                  },
                                  icon: const Icon(Icons.event_rounded, size: 18),
                                  label: Text(dateIso),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: OutlinedButton.icon(
                                  onPressed: () async {
                                    final parts = hm.split(':');
                                    final picked = await showTimePicker(
                                      context: ctx,
                                      initialTime: TimeOfDay(
                                        hour: int.tryParse(parts[0]) ?? 12,
                                        minute: parts.length > 1
                                            ? (int.tryParse(parts[1]) ?? 0)
                                            : 0,
                                      ),
                                    );
                                    if (picked != null) {
                                      setModalState(
                                        () => hm =
                                            '${picked.hour.toString().padLeft(2, "0")}:${picked.minute.toString().padLeft(2, "0")}',
                                      );
                                    }
                                  },
                                  icon: const Icon(
                                    Icons.schedule_rounded,
                                    size: 18,
                                  ),
                                  label: Text(hm),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          TextField(
                            controller: noteCtrl,
                            decoration:
                                InputDecoration(labelText: s.optionalNote),
                          ),
                          const SizedBox(height: 10),
                          // Full nutrient & 21 micronutrient inspection table for this food/portion
                          ExpansionTile(
                            tilePadding: EdgeInsets.zero,
                            title: Text(
                              s.allNutrientsAndMicros,
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            children: [
                              for (final k in NutrientKey.values.where(
                                (x) => x.category != NutrientCategory.macro,
                              ))
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 3),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          k.label(controller.localeCode),
                                          style: const TextStyle(fontSize: 13.5),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        activeFood.nutrientsPer100
                                                .containsKey(k)
                                            ? '${previewNutrients.valueOrZero(k).toStringAsFixed(k.decimals)} ${k.unit}'
                                            : '—',
                                        style: TextStyle(
                                          fontSize: 13.5,
                                          fontWeight: FontWeight.w600,
                                          color: activeFood.nutrientsPer100
                                                  .containsKey(k)
                                              ? null
                                              : Theme.of(ctx)
                                                  .colorScheme
                                                  .outline,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (errorMsg != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                          errorMsg!,
                          style: TextStyle(
                            color: Theme.of(ctx).colorScheme.error,
                          ),
                        ),
                      ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        if (existingEntry != null) ...[
                          TextButton.icon(
                            onPressed: () async {
                              await controller
                                  .deleteMealEntry(existingEntry.id);
                              if (ctx.mounted) Navigator.pop(ctx);
                            },
                            icon: Icon(
                              Icons.delete_outline_rounded,
                              color: Theme.of(ctx).colorScheme.error,
                            ),
                            label: Text(
                              s.delete,
                              style: TextStyle(
                                color: Theme.of(ctx).colorScheme.error,
                              ),
                            ),
                          ),
                          const Spacer(),
                        ] else
                          const Spacer(),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: Text(s.cancel),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: () async {
                            final amt = double.tryParse(
                              amountCtrl.text.trim().replaceAll(',', '.'),
                            );
                            if (amt == null || amt <= 0 || amt > 20000) {
                              setModalState(
                                () => errorMsg = s.tr(
                                  'Bitte gib eine gültige Menge größer als 0 ein.',
                                  'Please enter a valid amount greater than 0.',
                                ),
                              );
                              return;
                            }
                            final entry = FoodDiaryEntry(
                              id: existingEntry?.id ?? generateEntityId('meal'),
                              date: dateIso,
                              recordedAt: IsoDate.combineDateAndHm(dateIso, hm),
                              mealType: mealType,
                              foodId: activeFood.id,
                              foodNameSnapshot: activeFood.name,
                              brandSnapshot: activeFood.brand,
                              amount: amt,
                              unit: unit,
                              servingQuantitySnapshot:
                                  activeFood.servingQuantity,
                              nutrientsPer100Snapshot:
                                  activeFood.nutrientsPer100,
                              note: noteCtrl.text.trim().isEmpty
                                  ? null
                                  : noteCtrl.text.trim(),
                            );
                            await controller.saveMealEntry(
                              entry,
                              foodToPersist: activeFood,
                            );
                            logged = true;
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                          child: Text(s.save),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            },
          );
        },
      );
    },
  );
  return logged;
}

class _MiniMacroStat extends StatelessWidget {
  final String label;
  final String value;

  const _MiniMacroStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Add Food Full Modal (Open Food Facts + Barcode + Re-log + Favorites + Custom)
// ---------------------------------------------------------------------------

Future<void> showAddFoodModal(
  BuildContext context,
  AppController controller, {
  MealType initialMealType = MealType.breakfast,
}) async {
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => _AddFoodScreen(
        controller: controller,
        initialMealType: initialMealType,
      ),
    ),
  );
}

class _AddFoodScreen extends StatefulWidget {
  final AppController controller;
  final MealType initialMealType;

  const _AddFoodScreen({
    required this.controller,
    required this.initialMealType,
  });

  @override
  State<_AddFoodScreen> createState() => _AddFoodScreenState();
}

class _AddFoodScreenState extends State<_AddFoodScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabCtrl;
  final TextEditingController _searchCtrl = TextEditingController();
  final TextEditingController _barcodeCtrl = TextEditingController();
  final TextEditingController _localFilterCtrl = TextEditingController();

  bool _loading = false;
  String? _error;
  FoodSearchPage? _searchPage;
  int _currentPage = 1;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    _searchCtrl.dispose();
    _barcodeCtrl.dispose();
    _localFilterCtrl.dispose();
    super.dispose();
  }

  Future<void> _executeOffSearch({int page = 1}) async {
    final q = _searchCtrl.text.trim();
    if (q.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final res = await widget.controller.foodClient.searchProducts(
        query: q,
        page: page,
      );
      if (!mounted) return;
      setState(() {
        _searchPage = res;
        _currentPage = page;
        _loading = false;
      });
    } on FoodApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.message;
        _loading = false;
      });
    }
  }

  Future<void> _executeBarcodeLookup() async {
    final code = _barcodeCtrl.text.trim();
    if (code.isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final item = await widget.controller.foodClient.lookupBarcode(code);
      if (!mounted) return;
      setState(() => _loading = false);
      final logged = await showLogFoodEntrySheet(
        context,
        widget.controller,
        food: item,
        initialMealType: widget.initialMealType,
      );
      if (logged && mounted) Navigator.pop(context);
    } on FoodNotFoundException {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = widget.controller.strings.tr(
          'Kein Produkt zu Barcode „$code“ in Open Food Facts gefunden.',
          'No product found in Open Food Facts for barcode "$code".',
        );
      });
    } on FoodApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.message;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final s = widget.controller.strings;
        final onlineEnabled = widget.controller.preferences.onlineFoodEnabled;

        return Scaffold(
          appBar: AppBar(
            title: Text(s.addFood),
            bottom: TabBar(
              controller: _tabCtrl,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              tabs: [
                Tab(text: s.tabOffSearch),
                Tab(text: s.tabRecent),
                Tab(text: s.tabFavorites),
                Tab(text: s.tabCustomFoods),
              ],
            ),
          ),
          body: SafeArea(
            top: false,
            child: TabBarView(
              controller: _tabCtrl,
              children: [
                _buildOffTab(context, s, onlineEnabled),
                _buildRecentTab(context, s),
                _buildFavoritesTab(context, s),
                _buildCustomTab(context, s),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildOffTab(BuildContext context, MhStrings s, bool onlineEnabled) {
    if (!onlineEnabled) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 44),
              const SizedBox(height: 12),
              Text(
                s.onlineSearchDisabledMsg,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: () {
                  widget.controller.updatePreferences(
                    widget.controller.preferences
                        .copyWith(onlineFoodEnabled: true),
                  );
                },
                child: Text(
                  s.tr(
                    'Online-Suche aktivieren',
                    'Enable online search',
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _searchCtrl,
                      textInputAction: TextInputAction.search,
                      onSubmitted: (_) => _executeOffSearch(page: 1),
                      decoration: InputDecoration(
                        hintText: s.searchByNameHint,
                        prefixIcon: const Icon(Icons.search_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed:
                        _loading ? null : () => _executeOffSearch(page: 1),
                    child: Text(s.tr('Suchen', 'Search')),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _barcodeCtrl,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.go,
                      onSubmitted: (_) => _executeBarcodeLookup(),
                      decoration: InputDecoration(
                        hintText: s.barcodeHint,
                        prefixIcon: const Icon(Icons.qr_code_rounded),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: _loading ? null : _executeBarcodeLookup,
                    child: Text(s.lookupBarcodeBtn),
                  ),
                ],
              ),
            ],
          ),
        ),
        if (_loading) const LinearProgressIndicator(),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        Expanded(
          child: _searchPage == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      s.tr(
                        'Suche nach Namen (z. B. Haferflocken, Alpro, Joghurt) oder gib eine Barcode-Nummer ein.',
                        'Search by food name or enter a barcode number.',
                      ),
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                )
              : _searchPage!.items.isEmpty
                  ? Center(
                      child: Text(
                        s.tr('Keine Treffer gefunden.', 'No products found.'),
                      ),
                    )
                  : Column(
                      children: [
                        Expanded(
                          child: ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: _searchPage!.items.length,
                            separatorBuilder: (_, _) =>
                                const SizedBox(height: 8),
                            itemBuilder: (ctx, idx) {
                              final item = _searchPage!.items[idx];
                              return _FoodListTile(
                                food: item,
                                controller: widget.controller,
                                onTap: () async {
                                  final ok = await showLogFoodEntrySheet(
                                    context,
                                    widget.controller,
                                    food: item,
                                    initialMealType: widget.initialMealType,
                                  );
                                  if (ok && context.mounted) {
                                    Navigator.pop(context);
                                  }
                                },
                              );
                            },
                          ),
                        ),
                        if (_searchPage!.pageCount > 1)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                OutlinedButton(
                                  onPressed: !_loading && _currentPage > 1
                                      ? () => _executeOffSearch(
                                            page: _currentPage - 1,
                                          )
                                      : null,
                                  child: Text(s.tr('Zurück', 'Prev')),
                                ),
                                Text(
                                  '${s.tr("Seite", "Page")} $_currentPage / ${_searchPage!.pageCount}',
                                ),
                                OutlinedButton(
                                  onPressed: !_loading &&
                                          _currentPage < _searchPage!.pageCount
                                      ? () => _executeOffSearch(
                                            page: _currentPage + 1,
                                          )
                                      : null,
                                  child: Text(s.tr('Weiter', 'Next')),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
        ),
      ],
    );
  }

  Widget _buildRecentTab(BuildContext context, MhStrings s) {
    final recent = widget.controller.store.recentLoggedMealTemplates();
    if (recent.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            s.tr(
              'Noch keine protokollierten Mahlzeiten vorhanden. Bereits erfasste Einträge lassen sich hier mit einem Tippen erneut übernehmen.',
              'No logged meals yet. Previously logged entries can be re-logged here with one tap.',
            ),
            textAlign: TextAlign.center,
          ),
        ),
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: recent.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (ctx, i) {
        final tmpl = recent[i];
        final liveFood = widget.controller.store.foodsById[tmpl.foodId];
        final kcal = tmpl
            .computeNutrients(liveFood)
            .valueOrZero(NutrientKey.caloriesKcal)
            .round();
        return Card(
          child: ListTile(
            title: Text(
              tmpl.displayName(liveFood, widget.controller.localeCode),
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            subtitle: Text(
              '${_cleanNumber(tmpl.amount)} ${tmpl.unit.label(widget.controller.localeCode)} · $kcal kcal',
            ),
            trailing: FilledButton.tonalIcon(
              onPressed: () async {
                await widget.controller.relogMealEntry(
                  tmpl,
                  targetMealType: widget.initialMealType,
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text(s.reloggedNotice)),
                  );
                  Navigator.pop(context);
                }
              },
              icon: const Icon(Icons.replay_rounded, size: 18),
              label: Text(s.relogEntry),
            ),
            onTap: () async {
              final ok = await showLogFoodEntrySheet(
                context,
                widget.controller,
                food: liveFood,
                existingEntry: tmpl.copyWith(
                  id: generateEntityId('meal'),
                  date: widget.controller.selectedDate,
                  mealType: widget.initialMealType,
                ),
                initialMealType: widget.initialMealType,
              );
              if (ok && context.mounted) Navigator.pop(context);
            },
          ),
        );
      },
    );
  }

  Widget _buildFavoritesTab(BuildContext context, MhStrings s) {
    final favs = widget.controller.store.searchLocalFoods(
      _localFilterCtrl.text,
      favoritesOnly: true,
    );
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _localFilterCtrl,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: s.tr('Favoriten filtern…', 'Filter favorites…'),
              prefixIcon: const Icon(Icons.filter_list_rounded),
            ),
          ),
        ),
        Expanded(
          child: favs.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      s.tr(
                        'Markiere häufig verwendete Lebensmittel über das Stern-Symbol als Favoriten.',
                        'Mark frequently used foods with the star icon to keep them here.',
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: favs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) => _FoodListTile(
                    food: favs[i],
                    controller: widget.controller,
                    onTap: () async {
                      final ok = await showLogFoodEntrySheet(
                        context,
                        widget.controller,
                        food: favs[i],
                        initialMealType: widget.initialMealType,
                      );
                      if (ok && context.mounted) Navigator.pop(context);
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildCustomTab(BuildContext context, MhStrings s) {
    final customs = widget.controller.store.customFoods;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () async {
                final created = await showCustomFoodEditorSheet(
                  context,
                  widget.controller,
                );
                if (created != null && context.mounted) {
                  final ok = await showLogFoodEntrySheet(
                    context,
                    widget.controller,
                    food: created,
                    initialMealType: widget.initialMealType,
                  );
                  if (ok && context.mounted) Navigator.pop(context);
                }
              },
              icon: const Icon(Icons.add_rounded),
              label: Text(s.createCustomFood),
            ),
          ),
        ),
        Expanded(
          child: customs.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(
                      s.tr(
                        'Noch keine eigenen Lebensmittel angelegt.',
                        'No custom foods created yet.',
                      ),
                    ),
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: customs.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (ctx, i) {
                    final item = customs[i];
                    return _FoodListTile(
                      food: item,
                      controller: widget.controller,
                      trailingEdit: () => showCustomFoodEditorSheet(
                        context,
                        widget.controller,
                        existing: item,
                      ),
                      onTap: () async {
                        final ok = await showLogFoodEntrySheet(
                          context,
                          widget.controller,
                          food: item,
                          initialMealType: widget.initialMealType,
                        );
                        if (ok && context.mounted) Navigator.pop(context);
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }
}

class _FoodListTile extends StatelessWidget {
  final FoodItem food;
  final AppController controller;
  final VoidCallback onTap;
  final VoidCallback? trailingEdit;

  const _FoodListTile({
    required this.food,
    required this.controller,
    required this.onTap,
    this.trailingEdit,
  });

  @override
  Widget build(BuildContext context) {
    final p = food.nutrientsPer100;
    final kcal = p.valueOrZero(NutrientKey.caloriesKcal).round();
    final prot = p.valueOrZero(NutrientKey.proteinG).toStringAsFixed(1);
    final carbs = p.valueOrZero(NutrientKey.carbsG).toStringAsFixed(1);
    final fat = p.valueOrZero(NutrientKey.fatG).toStringAsFixed(1);
    final savedFav =
        controller.store.foodsById[food.id]?.isFavorite ?? food.isFavorite;

    return Card(
      child: ListTile(
        onTap: onTap,
        title: Text(
          food.localizedName(controller.localeCode),
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(
          '${food.brand != null ? "${food.brand} · " : ""}$kcal kcal · P $prot g · KH $carbs g · F $fat g / ${food.nutritionBasis}',
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (trailingEdit != null)
              IconButton(
                tooltip: controller.strings.edit,
                onPressed: trailingEdit,
                icon: const Icon(Icons.edit_outlined, size: 20),
              ),
            IconButton(
              tooltip: controller.strings.tr('Favorit', 'Favorite'),
              onPressed: () => controller.toggleFavoriteFood(food),
              icon: Icon(
                savedFav ? Icons.star_rounded : Icons.star_border_rounded,
                color: savedFav ? Colors.amber.shade700 : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String _cleanNumber(double v) {
  if (v == v.roundToDouble()) return v.round().toString();
  return v.toStringAsFixed(1);
}
