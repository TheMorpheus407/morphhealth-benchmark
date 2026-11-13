/// Shared accessible calendar date navigation bar.
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/clock.dart';
import '../app_controller.dart';

String formatHumanDate(String dateIso, String localeCode, {String? todayIso}) {
  final dt = IsoDate.parseUtc(dateIso);
  final localDate = DateTime(dt.year, dt.month, dt.day);
  final fmt = DateFormat(
    localeCode == 'en' ? 'EEE, MMM d, yyyy' : 'EEE, dd.MM.yyyy',
    localeCode == 'en' ? 'en_US' : 'de_DE',
  );
  final formatted = fmt.format(localDate);
  if (todayIso != null && dateIso == todayIso) {
    final prefix = localeCode == 'en' ? 'Today · ' : 'Heute · ';
    return '$prefix$formatted';
  }
  return formatted;
}

class MhDateSelectorBar extends StatelessWidget {
  final AppController controller;

  const MhDateSelectorBar({super.key, required this.controller});

  Future<void> _pickCalendarDate(BuildContext context) async {
    final current = IsoDate.parseUtc(controller.selectedDate);
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(current.year, current.month, current.day),
      firstDate: DateTime(1990, 1, 1),
      lastDate: DateTime(2100, 12, 31),
      locale: Locale(controller.localeCode),
      helpText: controller.strings.pickDate,
    );
    if (picked != null) {
      controller.setSelectedDate(IsoDate.fromLocalDateTime(picked));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = controller.strings;
    final cs = Theme.of(context).colorScheme;
    final dateText = formatHumanDate(
      controller.selectedDate,
      controller.localeCode,
      todayIso: controller.todayDate,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: cs.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          IconButton(
            tooltip: s.previousDay,
            onPressed: () => controller.stepSelectedDate(-1),
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          Expanded(
            child: InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: () => _pickCalendarDate(context),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 16,
                      color: cs.primary,
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        dateText,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 14.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (!controller.isOnToday)
            Padding(
              padding: const EdgeInsets.only(right: 2),
              child: TextButton(
                onPressed: controller.jumpToToday,
                style: TextButton.styleFrom(
                  visualDensity: VisualDensity.compact,
                  minimumSize: const Size(48, 40),
                ),
                child: Text(s.today),
              ),
            ),
          IconButton(
            tooltip: s.nextDay,
            onPressed: () => controller.stepSelectedDate(1),
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }
}
