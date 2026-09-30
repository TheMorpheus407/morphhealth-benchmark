import 'package:flutter/material.dart';

import '../core/model/enums.dart';

/// Additional semantic colors of MorphHealth (contrast-checked against the
/// surfaces they are used on).
@immutable
class AppColors extends ThemeExtension<AppColors> {
  const AppColors({
    required this.nutrition,
    required this.cycle,
    required this.weight,
    required this.symptoms,
    required this.water,
    required this.period,
    required this.onPeriod,
    required this.window,
    required this.onWindow,
  });

  final Color nutrition;
  final Color cycle;
  final Color weight;
  final Color symptoms;
  final Color water;

  /// Fill of recorded period days and text on it.
  final Color period;
  final Color onPeriod;

  /// Background of the likely-start window and text on it.
  final Color window;
  final Color onWindow;

  static const light = AppColors(
    nutrition: Color(0xFF2E7650),
    cycle: Color(0xFFA8385A),
    weight: Color(0xFF355F9E),
    symptoms: Color(0xFF7A4B9A),
    water: Color(0xFF1F6E9E),
    period: Color(0xFFA8385A),
    onPeriod: Color(0xFFFFFFFF),
    window: Color(0xFFF8DDE5),
    onWindow: Color(0xFF3B0A1B),
  );

  static const dark = AppColors(
    nutrition: Color(0xFF86D5A9),
    cycle: Color(0xFFF3A9BF),
    weight: Color(0xFFA7C3F2),
    symptoms: Color(0xFFD7B6F0),
    water: Color(0xFF8FCBF0),
    period: Color(0xFFF3A9BF),
    onPeriod: Color(0xFF3B0A1B),
    window: Color(0xFF512234),
    onWindow: Color(0xFFFFD9E2),
  );

  Color area(Area a) => switch (a) {
    Area.nutrition => nutrition,
    Area.cycle => cycle,
    Area.weight => weight,
    Area.symptoms => symptoms,
  };

  @override
  AppColors copyWith() => this;

  @override
  AppColors lerp(ThemeExtension<AppColors>? other, double t) =>
      t < 0.5 ? this : (other as AppColors? ?? this);
}

const Color seedColor = Color(0xFF2F6F64);

ThemeData buildTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(seedColor: seedColor, brightness: brightness);
  final base = ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    visualDensity: VisualDensity.standard,
  );
  return base.copyWith(
    extensions: [brightness == Brightness.light ? AppColors.light : AppColors.dark],
    scaffoldBackgroundColor: scheme.surface,
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      clipBehavior: Clip.antiAlias,
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(),
      isDense: false,
    ),
    listTileTheme: const ListTileThemeData(contentPadding: EdgeInsets.symmetric(horizontal: 16)),
    snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      centerTitle: false,
    ),
  );
}

extension AppThemeContext on BuildContext {
  AppColors get colors => Theme.of(this).extension<AppColors>()!;
  ColorScheme get scheme => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;
}

IconData areaIcon(Area area) => switch (area) {
  Area.nutrition => Icons.restaurant_outlined,
  Area.cycle => Icons.water_drop_outlined,
  Area.weight => Icons.monitor_weight_outlined,
  Area.symptoms => Icons.healing_outlined,
};

IconData mealIcon(Meal meal) => switch (meal) {
  Meal.breakfast => Icons.free_breakfast_outlined,
  Meal.lunch => Icons.lunch_dining_outlined,
  Meal.dinner => Icons.dinner_dining_outlined,
  Meal.snack => Icons.cookie_outlined,
};
