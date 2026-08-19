import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../core/theme/app_icons.dart';
import '../../core/theme/theme_ext.dart';
import 'app_icon.dart';
import 'cliniqnovva_button.dart';

/// Part 17 Task 7 — "Empty states throughout, friendly + actionable". The
/// shared shape every empty list/table falls back to: an icon (so it
/// doesn't read as a loading glitch), a warm one-line message instead of a
/// flat "No X yet.", and an optional action button when there's an obvious
/// next step (e.g. "+ Add Item"). [icon]/[message] are required; [actionLabel]
/// + [onAction] are both-or-neither.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconRef icon;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppIcon(icon, size: 32, color: context.appSubtext),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(color: context.appSubtext, fontSize: 13.5, height: 1.4),
            ),
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 16),
              CliniqnovvaButton.text(label: actionLabel!, onPressed: onAction),
            ],
          ],
        ),
      ),
    );
  }
}

/// The single most-repeated empty state in the app (13+ screens, Part
/// 17's research pass found it byte-for-byte identical everywhere) — an
/// Clinic Admin hasn't picked a branch yet (or a branch-scoped role
/// has none assigned). One shared widget instead of 13 copies of the same
/// `Center(child: Text(...))`.
class NoBranchSelectedState extends StatelessWidget {
  const NoBranchSelectedState({super.key});

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: AppIcons.clinics,
      message: 'empty_pick_branch'.tr(),
    );
  }
}
