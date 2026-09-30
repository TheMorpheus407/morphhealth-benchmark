import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/core.dart';

const ink = Color(0xFF203C39);
const mint = Color(0xFFE3EEE5);
const cream = Color(0xFFF7F8F2);
const terracotta = Color(0xFFAF6147);

class AppModel extends ChangeNotifier {
  AppModel(this.store, this.api);
  final Store store;
  final FoodApi api;
  Json get doc => store.document;
  Json get settings => doc['settings'] as Json;
  bool get de => settings['language'] != 'en';
  String tr(String german, String english) => de ? german : english;
  DateTime selectedDate = DateUtils.dateOnly(DateTime.now());
  Future<void> put(String col, Json item) async {
    await store.put(col, item);
    notifyListeners();
  }

  Future<void> remove(String col, String id) async {
    await store.remove(col, id);
    notifyListeners();
  }

  Future<void> settingsPatch(Json patch) async {
    await store.updateSettings(patch);
    notifyListeners();
  }

  Future<void> replace(Json document) async {
    await store.replace(document);
    notifyListeners();
  }

  Future<void> clear() async {
    await store.clear();
    notifyListeners();
  }

  void selectDate(DateTime date) {
    selectedDate = DateUtils.dateOnly(date);
    notifyListeners();
  }

  void refresh() => notifyListeners();
}

class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.color});
  final Widget child;
  final Color? color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: color ?? Colors.white,
      borderRadius: BorderRadius.circular(24),
      border: Border.all(color: ink.withValues(alpha: .07)),
    ),
    child: child,
  );
}

class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.trailing});
  final String title;
  final Widget? trailing;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 12),
    child: Row(
      children: [
        Expanded(
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        ?trailing,
      ],
    ),
  );
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
  });
  final IconData icon;
  final String title, message;
  final Widget? action;
  @override
  Widget build(BuildContext context) => Panel(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 32, color: Theme.of(context).colorScheme.primary),
        const SizedBox(height: 16),
        Text(title, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        Text(message),
        if (action != null)
          Padding(padding: const EdgeInsets.only(top: 16), child: action),
      ],
    ),
  );
}

String fmt(num? value, [int digits = 1]) {
  if (value == null) return '—';
  var precision = digits;
  while (value != 0 &&
      double.parse(value.toStringAsFixed(precision)) == 0 &&
      precision < 6) {
    precision++;
  }
  if (value != 0 && double.parse(value.toStringAsFixed(precision)) == 0) {
    return value.toStringAsExponential(2);
  }
  final s = value.toStringAsFixed(precision);
  return s.replaceFirst(RegExp(r'\.0+$'), '');
}

String displayDate(DateTime date, bool de) => de
    ? '${date.day.toString().padLeft(2, '0')}.${date.month.toString().padLeft(2, '0')}.${date.year}'
    : '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
Future<DateTime?> pickDate(BuildContext context, DateTime initial) =>
    showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(1900),
      lastDate: DateTime(2200),
    );
Future<DateTime?> pickTimestamp(BuildContext context, DateTime initial) async {
  final date = await pickDate(context, initial);
  if (date == null || !context.mounted) return null;
  final time = await showTimePicker(
    context: context,
    initialTime: TimeOfDay.fromDateTime(initial),
  );
  return time == null
      ? null
      : DateTime(date.year, date.month, date.day, time.hour, time.minute);
}

Future<bool> confirmDelete(BuildContext context, AppModel m) async =>
    await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(m.tr('Eintrag löschen?', 'Delete entry?')),
        content: Text(
          m.tr(
            'Dieser Eintrag wird dauerhaft entfernt.',
            'This entry will be permanently removed.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(c, false),
            child: Text(m.tr('Abbrechen', 'Cancel')),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(c, true),
            child: Text(m.tr('Löschen', 'Delete')),
          ),
        ],
      ),
    ) ??
    false;
Future<void> safeAction(
  BuildContext context,
  AppModel m,
  Future<void> Function() action,
) async {
  try {
    await action();
  } catch (e) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${m.tr('Aktion fehlgeschlagen', 'Action failed')}: ${friendlyError(m, e)}',
          ),
          duration: const Duration(seconds: 7),
        ),
      );
    }
  }
}

