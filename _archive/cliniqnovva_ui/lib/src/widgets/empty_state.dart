import 'package:flutter/material.dart';

import '../theme/app_icons.dart';
import '../theme/app_spacing.dart';
import '../theme/theme_ext.dart';
import 'app_icon.dart';
import 'cliniqnovva_button.dart';

/// The single "nothing here yet" component — used whenever a list/table has
/// no data (no patients, no appointments, no departments, etc.).
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconRef icon;
  final String title;
  final String? message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppIcon(icon, size: 64, color: context.appSubtext.withValues(alpha: 0.4)),
          const SizedBox(height: AppSpacing.lg),
          Text(
            title,
            style: TextStyle(color: context.appText, fontSize: 18, fontWeight: FontWeight.w500),
          ),
          if (message != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              message!,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.appSubtext, fontSize: 15),
            ),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: AppSpacing.xxl),
            CliniqnovvaButton(
              label: actionLabel!,
              icon: AppIcons.addRounded,
              isFullWidth: false,
              onPressed: onAction,
            ),
          ],
        ],
      ),
    );
  }
}
