import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/health.dart';
import '../core/utils.dart';
import 'charts.dart' hide fieldDecoration;
import 'controller.dart';
import 'l10n.dart';
import 'widgets.dart';

const _poundsPerKilogram = 2.2046226218;

enum _EditResult { saved, deleted }

class WeightPage extends StatefulWidget {
  const WeightPage({super.key});

  @override
  State<WeightPage> createState() => _WeightPageState();
}

class _WeightPageState extends State<WeightPage> {
  int _days = 7;
  bool _savingUnit = false;
  String? _deletingId;

  Future<void> _changeUnit(String unit) async {
    final controller = context.read<AppController>();
    if (_savingUnit || unit == controller.settings.weightUnit) return;
    setState(() => _savingUnit = true);
    try {
      await controller.repository.updateSettings(
        controller.settings.copyWith(weightUnit: unit),
      );
    } catch (_) {
      if (mounted) showError(context);
    } finally {
      if (mounted) setState(() => _savingUnit = false);
    }
  }

  Future<void> _openEditor([WeightEntry? existing]) async {
    final selectedDate = context.read<AppController>().selectedDate;
    final result = await Navigator.of(context).push<_EditResult>(
      MaterialPageRoute(
        builder: (_) =>
            WeightEditPage(existing: existing, initialDate: selectedDate),
      ),
    );
    if (!mounted || result != _EditResult.saved) return;
    showMessage(context, l10n(context).t('saved'));
  }

  Future<void> _delete(WeightEntry entry) async {
    if (_deletingId != null) return;
    final repository = context.read<AppController>().repository;
    setState(() => _deletingId = entry.id);
    try {
      final confirmed = await confirmDeletion(context);
      if (!mounted || !confirmed) return;
      await repository.deleteWeight(entry.id);
    } catch (_) {
      if (mounted) showError(context);
    } finally {
      if (mounted) setState(() => _deletingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = l10n(context);
    final controller = context.watch<AppController>();
    final unit = controller.settings.weightUnit == 'lb' ? 'lb' : 'kg';
    final weights = [...controller.state.weights]
      ..sort((a, b) {
        final byDate = b.date.compareTo(a.date);
        if (byDate != 0) return byDate;
        final byUpdate = b.updatedAt.compareTo(a.updatedAt);
        if (byUpdate != 0) return byUpdate;
        return a.id.compareTo(b.id);
      });

    return Scaffold(
      appBar: AppBar(title: Text(strings.t('weight'))),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'weight-add',
        onPressed: _savingUnit ? null : () => _openEditor(),
        icon: const Icon(Icons.add),
        label: Text(strings.t('add_weight')),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.only(bottom: 96),
        itemCount: weights.isEmpty ? 2 : weights.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _buildHeader(controller, unit);
          }
          if (weights.isEmpty) {
            return EmptyState(
              text: strings.t('no_weight'),
              icon: Icons.monitor_weight_outlined,
            );
          }
          final entry = weights[index - 1];
          return AppCard(
            title: strings.amount(_weightInUnit(entry, unit), unit),
            subtitle: strings.date(entry.date),
            onTap: () => _openEditor(entry),
            trailing: IconButton(
              tooltip: strings.t('delete'),
              onPressed: _deletingId == null ? () => _delete(entry) : null,
              icon: const Icon(Icons.delete_outline),
            ),
            children: [if (entry.notes.isNotEmpty) Text(entry.notes)],
          );
        },
      ),
    );
  }

  Widget _buildHeader(AppController controller, String unit) {
    final strings = l10n(context);
    final trend = _weightTrend(
      controller.state.weights,
      controller.selectedDate,
      _days,
    );
    final points = [
      for (final entry in trend)
        ChartPoint(
          strings.date(entry.date),
          _weightInUnit(entry, unit),
          strings.amount(_weightInUnit(entry, unit), unit),
        ),
    ];
    final average = points.isEmpty
        ? null
        : points.fold<double>(0, (sum, point) => sum + point.value) /
              points.length;
    final period = strings.t('days_$_days');

    return Column(
      children: [
        AppCard(
          title: strings.t('weight_unit'),
          icon: Icons.straighten,
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'kg', label: Text('kg')),
                ButtonSegment(value: 'lb', label: Text('lb')),
              ],
              selected: {unit},
              onSelectionChanged: _savingUnit
                  ? null
                  : (selection) => _changeUnit(selection.first),
            ),
          ],
        ),
        AppCard(
          title: strings.t('weight_history'),
          icon: Icons.show_chart,
          children: [
            DateField(
              label: strings.t('date'),
              value: controller.selectedDate,
              onChanged: controller.selectDate,
            ),
            const SizedBox(height: 8),
            SegmentedButton<int>(
              segments: [
                ButtonSegment(value: 7, label: Text(strings.t('days_7'))),
                ButtonSegment(value: 28, label: Text(strings.t('days_28'))),
              ],
              selected: {_days},
              onSelectionChanged: (selection) {
                setState(() => _days = selection.first);
              },
            ),
            if (average != null) ...[
              const SizedBox(height: 16),
              Text(
                '${strings.t('average')}: ${strings.amount(average, unit)}',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
            const SizedBox(height: 8),
            SimpleChart(
              points: points,
              line: true,
              semanticLabel: average == null
                  ? '${strings.t('weight_history')}, $period'
                  : '${strings.t('weight_history')}, $period, '
                        '${strings.t('average')} ${strings.amount(average, unit)}',
            ),
          ],
        ),
      ],
    );
  }
}

