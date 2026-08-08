import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Design-system constants shared by card-like widgets — same values as
/// cliniqnovva/lib/core/theme/app_theme.dart, minus the sidebar/topbar
/// constants (no sidebar on mobile — see [bottomNavHeight] instead).
abstract final class AppTheme {
  static const String fontFamily = 'General Sans';

  static const double cardRadius = 18;
  static const double buttonRadius = 30;
  static const double inputRadius = 12;

  /// Mobile bottom navigation bar height (replaces the web app's
  /// `sidebarWidth`/`topbarHeight` — see DESIGN_LANGUAGE.md's Patient App
  /// section for the sidebar -> bottom nav adaptation).
  static const double bottomNavHeight = 64;

  static BorderSide cardBorderSide(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BorderSide(
      color: isDark ? const Color(0xFF2A2A2A) : AppColors.cardBorder,
      width: 0.5,
    );
  }

  static Color cardColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? AppColors.pageBackgroundDark
        : AppColors.pageBackground;
  }

  static DatePickerThemeData _datePickerTheme({required bool isDark}) {
    final bg = isDark ? AppColors.pageBackgroundDark : AppColors.pageBackground;
    final fg = isDark ? Colors.white : Colors.black;
    final selectedBg = isDark ? Colors.white : Colors.black;
    final selectedFg = isDark ? Colors.black : Colors.white;
    final borderColor = isDark ? const Color(0xFF2A2A2A) : AppColors.cardBorder;

    Color dayColor(
      Set<WidgetState> states, {
      required Color selected,
      required Color normal,
    }) {
      if (states.contains(WidgetState.selected)) return selected;
      if (states.contains(WidgetState.disabled)) {
        return normal.withValues(alpha: 0.35);
      }
      return normal;
    }

    return DatePickerThemeData(
      backgroundColor: bg,
      surfaceTintColor: Colors.transparent,
      headerBackgroundColor: bg,
      headerForegroundColor: fg,
      weekdayStyle: TextStyle(color: fg),
      dayForegroundColor: WidgetStateProperty.resolveWith(
        (states) => dayColor(states, selected: selectedFg, normal: fg),
      ),
      dayBackgroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? selectedBg
            : Colors.transparent,
      ),
      dayOverlayColor: WidgetStateProperty.resolveWith(
        (states) =>
            states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.pressed)
            ? fg.withValues(alpha: 0.08)
            : Colors.transparent,
      ),
      todayForegroundColor: WidgetStateProperty.resolveWith(
        (states) => dayColor(states, selected: selectedFg, normal: fg),
      ),
      todayBackgroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? selectedBg
            : Colors.transparent,
      ),
      todayBorder: BorderSide(color: fg, width: 1),
      yearForegroundColor: WidgetStateProperty.resolveWith(
        (states) => dayColor(states, selected: selectedFg, normal: fg),
      ),
      yearBackgroundColor: WidgetStateProperty.resolveWith(
        (states) => states.contains(WidgetState.selected)
            ? selectedBg
            : Colors.transparent,
      ),
      dividerColor: borderColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor),
      ),
      cancelButtonStyle: TextButton.styleFrom(foregroundColor: fg),
      confirmButtonStyle: TextButton.styleFrom(foregroundColor: fg),
    );
  }

  static DialogThemeData _dialogTheme({required bool isDark}) {
    final bg = isDark ? AppColors.pageBackgroundDark : AppColors.pageBackground;
    final fg = isDark ? Colors.white : AppColors.textPrimary;
    final sub = isDark ? const Color(0xFF8A9BBC) : AppColors.textSecondary;
    final borderColor = isDark ? const Color(0xFF2A2A2A) : AppColors.cardBorder;

    return DialogThemeData(
      backgroundColor: bg,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(18),
        side: BorderSide(color: borderColor),
      ),
      titleTextStyle: TextStyle(
        color: fg,
        fontFamily: fontFamily,
        fontSize: 18,
        fontWeight: FontWeight.w600,
      ),
      contentTextStyle: TextStyle(
        color: sub,
        fontFamily: fontFamily,
        fontSize: 14,
        height: 1.4,
      ),
    );
  }

  static SnackBarThemeData _snackBarTheme({required bool isDark}) {
    final bg = isDark ? Colors.white : Colors.black;
    final fg = isDark ? Colors.black : Colors.white;

    return SnackBarThemeData(
      backgroundColor: bg,
      contentTextStyle: TextStyle(
        color: fg,
        fontFamily: fontFamily,
        fontSize: 14,
        fontWeight: FontWeight.w500,
      ),
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      actionTextColor: fg,
    );
  }

  static ThemeData lightTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: Colors.black,
      brightness: Brightness.light,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme.copyWith(primary: Colors.black),
      scaffoldBackgroundColor: AppColors.pageBackground,
      cardColor: Colors.white,
      primaryColor: Colors.black,
      fontFamily: fontFamily,
      textTheme: const TextTheme().apply(
        fontFamily: fontFamily,
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
      dividerColor: AppColors.cardBorder,
      datePickerTheme: _datePickerTheme(isDark: false),
      dialogTheme: _dialogTheme(isDark: false),
      snackBarTheme: _snackBarTheme(isDark: false),
    );
  }

  static ThemeData darkTheme() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: Colors.white,
      brightness: Brightness.dark,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme.copyWith(primary: Colors.white),
      scaffoldBackgroundColor: AppColors.pageBackgroundDark,
      cardColor: AppColors.pageBackgroundDark,
      primaryColor: Colors.white,
      fontFamily: fontFamily,
      textTheme: const TextTheme().apply(
        fontFamily: fontFamily,
        bodyColor: Colors.white,
        displayColor: Colors.white,
      ),
      dividerColor: const Color(0xFF2A2A2A),
      datePickerTheme: _datePickerTheme(isDark: true),
      dialogTheme: _dialogTheme(isDark: true),
      snackBarTheme: _snackBarTheme(isDark: true),
    );
  }
}
