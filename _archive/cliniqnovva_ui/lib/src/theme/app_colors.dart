import 'package:flutter/material.dart';

/// Semantic, theme-independent colors. These stay the same in light and dark
/// mode (e.g. "success green" is the same green either way) — colors that
/// DO change between light/dark (backgrounds, text, borders) live in
/// [CliniqnovvaColors] instead (see theme_ext.dart).
abstract final class AppColors {
  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color successGreen = Color(0xFF16A34A);
  static const Color warningAmber = Color(0xFFD97706);
  static const Color errorRed = Color(0xFFDC2626);
  static const Color infoNavy = Color(0xFF1E3A5F);

  static const List<Color> categoryPalette = [
    primaryBlue,
    successGreen,
    warningAmber,
    Color(0xFF9B59B6),
    errorRed,
    Color(0xFF00897B),
    Color(0xFF546E7A),
  ];

  /// Deterministic gradient for an avatar-initial circle, keyed off [name] so
  /// the same person always gets the same colors across the whole app.
  static List<Color> gradientForName(String name) {
    const gradients = [
      [Color(0xFF2563EB), Color(0xFF60A5FA)],
      [Color(0xFF16A34A), Color(0xFF4ADE80)],
      [Color(0xFFD97706), Color(0xFFFBBF24)],
      [Color(0xFF9B59B6), Color(0xFFC084FC)],
      [Color(0xFFDC2626), Color(0xFFF87171)],
      [Color(0xFF00897B), Color(0xFF4DB6AC)],
      [Color(0xFF546E7A), Color(0xFF90A4AE)],
    ];
    if (name.isEmpty) return gradients[0];
    final index =
        name.codeUnits.fold<int>(0, (sum, c) => sum + c) % gradients.length;
    return gradients[index];
  }
}