class WeightEditPage extends StatefulWidget {
  const WeightEditPage({super.key, this.existing, this.initialDate});

  final WeightEntry? existing;
  final String? initialDate;

  @override
  State<WeightEditPage> createState() => _WeightEditPageState();
}

class _WeightEditPageState extends State<WeightEditPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _weightController;
  late final TextEditingController _notesController;
  late String _date;
  late String _unit;
  bool _initialized = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _weightController = TextEditingController();
    _notesController = TextEditingController(
      text: widget.existing?.notes ?? '',
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final controller = context.read<AppController>();
    final existing = widget.existing;
    _date = existing?.date ?? widget.initialDate ?? controller.selectedDate;
    _unit = controller.settings.weightUnit == 'lb' ? 'lb' : 'kg';
    if (existing != null) {
      _weightController.text = l10n(
        context,
      ).number(_weightInUnit(existing, _unit));
    }
  }

  @override
  void dispose() {
    _weightController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  double _toKilograms(double value) =>
      _unit == 'lb' ? value / _poundsPerKilogram : value;

  String? _validateWeight(String? raw) {
    final strings = l10n(context);
    if (raw == null || raw.trim().isEmpty) return strings.t('required');
    final value = parseAmount(raw);
    if (value == null || !value.isFinite) {
      return strings.t('invalid_number');
    }
    if (value <= 0) return strings.t('positive_number');
    final kilograms = _toKilograms(value);
    if (!kilograms.isFinite || kilograms <= 0) {
      return strings.t('positive_number');
    }
    if (kilograms < 0.000001 || kilograms > 2000) {
      return strings.t('invalid_number');
    }
    return null;
  }

  Future<void> _save() async {
    if (_busy || !(_formKey.currentState?.validate() ?? false)) return;
    final value = parseAmount(_weightController.text);
    if (value == null || !value.isFinite || value <= 0) return;
    final kilograms = _toKilograms(value);
    if (!kilograms.isFinite || kilograms < 0.000001 || kilograms > 2000) {
      return;
    }
    final controller = context.read<AppController>();
    final timestamp = controller.now.toUtc();
    final existing = widget.existing;
    final entry = WeightEntry(
      id: existing?.id ?? newId(),
      date: _date,
      kg: kilograms,
      notes: _notesController.text.trim(),
      createdAt: existing?.createdAt.toUtc() ?? timestamp,
      updatedAt: timestamp,
    );

    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      await controller.repository.saveWeight(entry);
      if (!mounted) return;
      Navigator.of(context).pop(_EditResult.saved);
    } catch (_) {
      if (mounted) showError(context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final existing = widget.existing;
    if (_busy || existing == null) return;
    final repository = context.read<AppController>().repository;
    setState(() => _busy = true);
    try {
      final confirmed = await confirmDeletion(context);
      if (!mounted || !confirmed) return;
      await repository.deleteWeight(existing.id);
      if (!mounted) return;
      Navigator.of(context).pop(_EditResult.deleted);
    } catch (_) {
      if (mounted) showError(context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = l10n(context);
    final existing = widget.existing;
    return Scaffold(
      appBar: AppBar(
        title: Text(strings.t(existing == null ? 'add_weight' : 'edit_weight')),
        actions: [
          if (existing != null)
            IconButton(
              tooltip: strings.t('delete'),
              onPressed: _busy ? null : _delete,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_busy) ...[
                const LinearProgressIndicator(minHeight: 2),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: _weightController,
                enabled: !_busy,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: fieldDecoration(strings.t('weight'), suffix: _unit),
                validator: _validateWeight,
              ),
              const SizedBox(height: 8),
              DateField(
                label: strings.t('date'),
                value: _date,
                onChanged: (value) {
                  if (!_busy) setState(() => _date = value);
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _notesController,
                enabled: !_busy,
                minLines: 2,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: fieldDecoration(
                  '${strings.t('notes')} (${strings.t('optional')})',
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: _busy ? null : _save,
                      child: Text(strings.t('save')),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: Text(strings.t('cancel')),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SymptomsPage extends StatefulWidget {
  const SymptomsPage({super.key});

  @override
  State<SymptomsPage> createState() => _SymptomsPageState();
}

class _SymptomsPageState extends State<SymptomsPage> {
  int _days = 0;
  String? _selectedSymptom;
  String? _deletingId;

  Future<void> _openEditor([SymptomEntry? existing]) async {
    final result = await Navigator.of(context).push<_EditResult>(
      MaterialPageRoute(builder: (_) => SymptomEditPage(existing: existing)),
    );
    if (!mounted || result != _EditResult.saved) return;
    showMessage(context, l10n(context).t('saved'));
  }

  Future<void> _delete(SymptomEntry entry) async {
    if (_deletingId != null) return;
    final repository = context.read<AppController>().repository;
    setState(() => _deletingId = entry.id);
    try {
      final confirmed = await confirmDeletion(context);
      if (!mounted || !confirmed) return;
      await repository.deleteSymptom(entry.id);
    } catch (_) {
      if (mounted) showError(context);
    } finally {
      if (mounted) setState(() => _deletingId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = l10n(context);
    final controller = context.watch<AppController>();
    final symptoms = [...controller.state.symptoms]
      ..sort((a, b) {
        final byTime = b.occurredAt.compareTo(a.occurredAt);
        if (byTime != 0) return byTime;
        final byUpdate = b.updatedAt.compareTo(a.updatedAt);
        if (byUpdate != 0) return byUpdate;
        return a.id.compareTo(b.id);
      });
    final names = symptoms.map((entry) => entry.name).toSet().toList();
    final selectedName = names.contains(_selectedSymptom)
        ? _selectedSymptom
        : names.firstOrNull;

    return Scaffold(
      appBar: AppBar(title: Text(strings.t('symptoms'))),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'symptoms-add',
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add),
        label: Text(strings.t('add_symptom')),
      ),
      body: symptoms.isEmpty
          ? ListView(
              children: [
                EmptyState(
                  text: strings.t('no_symptoms'),
                  icon: Icons.sick_outlined,
                ),
              ],
            )
          : ListView.builder(
              padding: const EdgeInsets.only(bottom: 96),
              itemCount: symptoms.length + 1,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _buildHeader(
                    controller,
                    symptoms,
                    names,
                    selectedName,
                  );
                }
                final entry = symptoms[index - 1];
                return AppCard(
                  title: entry.name,
                  subtitle:
                      '${strings.dateTime(entry.occurredAt)}\n'
                      '${strings.t('intensity_value', {'value': entry.intensity})}',
                  onTap: () => _openEditor(entry),
                  trailing: IconButton(
                    tooltip: strings.t('delete'),
                    onPressed: _deletingId == null
                        ? () => _delete(entry)
                        : null,
                    icon: const Icon(Icons.delete_outline),
                  ),
                  children: [if (entry.notes.isNotEmpty) Text(entry.notes)],
                );
              },
            ),
    );
  }

  Widget _buildHeader(
    AppController controller,
    List<SymptomEntry> symptoms,
    List<String> names,
    String? selectedName,
  ) {
    final strings = l10n(context);
    final selectedEntries = selectedName == null
        ? <SymptomEntry>[]
        : symptoms.where((entry) => entry.name == selectedName).toList();
    final trend = _symptomTrend(
      selectedEntries,
      controller.selectedDate,
      _days,
    );
    final points = [
      for (final entry in trend)
        ChartPoint(
          strings.dateTime(entry.occurredAt),
          entry.intensity.toDouble(),
          strings.t('intensity_value', {'value': entry.intensity}),
        ),
    ];
    final average = points.isEmpty
        ? null
        : points.fold<double>(0, (sum, point) => sum + point.value) /
              points.length;
    final period = strings.t(_days == 0 ? 'all' : 'days_$_days');

    return AppCard(
      title: strings.t('symptom_history'),
      icon: Icons.show_chart,
      children: [
        DropdownButtonFormField<String>(
          isExpanded: true,
          key: ValueKey(selectedName),
          initialValue: selectedName,
          decoration: fieldDecoration(strings.t('select_symptom')),
          items: [
            for (final name in names)
              DropdownMenuItem(value: name, child: Text(name)),
          ],
          onChanged: (value) {
            if (value != null) setState(() => _selectedSymptom = value);
          },
        ),
        const SizedBox(height: 8),
        DateField(
          label: strings.t('date'),
          value: controller.selectedDate,
          onChanged: controller.selectDate,
        ),
        const SizedBox(height: 8),
        SegmentedButton<int>(
          segments: [
            ButtonSegment(value: 7, label: Text(strings.t('days_7'))),
            ButtonSegment(value: 28, label: Text(strings.t('days_28'))),
            ButtonSegment(value: 0, label: Text(strings.t('all'))),
          ],
          selected: {_days},
          onSelectionChanged: (selection) {
            setState(() => _days = selection.first);
          },
        ),
        if (average != null) ...[
          const SizedBox(height: 16),
          Text(
            '${strings.t('average')}: ${strings.number(average)}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ],
        const SizedBox(height: 8),
        SimpleChart(
          points: points,
          line: true,
          semanticLabel: average == null
              ? '${strings.t('symptom_history')}, $selectedName, $period'
              : '${strings.t('symptom_history')}, $selectedName, $period, '
                    '${strings.t('average')} ${strings.number(average)}',
        ),
      ],
    );
  }
}

class SymptomEditPage extends StatefulWidget {
  const SymptomEditPage({super.key, this.existing, this.initialTime});

  final SymptomEntry? existing;
  final DateTime? initialTime;

  @override
  State<SymptomEditPage> createState() => _SymptomEditPageState();
}

class _SymptomEditPageState extends State<SymptomEditPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _notesController;
  late DateTime _occurredAt;
  late int _intensity;
  bool _initialized = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.existing?.name ?? '');
    _notesController = TextEditingController(
      text: widget.existing?.notes ?? '',
    );
    _intensity = (widget.existing?.intensity ?? 0).clamp(0, 10);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    final controller = context.read<AppController>();
    final existing = widget.existing;
    if (existing != null) {
      _occurredAt = existing.occurredAt;
    } else if (widget.initialTime != null) {
      _occurredAt = widget.initialTime!;
    } else {
      final selected = parseDate(controller.selectedDate);
      final now = controller.now.toLocal();
      _occurredAt = DateTime(
        selected.year,
        selected.month,
        selected.day,
        now.hour,
        now.minute,
      );
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !(_formKey.currentState?.validate() ?? false)) return;
    final name = _nameController.text.trim();
    if (name.isEmpty) return;
    final controller = context.read<AppController>();
    final timestamp = controller.now.toUtc();
    final existing = widget.existing;
    final entry = SymptomEntry(
      id: existing?.id ?? newId(),
      name: name,
      intensity: _intensity,
      occurredAt: _occurredAt.toUtc(),
      notes: _notesController.text.trim(),
      createdAt: existing?.createdAt.toUtc() ?? timestamp,
      updatedAt: timestamp,
    );

    FocusScope.of(context).unfocus();
    setState(() => _busy = true);
    try {
      await controller.repository.saveSymptom(entry);
      if (!mounted) return;
      Navigator.of(context).pop(_EditResult.saved);
    } catch (_) {
      if (mounted) showError(context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    final existing = widget.existing;
    if (_busy || existing == null) return;
    final repository = context.read<AppController>().repository;
    setState(() => _busy = true);
    try {
      final confirmed = await confirmDeletion(context);
      if (!mounted || !confirmed) return;
      await repository.deleteSymptom(existing.id);
      if (!mounted) return;
      Navigator.of(context).pop(_EditResult.deleted);
    } catch (_) {
      if (mounted) showError(context);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final strings = l10n(context);
    final existing = widget.existing;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          strings.t(existing == null ? 'add_symptom' : 'edit_symptom'),
        ),
        actions: [
          if (existing != null)
            IconButton(
              tooltip: strings.t('delete'),
              onPressed: _busy ? null : _delete,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_busy) ...[
                const LinearProgressIndicator(minHeight: 2),
                const SizedBox(height: 16),
              ],
              TextFormField(
                controller: _nameController,
                enabled: !_busy,
                textCapitalization: TextCapitalization.sentences,
                decoration: fieldDecoration(strings.t('symptom_name')),
                validator: (value) => value == null || value.trim().isEmpty
                    ? strings.t('required')
                    : null,
              ),
              const SizedBox(height: 24),
              Text(
                strings.t('intensity_value', {'value': _intensity}),
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Slider(
                value: _intensity.toDouble(),
                min: 0,
                max: 10,
                divisions: 10,
                label: strings.number(_intensity, decimals: 0),
                onChanged: _busy
                    ? null
                    : (value) {
                        setState(() => _intensity = value.round().clamp(0, 10));
                      },
              ),
              Text(strings.t('intensity')),
              const SizedBox(height: 8),
              DateTimeFields(
                value: _occurredAt,
                onChanged: (value) {
                  if (!_busy) setState(() => _occurredAt = value);
                },
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _notesController,
                enabled: !_busy,
                minLines: 2,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                decoration: fieldDecoration(
                  '${strings.t('notes')} (${strings.t('optional')})',
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: _busy ? null : _save,
                      child: Text(strings.t('save')),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _busy
                          ? null
                          : () => Navigator.of(context).pop(),
                      child: Text(strings.t('cancel')),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

double _weightInUnit(WeightEntry entry, String unit) =>
    unit == 'lb' ? entry.kg * _poundsPerKilogram : entry.kg;

List<WeightEntry> _weightTrend(
  List<WeightEntry> entries,
  String endDate,
  int days,
) {
  final startDate = dateKey(addDays(parseDate(endDate), -days + 1));
  final result = entries.where((entry) {
    return entry.date.compareTo(startDate) >= 0 &&
        entry.date.compareTo(endDate) <= 0;
  }).toList();
  result.sort((a, b) {
    final byDate = a.date.compareTo(b.date);
    if (byDate != 0) return byDate;
    final byUpdate = a.updatedAt.compareTo(b.updatedAt);
    if (byUpdate != 0) return byUpdate;
    return a.id.compareTo(b.id);
  });
  return result;
}

List<SymptomEntry> _symptomTrend(
  List<SymptomEntry> entries,
  String endDate,
  int days,
) {
  final startDate = days == 0
      ? null
      : dateKey(addDays(parseDate(endDate), -days + 1));
  final result = entries.where((entry) {
    final date = instantDateKey(entry.occurredAt);
    return (startDate == null || date.compareTo(startDate) >= 0) &&
        (days == 0 || date.compareTo(endDate) <= 0);
  }).toList();
  result.sort((a, b) {
    final byTime = a.occurredAt.compareTo(b.occurredAt);
    if (byTime != 0) return byTime;
    final byUpdate = a.updatedAt.compareTo(b.updatedAt);
    if (byUpdate != 0) return byUpdate;
    return a.id.compareTo(b.id);
  });
  return result;
}
