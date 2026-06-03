import 'package:flutter/material.dart';

class AppColors {
  static const amber = Color(0xFFF59E0B);
  static const slate950 = Color(0xFF0F172A);
  static const slate900 = Color(0xFF111827);
  static const slate800 = Color(0xFF1E293B);
  static const slate700 = Color(0xFF334155);
  static const green = Color(0xFF22C55E);
  static const red = Color(0xFFEF4444);
}

class AppTheme {
  static ThemeData dark() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.amber,
        brightness: Brightness.dark,
        primary: AppColors.amber,
        surface: AppColors.slate800,
      ),
    );
    return base.copyWith(
      scaffoldBackgroundColor: AppColors.slate950,
      textTheme: base.textTheme.apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.slate950,
        foregroundColor: Colors.white,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: AppColors.slate800,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        backgroundColor: AppColors.slate900,
        indicatorColor: Color(0x33F59E0B),
        labelTextStyle: MaterialStatePropertyAll(TextStyle(fontSize: 13)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.slate900,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  static ThemeData light() {
    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(seedColor: AppColors.amber),
    );
    return base;
  }
}
