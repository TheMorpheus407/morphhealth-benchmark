import 'package:flutter/material.dart';

import '../../../core/l10n/format.dart';
import '../../../core/model/dataset.dart';
import '../../../core/model/entries.dart';
import '../../../core/util/local_date.dart';
import '../../controller.dart';
import '../../theme.dart';
import '../../widgets/common.dart';
import '../../widgets/inputs.dart';

/// Water for a day: total, goal progress, quick-add buttons and entries.
class WaterCard extends StatelessWidget {
  const WaterCard({super.key, required this.date, this.compact = false});

  final LocalDate date;

  /// Compact: no entry list (used on the overview).
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final s = app.s;
    final fmt = app.fmt;
    final entries = app.data.waterOn(date);
    final total = entries.fold<double>(0, (sum, e) => sum + e.amountMl);
    final goal = app.settings.goals.waterMl;
    return SectionCard(
      title: s.water,
      icon: Icons.local_drink_outlined,
      iconColor: context.colors.water,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GoalProgress(
            label: s.dayTotal,
            valueText: '${fmt.integer(total)} ml',
            value: total,
            goal: goal,
            goalText: goal == null ? null : '${fmt.integer(goal)} ml',
            color: context.colors.water,
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final ml in app.settings.waterQuickMl)
                ActionChip(
                  avatar: const Icon(Icons.add, size: 18),
                  label: Text('${fmt.integer(ml)} ml'),
                  tooltip: '${s.water} +${fmt.integer(ml)} ml',
                  onPressed: () => _add(context, ml.toDouble()),
                ),
              ActionChip(
                avatar: const Icon(Icons.edit_outlined, size: 18),
                label: Text(s.waterAddCustom),
                onPressed: () async {
                  final ml = await askAmount(
                    context,
                    title: s.water,
                    label: s.waterAmountMl,
                    suffix: 'ml',
                    max: WaterEntry.maxMl,
                  );
                  if (ml != null && context.mounted) await _add(context, ml);
                },
              ),
            ],
          ),
          if (!compact && entries.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final e in entries)
              _IntakeTile(
                title: '${fmt.integer(e.amountMl)} ml',
                time: e.time,
                onEdit: () => editWater(context, e),
                onDelete: () => deleteWithUndo(context, Collection.waterEntries, e),
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _add(BuildContext context, double ml) async {
    final app = context.appRead;
    final time = date == app.today ? app.service.clock.minutesOfDay() : 12 * 60;
    await app.run(() async {
      final entry = await app.service.addWater(date, ml, time: time);
      app.showMessage(
        app.s.waterAdded('${app.fmt.integer(ml)} ml'),
        actionLabel: app.s.undo,
        onAction: () => app.service.deleteRecord(Collection.waterEntries, entry.id),
      );
    });
  }
}

/// Additional caffeine for a day plus caffeine from logged foods.
class CaffeineCard extends StatelessWidget {
  const CaffeineCard({super.key, required this.date, this.compact = false});

  final LocalDate date;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final s = app.s;
    final fmt = app.fmt;
    final day = app.service.nutritionDay(date);
    return SectionCard(
      title: s.caffeine,
      icon: Icons.coffee_outlined,
      iconColor: context.colors.symptoms,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GoalProgress(
            label: s.caffeineTotal,
            valueText: '${fmt.integer(day.caffeineTotalMg)} mg',
          ),
          if (day.caffeineFromFoodsMg > 0)
            Text(
              '${fmt.integer(day.caffeineFromFoodsMg)} mg ${s.caffeineFromFoods} · '
              '${fmt.integer(day.caffeineAdditionalMg)} mg ${s.caffeineAdditional.toLowerCase()}',
              style: context.text.bodySmall?.copyWith(color: context.scheme.onSurfaceVariant),
            ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final mg in app.settings.caffeineQuickMg)
                ActionChip(
                  avatar: const Icon(Icons.add, size: 18),
                  label: Text('${fmt.integer(mg)} mg'),
                  tooltip: '${s.caffeine} +${fmt.integer(mg)} mg',
                  onPressed: () => _add(context, mg.toDouble(), null),
                ),
              ActionChip(
                avatar: const Icon(Icons.edit_outlined, size: 18),
                label: Text(s.caffeineAddCustom),
                onPressed: () async {
                  final result = await askCaffeine(context);
                  if (result != null && context.mounted) {
                    await _add(context, result.$1, result.$2);
                  }
                },
              ),
            ],
          ),
          if (!compact && day.caffeine.isNotEmpty) ...[
            const SizedBox(height: 8),
            for (final e in day.caffeine)
              _IntakeTile(
                title: e.label == null
                    ? '${fmt.integer(e.amountMg)} mg'
                    : '${fmt.integer(e.amountMg)} mg · ${e.label}',
                time: e.time,
                onEdit: () => editCaffeine(context, e),
                onDelete: () => deleteWithUndo(context, Collection.caffeineEntries, e),
              ),
          ],
        ],
      ),
    );
  }

  Future<void> _add(BuildContext context, double mg, String? label) async {
    final app = context.appRead;
    final time = date == app.today ? app.service.clock.minutesOfDay() : 12 * 60;
    await app.run(() async {
      final entry = await app.service.addCaffeine(date, mg, time: time, label: label);
      app.showMessage(
        app.s.caffeineAdded('${app.fmt.integer(mg)} mg'),
        actionLabel: app.s.undo,
        onAction: () => app.service.deleteRecord(Collection.caffeineEntries, entry.id),
      );
    });
  }
}

