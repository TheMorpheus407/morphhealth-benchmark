/// Shared modal bottom-sheet editors for Water, Caffeine, Goals, Period/Spotting,
/// Weight, and Symptoms — callable from Overview, Domain screens, Day Detail,
/// Cycle Calendar, and Searchable History.
library;

import 'package:flutter/material.dart';

import '../../core/clock.dart';
import '../../core/models.dart';
import '../app_controller.dart';

double? _parsePositiveNum(String raw) {
  final cleaned = raw.trim().replaceAll(',', '.');
  if (cleaned.isEmpty) return null;
  final val = double.tryParse(cleaned);
  if (val == null || !val.isFinite || val <= 0) return null;
  return val;
}

Future<String?> _pickIsoDate(
  BuildContext context,
  String currentIso,
  String localeCode,
) async {
  final dt = IsoDate.parseUtc(currentIso);
  final picked = await showDatePicker(
    context: context,
    initialDate: DateTime(dt.year, dt.month, dt.day),
    firstDate: DateTime(1990, 1, 1),
    lastDate: DateTime(2100, 12, 31),
    locale: Locale(localeCode),
  );
  if (picked == null) return null;
  return IsoDate.fromLocalDateTime(picked);
}

Future<String?> _pickHmTime(BuildContext context, String currentHm) async {
  final parts = currentHm.split(':');
  final h = int.tryParse(parts.first) ?? 12;
  final m = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
  final picked = await showTimePicker(
    context: context,
    initialTime: TimeOfDay(hour: h.clamp(0, 23), minute: m.clamp(0, 59)),
  );
  if (picked == null) return null;
  return '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
}

// ---------------------------------------------------------------------------
// Water Entry Editor
// ---------------------------------------------------------------------------

