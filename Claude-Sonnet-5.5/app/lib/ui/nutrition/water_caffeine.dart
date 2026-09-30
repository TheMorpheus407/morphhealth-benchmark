import 'package:flutter/material.dart';

import '../../core/civil.dart';
import '../../core/db.dart';
import '../../core/ids.dart';
import '../../core/models.dart';
import '../../core/nutrition.dart';
import '../../state/app_state.dart';
import '../format.dart';
import '../l10n_x.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/fields.dart';

/// Häufige Wassermengen in ml für die Schnellerfassung.
const List<int> kQuickWaterAmounts = [150, 250, 330, 500];

/// Zeitpunkt für einen neuen Eintrag am Tag [day]: jetzt, wenn der Tag heute
/// ist, sonst 12:00.
LocalDateTime defaultTimeFor(AppState app, Day day) {
  final now = app.core.clock.nowLocal();
  return day == now.day ? now : LocalDateTime(day, 12, 0);
}

/// Karte "Wasser": Tagessumme, Fortschritt zum Ziel, Schnellerfassung, Einträge.
class WaterCard extends StatelessWidget {
  final DayNutrition data;

  const WaterCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final l = context.l10n;
    final f = context.fmt;
    final brightness = context.theme.brightness;
    final color = areaColor(Area.nutrition, brightness);
    final goal = data.goals.waterMl;
    final value = data.waterMl;
    return SectionCard(
      title: l.waterTitle,
      icon: Icons.water_drop_outlined,
      accent: color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ProgressRow(
            label: l.waterTotalLabel,
            valueText: goal == null ? l.waterPlain(f.n(value)) : l.waterOfGoal(f.n(value), f.n(goal)),
            fraction: goal == null ? null : value / goal,
            color: color,
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final ml in kQuickWaterAmounts)
                Semantics(
                  label: l.waterQuickAdd(ml.toString()),
                  button: true,
                  excludeSemantics: true,
                  onTap: () => addWater(context, app, app.selectedDay, ml.toDouble()),
                  child: ActionChip(
                    avatar: const Icon(Icons.add, size: 18),
                    label: Text('$ml ml'),
                    onPressed: () => addWater(context, app, app.selectedDay, ml.toDouble()),
                  ),
                ),
              ActionChip(
                avatar: const Icon(Icons.edit_outlined, size: 18),
                label: Text(l.waterOther),
                onPressed: () => showWaterSheet(context, day: app.selectedDay),
              ),
            ],
          ),
          if (data.waterEntries.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final w in data.waterEntries)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: const Icon(Icons.water_drop_outlined, size: 20),
                title: Text(l.waterEntryTitle(f.n(w.ml))),
                subtitle: Text(f.time(w.at)),
                trailing: const Icon(Icons.edit_outlined, size: 18),
                onTap: () => showWaterSheet(context, day: w.day, existing: w),
              ),
          ],
        ],
      ),
    );
  }
}

/// Erfasst Wasser sofort und bietet "Rückgängig" an.
Future<void> addWater(BuildContext context, AppState app, Day day, double ml) async {
  final l = context.l10n;
  final f = context.fmt;
  final messenger = context;
  final entry = WaterEntry(id: newId(), at: defaultTimeFor(app, day), ml: ml);
  try {
    await app.db.saveWater(entry);
  } on DomainException catch (e) {
    if (messenger.mounted) showMessage(messenger, domainErrorText(l, e));
    return;
  }
  if (messenger.mounted) {
    showUndo(messenger, l.waterAdded(f.n(ml)), () => app.db.deleteWater(entry.id));
  }
}

/// Blatt zum Erfassen oder Bearbeiten von Wasser.
Future<void> showWaterSheet(BuildContext context, {required Day day, WaterEntry? existing}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (c) => _WaterSheet(day: day, existing: existing, parent: context),
  );
}

class _WaterSheet extends StatefulWidget {
  final Day day;
  final WaterEntry? existing;
  final BuildContext parent;

  const _WaterSheet({required this.day, required this.existing, required this.parent});

  @override
  State<_WaterSheet> createState() => _WaterSheetState();
}

