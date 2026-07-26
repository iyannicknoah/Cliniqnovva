import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';
import '../../core/theme/app_icons.dart';
import '../../core/theme/theme_ext.dart';
import 'app_icon.dart';

/// One entry in a [RowActionsMenu] dropdown.
class RowAction {
  const RowAction({required this.label, required this.onTap, this.isDestructive = false});

  final String label;
  final VoidCallback onTap;

  /// Renders the label in `AppColors.brightRed` (e.g. Delete, Cancel) —
  /// opt-in per action, most actions stay plain text.
  final bool isDestructive;
}

/// A single "⋯" icon per table row that opens a dropdown of [actions]
/// (2026-07-25, explicit user instruction — replaces the old row of inline
/// icon/text buttons everywhere a table has an Actions column, matching a
/// reference screenshot's Catalog-row kebab menu). Left-aligned (via
/// `Align`) so it lines up directly under the "Actions" header text instead
/// of drifting toward the middle of the `Expanded` cell — same left edge
/// whether a row has actions (the icon) or not (a "—" placeholder).
///
/// Uses `PopupMenuButton(child: …)` rather than `icon: …` on purpose: the
/// `icon` path wraps in a Material 3 `IconButton`, which ignores
/// `ThemeData.hoverColor` and always paints its own grey hover/focus
/// overlay — impossible to turn off via `Theme`. The `child` path wraps in
/// a plain `InkWell` instead, which *does* respect `Theme.of(context)`'s
/// `hoverColor`/`highlightColor`/`splashColor`, so wrapping in a
/// transparent `Theme` here actually removes the hover fill (explicit
/// instruction — "keep it white" on hover) instead of only working on the
/// dropdown's own items like the `icon` path did.
class RowActionsMenu extends StatelessWidget {
  const RowActionsMenu({super.key, required this.actions});

  final List<RowAction> actions;

  @override
  Widget build(BuildContext context) {
    if (actions.isEmpty) {
      return Align(
        alignment: Alignment.centerLeft,
        child: Text('—', style: TextStyle(color: context.appSubtext)),
      );
    }

    return Align(
      alignment: Alignment.centerLeft,
      child: Theme(
        data: Theme.of(context).copyWith(
          hoverColor: Colors.transparent,
          highlightColor: Colors.transparent,
          splashColor: Colors.transparent,
        ),
        child: PopupMenuButton<int>(
          tooltip: 'More actions',
          padding: EdgeInsets.zero,
          color: context.appCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
            side: BorderSide(color: context.appBorder),
          ),
          onSelected: (index) => actions[index].onTap(),
          itemBuilder: (context) => [
            for (var i = 0; i < actions.length; i++)
              PopupMenuItem<int>(
                value: i,
                child: Text(
                  actions[i].label,
                  style: TextStyle(
                    color: actions[i].isDestructive ? AppColors.brightRed : context.appText,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: AppIcon(AppIcons.moreHoriz, size: 18, color: context.appSubtext),
          ),
        ),
      ),
    );
  }
}
