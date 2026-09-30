import 'package:flutter/material.dart';

import '../controller.dart';
import '../theme.dart';

/// Card with a header row (icon, title, optional trailing action).
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    this.icon,
    this.iconColor,
    this.trailing,
    this.onTap,
    required this.child,
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 16),
  });

  final String title;
  final IconData? icon;
  final Color? iconColor;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final header = Row(
      children: [
        if (icon != null) ...[
          ExcludeSemantics(child: Icon(icon, color: iconColor ?? context.scheme.primary)),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: Semantics(
            header: true,
            child: Text(title, style: context.text.titleMedium),
          ),
        ),
        ?trailing,
      ],
    );
    final content = Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [header, const SizedBox(height: 8), child],
      ),
    );
    return Card(
      // Keep entries and buttons inside the card individually accessible.
      semanticContainer: false,
      child: onTap == null ? content : InkWell(onTap: onTap, child: content),
    );
  }
}

/// List padding for pushed pages that also keeps the last item above the
/// system navigation bar (Android 15 draws apps edge-to-edge).
EdgeInsets pagePadding(
  BuildContext context, {
  double horizontal = 16,
  double top = 8,
  double bottom = 32,
}) => EdgeInsets.fromLTRB(
  horizontal,
  top,
  horizontal,
  bottom + MediaQuery.paddingOf(context).bottom,
);

/// A quiet explanatory text for empty states.
class EmptyHint extends StatelessWidget {
  const EmptyHint(this.text, {super.key, this.icon});

  final String text;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          if (icon != null) ...[
            ExcludeSemantics(child: Icon(icon, color: context.scheme.outline)),
            const SizedBox(width: 12),
          ],
          Expanded(
            child: Text(
              text,
              style: context.text.bodyMedium?.copyWith(color: context.scheme.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}

/// Label + value, and a neutral progress bar if a goal exists. Values above
/// the goal are shown the same way (no alarming colors, no judgement).
class GoalProgress extends StatelessWidget {
  const GoalProgress({
    super.key,
    required this.label,
    required this.valueText,
    this.goal,
    this.goalText,
    this.value = 0,
    this.color,
  });

  final String label;
  final String valueText;
  final double value;
  final double? goal;
  final String? goalText;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final ratio = goal == null || goal == 0 ? null : (value / goal!).clamp(0.0, 1.0);
    final text = goalText == null ? valueText : s.valueOfGoal(valueText, goalText!);
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: Text(label, style: context.text.bodyMedium)),
                const SizedBox(width: 12),
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * 0.55),
                  child: Text(
                    text,
                    style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
                    textAlign: TextAlign.end,
                  ),
                ),
              ],
            ),
            if (ratio != null) ...[
              const SizedBox(height: 4),
              ExcludeSemantics(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 6,
                    color: color ?? context.scheme.primary,
                    backgroundColor: context.scheme.surfaceContainerHighest,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Asks for confirmation; returns true if confirmed.
Future<bool> confirm(
  BuildContext context, {
  required String title,
  String? message,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final s = context.appRead.s;
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: message == null ? null : Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: Text(s.cancel)),
        FilledButton(
          style: destructive
              ? FilledButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error,
                  foregroundColor: Theme.of(context).colorScheme.onError,
                )
              : null,
          onPressed: () => Navigator.pop(context, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// A small pill used for secondary information (e.g. "geschätzt").
class TagChip extends StatelessWidget {
  const TagChip(this.label, {super.key, this.color});

  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = color ?? context.scheme.secondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: c),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label, style: context.text.labelSmall?.copyWith(color: c)),
    );
  }
}

/// Section title inside scrolling lists.
class ListHeader extends StatelessWidget {
  const ListHeader(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                text,
                style: context.text.titleSmall?.copyWith(color: context.scheme.primary),
              ),
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}
