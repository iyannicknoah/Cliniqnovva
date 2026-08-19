import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../shared/utils/async_feedback.dart';
import '../../../shared/widgets/app_icon.dart';
import '../../../shared/widgets/cliniqnovva_button.dart';
import '../../../shared/widgets/cliniqnovva_table.dart';
import '../../../shared/widgets/cliniqnovva_text_field.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/widgets/row_actions_menu.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/top_bar_actions.dart';
import '../../auth/providers/access_control_provider.dart';
import '../../clinics/providers/branches_provider.dart'
    show showAllBranchesProvider;
import '../../departments/providers/departments_provider.dart';
import '../../departments/widgets/branch_selector.dart';
import '../models/staff_model.dart';
import '../providers/staff_provider.dart';
import '../widgets/add_edit_staff_panel.dart';
import '../widgets/staff_details_dialog.dart';

/// Part 8 Task 1 — /staff. Clinic Admin picks among their branches;
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
              role == AppConstants.roleClinicAdmin ||
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

class _StaffBody extends ConsumerStatefulWidget {
  const _StaffBody({
    required this.branchId,
    required this.showBranchSelector,
    required this.canManage,
  });

  final String? branchId;
  final bool showBranchSelector;
  final bool canManage;

  @override
  ConsumerState<_StaffBody> createState() => _StaffBodyState();
}

class _StaffBodyState extends ConsumerState<_StaffBody> {
  final _searchController = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _confirmSetStatus(
    BuildContext context,
    WidgetRef ref,
    StaffModel staff,
    bool activate,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(
          activate ? 'Activate staff member?' : 'Deactivate staff member?',
        ),
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
      successMessage: activate
          ? 'Staff member activated.'
          : 'Staff member deactivated.',
    );
  }

  @override
  Widget build(BuildContext context) {
    final effectiveBranchId =
        widget.branchId ?? ref.watch(activeBranchIdProvider);
    final isAllBranches =
        widget.branchId == null && ref.watch(showAllBranchesProvider);

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
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (widget.showBranchSelector) ...[
                const BranchSelector(),
                const SizedBox(width: 12),
              ],
              const TopBarActions(),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: CliniqnovvaTextField(
                  label: 'Search',
                  controller: _searchController,
                  hint: 'Name, role, specialty, or status',
                  prefixIcon: Padding(
                    padding: const EdgeInsets.all(12),
                    child: AppIcon(
                      AppIcons.search,
                      size: 18,
                      color: context.appSubtext,
                    ),
                  ),
                  onChanged: (value) => setState(() => _search = value),
                ),
              ),
              if (widget.canManage) ...[
                const SizedBox(width: 16),
                CliniqnovvaButton(
                  label: '+ Add Staff',
                  onPressed: effectiveBranchId == null
                      ? null
                      : () => showStaffPanel(
                          context,
                          branchId: effectiveBranchId,
                        ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 28),
          Expanded(
            child: effectiveBranchId == null && !isAllBranches
                ? const NoBranchSelectedState()
                : _StaffList(
                    branchId: isAllBranches ? null : effectiveBranchId,
                    canManage: widget.canManage,
                    query: _search,
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
    required this.query,
    required this.onSetStatus,
  });

  final String? branchId;
  final bool canManage;
  final String query;
  final void Function(StaffModel staff, bool activate) onSetStatus;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final staffAsync = ref.watch(staffListProvider(branchId));

    return staffAsync.when(
      loading: () => const LoadingWidget(),
      error: (e, _) => Center(
        child: Text('$e', style: TextStyle(color: context.appSubtext)),
      ),
      data: (allStaff) {
        final q = query.trim().toLowerCase();
        final staff = q.isEmpty
            ? allStaff
            : allStaff.where((member) {
                final statusLabel = member.isActive ? 'active' : 'inactive';
                return member.name.toLowerCase().contains(q) ||
                    roleLabel(member.role).toLowerCase().contains(q) ||
                    (member.specialty?.toLowerCase().contains(q) ?? false) ||
                    statusLabel.contains(q);
              }).toList();

        return Column(
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
              lastColumnEndPadding: canManage ? 50 : 0,
            ),
            Expanded(
              child: staff.isEmpty
                  ? Center(
                      child: Text(
                        q.isEmpty
                            ? 'No staff yet.'
                            : 'No staff match "$query".',
                        style: TextStyle(color: context.appSubtext),
                      ),
                    )
                  : ListView(
                      children: staff
                          .map(
                            (member) => CliniqnovvaTableRow(
                              lastColumnEndPadding: canManage ? 50 : 0,
                              onTap: () => showStaffDetailsDialog(
                                context,
                                staff: member,
                                canManage: canManage,
                                onEdit: () =>
                                    showStaffPanel(context, staff: member),
                                onSetStatus: () =>
                                    onSetStatus(member, !member.isActive),
                              ),
                              cells: [
                                Text(
                                  member.name,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: context.appText,
                                    fontWeight: FontWeight.w500,
                                  ),
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
                                  RowActionsMenu(
                                    actions: [
                                      RowAction(
                                        label: 'Edit',
                                        onTap: () => showStaffPanel(
                                          context,
                                          staff: member,
                                        ),
                                      ),
                                      RowAction(
                                        label: member.isActive
                                            ? 'Deactivate'
                                            : 'Activate',
                                        onTap: () => onSetStatus(
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
        );
      },
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
          roleLabel(role),
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
