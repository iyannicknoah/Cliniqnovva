import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../shared/widgets/app_icon.dart';
import '../../../shared/widgets/cliniqnovva_button.dart';
import '../../../shared/widgets/status_badge.dart';
import '../models/staff_model.dart';

/// Staff row → tap (2026-07-26, explicit user instruction) opens this
/// read-only details popup with Edit/Deactivate shortcuts, same
/// `showGeneralDialog` fade+scale shell as [showStaffPanel]. Row's "..."
/// menu (`RowActionsMenu`) keeps working exactly as before — this is an
/// additional entry point, not a replacement.
Future<void> showStaffDetailsDialog(
  BuildContext context, {
  required StaffModel staff,
  required bool canManage,
  required VoidCallback onEdit,
  required VoidCallback onSetStatus,
}) {
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Staff details',
    barrierColor: Colors.black45,
    transitionDuration: const Duration(milliseconds: 200),
    pageBuilder: (context, animation, secondaryAnimation) => Center(
      child: _StaffDetailsDialog(
        staff: staff,
        canManage: canManage,
        onEdit: onEdit,
        onSetStatus: onSetStatus,
      ),
    ),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOut);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.96, end: 1).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _StaffDetailsDialog extends StatelessWidget {
  const _StaffDetailsDialog({
    required this.staff,
    required this.canManage,
    required this.onEdit,
    required this.onSetStatus,
  });

  final StaffModel staff;
  final bool canManage;
  final VoidCallback onEdit;
  final VoidCallback onSetStatus;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.appCard,
      borderRadius: BorderRadius.circular(AppTheme.cardRadius),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          border: Border.all(color: context.appBorder),
        ),
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      staff.name,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: context.appText,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const AppIcon(AppIcons.close),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              StatusBadge(
                text: staff.isActive ? 'Active' : 'Inactive',
                type: staff.isActive ? BadgeType.success : BadgeType.error,
              ),
              const SizedBox(height: 20),
              _DetailRow(label: 'Role', value: roleLabel(staff.role)),
              _DetailRow(
                label: 'Specialty',
                value: staff.specialty?.isNotEmpty == true
                    ? staff.specialty!
                    : '—',
              ),
              _DetailRow(
                label: 'Phone',
                value: staff.phone?.isNotEmpty == true ? staff.phone! : '—',
              ),
              _DetailRow(
                label: 'Email',
                value: staff.email?.isNotEmpty == true ? staff.email! : '—',
                isLast: true,
              ),
              if (canManage) ...[
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: CliniqnovvaButton(
                        label: 'Edit',
                        onPressed: () {
                          Navigator.of(context).pop();
                          onEdit();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CliniqnovvaButton.text(
                        label: staff.isActive ? 'Deactivate' : 'Activate',
                        isFullWidth: true,
                        color: staff.isActive
                            ? AppColors.pillRedText
                            : AppColors.pillGreenText,
                        onPressed: () {
                          Navigator.of(context).pop();
                          onSetStatus();
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.isLast = false,
  });

  final String label;
  final String value;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: TextStyle(color: context.appSubtext, fontSize: 13.5),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(color: context.appText, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
