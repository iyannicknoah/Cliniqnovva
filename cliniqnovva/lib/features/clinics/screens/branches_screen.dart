import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../shared/utils/async_feedback.dart';
import '../../../shared/widgets/cliniqnovva_button.dart';
import '../../../shared/widgets/cliniqnovva_table.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../auth/providers/access_control_provider.dart';
import '../models/branch_model.dart';
import '../providers/branches_provider.dart';
import '../widgets/add_edit_branch_panel.dart';

/// Part 6 Task 3 — /branches.
/// Clinic Admin: every branch of their clinic (employee count each),
/// "+ Add Branch" gated by the plan's branch limit, row tap filters the
/// dashboard to that branch. Branch Admin: their own branch only, read-only
/// except working hours.
class BranchesScreen extends ConsumerWidget {
  const BranchesScreen({super.key});

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
          if (role == AppConstants.roleBranchAdmin) {
            final branchId = data?['branchId'] as String?;
            return branchId == null
                ? Center(
                    child: Text(
                      'Your account has no branch assigned.',
                      style: TextStyle(color: context.appSubtext),
                    ),
                  )
                : _OwnBranchView(branchId: branchId);
          }
          return const _ClinicBranchesView();
        },
      ),
    );
  }
}

/// Clinic Admin: all branches, add/edit/deactivate, dashboard filter.
class _ClinicBranchesView extends ConsumerWidget {
  const _ClinicBranchesView();

  Future<void> _confirmSetStatus(
    BuildContext context,
    WidgetRef ref,
    BranchModel branch,
    bool activate,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(activate ? 'Activate branch?' : 'Deactivate branch?'),
        content: Text(
          activate
              ? '${branch.name} will start operating again.'
              : '${branch.name} will stop accepting activity. A branch with '
                    'active staff or appointments can\'t be deactivated.',
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

    try {
      await runWithFeedback(
        context,
        () => ref
            .read(branchesNotifierProvider.notifier)
            .setBranchStatus(branch.id, activate),
        loadingMessage: activate
            ? 'Activating branch…'
            : 'Deactivating branch…',
        successMessage: activate ? 'Branch activated.' : 'Branch deactivated.',
      );
    } catch (_) {
      // runWithFeedback already surfaced the server's reason (e.g. active
      // staff/appointments blocking deactivation) in the error SnackBar.
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branchesAsync = ref.watch(branchesProvider);

    return branchesAsync.when(
      loading: () => const LoadingWidget(),
      error: (e, _) => Center(
        child: Text('$e', style: TextStyle(color: context.appSubtext)),
      ),
      data: (result) {
        final branches = result.branches;
        return Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Branches',
                          style: TextStyle(
                            color: context.appText,
                            fontSize: 22,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tap a branch to filter the dashboard to it.',
                          style: TextStyle(
                            color: context.appSubtext,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 150,
                    child: CliniqnovvaButton(
                      label: '+ Add Branch',
                      onPressed: result.limitReached
                          ? null
                          : () => showBranchPanel(context),
                    ),
                  ),
                ],
              ),
              if (result.limitReached) ...[
                const SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    "You've reached your plan's branch limit. "
                    'Contact support to upgrade.',
                    style: TextStyle(color: context.appSubtext, fontSize: 13),
                  ),
                ),
              ],
              const SizedBox(height: 28),
              const CliniqnovvaTableHeader(
                columns: [
                  'Branch',
                  'Location',
                  'Employees',
                  'Working hours',
                  'Status',
                  'Actions',
                ],
              ),
              Expanded(
                child: branches.isEmpty
                    ? Center(
                        child: Text(
                          'No branches yet.',
                          style: TextStyle(color: context.appSubtext),
                        ),
                      )
                    : ListView(
                        children: branches
                            .map(
                              (branch) => CliniqnovvaTableRow(
                                onTap: () {
                                  // Part 6 Task 3: click a branch → the
                                  // dashboard shows that branch's data only.
                                  ref
                                          .read(
                                            selectedBranchProvider.notifier,
                                          )
                                          .state =
                                      branch;
                                  context.go('/dashboard');
                                },
                                cells: [
                                  Text(
                                    branch.name,
                                    style: TextStyle(
                                      color: context.appText,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  Text(
                                    branch.location?.label.isNotEmpty == true
                                        ? branch.location!.label
                                        : '—',
                                    style: TextStyle(color: context.appText),
                                  ),
                                  Text(
                                    '${branch.employeeCount ?? 0}',
                                    style: TextStyle(color: context.appText),
                                  ),
                                  Text(
                                    branch.workingHours?.label ?? '—',
                                    style: TextStyle(color: context.appText),
                                  ),
                                  StatusBadge(
                                    text: branch.isActive
                                        ? 'Active'
                                        : 'Inactive',
                                    type: branch.isActive
                                        ? BadgeType.success
                                        : BadgeType.error,
                                  ),
                                  Row(
                                    children: [
                                      CliniqnovvaButton.text(
                                        label: 'Edit',
                                        color: context.appText,
                                        onPressed: () => showBranchPanel(
                                          context,
                                          branch: branch,
                                        ),
                                      ),
                                      CliniqnovvaButton.text(
                                        label: branch.isActive
                                            ? 'Deactivate'
                                            : 'Activate',
                                        color: context.appSubtext,
                                        onPressed: () => _confirmSetStatus(
                                          context,
                                          ref,
                                          branch,
                                          !branch.isActive,
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
      },
    );
  }
}

/// Branch Admin: a read-only card of their own branch — working hours are
/// the one thing they can change.
class _OwnBranchView extends ConsumerWidget {
  const _OwnBranchView({required this.branchId});

  final String branchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branchAsync = ref.watch(branchDetailProvider(branchId));

    return branchAsync.when(
      loading: () => const LoadingWidget(),
      error: (e, _) => Center(
        child: Text('$e', style: TextStyle(color: context.appSubtext)),
      ),
      data: (branch) => Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'My Branch',
                  style: TextStyle(
                    color: context.appText,
                    fontSize: 22,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(20),
                  decoration: context.cardDeco(),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              branch.name,
                              style: TextStyle(
                                color: context.appText,
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          StatusBadge(
                            text: branch.isActive ? 'Active' : 'Inactive',
                            type: branch.isActive
                                ? BadgeType.success
                                : BadgeType.error,
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      _InfoRow(
                        label: 'Location',
                        value: branch.location?.label.isNotEmpty == true
                            ? branch.location!.label
                            : '—',
                      ),
                      _InfoRow(label: 'Phone', value: branch.phone ?? '—'),
                      _InfoRow(
                        label: 'Working hours',
                        value: branch.workingHours?.label ?? '—',
                      ),
                      _InfoRow(
                        label: 'Umuganda Saturdays',
                        value: branch.umugandaSaturdayHours?.label ??
                            'Normal hours',
                        isLast: true,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: 200,
                  child: CliniqnovvaButton(
                    label: 'Edit working hours',
                    onPressed: () =>
                        showBranchPanel(context, branch: branch, hoursOnly: true),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.isLast = false});

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
            width: 160,
            child: Text(
              label,
              style: TextStyle(color: context.appSubtext, fontSize: 13.5),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: context.appText,
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
