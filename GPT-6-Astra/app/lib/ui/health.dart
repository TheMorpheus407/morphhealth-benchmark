import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/core.dart';
import 'shared.dart';

const _rose = Color(0xFF9F5267);
const _mint = Color(0xFF277665);

List<Json> _records(AppModel model, String collection) =>
    (model.doc[collection] as List).cast<Json>();

String _flow(AppModel m, String flow) => switch (flow) {
  'spotting' => m.tr('Spotting', 'Spotting'),
  'light' => m.tr('Leicht', 'Light'),
  'heavy' => m.tr('Stark', 'Heavy'),
  _ => m.tr('Mittel', 'Medium'),
};

String _date(String value, AppModel m) => displayDate(parseDay(value), m.de);

// Records retain the calendar day and clock time that the user entered, even
// when a portable import includes an explicit time-zone offset.
DateTime _civilTime(String value) => DateTime.parse(value.substring(0, 19));

String _savedTimestamp(DateTime value, Json? entry) =>
    entry != null && _civilTime(entry['at'] as String) == value
    ? entry['at'] as String
    : value.toIso8601String();

String _stamp(String value, AppModel m) {
  final at = _civilTime(value);
  return '${displayDate(at, m.de)} · ${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';
}

bool _periodOn(Json entry, String day) =>
    (entry['start'] as String).compareTo(day) <= 0 &&
    ((entry['end'] as String?) ?? dateKey(DateTime.now())).compareTo(day) >= 0;

String _periodDates(Json entry, AppModel m) =>
    '${_date(entry['start'] as String, m)} – ${entry['end'] == null ? m.tr('offen', 'ongoing') : _date(entry['end'] as String, m)}';

Widget cycleSummary(AppModel model) {
  final forecast = cycleForecast(model.doc, dateKey(model.selectedDate));
  final ready = forecast['status'] == 'ready';
  final explanation =
      (forecast['explanation'] as Map?)?[model.de ? 'de' : 'en'];
  return Panel(
    color: const Color(0xFFE7F0E9),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.auto_awesome_outlined, color: _mint),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                model.tr(
                  'Deine persönliche Einschätzung',
                  'Your personal estimate',
                ),
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          ready && forecast['predictedStart'] != null
              ? _date(forecast['predictedStart'] as String, model)
              : forecast['status'] == 'disabled'
              ? model.tr('Tagebuchmodus', 'Diary mode')
              : model.tr('Deine Historie wächst', 'Your history is growing'),
          style: const TextStyle(fontSize: 25, fontWeight: FontWeight.w600),
        ),
        if (ready &&
            forecast['earliest'] != null &&
            forecast['latest'] != null) ...[
          const SizedBox(height: 4),
          Text(
            '${model.tr('Möglicher Beginn', 'Possible start')}: '
            '${_date(forecast['earliest'] as String, model)} – ${_date(forecast['latest'] as String, model)}',
          ),
        ],
        const SizedBox(height: 10),
        Text(
          explanation?.toString() ??
              model.tr(
                'Erfasse deine Perioden, um eine persönliche Einschätzung zu erhalten.',
                'Record your periods to receive a personal estimate.',
              ),
        ),
        if (ready) ...[
          const SizedBox(height: 10),
          Text(
            '${model.tr('Aufgezeichnete Abstände', 'Recorded intervals')}: ${forecast['sampleSize']} · '
            '${model.tr('Typischer Abstand', 'Typical interval')}: ${fmt(forecast['cycleLength'] as num?, 0)} ${model.tr('Tage', 'days')}',
            style: const TextStyle(fontSize: 12),
          ),
        ],
      ],
    ),
  );
}

class CyclePage extends StatefulWidget {
  const CyclePage({super.key, required this.model});
  final AppModel model;

  @override
  State<CyclePage> createState() => _CyclePageState();
}

