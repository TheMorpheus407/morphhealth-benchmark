import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/civil.dart';
import '../format.dart';
import '../l10n_x.dart';
import 'common.dart';

/// Zahlenfeld, das Komma und Punkt als Dezimaltrenner versteht.
class NumberField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? suffix;
  final String? helper;
  final bool required;
  final bool positive;
  final double? max;
  final ValueChanged<String>? onChanged;
  final TextInputAction? action;
  final FocusNode? focusNode;
  final bool autofocus;

  const NumberField({
    super.key,
    required this.controller,
    required this.label,
    this.suffix,
    this.helper,
    this.required = false,
    this.positive = false,
    this.max,
    this.onChanged,
    this.action,
    this.focusNode,
    this.autofocus = false,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      autofocus: autofocus,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      textInputAction: action,
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
      onChanged: onChanged,
      decoration: InputDecoration(labelText: label, suffixText: suffix, helperText: helper),
      validator: (v) {
        final t = v?.trim() ?? '';
        if (t.isEmpty) return required ? l.commonRequired : null;
        final n = Fmt.parse(t);
        if (n == null) return l.commonInvalidNumber;
        if (positive && n <= 0) return l.commonMustBePositive;
        if (n < 0) return l.commonInvalidNumber;
        if (max != null && n > max!) return l.commonInvalidNumber;
        return null;
      },
    );
  }
}

/// Zeile mit Datum- und Uhrzeitwahl.
class DateTimeRow extends StatelessWidget {
  final Day day;
  final TimeOfDay time;
  final ValueChanged<Day> onDay;
  final ValueChanged<TimeOfDay> onTime;
  final Day? first;
  final Day? last;

  const DateTimeRow({
    super.key,
    required this.day,
    required this.time,
    required this.onDay,
    required this.onTime,
    this.first,
    this.last,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final f = context.fmt;
    return ControlGroup(
      child: Row(
        children: [
          Expanded(
            flex: 3,
            child: OutlinedButton.icon(
              style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52), alignment: Alignment.centerLeft),
              icon: const Icon(Icons.event),
              label: Text(f.dateWithWeekday(day), overflow: TextOverflow.ellipsis),
              onPressed: () async {
                final d = await pickDay(context, day, first: first, last: last);
                if (d != null) onDay(d);
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: Semantics(
              label: '${l.commonTime}: ${f.timeOfHm(time.hour, time.minute)}',
              button: true,
              excludeSemantics: true,
              onTap: () async {
                final t = await pickTime(context, time);
                if (t != null) onTime(t);
              },
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52), alignment: Alignment.centerLeft),
                icon: const Icon(Icons.schedule),
                label: Text(f.timeOfHm(time.hour, time.minute)),
                onPressed: () async {
                  final t = await pickTime(context, time);
                  if (t != null) onTime(t);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
