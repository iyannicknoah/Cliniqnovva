import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Design-system constants shared by card-like widgets (CliniqnovvaCard,
/// MetricCard, etc.) so every card in the app looks identical.
abstract final class AppTheme {
  /// Primary UI font (spec: "no italic anywhere, General Sans throughout").
  /// Bundled from Fontshare (free, see assets/fonts/LICENSE.txt) —
  /// Regular/Medium/Semibold/Bold only, no italics.
  static const String fontFamily = 'General Sans';

  static const double cardRadius = 18;
  static const double buttonRadius = 30;
  static const double inputRadius = 12;
  static const double sidebarWidth = 220;
  static const double topbarHeight = 64;

  static BorderSide cardBorderSide(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BorderSide(color: isDark ? const Color(0xFF2A2A2A) : AppColors.cardBorder, width: 0.5);
  }

  // Cards use the exact same value as the page background in both themes
  // (design rule 2026-07-23, copied from HRNova) — never a separate shade.
  // Differentiate a card from the page with `cardBorderSide` only.
  static Color cardColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark ? AppColors.pageBackgroundDark : AppColors.pageBackground;
  }

  static ThemeData lightTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme.copyWith(primary: AppColors.primary),
      scaffoldBackgroundColor: AppColors.pageBackground,
      cardColor: Colors.white,
      primaryColor: AppColors.primary,
      fontFamily: fontFamily,
      textTheme: const TextTheme().apply(
        fontFamily: fontFamily,
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
      dividerColor: AppColors.cardBorder,
    );
  }

  static ThemeData darkTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.dark,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme.copyWith(primary: AppColors.primary),
      scaffoldBackgroundColor: AppColors.pageBackgroundDark,
      cardColor: AppColors.pageBackgroundDark,
      primaryColor: AppColors.primary,
      fontFamily: fontFamily,
      textTheme: const TextTheme().apply(
        fontFamily: fontFamily,
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
      dividerColor: const Color(0xFF2A2A2A),
    );
  }
}
