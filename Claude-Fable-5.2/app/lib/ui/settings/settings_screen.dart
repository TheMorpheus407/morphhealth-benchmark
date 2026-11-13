import 'package:flutter/material.dart';
import 'package:morphhealth_core/morphhealth_core.dart';

import '../nutrition/goals_screen.dart';
import '../overview/overview_screen.dart' show AreaSwitches;
import '../widgets/common.dart';
import 'about_screen.dart';
import 'data_screen.dart';

/// Language, appearance, units, the areas of the overview, nutrition and
/// cycle options, and the way to data management.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<String?> _askText(
    BuildContext context, {
    required String title,
    required String initial,
    String? helper,
    TextInputType? keyboardType,
    required String? Function(String value) validate,
  }) => showDialog<String>(
    context: context,
    builder: (_) => _TextDialog(
      title: title,
      initial: initial,
      helper: helper,
      keyboardType: keyboardType,
      validate: validate,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final app = context.app;
    final s = app.settings;

    Widget choice<T extends Object>({
      required String label,
      required T value,
      required List<(T, String)> options,
      required ValueChanged<T> onChanged,
    }) => Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // The group below carries the same words as its label.
          ExcludeSemantics(child: Text(label, style: context.texts.bodyLarge)),
          const SizedBox(height: 8),
          Semantics(
            label: label,
            container: true,
            child: SizedBox(
              width: double.infinity,
              child: SegmentedButton<T>(
                showSelectedIcon: false,
                segments: [
                  for (final o in options)
                    ButtonSegment(value: o.$1, label: Text(o.$2)),
                ],
                selected: {value},
                onSelectionChanged: (sel) => onChanged(sel.first),
              ),
            ),
          ),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l.settings)),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            SectionTitle(
              l.sectionGeneral,
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            ),
            choice<String>(
              label: l.language,
              value: s.language,
              options: const [('de', 'Deutsch'), ('en', 'English')],
              onChanged: (v) => guarded(
                context,
                () => app.updateSettings((s) => s.copyWith(language: v)),
              ),
            ),
            choice<String>(
              label: l.appearance,
              value: s.theme,
              options: [
                ('system', l.themeSystem),
                ('light', l.themeLight),
                ('dark', l.themeDark),
              ],
              onChanged: (v) => guarded(
                context,
                () => app.updateSettings((s) => s.copyWith(theme: v)),
              ),
            ),
            choice<String>(
              label: l.weightUnit,
              value: s.weightUnit,
              options: [('kg', l.kilograms), ('lb', l.pounds)],
              onChanged: (v) => guarded(
                context,
                () => app.updateSettings((s) => s.copyWith(weightUnit: v)),
              ),
            ),
            const Divider(height: 24),
            SectionTitle(
              l.overviewAreas,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            ),
            const AreaSwitches(),
            const Divider(height: 24),
            SectionTitle(
              l.navNutrition,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            ),
            ListTile(
              leading: const Icon(Icons.flag_outlined),
              title: Text(l.goals),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const GoalsScreen()),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.local_drink_outlined),
              title: Text(l.waterQuickAmounts),
              subtitle: Text(
                s.waterQuickAmountsMl.map((v) => '$v ml').join(', '),
              ),
              trailing: const Icon(Icons.edit_outlined),
              onTap: () async {
                List<int>? parse(String v) {
                  final parts = v
                      .split(RegExp(r'[,;\s]+'))
                      .where((p) => p.isNotEmpty)
                      .toList();
                  final values = <int>[];
                  for (final p in parts) {
                    final n = int.tryParse(p);
                    if (n == null || n < 10 || n > 5000) return null;
                    if (!values.contains(n)) values.add(n);
                  }
                  return values.isEmpty || values.length > 6 ? null : values;
                }

                final text = await _askText(
                  context,
                  title: l.waterQuickAmounts,
                  initial: s.waterQuickAmountsMl.join(', '),
                  helper: l.waterQuickAmountsHelper,
                  validate: (v) =>
                      parse(v) == null ? l.waterQuickAmountsInvalid : null,
                );
                if (text == null || !context.mounted) return;
                await guarded(
                  context,
                  () => app.updateSettings(
                    (s) => s.copyWith(waterQuickAmountsMl: parse(text)),
                  ),
                );
              },
            ),
            SwitchListTile(
              secondary: const Icon(Icons.public),
              title: Text(l.onlineSearch),
              subtitle: Text(
                s.onlineFoodSearch == OnlineFoodSearch.enabled
                    ? l.onlineSearchOn
                    : l.onlineSearchOff,
              ),
              value: s.onlineFoodSearch == OnlineFoodSearch.enabled,
              onChanged: (v) => guarded(
                context,
                () => app.updateSettings(
                  (s) => s.copyWith(
                    onlineFoodSearch: v
                        ? OnlineFoodSearch.enabled
                        : OnlineFoodSearch.disabled,
                  ),
                ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.dns_outlined),
              title: Text(l.foodServer),
              subtitle: Text(
                app.local.foodApiBaseUrl == null
                    ? l.foodServerDefault(app.config.defaultFoodBaseUrl)
                    : app.foodBaseUrl,
              ),
              trailing: const Icon(Icons.edit_outlined),
              onTap: () async {
                String? check(String v) {
                  if (v.trim().isEmpty) return null;
                  try {
                    FoodApiClient.parseOrigin(v);
                    return null;
                  } on FoodApiException {
                    return l.foodServerInvalid;
                  }
                }

                final text = await _askText(
                  context,
                  title: l.foodServer,
                  initial: app.local.foodApiBaseUrl ?? '',
                  helper:
                      '${l.foodServerHelper} ${l.foodServerDefault(app.config.defaultFoodBaseUrl)}',
                  keyboardType: TextInputType.url,
                  validate: check,
                );
                if (text == null || !context.mounted) return;
                final value = text.trim().isEmpty
                    ? null
                    : FoodApiClient.parseOrigin(text).toString();
                await guarded(
                  context,
                  () => app.repository.updateLocal(
                    app.local.copyWith(foodApiBaseUrl: value),
                  ),
                );
              },
            ),
            const Divider(height: 24),
            SectionTitle(
              l.navCycle,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            ),
            SwitchListTile(
              secondary: const Icon(Icons.insights_outlined),
              title: Text(l.cyclePredictions),
              subtitle: Text(
                s.cyclePredictions
                    ? l.cyclePredictionsOn
                    : l.cyclePredictionsOff,
              ),
              value: s.cyclePredictions,
              onChanged: (v) => guarded(
                context,
                () =>
                    app.updateSettings((s) => s.copyWith(cyclePredictions: v)),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.straighten),
              title: Text(l.typicalCycleLength),
              subtitle: Text(
                s.typicalCycleLengthDays == null
                    ? l.notSet
                    : l.daysCount(s.typicalCycleLengthDays!),
              ),
              trailing: const Icon(Icons.edit_outlined),
              enabled: s.cyclePredictions,
              onTap: () async {
                String? check(String v) {
                  if (v.trim().isEmpty) return null;
                  final n = int.tryParse(v.trim());
                  return n == null ||
                          n < Settings.minCycleLength ||
                          n > Settings.maxCycleLength
                      ? l.typicalCycleInvalid(
                          Settings.minCycleLength,
                          Settings.maxCycleLength,
                        )
                      : null;
                }

                final text = await _askText(
                  context,
                  title: l.typicalCycleLength,
                  initial: s.typicalCycleLengthDays?.toString() ?? '',
                  helper: l.typicalCycleHelper,
                  keyboardType: TextInputType.number,
                  validate: check,
                );
                if (text == null || !context.mounted) return;
                await guarded(
                  context,
                  () => app.updateSettings(
                    (s) => s.copyWith(
                      typicalCycleLengthDays: int.tryParse(text.trim()),
                    ),
                  ),
                );
              },
            ),
            const Divider(height: 24),
            ListTile(
              leading: const Icon(Icons.folder_outlined),
              title: Text(l.dataTitle),
              subtitle: Text(l.dataSubtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const DataScreen()),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.info_outline),
              title: Text(l.about),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const AboutScreen()),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TextDialog extends StatefulWidget {
  final String title;
  final String initial;
  final String? helper;
  final TextInputType? keyboardType;
  final String? Function(String value) validate;

  const _TextDialog({
    required this.title,
    required this.initial,
    required this.validate,
    this.helper,
    this.keyboardType,
  });

  @override
  State<_TextDialog> createState() => _TextDialogState();
}

class _TextDialogState extends State<_TextDialog> {
  late final _controller = TextEditingController(text: widget.initial);
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final error = widget.validate(_controller.text);
    if (error != null) {
      setState(() => _error = error);
      return;
    }
    Navigator.of(context).pop(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    return AlertDialog(
      title: Text(widget.title),
      scrollable: true,
      content: TextField(
        enableIMEPersonalizedLearning: false,
        controller: _controller,
        autofocus: true,
        keyboardType: widget.keyboardType,
        autocorrect: false,
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          helperText: widget.helper,
          errorText: _error,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.cancel),
        ),
        FilledButton(onPressed: _submit, child: Text(l.save)),
      ],
    );
  }
}
