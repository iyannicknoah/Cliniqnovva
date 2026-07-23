import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/theme_ext.dart';
import '../../../shared/widgets/cliniqnovva_card.dart';
import '../../../shared/widgets/cliniqnovva_table.dart';
import '../../../shared/widgets/metric_card.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../organizations/models/organization.dart';
import '../../organizations/providers/organizations_provider.dart';
import '../widgets/payment_history_panel.dart';
import '../widgets/super_admin_scaffold.dart';

/// Part 4 — Super Admin B: subscription/billing tracking. Cash-only
/// record-keeping — there is NO payment gateway, this screen only records
/// that a payment happened and surfaces overdue status (never auto-suspends;
/// suspending stays the manual Part 3 toggle).
class SuperAdminBillingScreen extends ConsumerWidget {
  const SuperAdminBillingScreen({super.key});

  String _formatDate(DateTime? date) {
    if (date == null) return '—';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  (String, BadgeType) _statusLabel(String billingStatus) {
    return switch (billingStatus) {
      'paid' => ('Paid', BadgeType.success),
      'pending' => ('Pending', BadgeType.warning),
      _ => ('Not Paid', BadgeType.error),
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final organizationsAsync = ref.watch(organizationsListProvider);

    return SuperAdminScaffold(
      currentRoute: '/super-admin/billing',
      title: 'Platform Billing',
      body: organizationsAsync.when(
        loading: () => const Padding(
          padding: EdgeInsets.all(40),
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (err, _) => Text('Failed to load clinics: $err'),
        data: (organizations) {
          final active = organizations.where((o) => o.isActive).toList();
          final totalMonthlyRevenue = active.fold<double>(
            0,
            (sum, o) => sum + o.monthlyEquivalentRwf,
          );
          final paidThisCycle = active
              .where((o) => o.billingStatus == 'paid')
              .length;
          final pending = active
              .where((o) => o.billingStatus == 'pending')
              .length;
          final notPaid = active
              .where((o) => o.billingStatus == 'notPaid')
              .length;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: MetricCard(
                      value: formatRwf(totalMonthlyRevenue),
                      label: 'Total monthly revenue',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: MetricCard(
                      value: '$paidThisCycle',
                      label: 'Clinics paid this cycle',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: MetricCard(
                      value: '$pending',
                      label: 'Clinics pending',
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: MetricCard(
                      value: '$notPaid',
                      label: 'Clinics not paid',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              CliniqnovvaCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CliniqnovvaTableHeader(
                      columns: [
                        'Clinic',
                        'Plan',
                        'Amount (RWF)',
                        'Next due',
                        'Status',
                      ],
                    ),
                    if (organizations.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'No clinics yet.',
                          style: TextStyle(color: context.appSubtext),
                        ),
                      )
                    else
                      for (final org in organizations)
                        CliniqnovvaTableRow(
                          onTap: () => showPaymentHistoryPanel(context, org),
                          cells: _buildRowCells(context, org),
                        ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  List<Widget> _buildRowCells(BuildContext context, Organization org) {
    final (label, type) = _statusLabel(org.billingStatus);
    return [
      Text(
        org.name,
        style: TextStyle(color: context.appText, fontWeight: FontWeight.w600),
      ),
      Text(
        '${org.subscriptionPlan[0].toUpperCase()}${org.subscriptionPlan.substring(1)}',
      ),
      Text(formatRwf(org.subscriptionAmountRwf)),
      Text(_formatDate(org.nextDueDate)),
      StatusBadge(text: label, type: type),
    ];
  }
}
