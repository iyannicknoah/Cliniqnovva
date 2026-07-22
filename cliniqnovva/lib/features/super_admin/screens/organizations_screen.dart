import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/cliniqnovva_button.dart';
import '../../../shared/widgets/cliniqnovva_card.dart';
import '../../../shared/widgets/cliniqnovva_table.dart';
import '../../../shared/widgets/cliniqnovva_text_field.dart';
import '../../../shared/widgets/metric_card.dart';
import '../../../shared/widgets/status_badge.dart';
import '../../organizations/models/organization.dart';
import '../../organizations/providers/organizations_provider.dart';
import '../widgets/add_organization_panel.dart';
import '../widgets/confirm_status_dialog.dart';
import '../widgets/super_admin_scaffold.dart';

/// Part 3 Task 1 — Super Admin's organization list: summary MetricCards,
/// search, "+ Add Organization", and the organizations table.
class OrganizationsScreen extends ConsumerStatefulWidget {
  const OrganizationsScreen({super.key});

  @override
  ConsumerState<OrganizationsScreen> createState() => _OrganizationsScreenState();
}

class _OrganizationsScreenState extends ConsumerState<OrganizationsScreen> {
  final _searchController = TextEditingController();
  String _search = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _confirmSetStatus(Organization org, bool activate) async {
    final confirmed = await confirmOrganizationStatusChange(context, organizationName: org.name, activate: activate);
    if (!confirmed) return;
    await ref.read(organizationsNotifierProvider.notifier).setStatus(org.id, activate);
  }

  String _formatDate(DateTime? date) {
    if (date == null) return '—';
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final organizationsAsync = ref.watch(organizationsListProvider);

    return SuperAdminScaffold(
      currentRoute: '/super-admin/organizations',
      title: 'Organizations',
      body: organizationsAsync.when(
        loading: () => const Padding(padding: EdgeInsets.all(40), child: Center(child: CircularProgressIndicator())),
        error: (err, _) => Text('Failed to load organizations: $err'),
        data: (organizations) {
          final total = organizations.length;
          final active = organizations.where((o) => o.isActive).length;
          final suspended = total - active;
          final filtered = _search.isEmpty
              ? organizations
              : organizations.where((o) => o.name.toLowerCase().contains(_search.toLowerCase())).toList();

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(child: MetricCard(value: '$total', label: 'Total organizations')),
                  const SizedBox(width: 16),
                  Expanded(child: MetricCard(value: '$active', label: 'Active')),
                  const SizedBox(width: 16),
                  Expanded(child: MetricCard(value: '$suspended', label: 'Suspended')),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: CliniqnovvaTextField(
                      label: 'Search',
                      controller: _searchController,
                      hint: 'Search by name',
                      onChanged: (value) => setState(() => _search = value),
                    ),
                  ),
                  const SizedBox(width: 16),
                  CliniqnovvaButton(
                    label: '+ Add Organization',
                    isFullWidth: false,
                    onPressed: () => showAddOrganizationPanel(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              CliniqnovvaCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const CliniqnovvaTableHeader(columns: ['Name', 'Plan', 'Branches', 'Status', 'Created', 'Actions']),
                    if (filtered.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Text('No organizations yet.', style: TextStyle(color: AppColors.textSecondary)),
                      )
                    else
                      for (final org in filtered)
                        CliniqnovvaTableRow(
                          onTap: () => context.push('/super-admin/organizations/${org.id}'),
                          cells: [
                            Text(
                              org.name,
                              style: const TextStyle(color: AppColors.textPrimary, fontWeight: FontWeight.w600),
                            ),
                            Text('${org.subscriptionPlan[0].toUpperCase()}${org.subscriptionPlan.substring(1)}'),
                            Text(org.branchLimitLabel),
                            StatusBadge(
                              text: org.isActive ? 'Active' : 'Suspended',
                              type: org.isActive ? BadgeType.success : BadgeType.error,
                            ),
                            Text(_formatDate(org.createdAt)),
                            Row(
                              children: [
                                IconButton(
                                  icon: const Icon(Icons.visibility_outlined, size: 18),
                                  tooltip: 'View',
                                  onPressed: () => context.push('/super-admin/organizations/${org.id}'),
                                ),
                                IconButton(
                                  icon: Icon(
                                    org.isActive ? Icons.pause_circle_outline : Icons.play_circle_outline,
                                    size: 18,
                                  ),
                                  tooltip: org.isActive ? 'Suspend' : 'Activate',
                                  onPressed: () => _confirmSetStatus(org, !org.isActive),
                                ),
                              ],
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
    );
  }
}
