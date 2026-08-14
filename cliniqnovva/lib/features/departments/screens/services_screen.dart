import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../shared/utils/async_feedback.dart';
import '../../../shared/widgets/cliniqnovva_button.dart';
import '../../../shared/widgets/cliniqnovva_table.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/widgets/row_actions_menu.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/top_bar_actions.dart';
import '../../auth/providers/access_control_provider.dart';
import '../../clinics/providers/branches_provider.dart' show showAllBranchesProvider;
import '../models/department_model.dart';
import '../models/service_model.dart';
import '../providers/departments_provider.dart';
import '../providers/services_provider.dart';
import '../widgets/add_edit_service_panel.dart';
import '../widgets/branch_selector.dart';

/// Part 7 Task 2 — /services. Table: name, department, default
/// duration/price, status, actions. "+ Add Service" opens a right-edge
/// slide-out panel. A service with appointment/invoice history can't be
/// hard-deleted — Deactivate is offered instead.
class ServicesScreen extends ConsumerWidget {
  const ServicesScreen({super.key});

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

          return _ServicesBody(
            branchId: isBranchScoped ? ownBranchId : null,
            showBranchSelector: !isBranchScoped,
            canManage: canManage,
          );
        },
      ),
    );
  }
}

class _ServicesBody extends ConsumerWidget {
  const _ServicesBody({
    required this.branchId,
    required this.showBranchSelector,
    required this.canManage,
  });

  final String? branchId;
  final bool showBranchSelector;
  final bool canManage;

  Future<void> _confirmDelete(
    BuildContext context,
    WidgetRef ref,
    ServiceModel service,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Delete service?'),
        content: Text('This removes "${service.name}" permanently.'),
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
        () => ref.read(servicesNotifierProvider.notifier).remove(service.id),
        loadingMessage: 'Deleting service…',
        successMessage: 'Service deleted.',
      );
    } catch (_) {
      // runWithFeedback already surfaced the server's reason in the error
      // SnackBar (e.g. appointment/invoice history).
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final effectiveBranchId = branchId ?? ref.watch(activeBranchIdProvider);
    final isAllBranches = branchId == null && ref.watch(showAllBranchesProvider);

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
                  'Service Catalog',
                  style: TextStyle(
                    color: context.appText,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              if (showBranchSelector) ...[
                const BranchSelector(),
                const SizedBox(width: 12),
              ],
              if (canManage) ...[
                SizedBox(
                  width: 150,
                  child: CliniqnovvaButton(
                    label: '+ Add Service',
                    onPressed: effectiveBranchId == null
                        ? null
                        : () => showServicePanel(
                            context,
                            branchId: effectiveBranchId,
                          ),
                  ),
                ),
                const SizedBox(width: 12),
              ],
              const TopBarActions(),
            ],
          ),
          const SizedBox(height: 28),
          Expanded(
            child: effectiveBranchId == null && !isAllBranches
                ? const NoBranchSelectedState()
                : _ServicesList(
                    branchId: isAllBranches ? null : effectiveBranchId,
                    canManage: canManage,
                    onDelete: (service) =>
                        _confirmDelete(context, ref, service),
                  ),
          ),
        ],
      ),
    );
  }
}

class _ServicesList extends ConsumerWidget {
  const _ServicesList({
    required this.branchId,
    required this.canManage,
    required this.onDelete,
  });

  final String? branchId;
  final bool canManage;
  final ValueChanged<ServiceModel> onDelete;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final servicesAsync = ref.watch(servicesProvider(branchId));
    final departmentsAsync = ref.watch(departmentsProvider(branchId));

    return servicesAsync.when(
      loading: () => const LoadingWidget(),
      error: (e, _) => Center(
        child: Text('$e', style: TextStyle(color: context.appSubtext)),
      ),
      data: (services) {
        final departmentNames = <String, String>{
          for (final DepartmentModel d in departmentsAsync.valueOrNull ?? [])
            d.id: d.name,
        };

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CliniqnovvaTableHeader(
              columns: [
                'Service',
                'Department',
                'Duration',
                'Price (RWF)',
                'Status',
                if (canManage) 'Actions',
              ],
              lastColumnEndPadding: canManage ? 50 : 0,
            ),
            Expanded(
              child: services.isEmpty
                  ? Center(
                      child: Text(
                        'No services yet.',
                        style: TextStyle(color: context.appSubtext),
                      ),
                    )
                  : ListView(
                      children: services
                          .map(
                            (service) => CliniqnovvaTableRow(
                              lastColumnEndPadding: canManage ? 50 : 0,
                              cells: [
                                Text(
                                  service.name,
                                  style: TextStyle(
                                    color: context.appText,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                                Text(
                                  departmentNames[service.departmentId] ?? '—',
                                  style: TextStyle(color: context.appText),
                                ),
                                Text(
                                  '${service.defaultDurationMins} mins',
                                  style: TextStyle(color: context.appText),
                                ),
                                Text(
                                  service.defaultPriceRwf.toString(),
                                  style: TextStyle(color: context.appText),
                                ),
                                StatusBadge(
                                  text: service.isActive
                                      ? 'Active'
                                      : 'Inactive',
                                  type: service.isActive
                                      ? BadgeType.success
                                      : BadgeType.error,
                                ),
                                if (canManage)
                                  RowActionsMenu(
                                    actions: [
                                      RowAction(
                                        label: 'Edit',
                                        onTap: () => showServicePanel(
                                          context,
                                          branchId: service.branchId,
                                          service: service,
                                        ),
                                      ),
                                      RowAction(
                                        label: service.isActive
                                            ? 'Deactivate'
                                            : 'Activate',
                                        onTap: () => ref
                                            .read(
                                              servicesNotifierProvider
                                                  .notifier,
                                            )
                                            .setActive(
                                              service.id,
                                              !service.isActive,
                                            ),
                                      ),
                                      if (service.canDelete)
                                        RowAction(
                                          label: 'Delete',
                                          isDestructive: true,
                                          onTap: () => onDelete(service),
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
