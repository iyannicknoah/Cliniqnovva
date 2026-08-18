import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Theme-aware color getters — identical to
/// cliniqnovva/lib/core/theme/theme_ext.dart (2026-08-19 sync, explicit
/// user instruction: "make patient app and dashboard get one theme"). Page
/// background and card background are the SAME value in both themes;
/// differentiate a card from the page with a border only (see [cardDeco]).
extension AppThemeX on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  Color get appBg =>
      isDark ? AppColors.pageBackgroundDark : AppColors.pageBackground;

  Color get appCard => appBg;

  Color get appText => isDark ? Colors.white : AppColors.textPrimary;

  Color get appSubtext =>
      isDark ? const Color(0xFF8A9BBC) : AppColors.textSecondary;

  Color get appBorder =>
      isDark ? AppColors.cardBorderDark : AppColors.cardBorder;

  Color get appSecondaryBg =>
      isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFF3F4F6);

  /// The system "primary" color — brand blue (`AppColors.primary`), fixed
  /// in both themes (was black/light-mode + white/dark-mode inversion,
  /// retired 2026-08-19 to match the web dashboard's own 2026-08-13 switch
  /// to a fixed brand blue).
  Color get appPrimary => AppColors.primary;

  BoxDecoration cardDeco([double radius = 18]) => BoxDecoration(
    color: appCard,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: appBorder, width: 1),
  );
}
