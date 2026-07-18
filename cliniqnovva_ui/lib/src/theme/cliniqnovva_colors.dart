import 'package:flutter/material.dart';

/// Colors that differ between light/dark mode. Registered into [ThemeData]
/// via `extensions: [CliniqnovvaColors.light]` (or `.dark`) and read through
/// the `context.appBg` etc. getters in `theme_ext.dart` — never read this
/// class directly from a screen/widget.
@immutable
class CliniqnovvaColors extends ThemeExtension<CliniqnovvaColors> {
  const CliniqnovvaColors({
    required this.appBg,
    required this.appText,
    required this.appSubtext,
    required this.appCard,
    required this.appBorder,
    required this.appTint,
    required this.pillGreenBg,
    required this.pillGreenText,
    required this.pillRedBg,
    required this.pillRedText,
    required this.pillAmberBg,
    required this.pillAmberText,
    required this.pillNavyBg,
    required this.pillNavyText,
    required this.pillBlueBg,
    required this.pillBlueText,
  });

  final Color appBg;
  final Color appText;
  final Color appSubtext;
  final Color appCard;
  final Color appBorder;
  final Color appTint;

  final Color pillGreenBg;
  final Color pillGreenText;
  final Color pillRedBg;
  final Color pillRedText;
  final Color pillAmberBg;
  final Color pillAmberText;
  final Color pillNavyBg;
  final Color pillNavyText;
  final Color pillBlueBg;
  final Color pillBlueText;

  static const light = CliniqnovvaColors(
    appBg: Color(0xFFF7F8FA),
    appText: Color(0xFF16181D),
    appSubtext: Color(0xFF6B7280),
    appCard: Color(0xFFFFFFFF),
    appBorder: Color(0xFFE5E7EB),
    appTint: Color(0xFFF0F2F5),
    pillGreenBg: Color(0xFFE3F6E8),
    pillGreenText: Color(0xFF16A34A),
    pillRedBg: Color(0xFFFCE7E7),
    pillRedText: Color(0xFFDC2626),
    pillAmberBg: Color(0xFFFDF0DA),
    pillAmberText: Color(0xFFB45309),
    pillNavyBg: Color(0xFFE3E9F6),
    pillNavyText: Color(0xFF1E3A5F),
    pillBlueBg: Color(0xFFE1EBFC),
    pillBlueText: Color(0xFF2563EB),
  );

  static const dark = CliniqnovvaColors(
    appBg: Color(0xFF0F1115),
    appText: Color(0xFFF1F2F4),
    appSubtext: Color(0xFF9AA1AC),
    appCard: Color(0xFF1A1D23),
    appBorder: Color(0xFF2A2E37),
    appTint: Color(0xFF20242C),
    pillGreenBg: Color(0xFF163420),
    pillGreenText: Color(0xFF4ADE80),
    pillRedBg: Color(0xFF3A1B1B),
    pillRedText: Color(0xFFF87171),
    pillAmberBg: Color(0xFF3A2C10),
    pillAmberText: Color(0xFFFBBF24),
    pillNavyBg: Color(0xFF1C2740),
    pillNavyText: Color(0xFF8FA8D6),
    pillBlueBg: Color(0xFF1B2A4A),
    pillBlueText: Color(0xFF60A5FA),
  );

  @override
  CliniqnovvaColors copyWith({
    Color? appBg,
    Color? appText,
    Color? appSubtext,
    Color? appCard,
    Color? appBorder,
    Color? appTint,
    Color? pillGreenBg,
    Color? pillGreenText,
    Color? pillRedBg,
    Color? pillRedText,
    Color? pillAmberBg,
    Color? pillAmberText,
    Color? pillNavyBg,
    Color? pillNavyText,
    Color? pillBlueBg,
    Color? pillBlueText,
  }) {
    return CliniqnovvaColors(
      appBg: appBg ?? this.appBg,
      appText: appText ?? this.appText,
      appSubtext: appSubtext ?? this.appSubtext,
      appCard: appCard ?? this.appCard,
      appBorder: appBorder ?? this.appBorder,
      appTint: appTint ?? this.appTint,
      pillGreenBg: pillGreenBg ?? this.pillGreenBg,
      pillGreenText: pillGreenText ?? this.pillGreenText,
      pillRedBg: pillRedBg ?? this.pillRedBg,
      pillRedText: pillRedText ?? this.pillRedText,
      pillAmberBg: pillAmberBg ?? this.pillAmberBg,
      pillAmberText: pillAmberText ?? this.pillAmberText,
      pillNavyBg: pillNavyBg ?? this.pillNavyBg,
      pillNavyText: pillNavyText ?? this.pillNavyText,
      pillBlueBg: pillBlueBg ?? this.pillBlueBg,
      pillBlueText: pillBlueText ?? this.pillBlueText,
    );
  }

  @override
  CliniqnovvaColors lerp(ThemeExtension<CliniqnovvaColors>? other, double t) {
    if (other is! CliniqnovvaColors) return this;
    return CliniqnovvaColors(
      appBg: Color.lerp(appBg, other.appBg, t)!,
      appText: Color.lerp(appText, other.appText, t)!,
      appSubtext: Color.lerp(appSubtext, other.appSubtext, t)!,
      appCard: Color.lerp(appCard, other.appCard, t)!,
      appBorder: Color.lerp(appBorder, other.appBorder, t)!,
      appTint: Color.lerp(appTint, other.appTint, t)!,
      pillGreenBg: Color.lerp(pillGreenBg, other.pillGreenBg, t)!,
      pillGreenText: Color.lerp(pillGreenText, other.pillGreenText, t)!,
      pillRedBg: Color.lerp(pillRedBg, other.pillRedBg, t)!,
      pillRedText: Color.lerp(pillRedText, other.pillRedText, t)!,
      pillAmberBg: Color.lerp(pillAmberBg, other.pillAmberBg, t)!,
      pillAmberText: Color.lerp(pillAmberText, other.pillAmberText, t)!,
      pillNavyBg: Color.lerp(pillNavyBg, other.pillNavyBg, t)!,
      pillNavyText: Color.lerp(pillNavyText, other.pillNavyText, t)!,
      pillBlueBg: Color.lerp(pillBlueBg, other.pillBlueBg, t)!,
      pillBlueText: Color.lerp(pillBlueText, other.pillBlueText, t)!,
    );
  }
}