class _CyclePageState extends State<CyclePage> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    _month = DateTime(
      widget.model.selectedDate.year,
      widget.model.selectedDate.month,
    );
  }

  void _moveMonth(int offset) {
    setState(() {
      _month = DateTime(_month.year, _month.month + offset);
      widget.model.selectDate(_month);
    });
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.model,
    builder: (context, _) {
      final m = widget.model;
      // Other sections share the selected day while this page stays mounted in
      // the navigation stack. Keep the displayed calendar in that month.
      _month = DateTime(m.selectedDate.year, m.selectedDate.month);
      final periods = _records(m, 'periods').toList()
        ..sort(
          (a, b) => (b['start'] as String).compareTo(a['start'] as String),
        );
      final day = dateKey(m.selectedDate);
      final dailyPeriods = periods.where((p) => _periodOn(p, day)).toList();
      final dailySymptoms =
          _records(
              m,
              'symptoms',
            ).where((s) => (s['at'] as String).startsWith(day)).toList()
            ..sort((a, b) => (a['at'] as String).compareTo(b['at'] as String));
      return CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
            sliver: SliverList.list(
              children: [
                Text(
                  m.tr(
                    'Dein Rhythmus. Dein Tagebuch.',
                    'Your rhythm. Your diary.',
                  ),
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 6),
                Text(
                  m.tr(
                    'Dokumentiere, was du bemerkst, und plane mit deiner eigenen Historie.',
                    'Record what you notice and plan with your own history.',
                  ),
                ),
                const SizedBox(height: 18),
                FilledButton.icon(
                  onPressed: () => editPeriod(context, m),
                  icon: const Icon(Icons.add),
                  label: Text(m.tr('Periode erfassen', 'Record period')),
                ),
                const SizedBox(height: 14),
                _calendar(context, m, periods),
                const SizedBox(height: 20),
                SectionTitle(displayDate(m.selectedDate, m.de)),
                if (dailyPeriods.isEmpty)
                  Text(
                    m.tr(
                      'Keine Periode an diesem Tag eingetragen.',
                      'No period recorded for this day.',
                    ),
                  ),
                ...dailyPeriods.map((p) => _periodTile(context, m, p)),
                if (dailySymptoms.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  ...dailySymptoms.map((s) => _symptomTile(context, m, s)),
                ],
                const SizedBox(height: 8),
                OutlinedButton.icon(
                  onPressed: () => editSymptom(context, m),
                  icon: const Icon(Icons.add),
                  label: Text(
                    m.tr('Symptom an diesem Tag', 'Symptom for this day'),
                  ),
                ),
                const SizedBox(height: 18),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    m.tr('Persönliche Einschätzung', 'Personal estimate'),
                  ),
                  subtitle: Text(
                    m.tr(
                      'Ausschalten, um nur Tagebuch zu führen.',
                      'Turn off to use as a diary only.',
                    ),
                  ),
                  value: m.settings['cyclePredictions'] != false,
                  onChanged: (value) => safeAction(
                    context,
                    m,
                    () => m.settingsPatch({'cyclePredictions': value}),
                  ),
                ),
                const SizedBox(height: 8),
                cycleSummary(m),
                const SizedBox(height: 10),
                Text(
                  m.tr(
                    'Zur persönlichen Planung. Keine Eisprung- oder Verhütungsberechnung.',
                    'For personal planning. Does not estimate ovulation or provide contraception.',
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 24),
                SectionTitle(m.tr('Periodenhistorie', 'Period history')),
                if (periods.isEmpty)
                  EmptyState(
                    icon: Icons.calendar_month_outlined,
                    title: m.tr(
                      'Platz für deinen Verlauf',
                      'Room for your history',
                    ),
                    message: m.tr(
                      'Du kannst auch vergangene Perioden eintragen. Tippe auf einen Kalendertag oder wähle beim Erfassen ein Datum.',
                      'You can also add past periods. Tap a calendar day or choose a date when recording.',
                    ),
                  ),
              ],
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
            sliver: SliverList.builder(
              itemCount: periods.length,
              itemBuilder: (context, index) =>
                  _periodTile(context, m, periods[index]),
            ),
          ),
        ],
      );
    },
  );

  Widget _calendar(BuildContext context, AppModel m, List<Json> periods) {
    final localizations = MaterialLocalizations.of(context);
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final offset = _month.weekday - 1;
    final daySelected = dateKey(m.selectedDate);
    final symptomDays = _records(
      m,
      'symptoms',
    ).map((s) => (s['at'] as String).substring(0, 10)).toSet();
    final forecast = cycleForecast(m.doc, daySelected);
    final first = forecast['earliest'] as String?;
    final last = forecast['latest'] as String?;
    final weekdayNames = m.de
        ? ['Mo', 'Di', 'Mi', 'Do', 'Fr', 'Sa', 'So']
        : ['Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa', 'Su'];
    return Panel(
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                tooltip: m.tr('Vorheriger Monat', 'Previous month'),
                onPressed: () => _moveMonth(-1),
                icon: const Icon(Icons.chevron_left),
              ),
              Expanded(
                child: TextButton(
                  onPressed: () async {
                    final selected = await pickDate(context, m.selectedDate);
                    if (selected != null && mounted) {
                      setState(
                        () => _month = DateTime(selected.year, selected.month),
                      );
                      m.selectDate(selected);
                    }
                  },
                  child: Text(
                    localizations.formatMonthYear(_month),
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
              IconButton(
                tooltip: m.tr('Nächster Monat', 'Next month'),
                onPressed: () => _moveMonth(1),
                icon: const Icon(Icons.chevron_right),
              ),
            ],
          ),
          Row(
            children: weekdayNames
                .map(
                  (w) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          w,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          LayoutBuilder(
            builder: (context, constraints) => GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisExtent: math.max(
                  math.max(48, constraints.maxWidth / 7),
                  MediaQuery.textScalerOf(context).scale(16) * 1.5 + 20,
                ),
              ),
              itemCount: ((daysInMonth + offset) / 7).ceil() * 7,
              itemBuilder: (context, index) {
                final number = index - offset + 1;
                if (number < 1 || number > daysInMonth) {
                  return const SizedBox.shrink();
                }
                final date = DateTime(_month.year, _month.month, number);
                final key = dateKey(date);
                final active = periods.any((p) => _periodOn(p, key));
                final symptom = symptomDays.contains(key);
                final estimate =
                    forecast['status'] == 'ready' &&
                    first != null &&
                    last != null &&
                    key.compareTo(first) >= 0 &&
                    key.compareTo(last) <= 0;
                final selected = key == daySelected;
                final today = key == dateKey(DateTime.now());
                final label = [
                  displayDate(date, m.de),
                  if (today) m.tr('heute', 'today'),
                  if (active) m.tr('Periode aufgezeichnet', 'period recorded'),
                  if (symptom)
                    m.tr('Symptome aufgezeichnet', 'symptoms recorded'),
                  if (estimate)
                    m.tr('möglicher Periodenbeginn', 'possible period start'),
                ].join(', ');
                return Semantics(
                  label: label,
                  button: true,
                  selected: selected,
                  excludeSemantics: true,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () => m.selectDate(date),
                    child: Container(
                      margin: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: selected
                            ? _mint
                            : active
                            ? const Color(0xFFF6E2E6)
                            : estimate
                            ? const Color(0xFFE7F0E9)
                            : null,
                        borderRadius: BorderRadius.circular(12),
                        border: today || estimate
                            ? Border.all(color: selected ? Colors.white : _mint)
                            : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                '$number',
                                maxLines: 1,
                                style: TextStyle(
                                  color: selected ? Colors.white : null,
                                  fontWeight: selected || today
                                      ? FontWeight.bold
                                      : FontWeight.normal,
                                ),
                              ),
                            ),
                          ),
                          if (active || symptom)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (active)
                                  Icon(
                                    Icons.water_drop,
                                    size: 9,
                                    color: selected ? Colors.white : _rose,
                                  ),
                                if (symptom)
                                  Icon(
                                    Icons.circle,
                                    size: 7,
                                    color: selected ? Colors.white : _mint,
                                  ),
                              ],
                            )
                          else
                            const SizedBox(height: 9),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 6,
            children: [
              _legend(Icons.water_drop, _rose, m.tr('Periode', 'Period')),
              _legend(Icons.circle, _mint, m.tr('Symptom', 'Symptom')),
              if (forecast['status'] == 'ready')
                _legend(
                  Icons.crop_square,
                  _mint,
                  m.tr('Einschätzung', 'Estimate'),
                ),
            ],
          ),
          TextButton(
            onPressed: () {
              final today = DateTime.now();
              setState(() => _month = DateTime(today.year, today.month));
              m.selectDate(today);
            },
            child: Text(m.tr('Heute', 'Today')),
          ),
        ],
      ),
    );
  }
}

