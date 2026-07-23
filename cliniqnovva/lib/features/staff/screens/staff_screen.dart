import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../shared/utils/async_feedback.dart';
import '../../../shared/widgets/avatar_widget.dart';
import '../../../shared/widgets/cliniqnovva_button.dart';
import '../../../shared/widgets/cliniqnovva_table.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../auth/providers/access_control_provider.dart';
import '../../departments/providers/departments_provider.dart';
import '../../departments/widgets/branch_selector.dart';
import '../models/staff_model.dart';
import '../providers/staff_provider.dart';
import '../widgets/add_edit_staff_panel.dart';

const _roleLabels = {
  AppConstants.roleDoctor: 'Doctor',
  AppConstants.roleNurse: 'Nurse',
  AppConstants.roleReceptionist: 'Receptionist',
  AppConstants.rolePharmacist: 'Pharmacist',
  AppConstants.roleAccountant: 'Accountant',
};

/// Part 8 Task 1 — /staff. Organization Admin picks among their branches;
/// Branch Admin is auto-scoped to their own. Staff are never hard-deleted —
/// only ever deactivated (server-enforced, no delete route even exists).
class StaffScreen extends ConsumerWidget {
  const StaffScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final claims = ref.watch(userClaimsProvider);

    return Scaffold(
      backgroundColor: context.appBg,
      body: claims.when(
        loading: () => const LoadingWidget(),
        error: (e, _) => Center(
          child: Text('$e', style: TextStyle(color: context.appSubtext)),
        ),
        data: (data) {
          final role = data?['role'] as String?;
          final isBranchScoped = role == AppConstants.roleBranchAdmin;
          final ownBranchId = data?['branchId'] as String?;
          final canManage =
              role == AppConstants.roleOrganizationAdmin ||
              role == AppConstants.roleBranchAdmin;

          return _StaffBody(
            branchId: isBranchScoped ? ownBranchId : null,
            showBranchSelector: !isBranchScoped,
            canManage: canManage,
          );
        },
      ),
    );
  }
}

class _StaffBody extends ConsumerWidget {
  const _StaffBody({
    required this.branchId,
    required this.showBranchSelector,
    required this.canManage,
  });

  final String? branchId;
  final bool showBranchSelector;
  final bool canManage;

  Future<void> _confirmSetStatus(
    BuildContext context,
    WidgetRef ref,
    StaffModel staff,
    bool activate,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(activate ? 'Activate staff member?' : 'Deactivate staff member?'),
        content: Text(
          activate
              ? '${staff.name} will be able to log in again.'
              : '${staff.name} will lose access immediately. This does not delete their record.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(activate ? 'Activate' : 'Deactivate'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    await runWithFeedback(
      context,
      () => ref
          .read(staffNotifierProvider.notifier)
          .setStatus(staff.id, activate),
      loadingMessage: activate ? 'Activating…' : 'Deactivating…',
      successMessage: activate ? 'Staff member activated.' : 'Staff member deactivated.',
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final effectiveBranchId = branchId ?? ref.watch(activeBranchIdProvider);

    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  'Staff',
                  style: TextStyle(
                    color: context.appText,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (showBranchSelector) ...[
                const BranchSelector(),
                const SizedBox(width: 12),
              ],
              if (canManage)
                SizedBox(
                  width: 150,
                  child: CliniqnovvaButton(
                    label: '+ Add Staff',
                    onPressed: effectiveBranchId == null
                        ? null
                        : () =>
                              showStaffPanel(context, branchId: effectiveBranchId),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 28),
          Expanded(
            child: effectiveBranchId == null
                ? Center(
                    child: Text(
                      'No branch to show yet.',
                      style: TextStyle(color: context.appSubtext),
                    ),
                  )
                : _StaffList(
                    branchId: effectiveBranchId,
                    canManage: canManage,
                    onSetStatus: (staff, activate) =>
                        _confirmSetStatus(context, ref, staff, activate),
                  ),
          ),
        ],
      ),
    );
  }
}

class _StaffList extends ConsumerWidget {
  const _StaffList({
    required this.branchId,
    required this.canManage,
    required this.onSetStatus,
  });

  final String branchId;
  final bool canManage;
  final void Function(StaffModel staff, bool activate) onSetStatus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staffAsync = ref.watch(staffListProvider(branchId));

    return staffAsync.when(
      loading: () => const LoadingWidget(),
      error: (e, _) => Center(
        child: Text('$e', style: TextStyle(color: context.appSubtext)),
      ),
      data: (staff) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CliniqnovvaTableHeader(
            columns: [
              'Name',
              'Role',
              'Specialty',
              'Status',
              if (canManage) 'Actions',
            ],
          ),
          Expanded(
            child: staff.isEmpty
                ? Center(
                    child: Text(
                      'No staff yet.',
                      style: TextStyle(color: context.appSubtext),
                    ),
                  )
                : ListView(
                    children: staff
                        .map(
                          (member) => CliniqnovvaTableRow(
                            cells: [
                              Row(
                                children: [
                                  AvatarWidget(firstName: member.name, size: 32),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      member.name,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: context.appText,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              _RoleBadge(role: member.role),
                              Text(
                                member.specialty ?? '—',
                                style: TextStyle(color: context.appText),
                              ),
                              StatusBadge(
                                text: member.isActive ? 'Active' : 'Inactive',
                                type: member.isActive
                                    ? BadgeType.success
                                    : BadgeType.error,
                              ),
                              if (canManage)
                                Row(
                                  children: [
                                    CliniqnovvaButton.text(
                                      label: 'Edit',
                                      color: context.appText,
                                      onPressed: () => showStaffPanel(
                                        context,
                                        staff: member,
                                      ),
                                    ),
                                    CliniqnovvaButton.text(
                                      label: member.isActive
                                          ? 'Deactivate'
                                          : 'Activate',
                                      color: context.appSubtext,
                                      onPressed: () => onSetStatus(
                                        member,
                                        !member.isActive,
                                      ),
                                    ),
                                  ],
                                ),
                            ],
                          ),
                        )
                        .toList(),
                  ),
          ),
        ],
      ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  const _RoleBadge({required this.role});

  final String role;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: context.appSecondaryBg,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(
          _roleLabels[role] ?? role,
          style: TextStyle(
            color: context.appText,
            fontSize: 12.5,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
