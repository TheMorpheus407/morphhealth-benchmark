import 'package:flutter/material.dart';
import 'package:morphhealth_core/morphhealth_core.dart';

import '../widgets/common.dart';

/// All 31 nutrients in their groups, each with its amount or "–" if unknown.
class NutrientTable extends StatelessWidget {
  final NutrientValues values;

  /// Keys of nutrients whose value is an estimate (marked with "≈").
  final Set<String> estimated;

  /// For day totals: per nutrient index, how many entries state a value.
  final List<int>? knownCounts;

  /// For day totals: per nutrient index, how many contributing values are
  /// estimates.
  final List<int>? estimatedCounts;

  /// For day totals: number of entries of the day.
  final int? entryTotal;

  /// Groups shown; all by default.
  final List<NutrientGroup> groups;

  const NutrientTable({
    super.key,
    required this.values,
    this.estimated = const {},
    this.knownCounts,
    this.estimatedCounts,
    this.entryTotal,
    this.groups = const [
      NutrientGroup.macro,
      NutrientGroup.detail,
      NutrientGroup.vitamin,
      NutrientGroup.mineral,
    ],
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final group in groups) ...[
          SectionTitle(
            l.nutrientGroup(group),
            padding: const EdgeInsets.fromLTRB(0, 14, 0, 4),
          ),
          for (final n in Nutrients.all)
            if (n.group == group ||
                (group == NutrientGroup.macro &&
                    n.group == NutrientGroup.energy))
              _row(context, n),
        ],
      ],
    );
  }

  Widget _row(BuildContext context, Nutrient n) {
    final l = context.l;
    final fmt = context.fmt;
    final v = values[n];
    final total = entryTotal;
    final known = knownCounts?[n.index];
    final isEstimate =
        estimated.contains(n.key) ||
        (estimatedCounts != null && estimatedCounts![n.index] > 0);

    String valueText;
    String? remark;
    if (total != null && known != null) {
      // Day totals.
      if (known == 0) {
        valueText = '–';
        remark = total == 0 ? null : l.coverageNone;
      } else {
        valueText = fmt.nutrient(n, v ?? 0, approximate: isEstimate);
        if (known < total) remark = l.coverage(known, total);
        if (isEstimate) {
          remark = remark == null
              ? l.containsEstimates
              : '$remark, ${l.containsEstimates}';
        }
      }
    } else {
      valueText = v == null ? '–' : fmt.nutrient(n, v, approximate: isEstimate);
    }

    return Semantics(
      label:
          '${l.nutrient(n)}: '
          '${valueText == '–' ? l.coverageNone : valueText}'
          '${remark == null ? '' : ', $remark'}',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.nutrient(n), style: context.texts.bodyMedium),
                  if (remark != null)
                    Text(
                      remark,
                      style: context.texts.bodySmall?.copyWith(
                        color: context.colors.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              valueText,
              style: context.texts.bodyMedium?.copyWith(
                fontFeatures: const [FontFeature.tabularFigures()],
                color: valueText == '–'
                    ? context.colors.onSurfaceVariant
                    : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Calories and the three macronutrients side by side.
class MainNutrientRow extends StatelessWidget {
  final NutrientValues values;
  final Set<String> estimated;

  const MainNutrientRow({
    super.key,
    required this.values,
    this.estimated = const {},
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final fmt = context.fmt;
    Widget cell(Nutrient n) {
      final v = values[n];
      final text = v == null
          ? '–'
          : fmt.nutrient(n, v, approximate: estimated.contains(n.key));
      return Semantics(
        label: '${l.nutrient(n)}: ${v == null ? l.coverageNone : text}',
        excludeSemantics: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.nutrient(n),
              style: context.texts.labelSmall?.copyWith(
                color: context.colors.onSurfaceVariant,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 2),
            Text(text, style: context.texts.titleSmall),
          ],
        ),
      );
    }

    return AdaptiveColumns(
      minColumnWidth: 78,
      spacing: 8,
      children: [
        cell(Nutrients.energy),
        cell(Nutrients.protein),
        cell(Nutrients.carbohydrates),
        cell(Nutrients.fat),
      ],
    );
  }
}