class _WaterSheetState extends State<_WaterSheet> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _ml;
  late Day _day;
  late TimeOfDay _time;

  @override
  void initState() {
    super.initState();
    final app = AppScope.read(widget.parent);
    final e = widget.existing;
    final at = e?.at ?? defaultTimeFor(app, widget.day);
    _ml = TextEditingController(text: e == null ? '' : Fmt(app.lang).input(e.ml));
    _day = at.day;
    _time = TimeOfDay(hour: at.hour, minute: at.minute);
  }

  @override
  void dispose() {
    _ml.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final app = AppScope.read(widget.parent);
    final l = context.l10n;
    final nav = Navigator.of(context);
    final messenger = widget.parent;
    final ml = Fmt.parse(_ml.text)!;
    final at = LocalDateTime(_day, _time.hour, _time.minute);
    try {
      final e = widget.existing;
      final saved = e == null ? WaterEntry(id: newId(), at: at, ml: ml) : e.copyWith(at: at, ml: ml);
      await app.db.saveWater(saved);
      nav.pop();
      if (messenger.mounted && e == null) {
        showUndo(messenger, l.waterAdded(Fmt(app.lang).n(ml)), () => app.db.deleteWater(saved.id));
      }
    } on DomainException catch (e) {
      if (mounted) showMessage(context, domainErrorText(l, e));
    }
  }

  Future<void> _delete() async {
    final app = AppScope.read(widget.parent);
    final l = context.l10n;
    final nav = Navigator.of(context);
    final messenger = widget.parent;
    final e = widget.existing!;
    await app.db.deleteWater(e.id);
    nav.pop();
    if (messenger.mounted) showUndo(messenger, l.commonDeletedItem(l.waterTitle), () => app.db.saveWater(e));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final editing = widget.existing != null;
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + sheetBottomInset(context)),
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(editing ? l.waterEditTitle : l.waterLogTitle, style: context.text.titleLarge),
              const SizedBox(height: 16),
              NumberField(
                controller: _ml,
                label: l.waterAmountLabel,
                suffix: 'ml',
                required: true,
                positive: true,
                max: 20000,
                autofocus: !editing,
              ),
              const SizedBox(height: 12),
              DateTimeRow(
                day: _day,
                time: _time,
                onDay: (d) => setState(() => _day = d),
                onTime: (t) => setState(() => _time = t),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  if (editing)
                    TextButton.icon(
                      onPressed: _delete,
                      icon: const Icon(Icons.delete_outline),
                      label: Text(l.commonDelete),
                    ),
                  const Spacer(),
                  TextButton(onPressed: () => Navigator.pop(context), child: Text(l.commonCancel)),
                  const SizedBox(width: 8),
                  FilledButton(onPressed: _save, child: Text(l.commonSave)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Karte "Koffein": Summe und zusätzlich erfasste Einträge.
class CaffeineCard extends StatelessWidget {
  final DayNutrition data;

  const CaffeineCard({super.key, required this.data});

  @override
  Widget build(BuildContext context) {
    final app = AppScope.of(context);
    final l = context.l10n;
    final f = context.fmt;
    final color = areaColor(Area.nutrition, context.theme.brightness);
    return SectionCard(
      title: l.caffeineTitle,
      icon: Icons.coffee_outlined,
      accent: color,
      trailing: TextButton.icon(
        onPressed: () => showCaffeineSheet(context, day: app.selectedDay),
        icon: const Icon(Icons.add),
        label: Text(l.commonAdd),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l.caffeineTotal(f.n(data.caffeineTotalMg)), style: context.text.titleLarge),
          if (data.caffeineFromFoodsMg > 0)
            Text(l.caffeineFromFoods(f.n(data.caffeineFromFoodsMg)), style: context.text.bodyMedium),
          if (data.caffeineAdditionalMg > 0)
            Text(l.caffeineAdditional(f.n(data.caffeineAdditionalMg)), style: context.text.bodyMedium),
          for (final c in data.caffeineEntries)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: const Icon(Icons.coffee_outlined, size: 20),
              title: Text(c.label == null ? l.caffeineEntryTitle(f.n(c.mg)) : '${c.label} · ${f.n(c.mg)} mg'),
              subtitle: Text(f.time(c.at)),
              trailing: const Icon(Icons.edit_outlined, size: 18),
              onTap: () => showCaffeineSheet(context, day: c.day, existing: c),
            ),
        ],
      ),
    );
  }
}

Future<void> showCaffeineSheet(BuildContext context, {required Day day, CaffeineEntry? existing}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (c) => _CaffeineSheet(day: day, existing: existing, parent: context),
  );
}

