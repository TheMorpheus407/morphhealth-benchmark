import 'package:flutter/material.dart';

import '../core/food/off_client.dart';
import '../core/l10n/format.dart';
import '../core/l10n/strings.dart';
import '../core/model/dataset.dart';
import '../core/model/settings.dart';
import '../core/portable/backup.dart';
import '../core/service/morphhealth_service.dart';
import '../core/util/json_reader.dart';
import '../core/util/local_date.dart';
import 'platform/platform_bridge.dart';

/// UI-wide state: the product service, the selected day and navigation.
/// Rebuilds dependents whenever data or settings change.
class AppController extends ChangeNotifier with WidgetsBindingObserver {
  AppController({
    required this.service,
    required this.platform,
    required this.messengerKey,
    required this.onResetRequested,
  }) : selectedDate = service.today,
       _lastToday = service.today {
    service.repo.addListener(_onDataChanged);
    WidgetsBinding.instance.addObserver(this);
  }

  final MorphHealthService service;
  final PlatformBridge platform;
  final GlobalKey<ScaffoldMessengerState> messengerKey;

  /// Asks the root to tear down and restart with fresh (empty) data.
  final Future<void> Function() onResetRequested;

  LocalDate selectedDate;
  LocalDate _lastToday;
  int tabIndex = 0;

  S get s => service.strings;
  Fmt get fmt => service.fmt;
  Settings get settings => service.settings;
  Dataset get data => service.data;
  LocalDate get today => service.today;

  void _onDataChanged() => notifyListeners();

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final now = service.today;
      if (now != _lastToday) {
        if (selectedDate == _lastToday) selectedDate = now;
        _lastToday = now;
        notifyListeners();
      }
    }
  }

  void selectDate(LocalDate date) {
    if (date == selectedDate) return;
    selectedDate = date;
    notifyListeners();
  }

  void goToTab(int index) {
    if (index == tabIndex) return;
    tabIndex = index;
    notifyListeners();
  }

  Future<void> updateSettings(Settings settings) => service.updateSettings(settings);

  // ---------------------------------------------------------------------
  // Messages

  void showMessage(String text, {String? actionLabel, VoidCallback? onAction}) {
    final messenger = messengerKey.currentState;
    if (messenger == null) return;
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(text),
          action: actionLabel == null || onAction == null
              ? null
              : SnackBarAction(label: actionLabel, onPressed: onAction),
        ),
      );
  }

  /// Runs [action]; failures are shown as a readable message.
  /// Returns true on success.
  Future<bool> run(Future<void> Function() action) async {
    try {
      await action();
      return true;
    } catch (e) {
      showMessage(errorMessage(e));
      return false;
    }
  }

  String errorMessage(Object error) {
    final s = this.s;
    if (error is DomainException) {
      return switch (error.code) {
        'period_overlap' => s.periodOverlap,
        'period_end_before_start' => s.periodEndBeforeStart,
        'period_too_long' => s.periodTooLong(60),
        'period_start_in_future' => s.periodStartInFuture,
        'only_latest_ongoing' => s.onlyLatestOngoing,
        'portion_needs_serving' => s.portionNeedsServing,
        'passphrase_too_short' => s.passphraseTooShort,
        'online_disabled' => s.onlineDisabled,
        _ => s.errorGeneric,
      };
    }
    if (error is FoodApiException) return s.foodApiError(error.code);
    if (error is BackupAuthenticationException) return s.restoreWrongPassphrase;
    if (error is BackupFormatException) return s.restoreInvalidFile;
    if (error is ValidationException) {
      return s.importFailed(error.errors.take(3).join('; '));
    }
    return s.errorGeneric;
  }

  @override
  void dispose() {
    service.repo.removeListener(_onDataChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}

/// Makes the [AppController] available to the widget tree.
class AppScope extends InheritedNotifier<AppController> {
  const AppScope({super.key, required AppController controller, required super.child})
    : super(notifier: controller);

  static AppController of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!.notifier!;

  static AppController read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<AppScope>()!.notifier!;
}

extension AppContext on BuildContext {
  /// The controller; the calling widget rebuilds on every change.
  AppController get app => AppScope.of(this);

  /// The controller without registering a dependency (for callbacks).
  AppController get appRead => AppScope.read(this);

  S get s => AppScope.of(this).s;
  Fmt get fmt => AppScope.of(this).fmt;
}
