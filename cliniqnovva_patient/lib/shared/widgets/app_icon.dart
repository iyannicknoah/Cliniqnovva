import 'package:flutter/widgets.dart';
import 'package:heroicons/heroicons.dart';

import '../../core/theme/app_icons.dart';

/// Renders an [IconRef] — a Migambi font glyph or a Heroicon, whichever
/// the ref carries (see app_icons.dart's 2026-08-13 note: Migambi
/// everywhere except the bottom nav, which stays Heroicons). Drop-in
/// replacement for the Material [Icon] widget — never use [Icon]/
/// `Icons.*` directly in a screen.
class AppIcon extends StatelessWidget {
  const AppIcon(this.ref, {super.key, this.size, this.color, this.style = HeroIconStyle.solid});

  final IconRef ref;
  final double? size;
  final Color? color;

  /// Heroicon-only — ignored for a Migambi glyph (that font has one weight).
  /// Defaults to solid (every existing Heroicon call site is unaffected);
  /// pass [HeroIconStyle.mini] for a small, denser rendering (e.g. the
  /// bottom nav's Home tab).
  final HeroIconStyle style;

  @override
  Widget build(BuildContext context) {
    final font = ref.font;
    if (font != null) {
      return Icon(font, size: size, color: color);
    }
    return HeroIcon(ref.hero!, style: style, size: size, color: color);
  }
}
