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
    this.trailing,
    this.padding = const EdgeInsets.all(20),
    this.showBorder = true,
  });

  final Widget child;
  final String? title;

  /// Optional widget on the same row as [title], right-aligned (e.g. a
  /// "View all" text link) — 2026-07-25, first used by the Dashboard's
  /// Reviews Needing Reply card. Ignored if [title] is null.
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  /// Set false to drop the border entirely, keeping the background/radius
  /// (2026-07-25, explicit user instruction — first used by the Dashboard's
  /// Today's Appointments card). Defaults true — every other card keeps its
  /// border unless it opts out.
  final bool showBorder;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor(context),
        borderRadius: BorderRadius.circular(AppTheme.cardRadius),
        border: showBorder ? Border.fromBorderSide(AppTheme.cardBorderSide(context)) : null,
      ),
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Row(
              children: [
                Expanded(
                  child: Text(
                    title!,
                    style: TextStyle(
                      color: context.appText,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
            const SizedBox(height: 14),
          ],
          child,
        ],
      ),
    );
  }
}
