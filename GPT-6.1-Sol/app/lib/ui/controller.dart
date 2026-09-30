import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../core/engine.dart';
import '../core/food_api.dart';
import '../core/model.dart';
import '../core/nutrients.dart';

class AppController extends ChangeNotifier {
  final HealthEngine engine;
  final FoodApi api;
  String selectedDay;
  int tab = 0;
  Future<void> _pending = Future.value();
  Future<void> whenIdle() => _pending;
  AppController(this.engine, this.api) : selectedDay = engine.clock.today;
  HealthData get data => engine.data;
  String get language => data.settings['language'];
  bool get pounds => data.settings['weight_unit'] == 'lb';
  String tr(String de, String en) => language == 'de' ? de : en;
  String date(String day, {bool short = false}) => DateFormat(
    short ? 'dd.MM.yyyy' : 'EEE, d. MMM yyyy',
    language,
  ).format(parseDay(day));
  String fmt(dynamic value, {int digits = 1}) {
    final v = number(value);
    if (v == null) return '—';
    return NumberFormat(
      v == v.roundToDouble() ? '0' : '0.${'#' * digits}',
      language,
    ).format(v);
  }

  String input(dynamic value) {
    final v = number(value);
    if (v == null) return '';
    final text = v.abs() < 9007199254740992 && v == v.roundToDouble()
        ? v.toInt().toString()
        : v.toString();
    return language == 'de' ? text.replaceAll('.', ',') : text;
  }

  String foodName(Json food) =>
      language == 'en' && (food['name_en'] as String?)?.isNotEmpty == true
      ? food['name_en']
      : food['name'];
  String unit(String u) => u == 'portion' ? tr('Portionen', 'servings') : u;
  String meal(String m) => switch (m) {
    'breakfast' => tr('Frühstück', 'Breakfast'),
    'lunch' => tr('Mittagessen', 'Lunch'),
    'dinner' => tr('Abendessen', 'Dinner'),
    _ => tr('Snack', 'Snack'),
  };
  String strength(String s) => switch (s) {
    'none' => tr('Keine Blutung', 'No bleeding'),
    'spotting' => tr('Spotting', 'Spotting'),
    'light' => tr('Leicht', 'Light'),
    'heavy' => tr('Stark', 'Heavy'),
    _ => tr('Mittel', 'Medium'),
  };
  void day(String date) {
    selectedDay = date;
    notifyListeners();
  }

  void navigate(int index) {
    tab = index;
    notifyListeners();
  }

  Future<void> change(void Function(HealthData) action) {
    final next = _pending.then((_) => engine.change(action));
    _pending = next.catchError((_) {});
    return next.then((_) => notifyListeners());
  }

  Future<void> replace(Json document) {
    final next = _pending.then((_) => engine.replace(document));
    _pending = next.catchError((_) {});
    return next.then((_) => notifyListeners());
  }

  Future<void> upsert(String table, Json record) => change((data) {
    final index = data[table].indexWhere((r) => r['id'] == record['id']);
    final copy = jsonDecode(jsonEncode(record)) as Json;
    if (index < 0) {
      data[table].add(copy);
    } else {
      data[table][index] = copy;
    }
  });
  Future<void> remove(String table, String id) =>
      change((data) => data[table].removeWhere((r) => r['id'] == id));
  String error(Object e) {
    final code = e is FormatException
        ? e.message
        : e is FoodApiError
        ? e.code
        : '';
    return switch (code) {
      'end_before_start' => tr(
        'Das Ende muss am oder nach dem Beginn liegen.',
        'The end must be on or after the start.',
      ),
      'periods_overlap' => tr(
        'Diese Periode überschneidet sich mit einer vorhandenen. Beende oder korrigiere zuerst den anderen Eintrag.',
        'This period overlaps an existing one. End or correct the other entry first.',
      ),
      'duplicate_bleeding_date' => tr(
        'Für diesen Tag gibt es bereits eine Blutungsaufzeichnung. Bearbeite sie im Tagesdetail.',
        'This day already has a bleeding record. Edit it in the day detail.',
      ),
      'density_required' => tr(
        'Für die Umrechnung zwischen g und ml ist eine Dichte nötig.',
        'A density is needed to convert between g and ml.',
      ),
      'serving_required' => tr(
        'Gib zuerst die Größe einer Portion an.',
        'Enter the size of one serving first.',
      ),
      'authentication_failed' => tr(
        'Die Passphrase ist falsch oder die Datei wurde verändert.',
        'The passphrase is incorrect or the file has been changed.',
      ),
      'network_unavailable' => tr(
        'Keine Verbindung. Deine lokalen Lebensmittel bleiben verfügbar.',
        'No connection. Your local foods are still available.',
      ),
      'request_timeout' => tr(
        'Die Suche hat zu lange gedauert. Versuche es erneut.',
        'The search timed out. Please try again.',
      ),
      'rate_limited' => tr(
        'Die Lebensmittelsuche ist gerade ausgelastet. Versuche es später erneut.',
        'Food search is busy. Please try again later.',
      ),
      'tls_error' => tr(
        'Die sichere Verbindung konnte nicht hergestellt werden.',
        'A secure connection could not be established.',
      ),
      'passphrase_too_short' => tr(
        'Verwende mindestens zehn Zeichen.',
        'Use at least ten characters.',
      ),
      'invalid_barcode' => tr(
        'Gib eine Barcode-Nummer mit 4 bis 24 Ziffern ein.',
        'Enter a barcode number with 4 to 24 digits.',
      ),
      _ =>
        e is FormatException
            ? tr(
                'Die Eingaben oder das Dateiformat sind ungültig. Prüfe die Werte und die unterstützte Dateiversion.',
                'The values or file format are invalid. Check the values and the supported file version.',
              )
            : tr(
                'Der Vorgang konnte nicht abgeschlossen werden. Versuche es erneut.',
                'The operation could not be completed. Please try again.',
              ),
    };
  }
}

class AppScope extends InheritedNotifier<AppController> {
  const AppScope({
    super.key,
    required AppController controller,
    required super.child,
  }) : super(notifier: controller);
  static AppController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;
}
