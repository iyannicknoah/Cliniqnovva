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
    return BorderSide(
      color: isDark ? const Color(0xFF2A2A2A) : AppColors.cardBorder,
      width: 0.5,
    );
  }

  // Cards use the exact same value as the page background in both themes
  // (design rule 2026-07-23, copied from HRNova) — never a separate shade.
  // Differentiate a card from the page with `cardBorderSide` only.
  static Color cardColor(BuildContext context) {
    return Theme.of(context).brightness == Brightness.dark
        ? AppColors.pageBackgroundDark
        : AppColors.pageBackground;
  }

  /// `showDatePicker`'s default Material 3 styling derives its colors from
  /// `ColorScheme.fromSeed(seedColor: AppColors.primary)` — since our seed is
  /// the brand lime, that produced a beige/olive-tinted calendar completely
  /// off the app's black/white design system. Themed explicitly instead
  /// (2026-07-24): white/black background+text, black/white circle for the
  /// selected day, and a bordered (not filled) circle for today — same
  /// light/dark inversion `CliniqnovvaButton` already uses.
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
      // Today: a bordered circle, filled only if also selected.
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

  /// Every dialog (`AlertDialog`/`SimpleDialog`) in the app was inheriting
  /// ad-hoc Material defaults — no shared title/body text scale, and a beige
  /// wash from the same M3 elevation-tint issue as the date picker. Themed
  /// globally (2026-07-24) so every dialog automatically matches: page-flat
  /// background (no shadow, border only — "no mixing colors"), ONE title
  /// style and ONE content style used everywhere.
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

  /// Every write action shows a loading SnackBar while in flight and a
  /// success/error one when it finishes (`runWithFeedback`, 2026-07-23).
  /// Themed to match the black/white inversion rule every other filled
  /// surface (`CliniqnovvaButton`, selected chips) already follows: black
  /// bg/white text in light mode, white bg/black text in dark mode.
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
    // Seeded from black, not the old brand lime (retired 2026-07-24) — the
    // system "primary" is black in light mode, white in dark. This also
    // fixes every default-Material-styled control (dialog action buttons,
    // etc.) that reads `colorScheme.primary` without us touching it directly.
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
