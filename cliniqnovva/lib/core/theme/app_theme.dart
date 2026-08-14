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
  static const double sidebarWidth = 250;
  static const double topbarHeight = 64;

  static BorderSide cardBorderSide(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return BorderSide(
      color: isDark ? AppColors.cardBorderDark : AppColors.cardBorder,
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
  /// off the app's design system. Themed explicitly instead (2026-07-24):
  /// white/black background+text, a bordered (not filled) circle for today.
  /// Selected-day circle updated 2026-08-13 to the brand blue `appPrimary`
  /// (was theme-inverted black/white) — "copy primary color" instruction.
  static DatePickerThemeData _datePickerTheme({required bool isDark}) {
    final bg = isDark ? AppColors.pageBackgroundDark : AppColors.pageBackground;
    final fg = isDark ? Colors.white : Colors.black;
    final selectedBg = AppColors.primary;
    final selectedFg = AppColors.primaryContrast;
    final borderColor = isDark ? AppColors.cardBorderDark : AppColors.cardBorder;

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
      confirmButtonStyle: TextButton.styleFrom(foregroundColor: AppColors.primary),
    );
  }

  /// Every dropdown/text field builds its OWN `border`/`enabledBorder` per
  /// call site (there's ~15 of them, all copying the same subtle-border
  /// look) but none of them ever set `focusedBorder` — so once tapped/opened
  /// (a `DropdownButtonFormField` keeps focus after you pick an option, it
  /// doesn't return it), Flutter's Material 3 default took over: a thick
  /// `colorScheme.primary` (black light / white dark) ring that then stayed
  /// stuck on the field permanently. Themed globally (2026-08-13, explicit
  /// user instruction — "apply to all dropdowns in the system") so every
  /// field without its own explicit override reverts to the exact same
  /// subtle border whether idle, focused, or after a selection.
  /// `CliniqnovvaTextField`/`searchable_dropdown.dart` already set their own
  /// intentional focused-border highlight and are unaffected — an explicit
  /// per-widget `focusedBorder` always wins over this theme default.
  static InputDecorationTheme _inputDecorationTheme({required bool isDark}) {
    final borderColor = isDark ? AppColors.cardBorderDark : AppColors.cardBorder;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(inputRadius),
      borderSide: BorderSide(color: borderColor),
    );
    return InputDecorationTheme(
      border: border,
      enabledBorder: border,
      focusedBorder: border,
      disabledBorder: border,
    );
  }

  /// Every dialog (`AlertDialog`/`SimpleDialog`) in the app was inheriting
  /// ad-hoc Material defaults — no shared title/body text scale, and a beige
  /// wash from the same M3 elevation-tint issue as the date picker. Themed
  /// globally (2026-07-24) so every dialog automatically matches: page-flat
  /// background, border, ONE title style and ONE content style everywhere.
  /// A real drop shadow was added 2026-08-13 (was `elevation: 0`, "no shadow
  /// anywhere" rule) matching the Smart Feed Rwanda reference's Modal
  /// (`box-shadow: 0 12px 32px rgba(0,0,0,0.24)`) — floating/portaled
  /// surfaces (dialogs, dropdown/menu popovers) get a shadow in that
  /// reference even though flat page cards don't; `CliniqnovvaCard` is
  /// untouched, still border-only, since its own reference component has no
  /// shadow either.
  static DialogThemeData _dialogTheme({required bool isDark}) {
    final bg = isDark ? AppColors.pageBackgroundDark : AppColors.pageBackground;
    final fg = isDark ? Colors.white : AppColors.textPrimary;
    final sub = isDark ? const Color(0xFF8A9BBC) : AppColors.textSecondary;
    final borderColor = isDark ? AppColors.cardBorderDark : AppColors.cardBorder;

    return DialogThemeData(
      backgroundColor: bg,
      surfaceTintColor: Colors.transparent,
      elevation: 12,
      shadowColor: Colors.black.withValues(alpha: 0.24),
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
    // Seeded from the brand blue (2026-08-13, "copy primary color" —
    // replaces the black/white theme-inversion seed used 2026-07-24 -
    // 2026-08-13). This also fixes every default-Material-styled control
    // (dialog action buttons, etc.) that reads `colorScheme.primary`
    // without us touching it directly.
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
      inputDecorationTheme: _inputDecorationTheme(isDark: false),
      datePickerTheme: _datePickerTheme(isDark: false),
      dialogTheme: _dialogTheme(isDark: false),
      snackBarTheme: _snackBarTheme(isDark: false),
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
      dividerColor: AppColors.cardBorderDark,
      inputDecorationTheme: _inputDecorationTheme(isDark: true),
      datePickerTheme: _datePickerTheme(isDark: true),
      dialogTheme: _dialogTheme(isDark: true),
      snackBarTheme: _snackBarTheme(isDark: true),
    );
  }
}