class _CaffeineSheet extends StatefulWidget {
  final Day day;
  final CaffeineEntry? existing;
  final BuildContext parent;

  const _CaffeineSheet({required this.day, required this.existing, required this.parent});

  @override
  State<_CaffeineSheet> createState() => _CaffeineSheetState();
}

class _CaffeineSheetState extends State<_CaffeineSheet> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _mg;
  late final TextEditingController _label;
  late Day _day;
  late TimeOfDay _time;

  @override
  void initState() {
    super.initState();
    final app = AppScope.read(widget.parent);
    final e = widget.existing;
    final at = e?.at ?? defaultTimeFor(app, widget.day);
    _mg = TextEditingController(text: e == null ? '' : Fmt(app.lang).input(e.mg));
    _label = TextEditingController(text: e?.label ?? '');
    _day = at.day;
    _time = TimeOfDay(hour: at.hour, minute: at.minute);
  }

  @override
  void dispose() {
    _mg.dispose();
    _label.dispose();
    super.dispose();
  }

  void _preset(String label, int mg) {
    setState(() {
      _label.text = label;
      _mg.text = mg.toString();
    });
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final app = AppScope.read(widget.parent);
    final l = context.l10n;
    final nav = Navigator.of(context);
    final messenger = widget.parent;
    final mg = Fmt.parse(_mg.text)!;
    final label = _label.text.trim().isEmpty ? null : _label.text.trim();
    final at = LocalDateTime(_day, _time.hour, _time.minute);
    try {
      final e = widget.existing;
      final saved = e == null
          ? CaffeineEntry(id: newId(), at: at, mg: mg, label: label)
          : e.copyWith(at: at, mg: mg, label: () => label);
      await app.db.saveCaffeine(saved);
      nav.pop();
      if (messenger.mounted && e == null) {
        showUndo(messenger, l.caffeineAdded(Fmt(app.lang).n(mg)), () => app.db.deleteCaffeine(saved.id));
      }
    } on DomainException catch (e) {
      if (mounted) showMessage(context, domainErrorText(l, e));
    }
  }

  Future<void> _delete() async {
    final app = AppScope.read(widget.parent);
    final l = context.l10n;
    final nav = Navigator.of(context);
    final messenger = widget.parent;
    final e = widget.existing!;
    await app.db.deleteCaffeine(e.id);
    nav.pop();
    if (messenger.mounted) showUndo(messenger, l.commonDeletedItem(l.caffeineTitle), () => app.db.saveCaffeine(e));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final editing = widget.existing != null;
    final presets = <(String, int)>[
      (l.caffeineCoffee, 80),
      (l.caffeineEspresso, 65),
      (l.caffeineTea, 45),
      (l.caffeineGreenTea, 30),
      (l.caffeineCola, 35),
      (l.caffeineEnergy, 80),
    ];
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + sheetBottomInset(context)),
      child: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(editing ? l.caffeineEditTitle : l.caffeineLogTitle, style: context.text.titleLarge),
              const SizedBox(height: 12),
              Text(l.caffeinePresetNote, style: context.text.bodySmall),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final p in presets)
                    ActionChip(label: Text('${p.$1} · ${p.$2} mg'), onPressed: () => _preset(p.$1, p.$2)),
                ],
              ),
              const SizedBox(height: 16),
              NumberField(
                controller: _mg,
                label: l.caffeineAmountLabel,
                suffix: 'mg',
                required: true,
                positive: true,
                max: 5000,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _label,
                textCapitalization: TextCapitalization.sentences,
                maxLength: 100,
                decoration: InputDecoration(labelText: l.caffeineLabelHint, counterText: ''),
              ),
              const SizedBox(height: 12),
              DateTimeRow(
                day: _day,
                time: _time,
                onDay: (d) => setState(() => _day = d),
                onTime: (t) => setState(() => _time = t),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  if (editing)
                    TextButton.icon(
                      onPressed: _delete,
                      icon: const Icon(Icons.delete_outline),
                      label: Text(l.commonDelete),
                    ),
                  const Spacer(),
                  TextButton(onPressed: () => Navigator.pop(context), child: Text(l.commonCancel)),
                  const SizedBox(width: 8),
                  FilledButton(onPressed: _save, child: Text(l.commonSave)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