Widget _legend(IconData icon, Color color, String text) => Row(
  mainAxisSize: MainAxisSize.min,
  children: [
    Icon(icon, size: 12, color: color),
    const SizedBox(width: 4),
    Text(text, style: const TextStyle(fontSize: 12)),
  ],
);

Widget _periodTile(BuildContext context, AppModel m, Json p) => Card(
  margin: const EdgeInsets.symmetric(vertical: 5),
  child: ListTile(
    leading: const Icon(Icons.water_drop_outlined, color: _rose),
    title: Text(_periodDates(p, m)),
    subtitle: Text(
      '${_flow(m, p['flow'] as String)}${(p['note'] as String? ?? '').isEmpty ? '' : '\n${p['note']}'}',
    ),
    isThreeLine: (p['note'] as String? ?? '').isNotEmpty,
    trailing: const Icon(Icons.edit_outlined, size: 20),
    onTap: () => editPeriod(context, m, entry: p),
  ),
);

Widget _symptomTile(BuildContext context, AppModel m, Json s) => Card(
  margin: const EdgeInsets.symmetric(vertical: 5),
  child: ListTile(
    leading: CircleAvatar(
      backgroundColor: const Color(0xFFE7F0E9),
      child: Text('${s['intensity']}', style: const TextStyle(color: _mint)),
    ),
    title: Text('${s['name']} · ${s['intensity']}/10'),
    subtitle: Text(
      '${_stamp(s['at'] as String, m)}${(s['note'] as String? ?? '').isEmpty ? '' : '\n${s['note']}'}',
    ),
    isThreeLine: (s['note'] as String? ?? '').isNotEmpty,
    trailing: const Icon(Icons.edit_outlined, size: 20),
    onTap: () => editSymptom(context, m, entry: s),
  ),
);

