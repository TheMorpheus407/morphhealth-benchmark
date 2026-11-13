import 'package:flutter/material.dart';
import 'package:morphhealth_core/morphhealth_core.dart';

import '../format.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// The time for a new entry on [day]: now for today, noon for other days.
LocalDateTime defaultEntryTime(BuildContext context, Day day) {
  final app = context.appRead;
  final now = app.now;
  return day == app.today
      ? LocalDateTime(day, now.hour, now.minute, 0, now.offsetMinutes)
      : LocalDateTime(day, 12, 0);
}

/// Records [ml] of water on [day] and offers to undo it.
Future<void> quickAddWater(BuildContext context, Day day, double ml) async {
  final repo = context.appRead.repository;
  final l = context.l;
  final fmt = context.fmt;
  WaterEntry? entry;
  final ok = await guarded(context, () async {
    entry = await repo.addWater(ml, at: defaultEntryTime(context, day));
  });
  if (ok && context.mounted) {
    showSnack(
      context,
      l.waterAdded(fmt.ml(ml)),
      onUndo: () => repo.deleteWater(entry!.id),
    );
  }
}

/// Records [mg] of caffeine on [day] and offers to undo it.
Future<void> quickAddCaffeine(
  BuildContext context,
  Day day,
  double mg,
  String label,
) async {
  final repo = context.appRead.repository;
  final l = context.l;
  final fmt = context.fmt;
  CaffeineEntry? entry;
  final ok = await guarded(context, () async {
    entry = await repo.addCaffeine(
      mg,
      label: label,
      at: defaultEntryTime(context, day),
    );
  });
  if (ok && context.mounted) {
    showSnack(
      context,
      l.caffeineAdded(fmt.mg(mg)),
      onUndo: () => repo.deleteCaffeine(entry!.id),
    );
  }
}

/// Water and caffeine of one day with one-tap entry.
class WaterCaffeineCard extends StatelessWidget {
  final Day day;

  /// Leaves out the list links, for the overview.
  final bool compact;

  const WaterCaffeineCard({super.key, required this.day, this.compact = false});

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final fmt = context.fmt;
    final app = context.app;
    final colors = MhColors.of(context);
    final summary = app.nutritionDay(day);
    final goal = summary.waterProgress;
    final presets = [(l.espresso, 60.0), (l.coffee, 90.0), (l.tea, 45.0)];

    // On the overview the chips stay on one line and scroll sideways, so
    // that the card leaves room for the other areas.
    Widget chips(List<Widget> children) => compact
        ? SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final c in children)
                  Padding(
                    padding: const EdgeInsetsDirectional.only(end: 8),
                    child: c,
                  ),
              ],
            ),
          )
        : Wrap(spacing: 8, runSpacing: 4, children: children);

    return MhCard(
      title: l.waterAndCaffeine,
      icon: Icons.local_drink_outlined,
      iconColor: colors.water,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GoalBar(
            label: l.water,
            value: goal == null
                ? fmt.volume(summary.waterMl)
                : l.ofGoal(
                    fmt.number(summary.waterMl, decimals: 0),
                    fmt.number(goal.goal, decimals: 0),
                    'ml',
                  ),
            fraction: goal?.fraction,
            color: colors.water,
          ),
          const SizedBox(height: 10),
          chips([
            for (final ml in app.settings.waterQuickAmountsMl)
              ActionChip(
                avatar: Icon(Icons.add, size: 18, color: colors.water),
                label: Text(
                  fmt.ml(ml.toDouble()),
                  semanticsLabel: l.addWaterSemantics(fmt.ml(ml.toDouble())),
                ),
                onPressed: () => quickAddWater(context, day, ml.toDouble()),
              ),
            ActionChip(
              label: Text(l.otherAmount),
              onPressed: () => showWaterEditor(context, day: day),
            ),
          ]),
          compact ? const SizedBox(height: 12) : const Divider(height: 28),
          GoalBar(
            label: l.caffeine,
            value: summary.caffeineFoodMg > 0
                ? '${fmt.mg(summary.caffeineTotalMg)} '
                      '(${fmt.mg(summary.caffeineFoodMg)} ${l.caffeineFromFood})'
                : fmt.mg(summary.caffeineTotalMg),
          ),
          const SizedBox(height: 10),
          chips([
            for (final p in presets)
              ActionChip(
                avatar: Icon(Icons.add, size: 18, color: colors.caffeine),
                label: Text(
                  '${p.$1} ${fmt.mg(p.$2)}',
                  semanticsLabel: l.addCaffeineSemantics(p.$1, fmt.mg(p.$2)),
                ),
                onPressed: () => quickAddCaffeine(context, day, p.$2, p.$1),
              ),
            ActionChip(
              label: Text(l.otherAmount),
              onPressed: () => showCaffeineEditor(context, day: day),
            ),
          ]),
          if (!compact &&
              (summary.water.isNotEmpty || summary.caffeine.isNotEmpty))
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                icon: const Icon(Icons.list),
                label: Text(
                  '${l.showEntries} (${summary.water.length + summary.caffeine.length})',
                ),
                onPressed: () => showHydrationEntries(context, day),
              ),
            ),
        ],
      ),
    );
  }
}

