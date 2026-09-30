import 'package:flutter/material.dart';

import '../../../core/model/nutrients.dart';
import '../../controller.dart';
import '../../theme.dart';

/// Grouped list of all nutrients (energy & macros, details, vitamins,
/// minerals). Unknown values are shown as "–"; estimates are marked.
class NutrientList extends StatelessWidget {
  const NutrientList({
    super.key,
    required this.valueOf,
    this.isEstimated,
    this.coverageOf,
    this.showUnknown = true,
    this.extraCaffeineMg,
    this.singleFood = false,
  });

  /// Values of one food (marks estimates as "estimated") rather than sums
  /// (marked as "includes estimates").
  final bool singleFood;

  /// Value in the nutrient's unit, or null if unknown.
  final double? Function(Nutrient) valueOf;
  final bool Function(Nutrient)? isEstimated;

  /// Optional "values from n of m entries" text per nutrient.
  final String? Function(Nutrient)? coverageOf;
  final bool showUnknown;

  /// Additionally logged caffeine, shown as part of the caffeine line.
  final double? extraCaffeineMg;

  @override
  Widget build(BuildContext context) {
    final s = context.s;
    final groups = [
      (s.groupEnergyMacros, [NutrientGroup.energy, NutrientGroup.macro]),
      (s.groupDetails, [NutrientGroup.detail]),
      (s.groupVitamins, [NutrientGroup.vitamin]),
      (s.groupMinerals, [NutrientGroup.mineral]),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (title, kinds) in groups) ...[
          Padding(
            padding: const EdgeInsets.only(top: 12, bottom: 4),
            child: Semantics(
              header: true,
              child: Text(
                title,
                style: context.text.titleSmall?.copyWith(color: context.scheme.primary),
              ),
            ),
          ),
          for (final n in Nutrients.all.where((n) => kinds.contains(n.group)))
            if (showUnknown || valueOf(n) != null) _row(context, n),
        ],
      ],
    );
  }

  Widget _row(BuildContext context, Nutrient n) {
    final s = context.s;
    final fmt = context.fmt;
    var value = valueOf(n);
    String? extra;
    if (n == Nutrients.caffeine && extraCaffeineMg != null && extraCaffeineMg! > 0) {
      extra = '${s.caffeineFromFoods}: ${fmt.nutrient(n, value ?? 0)} · '
          '${s.caffeineAdditional}: ${fmt.nutrient(n, extraCaffeineMg!)}';
      value = (value ?? 0) + extraCaffeineMg!;
    }
    final estimated = value != null && (isEstimated?.call(n) ?? false);
    final coverage = coverageOf?.call(n);
    final valueText = value == null ? '–' : fmt.nutrient(n, value);
    final subtitle = [
      ?extra,
      ?coverage,
      if (estimated) singleFood ? s.estimated : s.includesEstimates,
    ].join(' · ');
    return MergeSemantics(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.nutrientName(n.key)),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      style: context.text.bodySmall?.copyWith(
                        color: context.scheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              estimated ? '≈ $valueText' : valueText,
              style: context.text.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

/// Compact line "kcal · P · C · F" for list tiles.
String macroLine(BuildContext context, double? Function(String key) value) {
  final fmt = context.fmt;
  String v(String key, String label, int decimals) {
    final x = value(key);
    return x == null ? '$label –' : '$label ${fmt.number(x, decimals)}';
  }

  final kcal = value('energy_kcal');
  return [
    kcal == null ? '– kcal' : '${fmt.integer(kcal)} kcal',
    v('protein_g', 'P', 1),
    v('carbohydrates_g', context.s.language.json == 'de' ? 'KH' : 'C', 1),
    v('fat_g', 'F', 1),
  ].join(' · ');
}
