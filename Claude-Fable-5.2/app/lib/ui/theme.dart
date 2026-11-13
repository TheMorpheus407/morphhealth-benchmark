import 'package:flutter/material.dart';

/// Colours with a meaning of their own, in addition to the Material scheme.
///
/// They mark areas of the app (period, water, …) and are always used
/// together with text, an icon or a shape, never as the only carrier of
/// information.
@immutable
class MhColors extends ThemeExtension<MhColors> {
  /// Recorded period days.
  final Color period;
  final Color onPeriod;

  /// Lighter fill for weak bleeding and for backgrounds.
  final Color periodContainer;
  final Color onPeriodContainer;
  final Color water;
  final Color caffeine;
  final Color weight;
  final Color symptom;
  final Color nutrition;

  const MhColors({
    required this.period,
    required this.onPeriod,
    required this.periodContainer,
    required this.onPeriodContainer,
    required this.water,
    required this.caffeine,
    required this.weight,
    required this.symptom,
    required this.nutrition,
  });

  static const MhColors light = MhColors(
    period: Color(0xFFA62B5B),
    onPeriod: Color(0xFFFFFFFF),
    periodContainer: Color(0xFFFFD9E3),
    onPeriodContainer: Color(0xFF3F001B),
    water: Color(0xFF1B62A6),
    caffeine: Color(0xFF7A4B2A),
    weight: Color(0xFF4F5596),
    symptom: Color(0xFF7E5700),
    nutrition: Color(0xFF2F6F62),
  );

  static const MhColors dark = MhColors(
    period: Color(0xFFFFB0C8),
    onPeriod: Color(0xFF5F1131),
    periodContainer: Color(0xFF7D2948),
    onPeriodContainer: Color(0xFFFFD9E3),
    water: Color(0xFFA2C9FF),
    caffeine: Color(0xFFEBBE9C),
    weight: Color(0xFFBEC2FF),
    symptom: Color(0xFFF7BD48),
    nutrition: Color(0xFF9BD3C3),
  );

  static MhColors of(BuildContext context) =>
      Theme.of(context).extension<MhColors>()!;

  @override
  MhColors copyWith() => this;

  @override
  MhColors lerp(ThemeExtension<MhColors>? other, double t) {
    if (other is! MhColors) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return MhColors(
      period: c(period, other.period),
      onPeriod: c(onPeriod, other.onPeriod),
      periodContainer: c(periodContainer, other.periodContainer),
      onPeriodContainer: c(onPeriodContainer, other.onPeriodContainer),
      water: c(water, other.water),
      caffeine: c(caffeine, other.caffeine),
      weight: c(weight, other.weight),
      symptom: c(symptom, other.symptom),
      nutrition: c(nutrition, other.nutrition),
    );
  }
}

/// The calm Material 3 look of MorphHealth.
ThemeData buildTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF2F6F62),
    brightness: brightness,
  );
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    brightness: brightness,
    materialTapTargetSize: MaterialTapTargetSize.padded,
    visualDensity: VisualDensity.standard,
  );
  const radius = BorderRadius.all(Radius.circular(16));
  return base.copyWith(
    extensions: [
      brightness == Brightness.dark ? MhColors.dark : MhColors.light,
    ],
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      centerTitle: false,
      backgroundColor: scheme.surface,
      scrolledUnderElevation: 2,
      titleTextStyle: base.textTheme.titleLarge?.copyWith(
        color: scheme.onSurface,
        fontWeight: FontWeight.w600,
      ),
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(
        borderRadius: radius,
        side: BorderSide(color: scheme.outlineVariant),
      ),
      clipBehavior: Clip.antiAlias,
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: const OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      helperMaxLines: 4,
      errorMaxLines: 4,
      floatingLabelBehavior: FloatingLabelBehavior.auto,
      labelStyle: TextStyle(color: scheme.onSurfaceVariant),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(minimumSize: const Size(64, 48)),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(minimumSize: const Size(64, 48)),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(minimumSize: const Size(64, 48)),
    ),
    navigationBarTheme: NavigationBarThemeData(
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      backgroundColor: scheme.surfaceContainer,
    ),
    // Fixed at the bottom edge: the action button moves up to make room, and
    // the message never lies on top of controls in the middle of the screen.
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.fixed),
    listTileTheme: const ListTileThemeData(minVerticalPadding: 10),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: scheme.primary,
      linearTrackColor: scheme.surfaceContainerHighest,
    ),
  );
}