/// Lists the water and caffeine entries of [day] for editing.
Future<void> showHydrationEntries(BuildContext context, Day day) {
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    // The sheet ends above the system navigation bar.
    builder: (context) => SafeArea(
      top: false,
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (context, scroll) =>
            HydrationEntryList(day: day, scrollController: scroll),
      ),
    ),
  );
}

/// The water and caffeine entries of a day as tappable rows.
class HydrationEntryList extends StatelessWidget {
  final Day day;
  final ScrollController? scrollController;
  final bool shrinkWrap;

  const HydrationEntryList({
    super.key,
    required this.day,
    this.scrollController,
    this.shrinkWrap = false,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final fmt = context.fmt;
    final colors = MhColors.of(context);
    final summary = context.app.nutritionDay(day);
    final tiles = <Widget>[
      for (final w in summary.water)
        ListTile(
          leading: Icon(Icons.water_drop_outlined, color: colors.water),
          title: Text('${l.water}, ${fmt.ml(w.amountMl)}'),
          subtitle: Text(fmt.time(w.at)),
          trailing: const Icon(Icons.edit_outlined),
          onTap: () => showWaterEditor(context, day: day, entry: w),
        ),
      for (final c in summary.caffeine)
        ListTile(
          leading: Icon(Icons.coffee_outlined, color: colors.caffeine),
          title: Text('${c.label ?? l.caffeine}, ${fmt.mg(c.amountMg)}'),
          subtitle: Text(fmt.time(c.at)),
          trailing: const Icon(Icons.edit_outlined),
          onTap: () => showCaffeineEditor(context, day: day, entry: c),
        ),
    ];
    if (tiles.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text(l.nothingLoggedYet, textAlign: TextAlign.center),
      );
    }
    return ListView(
      controller: scrollController,
      shrinkWrap: shrinkWrap,
      physics: shrinkWrap ? const NeverScrollableScrollPhysics() : null,
      padding: EdgeInsets.zero,
      children: tiles,
    );
  }
}

/// Dialog for a new or existing water entry.
Future<void> showWaterEditor(
  BuildContext context, {
  required Day day,
  WaterEntry? entry,
}) => showDialog<void>(
  context: context,
  builder: (_) => _AmountDialog(
    title: entry == null ? context.l.waterEntry : context.l.waterEdit,
    amountLabel: context.l.amountMl,
    unit: 'ml',
    max: 20000,
    initialAmount: entry?.amountMl,
    initialTime: entry?.at ?? defaultEntryTime(context, day),
    onDelete: entry == null ? null : (repo) => repo.deleteWater(entry.id),
    onUndoDelete: entry == null ? null : (repo) => repo.saveWater(entry),
    onSave: (repo, amount, at, _) => entry == null
        ? repo.addWater(amount, at: at)
        : repo.saveWater(entry.copyWith(amountMl: amount, at: at)),
  ),
);

