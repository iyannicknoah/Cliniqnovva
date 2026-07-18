import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Design-system constants shared by card-like widgets (CliniqnovvaCard,
/// MetricCard, etc.) so every card in the app looks identical.
abstract final class AppTheme {
  static const double cardRadius = 18;
  static const double buttonRadius = 10;
  static const double inputRadius = 10;
  static const double sidebarWidth = 220;
  static const double topbarHeight = 64;

  static const List<BoxShadow> cardShadow = [
    BoxShadow(color: Color(0x122A9D8F), blurRadius: 20, offset: Offset(0, 2)),
  ];

  static BorderSide cardBorderSide(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BorderSide(color: isDark ? const Color(0xFF1C3640) : AppColors.cardBorder, width: 0.5);
  }

  static Color cardColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? _darkCard : Colors.white;
  }

  static const Color _darkBg = Color(0xFF071820);
  static const Color _darkCard = Color(0xFF0F2430);

  static ThemeData lightTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primaryTeal,
      brightness: Brightness.light,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme.copyWith(primary: AppColors.primaryTeal),
      scaffoldBackgroundColor: AppColors.backgroundTint,
      cardColor: Colors.white,
      primaryColor: AppColors.primaryTeal,
      textTheme: const TextTheme().apply(
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
      dividerColor: AppColors.cardBorder,
    );
  }

  static ThemeData darkTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primaryTeal,
      brightness: Brightness.dark,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme.copyWith(primary: AppColors.primaryTeal),
      scaffoldBackgroundColor: _darkBg,
      cardColor: _darkCard,
      primaryColor: AppColors.primaryTeal,
      textTheme: const TextTheme().apply(
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
      dividerColor: const Color(0xFF1C3640),
    );
  }
}
