import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/l10n/format.dart';
import '../../core/util/local_date.dart';
import '../controller.dart';
import '../theme.dart';

/// Numeric text field accepting "," or "." as decimal separator.
class NumberField extends StatelessWidget {
  const NumberField({
    super.key,
    required this.controller,
    required this.label,
    this.suffix,
    this.min,
    this.max,
    this.required = false,
    this.allowDecimals = true,
    this.helper,
    this.autofocus = false,
    this.onChanged,
    this.textInputAction,
    this.minExclusive = false,
  });

  final TextEditingController controller;
  final String label;
  final String? suffix;
  final double? min;
  final double? max;
  final bool minExclusive;
  final bool required;
  final bool allowDecimals;
  final String? helper;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final TextInputAction? textInputAction;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final fmt = context.fmt;
    return TextFormField(
      controller: controller,
      autofocus: autofocus,
      keyboardType: TextInputType.numberWithOptions(decimal: allowDecimals),
      textInputAction: textInputAction,
      inputFormatters: [
        FilteringTextInputFormatter.allow(RegExp(allowDecimals ? r'[0-9.,]' : r'[0-9]')),
      ],
      decoration: InputDecoration(labelText: label, suffixText: suffix, helperText: helper, helperMaxLines: 3),
      onChanged: onChanged,
      validator: (text) {
        if (text == null || text.trim().isEmpty) {
          return required ? s.fieldRequired : null;
        }
        final v = Fmt.parseNumber(text);
        if (v == null) return s.invalidNumber;
        final lo = min;
        final hi = max;
        final tooLow = lo != null && (minExclusive ? v <= lo : v < lo);
        if (tooLow || (hi != null && v > hi)) {
          return s.numberRange(fmt.number(lo ?? 0, 2), fmt.number(hi ?? double.infinity, 2));
        }
        return null;
      },
    );
  }
}

/// A button-like field that shows a date and opens the date picker.
class DateField extends StatelessWidget {
  const DateField({
    super.key,
    required this.date,
    required this.onChanged,
    this.label,
    this.first,
    this.last,
  });

  final LocalDate date;
  final ValueChanged<LocalDate> onChanged;
  final String? label;
  final LocalDate? first;
  final LocalDate? last;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    return _PickerTile(
      icon: Icons.event_outlined,
      label: label ?? app.s.date,
      value: app.fmt.weekdayDayMonth(date) + (date.year == app.today.year ? '' : ' ${date.year}'),
      onTap: () async {
        final picked = await pickDate(
          context,
          initial: date,
          first: first,
          last: last,
        );
        if (picked != null) onChanged(picked);
      },
    );
  }
}

Future<LocalDate?> pickDate(
  BuildContext context, {
  required LocalDate initial,
  LocalDate? first,
  LocalDate? last,
}) async {
  final lo = first ?? LocalDate(2000, 1, 1);
  final hi = last ?? LocalDate(2100, 12, 31);
  final init = initial.isBefore(lo) ? lo : (initial.isAfter(hi) ? hi : initial);
  final picked = await showDatePicker(
    context: context,
    initialDate: init.toDateTime(),
    firstDate: lo.toDateTime(),
    lastDate: hi.toDateTime(),
  );
  return picked == null ? null : LocalDate.fromDateTime(picked);
}

/// A button-like field for the time of day (minutes since midnight).
class TimeField extends StatelessWidget {
  const TimeField({super.key, required this.minutes, required this.onChanged, this.label});

  final int? minutes;
  final ValueChanged<int?> onChanged;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    return _PickerTile(
      icon: Icons.schedule_outlined,
      label: label ?? app.s.time,
      value: minutes == null ? '–' : app.fmt.time(minutes!),
      onTap: () async {
        final initial = minutes ?? app.service.clock.minutesOfDay();
        final picked = await showTimePicker(
          context: context,
          initialTime: TimeOfDay(hour: initial ~/ 60, minute: initial % 60),
        );
        if (picked != null) onChanged(picked.hour * 60 + picked.minute);
      },
    );
  }
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label: $value',
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(4),
        child: InputDecorator(
          decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon)),
          child: Text(value, style: context.text.bodyLarge),
        ),
      ),
    );
  }
}

/// Parses a list like "150, 250 330" into positive integers.
List<int>? parseIntList(String text, int max) {
  final parts = text.split(RegExp(r'[\s,;]+')).where((p) => p.isNotEmpty).toList();
  if (parts.isEmpty || parts.length > 6) return null;
  final values = <int>[];
  for (final p in parts) {
    final v = int.tryParse(p);
    if (v == null || v <= 0 || v > max) return null;
    values.add(v);
  }
  return values;
}
