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
///
/// [background] (2026-08-14, explicit user instruction — "make it have
/// white background again", sidebar only) wraps the mark in a fixed WHITE
/// square (not theme-aware — deliberately fixed in both light/dark, same
/// as the sidebar's own solid-blue background it sits on) with a small
/// internal inset so the white actually reads as a visible mat around the
/// mark rather than being fully covered by it.
class CliniqnovvaLogo extends StatelessWidget {
  const CliniqnovvaLogo({
    super.key,
    this.size = 24,
    this.radius = 8,
    this.background = false,
  });

  final double size;
  final double radius;
  final bool background;

  @override
  Widget build(BuildContext context) {
    final image = Image.asset(
      'assets/images/logo.png',
      fit: background ? BoxFit.contain : BoxFit.cover,
    );
    return Container(
      width: size,
      height: size,
      padding: background ? EdgeInsets.all(size * 0.12) : EdgeInsets.zero,
      decoration: BoxDecoration(
        color: background ? Colors.white : null,
        borderRadius: BorderRadius.circular(radius),
      ),
      clipBehavior: Clip.antiAlias,
      child: image,
    );
  }
}