class _IntakeTile extends StatelessWidget {
  const _IntakeTile({
    required this.title,
    required this.time,
    required this.onEdit,
    required this.onDelete,
  });

  final String title;
  final int? time;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final fmt = context.fmt;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      dense: true,
      title: Text(title),
      subtitle: time == null ? null : Text(fmt.time(time!)),
      onTap: onEdit,
      trailing: IconButton(
        tooltip: context.s.delete,
        icon: const Icon(Icons.delete_outline),
        onPressed: onDelete,
      ),
    );
  }
}

/// Deletes a record and offers "undo" in a snackbar.
Future<void> deleteWithUndo(BuildContext context, Collection collection, Record record) async {
  final app = context.appRead;
  await app.run(() async {
    await app.service.deleteRecord(collection, record.id);
    app.showMessage(
      app.s.entryDeleted,
      actionLabel: app.s.undo,
      onAction: () => app.service.restoreRecord(collection, record),
    );
  });
}

/// Dialog asking for a single amount.
Future<double?> askAmount(
  BuildContext context, {
  required String title,
  required String label,
  required String suffix,
  required double max,
  double? initial,
}) {
  final controller = TextEditingController(
    text: initial == null ? '' : context.appRead.fmt.input(initial),
  );
  final formKey = GlobalKey<FormState>();
  return showDialog<double>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Form(
        key: formKey,
        child: NumberField(
          controller: controller,
          label: label,
          suffix: suffix,
          min: 0,
          minExclusive: true,
          max: max,
          required: true,
          autofocus: true,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: Text(context.appRead.s.cancel),
        ),
        FilledButton(
          onPressed: () {
            if (formKey.currentState!.validate()) {
              Navigator.pop(dialogContext, Fmt.parseNumber(controller.text));
            }
          },
          child: Text(context.appRead.s.save),
        ),
      ],
    ),
  );
}

Future<(double, String?)?> askCaffeine(
  BuildContext context, {
  double? initialMg,
  String? initialLabel,
}) {
  final s = context.appRead.s;
  final amount = TextEditingController(
    text: initialMg == null ? '' : context.appRead.fmt.input(initialMg),
  );
  final label = TextEditingController(text: initialLabel ?? '');
  final formKey = GlobalKey<FormState>();
  return showDialog<(double, String?)>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(s.caffeine),
      content: Form(
        key: formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            NumberField(
              controller: amount,
              label: s.caffeineAmountMg,
              suffix: 'mg',
              min: 0,
              minExclusive: true,
              max: CaffeineEntry.maxMg,
              required: true,
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: label,
              maxLength: 60,
              decoration: InputDecoration(labelText: s.caffeineLabelOptional),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext), child: Text(s.cancel)),
        FilledButton(
          onPressed: () {
            if (formKey.currentState!.validate()) {
              final text = label.text.trim();
              Navigator.pop(dialogContext, (
                Fmt.parseNumber(amount.text)!,
                text.isEmpty ? null : text,
              ));
            }
          },
          child: Text(s.save),
        ),
      ],
    ),
  );
}