String friendlyError(AppModel m, Object error) {
  if (error is CoreException) {
    return switch (error.code) {
      'authentication_failed' => m.tr(
        'Passphrase oder Datei ungültig. Die Daten wurden nicht geändert.',
        'Invalid passphrase or file. Your data has not changed.',
      ),
      'invalid_document' => m.tr(
        'Die Angaben oder das Datenformat sind ungültig. Prüfe Werte, Einheiten und die Dateiversion.',
        'The values or data format are invalid. Check values, units and file version.',
      ),
      'encrypted_data_invalid' => m.tr(
        'Diese Datei ist keine unterstützte, unbeschädigte Sicherung.',
        'This file is not a supported, intact backup.',
      ),
      'document_too_large' => m.tr(
        'Der Datenbestand überschreitet die unterstützte Größe (64 MiB oder 100.000 Einträge).',
        'The data exceeds the supported size (64 MiB or 100,000 records).',
      ),
      'invalid_passphrase' => m.tr(
        'Die Passphrase muss 10 bis 1.024 Zeichen enthalten.',
        'The passphrase must contain 10 to 1,024 characters.',
      ),
      'overlapping_periods' => m.tr(
        'Die Perioden überschneiden sich. Beende oder korrigiere zuerst den früheren Eintrag.',
        'Periods overlap. Close or correct the earlier entry first.',
      ),
      'invalid_date' => m.tr(
        'Dieses Datum ist ungültig.',
        'This date is invalid.',
      ),
      'food_rate_limited' => m.tr(
        'Zu viele Suchanfragen. Versuche es später erneut.',
        'Too many requests. Please try again later.',
      ),
      'food_offline' || 'food_network' || 'food_timeout' || 'food_tls' => m.tr(
        'Die sichere Verbindung zum Lebensmitteldienst ist nicht verfügbar. Versuche es später erneut.',
        'The secure connection to the food service is unavailable. Try again later.',
      ),
      _ => m.tr(
        'Die Aktion konnte nicht abgeschlossen werden. Prüfe die Angaben und versuche es erneut.',
        'The action could not be completed. Check your input and try again.',
      ),
    };
  }
  if (error is FormatException) {
    return m.tr(
      'Die Datei enthält kein gültiges MorphHealth-JSON.',
      'The file does not contain valid MorphHealth JSON.',
    );
  }
  if (error is PlatformException) {
    return m.tr(
      'Die Datei konnte nicht geöffnet oder gespeichert werden. Prüfe Speicherort, Zugriff und Dateigröße (höchstens 100 MiB).',
      'The file could not be opened or saved. Check its location, access and size (maximum 100 MiB).',
    );
  }
  if (error is FileSystemException) {
    return m.tr(
      'Die Daten konnten nicht gespeichert werden. Prüfe den freien Gerätespeicher.',
      'Your data could not be saved. Check available device storage.',
    );
  }
  return m.tr(
    'Die Aktion konnte nicht abgeschlossen werden. Bitte versuche es erneut.',
    'The action could not be completed. Please try again.',
  );
}

