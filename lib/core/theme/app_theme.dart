import 'package:flutter/material.dart';

class AppTheme {
  static const _seed = Color(0xFF1565C0); // Deep Blue

  static ThemeData light() => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.light,
    ),
    cardTheme: const CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
      filled: true,
    ),
    appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
    navigationBarTheme: const NavigationBarThemeData(labelBehavior: NavigationDestinationLabelBehavior.alwaysShow),
  );

  static ThemeData dark() => ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.dark,
    ),
    cardTheme: const CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(16))),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
      filled: true,
    ),
    appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
    navigationBarTheme: const NavigationBarThemeData(labelBehavior: NavigationDestinationLabelBehavior.alwaysShow),
  );
}