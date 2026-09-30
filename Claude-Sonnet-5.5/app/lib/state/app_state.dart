import 'package:flutter/widgets.dart';

import '../core/civil.dart';
import '../core/core.dart';
import '../core/db.dart';
import '../core/models.dart';
import 'boot.dart';

/// Zustand der Oberfläche: der geöffnete Kern, der gewählte Tag und die
/// gemeinsame Beobachtung aller Datenänderungen.
class AppState extends ChangeNotifier with WidgetsBindingObserver {
  MorphCore _core;
  final Session session;

  late Day _selected;
  bool _followsToday = true;
  Area? _area;

  AppState(this._core, this.session) {
    _selected = _core.clock.today();
    _core.db.changes.addListener(_onDbChanged);
    WidgetsBinding.instance.addObserver(this);
  }

  MorphCore get core => _core;
  Db get db => _core.db;
  AppSettings get settings => db.settings;
  Locale get locale => Locale(settings.language);
  String get lang => settings.language;

  Day get today => _core.clock.today();

  /// Der Tag, den Übersicht, Ernährung, Gewicht und Symptome anzeigen.
  Day get selectedDay => _selected;

  bool get isToday => _selected == today;

  void selectDay(Day d) {
    if (d == _selected) return;
    _selected = d;
    _followsToday = d == today;
    notifyListeners();
  }

  /// Der geöffnete Bereich der Hauptnavigation (null = Übersicht).
  Area? get currentArea => _area;

  void openArea(Area? a) {
    if (a == _area) return;
    _area = a;
    notifyListeners();
  }

  void goToday() => selectDay(today);

  void shiftDay(int delta) => selectDay(_selected.addDays(delta));

  void _onDbChanged() => notifyListeners();

  /// Nach dem Zurückkehren in die App: Wer "heute" betrachtet hat, bleibt bei
  /// "heute", auch wenn inzwischen ein neuer Tag begonnen hat.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && _followsToday && _selected != today) {
      _selected = today;
      notifyListeners();
    }
  }

  /// Ersetzt den Kern (nach "Alles löschen" oder einer Wiederherstellung mit
  /// neuem Speicher).
  void swapCore(MorphCore next) {
    _core.db.changes.removeListener(_onDbChanged);
    _core = next;
    _core.db.changes.addListener(_onDbChanged);
    _selected = today;
    _followsToday = true;
    notifyListeners();
  }

  /// Löscht alle lokalen Daten und erneuert den Schlüssel.
  Future<void> wipeAll() async {
    final next = await session.wipeAndReopen(_core);
    swapCore(next);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _core.db.changes.removeListener(_onDbChanged);
    super.dispose();
  }
}

/// Stellt [AppState] im Widget-Baum bereit und baut bei Änderungen neu.
class AppScope extends InheritedNotifier<AppState> {
  const AppScope({super.key, required AppState state, required super.child}) : super(notifier: state);

  static AppState of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope fehlt im Widget-Baum');
    return scope!.notifier!;
  }

  /// Wie [of], ohne bei Änderungen neu zu bauen (für Handler).
  static AppState read(BuildContext context) {
    final scope = context.getInheritedWidgetOfExactType<AppScope>();
    assert(scope != null, 'AppScope fehlt im Widget-Baum');
    return scope!.notifier!;
  }
}