Future<void> editPeriod(
  BuildContext context,
  AppModel model, {
  Json? entry,
}) async {
  var start = entry == null
      ? model.selectedDate
      : parseDay(entry['start'] as String);
  DateTime? end = entry?['end'] == null
      ? null
      : parseDay(entry!['end'] as String);
  var ongoing = end == null;
  var flow = entry?['flow'] as String? ?? 'medium';
  final note = TextEditingController(text: entry?['note'] as String? ?? '');
  String? error;
  var busy = false;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => _EditorScope(
      controllers: [note],
      builder: (context, update) {
        final m = model;
        return AlertDialog(
          title: Text(
            entry == null
                ? m.tr('Periode erfassen', 'Record period')
                : m.tr('Periode bearbeiten', 'Edit period'),
          ),
          scrollable: true,
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dateButton(
                  m.tr('Beginn', 'Start'),
                  displayDate(start, m.de),
                  busy
                      ? null
                      : () async {
                          final date = await pickDate(context, start);
                          if (date != null && context.mounted) {
                            update(() {
                              start = date;
                              error = null;
                            });
                          }
                        },
                ),
                SwitchListTile.adaptive(
                  contentPadding: EdgeInsets.zero,
                  title: Text(m.tr('Noch nicht beendet', 'Still ongoing')),
                  value: ongoing,
                  onChanged: busy
                      ? null
                      : (value) => update(() {
                          ongoing = value;
                          end ??= start;
                          error = null;
                        }),
                ),
                if (!ongoing)
                  _dateButton(
                    m.tr('Ende (einschließlich)', 'End (inclusive)'),
                    displayDate(end ?? start, m.de),
                    busy
                        ? null
                        : () async {
                            final date = await pickDate(context, end ?? start);
                            if (date != null && context.mounted) {
                              update(() {
                                end = date;
                                error = null;
                              });
                            }
                          },
                  ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: flow,
                  decoration: InputDecoration(
                    labelText: m.tr('Blutungsstärke', 'Flow'),
                  ),
                  items: ['spotting', 'light', 'medium', 'heavy']
                      .map(
                        (f) => DropdownMenuItem(
                          value: f,
                          child: Text(_flow(m, f)),
                        ),
                      )
                      .toList(),
                  onChanged: busy
                      ? null
                      : (value) => update(() => flow = value!),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: note,
                  enabled: !busy,
                  minLines: 2,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: m.tr('Notiz (optional)', 'Note (optional)'),
                  ),
                ),
                if (error != null) _errorText(error!),
              ],
            ),
          ),
          actions: _editorActions(
            context,
            m,
            busy: busy,
            existing: entry != null,
            onDelete: () async {
              if (!await confirmDelete(context, m) || !context.mounted) return;
              update(() => busy = true);
              try {
                await m.remove('periods', entry!['id'] as String);
                if (context.mounted) Navigator.pop(context);
              } catch (_) {
                if (context.mounted) {
                  update(() {
                    busy = false;
                    error = m.tr(
                      'Löschen fehlgeschlagen. Bitte erneut versuchen.',
                      'Could not delete. Please try again.',
                    );
                  });
                }
              }
            },
            onSave: () async {
              final startKey = dateKey(start);
              final endKey = ongoing ? null : dateKey(end ?? start);
              final today = dateKey(DateTime.now());
              String? validation;
              if (startKey.compareTo(today) > 0 ||
                  (endKey != null && endKey.compareTo(today) > 0)) {
                validation = m.tr(
                  'Perioden können bis einschließlich heute dokumentiert werden.',
                  'Periods can be recorded up to and including today.',
                );
              } else if (endKey != null && endKey.compareTo(startKey) < 0) {
                validation = m.tr(
                  'Das Ende muss am oder nach dem Beginn liegen.',
                  'The end must be on or after the start.',
                );
              } else {
                try {
                  validatePeriodOverlaps([
                    ..._records(
                      m,
                      'periods',
                    ).where((p) => p['id'] != entry?['id']),
                    {'start': startKey, 'end': endKey, 'flow': flow},
                  ]);
                } on CoreException {
                  validation = m.tr(
                    'Dieser Zeitraum überschneidet sich mit einer bestehenden Periode. Bearbeite zunächst den vorhandenen Eintrag.',
                    'These dates overlap an existing period. Edit the existing record first.',
                  );
                }
              }
              if (validation != null) {
                update(() => error = validation);
                return;
              }
              update(() {
                busy = true;
                error = null;
              });
              try {
                await m.put('periods', {
                  'id': entry?['id'] ?? newId(),
                  'start': startKey,
                  'end': endKey,
                  'flow': flow,
                  'note': note.text.trim(),
                });
                if (context.mounted) Navigator.pop(context);
              } catch (_) {
                if (context.mounted) {
                  update(() {
                    busy = false;
                    error = m.tr(
                      'Speichern fehlgeschlagen. Prüfe die Angaben und versuche es erneut.',
                      'Could not save. Check the values and try again.',
                    );
                  });
                }
              }
            },
          ),
        );
      },
    ),
  );
}

/// Dispose only when the route is unmounted, after its reverse animation.
class _EditorScope extends StatefulWidget {
  const _EditorScope({required this.controllers, required this.builder});
  final List<TextEditingController> controllers;
  final StatefulWidgetBuilder builder;
  @override
  State<_EditorScope> createState() => _EditorScopeState();
}

class _EditorScopeState extends State<_EditorScope> {
  @override
  Widget build(BuildContext context) => widget.builder(context, setState);
  @override
  void dispose() {
    for (final controller in widget.controllers) {
      controller.dispose();
    }
    super.dispose();
  }
}

Widget _dateButton(String label, String value, VoidCallback? onPressed) =>
    Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: const Icon(Icons.calendar_today_outlined, size: 18),
        label: Padding(
          padding: const EdgeInsets.symmetric(vertical: 9),
          child: Text('$label: $value'),
        ),
      ),
    );

Widget _errorText(String error) => Padding(
  padding: const EdgeInsets.only(top: 14),
  child: Semantics(
    liveRegion: true,
    child: Text(error, style: const TextStyle(color: Color(0xFF9D2634))),
  ),
);

List<Widget> _editorActions(
  BuildContext context,
  AppModel m, {
  required bool busy,
  required bool existing,
  required VoidCallback onDelete,
  required VoidCallback onSave,
}) => [
  if (existing)
    TextButton.icon(
      onPressed: busy ? null : onDelete,
      icon: const Icon(Icons.delete_outline, size: 18),
      label: Text(m.tr('Löschen', 'Delete')),
      style: TextButton.styleFrom(foregroundColor: const Color(0xFF9D2634)),
    ),
  TextButton(
    onPressed: busy ? null : () => Navigator.pop(context),
    child: Text(m.tr('Abbrechen', 'Cancel')),
  ),
  FilledButton(
    onPressed: busy ? null : onSave,
    child: busy
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : Text(m.tr('Speichern', 'Save')),
  ),
];

