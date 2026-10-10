import 'package:flutter/material.dart';

class AppColors {
  const AppColors._();

  static const background = Color(0xFF232323);
  static const surface = Color(0xFF555555);
  static const surfaceLight = Color(0xFF666666);
  static const navigation = Color(0xFF3C3C3C);
  static const orange = Color(0xFFFFA000);
  static const teal = Color(0xFF08C7A2);
  static const textPrimary = Color(0xFFF6F6F6);
  static const textSecondary = Color(0xFFB6B6B6);
  static const divider = Color(0xFF626262);
}

class AppTheme {
  const AppTheme._();

  static ThemeData get dark {
    return ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.orange,
        secondary: AppColors.teal,
        surface: AppColors.surface,
        onSurface: AppColors.textPrimary,
      ),
      textTheme: const TextTheme(
        headlineSmall: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w700,
          height: 1.2,
        ),
        titleMedium: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 17,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: TextStyle(
          color: AppColors.textPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        bodyMedium: TextStyle(color: AppColors.textSecondary, fontSize: 13),
      ),
      dividerColor: AppColors.divider,
      dialogTheme: const DialogThemeData(
        backgroundColor: Color(0xFF363636),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(18)),
        ),
      ),
    );
  }
}
