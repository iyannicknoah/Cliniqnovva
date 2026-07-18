import 'package:flutter/material.dart';

import '../theme/app_spacing.dart';
import '../theme/theme_ext.dart';

/// Semantic tone for a [StatusPill] — pick the meaning, not a color, so the
/// actual colors stay swappable from the theme in one place.
enum PillTone { success, error, warning, info, neutral }

/// The single "status badge" component (e.g. appointment status, invoice
/// status, staff active/inactive). Never build an ad-hoc colored Container
/// for a status label in a screen — use [StatusPill].
class StatusPill extends StatelessWidget {
  const StatusPill({super.key, required this.label, required this.tone});

  final String label;
  final PillTone tone;

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (tone) {
      PillTone.success => (context.pillGreenBg, context.pillGreenText),
      PillTone.error => (context.pillRedBg, context.pillRedText),
      PillTone.warning => (context.pillAmberBg, context.pillAmberText),
      PillTone.info => (context.pillNavyBg, context.pillNavyText),
      PillTone.neutral => (context.pillBlueBg, context.pillBlueText),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(100)),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 13, fontWeight: FontWeight.w500),
      ),
    );
  }
}
