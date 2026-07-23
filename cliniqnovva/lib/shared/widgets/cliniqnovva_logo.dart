import 'package:flutter/material.dart';

/// The brand logo mark: `assets/images/logo.png` (from the repo-root
/// `Logo.png` source, added 2026-07-23 — supersedes the earlier
/// `logo_dark.png`/`logo_light.png` pair). One single mark in BOTH light
/// and dark mode. Always rendered with rounded corners.
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
