import 'package:flutter/material.dart';

/// The brand logo mark: `assets/images/logo.png` (from the repo-root
/// `Cliniqnovva No BG.png` source, swapped in 2026-07-26 — explicit user
/// instruction to use the transparent-background mark here specifically
/// *because* it has no background, so one asset reads correctly on both
/// pure white and pure black pages with no visible edge). One single mark
/// in BOTH light and dark mode. Always rendered with rounded corners
/// (a no-op on the transparent corners, but kept so a future opaque-bg
/// swap doesn't need a second code change).
///
/// Use this everywhere the logo appears — never `Image.asset` a logo
/// file directly, so a future asset swap stays a one-file change.
class CliniqnovvaLogo extends StatelessWidget {
  const CliniqnovvaLogo({super.key, this.size = 24, this.radius = 8});

  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.asset(
        'assets/images/logo.png',
        width: size,
        height: size,
        fit: BoxFit.cover,
      ),
    );
  }
}
