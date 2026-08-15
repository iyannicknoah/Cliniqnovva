import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../shared/widgets/app_select.dart';
import '../../../shared/widgets/cliniqnovva_table.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/loading_widget.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../../shared/widgets/top_bar_actions.dart';
import '../../auth/providers/access_control_provider.dart';
import '../../clinics/providers/branches_provider.dart' show showAllBranchesProvider;
import '../../departments/providers/departments_provider.dart' show activeBranchIdProvider;
import '../../departments/widgets/branch_selector.dart';
import '../../patients/providers/patients_provider.dart';
import '../providers/invoices_provider.dart';
import 'invoice_detail_screen.dart';

const _statusLabels = {
  AppConstants.invoiceUnpaid: 'Unpaid',
  AppConstants.invoicePartial: 'Partial',
  AppConstants.invoicePaid: 'Paid',
  AppConstants.invoiceVoided: 'Voided',
};

BadgeType _badgeTypeFor(String status) => switch (status) {
  AppConstants.invoicePaid => BadgeType.success,
  AppConstants.invoiceVoided => BadgeType.error,
  AppConstants.invoicePartial => BadgeType.info,
  _ => BadgeType.warning,
};

String _formatDate(DateTime? d) {
  if (d == null) return '—';
  return '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// Part 12 Task 2 — /billing. List filterable by status and date range.
class BillingScreen extends ConsumerStatefulWidget {
  const BillingScreen({super.key});

  @override
  ConsumerState<BillingScreen> createState() => _BillingScreenState();
}

class _BillingScreenState extends ConsumerState<BillingScreen> {
  String? _statusFilter;
  DateTime? _dateFrom;
  DateTime? _dateTo;

  Future<void> _pickDate({required bool isFrom}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: (isFrom ? _dateFrom : _dateTo) ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null) {
      setState(() {
        if (isFrom) {
          _dateFrom = picked;
        } else {
          _dateTo = picked;
        }
      });
    }
  }

  static String _isoDate(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

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
                        'Billing',
                        style: TextStyle(
                          color: context.appText,
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    if (isOrgAdmin) ...[
                      const BranchSelector(),
                      const SizedBox(width: 12),
                    ],
                    const TopBarActions(),
                  ],
                ),
                const SizedBox(height: 20),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    SizedBox(
                      width: 180,
                      child: AppSelect(
                        // '' is a sentinel for "All statuses" — AppSelect's
                        // options require a non-null value, unlike
                        // DropdownMenuItem which allowed a literal `null`.
                        value: _statusFilter ?? '',
                        hint: 'All statuses',
                        options: [
                          const AppSelectOption(value: '', label: 'All statuses'),
                          ...AppConstants.invoiceStatuses.map(
                            (s) => AppSelectOption(value: s, label: _statusLabels[s] ?? s),
                          ),
                        ],
                        onChanged: (v) =>
                            setState(() => _statusFilter = (v == null || v.isEmpty) ? null : v),
                      ),
                    ),
                    _DateFilterButton(
                      label: _dateFrom == null ? 'From date' : _isoDate(_dateFrom!),
                      onTap: () => _pickDate(isFrom: true),
                    ),
                    _DateFilterButton(
                      label: _dateTo == null ? 'To date' : _isoDate(_dateTo!),
                      onTap: () => _pickDate(isFrom: false),
                    ),
                    if (_statusFilter != null || _dateFrom != null || _dateTo != null)
                      TextButton(
                        onPressed: () => setState(() {
                          _statusFilter = null;
                          _dateFrom = null;
                          _dateTo = null;
                        }),
                        child: const Text('Clear filters'),
                      ),
                  ],
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: effectiveBranchId == null && !isAllBranches
                      ? const NoBranchSelectedState()
                      : _InvoicesList(
                          branchId: isAllBranches ? null : effectiveBranchId,
                          status: _statusFilter,
                          dateFrom: _dateFrom != null ? _isoDate(_dateFrom!) : null,
                          dateTo: _dateTo != null ? _isoDate(_dateTo!) : null,
                        ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _DateFilterButton extends StatelessWidget {
  const _DateFilterButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(AppTheme.inputRadius),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          border: Border.all(color: context.appBorder),
          borderRadius: BorderRadius.circular(AppTheme.inputRadius),
        ),
        child: Text(label, style: TextStyle(color: context.appText, fontSize: 14)),
      ),
    );
  }
}

class _InvoicesList extends ConsumerWidget {
  const _InvoicesList({
    required this.branchId,
    required this.status,
    required this.dateFrom,
    required this.dateTo,
  });

  final String? branchId;
  final String? status;
  final String? dateFrom;
  final String? dateTo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final invoicesAsync = ref.watch(
      invoicesListProvider((
        branchId: branchId,
        status: status,
        dateFrom: dateFrom,
        dateTo: dateTo,
      )),
    );

    return invoicesAsync.when(
      loading: () => const LoadingWidget(),
      error: (e, _) => Center(
        child: Text('$e', style: TextStyle(color: context.appSubtext)),
      ),
      data: (invoices) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CliniqnovvaTableHeader(
            columns: ['Patient', 'Date', 'Total (RWF)', 'Balance (RWF)', 'Status'],
            lastColumnEndPadding: 50,
          ),
          Expanded(
            child: invoices.isEmpty
                ? Center(
                    child: Text(
                      'No invoices match these filters.',
                      style: TextStyle(color: context.appSubtext),
                    ),
                  )
                : ListView(
                    children: invoices
                        .map(
                          (invoice) => CliniqnovvaTableRow(
                            onTap: () => showInvoiceDetailPanel(
                              context,
                              invoiceId: invoice.id,
                            ),
                            lastColumnEndPadding: 50,
                            cells: [
                              _PatientCell(patientId: invoice.patientId),
                              Text(
                                _formatDate(invoice.createdAt),
                                style: TextStyle(color: context.appText),
                              ),
                              Text(
                                invoice.totalAmountRwf.toString(),
                                style: TextStyle(color: context.appText),
                              ),
                              Text(
                                invoice.balanceDueRwf.toString(),
                                style: TextStyle(
                                  color: invoice.balanceDueRwf > 0
                                      ? context.appText
                                      : context.appSubtext,
                                ),
                              ),
                              StatusBadge(
                                text: _statusLabels[invoice.status] ?? invoice.status,
                                type: _badgeTypeFor(invoice.status),
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

class _PatientCell extends ConsumerWidget {
  const _PatientCell({required this.patientId});

  final String patientId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final patientAsync = ref.watch(patientDetailProvider(patientId));
    return patientAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (e, _) => Text('—', style: TextStyle(color: context.appSubtext)),
      data: (patient) => Text(
        patient.name,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: context.appText, fontWeight: FontWeight.w500),
      ),
    );
  }
}
