import 'package:flutter/material.dart';

/// Cliniqnovva's fixed brand palette. These exact values come from the
/// project's design system — do not change them without an explicit
/// instruction to update the design language.
abstract final class AppColors {
  /// Page/scaffold background, input fill, and container backgrounds across
  /// the whole app — pure white per explicit instruction (2026-07-19).
  static const Color pageBackground = Color(0xFFFFFFFF);

  /// The dark-mode equivalent of [pageBackground] — near-black navy, ported
  /// 2026-08-13 from the Smart Feed Rwanda reference's `--color-background`
  /// dark value (was pure black `#000000`, retired). Cards/containers use
  /// this SAME value, never a separate "dark card" shade — see
  /// `theme_ext.dart`'s `appCard`.
  static const Color pageBackgroundDark = Color(0xFF0D1117);

  /// System primary — brand blue, ported 2026-08-13 from the Smart Feed
  /// Rwanda reference project's `--color-primary` (explicit user
  /// instruction: "copy primary color"). Fixed, NOT theme-inverted — same
  /// exact blue in light and dark mode, replacing the retired
  /// black(light)/white(dark) inversion rule. See `context.appPrimary`.
  static const Color primary = Color(0xFF1E8CFF);

  /// Hover/pressed state for [primary] (reference `--color-primary-hover`).
  static const Color primaryHover = Color(0xFF1670CC);

  /// ~10%-opacity tint of [primary], for tinted backgrounds/selected rows
  /// (reference `--color-primary-tint`).
  static const Color primaryTint = Color(0xFFE8F3FF);

  /// Fixed white — text/icon color on top of a [primary] fill, in BOTH
  /// themes (reference `--color-primary-contrast`, never theme-inverted).
  static const Color primaryContrast = Color(0xFFFFFFFF);

  static const Color successGreen = Color(0xFF16A34A);
  static const Color warningAmber = Color(0xFFB98900);
  static const Color errorRed = Color(0xFFD92D20);
  static const Color infoBlue = Color(0xFF00A1DE);
  static const Color textPrimary = Color(0xFF14181B);
  static const Color textSecondary = Color(0xFF57636C);
  static const Color cardBorder = Color(0xFFE0E3E7);

  /// Dark-mode equivalent of [cardBorder] (reference `--color-border` dark
  /// value) — was an inline `Color(0xFF2A2A2A)` hardcoded at every call
  /// site; centralized here 2026-08-13 during the same color-token pass.
  static const Color cardBorderDark = Color(0xFF26303C);

  // Status pills: light background + a saturated/readable text color per tone.
  static const Color pillGreenBg = Color(0xFFE8F8EF);
  static const Color pillGreenText = Color(0xFF1E8449);
  static const Color pillAmberBg = Color(0xFFFDF0E1);
  static const Color pillAmberText = Color(0xFFB9701E);
  static const Color pillRedBg = Color(0xFFFBE4E6);
  static const Color pillRedText = Color(0xFFC81E2C);
  static const Color pillTealBg = Color(0xFFE3F3F1);
  static const Color pillTealText = Color(0xFF1F6F64);

  /// Bright, no-background status text (2026-07-23) — used by [StatusBadge]
  /// for success/error states (Active/Paid vs Suspended/Overdue) across the
  /// whole system: no pill fill, just vivid colored text.
  static const Color brightGreen = Color(0xFF34C759);
  static const Color brightRed = Color(0xFFFF3B30);

  /// The system's second primary color (2026-07-23), alongside the
  /// black/white `context.appPrimary`. Currently used for the Overview
  /// revenue chart's line + area fill — reach for this first before
  /// introducing any other accent color.
  static const Color skyBlue = Color(0xFF38BDF8);

  /// One unique 2-color gradient per letter A-Z, used for avatar-initial
  /// circles when a person has no photo. Look up by the first letter of a
  /// name (uppercased) — see [AvatarWidget].
  static const Map<String, List<Color>> avatarGradients = {
    'A': [Color(0xFF2A9D8F), Color(0xFF56C9B9)],
    'B': [Color(0xFF3A86FF), Color(0xFF6FB1FC)],
    'C': [Color(0xFF7B2CBF), Color(0xFFB185DB)],
    'D': [Color(0xFFE63969), Color(0xFFF48FB1)],
    'E': [Color(0xFFF4A261), Color(0xFFFBC490)],
    'F': [Color(0xFFE63946), Color(0xFFF28B82)],
    'G': [Color(0xFF2ECC71), Color(0xFF7EE8A6)],
    'H': [Color(0xFF4C51BF), Color(0xFF8B93F0)],
    'I': [Color(0xFFF2A65A), Color(0xFFFFD97D)],
    'J': [Color(0xFF118AB2), Color(0xFF6FDDD0)],
    'K': [Color(0xFFC2185B), Color(0xFFE888B8)],
    'L': [Color(0xFF0B2545), Color(0xFF4C6C9C)],
    'M': [Color(0xFF059669), Color(0xFF6EE7B7)],
    'N': [Color(0xFFFF6B35), Color(0xFFFFD166)],
    'O': [Color(0xFF7C3AED), Color(0xFFC4B5FD)],
    'P': [Color(0xFF0EA5E9), Color(0xFF67E8F9)],
    'Q': [Color(0xFFDC2626), Color(0xFFF87171)],
    'R': [Color(0xFF166534), Color(0xFF86EFAC)],
    'S': [Color(0xFF1D4ED8), Color(0xFF93C5FD)],
    'T': [Color(0xFF0D9488), Color(0xFF5EEAD4)],
    'U': [Color(0xFF9D174D), Color(0xFFF9A8D4)],
    'V': [Color(0xFF6D28D9), Color(0xFFD8B4FE)],
    'W': [Color(0xFFEA580C), Color(0xFFFDBA74)],
    'X': [Color(0xFF334155), Color(0xFF94A3B8)],
    'Y': [Color(0xFFB45309), Color(0xFFFCD34D)],
    'Z': [Color(0xFF155E63), Color(0xFF5EC9C0)],
  };

  /// Fallback gradient for a name that doesn't start with A-Z (rare).
  static const List<Color> fallbackGradient = [
    Color(0xFF2A9D8F),
    Color(0xFF0B2545),
  ];
}
