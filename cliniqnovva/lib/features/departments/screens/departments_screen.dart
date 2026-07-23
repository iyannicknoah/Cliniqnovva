import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../shared/utils/async_feedback.dart';
import '../../../shared/widgets/cliniqnovva_button.dart';
import '../../../shared/widgets/cliniqnovva_table.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../auth/providers/access_control_provider.dart';
import '../models/department_model.dart';
import '../providers/departments_provider.dart';
import '../widgets/add_department_dialog.dart';
import '../widgets/branch_selector.dart';

/// Part 7 Task 1 — /departments. Organization Admin picks among their
/// branches (list scoped per branch); Branch Admin only ever sees their own
/// (server-scoped, no picker shown). A department with services attached
/// can't be hard-deleted — Deactivate is offered instead.
class DepartmentsScreen extends ConsumerWidget {
  const DepartmentsScreen({super.key});

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

          return _DepartmentsBody(
            branchId: isBranchScoped ? ownBranchId : null,
            showBranchSelector: !isBranchScoped,
            canManage: canManage,
          );
        },
      ),
    );
  }
}

class _DepartmentsBody extends ConsumerWidget {
  const _DepartmentsBody({
    required this.branchId,
    required this.showBranchSelector,
    required this.canManage,
  });

  /// Fixed branch id for a branch-scoped user; null for an Organization
  /// Admin, who picks one via [activeBranchIdProvider]/[BranchSelector].
  final String? branchId;
  final bool showBranchSelector;
  final bool canManage;

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    DepartmentModel department,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete department?'),
        content: Text('This removes "${department.name}" permanently.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      await runWithFeedback(
        context,
        () => ref
            .read(departmentsNotifierProvider.notifier)
            .remove(department.id),
        loadingMessage: 'Deleting department…',
        successMessage: 'Department deleted.',
      );
    } catch (_) {
      // runWithFeedback already surfaced the server's reason in the error
      // SnackBar (e.g. services still attached).
    }
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
                  'Departments',
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
                  width: 170,
                  child: CliniqnovvaButton(
                    label: '+ Add Department',
                    onPressed: effectiveBranchId == null
                        ? null
                        : () => showDepartmentDialog(
                            context,
                            branchId: effectiveBranchId,
                          ),
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
                : _DepartmentsList(
                    branchId: effectiveBranchId,
                    canManage: canManage,
                    onDelete: (dept) => _confirmDelete(context, ref, dept),
                  ),
          ),
        ],
      ),
    );
  }
}

class _DepartmentsList extends ConsumerWidget {
  const _DepartmentsList({
    required this.branchId,
    required this.canManage,
    required this.onDelete,
  });

  final String branchId;
  final bool canManage;
  final ValueChanged<DepartmentModel> onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final departmentsAsync = ref.watch(departmentsProvider(branchId));

    return departmentsAsync.when(
      loading: () => const LoadingWidget(),
      error: (e, _) => Center(
        child: Text('$e', style: TextStyle(color: context.appSubtext)),
      ),
      data: (departments) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CliniqnovvaTableHeader(
            columns: [
              'Department',
              'Services',
              'Status',
              if (canManage) 'Actions',
            ],
          ),
          Expanded(
            child: departments.isEmpty
                ? Center(
                    child: Text(
                      'No departments yet.',
                      style: TextStyle(color: context.appSubtext),
                    ),
                  )
                : ListView(
                    children: departments
                        .map(
                          (dept) => CliniqnovvaTableRow(
                            cells: [
                              Text(
                                dept.name,
                                style: TextStyle(
                                  color: context.appText,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                '${dept.serviceCount}',
                                style: TextStyle(color: context.appText),
                              ),
                              StatusBadge(
                                text: dept.isActive ? 'Active' : 'Inactive',
                                type: dept.isActive
                                    ? BadgeType.success
                                    : BadgeType.error,
                              ),
                              if (canManage)
                                Row(
                                  children: [
                                    CliniqnovvaButton.text(
                                      label: 'Rename',
                                      color: context.appText,
                                      onPressed: () => showDepartmentDialog(
                                        context,
                                        department: dept,
                                      ),
                                    ),
                                    CliniqnovvaButton.text(
                                      label: dept.isActive
                                          ? 'Deactivate'
                                          : 'Activate',
                                      color: context.appSubtext,
                                      onPressed: () => ref
                                          .read(
                                            departmentsNotifierProvider
                                                .notifier,
                                          )
                                          .setActive(dept.id, !dept.isActive),
                                    ),
                                    if (dept.canDelete)
                                      CliniqnovvaButton.text(
                                        label: 'Delete',
                                        color: context.appSubtext,
                                        onPressed: () => onDelete(dept),
                                      )
                                    else
                                      Tooltip(
                                        message:
                                            'Has services attached — deactivate instead.',
                                        child: Text(
                                          'Has services',
                                          style: TextStyle(
                                            color: context.appSubtext,
                                            fontSize: 12,
                                          ),
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
