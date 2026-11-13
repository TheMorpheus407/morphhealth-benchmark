import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:morphhealth_core/morphhealth_core.dart';

import '../../controller.dart';
import '../../l10n/strings.dart';
import '../../platform/platform_bridge.dart';
import '../format.dart';

/// Shortcuts used by almost every widget.
extension AppContext on BuildContext {
  L get l => L.of(this);
  AppController get app => AppScope.of(this);
  AppController get appRead => AppScope.read(this);
  Fmt get fmt => Fmt.of(this, today: AppScope.of(this).today);
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get texts => Theme.of(this).textTheme;
}

/// A section heading that screen readers announce as a heading.
class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  const SectionTitle(
    this.text, {
    super.key,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(4, 16, 4, 8),
  });

  @override
  Widget build(BuildContext context) {
    final title = Semantics(
      header: true,
      child: Text(
        text,
        style: context.texts.titleMedium?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
    return Padding(
      padding: padding,
      child: trailing == null
          ? Align(alignment: AlignmentDirectional.centerStart, child: title)
          : Row(
              children: [
                Expanded(child: title),
                trailing!,
              ],
            ),
    );
  }
}

/// A card whose content stays separate for assistive technology.
///
/// A plain [Card] is one semantic group: all texts inside it are merged into
/// a single announcement, and with several tappable rows it is unclear which
/// one a double tap activates. Here every text and every control keeps its
/// own node.
class PlainCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? margin;

  const PlainCard({super.key, required this.child, this.margin});

  @override
  Widget build(BuildContext context) => Card(
    margin: margin,
    semanticContainer: false,
    child: Semantics(container: true, explicitChildNodes: true, child: child),
  );
}

/// A card with an optional title row; the whole title row can be a button.
class MhCard extends StatelessWidget {
  final String? title;
  final IconData? icon;
  final Color? iconColor;
  final VoidCallback? onOpen;
  final String? openLabel;
  final Widget child;
  final EdgeInsetsGeometry padding;

  const MhCard({
    super.key,
    this.title,
    this.icon,
    this.iconColor,
    this.onOpen,
    this.openLabel,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(16, 4, 16, 16),
  });

  @override
  Widget build(BuildContext context) {
    final title = this.title;
    Widget? header;
    if (title != null) {
      final row = Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 8, 8),
        child: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, color: iconColor ?? context.colors.primary, size: 22),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(
                title,
                style: context.texts.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (onOpen != null)
              Padding(
                padding: const EdgeInsets.all(8),
                child: Icon(
                  Icons.chevron_right,
                  color: context.colors.onSurfaceVariant,
                ),
              )
            else
              const SizedBox(height: 40),
          ],
        ),
      );
      // A node of its own, so that the title (and its action) is not merged
      // with the content of the card.
      header = onOpen == null
          ? Semantics(container: true, header: true, child: row)
          : Semantics(
              container: true,
              header: true,
              button: true,
              label: openLabel,
              child: InkWell(onTap: onOpen, child: row),
            );
    }
    return PlainCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ?header,
          Padding(
            padding: title == null ? const EdgeInsets.all(16) : padding,
            child: child,
          ),
        ],
      ),
    );
  }
}

/// A quiet placeholder for lists without content.
class EmptyHint extends StatelessWidget {
  final IconData icon;
  final String text;
  final Widget? action;

  const EmptyHint({
    super.key,
    required this.icon,
    required this.text,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ExcludeSemantics(
            child: Icon(icon, size: 40, color: context.colors.outline),
          ),
          const SizedBox(height: 12),
          Text(
            text,
            textAlign: TextAlign.center,
            style: context.texts.bodyLarge?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    );
  }
}

/// Day navigation: previous day, the date (opens a calendar), next day.
class DayBar extends StatelessWidget {
  final Day day;
  final ValueChanged<Day> onChanged;

  /// Latest selectable day; defaults to today.
  final Day? lastDay;

  const DayBar({
    super.key,
    required this.day,
    required this.onChanged,
    this.lastDay,
  });