Widget dateBar(BuildContext context, AppModel m) => LayoutBuilder(
  builder: (context, constraints) {
    final previous = IconButton(
      tooltip: m.tr('Vorheriger Tag', 'Previous day'),
      onPressed: () => m.selectDate(
        DateTime(
          m.selectedDate.year,
          m.selectedDate.month,
          m.selectedDate.day - 1,
        ),
      ),
      icon: const Icon(Icons.chevron_left),
    );
    final next = IconButton(
      tooltip: m.tr('Nächster Tag', 'Next day'),
      onPressed: () => m.selectDate(
        DateTime(
          m.selectedDate.year,
          m.selectedDate.month,
          m.selectedDate.day + 1,
        ),
      ),
      icon: const Icon(Icons.chevron_right),
    );
    final today = TextButton(
      onPressed: () => m.selectDate(DateTime.now()),
      child: Text(m.tr('Heute', 'Today')),
    );
    final date = TextButton.icon(
      onPressed: () async {
        final d = await pickDate(context, m.selectedDate);
        if (d != null) m.selectDate(d);
      },
      icon: const Icon(Icons.calendar_today_outlined, size: 17),
      label: Text(displayDate(m.selectedDate, m.de)),
    );
    if (constraints.maxWidth < 350 ||
        MediaQuery.textScalerOf(context).scale(14) > 19) {
      return Column(
        children: [
          date,
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [previous, today, next],
          ),
        ],
      );
    }
    return Row(
      children: [
        previous,
        Expanded(child: date),
        next,
        today,
      ],
    );
  },
);
Widget numberField(
  TextEditingController controller,
  String label, {
  bool required = false,
}) => TextFormField(
  controller: controller,
  decoration: InputDecoration(labelText: label),
  keyboardType: const TextInputType.numberWithOptions(decimal: true),
  validator: (v) {
    if (v == null || v.trim().isEmpty) {
      return required ? '${label.split(' (').first}: > 0' : null;
    }
    final n = double.tryParse(v.replaceAll(',', '.'));
    return n == null || !n.isFinite || n < 0 || (required && n == 0)
        ? '${label.split(' (').first}: ≥ ${required ? '0.01' : '0'}'
        : null;
  },
);

/// Shared trend graphic. Unknown days remain gaps; accessible data table follows.
class TrendPlot extends StatelessWidget {
  const TrendPlot({
    super.key,
    required this.values,
    required this.labels,
    required this.unit,
    required this.model,
    this.color = ink,
  });
  final List<double?> values;
  final List<String> labels;
  final String unit;
  final AppModel model;
  final Color color;
  @override
  Widget build(BuildContext context) {
    final known = values.whereType<double>().toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (known.isNotEmpty) ...[
          Text(
            '${fmt(known.reduce((a, b) => a < b ? a : b))} – ${fmt(known.reduce((a, b) => a > b ? a : b))} $unit',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          Semantics(
            label: model.tr(
              'Verlauf. Die einzelnen Werte stehen in der Tabelle darunter.',
              'Trend. Individual values are in the table below.',
            ),
            child: SizedBox(
              height: 140,
              width: double.infinity,
              child: CustomPaint(painter: _TrendPainter(values, color)),
            ),
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [Text(labels.first), Text(labels.last)],
          ),
        ] else
          Text(
            model.tr(
              'Für diesen Zeitraum liegen noch keine Werte vor.',
              'No values in this time range yet.',
            ),
          ),
        const SizedBox(height: 8),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: Text(model.tr('Tageswerte anzeigen', 'Show daily values')),
          children: [
            for (var i = 0; i < values.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [Text(labels[i]), Text('${fmt(values[i])} $unit')],
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter(this.values, this.color);
  final List<double?> values;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final nums = values.whereType<double>().toList();
    if (nums.isEmpty) return;
    var low = nums.reduce((a, b) => a < b ? a : b),
        high = nums.reduce((a, b) => a > b ? a : b);
    if (low == high) {
      low -= 1;
      high += 1;
    }
    final grid = Paint()
      ..color = color.withValues(alpha: .1)
      ..strokeWidth = 1;
    for (var i = 0; i < 4; i++) {
      final y = 8 + (size.height - 16) * i / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    final stroke = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..style = PaintingStyle.stroke;
    Offset? last;
    for (var i = 0; i < values.length; i++) {
      final n = values[i];
      if (n == null) {
        last = null;
        continue;
      }
      final p = Offset(
        values.length == 1
            ? size.width / 2
            : 4 + (size.width - 8) * i / (values.length - 1),
        8 + (size.height - 16) * (1 - (n - low) / (high - low)),
      );
      if (last != null) canvas.drawLine(last, p, stroke);
      canvas.drawCircle(p, 3.5, Paint()..color = color);
      last = p;
    }
  }

  @override
  bool shouldRepaint(_TrendPainter old) =>
      old.values != values || old.color != color;
}
