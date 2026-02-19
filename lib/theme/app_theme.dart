import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData lightTheme(ColorSeed seedColor) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seedColor.color,
        brightness: Brightness.light,
      ),
      appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        elevation: 3,
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        indicatorColor: seedColor.color.withValues(alpha: 0.3),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }

  static ThemeData darkTheme(ColorSeed seedColor) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: seedColor.color,
        brightness: Brightness.dark,
      ),
      appBarTheme: const AppBarTheme(centerTitle: true, elevation: 0),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        elevation: 3,
      ),
      navigationBarTheme: NavigationBarThemeData(
        elevation: 0,
        indicatorColor: seedColor.color.withValues(alpha: 0.3),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
    );
  }
}

enum ColorSeed {
  deepPurple('Deep Purple', Colors.deepPurple),
  indigo('Indigo', Colors.indigo),
  teal('Teal', Colors.teal),
  green('Green', Colors.green),
  orange('Orange', Colors.orange),
  pink('Pink', Colors.pink),
  blue('Blue', Colors.blue),
  cyan('Cyan', Colors.cyan);

  final String label;
  final Color color;

  const ColorSeed(this.label, this.color);
}
