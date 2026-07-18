import 'package:flutter/material.dart';

import '../theme/app_icons.dart';

/// The single widget every screen uses to render an icon. Never use `Icon(
/// Icons.xxx)` directly in a screen — go through [AppIcon] with an [IconRef]
/// from [AppIcons], so icon styling/sizing defaults are consistent and
/// swappable from one place.
class AppIcon extends StatelessWidget {
  const AppIcon(this.icon, {super.key, this.color, this.size = 20});

  final IconRef icon;
  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Icon(icon, color: color, size: size);
  }
}
