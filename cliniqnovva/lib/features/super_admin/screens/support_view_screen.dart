import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_icons.dart';
import '../../../core/theme/theme_ext.dart';
import '../../../shared/widgets/app_icon.dart';
import '../../../shared/widgets/cliniqnovva_button.dart';
import '../../../shared/widgets/cliniqnovva_card.dart';
import '../../../shared/widgets/cliniqnovva_table.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../organizations/providers/organizations_provider.dart';
import '../../platform/providers/platform_provider.dart';
import '../widgets/super_admin_scaffold.dart';

/// Part 5 Task 3 — a read-only view of an organization's info for support
/// purposes. Every session start/end is logged to auditLogs. Deliberately
/// has ZERO write-capable widgets (no edit fields, no Suspend/Activate, no
/// Record Payment, no branch creation) — Super Admin must never be able to
/// accidentally write another org's data through this screen (DONE
/// CONDITION). Only `ApiService` calls this file makes are the audit-only
/// support-view start/end and the existing read-only
/// `organizationDetailProvider`.
class SupportViewScreen extends ConsumerStatefulWidget {
  const SupportViewScreen({super.key, required this.organizationId});

  final String organizationId;

  @override
  ConsumerState<SupportViewScreen> createState() => _SupportViewScreenState();
}

class _SupportViewScreenState extends ConsumerState<SupportViewScreen> {
  String? _sessionId;

  @override
  void initState() {
    super.initState();
    _startSession();
  }

  Future<void> _startSession() async {
    final sessionId = await ref.read(platformNotifierProvider.notifier).startSupportView(widget.organizationId);
    if (!mounted) return;
    setState(() => _sessionId = sessionId);
  }

  @override
  void dispose() {
    if (_sessionId != null) {
      // Fire-and-forget — dispose() can't be async, and this is a pure
      // audit-log write, not user-facing state.
      ref.read(platformNotifierProvider.notifier).endSupportView(widget.organizationId, _sessionId!);
    }
    super.dispose();
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '—';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final detailAsync = ref.watch(organizationDetailProvider(widget.organizationId));

    return SuperAdminScaffold(
      currentRoute: '/super-admin/oversight',
      title: 'Support View',
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(color: AppColors.pillAmberBg, borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                const AppIcon(AppIcons.warning, size: 18, color: AppColors.pillAmberText),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text(
                    'Support View — Read Only. This session is logged.',
                    style: TextStyle(color: AppColors.pillAmberText, fontWeight: FontWeight.w600),
                  ),
                ),
                CliniqnovvaButton.text(
                  label: 'Exit',
                  color: AppColors.pillAmberText,
                  onPressed: () => context.go('/super-admin/oversight'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          detailAsync.when(
            loading: () => const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())),
            error: (err, _) => Text('Failed to load organization: $err'),
            data: (org) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          org.name,
                          style: TextStyle(color: context.appText, fontSize: 20, fontWeight: FontWeight.w600),
                        ),
                      ),
                      StatusBadge(
                        text: org.isActive ? 'Active' : 'Suspended',
                        type: org.isActive ? BadgeType.success : BadgeType.error,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  CliniqnovvaCard(
                    title: 'Organization info',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _InfoRow(
                          label: 'Subscription plan',
                          value: '${org.subscriptionPlan[0].toUpperCase()}${org.subscriptionPlan.substring(1)}',
                        ),
                        _InfoRow(label: 'Branches', value: org.branchLimitLabel),
                        _InfoRow(label: 'Billing cycle', value: org.billingCycle),
                        _InfoRow(label: 'Subscription amount', value: '${org.subscriptionAmountRwf} RWF'),
                        _InfoRow(label: 'Next due', value: _formatDate(org.nextDueDate)),
                        _InfoRow(label: 'Owner contact', value: org.ownerContactName ?? '—'),
                        _InfoRow(label: 'Owner phone', value: org.ownerContactPhone ?? '—'),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  CliniqnovvaCard(
                    title: 'Branches',
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const CliniqnovvaTableHeader(columns: ['Name', 'Address', 'Phone', 'Status']),
                        if (org.branches.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 24),
                            child: Text('No branches yet.', style: TextStyle(color: context.appSubtext)),
                          )
                        else
                          for (final branch in org.branches)
                            CliniqnovvaTableRow(
                              cells: [
                                Text(branch.name, style: TextStyle(color: context.appText, fontWeight: FontWeight.w600)),
                                Text(branch.address ?? '—'),
                                Text(branch.phone ?? '—'),
                                StatusBadge(
                                  text: branch.isActive ? 'Active' : 'Inactive',
                                  type: branch.isActive ? BadgeType.success : BadgeType.error,
                                ),
                              ],
                            ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(width: 180, child: Text(label, style: TextStyle(color: context.appSubtext))),
          Expanded(child: Text(value, style: TextStyle(color: context.appText, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }
}