  static final Day firstSelectable = Day(2000, 1, 1);

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final fmt = context.fmt;
    final today = context.app.today;
    final last = lastDay ?? today;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          IconButton(
            tooltip: l.previousDay,
            onPressed: day > firstSelectable
                ? () => onChanged(day.addDays(-1))
                : null,
            icon: const Icon(Icons.chevron_left),
          ),
          Expanded(
            child: TextButton(
              onPressed: () async {
                final picked = await pickDay(
                  context,
                  initial: day,
                  first: firstSelectable,
                  last: last,
                );
                if (picked != null) onChanged(picked);
              },
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(
                      fmt.dayHeadline(day),
                      semanticsLabel: '${fmt.dayLong(day)}. ${l.pickDate}',
                      style: context.texts.titleMedium,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
          ),
          if (day != today)
            IconButton(
              tooltip: l.goToToday,
              onPressed: () => onChanged(today),
              icon: const Icon(Icons.today_outlined),
            ),
          IconButton(
            tooltip: l.nextDay,
            onPressed: day < last ? () => onChanged(day.addDays(1)) : null,
            icon: const Icon(Icons.chevron_right),
          ),
        ],
      ),
    );
  }
}

/// Shows the platform date picker with [Day] values.
Future<Day?> pickDay(
  BuildContext context, {
  required Day initial,
  required Day first,
  required Day last,
}) async {
  final clamped = initial < first ? first : (initial > last ? last : initial);
  final picked = await showDatePicker(
    context: context,
    initialDate: clamped.toDateTime(),
    firstDate: first.toDateTime(),
    lastDate: last.toDateTime(),
  );
  return picked == null ? null : Day.fromDateTime(picked);
}

/// Shows the platform time picker; returns [value] with the chosen time.
Future<LocalDateTime?> pickTime(
  BuildContext context,
  LocalDateTime value,
) async {
  final picked = await showTimePicker(
    context: context,
    initialTime: TimeOfDay(hour: value.hour, minute: value.minute),
  );
  return picked == null ? null : value.withTime(picked.hour, picked.minute);
}

/// Two tappable fields for the date and the time of an entry.
class DateTimeFields extends StatelessWidget {
  final LocalDateTime value;
  final ValueChanged<LocalDateTime> onChanged;

  const DateTimeFields({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final fmt = context.fmt;
    final today = context.app.today;
    return Row(
      children: [
        Expanded(
          flex: 3,
          child: _PickerField(
            label: l.date,
            value: fmt.dayRelative(value.day),
            icon: Icons.event_outlined,
            onTap: () async {
              final day = await pickDay(
                context,
                initial: value.day,
                first: DayBar.firstSelectable,
                last: today,
              );
              if (day != null) onChanged(value.withDay(day));
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 2,
          child: _PickerField(
            label: l.time,
            value: fmt.time(value),
            icon: Icons.schedule_outlined,
            onTap: () async {
              final t = await pickTime(context, value);
              if (t != null) onChanged(t);
            },
          ),
        ),
      ],
    );
  }
}

/// A single tappable field for a date.
class DateField extends StatelessWidget {
  final String label;
  final Day? value;
  final String? placeholder;
  final Day first;
  final Day last;
  final ValueChanged<Day> onChanged;
  final String? errorText;

  const DateField({
    super.key,
    required this.label,
    required this.value,
    required this.first,
    required this.last,
    required this.onChanged,
    this.placeholder,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = context.fmt;
    return _PickerField(
      label: label,
      value: value == null ? (placeholder ?? '') : fmt.dayLong(value!),
      icon: Icons.event_outlined,
      errorText: errorText,
      onTap: () async {
        final day = await pickDay(
          context,
          initial: value ?? last,
          first: first,
          last: last,
        );
        if (day != null) onChanged(day);
      },
    );
  }
}

class _PickerField extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;
  final String? errorText;

  const _PickerField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '$label: $value',
      onTap: onTap,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            suffixIcon: Icon(icon),
            errorText: errorText,
          ),
          child: Text(value, style: context.texts.bodyLarge),
        ),
      ),
    );
  }
}

