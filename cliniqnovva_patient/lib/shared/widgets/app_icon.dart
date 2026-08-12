import 'package:flutter/widgets.dart';
import 'package:heroicons/heroicons.dart';

import '../../core/theme/app_icons.dart';

/// Renders an [IconRef]. Drop-in replacement for the Material [Icon] widget
/// — never use [Icon]/`Icons.*` directly in a screen.
class AppIcon extends StatelessWidget {
  const AppIcon(this.ref, {super.key, this.size, this.color, this.style = HeroIconStyle.solid});

  final IconRef ref;
  final double? size;
  final Color? color;

  /// Defaults to solid (every existing call site is unaffected) — pass
  /// [HeroIconStyle.mini] for a small, denser rendering (e.g. the bottom
  /// nav's Home tab).
  final HeroIconStyle style;

  @override
  Widget build(BuildContext context) {
    return HeroIcon(
      ref.hero,
      style: style,
      size: size,
      color: color,
    );
  }
}
