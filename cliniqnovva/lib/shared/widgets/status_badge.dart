import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Semantic type for a [StatusBadge] — picks a pill color pair from
/// app_colors.dart.
enum BadgeType { success, warning, error, info }

/// The single status-pill component (appointment status, invoice status,
/// active/inactive, etc.) — radius 100px, colors from AppColors.
class StatusBadge extends StatelessWidget {
  const StatusBadge({super.key, required this.text, required this.type});

  final String text;
  final BadgeType type;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (type) {
      BadgeType.success => (AppColors.pillGreenBg, AppColors.pillGreenText),
      BadgeType.warning => (AppColors.pillAmberBg, AppColors.pillAmberText),
      BadgeType.error => (AppColors.pillRedBg, AppColors.pillRedText),
      BadgeType.info => (AppColors.pillTealBg, AppColors.pillTealText),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(100)),
      child: Text(text, style: TextStyle(color: fg, fontSize: 13, fontWeight: FontWeight.w500)),
    );
  }
}