Future<void> editWeight(
  BuildContext context,
  AppModel model, {
  Json? entry,
}) async {
  var unit = model.settings['weightUnit'] as String? ?? 'kg';
  var date = entry == null
      ? model.selectedDate
      : _civilTime(entry['at'] as String);
  final kg = numeric(entry?['kg']);
  final amount = TextEditingController(
    text: kg == null ? '' : fmt(unit == 'lb' ? kg * 2.2046226218 : kg, 2),
  );
  var amountEdited = false;
  final note = TextEditingController(text: entry?['note'] as String? ?? '');
  String? error;
  var busy = false;
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => _EditorScope(
      controllers: [amount, note],
      builder: (context, update) {
        final m = model;
        return AlertDialog(
          title: Text(
            entry == null
                ? m.tr('Gewicht erfassen', 'Record weight')
                : m.tr('Gewicht bearbeiten', 'Edit weight'),
          ),
          scrollable: true,
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _dateButton(
                  m.tr('Datum', 'Date'),
                  displayDate(date, m.de),
                  busy
                      ? null
                      : () async {
                          final selected = await pickDate(context, date);
                          if (selected != null && context.mounted) {
                            update(() => date = selected);
                          }
                        },
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: amount,
                        onChanged: (_) => amountEdited = true,
                        enabled: !busy,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: InputDecoration(
                          labelText: '${m.tr('Gewicht', 'Weight')} ($unit)',
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SegmentedButton<String>(
                      segments: const [
                        ButtonSegment(value: 'kg', label: Text('kg')),
                        ButtonSegment(value: 'lb', label: Text('lb')),
                      ],
                      selected: {unit},
                      showSelectedIcon: false,
                      onSelectionChanged: busy
                          ? null
                          : (selected) => update(() {
                              final value = double.tryParse(
                                amount.text.trim().replaceAll(',', '.'),
                              );
                              final next = selected.first;
                              if (!amountEdited && kg != null) {
                                amount.text = fmt(
                                  next == 'lb' ? kg * 2.2046226218 : kg,
                                  2,
                                );
                              } else if (value != null && next != unit) {
                                amount.text = fmt(
                                  next == 'lb'
                                      ? value * 2.2046226218
                                      : value / 2.2046226218,
                                  2,
                                );
                              }
                              unit = next;
                            }),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                TextField(
                  controller: note,
                  enabled: !busy,
                  minLines: 2,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: m.tr('Notiz (optional)', 'Note (optional)'),
                  ),
                ),
                if (error != null) _errorText(error!),
              ],
            ),
          ),
          actions: _editorActions(
            context,
            m,
            busy: busy,
            existing: entry != null,
            onDelete: () async {
              if (!await confirmDelete(context, m) || !context.mounted) return;
              update(() => busy = true);
              try {
                await m.remove('weights', entry!['id'] as String);
                if (context.mounted) Navigator.pop(context);
              } catch (_) {
                if (context.mounted) {
                  update(() {
                    busy = false;
                    error = m.tr(
                      'Löschen fehlgeschlagen. Bitte erneut versuchen.',
                      'Could not delete. Please try again.',
                    );
                  });
                }
              }
            },
            onSave: () async {
              final input = double.tryParse(
                amount.text.trim().replaceAll(',', '.'),
              );
              final value = !amountEdited && kg != null
                  ? kg
                  : input == null
                  ? null
                  : unit == 'lb'
                  ? input / 2.2046226218
                  : input;
              if (value == null ||
                  !value.isFinite ||
                  value <= 0 ||
                  value > 2000) {
                update(
                  () => error = m.tr(
                    'Bitte ein Gewicht größer als 0 und höchstens 2.000 kg (4.409,25 lb) eingeben.',
                    'Enter a weight above 0 and at most 2,000 kg (4,409.25 lb).',
                  ),
                );
                return;
              }
              update(() {
                busy = true;
                error = null;
              });
              try {
                await m.put('weights', {
                  'id': entry?['id'] ?? newId(),
                  'at': _savedTimestamp(date, entry),
                  'kg': value,
                  'note': note.text.trim(),
                });
                if (context.mounted) Navigator.pop(context);
              } catch (_) {
                if (context.mounted) {
                  update(() {
                    busy = false;
                    error = m.tr(
                      'Speichern fehlgeschlagen. Prüfe die Angaben und versuche es erneut.',
                      'Could not save. Check the values and try again.',
                    );
                  });
                }
              }
            },
          ),
        );
      },
    ),
  );
}