/// Dialog for a new or existing caffeine entry.
Future<void> showCaffeineEditor(
  BuildContext context, {
  required Day day,
  CaffeineEntry? entry,
}) => showDialog<void>(
  context: context,
  builder: (_) => _AmountDialog(
    title: entry == null ? context.l.caffeineEntry : context.l.caffeineEdit,
    amountLabel: context.l.amountMg,
    unit: 'mg',
    max: 5000,
    withLabel: true,
    initialLabel: entry?.label,
    initialAmount: entry?.amountMg,
    initialTime: entry?.at ?? defaultEntryTime(context, day),
    onDelete: entry == null ? null : (repo) => repo.deleteCaffeine(entry.id),
    onUndoDelete: entry == null ? null : (repo) => repo.saveCaffeine(entry),
    onSave: (repo, amount, at, label) => entry == null
        ? repo.addCaffeine(amount, at: at, label: label)
        : repo.saveCaffeine(
            entry.copyWith(amountMg: amount, at: at, label: label),
          ),
  ),
);

class _AmountDialog extends StatefulWidget {
  final String title;
  final String amountLabel;
  final String unit;
  final double max;
  final bool withLabel;
  final String? initialLabel;
  final double? initialAmount;
  final LocalDateTime initialTime;
  final Future<Object?> Function(
    HealthRepository repo,
    double amount,
    LocalDateTime at,
    String? label,
  )
  onSave;
  final Future<void> Function(HealthRepository repo)? onDelete;
  final Future<Object?> Function(HealthRepository repo)? onUndoDelete;

  const _AmountDialog({
    required this.title,
    required this.amountLabel,
    required this.unit,
    required this.max,
    required this.initialTime,
    required this.onSave,
    this.withLabel = false,
    this.initialLabel,
    this.initialAmount,
    this.onDelete,
    this.onUndoDelete,
  });

  @override
  State<_AmountDialog> createState() => _AmountDialogState();
}

class _AmountDialogState extends State<_AmountDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _label = TextEditingController();
  late LocalDateTime _at = widget.initialTime;
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final a = widget.initialAmount;
    if (a != null) {
      _amount.text = Fmt.of(context, today: context.appRead.today).editable(a);
    }
    _label.text = widget.initialLabel ?? '';
  }

  @override
  void dispose() {
    _amount.dispose();
    _label.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final amount = Fmt.parse(_amount.text);
    if (amount == null) return;
    final repo = context.appRead.repository;
    final label = _label.text.trim().isEmpty ? null : _label.text.trim();
    final ok = await guarded(
      context,
      () => widget.onSave(repo, amount, _at, label),
    );
    if (ok && mounted) Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final repo = context.appRead.repository;
    final l = context.l;
    final messenger = ScaffoldMessenger.of(context);
    final ok = await guarded(context, () => widget.onDelete!(repo));
    if (!ok || !mounted) return;
    Navigator.of(context).pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(l.entryDeleted),
          duration: const Duration(seconds: 6),
          action: SnackBarAction(
            label: l.undo,
            onPressed: () => widget.onUndoDelete!(repo),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    return AlertDialog(
      title: Text(widget.title),
      scrollable: true,
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            NumberField(
              controller: _amount,
              label: widget.amountLabel,
              unit: widget.unit,
              required: true,
              allowZero: false,
              max: widget.max,
              autofocus: widget.initialAmount == null,
              onSubmitted: (_) => _save(),
            ),
            if (widget.withLabel) ...[
              const SizedBox(height: 12),
              TextFormField(
                enableIMEPersonalizedLearning: false,
                controller: _label,
                maxLength: 100,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: l.caffeineLabel,
                  hintText: l.caffeineLabelHint,
                  counterText: '',
                ),
              ),
            ],
            const SizedBox(height: 12),
            DateTimeFields(
              value: _at,
              onChanged: (v) => setState(() => _at = v),
            ),
          ],
        ),
      ),
      actions: [
        if (widget.onDelete != null)
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: _delete,
            child: Text(l.delete),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.cancel),
        ),
        FilledButton(onPressed: _save, child: Text(l.save)),
      ],
    );
  }
}
