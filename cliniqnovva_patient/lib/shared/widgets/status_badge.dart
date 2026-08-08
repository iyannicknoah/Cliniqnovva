import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Semantic type for a [StatusBadge] — picks a text color from
/// app_colors.dart. Identical to
/// cliniqnovva/lib/shared/widgets/status_badge.dart.
enum BadgeType { success, warning, error, info }

/// The single status-label component (appointment status, review reply
/// status, etc.) — plain colored text, no pill background.
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.text, required this.type});

  final String text;
  final BadgeType type;

  @override
  Widget build(BuildContext context) {
    final color = switch (type) {
      BadgeType.success => AppColors.brightGreen,
      BadgeType.warning => AppColors.pillAmberText,
      BadgeType.error => AppColors.brightRed,
      BadgeType.info => AppColors.pillTealText,
    };

    return Text(
      text,
      style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600),
    );
  }
}
