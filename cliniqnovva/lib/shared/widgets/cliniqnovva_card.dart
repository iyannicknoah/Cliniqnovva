import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../../core/theme/theme_ext.dart';

/// The single card container used everywhere — page-matching background,
/// 18px radius, border-only definition (no shadow — a translucent-lime
/// shadow used to sit here but read as a muddy haze in light mode, removed
/// 2026-07-24 in both themes). Change it here, every card in the app updates.
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
      ),
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(
              title!,
              style: TextStyle(color: context.appText, fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 14),
          ],
          child,
        ],
      ),
    );
  }
}
