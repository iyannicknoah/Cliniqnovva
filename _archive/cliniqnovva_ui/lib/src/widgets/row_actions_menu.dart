import 'package:flutter/material.dart';

import '../theme/app_icons.dart';
import '../theme/theme_ext.dart';
import 'app_icon.dart';

/// One action inside a [RowActionsMenu] (e.g. "Edit", "Delete").
class RowAction {
  const RowAction({
    required this.label,
    required this.icon,
    required this.onTap,
    this.danger = false,
  });

  final String label;
  final IconRef icon;
  final VoidCallback onTap;

  /// Renders the action in the error color (e.g. for "Delete").
  final bool danger;
}

/// The single "⋮ menu" component for table/list rows — used wherever a row
/// needs Edit/Delete/etc. actions (patients, appointments, staff, services).
class RowActionsMenu extends StatelessWidget {
  const RowActionsMenu({super.key, required this.actions});

  final List<RowAction> actions;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      icon: AppIcon(AppIcons.moreVertRounded, color: context.appSubtext),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: (index) => actions[index].onTap(),
      itemBuilder: (context) {
        return List.generate(actions.length, (i) {
          final action = actions[i];
          final color = action.danger
              ? const Color(0xFFDC2626)
              : context.appText;
          return PopupMenuItem<int>(
            value: i,
            child: Row(
              children: [
                AppIcon(action.icon, size: 18, color: color),
                const SizedBox(width: 10),
                Text(
                  action.label,
                  style: TextStyle(color: color, fontSize: 14),
                ),
              ],
            ),
          );
        });
      },
    );
  }
}
