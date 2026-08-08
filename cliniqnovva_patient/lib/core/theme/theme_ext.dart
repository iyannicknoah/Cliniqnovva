import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Theme-aware color getters — identical to
/// cliniqnovva/lib/core/theme/theme_ext.dart. Page background and card
/// background are the SAME value in both themes; differentiate a card from
/// the page with a border only (see [cardDeco]).
extension AppThemeX on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  Color get appBg =>
      isDark ? AppColors.pageBackgroundDark : AppColors.pageBackground;

  Color get appCard => appBg;

  Color get appText => isDark ? Colors.white : AppColors.textPrimary;

  Color get appSubtext =>
      isDark ? const Color(0xFF8A9BBC) : AppColors.textSecondary;

  Color get appBorder =>
      isDark ? const Color(0xFF2A2A2A) : AppColors.cardBorder;

  Color get appSecondaryBg =>
      isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFF3F4F6);

  /// The system "primary" color: black in light mode, white in dark mode.
  Color get appPrimary => isDark ? Colors.white : Colors.black;

  BoxDecoration cardDeco([double radius = 18]) => BoxDecoration(
    color: appCard,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: appBorder, width: 1),
  );
}