/// Edit dialog for a water entry (amount, date, time, delete).
Future<void> editWater(BuildContext context, WaterEntry entry) async {
  final app = context.appRead;
  final result = await showDialog<_IntakeEdit>(
    context: context,
    builder: (_) => _IntakeEditDialog(
      title: app.s.water,
      label: app.s.waterAmountMl,
      suffix: 'ml',
      max: WaterEntry.maxMl,
      amount: entry.amountMl,
      date: entry.date,
      time: entry.time,
    ),
  );
  if (result == null || !context.mounted) return;
  if (result.delete) {
    await deleteWithUndo(context, Collection.waterEntries, entry);
    return;
  }
  await app.run(() => app.service.updateWater(entry.copyWith(
    amountMl: result.amount,
    date: result.date,
    time: () => result.time,
    updatedAt: app.service.clock.nowUtc(),
  )));
}

Future<void> editCaffeine(BuildContext context, CaffeineEntry entry) async {
  final app = context.appRead;
  final result = await showDialog<_IntakeEdit>(
    context: context,
    builder: (_) => _IntakeEditDialog(
      title: app.s.caffeine,
      label: app.s.caffeineAmountMg,
      suffix: 'mg',
      max: CaffeineEntry.maxMg,
      amount: entry.amountMg,
      date: entry.date,
      time: entry.time,
      textLabel: app.s.caffeineLabelOptional,
      text: entry.label,
    ),
  );
  if (result == null || !context.mounted) return;
  if (result.delete) {
    await deleteWithUndo(context, Collection.caffeineEntries, entry);
    return;
  }
  await app.run(() => app.service.updateCaffeine(entry.copyWith(
    amountMg: result.amount,
    date: result.date,
    time: () => result.time,
    label: () => result.text,
    updatedAt: app.service.clock.nowUtc(),
  )));
}

class _IntakeEdit {
  _IntakeEdit(this.amount, this.date, this.time, this.text, {this.delete = false});
  final double amount;
  final LocalDate date;
  final int? time;
  final String? text;
  final bool delete;
}

class _IntakeEditDialog extends StatefulWidget {
  const _IntakeEditDialog({
    required this.title,
    required this.label,
    required this.suffix,
    required this.max,
    required this.amount,
    required this.date,
    required this.time,
    this.textLabel,
    this.text,
  });

  final String title;
  final String label;
  final String suffix;
  final double max;
  final double amount;
  final LocalDate date;
  final int? time;
  final String? textLabel;
  final String? text;

  @override
  State<_IntakeEditDialog> createState() => _IntakeEditDialogState();
}

class _IntakeEditDialogState extends State<_IntakeEditDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _amount;
  late final TextEditingController _text;
  late LocalDate _date = widget.date;
  late int? _time = widget.time;

  @override
  void initState() {
    super.initState();
    _amount = TextEditingController(text: context.appRead.fmt.input(widget.amount));
    _text = TextEditingController(text: widget.text ?? '');
  }

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    return AlertDialog(
      title: Text(widget.title),
      scrollable: true,
      content: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            NumberField(
              controller: _amount,
              label: widget.label,
              suffix: widget.suffix,
              min: 0,
              minExclusive: true,
              max: widget.max,
              required: true,
            ),
            const SizedBox(height: 12),
            DateField(date: _date, onChanged: (d) => setState(() => _date = d)),
            const SizedBox(height: 12),
            TimeField(minutes: _time, onChanged: (t) => setState(() => _time = t)),
            if (widget.textLabel != null) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _text,
                maxLength: 60,
                decoration: InputDecoration(labelText: widget.textLabel),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(
            context,
            _IntakeEdit(widget.amount, _date, _time, null, delete: true),
          ),
          child: Text(s.delete),
        ),
        TextButton(onPressed: () => Navigator.pop(context), child: Text(s.cancel)),
        FilledButton(
          onPressed: () {
            if (!_form.currentState!.validate()) return;
            final text = _text.text.trim();
            Navigator.pop(
              context,
              _IntakeEdit(
                Fmt.parseNumber(_amount.text)!,
                _date,
                _time,
                text.isEmpty ? null : text,
              ),
            );
          },
          child: Text(s.save),
        ),
      ],
    );
  }
}
