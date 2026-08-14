import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Theme-aware color getters (copied from the HRNova reference, 2026-07-23):
/// page background and card/container background are the SAME value in
/// both themes — pure white in light, pure black in dark. Never give a card
/// a different flat color than the page it sits on; differentiate with a
/// border only (see [cardDeco]).
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

  /// A subtle neutral fill, distinct from [appBg]/[appCard] — used for
  /// interactive-state highlights (active nav item, theme-toggle track,
  /// menu-row hover) where a flat gray reads better than a colored accent.
  Color get appSecondaryBg =>
      isDark ? Colors.white.withValues(alpha: 0.08) : const Color(0xFFF3F4F6);

  /// The system "primary" color — brand blue (`AppColors.primary`), ported
  /// 2026-08-13 from the Smart Feed Rwanda reference (explicit user
  /// instruction: "copy primary color"). Fixed, NOT theme-inverted — same
  /// blue in both themes, replacing the retired black(light)/white(dark)
  /// inversion rule (2026-07-24 - 2026-08-13). Use this for anything that
  /// reaches for the app's primary/brand accent (buttons, focus borders,
  /// avatar rings, spinners, sidebar background).
  Color get appPrimary => AppColors.primary;

  BoxDecoration cardDeco([double radius = 18]) => BoxDecoration(
    color: appCard,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: appBorder, width: 1),
  );
}
