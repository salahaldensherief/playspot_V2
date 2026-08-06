import 'package:flutter/material.dart';
import 'app_colors.dart';

class AppTheme {
  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: AppColors.scaffoldBackground,
      cardColor: AppColors.cardBackground,
      dividerColor: AppColors.divider,
      colorScheme: const ColorScheme.dark(
        primary: AppColors.primary,
        secondary: AppColors.neonPurple,
        surface: AppColors.cardBackground,
        background: AppColors.scaffoldBackground,
        error: AppColors.danger,
        onPrimary: AppColors.black,
        onSecondary: AppColors.white,
        onSurface: AppColors.white,
        onBackground: AppColors.white,
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: AppColors.white),
        bodyMedium: TextStyle(color: AppColors.white),
        titleLarge: TextStyle(color: AppColors.white),
      ),
    );
  }

  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: AppColors.primary,
      scaffoldBackgroundColor: const Color(0xFFF8F9FA),
      cardColor: Colors.white,
      dividerColor: Colors.grey[300],
      colorScheme: ColorScheme.light(
        primary: AppColors.primary,
        secondary: AppColors.neonPurple,
        surface: Colors.white,
        background: const Color(0xFFF8F9FA),
        error: AppColors.danger,
        onPrimary: AppColors.white,
        onSecondary: AppColors.black,
        onSurface: AppColors.black,
        onBackground: AppColors.black,
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: Colors.black),
        bodyMedium: TextStyle(color: Colors.black),
        titleLarge: TextStyle(color: Colors.black),
      ),
    );
  }
}
