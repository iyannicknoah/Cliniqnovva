import 'package:flutter/material.dart';

/// The brand logo mark, theme-aware by design (explicit instruction,
/// 2026-07-20): light mode shows the favappIcon-derived mark
/// (`logo_light.png`), dark mode shows the black-background mark
/// (`logo_dark.png`). Always rendered with rounded corners.
///
/// Use this everywhere the logo appears — never `Image.asset` a logo
/// file directly, so a future asset swap stays a one-file change.
class CliniqnovvaLogo extends StatelessWidget {
  const CliniqnovvaLogo({super.key, this.size = 30, this.radius = 10});

  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.asset(
        isDark ? 'assets/images/logo_dark.png' : 'assets/images/logo_light.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
      ),
    );
  }
}
