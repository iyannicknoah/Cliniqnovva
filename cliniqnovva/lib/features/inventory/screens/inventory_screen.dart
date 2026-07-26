import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../shared/utils/async_feedback.dart';
import '../../../shared/widgets/cliniqnovva_button.dart';
import '../../../shared/widgets/cliniqnovva_table.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/widgets/row_actions_menu.dart';
import '../../../shared/widgets/segmented_tabs.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../auth/providers/access_control_provider.dart';
import '../../clinics/providers/branches_provider.dart' show showAllBranchesProvider;
import '../../departments/providers/departments_provider.dart' show activeBranchIdProvider;
import '../../departments/widgets/branch_selector.dart';
import '../models/inventory_item_model.dart';
import '../providers/inventory_provider.dart';
import '../widgets/add_edit_item_panel.dart';
import '../widgets/adjust_stock_dialog.dart';
import '../widgets/dispense_panel.dart';

/// Part 13 — /inventory. Stock CRUD, the dispense flow, and the stock
/// adjustment log, one tabbed screen (Pharmacist role, with admin parity).
class InventoryScreen extends ConsumerStatefulWidget {
  const InventoryScreen({super.key});

  @override
  ConsumerState<InventoryScreen> createState() => _InventoryScreenState();
}

class _InventoryScreenState extends ConsumerState<InventoryScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
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
          final isOrgAdmin = role == AppConstants.roleClinicAdmin;
          final ownBranchId = data?['branchId'] as String?;
          final effectiveBranchId = isOrgAdmin
              ? ref.watch(activeBranchIdProvider)
              : ownBranchId;
          final isAllBranches = isOrgAdmin && ref.watch(showAllBranchesProvider);

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
                        'Inventory',
                        style: TextStyle(
                          color: context.appText,
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    if (isOrgAdmin) const BranchSelector(),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: 420,
                  child: SegmentedTabs(
                    labels: const ['Stock', 'Dispense', 'Log'],
                    index: _tab,
                    onChanged: (i) => setState(() => _tab = i),
                  ),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: effectiveBranchId == null && !isAllBranches
                      ? const NoBranchSelectedState()
                      : switch (_tab) {
                          0 => _StockTab(
                            branchId: isAllBranches ? null : effectiveBranchId,
                          ),
                          1 => effectiveBranchId == null
                              ? const NoBranchSelectedState()
                              : DispensePanel(branchId: effectiveBranchId),
                          _ => _LogTab(
                            branchId: isAllBranches ? null : effectiveBranchId,
                          ),
                        },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _StockTab extends ConsumerWidget {
  const _StockTab({required this.branchId});

  /// Null means "All branches" — the list shows every branch's stock
  /// combined, but adding a new item still needs one specific branch, so
  /// "+ Add Item" is disabled until the admin picks one.
  final String? branchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsAsync = ref.watch(inventoryListProvider(branchId));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Align(
          alignment: Alignment.centerRight,
          child: SizedBox(
            width: 140,
            child: CliniqnovvaButton(
              label: '+ Add Item',
              onPressed: branchId == null
                  ? null
                  : () => showInventoryItemPanel(context, branchId: branchId!),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Expanded(
          child: itemsAsync.when(
            loading: () => const LoadingWidget(),
            error: (e, _) => Center(
              child: Text('$e', style: TextStyle(color: context.appSubtext)),
            ),
            data: (items) => Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const CliniqnovvaTableHeader(
                  columns: ['Item', 'Category', 'Stock', 'Expiry', 'Status', 'Actions'],
                ),
                Expanded(
                  child: items.isEmpty
                      ? Center(
                          child: Text(
                            'No items yet.',
                            style: TextStyle(color: context.appSubtext),
                          ),
                        )
                      : ListView(
                          children: items
                              .map((item) => _ItemRow(item: item))
                              .toList(),
                        ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ItemRow extends ConsumerWidget {
  const _ItemRow({required this.item});

  final InventoryItemModel item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return CliniqnovvaTableRow(
      cells: [
        Text(
          item.name,
          style: TextStyle(color: context.appText, fontWeight: FontWeight.w500),
        ),
        Text(item.category ?? '—', style: TextStyle(color: context.appText)),
        Text(
          '${item.quantity} ${item.unit}',
          style: TextStyle(
            color: item.needsReorder ? AppColors.pillAmberText : context.appText,
            fontWeight: item.needsReorder ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        Text(
          item.expiryDate ?? '—',
          style: TextStyle(
            color: item.isExpired ? AppColors.brightRed : context.appText,
          ),
        ),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            StatusBadge(
              text: item.isActive ? 'Active' : 'Inactive',
              type: item.isActive ? BadgeType.success : BadgeType.error,
            ),
            if (item.needsReorder)
              const StatusBadge(text: 'Low stock', type: BadgeType.warning),
            if (item.isExpired)
              const StatusBadge(text: 'Expired', type: BadgeType.error),
          ],
        ),
        RowActionsMenu(
          actions: [
            RowAction(
              label: 'Edit',
              onTap: () => showInventoryItemPanel(
                context,
                branchId: item.branchId,
                item: item,
              ),
            ),
            RowAction(
              label: 'Adjust',
              onTap: () => showAdjustStockDialog(context, item: item),
            ),
            RowAction(
              label: item.isActive ? 'Deactivate' : 'Activate',
              onTap: () async {
                try {
                  await runWithFeedback(
                    context,
                    () => ref
                        .read(inventoryNotifierProvider.notifier)
                        .setActive(item.id, !item.isActive),
                    loadingMessage: item.isActive
                        ? 'Deactivating…'
                        : 'Activating…',
                    successMessage: item.isActive
                        ? 'Item deactivated.'
                        : 'Item activated.',
                  );
                } catch (_) {
                  // runWithFeedback already surfaced the error.
                }
              },
            ),
          ],
        ),
      ],
    );
  }
}

class _LogTab extends ConsumerWidget {
  const _LogTab({required this.branchId});

  final String? branchId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logAsync = ref.watch(
      inventoryAdjustmentsProvider((branchId: branchId, itemId: null)),
    );

    return logAsync.when(
      loading: () => const LoadingWidget(),
      error: (e, _) => Center(
        child: Text('$e', style: TextStyle(color: context.appSubtext)),
      ),
      data: (entries) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CliniqnovvaTableHeader(
            columns: ['Item', 'Change', 'New Qty', 'Type', 'Reason', 'When'],
          ),
          Expanded(
            child: entries.isEmpty
                ? Center(
                    child: Text(
                      'No stock changes yet.',
                      style: TextStyle(color: context.appSubtext),
                    ),
                  )
                : ListView(
                    children: entries
                        .map(
                          (entry) => CliniqnovvaTableRow(
                            cells: [
                              _ItemNameCell(itemId: entry.itemId),
                              Text(
                                entry.quantityChange > 0
                                    ? '+${entry.quantityChange}'
                                    : '${entry.quantityChange}',
                                style: TextStyle(
                                  color: entry.quantityChange >= 0
                                      ? AppColors.brightGreen
                                      : AppColors.brightRed,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                entry.quantityAfter.toString(),
                                style: TextStyle(color: context.appText),
                              ),
                              Text(
                                entry.type,
                                style: TextStyle(color: context.appSubtext),
                              ),
                              Text(
                                entry.reason,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: context.appText),
                              ),
                              Text(
                                _formatDateTime(entry.createdAt),
                                style: TextStyle(color: context.appSubtext, fontSize: 12.5),
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

class _ItemNameCell extends ConsumerWidget {
  const _ItemNameCell({required this.itemId});

  final String itemId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemAsync = ref.watch(inventoryItemProvider(itemId));
    return itemAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => Text('—', style: TextStyle(color: context.appSubtext)),
      data: (item) => Text(
        item.name,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: context.appText, fontWeight: FontWeight.w500),
      ),
    );
  }
}

String _formatDateTime(DateTime? d) {
  if (d == null) return '—';
  final local = d.toLocal();
  final date =
      '${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}';
  final time =
      '${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
  return '$date $time';
}
