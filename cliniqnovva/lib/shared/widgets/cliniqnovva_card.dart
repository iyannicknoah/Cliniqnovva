import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme.dart';

/// The single card container used everywhere — white background, 18px
/// radius, 0.5px border, soft teal-tinted shadow. Change it here, every
/// card in the app updates.
class CliniqnovvaCard extends StatelessWidget {
  const CliniqnovvaCard({
    super.key,
    required this.child,
    this.title,
    this.padding = const EdgeInsets.all(20),
  });

  final Widget child;
  final String? title;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: Border.fromBorderSide(AppTheme.cardBorderSide(context)),
        boxShadow: AppTheme.cardShadow,
      ),
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(
              title!,
              style: const TextStyle(color: AppColors.textPrimary, fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 14),
          ],
          child,
        ],
      ),
    );
  }
}