Future<void> editSymptom(
  BuildContext context,
  AppModel model, {
  Json? entry,
}) async {
  final now = DateTime.now();
  var at = entry == null
      ? DateTime(
          model.selectedDate.year,
          model.selectedDate.month,
          model.selectedDate.day,
          now.hour,
          now.minute,
        )
      : _civilTime(entry['at'] as String);
  var intensity = (entry?['intensity'] as num?)?.toInt() ?? 5;
  final name = TextEditingController(text: entry?['name'] as String? ?? '');
  final note = TextEditingController(text: entry?['note'] as String? ?? '');
  String? error;
  var busy = false;
  final names = _records(
    model,
    'symptoms',
  ).map((s) => s['name'] as String).toSet().take(8).toList();
  await showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (dialogContext) => _EditorScope(
      controllers: [name, note],
      builder: (context, update) {
        final m = model;
        return AlertDialog(
          title: Text(
            entry == null
                ? m.tr('Symptom erfassen', 'Record symptom')
                : m.tr('Symptom bearbeiten', 'Edit symptom'),
          ),
          scrollable: true,
          content: SizedBox(
            width: 440,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  enabled: !busy,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    labelText: m.tr('Symptomname', 'Symptom name'),
                    hintText: m.tr(
                      'Zum Beispiel Kopfschmerzen',
                      'For example, headache',
                    ),
                  ),
                ),
                if (names.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 2,
                    children: names
                        .map(
                          (n) => ActionChip(
                            label: Text(n),
                            onPressed: busy ? null : () => name.text = n,
                          ),
                        )
                        .toList(),
                  ),
                ],
                const SizedBox(height: 18),
                Text(
                  '${m.tr('Intensität', 'Intensity')}: $intensity / 10',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                Slider(
                  value: intensity.toDouble(),
                  min: 0,
                  max: 10,
                  divisions: 10,
                  label: '$intensity / 10',
                  semanticFormatterCallback: (v) =>
                      '${v.round()} ${m.tr('von', 'out of')} 10',
                  onChanged: busy
                      ? null
                      : (v) => update(() => intensity = v.round()),
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(child: Text(m.tr('0 · keine', '0 · none'))),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        m.tr('10 · sehr stark', '10 · severe'),
                        textAlign: TextAlign.end,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                _dateButton(
                  m.tr('Zeitpunkt', 'Date & time'),
                  _stamp(at.toIso8601String(), m),
                  busy
                      ? null
                      : () async {
                          final selected = await pickTimestamp(context, at);
                          if (selected != null && context.mounted) {
                            update(() => at = selected);
                          }
                        },
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: note,
                  enabled: !busy,
                  minLines: 2,
                  maxLines: 4,
                  decoration: InputDecoration(
                    labelText: m.tr('Notiz (optional)', 'Note (optional)'),
                  ),
                ),
                if (error != null) _errorText(error!),
              ],
            ),
          ),
          actions: _editorActions(
            context,
            m,
            busy: busy,
            existing: entry != null,
            onDelete: () async {
              if (!await confirmDelete(context, m) || !context.mounted) return;
              update(() => busy = true);
              try {
                await m.remove('symptoms', entry!['id'] as String);
                if (context.mounted) Navigator.pop(context);
              } catch (_) {
                if (context.mounted) {
                  update(() {
                    busy = false;
                    error = m.tr(
                      'Löschen fehlgeschlagen. Bitte erneut versuchen.',
                      'Could not delete. Please try again.',
                    );
                  });
                }
              }
            },
            onSave: () async {
              if (name.text.trim().isEmpty) {
                update(
                  () => error = m.tr(
                    'Bitte benenne das Symptom.',
                    'Please enter a symptom name.',
                  ),
                );
                return;
              }
              update(() {
                busy = true;
                error = null;
              });
              try {
                await m.put('symptoms', {
                  'id': entry?['id'] ?? newId(),
                  'name': name.text.trim(),
                  'intensity': intensity,
                  'at': _savedTimestamp(at, entry),
                  'note': note.text.trim(),
                });
                if (context.mounted) Navigator.pop(context);
              } catch (_) {
                if (context.mounted) {
                  update(() {
                    busy = false;
                    error = m.tr(
                      'Speichern fehlgeschlagen. Prüfe die Angaben und versuche es erneut.',
                      'Could not save. Check the values and try again.',
                    );
                  });
                }
              }
            },
          ),
        );
      },
    ),
  );
}

class WeightPage extends StatefulWidget {
  const WeightPage({super.key, required this.model});
  final AppModel model;

  @override
  State<WeightPage> createState() => _WeightPageState();
}