/// A field that shows the current choice and opens the list of all options.
///
/// It is used instead of the Material dropdown, which offers screen readers
/// no tap action when it is not a text field. This one is a plain button
/// labelled with name and value, and its options are ordinary list entries.
class ChoiceField<T> extends StatelessWidget {
  final String label;
  final T value;

  /// The options with their texts, in the order they are shown.
  final List<(T, String)> options;
  final ValueChanged<T> onChanged;

  const ChoiceField({
    super.key,
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    var current = '';
    for (final o in options) {
      if (o.$1 == value) current = o.$2;
    }
    return _PickerField(
      label: label,
      value: current,
      icon: Icons.arrow_drop_down,
      onTap: () async {
        // Wrapped in a record, so that an option whose value is null can be
        // told from closing the sheet without choosing.
        final picked = await showModalBottomSheet<(T,)>(
          context: context,
          showDragHandle: true,
          isScrollControlled: true,
          useSafeArea: true,
          builder: (context) => SafeArea(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(context).height * 0.7,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
                    child: Semantics(
                      header: true,
                      child: Text(label, style: context.texts.titleMedium),
                    ),
                  ),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        for (final o in options)
                          ListTile(
                            title: Text(o.$2),
                            selected: o.$1 == value,
                            trailing: o.$1 == value
                                ? const Icon(Icons.check)
                                : null,
                            onTap: () => Navigator.of(context).pop((o.$1,)),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
        if (picked != null) onChanged(picked.$1);
      },
    );
  }
}

/// A text field for a decimal number with a unit, accepting comma and point.
class NumberField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? unit;
  final String? helper;
  final bool required;
  final bool allowZero;
  final double? max;
  final bool integer;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onSubmitted;

  const NumberField({
    super.key,
    required this.controller,
    required this.label,
    this.unit,
    this.helper,
    this.required = false,
    this.allowZero = true,
    this.max,
    this.integer = false,
    this.autofocus = false,
    this.onChanged,
    this.textInputAction,
    this.onSubmitted,
  });

  /// The validator used by the field, for reuse outside of forms.
  static String? validate(
    L l,
    Fmt fmt,
    String? text, {
    required bool required,
    required bool allowZero,
    double? max,
    bool integer = false,
  }) {
    final value = text?.trim() ?? '';
    if (value.isEmpty) return required ? l.requiredField : null;
    final v = Fmt.parse(value);
    if (v == null || (integer && v != v.roundToDouble())) {
      return l.invalidNumber;
    }
    if (v < 0 || (!allowZero && v == 0)) return l.mustBePositive;
    if (max != null && v > max) return l.valueTooLarge(fmt.number(max));
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final fmt = context.fmt;
    return TextFormField(
      enableIMEPersonalizedLearning: false,
      controller: controller,
      autofocus: autofocus,
      keyboardType: TextInputType.numberWithOptions(decimal: !integer),
      inputFormatters: [
        FilteringTextInputFormatter.allow(
          integer ? RegExp(r'[0-9]') : RegExp(r'[0-9.,]'),
        ),
        LengthLimitingTextInputFormatter(12),
      ],
      textInputAction: textInputAction,
      onChanged: onChanged,
      onFieldSubmitted: onSubmitted,
      decoration: InputDecoration(
        labelText: label,
        suffixText: unit,
        helperText: helper,
      ),
      validator: (text) => validate(
        l,
        fmt,
        text,
        required: required,
        allowZero: allowZero,
        max: max,
        integer: integer,
      ),
      autovalidateMode: AutovalidateMode.onUserInteraction,
    );
  }
}

/// Asks the user to confirm an action. Returns true if confirmed.
Future<bool> confirm(
  BuildContext context, {
  required String title,
  String? message,
  required String action,
  bool destructive = false,
}) async {
  final l = L.of(context);
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: message == null
          ? null
          : SingleChildScrollView(child: Text(message)),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(l.cancel),
        ),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                )
              : null,
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(action),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Shows a short message, optionally with an undo action.
void showSnack(BuildContext context, String message, {VoidCallback? onUndo}) {
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (messenger == null) return;
  final l = L.of(context);
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        duration: Duration(seconds: onUndo == null ? 3 : 6),
        action: onUndo == null
            ? null
            : SnackBarAction(label: l.undo, onPressed: onUndo),
      ),
    );
}

