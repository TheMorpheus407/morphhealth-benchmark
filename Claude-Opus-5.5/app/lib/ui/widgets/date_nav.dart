import 'package:flutter/material.dart';

import '../../core/util/local_date.dart';
import '../controller.dart';
import '../theme.dart';
import 'inputs.dart';

/// Previous/next day buttons around the selected date; tapping the date
/// opens a calendar that can go back to older months.
class DateNavigator extends StatelessWidget {
  const DateNavigator({super.key, required this.date, required this.onChanged});

  final LocalDate date;
  final ValueChanged<LocalDate> onChanged;

  @override
  Widget build(BuildContext context) {
    final app = context.app;
    final s = app.s;
    final today = app.today;
    String label;
    if (date == today) {
      label = s.today;
    } else if (date == today.addDays(-1)) {
      label = s.yesterday;
    } else if (date == today.addDays(1)) {
      label = s.tomorrow;
    } else {
      label = app.fmt.weekdayDayMonth(date);
    }
    final full = app.fmt.full(date);
    Future<void> choose() async {
      final picked = await pickDate(context, initial: date);
      if (picked != null) onChanged(picked);
    }

    return Row(
      children: [
        IconButton(
          tooltip: s.previousDay,
          icon: const Icon(Icons.chevron_left),
          onPressed: () => onChanged(date.addDays(-1)),
        ),
        Expanded(
          child: Semantics(
            button: true,
            label: '${s.chooseDate}: $full',
            onTap: choose,
            excludeSemantics: true,
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: choose,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    Text(label, style: context.text.titleMedium, textAlign: TextAlign.center),
                    if (label != app.fmt.weekdayDayMonth(date))
                      Text(
                        app.fmt.weekdayDayMonth(date),
                        style: context.text.bodySmall?.copyWith(color: context.scheme.onSurfaceVariant),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        if (date != today)
          TextButton(onPressed: () => onChanged(today), child: Text(s.today)),
        IconButton(
          tooltip: s.nextDay,
          icon: const Icon(Icons.chevron_right),
          onPressed: () => onChanged(date.addDays(1)),
        ),
      ],
    );
  }
}
