import 'package:flutter/widgets.dart';

import '../../core/theme/app_icons.dart';
import '../../core/theme/theme_ext.dart';
import 'app_icon.dart';
import 'cliniqnovva_button.dart';

/// Part 27 Task 2 — "Empty states throughout, with personality and a clear
/// next action". Mirrors cliniqnovva/lib/shared/widgets/empty_state.dart
/// byte-for-byte (same icon + warm one-liner + optional action shape) so
/// both clients read as one product. [icon]/[message] are required;
/// [actionLabel] + [onAction] are both-or-neither.
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
              SizedBox(
                width: 200,
                child: CliniqnovvaButton.text(label: actionLabel!, onPressed: onAction),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