Future<void> showWaterEditorSheet(
  BuildContext context,
  AppController controller, {
  WaterEntry? existing,
  String? initialDate,
}) async {
  final s = controller.strings;
  var dateIso = existing?.date ?? initialDate ?? controller.selectedDate;
  var hm = existing != null
      ? IsoDate.extractTimeHm(existing.recordedAt)
      : IsoDate.extractTimeHm(controller.defaultTimestampForSelectedDate());
  final amountCtrl = TextEditingController(
    text: existing != null ? existing.amountMl.round().toString() : '250',
  );
  final noteCtrl = TextEditingController(text: existing?.note ?? '');
  String? errorMsg;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              bottom: MediaQuery.viewInsetsOf(ctx).bottom +
                  MediaQuery.viewPaddingOf(ctx).bottom +
                  20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    existing == null
                        ? s.logWater
                        : s.tr('Wassereintrag bearbeiten', 'Edit water entry'),
                    style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: amountCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: s.tr('Wassermenge (ml)', 'Water amount (ml)'),
                      suffixText: 'ml',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final d = await _pickIsoDate(
                              ctx,
                              dateIso,
                              controller.localeCode,
                            );
                            if (d != null) setModalState(() => dateIso = d);
                          },
                          icon: const Icon(Icons.event_rounded, size: 18),
                          label: Text(dateIso),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final t = await _pickHmTime(ctx, hm);
                            if (t != null) setModalState(() => hm = t);
                          },
                          icon: const Icon(Icons.schedule_rounded, size: 18),
                          label: Text(hm),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteCtrl,
                    decoration: InputDecoration(labelText: s.optionalNote),
                  ),
                  if (errorMsg != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      errorMsg!,
                      style: TextStyle(
                        color: Theme.of(ctx).colorScheme.error,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      if (existing != null) ...[
                        TextButton.icon(
                          onPressed: () async {
                            await controller.deleteWaterEntry(existing.id);
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
                          final ml = _parsePositiveNum(amountCtrl.text);
                          if (ml == null || ml > 10000) {
                            setModalState(
                              () => errorMsg = s.tr(
                                'Bitte gib eine gültige Menge zwischen 1 und 10.000 ml ein.',
                                'Please enter a valid amount between 1 and 10,000 ml.',
                              ),
                            );
                            return;
                          }
                          final entry = WaterEntry(
                            id: existing?.id ?? generateEntityId('water'),
                            date: dateIso,
                            recordedAt: IsoDate.combineDateAndHm(dateIso, hm),
                            amountMl: ml,
                            note: noteCtrl.text.trim().isEmpty
                                ? null
                                : noteCtrl.text.trim(),
                          );
                          await controller.saveWaterEntry(entry);
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                        child: Text(s.save),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

// ---------------------------------------------------------------------------
// Caffeine Entry Editor
// ---------------------------------------------------------------------------

Future<void> showCaffeineEditorSheet(
  BuildContext context,
  AppController controller, {
  CaffeineEntry? existing,
  String? initialDate,
}) async {
  final s = controller.strings;
  var dateIso = existing?.date ?? initialDate ?? controller.selectedDate;
  var hm = existing != null
      ? IsoDate.extractTimeHm(existing.recordedAt)
      : IsoDate.extractTimeHm(controller.defaultTimestampForSelectedDate());
  final amountCtrl = TextEditingController(
    text: existing != null ? existing.amountMg.round().toString() : '80',
  );
  final sourceCtrl = TextEditingController(
    text: existing?.sourceLabel ?? s.tr('Kaffee', 'Coffee'),
  );
  final noteCtrl = TextEditingController(text: existing?.note ?? '');
  String? errorMsg;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              bottom: MediaQuery.viewInsetsOf(ctx).bottom +
                  MediaQuery.viewPaddingOf(ctx).bottom +
                  20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    existing == null
                        ? s.logCaffeine
                        : s.tr('Koffeineintrag bearbeiten', 'Edit caffeine entry'),
                    style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: sourceCtrl,
                    decoration: InputDecoration(
                      labelText: s.tr(
                        'Getränk / Bezeichnung (optional)',
                        'Beverage / label (optional)',
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: amountCtrl,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                      labelText: s.tr('Koffeinmenge (mg)', 'Caffeine amount (mg)'),
                      suffixText: 'mg',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final d = await _pickIsoDate(
                              ctx,
                              dateIso,
                              controller.localeCode,
                            );
                            if (d != null) setModalState(() => dateIso = d);
                          },
                          icon: const Icon(Icons.event_rounded, size: 18),
                          label: Text(dateIso),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final t = await _pickHmTime(ctx, hm);
                            if (t != null) setModalState(() => hm = t);
                          },
                          icon: const Icon(Icons.schedule_rounded, size: 18),
                          label: Text(hm),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteCtrl,
                    decoration: InputDecoration(labelText: s.optionalNote),
                  ),
                  if (errorMsg != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      errorMsg!,
                      style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      if (existing != null) ...[
                        TextButton.icon(
                          onPressed: () async {
                            await controller.deleteCaffeineEntry(existing.id);
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
                          final mg = _parsePositiveNum(amountCtrl.text);
                          if (mg == null || mg > 2000) {
                            setModalState(
                              () => errorMsg = s.tr(
                                'Bitte gib eine gültige Koffeinmenge zwischen 1 und 2.000 mg ein.',
                                'Please enter a valid caffeine amount between 1 and 2,000 mg.',
                              ),
                            );
                            return;
                          }
                          final entry = CaffeineEntry(
                            id: existing?.id ?? generateEntityId('caff'),
                            date: dateIso,
                            recordedAt: IsoDate.combineDateAndHm(dateIso, hm),
                            amountMg: mg,
                            sourceLabel: sourceCtrl.text.trim().isEmpty
                                ? null
                                : sourceCtrl.text.trim(),
                            note: noteCtrl.text.trim().isEmpty
                                ? null
                                : noteCtrl.text.trim(),
                          );
                          await controller.saveCaffeineEntry(entry);
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                        child: Text(s.save),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

// ---------------------------------------------------------------------------
// Voluntary Daily Goals Editor
// ---------------------------------------------------------------------------

Future<void> showGoalsEditorSheet(
  BuildContext context,
  AppController controller,
) async {
  final s = controller.strings;
  final g = controller.goals;
  final waterCtrl = TextEditingController(
    text: g.waterMl?.round().toString() ?? '',
  );
  final kcalCtrl = TextEditingController(
    text: g.caloriesKcal?.round().toString() ?? '',
  );
  final protCtrl = TextEditingController(
    text: g.proteinG?.round().toString() ?? '',
  );
  final carbsCtrl = TextEditingController(
    text: g.carbsG?.round().toString() ?? '',
  );
  final fatCtrl = TextEditingController(
    text: g.fatG?.round().toString() ?? '',
  );
  String? errorMsg;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              bottom: MediaQuery.viewInsetsOf(ctx).bottom +
                  MediaQuery.viewPaddingOf(ctx).bottom +
                  20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    s.tr('Freiwillige Tagesziele', 'Voluntary Daily Goals'),
                    style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    s.voluntaryGoalsInfo,
                    style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: waterCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: s.tr('Wasserziel (ml)', 'Water target (ml)'),
                      suffixText: 'ml',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: kcalCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: s.tr('Kalorienziel (kcal)', 'Calorie target (kcal)'),
                      suffixText: 'kcal',
                    ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: protCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: s.tr('Protein (g)', 'Protein (g)'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: carbsCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: s.tr('Kohlenhydrate (g)', 'Carbs (g)'),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          controller: fatCtrl,
                          keyboardType: TextInputType.number,
                          decoration: InputDecoration(
                            labelText: s.tr('Fett (g)', 'Fat (g)'),
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (errorMsg != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      errorMsg!,
                      style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () {
                          waterCtrl.clear();
                          kcalCtrl.clear();
                          protCtrl.clear();
                          carbsCtrl.clear();
                          fatCtrl.clear();
                        },
                        child: Text(s.tr('Alle leeren', 'Clear all')),
                      ),
                      const Spacer(),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: Text(s.cancel),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () async {
                          double? parseOpt(TextEditingController c) {
                            final t = c.text.trim().replaceAll(',', '.');
                            if (t.isEmpty) return null;
                            final v = double.tryParse(t);
                            if (v == null || v <= 0) {
                              throw const FormatException();
                            }
                            return v;
                          }

                          try {
                            final next = NutritionGoals(
                              waterMl: parseOpt(waterCtrl),
                              caloriesKcal: parseOpt(kcalCtrl),
                              proteinG: parseOpt(protCtrl),
                              carbsG: parseOpt(carbsCtrl),
                              fatG: parseOpt(fatCtrl),
                            );
                            await controller.updateGoals(next);
                            if (ctx.mounted) Navigator.pop(ctx);
                          } on FormatException {
                            setModalState(
                              () => errorMsg = s.tr(
                                'Ziele müssen leer oder größer als 0 sein.',
                                'Targets must be empty or greater than 0.',
                              ),
                            );
                          }
                        },
                        child: Text(s.save),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

// ---------------------------------------------------------------------------
// Period & Spotting Editor
// ---------------------------------------------------------------------------

Future<void> showPeriodEditorSheet(
  BuildContext context,
  AppController controller, {
  PeriodEntry? existing,
  String? initialStartDate,
}) async {
  final s = controller.strings;
  var startDate = existing?.startDate ?? initialStartDate ?? controller.selectedDate;
  var hasEndDate = existing != null ? existing.endDate != null : true;
  var endDate = existing?.endDate ?? IsoDate.addDays(startDate, 4);
  var intensity = existing?.intensity ?? FlowIntensity.medium;
  var standaloneSpotting = existing != null ? !existing.countsAsPeriod : false;
  final noteCtrl = TextEditingController(text: existing?.note ?? '');
  String? errorMsg;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              bottom: MediaQuery.viewInsetsOf(ctx).bottom +
                  MediaQuery.viewPaddingOf(ctx).bottom +
                  20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    existing == null
                        ? s.logPeriodOrSpotting
                        : s.tr('Eintrag bearbeiten', 'Edit entry'),
                    style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 14),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    title: Text(s.standaloneSpottingLabel),
                    value: standaloneSpotting,
                    onChanged: (v) {
                      setModalState(() {
                        standaloneSpotting = v;
                        if (v) {
                          intensity = FlowIntensity.spotting;
                          hasEndDate = true;
                          endDate = startDate;
                        }
                      });
                    },
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final picked = await _pickIsoDate(
                              ctx,
                              startDate,
                              controller.localeCode,
                            );
                            if (picked != null) {
                              setModalState(() {
                                startDate = picked;
                                if (IsoDate.daysBetween(startDate, endDate) < 0) {
                                  endDate = startDate;
                                }
                              });
                            }
                          },
                          icon: const Icon(Icons.play_arrow_rounded, size: 18),
                          label: Text('${s.tr("Beginn", "Start")}: $startDate'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      s.tr('Enddatum bekannt / abgeschlossen', 'End date set / completed'),
                    ),
                    subtitle: !hasEndDate ? Text(s.ongoingPeriod) : null,
                    value: hasEndDate,
                    onChanged: (v) => setModalState(() => hasEndDate = v ?? false),
                  ),
                  if (hasEndDate)
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await _pickIsoDate(
                          ctx,
                          endDate,
                          controller.localeCode,
                        );
                        if (picked != null) {
                          setModalState(() => endDate = picked);
                        }
                      },
                      icon: const Icon(Icons.stop_rounded, size: 18),
                      label: Text('${s.tr("Ende", "End")}: $endDate'),
                    ),
                  const SizedBox(height: 14),
                  Text(
                    s.tr('Blutungsstärke', 'Flow intensity'),
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final fi in FlowIntensity.values)
                        ChoiceChip(
                          label: Text(fi.label(controller.localeCode)),
                          selected: intensity == fi,
                          onSelected: (_) =>
                              setModalState(() => intensity = fi),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: noteCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(labelText: s.optionalNote),
                  ),
                  if (errorMsg != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      errorMsg!,
                      style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      if (existing != null) ...[
                        TextButton.icon(
                          onPressed: () async {
                            await controller.deletePeriodEntry(existing.id);
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
                          if (hasEndDate &&
                              IsoDate.daysBetween(startDate, endDate) < 0) {
                            setModalState(
                              () => errorMsg = s.tr(
                                'Das Enddatum darf nicht vor dem Beginn liegen.',
                                'End date cannot be earlier than start date.',
                              ),
                            );
                            return;
                          }
                          final entry = PeriodEntry(
                            id: existing?.id ?? generateEntityId('period'),
                            startDate: startDate,
                            endDate: hasEndDate ? endDate : null,
                            intensity: intensity,
                            dailyFlows: existing?.dailyFlows ?? const {},
                            countsAsPeriod: !standaloneSpotting,
                            note: noteCtrl.text.trim().isEmpty
                                ? null
                                : noteCtrl.text.trim(),
                          );
                          await controller.savePeriodEntry(entry);
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                        child: Text(s.save),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

// ---------------------------------------------------------------------------
// Weight Entry Editor
// ---------------------------------------------------------------------------

Future<void> showWeightEditorSheet(
  BuildContext context,
  AppController controller, {
  WeightEntry? existing,
  String? initialDate,
}) async {
  final s = controller.strings;
  var dateIso = existing?.date ?? initialDate ?? controller.selectedDate;
  var hm = existing != null
      ? IsoDate.extractTimeHm(existing.recordedAt)
      : IsoDate.extractTimeHm(controller.defaultTimestampForSelectedDate());
  var unit = existing?.inputUnit ?? controller.preferences.weightUnit;
  final valCtrl = TextEditingController(
    text: existing != null
        ? existing.valueIn(unit).toStringAsFixed(1)
        : '',
  );
  final noteCtrl = TextEditingController(text: existing?.note ?? '');
  String? errorMsg;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              bottom: MediaQuery.viewInsetsOf(ctx).bottom +
                  MediaQuery.viewPaddingOf(ctx).bottom +
                  20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    existing == null
                        ? s.logWeight
                        : s.tr('Gewicht bearbeiten', 'Edit weight'),
                    style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: valCtrl,
                          autofocus: existing == null,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration: InputDecoration(
                            labelText: '${s.weightTitle} (${unit.jsonKey})',
                            suffixText: unit.jsonKey,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      SegmentedButton<WeightUnit>(
                        segments: const [
                          ButtonSegment(value: WeightUnit.kg, label: Text('kg')),
                          ButtonSegment(value: WeightUnit.lb, label: Text('lb')),
                        ],
                        selected: {unit},
                        onSelectionChanged: (sel) {
                          final nextU = sel.first;
                          final curVal = _parsePositiveNum(valCtrl.text);
                          setModalState(() {
                            if (curVal != null && nextU != unit) {
                              final converted = nextU == WeightUnit.lb
                                  ? curVal / kPoundsToKg
                                  : curVal * kPoundsToKg;
                              valCtrl.text = converted.toStringAsFixed(1);
                            }
                            unit = nextU;
                          });
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final d = await _pickIsoDate(
                              ctx,
                              dateIso,
                              controller.localeCode,
                            );
                            if (d != null) setModalState(() => dateIso = d);
                          },
                          icon: const Icon(Icons.event_rounded, size: 18),
                          label: Text(dateIso),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final t = await _pickHmTime(ctx, hm);
                            if (t != null) setModalState(() => hm = t);
                          },
                          icon: const Icon(Icons.schedule_rounded, size: 18),
                          label: Text(hm),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteCtrl,
                    decoration: InputDecoration(labelText: s.optionalNote),
                  ),
                  if (errorMsg != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      errorMsg!,
                      style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      if (existing != null) ...[
                        TextButton.icon(
                          onPressed: () async {
                            await controller.deleteWeightEntry(existing.id);
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
                          final v = _parsePositiveNum(valCtrl.text);
                          final maxBound = unit == WeightUnit.kg ? 500.0 : 1100.0;
                          if (v == null || v < 5 || v > maxBound) {
                            setModalState(
                              () => errorMsg = s.tr(
                                'Bitte gib einen gültigen Gewichtswert ein.',
                                'Please enter a valid weight value.',
                              ),
                            );
                            return;
                          }
                          final entry = WeightEntry.fromInput(
                            id: existing?.id ?? generateEntityId('weight'),
                            date: dateIso,
                            recordedAt: IsoDate.combineDateAndHm(dateIso, hm),
                            value: v,
                            unit: unit,
                            note: noteCtrl.text.trim().isEmpty
                                ? null
                                : noteCtrl.text.trim(),
                          );
                          await controller.saveWeightEntry(entry);
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                        child: Text(s.save),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

// ---------------------------------------------------------------------------
// Symptom Entry Editor
// ---------------------------------------------------------------------------

Future<void> showSymptomEditorSheet(
  BuildContext context,
  AppController controller, {
  SymptomEntry? existing,
  String? initialDate,
}) async {
  final s = controller.strings;
  var dateIso = existing?.date ?? initialDate ?? controller.selectedDate;
  var hm = existing != null
      ? IsoDate.extractTimeHm(existing.recordedAt)
      : IsoDate.extractTimeHm(controller.defaultTimestampForSelectedDate());
  final nameCtrl = TextEditingController(text: existing?.name ?? '');
  var intensity = existing?.intensity ?? 4;
  final noteCtrl = TextEditingController(text: existing?.note ?? '');
  String? errorMsg;

  final starterSuggestions = controller.localeCode == 'en'
      ? const [
          'Cramps',
          'Headache',
          'Fatigue',
          'Bloating',
          'Back pain',
          'Nausea',
        ]
      : const [
          'Unterleibskrämpfe',
          'Kopfschmerzen',
          'Müdigkeit',
          'Blähbauch',
          'Rückenschmerzen',
          'Übelkeit',
        ];
  final suggestions = <String>{
    ...controller.store.distinctSymptomNames.take(8),
    ...starterSuggestions,
  }.take(8).toList();

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (ctx) {
      return StatefulBuilder(
        builder: (ctx, setModalState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 20,
              right: 20,
              bottom: MediaQuery.viewInsetsOf(ctx).bottom +
                  MediaQuery.viewPaddingOf(ctx).bottom +
                  20,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    existing == null
                        ? s.logSymptom
                        : s.tr('Symptom bearbeiten', 'Edit symptom'),
                    style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: nameCtrl,
                    decoration: InputDecoration(
                      labelText: s.symptomNameLabel,
                      hintText: s.tr(
                        'Frei wählbarer Name, z. B. Migräne',
                        'Freely chosen name, e.g. Migraine',
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final chip in suggestions)
                        ActionChip(
                          label: Text(chip),
                          onPressed: () =>
                              setModalState(() => nameCtrl.text = chip),
                        ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        s.intensityLabel,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '$intensity / 10',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: Theme.of(ctx).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  Semantics(
                    label: '${s.intensityLabel}: $intensity',
                    child: Slider(
                      value: intensity.toDouble(),
                      min: 0,
                      max: 10,
                      divisions: 10,
                      label: '$intensity',
                      onChanged: (v) =>
                          setModalState(() => intensity = v.round()),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final d = await _pickIsoDate(
                              ctx,
                              dateIso,
                              controller.localeCode,
                            );
                            if (d != null) setModalState(() => dateIso = d);
                          },
                          icon: const Icon(Icons.event_rounded, size: 18),
                          label: Text(dateIso),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () async {
                            final t = await _pickHmTime(ctx, hm);
                            if (t != null) setModalState(() => hm = t);
                          },
                          icon: const Icon(Icons.schedule_rounded, size: 18),
                          label: Text(hm),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: noteCtrl,
                    maxLines: 2,
                    decoration: InputDecoration(labelText: s.optionalNote),
                  ),
                  if (errorMsg != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      errorMsg!,
                      style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                    ),
                  ],
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      if (existing != null) ...[
                        TextButton.icon(
                          onPressed: () async {
                            await controller.deleteSymptomEntry(existing.id);
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
                          final trimmedName = nameCtrl.text.trim();
                          if (trimmedName.isEmpty) {
                            setModalState(
                              () => errorMsg = s.tr(
                                'Bitte gib einen Symptomnamen ein.',
                                'Please enter a symptom name.',
                              ),
                            );
                            return;
                          }
                          final entry = SymptomEntry(
                            id: existing?.id ?? generateEntityId('sym'),
                            date: dateIso,
                            recordedAt: IsoDate.combineDateAndHm(dateIso, hm),
                            name: trimmedName,
                            intensity: intensity,
                            note: noteCtrl.text.trim().isEmpty
                                ? null
                                : noteCtrl.text.trim(),
                          );
                          await controller.saveSymptomEntry(entry);
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                        child: Text(s.save),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}
