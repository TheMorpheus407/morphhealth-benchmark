import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/utils.dart';
import 'controller.dart';
import 'l10n.dart';

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.title,
    this.icon,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.children = const [],
  });

  final String title;
  final IconData? icon;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final content = Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                  ],
                ),
              ),
              ?trailing,
            ],
          ),
          if (children.isNotEmpty) ...[const SizedBox(height: 12), ...children],
        ],
      ),
    );
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      clipBehavior: Clip.antiAlias,
      child: onTap == null ? content : InkWell(onTap: onTap, child: content),
    );
  }
}

class DateSelector extends StatelessWidget {
  const DateSelector({super.key, required this.date, required this.onChanged});

  final String date;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final strings = l10n(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        IconButton(
          tooltip: '−1 ${strings.t('day')}',
          onPressed: () => onChanged(dateKey(addDays(parseDate(date), -1))),
          icon: const Icon(Icons.chevron_left),
        ),
        Flexible(
          child: TextButton.icon(
            key: const ValueKey('date-picker'),
            onPressed: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: parseDate(date),
                firstDate: DateTime(1900),
                lastDate: DateTime(2100),
              );
              if (picked != null) onChanged(dateKey(picked));
            },
            icon: const Icon(Icons.calendar_today),
            label: Text(strings.date(date), overflow: TextOverflow.ellipsis),
          ),
        ),
        IconButton(
          tooltip: '+1 ${strings.t('day')}',
          onPressed: () => onChanged(dateKey(addDays(parseDate(date), 1))),
          icon: const Icon(Icons.chevron_right),
        ),
      ],
    );
  }
}

class DateField extends StatelessWidget {
  const DateField({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.event),
      title: Text(label),
      subtitle: Text(l10n(context).date(value)),
      trailing: const Icon(Icons.edit_calendar),
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: parseDate(value),
          firstDate: DateTime(1900),
          lastDate: DateTime(2100),
        );
        if (picked != null) onChanged(dateKey(picked));
      },
    );
  }
}

class DateTimeFields extends StatelessWidget {
  const DateTimeFields({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final DateTime value;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) {
    final strings = l10n(context);
    final local = value.toLocal();
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: DateField(
            label: strings.t('date'),
            value: dateKey(local),
            onChanged: (date) {
              final parsed = parseDate(date);
              onChanged(
                DateTime(
                  parsed.year,
                  parsed.month,
                  parsed.day,
                  local.hour,
                  local.minute,
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          flex: 2,
          child: ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(strings.t('time')),
            subtitle: Text(strings.time(value)),
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: TimeOfDay.fromDateTime(local),
              );
              if (picked != null) {
                onChanged(
                  DateTime(
                    local.year,
                    local.month,
                    local.day,
                    picked.hour,
                    picked.minute,
                  ),
                );
              }
            },
          ),
        ),
      ],
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.text,
    this.icon = Icons.inbox_outlined,
  });
  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(32),
    child: Center(
      child: Column(
        children: [
          Icon(icon, size: 40, color: Theme.of(context).colorScheme.outline),
          const SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

Future<bool> confirmDeletion(BuildContext context) async {
  final strings = l10n(context);
  return await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          scrollable: true,
          title: Text(strings.t('confirm_delete')),
          content: Text(strings.t('confirm_delete_message')),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(strings.t('cancel')),
            ),
            FilledButton(
              key: const ValueKey('confirm-delete'),
              onPressed: () => Navigator.pop(context, true),
              child: Text(strings.t('delete')),
            ),
          ],
        ),
      ) ??
      false;
}

void showError(BuildContext context, [String? message]) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(content: Text(message ?? l10n(context).t('error'))),
    );
}

void showMessage(BuildContext context, String message) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

double? parseAmount(String value) => double.tryParse(
  value.trim().replaceAll(',', '.').replaceAll(RegExp(r'\s'), ''),
);

String selectedDateOf(BuildContext context) =>
    context.watch<AppController>().selectedDate;

InputDecoration fieldDecoration(String label, {String? suffix}) =>
    InputDecoration(
      label: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
      helperText: suffix,
      border: const OutlineInputBorder(),
    );
