import 'package:flutter/material.dart';

import '../../core/nutrients.dart';
import '../l10n_x.dart';
import '../widgets/common.dart';

/// Nährwerttabelle nach Gruppen. Fehlende Angaben erscheinen als Strich, weil
/// "keine Angabe" nicht dasselbe ist wie 0.
class NutrientTable extends StatelessWidget {
  final Nutrients values;

  /// Je Nährstoff: Zahl der Einträge mit Angabe (nur bei Tagessummen).
  final Map<String, int>? coverage;

  /// Zahl der Einträge insgesamt (für Teilangaben).
  final int entryCount;

  /// Nur Nährstoffe mit Angabe zeigen (für einzelne Lebensmittel).
  final bool onlyPresent;

  const NutrientTable({super.key, required this.values, this.coverage, this.entryCount = 0, this.onlyPresent = false});

  bool _has(String key) => coverage != null ? (coverage![key] ?? 0) > 0 : values.has(key);

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    final f = context.fmt;
    final groups = <(String, NutrientGroup?, List<NutrientDef>)>[
      (
        l.nutrientsGroupMain,
        null,
        [...nutrientsOfGroup(NutrientGroup.energy), ...nutrientsOfGroup(NutrientGroup.macro)],
      ),
      (l.nutrientsGroupMore, NutrientGroup.detail, nutrientsOfGroup(NutrientGroup.detail)),
      (l.nutrientsGroupVitamins, NutrientGroup.vitamin, nutrientsOfGroup(NutrientGroup.vitamin)),
      (l.nutrientsGroupMinerals, NutrientGroup.mineral, nutrientsOfGroup(NutrientGroup.mineral)),
    ];
    final children = <Widget>[];
    for (final g in groups) {
      final defs = [
        for (final d in g.$3)
          if (!onlyPresent || _has(d.key)) d,
      ];
      if (defs.isEmpty) continue;
      children.add(
        Padding(
          padding: const EdgeInsets.only(top: 14, bottom: 4),
          child: Semantics(
            header: true,
            child: Text(g.$1, style: context.text.titleSmall?.copyWith(color: context.colors.primary)),
          ),
        ),
      );
      for (final d in defs) {
        final has = _has(d.key);
        final name = nutrientName(d.key, f.lang);
        final partial = coverage != null && has && entryCount > 0 && (coverage![d.key] ?? 0) < entryCount;
        final valueText = has ? f.nutrient(values.get0(d.key), d) : '–';
        children.add(
          MergeSemantics(
            child: Semantics(
              label:
                  '$name: ${has ? valueText : l.nutritionNoData}${partial ? ', ${l.nutritionCoverage('${coverage![d.key]}', '$entryCount')}' : ''}',
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
                          Text(name, style: context.text.bodyLarge),
                          if (partial)
                            Text(
                              l.nutritionCoverage('${coverage![d.key]}', '$entryCount'),
                              style: context.text.bodySmall?.copyWith(color: context.colors.onSurfaceVariant),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      valueText,
                      style: context.text.bodyLarge?.copyWith(
                        fontWeight: has ? FontWeight.w600 : FontWeight.normal,
                        color: has ? null : context.colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        children.add(const Divider(height: 1));
      }
    }
    return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: children);
  }
}

/// Bildschirm mit allen Nährwerten des Tages.
class NutrientsScreen extends StatelessWidget {
  final String title;
  final String subtitle;
  final Nutrients values;
  final Map<String, int> coverage;
  final int entryCount;

  const NutrientsScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.values,
    required this.coverage,
    required this.entryCount,
  });

  @override
  Widget build(BuildContext context) {
    final l = context.l10n;
    return AppScaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          Text(subtitle, style: context.text.bodyMedium),
          NutrientTable(values: values, coverage: coverage, entryCount: entryCount),
          const SizedBox(height: 12),
          EmptyHint(l.nutrientsDashHint, icon: Icons.info_outline),
        ],
      ),
    );
  }
}
