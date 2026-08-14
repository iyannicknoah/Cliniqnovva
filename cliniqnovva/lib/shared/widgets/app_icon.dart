import 'package:flutter/widgets.dart';
import 'package:heroicons/heroicons.dart';

import '../../core/theme/app_icons.dart';

/// Renders an [IconRef]. Drop-in replacement for the Material [Icon] widget
/// — never use [Icon]/`Icons.*` directly in a screen. Defaults to the solid
/// style everywhere; pass [style] to override at a specific call site (e.g.
/// the sidebar nav, 2026-08-13, explicit user instruction — outline icons
/// there only, not app-wide).
class AppIcon extends StatelessWidget {
  const AppIcon(this.ref, {super.key, this.size, this.color, this.style = HeroIconStyle.solid});

  final IconRef ref;
  final double? size;
  final Color? color;
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
