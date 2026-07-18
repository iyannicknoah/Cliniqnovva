import 'package:flutter/material.dart';

/// Cliniqnovva's fixed brand palette. These exact values come from the
/// project's design system — do not change them without an explicit
/// instruction to update the design language.
abstract final class AppColors {
  /// Extracted from the reference design language's Overview chart (the
  /// primary line's translucent area-fill `Color(0x0ACFFF04)`, alpha
  /// stripped) — confirmed with the user 2026-07-18 before replacing the
  /// previous teal (#2A9D8F).
  static const Color primary = Color(0xFFCFFF04);
  static const Color deepNavy = Color(0xFF0B2545);
  static const Color backgroundTint = Color(0xFFF6FAFA);
  static const Color successGreen = Color(0xFF2ECC71);
  static const Color warningAmber = Color(0xFFF4A261);
  static const Color errorRed = Color(0xFFE63946);
  static const Color textPrimary = Color(0xFF0B2545);
  static const Color textSecondary = Color(0xFF5B6B73);
  static const Color cardBorder = Color(0xFFE1EDEC);

  // Status pills: light background + a saturated/readable text color per tone.
  static const Color pillGreenBg = Color(0xFFE8F8EF);
  static const Color pillGreenText = Color(0xFF1E8449);
  static const Color pillAmberBg = Color(0xFFFDF0E1);
  static const Color pillAmberText = Color(0xFFB9701E);
  static const Color pillRedBg = Color(0xFFFBE4E6);
  static const Color pillRedText = Color(0xFFC81E2C);
  static const Color pillTealBg = Color(0xFFE3F3F1);
  static const Color pillTealText = Color(0xFF1F6F64);

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
  static const List<Color> fallbackGradient = [Color(0xFF2A9D8F), Color(0xFF0B2545)];
}
