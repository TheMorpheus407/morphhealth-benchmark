import 'package:flutter/material.dart';

import '../core/models.dart';

const Color kSeed = Color(0xFF1F6F5C);

/// Bereichsfarben. Sie ergänzen Symbole und Beschriftungen, nie allein.
Color areaColor(Area a, Brightness b) {
  final dark = b == Brightness.dark;
  return switch (a) {
    Area.nutrition => dark ? const Color(0xFF7FD3A2) : const Color(0xFF2E7D4F),
    Area.cycle => dark ? const Color(0xFFF29AB3) : const Color(0xFFB03A5B),
    Area.weight => dark ? const Color(0xFF9CBFF5) : const Color(0xFF2F62B0),
    Area.symptoms => dark ? const Color(0xFFF0B45C) : const Color(0xFF9A5B00),
  };
}

IconData areaIcon(Area a, {bool selected = false}) => switch (a) {
  Area.nutrition => selected ? Icons.restaurant : Icons.restaurant_outlined,
  Area.cycle => selected ? Icons.water_drop : Icons.water_drop_outlined,
  Area.weight => selected ? Icons.monitor_weight : Icons.monitor_weight_outlined,
  Area.symptoms => selected ? Icons.healing : Icons.healing_outlined,
};

ThemeData buildTheme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(seedColor: kSeed, brightness: brightness);
  final base = ThemeData(useMaterial3: true, colorScheme: scheme, brightness: brightness);
  return base.copyWith(
    visualDensity: VisualDensity.standard,
    scaffoldBackgroundColor: scheme.surface,
    appBarTheme: AppBarTheme(
      backgroundColor: scheme.surface,
      surfaceTintColor: Colors.transparent,
      scrolledUnderElevation: 1,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
    ),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: scheme.surfaceContainer,
      indicatorColor: scheme.secondaryContainer,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    ),
    // Die Meldung schwebt über dem Aktionsknopf und verdeckt ihn nicht.
    snackBarTheme: const SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      insetPadding: EdgeInsets.fromLTRB(16, 0, 16, 88),
    ),
    listTileTheme: const ListTileThemeData(minVerticalPadding: 8),
    chipTheme: base.chipTheme.copyWith(side: BorderSide(color: scheme.outlineVariant)),
    dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1, thickness: 1),
  );
}
