// InheritedWidgets: Zugriff auf Repository, OFF-Client und Texte im UI-Baum.
library;

import 'package:flutter/widgets.dart';

import '../data/repository.dart';
import '../food/off_client.dart';
import '../l10n/app_strings.dart';
import '../model/document.dart';

/// Leitet Repository-Benachrichtigungen als [Listenable] weiter, damit
/// einzelne Screens gezielt neu bauen können (ListenableBuilder).
class RepoListenable extends ChangeNotifier {
  final MorphRepository repo;
  RepoListenable(this.repo) {
    repo.addListener(notifyListeners);
  }
  @override
  void dispose() {
    repo.removeListener(notifyListeners);
    super.dispose();
  }
}

/// Stellt Repository, OFF-Client und App-Info im Widget-Baum bereit.
class MorphScope extends InheritedWidget {
  final MorphRepository repo;
  final RepoListenable listenable;
  final OffClient off;
  final AppInfo appInfo;

  const MorphScope({
    super.key,
    required this.repo,
    required this.listenable,
    required this.off,
    required this.appInfo,
    required super.child,
  });

  static MorphScope of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MorphScope>()!;

  static MorphRepository repoOf(BuildContext context) => of(context).repo;

  static Listenable listenableOf(BuildContext context) => of(context).listenable;

  static OffClient offOf(BuildContext context) => of(context).off;

  static AppInfo appInfoOf(BuildContext context) => of(context).appInfo;

  @override
  bool updateShouldNotify(MorphScope oldWidget) => false;
}

/// Stellt die lokalisierten Texte bereit.
class StringsScope extends InheritedWidget {
  final AppStrings strings;

  const StringsScope({super.key, required this.strings, required super.child});

  static AppStrings of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<StringsScope>()!.strings;

  @override
  bool updateShouldNotify(StringsScope oldWidget) =>
      strings.lang != oldWidget.strings.lang;
}

/// Kurzzugriff auf die Texte.
AppStrings s(BuildContext context) => StringsScope.of(context);

/// Kurzzugriff auf das Repository.
MorphRepository repo(BuildContext context) => MorphScope.repoOf(context);
