import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/civil.dart';
import '../l10n_x.dart';

/// Abschnittskarte mit Überschrift, Symbol und optionaler Aktion.
class SectionCard extends StatelessWidget {
  final String title;
  final IconData? icon;
  final Color? accent;
  final Widget? trailing;
  final Widget child;
  final EdgeInsetsGeometry padding;

  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.icon,
    this.accent,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(16, 14, 16, 16),
  });

  @override
  Widget build(BuildContext context) {
    final color = accent ?? context.colors.primary;
    final titleRow = Row(
      children: [
        if (icon != null) ...[Icon(icon, color: color, size: 22), const SizedBox(width: 10)],
        Expanded(
          child: Semantics(
            header: true,
            child: Text(title, style: context.text.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          ),
        ),
      ],
    );
    // Bei stark vergrößerter Schrift rutscht die Aktion unter die Überschrift.
    final stacked = trailing != null && MediaQuery.textScalerOf(context).scale(1.0) > 1.3;
    final Widget header = trailing == null
        ? titleRow
        : stacked
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              titleRow,
              Align(alignment: Alignment.centerRight, child: trailing),
            ],
          )
        : Row(
            children: [
              Expanded(child: titleRow),
              trailing!,
            ],
          );
    final content = Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [header, const SizedBox(height: 12), child],
      ),
    );
    return Card(
      clipBehavior: Clip.antiAlias,
      child: ControlGroup(child: content),
    );
  }
}

/// Unterer Abstand für Blätter: über der Tastatur, sonst über der System-Navigationsleiste.
/// Android zeichnet randlos, und `showModalBottomSheet(useSafeArea: true)` schützt unten nicht.
double sheetBottomInset(BuildContext context) {
  final m = MediaQuery.of(context);
  return math.max(m.viewInsets.bottom, m.viewPadding.bottom);
}

/// Gruppe für Inhalte mit mehreren Bedienelementen. Jedes Kind bleibt ein
/// eigener Knoten für Screenreader und Automatisierung. Ohne Gruppe verschmilzt
/// Flutter die Beschriftungen innerhalb einer Karte, und in einem Listeneintrag
/// mit mehreren Elementen nebeneinander bekommt das erste, zum Beispiel ein
/// Textfeld, die Fläche der ganzen Zeile, während die übrigen als seine Kinder
/// gemeldet werden.
class ControlGroup extends StatelessWidget {
  final Widget child;

  const ControlGroup({super.key, required this.child});

  @override
  Widget build(BuildContext context) => Semantics(container: true, explicitChildNodes: true, child: child);
}

/// Text mit Erklärung für leere Bereiche.
class EmptyHint extends StatelessWidget {
  final String text;
  final IconData? icon;

  const EmptyHint(this.text, {super.key, this.icon});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (icon != null) ...[Icon(icon, size: 20, color: context.colors.outline), const SizedBox(width: 8)],
        Expanded(
          child: Text(text, style: context.text.bodyMedium?.copyWith(color: context.colors.onSurfaceVariant)),
        ),
      ],
    ),
  );
}

/// Tag wählen: zurück, Datum (öffnet die Kalenderauswahl), weiter, "Heute".
class DayNavigator extends StatelessWidget {
  final Day day;
  final Day today;
  final ValueChanged<Day> onChanged;

  const DayNavigator({super.key, required this.day, required this.today, required this.onChanged});

  Future<void> _pick(BuildContext context) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: day.toDateTime(),
      firstDate: DateTime(2000),
      lastDate: today.addDays(366).toDateTime(),
      helpText: context.l10n.dayPick,
    );
    if (picked != null) onChanged(Day.fromDateTime(picked));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final f = context.fmt;
    final isToday = day == today;
    return ControlGroup(
      child: Row(
        children: [
          IconButton(
            tooltip: l.dayPrevious,
            icon: const Icon(Icons.chevron_left),
            onPressed: () => onChanged(day.addDays(-1)),
          ),
          Expanded(
            child: Semantics(
              button: true,
              label: '${f.dateLong(day)}. ${l.dayPick}',
              excludeSemantics: true,
              onTap: () => _pick(context),
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () => _pick(context),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        f.dateWithWeekday(day),
                        style: context.text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                        textAlign: TextAlign.center,
                      ),
                      if (isToday)
                        Text(l.commonToday, style: context.text.labelMedium?.copyWith(color: context.colors.primary)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: l.dayNext,
            icon: const Icon(Icons.chevron_right),
            onPressed: () => onChanged(day.addDays(1)),
          ),
          if (!isToday)
            TextButton(onPressed: () => onChanged(today), child: Text(l.commonToday))
          else
            const SizedBox(width: 8),
        ],
      ),
    );
  }
}

/// Fortschrittsbalken mit Beschriftung und Screenreader-Text.
class ProgressRow extends StatelessWidget {
  final String label;
  final String valueText;
  final double? fraction;
  final Color color;
  final String? semanticsValue;

  const ProgressRow({
    super.key,
    required this.label,
    required this.valueText,
    this.fraction,
    required this.color,
    this.semanticsValue,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: '$label, ${semanticsValue ?? valueText}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: context.text.bodyMedium)),
              Text(valueText, style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
            ],
          ),
          if (fraction != null) ...[
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: fraction!.clamp(0.0, 1.0),
                minHeight: 8,
                color: color,
                backgroundColor: context.colors.surfaceContainerHighest,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Zeigt eine Meldung mit "Rückgängig".
void showUndo(BuildContext context, String message, Future<void> Function() onUndo) {
  final m = ScaffoldMessenger.of(context);
  m.hideCurrentSnackBar();
  m.showSnackBar(
    SnackBar(
      content: Text(message),
      duration: const Duration(seconds: 6),
      action: SnackBarAction(label: context.l10n.commonUndo, onPressed: () => onUndo()),
    ),
  );
}

void showMessage(BuildContext context, String message) {
  final m = ScaffoldMessenger.of(context);
  m.hideCurrentSnackBar();
  m.showSnackBar(SnackBar(content: Text(message)));
}

/// Bestätigungsdialog. Liefert true bei Bestätigung.
Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final l = context.l10n;
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c, false), child: Text(l.commonCancel)),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(backgroundColor: c.colors.error, foregroundColor: c.colors.onError)
              : null,
          onPressed: () => Navigator.pop(c, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return r ?? false;
}

/// Uhrzeit wählen (24 Stunden auf Deutsch).
Future<TimeOfDay?> pickTime(BuildContext context, TimeOfDay initial) => showTimePicker(
  context: context,
  initialTime: initial,
  builder: (c, child) => MediaQuery(
    data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: Localizations.localeOf(c).languageCode == 'de'),
    child: child!,
  ),
);

/// Datum wählen.
Future<Day?> pickDay(BuildContext context, Day initial, {Day? first, Day? last}) async {
  final d = await showDatePicker(
    context: context,
    initialDate: initial.toDateTime(),
    firstDate: (first ?? Day(2000, 1, 1)).toDateTime(),
    lastDate: (last ?? initial.addDays(366)).toDateTime(),
  );
  return d == null ? null : Day.fromDateTime(d);
}

/// Scaffold für Bildschirme ohne untere Navigationsleiste: Der Inhalt bleibt
/// über der System-Navigationsleiste (Android zeichnet randlos).
class AppScaffold extends StatelessWidget {
  final PreferredSizeWidget? appBar;
  final Widget body;
  final Widget? floatingActionButton;

  const AppScaffold({super.key, this.appBar, required this.body, this.floatingActionButton});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: appBar,
    floatingActionButton: floatingActionButton,
    body: SafeArea(top: false, child: body),
  );
}
