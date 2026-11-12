library morphhealth.ui.overview_page;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:morphhealth/core/repository.dart';
import 'package:morphhealth/l10n/app_localizations.dart';
import 'package:morphhealth/ui/caffeine_entry_page.dart';
import 'package:morphhealth/ui/cycle_page.dart';
import 'package:morphhealth/ui/history_page.dart';
import 'package:morphhealth/ui/nutrition_entry_page.dart';
import 'package:morphhealth/ui/symptoms_page.dart';
import 'package:morphhealth/ui/water_entry_page.dart';
import 'package:morphhealth/ui/weight_entry_page.dart';

class OverviewPage extends StatefulWidget {
  final HealthRepository repository;
  const OverviewPage({super.key, required this.repository});

  @override
  State<OverviewPage> createState() => _OverviewPageState();
}

class _OverviewPageState extends State<OverviewPage> {
  DateTime _selected = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final vis = widget.repository.settings.visibleAreas;
    final summary = widget.repository.nutritionDaySummary(_selected);
    final wc = widget.repository.waterCaffeineDaySummary(_selected);
    final cycleOnDay = widget.repository.hasPeriodOnDate(_selected);
    final forecast = widget.repository.forecastFor(
      _selected,
      locale: widget.repository.settings.locale,
    );
    final symptomsToday = widget.repository.symptomEntriesForDay(_selected);
    final weightToday = widget.repository.weightEntriesForDay(_selected);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(l.msg('date'), style: Theme.of(context).textTheme.titleMedium),
              ),
              Text(DateFormat.yMMMd(widget.repository.settings.locale).format(_selected),
                  style: Theme.of(context).textTheme.titleMedium),
              IconButton(
                icon: const Icon(Icons.calendar_month),
                onPressed: () async {
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: _selected,
                    firstDate: DateTime(2000),
                    lastDate: DateTime(2100),
locale: Locale(widget.repository.settings.locale),
                  );
                  if (picked != null) setState(() => _selected = picked);
                },
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (vis.contains('nutrition')) ...[
            _Card(
              title: l.msg('nutritionDiary'),
              subtitle:
                  '${summary.energyKcal.toStringAsFixed(0)} ${l.msg('kcal')} · '
                  '${summary.proteinG.toStringAsFixed(0)}g P / ${summary.carbsG.toStringAsFixed(0)}g KH / ${summary.fatG.toStringAsFixed(0)}g F',
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _QuickButton(
                        icon: Icons.add,
                        label: l.msg('add'),
                        onTap: () => _addNutrition(context),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _QuickButton(
                        icon: Icons.local_drink,
                        label: l.msg('water'),
                        onTap: () => _addWater(context),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ],
          if (vis.contains('nutrition')) ...[
            const SizedBox(height: 12),
            _Card(
              title: '${l.msg('water')} / ${l.msg('caffeine')}',
              subtitle:
                  '${wc.waterMilliliters.toStringAsFixed(0)} ${l.msg('mlAbbr')} · ${wc.caffeineMg.toStringAsFixed(0)} ${l.msg('mg')}',
              children: [
                Row(
                  children: [
                    Expanded(child: _QuickButton(icon: Icons.local_drink, label: '250ml', onTap: () => _addWaterAmount(context, 250))),
                    const SizedBox(width: 8),
                    Expanded(child: _QuickButton(icon: Icons.local_drink, label: '500ml', onTap: () => _addWaterAmount(context, 500))),
                    const SizedBox(width: 8),
                    Expanded(child: _QuickButton(icon: Icons.coffee, label: l.msg('caffeine'), onTap: () => _addCaffeine(context))),
                  ],
                ),
              ],
            ),
          ],
          if (vis.contains('cycle')) ...[
            const SizedBox(height: 12),
            _Card(
              title: l.msg('cycle'),
              subtitle: cycleOnDay ? l.msg('period') : 'Keine Periode heute',
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _QuickButton(
                        icon: Icons.bloodtype,
                        label: l.msg('period'),
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => CyclePage(repository: widget.repository, initialDate: _selected),
                        )),
                      )),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _QuickButton(
                        icon: Icons.psychology,
                        label: l.msg('symptom'),
                        onTap: () => Navigator.of(context).push(MaterialPageRoute(
                          builder: (_) => SymptomsPage(repository: widget.repository, initialDate: _selected),
                        )),
                      )),
                  ],
                ),
                if (forecast.hasPrediction) ...[
                  const SizedBox(height: 8),
                  Text(
                    '${l.msg('forecast')}: ${DateFormat.yMMMd(widget.repository.settings.locale).format(forecast.predictedNextStart!)}',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ],
            ),
          ],
          if (vis.contains('weight')) ...[
            const SizedBox(height: 12),
            _Card(
              title: l.msg('weight'),
              subtitle: weightToday.isEmpty
                  ? 'Kein Eintrag heute'
                  : '${weightToday.first.value.toStringAsFixed(1)} ${weightToday.first.unit.key.toUpperCase()}',
              children: [
                _QuickButton(
                  icon: Icons.monitor_weight,
                  label: l.msg('add'),
                  onTap: () => _addWeight(context),
                ),
              ],
            ),
          ],
          if (symptomsToday.isNotEmpty) ...[
            const SizedBox(height: 12),
            _Card(
              title: l.msg('symptomHistory'),
              subtitle: symptomsToday.map((e) => '${e.name} (${e.intensity}/10)').join(' · '),
              children: [
                _QuickButton(
                  icon: Icons.psychology,
                  label: l.msg('add'),
                  onTap: () => Navigator.of(context).push(MaterialPageRoute(
                    builder: (_) => SymptomsPage(repository: widget.repository, initialDate: _selected),
                  )),
                ),
              ],
            ),
          ],
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.history),
              label: Text(l.msg('history')),
              onPressed: () => Navigator.of(context).push(MaterialPageRoute(
                builder: (_) => HistoryPage(repository: widget.repository),
              )),
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _addNutrition(BuildContext context) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => NutritionEntryPage(repository: widget.repository, day: _selected),
    ));
    setState(() {});
  }

  Future<void> _addWater(BuildContext context) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => WaterEntryPage(repository: widget.repository, day: _selected),
    ));
    setState(() {});
  }

  Future<void> _addWaterAmount(BuildContext context, double ml) async {
    await widget.repository.addWaterEntry(
      WaterEntry(id: '', amountMilliliters: ml, occurredAt: _selected),
    );
    setState(() {});
  }

  Future<void> _addCaffeine(BuildContext context) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => CaffeineEntryPage(repository: widget.repository, day: _selected),
    ));
    setState(() {});
  }

  Future<void> _addWeight(BuildContext context) async {
    await Navigator.of(context).push(MaterialPageRoute(
      builder: (_) => WeightEntryPage(repository: widget.repository, day: _selected),
    ));
    setState(() {});
  }
}

class _Card extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<Widget> children;
  const _Card({required this.title, required this.subtitle, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(subtitle, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 12),
            ...children,
          ],
        ),
      ),
    );
  }
}

class _QuickButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _QuickButton({required this.icon, required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      icon: Icon(icon, size: 18),
      label: Text(label),
      onPressed: onTap,
      style: OutlinedButton.styleFrom(
        minimumSize: Size.zero,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    );
  }
}