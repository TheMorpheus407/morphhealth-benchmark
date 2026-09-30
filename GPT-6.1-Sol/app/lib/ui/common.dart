import 'package:flutter/material.dart';
import '../core/model.dart';
import '../core/nutrients.dart';
import 'controller.dart';

const ink = Color(0xff203d37);
const sage = Color(0xffe3eee5);
const rose = Color(0xffa34962);
const canvas = Color(0xfff7f8f3);

class Panel extends StatelessWidget {
  final Widget child;
  final Color? color;
  const Panel({super.key, required this.child, this.color});
  @override
  Widget build(BuildContext context) => Card(
    color: color,
    margin: const EdgeInsets.only(bottom: 16),
    child: Padding(padding: const EdgeInsets.all(20), child: child),
  );
}

class Heading extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  const Heading(this.title, {super.key, this.subtitle, this.trailing});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
            ],
          ),
        ),
        ?trailing,
      ],
    ),
  );
}

class EmptyNote extends StatelessWidget {
  final String text;
  const EmptyNote(this.text, {super.key});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 18),
    child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
  );
}

Future<void> notifyError(BuildContext context, Object error) async {
  if (!context.mounted) return;
  final c = AppScope.of(context);
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text(c.error(error))));
}

void notice(BuildContext context, String text) {
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
}

Future<bool> confirm(
  BuildContext context,
  String title,
  String body, {
  String? action,
}) async {
  final c = AppScope.of(context);
  return await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Text(body),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(c.tr('Abbrechen', 'Cancel')),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(action ?? c.tr('Löschen', 'Delete')),
            ),
          ],
        ),
      ) ??
      false;
}

Future<void> deleteRecord(BuildContext context, String table, String id) async {
  final c = AppScope.of(context);
  if (await confirm(
    context,
    c.tr('Eintrag löschen?', 'Delete entry?'),
    c.tr(
      'Dieser Eintrag wird aus deinem Tagebuch entfernt.',
      'This entry will be removed from your journal.',
    ),
  )) {
    try {
      await c.remove(table, id);
    } catch (e) {
      if (context.mounted) await notifyError(context, e);
    }
  }
}

String? numericValidation(
  String? text,
  AppController c, {
  bool optional = false,
  bool zero = false,
}) {
  if (optional && (text ?? '').trim().isEmpty) return null;
  final value = number(text?.trim());
  if (value == null || !value.isFinite || (zero ? value < 0 : value <= 0)) {
    return c.tr(
      zero ? 'Zahl ab 0 eingeben' : 'Positive Zahl eingeben',
      zero ? 'Enter a number ≥0' : 'Enter a positive number',
    );
  }
  return null;
}

String? requiredValidation(String? value, AppController c) =>
    (value ?? '').trim().isEmpty ? c.tr('Bitte ausfüllen', 'Required') : null;

class DayBar extends StatelessWidget {
  const DayBar({super.key});
  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          IconButton(
            tooltip: c.tr('Voriger Tag', 'Previous day'),
            onPressed: () => c.day(addDays(c.selectedDay, -1)),
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: TextButton.icon(
              onPressed: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: parseDay(c.selectedDay),
                  firstDate: DateTime(1900),
                  lastDate: DateTime(2200),
                );
                if (d != null) c.day(dateKey(d));
              },
              icon: const Icon(Icons.calendar_today_outlined, size: 18),
              label: Text(c.date(c.selectedDay)),
            ),
          ),
          IconButton(
            tooltip: c.tr('Nächster Tag', 'Next day'),
            onPressed: () => c.day(addDays(c.selectedDay, 1)),
            icon: const Icon(Icons.chevron_right),
          ),
          if (c.selectedDay != c.engine.clock.today)
            IconButton(
              tooltip: c.tr('Heute', 'Today'),
              onPressed: () => c.day(c.engine.clock.today),
              icon: const Icon(Icons.today),
            ),
        ],
      ),
    );
  }
}

class DateField extends StatelessWidget {
  final String label, value;
  final ValueChanged<String> onChanged;
  const DateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });
  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: OutlinedButton.icon(
        onPressed: () async {
          final d = await showDatePicker(
            context: context,
            initialDate: parseDay(value),
            firstDate: DateTime(1900),
            lastDate: DateTime(2200),
          );
          if (d != null) onChanged(dateKey(d));
        },
        icon: const Icon(Icons.calendar_month_outlined),
        label: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Text('$label · ${c.date(value, short: true)}'),
        ),
      ),
    );
  }
}

class TimeField extends StatelessWidget {
  final TimeOfDay value;
  final ValueChanged<TimeOfDay> onChanged;
  const TimeField({super.key, required this.value, required this.onChanged});
  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: OutlinedButton.icon(
        onPressed: () async {
          final t = await showTimePicker(context: context, initialTime: value);
          if (t != null) onChanged(t);
        },
        icon: const Icon(Icons.schedule),
        label: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14),
          child: Text('${c.tr('Uhrzeit', 'Time')} · ${value.format(context)}'),
        ),
      ),
    );
  }
}

String atTime(String day, TimeOfDay t) =>
    '${day}T${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';
TimeOfDay parseTime(String? at) => at == null
    ? TimeOfDay.now()
    : TimeOfDay(
        hour: int.parse(at.substring(11, 13)),
        minute: int.parse(at.substring(14, 16)),
      );

class NutrientTable extends StatelessWidget {
  final Json values;
  final Json? coverage;
  final int? foodCount;
  const NutrientTable({
    super.key,
    required this.values,
    this.coverage,
    this.foodCount,
  });
  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    return Column(
      children: [
        for (final n in nutrients)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 9),
            child: Row(
              children: [
                Expanded(child: Text(n.name(c.language))),
                Text(
                  '${c.fmt(values[n.id], digits: 3)} ${n.unit}',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                if (coverage != null &&
                    foodCount != null &&
                    (coverage![n.id] as int) < foodCount!)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: Tooltip(
                      message: c.tr(
                        'Unvollständig: Werte fehlen bei Lebensmitteln',
                        'Incomplete: some foods have missing values',
                      ),
                      child: const Icon(Icons.info_outline, size: 16),
                    ),
                  ),
              ],
            ),
          ),
        const SizedBox(height: 8),
        Text(
          c.tr(
            '— bedeutet unbekannt. Summen mit fehlenden Angaben sind unvollständig.',
            '— means unknown. Totals with missing values are incomplete.',
          ),
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    );
  }
}

class FormFrame extends StatelessWidget {
  final String title;
  final List<Widget> children;
  final bool busy;
  final VoidCallback save;
  final VoidCallback? delete;
  final String? error;
  const FormFrame({
    super.key,
    required this.title,
    required this.children,
    required this.busy,
    required this.save,
    this.delete,
    this.error,
  });
  @override
  Widget build(BuildContext context) {
    final c = AppScope.of(context);
    return PopScope(
      canPop: !busy,
      child: Scaffold(
        appBar: AppBar(
          title: Text(title),
          actions: [
            if (delete != null)
              IconButton(
                tooltip: c.tr('Löschen', 'Delete'),
                onPressed: busy ? null : delete,
                icon: const Icon(Icons.delete_outline),
              ),
          ],
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              ...children,
              if (error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: busy ? null : save,
                icon: busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  child: Text(c.tr('Speichern', 'Save')),
                ),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}