/// A readable message for anything an action can throw.
String describeError(BuildContext context, Object error) {
  final l = L.of(context);
  final fmt = Fmt.of(context, today: AppScope.read(context).today);
  if (error is ValidationException) return l.validation(error, fmt.date);
  if (error is StoreException) return l.saveFailed;
  if (error is FoodApiException) return l.foodError(error.code);
  if (error is BackupException) return l.backupError(error.code);
  if (error is DocumentException) return l.documentError;
  return l.errorGeneric('$error');
}

/// Runs [action]; problems are shown as a message instead of being thrown.
/// Returns true on success.
Future<bool> guarded(
  BuildContext context,
  Future<void> Function() action,
) async {
  try {
    await action();
    return true;
  } on Object catch (e) {
    if (context.mounted) showSnack(context, describeError(context, e));
    return false;
  }
}

/// A labelled value with an optional progress bar towards a goal.
class GoalBar extends StatelessWidget {
  final String label;
  final String value;
  final double? fraction;
  final Color? color;

  const GoalBar({
    super.key,
    required this.label,
    required this.value,
    this.fraction,
    this.color,
  });

  @override
  Widget build(BuildContext context) {
    final fraction = this.fraction;
    return Semantics(
      label: '$label: $value',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: context.texts.labelMedium?.copyWith(
              color: context.colors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 2),
          Text(value, style: context.texts.bodyMedium),
          if (fraction != null) ...[
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: fraction.clamp(0.0, 1.0),
                minHeight: 6,
                color: color,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Shows a few figures side by side in equal columns as long as their labels
/// fit, otherwise in fewer columns or one below the other.
///
/// With enlarged text or on a narrow screen, three or four columns would
/// break words in the middle ("Kohlenhy-drate"); this layout gives way
/// before that happens.
class AdaptiveColumns extends StatelessWidget {
  final List<Widget> children;

  /// Width one column needs at normal text size.
  final double minColumnWidth;
  final double spacing;
  final double runSpacing;

  const AdaptiveColumns({
    super.key,
    required this.children,
    this.minColumnWidth = 86,
    this.spacing = 12,
    this.runSpacing = 10,
  });

  @override
  Widget build(BuildContext context) {
    // Measured at the size of a label: since Android 14 small text is
    // enlarged more than large text, so one factor does not fit all sizes.
    final scale = MediaQuery.textScalerOf(context).scale(12) / 12;
    final count = children.length;
    return LayoutBuilder(
      builder: (context, box) {
        var columns = 1;
        for (final candidate in [count, if (count.isEven && count > 2) 2]) {
          final width = (box.maxWidth - spacing * (candidate - 1)) / candidate;
          if (width >= minColumnWidth * scale) {
            columns = candidate;
            break;
          }
        }
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var first = 0; first < count; first += columns) ...[
              if (first > 0) SizedBox(height: runSpacing),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = first; i < first + columns; i++) ...[
                    if (i > first) SizedBox(width: spacing),
                    Expanded(
                      child: i < count ? children[i] : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ],
          ],
        );
      },
    );
  }
}

/// A full-width progress overlay for work that takes a moment.
Future<T> withProgress<T>(
  BuildContext context,
  String message,
  Future<T> Function() work,
) async {
  unawaited(
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => PopScope(
        canPop: false,
        child: AlertDialog(
          content: Row(
            children: [
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(),
              ),
              const SizedBox(width: 20),
              Expanded(child: Text(message)),
            ],
          ),
        ),
      ),
    ),
  );
  try {
    return await work();
  } finally {
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
  }
}