class _WeightPageState extends State<WeightPage> {
  int _days = 28;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.model,
    builder: (context, _) {
      final m = widget.model;
      final unit = m.settings['weightUnit'] as String? ?? 'kg';
      final entries = _range(_records(m, 'weights'), m.selectedDate, _days);
      final points = entries.reversed
          .map(
            (e) => _Point(
              _civilTime(e['at'] as String),
              (e['kg'] as num).toDouble() * (unit == 'lb' ? 2.2046226218 : 1),
            ),
          )
          .toList();
      return Scaffold(
        appBar: AppBar(title: Text(m.tr('Gewicht', 'Weight'))),
        body: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                sliver: SliverList.list(
                  children: [
                    Text(
                      m.tr('Dein Gewicht im Verlauf', 'Your weight over time'),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      m.tr(
                        'Eine ruhige Übersicht deiner eigenen Aufzeichnungen.',
                        'A calm view of your own records.',
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => editWeight(context, m),
                      icon: const Icon(Icons.add),
                      label: Text(m.tr('Gewicht erfassen', 'Record weight')),
                    ),
                    const SizedBox(height: 14),
                    dateBar(context, m),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: Text(m.tr('Anzeigeeinheit', 'Display unit')),
                        ),
                        SegmentedButton<String>(
                          segments: const [
                            ButtonSegment(value: 'kg', label: Text('kg')),
                            ButtonSegment(value: 'lb', label: Text('lb')),
                          ],
                          selected: {unit},
                          showSelectedIcon: false,
                          onSelectionChanged: (v) => safeAction(
                            context,
                            m,
                            () => m.settingsPatch({'weightUnit': v.first}),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    _rangeButtons(m, _days, (v) => setState(() => _days = v)),
                    const SizedBox(height: 16),
                    _TrendPanel(
                      model: m,
                      points: points,
                      unit: unit,
                      title: m.tr('Gewichtsverlauf', 'Weight trend'),
                    ),
                    const SizedBox(height: 24),
                    SectionTitle(
                      '${m.tr('Aufzeichnungen', 'Records')} · ${entries.length}',
                    ),
                    if (entries.isEmpty)
                      EmptyState(
                        icon: Icons.monitor_weight_outlined,
                        title: m.tr(
                          'Noch kein Gewicht in diesem Zeitraum',
                          'No weight in this range yet',
                        ),
                        message: m.tr(
                          'Erfasse einen Wert oder wähle einen anderen Zeitraum.',
                          'Record a value or choose another date range.',
                        ),
                      ),
                  ],
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                sliver: SliverList.builder(
                  itemCount: entries.length,
                  itemBuilder: (context, index) {
                    final e = entries[index];
                    final value =
                        (e['kg'] as num) * (unit == 'lb' ? 2.2046226218 : 1);
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 5),
                      child: ListTile(
                        leading: const Icon(
                          Icons.monitor_weight_outlined,
                          color: _mint,
                        ),
                        title: Text('${fmt(value, 2)} $unit'),
                        subtitle: Text(
                          '${_date((e['at'] as String).substring(0, 10), m)}${(e['note'] as String? ?? '').isEmpty ? '' : '\n${e['note']}'}',
                        ),
                        isThreeLine: (e['note'] as String? ?? '').isNotEmpty,
                        trailing: const Icon(Icons.edit_outlined, size: 20),
                        onTap: () => editWeight(context, m, entry: e),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

class SymptomsPage extends StatefulWidget {
  const SymptomsPage({super.key, required this.model});
  final AppModel model;

  @override
  State<SymptomsPage> createState() => _SymptomsPageState();
}

class _SymptomsPageState extends State<SymptomsPage> {
  int _days = 28;
  String? _name;
  bool _allRecords = true;

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.model,
    builder: (context, _) {
      final m = widget.model;
      final all = _records(m, 'symptoms');
      final names = all.map((s) => s['name'] as String).toSet().toList()
        ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
      final selected = names.contains(_name) ? _name : names.firstOrNull;
      final entries = _range(all, m.selectedDate, _days);
      final selectedEntries = entries
          .where((e) => e['name'] == selected)
          .toList();
      final list = _allRecords ? entries : selectedEntries;
      final points = selectedEntries.reversed
          .map(
            (e) => _Point(
              _civilTime(e['at'] as String),
              (e['intensity'] as num).toDouble(),
            ),
          )
          .toList();
      return Scaffold(
        appBar: AppBar(title: Text(m.tr('Symptome', 'Symptoms'))),
        body: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                sliver: SliverList.list(
                  children: [
                    Text(
                      m.tr('Wie fühlst du dich?', 'How are you feeling?'),
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      m.tr(
                        'Eigene Worte. Ein klarer Verlauf.',
                        'Your own words. A clear history.',
                      ),
                    ),
                    const SizedBox(height: 16),
                    FilledButton.icon(
                      onPressed: () => editSymptom(context, m),
                      icon: const Icon(Icons.add),
                      label: Text(m.tr('Symptom erfassen', 'Record symptom')),
                    ),
                    const SizedBox(height: 14),
                    dateBar(context, m),
                    const SizedBox(height: 14),
                    _rangeButtons(m, _days, (v) => setState(() => _days = v)),
                    const SizedBox(height: 16),
                    if (names.isNotEmpty) ...[
                      DropdownButtonFormField<String>(
                        key: ValueKey(selected),
                        initialValue: selected,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: m.tr(
                            'Symptom für den Verlauf',
                            'Symptom to chart',
                          ),
                        ),
                        items: names
                            .map(
                              (name) => DropdownMenuItem(
                                value: name,
                                child: Text(
                                  name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) => setState(() => _name = value),
                      ),
                      const SizedBox(height: 16),
                      _TrendPanel(
                        model: m,
                        points: points,
                        unit: '/10',
                        title: selected ?? '',
                        fixedBounds: true,
                      ),
                      const SizedBox(height: 12),
                      SwitchListTile.adaptive(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          m.tr(
                            'Alle Symptome in der Liste',
                            'Show all symptoms in the list',
                          ),
                        ),
                        subtitle: Text(
                          m.tr(
                            'Der Verlauf zeigt das oben gewählte Symptom.',
                            'The chart shows the symptom selected above.',
                          ),
                        ),
                        value: _allRecords,
                        onChanged: (value) =>
                            setState(() => _allRecords = value),
                      ),
                    ],
                    const SizedBox(height: 16),
                    SectionTitle(
                      '${m.tr('Aufzeichnungen', 'Records')} · ${list.length}',
                    ),
                    if (list.isEmpty)
                      EmptyState(
                        icon: Icons.spa_outlined,
                        title: m.tr(
                          'Raum für deine Beobachtungen',
                          'Room for your observations',
                        ),
                        message: m.tr(
                          'Für diesen Zeitraum gibt es keine passenden Einträge. Erfasse ein Symptom oder ändere den Zeitraum.',
                          'There are no matching records in this range. Record a symptom or change the date range.',
                        ),
                      ),
                  ],
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                sliver: SliverList.builder(
                  itemCount: list.length,
                  itemBuilder: (context, index) =>
                      _symptomTile(context, m, list[index]),
                ),
              ),
            ],
          ),
        ),
      );
    },
  );
}

List<Json> _range(List<Json> entries, DateTime until, int days) {
  final end = dateKey(until);
  final start = dateKey(
    DateTime(until.year, until.month, until.day - days + 1),
  );
  return entries.where((e) {
    if (days == 0) return true;
    final key = (e['at'] as String).substring(0, 10);
    return key.compareTo(start) >= 0 && key.compareTo(end) <= 0;
  }).toList()..sort((a, b) => (b['at'] as String).compareTo(a['at'] as String));
}

Widget _rangeButtons(AppModel m, int selected, ValueChanged<int> onChanged) =>
    SegmentedButton<int>(
      segments: [
        ButtonSegment(value: 7, label: Text(m.tr('7 Tage', '7 days'))),
        ButtonSegment(value: 28, label: Text(m.tr('28 Tage', '28 days'))),
        ButtonSegment(value: 0, label: Text(m.tr('Alle', 'All'))),
      ],
      selected: {selected},
      onSelectionChanged: (value) => onChanged(value.first),
    );

class _Point {
  const _Point(this.at, this.value);
  final DateTime at;
  final double value;
}

class _TrendPanel extends StatelessWidget {
  const _TrendPanel({
    required this.model,
    required this.points,
    required this.unit,
    required this.title,
    this.fixedBounds = false,
  });
  final AppModel model;
  final List<_Point> points;
  final String unit;
  final String title;
  final bool fixedBounds;

  @override
  Widget build(BuildContext context) {
    final m = model;
    final low = points.isEmpty
        ? 0.0
        : points.map((p) => p.value).reduce(math.min);
    final high = points.isEmpty
        ? 0.0
        : points.map((p) => p.value).reduce(math.max);
    final difference = points.length < 2
        ? 0.0
        : points.last.value - points.first.value;
    final summary = points.isEmpty
        ? m.tr('Keine Werte im gewählten Zeitraum.', 'No values in this range.')
        : '${points.length} ${m.tr('Werte', 'values')} · ${m.tr('Zuletzt', 'Latest')}: ${fmt(points.last.value)} $unit\n'
              '${m.tr('Bereich', 'Range')}: ${fmt(low)}–${fmt(high)} $unit'
              '${points.length < 2 ? '' : '\n${m.tr('Änderung vom ersten zum letzten Wert', 'Change from first to last value')}: ${difference > 0 ? '+' : ''}${fmt(difference)} $unit'}';
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 10),
          Text(summary),
          if (points.isNotEmpty) ...[
            const SizedBox(height: 16),
            Semantics(
              label:
                  '$title. $summary. ${m.tr('Die einzelnen Werte stehen in der Liste darunter.', 'Individual values appear in the list below.')}',
              image: true,
              child: ExcludeSemantics(
                child: SizedBox(
                  height: 150,
                  width: double.infinity,
                  child: CustomPaint(
                    painter: _TrendPainter(
                      points,
                      fixedBounds: fixedBounds,
                      textDirection: Directionality.of(context),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  displayDate(points.first.at, m.de),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                Text(
                  displayDate(points.last.at, m.de),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              m.tr(
                'Punkte sind Aufzeichnungen; Linien verbinden sie. Fehlende Tage sind keine Nullwerte.',
                'Dots are records; lines connect them. Missing days are not zero values.',
              ),
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ],
      ),
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter(
    this.points, {
    required this.fixedBounds,
    required this.textDirection,
  });
  final List<_Point> points;
  final bool fixedBounds;
  final TextDirection textDirection;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty) return;
    final min = fixedBounds ? 0.0 : points.map((p) => p.value).reduce(math.min);
    final max = fixedBounds
        ? 10.0
        : points.map((p) => p.value).reduce(math.max);
    final padding = fixedBounds ? 0.0 : math.max((max - min) * .15, .5);
    final bottom = min - padding;
    final top = max + padding;
    final span = math.max(top - bottom, 1.0);
    final plot = Rect.fromLTRB(
      48,
      10,
      math.max(49, size.width - 8),
      size.height - 10,
    );
    final grid = Paint()
      ..color = const Color(0xFFD8E1D9)
      ..strokeWidth = 1;
    for (var i = 0; i <= 2; i++) {
      final y = plot.top + plot.height * i / 2;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), grid);
      final label = TextPainter(
        text: TextSpan(
          text: fmt(top - span * i / 2),
          style: const TextStyle(fontSize: 11, color: Color(0xFF53675E)),
        ),
        textDirection: textDirection,
      )..layout(maxWidth: 44);
      label.paint(canvas, Offset(0, y - label.height / 2));
    }
    final start = points.first.at.millisecondsSinceEpoch;
    final elapsed = math.max(1, points.last.at.millisecondsSinceEpoch - start);
    Offset position(_Point p) => Offset(
      points.length == 1
          ? plot.center.dx
          : plot.left +
                plot.width * (p.at.millisecondsSinceEpoch - start) / elapsed,
      plot.bottom - (p.value - bottom) / span * plot.height,
    );
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final p = position(points[i]);
      if (i == 0) {
        path.moveTo(p.dx, p.dy);
      } else {
        path.lineTo(p.dx, p.dy);
      }
    }
    canvas.drawPath(
      path,
      Paint()
        ..color = _mint
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke,
    );
    final dotPaint = Paint()..color = _mint;
    final stride = math.max(1, (points.length / 180).ceil());
    for (var i = 0; i < points.length; i += stride) {
      canvas.drawCircle(position(points[i]), 3.5, dotPaint);
    }
    canvas.drawCircle(position(points.last), 3.5, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _TrendPainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.fixedBounds != fixedBounds ||
      oldDelegate.textDirection != textDirection;
}
